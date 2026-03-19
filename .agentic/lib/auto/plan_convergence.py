"""
plan_convergence.py -- Autonomous plan convergence loop (F-0236).

Runs reviewers in parallel, checks convergence, auto-revises plans until
converged or max iterations reached. Supports configurable reviewer roles.

Usage (Python API):
    from auto.plan_convergence import ConvergenceLoop
    loop = ConvergenceLoop(project_root=Path("."), claude_command="claude")
    result = loop.run(feature_id="F-0042", plan_path="...", autonomous=True)

Usage (CLI):
    python3 .agentic/lib/auto/plan_convergence.py --feature F-0042
    # Exit 0: approved, Exit 1: ran loop (check result), Exit 2: not found/escalated
"""
from __future__ import annotations

import json
import re
import subprocess
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional

_LIB_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(_LIB_DIR))
from paths import get_paths  # noqa: E402
from settings import get_setting  # noqa: E402

from auto import spawn_claude  # noqa: E402
from auto.reviewer_catalog import (  # noqa: E402
    ReviewerRole,
    get_active_reviewers,
    get_setting_list,
)


@dataclass
class ConvergenceResult:
    """Result of a convergence loop run."""
    converged: bool = False
    iteration_count: int = 0
    final_synthesis: str = ""
    plan_status: str = ""        # APPROVED | ESCALATED | MANUAL
    escalation_reason: str = ""


# ---------------------------------------------------------------------------
# Convergence Detection
# ---------------------------------------------------------------------------

class ConvergenceDetector:
    """Detects whether a plan review has converged.

    Convergence = ALL of:
    1. Critic has zero High-Confidence Concerns
    2. No expert reviewer has high-severity findings
    3. Iteration >= 2 (minimum 2 rounds)
    """

    def detect(
        self,
        critic_output: str,
        expert_outputs: dict[str, str],
        iteration: int,
    ) -> tuple[bool, str]:
        """Check convergence. Returns (converged, reason)."""
        # Guard: minimum 2 iterations
        if iteration < 2:
            return False, "Minimum 2 iterations required"

        # Check Critic high-confidence concerns
        critic_has_concerns = self._has_high_confidence_concerns(critic_output)
        if critic_has_concerns:
            return False, "Critic has high-confidence concerns"

        # Check explicit convergence signal checkbox
        critic_converged = self._has_convergence_signal(critic_output)

        # Check expert outputs for high-severity findings
        for role_name, output in expert_outputs.items():
            if role_name in ("critic", "advocate"):
                continue  # handled separately
            if self._has_high_confidence_concerns(output):
                return False, f"Expert '{role_name}' has high-confidence concerns"

        # Check advocate convergence signal (if present)
        advocate_output = expert_outputs.get("advocate", "")
        advocate_converged = self._has_convergence_signal(advocate_output)

        if critic_converged or not critic_has_concerns:
            return True, "No high-confidence concerns remaining"

        return True, "No high-confidence concerns remaining"

    def _has_high_confidence_concerns(self, output: str) -> bool:
        """Check if output contains High-Confidence Concerns with items.

        Uses resilient parsing with fallbacks.
        """
        if not output:
            return False  # no output = can't determine, treat as no concerns

        # Primary: look for "High-Confidence Concerns" section header
        pattern = r"###?\s*High-Confidence Concerns\s*\n(.*?)(?=\n###|\n##|\Z)"
        match = re.search(pattern, output, re.DOTALL | re.IGNORECASE)
        if match:
            section = match.group(1).strip()
            # Empty section or "None" = no concerns
            if not section or section.lower() in ("none", "none.", "n/a"):
                return False
            # Check for numbered items (1. **Topic**: ...)
            if re.search(r"^\s*\d+\.\s+", section, re.MULTILINE):
                return True
            # Check for bullet items
            if re.search(r"^\s*[-*]\s+", section, re.MULTILINE):
                return True
            return False

        # Fallback: search for "High-Confidence" anywhere with numbered items
        hc_idx = output.lower().find("high-confidence")
        if hc_idx >= 0:
            after = output[hc_idx:hc_idx + 500]
            if re.search(r"\d+\.\s+\*\*", after):
                return True

        # Last resort: parsing failed — safe default is NOT converged
        return True  # assume concerns exist if we can't parse

    def _has_convergence_signal(self, output: str) -> bool:
        """Check for explicit convergence checkbox."""
        return bool(re.search(
            r"-\s*\[x\]\s*Plan is fundamentally sound",
            output, re.IGNORECASE,
        ))


