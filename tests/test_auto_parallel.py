"""Tests for parallel epic execution (F-0214)."""
from __future__ import annotations

import os
import signal
import subprocess
import sys
import time
from pathlib import Path
from unittest.mock import MagicMock, patch, call

import pytest

# Add lib dirs to path
_LIB_DIR = Path(__file__).resolve().parent.parent / ".agentic" / "lib"
sys.path.insert(0, str(_LIB_DIR))
sys.path.insert(0, str(_LIB_DIR / "tools"))
sys.path.insert(0, str(_LIB_DIR / "auto"))

from auto.parallel import ParallelDispatcher, AgentProcess  # noqa: E402


@pytest.fixture
def mock_paths(tmp_path):
    """Create a minimal project structure for testing."""
    session_dir = tmp_path / ".agentic" / "session"
    session_dir.mkdir(parents=True)
    tools_dir = tmp_path / ".agentic" / "lib" / "tools"
    tools_dir.mkdir(parents=True)
    # Create stub worktree.sh
    (tools_dir / "worktree.sh").write_text("#!/bin/bash\necho /tmp/test-wt")
    (tools_dir / "agents_helpers.py").write_text("# stub")
    return tmp_path


@pytest.fixture
def mock_get_paths(mock_paths):
    """Patch get_paths to return mock paths."""
    paths = MagicMock()
    paths.session_dir = mock_paths / ".agentic" / "session"
    paths.tools_dir = mock_paths / ".agentic" / "lib" / "tools"
    with patch("auto.parallel.get_paths", return_value=paths):
        yield paths


class TestParallelDispatcherInit:
    """AC-005: max_parallel clamping and defaults."""

    def test_max_parallel_clamped_to_1_minimum(self, mock_get_paths):
        d = ParallelDispatcher(Path("/tmp/test"), max_parallel=0)
        assert d.max_parallel == 1

    def test_max_parallel_clamped_to_10_maximum(self, mock_get_paths):
        d = ParallelDispatcher(Path("/tmp/test"), max_parallel=20)
        assert d.max_parallel == 10

    def test_default_max_parallel_is_3(self, mock_get_paths):
        d = ParallelDispatcher(Path("/tmp/test"))
        assert d.max_parallel == 3

    def test_default_timeout_is_600(self, mock_get_paths):
        d = ParallelDispatcher(Path("/tmp/test"))
        assert d.timeout == 600


class TestParallelDispatcherRun:
    """AC-001, AC-002, AC-008, AC-010."""

    def test_empty_feature_list_returns_early(self, mock_get_paths):
        d = ParallelDispatcher(Path("/tmp/test"))
        result = d.run([])
        assert result.features_total == 0
        assert result.stopped_reason == "no features to schedule"

    @patch.object(ParallelDispatcher, "_spawn_feature")
    @patch.object(ParallelDispatcher, "_cleanup_all")
    def test_spawn_called_for_each_feature(self, mock_cleanup, mock_spawn,
                                           mock_get_paths):
        """AC-001: Spawns concurrent processes."""
        # Mock spawn to return None (failed) so we exit quickly
        mock_spawn.return_value = None
        d = ParallelDispatcher(Path("/tmp/test"), max_parallel=3)
        result = d.run(["F-0001", "F-0002", "F-0003"])

        assert mock_spawn.call_count == 3
        assert result.features_failed == 3

    @patch.object(ParallelDispatcher, "_spawn_feature")
    @patch.object(ParallelDispatcher, "_cleanup_all")
    def test_rolling_slots_with_max_parallel(self, mock_cleanup, mock_spawn,
                                             mock_get_paths):
        """AC-002: Rolling slot management respects max_parallel."""
        # First 2 calls return None (fill initial slots), rest also None
        mock_spawn.return_value = None
        d = ParallelDispatcher(Path("/tmp/test"), max_parallel=2)
        result = d.run(["F-0001", "F-0002", "F-0003"])

        # With max_parallel=2 and all spawns failing, should try all 3
        # (2 initial + 1 when slots are immediately freed due to failure)
        assert mock_spawn.call_count == 3

    @patch.object(ParallelDispatcher, "_spawn_feature")
    @patch.object(ParallelDispatcher, "_cleanup_all")
    def test_result_shape_matches_sequential(self, mock_cleanup, mock_spawn,
                                             mock_get_paths):
        """AC-008: SchedulerResult has same shape."""
        mock_spawn.return_value = None
        d = ParallelDispatcher(Path("/tmp/test"))
        result = d.run(["F-0001"])

        # Verify SchedulerResult fields exist
        assert hasattr(result, "success")
        assert hasattr(result, "features_total")
        assert hasattr(result, "features_completed")
        assert hasattr(result, "features_failed")
        assert hasattr(result, "features_review_blocked")
        assert hasattr(result, "features_skipped")
        assert hasattr(result, "feature_work")
        assert hasattr(result, "stopped_reason")

        # Verify to_dict() works
        d_dict = result.to_dict()
        assert "success" in d_dict
        assert "feature_work" in d_dict


