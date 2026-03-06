#!/usr/bin/env python3
"""
Tests for the autonomous task mode (F-0162): single-feature implementation.
"""
import json
import sys
import tempfile
from pathlib import Path
from unittest.mock import patch, MagicMock

import pytest

sys.path.insert(0, str(Path(__file__).parent.parent / ".agentic" / "lib"))
sys.path.insert(0, str(Path(__file__).parent.parent / ".agentic" / "lib" / "auto"))

from auto.task import TaskRunner, TaskResult, ACResult
from auto.engine import EngineState


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def project_dir():
    """Project dir with ACs for F-0042."""
    with tempfile.TemporaryDirectory() as tmpdir:
        root = Path(tmpdir)
        (root / ".agentic" / "lib").mkdir(parents=True)
        (root / ".agentic" / "session").mkdir(parents=True)
        (root / ".agentic" / "spec" / "acceptance").mkdir(parents=True)
        lib_src = Path(__file__).parent.parent / ".agentic" / "lib"
        for f in ["paths.py", "settings.py"]:
            src = lib_src / f
            if src.exists():
                (root / ".agentic" / "lib" / f).write_text(src.read_text())
        (root / "STACK.md").write_text(
            "## Settings\n- profile: formal\n\n"
            "## Languages & runtimes\n- Language(s): Python\n"
        )
        (root / ".agentic" / "spec" / "acceptance" / "F-0042.md").write_text(
            "# F-0042: Auth\n\n"
            "## Acceptance Criteria\n"
            "- [ ] AC-001: Given valid creds, return JWT\n"
            "- [ ] AC-002: Given invalid creds, return 401\n"
        )
        # Init git repo for branch operations
        import subprocess
        subprocess.run(["git", "init"], cwd=str(root), capture_output=True)
        subprocess.run(
            ["git", "commit", "--allow-empty", "-m", "init"],
            cwd=str(root), capture_output=True,
        )
        yield root


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

class TestTaskRunner:
    def test_loads_acs_for_feature(self, project_dir):
        runner = TaskRunner(project_dir)
        criteria = runner.engine._load_acceptance_criteria("F-0042")
        assert len(criteria) == 2
        assert criteria[0][0] == "AC-001"

    def test_missing_feature_returns_empty(self, project_dir):
        runner = TaskRunner(project_dir)
        result = runner.run("F-9999", skip_branch=True, skip_pr=True)
        assert result.acs_total == 0
        assert result.success is False

    @patch("auto.task.TaskRunner._run_tests")
    @patch("auto.task.TaskRunner._spawn_claude_implement")
    @patch("auto.task.TaskRunner._commit_ac")
    @patch("auto.verify.VerifyLoop.run")
    def test_all_acs_pass(
        self, mock_verify, mock_commit, mock_impl, mock_tests, project_dir
    ):
        mock_impl.return_value = "Implemented successfully"
        mock_tests.return_value = True
        mock_commit.return_value = True
        mock_verify.return_value = MagicMock(success=True)

        runner = TaskRunner(project_dir)
        result = runner.run("F-0042", skip_branch=True, skip_pr=True)
        assert result.acs_passed == 2
        assert result.acs_failed == 0
        assert result.success is True

    @patch("auto.task.TaskRunner._run_tests")
    @patch("auto.task.TaskRunner._spawn_claude_implement")
    @patch("auto.task.TaskRunner._commit_ac")
    @patch("auto.verify.VerifyLoop.run")
    def test_one_ac_fails(
        self, mock_verify, mock_commit, mock_impl, mock_tests, project_dir
    ):
        mock_impl.return_value = "Implemented"
        mock_tests.side_effect = [True, False, False, False]  # AC-001 pass, AC-002 fail x3
        mock_commit.return_value = True
        mock_verify.return_value = MagicMock(success=False)

        runner = TaskRunner(project_dir)
        result = runner.run("F-0042", skip_branch=True, skip_pr=True)
        assert result.acs_passed == 1
        assert result.acs_failed == 1
        assert result.success is False

    @patch("auto.task.TaskRunner._run_tests")
    @patch("auto.task.TaskRunner._spawn_claude_implement")
    @patch("auto.verify.VerifyLoop.run")
    def test_callback_called_per_ac(
        self, mock_verify, mock_impl, mock_tests, project_dir
    ):
        mock_impl.return_value = "Implemented"
        mock_tests.return_value = True
        mock_verify.return_value = MagicMock(success=True)

        callbacks = []
        runner = TaskRunner(
            project_dir, on_ac_done=lambda ac: callbacks.append(ac)
        )
        runner.run("F-0042", skip_branch=True, skip_pr=True)
        assert len(callbacks) == 2
        assert callbacks[0].ac_id == "AC-001"

    @patch("auto.task.TaskRunner._run_tests")
    @patch("auto.task.TaskRunner._spawn_claude_implement")
    @patch("auto.verify.VerifyLoop.run")
    def test_feedback_incorporated(
        self, mock_verify, mock_impl, mock_tests, project_dir
    ):
        mock_impl.return_value = "Implemented"
        mock_tests.return_value = True
        mock_verify.return_value = MagicMock(success=True)

        runner = TaskRunner(project_dir)
        runner.engine.engine_state.add_feedback("AC-001", "use existing auth module")
        result = runner.run("F-0042", skip_branch=True, skip_pr=True)
        # Feedback was consumed (no error)
        assert result.acs_passed == 2

    def test_branch_creation(self, project_dir):
        runner = TaskRunner(project_dir)
        branch = runner._create_branch("F-0042")
        assert branch == "feat/auto-f-0042"
        import subprocess
        result = subprocess.run(
            ["git", "branch", "--show-current"],
            cwd=str(project_dir), capture_output=True, text=True,
        )
        assert "feat/auto-f-0042" in result.stdout


class TestTaskResult:
    def test_to_dict(self):
        result = TaskResult(
            feature_id="F-0042",
            success=True,
            acs_total=2,
            acs_passed=2,
        )
        result.ac_results.append(
            ACResult(ac_id="AC-001", ac_text="test", status="passed",
                     test_passed=True, committed=True, duration_seconds=5.123)
        )
        d = result.to_dict()
        assert d["feature_id"] == "F-0042"
        assert d["success"] is True
        assert len(d["ac_results"]) == 1
        assert d["ac_results"][0]["duration_seconds"] == 5.1
