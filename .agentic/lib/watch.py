"""
watch.py — `ag watch` lightweight terminal event tail (R-009).

Color-coded `tail -f` style stream of `events.jsonl` for SSH sessions where the
Textual TUI (R-008) is too heavy or unavailable.

Design notes
------------
* Stdlib only. ANSI color codes are emitted directly when stdout is a TTY; when
  piped to a file or non-TTY, output is plain text. (colorama was listed in the
  AC for Windows shims but every supported terminal handles ANSI natively, and
  keeping the dep surface at zero matches the rest of the framework.)
* Tail strategy: open the file, seek to EOF (the default; tail-from-end), then
  poll for new bytes. Re-stat each iteration so a rotated/recreated file is
  reopened (inode change). When a new file appears mid-tail, picks up from
  position 0.
* `--from-start` reads the whole file before tailing (useful for `ag watch | grep`).
* Filters are AND-ed: `--filter type=commit --filter feature=F-008` matches a
  record only if both fields equal the supplied values.
* `--since` accepts `Nm`, `Nh`, `Nd` shorthand and ISO8601 / `YYYY-MM-DD HH:MM`
  absolute timestamps. The clock is the record's `ts` field, not file mtime.

Honest limits
-------------
* `tail -f` is poll-based (default 250ms). New events appear within one poll
  interval. The R-009 AC specifies "<1s"; the default beats that.
* On macOS / Linux this is purely best-effort: if the journal directory lives on
  NFS or another filesystem with weak `stat`, inode reuse may briefly cause a
  duplicate record on reopen. Acceptable for an observability tail.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Iterable, Optional


# ---------------------------------------------------------------------------
# Color taxonomy — keyed by event type (R-009 AC #2)
# ---------------------------------------------------------------------------

_RESET = "\033[0m"
_BOLD = "\033[1m"
_DIM = "\033[2m"
_RED = "\033[31m"
_GREEN = "\033[32m"
_YELLOW = "\033[33m"
_BLUE = "\033[34m"
_MAGENTA = "\033[35m"
_CYAN = "\033[36m"

# Categorise event types into severity buckets. Unknown types fall back to BLUE.
_RED_TYPES = {
    "gate_blocked",
    "human_needed",
}
_YELLOW_TYPES = {
    "gate_skipped",
    "quota_degraded",
    "hotfix_commit",
}
_GREEN_TYPES = {
    "session_start",
    "session_end",
    "task_complete",
    "commit",
    "test_run",
    "contract_check",
    "contract_migration",
    "integrity_baseline_updated",
    "merge_attempt",
    "push_attempt",
}
_MAGENTA_TYPES = {
    "critic_verdict",
}
_CYAN_TYPES = {
    "intel_invoked",
    "task_dispatch",
    "tool_call",
}


def _color_for(event_type: str) -> str:
    if event_type in _RED_TYPES:
        return _RED
    if event_type in _YELLOW_TYPES:
        return _YELLOW
    if event_type in _GREEN_TYPES:
        return _GREEN
    if event_type in _MAGENTA_TYPES:
        return _MAGENTA
    if event_type in _CYAN_TYPES:
        return _CYAN
    return _BLUE


# ---------------------------------------------------------------------------
# Filters
# ---------------------------------------------------------------------------


def parse_filter(raw: str) -> tuple[str, str]:
    """Parse a `key=value` filter spec. Raises ValueError on bad input."""
    if "=" not in raw:
        raise ValueError(f"--filter expects key=value, got {raw!r}")
    key, value = raw.split("=", 1)
    key = key.strip()
    value = value.strip()
    if not key or not value:
        raise ValueError(f"--filter has empty key or value: {raw!r}")
    return key, value


def matches_filters(record: dict, filters: list[tuple[str, str]]) -> bool:
    """Return True if `record` matches all `(key, value)` filter pairs."""
    for key, value in filters:
        actual = record.get(key)
        if actual is None or str(actual) != value:
            return False
    return True


# ---------------------------------------------------------------------------
# --since time parsing
# ---------------------------------------------------------------------------


def parse_since(raw: str, *, now: Optional[datetime] = None) -> datetime:
    """
    Parse `--since` argument into a UTC datetime threshold.

    Accepts:
      * `30m` / `2h` / `7d`              — relative to now
      * `2026-04-26T14:00:00Z`           — ISO8601 with Z
      * `2026-04-26 14:00`               — common loose form (assumed UTC)
      * `2026-04-26`                     — date-only (start of day, UTC)
    """
    raw = raw.strip()
    if not raw:
        raise ValueError("--since cannot be empty")

    base = now or datetime.now(timezone.utc)

    # Relative shorthand: <int><suffix>
    if len(raw) >= 2 and raw[-1] in {"m", "h", "d"} and raw[:-1].isdigit():
        amount = int(raw[:-1])
        suffix = raw[-1]
        if suffix == "m":
            return base - timedelta(minutes=amount)
        if suffix == "h":
            return base - timedelta(hours=amount)
        if suffix == "d":
            return base - timedelta(days=amount)

    # ISO8601 with trailing Z
    if raw.endswith("Z"):
        try:
            return datetime.fromisoformat(raw[:-1]).replace(tzinfo=timezone.utc)
        except ValueError as e:
            raise ValueError(f"unparseable ISO8601 timestamp: {raw!r}") from e

    # ISO8601 with offset (e.g., 2026-04-26T14:00:00+00:00)
    try:
        dt = datetime.fromisoformat(raw)
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt.astimezone(timezone.utc)
    except ValueError:
        pass

    # Loose `YYYY-MM-DD HH:MM` (UTC)
    for fmt in ("%Y-%m-%d %H:%M:%S", "%Y-%m-%d %H:%M", "%Y-%m-%d"):
        try:
            dt = datetime.strptime(raw, fmt).replace(tzinfo=timezone.utc)
            return dt
        except ValueError:
            continue

    raise ValueError(
        f"unparseable --since value: {raw!r}; use Nm/Nh/Nd or ISO8601 / YYYY-MM-DD"
    )


def _record_ts(record: dict) -> Optional[datetime]:
    """Parse a record's `ts` field into a UTC datetime, or None on failure."""
    ts = record.get("ts")
    if not isinstance(ts, str):
        return None
    try:
        if ts.endswith("Z"):
            return datetime.fromisoformat(ts[:-1]).replace(tzinfo=timezone.utc)
        dt = datetime.fromisoformat(ts)
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt.astimezone(timezone.utc)
    except ValueError:
        return None


