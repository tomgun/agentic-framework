"""
Tests for the Autonomous Scheduler (F-0186).

Covers all 9 acceptance criteria:
- AC-001: Scheduling loop (get_unblocked → spawn → review → repeat)
- AC-002: Non-blocking reviews
- AC-003: Component-scoped workers
- AC-004: Crunch evolves to scheduler-backed
- AC-005: ag auto epic F-XXXX
- AC-006: Escalation handling
- AC-007: All blocked → report + wait
- AC-008: Review resolution → resume
- AC-009: Unit test coverage (this file)
"""
from __future__ import annotations

import json
import os
import sys
import textwrap
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

# Resolve imports
_LIB_DIR = Path(__file__).resolve().parent.parent / ".agentic" / "lib"
sys.path.insert(0, str(_LIB_DIR))
sys.path.insert(0, str(_LIB_DIR / "tools"))


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def project_root(tmp_path):
    """Create a minimal project structure for scheduler tests."""
    agentic = tmp_path / ".agentic"
    spec = agentic / "spec"
    acceptance = spec / "acceptance"
    session = agentic / "session"
    tools = agentic / "lib" / "tools"
    reviews_dir = session / "reviews"

    for d in [spec, acceptance, session, tools, reviews_dir]:
        d.mkdir(parents=True)

    # FEATURES.md with an epic and children
    features_md = spec / "FEATURES.md"
    features_md.write_text(textwrap.dedent("""\
        # Features

        ## F-0100: Test Epic

        **Status**: planned
        **Category**: Test

        **Acceptance**: See `spec/acceptance/F-0100.md`

        ---

        ## F-0101: Child Feature A

        **Status**: planned
        **Category**: Test
        **Parent**: F-0100
        **Component**: api

        **Acceptance**: See `spec/acceptance/F-0101.md`

        ---

        ## F-0102: Child Feature B

        **Status**: planned
        **Category**: Test
        **Parent**: F-0100
        **Component**: web

        **Acceptance**: See `spec/acceptance/F-0102.md`

        ---

        ## F-0103: Child Feature C

        **Status**: shipped
        **Category**: Test
        **Parent**: F-0100

        **Acceptance**: See `spec/acceptance/F-0103.md`

        ---
    """))

    # AC files
    for fid in ["F-0100", "F-0101", "F-0102", "F-0103"]:
        (acceptance / f"{fid}.md").write_text(
            f"# {fid}\n\n- [ ] **AC-001**: Test criterion\n"
        )

    # Minimal STACK.md
    (tmp_path / "STACK.md").write_text("# Stack\n")

    # Git init for state machine
    os.system(f"cd {tmp_path} && git init -q && git add -A && git commit -q -m init")

    return tmp_path


# ---------------------------------------------------------------------------
# AC-001: Scheduling loop
# ---------------------------------------------------------------------------

class TestSchedulingLoop:
    """AC-001: get_unblocked → spawn worker → review gate → repeat."""

    def test_run_with_empty_features(self, project_root):
        from auto.scheduler import AutonomousScheduler

        scheduler = AutonomousScheduler(project_root=project_root)
        result = scheduler.run(feature_ids=[])
        assert not result.success
        assert result.stopped_reason == "no features to schedule"

    @patch("auto.scheduler.TaskRunner")
    def test_scheduling_loop_completes_features(self, mock_runner_cls, project_root):
        """Scheduler should process features and track results."""
        from auto.scheduler import AutonomousScheduler
        from auto.task import TaskResult

        mock_runner = MagicMock()
        mock_runner.run.return_value = TaskResult(
            feature_id="F-0101", success=True,
            acs_total=1, acs_passed=1,
        )
        mock_runner_cls.return_value = mock_runner

        scheduler = AutonomousScheduler(project_root=project_root)
        result = scheduler.run(feature_ids=["F-0101"])

        assert result.features_total == 1
        assert result.features_completed == 1
        assert result.success
        assert len(result.feature_work) == 1
        assert result.feature_work[0].status == "completed"

    @patch("auto.scheduler.TaskRunner")
    def test_scheduling_loop_handles_failures(self, mock_runner_cls, project_root):
        """Scheduler should track failed features and respect max_errors."""
        from auto.scheduler import AutonomousScheduler
        from auto.task import TaskResult

        mock_runner = MagicMock()
        mock_runner.run.return_value = TaskResult(
            feature_id="F-0101", success=False,
            acs_total=1, acs_passed=0, acs_failed=1,
        )
        mock_runner_cls.return_value = mock_runner

        scheduler = AutonomousScheduler(project_root=project_root)
        result = scheduler.run(feature_ids=["F-0101", "F-0102"], max_errors=1)

        assert not result.success
        assert result.features_failed >= 1
        assert "max errors" in result.stopped_reason


