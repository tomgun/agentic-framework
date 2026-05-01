#!/usr/bin/env python3
"""
token_emit.py — R-101 token-ledger emitter (Stop hook + SessionStart recovery).

Reads the Claude Code transcript JSONL written by the harness, parses each
assistant turn's `message.usage` block, and appends one record per turn to
`.agentic/journal/token-ledger.jsonl` via `events.append_token_ledger()`.

Two entry points share one parsing core:

  python3 -m hooks.token_emit stop      — invoked from the Stop hook chain.
                                           Reads stdin (the Anthropic Stop hook
                                           envelope) for `transcript_path`.

  python3 -m hooks.token_emit recover   — invoked from the SessionStart chain.
                                           Re-scans all watermarked sessions
                                           for unprocessed turns left behind
                                           by abrupt termination (Ctrl+C,
                                           terminal close, OOM kill — Stop
                                           never fires for those).

What is emitted (per assistant turn that has `message.usage`):

  tokens_in           = usage["input_tokens"]                  (NET NEW input)
  tokens_out          = usage["output_tokens"]
  cache_read_tokens   = usage["cache_read_input_tokens"]       (informational)
  cache_write_tokens  = usage["cache_creation_input_tokens"]   (informational)

  CRITICAL: `tokens_in` does NOT include cache_creation_input_tokens. This
  matches the convention `quota.py:228-235` already uses (`ti = tokens_in`
  summed straight as billable input). Folding cache_creation in would
  silently inflate every post-R-101 quota number vs. all numbers produced
  before R-101 — a regression of R-013's quota report.

What is skipped (logged, not failed):

  - `type != "assistant"` rows (user, system, tool_result, snapshots)
  - `isSidechain == true` (subagent transcripts; R-201 owns those)
  - `message.usage` absent (synthetic snapshot rows)
  - `input_tokens` or `output_tokens` missing/non-int → schema-drift event
  - Whole transcript file missing or `transcript_path` absent → skip event

Exit code is always 0. Telemetry must NEVER block work — that is the Tier 0
git layer's job.

Idempotence + concurrency:

  - Watermark file `.agentic/session/.token-ledger-watermarks.json` records
    the last-processed assistant-turn UUID per sessionId.
  - Flock on the watermark file serializes processes; the ledger's own
    flock (via `_append_jsonl`) serializes appends across all writers.
  - Re-running on a static transcript is a no-op.
  - 4 different concurrent sessionIds writing to the same ledger produce
    exactly Σ(per-session expected counts) records (G3 sub-test).

Tier attribution: always `"tier1"` for main-session work (per v5 plan tier
matrix). Subagent / Agent Teams costs are tracked via delegation.jsonl by
R-201/R-401 dispatchers — out of R-101 scope.

Feature attribution (`current_feature()`):

  1. PRIMARY    Parse the transcript line's `gitBranch` field with regex
                `^(?:feat|fix|hotfix)/(F-\\d{3,4})(?:[-_].*)?$` — every
                feature in this framework branches as `feat/F-XXXX-…` per
                `ag implement` enforcement.
  2. SECONDARY  Read `.agentic/session/AGENTS.json` (canonical schema at
                `agents_helpers.py:10-29`). Find entry where `worktree`
                equals `git -C <cwd> rev-parse --show-toplevel`. Return
                its `feature_id`.
  3. FALLBACK   `None`. Records render under "(untagged)".
"""

from __future__ import annotations

import errno
import fcntl
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Iterator, Optional

# Make .agentic/lib importable when invoked as a script, not just module.
_LIB_DIR = Path(__file__).resolve().parent.parent
if str(_LIB_DIR) not in sys.path:
    sys.path.insert(0, str(_LIB_DIR))

import events  # noqa: E402  — events.append_token_ledger / append_event


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------


_BRANCH_FEATURE_RE = re.compile(
    # Match every feature-id prefix the schema enumerates:
    # F-XXX (capabilities), DEV-XXX (developer tooling), E-XXX (epics),
    # NFR-XXX (non-functional requirements), R-XXX (redesign tracker).
    # Mirrors the `feature` field pattern in events.schema.json so the
    # emitter and the schema can never disagree on what counts as a feature.
    r"^(?:feat|fix|hotfix)/((?:F|R|DEV|E|NFR)-\d+(?:\.[1-9][0-9]*)*)(?:[-_].*)?$"
)
_DEFAULT_TIER = "tier1"
_DEFAULT_ACTOR = "assistant"
_WATERMARK_PRUNE_DAYS = 30


# ---------------------------------------------------------------------------
# Path helpers
# ---------------------------------------------------------------------------


