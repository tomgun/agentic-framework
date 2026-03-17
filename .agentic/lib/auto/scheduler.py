"""
scheduler.py -- Autonomous Scheduler for the Agentic Framework.

Implements F-0186 (ADR-001 Phase 7, Section 3): `AutonomousScheduler` class
that finds unblocked features, spawns component-scoped workers, handles
non-blocking reviews, and repeats until all features are shipped.

Usage:
    from auto.scheduler import AutonomousScheduler
    scheduler = AutonomousScheduler(project_root=Path("."))
    result = scheduler.run(feature_ids=["F-0042", "F-0043"])

    # Or for epic mode:
    result = scheduler.run_epic("F-0100")

CLI:
    ag auto epic F-XXXX    # Start autonomous execution of epic's children
"""
from __future__ import annotations

import json
import re
import subprocess
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional

_LIB_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(_LIB_DIR))
sys.path.insert(0, str(_LIB_DIR / "tools"))
from paths import get_paths  # noqa: E402

from auto.engine import EngineState  # noqa: E402
from auto.task import TaskRunner, TaskResult  # noqa: E402


# ---------------------------------------------------------------------------
# Data types
# ---------------------------------------------------------------------------

@dataclass
class FeatureWork:
    """Tracking state for a feature in the scheduler."""
    feature_id: str
    component: Optional[str] = None
    status: str = "pending"  # pending | working | review_blocked | completed | failed
    review_blocked_at: str = ""  # transition that's blocked (e.g., "committed_to_shipped")
    task_result: Optional[TaskResult] = None
    error: str = ""
    duration_seconds: float = 0.0


@dataclass
class SchedulerResult:
    """Final result of a scheduler run."""
    success: bool
    features_total: int = 0
    features_completed: int = 0
    features_failed: int = 0
    features_review_blocked: int = 0
    features_skipped: int = 0
    feature_work: list[FeatureWork] = field(default_factory=list)
    stopped_reason: str = ""
    integration_result: Optional[dict] = None  # F-0204

    def to_dict(self) -> dict:
        d = {
            "success": self.success,
            "features_total": self.features_total,
            "features_completed": self.features_completed,
            "features_failed": self.features_failed,
            "features_review_blocked": self.features_review_blocked,
            "features_skipped": self.features_skipped,
            "stopped_reason": self.stopped_reason,
            "feature_work": [
                {
                    "feature_id": fw.feature_id,
                    "component": fw.component,
                    "status": fw.status,
                    "review_blocked_at": fw.review_blocked_at,
                    "duration_seconds": round(fw.duration_seconds, 1),
                    "error": fw.error,
                }
                for fw in self.feature_work
            ],
        }
        if self.integration_result:
            d["integration_result"] = self.integration_result
        return d


# ---------------------------------------------------------------------------
# AutonomousScheduler
# ---------------------------------------------------------------------------

