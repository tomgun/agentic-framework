#!/usr/bin/env python3
"""
Tests for the tiered verify loop (F-0164): multi-tier test execution.
"""
import sys
import tempfile
from pathlib import Path
from unittest.mock import patch

import pytest

sys.path.insert(0, str(Path(__file__).parent.parent / ".agentic" / "lib"))
sys.path.insert(0, str(Path(__file__).parent.parent / ".agentic" / "lib" / "auto"))

from auto.verify import (
    VerifyLoop,
    VerifyResult,
    IterationResult,
    TestTier,
    TierResult,
)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def project_dir():
    """Minimal project directory with STACK.md."""
    with tempfile.TemporaryDirectory() as tmpdir:
        root = Path(tmpdir)
        (root / ".agentic" / "lib").mkdir(parents=True)
        (root / ".agentic" / "session").mkdir(parents=True)
        lib_src = Path(__file__).parent.parent / ".agentic" / "lib"
        for f in ["paths.py", "settings.py"]:
            src = lib_src / f
            if src.exists():
                (root / ".agentic" / "lib" / f).write_text(src.read_text())
        yield root


# ---------------------------------------------------------------------------
# TestTier dataclass
# ---------------------------------------------------------------------------

class TestTestTierDataclass:
    def test_defaults(self):
        tier = TestTier(name="unit", command="pytest")
        assert tier.timeout == 120
        assert tier.max_fix_iterations == 5
        assert tier.continue_on_failure is False

    def test_custom_values(self):
        tier = TestTier(
            name="e2e",
            command="npx playwright test",
            timeout=300,
            max_fix_iterations=3,
            continue_on_failure=True,
        )
        assert tier.name == "e2e"
        assert tier.timeout == 300
        assert tier.continue_on_failure is True


# ---------------------------------------------------------------------------
# Multi-tier detection from STACK.md
# ---------------------------------------------------------------------------

