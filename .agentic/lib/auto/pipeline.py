"""
pipeline.py -- End-to-End Autonomous Pipeline orchestrator.

Implements F-0188 (ADR-001 Phase 7 capstone): wires kickoff, promote,
epic creation, and scheduler into a single autonomous flow.

The pipeline accepts pre-structured features_data (same format as
kickoff.generate_to_staging). The LLM vision-to-features step is the
caller's responsibility (ag.sh/skill layer), keeping this module
fully testable and agent-agnostic.

@feature F-0188

Usage:
    # Programmatic
    from auto.pipeline import run_pipeline, PipelineResult
    result = run_pipeline(project_root, features_data, epic_name="My Epic")

    # CLI
    ag auto pipeline --features-json '[...]' --epic-name "My Epic"
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
sys.path.insert(0, str(_LIB_DIR / "tools"))
from paths import get_paths  # noqa: E402
from settings import get_setting  # noqa: E402
from auto.kickoff import generate_to_staging, promote_staging_with_ids  # noqa: E402
from auto.scheduler import AutonomousScheduler  # noqa: E402


# ---------------------------------------------------------------------------
# Data types
# ---------------------------------------------------------------------------

@dataclass
class PipelineResult:
    """Result of a full pipeline run."""
    success: bool
    phase: str = ""  # gate_check | epic_create | kickoff | promote | schedule | done
    epic_id: str = ""
    feature_ids: list[str] = field(default_factory=list)
    scheduler_result: Optional[object] = None  # SchedulerResult when available
    blocked_reason: str = ""
    messages: list[str] = field(default_factory=list)

    def to_dict(self) -> dict:
        d = {
            "success": self.success,
            "phase": self.phase,
            "epic_id": self.epic_id,
            "feature_ids": self.feature_ids,
            "blocked_reason": self.blocked_reason,
            "messages": self.messages,
        }
        if self.scheduler_result and hasattr(self.scheduler_result, "to_dict"):
            d["scheduler_result"] = self.scheduler_result.to_dict()
        return d


# ---------------------------------------------------------------------------
# Epic entry creation
# ---------------------------------------------------------------------------

def _create_epic_entry(
    project_root: Path,
    epic_name: str,
) -> tuple[str, list[str]]:
    """Create an epic entry in FEATURES.md and a synthetic AC file.

    Allocates a fresh feature ID, appends an epic section to FEATURES.md,
    and creates a minimal AC file. Does NOT create or link children —
    that happens during promote via parent_id.

    Returns:
        (epic_id, messages)
    """
    paths = get_paths(project_root)
    messages: list[str] = []

    from auto.epic import get_next_feature_id
    next_id = get_next_feature_id(paths.features_file)
    epic_id = f"F-{next_id:04d}"

    # Append epic section to FEATURES.md
    section = "\n".join([
        f"## {epic_id}: {epic_name}",
        "",
        "**Status**: planned",
        "**Category**: Epic",
        "",
        f"**Description**: Pipeline epic — {epic_name}.",
        "",
        f"**Acceptance**: See `spec/acceptance/{epic_id}.md`",
        "",
        "---",
        "",
    ])

    features_file = paths.features_file
    with open(features_file, "a") as f:
        f.write("\n" + section + "\n")

    # Create synthetic AC file
    acceptance_dir = paths.acceptance_dir
    acceptance_dir.mkdir(parents=True, exist_ok=True)
    ac_content = "\n".join([
        f"# {epic_id}: {epic_name}",
        "",
        "**Category**: Epic",
        "",
        "## Acceptance Criteria",
        "",
        "- [ ] **AC-001**: All child features implemented, reviewed, and shipped",
        "- [ ] **AC-002**: Integration verification passes across all children",
        "",
    ])
    (acceptance_dir / f"{epic_id}.md").write_text(ac_content)

    messages.append(f"Created epic {epic_id}: {epic_name}")
    return epic_id, messages


# ---------------------------------------------------------------------------
# Pipeline orchestrator
# ---------------------------------------------------------------------------

def run_pipeline(
    project_root: Path,
    features_data: list[dict],
    overview_text: str = "",
    epic_name: str = "Pipeline Epic",
    force_overview: bool = False,
    max_errors: int = 3,
    skip_pr: bool = False,
    claude_command: str = "claude",
) -> PipelineResult:
    """Run the full autonomous pipeline: epic → kickoff → promote → schedule.

    Args:
        project_root: Project root path.
        features_data: List of feature dicts (same format as
            kickoff.generate_to_staging). Pre-structured — the LLM
            vision-to-features step is the caller's responsibility.
        overview_text: Optional overview text for OVERVIEW.md.
        epic_name: Name for the epic entry.
        force_overview: Overwrite existing OVERVIEW.md.
        max_errors: Stop scheduler after N feature failures.
        skip_pr: Skip PR creation per feature.
        claude_command: Claude CLI command for worker agents.

    Returns:
        PipelineResult with phase tracking and per-feature results.
    """
    result = PipelineResult(success=False)

    # -- Phase: gate_check -------------------------------------------------
    review_mode = get_setting(project_root, "review_decomposition", "skip")
    if review_mode == "human":
        result.phase = "gate_check"
        result.blocked_reason = (
            "review_decomposition is set to 'human'. "
            "Pipeline requires 'critical_agent' or 'skip'. "
            "Set in STACK.md ## Settings."
        )
        return result

    if not features_data:
        result.phase = "gate_check"
        result.blocked_reason = "No features_data provided"
        return result

    # -- Phase: epic_create ------------------------------------------------
    try:
        epic_id, epic_msgs = _create_epic_entry(project_root, epic_name)
        result.epic_id = epic_id
        result.messages.extend(epic_msgs)
    except Exception as e:
        result.phase = "epic_create"
        result.blocked_reason = f"Epic creation failed: {e}"
        return result

    # -- Phase: kickoff ----------------------------------------------------
    try:
        success, kickoff_msgs = generate_to_staging(
            project_root, features_data, overview_text,
        )
        result.messages.extend(kickoff_msgs)
        if not success:
            result.phase = "kickoff"
            result.blocked_reason = "; ".join(kickoff_msgs)
            return result
    except Exception as e:
        result.phase = "kickoff"
        result.blocked_reason = f"Kickoff failed: {e}"
        return result

    # -- Phase: promote ----------------------------------------------------
    try:
        success, promote_msgs, id_map = promote_staging_with_ids(
            project_root,
            force_overview=force_overview,
            parent_id=epic_id,
        )
        result.messages.extend(promote_msgs)
        if not success:
            result.phase = "promote"
            result.blocked_reason = "; ".join(promote_msgs)
            return result

        result.feature_ids = list(id_map.values())
    except Exception as e:
        result.phase = "promote"
        result.blocked_reason = f"Promote failed: {e}"
        return result

    # -- Phase: schedule ---------------------------------------------------
    try:
        scheduler = AutonomousScheduler(
            project_root=project_root,
            claude_command=claude_command,
        )
        sched_result = scheduler.run_epic(
            epic_id=epic_id,
            max_errors=max_errors,
            skip_pr=skip_pr,
        )
        result.scheduler_result = sched_result
        result.messages.append(
            f"Scheduler: {sched_result.features_completed}/{sched_result.features_total} "
            f"completed"
        )

        if sched_result.success:
            result.phase = "done"
            result.success = True
        else:
            result.phase = "schedule"
            result.blocked_reason = sched_result.stopped_reason or "Scheduler did not complete all features"
    except Exception as e:
        result.phase = "schedule"
        result.blocked_reason = f"Scheduler failed: {e}"

    return result


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------

def main() -> int:
    """Entry point for `ag auto pipeline`."""
    import argparse

    parser = argparse.ArgumentParser(
        description=(
            "End-to-end autonomous pipeline: vision → epic → implement → ship.\n\n"
            "Accepts pre-structured features_data (JSON). The LLM\n"
            "vision-to-features step is the caller's responsibility."
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "--features-json",
        required=True,
        help=(
            "JSON array of feature dicts. Each dict needs at minimum: "
            "placeholder_id, name. Example: "
            "'[{\"placeholder_id\": \"P-1\", \"name\": \"Auth\"}]'"
        ),
    )
    parser.add_argument(
        "--overview", default="",
        help="Overview text for OVERVIEW.md",
    )
    parser.add_argument(
        "--epic-name", default="Pipeline Epic",
        help="Name for the pipeline epic (default: 'Pipeline Epic')",
    )
    parser.add_argument(
        "--project-root", type=Path, default=Path.cwd(),
        help="Project root directory",
    )
    parser.add_argument(
        "--force-overview", action="store_true",
        help="Overwrite existing OVERVIEW.md",
    )
    parser.add_argument(
        "--max-errors", type=int, default=3,
        help="Stop scheduler after N feature failures (default: 3)",
    )
    parser.add_argument(
        "--skip-pr", action="store_true",
        help="Skip PR creation per feature",
    )
    parser.add_argument(
        "--json", action="store_true",
        help="Output result as JSON",
    )

    args = parser.parse_args()

    # Parse features JSON
    try:
        features_data = json.loads(args.features_json)
        if not isinstance(features_data, list):
            print("Error: --features-json must be a JSON array", file=sys.stderr)
            return 1
    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON in --features-json: {e}", file=sys.stderr)
        return 1

    result = run_pipeline(
        project_root=args.project_root.resolve(),
        features_data=features_data,
        overview_text=args.overview,
        epic_name=args.epic_name,
        force_overview=args.force_overview,
        max_errors=args.max_errors,
        skip_pr=args.skip_pr,
    )

    if args.json:
        print(json.dumps(result.to_dict(), indent=2))
    else:
        if result.success:
            print(f"Pipeline completed: epic {result.epic_id}")
            print(f"  Features: {', '.join(result.feature_ids)}")
        else:
            print(f"Pipeline stopped at phase: {result.phase}")
            if result.blocked_reason:
                print(f"  Reason: {result.blocked_reason}")
            if result.epic_id:
                print(f"  Epic: {result.epic_id}")
            if result.feature_ids:
                print(f"  Features: {', '.join(result.feature_ids)}")

        for msg in result.messages:
            print(f"  {msg}")

    return 0 if result.success else 1


if __name__ == "__main__":
    sys.exit(main())
