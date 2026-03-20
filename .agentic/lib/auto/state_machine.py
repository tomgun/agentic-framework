"""
state_machine.py -- Formal state machine for the Agentic Framework's feature lifecycle.

Implements ADR-001 Section 5: a 9-state feature lifecycle with forward transitions,
regression transitions, cascade rules, and advisory mode.

States:
    planned -> specced -> criteria_set -> tests_written -> implementing ->
    verified -> documented -> committed -> shipped
    (+ deprecated as terminal state reachable from any state)

Usage:
    from auto.state_machine import FeatureStateMachine, FeatureState
    sm = FeatureStateMachine(project_root=Path("."))
    ok, msgs = sm.transition("F-0042", FeatureState.IMPLEMENTING)

CLI:
    python -m auto.state_machine F-0042 implementing
    python -m auto.state_machine F-0042 --status
    python -m auto.state_machine F-0042 --next
    python -m auto.state_machine F-0042 --unblocked
"""
from __future__ import annotations

import re
import subprocess
import sys
from enum import Enum
from pathlib import Path
from typing import Callable, Optional

# ---------------------------------------------------------------------------
# Resolve paths.py from the lib/ directory (our parent)
# ---------------------------------------------------------------------------
_LIB_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(_LIB_DIR))
from paths import get_paths  # noqa: E402

from auto.gates import GateResult, register_default_gates  # noqa: E402


# ---------------------------------------------------------------------------
# Feature states
# ---------------------------------------------------------------------------

class FeatureState(Enum):
    """9-state feature lifecycle + deprecated terminal state."""
    PLANNED = "planned"
    SPECCED = "specced"
    CRITERIA_SET = "criteria_set"
    TESTS_WRITTEN = "tests_written"
    IMPLEMENTING = "implementing"
    VERIFIED = "verified"
    DOCUMENTED = "documented"
    COMMITTED = "committed"
    SHIPPED = "shipped"
    DEPRECATED = "deprecated"


# Ordered list for comparison / progression (excludes deprecated)
STATE_ORDER: list[FeatureState] = [
    s for s in FeatureState if s != FeatureState.DEPRECATED
]

# Backward-compatibility aliases: old values -> new states
STATUS_ALIASES: dict[str, FeatureState] = {
    "in_progress": FeatureState.IMPLEMENTING,
    "in-progress": FeatureState.IMPLEMENTING,
}

# All valid status strings (for validation messages)
ALL_VALID_STATUSES: set[str] = (
    {s.value for s in FeatureState} | set(STATUS_ALIASES.keys())
)


# ---------------------------------------------------------------------------
# Transition tables
# ---------------------------------------------------------------------------

FORWARD_TRANSITIONS: set[tuple[FeatureState, FeatureState]] = {
    (FeatureState.PLANNED, FeatureState.SPECCED),
    (FeatureState.SPECCED, FeatureState.CRITERIA_SET),
    (FeatureState.CRITERIA_SET, FeatureState.TESTS_WRITTEN),
    (FeatureState.TESTS_WRITTEN, FeatureState.IMPLEMENTING),
    (FeatureState.IMPLEMENTING, FeatureState.VERIFIED),
    (FeatureState.VERIFIED, FeatureState.DOCUMENTED),
    (FeatureState.DOCUMENTED, FeatureState.COMMITTED),
    (FeatureState.COMMITTED, FeatureState.SHIPPED),
}

REGRESSION_TRANSITIONS: set[tuple[FeatureState, FeatureState]] = {
    (FeatureState.IMPLEMENTING, FeatureState.SPECCED),
    (FeatureState.IMPLEMENTING, FeatureState.CRITERIA_SET),
    (FeatureState.VERIFIED, FeatureState.IMPLEMENTING),
    (FeatureState.VERIFIED, FeatureState.CRITERIA_SET),
    (FeatureState.COMMITTED, FeatureState.IMPLEMENTING),
    (FeatureState.SHIPPED, FeatureState.SPECCED),
}

