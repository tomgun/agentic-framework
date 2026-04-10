#!/usr/bin/env python3
"""
Tests for the autonomous crunch mode (F-0163): multi-feature batch.

CrunchRunner delegates to AutonomousScheduler (F-0186). Tests mock at
the scheduler's TaskRunner (auto.scheduler.TaskRunner) and set up a
git-initialized project with FEATURES.md so the state machine can
resolve feature states.
"""
import os
import sys
import tempfile
from pathlib import Path
from unittest.mock import patch, MagicMock

import pytest

sys.path.insert(0, str(Path(__file__).parent.parent / ".agentic" / "lib"))
sys.path.insert(0, str(Path(__file__).parent.parent / ".agentic" / "lib" / "auto"))

from auto.crunch import CrunchRunner, CrunchResult, FeatureBatchResult
from auto.engine import EngineState


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def project_dir():
    """Project dir with git init + FEATURES.md for state machine."""
    with tempfile.TemporaryDirectory() as tmpdir:
        root = Path(tmpdir)
        (root / ".agentic" / "lib").mkdir(parents=True)
        (root / ".agentic" / "session").mkdir(parents=True)
        (root / ".agentic" / "spec").mkdir(parents=True)
        lib_src = Path(__file__).parent.parent / ".agentic" / "lib"
        for f in ["paths.py", "settings.py"]:
            src = lib_src / f
            if src.exists():
                (root / ".agentic" / "lib" / f).write_text(src.read_text())
        (root / "STACK.md").write_text("## Settings\n- profile: formal\n")
        # Git init required by FeatureStateMachine
        os.system(
            f"cd {root} && git init -q"
            f" && git config user.email test@test.com"
            f" && git config user.name Test"
            f" && git add -A && git commit -q -m init"
        )
        yield root


def write_features_md(root: Path, features: list[tuple[str, str]]) -> None:
    """Write a minimal FEATURES.md with given (id, status) entries.

    Uses heading format (the actual FEATURES.md format) instead of table format.
    """
    lines = ["# Features", ""]
    for fid, status in features:
        # Normalize in-progress to the heading-style format
        status_val = status.replace("-", "_")
        lines.extend([
            f"## {fid}: Test Feature",
            "",
            f"**Status**: {status_val}",
            "**Category**: Test",
            "",
            f"**Description**: Test feature {fid}.",
            "",
            "---",
            "",
        ])
    (root / ".agentic" / "spec" / "FEATURES.md").write_text("\n".join(lines) + "\n")


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

class TestReadPlannedFeatures:
    def test_reads_planned_features(self, project_dir):
        write_features_md(project_dir, [
            ("F-0042", "planned"),
            ("F-0043", "in-progress"),
            ("F-0044", "shipped"),
        ])
        runner = CrunchRunner(project_dir)
        features = runner._read_planned_features()
        assert features == ["F-0042", "F-0043"]

    def test_empty_features(self, project_dir):
        write_features_md(project_dir, [("F-0042", "shipped")])
        runner = CrunchRunner(project_dir)
        features = runner._read_planned_features()
        assert features == []

    def test_no_features_file(self, project_dir):
        runner = CrunchRunner(project_dir)
        features = runner._read_planned_features()
        assert features == []

    def test_preserves_order(self, project_dir):
        write_features_md(project_dir, [
            ("F-0050", "planned"),
            ("F-0042", "planned"),
            ("F-0047", "planned"),
        ])
        runner = CrunchRunner(project_dir)
        features = runner._read_planned_features()
        assert features == ["F-0050", "F-0042", "F-0047"]


