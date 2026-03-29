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
        (root / ".agentic" / "spec" / "contracts").mkdir(parents=True)
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
    def test_all_ten_states_plus_deprecated(self):
        assert len(FeatureState) == 11
        expected = {
            "planned", "designed", "specced", "criteria_set", "tests_written",
            "implementing", "verified", "documented", "committed",
            "shipped", "deprecated",
        }
        assert {s.value for s in FeatureState} == expected

    def test_state_order_excludes_deprecated(self):
        assert FeatureState.DEPRECATED not in STATE_ORDER
        assert len(STATE_ORDER) == 10
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
        """Each sequential pair in STATE_ORDER is a forward transition."""
        # 9 sequential pairs + 1 non-sequential (planned -> specced) = 10
        assert len(FORWARD_TRANSITIONS) == 10
        for i in range(len(STATE_ORDER) - 1):
            assert (STATE_ORDER[i], STATE_ORDER[i + 1]) in FORWARD_TRANSITIONS
        # Also: planned -> specced (non-sequential, gate-controlled)
        assert (FeatureState.PLANNED, FeatureState.SPECCED) in FORWARD_TRANSITIONS

    def test_regression_transitions_go_backward(self):
        for from_state, to_state in REGRESSION_TRANSITIONS:
            from_idx = STATE_ORDER.index(from_state)
            to_idx = STATE_ORDER.index(to_state)
            assert from_idx > to_idx, (
                f"Regression {from_state.value} -> {to_state.value} "
                f"is not backward"
            )

    def test_skip_transitions_exist(self):
        assert len(SKIP_TRANSITIONS) >= 5
        # designed -> implementing (lean workflow)
        assert (FeatureState.DESIGNED, FeatureState.IMPLEMENTING) in SKIP_TRANSITIONS
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
    """Tests for state_enforcement=blocking mode (F-0222).

    Verifies that enforce=True makes gate failures block transitions,
    while enforce=False (advisory) warns but allows them.
    """

    def test_gate_failure_blocks_when_enforce_true(self, project_dir):
        """AC1: Gate failure blocks transition in enforce mode."""
        write_features(project_dir, [("F-0042", "Test", "planned")])
        sm = FeatureStateMachine(project_root=project_dir, enforce=True)

        def blocking_gate(fid, root):
            return GateResult(allowed=False, reasons=["AC file missing"], warnings=[])

        sm.register_gate(FeatureState.PLANNED, FeatureState.SPECCED, blocking_gate)
        allowed, msgs = sm.can_transition("F-0042", FeatureState.SPECCED)
        assert not allowed
        assert any("AC file missing" in m for m in msgs)

    def test_gate_failure_advisory_when_enforce_false(self, project_dir):
        """AC1 inverse: Gate failure is advisory when enforce=False."""
        write_features(project_dir, [("F-0042", "Test", "planned")])
        sm = FeatureStateMachine(project_root=project_dir, enforce=False)

        def blocking_gate(fid, root):
            return GateResult(allowed=False, reasons=["AC file missing"], warnings=[])

        sm.register_gate(FeatureState.PLANNED, FeatureState.SPECCED, blocking_gate)
        allowed, msgs = sm.can_transition("F-0042", FeatureState.SPECCED)
        assert allowed  # advisory lets it through

    def test_skip_transitions_work_with_enforce(self, project_dir):
        """AC4: SKIP_TRANSITIONS are valid transitions in blocking mode.

        Skip transitions pass is_valid_transition() so they aren't rejected
        as invalid. Gates still apply — but the transition itself is allowed.
        """
        write_features(project_dir, [("F-0042", "Test", "planned")])
        sm = FeatureStateMachine(project_root=project_dir, enforce=True)

        # No gate registered — skip transition should succeed
        allowed, msgs = sm.can_transition("F-0042", FeatureState.IMPLEMENTING)
        assert allowed

    def test_skip_transition_planned_to_shipped_with_enforce(self, project_dir):
        """AC4: planned->shipped (retroactive tracking) works in blocking mode."""
        write_features(project_dir, [("F-0042", "Test", "planned")])
        sm = FeatureStateMachine(project_root=project_dir, enforce=True)
        allowed, msgs = sm.can_transition("F-0042", FeatureState.SHIPPED)
        assert allowed

    def test_error_messages_contain_gate_reason(self, project_dir):
        """AC5: Blocked transition output includes gate failure reason."""
        write_features(project_dir, [("F-0042", "Test", "planned")])
        sm = FeatureStateMachine(project_root=project_dir, enforce=True)

        def blocking_gate(fid, root):
            return GateResult(
                allowed=False,
                reasons=["Contract file not found"],
                warnings=["Consider creating spec/contracts/F-0042.yaml"],
            )

        sm.register_gate(FeatureState.PLANNED, FeatureState.SPECCED, blocking_gate)
        allowed, msgs = sm.can_transition("F-0042", FeatureState.SPECCED)
        assert not allowed
        assert any("Contract file not found" in m for m in msgs)

    def test_existing_feature_not_retroactively_broken(self, project_dir):
        """AC7: Feature already at implementing with no AC file is not broken.

        Enforcement is forward-looking: it only blocks when attempting a NEW
        transition. An existing feature at implementing (even with missing AC)
        can still be read, and attempting a forward transition may fail on
        gates but doesn't corrupt the feature's state.
        """
        write_features(project_dir, [("F-0042", "Test", "implementing")])
        # No acceptance criteria file created
        sm = FeatureStateMachine(project_root=project_dir, enforce=True)

        # Reading state works fine — no retroactive validation
        state = sm.get_current_state("F-0042")
        assert state == FeatureState.IMPLEMENTING

        # Attempting a forward transition may fail on gate, but doesn't corrupt state
        allowed, msgs = sm.can_transition("F-0042", FeatureState.SHIPPED)
        # implementing->shipped is a SKIP_TRANSITION, should succeed
        assert allowed

        # Feature state is still readable and unchanged after the check
        state_after = sm.get_current_state("F-0042")
        assert state_after == FeatureState.IMPLEMENTING

    def test_invalid_transition_blocked_in_enforce_mode(self, project_dir):
        """AC1/AC2: Invalid transitions (shipped->planned) blocked in enforce mode."""
        write_features(project_dir, [("F-0042", "Test", "shipped")])
        sm = FeatureStateMachine(project_root=project_dir, enforce=True)
        allowed, msgs = sm.can_transition("F-0042", FeatureState.PLANNED)
        assert not allowed
        assert any("Invalid transition" in m for m in msgs)


