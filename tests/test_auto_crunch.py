#!/usr/bin/env python3
"""
Tests for the autonomous crunch mode (F-0163): multi-feature batch.
"""
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
    """Project dir with FEATURES.md listing planned features."""
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
        yield root


def write_features_md(root: Path, features: list[tuple[str, str]]) -> None:
    """Write a minimal FEATURES.md with given (id, status) entries."""
    lines = [
        "# Features",
        "",
        "| ID | Category | Status | Description |",
        "|----|----------|--------|-------------|",
    ]
    for fid, status in features:
        lines.append(f"| {fid} | Test | {status} | Test feature |")
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
    @patch("auto.crunch.TaskRunner")
    def test_all_features_complete(self, MockTaskRunner, project_dir):
        mock_runner = MagicMock()
        mock_result = MagicMock()
        mock_result.success = True
        mock_result.acs_passed = 3
        mock_result.acs_total = 3
        mock_result.pr_url = "https://github.com/test/pr/1"
        mock_runner.run.return_value = mock_result
        MockTaskRunner.return_value = mock_runner

        runner = CrunchRunner(project_dir)
        result = runner.run(feature_ids=["F-0042", "F-0043"], skip_pr=True)
        assert result.features_completed == 2
        assert result.features_failed == 0
        assert result.success is True

    @patch("auto.crunch.TaskRunner")
    def test_stops_on_max_errors(self, MockTaskRunner, project_dir):
        mock_runner = MagicMock()
        mock_result = MagicMock()
        mock_result.success = False
        mock_result.acs_passed = 0
        mock_result.acs_total = 3
        mock_result.pr_url = ""
        mock_runner.run.return_value = mock_result
        MockTaskRunner.return_value = mock_runner

        runner = CrunchRunner(project_dir)
        result = runner.run(
            feature_ids=["F-0042", "F-0043", "F-0044", "F-0045"],
            max_errors=2,
            skip_pr=True,
        )
        assert result.features_failed == 2
        assert "max errors" in result.stopped_reason
        assert result.features_skipped == 2

    @patch("auto.crunch.TaskRunner")
    def test_stops_on_user_command(self, MockTaskRunner, project_dir):
        engine_state = EngineState()

        def stop_after_first(*args, **kwargs):
            engine_state.state = "stopping"
            result = MagicMock()
            result.success = True
            result.acs_passed = 1
            result.acs_total = 1
            result.pr_url = ""
            return result

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

    @patch("auto.crunch.TaskRunner")
    def test_callback_per_feature(self, MockTaskRunner, project_dir):
        mock_runner = MagicMock()
        mock_result = MagicMock()
        mock_result.success = True
        mock_result.acs_passed = 2
        mock_result.acs_total = 2
        mock_result.pr_url = ""
        mock_runner.run.return_value = mock_result
        MockTaskRunner.return_value = mock_runner

        callbacks = []
        runner = CrunchRunner(
            project_dir,
            on_feature_done=lambda f: callbacks.append(f),
        )
        runner.run(feature_ids=["F-0042", "F-0043"], skip_pr=True)
        assert len(callbacks) == 2

    @patch("auto.crunch.TaskRunner")
    def test_saves_progress(self, MockTaskRunner, project_dir):
        mock_runner = MagicMock()
        mock_result = MagicMock()
        mock_result.success = True
        mock_result.acs_passed = 1
        mock_result.acs_total = 1
        mock_result.pr_url = ""
        mock_runner.run.return_value = mock_result
        MockTaskRunner.return_value = mock_runner

        runner = CrunchRunner(project_dir)
        runner.run(feature_ids=["F-0042"], skip_pr=True)
        state_file = project_dir / ".agentic" / "session" / "crunch-state.json"
        assert state_file.exists()
        import json
        state = json.loads(state_file.read_text())
        assert state["features_completed"] == 1

    def test_no_features_returns_early(self, project_dir):
        runner = CrunchRunner(project_dir)
        result = runner.run()
        assert result.success is False
        assert "no planned features" in result.stopped_reason

    @patch("auto.crunch.TaskRunner")
    def test_exception_counts_as_failure(self, MockTaskRunner, project_dir):
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
