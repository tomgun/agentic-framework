#!/usr/bin/env python3
"""
Tests for the formal feature state machine (ADR-001 Phase 1).

Covers:
- FeatureState enum and aliases
- Forward transitions
- Regression transitions and cascade invalidations
- Skip transitions
- Advisory vs enforce modes
- Gate integration
- State reading from FEATURES.md
- CLI entry point
- get_unblocked() query
"""
import re
import sys
import tempfile
from pathlib import Path
from unittest.mock import patch

import pytest

sys.path.insert(0, str(Path(__file__).parent.parent / ".agentic" / "lib"))
sys.path.insert(0, str(Path(__file__).parent.parent / ".agentic" / "lib" / "auto"))

from auto.state_machine import (
    FeatureState,
    FeatureStateMachine,
    GateResult,
    STATE_ORDER,
    STATUS_ALIASES,
    ALL_VALID_STATUSES,
    FORWARD_TRANSITIONS,
    REGRESSION_TRANSITIONS,
    SKIP_TRANSITIONS,
)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def project_dir():
    """Temporary project directory with paths.py and settings.py."""
    with tempfile.TemporaryDirectory() as tmpdir:
        root = Path(tmpdir)
        (root / ".agentic" / "lib").mkdir(parents=True)
        (root / ".agentic" / "spec" / "acceptance").mkdir(parents=True)
        (root / ".agentic" / "session").mkdir(parents=True)
        lib_src = Path(__file__).parent.parent / ".agentic" / "lib"
        for f in ["paths.py", "settings.py"]:
            src = lib_src / f
            if src.exists():
                (root / ".agentic" / "lib" / f).write_text(src.read_text())
        (root / "STACK.md").write_text("## Settings\n- profile: formal\n")
        yield root


def write_features(root: Path, features: list[tuple[str, str, str]]) -> None:
    """Write FEATURES.md with heading-based format.

    features: list of (feature_id, name, status)
    """
    lines = [
        "# Feature Specifications",
        "",
        "<!-- format: features-v0.2.0 -->",
        "",
    ]
    for fid, name, status in features:
        lines.extend([
            f"## {fid}: {name}",
            "",
            f"**Status**: {status}",
            f"**Category**: Test",
            "",
            f"**Description**: Test feature {fid}.",
            "",
            "---",
            "",
        ])
    (root / ".agentic" / "spec" / "FEATURES.md").write_text("\n".join(lines))


# ---------------------------------------------------------------------------
# FeatureState enum
# ---------------------------------------------------------------------------

class TestFeatureState:
    def test_all_nine_states_plus_deprecated(self):
        assert len(FeatureState) == 10
        expected = {
            "planned", "specced", "criteria_set", "tests_written",
            "implementing", "verified", "documented", "committed",
            "shipped", "deprecated",
        }
        assert {s.value for s in FeatureState} == expected

    def test_state_order_excludes_deprecated(self):
        assert FeatureState.DEPRECATED not in STATE_ORDER
        assert len(STATE_ORDER) == 9
        assert STATE_ORDER[0] == FeatureState.PLANNED
        assert STATE_ORDER[-1] == FeatureState.SHIPPED

    def test_aliases(self):
        assert STATUS_ALIASES["in_progress"] == FeatureState.IMPLEMENTING
        assert STATUS_ALIASES["in-progress"] == FeatureState.IMPLEMENTING

    def test_all_valid_statuses_comprehensive(self):
        for state in FeatureState:
            assert state.value in ALL_VALID_STATUSES
        assert "in_progress" in ALL_VALID_STATUSES
        assert "in-progress" in ALL_VALID_STATUSES


# ---------------------------------------------------------------------------
# Transition tables
# ---------------------------------------------------------------------------

class TestTransitionTables:
    def test_forward_transitions_are_sequential(self):
        """Each forward transition goes to the next state in order."""
        assert len(FORWARD_TRANSITIONS) == 8
        for i in range(len(STATE_ORDER) - 1):
            assert (STATE_ORDER[i], STATE_ORDER[i + 1]) in FORWARD_TRANSITIONS

    def test_regression_transitions_go_backward(self):
        for from_state, to_state in REGRESSION_TRANSITIONS:
            from_idx = STATE_ORDER.index(from_state)
            to_idx = STATE_ORDER.index(to_state)
            assert from_idx > to_idx, (
                f"Regression {from_state.value} -> {to_state.value} "
                f"is not backward"
            )

    def test_skip_transitions_exist(self):
        assert len(SKIP_TRANSITIONS) >= 4
        # planned -> implementing (legacy flow)
        assert (FeatureState.PLANNED, FeatureState.IMPLEMENTING) in SKIP_TRANSITIONS
        # planned -> shipped (retroactive tracking)
        assert (FeatureState.PLANNED, FeatureState.SHIPPED) in SKIP_TRANSITIONS
        # implementing -> shipped (current common flow)
        assert (FeatureState.IMPLEMENTING, FeatureState.SHIPPED) in SKIP_TRANSITIONS


