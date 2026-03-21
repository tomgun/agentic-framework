"""
pipeline.py -- End-to-End Autonomous Pipeline orchestrator.

Implements F-0188 (ADR-001 Phase 7 capstone): wires kickoff, promote,
epic creation, and scheduler into a single autonomous flow.

Accepts either:
- Pre-structured features_data (for programmatic/test use)
- A freeform vision string (--vision), which spawns Claude to convert
  it into structured features_data before running the pipeline

@feature F-0188

Usage:
    # Programmatic (pre-structured)
    from auto.pipeline import run_pipeline, PipelineResult
    result = run_pipeline(project_root, features_data, epic_name="My Epic")

    # Programmatic (from vision)
    result = run_pipeline_from_vision(project_root, "Build a todo app", epic_name="Todo")

    # CLI
    ag auto pipeline --vision "Build a todo app with auth and notifications"
    ag auto pipeline --features-json '[...]' --epic-name "My Epic"
"""
from __future__ import annotations

import json
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
from auto import spawn_claude  # noqa: E402


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
# Vision → features_data conversion
# ---------------------------------------------------------------------------

_VISION_PROMPT_TEMPLATE = """\
You are a product architect. Convert the following product vision into a
structured JSON array of features suitable for an agentic development pipeline.

VISION:
{vision}

{context_section}

OUTPUT FORMAT — respond with ONLY a JSON object (no markdown fences, no commentary):
{{
  "epic_name": "Short epic title (3-6 words)",
  "overview": "2-3 sentence project overview",
  "features": [
    {{
      "name": "Feature Name",
      "description": "What this feature does and why",
      "criteria": [
        "AC-001: User can ...",
        "AC-002: System validates ...",
        "AC-003: Error case ..."
      ],
      "dependencies": []
    }}
  ]
}}

RULES:
- Each feature should be independently implementable (max 5-10 files of change)
- Order features by dependency (foundations first)
- Each feature needs 2-5 concrete, testable acceptance criteria
- Dependencies reference other features by name (empty list if none)
- Keep features small and focused — split large concerns into multiple features
- Include error handling and edge cases in criteria, not as separate features
- If the vision is vague, make reasonable assumptions and note them in descriptions
"""


def vision_to_features(
    project_root: Path,
    vision: str,
    claude_command: str = "claude",
    timeout: int = 120,
) -> tuple[bool, list[dict], str, str, list[str]]:
    """Convert a freeform vision string into structured features_data.

    Spawns Claude to parse the vision into the features_data format
    expected by generate_to_staging().

    Args:
        project_root: Project root path.
        vision: Freeform product vision text.
        claude_command: Claude CLI command.
        timeout: Spawn timeout in seconds.

    Returns:
        (success, features_data, epic_name, overview_text, messages)
    """
    messages: list[str] = []

    # Build context section from project files (if they exist)
    context_parts = []
    paths = get_paths(project_root)

    stack_file = project_root / "STACK.md"
    if stack_file.exists():
        stack_text = stack_file.read_text()[:2000]
        context_parts.append(f"TECH STACK (from STACK.md):\n{stack_text}")

    context_pack = paths.context_pack
    if context_pack.exists():
        cp_text = context_pack.read_text()[:2000]
        context_parts.append(f"PROJECT CONTEXT:\n{cp_text}")

    nfr_file = paths.spec_dir / "NFR.md"
    if nfr_file.exists():
        nfr_text = nfr_file.read_text()[:1000]
        context_parts.append(f"NON-FUNCTIONAL REQUIREMENTS:\n{nfr_text}")

    context_section = "\n\n".join(context_parts) if context_parts else ""

    prompt = _VISION_PROMPT_TEMPLATE.format(
        vision=vision,
        context_section=context_section,
    )

    result = spawn_claude(
        claude_command, project_root, prompt,
        timeout=timeout,
    )

    if result.returncode != 0:
        messages.append(f"Claude vision-to-features failed (rc={result.returncode})")
        return False, [], "", "", messages

    # Parse JSON from output — handle markdown fences if present
    output = str(result).strip()
    if output.startswith("```"):
        lines = output.split("\n")
        # Strip first and last fence lines
        lines = [l for l in lines if not l.strip().startswith("```")]
        output = "\n".join(lines).strip()

    try:
        parsed = json.loads(output)
    except json.JSONDecodeError:
        # Try to extract JSON object from mixed output
        start = output.find("{")
        end = output.rfind("}") + 1
        if start >= 0 and end > start:
            try:
                parsed = json.loads(output[start:end])
            except json.JSONDecodeError as e:
                messages.append(f"Failed to parse features JSON: {e}")
                messages.append(f"Raw output: {output[:500]}")
                return False, [], "", "", messages
        else:
            messages.append("No JSON object found in Claude output")
            messages.append(f"Raw output: {output[:500]}")
            return False, [], "", "", messages

    # Extract fields
    if isinstance(parsed, dict):
        epic_name = parsed.get("epic_name", "Pipeline Epic")
        overview = parsed.get("overview", "")
        features = parsed.get("features", [])
    elif isinstance(parsed, list):
        # Backward compat: raw features array
        epic_name = "Pipeline Epic"
        overview = ""
        features = parsed
    else:
        messages.append(f"Unexpected JSON type: {type(parsed).__name__}")
        return False, [], "", "", messages

    if not features:
        messages.append("Claude returned no features")
        return False, [], "", "", messages

    messages.append(f"Vision decomposed into {len(features)} features: "
                    f"{', '.join(f['name'] for f in features)}")
    return True, features, epic_name, overview, messages