class TestBuildPrompt:
    """AC-001: Prompt includes --skip-branch."""

    def test_prompt_includes_skip_branch(self, mock_get_paths):
        d = ParallelDispatcher(Path("/tmp/test"))
        prompt = d._build_prompt("F-0001")
        assert "--skip-branch" in prompt
        assert "F-0001" in prompt

    def test_prompt_includes_skip_pr_when_set(self, mock_get_paths):
        d = ParallelDispatcher(Path("/tmp/test"), skip_pr=True)
        prompt = d._build_prompt("F-0001")
        assert "--skip-pr" in prompt

    def test_prompt_no_skip_pr_by_default(self, mock_get_paths):
        d = ParallelDispatcher(Path("/tmp/test"))
        prompt = d._build_prompt("F-0001")
        assert "--skip-pr" not in prompt


class TestProcessManagement:
    """AC-004, AC-006: Termination and timeout."""

    def test_terminate_with_grace_period(self, mock_get_paths):
        """AC-006: Timeout terminates then kills."""
        mock_proc = MagicMock()
        mock_proc.wait.return_value = None
        agent = AgentProcess(
            feature_id="F-0001",
            worktree_path="/tmp/wt",
            branch_name="feature/F-0001",
            process=mock_proc,
            start_time=time.time(),
            log_path=Path("/tmp/log"),
        )
        d = ParallelDispatcher(Path("/tmp/test"))
        d._terminate_process(agent)
        mock_proc.terminate.assert_called_once()
        mock_proc.wait.assert_called_once_with(timeout=10)

    def test_kill_after_grace_period_timeout(self, mock_get_paths):
        """AC-006: Kill if terminate doesn't work within grace period."""
        mock_proc = MagicMock()
        mock_proc.wait.side_effect = [
            subprocess.TimeoutExpired("cmd", 10),  # first wait (terminate)
            None,  # second wait (kill)
        ]
        agent = AgentProcess(
            feature_id="F-0001",
            worktree_path="/tmp/wt",
            branch_name="feature/F-0001",
            process=mock_proc,
            start_time=time.time(),
            log_path=Path("/tmp/log"),
        )
        d = ParallelDispatcher(Path("/tmp/test"))
        d._terminate_process(agent)
        mock_proc.terminate.assert_called_once()
        mock_proc.kill.assert_called_once()

    def test_signal_handler_sets_stop_flag(self, mock_get_paths):
        """AC-004: Ctrl+C sets stop flag."""
        d = ParallelDispatcher(Path("/tmp/test"))
        assert d._stop_flag is False
        d._signal_handler(signal.SIGINT, None)
        assert d._stop_flag is True


class TestSchedulerParallelFlag:
    """AC-010: Sequential path unchanged when --parallel not set."""

    def test_scheduler_defaults_to_sequential(self):
        """AC-010: Without --parallel, parallel=False."""
        from auto.scheduler import AutonomousScheduler
        s = AutonomousScheduler(project_root=Path("/tmp/test"))
        assert s.parallel is False

    def test_scheduler_parallel_flag_propagates(self):
        """F-0214: --parallel flag stored on scheduler."""
        from auto.scheduler import AutonomousScheduler
        s = AutonomousScheduler(
            project_root=Path("/tmp/test"),
            parallel=True,
            max_parallel=5,
            timeout=900,
        )
        assert s.parallel is True
        assert s.max_parallel == 5
        assert s.timeout == 900

    @patch("auto.parallel.ParallelDispatcher")
    def test_run_delegates_to_parallel_dispatcher(self, MockDispatcher):
        """F-0214: run() delegates when parallel=True."""
        from auto.scheduler import AutonomousScheduler, SchedulerResult
        mock_result = SchedulerResult(success=True)
        MockDispatcher.return_value.run.return_value = mock_result

        s = AutonomousScheduler(
            project_root=Path("/tmp/test"),
            parallel=True,
            max_parallel=5,
            timeout=900,
        )
        result = s.run(["F-0001", "F-0002"])

        MockDispatcher.assert_called_once()
        MockDispatcher.return_value.run.assert_called_once_with(
            ["F-0001", "F-0002"],
        )
        assert result.success is True


class TestCloseLog:
    """Verify log file handles are properly closed."""

    def test_close_log_closes_file_handle(self, mock_get_paths):
        mock_file = MagicMock()
        mock_file.closed = False
        agent = AgentProcess(
            feature_id="F-0001",
            worktree_path="/tmp/wt",
            branch_name="feature/F-0001",
            process=MagicMock(),
            start_time=time.time(),
            log_path=Path("/tmp/log"),
            log_file=mock_file,
        )
        d = ParallelDispatcher(Path("/tmp/test"))
        d._close_log(agent)
        mock_file.close.assert_called_once()

    def test_close_log_skips_already_closed(self, mock_get_paths):
        mock_file = MagicMock()
        mock_file.closed = True
        agent = AgentProcess(
            feature_id="F-0001",
            worktree_path="/tmp/wt",
            branch_name="feature/F-0001",
            process=MagicMock(),
            start_time=time.time(),
            log_path=Path("/tmp/log"),
            log_file=mock_file,
        )
        d = ParallelDispatcher(Path("/tmp/test"))
        d._close_log(agent)
        mock_file.close.assert_not_called()

    def test_close_log_handles_no_file(self, mock_get_paths):
        agent = AgentProcess(
            feature_id="F-0001",
            worktree_path="/tmp/wt",
            branch_name="feature/F-0001",
            process=MagicMock(),
            start_time=time.time(),
            log_path=Path("/tmp/log"),
            log_file=None,
        )
        d = ParallelDispatcher(Path("/tmp/test"))
        d._close_log(agent)  # should not raise
