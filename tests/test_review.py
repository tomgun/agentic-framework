#!/usr/bin/env python3
"""
Tests for the review checkpoint framework (F-0180, ADR-001 Phase 3).

Covers:
- ReviewMode enum
- Transition → review setting map
- get_review_mode resolution from profiles + STACK.md overrides
- check_review: auto proceeds, human blocks, critical_agent falls back
- Pending review lifecycle: create/find/list
- resolve_review: verdict artifact creation, pending cleanup, transition
- Profile switch mid-feature: pending reviews keep snapshotted mode (AC-008)
- Verdict artifact format and storage
"""
import json
import sys
import tempfile
from pathlib import Path
from unittest.mock import patch, MagicMock

import pytest

sys.path.insert(0, str(Path(__file__).parent.parent / ".agentic" / "lib"))
sys.path.insert(0, str(Path(__file__).parent.parent / ".agentic" / "lib" / "auto"))

from auto.review import (
    ReviewMode,
    TRANSITION_REVIEW_MAP,
    _REGRESSION_PAIRS,
    _get_review_setting_key,
    get_review_mode,
    check_review,
    create_pending_review,
    has_pending_review,
    get_pending_reviews,
    resolve_review,
)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def project_dir():
    """Temporary project directory with settings infrastructure."""
    with tempfile.TemporaryDirectory() as tmpdir:
        root = Path(tmpdir)
        (root / ".agentic" / "lib").mkdir(parents=True)
        (root / ".agentic" / "spec" / "acceptance").mkdir(parents=True)
        (root / ".agentic" / "spec" / "reviews").mkdir(parents=True)
        (root / ".agentic" / "session").mkdir(parents=True)
        (root / ".agentic" / "session" / "reviews").mkdir(parents=True)
        # Create tools directory (paths.tools_dir resolves to .agentic/lib/tools)
        (root / ".agentic" / "lib" / "tools").mkdir(parents=True, exist_ok=True)
        (root / ".agentic" / "lib" / "tools" / "blocker.sh").write_text(
            "#!/bin/bash\necho 'mock'\n"
        )

        # Copy settings infrastructure
        lib_src = Path(__file__).parent.parent / ".agentic" / "lib"
        for f in ["paths.py", "settings.py"]:
            src = lib_src / f
            if src.exists():
                (root / ".agentic" / "lib" / f).write_text(src.read_text())

        # Copy profiles.conf (needed for settings resolution)
        presets_dir = root / ".agentic" / "presets"
        presets_dir.mkdir(parents=True)
        profiles_src = lib_src / "presets" / "profiles.conf"
        if profiles_src.exists():
            (presets_dir / "profiles.conf").write_text(profiles_src.read_text())

        # Default STACK.md with formal profile
        (root / "STACK.md").write_text("## Settings\n- profile: formal\n")
        yield root


def write_features(root: Path, features: list[tuple[str, str, str]]) -> None:
    """Write FEATURES.md with heading-based format."""
    lines = ["# Feature Specifications", "", "<!-- format: features-v0.2.0 -->", ""]
    for fid, name, status in features:
        lines.extend([
            f"## {fid}: {name}", "",
            f"**Status**: {status}", f"**Category**: Test", "",
            f"**Description**: Test feature {fid}.", "", "---", "",
        ])
    (root / ".agentic" / "spec" / "FEATURES.md").write_text("\n".join(lines))


# ---------------------------------------------------------------------------
# TestReviewMode
# ---------------------------------------------------------------------------

class TestReviewMode:
    def test_enum_values(self):
        assert ReviewMode.HUMAN.value == "human"
        assert ReviewMode.CRITICAL_AGENT.value == "critical_agent"
        assert ReviewMode.AUTO.value == "auto"

    def test_enum_from_string(self):
        assert ReviewMode("human") == ReviewMode.HUMAN
        assert ReviewMode("critical_agent") == ReviewMode.CRITICAL_AGENT
        assert ReviewMode("auto") == ReviewMode.AUTO

    def test_invalid_value_raises(self):
        with pytest.raises(ValueError):
            ReviewMode("invalid")


