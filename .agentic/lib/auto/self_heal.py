"""
self_heal.py -- Self-Healing Engine for Framework Verification.

Implements the failure classification and fix-spawning logic used by
framework_verify.py (F-0215). Classifies failures as framework_bug,
agent_error, or external, then spawns a scoped fix agent when appropriate.

@feature F-0215
"""
from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from auto.framework_verify import MilestoneResult

_LIB_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(_LIB_DIR))
sys.path.insert(0, str(_LIB_DIR / "tools"))

from auto import SpawnResult, spawn_claude  # noqa: E402

PROMPTS_DIR = Path(__file__).resolve().parent / "prompts"


# ---------------------------------------------------------------------------
# Failure classification
# ---------------------------------------------------------------------------

# Patterns that indicate a framework bug (not agent error)
_FRAMEWORK_BUG_PATTERNS = [
    r"Traceback \(most recent call last\):.*\.agentic/lib/",
    r"\.agentic/lib/.*Error:",
    r"\.agentic/lib/.*Exception:",
    r"ag\.sh: line \d+:.*error",
    r"ModuleNotFoundError:.*auto\.",
    r"FileNotFoundError:.*\.agentic/",
]

# Patterns that indicate external issues (not framework or agent)
_EXTERNAL_PATTERNS = [
    r"error: claude command not found",
    r"network error",
    r"rate limit",
    r"ECONNREFUSED",
    r"429 Too Many Requests",
]


class SelfHealEngine:
    """Classifies failures and spawns fix agents."""

    def __init__(self, vw_path: Path, claude_command: str = "claude"):
        self.vw_path = vw_path
        self.claude_command = claude_command

    def classify(
        self,
        result: SpawnResult,
        milestones: list[MilestoneResult],
    ) -> str:
        """Classify a failure as 'framework_bug', 'agent_error', or 'external'.

        Uses three tiers:
        1. Pattern matching on output
        2. LLM classification for ambiguous cases
        3. Conservative default: agent_error
        """
        output = str(result)

        # Timeout → agent_error (not a framework bug)
        if result.timed_out:
            return "agent_error"

        # Tier 1: Pattern matching
        for pattern in _EXTERNAL_PATTERNS:
            if re.search(pattern, output, re.IGNORECASE):
                return "external"

        for pattern in _FRAMEWORK_BUG_PATTERNS:
            if re.search(pattern, output, re.DOTALL | re.IGNORECASE):
                return "framework_bug"

        # Tier 2: LLM classification for ambiguous cases
        if result.returncode != 0 and len(output) > 100:
            llm_class = self._llm_classify(output)
            if llm_class in ("framework_bug", "agent_error", "external"):
                return llm_class

        # Tier 3: Conservative default
        return "agent_error"

    def _llm_classify(self, output: str) -> str:
        """Use Claude to classify an ambiguous failure."""
        prompt_path = PROMPTS_DIR / "classify_failure.md"
        if not prompt_path.exists():
            return "agent_error"

        template = prompt_path.read_text()
        # Truncate output to avoid massive prompts
        truncated = output[-3000:] if len(output) > 3000 else output
        prompt = template.format(error_output=truncated)

        result = spawn_claude(
            self.claude_command,
            self.vw_path,
            prompt,
            timeout=60,
        )

        # Parse classification from response
        response = str(result).lower()
        if "framework_bug" in response:
            return "framework_bug"
        if "external" in response:
            return "external"
        return "agent_error"

    # -----------------------------------------------------------------------
    # Fix spawning
    # -----------------------------------------------------------------------

    def attempt_fix(
        self,
        result: SpawnResult,
        milestones: list[MilestoneResult],
        scenario_name: str,
    ) -> str:
        """Spawn a fix agent in the VW. Returns commit message or empty string."""
        # Record HEAD before fix
        pre_fix_head = self._get_head()

        # Build fix prompt
        prompt = self._build_fix_prompt(result, milestones, scenario_name)

        # Spawn fix agent in VW
        fix_result = spawn_claude(
            self.claude_command,
            self.vw_path,
            prompt,
            timeout=120,
        )

        # Zero-commit guard: check if fix agent actually committed
        post_fix_head = self._get_head()
        if pre_fix_head == post_fix_head:
            # Fix agent produced no commit — classify as agent_error
            return ""

        # Post-fix validation: run validate_framework.sh
        validate_result = subprocess.run(
            ["bash", "tests/validate_framework.sh"],
            capture_output=True, text=True,
            cwd=str(self.vw_path),
            timeout=120,
        )

        if validate_result.returncode != 0:
            # Validation failed — revert the fix
            subprocess.run(
                ["git", "revert", "--no-edit", "HEAD"],
                capture_output=True, text=True,
                cwd=str(self.vw_path),
            )
            return ""

        # Extract commit message
        commit_msg = subprocess.run(
            ["git", "log", "-1", "--format=%s"],
            capture_output=True, text=True,
            cwd=str(self.vw_path),
        ).stdout.strip()

        return commit_msg

    def _get_head(self) -> str:
        """Get current HEAD commit hash."""
        return subprocess.run(
            ["git", "rev-parse", "HEAD"],
            capture_output=True, text=True,
            cwd=str(self.vw_path),
        ).stdout.strip()

    def _build_fix_prompt(
        self,
        result: SpawnResult,
        milestones: list[MilestoneResult],
        scenario_name: str,
    ) -> str:
        """Build the fix agent prompt."""
        prompt_path = PROMPTS_DIR / "verify_fix.md"
        if not prompt_path.exists():
            return self._fallback_fix_prompt(result, milestones, scenario_name)

        template = prompt_path.read_text()

        # Build failure summary
        failed_milestones = [m for m in milestones if not m.passed]
        milestone_summary = "\n".join(
            f"- {m.name}: {m.detail}" for m in failed_milestones
        )

        # Truncate output
        error_output = str(result)
        if len(error_output) > 3000:
            error_output = error_output[-3000:]

        return template.format(
            scenario_name=scenario_name,
            error_output=error_output,
            milestone_summary=milestone_summary or "No milestone details",
        )

    def _fallback_fix_prompt(
        self,
        result: SpawnResult,
        milestones: list[MilestoneResult],
        scenario_name: str,
    ) -> str:
        """Fallback fix prompt when template is missing."""
        failed = [m for m in milestones if not m.passed]
        milestone_info = "\n".join(f"- {m.name}: {m.detail}" for m in failed)
        error_tail = str(result)[-2000:]

        return (
            f"A framework bug was detected during verification scenario '{scenario_name}'.\n\n"
            f"Failed milestones:\n{milestone_info}\n\n"
            f"Error output (last 2000 chars):\n{error_tail}\n\n"
            "Fix ONLY the specific bug in the .agentic/lib/ framework code. "
            "Do not refactor, add features, or modify unrelated code.\n"
            "Use `git add` + `git commit --no-verify -m 'fix(verify): <description>'` "
            "to commit your fix."
        )
