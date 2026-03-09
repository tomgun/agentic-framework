"""
agents_helpers.py -- JSON manipulation for AGENTS.json (agent/WIP registry).

Replaces both WIP.md and AGENTS_ACTIVE.md with a single machine-parseable registry.
Called by wip.sh and ag.sh. Handles register/activate/checkpoint/complete/list.

AGENTS.json schema (array of entries):
[
  {
    "feature_id": "F-0194",
    "description": "Worktree-by-default",
    "worktree": "/abs/path/to/repo-f-0194",
    "branch": "feature/F-0194",
    "agent": "claude-desktop",
    "started": "2026-03-09T14:30:00Z",
    "last_checkpoint": "2026-03-09T15:00:00Z",
    "status": "active",
    "progress": ["Created settings", "Wired ag implement"],
    "files": ["ag.sh", "worktree.sh"]
  }
]
"""
from __future__ import annotations

import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

_LIB_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(_LIB_DIR))
from paths import get_paths  # noqa: E402


def _now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


# ---------------------------------------------------------------------------
# File locking (best-effort: fcntl on Unix, no-op elsewhere)
# ---------------------------------------------------------------------------
try:
    import fcntl

    def _lock(f):
        fcntl.flock(f, fcntl.LOCK_EX)

    def _unlock(f):
        fcntl.flock(f, fcntl.LOCK_UN)
except ImportError:
    try:
        import msvcrt

        def _lock(f):
            msvcrt.locking(f.fileno(), msvcrt.LK_LOCK, 1)

        def _unlock(f):
            msvcrt.locking(f.fileno(), msvcrt.LK_UNLCK, 1)
    except ImportError:
        def _lock(f):
            pass

        def _unlock(f):
            pass


# ---------------------------------------------------------------------------
# Load / Save with locking
# ---------------------------------------------------------------------------
def _load(agents_file: Path) -> list[dict]:
    if not agents_file.exists():
        return []
    try:
        with open(agents_file, "r") as f:
            _lock(f)
            try:
                data = json.load(f)
            finally:
                _unlock(f)
        if not isinstance(data, list):
            return []
        return data
    except (json.JSONDecodeError, OSError):
        return []


def _save(agents_file: Path, items: list[dict]) -> None:
    agents_file.parent.mkdir(parents=True, exist_ok=True)
    with open(agents_file, "w") as f:
        _lock(f)
        try:
            json.dump(items, f, indent=2)
            f.write("\n")
        finally:
            _unlock(f)


def _find_by_feature(items: list[dict], feature_id: str) -> int:
    for i, item in enumerate(items):
        if item.get("feature_id") == feature_id:
            return i
    return -1


def _find_by_worktree(items: list[dict], worktree_path: str) -> int:
    norm = os.path.normpath(worktree_path)
    for i, item in enumerate(items):
        if os.path.normpath(item.get("worktree", "")) == norm:
            return i
    return -1


# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------
def cmd_register(agents_file: Path, feature_id: str, worktree: str,
                 branch: str, description: str = "") -> int:
    """Register a new agent entry (status: created)."""
    items = _load(agents_file)
    idx = _find_by_feature(items, feature_id)
    if idx >= 0:
        # Already registered — update worktree/branch if needed
        items[idx]["worktree"] = worktree
        items[idx]["branch"] = branch
        if description:
            items[idx]["description"] = description
        _save(agents_file, items)
        print(f"Updated: {feature_id}")
        return 0

    entry = {
        "feature_id": feature_id,
        "description": description or feature_id,
        "worktree": worktree,
        "branch": branch,
        "agent": "",
        "started": _now_iso(),
        "last_checkpoint": _now_iso(),
        "status": "created",
        "progress": [],
        "files": [],
    }
    items.append(entry)
    _save(agents_file, items)
    print(f"Registered: {feature_id}")
    return 0


def cmd_activate(agents_file: Path, feature_id: str, description: str = "",
                 files: str = "", agent: str = "") -> int:
    """Activate an entry (status: active). Creates if not exists."""
    items = _load(agents_file)
    idx = _find_by_feature(items, feature_id)
    now = _now_iso()

    if idx >= 0:
        items[idx]["status"] = "active"
        if description:
            items[idx]["description"] = description
        if files:
            items[idx]["files"] = [f.strip() for f in files.split(",") if f.strip()]
        if agent:
            items[idx]["agent"] = agent
        items[idx]["last_checkpoint"] = now
    else:
        # Auto-create entry (no worktree — working in main repo)
        items.append({
            "feature_id": feature_id,
            "description": description or feature_id,
            "worktree": os.environ.get("PROJECT_ROOT", os.getcwd()),
            "branch": "",
            "agent": agent,
            "started": now,
            "last_checkpoint": now,
            "status": "active",
            "progress": [],
            "files": [f.strip() for f in files.split(",") if f.strip()] if files else [],
        })

    _save(agents_file, items)
    print(f"Activated: {feature_id}")
    return 0