# ---------------------------------------------------------------------------
# Formatting
# ---------------------------------------------------------------------------


def format_record(record: dict, *, color: bool = True) -> str:
    """Render one event record as a single human-readable line."""
    ts = record.get("ts", "—")
    type_ = record.get("type", "?")
    feature = record.get("feature") or "—"
    actor = record.get("actor", "?")
    payload = record.get("payload", {})

    # Compact payload preview: top-level keys only, joined with commas.
    if isinstance(payload, dict) and payload:
        keys = list(payload.keys())[:4]
        bits = []
        for k in keys:
            v = payload[k]
            if isinstance(v, (str, int, float, bool)) or v is None:
                bits.append(f"{k}={v}")
            else:
                bits.append(f"{k}=…")
        payload_str = " ".join(bits)
        if len(payload) > len(keys):
            payload_str += f" (+{len(payload) - len(keys)})"
    else:
        payload_str = ""

    if color:
        c = _color_for(type_)
        return (
            f"{_DIM}{ts}{_RESET} "
            f"{c}{_BOLD}{type_:<22}{_RESET} "
            f"{_CYAN}{feature:<10}{_RESET} "
            f"{actor:<14} "
            f"{_DIM}{payload_str}{_RESET}"
        )
    return f"{ts} {type_:<22} {feature:<10} {actor:<14} {payload_str}"


# ---------------------------------------------------------------------------
# Tailer
# ---------------------------------------------------------------------------


def _safe_parse_line(line: str) -> Optional[dict]:
    line = line.strip()
    if not line:
        return None
    try:
        record = json.loads(line)
    except json.JSONDecodeError:
        return None
    if not isinstance(record, dict):
        return None
    return record