class TestCrunchRunner:
    """CrunchRunner delegates to AutonomousScheduler.

    Mock at auto.scheduler.TaskRunner (the scheduler's execution layer)
    and write FEATURES.md entries so the state machine marks features
    as actionable.
    """

    @patch("auto.scheduler.TaskRunner")
    def test_all_features_complete(self, MockTaskRunner, project_dir):
        from auto.task import TaskResult

        write_features_md(project_dir, [
            ("F-0042", "planned"), ("F-0043", "planned"),
        ])
        mock_runner = MagicMock()
        mock_runner.run.return_value = TaskResult(
            feature_id="test", success=True,
            acs_passed=3, acs_total=3,
            pr_url="https://github.com/test/pr/1",
        )
        MockTaskRunner.return_value = mock_runner

        runner = CrunchRunner(project_dir)
        result = runner.run(feature_ids=["F-0042", "F-0043"], skip_pr=True)
        assert result.features_completed == 2
        assert result.features_failed == 0
        assert result.success is True

    @patch("auto.scheduler.TaskRunner")
    def test_stops_on_max_errors(self, MockTaskRunner, project_dir):
        from auto.task import TaskResult

        write_features_md(project_dir, [
            ("F-0042", "planned"), ("F-0043", "planned"),
            ("F-0044", "planned"), ("F-0045", "planned"),
        ])
        mock_runner = MagicMock()
        mock_runner.run.return_value = TaskResult(
            feature_id="test", success=False,
            acs_passed=0, acs_total=3,
        )
        MockTaskRunner.return_value = mock_runner

        runner = CrunchRunner(project_dir)
        result = runner.run(
            feature_ids=["F-0042", "F-0043", "F-0044", "F-0045"],
            max_errors=2,
            skip_pr=True,
        )
        # With retry (attempts < 2), each feature fails after 2 attempts.
        # max_errors=2 stops after 2 features fully fail.
        assert result.features_failed == 2
        assert "max errors" in result.stopped_reason
        assert result.features_skipped == 2

    @patch("auto.scheduler.TaskRunner")
    def test_stops_on_user_command(self, MockTaskRunner, project_dir):
        from auto.task import TaskResult

        write_features_md(project_dir, [
            ("F-0042", "planned"), ("F-0043", "planned"),
            ("F-0044", "planned"),
        ])
        engine_state = EngineState()

        def stop_after_first(**kwargs):
            engine_state.state = "stopping"
            return TaskResult(
                feature_id="test", success=True,
                acs_passed=1, acs_total=1,
            )

        mock_runner = MagicMock()
        mock_runner.run.side_effect = stop_after_first
        MockTaskRunner.return_value = mock_runner

        runner = CrunchRunner(project_dir, engine_state=engine_state)
        result = runner.run(
            feature_ids=["F-0042", "F-0043", "F-0044"],
            skip_pr=True,
        )
        assert result.features_completed == 1
        assert "stopped by user" in result.stopped_reason

    @patch("auto.scheduler.TaskRunner")
    def test_callback_per_feature(self, MockTaskRunner, project_dir):
        from auto.task import TaskResult

        write_features_md(project_dir, [
            ("F-0042", "planned"), ("F-0043", "planned"),
        ])
        mock_runner = MagicMock()
        mock_runner.run.return_value = TaskResult(
            feature_id="test", success=True,
            acs_passed=2, acs_total=2,
        )
        MockTaskRunner.return_value = mock_runner

        callbacks = []
        runner = CrunchRunner(
            project_dir,
            on_feature_done=lambda f: callbacks.append(f),
        )
        runner.run(feature_ids=["F-0042", "F-0043"], skip_pr=True)
        assert len(callbacks) == 2

    @patch("auto.scheduler.TaskRunner")
    def test_saves_progress(self, MockTaskRunner, project_dir):
        from auto.task import TaskResult

        write_features_md(project_dir, [("F-0042", "planned")])
        mock_runner = MagicMock()
        mock_runner.run.return_value = TaskResult(
            feature_id="test", success=True,
            acs_passed=1, acs_total=1,
        )
        MockTaskRunner.return_value = mock_runner

        runner = CrunchRunner(project_dir)
        runner.run(feature_ids=["F-0042"], skip_pr=True)
        # Scheduler saves to scheduler-state.json (not crunch-state.json)
        state_file = project_dir / ".agentic" / "session" / "scheduler-state.json"
        assert state_file.exists()
        import json
        state = json.loads(state_file.read_text())
        assert state["features_completed"] == 1

    def test_no_features_returns_early(self, project_dir):
        runner = CrunchRunner(project_dir)
        result = runner.run()
        assert result.success is False
        assert "no planned features" in result.stopped_reason

    @patch("auto.scheduler.TaskRunner")
    def test_exception_counts_as_failure(self, MockTaskRunner, project_dir):
        write_features_md(project_dir, [("F-0042", "planned")])
        mock_runner = MagicMock()
        mock_runner.run.side_effect = RuntimeError("something broke")
        MockTaskRunner.return_value = mock_runner

        runner = CrunchRunner(project_dir)
        result = runner.run(feature_ids=["F-0042"], max_errors=5, skip_pr=True)
        assert result.features_failed == 1
        assert result.feature_results[0].error == "something broke"


class TestCrunchResult:
    def test_to_dict(self):
        result = CrunchResult(
            success=True,
            features_total=2,
            features_completed=2,
        )
        result.feature_results.append(
            FeatureBatchResult(
                feature_id="F-0042", status="completed",
                acs_passed=3, acs_total=3, duration_seconds=120.5,
            )
        )
        d = result.to_dict()
        assert d["success"] is True
        assert len(d["feature_results"]) == 1
        assert d["feature_results"][0]["duration_seconds"] == 120.5
