"""
transitions.py — TransitionOrchestrator: the core of the v2 workflow engine.

Atomically runs: validate → check artifacts → check gate → update state.
No escape hatches in formal mode. Audit-logged skips in lean mode.
"""
from __future__ import annotations

import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional

from .config import WorkflowConfig, Transition, load_config
from .preconditions import CheckResult, check_transition_artifacts
from . import work_items


# ---------------------------------------------------------------------------
# Transition result
# ---------------------------------------------------------------------------


@dataclass
class TransitionResult:
    """Result of a transition attempt."""
    success: bool
    from_state: str
    to_state: str
    errors: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)
    skipped: bool = False
    gate_reviewer: Optional[str] = None
    prompt: Optional[str] = None  # Role prompt to emit after transition

    def format(self) -> str:
        """Format result for CLI output."""
        lines = []
        if self.success:
            arrow = f"{self.from_state} → {self.to_state}"
            if self.skipped:
                lines.append(f"⚡ Skipped: {arrow} (audit-logged)")
            else:
                lines.append(f"✅ Transitioned: {arrow}")
            for w in self.warnings:
                lines.append(f"  ⚠️  {w}")
        else:
            lines.append(f"❌ Transition blocked: {self.from_state} → {self.to_state}")
            for e in self.errors:
                lines.append(f"  • {e}")
            for w in self.warnings:
                lines.append(f"  ⚠️  {w}")
        return "\n".join(lines)


# ---------------------------------------------------------------------------
# TransitionOrchestrator
# ---------------------------------------------------------------------------