def _project_root() -> Path:
    """Return CLAUDE_PROJECT_DIR if set; otherwise cwd."""
    raw = os.environ.get("CLAUDE_PROJECT_DIR")
    return Path(raw).resolve() if raw else Path.cwd().resolve()


def watermark_path(project_root: Optional[Path] = None) -> Path:
    root = project_root or _project_root()
    return root / ".agentic" / "session" / ".token-ledger-watermarks.json"


def agents_json_path(project_root: Optional[Path] = None) -> Path:
    root = project_root or _project_root()
    return root / ".agentic" / "session" / "AGENTS.json"


# ---------------------------------------------------------------------------
# Feature attribution
# ---------------------------------------------------------------------------


def parse_branch_feature(branch: Optional[str]) -> Optional[str]:
    """Return the feature id captured from a `feat|fix|hotfix/{F,R,DEV,E,NFR}-N…` branch, else None.

    The set of accepted prefixes mirrors the `feature` field in
    events.schema.json. R-XXX (redesign tracker) is included so framework
    work-on-the-framework branches like `feat/R-101-…` get attributed
    instead of falling through to "(untagged)".
    """
    if not isinstance(branch, str) or not branch:
        return None
    m = _BRANCH_FEATURE_RE.match(branch.strip())
    return m.group(1) if m else None


def _git_toplevel(cwd: str) -> Optional[str]:
    """Resolve git toplevel for cwd; return None on any failure (not a git repo, etc.)."""
    try:
        out = subprocess.run(
            ["git", "-C", cwd, "rev-parse", "--show-toplevel"],
            capture_output=True,
            text=True,
            timeout=5,
            check=False,
        )
        if out.returncode != 0:
            return None
        path = out.stdout.strip()
        return path or None
    except (OSError, subprocess.SubprocessError):
        return None


def feature_from_agents_json(
    cwd: Optional[str], agents_path: Optional[Path] = None
) -> Optional[str]:
    """Read AGENTS.json; return feature_id where `worktree` matches git toplevel of cwd."""
    if not cwd:
        return None
    toplevel = _git_toplevel(cwd)
    if not toplevel:
        return None
    path = agents_path or agents_json_path()
    if not path.exists():
        return None
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None
    if not isinstance(data, list):
        return None
    target = str(Path(toplevel).resolve())
    for entry in data:
        if not isinstance(entry, dict):
            continue
        worktree = entry.get("worktree")
        if not isinstance(worktree, str):
            continue
        try:
            if str(Path(worktree).resolve()) == target:
                fid = entry.get("feature_id")
                if isinstance(fid, str) and fid:
                    return fid
        except (OSError, ValueError):
            continue
    return None


def current_feature(
    cwd: Optional[str],
    git_branch: Optional[str],
    *,
    agents_path: Optional[Path] = None,
) -> Optional[str]:
    """Resolve feature attribution: branch primary → AGENTS.json secondary → None."""
    fid = parse_branch_feature(git_branch)
    if fid:
        return fid
    return feature_from_agents_json(cwd, agents_path=agents_path)


# ---------------------------------------------------------------------------
# Watermark file (flock-protected; per-session last-processed UUID)
# ---------------------------------------------------------------------------


def _flock_with_retry(fd: int, op: int, *, attempts: int = 50, delay: float = 0.02) -> None:
    """flock with bounded retry on EINTR (matches events.py pattern)."""
    import time

    for _ in range(attempts):
        try:
            fcntl.flock(fd, op)
            return
        except OSError as e:
            if e.errno == errno.EINTR:
                time.sleep(delay)
                continue
            raise
    raise OSError(errno.EINTR, "flock interrupted repeatedly")


def _read_watermarks(path: Path) -> dict:
    """Return current watermark dict or {} if missing/unreadable.

    Path-based read used by tests and SessionStart-recovery (which iterates
    over watermarks before holding flock). The hot path in main_stop /
    main_recover uses `_read_watermarks_fd` instead so the read happens on
    the same fd the flock guards — avoiding the TOCTOU window between
    open(path) and flock acquisition.
    """
    if not path.exists():
        return {}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        return data if isinstance(data, dict) else {}
    except (OSError, json.JSONDecodeError):
        return {}


def _read_watermarks_fd(fd: int) -> dict:
    """Read watermarks from an open fd held under flock.

    Reads the entire file from offset 0. Used by the production hot path so
    the read+modify+write cycle stays bound to a single inode that the flock
    actually serializes against.
    """
    try:
        os.lseek(fd, 0, os.SEEK_SET)
        chunks: list[bytes] = []
        while True:
            buf = os.read(fd, 65536)
            if not buf:
                break
            chunks.append(buf)
        if not chunks:
            return {}
        data = json.loads(b"".join(chunks).decode("utf-8"))
        return data if isinstance(data, dict) else {}
    except (OSError, json.JSONDecodeError, UnicodeDecodeError):
        return {}