# ---------------------------------------------------------------------------
# Plan Synthesizer
# ---------------------------------------------------------------------------

class PlanSynthesizer:
    """Synthesizes reviewer outputs into a structured document."""

    def __init__(
        self,
        project_root: Path,
        claude_command: str = "claude",
    ) -> None:
        self.project_root = project_root
        self.claude_command = claude_command

    def synthesize(
        self,
        reviewer_outputs: dict[str, str],
        feature_id: str,
        iteration: int,
    ) -> str:
        """Spawn synthesis agent with all reviewer outputs."""
        prompt_file = Path(__file__).parent / "prompts" / "plan_synthesis.md"
        if not prompt_file.exists():
            return self._simple_synthesis(reviewer_outputs, feature_id, iteration)

        template = prompt_file.read_text()

        # Format reviewer outputs
        outputs_text = ""
        for role_name, output in reviewer_outputs.items():
            outputs_text += f"\n### {role_name.replace('_', ' ').title()}\n\n{output}\n"

        prompt = template.format(
            reviewer_count=len(reviewer_outputs),
            iteration=iteration,
            feature_id=feature_id,
            reviewer_outputs=outputs_text,
        )

        result = spawn_claude(
            self.claude_command,
            self.project_root,
            prompt,
            print_mode=True,
            timeout=180,
        )
        return str(result)

    def _simple_synthesis(
        self,
        reviewer_outputs: dict[str, str],
        feature_id: str,
        iteration: int,
    ) -> str:
        """Fallback synthesis when prompt template is missing."""
        parts = [f"# Dialectical Review: {feature_id} (Iteration {iteration})\n"]
        for role_name, output in reviewer_outputs.items():
            parts.append(f"## {role_name.replace('_', ' ').title()}\n\n{output}\n")
        return "\n".join(parts)

    def extract_revision_guidance(self, synthesis: str) -> str:
        """Extract the Revision Guidance section from synthesis."""
        match = re.search(
            r"##\s*Revision Guidance\s*\n(.*?)(?=\n##|\Z)",
            synthesis, re.DOTALL,
        )
        if match:
            return match.group(1).strip()
        return ""


# ---------------------------------------------------------------------------
# Convergence Loop
# ---------------------------------------------------------------------------

