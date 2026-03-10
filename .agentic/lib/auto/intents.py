"""
intents.py -- Write-ahead intent journal for multi-step ag.sh operations.

Provides crash recovery via reconciliation: before any multi-step operation
(e.g., ag implement, ag done), an intent is written to intents.json. Each
step is checkpointed on completion. If the process dies mid-sequence, the
reconciler (ag sync) can resume from the last checkpoint.

Storage: .agentic/session/intents.json (gitignored, session-scoped)
Locking: All reads/writes use fcntl exclusive lock (via _with_lock pattern)
Identity: UUID session_id for ownership, PID for liveness detection only

Intent schema:
{
  "feature_id": "F-0042",
  "previous_state": "planned",
  "target_state": "implementing",
  "command": "implement",
  "session_id": "uuid-...",
  "agent_pid": 12345,
  "worktree": "/abs/path/repo-f-0042",
  "created_at": "2026-03-10T12:00:00Z",
  "steps_completed": ["wip_registered"],
  "steps_remaining": ["create_worktree", "transition_state"],
  "attempt_count": 1,
  "status": "active",
  "error": null
}
"""
from __future__ import annotations

import json
import os
import sys
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

# ---------------------------------------------------------------------------
# Resolve paths.py from the lib/ directory (our parent)
# ---------------------------------------------------------------------------
_LIB_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(_LIB_DIR))
from paths import get_paths  # noqa: E402


# ---------------------------------------------------------------------------
# File locking (reuse same pattern as agents_helpers.py)
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
# Constants
# ---------------------------------------------------------------------------
_ORPHAN_AGE_MINUTES = 5


def _now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _intents_file(root: Path) -> Path:
    """Return the path to intents.json, using main project root."""
    paths = get_paths(root)
    return paths.main_project_root / ".agentic" / "session" / "intents.json"


def _session_id_file(root: Path) -> Path:
    """Return the path to .current-session-id."""
    paths = get_paths(root)
    return paths.main_project_root / ".agentic" / "session" / ".current-session-id"


# ---------------------------------------------------------------------------
# Atomic read-modify-write via _with_lock (same pattern as agents_helpers.py)
# ---------------------------------------------------------------------------
def _load_unlocked(intents_file: Path) -> list[dict]:
    """Read-only load (no locking). Use _with_lock for mutations."""
    if not intents_file.exists():
        return []
    try:
        with open(intents_file, "r") as f:
            data = json.load(f)
        if not isinstance(data, list):
            return []
        return data
    except (json.JSONDecodeError, OSError):
        return []


def _with_lock(intents_file: Path, fn):
    """Atomic read-modify-write with exclusive file lock.

    Opens file with r+ (or creates it), acquires exclusive lock, reads,
    calls fn(items), writes result, truncates, and releases lock.
    """
    intents_file.parent.mkdir(parents=True, exist_ok=True)

    # Create file if it doesn't exist
    if not intents_file.exists():
        intents_file.write_text("[]\n")

    with open(intents_file, "r+") as f:
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
    """Find index of intent for a given feature_id. Returns -1 if not found."""
    for i, item in enumerate(items):
        if item.get("feature_id") == feature_id:
            return i
    return -1


def _is_pid_alive(pid: int) -> bool:
    """Check if a process is alive (POSIX: os.kill with signal 0)."""
    if pid <= 0:
        return False
    try:
        os.kill(pid, 0)
        return True
    except (ProcessLookupError, OSError):
        return False


# ---------------------------------------------------------------------------
# Session ID management
# ---------------------------------------------------------------------------
def get_or_create_session_id(root: Path) -> str:
    """Get the current session ID or create a new one.

    Session ID is stored in .agentic/session/.current-session-id.
    A new UUID is generated if the file doesn't exist.
    """
    sid_file = _session_id_file(root)
    sid_file.parent.mkdir(parents=True, exist_ok=True)

    if sid_file.exists():
        try:
            existing = sid_file.read_text().strip()
            if existing:
                return existing
        except OSError:
            pass

    new_id = str(uuid.uuid4())
    try:
        sid_file.write_text(new_id + "\n")
    except OSError:
        pass
    return new_id


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------
def write_intent(
    root: Path,
    feature_id: str,
    target_state: str,
    command: str,
    steps: list[str],
    session_id: str,
    pid: int,
    worktree: str = "",
    previous_state: str = "",
) -> dict:
    """Write a new intent before starting a multi-step operation.

    Args:
        root: Project root directory.
        feature_id: Feature being operated on (e.g., "F-0042").
        target_state: Desired end state (e.g., "implementing").
        command: The ag command (e.g., "implement", "done").
        steps: Ordered list of step names to execute.
        session_id: UUID identifying this agent session.
        pid: Agent process ID (for liveness detection).
        worktree: Absolute path to worktree (if applicable).
        previous_state: Current state before operation (for rollback).

    Returns:
        The intent entry that was written.
    """
    ifile = _intents_file(root)
    now = _now_iso()
    entry = {
        "feature_id": feature_id,
        "previous_state": previous_state,
        "target_state": target_state,
        "command": command,
        "session_id": session_id,
        "agent_pid": pid,
        "worktree": worktree,
        "created_at": now,
        "steps_completed": [],
        "steps_remaining": list(steps),
        "attempt_count": 1,
        "status": "active",
        "error": None,
    }

    def _do(items):
        idx = _find_by_feature(items, feature_id)
        if idx >= 0:
            # Overwrite existing intent for same feature
            items[idx] = entry
        else:
            items.append(entry)
        return items

    _with_lock(ifile, _do)
    return entry


