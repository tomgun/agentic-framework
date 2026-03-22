"""
kickoff.py -- Vision-to-Backlog pipeline: staging generation, validation, promotion.

Implements F-0201: `ag kickoff` converts a product vision into structured spec
artifacts (OVERVIEW.md, FEATURES.md entries, acceptance criteria stubs, BACKLOG.json)
in a staging area for review before promotion to real spec files.

Key design: this module does NOT call the LLM. It accepts structured data (features_data)
and handles file generation, validation, and promotion. LLM interaction happens at the
ag.sh/skill layer. This keeps the Python layer fully unit-testable and agent-agnostic.

@feature F-0201

Usage:
    # Programmatic
    from auto.kickoff import generate_to_staging, validate_staging, promote_staging

    # CLI
    python -m auto.kickoff generate --features-json '...' --project-root .
    python -m auto.kickoff validate --project-root .
    python -m auto.kickoff review --project-root .
    python -m auto.kickoff promote --project-root .
    python -m auto.kickoff discard --project-root .
    python -m auto.kickoff status --project-root .
"""
from __future__ import annotations

import json
import re
import shutil
import sys
from pathlib import Path
from typing import Optional

# ---------------------------------------------------------------------------
# Resolve paths.py and backlog_helpers from lib/
# ---------------------------------------------------------------------------
_LIB_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(_LIB_DIR))
sys.path.insert(0, str(_LIB_DIR / "tools"))
from paths import get_paths  # noqa: E402
from settings import get_setting  # noqa: E402

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

from ids import FEATURE_ID_STRICT_RE as _FEATURE_ID_RE  # noqa: E402
from ids import is_valid_feature_id, format_feature_id  # noqa: E402
from ids import get_next_feature_id  # noqa: E402

_PROPOSAL_MARKER = "<!-- PROPOSAL -->"
_PLACEHOLDER_PREFIX = "F-NEW-"


# ---------------------------------------------------------------------------
# Staging directory helpers
# ---------------------------------------------------------------------------

def _staging_dir(project_root: Path) -> Path:
    """Return the staging directory path."""
    paths = get_paths(project_root)
    return paths.session_dir / "kickoff-draft"


def _staging_exists(project_root: Path) -> bool:
    """Check if a staging area exists."""
    return _staging_dir(project_root).exists()


# ---------------------------------------------------------------------------
# Generate to staging (AC-001, AC-009, AC-011)
# ---------------------------------------------------------------------------

def generate_to_staging(
    project_root: Path,
    features_data: list[dict],
    overview_text: Optional[str] = None,
) -> tuple[bool, list[str]]:
    """Write kickoff artifacts to staging area.

    Args:
        project_root: Project root path.
        features_data: List of dicts with keys:
            name (str), description (str),
            criteria (list[str]), dependencies (list[str], optional)
        overview_text: Optional OVERVIEW.md content.

    Returns:
        (success, messages)

    Raises if staging dir already exists (must --discard first).
    Staging uses placeholder IDs (F-NEW-001, F-NEW-002, ...).
    Real IDs are allocated at promotion time.
    """
    messages: list[str] = []

    # Block if staging exists (AC-011)
    staging = _staging_dir(project_root)
    if staging.exists():
        return False, [
            "Staging area already exists. Run `ag kickoff --discard` first, "
            "or `ag kickoff --review` to continue reviewing."
        ]

    if not features_data:
        return False, ["No features provided"]

    # Create staging directory structure
    staging.mkdir(parents=True, exist_ok=True)
    staging_spec = staging / "spec" / "acceptance"
    staging_spec.mkdir(parents=True, exist_ok=True)

    # Assign placeholder IDs
    for i, feature in enumerate(features_data):
        feature["_placeholder_id"] = f"{_PLACEHOLDER_PREFIX}{i + 1:03d}"

    # Write OVERVIEW.md (AC-009: with PROPOSAL markers)
    if overview_text:
        overview_content = f"{_PROPOSAL_MARKER}\n# Project Overview\n\n{overview_text}\n"
    else:
        overview_content = (
            f"{_PROPOSAL_MARKER}\n# Project Overview\n\n"
            "_No overview provided. Add one before promoting._\n"
        )
    (staging / "OVERVIEW.md").write_text(overview_content)

    # Write FEATURES.md entries
    features_lines: list[str] = [f"{_PROPOSAL_MARKER}\n# Proposed Features\n"]
    for feature in features_data:
        pid = feature["_placeholder_id"]
        name = feature.get("name", "Unnamed Feature")
        desc = feature.get("description", "")
        deps = feature.get("dependencies", [])

        section = [
            f"\n## {pid}: {name}\n",
            "**Status**: planned",
            "**Category**: Proposed",
        ]
        if deps:
            section.append(f"**Dependencies**: {', '.join(deps)}")
        section.extend([
            "",
            f"**Description**: {desc}" if desc else "**Description**: _TBD_",
            "",
            f"**Acceptance**: See `spec/contracts/{pid}.yaml`",
            "",
            "---",
            "",
        ])
        features_lines.append("\n".join(section))

    (staging / "FEATURES.md").write_text("\n".join(features_lines))

    # Write AC stub files
    for feature in features_data:
        pid = feature["_placeholder_id"]
        name = feature.get("name", "Unnamed Feature")
        criteria = feature.get("criteria", [])

        ac_lines = [
            f"{_PROPOSAL_MARKER}",
            f"# {pid}: {name}",
            "",
            "## Acceptance Criteria",
            "",
        ]
        for j, criterion in enumerate(criteria, 1):
            ac_lines.append(f"- [ ] **AC-{j:03d}**: {criterion}")
        ac_lines.append("")

        ac_file = staging_spec / f"{pid}.md"
        ac_file.write_text("\n".join(ac_lines))

    # Write BACKLOG.json (ordered by dependency — simple: deps first)
    backlog_order = _order_by_dependencies(features_data)
    backlog_items = []
    for feature in backlog_order:
        pid = feature["_placeholder_id"]
        backlog_items.append({
            "type": "feature",
            "id": pid,
            "description": feature.get("name", pid),
            "added_by": "kickoff",
        })
    (staging / "BACKLOG.json").write_text(
        json.dumps(backlog_items, indent=2) + "\n"
    )

    # Write metadata for tracking
    metadata = {
        "feature_count": len(features_data),
        "features": [
            {
                "placeholder_id": f["_placeholder_id"],
                "name": f.get("name", ""),
                "description": f.get("description", ""),
                "criteria_count": len(f.get("criteria", [])),
                "dependencies": f.get("dependencies", []),
            }
            for f in features_data
        ],
    }
    (staging / ".metadata.json").write_text(
        json.dumps(metadata, indent=2) + "\n"
    )

    messages.append(f"Generated {len(features_data)} features to staging")
    messages.append(f"Staging: {staging}")
    messages.append("Next: `ag kickoff --review` to inspect, then `ag kickoff --approve`")
    return True, messages