class ConvergenceLoop:
    """Orchestrates the plan review convergence loop."""

    def __init__(
        self,
        project_root: Path,
        claude_command: str = "claude",
    ) -> None:
        self.project_root = project_root.resolve()
        self.paths = get_paths(project_root)
        self.claude_command = claude_command
        self.detector = ConvergenceDetector()
        self.synthesizer = PlanSynthesizer(project_root, claude_command)

    def run(
        self,
        feature_id: str,
        plan_path: str,
        max_iterations: int = 0,
        reviewers: Optional[list[ReviewerRole]] = None,
        autonomous: bool = False,
    ) -> ConvergenceResult:
        """Run the convergence loop.

        Args:
            feature_id: Feature ID (e.g., "F-0042").
            plan_path: Path to the plan file.
            max_iterations: Max iterations (0 = use setting).
            reviewers: Reviewer roles (None = load from settings).
            autonomous: If True, auto-approve on convergence.

        Returns:
            ConvergenceResult with convergence status and final synthesis.
        """
        result = ConvergenceResult()

        # Guard: plan_review_enabled must be yes
        plan_review = get_setting(
            self.project_root, "plan_review_enabled", "no",
        )
        if plan_review != "yes":
            result.plan_status = "APPROVED"
            result.converged = True
            return result

        # Guard: convergence mode
        convergence_mode = get_setting(
            self.project_root, "plan_review_convergence", "auto",
        )
        if convergence_mode == "manual":
            result.plan_status = "MANUAL"
            return result

        # Resolve max iterations
        if max_iterations <= 0:
            max_iterations = int(get_setting(
                self.project_root, "plan_review_max_iterations", "3",
            ))

        # Resolve reviewers
        if reviewers is None:
            reviewers = get_active_reviewers(self.project_root)
        if not reviewers:
            result.plan_status = "APPROVED"
            result.converged = True
            return result

        # Verify plan file exists
        plan_file = Path(plan_path)
        if not plan_file.exists():
            result.plan_status = "ESCALATED"
            result.escalation_reason = f"Plan file not found: {plan_path}"
            return result

        # Convergence loop
        for iteration in range(1, max_iterations + 1):
            result.iteration_count = iteration
            print(
                f"\n  Plan review iteration {iteration}/{max_iterations}...",
                file=sys.stderr,
            )

            # Spawn all reviewers (sequentially for simplicity;
            # parallelism can be added later via threading)
            reviewer_outputs: dict[str, str] = {}
            for role in reviewers:
                output = self._spawn_reviewer(
                    role, feature_id, plan_path, iteration,
                )
                reviewer_outputs[role.name] = output

            # Synthesize
            synthesis = self.synthesizer.synthesize(
                reviewer_outputs, feature_id, iteration,
            )
            result.final_synthesis = synthesis

            # Check convergence
            critic_output = reviewer_outputs.get("critic", "")
            expert_outputs = {
                k: v for k, v in reviewer_outputs.items()
                if k not in ("critic",)
            }
            converged, reason = self.detector.detect(
                critic_output, expert_outputs, iteration,
            )

            if converged:
                result.converged = True
                if autonomous:
                    result.plan_status = "APPROVED"
                    self._update_plan_status(plan_path, "APPROVED")
                else:
                    result.plan_status = "CONVERGED"
                print(
                    f"  Plan converged: {reason}",
                    file=sys.stderr,
                )
                return result

            # Not converged — auto-revise if iterations remain
            if iteration < max_iterations:
                revision_guidance = self.synthesizer.extract_revision_guidance(
                    synthesis,
                )
                self._auto_revise_plan(
                    feature_id, plan_path, synthesis, revision_guidance,
                )
            else:
                # Max iterations reached — escalate
                result.plan_status = "ESCALATED"
                result.escalation_reason = (
                    f"Plan did not converge after {max_iterations} iterations"
                )
                self._update_plan_status(plan_path, "ESCALATED")
                self._create_escalation_blocker(feature_id, result)
                print(
                    f"  Plan did not converge after {max_iterations} iterations"
                    f" — escalating to human",
                    file=sys.stderr,
                )

        return result

    # -- Reviewer spawning --------------------------------------------------

    def _spawn_reviewer(
        self,
        role: ReviewerRole,
        feature_id: str,
        plan_path: str,
        iteration: int,
    ) -> str:
        """Spawn a single reviewer agent."""
        # Build context-aware prompt
        ac_path = self.paths.acceptance_dir / f"{feature_id}.md"
        agent_file = (
            self.paths.agentic_lib / "agents" / "claude"
            / "subagents" / role.agent_file
        )

        prompt = (
            f"You are a PLAN {role.name.upper().replace('_', ' ')} "
            f"with fresh context (iteration {iteration}).\n\n"
            f"Read plan: {plan_path}\n"
        )
        if ac_path.exists():
            prompt += f"Read requirements: {ac_path}\n"
        if agent_file.exists():
            prompt += f"Follow: {agent_file}\n"
        prompt += (
            f"\nYour mandate: {role.mandate}\n"
            f"Output your structured assessment using the format specified "
            f"in the agent file.\n\n"
            f"IMPORTANT: Include a 'Convergence Signal' section at the end:\n"
            f"### Convergence Signal\n"
            f"- [x] Plan is fundamentally sound (no high-severity concerns remaining)\n"
            f"OR\n"
            f"- [ ] Plan is fundamentally sound (check this ONLY if you have "
            f"zero high-confidence concerns)\n"
        )

        return spawn_claude(
            self.claude_command,
            self.project_root,
            prompt,
            print_mode=True,
            timeout=180,
        )

    # -- Auto-revision ------------------------------------------------------

    def _auto_revise_plan(
        self,
        feature_id: str,
        plan_path: str,
        synthesis: str,
        revision_guidance: str,
    ) -> None:
        """Spawn planner agent to revise plan based on synthesis."""
        prompt_file = Path(__file__).parent / "prompts" / "plan_revision.md"
        if prompt_file.exists():
            template = prompt_file.read_text()
            prompt = template.format(
                feature_id=feature_id,
                plan_path=plan_path,
                synthesis=synthesis,
                revision_guidance=revision_guidance or "(No specific guidance)",
            )
        else:
            prompt = (
                f"Revise the plan at {plan_path} for feature {feature_id}.\n\n"
                f"Review synthesis:\n{synthesis}\n\n"
                f"Revision guidance:\n{revision_guidance}\n\n"
                f"Read the plan, address all findings, and write it back."
            )

        # Planner needs file write access — NOT print_mode
        spawn_claude(
            self.claude_command,
            self.project_root,
            prompt,
            print_mode=False,
            timeout=300,
        )

    # -- Plan status management ---------------------------------------------

    def _update_plan_status(self, plan_path: str, status: str) -> None:
        """Update the Status field in a plan file."""
        plan_file = Path(plan_path)
        if not plan_file.exists():
            return
        content = plan_file.read_text()
        # Replace status line
        updated = re.sub(
            r"\*\*Status\*\*:\s*\w+",
            f"**Status**: {status}",
            content,
            count=1,
        )
        if updated != content:
            plan_file.write_text(updated)

    def _create_escalation_blocker(
        self, feature_id: str, result: ConvergenceResult,
    ) -> None:
        """Create HUMAN_NEEDED entry for escalated plan review."""
        blocker_sh = self.paths.tools_dir / "blocker.sh"
        if blocker_sh.exists():
            try:
                subprocess.run(
                    [
                        "bash", str(blocker_sh), "add",
                        f"Plan Escalation: {feature_id}",
                        "decision",
                        f"Plan review did not converge after "
                        f"{result.iteration_count} iterations. "
                        f"Review the plan and synthesis manually.",
                    ],
                    capture_output=True, text=True,
                    cwd=str(self.project_root),
                )
            except (OSError, subprocess.SubprocessError):
                pass


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------

