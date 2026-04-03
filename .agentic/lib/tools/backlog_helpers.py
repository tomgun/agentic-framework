"""
backlog_helpers.py -- JSON manipulation for BACKLOG.json.

Called by backlog.sh. Handles add/remove/move/list/current/done/clear.
"""
from __future__ import annotations

import json
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Callable, Optional

_LIB_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(_LIB_DIR))
from paths import get_paths  # noqa: E402


def _now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _load(backlog_file: Path) -> list[dict]:
    if not backlog_file.exists():
        return []
    try:
        data = json.loads(backlog_file.read_text())
        if not isinstance(data, list):
            return []
        # Normalize depends_on: accept string or list, always return list
        for item in data:
            deps = item.get("depends_on")
            if isinstance(deps, str):
                item["depends_on"] = [deps] if deps else []
        return data
    except (json.JSONDecodeError, OSError):
        return []


def _save(backlog_file: Path, items: list[dict]) -> None:
    backlog_file.parent.mkdir(parents=True, exist_ok=True)
    backlog_file.write_text(json.dumps(items, indent=2) + "\n")


def _find_index(items: list[dict], feature_id: str) -> int:
    """Find index of a feature item by ID. Returns -1 if not found."""
    for i, item in enumerate(items):
        if item.get("id") == feature_id:
            return i
    return -1


def _auto_discover_refs(project_root: Path, feature_id: str) -> list[str]:
    """Auto-discover plan and acceptance criteria files for a feature."""
    refs = []
    paths = get_paths(project_root)
    plan = paths.plans_dir / f"{feature_id}-plan.md"
    if plan.exists():
        refs.append(str(plan.relative_to(project_root)))
    # Prefer contract YAML, fall back to legacy acceptance markdown
    contract = paths.contracts_dir / f"{feature_id}.yaml"
    ac = paths.acceptance_dir / f"{feature_id}.md"
    if contract.exists():
        refs.append(str(contract.relative_to(project_root)))
    elif ac.exists():
        refs.append(str(ac.relative_to(project_root)))
    return refs


def _feature_title(project_root: Path, feature_id: str) -> str:
    """Look up the feature title from FEATURES.md. Returns '' if not found."""
    paths = get_paths(project_root)
    ff = paths.features_file
    if not ff.exists():
        return ""
    prefix = f"## {feature_id}: "
    for line in ff.read_text().splitlines():
        if line.startswith(prefix):
            return line[len(prefix):].strip()
    return ""


def _feature_exists_in_registry(project_root: Path, feature_id: str) -> bool:
    """Check if feature is registered in FEATURES.md."""
    paths = get_paths(project_root)
    ff = paths.features_file
    if not ff.exists():
        return True  # no registry = no check
    content = ff.read_text()
    return f"## {feature_id}:" in content