def _prune_watermarks(data: dict, *, now: Optional[datetime] = None, days: int = _WATERMARK_PRUNE_DAYS) -> dict:
    """Remove watermark entries whose last_seen is older than `days`. Mutates+returns."""
    now_dt = now or datetime.now(timezone.utc)
    cutoff = now_dt - timedelta(days=days)
    keys_to_drop = []
    for sid, entry in data.items():
        if not isinstance(entry, dict):
            keys_to_drop.append(sid)
            continue
        last_seen = entry.get("last_seen")
        if not isinstance(last_seen, str):
            keys_to_drop.append(sid)
            continue
        try:
            ts = datetime.fromisoformat(last_seen.replace("Z", "+00:00"))
        except ValueError:
            keys_to_drop.append(sid)
            continue
        if ts < cutoff:
            keys_to_drop.append(sid)
    for k in keys_to_drop:
        del data[k]
    return data


def _write_watermarks_inplace(fd: int, data: dict) -> None:
    """Truncate + write watermarks to the held fd without changing the inode.

    The earlier implementation used temp+rename for crash-atomicity, but
    rename swaps the inode underneath any concurrent fd. A second writer that
    opened the wm_path AFTER the rename gets a fresh inode — and its flock
    no longer serializes against an outstanding flock on the unlinked inode.
    Two simultaneous Stop hooks could then have one update silently lost.

    In-place truncate+write keeps every writer bound to the same inode, so
    flock holds its serialization guarantee. Crash-safety is weaker (a kill
    between truncate and write leaves the file partially written), but
    `_read_watermarks{,_fd}` returns `{}` on JSON decode error, and the
    next emit re-walks from the previous valid watermark — at most one
    duplicate record per session, idempotent with the per-line watermark
    update inside `emit_for_transcript`.
    """
    payload = json.dumps(data, sort_keys=True, indent=2).encode("utf-8")
    os.lseek(fd, 0, os.SEEK_SET)
    os.ftruncate(fd, 0)
    os.write(fd, payload)
    try:
        os.fsync(fd)
    except OSError:
        # fsync can fail on some filesystems (e.g. tmpfs in tests); the
        # caller's flock + the JSON-on-error fallback in _read_watermarks
        # are enough to keep correctness.
        pass


# ---------------------------------------------------------------------------
# Transcript parsing
# ---------------------------------------------------------------------------


def _iter_transcript_lines(transcript_path: Path) -> Iterator[tuple[int, dict]]:
    """Yield (line_no_1based, parsed_dict) for each non-empty line. Skips malformed."""
    try:
        fh = open(transcript_path, "r", encoding="utf-8", errors="replace")
    except OSError:
        return
    try:
        for line_no, raw in enumerate(fh, start=1):
            stripped = raw.strip()
            if not stripped:
                continue
            try:
                parsed = json.loads(stripped)
            except json.JSONDecodeError:
                _safe_event(
                    "token_emit_skipped",
                    {"reason": "malformed_jsonl", "line_no": line_no},
                )
                continue
            if not isinstance(parsed, dict):
                continue
            yield line_no, parsed
    finally:
        fh.close()


def _is_assistant_usage_turn(line: dict) -> bool:
    """True iff this transcript row is an assistant turn with a usage block we care about."""
    if line.get("type") != "assistant":
        return False
    if line.get("isSidechain") is True:
        return False
    msg = line.get("message")
    if not isinstance(msg, dict):
        return False
    usage = msg.get("usage")
    return isinstance(usage, dict)


def _build_record(line: dict) -> Optional[dict]:
    """Map a transcript turn to the kwargs for events.append_token_ledger.

    Returns None when the turn is missing required usage fields (in which case
    the caller emits token_emit_schema_change).
    """
    msg = line["message"]
    usage = msg["usage"]
    in_tok = usage.get("input_tokens")
    out_tok = usage.get("output_tokens")
    if not isinstance(in_tok, int) or not isinstance(out_tok, int):
        return None
    if in_tok < 0 or out_tok < 0:
        return None
    cache_read = usage.get("cache_read_input_tokens", 0)
    cache_write = usage.get("cache_creation_input_tokens", 0)
    if not isinstance(cache_read, int) or cache_read < 0:
        cache_read = 0
    if not isinstance(cache_write, int) or cache_write < 0:
        cache_write = 0

    session_id = line.get("sessionId")
    if not isinstance(session_id, str) or not session_id:
        return None
    model = msg.get("model")
    if not isinstance(model, str) or not model:
        model = "unknown"
    ts = line.get("timestamp") or events.now_iso()

    return {
        "session_id": session_id,
        "model": model,
        "tier": _DEFAULT_TIER,
        "tokens_in": in_tok,
        "tokens_out": out_tok,
        "cache_read_tokens": cache_read,
        "cache_write_tokens": cache_write,
        "feature": current_feature(line.get("cwd"), line.get("gitBranch")),
        "actor": _DEFAULT_ACTOR,
        "ts": ts,
    }


