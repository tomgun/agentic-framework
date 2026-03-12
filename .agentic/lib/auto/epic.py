"""
epic.py -- Epic decomposition and parent-child status derivation.

Implements F-0184: `ag decompose F-XXXX` analyzes an epic's acceptance criteria,
proposes child features scoped to components, routes through review_decomposition
checkpoint, and manages parent-child status cascade.

@feature F-0184

Usage:
    # Decompose an epic into child features
    python -m auto.epic decompose F-0100

    # Recompute an epic's derived status from children
    python -m auto.epic recompute F-0100

    # Programmatic
    from auto.epic import decompose, derive_epic_status, recompute_epic_status
"""
from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path
from typing import Optional

# ---------------------------------------------------------------------------
# Resolve paths.py from the lib/ directory (our parent)
# ---------------------------------------------------------------------------
_LIB_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(_LIB_DIR))
sys.path.insert(0, str(_LIB_DIR / "tools"))
from paths import get_paths  # noqa: E402
from settings import get_setting  # noqa: E402
from auto.components import Component, load_registry  # noqa: E402

# ---------------------------------------------------------------------------
# Feature ID validation
# ---------------------------------------------------------------------------

_FEATURE_ID_RE = re.compile(r"^F-\d{4,}$")


def _validate_feature_id(feature_id: str) -> None:
    """Validate feature ID format to prevent path traversal."""
    if not _FEATURE_ID_RE.match(feature_id):
        raise ValueError(
            f"Invalid feature ID: '{feature_id}'. Must match F-XXXX format."
        )


# ---------------------------------------------------------------------------
# State ordering (mirrors state_machine.py without importing it to avoid
# circular deps at module level)
# ---------------------------------------------------------------------------

_STATE_ORDER = [
    "planned", "specced", "criteria_set", "tests_written",
    "implementing", "verified", "documented", "committed", "shipped",
]

_ACTIVE_STATES = {"implementing", "verified", "documented", "committed"}


# ---------------------------------------------------------------------------
# Epic status derivation (AC-005)
# ---------------------------------------------------------------------------

def derive_epic_status(children_statuses: list[str]) -> Optional[str]:
    """Derive an epic's status from its children's statuses.

    Rules:
        - Empty list → None (don't change epic status)
        - All deprecated → "deprecated"
        - Filter out deprecated, then:
          - All shipped → "shipped"
          - Any active (implementing/verified/documented/committed) → "implementing"
          - All criteria_set or earlier → "criteria_set"
          - Otherwise → min(children) by state order

    Args:
        children_statuses: List of child status strings.

    Returns:
        Derived status string, or None if no children.
    """
    if not children_statuses:
        return None

    # Filter deprecated
    non_deprecated = [s for s in children_statuses if s != "deprecated"]

    # All deprecated
    if not non_deprecated:
        return "deprecated"

    # All shipped
    if all(s == "shipped" for s in non_deprecated):
        return "shipped"

    # Any active state
    if any(s in _ACTIVE_STATES for s in non_deprecated):
        return "implementing"

    # All criteria_set or earlier
    early_states = {"planned", "specced", "criteria_set"}
    if all(s in early_states for s in non_deprecated):
        return "criteria_set"

    # Fallback: minimum state by order
    def state_index(s: str) -> int:
        try:
            return _STATE_ORDER.index(s)
        except ValueError:
            return 0  # Unknown states treated as earliest
    return min(non_deprecated, key=state_index)


# ---------------------------------------------------------------------------
# Epic status recomputation (AC-006)
# ---------------------------------------------------------------------------