# ---------------------------------------------------------------------------
# Vision → Pipeline (full end-to-end from freeform text)
# ---------------------------------------------------------------------------

def run_pipeline_from_vision(
    project_root: Path,
    vision: str,
    epic_name: str = "",
    force_overview: bool = False,
    max_errors: int = 3,
    skip_pr: bool = False,
    claude_command: str = "claude",
    vision_timeout: int = 120,
) -> PipelineResult:
    """Run the full pipeline starting from a freeform vision string.

    Spawns Claude to convert vision → features_data, then delegates to
    run_pipeline() for the rest.

    Args:
        project_root: Project root path.
        vision: Freeform product vision text.
        epic_name: Override epic name (auto-derived from vision if empty).
        force_overview: Overwrite existing OVERVIEW.md.
        max_errors: Stop scheduler after N feature failures.
        skip_pr: Skip PR creation per feature.
        claude_command: Claude CLI command for worker agents.
        vision_timeout: Timeout for vision-to-features conversion.

    Returns:
        PipelineResult with phase tracking.
    """
    result = PipelineResult(success=False)

    # -- Phase: vision -------------------------------------------------
    success, features_data, derived_name, overview, msgs = vision_to_features(
        project_root, vision,
        claude_command=claude_command,
        timeout=vision_timeout,
    )
    result.messages.extend(msgs)

    if not success:
        result.phase = "vision"
        result.blocked_reason = "; ".join(msgs)
        return result

    # Use derived epic name if not overridden
    final_epic_name = epic_name or derived_name or "Pipeline Epic"

    return run_pipeline(
        project_root=project_root,
        features_data=features_data,
        overview_text=overview,
        epic_name=final_epic_name,
        force_overview=force_overview,
        max_errors=max_errors,
        skip_pr=skip_pr,
        claude_command=claude_command,
    )


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

    from ids import get_next_feature_id, format_feature_id
    next_id = get_next_feature_id(paths.features_file)
    epic_id = format_feature_id(next_id)

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
            "Two modes:\n"
            "  --vision   Freeform text — Claude decomposes into features\n"
            "  --features-json   Pre-structured JSON (for programmatic use)\n"
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )

    input_group = parser.add_mutually_exclusive_group(required=True)
    input_group.add_argument(
        "--vision",
        help="Freeform product vision — Claude converts to features automatically",
    )
    input_group.add_argument(
        "--features-json",
        help=(
            "JSON array of feature dicts. Each dict needs at minimum: "
            "name, criteria. Example: "
            "'[{\"name\": \"Auth\", \"description\": \"...\", \"criteria\": [\"AC-001: ...\"]}]'"
        ),
    )

    parser.add_argument(
        "--overview", default="",
        help="Overview text for OVERVIEW.md",
    )
    parser.add_argument(
        "--epic-name", default="",
        help="Epic name (auto-derived from vision if omitted)",
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
        "--vision-timeout", type=int, default=120,
        help="Timeout for vision-to-features conversion in seconds (default: 120)",
    )
    parser.add_argument(
        "--json", action="store_true",
        help="Output result as JSON",
    )

    args = parser.parse_args()
    project_root = args.project_root.resolve()

    if args.vision:
        # Vision mode: Claude decomposes vision → features → pipeline
        result = run_pipeline_from_vision(
            project_root=project_root,
            vision=args.vision,
            epic_name=args.epic_name,
            force_overview=args.force_overview,
            max_errors=args.max_errors,
            skip_pr=args.skip_pr,
            vision_timeout=args.vision_timeout,
        )
    else:
        # Pre-structured mode
        try:
            features_data = json.loads(args.features_json)
            if not isinstance(features_data, list):
                print("Error: --features-json must be a JSON array", file=sys.stderr)
                return 1
        except json.JSONDecodeError as e:
            print(f"Error: Invalid JSON in --features-json: {e}", file=sys.stderr)
            return 1

        result = run_pipeline(
            project_root=project_root,
            features_data=features_data,
            overview_text=args.overview,
            epic_name=args.epic_name or "Pipeline Epic",
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