# ---------------------------------------------------------------------------
# State resolution
# ---------------------------------------------------------------------------

class TestResolveState:
    def test_direct_values(self):
        assert FeatureStateMachine.resolve_state("planned") == FeatureState.PLANNED
        assert FeatureStateMachine.resolve_state("shipped") == FeatureState.SHIPPED
        assert FeatureStateMachine.resolve_state("implementing") == FeatureState.IMPLEMENTING

    def test_alias_in_progress(self):
        assert FeatureStateMachine.resolve_state("in_progress") == FeatureState.IMPLEMENTING
        assert FeatureStateMachine.resolve_state("in-progress") == FeatureState.IMPLEMENTING

    def test_case_insensitive(self):
        assert FeatureStateMachine.resolve_state("PLANNED") == FeatureState.PLANNED
        assert FeatureStateMachine.resolve_state("Shipped") == FeatureState.SHIPPED

    def test_unknown_raises(self):
        with pytest.raises(ValueError, match="Unknown status"):
            FeatureStateMachine.resolve_state("nonexistent")

    def test_new_states_resolve(self):
        assert FeatureStateMachine.resolve_state("specced") == FeatureState.SPECCED
        assert FeatureStateMachine.resolve_state("criteria_set") == FeatureState.CRITERIA_SET
        assert FeatureStateMachine.resolve_state("tests_written") == FeatureState.TESTS_WRITTEN
        assert FeatureStateMachine.resolve_state("verified") == FeatureState.VERIFIED
        assert FeatureStateMachine.resolve_state("documented") == FeatureState.DOCUMENTED
        assert FeatureStateMachine.resolve_state("committed") == FeatureState.COMMITTED


# ---------------------------------------------------------------------------
# Get current state
# ---------------------------------------------------------------------------

class TestGetCurrentState:
    def test_reads_state_from_features_md(self, project_dir):
        write_features(project_dir, [("F-0042", "Test", "planned")])
        sm = FeatureStateMachine(project_root=project_dir)
        assert sm.get_current_state("F-0042") == FeatureState.PLANNED

    def test_reads_implementing_alias(self, project_dir):
        write_features(project_dir, [("F-0042", "Test", "in_progress")])
        sm = FeatureStateMachine(project_root=project_dir)
        assert sm.get_current_state("F-0042") == FeatureState.IMPLEMENTING

    def test_reads_new_states(self, project_dir):
        write_features(project_dir, [("F-0042", "Test", "specced")])
        sm = FeatureStateMachine(project_root=project_dir)
        assert sm.get_current_state("F-0042") == FeatureState.SPECCED

    def test_missing_feature_returns_none(self, project_dir):
        write_features(project_dir, [("F-0042", "Test", "planned")])
        sm = FeatureStateMachine(project_root=project_dir)
        assert sm.get_current_state("F-9999") is None

    def test_missing_features_file_returns_none(self, project_dir):
        sm = FeatureStateMachine(project_root=project_dir)
        assert sm.get_current_state("F-0042") is None


# ---------------------------------------------------------------------------
# Transition validity
# ---------------------------------------------------------------------------

class TestIsValidTransition:
    def test_forward_transitions_valid(self):
        for from_s, to_s in FORWARD_TRANSITIONS:
            assert FeatureStateMachine.is_valid_transition(from_s, to_s)

    def test_regressions_valid(self):
        for from_s, to_s in REGRESSION_TRANSITIONS:
            assert FeatureStateMachine.is_valid_transition(from_s, to_s)

    def test_skips_valid(self):
        for from_s, to_s in SKIP_TRANSITIONS:
            assert FeatureStateMachine.is_valid_transition(from_s, to_s)

    def test_any_to_deprecated_valid(self):
        for state in FeatureState:
            if state != FeatureState.DEPRECATED:
                assert FeatureStateMachine.is_valid_transition(
                    state, FeatureState.DEPRECATED
                )

    def test_invalid_transition_rejected(self):
        # shipped -> planned is not a valid transition
        assert not FeatureStateMachine.is_valid_transition(
            FeatureState.SHIPPED, FeatureState.PLANNED
        )
        # verified -> specced is not defined
        assert not FeatureStateMachine.is_valid_transition(
            FeatureState.VERIFIED, FeatureState.SPECCED
        )


