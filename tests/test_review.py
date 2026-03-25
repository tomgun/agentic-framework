#!/usr/bin/env python3
"""
Tests for the review checkpoint framework (F-014, ADR-001 Phase 3).

Covers:
- ReviewMode enum
- Transition → review setting map (including sync with state_machine)
- get_review_mode resolution from profiles + STACK.md overrides
- check_review: auto proceeds, human blocks, critical_agent delegates
- Pending review lifecycle: create/find/list (including malformed JSON)
- resolve_review: verdict artifact creation, pending cleanup, transition
- resolve_review: atomic writes, unlink error handling
- Profile switch mid-feature: pending reviews keep snapshotted mode (AC-008)
- Verdict artifact format and storage
- CLI entry point (main)
- Feature ID validation (path traversal prevention)
- Regression pairs sync with state_machine.REGRESSION_TRANSITIONS
- Re-review prevention loop (verdict artifact blocks second review)
"""
import json
import sys
import tempfile
from io import StringIO
from pathlib import Path
from unittest.mock import patch, MagicMock

import pytest

sys.path.insert(0, str(Path(__file__).parent.parent / ".agentic" / "lib"))
sys.path.insert(0, str(Path(__file__).parent.parent / ".agentic" / "lib" / "auto"))

from auto.review import (
    ReviewMode,
    TRANSITION_REVIEW_MAP,
    _REGRESSION_PAIRS,
    _LEGACY_MODE_ALIASES,
    _normalize_review_value,
    _get_review_setting_key,
    _validate_feature_id,
    get_review_mode,
    check_review,
    create_pending_review,
    has_pending_review,
    get_pending_reviews,
    resolve_review,
    main,
)
from auto.state_machine import REGRESSION_TRANSITIONS


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture(autouse=True)
def clear_caches():
    """Clear settings and paths caches between tests."""
    import settings as settings_mod
    import paths as paths_mod
    yield
    # Clear after each test to prevent stale cache between temp dirs
    if hasattr(settings_mod, '_settings_cache'):
        settings_mod._settings_cache.clear()
    if hasattr(settings_mod, '_profile_cache'):
        settings_mod._profile_cache.clear()
    if hasattr(settings_mod, '_presets_cache'):
        settings_mod._presets_cache.clear()
    if hasattr(paths_mod, '_paths_cache'):
        paths_mod._paths_cache.clear()


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
# TestFeatureIdValidation
# ---------------------------------------------------------------------------

class TestFeatureIdValidation:
    def test_valid_feature_id(self):
        _validate_feature_id("F-0042")
        _validate_feature_id("F-001")
        _validate_feature_id("F-99999")  # 5+ digits ok

    def test_path_traversal_rejected(self):
        with pytest.raises(ValueError, match="Invalid feature ID"):
            _validate_feature_id("../../etc")

    def test_empty_string_rejected(self):
        with pytest.raises(ValueError, match="Invalid feature ID"):
            _validate_feature_id("")

    def test_missing_prefix_rejected(self):
        with pytest.raises(ValueError, match="Invalid feature ID"):
            _validate_feature_id("0042")

    def test_wrong_format_rejected(self):
        with pytest.raises(ValueError, match="Invalid feature ID"):
            _validate_feature_id("F-abc")


# ---------------------------------------------------------------------------
# TestReviewMode
# ---------------------------------------------------------------------------

class TestReviewMode:
    def test_enum_values(self):
        assert ReviewMode.HUMAN.value == "human"
        assert ReviewMode.CRITICAL_AGENT.value == "critical_agent"
        assert ReviewMode.SKIP.value == "skip"

    def test_enum_from_string(self):
        assert ReviewMode("human") == ReviewMode.HUMAN
        assert ReviewMode("critical_agent") == ReviewMode.CRITICAL_AGENT
        assert ReviewMode("skip") == ReviewMode.SKIP

    def test_invalid_value_raises(self):
        with pytest.raises(ValueError):
            ReviewMode("invalid")

    def test_legacy_auto_not_valid_enum(self):
        """'auto' is no longer a valid enum value — use _normalize_review_value."""
        with pytest.raises(ValueError):
            ReviewMode("auto")