class TestDetectTestTiers:
    def test_parses_multi_tier_format(self, project_dir):
        (project_dir / "STACK.md").write_text(
            "## Testing\n"
            "- Test commands:\n"
            "  - Unit: `npm run test`\n"
            "  - E2E API: `pytest tests/e2e/api/`\n"
            "  - E2E UI: `npx playwright test`\n"
        )
        loop = VerifyLoop(project_dir)
        assert len(loop.tiers) == 3
        assert loop.tiers[0].name == "Unit"
        assert loop.tiers[0].command == "npm run test"
        assert loop.tiers[1].name == "E2E API"
        assert loop.tiers[1].command == "pytest tests/e2e/api/"
        assert loop.tiers[2].name == "E2E UI"
        assert loop.tiers[2].command == "npx playwright test"

    def test_e2e_tiers_get_longer_timeout(self, project_dir):
        (project_dir / "STACK.md").write_text(
            "## Testing\n"
            "- Test commands:\n"
            "  - Unit: `pytest`\n"
            "  - E2E: `npx playwright test`\n"
        )
        loop = VerifyLoop(project_dir)
        assert loop.tiers[0].timeout == 120  # unit default
        assert loop.tiers[1].timeout == 300  # e2e gets longer

    def test_skips_placeholder_commands(self, project_dir):
        (project_dir / "STACK.md").write_text(
            "## Testing\n"
            "- Test commands:\n"
            "  - Unit: `npm run test`\n"
            "  - Integration: `<!-- fill or N/A -->`\n"
            "  - E2E: `N/A`\n"
        )
        loop = VerifyLoop(project_dir)
        assert len(loop.tiers) == 1
        assert loop.tiers[0].name == "Unit"

    def test_commands_without_backticks(self, project_dir):
        (project_dir / "STACK.md").write_text(
            "## Testing\n"
            "- Test commands:\n"
            "  - Unit: npm run test\n"
        )
        loop = VerifyLoop(project_dir)
        assert len(loop.tiers) == 1
        assert loop.tiers[0].command == "npm run test"

    def test_backward_compat_old_format(self, project_dir):
        (project_dir / "STACK.md").write_text(
            "## Testing\n- Test runner: python -m pytest -v\n"
        )
        loop = VerifyLoop(project_dir)
        assert len(loop.tiers) == 1
        assert loop.tiers[0].name == "unit"
        assert loop.tiers[0].command == "python -m pytest -v"

    def test_backward_compat_test_command_field(self, project_dir):
        (project_dir / "STACK.md").write_text(
            "## Testing\n- Test command: npm run test:ci\n"
        )
        loop = VerifyLoop(project_dir)
        assert len(loop.tiers) == 1
        assert loop.tiers[0].command == "npm run test:ci"

    def test_backward_compat_file_detection(self, project_dir):
        (project_dir / "STACK.md").write_text("## Settings\n")
        (project_dir / "pytest.ini").write_text("[pytest]\n")
        loop = VerifyLoop(project_dir)
        assert len(loop.tiers) == 1
        assert loop.tiers[0].command == "python -m pytest"

    def test_explicit_test_command_creates_single_tier(self, project_dir):
        (project_dir / "STACK.md").write_text(
            "## Testing\n"
            "- Test commands:\n"
            "  - Unit: `npm test`\n"
            "  - E2E: `npx playwright test`\n"
        )
        loop = VerifyLoop(project_dir, test_command="make test")
        assert len(loop.tiers) == 1
        assert loop.tiers[0].name == "default"
        assert loop.tiers[0].command == "make test"
        assert loop.test_command == "make test"

    def test_test_command_backward_compat_property(self, project_dir):
        (project_dir / "STACK.md").write_text(
            "## Testing\n"
            "- Test commands:\n"
            "  - Unit: `npm test`\n"
            "  - E2E: `npx playwright test`\n"
        )
        loop = VerifyLoop(project_dir)
        # test_command should be the first tier's command
        assert loop.test_command == "npm test"

    def test_stops_parsing_at_next_section(self, project_dir):
        (project_dir / "STACK.md").write_text(
            "## Testing\n"
            "- Test commands:\n"
            "  - Unit: `pytest`\n"
            "## Development approach\n"
            "- development_mode: standard\n"
        )
        loop = VerifyLoop(project_dir)
        assert len(loop.tiers) == 1
        assert loop.tiers[0].command == "pytest"


# ---------------------------------------------------------------------------
# Tier filtering
# ---------------------------------------------------------------------------

class TestTierFiltering:
    def test_filter_by_prefix(self, project_dir):
        (project_dir / "STACK.md").write_text(
            "## Testing\n"
            "- Test commands:\n"
            "  - Unit: `pytest`\n"
            "  - E2E API: `pytest tests/e2e/api/`\n"
            "  - E2E UI: `npx playwright test`\n"
        )
        loop = VerifyLoop(project_dir)
        matched = loop._filter_tiers("e2e")
        assert len(matched) == 2
        assert matched[0].name == "E2E API"
        assert matched[1].name == "E2E UI"

    def test_filter_by_exact_name(self, project_dir):
        (project_dir / "STACK.md").write_text(
            "## Testing\n"
            "- Test commands:\n"
            "  - Unit: `pytest`\n"
            "  - E2E: `npx playwright test`\n"
        )
        loop = VerifyLoop(project_dir)
        matched = loop._filter_tiers("unit")
        assert len(matched) == 1
        assert matched[0].name == "Unit"

    def test_filter_no_match_falls_back_to_all(self, project_dir):
        (project_dir / "STACK.md").write_text(
            "## Testing\n"
            "- Test commands:\n"
            "  - Unit: `pytest`\n"
        )
        loop = VerifyLoop(project_dir)
        matched = loop._filter_tiers("nonexistent")
        assert len(matched) == 1  # falls back to all


# ---------------------------------------------------------------------------
# Tiered execution
# ---------------------------------------------------------------------------