class TransitionOrchestrator:
    """Orchestrates state transitions with structural enforcement.

    The critical behavior: reads state_machine_af.yaml and REFUSES to
    proceed without required artifacts. The agent's job becomes
    "produce artifacts" not "remember the workflow."
    """

    def __init__(self, project_root: Path, config: Optional[WorkflowConfig] = None):
        self.project_root = project_root.resolve()
        self.config = config or load_config(project_root)

    def transition(
        self,
        feature_id: str,
        target_state: str,
        by: str = "agent",
        reason: Optional[str] = None,
        force_skip: bool = False,
    ) -> TransitionResult:
        """Execute a state transition with full enforcement.

        Steps:
        1. Load work item
        2. Validate transition is structurally valid
        3. Check if this is a skip transition (lean mode only)
        4. Check artifact preconditions
        5. Check gate (human/ai/skip per profile)
        6. Update item.yaml with transition log entry
        7. Return result with optional role prompt

        Args:
            feature_id: The feature to transition.
            target_state: The desired target state.
            by: Who is performing the transition (agent/human/system).
            reason: Why (required for skips and regressions).
            force_skip: If True, attempt skip even if not a defined skip transition.
        """
        # Step 1: Load work item
        try:
            item = work_items.load(self.project_root, feature_id)
        except FileNotFoundError as e:
            return TransitionResult(
                success=False,
                from_state="unknown",
                to_state=target_state,
                errors=[str(e)],
            )

        current_state = item.status

        # Handle deprecated (always allowed from any state)
        if target_state == "deprecated":
            item.add_transition(current_state, target_state, by=by, reason=reason)
            work_items.save(self.project_root, item)
            return TransitionResult(
                success=True,
                from_state=current_state,
                to_state=target_state,
            )

        # Step 2: Validate transition is structurally valid
        transition_def = self.config.get_transition(current_state, target_state)
        is_skip = False
        is_regression = False

        if transition_def:
            is_regression = transition_def.type == "regression"
        elif self.config.is_skip_allowed(item.mode, current_state, target_state):
            is_skip = True
        elif force_skip and item.mode == "lean":
            # Lean mode allows forced skips with audit logging
            is_skip = True
        else:
            # Check if it's a valid state at all
            if not self.config.is_valid_state(target_state):
                return TransitionResult(
                    success=False,
                    from_state=current_state,
                    to_state=target_state,
                    errors=[
                        f"Invalid state: '{target_state}'. "
                        f"Valid states: {', '.join(self.config.states + ['deprecated'])}"
                    ],
                )

            return TransitionResult(
                success=False,
                from_state=current_state,
                to_state=target_state,
                errors=[
                    f"No valid transition from '{current_state}' to '{target_state}'.",
                    f"Mode '{item.mode}' does not allow this skip.",
                    f"Hint: check workflow.transitions and modes.{item.mode}.skip_transitions "
                    f"in state_machine_af.yaml",
                ],
            )

        # Step 3: For skips in lean mode, audit-log but don't block
        # For formal mode, skips are never allowed (escape_hatches: false)
        mode = self.config.modes.get(item.mode)
        if is_skip and mode and not mode.escape_hatches:
            return TransitionResult(
                success=False,
                from_state=current_state,
                to_state=target_state,
                errors=[
                    f"Skip transitions are not allowed in '{item.mode}' mode.",
                    f"Complete the required steps: {current_state} → ... → {target_state}",
                ],
            )

        # Step 4: Check artifact preconditions (unless this is a skip)
        warnings: list[str] = []
        if not is_skip:
            artifact_check = check_transition_artifacts(
                self.project_root, feature_id, target_state,
                self.config, item.mode,
            )
            if not artifact_check.passed:
                # In formal mode: hard block
                if mode and not mode.escape_hatches:
                    return TransitionResult(
                        success=False,
                        from_state=current_state,
                        to_state=target_state,
                        errors=artifact_check.errors,
                        warnings=artifact_check.warnings,
                    )
                else:
                    # In lean mode: warn but allow with audit
                    warnings.extend(artifact_check.warnings)
                    warnings.extend(
                        f"⚠️  Missing artifact (lean mode allows): {e}"
                        for e in artifact_check.errors
                    )

        # Step 5: Check gate (if defined on this transition)
        gate_reviewer = None
        if transition_def and transition_def.gate:
            gate_reviewer = self.config.get_gate_reviewer(
                item.profile, transition_def.gate
            )
            if gate_reviewer == "human":
                # Human gate — we don't block here, the CLI will pause for approval.
                # The transition is recorded; human reviews asynchronously.
                warnings.append(
                    f"Gate '{transition_def.gate}' requires human review "
                    f"(profile: {item.profile})"
                )

        # Step 6: Update item.yaml with transition
        if is_regression and not reason:
            reason = f"Regression: {current_state} → {target_state}"

        item.add_transition(
            current_state, target_state,
            by=by,
            reason=reason,
            skipped=is_skip,
        )
        work_items.save(self.project_root, item)

        # Step 7: Determine role prompt for target state
        prompt = self._get_role_prompt(target_state)

        return TransitionResult(
            success=True,
            from_state=current_state,
            to_state=target_state,
            warnings=warnings,
            skipped=is_skip,
            gate_reviewer=gate_reviewer,
            prompt=prompt,
        )

    def validate(self, feature_id: str) -> CheckResult:
        """Validate all artifacts for a work item's current state.

        Used by `ag check F-XXXX`.
        """
        item = work_items.load(self.project_root, feature_id)
        return check_transition_artifacts(
            self.project_root, feature_id, item.status,
            self.config, item.mode,
        )

    def next_state(self, feature_id: str) -> Optional[str]:
        """Determine the next state for a work item.

        Finds the first forward transition from current state.
        """
        item = work_items.load(self.project_root, feature_id)
        for t in self.config.transitions:
            if t.from_state == item.status and t.type != "regression":
                return t.to_state
        return None

    def can_transition(self, feature_id: str, target_state: str) -> CheckResult:
        """Check if a transition would succeed without executing it.

        Returns CheckResult with errors/warnings.
        """
        try:
            item = work_items.load(self.project_root, feature_id)
        except FileNotFoundError as e:
            return CheckResult.fail([str(e)])

        current_state = item.status

        # Check structural validity
        transition_def = self.config.get_transition(current_state, target_state)
        is_skip = self.config.is_skip_allowed(item.mode, current_state, target_state)

        if not transition_def and not is_skip and target_state != "deprecated":
            return CheckResult.fail([
                f"No valid transition from '{current_state}' to '{target_state}'"
            ])

        # Check artifacts
        if not is_skip:
            return check_transition_artifacts(
                self.project_root, feature_id, target_state,
                self.config, item.mode,
            )

        return CheckResult.ok()

    def _get_role_prompt(self, state: str) -> Optional[str]:
        """Get the role prompt file for a state, if one exists."""
        state_to_prompt = {
            "planning": "planner.md",
            "plan_review": "reviewer.md",
            "spec": "planner.md",
            "implementation": "implementer.md",
            "verification": "verifier.md",
            "docs": "implementer.md",
            "ready_to_ship": "verifier.md",
        }
        prompt_name = state_to_prompt.get(state)
        if not prompt_name:
            return None

        prompt_path = self.project_root / ".agentic" / "prompts" / prompt_name
        if prompt_path.exists():
            return prompt_path.read_text()
        return None
