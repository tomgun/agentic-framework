#!/usr/bin/env python3
"""
Tests for the end-to-end autonomous pipeline (F-0188).

Tests the full pipeline orchestrator that wires kickoff → promote →
epic creation → scheduler into a single autonomous flow.
"""
import json
import sys
from pathlib import Path
from unittest.mock import patch, MagicMock

import pytest

sys.path.insert(0, str(Path(__file__).parent.parent / ".agentic" / "lib"))
sys.path.insert(0, str(Path(__file__).parent.parent / ".agentic" / "lib" / "auto"))
sys.path.insert(0, str(Path(__file__).parent.parent / ".agentic" / "lib" / "tools"))

from auto.pipeline import run_pipeline, PipelineResult, _create_epic_entry
from auto.scheduler import SchedulerResult, FeatureWork


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def project_dir(tmp_path):
    """Minimal project structure for pipeline testing."""
    agentic = tmp_path / ".agentic"
    agentic.mkdir()
    (agentic / "session").mkdir()
    spec = agentic / "spec"
    spec.mkdir()
    acceptance = spec / "acceptance"
    acceptance.mkdir()

    # Copy paths.py and settings.py from real lib
    lib_src = Path(__file__).parent.parent / ".agentic" / "lib"
    lib_dst = agentic / "lib"
    lib_dst.mkdir()
    for f in ["paths.py", "settings.py"]:
        src = lib_src / f
        if src.exists():
            (lib_dst / f).write_text(src.read_text())

    # FEATURES.md with one existing feature
    features = spec / "FEATURES.md"
    features.write_text(
        "# Features\n\n"
        "## F-0001: Existing Feature\n\n"
        "**Status**: shipped\n"
        "**Category**: Core\n\n"
        "---\n\n"
    )

    # STACK.md with skip review mode
    (tmp_path / "STACK.md").write_text(
        "## Settings\n"
        "- profile: formal\n"
        "- review_decomposition: skip\n"
    )

    # BACKLOG.json
    (agentic / "BACKLOG.json").write_text("[]")

    return tmp_path


def make_features_data(count=2):
    """Create test features_data in kickoff format."""
    return [
        {
            "placeholder_id": f"P-{i+1}",
            "name": f"Test Feature {i+1}",
            "description": f"Description for feature {i+1}",
            "dependencies": [],
            "criteria_count": 1,
        }
        for i in range(count)
    ]


def make_staging(project_dir, features_data, overview_text="Test overview"):
    """Create a valid staging directory matching features_data."""
    staging = project_dir / ".agentic" / "session" / "kickoff-draft"
    staging.mkdir(parents=True, exist_ok=True)
    spec = staging / "spec" / "acceptance"
    spec.mkdir(parents=True, exist_ok=True)

    # Metadata
    metadata = {"features": features_data}
    if overview_text:
        metadata["overview_text"] = overview_text
    (staging / ".metadata.json").write_text(json.dumps(metadata))

    # OVERVIEW.md (required by validate_staging)
    (staging / "OVERVIEW.md").write_text(
        f"# Project Overview\n\n{overview_text}\n"
    )

    # FEATURES.md (required by validate_staging)
    feature_lines = ["# Proposed Features\n"]
    for f in features_data:
        feature_lines.append(f"## {f['placeholder_id']}: {f['name']}\n")
    (staging / "FEATURES.md").write_text("\n".join(feature_lines))

    # AC files for each feature
    for f in features_data:
        pid = f["placeholder_id"]
        ac = spec / f"{pid}.md"
        ac.write_text(
            f"# {pid}: {f['name']}\n\n"
            f"## Acceptance Criteria\n\n"
            f"- [ ] **AC-001**: {f['name']} works correctly\n"
        )

    # Staging BACKLOG.json
    backlog = [{"id": f["placeholder_id"]} for f in features_data]
    (staging / "BACKLOG.json").write_text(json.dumps(backlog))

    return staging