def checkpoint_step(root: Path, feature_id: str, step_name: str) -> bool:
    """Mark a step as completed for a feature's intent.

    Moves step_name from steps_remaining to steps_completed.

    Returns:
        True if the checkpoint was recorded, False if intent not found.
    """
    ifile = _intents_file(root)
    found = [False]

    def _do(items):
        idx = _find_by_feature(items, feature_id)
        if idx < 0:
            found[0] = False
            return items
        found[0] = True
        intent = items[idx]
        if step_name in intent.get("steps_remaining", []):
            intent["steps_remaining"].remove(step_name)
        if step_name not in intent.get("steps_completed", []):
            intent.setdefault("steps_completed", []).append(step_name)
        return items

    _with_lock(ifile, _do)
    return found[0]


def get_pending(root: Path, session_id: Optional[str] = None) -> list[dict]:
    """List incomplete intents, optionally filtered by session_id.

    An intent is pending if it has status 'active' and steps_remaining is non-empty.

    Args:
        root: Project root directory.
        session_id: If provided, only return intents for this session.

    Returns:
        List of pending intent entries.
    """
    ifile = _intents_file(root)
    items = _load_unlocked(ifile)
    result = []
    for item in items:
        if item.get("status") != "active":
            continue
        if not item.get("steps_remaining"):
            continue
        if session_id is not None and item.get("session_id") != session_id:
            continue
        result.append(item)
    return result


def get_orphaned(root: Path) -> list[dict]:
    """Find intents where the agent PID is dead AND the intent is older than threshold.

    An intent is orphaned if:
    1. agent_pid is dead (process no longer exists)
    2. created_at is older than _ORPHAN_AGE_MINUTES minutes
    3. status is 'active'

    Returns:
        List of orphaned intent entries.
    """
    ifile = _intents_file(root)
    items = _load_unlocked(ifile)
    now = datetime.now(timezone.utc)
    result = []
    for item in items:
        if item.get("status") != "active":
            continue
        pid = item.get("agent_pid", 0)
        if _is_pid_alive(pid):
            continue
        # Check age
        created_at = item.get("created_at", "")
        if created_at:
            try:
                created_dt = datetime.fromisoformat(
                    created_at.replace("Z", "+00:00")
                )
                age_min = (now - created_dt).total_seconds() / 60
                if age_min < _ORPHAN_AGE_MINUTES:
                    continue
            except (ValueError, TypeError):
                pass
        result.append(item)
    return result


def clear_intent(root: Path, feature_id: str) -> bool:
    """Remove a completed intent.

    Args:
        root: Project root directory.
        feature_id: Feature whose intent to clear.

    Returns:
        True if an intent was removed, False if not found.
    """
    ifile = _intents_file(root)
    removed = [False]

    def _do(items):
        idx = _find_by_feature(items, feature_id)
        if idx < 0:
            removed[0] = False
            return items
        removed[0] = True
        items.pop(idx)
        return items

    _with_lock(ifile, _do)
    return removed[0]


def cancel_intent(root: Path, feature_id: str) -> bool:
    """Mark an intent as cancelled (abort, note rollback needed).

    Sets status to 'cancelled' rather than removing, so the reconciler
    knows rollback may be needed.

    Args:
        root: Project root directory.
        feature_id: Feature whose intent to cancel.

    Returns:
        True if an intent was cancelled, False if not found.
    """
    ifile = _intents_file(root)
    found = [False]

    def _do(items):
        idx = _find_by_feature(items, feature_id)
        if idx < 0:
            found[0] = False
            return items
        found[0] = True
        items[idx]["status"] = "cancelled"
        items[idx]["error"] = "Cancelled by user or reconciler"
        return items

    _with_lock(ifile, _do)
    return found[0]