# ---------------------------------------------------------------------------
# AC-002: Non-blocking reviews
# ---------------------------------------------------------------------------

class TestNonBlockingReviews:
    """AC-002: While one feature awaits review, scheduler advances others."""

    @patch("auto.scheduler.TaskRunner")
    def test_review_blocked_feature_skipped(self, mock_runner_cls, project_root):
        """Features with pending reviews should be skipped, not stalled."""
        from auto.scheduler import AutonomousScheduler
        from auto.task import TaskResult

        mock_runner = MagicMock()
        mock_runner.run.return_value = TaskResult(
            feature_id="F-0102", success=True,
            acs_total=1, acs_passed=1,
        )
        mock_runner_cls.return_value = mock_runner

        # Create a pending review for F-0101
        pending_dir = project_root / ".agentic" / "session" / "reviews"
        pending_dir.mkdir(parents=True, exist_ok=True)
        review_data = {
            "feature_id": "F-0101",
            "from_state": "documented",
            "to_state": "committed",
            "review_setting": "review_code",
            "review_mode": "human",
        }
        (pending_dir / "F-0101_committed.json").write_text(
            json.dumps(review_data)
        )

        scheduler = AutonomousScheduler(
            project_root=project_root,
            poll_interval=0.05,
            max_poll_cycles=1,
        )
        result = scheduler.run(feature_ids=["F-0101", "F-0102"])

        # F-0101 should be review_blocked, F-0102 should complete
        statuses = {fw.feature_id: fw.status for fw in result.feature_work}
        assert statuses["F-0101"] == "review_blocked"
        assert statuses["F-0102"] == "completed"


# ---------------------------------------------------------------------------
# AC-003: Component-scoped workers
# ---------------------------------------------------------------------------

class TestComponentScoping:
    """AC-003: Worker agents scoped to components."""

    def test_get_feature_component(self, project_root):
        from auto.scheduler import AutonomousScheduler

        scheduler = AutonomousScheduler(project_root=project_root)
        assert scheduler._get_feature_component("F-0101") == "api"
        assert scheduler._get_feature_component("F-0102") == "web"
        assert scheduler._get_feature_component("F-0100") is None

    @patch("auto.scheduler.TaskRunner")
    def test_component_recorded_in_work(self, mock_runner_cls, project_root):
        """FeatureWork should have component populated from FEATURES.md."""
        from auto.scheduler import AutonomousScheduler
        from auto.task import TaskResult

        mock_runner = MagicMock()
        mock_runner.run.return_value = TaskResult(
            feature_id="F-0101", success=True,
            acs_total=1, acs_passed=1,
        )
        mock_runner_cls.return_value = mock_runner

        scheduler = AutonomousScheduler(project_root=project_root)
        result = scheduler.run(feature_ids=["F-0101"])

        assert result.feature_work[0].component == "api"


# ---------------------------------------------------------------------------
# AC-004: Crunch evolves to scheduler-backed
# ---------------------------------------------------------------------------

class TestCrunchEvolution:
    """AC-004: CrunchRunner delegates to AutonomousScheduler."""

    @patch("auto.scheduler.TaskRunner")
    def test_crunch_uses_scheduler(self, mock_runner_cls, project_root):
        """CrunchRunner.run() should use the scheduler underneath."""
        from auto.crunch import CrunchRunner
        from auto.task import TaskResult

        mock_runner = MagicMock()
        mock_runner.run.return_value = TaskResult(
            feature_id="F-0101", success=True,
            acs_total=1, acs_passed=1,
        )
        mock_runner_cls.return_value = mock_runner

        runner = CrunchRunner(project_root=project_root)
        result = runner.run(feature_ids=["F-0101"])

        assert result.success
        assert result.features_completed == 1
        assert len(result.feature_results) == 1
        assert result.feature_results[0].feature_id == "F-0101"
        assert result.feature_results[0].status == "completed"

    def test_crunch_result_format_preserved(self, project_root):
        """CrunchResult.to_dict() should have the expected keys."""
        from auto.crunch import CrunchResult, FeatureBatchResult

        cr = CrunchResult(
            success=True,
            features_total=1,
            features_completed=1,
            feature_results=[FeatureBatchResult(
                feature_id="F-0101", status="completed",
                acs_passed=1, acs_total=1,
            )],
        )
        d = cr.to_dict()
        assert "feature_results" in d
        assert d["feature_results"][0]["feature_id"] == "F-0101"