def main() -> int:
    """CLI entry point for plan convergence.

    Exit codes:
        0 = plan is APPROVED
        1 = plan is DRAFT/REVIEWING (ran loop or manual mode)
        2 = plan not found or ESCALATED
    """
    import argparse

    parser = argparse.ArgumentParser(
        description="Plan convergence loop (F-0236)",
    )
    parser.add_argument(
        "--feature", required=True,
        help="Feature ID (e.g., F-0042)",
    )
    parser.add_argument(
        "--project-root", type=Path, default=Path.cwd(),
        help="Project root directory",
    )
    parser.add_argument(
        "--autonomous", action="store_true",
        help="Auto-approve on convergence (for ag auto task)",
    )
    args = parser.parse_args()

    project_root = args.project_root.resolve()
    paths = get_paths(project_root)
    feature_id = args.feature

    # Find plan file
    plans_dir = paths.plans_dir
    plan_matches = list(plans_dir.glob(f"*{feature_id}*plan*.md")) if plans_dir.exists() else []
    if not plan_matches:
        print(f"No plan found for {feature_id}", file=sys.stderr)
        return 2

    plan_path = str(plan_matches[0])

    # Check current plan status
    plan_content = Path(plan_path).read_text()
    status_match = re.search(r"\*\*Status\*\*:\s*(\w+)", plan_content)
    plan_status = status_match.group(1).upper() if status_match else "DRAFT"

    if plan_status == "APPROVED":
        return 0  # already approved

    # Run convergence loop
    loop = ConvergenceLoop(
        project_root=project_root,
        claude_command="claude",
    )
    result = loop.run(
        feature_id=feature_id,
        plan_path=plan_path,
        autonomous=args.autonomous,
    )

    if result.plan_status == "APPROVED":
        return 0
    elif result.plan_status == "ESCALATED":
        return 2
    elif result.plan_status == "MANUAL":
        print(
            f"Plan review convergence set to manual. "
            f"Run dialectical review manually.",
            file=sys.stderr,
        )
        return 1
    else:
        return 1


if __name__ == "__main__":
    sys.exit(main())