# ---------------------------------------------------------------------------
# TestPipeline — unit-level tests for each phase
# ---------------------------------------------------------------------------

class TestPipeline:
    def test_full_pipeline_success(self, project_dir):
        """Full pipeline: features_data → shipped epic."""
        features_data = make_features_data(2)

        sched_result = SchedulerResult(
            success=True,
            features_total=2,
            features_completed=2,
        )

        with patch("auto.pipeline.generate_to_staging") as mock_kickoff, \
             patch("auto.pipeline.promote_staging_with_ids") as mock_promote, \
             patch("auto.pipeline.AutonomousScheduler") as mock_sched_cls:

            # Kickoff: create staging
            def kickoff_side_effect(root, data, overview):
                make_staging(root, data, overview)
                return True, ["Staging created"]
            mock_kickoff.side_effect = kickoff_side_effect

            # Promote: return id_map
            mock_promote.return_value = (
                True,
                ["Promoted 2 features"],
                {"P-1": "F-0003", "P-2": "F-0004"},
            )

            # Scheduler: all features succeed
            mock_sched = MagicMock()
            mock_sched.run_epic.return_value = sched_result
            mock_sched_cls.return_value = mock_sched

            result = run_pipeline(
                project_root=project_dir,
                features_data=features_data,
                epic_name="Test Epic",
            )

        assert result.success is True
        assert result.phase == "done"
        assert result.epic_id.startswith("F-")
        assert result.feature_ids == ["F-0003", "F-0004"]
        assert result.scheduler_result is sched_result

    def test_gate_check_blocks_human(self, project_dir):
        """Pipeline refuses to start if review_decomposition: human."""
        (project_dir / "STACK.md").write_text(
            "## Settings\n- review_decomposition: human\n"
        )
        result = run_pipeline(
            project_root=project_dir,
            features_data=make_features_data(),
            epic_name="Test",
        )
        assert result.success is False
        assert result.phase == "gate_check"
        assert "human" in result.blocked_reason

    def test_gate_check_no_writes(self, project_dir):
        """Gate fires BEFORE any writes to FEATURES.md."""
        (project_dir / "STACK.md").write_text(
            "## Settings\n- review_decomposition: human\n"
        )
        features_before = (project_dir / ".agentic" / "spec" / "FEATURES.md").read_text()

        run_pipeline(
            project_root=project_dir,
            features_data=make_features_data(),
            epic_name="Test",
        )

        features_after = (project_dir / ".agentic" / "spec" / "FEATURES.md").read_text()
        assert features_before == features_after, "FEATURES.md should not be modified when gate blocks"

    def test_gate_check_empty_features(self, project_dir):
        """Pipeline refuses empty features_data."""
        result = run_pipeline(
            project_root=project_dir,
            features_data=[],
            epic_name="Test",
        )
        assert result.success is False
        assert result.phase == "gate_check"

    def test_kickoff_failure(self, project_dir):
        """Pipeline stops at kickoff phase on failure."""
        with patch("auto.pipeline.generate_to_staging") as mock_kickoff:
            mock_kickoff.return_value = (False, ["Staging failed"])

            result = run_pipeline(
                project_root=project_dir,
                features_data=make_features_data(),
                epic_name="Test",
            )

        assert result.success is False
        assert result.phase == "kickoff"
        assert result.epic_id  # Epic was created before kickoff

    def test_promote_failure(self, project_dir):
        """Pipeline stops at promote phase on failure."""
        with patch("auto.pipeline.generate_to_staging") as mock_kickoff, \
             patch("auto.pipeline.promote_staging_with_ids") as mock_promote:

            mock_kickoff.return_value = (True, ["OK"])
            mock_promote.return_value = (False, ["Validation failed"], {})

            result = run_pipeline(
                project_root=project_dir,
                features_data=make_features_data(),
                epic_name="Test",
            )

        assert result.success is False
        assert result.phase == "promote"

    def test_epic_creation(self, project_dir):
        """Epic entry is written correctly to FEATURES.md."""
        epic_id, messages = _create_epic_entry(project_dir, "My Epic")

        features_content = (project_dir / ".agentic" / "spec" / "FEATURES.md").read_text()
        assert f"## {epic_id}: My Epic" in features_content
        assert "**Category**: Epic" in features_content
        assert "**Status**: planned" in features_content

        # AC file created
        ac_file = project_dir / ".agentic" / "spec" / "acceptance" / f"{epic_id}.md"
        assert ac_file.exists()
        ac_content = ac_file.read_text()
        assert "AC-001" in ac_content

    def test_children_have_parent(self, project_dir):
        """Promoted features get **Parent** field when parent_id is set."""
        features_data = make_features_data(2)
        make_staging(project_dir, features_data)

        from auto.kickoff import promote_staging_with_ids
        success, msgs, id_map = promote_staging_with_ids(
            project_dir, parent_id="F-0099",
        )

        assert success is True, f"promote failed: {msgs}"
        features_content = (project_dir / ".agentic" / "spec" / "FEATURES.md").read_text()
        # Each promoted child should have the Parent field
        assert features_content.count("**Parent**: F-0099") == 2

    def test_scheduler_partial_failure(self, project_dir):
        """Pipeline reports failure when scheduler has partial completion."""
        sched_result = SchedulerResult(
            success=False,
            features_total=3,
            features_completed=1,
            features_failed=2,
            stopped_reason="max errors reached (3)",
        )

        with patch("auto.pipeline.generate_to_staging") as mock_kickoff, \
             patch("auto.pipeline.promote_staging_with_ids") as mock_promote, \
             patch("auto.pipeline.AutonomousScheduler") as mock_sched_cls:

            mock_kickoff.return_value = (True, ["OK"])
            mock_promote.return_value = (True, ["OK"], {"P-1": "F-0003"})

            mock_sched = MagicMock()
            mock_sched.run_epic.return_value = sched_result
            mock_sched_cls.return_value = mock_sched

            result = run_pipeline(
                project_root=project_dir,
                features_data=make_features_data(1),
                epic_name="Test",
            )

        assert result.success is False
        assert result.phase == "schedule"
        assert "max errors" in result.blocked_reason

    def test_pipeline_result_structure(self, project_dir):
        """PipelineResult.to_dict() includes all fields."""
        r = PipelineResult(
            success=True,
            phase="done",
            epic_id="F-0010",
            feature_ids=["F-0011", "F-0012"],
            messages=["All done"],
        )
        d = r.to_dict()
        assert d["success"] is True
        assert d["phase"] == "done"
        assert d["epic_id"] == "F-0010"
        assert d["feature_ids"] == ["F-0011", "F-0012"]
        assert "messages" in d


