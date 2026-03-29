"""
crunch.py -- Autonomous multi-feature batch mode (F-0163).

Now backed by AutonomousScheduler (F-0186) for non-blocking review handling,
component-scoped workers, and intelligent scheduling. CrunchRunner delegates
to the scheduler and adapts the result to the CrunchResult format for
backward compatibility.

Usage:
    from auto.crunch import CrunchRunner
    runner = CrunchRunner(project_root=Path("."))
    result = runner.run()
"""
from __future__ import annotations

import json
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional

_LIB_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(_LIB_DIR))
from paths import get_paths  # noqa: E402
from ids import FEATURE_HEADER_RE  # noqa: E402

from auto.engine import EngineState  # noqa: E402
from auto.task import TaskRunner  # noqa: E402 — used by scheduler, kept for traceability
from auto.scheduler import AutonomousScheduler, SchedulerResult  # noqa: E402


@dataclass
class FeatureBatchResult:
    """Result for one feature in the batch."""
    feature_id: str
    status: str = "pending"  # pending | completed | failed | skipped
    acs_passed: int = 0
    acs_total: int = 0
    pr_url: str = ""
    duration_seconds: float = 0.0
    error: str = ""


@dataclass
class CrunchResult:
    """Final result of a crunch batch run."""
    success: bool
    features_total: int = 0
    features_completed: int = 0
    features_failed: int = 0
    features_skipped: int = 0
    feature_results: list[FeatureBatchResult] = field(default_factory=list)
    stopped_reason: str = ""

    def to_dict(self) -> dict:
        return {
            "success": self.success,
            "features_total": self.features_total,
            "features_completed": self.features_completed,
            "features_failed": self.features_failed,
            "features_skipped": self.features_skipped,
            "stopped_reason": self.stopped_reason,
            "feature_results": [
                {
                    "feature_id": r.feature_id,
                    "status": r.status,
                    "acs_passed": r.acs_passed,
                    "acs_total": r.acs_total,
                    "pr_url": r.pr_url,
                    "duration_seconds": round(r.duration_seconds, 1),
                }
                for r in self.feature_results
            ],
        }


def _scheduler_to_crunch_result(sr: SchedulerResult) -> CrunchResult:
    """Convert SchedulerResult to CrunchResult for backward compatibility."""
    cr = CrunchResult(
        success=sr.success,
        features_total=sr.features_total,
        features_completed=sr.features_completed,
        features_failed=sr.features_failed,
        # review_blocked treated as skipped in crunch's simpler model
        features_skipped=sr.features_skipped + sr.features_review_blocked,
        stopped_reason=sr.stopped_reason,
    )
    for fw in sr.feature_work:
        status_map = {
            "completed": "completed",
            "failed": "failed",
            "review_blocked": "skipped",
            "skipped": "skipped",
            "pending": "pending",
            "working": "pending",
        }
        tr = fw.task_result
        cr.feature_results.append(FeatureBatchResult(
            feature_id=fw.feature_id,
            status=status_map.get(fw.status, fw.status),
            acs_passed=tr.acs_passed if tr else 0,
            acs_total=tr.acs_total if tr else 0,
            pr_url=tr.pr_url if tr else "",
            duration_seconds=fw.duration_seconds,
            error=fw.error,
        ))
    return cr


