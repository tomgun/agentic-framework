"""
events.py — Canonical append-only event spine (R-007).

Three JSONL streams under `.agentic/journal/`:

* `events.jsonl`        — every framework decision, commit, test run, critic verdict,
                          escalation. One JSON object per line.
* `delegation.jsonl`    — every Tier 2 / Tier 3 worker invocation with cost + outcome.
* `token-ledger.jsonl`  — per-session and per-worker token spend.

The schemas live next to this module at `.agentic/lib/schemas/{events,delegation,token-ledger}.schema.json`
and are the source of truth for external validators (ajv, jsonschema, etc.). The
in-process writers below validate against the same shape with a small built-in
validator, so the framework does not require `jsonschema` at runtime.

Process safety
--------------
Concurrent writers from parallel sessions/worktrees would corrupt JSONL if appends
were interleaved. `_append_jsonl()` opens the file in append mode, takes an
exclusive `fcntl.flock` for the duration of the write, fsyncs, and releases. POSIX
guarantees writes <= PIPE_BUF are atomic; the lock keeps each line whole regardless
of size. Tested with 4 processes × 1000 events; resulting file has exactly 4000
valid lines.

Soft size cap
-------------
Each line has an 8KB soft cap (LINE_BYTE_CAP). If the encoded record exceeds the
cap, the writer replaces the largest free-form field (`payload` for events,
`summary` for delegation) with a truncation marker and adds `_truncated: true`.
This keeps `events.jsonl` cheap to scan and prevents one runaway record from
breaking line-oriented tooling.

Never deletes
-------------
This module never opens a file with `w` mode. Callers wanting to rotate or archive
must do so explicitly in a separate process.
"""

from __future__ import annotations

import errno
import fcntl
import json
import os
import re
import threading
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Mapping, Optional

# ---------------------------------------------------------------------------
# Public constants
# ---------------------------------------------------------------------------

LINE_BYTE_CAP = 8192  # 8 KB soft cap per JSONL line

EVENT_TYPES: tuple[str, ...] = (
    "session_start",
    "session_end",
    "task_dispatch",
    "task_complete",
    "tool_call",
    "commit",
    "test_run",
    "critic_verdict",
    "contract_check",
    "human_needed",
    "gate_blocked",
    "gate_skipped",
    "push_attempt",
    "merge_attempt",
    "hotfix_commit",
    "integrity_baseline_updated",
    "intel_invoked",
    "quota_degraded",
)

DELEGATION_VERDICTS: tuple[str, ...] = (
    "approve",
    "request_changes",
    "escalate",
    "in_progress",
    "error",
)

TIERS: tuple[str, ...] = ("tier0", "tier1", "tier2", "tier3")
DELEGATION_TIERS: tuple[str, ...] = ("tier2", "tier3")

# Feature ID grammar — must match `.agentic/lib/schemas/contract.schema.json`.
_FEATURE_ID_RE = re.compile(r"^(F|DEV|E|NFR)-[0-9]{3,}(\.[1-9][0-9]*)*$")

# ISO8601 UTC, Z-suffixed, optional fractional seconds.
_TS_RE = re.compile(
    r"^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(?:\.[0-9]+)?Z$"
)

# Process-local lock so concurrent threads serialize before contending for flock.
_THREAD_LOCK = threading.Lock()


class ValidationError(ValueError):
    """Raised when a record fails the in-house schema check."""


# ---------------------------------------------------------------------------
# Time + path helpers
# ---------------------------------------------------------------------------


def now_iso() -> str:
    """Return current UTC time as ISO8601 with millisecond precision and trailing Z."""
    dt = datetime.now(timezone.utc)
    # Python emits +00:00; replace with Z and trim to milliseconds.
    return dt.strftime("%Y-%m-%dT%H:%M:%S.") + f"{dt.microsecond // 1000:03d}Z"


def default_journal_dir() -> Path:
    """
    Resolve the journal directory.

    Prefers `.agentic/lib/paths.py` when importable (the canonical project resolver);
    falls back to `<cwd>/.agentic/journal`. Tests pass an explicit `path=` so this
    fallback is fine for non-project contexts.
    """
    try:
        # Local import keeps events.py importable without paths.py present.
        import sys

        lib_dir = str(Path(__file__).resolve().parent)
        if lib_dir not in sys.path:
            sys.path.insert(0, lib_dir)
        from paths import get_paths  # type: ignore

        return Path(get_paths().journal_dir)
    except Exception:
        return Path.cwd() / ".agentic" / "journal"


def default_events_path() -> Path:
    return default_journal_dir() / "events.jsonl"


def default_delegation_path() -> Path:
    return default_journal_dir() / "delegation.jsonl"


def default_token_ledger_path() -> Path:
    return default_journal_dir() / "token-ledger.jsonl"