def cmd_add(project_root: Path, backlog_file: Path, args: list[str]) -> int:
    """Add an item to the backlog."""
    items = _load(backlog_file)

    # Parse args
    position: Optional[int] = None
    description = ""
    extra_refs: list[str] = []
    note = ""
    is_task = False
    depends_on: list[str] = []
    feature_id = ""

    i = 0
    while i < len(args):
        arg = args[i]
        if arg == "--task":
            is_task = True
            i += 1
            if i < len(args) and not args[i].startswith("-"):
                description = args[i]
                i += 1
        elif arg in ("--position", "-p"):
            i += 1
            if i < len(args):
                position = int(args[i])
                i += 1
        elif arg == "--desc":
            i += 1
            if i < len(args):
                description = args[i]
                i += 1
        elif arg == "--ref":
            i += 1
            if i < len(args):
                extra_refs.append(args[i])
                i += 1
        elif arg == "--note":
            i += 1
            if i < len(args):
                note = args[i]
                i += 1
        elif arg == "--dep":
            i += 1
            if i < len(args):
                depends_on.append(args[i])
                i += 1
        elif arg.startswith("F-") and not feature_id:
            feature_id = arg
            i += 1
        else:
            i += 1

    now = _now_iso()

    if is_task:
        if not description:
            print("Error: --task requires a description", file=sys.stderr)
            return 1
        item: dict = {
            "type": "task",
            "description": description,
            "added_at": now,
            "added_by": "agent",
        }
        if extra_refs:
            item["refs"] = extra_refs
        if note:
            item["notes"] = note
    else:
        if not feature_id:
            print("Error: feature ID required (e.g. F-0200)", file=sys.stderr)
            return 1

        # Validate feature exists in FEATURES.md
        if not _feature_exists_in_registry(project_root, feature_id):
            print(f"Error: {feature_id} not found in FEATURES.md", file=sys.stderr)
            return 1

        # Check duplicate
        if _find_index(items, feature_id) >= 0:
            print(f"Error: {feature_id} already in backlog", file=sys.stderr)
            return 1

        # Auto-discover refs
        refs = _auto_discover_refs(project_root, feature_id)
        refs.extend(extra_refs)

        item = {
            "type": "feature",
            "id": feature_id,
            "description": description or _feature_title(project_root, feature_id) or feature_id,
            "added_at": now,
            "added_by": "agent",
        }
        if refs:
            item["refs"] = refs
        if note:
            item["notes"] = note
        if depends_on:
            item["depends_on"] = depends_on

    # Position
    if position is not None:
        if position <= 0:
            items.insert(0, item)
            item["became_current_at"] = now
        elif position >= len(items):
            items.append(item)
        else:
            items.insert(position, item)
    else:
        items.append(item)

    _save(backlog_file, items)
    label = item.get("id", item.get("description", "task"))
    pos = items.index(item)
    print(f"Added: {label} at position {pos}")
    return 0


def cmd_current(backlog_file: Path) -> int:
    """Print position 0."""
    items = _load(backlog_file)
    if not items:
        print("Backlog is empty", file=sys.stderr)
        return 1
    _print_item(items[0], 0)
    return 0


def cmd_next(backlog_file: Path) -> int:
    """Print position 1."""
    items = _load(backlog_file)
    if len(items) < 2:
        print("No next item", file=sys.stderr)
        return 1
    _print_item(items[1], 1)
    return 0


def _get_feature_status(project_root: Path, feature_id: str) -> Optional[str]:
    """Return the status string for a feature from FEATURES.md, or None if not found."""
    paths = get_paths(project_root)
    ff = paths.features_file
    if not ff.exists():
        return None
    content = ff.read_text()
    pattern = rf"## {re.escape(feature_id)}:.*?\n(.*?)(?=\n## [A-Z]|\Z)"
    match = re.search(pattern, content, re.DOTALL)
    if not match:
        return None
    section = match.group(1)
    status_match = re.search(r"\*\*Status\*\*:\s*(\w+)", section)
    if not status_match:
        return None
    return status_match.group(1)


def _is_feature_shipped(project_root: Path, feature_id: str) -> bool:
    """Check if a feature is marked as shipped in FEATURES.md."""
    status = _get_feature_status(project_root, feature_id)
    if status is None:
        return True  # not found = allow removal
    return status == "shipped"