# ---------------------------------------------------------------------------
# TestTransitionReviewMap
# ---------------------------------------------------------------------------

class TestTransitionReviewMap:
    def test_forward_transitions_mapped(self):
        assert TRANSITION_REVIEW_MAP[("planned", "specced")] == "review_spec"
        assert TRANSITION_REVIEW_MAP[("specced", "criteria_set")] == "review_criteria"
        assert TRANSITION_REVIEW_MAP[("tests_written", "implementing")] == "review_plan"
        assert TRANSITION_REVIEW_MAP[("documented", "committed")] == "review_code"
        assert TRANSITION_REVIEW_MAP[("committed", "shipped")] == "review_merge"

    def test_skip_transitions_mapped(self):
        assert TRANSITION_REVIEW_MAP[("planned", "implementing")] == "review_plan"
        assert TRANSITION_REVIEW_MAP[("planned", "shipped")] == "review_merge"
        assert TRANSITION_REVIEW_MAP[("implementing", "shipped")] == "review_merge"
        assert TRANSITION_REVIEW_MAP[("implementing", "committed")] == "review_code"

    def test_regressions_use_review_regression(self):
        for pair in _REGRESSION_PAIRS:
            assert _get_review_setting_key(*pair) == "review_regression"

    def test_unmapped_forward_returns_none(self):
        # These transitions have structural gates, no review needed
        assert _get_review_setting_key("criteria_set", "tests_written") is None
        assert _get_review_setting_key("implementing", "verified") is None
        assert _get_review_setting_key("verified", "documented") is None


# ---------------------------------------------------------------------------
# TestGetReviewMode
# ---------------------------------------------------------------------------

class TestGetReviewMode:
    def test_auto_for_unmapped(self, project_dir):
        mode = get_review_mode(project_dir, "criteria_set", "tests_written")
        assert mode == ReviewMode.AUTO

    def test_formal_profile_defaults(self, project_dir):
        # Formal profile: review_spec=critical_agent
        mode = get_review_mode(project_dir, "planned", "specced")
        assert mode == ReviewMode.CRITICAL_AGENT

    def test_formal_profile_review_merge(self, project_dir):
        mode = get_review_mode(project_dir, "committed", "shipped")
        assert mode == ReviewMode.HUMAN

    def test_discovery_profile_defaults(self, project_dir):
        (project_dir / "STACK.md").write_text(
            "## Settings\n- profile: discovery\n"
        )
        mode = get_review_mode(project_dir, "planned", "specced")
        assert mode == ReviewMode.AUTO

    def test_explicit_override_in_stack(self, project_dir):
        (project_dir / "STACK.md").write_text(
            "## Settings\n- profile: formal\n- review_spec: auto\n"
        )
        mode = get_review_mode(project_dir, "planned", "specced")
        assert mode == ReviewMode.AUTO

    def test_invalid_mode_falls_back_to_auto(self, project_dir):
        (project_dir / "STACK.md").write_text(
            "## Settings\n- profile: formal\n- review_spec: invalid_mode\n"
        )
        mode = get_review_mode(project_dir, "planned", "specced")
        assert mode == ReviewMode.AUTO


# ---------------------------------------------------------------------------
# TestCheckReview
# ---------------------------------------------------------------------------

