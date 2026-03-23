"""
agents_helpers.py -- JSON manipulation for AGENTS.json (agent/WIP registry).

Replaces both WIP.md and AGENTS_ACTIVE.md with a single machine-parseable registry.
Called by wip.sh and ag.sh. Handles register/activate/checkpoint/complete/list.

Session tracking (F-0195): session-register/session-deregister/count-others/
cleanup-stale/session-heartbeat for multi-session collision prevention.

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

Session entries additionally have:
  "type": "session",
  "pid": 12345
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
from ids import FEATURE_ID_RE  # noqa: E402


def _now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


# ---------------------------------------------------------------------------
# File locking (best-effort: fcntl on Unix, msvcrt on Windows, no-op elsewhere)
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
            # Lock the whole file (up to 1MB — well beyond any AGENTS.json)
            f.seek(0)
            msvcrt.locking(f.fileno(), msvcrt.LK_LOCK, 1024 * 1024)

        def _unlock(f):
            f.seek(0)
            msvcrt.locking(f.fileno(), msvcrt.LK_UNLCK, 1024 * 1024)
    except ImportError:
        def _lock(f):
            pass

        def _unlock(f):
            pass


# ---------------------------------------------------------------------------
# Atomic read-modify-write via _with_lock
# ---------------------------------------------------------------------------
def _load_unlocked(agents_file: Path) -> list[dict]:
    """Read-only load (no locking). Use _with_lock for mutations."""
    if not agents_file.exists():
        return []
    try:
        with open(agents_file, "r") as f:
            data = json.load(f)
        if not isinstance(data, list):
            return []
        return data
    except (json.JSONDecodeError, OSError):
        return []


def _with_lock(agents_file: Path, fn):
    """Atomic read-modify-write. fn receives items list, returns modified list.

    Opens file with r+ (or creates it), acquires exclusive lock, reads,
    calls fn(items), writes result, truncates, and releases lock.
    """
    agents_file.parent.mkdir(parents=True, exist_ok=True)

    # Create file if it doesn't exist
    if not agents_file.exists():
        agents_file.write_text("[]\n")

    with open(agents_file, "r+") as f:
        _lock(f)
        try:
            f.seek(0)
            try:
                data = json.load(f)
                if not isinstance(data, list):
                    data = []
            except (json.JSONDecodeError, ValueError):
                data = []

            result = fn(data)

            f.seek(0)
            json.dump(result, f, indent=2)
            f.write("\n")
            f.truncate()
        finally:
            _unlock(f)

    return result


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
    now = _now_iso()

    def _do(items):
        idx = _find_by_feature(items, feature_id)
        if idx >= 0:
            items[idx]["worktree"] = worktree
            items[idx]["branch"] = branch
            if description:
                items[idx]["description"] = description
        else:
            items.append({
                "feature_id": feature_id,
                "description": description or feature_id,
                "worktree": worktree,
                "branch": branch,
                "agent": "",
                "started": now,
                "last_checkpoint": now,
                "status": "created",
                "progress": [],
                "files": [],
            })
        return items

    _with_lock(agents_file, _do)
    print(f"Registered: {feature_id}")
    return 0


def cmd_activate(agents_file: Path, feature_id: str, description: str = "",
                 files: str = "", agent: str = "") -> int:
    """Activate an entry (status: active). Creates if not exists."""
    now = _now_iso()
    file_list = [f.strip() for f in files.split(",") if f.strip()] if files else []
    project_root = os.environ.get("PROJECT_ROOT", os.getcwd())

    def _do(items):
        idx = _find_by_feature(items, feature_id)
        if idx >= 0:
            items[idx]["status"] = "active"
            if description:
                items[idx]["description"] = description
            if file_list:
                items[idx]["files"] = file_list
            if agent:
                items[idx]["agent"] = agent
            items[idx]["last_checkpoint"] = now
        else:
            items.append({
                "feature_id": feature_id,
                "description": description or feature_id,
                "worktree": project_root,
                "branch": "",
                "agent": agent,
                "started": now,
                "last_checkpoint": now,
                "status": "active",
                "progress": [],
                "files": file_list,
            })
        return items

    _with_lock(agents_file, _do)
    print(f"Activated: {feature_id}")
    return 0


def cmd_checkpoint(agents_file: Path, feature_id: str, note: str) -> int:
    """Update checkpoint timestamp and append progress note."""
    now = _now_iso()
    found = [False]

    def _do(items):
        idx = _find_by_feature(items, feature_id)
        if idx < 0:
            found[0] = False
            return items
        found[0] = True
        items[idx]["last_checkpoint"] = now
        items[idx].setdefault("progress", []).append(note)
        return items

    _with_lock(agents_file, _do)
    if not found[0]:
        print(f"Error: {feature_id} not found", file=sys.stderr)
        return 1
    print(f"Checkpoint: {feature_id} — {note}")
    return 0


def cmd_complete(agents_file: Path, feature_id: str) -> int:
    """Remove entry (feature complete)."""
    removed = [False]

    def _do(items):
        idx = _find_by_feature(items, feature_id)
        if idx < 0:
            removed[0] = False
            return items
        removed[0] = True
        items.pop(idx)
        return items

    _with_lock(agents_file, _do)
    if removed[0]:
        print(f"Completed: {feature_id}")
    else:
        print(f"No entry for {feature_id} (already complete)")
    return 0


def cmd_unregister(agents_file: Path, feature_id: str) -> int:
    """Alias for complete."""
    return cmd_complete(agents_file, feature_id)


def _cleanup_stale_claims(items: list[dict]) -> list[dict]:
    """Clean up stale feature claims where the claiming PID is dead.

    Unlike _cleanup_stale() which only targets session entries, this targets
    feature entries with a 'claim_pid' field whose process is no longer alive.
    Dead entries are removed entirely.
    """
    return [
        item for item in items
        if not (
            item.get("type") != "session"
            and item.get("status") == "active"
            and item.get("claim_pid")
            and not _is_pid_alive(item["claim_pid"])
        )
    ]


def cmd_claim(agents_file: Path, feature_id: str, agent: str = "",
              description: str = "", pid: int = 0) -> int:
    """Atomic claim: reject if feature already has an active entry.

    Uses fcntl.flock for inter-process safety. Stores claiming PID
    for stale-claim detection. Returns 0 on success, 1 if already claimed.
    """
    claim_pid = pid if pid > 0 else os.getpid()
    now = _now_iso()
    claimed = [False]
    conflict_agent = [""]

    def _do(items):
        items = _cleanup_stale_claims(items)
        for e in items:
            if (e.get("feature_id") == feature_id
                    and e.get("status") == "active"):
                conflict_agent[0] = e.get("agent", "unknown")
                claimed[0] = False
                return items
        # Unclaimed — activate with PID stored
        items.append({
            "feature_id": feature_id,
            "description": description or feature_id,
            "worktree": "",
            "branch": "",
            "agent": agent,
            "started": now,
            "last_checkpoint": now,
            "status": "active",
            "claim_pid": claim_pid,
            "progress": [],
            "files": [],
        })
        claimed[0] = True
        return items

    _with_lock(agents_file, _do)
    if claimed[0]:
        print(f"Claimed: {feature_id} (agent={agent or 'unset'}, pid={claim_pid})")
        return 0
    else:
        print(f"Already claimed by {conflict_agent[0]}", file=sys.stderr)
        return 1


def cmd_release(agents_file: Path, feature_id: str, pid: int = 0) -> int:
    """Release a feature claim. Removes the entry entirely.

    If the releasing PID differs from the claiming PID, logs a warning
    but allows the release (needed for manual cleanup).
    Returns 0 on success, 1 if not found.
    """
    release_pid = pid if pid > 0 else os.getpid()
    released = [False]

    def _do(items):
        for i, e in enumerate(items):
            if (e.get("feature_id") == feature_id
                    and e.get("status") == "active"):
                claim_pid = e.get("claim_pid", 0)
                if claim_pid and claim_pid != release_pid:
                    print(f"Warning: releasing PID {release_pid} != claiming PID {claim_pid}",
                          file=sys.stderr)
                items.pop(i)
                released[0] = True
                return items
        released[0] = False
        return items

    _with_lock(agents_file, _do)
    if released[0]:
        print(f"Released: {feature_id}")
        return 0
    else:
        print(f"No active claim for {feature_id}", file=sys.stderr)
        return 1


def cmd_check_tdd_phases(agents_file: Path) -> int:
    """Validate TDD phase ordering in progress entries.

    Reads active (non-session) entries from AGENTS.json and checks that
    every GREEN: entry is preceded by at least one RED: entry at an earlier
    index. REFACTOR: entries have no ordering constraint.

    Exit codes:
        0 — valid (phases present and correctly ordered)
        1 — error (no active entries found)
        2 — ordering violation (GREEN before RED)
        3 — zero phase entries (agent ignored --phase)
    """
    items = _load_unlocked(agents_file)
    feature_items = [i for i in items
                     if i.get("type") != "session"
                     and i.get("status") in ("active", "created")]
    if not feature_items:
        return 1

    for item in feature_items:
        progress = item.get("progress", [])
        red_count = 0
        green_count = 0
        refactor_count = 0
        for entry in progress:
            if not isinstance(entry, str):
                continue
            if entry.startswith("RED:"):
                red_count += 1
            elif entry.startswith("GREEN:"):
                if red_count == 0:
                    fid = item.get("feature_id", "?")
                    print(f"GREEN before RED in {fid}: \"{entry}\"")
                    return 2
                green_count += 1
            elif entry.startswith("REFACTOR:"):
                refactor_count += 1

        phase_count = red_count + green_count + refactor_count
        if phase_count == 0:
            fid = item.get("feature_id", "?")
            print(f"No TDD phase checkpoints in {fid}")
            return 3

    return 0


def cmd_check_worktree(agents_file: Path, worktree_path: str) -> int:
    """Check if a worktree has an active entry. Exit 0 = has entry, 1 = no entry."""
    items = _load_unlocked(agents_file)
    idx = _find_by_worktree(items, worktree_path)
    if idx >= 0:
        entry = items[idx]
        print(f"{entry['feature_id']}: {entry.get('description', '')} (status: {entry.get('status', 'unknown')})")
        return 0
    return 1


def cmd_get_active(agents_file: Path, feature_id: Optional[str] = None) -> int:
    """Get active entry. If feature_id given, get that specific entry."""
    items = _load_unlocked(agents_file)
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


def cmd_get_current_feature(agents_file: Path,
                            worktree_path: Optional[str] = None) -> int:
    """Print the feature_id of the current worktree's active entry.

    If worktree_path is given, returns the feature for that worktree.
    Otherwise returns the first active/created entry (single-agent compat).
    """
    items = _load_unlocked(agents_file)

    # Per-worktree lookup (preferred — avoids H-4 wrong-feature completion)
    if worktree_path:
        idx = _find_by_worktree(items, worktree_path)
        if idx >= 0 and items[idx].get("status") in ("active", "created"):
            print(items[idx]["feature_id"])
            return 0
        return 1

    # Fallback: first active/created entry (single-agent case)
    for item in items:
        if item.get("status") in ("active", "created"):
            print(item["feature_id"])
            return 0
    return 1


def cmd_list(agents_file: Path) -> int:
    """Print all entries in human-readable format.

    Automatically purges completed entries (legacy artifacts from
    release/stale-claim that used to mark-not-remove).
    """
    def _purge_completed(items):
        return [i for i in items if i.get("status") != "completed"]

    items = _with_lock(agents_file, _purge_completed)

    # Filter out session entries for display
    feature_items = [i for i in items if i.get("type") != "session"]
    if not feature_items:
        print("No active agents")
        return 0

    now = datetime.now(timezone.utc)
    for item in feature_items:
        fid = item.get("feature_id", "?")
        desc = item.get("description", "")
        status = item.get("status", "?")
        wt = item.get("worktree", "")
        checkpoint = item.get("last_checkpoint", "")
        ts = item.get("started", "")

        # Stale detection
        stale_warning = ""
        ref_ts = checkpoint or ts
        if ref_ts:
            try:
                ref_dt = datetime.fromisoformat(ref_ts.replace("Z", "+00:00"))
                age_min = (now - ref_dt).total_seconds() / 60
                if status == "created" and age_min > 30:
                    stale_warning = f"  ⚠️  STALE ({int(age_min)} min in 'created' — agent may have crashed)"
                elif status == "active" and age_min > 60:
                    stale_warning = f"  ⚠️  STALE ({int(age_min)} min since last checkpoint — agent may have crashed)"
            except (ValueError, TypeError):
                pass

        print(f"[{status}] {fid}: {desc}")
        if wt:
            print(f"  worktree: {wt}")
        if checkpoint:
            print(f"  checkpoint: {checkpoint}")
        if stale_warning:
            print(stale_warning)

    print(f"\n{len(feature_items)} entry(ies)")
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
            m = FEATURE_ID_RE.search(rest)
            if m:
                feature_id = m.group(0)
            # Description is after the feature ID
            desc_part = re.sub(r'^\*\*Feature\*\*:\s*', '', line.lstrip('- '))
            desc_part = FEATURE_ID_RE.sub('', desc_part).lstrip(': ')
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

    wip_worktree = str(wip_file.parent.parent.parent)  # .agentic/session/WIP.md → project root
    now = _now_iso()

    def _do(items):
        # Skip if already migrated (M-3: dedup)
        if _find_by_feature(items, feature_id) >= 0:
            return items
        items.append({
            "feature_id": feature_id,
            "description": description or feature_id,
            "worktree": wip_worktree,
            "branch": "",
            "agent": agent,
            "started": started or now,
            "last_checkpoint": checkpoint or now,
            "status": "active",
            "progress": ["Migrated from WIP.md"],
            "files": files,
        })
        return items

    _with_lock(agents_file, _do)
    print(f"Migrated WIP.md → AGENTS.json: {feature_id}")
    return 0


# ---------------------------------------------------------------------------
# Session tracking (F-0195: Multi-session collision prevention)
# ---------------------------------------------------------------------------
_STALE_HEARTBEAT_MINUTES = 30


def _is_pid_alive(pid: int) -> bool:
    """Check if a process is alive (POSIX: os.kill with signal 0)."""
    try:
        os.kill(pid, 0)
        return True
    except (ProcessLookupError, OSError):
        return False


def _find_session_by_pid(items: list[dict], worktree: str, pid: int) -> int:
    """Find session entry matching worktree + PID."""
    norm = os.path.normpath(worktree)
    for i, item in enumerate(items):
        if (item.get("type") == "session"
                and item.get("pid") == pid
                and os.path.normpath(item.get("worktree", "")) == norm):
            return i
    return -1


def cmd_session_register(agents_file: Path, worktree: str,
                         agent: str = "claude-code", pid: int = 0) -> int:
    """Register a session entry with PID for collision detection."""
    now = _now_iso()
    if pid <= 0:
        pid = os.getpid()

    def _do(items):
        # Deduplicate: if same worktree+pid already registered, update
        idx = _find_session_by_pid(items, worktree, pid)
        if idx >= 0:
            items[idx]["last_checkpoint"] = now
            items[idx]["status"] = "active"
            return items
        items.append({
            "feature_id": f"session-{pid}",
            "description": "Claude Code session",
            "worktree": os.path.normpath(worktree),
            "branch": "",
            "agent": agent,
            "started": now,
            "last_checkpoint": now,
            "status": "active",
            "type": "session",
            "pid": pid,
            "progress": [],
            "files": [],
        })
        return items

    _with_lock(agents_file, _do)
    return 0


def cmd_session_deregister(agents_file: Path, worktree: str,
                           pid: int = 0) -> int:
    """Remove a session entry by worktree + PID."""
    if pid <= 0:
        pid = os.getpid()

    def _do(items):
        idx = _find_session_by_pid(items, worktree, pid)
        if idx >= 0:
            items.pop(idx)
        return items

    _with_lock(agents_file, _do)
    return 0


def cmd_count_others(agents_file: Path, worktree: str,
                     pid: int = 0) -> int:
    """Count other active entries on the same worktree (excludes self by PID).

    Counts ALL entry types (sessions and feature entries) since any concurrent
    work on the same checkout is a collision risk. Prints count and exits 0.
    """
    if pid <= 0:
        pid = os.getpid()
    items = _load_unlocked(agents_file)
    norm = os.path.normpath(worktree)
    count = 0
    for item in items:
        if item.get("status") not in ("active", "created"):
            continue
        if os.path.normpath(item.get("worktree", "")) != norm:
            continue
        # Exclude self: match by PID for session entries
        if item.get("type") == "session" and item.get("pid") == pid:
            continue
        count += 1
    print(count)
    return 0


def cmd_cleanup_stale(agents_file: Path) -> int:
    """Remove stale entries: dead sessions AND completed feature entries.

    A session entry is stale if:
    - PID is dead (os.kill(pid, 0) fails), OR
    - last_checkpoint is older than _STALE_HEARTBEAT_MINUTES (PID recycling guard)

    Feature entries with status "completed" are always removed (legacy
    artifacts from release/stale-claim that used to mark-not-remove).
    """
    now = datetime.now(timezone.utc)
    removed = []

    def _do(items):
        keep = []
        for item in items:
            # Purge completed feature entries (no useful data left)
            if item.get("status") == "completed":
                removed.append(item.get("feature_id", "?"))
                continue
            if item.get("type") != "session":
                keep.append(item)
                continue
            pid = item.get("pid", 0)
            # Check 1: PID alive?
            pid_alive = _is_pid_alive(pid) if pid > 0 else False
            # Check 2: Heartbeat recent?
            heartbeat_ok = True
            checkpoint = item.get("last_checkpoint", "")
            if checkpoint:
                try:
                    ref_dt = datetime.fromisoformat(
                        checkpoint.replace("Z", "+00:00"))
                    age_min = (now - ref_dt).total_seconds() / 60
                    if age_min > _STALE_HEARTBEAT_MINUTES:
                        heartbeat_ok = False
                except (ValueError, TypeError):
                    pass
            # Stale if PID dead OR heartbeat expired
            if not pid_alive or not heartbeat_ok:
                removed.append(item.get("feature_id", "?"))
            else:
                keep.append(item)
        return keep

    _with_lock(agents_file, _do)
    if removed:
        print(f"Cleaned {len(removed)} stale entry(ies): {', '.join(removed)}")
    return 0


def cmd_session_heartbeat(agents_file: Path, worktree: str = "",
                          pid: int = 0) -> int:
    """Update last_checkpoint for a session entry (heartbeat for crash recovery)."""
    if pid <= 0:
        pid = os.getpid()
    now = _now_iso()

    def _do(items):
        if worktree:
            idx = _find_session_by_pid(items, worktree, pid)
            if idx >= 0:
                items[idx]["last_checkpoint"] = now
        else:
            # Fallback: match by PID only (backwards compat)
            for item in items:
                if item.get("type") == "session" and item.get("pid") == pid:
                    item["last_checkpoint"] = now
                    break
        return items

    _with_lock(agents_file, _do)
    return 0


def cmd_prompt_check(agents_file: Path, worktree: str,
                     pid: int = 0) -> int:
    """Combined count-others + heartbeat in one invocation (UserPromptSubmit hot path).

    Prints the count of other active entries on the same worktree, then updates
    the session heartbeat — all in a single Python startup and file lock cycle.
    """
    if pid <= 0:
        pid = os.getpid()
    now = _now_iso()
    norm = os.path.normpath(worktree)
    count_result = [0]

    def _do(items):
        # Count others (same logic as cmd_count_others)
        count = 0
        for item in items:
            if item.get("status") not in ("active", "created"):
                continue
            if os.path.normpath(item.get("worktree", "")) != norm:
                continue
            if item.get("type") == "session" and item.get("pid") == pid:
                continue
            count += 1
        count_result[0] = count

        # Heartbeat (same logic as cmd_session_heartbeat)
        idx = _find_session_by_pid(items, worktree, pid)
        if idx >= 0:
            items[idx]["last_checkpoint"] = now
        return items

    _with_lock(agents_file, _do)
    print(count_result[0])
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

    # Extract --pid (for session commands)
    pid_val = 0
    clean_args2: list[str] = []
    j = 0
    while j < len(clean_args):
        if clean_args[j] == "--pid" and j + 1 < len(clean_args):
            try:
                pid_val = int(clean_args[j + 1])
            except ValueError:
                pass
            j += 2
        else:
            clean_args2.append(clean_args[j])
            j += 1
    clean_args = clean_args2
    cmd = clean_args[0]
    rest = clean_args[1:]

    valid_cmds = {
        "register", "activate", "checkpoint", "complete", "unregister",
        "check-worktree", "check-tdd-phases", "get-active",
        "get-current-feature", "list",
        "migrate-wip", "claim", "release",
        "session-register", "session-deregister", "count-others",
        "cleanup-stale", "session-heartbeat", "prompt-check",
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
    elif cmd == "check-tdd-phases":
        return cmd_check_tdd_phases(agents_file)
    elif cmd == "get-active":
        fid = rest[0] if rest else None
        return cmd_get_active(agents_file, fid)
    elif cmd == "get-current-feature":
        wt = rest[0] if rest else None
        return cmd_get_current_feature(agents_file, wt)
    elif cmd == "list":
        return cmd_list(agents_file)
    elif cmd == "migrate-wip":
        if not rest:
            print("Error: WIP.md path required", file=sys.stderr)
            return 1
        return cmd_migrate_wip(agents_file, rest[0])
    elif cmd == "claim":
        if not rest:
            print("Error: feature_id required", file=sys.stderr)
            return 1
        agent = rest[1] if len(rest) > 1 else ""
        desc = rest[2] if len(rest) > 2 else ""
        return cmd_claim(agents_file, rest[0], agent, desc, pid_val)
    elif cmd == "release":
        if not rest:
            print("Error: feature_id required", file=sys.stderr)
            return 1
        return cmd_release(agents_file, rest[0], pid_val)
    elif cmd == "session-register":
        if not rest:
            print("Error: worktree path required", file=sys.stderr)
            return 1
        agent = rest[1] if len(rest) > 1 else "claude-code"
        return cmd_session_register(agents_file, rest[0], agent, pid_val)
    elif cmd == "session-deregister":
        if not rest:
            print("Error: worktree path required", file=sys.stderr)
            return 1
        return cmd_session_deregister(agents_file, rest[0], pid_val)
    elif cmd == "count-others":
        if not rest:
            print("Error: worktree path required", file=sys.stderr)
            return 1
        return cmd_count_others(agents_file, rest[0], pid_val)
    elif cmd == "cleanup-stale":
        return cmd_cleanup_stale(agents_file)
    elif cmd == "session-heartbeat":
        wt = rest[0] if rest else ""
        return cmd_session_heartbeat(agents_file, wt, pid_val)
    elif cmd == "prompt-check":
        if not rest:
            print("Error: worktree path required", file=sys.stderr)
            return 1
        return cmd_prompt_check(agents_file, rest[0], pid_val)
    return 1


if __name__ == "__main__":
    sys.exit(main())