def cmd_checkpoint(agents_file: Path, feature_id: str, note: str) -> int:
    """Update checkpoint timestamp and append progress note."""
    items = _load(agents_file)
    idx = _find_by_feature(items, feature_id)
    if idx < 0:
        print(f"Error: {feature_id} not found", file=sys.stderr)
        return 1

    items[idx]["last_checkpoint"] = _now_iso()
    items[idx].setdefault("progress", []).append(note)
    _save(agents_file, items)
    print(f"Checkpoint: {feature_id} — {note}")
    return 0


def cmd_complete(agents_file: Path, feature_id: str) -> int:
    """Remove entry (feature complete)."""
    items = _load(agents_file)
    idx = _find_by_feature(items, feature_id)
    if idx < 0:
        # Not found is OK — idempotent
        print(f"No entry for {feature_id} (already complete)")
        return 0

    items.pop(idx)
    _save(agents_file, items)
    print(f"Completed: {feature_id}")
    return 0


def cmd_unregister(agents_file: Path, feature_id: str) -> int:
    """Alias for complete."""
    return cmd_complete(agents_file, feature_id)


def cmd_check_worktree(agents_file: Path, worktree_path: str) -> int:
    """Check if a worktree has an active entry. Exit 0 = has entry, 1 = no entry."""
    items = _load(agents_file)
    idx = _find_by_worktree(items, worktree_path)
    if idx >= 0:
        entry = items[idx]
        print(f"{entry['feature_id']}: {entry.get('description', '')} (status: {entry.get('status', 'unknown')})")
        return 0
    return 1


def cmd_get_active(agents_file: Path, feature_id: Optional[str] = None) -> int:
    """Get active entry. If feature_id given, get that specific entry."""
    items = _load(agents_file)
    if feature_id:
        idx = _find_by_feature(items, feature_id)
        if idx < 0:
            return 1
        print(json.dumps(items[idx]))
        return 0
    # Return first active entry
    for item in items:
        if item.get("status") == "active":
            print(json.dumps(item))
            return 0
    return 1


def cmd_get_current_feature(agents_file: Path) -> int:
    """Print the feature_id of the first active entry."""
    items = _load(agents_file)
    for item in items:
        if item.get("status") in ("active", "created"):
            print(item["feature_id"])
            return 0
    return 1


def cmd_list(agents_file: Path) -> int:
    """Print all entries in human-readable format."""
    items = _load(agents_file)
    if not items:
        print("No active agents")
        return 0

    now = datetime.now(timezone.utc)
    for item in items:
        fid = item.get("feature_id", "?")
        desc = item.get("description", "")
        status = item.get("status", "?")
        wt = item.get("worktree", "")
        started = item.get("started", "")
        checkpoint = item.get("last_checkpoint", "")

        # Stale detection: "created" status for > 30 min
        stale_warning = ""
        if status == "created" and started:
            try:
                started_dt = datetime.fromisoformat(started.replace("Z", "+00:00"))
                age_min = (now - started_dt).total_seconds() / 60
                if age_min > 30:
                    stale_warning = f"  ⚠️  STALE ({int(age_min)} min in 'created' status)"
            except (ValueError, TypeError):
                pass

        print(f"[{status}] {fid}: {desc}")
        if wt:
            print(f"  worktree: {wt}")
        if checkpoint:
            print(f"  checkpoint: {checkpoint}")
        if stale_warning:
            print(stale_warning)

    print(f"\n{len(items)} entry(ies)")
    return 0