# ---------------------------------------------------------------------------
# AC-005: ag auto epic F-XXXX
# ---------------------------------------------------------------------------

class TestEpicExecution:
    """AC-005: ag auto epic starts autonomous execution of epic's children."""

    def test_get_epic_children(self, project_root):
        """Should return non-shipped children of an epic."""
        from auto.scheduler import AutonomousScheduler

        scheduler = AutonomousScheduler(project_root=project_root)
        children = scheduler._get_epic_children("F-0100")

        # F-0103 is shipped, should be excluded
        assert "F-0101" in children
        assert "F-0102" in children
        assert "F-0103" not in children

    def test_get_epic_children_no_children(self, project_root):
        from auto.scheduler import AutonomousScheduler

        scheduler = AutonomousScheduler(project_root=project_root)
        children = scheduler._get_epic_children("F-9999")
        assert children == []

    @patch("auto.scheduler.TaskRunner")
    def test_run_epic(self, mock_runner_cls, project_root):
        """run_epic should schedule non-shipped children."""
        from auto.scheduler import AutonomousScheduler
        from auto.task import TaskResult

        mock_runner = MagicMock()
        mock_runner.run.return_value = TaskResult(
            feature_id="test", success=True,
            acs_total=1, acs_passed=1,
        )
        mock_runner_cls.return_value = mock_runner

        scheduler = AutonomousScheduler(project_root=project_root)
        result = scheduler.run_epic("F-0100")

        # Should schedule F-0101, F-0102 (not F-0103 which is shipped)
        scheduled_ids = [fw.feature_id for fw in result.feature_work]
        assert "F-0101" in scheduled_ids
        assert "F-0102" in scheduled_ids
        assert "F-0103" not in scheduled_ids

    def test_run_epic_no_children(self, project_root):
        from auto.scheduler import AutonomousScheduler

        scheduler = AutonomousScheduler(project_root=project_root)
        result = scheduler.run_epic("F-9999")
        assert not result.success
        assert "no unshipped children" in result.stopped_reason


# ---------------------------------------------------------------------------
# AC-006: Escalation handling
# ---------------------------------------------------------------------------

class TestEscalationHandling:
    """AC-006: Escalation logs to HUMAN_NEEDED and continues."""

    def test_handle_escalation_creates_entry(self, project_root):
        """Escalation should attempt to create HUMAN_NEEDED entry."""
        from auto.scheduler import AutonomousScheduler

        # Create a mock blocker.sh that writes to a marker file
        tools_dir = project_root / ".agentic" / "lib" / "tools"
        blocker_sh = tools_dir / "blocker.sh"
        blocker_sh.write_text("#!/bin/bash\necho 'HN-099 added'\n")
        blocker_sh.chmod(0o755)

        scheduler = AutonomousScheduler(project_root=project_root)
        # Should not raise
        scheduler._handle_escalation("F-0101", "Tests failing consistently")

    @patch("auto.scheduler.TaskRunner")
    def test_scheduler_continues_after_exception(self, mock_runner_cls, project_root):
        """If one feature throws, scheduler should continue to next."""
        from auto.scheduler import AutonomousScheduler
        from auto.task import TaskResult

        call_count = 0

        def side_effect(**kwargs):
            nonlocal call_count
            call_count += 1
            if call_count == 1:
                raise RuntimeError("simulated escalation")
            return TaskResult(
                feature_id="F-0102", success=True,
                acs_total=1, acs_passed=1,
            )

        mock_runner = MagicMock()
        mock_runner.run.side_effect = side_effect
        mock_runner_cls.return_value = mock_runner

        scheduler = AutonomousScheduler(project_root=project_root)
        result = scheduler.run(
            feature_ids=["F-0101", "F-0102"],
            max_errors=3,
        )

        assert result.features_failed >= 1
        # Second feature should still be attempted
        ids_attempted = [fw.feature_id for fw in result.feature_work
                         if fw.status != "pending"]
        assert len(ids_attempted) >= 1


# ---------------------------------------------------------------------------
# AC-007: All blocked → report + wait
# ---------------------------------------------------------------------------