class AutonomousScheduler:
    """Autonomous scheduling loop for multi-feature execution.

    Implements ADR-001 Phase 7 Section 3:
    1. Query get_unblocked() — features with available forward transitions
    2. Skip features with pending reviews (non-blocking)
    3. For unblocked features, spawn component-scoped worker
    4. Worker executes next transition
    5. If review checkpoint blocks: record, continue with other features
    6. On escalation: log HUMAN_NEEDED, continue
    7. When all blocked on review: report status and wait
    8. When human resolves: feature unblocks on next iteration
    9. Repeat until all shipped or max errors
    """

    def __init__(
        self,
        project_root: Path,
        claude_command: str = "claude",
        engine_state: Optional[EngineState] = None,
        on_feature_done: Optional[callable] = None,
        poll_interval: float = 10.0,
        max_poll_cycles: int = 360,  # 360 * 10s = 1 hour max wait
        parallel: bool = False,
        max_parallel: int = 0,
        timeout: int = 600,
    ) -> None:
        self.project_root = project_root.resolve()
        self.paths = get_paths(project_root)
        self.claude_command = claude_command
        self.engine_state = engine_state or EngineState()
        self.on_feature_done = on_feature_done
        self.poll_interval = poll_interval
        self.max_poll_cycles = max_poll_cycles
        self.parallel = parallel
        self.max_parallel = max_parallel
        self.timeout = timeout

    # -- Public API --------------------------------------------------------

    def run(
        self,
        feature_ids: list[str],
        max_errors: int = 3,
        skip_pr: bool = False,
    ) -> SchedulerResult:
        """Run the scheduling loop for a set of features.

        Args:
            feature_ids: Feature IDs to schedule.
            max_errors: Stop after this many feature failures.
            skip_pr: Skip PR creation per feature.

        Returns:
            SchedulerResult with per-feature tracking.
        """
        # F-0214: Delegate to parallel dispatcher when --parallel is set
        if self.parallel:
            from auto.parallel import ParallelDispatcher
            max_p = self.max_parallel
            if max_p <= 0:
                from settings import get_setting
                max_p = int(get_setting(
                    self.project_root, "max_parallel_agents", "3",
                ))
            dispatcher = ParallelDispatcher(
                project_root=self.project_root,
                claude_command=self.claude_command,
                max_parallel=max_p,
                timeout=self.timeout,
                skip_pr=skip_pr,
            )
            return dispatcher.run(feature_ids)

        result = SchedulerResult(success=False, features_total=len(feature_ids))
        if not feature_ids:
            result.stopped_reason = "no features to schedule"
            return result

        # Initialize tracking
        work_map: dict[str, FeatureWork] = {}
        for fid in feature_ids:
            fw = FeatureWork(
                feature_id=fid,
                component=self._get_feature_component(fid),
            )
            work_map[fid] = fw
            result.feature_work.append(fw)

        self.engine_state.state = "running"
        error_count = 0

        # Scheduling loop: iterate until all done, all blocked, or stopped
        while True:
            if self._should_stop():
                result.stopped_reason = "stopped by user"
                break

            # Wait while paused
            while self.engine_state.state == "paused":
                time.sleep(0.5)
                if self._should_stop():
                    break
            if self._should_stop():
                result.stopped_reason = "stopped by user"
                break

            # Find actionable features
            actionable = self._get_actionable(work_map, result)
            review_blocked = [
                fw for fw in work_map.values()
                if fw.status == "review_blocked"
            ]

            if not actionable:
                # Check if everything is done
                pending = [
                    fw for fw in work_map.values()
                    if fw.status in ("pending", "working", "review_blocked")
                ]
                if not pending:
                    break  # All done (completed or failed)

                if review_blocked and not any(
                    fw.status in ("pending", "working")
                    for fw in work_map.values()
                ):
                    # AC-007: All remaining features blocked on review
                    resolved = self._wait_for_review_resolution(
                        review_blocked, result,
                    )
                    if not resolved:
                        result.stopped_reason = "all features blocked on human review"
                        break
                    continue  # Re-evaluate after resolution
                else:
                    break  # No actionable work and not all review-blocked

            # Process actionable features
            for fw in actionable:
                if self._should_stop():
                    break
                if error_count >= max_errors:
                    result.stopped_reason = f"max errors reached ({max_errors})"
                    break

                fw.status = "working"
                start = time.time()

                try:
                    task_result = self._run_feature(fw, skip_pr=skip_pr)
                    fw.task_result = task_result
                    fw.duration_seconds += time.time() - start

                    if task_result.success:
                        fw.status = "completed"
                        result.features_completed += 1
                    else:
                        # Check if blocked on review
                        if self._is_review_blocked(fw.feature_id):
                            fw.status = "review_blocked"
                            fw.review_blocked_at = self._get_blocked_transition(
                                fw.feature_id,
                            )
                            # AC-006: log escalation if review was created
                            self._handle_escalation(
                                fw.feature_id,
                                f"blocked at {fw.review_blocked_at}",
                            )
                        else:
                            fw.status = "failed"
                            result.features_failed += 1
                            error_count += 1
                except Exception as e:
                    fw.duration_seconds += time.time() - start
                    fw.status = "failed"
                    fw.error = str(e)
                    result.features_failed += 1
                    error_count += 1

                if self.on_feature_done:
                    self.on_feature_done(fw)

                self._save_progress(result)

            if error_count >= max_errors:
                result.stopped_reason = f"max errors reached ({max_errors})"
                break

        # Mark remaining pending features as skipped
        for fw in work_map.values():
            if fw.status == "pending":
                fw.status = "skipped"
                result.features_skipped += 1

        # Final counts for review-blocked
        result.features_review_blocked = sum(
            1 for fw in work_map.values() if fw.status == "review_blocked"
        )

        result.success = (
            result.features_completed == result.features_total
        )
        self.engine_state.state = "stopped"
        self._save_progress(result)
        return result

    def run_epic(
        self,
        epic_id: str,
        max_errors: int = 3,
        skip_pr: bool = False,
    ) -> SchedulerResult:
        """Run autonomous execution for an epic's child features.

        Reads children from FEATURES.md, filters to non-shipped, and
        schedules them.

        Args:
            epic_id: Epic feature ID (e.g., "F-0100").
            max_errors: Stop after this many feature failures.
            skip_pr: Skip PR creation per feature.

        Returns:
            SchedulerResult.
        """
        children = self._get_epic_children(epic_id)
        if not children:
            return SchedulerResult(
                success=False,
                stopped_reason=f"no unshipped children found for {epic_id}",
            )
        result = self.run(
            feature_ids=children,
            max_errors=max_errors,
            skip_pr=skip_pr,
        )

        # F-0204: Post-completion integration verification hook
        if result.success:
            iv_result = self._run_integration_verify(epic_id)
            if iv_result and not iv_result.success and not iv_result.skipped:
                result.success = False
                result.stopped_reason = (
                    f"Integration verification failed for {epic_id}"
                )
                result.integration_result = iv_result.to_dict()

        return result

    # -- Feature execution -------------------------------------------------

    def _run_feature(
        self,
        fw: FeatureWork,
        skip_pr: bool = False,
    ) -> TaskResult:
        """Run a single feature via TaskRunner with component scoping.

        AC-003: When a feature has a component, the worker is scoped to that
        component's path via the component registry. This narrows the context
        the worker agent sees.

        F-0187: For cross-repo components (repo field set), uses
        resolve_umbrella() for availability checking and clone instructions.
        """
        # Resolve component-scoped project root if component is set
        work_root = self.project_root
        if fw.component:
            from auto.components import load_registry
            registry = load_registry(self.project_root)
            comp = registry.get(fw.component)
            if comp:
                if comp.repo:
                    # F-0187: Cross-repo component — use umbrella resolution
                    from auto.umbrella import resolve_umbrella
                    umbrella = resolve_umbrella(self.project_root)
                    if umbrella and umbrella.missing_repos:
                        prefix = f"Component '{comp.name}':"
                        missing_for_comp = [
                            m for m in umbrella.missing_repos
                            if prefix in m
                        ]
                        if missing_for_comp:
                            return TaskResult(
                                success=False,
                                error=missing_for_comp[0],
                            )
                    if umbrella:
                        from auto.umbrella import get_component_root
                        resolved = get_component_root(umbrella, fw.component)
                        if resolved:
                            work_root = resolved
                else:
                    comp_path = self.project_root / comp.path
                    if comp_path.is_dir():
                        work_root = comp_path

        runner = TaskRunner(
            project_root=work_root,
            claude_command=self.claude_command,
        )
        return runner.run(
            feature_id=fw.feature_id,
            skip_pr=skip_pr,
        )

    # -- Scheduling helpers ------------------------------------------------

    def _get_actionable(
        self, work_map: dict[str, FeatureWork],
        result: SchedulerResult,
    ) -> list[FeatureWork]:
        """Find features that can make progress now.

        Actionable = pending AND not review-blocked AND has unblocked
        transitions in the state machine.

        Side effects: marks already-shipped features as completed and
        increments result.features_completed for accurate counts.
        """
        from auto.state_machine import FeatureStateMachine, FeatureState

        sm = FeatureStateMachine(project_root=self.project_root)
        actionable = []

        for fid, fw in work_map.items():
            if fw.status != "pending":
                continue

            # Check for pending reviews (AC-002: non-blocking)
            if self._is_review_blocked(fid):
                fw.status = "review_blocked"
                fw.review_blocked_at = self._get_blocked_transition(fid)
                continue

            # Check state machine for unblocked transitions
            current = sm.get_current_state(fid)
            if current is None:
                continue
            if current in (FeatureState.SHIPPED, FeatureState.DEPRECATED):
                fw.status = "completed"
                result.features_completed += 1
                continue

            next_states = sm.get_next_states(fid)
            if next_states:
                actionable.append(fw)

        return actionable

    def _is_review_blocked(self, feature_id: str) -> bool:
        """Check if a feature has any pending reviews."""
        from auto.review import get_pending_reviews
        reviews = get_pending_reviews(self.project_root, feature_id)
        return len(reviews) > 0

    def _get_blocked_transition(self, feature_id: str) -> str:
        """Get the transition that's blocked on review."""
        from auto.review import get_pending_reviews
        reviews = get_pending_reviews(self.project_root, feature_id)
        if reviews:
            r = reviews[0]
            return f"{r.get('from_state', '?')}_to_{r.get('to_state', '?')}"
        return ""

    # -- AC-007/AC-008: Review wait and resolution -------------------------

    def _wait_for_review_resolution(
        self,
        blocked: list[FeatureWork],
        result: SchedulerResult,
    ) -> bool:
        """Wait for at least one review to be resolved.

        AC-007: Reports status when all features are review-blocked.
        AC-008: When human resolves, scheduler picks up the feature again.

        Returns True if a review was resolved, False if timed out.
        """
        print(
            f"\nAll {len(blocked)} remaining features blocked on review:",
            file=sys.stderr,
        )
        for fw in blocked:
            print(
                f"  {fw.feature_id}: waiting at {fw.review_blocked_at}",
                file=sys.stderr,
            )
        print(
            f"\nPolling for review resolution (every {self.poll_interval}s)...",
            file=sys.stderr,
        )

        for cycle in range(self.max_poll_cycles):
            if self._should_stop():
                return False

            time.sleep(self.poll_interval)

            # Check if any review has been resolved
            for fw in blocked:
                if not self._is_review_blocked(fw.feature_id):
                    # AC-008: Review resolved — feature is unblocked
                    fw.status = "pending"
                    fw.review_blocked_at = ""
                    print(
                        f"\n  {fw.feature_id}: review resolved, resuming",
                        file=sys.stderr,
                    )
                    return True

        return False

    # -- AC-006: Escalation handling ---------------------------------------

    def _handle_escalation(
        self, feature_id: str, reason: str,
    ) -> None:
        """Log escalation and create HUMAN_NEEDED entry.

        Called when the critical agent escalates a review. The scheduler
        continues with other features (non-blocking).
        """
        blocker_sh = self.paths.tools_dir / "blocker.sh"
        if blocker_sh.exists():
            try:
                subprocess.run(
                    [
                        "bash", str(blocker_sh), "add",
                        f"Escalation: {feature_id}",
                        "decision",
                        f"Critical agent escalated: {reason}. "
                        f"Resolve with: ag review {feature_id}",
                    ],
                    capture_output=True, text=True,
                    cwd=str(self.project_root),
                )
            except (OSError, subprocess.SubprocessError):
                pass

    # -- Component scoping (AC-003) ----------------------------------------

    def _get_feature_component(self, feature_id: str) -> Optional[str]:
        """Get the component for a feature from FEATURES.md."""
        features_file = self.paths.features_file
        if not features_file.exists():
            return None

        content = features_file.read_text()
        pattern = re.compile(
            rf"^## {re.escape(feature_id)}:.*$", re.MULTILINE,
        )
        match = pattern.search(content)
        if not match:
            return None

        # Extract section
        section = content[match.end():]
        next_header = re.search(r"^## F-\d{4,}:", section, re.MULTILINE)
        if next_header:
            section = section[:next_header.start()]

        comp_match = re.search(r"\*\*Component\*\*:\s*(\S+)", section)
        return comp_match.group(1) if comp_match else None

    # -- Epic children (AC-005) --------------------------------------------

    def _get_epic_children(self, epic_id: str) -> list[str]:
        """Get non-shipped child feature IDs for an epic."""
        features_file = self.paths.features_file
        if not features_file.exists():
            return []

        content = features_file.read_text()
        from query_features import parse_features, get_children

        features = parse_features(content)
        children = get_children(features, epic_id)

        return [
            c["id"] for c in children
            if c.get("status") not in ("shipped", "deprecated")
        ]

    # -- Integration verification (F-0204) ---------------------------------

    def _run_integration_verify(self, epic_id: str):
        """Run integration verification for an epic after all children complete.

        Returns IntegrationResult. On error, returns a failed result (fail-closed)
        rather than None — prevents silent bypass of the verification gate.
        """
        try:
            from auto.integration_verify import run_integration_verify, IntegrationResult
            return run_integration_verify(
                self.project_root,
                epic_id,
                claude_command=self.claude_command,
            )
        except Exception as e:
            print(
                f"  ERROR: Integration verification failed for {epic_id}: {e}",
                file=sys.stderr,
            )
            from auto.integration_verify import IntegrationResult
            return IntegrationResult(
                epic_id=epic_id,
                success=False,
                error=f"Verification error: {e}",
            )

    # -- Engine control helpers --------------------------------------------

    def _should_stop(self) -> bool:
        return self.engine_state.state == "stopping"

    # -- Progress persistence ----------------------------------------------

    def _save_progress(self, result: SchedulerResult) -> None:
        """Save scheduler progress to session state."""
        state_file = self.paths.session_dir / "scheduler-state.json"
        self.paths.session_dir.mkdir(parents=True, exist_ok=True)
        state = result.to_dict()
        state["updated_at"] = time.time()
        tmp = state_file.with_suffix(".tmp")
        tmp.write_text(json.dumps(state, indent=2) + "\n")
        tmp.rename(state_file)


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------