# ---------------------------------------------------------------------------
# TestBackwardCompatibility (auto → skip rename, v0.51.0)
# ---------------------------------------------------------------------------

class TestBackwardCompatibility:
    """Tests for auto→skip backward compatibility (v0.51.0 rename)."""

    def test_normalize_auto_to_skip(self):
        assert _normalize_review_value("auto") == "skip"

    def test_normalize_skip_unchanged(self):
        assert _normalize_review_value("skip") == "skip"

    def test_normalize_human_unchanged(self):
        assert _normalize_review_value("human") == "human"

    def test_normalize_critical_agent_unchanged(self):
        assert _normalize_review_value("critical_agent") == "critical_agent"

    def test_legacy_alias_mapping(self):
        assert _LEGACY_MODE_ALIASES == {"auto": "skip"}

    def test_auto_in_stack_resolves_to_skip(self, project_dir):
        """STACK.md with legacy 'auto' value should resolve to SKIP mode."""
        (project_dir / "STACK.md").write_text(
            "## Settings\n- profile: discovery\n- review_spec: auto\n"
        )
        mode = get_review_mode(project_dir, "planned", "specced")
        assert mode == ReviewMode.SKIP


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

    def test_regression_pairs_sync_with_state_machine(self):
        """Verify _REGRESSION_PAIRS is derived from state_machine.REGRESSION_TRANSITIONS."""
        expected = {(fr.value, to.value) for fr, to in REGRESSION_TRANSITIONS}
        assert _REGRESSION_PAIRS == expected, (
            f"_REGRESSION_PAIRS out of sync with REGRESSION_TRANSITIONS.\n"
            f"Missing: {expected - _REGRESSION_PAIRS}\n"
            f"Extra: {_REGRESSION_PAIRS - expected}"
        )

    def test_deprecated_transition_returns_none(self):
        """Transitions to deprecated have no review (skip by default)."""
        assert _get_review_setting_key("implementing", "deprecated") is None
        assert _get_review_setting_key("shipped", "deprecated") is None


# ---------------------------------------------------------------------------
# TestGetReviewMode
# ---------------------------------------------------------------------------

class TestGetReviewMode:
    def test_skip_for_unmapped(self, project_dir):
        mode = get_review_mode(project_dir, "criteria_set", "tests_written")
        assert mode == ReviewMode.SKIP

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
        assert mode == ReviewMode.SKIP

    def test_explicit_override_in_stack(self, project_dir):
        (project_dir / "STACK.md").write_text(
            "## Settings\n- profile: formal\n- review_spec: skip\n"
        )
        mode = get_review_mode(project_dir, "planned", "specced")
        assert mode == ReviewMode.SKIP

    def test_invalid_mode_falls_back_to_skip(self, project_dir):
        (project_dir / "STACK.md").write_text(
            "## Settings\n- profile: formal\n- review_spec: invalid_mode\n"
        )
        mode = get_review_mode(project_dir, "planned", "specced")
        assert mode == ReviewMode.SKIP


# ---------------------------------------------------------------------------
# TestCheckReview
# ---------------------------------------------------------------------------

