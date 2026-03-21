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


# ---------------------------------------------------------------------------
# F-0203: review_commit conditional commit tests
# ---------------------------------------------------------------------------

class TestCommitAcReviewCommit:
    """Tests for _commit_ac() with review_commit setting (F-0203)."""

    @patch("auto.task.get_setting")
    def test_human_mode_stages_only(self, mock_setting, project_dir):
        """review_commit: human — stages files but does NOT commit."""
        mock_setting.side_effect = lambda root, key, default="": {
            "git_mode": "active", "review_commit": "human",
        }.get(key, default)
        import subprocess
        # Create a file to stage
        (project_dir / "test.py").write_text("print('hello')")
        runner = TaskRunner(project_dir)
        result = runner._commit_ac("F-0042", "AC-001", "test criterion")
        assert result is False
        # Verify file was staged
        status = subprocess.run(
            ["git", "status", "--porcelain"],
            cwd=str(project_dir), capture_output=True, text=True,
        )
        assert "test.py" in status.stdout

    @patch("auto.task.get_setting")
    @patch("auto.critical_agent.CriticalAgent.review_commit")
    def test_critical_agent_approved(self, mock_review, mock_setting, project_dir):
        """review_commit: critical_agent + approved — commits successfully."""
        mock_setting.side_effect = lambda root, key, default="": {
            "git_mode": "active", "review_commit": "critical_agent",
        }.get(key, default)
        mock_review.return_value = MagicMock(verdict="approved", summary="LGTM")
        # Create a file to commit
        (project_dir / "feature.py").write_text("# new feature")
        runner = TaskRunner(project_dir)
        result = runner._commit_ac("F-0042", "AC-001", "test criterion")
        assert result is True
        mock_review.assert_called_once_with("F-0042", "AC-001", "test criterion")

    @patch("auto.task.get_setting")
    @patch("auto.critical_agent.CriticalAgent.review_commit")
    def test_critical_agent_rejected(self, mock_review, mock_setting, project_dir):
        """review_commit: critical_agent + rejected — unstages, returns False."""
        mock_setting.side_effect = lambda root, key, default="": {
            "git_mode": "active", "review_commit": "critical_agent",
        }.get(key, default)
        mock_review.return_value = MagicMock(
            verdict="request_changes", summary="Issues found"
        )
        (project_dir / "bad.py").write_text("# bad code")
        runner = TaskRunner(project_dir)
        result = runner._commit_ac("F-0042", "AC-001", "test criterion")
        assert result is False

    @patch("auto.task.get_setting")
    @patch("auto.critical_agent.CriticalAgent.review_commit")
    def test_critical_agent_timeout(self, mock_review, mock_setting, project_dir):
        """review_commit: critical_agent + exception — unstages, returns False."""
        mock_setting.side_effect = lambda root, key, default="": {
            "git_mode": "active", "review_commit": "critical_agent",
        }.get(key, default)
        mock_review.side_effect = RuntimeError("Critical agent timed out")
        (project_dir / "timeout.py").write_text("# code")
        runner = TaskRunner(project_dir)
        result = runner._commit_ac("F-0042", "AC-001", "test criterion")
        assert result is False

    @patch("auto.task.get_setting")
    def test_staging_fails(self, mock_setting, project_dir):
        """Staging failure returns False without calling agent."""
        mock_setting.side_effect = lambda root, key, default="": {
            "git_mode": "active", "review_commit": "critical_agent",
        }.get(key, default)
        import subprocess
        runner = TaskRunner(project_dir)
        with patch("subprocess.run") as mock_run:
            mock_run.side_effect = subprocess.CalledProcessError(1, "git add")
            result = runner._commit_ac("F-0042", "AC-001", "test criterion")
            assert result is False

    @patch("auto.task.get_setting")
    def test_unrecognized_value_falls_back_to_human(self, mock_setting, project_dir):
        """Unrecognized values for review_commit fall back to human behavior."""
        mock_setting.side_effect = lambda root, key, default="": {
            "git_mode": "active", "review_commit": "invalid_value",
        }.get(key, default)
        (project_dir / "test2.py").write_text("print('test')")
        runner = TaskRunner(project_dir)
        result = runner._commit_ac("F-0042", "AC-001", "test criterion")
        assert result is False  # staged but not committed

    def test_unstage_or_warn_success(self, project_dir):
        """_unstage_or_warn succeeds silently."""
        runner = TaskRunner(project_dir)
        # Should not raise
        runner._unstage_or_warn()

    @patch("auto.task.TaskRunner._spawn_claude_implement")
    @patch("auto.task.get_setting")
    def test_check_docs_human_mode_stages_only(self, mock_setting, mock_spawn, project_dir):
        """_check_and_update_docs with review_commit: human stages but doesn't commit."""
        # docs_gate must be non-off to reach review_commit logic
        mock_setting.side_effect = lambda root, key, default="": {
            "git_mode": "active",
            "docs_gate": "blocking",
            "review_commit": "human",
        }.get(key, default)
        # drift.sh must exist and report drift (non-zero exit)
        drift_script = project_dir / ".agentic" / "lib" / "tools" / "drift.sh"
        drift_script.parent.mkdir(parents=True, exist_ok=True)
        drift_script.write_text("#!/bin/bash\necho 'drift detected'\nexit 1\n")
        drift_script.chmod(0o755)
        mock_spawn.return_value = "Updated docs"
        runner = TaskRunner(project_dir)
        runner._check_and_update_docs("F-0042")
        # Should have staged but NOT committed

    @patch("auto.task.TaskRunner._spawn_claude_implement")
    @patch("auto.critical_agent.CriticalAgent.review_commit")
    @patch("auto.task.get_setting")
    def test_check_docs_critical_agent_approved(self, mock_setting, mock_review, mock_spawn, project_dir):
        """_check_and_update_docs with critical_agent — commits on approval."""
        mock_setting.side_effect = lambda root, key, default="": {
            "git_mode": "active",
            "docs_gate": "blocking",
            "review_commit": "critical_agent",
        }.get(key, default)
        drift_script = project_dir / ".agentic" / "lib" / "tools" / "drift.sh"
        drift_script.parent.mkdir(parents=True, exist_ok=True)
        drift_script.write_text("#!/bin/bash\necho 'drift detected'\nexit 1\n")
        drift_script.chmod(0o755)
        mock_spawn.return_value = "Updated docs"
        mock_review.return_value = MagicMock(verdict="approved", summary="LGTM")
        # Create a tracked file change so git add -u has something
        (project_dir / "README.md").write_text("# Project")
        import subprocess
        subprocess.run(["git", "add", "README.md"], cwd=str(project_dir), capture_output=True)
        subprocess.run(["git", "commit", "-m", "add readme"], cwd=str(project_dir), capture_output=True)
        (project_dir / "README.md").write_text("# Updated Project")
        runner = TaskRunner(project_dir)
        runner._check_and_update_docs("F-0042")
        mock_review.assert_called_once()


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