SKIP_TRANSITIONS: set[tuple[FeatureState, FeatureState]] = {
    # Allow jumping from planned directly to implementing (legacy flow)
    (FeatureState.PLANNED, FeatureState.IMPLEMENTING),
    # Allow planned -> shipped for retroactive tracking
    (FeatureState.PLANNED, FeatureState.SHIPPED),
    # Allow implementing -> shipped (current common flow)
    (FeatureState.IMPLEMENTING, FeatureState.SHIPPED),
    # Allow implementing -> committed
    (FeatureState.IMPLEMENTING, FeatureState.COMMITTED),
}


# ---------------------------------------------------------------------------
# State machine
# ---------------------------------------------------------------------------

class FeatureStateMachine:
    """Formal state machine for feature lifecycle.

    Starts in advisory mode -- logs warnings on invalid transitions
    but doesn't block them. Set enforce=True to block.
    """

    def __init__(self, project_root: Path, enforce: bool = False) -> None:
        self.project_root = project_root.resolve()
        self.paths = get_paths(project_root)
        self.enforce = enforce
        self._gates: dict[tuple[FeatureState, FeatureState], Callable] = {}
        self._v2: object | None = None  # Lazy-init v2 orchestrator
        self._v2_checked: bool = False

    @property
    def _use_v2(self) -> bool:
        """Check if v2 engine is active (cached after first check)."""
        if not self._v2_checked:
            self._v2_checked = True
            try:
                from auto.v2.config import is_v2_engine
                if is_v2_engine(self.project_root):
                    from auto.v2.transitions import TransitionOrchestrator
                    self._v2 = TransitionOrchestrator(self.project_root)
            except Exception:
                pass
        return self._v2 is not None

    # -- Gate registration ---------------------------------------------------

    def register_gate(
        self,
        from_state: FeatureState,
        to_state: FeatureState,
        gate_fn: Callable[[str, Path], GateResult],
    ) -> None:
        """Register a gate function for a specific transition.

        Args:
            from_state: Source state.
            to_state: Target state.
            gate_fn: Callable(feature_id, project_root) -> GateResult.
        """
        self._gates[(from_state, to_state)] = gate_fn

    # -- State resolution ----------------------------------------------------

    @staticmethod
    def resolve_state(status_str: str) -> FeatureState:
        """Resolve a status string to a FeatureState, handling aliases.

        Raises ValueError for unknown status strings.
        """
        normalized = status_str.lower().replace("-", "_").strip()
        if normalized in STATUS_ALIASES:
            return STATUS_ALIASES[normalized]
        try:
            return FeatureState(normalized)
        except ValueError:
            raise ValueError(
                f"Unknown status: '{status_str}'. "
                f"Valid: {', '.join(sorted(ALL_VALID_STATUSES))}"
            )

    # -- Reading current state -----------------------------------------------

    def get_current_state(self, feature_id: str) -> Optional[FeatureState]:
        """Read current state. Uses v2 work item if available, else FEATURES.md."""
        if self._use_v2:
            state = self._get_current_state_v2(feature_id)
            if state is not None:
                return state
        return self._get_current_state_v1(feature_id)

    def _get_current_state_v2(self, feature_id: str) -> Optional[FeatureState]:
        """Read current state from v2 work item, mapping to v1 FeatureState."""
        try:
            from auto.v2 import work_items
            from auto.v2.config import load_config
            if not work_items.exists(self.project_root, feature_id):
                return None
            item = work_items.load(self.project_root, feature_id)
            config = load_config(self.project_root)
            # Reverse-map: v2 state → v1 state (pick most advanced v1 state
            # when multiple map to the same v2 state, e.g. specced+criteria_set→spec)
            reverse_map: dict[str, str] = {}
            for v1, v2 in config.state_mapping.items():
                if v2 not in reverse_map or STATE_ORDER.index(
                    FeatureState(v1)
                ) > STATE_ORDER.index(FeatureState(reverse_map[v2])):
                    reverse_map[v2] = v1
            v1_name = reverse_map.get(item.status)
            if v1_name:
                return self.resolve_state(v1_name)
            # Direct match attempt (e.g. "shipped" → "shipped")
            try:
                return FeatureState(item.status)
            except ValueError:
                return None
        except Exception:
            return None

    def _get_current_state_v1(self, feature_id: str) -> Optional[FeatureState]:
        """Read current state from FEATURES.md (v1 path).

        Parses the feature section and extracts the Status field.
        Returns None if the feature is not found.
        """
        features_file = self.paths.features_file
        if not features_file.exists():
            return None

        content = features_file.read_text()

        # Find the feature section header (e.g. "## F-0042: ...")
        pattern = re.compile(
            rf"^## {re.escape(feature_id)}:.*$", re.MULTILINE
        )
        match = pattern.search(content)
        if not match:
            return None

        # Extract the section (up to the next feature header or end of file)
        section_start = match.end()
        section = content[section_start:]
        next_header = re.search(r"^## F-\d{4,}:", section, re.MULTILINE)
        if next_header:
            section = section[:next_header.start()]

        # Try **Status**: value (markdown bold)
        status_match = re.search(r"\*\*Status\*\*:\s*(\S+)", section)
        if not status_match:
            # Try - Status: value (list format)
            status_match = re.search(r"- Status:\s*(\S+)", section)
        if not status_match:
            return None

        return self.resolve_state(status_match.group(1))

    # -- Transition validity -------------------------------------------------

    @staticmethod
    def is_valid_transition(
        from_state: FeatureState, to_state: FeatureState
    ) -> bool:
        """Check if transition is structurally valid (ignoring gates).

        Any state can transition to deprecated.
        """
        if to_state == FeatureState.DEPRECATED:
            return True
        return (
            (from_state, to_state) in FORWARD_TRANSITIONS
            or (from_state, to_state) in REGRESSION_TRANSITIONS
            or (from_state, to_state) in SKIP_TRANSITIONS
        )

    @staticmethod
    def is_regression(
        from_state: FeatureState, to_state: FeatureState
    ) -> bool:
        """Check if this is a backward (regression) transition."""
        return (from_state, to_state) in REGRESSION_TRANSITIONS

    @staticmethod
    def cascade_invalidations(
        from_state: FeatureState, to_state: FeatureState
    ) -> list[FeatureState]:
        """Return states invalidated by a regression.

        When regressing from *from_state* to *to_state*, all states between
        them (exclusive on both ends) are invalidated and must be re-achieved.
        """
        if (from_state, to_state) not in REGRESSION_TRANSITIONS:
            return []
        try:
            from_idx = STATE_ORDER.index(from_state)
            to_idx = STATE_ORDER.index(to_state)
        except ValueError:
            return []
        # States between to_state and from_state are invalidated
        return STATE_ORDER[to_idx + 1:from_idx]

    # -- Gate checking -------------------------------------------------------

    def check_gate(
        self,
        feature_id: str,
        from_state: FeatureState,
        to_state: FeatureState,
    ) -> GateResult:
        """Check the gate for a transition.

        Returns GateResult. If no gate is registered, allows by default.
        """
        gate_fn = self._gates.get((from_state, to_state))
        if gate_fn is None:
            return GateResult(allowed=True)
        return gate_fn(feature_id, self.project_root)

    # -- Transition logic ----------------------------------------------------

    def can_transition(
        self, feature_id: str, target: FeatureState
    ) -> tuple[bool, list[str]]:
        """Check if a feature can transition to the target state.

        Returns (allowed, messages). In advisory mode invalid transitions
        still return allowed=True with WARNING messages.
        """
        current = self.get_current_state(feature_id)
        if current is None:
            return False, [f"Feature {feature_id} not found in FEATURES.md"]

        if current == target:
            return True, [
                f"Feature {feature_id} already in state '{target.value}' (no-op)"
            ]

        if not self.is_valid_transition(current, target):
            msg = (
                f"Invalid transition: {current.value} -> {target.value} "
                f"for {feature_id}"
            )
            if self.enforce:
                return False, [msg]
            return True, [
                f"WARNING: {msg} (advisory mode -- proceeding anyway)"
            ]

        # Check gate
        gate_result = self.check_gate(feature_id, current, target)

        messages: list[str] = list(gate_result.warnings)
        if not gate_result.allowed:
            if self.enforce:
                return False, gate_result.reasons + gate_result.warnings
            messages.extend([
                f"WARNING: Gate failed: {r} (advisory mode -- proceeding anyway)"
                for r in gate_result.reasons
            ])

        return True, messages

    def transition(
        self,
        feature_id: str,
        target: FeatureState,
        dry_run: bool = False,
        skip_review: bool = False,
    ) -> tuple[bool, list[str]]:
        """Execute a state transition.

        When engine: v2 and a work item exists, delegates to TransitionOrchestrator.
        Otherwise uses v1 path (FEATURES.md via feature.sh).
        Returns (success, messages).
        """
        # v2 delegation: if work item exists, use TransitionOrchestrator
        if self._use_v2 and not dry_run:
            try:
                from auto.v2 import work_items
                from auto.v2.config import load_config
                if work_items.exists(self.project_root, feature_id):
                    config = load_config(self.project_root)
                    # Map v1 FeatureState to v2 state name
                    v2_state = config.resolve_v1_state(target.value)
                    if v2_state:
                        # skip_review maps to force_skip in v2 (bypasses gates)
                        result = self._v2.transition(  # type: ignore[union-attr]
                            feature_id, v2_state, by="agent",
                            force_skip=skip_review,
                        )
                        if result.success:
                            msgs = [f"Transitioned {feature_id}: → {target.value}"]
                            msgs.extend(result.warnings)
                            self._recompute_parent_if_needed(feature_id, msgs)
                            return True, msgs
                        return False, result.errors
            except Exception:
                pass  # Fall through to v1 path

        allowed, messages = self.can_transition(feature_id, target)
        if not allowed:
            return False, messages

        current = self.get_current_state(feature_id)

        # Short-circuit: already in target state — skip review, file write, logs
        if current == target:
            return True, [
                f"Feature {feature_id} already in state '{target.value}' (no-op)"
            ]

        # Review checkpoint: after gates pass, before transition writes
        if not skip_review:
            from auto.review import check_review, check_taste_review, has_pending_review

            if has_pending_review(self.project_root, feature_id, target.value):
                return False, [
                    f"Review pending for {feature_id} → {target.value}. "
                    f"Resolve with: ag review {feature_id} {target.value}"
                ]

            can_proceed, review_msgs = check_review(
                self.project_root, feature_id,
                current.value if current else "unknown", target.value,
            )
            if not can_proceed:
                if dry_run:
                    messages.append(
                        f"DRY RUN: Would block for review ({target.value})"
                    )
                    return True, messages
                return False, review_msgs

            # Taste review piggybacks on code review transitions (F-0183)
            taste_ok, taste_msgs = check_taste_review(
                self.project_root, feature_id,
                current.value if current else "unknown", target.value,
            )
            if taste_msgs:
                messages.extend(taste_msgs)
            if not taste_ok:
                if dry_run:
                    messages.append(
                        f"DRY RUN: Would block for taste review ({target.value})"
                    )
                    return True, messages
                return False, taste_msgs

        # Log regression cascades
        if current and self.is_regression(current, target):
            invalidated = self.cascade_invalidations(current, target)
            if invalidated:
                messages.append(
                    f"Regression cascade: states "
                    f"{[s.value for s in invalidated]} "
                    f"are invalidated and must be re-achieved"
                )

        if dry_run:
            messages.insert(
                0,
                f"DRY RUN: Would transition {feature_id} from "
                f"{current.value if current else '?'} -> {target.value}",
            )
            return True, messages

        # Update FEATURES.md via feature.sh for consistency
        feature_sh = self.paths.tools_dir / "feature.sh"
        result = subprocess.run(
            ["bash", str(feature_sh), feature_id, "status", target.value],
            capture_output=True,
            text=True,
            cwd=str(self.project_root),
        )
        if result.returncode != 0:
            return False, [
                f"Failed to update status: {result.stderr.strip()}"
            ]

        messages.insert(
            0,
            f"Transitioned {feature_id}: "
            f"{current.value if current else '?'} -> {target.value}",
        )

        # Post-transition hook: recompute parent epic status (F-0184)
        self._recompute_parent_if_needed(feature_id, messages)

        return True, messages

    def _recompute_parent_if_needed(
        self, feature_id: str, messages: list[str]
    ) -> None:
        """If this feature has a parent, recompute the parent's derived status."""
        try:
            from auto.epic import _get_feature_parent, recompute_epic_status

            parent_id = _get_feature_parent(
                self.paths.features_file, feature_id
            )
            if parent_id:
                changed, recomp_msgs = recompute_epic_status(
                    self.project_root, parent_id
                )
                messages.extend(recomp_msgs)
        except Exception:
            # Don't let epic recomputation failure block the transition
            pass

    # -- Query helpers -------------------------------------------------------

    def get_next_states(self, feature_id: str) -> list[FeatureState]:
        """Get valid forward transitions for a feature's current state."""
        current = self.get_current_state(feature_id)
        if current is None:
            return []
        return [
            to_state
            for from_state, to_state in FORWARD_TRANSITIONS
            if from_state == current
        ]

    def get_unblocked(
        self,
    ) -> list[tuple[str, FeatureState, list[FeatureState]]]:
        """Find all features with at least one available forward transition.

        Returns list of (feature_id, current_state, available_next_states).
        Skips features already shipped or deprecated.
        """
        features_file = self.paths.features_file
        if not features_file.exists():
            return []

        results: list[tuple[str, FeatureState, list[FeatureState]]] = []
        content = features_file.read_text()

        for match in re.finditer(r"^## (F-\d{4,}):", content, re.MULTILINE):
            fid = match.group(1)
            current = self.get_current_state(fid)
            if current is None:
                continue
            if current in (FeatureState.SHIPPED, FeatureState.DEPRECATED):
                continue
            next_states = self.get_next_states(fid)
            if next_states:
                results.append((fid, current, next_states))

        return results


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------