def recompute_epic_status(
    project_root: Path, epic_id: str, _depth: int = 0
) -> tuple[bool, list[str]]:
    """Recompute an epic's status from its children and update if changed.

    Uses feature.sh directly (not state machine transition) because epic
    status is derived, not independently transitioned.

    Args:
        project_root: Project root path.
        epic_id: The epic feature ID.
        _depth: Recursion depth guard (max 3).

    Returns:
        (changed, messages) — whether status was updated.
    """
    if _depth >= 3:
        return False, [f"Max depth reached recomputing {epic_id}"]

    _validate_feature_id(epic_id)
    paths = get_paths(project_root)
    messages: list[str] = []

    # Load children
    children = _get_children_statuses(paths.features_file, epic_id)
    if not children:
        return False, [f"No children found for {epic_id}"]

    derived = derive_epic_status(children)
    if derived is None:
        return False, []

    # Get current epic status
    current = _get_feature_status(paths.features_file, epic_id)
    if current == derived:
        return False, []

    # Update via feature.sh
    feature_sh = paths.tools_dir / "feature.sh"
    result = subprocess.run(
        ["bash", str(feature_sh), epic_id, "status", derived],
        capture_output=True, text=True,
        cwd=str(project_root),
    )
    if result.returncode != 0:
        return False, [
            f"Failed to update {epic_id} status: {result.stderr.strip()}"
        ]

    messages.append(
        f"Epic {epic_id}: {current} → {derived} (derived from children)"
    )

    # Recurse upward: if this epic itself has a parent, recompute that too
    parent_id = _get_feature_parent(paths.features_file, epic_id)
    if parent_id:
        changed, parent_msgs = recompute_epic_status(
            project_root, parent_id, _depth + 1
        )
        messages.extend(parent_msgs)

    return True, messages


# ---------------------------------------------------------------------------
# Decomposition proposal (AC-001, AC-002)
# ---------------------------------------------------------------------------

def propose_decomposition(
    project_root: Path, epic_id: str
) -> list[dict]:
    """Propose child features by splitting AC file on AC-NNN groups.

    Each AC-NNN group becomes a candidate child feature. If a component
    registry exists, children are tagged with matching components based
    on keyword overlap.

    Args:
        project_root: Project root path.
        epic_id: The epic feature ID.

    Returns:
        List of child feature dicts with keys:
        id, name, parent, component, ac_lines
    """
    _validate_feature_id(epic_id)
    paths = get_paths(project_root)

    # Read AC file
    ac_file = paths.acceptance_dir / f"{epic_id}.md"
    if not ac_file.exists():
        raise FileNotFoundError(
            f"No acceptance criteria file: {ac_file}"
        )
    ac_content = ac_file.read_text()

    # Parse AC groups
    ac_groups = _parse_ac_groups(ac_content)
    if not ac_groups:
        raise ValueError(
            f"No AC-NNN entries found in {ac_file}. "
            f"Expected lines like '- [ ] **AC-001**: ...'"
        )

    # Load component registry (may be empty)
    registry = load_registry(project_root)
    components = registry.list_all()

    # Get next available feature ID
    next_id = get_next_feature_id(paths.features_file)

    # Build child proposals
    children: list[dict] = []
    for i, (ac_id, ac_text, ac_lines) in enumerate(ac_groups):
        child_id = f"F-{next_id + i:04d}"
        name = _derive_child_name(ac_id, ac_text, epic_id)
        component = _match_component(ac_text, ac_lines, components)

        children.append({
            "id": child_id,
            "name": name,
            "parent": epic_id,
            "component": component.name if component else None,
            "ac_lines": ac_lines,
        })

    return children


# ---------------------------------------------------------------------------
# Child feature creation (AC-004, AC-008)
# ---------------------------------------------------------------------------

def create_child_features(
    project_root: Path, epic_id: str, children: list[dict]
) -> tuple[bool, list[str]]:
    """Write child feature entries to FEATURES.md and create AC files.

    Appends new feature sections to FEATURES.md with Parent field.
    Creates component-scoped AC files in spec/acceptance/.

    Args:
        project_root: Project root path.
        epic_id: The parent epic ID.
        children: List of child dicts from propose_decomposition().

    Returns:
        (success, messages)
    """
    _validate_feature_id(epic_id)
    paths = get_paths(project_root)
    messages: list[str] = []

    features_file = paths.features_file
    if not features_file.exists():
        return False, ["FEATURES.md not found"]

    # Get epic metadata for context
    epic_name = _get_feature_name(features_file, epic_id) or epic_id
    epic_category = _get_feature_category(features_file, epic_id)

    # Build FEATURES.md entries
    new_sections: list[str] = []
    for child in children:
        section = _build_feature_section(child, epic_name, epic_category)
        new_sections.append(section)

    # Append to FEATURES.md
    with open(features_file, "a") as f:
        f.write("\n")
        for section in new_sections:
            f.write(section)

    # Create AC files
    acceptance_dir = paths.acceptance_dir
    acceptance_dir.mkdir(parents=True, exist_ok=True)

    for child in children:
        ac_file = acceptance_dir / f"{child['id']}.md"
        ac_content = _build_child_ac(child, epic_id)
        ac_file.write_text(ac_content)
        messages.append(f"Created {child['id']}: {child['name']}")

    messages.append(
        f"Created {len(children)} child features for {epic_id}"
    )
    return True, messages


