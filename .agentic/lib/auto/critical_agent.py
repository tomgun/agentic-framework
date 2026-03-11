"""
critical_agent.py -- Critical Review Agent for the Agentic Framework.

Implements ADR-001 Phase 4 (F-0182): spawns a separate Claude instance with
an adversarial review prompt to evaluate transitions. The agent is read-only
(--print mode) and returns a structured verdict.

Usage (internal — called by review.py):
    from auto.critical_agent import CriticalAgent
    agent = CriticalAgent(project_root)
    verdict = agent.review("F-0042", "planned", "specced", "review_spec")
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

# ---------------------------------------------------------------------------
# Resolve paths.py / settings.py from the lib/ directory (our parent)
# ---------------------------------------------------------------------------
_LIB_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(_LIB_DIR))
from paths import get_paths  # noqa: E402
from settings import get_setting  # noqa: E402

from auto import spawn_claude  # noqa: E402

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

_DIFF_MAX_LINES = 3000
_REVIEW_TIMEOUT = 600  # seconds — reviews may need longer than default 300
_RETRY_DELAY = 5  # seconds before retry on transient error

# Agent-mode → model mapping (premium uses CLI default, no --model flag)
_AGENT_MODE_MODELS: dict[str, Optional[str]] = {
    "premium": None,
    "balanced": "sonnet",
    "economy": "haiku",
}

# Review-type → focus areas for prompt assembly
_REVIEW_FOCUS: dict[str, str] = {
    "review_spec": (
        "Focus on: completeness of requirements, ambiguity in language, "
        "testability of acceptance criteria, missing edge cases, "
        "consistency with existing features."
    ),
    "review_criteria": (
        "Focus on: measurability of criteria, coverage of happy/unhappy paths, "
        "missing NFR alignment, feasibility of testing approach."
    ),
    "review_plan": (
        "Focus on: architectural soundness, risk identification, "
        "phasing/ordering correctness, missing dependencies, scope creep."
    ),
    "review_code": (
        "Focus on: correctness, security vulnerabilities (OWASP top 10), "
        "test coverage, AC alignment, breaking changes, code conventions."
    ),
    "review_merge": (
        "Focus on: release readiness, backward compatibility, "
        "documentation completeness, changelog accuracy, version bump."
    ),
    "review_regression": (
        "Focus on: justification for regression, impact analysis, "
        "affected tests, rollback plan."
    ),
    "review_taste": (
        "Focus on: consistency with declared style guide, design system alignment, "
        "naming conventions, API pattern consistency, public surface quality. "
        "Only flag significant style inconsistencies — minor internal deviations are OK."
    ),
}


# ---------------------------------------------------------------------------
# ReviewVerdict
# ---------------------------------------------------------------------------

@dataclass
class ReviewVerdict:
    """Structured result from a critical agent review."""
    verdict: str  # approved | request_changes | escalate
    confidence: str = "medium"  # high | medium | low
    summary: str = ""
    issues: list[dict] = field(default_factory=list)
    recommendation: str = ""
    raw_output: str = ""


# ---------------------------------------------------------------------------
# CriticalAgent
# ---------------------------------------------------------------------------

class CriticalAgent:
    """Spawns a Claude instance to perform adversarial review of transitions."""

    def __init__(
        self,
        project_root: Path,
        claude_command: str = "claude",
    ):
        self.project_root = project_root
        self.claude_command = claude_command
        self._paths = get_paths(project_root)

    # -- Public API --------------------------------------------------------

    def review(
        self,
        feature_id: str,
        from_state: str,
        to_state: str,
        review_setting: str,
    ) -> ReviewVerdict:
        """Run adversarial review. Returns structured verdict.

        On transient errors, retries once before raising.
        On timeout/unavailable, raises immediately (caller falls back to human).
        """
        context = self._assemble_context(
            feature_id, from_state, to_state, review_setting,
        )
        prompt = self._build_prompt(context, review_setting)
        model = self._resolve_model()

        # First attempt
        output = spawn_claude(
            self.claude_command, self.project_root, prompt,
            print_mode=True, timeout=_REVIEW_TIMEOUT, model=model,
        )

        if self._is_error(output):
            error_type = self._classify_error(output)
            if error_type == "transient":
                # Retry once after delay
                time.sleep(_RETRY_DELAY)
                output = spawn_claude(
                    self.claude_command, self.project_root, prompt,
                    print_mode=True, timeout=_REVIEW_TIMEOUT, model=model,
                )
                if self._is_error(output):
                    raise RuntimeError(
                        f"Critical agent failed after retry: {output[:200]}"
                    )
            else:
                # timeout or unavailable — immediate failure
                raise RuntimeError(
                    f"Critical agent {error_type}: {output[:200]}"
                )

        return self._parse_verdict(output)

    # -- Context assembly --------------------------------------------------

    def _assemble_context(
        self,
        feature_id: str,
        from_state: str,
        to_state: str,
        review_setting: str,
    ) -> str:
        """Gather relevant context based on review type."""
        sections: list[str] = []

        sections.append(
            f"## Transition\n{feature_id}: {from_state} → {to_state} "
            f"(checkpoint: {review_setting})"
        )

        # Feature spec entry
        features_content = self._read_file(self._paths.features_file)
        if features_content:
            # Extract just this feature's section
            feature_section = self._extract_feature_section(
                features_content, feature_id,
            )
            if feature_section:
                sections.append(f"## Feature Spec\n{feature_section}")

        # Acceptance criteria
        ac_file = self._paths.acceptance_dir / f"{feature_id}.md"
        ac_content = self._read_file(ac_file)
        if ac_content:
            sections.append(f"## Acceptance Criteria\n{ac_content}")

        # Review-type-specific context
        if review_setting in (
            "review_code", "review_merge", "review_regression", "review_taste",
        ):
            diff = self._get_git_diff()
            if diff:
                sections.append(f"## Code Changes (git diff)\n```\n{diff}\n```")
            else:
                sections.append("## Code Changes\nNo changes detected.")

        if review_setting == "review_plan":
            plan_file = self._paths.plans_dir / f"{feature_id}-plan.md"
            plan_content = self._read_file(plan_file)
            if plan_content:
                sections.append(f"## Implementation Plan\n{plan_content}")

        # NFRs (all review types)
        nfr_content = self._read_file(self._paths.nfr_file)
        if nfr_content:
            sections.append(f"## Non-Functional Requirements\n{nfr_content}")

        return "\n\n".join(sections)

    def _load_style_settings(self) -> str:
        """Load style & taste settings from STACK.md's ## Style & taste section.

        Handles multi-line HTML comments and loads referenced style files
        (with path traversal guard).
        """
        stack_content = self._read_file(self._paths.stack_file)
        if not stack_content:
            return ""

        # Extract the ## Style & taste section (mirrors _parse_model_customization)
        lines = stack_content.splitlines()
        in_section = False
        in_comment = False
        section_lines: list[str] = []
        for line in lines:
            if not in_section:
                if line.startswith("## Style & taste"):
                    in_section = True
                continue
            if re.match(r"^##\s+[^#]", line):
                break
            # Multi-line comment handling (same pattern as _parse_model_customization)
            if "<!--" in line and "-->" in line:
                continue  # single-line comment
            if "<!--" in line:
                in_comment = True
                continue
            if "-->" in line:
                in_comment = False
                continue
            if in_comment:
                continue
            stripped = line.strip()
            if stripped.startswith("- ") and ":" in stripped:
                section_lines.append(stripped)

        if not section_lines:
            return ""

        result_parts = ["### Declared Settings"]
        result_parts.extend(section_lines)

        # Load referenced files (style_guide, design_system paths)
        for sl in section_lines:
            key_val = sl.lstrip("- ").split(":", 1)
            if len(key_val) == 2:
                key = key_val[0].strip()
                val = key_val[1].strip()
                if key in ("style_guide", "design_system") and val:
                    ref_path = (self.project_root / val).resolve()
                    # Path traversal guard
                    try:
                        ref_path.relative_to(self.project_root.resolve())
                    except ValueError:
                        continue
                    ref_content = self._read_file(ref_path)
                    if ref_content:
                        truncated = ref_content[:5000]
                        if len(ref_content) > 5000:
                            truncated += "\n... (truncated)"
                        result_parts.append(
                            f"\n### {key} ({val})\n{truncated}"
                        )

        return "\n".join(result_parts)

    def _get_git_diff(self) -> str:
        """Get git diff, choosing ref range based on branch. Truncates."""
        try:
            branch = subprocess.run(
                ["git", "rev-parse", "--abbrev-ref", "HEAD"],
                capture_output=True, text=True, cwd=str(self.project_root),
            ).stdout.strip()

            # Feature branch: try diff against main/master first
            if branch and branch not in ("main", "master"):
                for base in ("main", "master"):
                    result = subprocess.run(
                        ["git", "diff", f"{base}...HEAD"],
                        capture_output=True, text=True,
                        cwd=str(self.project_root),
                    )
                    if result.returncode == 0 and result.stdout.strip():
                        return self._truncate_diff(result.stdout)

            # Main branch or feature branch with no base diff: use HEAD~1
            result = subprocess.run(
                ["git", "diff", "HEAD~1"],
                capture_output=True, text=True,
                cwd=str(self.project_root),
            )
            if result.returncode == 0:
                return self._truncate_diff(result.stdout)
        except (FileNotFoundError, OSError, Exception):
            pass
        return ""

    def _truncate_diff(self, diff: str) -> str:
        """Truncate diff to _DIFF_MAX_LINES lines."""
        lines = diff.splitlines()
        if len(lines) <= _DIFF_MAX_LINES:
            return diff
        truncated = "\n".join(lines[:_DIFF_MAX_LINES])
        return f"{truncated}\n\n[diff truncated, {len(lines)} lines total]"

    @staticmethod
    def _extract_feature_section(content: str, feature_id: str) -> str:
        """Extract a single feature's section from FEATURES.md."""
        pattern = re.compile(
            rf"^## {re.escape(feature_id)}:.*?(?=^## |\Z)",
            re.MULTILINE | re.DOTALL,
        )
        m = pattern.search(content)
        return m.group(0).strip() if m else ""

    @staticmethod
    def _read_file(path: Path) -> str:
        """Read file contents, return empty string if missing."""
        try:
            if path.exists():
                return path.read_text(encoding="utf-8")
        except OSError:
            pass
        return ""

    # -- Model resolution --------------------------------------------------

    def _resolve_model(self) -> Optional[str]:
        """Resolve model with fallback chain.

        1. Parse ## Model customization section for 'review:' value
        2. Map agent_mode: premium→None, balanced→sonnet, economy→haiku
        3. Fall back to None (no --model flag, uses CLI default)
        """
        # 1. Check Model customization section
        model = self._parse_model_customization()
        if model is not None:
            return model if model else None

        # 2. Check agent_mode
        agent_mode = get_setting(self.project_root, "agent_mode", "")
        if agent_mode in _AGENT_MODE_MODELS:
            return _AGENT_MODE_MODELS[agent_mode]

        # 3. Default
        return None

    def _parse_model_customization(self) -> Optional[str]:
        """Parse ## Model customization in STACK.md for review model.

        Returns model string, empty string (meaning "use default"), or None
        (section not found / not configured).
        """
        stack_path = self.project_root / "STACK.md"
        try:
            text = stack_path.read_text(encoding="utf-8")
        except OSError:
            return None

        # Find the Model customization section
        in_section = False
        in_comment = False
        for line in text.splitlines():
            if not in_section:
                if re.match(r"^##\s+Model customization", line):
                    in_section = True
                continue

            # Stop at next H2 heading
            if re.match(r"^##\s+[^#]", line):
                break

            # Track HTML comment boundaries
            # Handle single-line comments (<!-- ... -->) and multi-line
            if "<!--" in line and "-->" in line:
                # Entire comment on one line — skip it, don't change state
                continue
            if "<!--" in line:
                in_comment = True
                continue
            if "-->" in line:
                in_comment = False
                continue

            # Skip lines inside multi-line comments
            if in_comment:
                continue

            # Match "    review: <model>" or "- review: <model>" (indented)
            m = re.match(r"^\s+(?:-\s+)?review:\s*(\S+)", line)
            if m:
                return m.group(1).strip()

        return None

    # -- Prompt building ---------------------------------------------------

    def _build_prompt(self, context: str, review_setting: str) -> str:
        """Load review template and substitute context."""
        prompts_dir = Path(__file__).resolve().parent / "prompts"

        # Taste reviews use their own template
        if review_setting == "review_taste":
            template_path = prompts_dir / "taste_review.md"
        else:
            template_path = prompts_dir / "critical_review.md"

        try:
            template = template_path.read_text(encoding="utf-8")
        except OSError:
            # Fallback inline prompt if template missing
            template = (
                "You are a CRITICAL REVIEWER. Review the following and "
                "respond with a JSON verdict.\n\n{context}\n\n{focus}\n\n"
                "{verdict_schema}"
            )

        focus = _REVIEW_FOCUS.get(review_setting, "Perform a general review.")
        verdict_schema = (
            'Respond with ONLY a JSON block in ```json fences:\n'
            '```json\n'
            '{\n'
            '  "verdict": "approved | request_changes | escalate",\n'
            '  "confidence": "high | medium | low",\n'
            '  "summary": "One-line summary",\n'
            '  "issues": [\n'
            '    {"severity": "critical|high|medium|low", '
            '"category": "...", "description": "...", "location": "..."}\n'
            '  ],\n'
            '  "recommendation": "What should happen next"\n'
            '}\n'
            '```'
        )

        # Taste template has {style_context} — only loaded here (not in
        # _assemble_context) to avoid duplicating style settings in the prompt.
        result = template
        if review_setting == "review_taste":
            style_context = self._load_style_settings() or "No style settings declared."
            result = result.replace("{style_context}", style_context)

        return (
            result
            .replace("{context}", context)
            .replace("{focus}", focus)
            .replace("{verdict_schema}", verdict_schema)
        )

    # -- Verdict parsing ---------------------------------------------------

    def _parse_verdict(self, output: str) -> ReviewVerdict:
        """Extract JSON verdict from Claude output.

        Strategy: fenced ```json block (last match wins), then bare JSON,
        then escalation fallback.
        """
        # 1. Try fenced JSON blocks — last match wins
        fenced = re.findall(
            r"```json\s*\n(.*?)\n\s*```", output, re.DOTALL | re.IGNORECASE,
        )
        if fenced:
            try:
                data = json.loads(fenced[-1])
                return self._verdict_from_dict(data, output)
            except (json.JSONDecodeError, KeyError):
                pass

        # 2. Try bare JSON — scan for { ... } blocks starting from each {
        start = 0
        while True:
            brace_start = output.find("{", start)
            if brace_start == -1:
                break
            brace_end = output.rfind("}")
            if brace_end <= brace_start:
                break
            try:
                data = json.loads(output[brace_start:brace_end + 1])
                return self._verdict_from_dict(data, output)
            except (json.JSONDecodeError, KeyError):
                start = brace_start + 1

        # 3. Parsing failed → escalate (never auto-approve)
        return ReviewVerdict(
            verdict="escalate",
            confidence="low",
            summary="Failed to parse critical agent output — escalating to human",
            issues=[{
                "severity": "high",
                "category": "parse_failure",
                "description": "Could not extract structured verdict from agent output",
                "location": "critical_agent",
            }],
            recommendation="Human should review the agent's raw output",
            raw_output=output,
        )

    @staticmethod
    def _verdict_from_dict(data: dict, raw_output: str) -> ReviewVerdict:
        """Build ReviewVerdict from parsed JSON dict."""
        verdict = data.get("verdict", "escalate")
        if verdict not in ("approved", "request_changes", "escalate"):
            verdict = "escalate"
        return ReviewVerdict(
            verdict=verdict,
            confidence=data.get("confidence", "medium"),
            summary=data.get("summary", ""),
            issues=data.get("issues", []),
            recommendation=data.get("recommendation", ""),
            raw_output=raw_output,
        )

    # -- Error handling ----------------------------------------------------

    @staticmethod
    def _is_error(output: str) -> bool:
        """Check if spawn_claude output indicates an error."""
        return output.startswith("error: ")

    @staticmethod
    def _classify_error(output: str) -> str:
        """Classify error type from spawn_claude output.

        Returns: 'timeout' | 'unavailable' | 'transient'
        """
        if "timed out" in output:
            return "timeout"
        if "command not found" in output:
            return "unavailable"
        return "transient"
