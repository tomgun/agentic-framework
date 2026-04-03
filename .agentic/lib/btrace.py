"""btrace.py — Behavioral trace emitter (Python side).

Append-only JSONL at .agentic/debug/btrace-<session-id>.jsonl.
Zero-cost when disabled. Mirror of btrace.sh for Python-side emission.

Toggle: AGENTIC_BTRACE env var (priority) or STACK.md btrace setting.
Values: off (default) | on (behavioral events) | verbose (+ sub-check detail)
"""

import json
import os
import time
from pathlib import Path

_level: str = ""
_seq: int = 0
_log_path: Path | None = None
_resolved_for: str = ""  # project_root str — re-resolve if project changes


def _resolve(project_root: Path) -> None:
    global _level, _log_path, _resolved_for
    root_key = str(project_root)
    if _resolved_for == root_key:
        return

    # Env var takes precedence
    _level = os.environ.get("AGENTIC_BTRACE", "")

    if not _level:
        # Try settings resolution
        try:
            import settings as settings_mod
            _level = settings_mod.get_setting(project_root, "btrace", "off")
        except Exception:
            _level = "off"

    if _level in ("on", "verbose"):
        debug_dir = project_root / ".agentic" / "debug"
        debug_dir.mkdir(parents=True, exist_ok=True)

        # Read session ID
        sid_file = project_root / ".agentic" / "session" / ".current-session-id"
        sid = "unknown"
        try:
            sid = sid_file.read_text().strip() or "unknown"
        except (OSError, FileNotFoundError):
            pass

        _log_path = debug_dir / f"btrace-{sid}.jsonl"

        # Update latest symlink
        latest = debug_dir / "btrace-latest.jsonl"
        try:
            latest.unlink(missing_ok=True)
            latest.symlink_to(f"btrace-{sid}.jsonl")
        except OSError:
            pass

    _resolved_for = root_key


def enabled(project_root: Path) -> bool:
    _resolve(project_root)
    return _level in ("on", "verbose")


def verbose(project_root: Path) -> bool:
    _resolve(project_root)
    return _level == "verbose"


def emit(project_root: Path, hook: str, phase: str, data: dict) -> None:
    """Append a trace event. No-op when disabled."""
    if not enabled(project_root):
        return

    global _seq
    _seq += 1

    # Sub-second timestamps for cross-process ordering
    now = time.time()
    ts = time.strftime("%Y-%m-%dT%H:%M:%S", time.gmtime(now))
    ms = int((now % 1) * 1000)
    event = {
        "ts": f"{ts}.{ms:03d}Z",
        "seq": _seq,
        "pid": os.getpid(),
        "hook": hook,
        "phase": phase,
        "data": data,
    }

    if _log_path is None:
        return

    try:
        with open(_log_path, "a") as f:
            f.write(json.dumps(event, separators=(",", ":")) + "\n")
    except OSError:
        pass