def adopt_orphans(root: Path, session_id: str, pid: int) -> list[str]:
    """Take over intents from dead sessions.

    Finds all orphaned intents (dead PID + old enough) and updates their
    session_id and agent_pid to the current session's values.

    Args:
        root: Project root directory.
        session_id: Current session's UUID.
        pid: Current agent's PID.

    Returns:
        List of feature_ids that were adopted.
    """
    ifile = _intents_file(root)
    now = datetime.now(timezone.utc)
    adopted = []

    def _do(items):
        for item in items:
            if item.get("status") != "active":
                continue
            item_pid = item.get("agent_pid", 0)
            if _is_pid_alive(item_pid):
                continue
            # Check age
            created_at = item.get("created_at", "")
            if created_at:
                try:
                    created_dt = datetime.fromisoformat(
                        created_at.replace("Z", "+00:00")
                    )
                    age_min = (now - created_dt).total_seconds() / 60
                    if age_min < _ORPHAN_AGE_MINUTES:
                        continue
                except (ValueError, TypeError):
                    pass
            # Adopt: update session_id and PID
            item["session_id"] = session_id
            item["agent_pid"] = pid
            item["attempt_count"] = item.get("attempt_count", 0) + 1
            adopted.append(item.get("feature_id", "?"))
        return items

    _with_lock(ifile, _do)
    return adopted


# ---------------------------------------------------------------------------
# CLI entry point (for calling from bash)
# ---------------------------------------------------------------------------
def main() -> int:
    """CLI for intents.py operations."""
    import argparse

    parser = argparse.ArgumentParser(description="Intent journal operations")
    parser.add_argument(
        "--project-root",
        type=Path,
        default=Path.cwd(),
        help="Project root directory",
    )
    subparsers = parser.add_subparsers(dest="command")

    # write-intent
    wp = subparsers.add_parser("write-intent")
    wp.add_argument("feature_id")
    wp.add_argument("--target-state", required=True)
    wp.add_argument("--command-name", required=True)
    wp.add_argument("--steps", required=True, help="Comma-separated step names")
    wp.add_argument("--session-id", default="")
    wp.add_argument("--pid", type=int, default=0)
    wp.add_argument("--worktree", default="")
    wp.add_argument("--previous-state", default="")

    # checkpoint-step
    cp = subparsers.add_parser("checkpoint-step")
    cp.add_argument("feature_id")
    cp.add_argument("step_name")

    # get-pending
    gp = subparsers.add_parser("get-pending")
    gp.add_argument("--session-id", default=None)

    # get-orphaned
    subparsers.add_parser("get-orphaned")

    # clear-intent
    ci = subparsers.add_parser("clear-intent")
    ci.add_argument("feature_id")

    # cancel-intent
    ca = subparsers.add_parser("cancel-intent")
    ca.add_argument("feature_id")

    # adopt-orphans
    ao = subparsers.add_parser("adopt-orphans")
    ao.add_argument("--session-id", required=True)
    ao.add_argument("--pid", type=int, required=True)

    args = parser.parse_args()
    root = args.project_root

    if args.command == "write-intent":
        sid = args.session_id or get_or_create_session_id(root)
        pid = args.pid or os.getpid()
        steps = [s.strip() for s in args.steps.split(",") if s.strip()]
        entry = write_intent(
            root, args.feature_id, args.target_state,
            args.command_name, steps, sid, pid,
            worktree=args.worktree,
            previous_state=args.previous_state,
        )
        print(json.dumps(entry, indent=2))
        return 0

    elif args.command == "checkpoint-step":
        ok = checkpoint_step(root, args.feature_id, args.step_name)
        if ok:
            print(f"Checkpoint: {args.feature_id} — {args.step_name}")
        else:
            print(f"Intent not found: {args.feature_id}", file=sys.stderr)
            return 1
        return 0

    elif args.command == "get-pending":
        pending = get_pending(root, session_id=args.session_id)
        if pending:
            print(json.dumps(pending, indent=2))
        return 0

    elif args.command == "get-orphaned":
        orphaned = get_orphaned(root)
        if orphaned:
            print(json.dumps(orphaned, indent=2))
        return 0

    elif args.command == "clear-intent":
        ok = clear_intent(root, args.feature_id)
        if ok:
            print(f"Cleared: {args.feature_id}")
        else:
            print(f"Not found: {args.feature_id}")
        return 0

    elif args.command == "cancel-intent":
        ok = cancel_intent(root, args.feature_id)
        if ok:
            print(f"Cancelled: {args.feature_id}")
        else:
            print(f"Not found: {args.feature_id}")
        return 0

    elif args.command == "adopt-orphans":
        adopted = adopt_orphans(root, args.session_id, args.pid)
        if adopted:
            print(f"Adopted: {', '.join(adopted)}")
        else:
            print("No orphans to adopt")
        return 0

    else:
        parser.print_help()
        return 1


if __name__ == "__main__":
    sys.exit(main())