# ---------------------------------------------------------------------------
# Validate staging (AC-007)
# ---------------------------------------------------------------------------

def validate_staging(project_root: Path) -> tuple[bool, list[str]]:
    """Validate staging area.

    Checks:
        - Staging directory exists
        - OVERVIEW.md exists and has content
        - Non-empty acceptance criteria (contracts) per feature
        - Dependency acyclicity (topological sort)

    Note: ID uniqueness vs existing FEATURES.md is checked at promotion
    time (not here), since staging uses placeholder IDs.

    Returns:
        (valid, errors)
    """
    staging = _staging_dir(project_root)
    errors: list[str] = []

    if not staging.exists():
        return False, ["No staging area found. Run `ag kickoff` first."]

    # Check OVERVIEW.md
    overview = staging / "OVERVIEW.md"
    if not overview.exists():
        errors.append("OVERVIEW.md missing from staging")
    else:
        content = overview.read_text().replace(_PROPOSAL_MARKER, "").strip()
        if not content or content == "# Project Overview":
            errors.append("OVERVIEW.md has no content")

    # Check FEATURES.md
    features_file = staging / "FEATURES.md"
    if not features_file.exists():
        errors.append("FEATURES.md missing from staging")

    # Check metadata
    metadata_file = staging / ".metadata.json"
    if not metadata_file.exists():
        errors.append("Metadata file missing (staging may be corrupt)")
        return len(errors) == 0, errors

    try:
        metadata = json.loads(metadata_file.read_text())
    except (json.JSONDecodeError, OSError):
        errors.append("Metadata file corrupt")
        return False, errors

    features = metadata.get("features", [])

    # Check each feature has non-empty criteria
    for f in features:
        if f.get("criteria_count", 0) == 0:
            errors.append(
                f"{f['placeholder_id']} ({f.get('name', '?')}): "
                f"no acceptance criteria"
            )

    # Check AC files exist
    staging_spec = staging / "spec" / "acceptance"
    for f in features:
        ac_file = staging_spec / f"{f['placeholder_id']}.md"
        if not ac_file.exists():
            errors.append(f"AC file missing: {f['placeholder_id']}.md")

    # Check dependency acyclicity
    cycle_errors = _check_dependency_cycles(features)
    errors.extend(cycle_errors)

    return len(errors) == 0, errors


def _check_dependency_cycles(features: list[dict]) -> list[str]:
    """Check for circular dependencies using topological sort."""
    # Build adjacency: placeholder_id → [dependency placeholder_ids]
    # Dependencies reference placeholder names within the staging set
    name_to_id = {}
    for f in features:
        name_to_id[f.get("name", "")] = f["placeholder_id"]

    # Map dependencies to placeholder IDs where possible
    graph: dict[str, list[str]] = {}
    all_ids = {f["placeholder_id"] for f in features}
    for f in features:
        pid = f["placeholder_id"]
        deps = []
        for dep in f.get("dependencies", []):
            # Dependencies can reference placeholder IDs or names
            if dep in all_ids:
                deps.append(dep)
            elif dep in name_to_id:
                deps.append(name_to_id[dep])
            # External deps (F-XXXX) are ignored for cycle check
        graph[pid] = deps

    # Kahn's algorithm — in_degree[X] = number of deps X has
    in_degree = {pid: 0 for pid in all_ids}
    for pid, deps in graph.items():
        for dep in deps:
            if dep in all_ids:
                in_degree[pid] += 1

    queue = [pid for pid, deg in in_degree.items() if deg == 0]
    visited = 0
    while queue:
        node = queue.pop(0)
        visited += 1
        # Find nodes that depend on this node
        for pid, deps in graph.items():
            if node in deps:
                in_degree[pid] -= 1
                if in_degree[pid] == 0:
                    queue.append(pid)

    if visited < len(all_ids):
        unvisited = [pid for pid in all_ids if in_degree.get(pid, 0) > 0]
        return [f"Circular dependency detected involving: {', '.join(sorted(unvisited))}"]
    return []