def main() -> int:
    """CLI for `ag transition F-XXXX <target>`."""
    import argparse

    parser = argparse.ArgumentParser(
        description="Feature state machine transitions"
    )
    parser.add_argument(
        "feature_id",
        nargs="?",
        default=None,
        help="Feature ID (e.g., F-0042)",
    )
    parser.add_argument(
        "target",
        nargs="?",
        help="Target state (e.g., implementing)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Check without executing",
    )
    parser.add_argument(
        "--enforce",
        action="store_true",
        help="Block invalid transitions (default: advisory mode)",
    )
    parser.add_argument(
        "--project-root",
        type=Path,
        default=Path.cwd(),
        help="Project root directory",
    )
    parser.add_argument(
        "--status",
        action="store_true",
        help="Show current state",
    )
    parser.add_argument(
        "--next",
        action="store_true",
        help="Show available forward transitions",
    )
    parser.add_argument(
        "--unblocked",
        action="store_true",
        help="Show all unblocked features",
    )
    args = parser.parse_args()

    sm = FeatureStateMachine(
        project_root=args.project_root, enforce=args.enforce
    )

    # Wire up default gate functions (pass FeatureState to avoid __main__ dual-import)
    register_default_gates(sm, state_enum=FeatureState)

    # --unblocked does not require feature_id
    if args.unblocked:
        unblocked = sm.get_unblocked()
        if not unblocked:
            print("No unblocked features found.")
            return 0
        for fid, current, nexts in unblocked:
            next_str = ", ".join(s.value for s in nexts)
            print(f"  {fid}: {current.value} -> [{next_str}]")
        return 0

    # All other commands need a feature_id
    if not args.feature_id:
        parser.error("feature_id is required (unless using --unblocked)")

    if args.status:
        state = sm.get_current_state(args.feature_id)
        if state is None:
            print(f"Feature {args.feature_id} not found")
            return 1
        print(f"{args.feature_id}: {state.value}")
        return 0

    if args.next:
        nexts = sm.get_next_states(args.feature_id)
        current = sm.get_current_state(args.feature_id)
        if current is None:
            print(f"Feature {args.feature_id} not found")
            return 1
        if not nexts:
            print(
                f"{args.feature_id} ({current.value}): "
                f"no forward transitions available"
            )
            return 0
        print(
            f"{args.feature_id} ({current.value}) -> "
            f"{', '.join(s.value for s in nexts)}"
        )
        return 0

    if not args.target:
        # Show current state + next options
        state = sm.get_current_state(args.feature_id)
        if state is None:
            print(f"Feature {args.feature_id} not found")
            return 1
        nexts = sm.get_next_states(args.feature_id)
        print(f"{args.feature_id}: {state.value}")
        if nexts:
            print(f"  Next: {', '.join(s.value for s in nexts)}")
        return 0

    target = sm.resolve_state(args.target)
    success, messages = sm.transition(
        args.feature_id, target, dry_run=args.dry_run
    )
    for msg in messages:
        print(msg)
    return 0 if success else 1


if __name__ == "__main__":
    sys.exit(main())