# ---------------------------------------------------------------------------
# Validators (in-process; mirror the JSON Schemas in schemas/)
# ---------------------------------------------------------------------------


def _require_str(record: Mapping[str, Any], field: str, *, max_len: int = 128) -> None:
    value = record.get(field)
    if not isinstance(value, str) or not value:
        raise ValidationError(f"{field!r} must be a non-empty string")
    if len(value) > max_len:
        raise ValidationError(f"{field!r} exceeds {max_len} characters")


def _require_ts(record: Mapping[str, Any]) -> None:
    ts = record.get("ts")
    if not isinstance(ts, str) or not _TS_RE.match(ts):
        raise ValidationError(
            "'ts' must be ISO8601 UTC with trailing Z (e.g., 2026-04-26T14:30:01.000Z)"
        )


def _require_optional_feature(record: Mapping[str, Any]) -> None:
    feature = record.get("feature")
    if feature is None or feature == "":
        return
    if not isinstance(feature, str) or not _FEATURE_ID_RE.match(feature):
        raise ValidationError(
            "'feature' must match (F|DEV|E|NFR)-NNN[.M] pattern or be null/empty"
        )


def validate_event(record: Mapping[str, Any]) -> None:
    """Validate an events.jsonl record. Raises ValidationError on first failure."""
    if not isinstance(record, Mapping):
        raise ValidationError("event record must be a mapping")
    _require_ts(record)
    _require_str(record, "session_id")
    _require_str(record, "actor")
    type_ = record.get("type")
    if type_ not in EVENT_TYPES:
        raise ValidationError(
            f"'type' must be one of {EVENT_TYPES!r}; got {type_!r}"
        )
    _require_optional_feature(record)
    payload = record.get("payload")
    if payload is None or not isinstance(payload, dict):
        raise ValidationError("'payload' must be a JSON object (possibly empty)")


def validate_delegation(record: Mapping[str, Any]) -> None:
    """Validate a delegation.jsonl record."""
    if not isinstance(record, Mapping):
        raise ValidationError("delegation record must be a mapping")
    _require_ts(record)
    _require_str(record, "session_id")
    _require_str(record, "delegation_id")
    _require_str(record, "model")
    _require_str(record, "target")
    _require_str(record, "actor")
    tier = record.get("tier")
    if tier not in DELEGATION_TIERS:
        raise ValidationError(
            f"'tier' must be one of {DELEGATION_TIERS!r}; got {tier!r}"
        )
    verdict = record.get("verdict")
    if verdict not in DELEGATION_VERDICTS:
        raise ValidationError(
            f"'verdict' must be one of {DELEGATION_VERDICTS!r}; got {verdict!r}"
        )
    _require_optional_feature(record)


def validate_token_ledger(record: Mapping[str, Any]) -> None:
    """Validate a token-ledger.jsonl record."""
    if not isinstance(record, Mapping):
        raise ValidationError("token-ledger record must be a mapping")
    _require_ts(record)
    _require_str(record, "session_id")
    _require_str(record, "model")
    tier = record.get("tier")
    if tier not in TIERS:
        raise ValidationError(f"'tier' must be one of {TIERS!r}; got {tier!r}")
    for field in ("tokens_in", "tokens_out"):
        value = record.get(field)
        if not isinstance(value, int) or value < 0 or isinstance(value, bool):
            raise ValidationError(f"'{field}' must be a non-negative integer")
    _require_optional_feature(record)


# ---------------------------------------------------------------------------
# Encoding + truncation
# ---------------------------------------------------------------------------


def _encode_line(record: Mapping[str, Any]) -> bytes:
    """JSON-encode a single record as one UTF-8 line (no trailing newline)."""
    return json.dumps(record, separators=(",", ":"), ensure_ascii=False).encode("utf-8")


def _truncate_to_cap(record: dict, *, big_field: str) -> dict:
    """
    Shrink `record` so its encoded length is <= LINE_BYTE_CAP - 1 (leave room for \n).

    Replaces `record[big_field]` with a small marker that records the original size;
    sets `_truncated: True`. If still too large after that, raises ValidationError —
    that means the non-truncatable fields alone exceed the cap, which would indicate
    a misuse (e.g., a 10KB session_id).
    """
    cap = LINE_BYTE_CAP - 1  # one byte for the newline appended at write-time
    if len(_encode_line(record)) <= cap:
        return record

    original = record.get(big_field)
    try:
        original_bytes = len(_encode_line({big_field: original}))
    except (TypeError, ValueError):
        original_bytes = 0

    record = dict(record)
    record[big_field] = {
        "_truncated_field": big_field,
        "_original_bytes": original_bytes,
    }
    record["_truncated"] = True

    if len(_encode_line(record)) > cap:
        raise ValidationError(
            "record exceeds LINE_BYTE_CAP even after truncating "
            f"{big_field!r}; trim other fields"
        )
    return record


# ---------------------------------------------------------------------------
# Append primitive
# ---------------------------------------------------------------------------