# ---------------------------------------------------------------------------
# Review staging (AC-003)
# ---------------------------------------------------------------------------

def review_staging(project_root: Path) -> tuple[bool, dict]:
    """Pretty-print staging artifacts for human review.

    Returns:
        (success, summary_dict)
        summary_dict has keys:
            overview: str (title + first paragraph)
            features: [{id, name, ac_count, dependencies}]
            backlog_order: [ids]
            validation: {valid, errors}
    """
    staging = _staging_dir(project_root)
    if not staging.exists():
        return False, {"error": "No staging area found"}

    summary: dict = {}

    # Overview
    overview_file = staging / "OVERVIEW.md"
    if overview_file.exists():
        content = overview_file.read_text().replace(_PROPOSAL_MARKER, "").strip()
        lines = content.splitlines()
        # Get title and first paragraph
        title = ""
        para = ""
        for line in lines:
            if line.startswith("# "):
                title = line[2:].strip()
            elif line.strip() and not title:
                continue
            elif line.strip() and title and not para:
                para = line.strip()
        summary["overview"] = f"{title}: {para}" if para else title
    else:
        summary["overview"] = "(no overview)"

    # Features from metadata
    metadata_file = staging / ".metadata.json"
    if metadata_file.exists():
        try:
            metadata = json.loads(metadata_file.read_text())
            summary["features"] = [
                {
                    "id": f["placeholder_id"],
                    "name": f.get("name", "?"),
                    "ac_count": f.get("criteria_count", 0),
                    "dependencies": f.get("dependencies", []),
                }
                for f in metadata.get("features", [])
            ]
        except (json.JSONDecodeError, OSError):
            summary["features"] = []
    else:
        summary["features"] = []

    # Backlog order
    backlog_file = staging / "BACKLOG.json"
    if backlog_file.exists():
        try:
            backlog = json.loads(backlog_file.read_text())
            summary["backlog_order"] = [
                item.get("id", "?") for item in backlog
            ]
        except (json.JSONDecodeError, OSError):
            summary["backlog_order"] = []
    else:
        summary["backlog_order"] = []

    # Validation
    valid, errors = validate_staging(project_root)
    summary["validation"] = {"valid": valid, "errors": errors}

    return True, summary


# ---------------------------------------------------------------------------
# Staging status (AC-015)
# ---------------------------------------------------------------------------

def staging_status(project_root: Path) -> dict:
    """Return staging state as a dict.

    Returns:
        {exists, feature_count, valid, errors}
    """
    staging = _staging_dir(project_root)
    if not staging.exists():
        return {"exists": False, "feature_count": 0, "valid": False, "errors": []}

    metadata_file = staging / ".metadata.json"
    feature_count = 0
    if metadata_file.exists():
        try:
            metadata = json.loads(metadata_file.read_text())
            feature_count = metadata.get("feature_count", 0)
        except (json.JSONDecodeError, OSError):
            pass

    valid, errors = validate_staging(project_root)
    return {
        "exists": True,
        "feature_count": feature_count,
        "valid": valid,
        "errors": errors,
    }


# ---------------------------------------------------------------------------
# Staging edit operations (AC-003, AC-004)
# ---------------------------------------------------------------------------

def merge_staging_features(
    project_root: Path, source_id: str, target_id: str
) -> tuple[bool, list[str]]:
    """Merge source feature into target. Combines ACs, removes source, updates deps."""
    staging = _staging_dir(project_root)
    if not staging.exists():
        return False, ["No staging area found"]

    metadata_file = staging / ".metadata.json"
    try:
        metadata = json.loads(metadata_file.read_text())
    except (json.JSONDecodeError, OSError):
        return False, ["Metadata corrupt"]

    features = metadata.get("features", [])
    source = next((f for f in features if f["placeholder_id"] == source_id), None)
    target = next((f for f in features if f["placeholder_id"] == target_id), None)

    if not source:
        return False, [f"Source feature {source_id} not found"]
    if not target:
        return False, [f"Target feature {target_id} not found"]

    # Merge AC files
    staging_spec = staging / "spec" / "acceptance"
    source_ac = staging_spec / f"{source_id}.md"
    target_ac = staging_spec / f"{target_id}.md"

    if source_ac.exists() and target_ac.exists():
        source_content = source_ac.read_text()
        # Extract AC lines from source
        source_criteria = [
            line for line in source_content.splitlines()
            if line.strip().startswith("- [ ] **AC-")
        ]
        # Append to target with renumbered ACs
        target_content = target_ac.read_text()
        existing_count = target.get("criteria_count", 0)
        for i, criterion in enumerate(source_criteria, existing_count + 1):
            # Renumber
            renumbered = re.sub(
                r"\*\*AC-\d+\*\*",
                f"**AC-{i:03d}**",
                criterion,
            )
            target_content += f"\n{renumbered}"
        target_ac.write_text(target_content)
        source_ac.unlink()

    # Update target criteria count
    target["criteria_count"] = target.get("criteria_count", 0) + source.get("criteria_count", 0)

    # Merge dependencies
    source_deps = set(source.get("dependencies", []))
    target_deps = set(target.get("dependencies", []))
    target["dependencies"] = list((target_deps | source_deps) - {target_id, source_id})

    # Remove source from features list
    metadata["features"] = [f for f in features if f["placeholder_id"] != source_id]
    metadata["feature_count"] = len(metadata["features"])

    # Update any deps that referenced source → now reference target
    for f in metadata["features"]:
        if source_id in f.get("dependencies", []):
            f["dependencies"] = [
                target_id if d == source_id else d
                for d in f["dependencies"]
            ]

    metadata_file.write_text(json.dumps(metadata, indent=2) + "\n")

    # Update BACKLOG.json
    _rebuild_staging_backlog(staging, metadata)
    # Rebuild FEATURES.md
    _rebuild_staging_features(staging, metadata)

    return True, [f"Merged {source_id} into {target_id}"]