class TestCheckReview:
    @patch("auto.review.create_pending_review", return_value=None)
    def test_skip_proceeds(self, mock_create, project_dir):
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

    @patch("auto.critical_agent.spawn_claude")
    def test_critical_agent_delegates_to_agent(self, mock_spawn, project_dir):
        """AC-008: critical_agent mode delegates to CriticalAgent."""
        import json as _json
        mock_spawn.return_value = '```json\n' + _json.dumps({
            "verdict": "approved",
            "confidence": "high",
            "summary": "Looks good",
            "issues": [],
            "recommendation": "Proceed",
        }) + '\n```'
        (project_dir / "STACK.md").write_text(
            "## Settings\n- profile: formal\n- review_spec: critical_agent\n"
        )
        can_proceed, msgs = check_review(
            project_dir, "F-0042", "planned", "specced"
        )
        assert can_proceed is True
        assert any("approved" in m.lower() for m in msgs)
        mock_spawn.assert_called_once()

    @patch("auto.review.create_pending_review", return_value="HN-0026")
    @patch("auto.critical_agent.CriticalAgent.review")
    def test_critical_agent_error_falls_back_to_human(
        self, mock_review, mock_create, project_dir,
    ):
        """Critical agent error → falls back to human review."""
        mock_review.side_effect = RuntimeError("timeout")
        (project_dir / "STACK.md").write_text(
            "## Settings\n- profile: formal\n- review_spec: critical_agent\n"
        )
        can_proceed, msgs = check_review(
            project_dir, "F-0042", "planned", "specced"
        )
        assert can_proceed is False
        assert any("Falling back" in m for m in msgs)
        mock_create.assert_called_once()

    @patch("auto.critical_agent.spawn_claude")
    def test_critical_agent_request_changes(self, mock_spawn, project_dir):
        """Critical agent request_changes → returns issues."""
        import json as _json
        mock_spawn.return_value = '```json\n' + _json.dumps({
            "verdict": "request_changes",
            "confidence": "high",
            "summary": "Missing tests",
            "issues": [
                {"severity": "high", "description": "No unit tests"},
            ],
            "recommendation": "Add tests",
        }) + '\n```'
        (project_dir / "STACK.md").write_text(
            "## Settings\n- profile: formal\n- review_spec: critical_agent\n"
        )
        can_proceed, msgs = check_review(
            project_dir, "F-0042", "planned", "specced"
        )
        assert can_proceed is False
        assert any("request" in m.lower() for m in msgs)
        assert any("No unit tests" in m for m in msgs)

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

    @patch("auto.review.subprocess.run")
    def test_create_pending_review_5digit_hn_id(self, mock_run, project_dir):
        """HN-ID regex supports more than 4 digits."""
        mock_run.return_value = MagicMock(
            stdout="✓ Added HN-10001: Review: F-0042 → specced\n",
            returncode=0,
        )
        hn_id = create_pending_review(
            project_dir, "F-0042", "planned", "specced",
            "review_spec", "human",
        )
        assert hn_id == "HN-10001"

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

    def test_get_pending_reviews_skips_malformed_json(self, project_dir):
        """Malformed JSON files are skipped without crashing."""
        reviews_dir = project_dir / ".agentic" / "session" / "reviews"
        reviews_dir.mkdir(parents=True, exist_ok=True)

        (reviews_dir / "F-0042_specced.json").write_text("not valid json{{{")
        (reviews_dir / "F-0043_shipped.json").write_text(
            json.dumps({"feature_id": "F-0043", "to_state": "shipped"})
        )

        reviews = get_pending_reviews(project_dir)
        assert len(reviews) == 1
        assert reviews[0]["feature_id"] == "F-0043"


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

    def test_invalid_feature_id_rejected(self, project_dir):
        with pytest.raises(ValueError, match="Invalid feature ID"):
            resolve_review(project_dir, "../../etc", "specced", "approved")

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

        resolve_review(project_dir, "F-0042", "specced", "rejected")

        # Check blocker.sh resolve was called with HN-0025
        calls = [
            c for c in mock_run.call_args_list
            if "resolve" in str(c)
        ]
        assert len(calls) >= 1
        resolve_call = calls[0]
        assert "HN-0025" in str(resolve_call)

    @patch("auto.review.subprocess.run")
    def test_unlink_failure_does_not_crash(self, mock_run, project_dir):
        """If pending file unlink fails, resolve continues with a warning."""
        mock_run.return_value = MagicMock(returncode=0, stdout="", stderr="")
        self._setup_pending(project_dir)

        pending_file = (
            project_dir / ".agentic" / "session" / "reviews"
            / "F-0042_specced.json"
        )

        with patch.object(Path, "unlink", side_effect=OSError("permission denied")):
            success, msgs = resolve_review(
                project_dir, "F-0042", "specced", "rejected"
            )

        assert success is True
        assert any("Could not remove" in m for m in msgs)

    @patch("auto.review.subprocess.run")
    def test_malformed_pending_json_fails_gracefully(self, mock_run, project_dir):
        """Malformed pending review JSON returns an error, not a crash."""
        reviews_dir = project_dir / ".agentic" / "session" / "reviews"
        reviews_dir.mkdir(parents=True, exist_ok=True)
        (reviews_dir / "F-0042_specced.json").write_text("not valid json")

        success, msgs = resolve_review(
            project_dir, "F-0042", "specced", "approved"
        )
        assert success is False
        assert any("Failed to read" in m for m in msgs)