def cmd_done(project_root: Path, backlog_file: Path) -> int:
    """Remove position 0, advance queue. Validates feature is actually shipped."""
    items = _load(backlog_file)
    if not items:
        print("Backlog is empty", file=sys.stderr)
        return 1

    current = items[0]
    # Safety check: if it's a feature, verify it's actually shipped
    if current.get("type") == "feature" and current.get("id"):
        fid = current["id"]
        if not _is_feature_shipped(project_root, fid):
            print(f"BLOCKED: {fid} is not shipped in FEATURES.md", file=sys.stderr)
            print(f"  Complete the feature first, or use 'backlog.sh remove {fid}' to force-remove", file=sys.stderr)
            return 1

    removed = items.pop(0)
    label = removed.get("id", removed.get("description", "task"))
    print(f"Done: {label}")

    if items:
        # Find first unblocked item to promote
        # Completed IDs = everything ever done (we track by not being in backlog)
        remaining_ids = {it.get("id") for it in items if it.get("id")}
        promoted = False
        for idx, item in enumerate(items):
            deps = item.get("depends_on", [])
            unmet = [d for d in deps if d in remaining_ids]
            if not unmet:
                if idx > 0:
                    # Move this item to position 0
                    items.insert(0, items.pop(idx))
                    print(f"Skipped items with unmet deps; promoted: {item.get('id', item.get('description'))}")
                items[0]["became_current_at"] = _now_iso()
                promoted = True
                break

        if not promoted:
            # All remaining have unmet deps — promote first anyway with warning
            items[0]["became_current_at"] = _now_iso()
            print("WARNING: All remaining items have unmet dependencies")

        new_label = items[0].get("id", items[0].get("description", "task"))
        print(f"Next up: {new_label} — {items[0].get('description', '')}")
    else:
        print("Backlog is now empty")

    _save(backlog_file, items)
    return 0


def cmd_list(backlog_file: Path) -> int:
    """Print full backlog."""
    items = _load(backlog_file)
    if not items:
        print("Backlog is empty")
        return 0
    for i, item in enumerate(items):
        _print_item(item, i, show_current=(i == 0))
    print(f"\n{len(items)} item(s) total")

    # Change 10: Triage nudge — if TODO.md has untriaged items, suggest triage
    todo_file = backlog_file.parent / "TODO.md"
    if todo_file.exists():
        try:
            content = todo_file.read_text()
            inbox_count = content.count("\n- T-")
            if inbox_count >= 5:
                print(f"\n💡 {inbox_count} untriaged items in TODO.md — run `ag todo triage` to promote or dismiss")
        except OSError:
            pass

    return 0


def cmd_remove(backlog_file: Path, target: str) -> int:
    """Remove item by ID."""
    items = _load(backlog_file)
    idx = _find_index(items, target)
    if idx < 0:
        print(f"Error: {target} not found in backlog", file=sys.stderr)
        return 1
    items.pop(idx)
    _save(backlog_file, items)
    print(f"Removed: {target}")
    return 0


def cmd_move(backlog_file: Path, target: str, position: int) -> int:
    """Move item to position."""
    items = _load(backlog_file)
    idx = _find_index(items, target)
    if idx < 0:
        print(f"Error: {target} not found in backlog", file=sys.stderr)
        return 1
    item = items.pop(idx)
    if position <= 0:
        items.insert(0, item)
        item["became_current_at"] = _now_iso()
    elif position >= len(items):
        items.append(item)
    else:
        items.insert(position, item)
    _save(backlog_file, items)
    new_pos = items.index(item)
    print(f"Moved: {target} to position {new_pos}")
    return 0


def cmd_clear(backlog_file: Path) -> int:
    """Clear backlog."""
    _save(backlog_file, [])
    print("Backlog cleared")
    return 0


def cmd_json_current(backlog_file: Path) -> int:
    """Print position 0 as JSON (for ag.sh consumption)."""
    items = _load(backlog_file)
    if not items:
        return 1
    print(json.dumps(items[0]))
    return 0


def cmd_json_all(backlog_file: Path) -> int:
    """Print all items as JSON (for ag.sh consumption)."""
    items = _load(backlog_file)
    print(json.dumps(items))
    return 0


def cmd_check_staleness(backlog_file: Path, days: int = 7) -> int:
    """Check if current item is stale. Exit 0 = stale, exit 1 = fresh/empty."""
    items = _load(backlog_file)
    if not items:
        return 1
    became = items[0].get("became_current_at")
    if not became:
        return 1
    try:
        dt = datetime.fromisoformat(became.replace("Z", "+00:00"))
        age = (datetime.now(timezone.utc) - dt).days
        if age >= days:
            label = items[0].get("id", items[0].get("description", "item"))
            print(f"WARNING: Current backlog item has been active for {age} days ({label})")
            print("  Still relevant? Or: ag backlog done | ag backlog clear")
            return 0
    except (ValueError, TypeError):
        pass
    return 1