class TestCheckReview:
    @patch("auto.review.create_pending_review", return_value=None)
    def test_auto_proceeds(self, mock_create, project_dir):
        (project_dir / "STACK.md").write_text(
            "## Settings\n- profile: discovery\n"
        )
        can_proceed, msgs = check_review(
            project_dir, "F-0042", "criteria_set", "tests_written"
        )
        assert can_proceed is True
        assert msgs == []
        mock_create.assert_not_called()

    @patch("auto.review.create_pending_review", return_value="HN-0025")
    def test_human_blocks(self, mock_create, project_dir):
        (project_dir / "STACK.md").write_text(
            "## Settings\n- profile: formal\n- review_merge: human\n"
        )
        can_proceed, msgs = check_review(
            project_dir, "F-0042", "committed", "shipped"
        )
        assert can_proceed is False
        assert any("Review required" in m for m in msgs)
        assert any("ag review F-0042 shipped" in m for m in msgs)
        mock_create.assert_called_once()

    @patch("auto.review.create_pending_review", return_value="HN-0026")
    def test_critical_agent_falls_back_to_human(self, mock_create, project_dir):
        (project_dir / "STACK.md").write_text(
            "## Settings\n- profile: formal\n- review_spec: critical_agent\n"
        )
        can_proceed, msgs = check_review(
            project_dir, "F-0042", "planned", "specced"
        )
        assert can_proceed is False
        assert any("critical_agent" in m and "F-0182" in m for m in msgs)

    def test_existing_verdict_skips_review(self, project_dir):
        # Create verdict artifact
        verdict_dir = project_dir / ".agentic" / "spec" / "reviews" / "F-0042"
        verdict_dir.mkdir(parents=True, exist_ok=True)
        (verdict_dir / "planned_to_specced.md").write_text("# Review: approved\n")

        can_proceed, msgs = check_review(
            project_dir, "F-0042", "planned", "specced"
        )
        assert can_proceed is True
        assert msgs == []


# ---------------------------------------------------------------------------
# TestPendingReview
# ---------------------------------------------------------------------------

class TestPendingReview:
    @patch("auto.review.subprocess.run")
    def test_create_pending_review(self, mock_run, project_dir):
        mock_run.return_value = MagicMock(
            stdout="✓ Added HN-0030: Review: F-0042 → specced\n",
            returncode=0,
        )
        hn_id = create_pending_review(
            project_dir, "F-0042", "planned", "specced",
            "review_spec", "human",
        )
        assert hn_id == "HN-0030"

        # Verify JSON file created
        review_file = (
            project_dir / ".agentic" / "session" / "reviews"
            / "F-0042_specced.json"
        )
        assert review_file.exists()
        data = json.loads(review_file.read_text())
        assert data["feature_id"] == "F-0042"
        assert data["from_state"] == "planned"
        assert data["to_state"] == "specced"
        assert data["review_setting"] == "review_spec"
        assert data["review_mode"] == "human"
        assert data["hn_id"] == "HN-0030"

    def test_has_pending_review(self, project_dir):
        assert not has_pending_review(project_dir, "F-0042", "specced")

        # Create the file
        reviews_dir = project_dir / ".agentic" / "session" / "reviews"
        reviews_dir.mkdir(parents=True, exist_ok=True)
        (reviews_dir / "F-0042_specced.json").write_text("{}")

        assert has_pending_review(project_dir, "F-0042", "specced")

    def test_get_pending_reviews_all(self, project_dir):
        reviews_dir = project_dir / ".agentic" / "session" / "reviews"
        reviews_dir.mkdir(parents=True, exist_ok=True)

        data1 = {"feature_id": "F-0042", "to_state": "specced"}
        data2 = {"feature_id": "F-0043", "to_state": "shipped"}
        (reviews_dir / "F-0042_specced.json").write_text(json.dumps(data1))
        (reviews_dir / "F-0043_shipped.json").write_text(json.dumps(data2))

        reviews = get_pending_reviews(project_dir)
        assert len(reviews) == 2

    def test_get_pending_reviews_filtered(self, project_dir):
        reviews_dir = project_dir / ".agentic" / "session" / "reviews"
        reviews_dir.mkdir(parents=True, exist_ok=True)

        data1 = {"feature_id": "F-0042", "to_state": "specced"}
        data2 = {"feature_id": "F-0043", "to_state": "shipped"}
        (reviews_dir / "F-0042_specced.json").write_text(json.dumps(data1))
        (reviews_dir / "F-0043_shipped.json").write_text(json.dumps(data2))

        reviews = get_pending_reviews(project_dir, "F-0042")
        assert len(reviews) == 1
        assert reviews[0]["feature_id"] == "F-0042"

    def test_get_pending_reviews_empty(self, project_dir):
        reviews = get_pending_reviews(project_dir)
        assert reviews == []