# ---------------------------------------------------------------------------
# Decompose orchestrator (AC-003)
# ---------------------------------------------------------------------------

def decompose(
    project_root: Path,
    epic_id: str,
    force: bool = False,
    confirm: bool = False,
) -> tuple[bool, list[str]]:
    """Decompose an epic into child features.

    Flow: validate → propose → review checkpoint → create.

    Args:
        project_root: Project root path.
        epic_id: The epic feature ID.
        force: Allow re-decomposition if children exist.
        confirm: Skip review gate (used after human reviews proposal).

    Returns:
        (success, messages)
    """
    _validate_feature_id(epic_id)
    paths = get_paths(project_root)
    messages: list[str] = []

    # --- Precondition checks ---

    # Feature must exist
    status = _get_feature_status(paths.features_file, epic_id)
    if status is None:
        return False, [f"Feature {epic_id} not found in FEATURES.md"]

    # Must be in planned or specced state
    if status not in ("planned", "specced"):
        return False, [
            f"Feature {epic_id} is in '{status}' state. "
            f"Decomposition requires 'planned' or 'specced'."
        ]

    # AC file must exist
    ac_file = paths.acceptance_dir / f"{epic_id}.md"
    if not ac_file.exists():
        return False, [
            f"No acceptance criteria file for {epic_id}. "
            f"Create {ac_file} first."
        ]

    # Idempotency check
    existing_children = _get_children_statuses(
        paths.features_file, epic_id
    )
    if existing_children and not force:
        return False, [
            f"{epic_id} already has {len(existing_children)} children. "
            f"Use --force to re-decompose."
        ]

    # --- Propose ---
    try:
        children = propose_decomposition(project_root, epic_id)
    except (FileNotFoundError, ValueError) as e:
        return False, [str(e)]

    if not children:
        return False, [f"No child features proposed for {epic_id}"]

    # --- Review checkpoint (DD-2: direct get_setting, not check_review) ---
    if not confirm:
        review_mode = get_setting(project_root, "review_decomposition", "skip")

        if review_mode == "human":
            # Print proposal for human review
            messages.append(f"Proposed decomposition of {epic_id}:")
            messages.append("")
            for child in children:
                comp_str = f" [{child['component']}]" if child.get("component") else ""
                messages.append(f"  {child['id']}: {child['name']}{comp_str}")
                for line in child["ac_lines"]:
                    messages.append(f"    {line}")
            messages.append("")
            messages.append(
                "Review the proposal above, then re-run with --confirm:"
            )
            messages.append(f"  ag decompose {epic_id} --confirm")
            return True, messages

        # skip (or critical_agent for v1) → proceed
        if review_mode not in ("skip", "critical_agent"):
            messages.append(
                f"Unknown review_decomposition mode: '{review_mode}', "
                f"proceeding as skip"
            )

    # --- Create child features ---
    success, create_msgs = create_child_features(
        project_root, epic_id, children
    )
    messages.extend(create_msgs)

    return success, messages


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

def _get_feature_status(features_file: Path, feature_id: str) -> Optional[str]:
    """Read a feature's status from FEATURES.md."""
    if not features_file.exists():
        return None
    content = features_file.read_text()
    pattern = re.compile(
        rf"^## {re.escape(feature_id)}:.*$", re.MULTILINE
    )
    match = pattern.search(content)
    if not match:
        return None

    section = _extract_section(content, match.end())
    status_match = re.search(r"\*\*Status\*\*:\s*(\S+)", section)
    if not status_match:
        status_match = re.search(r"- Status:\s*(\S+)", section)
    if not status_match:
        return None
    return status_match.group(1).lower().replace("-", "_")