def cmd_upsert(project_root: Path, backlog_file: Path, feature_id: str) -> int:
    """Auto-upsert: add feature at position 0 if not in backlog."""
    items = _load(backlog_file)
    idx = _find_index(items, feature_id)
    if idx >= 0:
        # Already in backlog — return position
        print(str(idx))
        return 0

    # Auto-add at position 0
    refs = _auto_discover_refs(project_root, feature_id)
    now = _now_iso()
    item: dict = {
        "type": "feature",
        "id": feature_id,
        "description": _feature_title(project_root, feature_id) or feature_id,
        "added_at": now,
        "added_by": "auto",
        "became_current_at": now,
    }
    if refs:
        item["refs"] = refs
    items.insert(0, item)
    _save(backlog_file, items)
    print("0")  # position
    return 0


def cmd_check_deps(backlog_file: Path, feature_id: str) -> int:
    """Check if feature has unmet dependencies. Exit 0 = deps ok, exit 2 = unmet deps."""
    items = _load(backlog_file)
    idx = _find_index(items, feature_id)
    if idx < 0:
        return 0  # not in backlog, no deps to check
    item = items[idx]
    deps = item.get("depends_on", [])
    if not deps:
        return 0
    remaining_ids = {it.get("id") for it in items if it.get("id")}
    unmet = [d for d in deps if d in remaining_ids]
    if unmet:
        for d in unmet:
            print(f"UNMET: {d}")
        return 2
    return 0


def _has_commits_on_main(project_root: Path, feature_id: str) -> int:
    """Check if a feature has implementation commits on main (excluding .agentic/ state files).
    Returns the number of matching commits, or 0 if none."""
    count = 0
    # Check commit messages mentioning the feature ID, excluding .agentic/ paths
    try:
        result = subprocess.run(
            ["git", "log", "--oneline", f"--grep={feature_id}", "main",
             "--", ":!.agentic/"],
            capture_output=True, text=True, cwd=project_root, timeout=10,
        )
        if result.returncode == 0 and result.stdout.strip():
            count += len(result.stdout.strip().splitlines())
    except (subprocess.TimeoutExpired, FileNotFoundError):
        pass
    # Also check for merged feature branches (feat/F-XXXX-*)
    try:
        result = subprocess.run(
            ["git", "branch", "--list", f"feat/{feature_id}-*", "--merged", "main"],
            capture_output=True, text=True, cwd=project_root, timeout=10,
        )
        if result.returncode == 0 and result.stdout.strip():
            count += len(result.stdout.strip().splitlines())
    except (subprocess.TimeoutExpired, FileNotFoundError):
        pass
    return count


def cmd_check_completion_gate(
    project_root: Path,
    backlog_file: Path,
    feature_id: str,
    has_commits_fn: Optional[Callable[[Path, str], int]] = None,
) -> int:
    """Check if any prior backlog item has commits on main but is still 'planned'.
    Outputs JSON: {"blocked": true/false, "stale_feature": "F-XXXX", ...}"""
    if has_commits_fn is None:
        has_commits_fn = _has_commits_on_main

    items = _load(backlog_file)
    if not items:
        print(json.dumps({"blocked": False}))
        return 0

    # Find target feature position
    target_idx = _find_index(items, feature_id)
    if target_idx < 0:
        # Not in backlog — check position 0 only
        target_idx = 1  # check item at 0

    # Check all items before the target
    for i in range(target_idx):
        item = items[i]
        # Skip task-type items (no feature ID to check)
        if item.get("type") != "feature":
            continue
        item_id = item.get("id", "")
        if not item_id:
            continue

        status = _get_feature_status(project_root, item_id)
        # Only trigger on "planned" — in_progress, implementing, partial, etc. are intentional
        if status != "planned":
            continue

        commit_count = has_commits_fn(project_root, item_id)
        if commit_count > 0:
            print(json.dumps({
                "blocked": True,
                "stale_feature": item_id,
                "status": status,
                "commit_count": commit_count,
            }))
            return 0

    print(json.dumps({"blocked": False}))
    return 0