def split_staging_feature(
    project_root: Path,
    feature_id: str,
    split_spec: list[dict],
) -> tuple[bool, list[str]]:
    """Split feature into N new features.

    Args:
        split_spec: [{name: str, criteria: [int]}]
            criteria is list of 1-based AC indices to assign to each child.
            Unassigned ACs are kept in the original feature.
    """
    staging = _staging_dir(project_root)
    if not staging.exists():
        return False, ["No staging area found"]

    metadata_file = staging / ".metadata.json"
    try:
        metadata = json.loads(metadata_file.read_text())
    except (json.JSONDecodeError, OSError):
        return False, ["Metadata corrupt"]

    features = metadata.get("features", [])
    original = next((f for f in features if f["placeholder_id"] == feature_id), None)
    if not original:
        return False, [f"Feature {feature_id} not found"]

    # Read original AC file
    staging_spec = staging / "spec" / "acceptance"
    original_ac_file = staging_spec / f"{feature_id}.md"
    if not original_ac_file.exists():
        return False, [f"AC file missing for {feature_id}"]

    original_content = original_ac_file.read_text()
    ac_lines = [
        line for line in original_content.splitlines()
        if line.strip().startswith("- [ ] **AC-")
    ]

    # Validate indices
    all_assigned: set[int] = set()
    for spec in split_spec:
        for idx in spec.get("criteria", []):
            if idx < 1 or idx > len(ac_lines):
                return False, [f"AC index {idx} out of range (1-{len(ac_lines)})"]
            if idx in all_assigned:
                return False, [f"AC index {idx} assigned to multiple children"]
            all_assigned.add(idx)

    # Determine next placeholder number
    existing_nums = []
    for f in features:
        pid = f["placeholder_id"]
        if pid.startswith(_PLACEHOLDER_PREFIX):
            try:
                existing_nums.append(int(pid[len(_PLACEHOLDER_PREFIX):]))
            except ValueError:
                pass
    next_num = max(existing_nums) + 1 if existing_nums else 1

    # Create new features
    new_features = []
    messages = []
    for i, spec in enumerate(split_spec):
        new_pid = f"{_PLACEHOLDER_PREFIX}{next_num + i:03d}"
        new_name = spec.get("name", f"Split from {feature_id}")
        assigned_indices = set(spec.get("criteria", []))
        new_criteria = [ac_lines[idx - 1] for idx in sorted(assigned_indices)]

        # Write AC file
        ac_content = [
            _PROPOSAL_MARKER,
            f"# {new_pid}: {new_name}",
            "",
            "## Acceptance Criteria",
            "",
        ]
        for j, criterion in enumerate(new_criteria, 1):
            renumbered = re.sub(r"\*\*AC-\d+\*\*", f"**AC-{j:03d}**", criterion)
            ac_content.append(renumbered)
        ac_content.append("")
        (staging_spec / f"{new_pid}.md").write_text("\n".join(ac_content))

        new_feature_meta = {
            "placeholder_id": new_pid,
            "name": new_name,
            "criteria_count": len(new_criteria),
            "dependencies": list(original.get("dependencies", [])),
        }
        new_features.append(new_feature_meta)
        messages.append(f"Created {new_pid}: {new_name} ({len(new_criteria)} ACs)")

    # Update original: keep unassigned ACs
    unassigned_indices = set(range(1, len(ac_lines) + 1)) - all_assigned
    if unassigned_indices:
        remaining_criteria = [ac_lines[idx - 1] for idx in sorted(unassigned_indices)]
        ac_content = [
            _PROPOSAL_MARKER,
            f"# {feature_id}: {original.get('name', '?')}",
            "",
            "## Acceptance Criteria",
            "",
        ]
        for j, criterion in enumerate(remaining_criteria, 1):
            renumbered = re.sub(r"\*\*AC-\d+\*\*", f"**AC-{j:03d}**", criterion)
            ac_content.append(renumbered)
        ac_content.append("")
        original_ac_file.write_text("\n".join(ac_content))
        original["criteria_count"] = len(remaining_criteria)
    else:
        # All ACs assigned to children — remove original
        original_ac_file.unlink(missing_ok=True)
        metadata["features"] = [f for f in features if f["placeholder_id"] != feature_id]

    # Add new features
    metadata["features"].extend(new_features)
    metadata["feature_count"] = len(metadata["features"])
    metadata_file.write_text(json.dumps(metadata, indent=2) + "\n")

    _rebuild_staging_backlog(staging, metadata)
    _rebuild_staging_features(staging, metadata)

    return True, messages


