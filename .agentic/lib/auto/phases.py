"""
phases.py -- Multi-session plan phase tracking (F-0303).

Extracts phases from approved plans and tracks completion in tasks.yaml.
Phases are the top-level work structure; tasks nest inside (D3 extension).

Usage (Python API):
    from auto.phases import extract_phases_from_plan, create_tasks_file
    phases = extract_phases_from_plan(Path("plan.md"))
    create_tasks_file(Path("."), "F-0042", phases, "plan.md")

Usage (CLI — via phase.sh):
    ag phase list F-0042
    ag phase done F-0042 2
"""
from __future__ import annotations

import re
import sys
from datetime import date
from pathlib import Path
from typing import Optional

# YAML handling: prefer ruamel.yaml for round-trip, fall back to PyYAML
try:
    from ruamel.yaml import YAML as _RYAML

    def _yaml_load(path: Path) -> dict:
        yaml = _RYAML()
        yaml.preserve_quotes = True
        with open(path) as f:
            return dict(yaml.load(f) or {})

    def _yaml_dump(data: dict, path: Path) -> None:
        yaml = _RYAML()
        yaml.default_flow_style = False
        with open(path, "w") as f:
            yaml.dump(data, f)

except ImportError:
    import yaml as _pyyaml  # type: ignore[no-redef]

    def _yaml_load(path: Path) -> dict:  # type: ignore[misc]
        with open(path) as f:
            return dict(_pyyaml.safe_load(f) or {})

    def _yaml_dump(data: dict, path: Path) -> None:  # type: ignore[misc]
        with open(path, "w") as f:
            _pyyaml.dump(data, f, default_flow_style=False, sort_keys=False)


# ---------------------------------------------------------------------------
# Phase extraction from plan markdown
# ---------------------------------------------------------------------------

# Covers observed formats:
#   ## Phase 0: Title (2-3 sessions)
#   ## Phase 3A: Title
#   ## Phase 1: Title — subtitle (estimate)
#   ## Phase 2 Algorithm: Title
_PHASE_RE = re.compile(
    r"^##\s+Phase\s+(\d+[A-Za-z]?)\s*:?\s+(.+?)(?:\s*\(([^)]+)\))?\s*$"
)

# Suffixes to strip from titles (status markers added during execution)
_TITLE_STRIP_RE = re.compile(
    r"\s*(?:✅\s*COMPLETE|—\s*NEXT|—\s*ACTIVE|🔄\s*IN\s*PROGRESS|⏭\s*SKIPPED)\s*$",
    re.IGNORECASE,
)


def extract_phases_from_plan(plan_path: Path) -> list[dict]:
    """Parse ## Phase N: Title (estimate) headers from a plan file.

    Returns empty list if no phases found (single-phase plans).
    """
    if not plan_path.exists():
        return []

    phases = []
    for line in plan_path.read_text().splitlines():
        m = _PHASE_RE.match(line)
        if m:
            phase_id = m.group(1)
            title = _TITLE_STRIP_RE.sub("", m.group(2)).strip()
            estimate = m.group(3) or ""
            phases.append({
                "id": phase_id,
                "title": title,
                "status": "pending",
                "sessions_estimate": estimate,
                "completed_at": None,
                "tasks": [],
            })
    return phases


# ---------------------------------------------------------------------------
# tasks.yaml CRUD
# ---------------------------------------------------------------------------

def _tasks_file_path(project_root: Path, feature_id: str) -> Path:
    return project_root / ".agentic" / "work" / feature_id / "tasks.yaml"


def create_tasks_file(
    project_root: Path,
    feature_id: str,
    phases: list[dict],
    plan_path: str,
) -> Path:
    """Write .agentic/work/F-XXXX/tasks.yaml. Atomic write."""
    path = _tasks_file_path(project_root, feature_id)
    path.parent.mkdir(parents=True, exist_ok=True)

    data = {
        "feature": feature_id,
        "source_plan": str(plan_path),
        "created": str(date.today()),
        "phases": phases,
    }

    # Atomic write via temp file
    tmp = path.with_suffix(".yaml.tmp")
    _yaml_dump(data, tmp)
    tmp.rename(path)
    return path