# ---------------------------------------------------------------------------
# Regression detection and cascade
# ---------------------------------------------------------------------------

class TestRegression:
    def test_is_regression(self):
        assert FeatureStateMachine.is_regression(
            FeatureState.IMPLEMENTING, FeatureState.SPECCED
        )
        assert FeatureStateMachine.is_regression(
            FeatureState.VERIFIED, FeatureState.IMPLEMENTING
        )

    def test_not_regression_for_forward(self):
        assert not FeatureStateMachine.is_regression(
            FeatureState.PLANNED, FeatureState.SPECCED
        )

    def test_cascade_implementing_to_specced(self):
        """Regressing from implementing to specced invalidates criteria_set + tests_written."""
        invalidated = FeatureStateMachine.cascade_invalidations(
            FeatureState.IMPLEMENTING, FeatureState.SPECCED
        )
        assert FeatureState.CRITERIA_SET in invalidated
        assert FeatureState.TESTS_WRITTEN in invalidated
        assert FeatureState.SPECCED not in invalidated
        assert FeatureState.IMPLEMENTING not in invalidated

    def test_cascade_verified_to_implementing(self):
        """Regressing from verified to implementing invalidates nothing between them."""
        invalidated = FeatureStateMachine.cascade_invalidations(
            FeatureState.VERIFIED, FeatureState.IMPLEMENTING
        )
        assert invalidated == []

    def test_cascade_committed_to_implementing(self):
        """Regressing from committed to implementing invalidates verified + documented."""
        invalidated = FeatureStateMachine.cascade_invalidations(
            FeatureState.COMMITTED, FeatureState.IMPLEMENTING
        )
        assert FeatureState.VERIFIED in invalidated
        assert FeatureState.DOCUMENTED in invalidated

    def test_no_cascade_for_forward(self):
        invalidated = FeatureStateMachine.cascade_invalidations(
            FeatureState.PLANNED, FeatureState.SPECCED
        )
        assert invalidated == []


# ---------------------------------------------------------------------------
# can_transition
# ---------------------------------------------------------------------------

class TestCanTransition:
    def test_valid_forward_allowed(self, project_dir):
        write_features(project_dir, [("F-0042", "Test", "planned")])
        sm = FeatureStateMachine(project_root=project_dir)
        allowed, msgs = sm.can_transition("F-0042", FeatureState.SPECCED)
        assert allowed

    def test_same_state_idempotent_noop(self, project_dir):
        """Transitioning to the same state is a no-op, not an error (AC-001)."""
        write_features(project_dir, [("F-0042", "Test", "planned")])
        sm = FeatureStateMachine(project_root=project_dir)
        allowed, msgs = sm.can_transition("F-0042", FeatureState.PLANNED)
        assert allowed
        assert "no-op" in msgs[0]
        assert "already in state" in msgs[0]

    def test_missing_feature_rejected(self, project_dir):
        write_features(project_dir, [("F-0042", "Test", "planned")])
        sm = FeatureStateMachine(project_root=project_dir)
        allowed, msgs = sm.can_transition("F-9999", FeatureState.SPECCED)
        assert not allowed

    def test_same_state_transition_short_circuits(self, project_dir):
        """transition() short-circuits when current == target (AC-002).

        Must not call check_review(), has_pending_review(), or feature.sh.
        """
        write_features(project_dir, [("F-0042", "Test", "implementing")])
        sm = FeatureStateMachine(project_root=project_dir)
        with patch("auto.review.check_review") as mock_review, \
             patch("auto.review.has_pending_review") as mock_pending:
            ok, msgs = sm.transition("F-0042", FeatureState.IMPLEMENTING)
            assert ok
            assert "no-op" in msgs[0]
            mock_review.assert_not_called()
            mock_pending.assert_not_called()

    def test_invalid_transition_advisory_mode(self, project_dir):
        """In advisory mode, invalid transitions warn but allow."""
        write_features(project_dir, [("F-0042", "Test", "shipped")])
        sm = FeatureStateMachine(project_root=project_dir, enforce=False)
        allowed, msgs = sm.can_transition("F-0042", FeatureState.PLANNED)
        assert allowed
        assert any("WARNING" in m for m in msgs)

    def test_invalid_transition_enforce_mode(self, project_dir):
        """In enforce mode, invalid transitions are blocked."""
        write_features(project_dir, [("F-0042", "Test", "shipped")])
        sm = FeatureStateMachine(project_root=project_dir, enforce=True)
        allowed, msgs = sm.can_transition("F-0042", FeatureState.PLANNED)
        assert not allowed
        assert any("Invalid transition" in m for m in msgs)