# ---------------------------------------------------------------------------
# V2 adapter tests
# ---------------------------------------------------------------------------


class TestStateMachineFeaturesMd:
    """Test FeatureStateMachine reads state from FEATURES.md."""

    def test_get_current_state(self, project_dir):
        """State reads from FEATURES.md."""
        write_features(project_dir, [("F-0099", "Test feature", "implementing")])
        sm = FeatureStateMachine(project_root=project_dir, enforce=False)
        state = sm.get_current_state("F-0099")
        assert state == FeatureState.IMPLEMENTING

    def test_shipped_feature(self, project_dir):
        """Shipped features read correctly from FEATURES.md."""
        write_features(project_dir, [("F-0042", "Old feature", "shipped")])
        sm = FeatureStateMachine(project_root=project_dir, enforce=False)
        state = sm.get_current_state("F-0042")
        assert state == FeatureState.SHIPPED

    def test_transition_from_planned(self, project_dir):
        """Can transition from planned to specced."""
        write_features(project_dir, [("F-0100", "Test transition", "planned")])
        sm = FeatureStateMachine(project_root=project_dir, enforce=False)
        allowed, msgs = sm.can_transition("F-0100", FeatureState.SPECCED)
        assert allowed


# ---------------------------------------------------------------------------
# Designed state (F-004 improvement: design phase formalization)
# ---------------------------------------------------------------------------

def _set_design_phase(root: Path, value: str) -> None:
    """Override design_phase setting in STACK.md."""
    stack = root / "STACK.md"
    stack.write_text(f"## Settings\n- profile: formal\n- design_phase: {value}\n")