def rename_staging_feature(
    project_root: Path, feature_id: str, new_name: str
) -> tuple[bool, list[str]]:
    """Rename a feature in staging."""
    staging = _staging_dir(project_root)
    if not staging.exists():
        return False, ["No staging area found"]

    metadata_file = staging / ".metadata.json"
    try:
        metadata = json.loads(metadata_file.read_text())
    except (json.JSONDecodeError, OSError):
        return False, ["Metadata corrupt"]

    feature = next(
        (f for f in metadata.get("features", []) if f["placeholder_id"] == feature_id),
        None,
    )
    if not feature:
        return False, [f"Feature {feature_id} not found"]

    old_name = feature.get("name", "?")
    feature["name"] = new_name
    metadata_file.write_text(json.dumps(metadata, indent=2) + "\n")

    # Update AC file header
    staging_spec = staging / "spec" / "acceptance"
    ac_file = staging_spec / f"{feature_id}.md"
    if ac_file.exists():
        content = ac_file.read_text()
        content = re.sub(
            rf"^# {re.escape(feature_id)}:.*$",
            f"# {feature_id}: {new_name}",
            content,
            flags=re.MULTILINE,
        )
        ac_file.write_text(content)

    _rebuild_staging_features(staging, metadata)
    _rebuild_staging_backlog(staging, metadata)

    return True, [f"Renamed {feature_id}: '{old_name}' → '{new_name}'"]


def reorder_staging_backlog(
    project_root: Path, ordered_ids: list[str]
) -> tuple[bool, list[str]]:
    """Set backlog order. ordered_ids: list of placeholder IDs in desired order."""
    staging = _staging_dir(project_root)
    if not staging.exists():
        return False, ["No staging area found"]

    metadata_file = staging / ".metadata.json"
    try:
        metadata = json.loads(metadata_file.read_text())
    except (json.JSONDecodeError, OSError):
        return False, ["Metadata corrupt"]

    known_ids = {f["placeholder_id"] for f in metadata.get("features", [])}
    for pid in ordered_ids:
        if pid not in known_ids:
            return False, [f"Unknown feature ID: {pid}"]

    # Build ordered backlog
    feature_map = {f["placeholder_id"]: f for f in metadata.get("features", [])}
    backlog_items = []
    for pid in ordered_ids:
        f = feature_map[pid]
        backlog_items.append({
            "type": "feature",
            "id": pid,
            "description": f.get("name", pid),
            "added_by": "kickoff",
        })
    # Append any features not in ordered_ids
    for pid in known_ids - set(ordered_ids):
        f = feature_map[pid]
        backlog_items.append({
            "type": "feature",
            "id": pid,
            "description": f.get("name", pid),
            "added_by": "kickoff",
        })

    backlog_file = staging / "BACKLOG.json"
    backlog_file.write_text(json.dumps(backlog_items, indent=2) + "\n")

    return True, [f"Reordered backlog: {', '.join(ordered_ids)}"]


def remove_staging_feature(
    project_root: Path, feature_id: str
) -> tuple[bool, list[str]]:
    """Remove feature from staging. Cascade-deletes AC file and BACKLOG entry."""
    staging = _staging_dir(project_root)
    if not staging.exists():
        return False, ["No staging area found"]

    metadata_file = staging / ".metadata.json"
    try:
        metadata = json.loads(metadata_file.read_text())
    except (json.JSONDecodeError, OSError):
        return False, ["Metadata corrupt"]

    features = metadata.get("features", [])
    feature = next((f for f in features if f["placeholder_id"] == feature_id), None)
    if not feature:
        return False, [f"Feature {feature_id} not found"]

    # Remove AC file
    staging_spec = staging / "spec" / "acceptance"
    ac_file = staging_spec / f"{feature_id}.md"
    ac_file.unlink(missing_ok=True)

    # Remove from metadata
    metadata["features"] = [f for f in features if f["placeholder_id"] != feature_id]
    metadata["feature_count"] = len(metadata["features"])

    # Clean up deps referencing removed feature
    for f in metadata["features"]:
        if feature_id in f.get("dependencies", []):
            f["dependencies"] = [d for d in f["dependencies"] if d != feature_id]

    metadata_file.write_text(json.dumps(metadata, indent=2) + "\n")

    _rebuild_staging_backlog(staging, metadata)
    _rebuild_staging_features(staging, metadata)

    return True, [f"Removed {feature_id}: {feature.get('name', '?')}"]


# ---------------------------------------------------------------------------
# Promote staging (AC-005, AC-008, AC-010, AC-014)
# ---------------------------------------------------------------------------

def promote_staging(
    project_root: Path, force_overview: bool = False
) -> tuple[bool, list[str]]:
    """Move staging artifacts to real spec files.

    1. Validates staging
    2. Checks review_decomposition gate (AC-008)
    3. Allocates fresh feature IDs via get_next_feature_id()
    4. Appends features to FEATURES.md
    5. Creates spec/contracts/F-XXXX.yaml files (and legacy spec/acceptance/F-XXXX.md)
    6. Adds entries to BACKLOG.json via backlog_helpers.cmd_add()
    7. Copies OVERVIEW.md (fails if exists unless force_overview) (AC-014)
    8. Removes staging directory on success

    On failure: staging remains intact for retry.
    """
    success, messages, _id_map = _promote_staging_impl(
        project_root, force_overview,
    )
    return success, messages