# ---------------------------------------------------------------------------
# Gate integration
# ---------------------------------------------------------------------------

class TestGateIntegration:
    def test_gate_blocks_in_enforce_mode(self, project_dir):
        write_features(project_dir, [("F-0042", "Test", "planned")])
        sm = FeatureStateMachine(project_root=project_dir, enforce=True)

        def blocking_gate(fid, root):
            return GateResult(allowed=False, reasons=["Test block"], warnings=[])

        sm.register_gate(FeatureState.PLANNED, FeatureState.SPECCED, blocking_gate)
        allowed, msgs = sm.can_transition("F-0042", FeatureState.SPECCED)
        assert not allowed
        assert "Test block" in msgs[0]

    def test_gate_warns_in_advisory_mode(self, project_dir):
        write_features(project_dir, [("F-0042", "Test", "planned")])
        sm = FeatureStateMachine(project_root=project_dir, enforce=False)

        def blocking_gate(fid, root):
            return GateResult(allowed=False, reasons=["Test block"], warnings=[])

        sm.register_gate(FeatureState.PLANNED, FeatureState.SPECCED, blocking_gate)
        allowed, msgs = sm.can_transition("F-0042", FeatureState.SPECCED)
        assert allowed  # advisory mode lets it through
        assert any("Gate failed" in m for m in msgs)

    def test_no_gate_allows(self, project_dir):
        write_features(project_dir, [("F-0042", "Test", "planned")])
        sm = FeatureStateMachine(project_root=project_dir)
        result = sm.check_gate(
            "F-0042", FeatureState.PLANNED, FeatureState.SPECCED
        )
        assert result.allowed


# ---------------------------------------------------------------------------
# transition (dry-run)
# ---------------------------------------------------------------------------

class TestTransitionDryRun:
    def test_dry_run_does_not_modify(self, project_dir):
        write_features(project_dir, [("F-0042", "Test", "planned")])
        sm = FeatureStateMachine(project_root=project_dir)
        ok, msgs = sm.transition("F-0042", FeatureState.SPECCED, dry_run=True)
        assert ok
        assert any("DRY RUN" in m for m in msgs)
        # State should NOT have changed
        assert sm.get_current_state("F-0042") == FeatureState.PLANNED

    def test_dry_run_regression_shows_cascade(self, project_dir):
        write_features(project_dir, [("F-0042", "Test", "implementing")])
        sm = FeatureStateMachine(project_root=project_dir)
        ok, msgs = sm.transition("F-0042", FeatureState.SPECCED, dry_run=True)
        assert ok
        assert any("cascade" in m.lower() for m in msgs)


# ---------------------------------------------------------------------------
# get_next_states
# ---------------------------------------------------------------------------

class TestGetNextStates:
    def test_planned_has_specced(self, project_dir):
        write_features(project_dir, [("F-0042", "Test", "planned")])
        sm = FeatureStateMachine(project_root=project_dir)
        nexts = sm.get_next_states("F-0042")
        assert FeatureState.SPECCED in nexts

    def test_shipped_has_no_next(self, project_dir):
        write_features(project_dir, [("F-0042", "Test", "shipped")])
        sm = FeatureStateMachine(project_root=project_dir)
        nexts = sm.get_next_states("F-0042")
        assert nexts == []


# ---------------------------------------------------------------------------
# get_unblocked
# ---------------------------------------------------------------------------

class TestGetUnblocked:
    def test_finds_unblocked_features(self, project_dir):
        write_features(project_dir, [
            ("F-0042", "Test A", "planned"),
            ("F-0043", "Test B", "implementing"),
            ("F-0044", "Test C", "shipped"),
        ])
        sm = FeatureStateMachine(project_root=project_dir)
        unblocked = sm.get_unblocked()
        fids = [fid for fid, _, _ in unblocked]
        assert "F-0042" in fids
        assert "F-0043" in fids
        assert "F-0044" not in fids  # shipped

    def test_empty_when_all_shipped(self, project_dir):
        write_features(project_dir, [("F-0042", "Test", "shipped")])
        sm = FeatureStateMachine(project_root=project_dir)
        assert sm.get_unblocked() == []