# ---------------------------------------------------------------------------
# TestResolveReview
# ---------------------------------------------------------------------------

class TestResolveReview:
    def _setup_pending(self, project_dir, feature_id="F-0042",
                       from_state="planned", to_state="specced"):
        reviews_dir = project_dir / ".agentic" / "session" / "reviews"
        reviews_dir.mkdir(parents=True, exist_ok=True)
        data = {
            "feature_id": feature_id,
            "from_state": from_state,
            "to_state": to_state,
            "review_setting": "review_spec",
            "review_mode": "human",
            "hn_id": "HN-0025",
            "created_at": "2026-03-08T14:30:00+00:00",
        }
        (reviews_dir / f"{feature_id}_{to_state}.json").write_text(
            json.dumps(data)
        )

    def test_no_pending_review_fails(self, project_dir):
        success, msgs = resolve_review(
            project_dir, "F-0042", "specced", "approved"
        )
        assert success is False
        assert any("No pending review" in m for m in msgs)

    @patch("auto.review.subprocess.run")
    def test_approve_creates_verdict_artifact(self, mock_run, project_dir):
        mock_run.return_value = MagicMock(returncode=0, stdout="", stderr="")
        self._setup_pending(project_dir)
        write_features(project_dir, [("F-0042", "Test", "planned")])

        # Mock the state machine transition to avoid feature.sh dependency
        with patch("auto.state_machine.subprocess.run") as mock_sm_run:
            mock_sm_run.return_value = MagicMock(returncode=0, stderr="")
            success, msgs = resolve_review(
                project_dir, "F-0042", "specced", "approved", "Looks good"
            )

        # Verify verdict artifact
        verdict_file = (
            project_dir / ".agentic" / "spec" / "reviews" / "F-0042"
            / "planned_to_specced.md"
        )
        assert verdict_file.exists()
        content = verdict_file.read_text()
        assert "approved" in content
        assert "Looks good" in content

    @patch("auto.review.subprocess.run")
    def test_approve_cleans_up_pending(self, mock_run, project_dir):
        mock_run.return_value = MagicMock(returncode=0, stdout="", stderr="")
        self._setup_pending(project_dir)
        write_features(project_dir, [("F-0042", "Test", "planned")])

        with patch("auto.state_machine.subprocess.run") as mock_sm_run:
            mock_sm_run.return_value = MagicMock(returncode=0, stderr="")
            resolve_review(project_dir, "F-0042", "specced", "approved")

        # Pending review should be gone
        pending_file = (
            project_dir / ".agentic" / "session" / "reviews"
            / "F-0042_specced.json"
        )
        assert not pending_file.exists()

    @patch("auto.review.subprocess.run")
    def test_reject_blocks_transition(self, mock_run, project_dir):
        mock_run.return_value = MagicMock(returncode=0, stdout="", stderr="")
        self._setup_pending(project_dir)

        success, msgs = resolve_review(
            project_dir, "F-0042", "specced", "rejected", "Needs rework"
        )
        assert success is True
        assert any("rejected" in m for m in msgs)

        # Verdict artifact should exist even for rejections
        verdict_file = (
            project_dir / ".agentic" / "spec" / "reviews" / "F-0042"
            / "planned_to_specced.md"
        )
        assert verdict_file.exists()
        content = verdict_file.read_text()
        assert "rejected" in content

    @patch("auto.review.subprocess.run")
    def test_resolve_calls_blocker_resolve(self, mock_run, project_dir):
        mock_run.return_value = MagicMock(returncode=0, stdout="", stderr="")
        self._setup_pending(project_dir)

        # Create fake blocker.sh so the exists() check passes
        # paths.tools_dir resolves to .agentic/lib/tools (new layout)
        tools_dir = project_dir / ".agentic" / "lib" / "tools"
        tools_dir.mkdir(parents=True, exist_ok=True)
        (tools_dir / "blocker.sh").write_text("#!/bin/bash\n")

        resolve_review(project_dir, "F-0042", "specced", "rejected")

        # Check blocker.sh resolve was called with HN-0025
        calls = [
            c for c in mock_run.call_args_list
            if "resolve" in str(c)
        ]
        assert len(calls) >= 1
        resolve_call = calls[0]
        assert "HN-0025" in str(resolve_call)