def _get_feature_name(features_file: Path, feature_id: str) -> Optional[str]:
    """Read a feature's name from FEATURES.md."""
    if not features_file.exists():
        return None
    content = features_file.read_text()
    match = re.search(
        rf"^## {re.escape(feature_id)}:\s*(.+?)\s*$",
        content, re.MULTILINE,
    )
    return match.group(1) if match else None


def _get_feature_category(features_file: Path, feature_id: str) -> Optional[str]:
    """Read a feature's category from FEATURES.md."""
    if not features_file.exists():
        return None
    content = features_file.read_text()
    pattern = re.compile(
        rf"^## {re.escape(feature_id)}:.*$", re.MULTILINE
    )
    match = pattern.search(content)
    if not match:
        return None

    section = _extract_section(content, match.end())
    cat_match = re.search(r"\*\*Category\*\*:\s*(\S+)", section)
    if not cat_match:
        cat_match = re.search(r"- Category:\s*(\S+)", section)
    return cat_match.group(1) if cat_match else None


def _get_feature_parent(features_file: Path, feature_id: str) -> Optional[str]:
    """Read a feature's parent from FEATURES.md."""
    if not features_file.exists():
        return None
    content = features_file.read_text()
    pattern = re.compile(
        rf"^## {re.escape(feature_id)}:.*$", re.MULTILINE
    )
    match = pattern.search(content)
    if not match:
        return None

    section = _extract_section(content, match.end())
    parent_match = re.search(
        r"(?:\*\*Parent\*\*|- Parent):\s*(F-\d{4,})", section
    )
    return parent_match.group(1) if parent_match else None


def _get_children_statuses(
    features_file: Path, parent_id: str
) -> list[str]:
    """Get status list for all children of a feature."""
    if not features_file.exists():
        return []
    content = features_file.read_text()

    from query_features import parse_features, get_children

    features = parse_features(content)
    children = get_children(features, parent_id)
    return [c.get("status", "planned") for c in children]


def _extract_section(content: str, start: int) -> str:
    """Extract a feature section from start position to next header."""
    section = content[start:]
    next_header = re.search(r"^## F-\d{4}:", section, re.MULTILINE)
    if next_header:
        section = section[:next_header.start()]
    return section


def get_next_feature_id(features_file: Path) -> int:
    """Get the next available feature ID number.

    Note: not atomic — concurrent operations could allocate overlapping IDs.
    Acceptable because callers (decompose, kickoff) are human-gated.

    Public API — used by kickoff.py for ID allocation at promotion time.
    """
    if not features_file.exists():
        return 1

    content = features_file.read_text()
    ids = [int(m.group(1)) for m in re.finditer(r"^## F-(\d{4,}):", content, re.MULTILINE)]
    return max(ids) + 1 if ids else 1


def _parse_ac_groups(ac_content: str) -> list[tuple[str, str, list[str]]]:
    """Parse AC file into groups of (ac_id, summary_text, all_lines).

    Groups on AC-NNN markers. Lines before the first AC-NNN are ignored.
    """
    groups: list[tuple[str, str, list[str]]] = []
    current_id: Optional[str] = None
    current_text = ""
    current_lines: list[str] = []

    ac_re = re.compile(r"\*\*AC-(\d+)\*\*:\s*(.+)")

    for line in ac_content.splitlines():
        m = ac_re.search(line)
        if m:
            # Save previous group
            if current_id is not None:
                groups.append((current_id, current_text, current_lines))
            current_id = f"AC-{m.group(1)}"
            current_text = m.group(2).strip()
            current_lines = [line.strip()]
        elif current_id is not None:
            stripped = line.strip()
            if stripped:
                current_lines.append(stripped)

    # Save last group
    if current_id is not None:
        groups.append((current_id, current_text, current_lines))

    return groups