class CrunchRunner:
    """Multi-feature batch orchestrator.

    Delegates to AutonomousScheduler (F-0186) for the scheduling loop,
    which provides non-blocking review handling, component-scoped workers,
    and intelligent feature ordering.

    Engine control (engine_state "stopping" / "paused") is passed through
    to the scheduler, which respects pause/stop signals.

    Backward compatible: same constructor, same run() signature, same
    CrunchResult output.
    """

    def __init__(
        self,
        project_root: Path,
        claude_command: str = "claude",
        engine_state: Optional[EngineState] = None,
        on_feature_done: Optional[callable] = None,
    ) -> None:
        self.project_root = project_root.resolve()
        self.paths = get_paths(project_root)
        self.claude_command = claude_command
        self.engine_state = engine_state or EngineState()
        self.on_feature_done = on_feature_done

    def run(
        self,
        max_errors: int = 3,
        feature_ids: Optional[list[str]] = None,
        skip_pr: bool = False,
    ) -> CrunchResult:
        """Run batch feature implementation via scheduler.

        Args:
            max_errors: Stop after this many feature failures.
            feature_ids: Explicit list of features (otherwise reads FEATURES.md).
            skip_pr: Skip PR creation per feature.

        Returns:
            CrunchResult with per-feature status.
        """
        # Resolve features to process
        features = feature_ids or self._read_planned_features()
        if not features:
            return CrunchResult(
                success=False,
                stopped_reason="no planned features found",
            )

        # Adapt on_feature_done callback from FeatureWork to FeatureBatchResult
        adapted_callback = None
        if self.on_feature_done:
            def adapted_callback(fw):
                tr = fw.task_result
                self.on_feature_done(FeatureBatchResult(
                    feature_id=fw.feature_id,
                    status=fw.status if fw.status != "review_blocked" else "skipped",
                    acs_passed=tr.acs_passed if tr else 0,
                    acs_total=tr.acs_total if tr else 0,
                    pr_url=tr.pr_url if tr else "",
                    duration_seconds=fw.duration_seconds,
                    error=fw.error,
                ))

        # Delegate to scheduler
        scheduler = AutonomousScheduler(
            project_root=self.project_root,
            claude_command=self.claude_command,
            engine_state=self.engine_state,
            on_feature_done=adapted_callback,
        )
        scheduler_result = scheduler.run(
            feature_ids=features,
            max_errors=max_errors,
            skip_pr=skip_pr,
        )

        return _scheduler_to_crunch_result(scheduler_result)

    def _read_planned_features(self) -> list[str]:
        """Read features that need work.

        Priority order:
        1. BACKLOG.json (if it exists and has feature items)
        2. State machine (features with available forward transitions)
        3. FEATURES.md fallback (planned/implementing features)
        """
        # Try backlog first
        backlog_features = self._read_backlog_features()
        if backlog_features:
            return backlog_features

        try:
            from auto.state_machine import FeatureStateMachine
            sm = FeatureStateMachine(project_root=self.project_root)
            unblocked = sm.get_unblocked()
            return [fid for fid, _state, _nexts in unblocked]
        except Exception:
            # Fallback: read FEATURES.md directly
            return self._read_planned_features_fallback()

    def _read_backlog_features(self) -> list[str]:
        """Read feature items from BACKLOG.json in queue order."""
        backlog_file = self.paths.backlog_file
        if not backlog_file.exists():
            return []
        try:
            items = json.loads(backlog_file.read_text())
            if not isinstance(items, list):
                return []
            return [
                item["id"]
                for item in items
                if item.get("type") == "feature" and item.get("id")
            ]
        except (json.JSONDecodeError, OSError, KeyError):
            return []

    def _read_planned_features_fallback(self) -> list[str]:
        """Fallback: read planned/implementing features from FEATURES.md."""
        features_file = self.paths.features_file
        if not features_file.exists():
            return []

        features = []
        content = features_file.read_text()
        # Match heading format: ## F-XXXX: Name followed by **Status**: value
        current_fid = None
        for line in content.splitlines():
            header = FEATURE_HEADER_RE.match(line)
            if header:
                current_fid = header.group(1)
                continue
            if current_fid:
                status_match = re.match(
                    r"\*\*Status\*\*:\s*(\S+)", line.strip()
                )
                if status_match:
                    status = status_match.group(1).lower().replace("-", "_")
                    if status in ("planned", "designed", "specced", "criteria_set",
                                  "tests_written", "implementing", "in_progress"):
                        features.append(current_fid)
                    current_fid = None
        return features


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------
def main() -> int:
    """Entry point for `ag auto crunch`."""
    import argparse

    parser = argparse.ArgumentParser(
        description="Autonomous multi-feature batch mode"
    )
    parser.add_argument(
        "--max-errors",
        type=int,
        default=3,
        help="Stop after N feature failures (default: 3)",
    )
    parser.add_argument(
        "--features",
        type=str,
        nargs="+",
        default=None,
        help="Explicit feature IDs (otherwise reads FEATURES.md)",
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
        "--json",
        action="store_true",
        help="Output result as JSON",
    )
    args = parser.parse_args()

    def print_feature(feat: FeatureBatchResult) -> None:
        mark = "DONE" if feat.status == "completed" else "FAIL"
        print(
            f"  [{feat.feature_id}] {mark}: "
            f"{feat.acs_passed}/{feat.acs_total} ACs "
            f"({feat.duration_seconds:.1f}s)"
        )

    runner = CrunchRunner(
        project_root=args.project_root,
        on_feature_done=None if args.json else print_feature,
    )

    if not args.json:
        print("Autonomous crunch mode")
        print()

    result = runner.run(
        max_errors=args.max_errors,
        feature_ids=args.features,
        skip_pr=args.skip_pr,
    )

    if args.json:
        print(json.dumps(result.to_dict(), indent=2))
    else:
        print()
        if result.success:
            print(f"All {result.features_completed} features completed.")
        else:
            print(
                f"{result.features_completed}/{result.features_total} "
                f"features completed, {result.features_failed} failed."
            )
            if result.stopped_reason:
                print(f"Stopped: {result.stopped_reason}")

    return 0 if result.success else 1


if __name__ == "__main__":
    sys.exit(main())