# ---------------------------------------------------------------------------
# TestPipelineIntegration — deeper tests for AC-003/004/005/006
# ---------------------------------------------------------------------------

class TestPipelineIntegration:
    def test_review_checkpoints_fire(self, project_dir):
        """AC-004: Scheduler calls review checks during run_epic."""
        with patch("auto.pipeline.generate_to_staging") as mock_kickoff, \
             patch("auto.pipeline.promote_staging_with_ids") as mock_promote, \
             patch("auto.pipeline.AutonomousScheduler") as mock_sched_cls:

            mock_kickoff.return_value = (True, ["OK"])
            mock_promote.return_value = (True, ["OK"], {"P-1": "F-0003"})

            mock_sched = MagicMock()
            mock_sched.run_epic.return_value = SchedulerResult(
                success=True, features_total=1, features_completed=1,
            )
            mock_sched_cls.return_value = mock_sched

            result = run_pipeline(
                project_root=project_dir,
                features_data=make_features_data(1),
                epic_name="Test",
            )

            # Verify scheduler was called with the epic ID
            mock_sched.run_epic.assert_called_once()
            call_kwargs = mock_sched.run_epic.call_args
            assert call_kwargs[1]["epic_id"].startswith("F-")

    def test_integration_verify_fires(self, project_dir):
        """AC-003: Integration verify is part of run_epic (delegated)."""
        sched_result = SchedulerResult(
            success=False,
            features_total=2,
            features_completed=2,
            stopped_reason="Integration verification failed for F-0002",
            integration_result={"success": False, "error": "test failed"},
        )

        with patch("auto.pipeline.generate_to_staging") as mock_kickoff, \
             patch("auto.pipeline.promote_staging_with_ids") as mock_promote, \
             patch("auto.pipeline.AutonomousScheduler") as mock_sched_cls:

            mock_kickoff.return_value = (True, ["OK"])
            mock_promote.return_value = (True, ["OK"], {"P-1": "F-0003"})

            mock_sched = MagicMock()
            mock_sched.run_epic.return_value = sched_result
            mock_sched_cls.return_value = mock_sched

            result = run_pipeline(
                project_root=project_dir,
                features_data=make_features_data(1),
                epic_name="Test",
            )

        assert result.success is False
        assert "Integration verification" in result.blocked_reason

    def test_escalation_handling(self, project_dir):
        """AC-005: Escalation results in blocked_reason with review info."""
        sched_result = SchedulerResult(
            success=False,
            features_total=2,
            features_completed=1,
            features_review_blocked=1,
            stopped_reason="all features blocked on human review",
            feature_work=[
                FeatureWork(feature_id="F-0003", status="completed"),
                FeatureWork(
                    feature_id="F-0004",
                    status="review_blocked",
                    review_blocked_at="committed_to_shipped",
                ),
            ],
        )

        with patch("auto.pipeline.generate_to_staging") as mock_kickoff, \
             patch("auto.pipeline.promote_staging_with_ids") as mock_promote, \
             patch("auto.pipeline.AutonomousScheduler") as mock_sched_cls:

            mock_kickoff.return_value = (True, ["OK"])
            mock_promote.return_value = (
                True, ["OK"],
                {"P-1": "F-0003", "P-2": "F-0004"},
            )

            mock_sched = MagicMock()
            mock_sched.run_epic.return_value = sched_result
            mock_sched_cls.return_value = mock_sched

            result = run_pipeline(
                project_root=project_dir,
                features_data=make_features_data(2),
                epic_name="Test",
            )

        assert result.success is False
        assert result.phase == "schedule"
        assert "review" in result.blocked_reason.lower()

    def test_multi_feature_epic(self, project_dir):
        """AC-006: Full pipeline with 3+ children."""
        features_data = make_features_data(3)

        sched_result = SchedulerResult(
            success=True,
            features_total=3,
            features_completed=3,
        )

        with patch("auto.pipeline.generate_to_staging") as mock_kickoff, \
             patch("auto.pipeline.promote_staging_with_ids") as mock_promote, \
             patch("auto.pipeline.AutonomousScheduler") as mock_sched_cls:

            mock_kickoff.return_value = (True, ["Staging created"])
            mock_promote.return_value = (
                True, ["OK"],
                {"P-1": "F-0003", "P-2": "F-0004", "P-3": "F-0005"},
            )

            mock_sched = MagicMock()
            mock_sched.run_epic.return_value = sched_result
            mock_sched_cls.return_value = mock_sched

            result = run_pipeline(
                project_root=project_dir,
                features_data=features_data,
                epic_name="Multi-Feature Epic",
            )

        assert result.success is True
        assert result.phase == "done"
        assert len(result.feature_ids) == 3
        assert result.epic_id.startswith("F-")

        # Verify epic was created in FEATURES.md
        features_content = (project_dir / ".agentic" / "spec" / "FEATURES.md").read_text()
        assert f"## {result.epic_id}: Multi-Feature Epic" in features_content