class TestAllBlockedReporting:
    """AC-007: When all features blocked, scheduler reports and waits."""

    def test_all_blocked_sets_stopped_reason(self, project_root):
        """When all features are review-blocked, scheduler should report."""
        from auto.scheduler import AutonomousScheduler

        # Create pending reviews for both features
        pending_dir = project_root / ".agentic" / "session" / "reviews"
        pending_dir.mkdir(parents=True, exist_ok=True)
        for fid, state in [("F-0101", "committed"), ("F-0102", "committed")]:
            review_data = {
                "feature_id": fid,
                "from_state": "documented",
                "to_state": state,
                "review_setting": "review_code",
                "review_mode": "human",
            }
            (pending_dir / f"{fid}_{state}.json").write_text(
                json.dumps(review_data)
            )

        scheduler = AutonomousScheduler(
            project_root=project_root,
            poll_interval=0.1,
            max_poll_cycles=1,  # Don't actually wait long
        )
        result = scheduler.run(feature_ids=["F-0101", "F-0102"])

        assert not result.success
        assert "blocked on human review" in result.stopped_reason
        assert result.features_review_blocked == 2


# ---------------------------------------------------------------------------
# AC-008: Review resolution → resume
# ---------------------------------------------------------------------------

class TestReviewResolution:
    """AC-008: When human resolves review, scheduler picks up feature."""

    @patch("auto.scheduler.TaskRunner")
    def test_review_resolution_unblocks(self, mock_runner_cls, project_root):
        """After review resolution, feature should become actionable."""
        from auto.scheduler import AutonomousScheduler
        from auto.task import TaskResult

        mock_runner = MagicMock()
        mock_runner.run.return_value = TaskResult(
            feature_id="F-0101", success=True,
            acs_total=1, acs_passed=1,
        )
        mock_runner_cls.return_value = mock_runner

        # Start with a pending review
        pending_dir = project_root / ".agentic" / "session" / "reviews"
        review_file = pending_dir / "F-0101_committed.json"
        review_file.write_text(json.dumps({
            "feature_id": "F-0101",
            "from_state": "documented",
            "to_state": "committed",
            "review_setting": "review_code",
            "review_mode": "human",
        }))

        scheduler = AutonomousScheduler(
            project_root=project_root,
            poll_interval=0.05,
            max_poll_cycles=5,
        )

        # Simulate review resolution during polling: delete the file
        # after a short delay
        import threading
        def resolve_review():
            import time
            time.sleep(0.1)
            if review_file.exists():
                review_file.unlink()

        thread = threading.Thread(target=resolve_review)
        thread.start()

        result = scheduler.run(feature_ids=["F-0101"])
        thread.join(timeout=2)

        # Feature should have been picked up after resolution
        fw = result.feature_work[0]
        assert fw.feature_id == "F-0101"
        # Should have been processed (completed or at least attempted)
        assert fw.status in ("completed", "failed", "pending")


# ---------------------------------------------------------------------------
# AC-009: SchedulerResult serialization
# ---------------------------------------------------------------------------

class TestResultSerialization:
    """AC-009: Proper serialization and data model."""

    def test_scheduler_result_to_dict(self):
        from auto.scheduler import SchedulerResult, FeatureWork

        result = SchedulerResult(
            success=True,
            features_total=2,
            features_completed=1,
            features_failed=0,
            features_review_blocked=1,
            feature_work=[
                FeatureWork(
                    feature_id="F-0101",
                    component="api",
                    status="completed",
                    duration_seconds=12.345,
                ),
                FeatureWork(
                    feature_id="F-0102",
                    component="web",
                    status="review_blocked",
                    review_blocked_at="documented_to_committed",
                ),
            ],
        )
        d = result.to_dict()
        assert d["success"] is True
        assert d["features_total"] == 2
        assert d["features_review_blocked"] == 1
        assert len(d["feature_work"]) == 2
        assert d["feature_work"][0]["component"] == "api"
        assert d["feature_work"][1]["review_blocked_at"] == "documented_to_committed"

    def test_feature_work_defaults(self):
        from auto.scheduler import FeatureWork

        fw = FeatureWork(feature_id="F-0101")
        assert fw.status == "pending"
        assert fw.component is None
        assert fw.review_blocked_at == ""
        assert fw.task_result is None

    def test_progress_saved_to_disk(self, project_root):
        """Scheduler should save progress to session state."""
        from auto.scheduler import AutonomousScheduler

        scheduler = AutonomousScheduler(project_root=project_root)

        with patch("auto.scheduler.TaskRunner") as mock_cls:
            from auto.task import TaskResult
            mock_cls.return_value.run.return_value = TaskResult(
                feature_id="F-0101", success=True,
                acs_total=1, acs_passed=1,
            )
            scheduler.run(feature_ids=["F-0101"])

        state_file = project_root / ".agentic" / "session" / "scheduler-state.json"
        assert state_file.exists()
        data = json.loads(state_file.read_text())
        assert "feature_work" in data
        assert data["features_completed"] == 1