def iter_lines(
    path: Path,
    *,
    from_start: bool,
    poll_interval: float,
    once: bool,
) -> Iterable[str]:
    """
    Yield raw lines from `path`, blocking-tail style.

    If `once` is True, yields existing lines and stops (used in tests + scripted
    usage). Otherwise polls forever, reopening on inode change or recreate.
    """
    pending = ""
    fh = None
    inode = None

    def _open_at(start: bool):
        """Open the file (creating gracefully when missing); return (fh, inode, pos)."""
        try:
            f = open(path, "r", encoding="utf-8", errors="replace")
        except FileNotFoundError:
            return None, None, 0
        try:
            ino = os.fstat(f.fileno()).st_ino
        except OSError:
            ino = None
        if not start:
            f.seek(0, os.SEEK_END)
        return f, ino, f.tell()

    fh, inode, _ = _open_at(start=from_start)

    while True:
        if fh is None:
            if once:
                return
            time.sleep(poll_interval)
            fh, inode, _ = _open_at(start=True)  # new file → read everything
            continue

        chunk = fh.read()
        if chunk:
            pending += chunk
            while "\n" in pending:
                line, pending = pending.split("\n", 1)
                yield line

        # Detect rotation/recreate (inode changed) or truncation (file shorter).
        try:
            stat = os.stat(path)
            if inode is not None and stat.st_ino != inode:
                fh.close()
                fh, inode, _ = _open_at(start=True)
                continue
            if stat.st_size < fh.tell():
                # Truncated — reopen from start.
                fh.close()
                fh, inode, _ = _open_at(start=True)
                continue
        except FileNotFoundError:
            fh.close()
            fh = None
            inode = None
            continue

        if once:
            if pending.strip():
                yield pending
            return

        time.sleep(poll_interval)


def watch(
    path: Path,
    *,
    filters: Optional[list[tuple[str, str]]] = None,
    since: Optional[datetime] = None,
    from_start: bool = False,
    color: Optional[bool] = None,
    poll_interval: float = 0.25,
    out=None,
    once: bool = False,
) -> int:
    """
    Tail `path` and emit color-coded lines.

    Returns the number of records emitted (useful in tests).
    """
    out = out if out is not None else sys.stdout
    if color is None:
        color = bool(getattr(out, "isatty", lambda: False)()) and os.environ.get(
            "NO_COLOR"
        ) is None
    filters = filters or []

    emitted = 0
    try:
        for raw in iter_lines(
            path, from_start=from_start, poll_interval=poll_interval, once=once
        ):
            record = _safe_parse_line(raw)
            if record is None:
                continue
            if filters and not matches_filters(record, filters):
                continue
            if since is not None:
                rec_ts = _record_ts(record)
                if rec_ts is None or rec_ts < since:
                    continue
            print(format_record(record, color=color), file=out, flush=True)
            emitted += 1
    except KeyboardInterrupt:
        pass
    return emitted


# ---------------------------------------------------------------------------
# CLI entry
# ---------------------------------------------------------------------------


def _build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="ag watch",
        description="Color-coded tail of .agentic/journal/events.jsonl.",
    )
    p.add_argument(
        "--journal-dir",
        type=Path,
        default=None,
        help="Path to journal directory (default: .agentic/journal under cwd).",
    )
    p.add_argument(
        "--path",
        type=Path,
        default=None,
        help="Override the events.jsonl path directly (advanced).",
    )
    p.add_argument(
        "--filter",
        action="append",
        default=[],
        metavar="key=value",
        help="Filter records (repeatable; AND-ed). e.g. --filter type=commit",
    )
    p.add_argument(
        "--since",
        default=None,
        help="Only emit records newer than this. Nm/Nh/Nd or ISO8601.",
    )
    p.add_argument(
        "--from-start",
        action="store_true",
        help="Read existing file from line 1 before tailing (default: tail end).",
    )
    p.add_argument(
        "--no-color",
        action="store_true",
        help="Disable ANSI colors (also honors NO_COLOR env var).",
    )
    p.add_argument(
        "--poll-interval",
        type=float,
        default=0.25,
        help="Polling interval in seconds (default: 0.25).",
    )
    p.add_argument(
        "--once",
        action="store_true",
        help="Read available data once and exit (no follow). Useful in scripts.",
    )
    return p


def main(argv: Optional[list[str]] = None) -> int:
    args = _build_parser().parse_args(argv)

    if args.path is not None:
        path = args.path
    else:
        journal_dir = args.journal_dir or Path.cwd() / ".agentic" / "journal"
        path = journal_dir / "events.jsonl"

    try:
        filters = [parse_filter(f) for f in args.filter]
    except ValueError as e:
        print(f"error: {e}", file=sys.stderr)
        return 2

    since: Optional[datetime] = None
    if args.since:
        try:
            since = parse_since(args.since)
        except ValueError as e:
            print(f"error: {e}", file=sys.stderr)
            return 2

    color = None if not args.no_color else False

    watch(
        path,
        filters=filters,
        since=since,
        from_start=args.from_start,
        color=color,
        poll_interval=args.poll_interval,
        once=args.once,
    )
    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