def promote_staging_with_ids(
    project_root: Path,
    force_overview: bool = False,
    parent_id: str = "",
) -> tuple[bool, list[str], dict[str, str]]:
    """Like promote_staging but also returns id_map {placeholder → real_id}.

    Args:
        project_root: Project root path.
        force_overview: Overwrite existing OVERVIEW.md.
        parent_id: Optional parent feature ID. When set, each promoted
            feature gets ``**Parent**: {parent_id}`` in its FEATURES.md
            section (written at creation time, not retroactively).

    Returns:
        (success, messages, id_map) where id_map maps placeholder IDs
        to real feature IDs.
    """
    return _promote_staging_impl(project_root, force_overview, parent_id)


def _promote_staging_impl(
    project_root: Path,
    force_overview: bool = False,
    parent_id: str = "",
) -> tuple[bool, list[str], dict[str, str]]:
    """Core promote logic returning (success, messages, id_map)."""
    messages: list[str] = []

    # Validate first
    valid, errors = validate_staging(project_root)
    if not valid:
        return False, ["Validation failed:"] + errors, {}

    staging = _staging_dir(project_root)
    paths = get_paths(project_root)

    # Check review_decomposition gate (AC-008)
    review_mode = get_setting(project_root, "review_decomposition", "skip")
    if review_mode == "human":
        messages.append(
            "REVIEW REQUIRED: review_decomposition is set to 'human'."
        )
        messages.append(
            "Review the staging artifacts with `ag kickoff --review`, "
            "then re-run `ag kickoff --approve`."
        )
        # In human mode, the shell layer handles the gate.
        # We proceed here because the shell already confirmed.

    # Check OVERVIEW.md collision (AC-014)
    overview_src = staging / "OVERVIEW.md"
    if overview_src.exists() and paths.overview_file.exists():
        existing = paths.overview_file.read_text().strip()
        if existing and not force_overview:
            return False, [
                "OVERVIEW.md already exists. Use --force to overwrite, "
                "or remove the existing file first."
            ], {}

    # Load metadata
    metadata_file = staging / ".metadata.json"
    try:
        metadata = json.loads(metadata_file.read_text())
    except (json.JSONDecodeError, OSError):
        return False, ["Metadata corrupt — cannot promote"], {}

    features = metadata.get("features", [])

    # Allocate fresh IDs
    next_id = get_next_feature_id(paths.features_file)
    id_map: dict[str, str] = {}  # placeholder → real
    for i, feature in enumerate(features):
        real_id = format_feature_id(next_id + i)
        id_map[feature["placeholder_id"]] = real_id

    # Append features to FEATURES.md
    features_file = paths.features_file
    if not features_file.exists():
        return False, ["FEATURES.md not found"], {}

    new_sections: list[str] = []
    for feature in features:
        real_id = id_map[feature["placeholder_id"]]
        name = feature.get("name", "Unnamed")
        deps = feature.get("dependencies", [])
        # Remap placeholder deps to real IDs
        real_deps = [id_map.get(d, d) for d in deps]

        section_lines = [
            f"## {real_id}: {name}",
            "",
            "**Status**: planned",
            "**Category**: Proposed",
        ]
        if parent_id:
            section_lines.append(f"**Parent**: {parent_id}")
        if real_deps:
            section_lines.append(f"**Dependencies**: {', '.join(real_deps)}")
        section_lines.extend([
            "",
            f"**Description**: {feature.get('description') or feature.get('name', 'TBD')}",
            "",
            f"**Acceptance**: See `spec/contracts/{real_id}.yaml`",
            "",
            "---",
            "",
        ])
        new_sections.append("\n".join(section_lines))

    with open(features_file, "a") as f:
        f.write("\n")
        for section in new_sections:
            f.write(section + "\n")

    # Create real AC files (both contract YAML and legacy acceptance markdown)
    staging_spec = staging / "spec" / "acceptance"
    acceptance_dir = paths.acceptance_dir
    acceptance_dir.mkdir(parents=True, exist_ok=True)
    contracts_dir = paths.contracts_dir
    contracts_dir.mkdir(parents=True, exist_ok=True)

    for feature in features:
        placeholder = feature["placeholder_id"]
        real_id = id_map[placeholder]
        src_ac = staging_spec / f"{placeholder}.md"
        if src_ac.exists():
            content = src_ac.read_text()
            # Strip proposal marker
            content = content.replace(_PROPOSAL_MARKER + "\n", "")
            content = content.replace(_PROPOSAL_MARKER, "")
            # Replace placeholder ID with real ID
            content = content.replace(placeholder, real_id)
            # Write legacy acceptance markdown
            dest_ac = acceptance_dir / f"{real_id}.md"
            dest_ac.write_text(content)

    # Add to BACKLOG.json via backlog_helpers
    from tools.backlog_helpers import cmd_add as backlog_add
    backlog_file = paths.backlog_file

    # Read staging backlog order
    staging_backlog = staging / "BACKLOG.json"
    if staging_backlog.exists():
        try:
            order = json.loads(staging_backlog.read_text())
            ordered_placeholders = [item.get("id") for item in order]
        except (json.JSONDecodeError, OSError):
            ordered_placeholders = [f["placeholder_id"] for f in features]
    else:
        ordered_placeholders = [f["placeholder_id"] for f in features]

    for placeholder in ordered_placeholders:
        if placeholder in id_map:
            real_id = id_map[placeholder]
            feature_meta = next(
                (f for f in features if f["placeholder_id"] == placeholder), {}
            )
            desc = feature_meta.get("name", real_id)
            backlog_add(project_root, backlog_file, [real_id, "--desc", desc])

    # Create v2 work items for promoted features (best-effort)
    _create_v2_kickoff_work_items(
        project_root, features, id_map, parent_id, messages,
    )

    # Copy OVERVIEW.md
    if overview_src.exists():
        content = overview_src.read_text()
        content = content.replace(_PROPOSAL_MARKER + "\n", "")
        content = content.replace(_PROPOSAL_MARKER, "")
        paths.overview_file.parent.mkdir(parents=True, exist_ok=True)
        paths.overview_file.write_text(content)
        messages.append("Promoted OVERVIEW.md")

    # Report ID mappings
    for placeholder, real_id in id_map.items():
        feature_meta = next(
            (f for f in features if f["placeholder_id"] == placeholder), {}
        )
        messages.append(f"  {placeholder} → {real_id}: {feature_meta.get('name', '?')}")

    messages.append(f"\nPromoted {len(features)} features to real spec files")

    # Clean up staging
    shutil.rmtree(staging)
    messages.append("Staging area removed")

    return True, messages, id_map