def load_tasks_file(
    project_root: Path, feature_id: str,
) -> Optional[dict]:
    """Load tasks.yaml for a feature. Returns None if missing."""
    path = _tasks_file_path(project_root, feature_id)
    if not path.exists():
        return None
    return _yaml_load(path)


def _save_tasks_file(project_root: Path, feature_id: str, data: dict) -> None:
    """Save tasks.yaml back to disk."""
    path = _tasks_file_path(project_root, feature_id)
    tmp = path.with_suffix(".yaml.tmp")
    _yaml_dump(data, tmp)
    tmp.rename(path)


# Valid status transitions
_VALID_TRANSITIONS = {
    ("pending", "active"),
    ("pending", "dropped"),
    ("active", "complete"),
    ("active", "dropped"),
}


def update_phase_status(
    project_root: Path,
    feature_id: str,
    phase_id: str,
    new_status: str,
) -> bool:
    """Update a phase's status. Returns True on success.

    Valid transitions: pending→active, pending→dropped,
    active→complete, active→dropped.
    Sets completed_at on complete.
    """
    data = load_tasks_file(project_root, feature_id)
    if data is None:
        return False

    for phase in data.get("phases", []):
        if str(phase["id"]) == str(phase_id):
            current = phase["status"]
            if (current, new_status) not in _VALID_TRANSITIONS:
                print(
                    f"Invalid transition: {current} → {new_status} "
                    f"(valid from {current}: "
                    f"{[t for f, t in _VALID_TRANSITIONS if f == current]})",
                    file=sys.stderr,
                )
                return False
            phase["status"] = new_status
            if new_status == "complete":
                phase["completed_at"] = str(date.today())
            elif new_status == "dropped":
                phase["completed_at"] = str(date.today())
            _save_tasks_file(project_root, feature_id, data)
            return True

    print(f"Phase {phase_id} not found in {feature_id}", file=sys.stderr)
    return False


def get_progress_summary(
    project_root: Path, feature_id: str,
) -> Optional[str]:
    """Returns '2/5 phases complete' or None if no tasks.yaml."""
    data = load_tasks_file(project_root, feature_id)
    if data is None:
        return None
    phases = data.get("phases", [])
    if not phases:
        return None
    done = sum(1 for p in phases if p["status"] in ("complete", "dropped"))
    total = len(phases)
    return f"{done}/{total} phases complete"


def get_next_phase(
    project_root: Path, feature_id: str,
) -> Optional[dict]:
    """Returns the next actionable phase (first active, or first pending)."""
    data = load_tasks_file(project_root, feature_id)
    if data is None:
        return None
    phases = data.get("phases", [])
    # First active phase
    for p in phases:
        if p["status"] == "active":
            return p
    # First pending phase
    for p in phases:
        if p["status"] == "pending":
            return p
    return None


def has_incomplete_phases(
    project_root: Path, feature_id: str,
) -> tuple[bool, str]:
    """Check if feature has incomplete phases. For done.sh gate.

    Returns (has_incomplete, message).
    """
    data = load_tasks_file(project_root, feature_id)
    if data is None:
        return (False, "")

    phases = data.get("phases", [])
    if not phases:
        return (False, "")

    done = sum(1 for p in phases if p["status"] in ("complete", "dropped"))
    total = len(phases)
    incomplete = [p for p in phases if p["status"] not in ("complete", "dropped")]

    if incomplete:
        next_phase = incomplete[0]
        return (
            True,
            f"{done}/{total} phases complete — "
            f"Phase {next_phase['id']}: {next_phase['title']} is {next_phase['status']}",
        )
    return (False, f"All {total} phases complete")