class TestDesignedState:
    """Tests for the optional designed state between planned and specced."""

    def test_designed_in_state_order(self):
        """DESIGNED is between PLANNED and SPECCED in STATE_ORDER."""
        idx_p = STATE_ORDER.index(FeatureState.PLANNED)
        idx_d = STATE_ORDER.index(FeatureState.DESIGNED)
        idx_s = STATE_ORDER.index(FeatureState.SPECCED)
        assert idx_p < idx_d < idx_s

    def test_planned_to_designed_valid(self):
        """planned -> designed is a valid forward transition."""
        assert (FeatureState.PLANNED, FeatureState.DESIGNED) in FORWARD_TRANSITIONS

    def test_designed_to_specced_valid(self):
        """designed -> specced is a valid forward transition."""
        assert (FeatureState.DESIGNED, FeatureState.SPECCED) in FORWARD_TRANSITIONS

    def test_planned_to_specced_still_valid_when_off(self, project_dir):
        """planned -> specced still works when design_phase is off (default)."""
        write_features(project_dir, [("F-0050", "Test", "planned")])
        sm = FeatureStateMachine(project_root=project_dir, enforce=True)
        from auto.gates import register_default_gates
        register_default_gates(sm, FeatureState)
        allowed, msgs = sm.can_transition("F-0050", FeatureState.SPECCED)
        assert allowed, f"Expected allowed but got: {msgs}"

    def test_planned_to_specced_blocked_when_required(self, project_dir):
        """planned -> specced blocked when design_phase is required."""
        _set_design_phase(project_dir, "required")
        write_features(project_dir, [("F-0050", "Test", "planned")])
        sm = FeatureStateMachine(project_root=project_dir, enforce=True)
        from auto.gates import register_default_gates
        register_default_gates(sm, FeatureState)
        allowed, msgs = sm.can_transition("F-0050", FeatureState.SPECCED)
        assert not allowed
        assert any("design_phase is required" in m for m in msgs)

    def test_planned_to_designed_blocked_when_off(self, project_dir):
        """planned -> designed blocked when design_phase is off."""
        write_features(project_dir, [("F-0050", "Test", "planned")])
        sm = FeatureStateMachine(project_root=project_dir, enforce=True)
        from auto.gates import register_default_gates
        register_default_gates(sm, FeatureState)
        allowed, msgs = sm.can_transition("F-0050", FeatureState.DESIGNED)
        assert not allowed
        assert any("design_phase is off" in m for m in msgs)

    def test_planned_to_designed_allowed_when_optional(self, project_dir):
        """planned -> designed allowed when design_phase is optional."""
        _set_design_phase(project_dir, "optional")
        write_features(project_dir, [("F-0050", "Test", "planned")])
        sm = FeatureStateMachine(project_root=project_dir, enforce=True)
        from auto.gates import register_default_gates
        register_default_gates(sm, FeatureState)
        allowed, msgs = sm.can_transition("F-0050", FeatureState.DESIGNED)
        assert allowed, f"Expected allowed but got: {msgs}"

    def test_planned_to_designed_allowed_when_required(self, project_dir):
        """planned -> designed allowed when design_phase is required."""
        _set_design_phase(project_dir, "required")
        write_features(project_dir, [("F-0050", "Test", "planned")])
        sm = FeatureStateMachine(project_root=project_dir, enforce=True)
        from auto.gates import register_default_gates
        register_default_gates(sm, FeatureState)
        allowed, msgs = sm.can_transition("F-0050", FeatureState.DESIGNED)
        assert allowed, f"Expected allowed but got: {msgs}"

    def test_design_gate_checks_artifacts(self, project_dir):
        """designed -> specced passes with a design.md artifact."""
        _set_design_phase(project_dir, "required")
        write_features(project_dir, [("F-0050", "Test", "designed")])
        # Create design artifact
        work_dir = project_dir / ".agentic" / "work" / "F-0050"
        work_dir.mkdir(parents=True)
        (work_dir / "design.md").write_text("# Design for F-0050\n")
        sm = FeatureStateMachine(project_root=project_dir, enforce=True)
        from auto.gates import register_default_gates
        register_default_gates(sm, FeatureState)
        allowed, msgs = sm.can_transition("F-0050", FeatureState.SPECCED)
        assert allowed, f"Expected allowed but got: {msgs}"

    def test_design_gate_checks_adr_artifact(self, project_dir):
        """designed -> specced passes with an ADR referencing the feature."""
        _set_design_phase(project_dir, "required")
        write_features(project_dir, [("F-0050", "Test", "designed")])
        # Create ADR artifact
        adr_dir = project_dir / ".agentic" / "spec" / "adr"
        adr_dir.mkdir(parents=True)
        (adr_dir / "ADR-001.md").write_text("# ADR-001\nRelates to F-0050\n")
        sm = FeatureStateMachine(project_root=project_dir, enforce=True)
        from auto.gates import register_default_gates
        register_default_gates(sm, FeatureState)
        allowed, msgs = sm.can_transition("F-0050", FeatureState.SPECCED)
        assert allowed, f"Expected allowed but got: {msgs}"

    def test_design_gate_blocks_without_artifacts(self, project_dir):
        """designed -> specced blocked without design artifacts."""
        _set_design_phase(project_dir, "required")
        write_features(project_dir, [("F-0050", "Test", "designed")])
        sm = FeatureStateMachine(project_root=project_dir, enforce=True)
        from auto.gates import register_default_gates
        register_default_gates(sm, FeatureState)
        allowed, msgs = sm.can_transition("F-0050", FeatureState.SPECCED)
        assert not allowed
        assert any("No design artifact" in m for m in msgs)

    def test_regression_specced_to_designed(self):
        """specced -> designed is a valid regression."""
        assert (FeatureState.SPECCED, FeatureState.DESIGNED) in REGRESSION_TRANSITIONS

    def test_regression_implementing_to_designed(self):
        """implementing -> designed is a valid regression."""
        assert (FeatureState.IMPLEMENTING, FeatureState.DESIGNED) in REGRESSION_TRANSITIONS

    def test_skip_designed_to_implementing(self):
        """designed -> implementing is a valid skip transition."""
        assert (FeatureState.DESIGNED, FeatureState.IMPLEMENTING) in SKIP_TRANSITIONS

    def test_get_next_states_off_hides_designed(self, project_dir):
        """get_next_states excludes designed when design_phase is off."""
        write_features(project_dir, [("F-0050", "Test", "planned")])
        sm = FeatureStateMachine(project_root=project_dir, enforce=False)
        next_states = sm.get_next_states("F-0050")
        assert FeatureState.DESIGNED not in next_states
        assert FeatureState.SPECCED in next_states

    def test_get_next_states_optional_shows_both(self, project_dir):
        """get_next_states shows both designed and specced when optional."""
        _set_design_phase(project_dir, "optional")
        write_features(project_dir, [("F-0050", "Test", "planned")])
        sm = FeatureStateMachine(project_root=project_dir, enforce=False)
        next_states = sm.get_next_states("F-0050")
        assert FeatureState.DESIGNED in next_states
        assert FeatureState.SPECCED in next_states

    def test_get_next_states_required_hides_specced(self, project_dir):
        """get_next_states hides specced from planned when required."""
        _set_design_phase(project_dir, "required")
        write_features(project_dir, [("F-0050", "Test", "planned")])
        sm = FeatureStateMachine(project_root=project_dir, enforce=False)
        next_states = sm.get_next_states("F-0050")
        assert FeatureState.DESIGNED in next_states
        assert FeatureState.SPECCED not in next_states

    def test_contract_roundtrip_designed(self, project_dir):
        """Designed state survives contract lifecycle round-trip."""
        from auto.state_machine import LIFECYCLE_TO_STATE, STATE_TO_LIFECYCLE
        # designed -> "designing" lifecycle
        assert STATE_TO_LIFECYCLE[FeatureState.DESIGNED] == "designing"
        # "designing" lifecycle -> DESIGNED state
        assert LIFECYCLE_TO_STATE["designing"] == FeatureState.DESIGNED

    def test_cascade_implementing_to_specced_excludes_designed(self):
        """Regression implementing->specced does NOT invalidate designed.

        designed is at index 1 (before specced at index 2), so it is outside
        the invalidation range between source and target.
        """
        sm = FeatureStateMachine(project_root=Path("."), enforce=False)
        invalidated = sm.cascade_invalidations(
            FeatureState.IMPLEMENTING, FeatureState.SPECCED
        )
        assert FeatureState.DESIGNED not in invalidated
        # But criteria_set and tests_written should be invalidated
        assert FeatureState.CRITERIA_SET in invalidated
        assert FeatureState.TESTS_WRITTEN in invalidated