# ---------------------------------------------------------------------------
# Telemetry helper (skip + schema-drift events)
# ---------------------------------------------------------------------------


def _safe_event(event_type: str, payload: dict) -> None:
    """Emit a telemetry event; swallow errors (telemetry never blocks).

    R9 mitigation depends on schema-drift events reaching events.jsonl so the
    user sees them via `ag watch --filter type=token_emit_schema_change`. If
    `events.append_event` itself fails (disk full, lock contention, encoding
    error), a silent swallow would defeat that purpose. We log a single
    one-line warning to stderr so the failure is at least observable in
    Claude Code's hook output, while still keeping `exit 0` semantics so
    the hook never blocks the user's session.
    """
    try:
        events.append_event(
            type=event_type,
            session_id=payload.get("session_id", "token_emit"),
            actor="token_emit",
            payload=payload,
            feature=None,
        )
    except Exception as exc:
        try:
            sys.stderr.write(
                f"[token_emit] telemetry write failed: "
                f"event_type={event_type} err={type(exc).__name__}: {exc}\n"
            )
        except Exception:
            # stderr itself is unwritable — give up; we tried.
            pass


# ---------------------------------------------------------------------------
# Core: process a single transcript from watermark forward
# ---------------------------------------------------------------------------


def emit_for_transcript(
    transcript_path: Path,
    watermarks: dict,
    *,
    ledger_path: Optional[Path] = None,
) -> int:
    """Process turns past the watermark for the transcript's sessionId.

    Mutates `watermarks` in place (caller writes it back atomically under flock).
    Returns the count of new ledger records appended.
    """
    if not transcript_path.exists():
        _safe_event(
            "token_emit_skipped",
            {"reason": "transcript_missing", "transcript_path": str(transcript_path)},
        )
        return 0

    appended = 0
    last_uuid_per_session: dict[str, str] = {}

    for line_no, line in _iter_transcript_lines(transcript_path):
        if not _is_assistant_usage_turn(line):
            continue

        sid = line.get("sessionId")
        if not isinstance(sid, str) or not sid:
            continue

        # Skip turns at-or-before the watermark for this sessionId.
        wm = watermarks.get(sid)
        wm_uuid = wm.get("last_uuid") if isinstance(wm, dict) else None
        # Past-watermark detection: record-then-skip until we see wm_uuid in the
        # stream; then process everything after. If no watermark, process all.
        # Simpler: track per-session "have we passed the watermark?" state.
        # We reset per session_id within this transcript file.
        state = last_uuid_per_session.setdefault("__state__:" + sid, "")
        if wm_uuid and not state == "passed":
            this_uuid = line.get("uuid")
            if this_uuid == wm_uuid:
                last_uuid_per_session["__state__:" + sid] = "passed"
            # In either case (the watermark line itself or anything before), skip.
            continue

        # Past the watermark (or no watermark existed): process this turn.
        record_kwargs = _build_record(line)
        if record_kwargs is None:
            usage = line.get("message", {}).get("usage", {}) if isinstance(line.get("message"), dict) else {}
            _safe_event(
                "token_emit_schema_change",
                {
                    "reason": "missing_required_usage_fields",
                    "session_id": sid,
                    "line_no": line_no,
                    "observed_keys": sorted(list(usage.keys())) if isinstance(usage, dict) else [],
                },
            )
            continue

        try:
            events.append_token_ledger(path=ledger_path, **record_kwargs)
        except events.ValidationError as exc:
            _safe_event(
                "token_emit_skipped",
                {
                    "reason": "validation_error",
                    "session_id": sid,
                    "line_no": line_no,
                    "error": str(exc),
                },
            )
            continue

        appended += 1
        this_uuid = line.get("uuid")
        if isinstance(this_uuid, str) and this_uuid:
            last_uuid_per_session[sid] = this_uuid

    # Update watermarks for any session we advanced.
    now_iso = events.now_iso()
    for sid, last_uuid in last_uuid_per_session.items():
        if sid.startswith("__state__:"):
            continue
        watermarks[sid] = {"last_uuid": last_uuid, "last_seen": now_iso}

    return appended


