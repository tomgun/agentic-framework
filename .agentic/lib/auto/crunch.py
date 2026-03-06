"""
crunch.py -- Autonomous multi-feature batch mode (F-0163).

Reads planned/in-progress features from FEATURES.md, processes each via
F-0162 task mode, tracks overall progress, stops on threshold errors.

Usage:
    from auto.crunch import CrunchRunner
    runner = CrunchRunner(project_root=Path("."))
    result = runner.run()
"""
from __future__ import annotations

import json
import re
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional

_LIB_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(_LIB_DIR))
from paths import get_paths  # noqa: E402

from auto.task import TaskRunner, TaskResult  # noqa: E402
from auto.engine import EngineState  # noqa: E402


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


class CrunchRunner:
    """Multi-feature batch orchestrator.

    1. Read planned/in-progress features from FEATURES.md
    2. Process each via TaskRunner (F-0162)
    3. Track progress in dashboard state
    4. Stop on: all done, max errors, or human stop command
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
        """Run batch feature implementation.

        Args:
            max_errors: Stop after this many feature failures.
            feature_ids: Explicit list of features (otherwise reads FEATURES.md).
            skip_pr: Skip PR creation per feature.

        Returns:
            CrunchResult with per-feature status.
        """
        result = CrunchResult(success=False)

        # Get features to process
        features = feature_ids or self._read_planned_features()
        if not features:
            result.stopped_reason = "no planned features found"
            return result
        result.features_total = len(features)

        self.engine_state.state = "running"
        error_count = 0

        for feature_id in features:
            if self.engine_state.state == "stopping":
                result.stopped_reason = "stopped by user"
                break

            # Wait while paused
            while self.engine_state.state == "paused":
                time.sleep(0.5)
                if self.engine_state.state == "stopping":
                    break
            if self.engine_state.state == "stopping":
                result.stopped_reason = "stopped by user"
                break

            start = time.time()
            feat_result = FeatureBatchResult(feature_id=feature_id)

            try:
                task_runner = TaskRunner(
                    project_root=self.project_root,
                    claude_command=self.claude_command,
                )
                task_result = task_runner.run(
                    feature_id=feature_id,
                    skip_pr=skip_pr,
                )

                feat_result.acs_passed = task_result.acs_passed
                feat_result.acs_total = task_result.acs_total
                feat_result.pr_url = task_result.pr_url

                if task_result.success:
                    feat_result.status = "completed"
                    result.features_completed += 1
                else:
                    feat_result.status = "failed"
                    result.features_failed += 1
                    error_count += 1
            except Exception as e:
                feat_result.status = "failed"
                feat_result.error = str(e)
                result.features_failed += 1
                error_count += 1

            feat_result.duration_seconds = time.time() - start
            result.feature_results.append(feat_result)

            if self.on_feature_done:
                self.on_feature_done(feat_result)

            # Save progress
            self._save_progress(result)

            # Check error threshold
            if error_count >= max_errors:
                result.stopped_reason = f"max errors reached ({max_errors})"
                break

        # Mark remaining as skipped
        processed = {r.feature_id for r in result.feature_results}
        for fid in features:
            if fid not in processed:
                result.feature_results.append(
                    FeatureBatchResult(feature_id=fid, status="skipped")
                )
                result.features_skipped += 1

        result.success = (
            result.features_completed == result.features_total
        )
        self.engine_state.state = "stopped"
        self._save_progress(result)
        return result

    def _read_planned_features(self) -> list[str]:
        """Read planned/in-progress features from FEATURES.md.

        Returns feature IDs in priority order (as listed in the file).
        """
        features_file = self.paths.features_file
        if not features_file.exists():
            return []

        features = []
        content = features_file.read_text()
        for line in content.splitlines():
            # Match lines like "| F-0042 | planned |" or "| F-0042 | in-progress |"
            match = re.match(
                r"\|\s*(F-\d{4})\s*\|.*?\|\s*(planned|in-progress)\s*\|",
                line,
                re.IGNORECASE,
            )
            if match:
                features.append(match.group(1))
        return features

    def _save_progress(self, result: CrunchResult) -> None:
        """Save batch progress to session state."""
        state_file = self.paths.session_dir / "crunch-state.json"
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