def sync_phases_with_plan(
    project_root: Path,
    feature_id: str,
    plan_path: Path,
) -> dict:
    """Reconcile tasks.yaml with a (potentially revised) plan.

    - New phases in plan → added as pending
    - Removed phases from plan → marked as dropped
    - Existing phases → preserved (status, completed_at unchanged)

    Returns summary: {added: [...], dropped: [...], unchanged: [...]}.
    """
    data = load_tasks_file(project_root, feature_id)
    plan_phases = extract_phases_from_plan(plan_path)

    if data is None:
        # No existing tasks.yaml — create fresh
        if plan_phases:
            create_tasks_file(project_root, feature_id, plan_phases, str(plan_path))
        return {"added": [p["id"] for p in plan_phases], "dropped": [], "unchanged": []}

    existing_by_id = {str(p["id"]): p for p in data.get("phases", [])}
    plan_ids = {str(p["id"]) for p in plan_phases}

    result = {"added": [], "dropped": [], "unchanged": []}
    new_phases = []

    # Process plan phases (preserves plan order)
    for pp in plan_phases:
        pid = str(pp["id"])
        if pid in existing_by_id:
            # Keep existing status
            new_phases.append(existing_by_id[pid])
            result["unchanged"].append(pid)
        else:
            new_phases.append(pp)
            result["added"].append(pid)

    # Mark removed phases as dropped (append at end)
    for pid, existing in existing_by_id.items():
        if pid not in plan_ids:
            if existing["status"] not in ("complete", "dropped"):
                existing["status"] = "dropped"
                existing["completed_at"] = str(date.today())
            new_phases.append(existing)
            result["dropped"].append(pid)

    data["phases"] = new_phases
    data["source_plan"] = str(plan_path)
    _save_tasks_file(project_root, feature_id, data)
    return result


# ---------------------------------------------------------------------------
# CLI entry point (called by phase.sh via python3)
# ---------------------------------------------------------------------------

def main() -> int:
    """CLI for phase operations. Called by phase.sh."""
    import argparse

    parser = argparse.ArgumentParser(description="Phase tracking (F-0303)")
    parser.add_argument("--project-root", type=Path, default=Path.cwd())
    sub = parser.add_subparsers(dest="command")

    # list
    p_list = sub.add_parser("list", help="Show phases and status")
    p_list.add_argument("feature_id")

    # update (done/active/drop)
    p_update = sub.add_parser("update", help="Update phase status")
    p_update.add_argument("feature_id")
    p_update.add_argument("phase_id")
    p_update.add_argument("new_status", choices=["active", "complete", "dropped"])

    # sync
    p_sync = sub.add_parser("sync", help="Re-parse plan, reconcile")
    p_sync.add_argument("feature_id")

    # progress (for shell scripts — outputs single line)
    p_prog = sub.add_parser("progress", help="Single-line progress summary")
    p_prog.add_argument("feature_id")

    # check (for done.sh gate — exit 1 if incomplete)
    p_check = sub.add_parser("check", help="Check if all phases complete")
    p_check.add_argument("feature_id")

    # create-from-plan (for implement.sh fallback — avoids inline Python)
    p_create = sub.add_parser("create-from-plan", help="Extract phases from plan, create tasks.yaml")
    p_create.add_argument("feature_id")
    p_create.add_argument("plan_path")

    # next-phase (for dashboard — outputs single line)
    p_next = sub.add_parser("next-phase", help="Show next actionable phase")
    p_next.add_argument("feature_id")

    args = parser.parse_args()
    root = args.project_root.resolve()

    if args.command == "list":
        return _cmd_list(root, args.feature_id)
    elif args.command == "update":
        ok = update_phase_status(root, args.feature_id, args.phase_id, args.new_status)
        return 0 if ok else 1
    elif args.command == "sync":
        return _cmd_sync(root, args.feature_id)
    elif args.command == "progress":
        summary = get_progress_summary(root, args.feature_id)
        if summary:
            print(summary)
            return 0
        return 1
    elif args.command == "check":
        return _cmd_check(root, args.feature_id)
    elif args.command == "create-from-plan":
        return _cmd_create_from_plan(root, args.feature_id, args.plan_path)
    elif args.command == "next-phase":
        return _cmd_next_phase(root, args.feature_id)
    else:
        parser.print_help()
        return 1