def _append_jsonl(path: Path, record: dict) -> dict:
    """
    Append `record` as a single line to `path`. Process-safe via fcntl.flock.

    Returns the (possibly truncation-mutated) record actually written.
    Creates parent directory + file if missing. Never opens with mode 'w'.
    """
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)

    line = _encode_line(record) + b"\n"

    with _THREAD_LOCK:
        # 'a' guarantees POSIX append semantics; the OS positions writes at EOF.
        # flock serializes writers across processes on the same local FS.
        with open(path, "ab") as fh:
            _flock_with_retry(fh.fileno(), fcntl.LOCK_EX)
            try:
                fh.write(line)
                fh.flush()
                os.fsync(fh.fileno())
            finally:
                fcntl.flock(fh.fileno(), fcntl.LOCK_UN)

    return record


def _flock_with_retry(fd: int, op: int, *, attempts: int = 50, delay: float = 0.02) -> None:
    """flock with bounded retry on EINTR (signal interruption)."""
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


# ---------------------------------------------------------------------------
# Public writers
# ---------------------------------------------------------------------------


def append_event(
    *,
    type: str,
    session_id: str,
    actor: str,
    payload: Optional[Mapping[str, Any]] = None,
    feature: Optional[str] = None,
    ts: Optional[str] = None,
    path: Optional[os.PathLike] = None,
) -> dict:
    """
    Append one event to events.jsonl. Returns the record as written.

    Validates against the events schema before writing. On payload >8KB, the
    payload is replaced with a truncation marker and `_truncated: True` is set.
    """
    record: dict[str, Any] = {
        "ts": ts or now_iso(),
        "session_id": session_id,
        "type": type,
        "feature": feature if feature else None,
        "actor": actor,
        "payload": dict(payload) if payload is not None else {},
    }
    validate_event(record)
    record = _truncate_to_cap(record, big_field="payload")
    target = Path(path) if path is not None else default_events_path()
    return _append_jsonl(target, record)


def append_delegation(
    *,
    session_id: str,
    delegation_id: str,
    tier: str,
    model: str,
    target: str,
    verdict: str,
    actor: str,
    feature: Optional[str] = None,
    tokens_in: Optional[int] = None,
    tokens_out: Optional[int] = None,
    cost_usd: Optional[float] = None,
    wall_time_ms: Optional[int] = None,
    summary: Optional[str] = None,
    ts: Optional[str] = None,
    path: Optional[os.PathLike] = None,
) -> dict:
    """Append one record to delegation.jsonl."""
    record: dict[str, Any] = {
        "ts": ts or now_iso(),
        "session_id": session_id,
        "delegation_id": delegation_id,
        "tier": tier,
        "model": model,
        "target": target,
        "feature": feature if feature else None,
        "verdict": verdict,
        "actor": actor,
        "tokens_in": tokens_in,
        "tokens_out": tokens_out,
        "cost_usd": cost_usd,
        "wall_time_ms": wall_time_ms,
        "summary": summary,
    }
    validate_delegation(record)
    record = _truncate_to_cap(record, big_field="summary")
    target_path = Path(path) if path is not None else default_delegation_path()
    return _append_jsonl(target_path, record)


def append_token_ledger(
    *,
    session_id: str,
    model: str,
    tier: str,
    tokens_in: int,
    tokens_out: int,
    actor: Optional[str] = None,
    feature: Optional[str] = None,
    cache_read_tokens: Optional[int] = None,
    cache_write_tokens: Optional[int] = None,
    cost_usd: Optional[float] = None,
    delegation_id: Optional[str] = None,
    ts: Optional[str] = None,
    path: Optional[os.PathLike] = None,
) -> dict:
    """Append one record to token-ledger.jsonl."""
    record: dict[str, Any] = {
        "ts": ts or now_iso(),
        "session_id": session_id,
        "model": model,
        "tier": tier,
        "actor": actor,
        "feature": feature if feature else None,
        "tokens_in": tokens_in,
        "tokens_out": tokens_out,
        "cache_read_tokens": cache_read_tokens,
        "cache_write_tokens": cache_write_tokens,
        "cost_usd": cost_usd,
        "delegation_id": delegation_id,
    }
    validate_token_ledger(record)
    target_path = Path(path) if path is not None else default_token_ledger_path()
    return _append_jsonl(target_path, record)


__all__ = [
    "EVENT_TYPES",
    "DELEGATION_VERDICTS",
    "TIERS",
    "DELEGATION_TIERS",
    "LINE_BYTE_CAP",
    "ValidationError",
    "now_iso",
    "default_journal_dir",
    "default_events_path",
    "default_delegation_path",
    "default_token_ledger_path",
    "validate_event",
    "validate_delegation",
    "validate_token_ledger",
    "append_event",
    "append_delegation",
    "append_token_ledger",
]