# ---------------------------------------------------------------------------
# Stop entry point
# ---------------------------------------------------------------------------


def _read_stdin_envelope() -> dict:
    """Best-effort parse of the Stop hook stdin JSON. Returns {} if absent/invalid."""
    if sys.stdin.isatty():
        return {}
    try:
        raw = sys.stdin.read()
    except OSError:
        return {}
    if not raw.strip():
        return {}
    try:
        data = json.loads(raw)
        return data if isinstance(data, dict) else {}
    except json.JSONDecodeError:
        return {}


def main_stop() -> int:
    """Stop hook entry point. Returns 0 always (telemetry never blocks)."""
    envelope = _read_stdin_envelope()
    transcript_raw = envelope.get("transcript_path")
    if not isinstance(transcript_raw, str) or not transcript_raw:
        _safe_event("token_emit_skipped", {"reason": "no_transcript_path"})
        return 0
    transcript_path = Path(transcript_raw).expanduser()

    wm_path = watermark_path()
    wm_path.parent.mkdir(parents=True, exist_ok=True)
    # Open ONCE for the read+modify+write cycle. Reading and writing both
    # happen on this fd — under flock — so the inode flock guards never
    # changes underneath a concurrent writer (see _write_watermarks_inplace
    # for the rationale).
    fd = os.open(str(wm_path), os.O_RDWR | os.O_CREAT, 0o644)
    try:
        _flock_with_retry(fd, fcntl.LOCK_EX)
        watermarks = _read_watermarks_fd(fd)
        _prune_watermarks(watermarks)
        emit_for_transcript(transcript_path, watermarks)
        _write_watermarks_inplace(fd, watermarks)
    finally:
        try:
            fcntl.flock(fd, fcntl.LOCK_UN)
        finally:
            os.close(fd)
    return 0


# ---------------------------------------------------------------------------
# SessionStart recovery entry point
# ---------------------------------------------------------------------------


def _enumerate_known_transcripts(envelope: dict) -> list[Path]:
    """Return transcript paths for recovery. Trusts envelope first; never enumerates blindly."""
    paths: list[Path] = []
    direct = envelope.get("transcript_path")
    if isinstance(direct, str) and direct:
        p = Path(direct).expanduser()
        if p.exists():
            paths.append(p)
    return paths


def main_recover() -> int:
    """SessionStart recovery entry point. Re-scans known transcripts for unprocessed turns."""
    envelope = _read_stdin_envelope()
    transcripts = _enumerate_known_transcripts(envelope)
    if not transcripts:
        # Best-effort: scan transcripts referenced by current watermarks. This
        # closes the Ctrl+C gap when SessionStart's envelope only describes the
        # NEW session; older sessions need a different signal.
        wm_path_p = watermark_path()
        if wm_path_p.exists():
            wm_data = _read_watermarks(wm_path_p)
            envelope_cwd = envelope.get("cwd") if isinstance(envelope.get("cwd"), str) else os.getcwd()
            home = Path.home()
            encoded = str(envelope_cwd).replace("/", "-")
            project_dir = home / ".claude" / "projects" / encoded
            if project_dir.exists():
                for sid in wm_data:
                    candidate = project_dir / f"{sid}.jsonl"
                    if candidate.exists():
                        transcripts.append(candidate)

    if not transcripts:
        _safe_event("token_emit_skipped", {"reason": "no_recoverable_transcripts"})
        return 0

    wm_path_p = watermark_path()
    wm_path_p.parent.mkdir(parents=True, exist_ok=True)
    fd = os.open(str(wm_path_p), os.O_RDWR | os.O_CREAT, 0o644)
    try:
        _flock_with_retry(fd, fcntl.LOCK_EX)
        watermarks = _read_watermarks_fd(fd)
        _prune_watermarks(watermarks)
        for tp in transcripts:
            emit_for_transcript(tp, watermarks)
        _write_watermarks_inplace(fd, watermarks)
    finally:
        try:
            fcntl.flock(fd, fcntl.LOCK_UN)
        finally:
            os.close(fd)
    return 0


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def main(argv: Optional[list[str]] = None) -> int:
    args = list(argv if argv is not None else sys.argv[1:])
    if not args:
        sys.stderr.write("usage: python3 -m hooks.token_emit {stop|recover}\n")
        return 0  # never block
    mode = args[0]
    if mode == "stop":
        return main_stop()
    if mode == "recover":
        return main_recover()
    sys.stderr.write(f"unknown mode: {mode!r}\n")
    return 0  # never block


if __name__ == "__main__":
    sys.exit(main())