# ---------------------------------------------------------------------------
# Blocking enforcement (F-0222)
# ---------------------------------------------------------------------------

class TestBlockingEnforcement:
    """Tests for state_enforcement=blocking mode (F-0222)."""

    def test_gate_failure_blocks_in_enforce_mode(self, project_dir):
        """AC1: Gate failures block transitions when enforce=True."""
        write_features(project_dir, [("F-0042", "Test", "planned")])
        sm = FeatureStateMachine(project_root=project_dir, enforce=True)

        def failing_gate(fid, root):
            return GateResult(
                allowed=False,
                reasons=["Missing acceptance criteria file"],
                warnings=[],
            )

        sm.register_gate(FeatureState.PLANNED, FeatureState.SPECCED, failing_gate)
        allowed, msgs = sm.can_transition("F-0042", FeatureState.SPECCED)
        assert not allowed
        assert any("Missing acceptance criteria" in m for m in msgs)

    def test_gate_failure_advisory_allows(self, project_dir):
        """AC1 inverse: Gate failures are advisory when enforce=False."""
        write_features(project_dir, [("F-0042", "Test", "planned")])
        sm = FeatureStateMachine(project_root=project_dir, enforce=False)

        def failing_gate(fid, root):
            return GateResult(
                allowed=False,
                reasons=["Missing acceptance criteria file"],
                warnings=[],
            )

        sm.register_gate(FeatureState.PLANNED, FeatureState.SPECCED, failing_gate)
        allowed, msgs = sm.can_transition("F-0042", FeatureState.SPECCED)
        assert allowed  # advisory lets it through

    def test_skip_transitions_work_in_enforce_mode(self, project_dir):
        """AC3: SKIP_TRANSITIONS (planned→implementing, planned→shipped) still work."""
        write_features(project_dir, [("F-0042", "Test", "planned")])
        sm = FeatureStateMachine(project_root=project_dir, enforce=True)

        # planned -> implementing (legacy flow)
        allowed, msgs = sm.can_transition("F-0042", FeatureState.IMPLEMENTING)
        assert allowed

        # planned -> shipped (retroactive tracking)
        allowed2, msgs2 = sm.can_transition("F-0042", FeatureState.SHIPPED)
        assert allowed2

    def test_error_messages_contain_gate_reason(self, project_dir):
        """AC4: Error messages include the gate failure reason."""
        write_features(project_dir, [("F-0042", "Test", "planned")])
        sm = FeatureStateMachine(project_root=project_dir, enforce=True)

        reason_text = "Spec file not found at spec/acceptance/F-0042.md"

        def failing_gate(fid, root):
            return GateResult(
                allowed=False,
                reasons=[reason_text],
                warnings=[],
            )

        sm.register_gate(FeatureState.PLANNED, FeatureState.SPECCED, failing_gate)
        allowed, msgs = sm.can_transition("F-0042", FeatureState.SPECCED)
        assert not allowed
        assert any(reason_text in m for m in msgs)

    def test_existing_features_not_retroactively_broken(self, project_dir):
        """AC5: Features in inconsistent states aren't broken by enforcement.

        Enforcement is forward-looking: it checks transitions, not existing state.
        A feature already at 'implementing' with no AC file is fine — enforcement
        only kicks in when you try to transition.
        """
        write_features(project_dir, [("F-0042", "Test", "implementing")])
        sm = FeatureStateMachine(project_root=project_dir, enforce=True)

        # Reading current state works fine
        assert sm.get_current_state("F-0042") == FeatureState.IMPLEMENTING

        # Forward transition from implementing still works (no gate registered)
        allowed, msgs = sm.can_transition("F-0042", FeatureState.VERIFIED)
        assert allowed

    def test_invalid_transition_blocked_in_enforce_mode(self, project_dir):
        """Invalid transitions (not in any table) are blocked in enforce mode."""
        write_features(project_dir, [("F-0042", "Test", "shipped")])
        sm = FeatureStateMachine(project_root=project_dir, enforce=True)

        allowed, msgs = sm.can_transition("F-0042", FeatureState.PLANNED)
        assert not allowed
        assert any("Invalid transition" in m for m in msgs)