# ---------------------------------------------------------------------------
# Discard staging (AC-006)
# ---------------------------------------------------------------------------

def discard_staging(project_root: Path) -> tuple[bool, list[str]]:
    """Delete staging directory (rollback)."""
    staging = _staging_dir(project_root)
    if not staging.exists():
        return False, ["No staging area to discard"]

    shutil.rmtree(staging)
    return True, ["Staging area discarded"]


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

def _order_by_dependencies(features_data: list[dict]) -> list[dict]:
    """Order features so dependencies come first (topological sort)."""
    # Build name→feature map for dependency resolution
    name_to_feature: dict[str, dict] = {}
    for f in features_data:
        name_to_feature[f.get("name", "")] = f
        name_to_feature[f["_placeholder_id"]] = f

    # Simple topological sort
    ordered: list[dict] = []
    visited: set[str] = set()

    def visit(feature: dict) -> None:
        pid = feature["_placeholder_id"]
        if pid in visited:
            return
        visited.add(pid)
        for dep in feature.get("dependencies", []):
            if dep in name_to_feature:
                visit(name_to_feature[dep])
        ordered.append(feature)

    for f in features_data:
        visit(f)

    return ordered


def _rebuild_staging_backlog(staging: Path, metadata: dict) -> None:
    """Rebuild BACKLOG.json from metadata."""
    features = metadata.get("features", [])
    backlog_items = []
    for f in features:
        backlog_items.append({
            "type": "feature",
            "id": f["placeholder_id"],
            "description": f.get("name", f["placeholder_id"]),
            "added_by": "kickoff",
        })
    (staging / "BACKLOG.json").write_text(
        json.dumps(backlog_items, indent=2) + "\n"
    )


def _rebuild_staging_features(staging: Path, metadata: dict) -> None:
    """Rebuild FEATURES.md from metadata."""
    features = metadata.get("features", [])
    lines = [f"{_PROPOSAL_MARKER}\n# Proposed Features\n"]
    for f in features:
        pid = f["placeholder_id"]
        name = f.get("name", "Unnamed")
        desc = f.get("description", "")
        deps = f.get("dependencies", [])
        section = [
            f"\n## {pid}: {name}\n",
            "**Status**: planned",
            "**Category**: Proposed",
        ]
        if deps:
            section.append(f"**Dependencies**: {', '.join(deps)}")
        section.extend([
            "",
            f"**Description**: {desc}" if desc else "**Description**: _TBD_",
            "",
            f"**Acceptance**: See `spec/contracts/{pid}.yaml`",
            "",
            "---",
            "",
        ])
        lines.append("\n".join(section))
    (staging / "FEATURES.md").write_text("\n".join(lines))


def _create_v2_kickoff_work_items(
    project_root: Path,
    features: list[dict],
    id_map: dict[str, str],
    parent_id: str,
    messages: list[str],
) -> None:
    """No-op: v2 work items removed (hooks-first simplification F-0244).

    Features are tracked in FEATURES.md via feature.sh (the v1 path).
    """
    pass


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------