def main() -> int:
    """Entry point for `ag auto epic F-XXXX`."""
    import argparse

    parser = argparse.ArgumentParser(
        description="Autonomous scheduler for epic execution"
    )
    parser.add_argument(
        "epic_id",
        help="Epic feature ID (e.g., F-0100)",
    )
    parser.add_argument(
        "--max-errors",
        type=int,
        default=3,
        help="Stop after N feature failures (default: 3)",
    )
    parser.add_argument(
        "--project-root",
        type=Path,
        default=Path.cwd(),
        help="Project root directory",
    )
    parser.add_argument(
        "--skip-pr",
        action="store_true",
        help="Skip PR creation per feature",
    )
    parser.add_argument(
        "--parallel",
        action="store_true",
        help="Execute children in parallel worktrees (F-0214)",
    )
    parser.add_argument(
        "--max-parallel",
        type=int,
        default=0,
        help="Max concurrent agents (default: max_parallel_agents setting or 3)",
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=600,
        help="Per-feature timeout in seconds (default: 600)",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Output result as JSON",
    )
    args = parser.parse_args()

    def print_feature(fw: FeatureWork) -> None:
        status_map = {
            "completed": "DONE",
            "failed": "FAIL",
            "review_blocked": "WAIT",
        }
        mark = status_map.get(fw.status, fw.status.upper())
        comp_str = f" [{fw.component}]" if fw.component else ""
        print(
            f"  [{fw.feature_id}]{comp_str} {mark} "
            f"({fw.duration_seconds:.1f}s)"
        )

    scheduler = AutonomousScheduler(
        project_root=args.project_root,
        on_feature_done=None if args.json else print_feature,
        parallel=args.parallel,
        max_parallel=args.max_parallel,
        timeout=args.timeout,
    )

    if not args.json:
        print(f"Autonomous scheduler: epic {args.epic_id}")
        print()

    result = scheduler.run_epic(
        epic_id=args.epic_id,
        max_errors=args.max_errors,
        skip_pr=args.skip_pr,
    )

    if args.json:
        print(json.dumps(result.to_dict(), indent=2))
    else:
        print()
        if result.success:
            print(f"All {result.features_completed} features completed.")
        else:
            parts = []
            if result.features_completed:
                parts.append(f"{result.features_completed} completed")
            if result.features_failed:
                parts.append(f"{result.features_failed} failed")
            if result.features_review_blocked:
                parts.append(f"{result.features_review_blocked} awaiting review")
            if result.features_skipped:
                parts.append(f"{result.features_skipped} skipped")
            print(
                f"{result.features_total} features: "
                + ", ".join(parts) + "."
            )
            if result.stopped_reason:
                print(f"Stopped: {result.stopped_reason}")

    return 0 if result.success else 1


if __name__ == "__main__":
    sys.exit(main())