def _derive_child_name(ac_id: str, ac_text: str, epic_id: str) -> str:
    """Derive a child feature name from AC text.

    Truncates to ~60 chars and cleans up for use as a feature title.
    """
    # Remove markdown formatting
    name = re.sub(r'[`*\[\]]', '', ac_text)
    # Remove leading verbs that are AC-specific
    name = re.sub(r'^(shall|must|should|will)\s+', '', name, flags=re.IGNORECASE)
    # Capitalize first letter
    if name:
        name = name[0].upper() + name[1:]
    # Truncate
    if len(name) > 60:
        name = name[:57] + "..."
    return name or f"{epic_id} child ({ac_id})"


def _match_component(
    ac_text: str,
    ac_lines: list[str],
    components: list[Component],
) -> Optional[Component]:
    """Match AC text to a component by keyword/path overlap."""
    if not components:
        return None

    combined = " ".join([ac_text] + ac_lines).lower()
    best_match = None
    best_score = 0

    for comp in components:
        score = 0
        # Check component name
        if comp.name.lower() in combined:
            score += 3
        # Check component path segments
        for segment in comp.path.split("/"):
            if len(segment) > 2 and segment.lower() in combined:
                score += 2
        # Check component type
        if comp.type.lower() in combined:
            score += 1
        if score > best_score:
            best_score = score
            best_match = comp

    return best_match if best_score > 0 else None


def _build_feature_section(
    child: dict, epic_name: str, category: Optional[str] = None
) -> str:
    """Build a FEATURES.md section for a child feature."""
    cat = category or "Uncategorized"
    lines = [
        f"## {child['id']}: {child['name']}",
        "",
        "**Status**: planned",
        f"**Category**: {cat}",
        f"**Parent**: {child['parent']}",
    ]
    if child.get("component"):
        lines.append(f"**Component**: {child['component']}")
    lines.extend([
        "",
        f"**Description**: Child feature of {child['parent']} ({epic_name}).",
        "",
        f"**Acceptance**: See `spec/acceptance/{child['id']}.md`",
        "",
        "---",
        "",
    ])
    return "\n".join(lines)


def _build_child_ac(child: dict, epic_id: str) -> str:
    """Build a component-scoped AC file for a child feature."""
    lines = [
        f"# {child['id']}: {child['name']}",
        "",
        f"**Parent**: {epic_id}",
    ]
    if child.get("component"):
        lines.append(f"**Component**: {child['component']}")
    lines.extend([
        "",
        "## Acceptance Criteria",
        "",
    ])
    for ac_line in child["ac_lines"]:
        # Re-wrap as checkboxes if not already
        if ac_line.startswith("- ["):
            lines.append(ac_line)
        else:
            lines.append(f"- [ ] {ac_line}")
    lines.append("")
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------

def main() -> int:
    """CLI for `ag decompose` and `ag epic`."""
    import argparse

    parser = argparse.ArgumentParser(
        description="Epic decomposition and status management"
    )
    subparsers = parser.add_subparsers(dest="command")

    # decompose
    decompose_parser = subparsers.add_parser(
        "decompose", help="Decompose an epic into child features"
    )
    decompose_parser.add_argument("feature_id", help="Epic feature ID (e.g., F-0100)")
    decompose_parser.add_argument(
        "--force", action="store_true",
        help="Allow re-decomposition if children exist",
    )
    decompose_parser.add_argument(
        "--confirm", action="store_true",
        help="Confirm proposal after human review",
    )
    decompose_parser.add_argument(
        "--project-root", type=Path, default=Path.cwd(),
    )

    # recompute
    recompute_parser = subparsers.add_parser(
        "recompute", help="Recompute epic status from children"
    )
    recompute_parser.add_argument("feature_id", help="Epic feature ID")
    recompute_parser.add_argument(
        "--project-root", type=Path, default=Path.cwd(),
    )

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        return 1

    project_root = args.project_root.resolve()

    if args.command == "decompose":
        success, messages = decompose(
            project_root, args.feature_id,
            force=args.force, confirm=args.confirm,
        )
        for msg in messages:
            print(msg)
        return 0 if success else 1

    if args.command == "recompute":
        changed, messages = recompute_epic_status(
            project_root, args.feature_id,
        )
        for msg in messages:
            print(msg)
        if not changed and not messages:
            print(f"Epic {args.feature_id} status unchanged")
        return 0

    return 1


if __name__ == "__main__":
    sys.exit(main())