def _cmd_list(root: Path, feature_id: str) -> int:
    data = load_tasks_file(root, feature_id)
    if data is None:
        print(f"No tasks.yaml for {feature_id}")
        return 1

    phases = data.get("phases", [])
    if not phases:
        print(f"{feature_id}: no phases tracked")
        return 0

    done = sum(1 for p in phases if p["status"] in ("complete", "dropped"))
    total = len(phases)

    # Get feature title from FEATURES.md if available
    features_file = root / ".agentic" / "spec" / "FEATURES.md"
    title = feature_id
    if features_file.exists():
        for line in features_file.read_text().splitlines():
            if line.startswith(f"## {feature_id}:"):
                title = line[3:].strip()  # strip "## " prefix
                break

    print(f"{title} ({done}/{total} phases complete)")
    for p in phases:
        status = p["status"]
        if status == "complete":
            icon = "✅"
            suffix = f"     {p.get('completed_at', '')}"
        elif status == "active":
            icon = "▶ "
            suffix = "    active"
        elif status == "dropped":
            icon = "⊘ "
            suffix = f"    dropped {p.get('completed_at', '')}"
        else:
            icon = "○ "
            suffix = "    pending"

        est = f" ({p['sessions_estimate']})" if p.get("sessions_estimate") else ""
        print(f"  {icon} Phase {p['id']}: {p['title']}{est}{suffix}")

    return 0


def _find_plan_for_feature(root: Path, feature_id: str) -> Optional[Path]:
    """Find the best plan file for a feature.

    Prefers the file with the most Phase headers (the actual multi-phase plan).
    Falls back to most recently modified.
    """
    _LIB_DIR = Path(__file__).resolve().parent.parent
    sys.path.insert(0, str(_LIB_DIR))
    from paths import get_paths
    paths = get_paths(root)

    if not paths.plans_dir.exists():
        return None
    all_matches = list(paths.plans_dir.glob(f"*{feature_id}*.md"))
    if not all_matches:
        return None

    # Prefer the file that actually has phase headers
    best = None
    best_count = -1
    for m in all_matches:
        phases = extract_phases_from_plan(m)
        if len(phases) > best_count:
            best_count = len(phases)
            best = m
    # If no file has phases, use the most recently modified
    if best_count == 0:
        all_matches.sort(key=lambda p: p.stat().st_mtime, reverse=True)
        best = all_matches[0]
    return best


def _cmd_sync(root: Path, feature_id: str) -> int:
    plan_path = _find_plan_for_feature(root, feature_id)
    if plan_path is None:
        print(f"No plan found for {feature_id}", file=sys.stderr)
        return 1
    result = sync_phases_with_plan(root, feature_id, plan_path)
    if result["added"]:
        print(f"Added phases: {', '.join(result['added'])}")
    if result["dropped"]:
        print(f"Dropped phases: {', '.join(result['dropped'])}")
    if result["unchanged"]:
        print(f"Unchanged phases: {', '.join(result['unchanged'])}")
    if not any(result.values()):
        print("No changes")
    return 0


def _cmd_check(root: Path, feature_id: str) -> int:
    """Exit 0 if all phases complete/dropped or no tasks.yaml. Exit 1 if incomplete."""
    incomplete, msg = has_incomplete_phases(root, feature_id)
    if incomplete:
        print(msg)
        return 1
    if msg:
        print(msg)
    return 0


def _cmd_create_from_plan(root: Path, feature_id: str, plan_path_str: str) -> int:
    """Extract phases from a plan file and create tasks.yaml."""
    plan_path = Path(plan_path_str)
    if not plan_path.exists():
        print(f"Plan file not found: {plan_path}", file=sys.stderr)
        return 1
    phases = extract_phases_from_plan(plan_path)
    if not phases:
        return 0  # No phases found — not an error
    create_tasks_file(root, feature_id, phases, plan_path_str)
    print(f"{len(phases)} phases extracted")
    return 0


def _cmd_next_phase(root: Path, feature_id: str) -> int:
    """Print the next actionable phase as a single line."""
    nxt = get_next_phase(root, feature_id)
    if nxt:
        print(f"Phase {nxt['id']}: {nxt['title']} {nxt['status']}")
        return 0
    return 1


if __name__ == "__main__":
    sys.exit(main())