def _print_item(item: dict, pos: int, show_current: bool = False) -> None:
    """Format and print a backlog item."""
    itype = item.get("type", "task")
    label = item.get("id", "")
    desc = item.get("description", "")

    suffix = ""
    if show_current:
        suffix = "  <- CURRENT"

    deps = item.get("depends_on", [])
    dep_str = f"  (depends: {', '.join(deps)})" if deps else ""

    if itype == "feature":
        display = f"{label} — {desc}" if desc and desc != label else label
        print(f"[{pos}] {display}{dep_str}{suffix}")
    else:
        print(f"[{pos}] {desc}  (task){dep_str}{suffix}")

    notes = item.get("notes")
    if notes:
        print(f"     NOTE: {notes}")
    refs = item.get("refs", [])
    for ref in refs:
        print(f"     REF:  {ref}")


def main() -> int:
    # Manual arg parsing — argparse doesn't handle pass-through flags well
    args = sys.argv[1:]

    project_root_str = "."
    # Extract --project-root
    i = 0
    clean_args: list[str] = []
    while i < len(args):
        if args[i] == "--project-root" and i + 1 < len(args):
            project_root_str = args[i + 1]
            i += 2
        else:
            clean_args.append(args[i])
            i += 1

    if not clean_args:
        print("Usage: backlog_helpers.py [--project-root PATH] <command> [args...]", file=sys.stderr)
        return 1

    cmd = clean_args[0]
    rest = clean_args[1:]

    valid_cmds = {
        "add", "current", "next", "done", "list", "remove", "move", "clear",
        "json-current", "json-all", "check-staleness", "upsert", "check-deps",
        "check-completion-gate",
    }
    if cmd not in valid_cmds:
        print(f"Unknown command: {cmd}", file=sys.stderr)
        return 1

    project_root = Path(project_root_str).resolve()
    paths = get_paths(project_root)
    backlog_file = paths.backlog_file

    if cmd == "add":
        return cmd_add(project_root, backlog_file, rest)
    elif cmd == "current":
        return cmd_current(backlog_file)
    elif cmd == "next":
        return cmd_next(backlog_file)
    elif cmd == "done":
        return cmd_done(project_root, backlog_file)
    elif cmd == "list":
        return cmd_list(backlog_file)
    elif cmd == "remove":
        if not rest:
            print("Error: ID required", file=sys.stderr)
            return 1
        return cmd_remove(backlog_file, rest[0])
    elif cmd == "move":
        if len(rest) < 2:
            print("Error: ID and position required", file=sys.stderr)
            return 1
        return cmd_move(backlog_file, rest[0], int(rest[1]))
    elif cmd == "clear":
        return cmd_clear(backlog_file)
    elif cmd == "json-current":
        return cmd_json_current(backlog_file)
    elif cmd == "json-all":
        return cmd_json_all(backlog_file)
    elif cmd == "check-staleness":
        days = int(rest[0]) if rest else 7
        return cmd_check_staleness(backlog_file, days)
    elif cmd == "upsert":
        if not rest:
            print("Error: feature ID required", file=sys.stderr)
            return 1
        return cmd_upsert(project_root, backlog_file, rest[0])
    elif cmd == "check-deps":
        if not rest:
            print("Error: feature ID required", file=sys.stderr)
            return 1
        return cmd_check_deps(backlog_file, rest[0])
    elif cmd == "check-completion-gate":
        if not rest:
            print("Error: feature ID required", file=sys.stderr)
            return 1
        return cmd_check_completion_gate(project_root, backlog_file, rest[0])
    return 1


if __name__ == "__main__":
    sys.exit(main())
