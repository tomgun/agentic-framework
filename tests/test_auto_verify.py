#!/usr/bin/env python3
"""
Tests for the autonomous verify mode (F-0161): test-fix loop.
"""
import sys
import tempfile
from pathlib import Path
from unittest.mock import patch, MagicMock

import pytest

sys.path.insert(0, str(Path(__file__).parent.parent / ".agentic" / "lib"))
sys.path.insert(0, str(Path(__file__).parent.parent / ".agentic" / "lib" / "auto"))

from auto.verify import (
    VerifyLoop,
    VerifyResult,
    IterationResult,
    TEST_RUNNER_PATTERNS,
    STACK_TEST_PATTERNS,
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
        # Copy paths.py for imports
        lib_src = Path(__file__).parent.parent / ".agentic" / "lib"
        for f in ["paths.py", "settings.py"]:
            src = lib_src / f
            if src.exists():
                (root / ".agentic" / "lib" / f).write_text(src.read_text())
        yield root


# ---------------------------------------------------------------------------
# Test command detection
# ---------------------------------------------------------------------------

class TestDetectTestCommand:
    def test_detects_from_stack_md(self, project_dir):
        (project_dir / "STACK.md").write_text(
            "## Testing\n- Test runner: python -m pytest -v\n"
        )
        loop = VerifyLoop(project_dir)
        assert loop.test_command == "python -m pytest -v"

    def test_detects_from_test_command_field(self, project_dir):
        (project_dir / "STACK.md").write_text(
            "## Testing\n- Test command: npm run test:ci\n"
        )
        loop = VerifyLoop(project_dir)
        assert loop.test_command == "npm run test:ci"

    def test_falls_back_to_file_detection_pytest(self, project_dir):
        (project_dir / "STACK.md").write_text("## Settings\n")
        (project_dir / "pytest.ini").write_text("[pytest]\n")
        loop = VerifyLoop(project_dir)
        assert loop.test_command == "python -m pytest"

    def test_falls_back_to_file_detection_npm(self, project_dir):
        (project_dir / "STACK.md").write_text("## Settings\n")
        (project_dir / "package.json").write_text("{}\n")
        loop = VerifyLoop(project_dir)
        assert loop.test_command == "npm test"

    def test_falls_back_to_cargo(self, project_dir):
        (project_dir / "STACK.md").write_text("## Settings\n")
        (project_dir / "Cargo.toml").write_text("[package]\n")
        loop = VerifyLoop(project_dir)
        assert loop.test_command == "cargo test"

    def test_falls_back_to_go(self, project_dir):
        (project_dir / "STACK.md").write_text("## Settings\n")
        (project_dir / "go.mod").write_text("module example.com/foo\n")
        loop = VerifyLoop(project_dir)
        assert loop.test_command == "go test ./..."

    def test_no_runner_detected(self, project_dir):
        (project_dir / "STACK.md").write_text("## Settings\n")
        loop = VerifyLoop(project_dir)
        assert "No test runner" in loop.test_command

    def test_explicit_test_command_overrides(self, project_dir):
        (project_dir / "STACK.md").write_text(
            "## Testing\n- Test runner: python -m pytest\n"
        )
        loop = VerifyLoop(project_dir, test_command="make test")
        assert loop.test_command == "make test"

    def test_ignores_html_comments_in_stack(self, project_dir):
        (project_dir / "STACK.md").write_text(
            "## Testing\n- Test runner: <!-- override here -->\n"
        )
        loop = VerifyLoop(project_dir)
        # Should fall through to file detection since comment stripped
        assert loop.test_command != "<!-- override here -->"


# ---------------------------------------------------------------------------
# Test output parsing
# ---------------------------------------------------------------------------

class TestParseTestOutput:
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

    def test_pytest_all_pass(self):
        output = "===== 42 passed in 3.21s ====="
        passed, failed, total = self.loop._parse_test_output(output, 0)
        assert passed == 42
        assert failed == 0
        assert total == 42

    def test_pytest_mixed(self):
        output = "===== 10 passed, 3 failed in 5.00s ====="
        passed, failed, total = self.loop._parse_test_output(output, 1)
        assert passed == 10
        assert failed == 3
        assert total == 13

    def test_jest_format(self):
        output = "Tests: 5 passed, 2 failed, 7 total"
        passed, failed, total = self.loop._parse_test_output(output, 1)
        assert passed == 5
        assert failed == 2
        assert total == 7

    def test_go_format(self):
        output = "ok  \texample.com/pkg1\t0.5s\nok  \texample.com/pkg2\t0.3s\nFAIL\texample.com/pkg3\t1.2s\n"
        passed, failed, total = self.loop._parse_test_output(output, 1)
        assert passed == 2
        assert failed == 1
        assert total == 3

    def test_cargo_format(self):
        output = "test result: ok. 15 passed; 0 failed; 0 ignored"
        passed, failed, total = self.loop._parse_test_output(output, 0)
        assert passed == 15
        assert failed == 0
        assert total == 15

    def test_generic_pass(self):
        output = "All good!"
        passed, failed, total = self.loop._parse_test_output(output, 0)
        assert passed == 1
        assert failed == 0

    def test_generic_fail(self):
        output = "Something broke"
        passed, failed, total = self.loop._parse_test_output(output, 1)
        assert failed == 1


# ---------------------------------------------------------------------------
# Test run loop
# ---------------------------------------------------------------------------

class TestVerifyLoop:
    @patch("auto.verify.VerifyLoop._run_tests")
    def test_all_pass_first_iteration(self, mock_tests, project_dir):
        (project_dir / "STACK.md").write_text("## Settings\n")
        mock_tests.return_value = ("5 passed in 1.00s", 0)
        loop = VerifyLoop(project_dir, test_command="echo ok")
        result = loop.run(max_iterations=3)
        assert result.success is True
        assert result.iterations_used == 1
        assert result.final_tests_passed == 5

    @patch("auto.verify.VerifyLoop._spawn_claude_fix")
    @patch("auto.verify.VerifyLoop._run_tests")
    def test_fix_on_second_iteration(self, mock_tests, mock_fix, project_dir):
        (project_dir / "STACK.md").write_text("## Settings\n")
        mock_tests.side_effect = [
            ("2 passed, 1 failed", 1),  # First run: failure
            ("3 passed in 1.00s", 0),   # Second run: pass
        ]
        mock_fix.return_value = "Fixed the bug"
        loop = VerifyLoop(project_dir, test_command="echo ok")
        result = loop.run(max_iterations=3)
        assert result.success is True
        assert result.iterations_used == 2
        assert len(result.iterations) == 2
        assert result.iterations[0].tests_failed == 1
        assert result.iterations[0].fix_applied is True

    @patch("auto.verify.VerifyLoop._spawn_claude_fix")
    @patch("auto.verify.VerifyLoop._run_tests")
    def test_max_iterations_exhausted(self, mock_tests, mock_fix, project_dir):
        (project_dir / "STACK.md").write_text("## Settings\n")
        mock_tests.return_value = ("1 passed, 2 failed", 1)
        mock_fix.return_value = "Tried to fix"
        loop = VerifyLoop(project_dir, test_command="echo ok")
        result = loop.run(max_iterations=2)
        assert result.success is False
        assert result.iterations_used == 2
        assert result.final_tests_failed == 2

    @patch("auto.verify.VerifyLoop._run_tests")
    def test_callback_called(self, mock_tests, project_dir):
        (project_dir / "STACK.md").write_text("## Settings\n")
        mock_tests.return_value = ("1 passed", 0)
        callbacks = []
        loop = VerifyLoop(
            project_dir,
            test_command="echo ok",
            on_iteration=lambda it: callbacks.append(it),
        )
        loop.run(max_iterations=1)
        assert len(callbacks) == 1
        assert callbacks[0].iteration == 1

    def test_timeout_handling(self, project_dir):
        (project_dir / "STACK.md").write_text("## Settings\n")
        loop = VerifyLoop(project_dir, test_command="sleep 10")
        output, code = loop._run_tests(timeout=1)
        assert "timed out" in output
        assert code == 124


# ---------------------------------------------------------------------------
# VerifyResult serialization
# ---------------------------------------------------------------------------

class TestVerifyResult:
    def test_to_dict(self):
        result = VerifyResult(
            success=True,
            iterations_used=2,
            max_iterations=10,
            test_command="pytest",
            final_tests_passed=5,
            final_tests_failed=0,
        )
        result.iterations.append(
            IterationResult(iteration=1, tests_run=5, tests_passed=3, tests_failed=2)
        )
        d = result.to_dict()
        assert d["success"] is True
        assert d["iterations_used"] == 2
        assert len(d["iterations"]) == 1
        assert d["iterations"][0]["tests_failed"] == 2

    def test_to_dict_empty(self):
        result = VerifyResult(
            success=False, iterations_used=0, max_iterations=5,
            test_command="echo test",
        )
        d = result.to_dict()
        assert d["iterations"] == []
        assert d["final_tests_passed"] == 0