class TestTieredExecution:
    @patch("auto.verify.VerifyLoop._run_tests")
    def test_runs_tiers_in_order(self, mock_tests, project_dir):
        (project_dir / "STACK.md").write_text(
            "## Testing\n"
            "- Test commands:\n"
            "  - Unit: `pytest`\n"
            "  - E2E: `npx playwright test`\n"
        )
        # Both tiers pass immediately
        mock_tests.side_effect = [
            ("5 passed in 1.0s", 0),   # unit
            ("3 passed", 0),           # e2e
        ]
        loop = VerifyLoop(project_dir)
        result = loop.run(max_iterations=3)

        assert result.success is True
        assert len(result.tier_results) == 2
        assert result.tier_results[0].tier_name == "Unit"
        assert result.tier_results[0].success is True
        assert result.tier_results[1].tier_name == "E2E"
        assert result.tier_results[1].success is True

    @patch("auto.verify.VerifyLoop._run_tests")
    def test_fast_fail_stops_at_failing_tier(self, mock_tests, project_dir):
        (project_dir / "STACK.md").write_text(
            "## Testing\n"
            "- Test commands:\n"
            "  - Unit: `pytest`\n"
            "  - E2E: `npx playwright test`\n"
        )
        # Unit fails all iterations, e2e should NOT run
        mock_tests.return_value = ("1 passed, 2 failed", 1)
        loop = VerifyLoop(project_dir)

        with patch.object(loop, "_spawn_claude_fix", return_value="tried fix"):
            result = loop.run(max_iterations=2)

        assert result.success is False
        assert len(result.tier_results) == 1  # only unit ran
        assert result.tier_results[0].tier_name == "Unit"
        assert result.tier_results[0].success is False

    @patch("auto.verify.VerifyLoop._run_tests")
    def test_continue_on_failure(self, mock_tests, project_dir):
        (project_dir / "STACK.md").write_text(
            "## Testing\n"
            "- Test commands:\n"
            "  - Unit: `pytest`\n"
            "  - E2E: `npx playwright test`\n"
        )
        # Unit fails, e2e passes
        mock_tests.side_effect = [
            ("1 passed, 2 failed", 1),  # unit iter 1
            ("1 passed, 2 failed", 1),  # unit iter 2 (max)
            ("1 passed, 2 failed", 1),  # unit final check
            ("3 passed", 0),            # e2e passes
        ]
        loop = VerifyLoop(project_dir)
        # Set continue_on_failure on first tier
        loop.tiers[0].continue_on_failure = True

        with patch.object(loop, "_spawn_claude_fix", return_value="tried fix"):
            result = loop.run(max_iterations=2)

        assert result.success is False  # overall fails because unit failed
        assert len(result.tier_results) == 2  # both ran
        assert result.tier_results[0].success is False
        assert result.tier_results[1].success is True

    @patch("auto.verify.VerifyLoop._run_tests")
    def test_tier_fix_loop(self, mock_tests, project_dir):
        (project_dir / "STACK.md").write_text(
            "## Testing\n"
            "- Test commands:\n"
            "  - Unit: `pytest`\n"
            "  - E2E: `npx playwright test`\n"
        )
        # Unit fails first, passes on second. E2E passes.
        mock_tests.side_effect = [
            ("2 passed, 1 failed", 1),  # unit iter 1
            ("3 passed", 0),            # unit iter 2 (fixed!)
            ("5 passed", 0),            # e2e passes
        ]
        loop = VerifyLoop(project_dir)

        with patch.object(loop, "_spawn_claude_fix", return_value="Fixed"):
            result = loop.run(max_iterations=3)

        assert result.success is True
        assert result.tier_results[0].iterations_used == 2
        assert result.tier_results[1].iterations_used == 1

    @patch("auto.verify.VerifyLoop._run_tests")
    def test_tier_filter_runs_subset(self, mock_tests, project_dir):
        (project_dir / "STACK.md").write_text(
            "## Testing\n"
            "- Test commands:\n"
            "  - Unit: `pytest`\n"
            "  - E2E API: `pytest tests/e2e/api/`\n"
            "  - E2E UI: `npx playwright test`\n"
        )
        mock_tests.side_effect = [
            ("3 passed", 0),  # E2E API
            ("5 passed", 0),  # E2E UI
        ]
        loop = VerifyLoop(project_dir)
        result = loop.run(max_iterations=3, tier_filter="e2e")

        assert result.success is True
        assert len(result.tier_results) == 2
        assert result.tier_results[0].tier_name == "E2E API"
        assert result.tier_results[1].tier_name == "E2E UI"