def cmd_migrate_wip(agents_file: Path, wip_path: str) -> int:
    """Migrate a WIP.md file into AGENTS.json."""
    wip_file = Path(wip_path)
    if not wip_file.exists():
        print(f"WIP file not found: {wip_path}", file=sys.stderr)
        return 1

    content = wip_file.read_text()

    # Parse WIP.md fields
    feature_id = ""
    description = ""
    agent = ""
    started = ""
    checkpoint = ""
    files: list[str] = []

    for line in content.splitlines():
        if line.startswith("- **Feature**:"):
            rest = line.split(":", 1)[1].strip() if ":" in line else ""
            # Try to extract F-XXXX
            m = re.search(r'F-\d{4}', rest)
            if m:
                feature_id = m.group(0)
            # Description is after the feature ID
            desc_part = re.sub(r'^\*\*Feature\*\*:\s*', '', line.lstrip('- '))
            desc_part = re.sub(r'F-\d{4}:\s*', '', desc_part)
            if desc_part:
                description = desc_part
        elif line.startswith("- **Agent**:"):
            agent = line.split(":", 1)[1].strip() if ":" in line else ""
        elif line.startswith("- **Started**:"):
            started = line.split(":", 1)[1].strip() if ":" in line else ""
        elif line.startswith("- **Last checkpoint**:"):
            checkpoint = line.split("**:", 1)[1].strip() if "**:" in line else ""

    if not feature_id:
        feature_id = "task"

    items = _load(agents_file)
    entry = {
        "feature_id": feature_id,
        "description": description or feature_id,
        "worktree": str(wip_file.parent.parent.parent),  # .agentic/session/WIP.md → project root
        "branch": "",
        "agent": agent,
        "started": started or _now_iso(),
        "last_checkpoint": checkpoint or _now_iso(),
        "status": "active",
        "progress": ["Migrated from WIP.md"],
        "files": files,
    }
    items.append(entry)
    _save(agents_file, items)
    print(f"Migrated WIP.md → AGENTS.json: {feature_id}")
    return 0


# ---------------------------------------------------------------------------
# CLI dispatch
# ---------------------------------------------------------------------------
def main() -> int:
    args = sys.argv[1:]

    # Extract --project-root
    project_root_str = "."
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
        print("Usage: agents_helpers.py [--project-root PATH] <command> [args...]", file=sys.stderr)
        return 1

    cmd = clean_args[0]
    rest = clean_args[1:]

    valid_cmds = {
        "register", "activate", "checkpoint", "complete", "unregister",
        "check-worktree", "get-active", "get-current-feature", "list",
        "migrate-wip",
    }
    if cmd not in valid_cmds:
        print(f"Unknown command: {cmd}", file=sys.stderr)
        return 1

    project_root = Path(project_root_str).resolve()
    paths = get_paths(project_root)
    agents_file = paths.agents_json

    if cmd == "register":
        if len(rest) < 3:
            print("Error: register <feature_id> <worktree> <branch> [description]", file=sys.stderr)
            return 1
        return cmd_register(agents_file, rest[0], rest[1], rest[2],
                           rest[3] if len(rest) > 3 else "")
    elif cmd == "activate":
        if not rest:
            print("Error: feature_id required", file=sys.stderr)
            return 1
        desc = rest[1] if len(rest) > 1 else ""
        files = rest[2] if len(rest) > 2 else ""
        agent = rest[3] if len(rest) > 3 else ""
        return cmd_activate(agents_file, rest[0], desc, files, agent)
    elif cmd == "checkpoint":
        if len(rest) < 2:
            print("Error: feature_id and note required", file=sys.stderr)
            return 1
        return cmd_checkpoint(agents_file, rest[0], rest[1])
    elif cmd == "complete":
        if not rest:
            print("Error: feature_id required", file=sys.stderr)
            return 1
        return cmd_complete(agents_file, rest[0])
    elif cmd == "unregister":
        if not rest:
            print("Error: feature_id required", file=sys.stderr)
            return 1
        return cmd_unregister(agents_file, rest[0])
    elif cmd == "check-worktree":
        if not rest:
            print("Error: worktree_path required", file=sys.stderr)
            return 1
        return cmd_check_worktree(agents_file, rest[0])
    elif cmd == "get-active":
        fid = rest[0] if rest else None
        return cmd_get_active(agents_file, fid)
    elif cmd == "get-current-feature":
        return cmd_get_current_feature(agents_file)
    elif cmd == "list":
        return cmd_list(agents_file)
    elif cmd == "migrate-wip":
        if not rest:
            print("Error: WIP.md path required", file=sys.stderr)
            return 1
        return cmd_migrate_wip(agents_file, rest[0])
    return 1


if __name__ == "__main__":
    sys.exit(main())