# ---------------------------------------------------------------------------
# TestProfileSwitchMidFeature (AC-008)
# ---------------------------------------------------------------------------

class TestProfileSwitchMidFeature:
    def test_pending_review_keeps_snapshotted_mode(self, project_dir):
        """AC-008: If profile changes after review created, pending review
        retains the mode it was created with."""
        reviews_dir = project_dir / ".agentic" / "session" / "reviews"
        reviews_dir.mkdir(parents=True, exist_ok=True)

        # Create review with human mode
        data = {
            "feature_id": "F-0042",
            "from_state": "committed",
            "to_state": "shipped",
            "review_setting": "review_merge",
            "review_mode": "human",
            "hn_id": "HN-0025",
            "created_at": "2026-03-08T14:30:00+00:00",
        }
        (reviews_dir / "F-0042_shipped.json").write_text(json.dumps(data))

        # Switch profile to discovery (which has review_merge=human too,
        # but the principle is that the snapshotted mode doesn't change)
        (project_dir / "STACK.md").write_text(
            "## Settings\n- profile: discovery\n- review_merge: auto\n"
        )

        # The pending review should still show the original mode
        reviews = get_pending_reviews(project_dir, "F-0042")
        assert len(reviews) == 1
        assert reviews[0]["review_mode"] == "human"


# ---------------------------------------------------------------------------
# TestReviewVerdict
# ---------------------------------------------------------------------------

class TestReviewVerdict:
    @patch("auto.review.subprocess.run")
    def test_verdict_artifact_format(self, mock_run, project_dir):
        mock_run.return_value = MagicMock(returncode=0, stdout="", stderr="")

        # Setup pending review
        reviews_dir = project_dir / ".agentic" / "session" / "reviews"
        reviews_dir.mkdir(parents=True, exist_ok=True)
        data = {
            "feature_id": "F-0042",
            "from_state": "planned",
            "to_state": "specced",
            "review_setting": "review_spec",
            "review_mode": "human",
            "hn_id": None,
            "created_at": "2026-03-08T14:30:00+00:00",
        }
        (reviews_dir / "F-0042_specced.json").write_text(json.dumps(data))
        write_features(project_dir, [("F-0042", "Test", "planned")])

        with patch("auto.state_machine.subprocess.run") as mock_sm_run:
            mock_sm_run.return_value = MagicMock(returncode=0, stderr="")
            resolve_review(
                project_dir, "F-0042", "specced", "approved",
                "Spec quality is good"
            )

        verdict_file = (
            project_dir / ".agentic" / "spec" / "reviews" / "F-0042"
            / "planned_to_specced.md"
        )
        content = verdict_file.read_text()

        # Verify expected format
        assert "# Review: F-0042 planned → specced" in content
        assert "**Verdict**: approved" in content
        assert "**Reviewer**: human" in content
        assert "**Setting**: review_spec (mode: human)" in content
        assert "Spec quality is good" in content

    def test_verdict_storage_location(self, project_dir):
        # Verdicts go in .agentic/spec/reviews/{feature_id}/
        verdict_dir = project_dir / ".agentic" / "spec" / "reviews" / "F-0042"
        verdict_dir.mkdir(parents=True, exist_ok=True)
        verdict_file = verdict_dir / "planned_to_specced.md"
        verdict_file.write_text("test")
        assert verdict_file.exists()
        assert "spec/reviews/F-0042" in str(verdict_file)