# ---------------------------------------------------------------------------
# Single-tier backward compat
# ---------------------------------------------------------------------------

class TestSingleTierCompat:
    @patch("auto.verify.VerifyLoop._run_tests")
    def test_single_tier_preserves_old_behavior(self, mock_tests, project_dir):
        """When only one tier is detected, behavior matches original exactly."""
        (project_dir / "STACK.md").write_text("## Settings\n")
        mock_tests.return_value = ("5 passed in 1.00s", 0)
        loop = VerifyLoop(project_dir, test_command="echo ok")
        result = loop.run(max_iterations=3)

        assert result.success is True
        assert result.iterations_used == 1
        assert result.final_tests_passed == 5
        assert result.test_command == "echo ok"
        # No tier_results in single-tier compat mode
        assert result.tier_results == []

    @patch("auto.verify.VerifyLoop._spawn_claude_fix")
    @patch("auto.verify.VerifyLoop._run_tests")
    def test_single_tier_fix_loop(self, mock_tests, mock_fix, project_dir):
        (project_dir / "STACK.md").write_text("## Settings\n")
        mock_tests.side_effect = [
            ("2 passed, 1 failed", 1),
            ("3 passed in 1.00s", 0),
        ]
        mock_fix.return_value = "Fixed the bug"
        loop = VerifyLoop(project_dir, test_command="echo ok")
        result = loop.run(max_iterations=3)

        assert result.success is True
        assert result.iterations_used == 2
        assert len(result.iterations) == 2

    @patch("auto.verify.VerifyLoop._spawn_claude_fix")
    @patch("auto.verify.VerifyLoop._run_tests")
    def test_single_tier_max_exhausted(self, mock_tests, mock_fix, project_dir):
        (project_dir / "STACK.md").write_text("## Settings\n")
        mock_tests.return_value = ("1 passed, 2 failed", 1)
        mock_fix.return_value = "Tried to fix"
        loop = VerifyLoop(project_dir, test_command="echo ok")
        result = loop.run(max_iterations=2)

        assert result.success is False
        assert result.iterations_used == 2
        assert result.final_tests_failed == 2


# ---------------------------------------------------------------------------
# Playwright / Cypress output parsing
# ---------------------------------------------------------------------------