def main() -> int:
    """CLI for kickoff operations."""
    import argparse

    parser = argparse.ArgumentParser(
        description="Vision-to-Backlog pipeline: staging management"
    )
    subparsers = parser.add_subparsers(dest="command")

    # generate
    gen_parser = subparsers.add_parser(
        "generate", help="Generate features to staging"
    )
    gen_parser.add_argument(
        "--features-json", required=True,
        help="JSON string or @file with features data",
    )
    gen_parser.add_argument(
        "--overview", default=None,
        help="Overview text or @file",
    )
    gen_parser.add_argument(
        "--project-root", type=Path, default=Path.cwd(),
    )

    # validate
    val_parser = subparsers.add_parser(
        "validate", help="Validate staging area",
    )
    val_parser.add_argument(
        "--project-root", type=Path, default=Path.cwd(),
    )

    # review
    rev_parser = subparsers.add_parser(
        "review", help="Review staging artifacts",
    )
    rev_parser.add_argument(
        "--project-root", type=Path, default=Path.cwd(),
    )

    # promote
    prom_parser = subparsers.add_parser(
        "promote", help="Promote staging to real spec files",
    )
    prom_parser.add_argument(
        "--force", action="store_true",
        help="Overwrite existing OVERVIEW.md",
    )
    prom_parser.add_argument(
        "--project-root", type=Path, default=Path.cwd(),
    )

    # discard
    disc_parser = subparsers.add_parser(
        "discard", help="Discard staging area",
    )
    disc_parser.add_argument(
        "--project-root", type=Path, default=Path.cwd(),
    )

    # status
    stat_parser = subparsers.add_parser(
        "status", help="Show staging status",
    )
    stat_parser.add_argument(
        "--project-root", type=Path, default=Path.cwd(),
    )

    # edit operations
    merge_parser = subparsers.add_parser(
        "merge", help="Merge two staging features",
    )
    merge_parser.add_argument("source", help="Source feature ID to merge from")
    merge_parser.add_argument("target", help="Target feature ID to merge into")
    merge_parser.add_argument(
        "--project-root", type=Path, default=Path.cwd(),
    )

    rename_parser = subparsers.add_parser(
        "rename", help="Rename a staging feature",
    )
    rename_parser.add_argument("feature_id", help="Feature ID to rename")
    rename_parser.add_argument("new_name", help="New feature name")
    rename_parser.add_argument(
        "--project-root", type=Path, default=Path.cwd(),
    )

    remove_parser = subparsers.add_parser(
        "remove", help="Remove a staging feature",
    )
    remove_parser.add_argument("feature_id", help="Feature ID to remove")
    remove_parser.add_argument(
        "--project-root", type=Path, default=Path.cwd(),
    )

    split_parser = subparsers.add_parser(
        "split", help="Split a staging feature",
    )
    split_parser.add_argument("feature_id", help="Feature ID to split")
    split_parser.add_argument(
        "--spec-json", required=True,
        help='JSON: [{"name": "...", "criteria": [1,2]}]',
    )
    split_parser.add_argument(
        "--project-root", type=Path, default=Path.cwd(),
    )

    reorder_parser = subparsers.add_parser(
        "reorder", help="Reorder staging backlog",
    )
    reorder_parser.add_argument(
        "ids", nargs="+", help="Feature IDs in desired order",
    )
    reorder_parser.add_argument(
        "--project-root", type=Path, default=Path.cwd(),
    )

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        return 1

    project_root = args.project_root.resolve()

    if args.command == "generate":
        # Load features data
        features_json = args.features_json
        if features_json.startswith("@"):
            features_json = Path(features_json[1:]).read_text()
        features_data = json.loads(features_json)

        overview = args.overview
        if overview and overview.startswith("@"):
            overview = Path(overview[1:]).read_text()

        success, messages = generate_to_staging(
            project_root, features_data, overview
        )
        for msg in messages:
            print(msg)
        return 0 if success else 1

    elif args.command == "validate":
        valid, errors = validate_staging(project_root)
        if valid:
            print("Staging is valid")
        else:
            print("Validation errors:")
            for err in errors:
                print(f"  - {err}")
        return 0 if valid else 1

    elif args.command == "review":
        success, summary = review_staging(project_root)
        if not success:
            print(summary.get("error", "Review failed"))
            return 1
        print(json.dumps(summary, indent=2))
        return 0

    elif args.command == "promote":
        success, messages = promote_staging(
            project_root, force_overview=args.force
        )
        for msg in messages:
            print(msg)
        return 0 if success else 1

    elif args.command == "discard":
        success, messages = discard_staging(project_root)
        for msg in messages:
            print(msg)
        return 0 if success else 1

    elif args.command == "status":
        status = staging_status(project_root)
        print(json.dumps(status, indent=2))
        return 0

    elif args.command == "merge":
        success, messages = merge_staging_features(
            project_root, args.source, args.target
        )
        for msg in messages:
            print(msg)
        return 0 if success else 1

    elif args.command == "rename":
        success, messages = rename_staging_feature(
            project_root, args.feature_id, args.new_name
        )
        for msg in messages:
            print(msg)
        return 0 if success else 1

    elif args.command == "remove":
        success, messages = remove_staging_feature(
            project_root, args.feature_id
        )
        for msg in messages:
            print(msg)
        return 0 if success else 1

    elif args.command == "split":
        spec_json = args.spec_json
        if spec_json.startswith("@"):
            spec_json = Path(spec_json[1:]).read_text()
        split_spec = json.loads(spec_json)
        success, messages = split_staging_feature(
            project_root, args.feature_id, split_spec
        )
        for msg in messages:
            print(msg)
        return 0 if success else 1

    elif args.command == "reorder":
        success, messages = reorder_staging_backlog(
            project_root, args.ids
        )
        for msg in messages:
            print(msg)
        return 0 if success else 1

    return 1


if __name__ == "__main__":
    sys.exit(main())