# ---------------------------------------------------------------------------
# TestReReviewPrevention
# ---------------------------------------------------------------------------

class TestReReviewPrevention:
    def test_verdict_artifact_prevents_second_review(self, project_dir):
        """After a verdict artifact exists, check_review returns (True, [])
        regardless of the current review mode setting."""
        # Set up a human review mode
        (project_dir / "STACK.md").write_text(
            "## Settings\n- profile: formal\n- review_spec: human\n"
        )

        # Create verdict artifact (as if already reviewed)
        verdict_dir = project_dir / ".agentic" / "spec" / "reviews" / "F-0042"
        verdict_dir.mkdir(parents=True, exist_ok=True)
        (verdict_dir / "planned_to_specced.md").write_text(
            "# Review: F-0042 planned → specced\n- **Verdict**: approved\n"
        )

        # Even though review_spec=human, the verdict artifact means it's done
        can_proceed, msgs = check_review(
            project_dir, "F-0042", "planned", "specced"
        )
        assert can_proceed is True
        assert msgs == []


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

        # Switch profile to discovery with review_merge: auto
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


# ---------------------------------------------------------------------------
# TestCLI
# ---------------------------------------------------------------------------

class TestCLI:
    def test_list_no_pending(self, project_dir, capsys):
        with patch("sys.argv", ["review", "--project-root", str(project_dir)]):
            result = main()
        assert result == 0
        assert "No pending reviews" in capsys.readouterr().out

    def test_list_with_pending(self, project_dir, capsys):
        reviews_dir = project_dir / ".agentic" / "session" / "reviews"
        reviews_dir.mkdir(parents=True, exist_ok=True)
        data = {
            "feature_id": "F-0042",
            "from_state": "planned",
            "to_state": "specced",
            "review_setting": "review_spec",
            "review_mode": "human",
        }
        (reviews_dir / "F-0042_specced.json").write_text(json.dumps(data))

        with patch("sys.argv", ["review", "--project-root", str(project_dir)]):
            result = main()
        assert result == 0
        out = capsys.readouterr().out
        assert "F-0042" in out
        assert "review_spec" in out

    def test_feature_list(self, project_dir, capsys):
        reviews_dir = project_dir / ".agentic" / "session" / "reviews"
        reviews_dir.mkdir(parents=True, exist_ok=True)
        data = {
            "feature_id": "F-0042",
            "from_state": "planned",
            "to_state": "specced",
            "review_setting": "review_spec",
            "review_mode": "human",
        }
        (reviews_dir / "F-0042_specced.json").write_text(json.dumps(data))

        with patch("sys.argv", ["review", "F-0042", "--project-root", str(project_dir)]):
            result = main()
        assert result == 0
        assert "planned" in capsys.readouterr().out

    def test_invalid_feature_id_rejected(self, project_dir, capsys):
        with patch("sys.argv", ["review", "../../etc", "--project-root", str(project_dir)]):
            result = main()
        assert result == 1
        assert "Invalid feature ID" in capsys.readouterr().out

    def test_reject_flag(self, project_dir, capsys):
        """--reject flag produces rejected verdict."""
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

        with patch("sys.argv", [
            "review", "F-0042", "specced", "--reject",
            "--reason", "Needs work",
            "--project-root", str(project_dir),
        ]):
            result = main()
        assert result == 0
        out = capsys.readouterr().out
        assert "rejected" in out

    def test_approve_reject_mutually_exclusive(self, project_dir):
        """--approve and --reject cannot be used together."""
        with pytest.raises(SystemExit):
            with patch("sys.argv", [
                "review", "F-0042", "specced",
                "--approve", "--reject",
                "--project-root", str(project_dir),
            ]):
                main()