class TestNewParsers:
    def setup_method(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            (root / ".agentic" / "lib").mkdir(parents=True)
            lib_src = Path(__file__).parent.parent / ".agentic" / "lib"
            for f in ["paths.py", "settings.py"]:
                src = lib_src / f
                if src.exists():
                    (root / ".agentic" / "lib" / f).write_text(src.read_text())
            (root / "STACK.md").write_text("## Settings\n")
            self.loop = VerifyLoop(root, test_command="echo test")

    def test_playwright_pass(self):
        output = "Running 10 tests using 4 workers\n  10 passed (5.2s)\nplaywright done"
        p, f, t = self.loop._parse_test_output(output, 0)
        assert p == 10
        assert f == 0
        assert t == 10

    def test_playwright_mixed(self):
        output = "Running 10 tests\n  7 passed\n  3 failed\nplaywright done"
        p, f, t = self.loop._parse_test_output(output, 1)
        assert p == 7
        assert f == 3
        assert t == 10

    def test_cypress_pass(self):
        output = "  (Results)\n\n  Tests:    8\n  Passing:  8\n  Failing:  0\n  Duration: 12s"
        p, f, t = self.loop._parse_test_output(output, 0)
        assert p == 8
        assert f == 0
        assert t == 8

    def test_cypress_mixed(self):
        output = "  Tests:    10\n  Passing:  7\n  Failing:  3\n  Duration: 15s"
        p, f, t = self.loop._parse_test_output(output, 1)
        assert p == 7
        assert f == 3
        assert t == 10


# ---------------------------------------------------------------------------
# Tier-specific fix prompts
# ---------------------------------------------------------------------------

class TestFixPrompts:
    def setup_method(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            (root / ".agentic" / "lib").mkdir(parents=True)
            lib_src = Path(__file__).parent.parent / ".agentic" / "lib"
            for f in ["paths.py", "settings.py"]:
                src = lib_src / f
                if src.exists():
                    (root / ".agentic" / "lib" / f).write_text(src.read_text())
            (root / "STACK.md").write_text("## Settings\n")
            self.loop = VerifyLoop(root, test_command="echo test")

    def test_unit_prompt(self):
        prompt = self.loop._build_fix_prompt("test failed", 1, "Unit")
        assert "Do NOT modify the tests" in prompt
        assert "Unit tests" in prompt

    def test_e2e_prompt(self):
        prompt = self.loop._build_fix_prompt("test failed", 1, "E2E UI")
        assert "real user behavior" in prompt
        assert "Do NOT modify the tests" in prompt

    def test_e2e_prompt_larger_context(self):
        # E2E prompts should allow 8000 chars of test output
        long_output = "x" * 10000
        prompt = self.loop._build_fix_prompt(long_output, 1, "E2E")
        # The output in the prompt should be truncated to ~8000
        assert "truncated" in prompt

    def test_unit_prompt_smaller_context(self):
        long_output = "x" * 6000
        prompt = self.loop._build_fix_prompt(long_output, 1, "Unit")
        # The output in the prompt should be truncated to ~4000
        assert "truncated" in prompt

    def test_default_prompt(self):
        prompt = self.loop._build_fix_prompt("test failed", 1, "custom-tier")
        assert "test suite has 1 failure" in prompt


# ---------------------------------------------------------------------------
# TierResult and VerifyResult serialization
# ---------------------------------------------------------------------------

class TestResultSerialization:
    def test_tier_result_to_dict(self):
        tr = TierResult(
            tier_name="Unit",
            success=True,
            iterations_used=1,
            tests_passed=5,
            tests_failed=0,
        )
        d = tr.to_dict()
        assert d["tier_name"] == "Unit"
        assert d["success"] is True

    def test_verify_result_with_tiers(self):
        result = VerifyResult(
            success=True,
            iterations_used=3,
            max_iterations=10,
            test_command="pytest",
            final_tests_passed=8,
            final_tests_failed=0,
        )
        result.tier_results = [
            TierResult(tier_name="Unit", success=True, iterations_used=1, tests_passed=5),
            TierResult(tier_name="E2E", success=True, iterations_used=2, tests_passed=3),
        ]
        d = result.to_dict()
        assert len(d["tier_results"]) == 2
        assert d["tier_results"][0]["tier_name"] == "Unit"
        assert d["tier_results"][1]["tier_name"] == "E2E"

    def test_verify_result_without_tiers(self):
        result = VerifyResult(
            success=True,
            iterations_used=1,
            max_iterations=5,
            test_command="echo test",
        )
        d = result.to_dict()
        assert "tier_results" not in d  # omitted when empty


# ---------------------------------------------------------------------------
# Placeholder detection
# ---------------------------------------------------------------------------

class TestPlaceholderDetection:
    def test_html_comment(self):
        assert VerifyLoop._is_placeholder("<!-- fill -->") is True

    def test_na(self):
        assert VerifyLoop._is_placeholder("N/A") is True
        assert VerifyLoop._is_placeholder("n/a") is True

    def test_fill_with_arrow(self):
        assert VerifyLoop._is_placeholder("<!-- fill or N/A -->") is True

    def test_valid_command(self):
        assert VerifyLoop._is_placeholder("npm run test") is False

    def test_empty(self):
        assert VerifyLoop._is_placeholder("") is True
        assert VerifyLoop._is_placeholder("  ") is True
