"""Tests for self_heal.py (F-0215)."""
from __future__ import annotations

import subprocess
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest
import sys

_LIB_DIR = Path(__file__).resolve().parent.parent / ".agentic" / "lib"
sys.path.insert(0, str(_LIB_DIR))
sys.path.insert(0, str(_LIB_DIR / "tools"))


# ---------------------------------------------------------------------------
# Failure classification tests
# ---------------------------------------------------------------------------

class TestFailureClassification:
    """Test the three-tier failure classification."""

    def test_timeout_is_agent_error(self):
        from auto import SpawnResult
        from auto.self_heal import SelfHealEngine
        engine = SelfHealEngine(Path("/tmp/fake-vw"))
        result = SpawnResult("error: timed out", returncode=-1, timed_out=True)
        assert engine.classify(result, []) == "agent_error"

    def test_framework_traceback_is_framework_bug(self):
        from auto import SpawnResult
        from auto.self_heal import SelfHealEngine
        engine = SelfHealEngine(Path("/tmp/fake-vw"))
        output = (
            "Running ag implement...\n"
            "Traceback (most recent call last):\n"
            "  File \".agentic/lib/auto/scheduler.py\", line 42\n"
            "    raise ValueError\n"
            "ValueError: bad config\n"
        )
        result = SpawnResult(output, returncode=1)
        assert engine.classify(result, []) == "framework_bug"

    def test_agentic_lib_error_is_framework_bug(self):
        from auto import SpawnResult
        from auto.self_heal import SelfHealEngine
        engine = SelfHealEngine(Path("/tmp/fake-vw"))
        output = ".agentic/lib/tools/wip.sh: line 45: Error: something broke"
        result = SpawnResult(output, returncode=1)
        assert engine.classify(result, []) == "framework_bug"

    def test_module_not_found_is_framework_bug(self):
        from auto import SpawnResult
        from auto.self_heal import SelfHealEngine
        engine = SelfHealEngine(Path("/tmp/fake-vw"))
        output = "ModuleNotFoundError: No module named 'auto.missing_module'"
        result = SpawnResult(output, returncode=1)
        assert engine.classify(result, []) == "framework_bug"

    def test_network_error_is_external(self):
        from auto import SpawnResult
        from auto.self_heal import SelfHealEngine
        engine = SelfHealEngine(Path("/tmp/fake-vw"))
        result = SpawnResult("error: claude command not found", returncode=-1)
        assert engine.classify(result, []) == "external"

    def test_rate_limit_is_external(self):
        from auto import SpawnResult
        from auto.self_heal import SelfHealEngine
        engine = SelfHealEngine(Path("/tmp/fake-vw"))
        result = SpawnResult("429 Too Many Requests", returncode=1)
        assert engine.classify(result, []) == "external"

    def test_ambiguous_defaults_to_agent_error(self):
        from auto import SpawnResult
        from auto.self_heal import SelfHealEngine
        engine = SelfHealEngine(Path("/tmp/fake-vw"))
        result = SpawnResult("something went wrong", returncode=1)
        assert engine.classify(result, []) == "agent_error"

    def test_success_output_defaults_to_agent_error(self):
        from auto import SpawnResult
        from auto.self_heal import SelfHealEngine
        engine = SelfHealEngine(Path("/tmp/fake-vw"))
        result = SpawnResult("all good", returncode=0)
        assert engine.classify(result, []) == "agent_error"

    def test_ag_sh_line_error_is_framework_bug(self):
        from auto import SpawnResult
        from auto.self_heal import SelfHealEngine
        engine = SelfHealEngine(Path("/tmp/fake-vw"))
        output = "ag.sh: line 234: unexpected error in ag done"
        result = SpawnResult(output, returncode=1)
        assert engine.classify(result, []) == "framework_bug"

    def test_file_not_found_in_agentic_is_framework_bug(self):
        from auto import SpawnResult
        from auto.self_heal import SelfHealEngine
        engine = SelfHealEngine(Path("/tmp/fake-vw"))
        output = "FileNotFoundError: .agentic/lib/tools/missing_script.sh"
        result = SpawnResult(output, returncode=1)
        assert engine.classify(result, []) == "framework_bug"


# ---------------------------------------------------------------------------
# Fix prompt tests
# ---------------------------------------------------------------------------

class TestFixPrompt:
    """Test fix prompt generation."""

    def test_fallback_prompt_includes_scenario(self):
        from auto import SpawnResult
        from auto.self_heal import SelfHealEngine
        from auto.framework_verify import MilestoneResult
        engine = SelfHealEngine(Path("/tmp/fake-vw"))
        result = SpawnResult("error output", returncode=1)
        milestones = [MilestoneResult("kickoff_complete", False, "FEATURES.md not found")]
        prompt = engine._fallback_fix_prompt(result, milestones, "Todo App")
        assert "Todo App" in prompt
        assert "FEATURES.md not found" in prompt
        assert "fix(verify)" in prompt

    def test_build_fix_prompt_uses_template_when_available(self):
        from auto import SpawnResult
        from auto.self_heal import SelfHealEngine
        from auto.framework_verify import MilestoneResult
        engine = SelfHealEngine(Path("/tmp/fake-vw"))
        result = SpawnResult("some error", returncode=1)
        milestones = [MilestoneResult("verification_green", False, "exit code 1")]
        prompt = engine._build_fix_prompt(result, milestones, "API Service")
        assert "API Service" in prompt


# ---------------------------------------------------------------------------
# Attempt fix tests (mocked)
# ---------------------------------------------------------------------------

class TestAttemptFix:
    """Test fix agent flow with mocked git/claude."""

    def test_zero_commit_returns_empty(self, tmp_path):
        """If fix agent produces no commit, attempt_fix returns ''."""
        from auto.self_heal import SelfHealEngine
        from auto import SpawnResult
        from auto.framework_verify import MilestoneResult

        # Create a git repo for the VW
        subprocess.run(["git", "init"], cwd=str(tmp_path), check=True,
                       capture_output=True, text=True)
        (tmp_path / "f.txt").write_text("x")
        subprocess.run(["git", "add", "."], cwd=str(tmp_path), check=True,
                       capture_output=True, text=True)
        subprocess.run(["git", "commit", "-m", "init"], cwd=str(tmp_path),
                       check=True, capture_output=True, text=True)

        engine = SelfHealEngine(tmp_path, claude_command="echo")

        # Mock spawn_claude to do nothing (no commit)
        with patch("auto.self_heal.spawn_claude") as mock_spawn:
            mock_spawn.return_value = SpawnResult("did nothing", returncode=0)
            result = SpawnResult("error", returncode=1)
            milestones = [MilestoneResult("verification_green", False, "exit 1")]
            fix = engine.attempt_fix(result, milestones, "test")
            assert fix == ""


# ---------------------------------------------------------------------------
# Pattern coverage
# ---------------------------------------------------------------------------

class TestPatternCoverage:
    """Verify classification patterns are comprehensive."""

    def test_all_framework_patterns_compile(self):
        import re
        from auto.self_heal import _FRAMEWORK_BUG_PATTERNS
        for pattern in _FRAMEWORK_BUG_PATTERNS:
            re.compile(pattern)

    def test_all_external_patterns_compile(self):
        import re
        from auto.self_heal import _EXTERNAL_PATTERNS
        for pattern in _EXTERNAL_PATTERNS:
            re.compile(pattern)
