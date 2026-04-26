#!/usr/bin/env python3
"""
Tests for `.agentic/lib/events.py` (R-007).

Runs under pytest or directly: `python3 tests/test_events.py`. The latter is the
fallback for environments without pytest installed (CI mirror images, scratch
containers).
"""
from __future__ import annotations

import json
import multiprocessing as mp
import os
import re
import sys
import time
from pathlib import Path
from typing import Iterable

_LIB_DIR = Path(__file__).resolve().parent.parent / ".agentic" / "lib"
sys.path.insert(0, str(_LIB_DIR))

import events  # noqa: E402  (imported via the path injection above)


# ---------------------------------------------------------------------------
# Shape + schema parity
# ---------------------------------------------------------------------------


def test_required_fields_present(tmp_path: Path) -> None:
    path = tmp_path / "events.jsonl"
    rec = events.append_event(
        type="session_start",
        session_id="sess-1",
        actor="harness",
        payload={"foo": "bar"},
        feature="F-008",
        path=path,
    )
    for field in ("ts", "session_id", "type", "feature", "actor", "payload"):
        assert field in rec, f"missing required field: {field}"
    assert re.match(events._TS_RE, rec["ts"])


def test_at_least_15_event_types_enumerated() -> None:
    assert len(events.EVENT_TYPES) >= 15, (
        "AC-2 requires 15+ canonical event types; "
        f"only {len(events.EVENT_TYPES)} declared"
    )
    # Spot-check the explicitly named ones from R-007 AC-2.
    must_have = {
        "session_start",
        "task_dispatch",
        "tool_call",
        "commit",
        "test_run",
        "critic_verdict",
        "contract_check",
        "human_needed",
        "task_complete",
        "session_end",
        "gate_blocked",
        "gate_skipped",
    }
    missing = must_have - set(events.EVENT_TYPES)
    assert not missing, f"missing AC-named event types: {missing}"


def test_validation_error_on_unknown_type(tmp_path: Path) -> None:
    try:
        events.append_event(
            type="not_a_real_type",
            session_id="sess-1",
            actor="harness",
            payload={},
            path=tmp_path / "events.jsonl",
        )
    except events.ValidationError as e:
        assert "type" in str(e)
    else:
        raise AssertionError("expected ValidationError for unknown event type")


def test_validation_error_on_missing_session_id(tmp_path: Path) -> None:
    try:
        events.append_event(
            type="session_start",
            session_id="",
            actor="harness",
            payload={},
            path=tmp_path / "events.jsonl",
        )
    except events.ValidationError:
        return
    raise AssertionError("expected ValidationError for empty session_id")


def test_validation_error_on_bad_feature_pattern(tmp_path: Path) -> None:
    try:
        events.append_event(
            type="commit",
            session_id="sess-1",
            actor="harness",
            payload={},
            feature="not-a-feature-id",
            path=tmp_path / "events.jsonl",
        )
    except events.ValidationError as e:
        assert "feature" in str(e)
    else:
        raise AssertionError("expected ValidationError for bad feature ID")


def test_validation_error_on_non_dict_payload(tmp_path: Path) -> None:
    # Bypass append_event's coercion by calling the validator directly.
    bad = {
        "ts": events.now_iso(),
        "session_id": "s",
        "type": "tool_call",
        "feature": None,
        "actor": "harness",
        "payload": "not-an-object",
    }
    try:
        events.validate_event(bad)
    except events.ValidationError:
        return
    raise AssertionError("expected ValidationError for non-object payload")


# ---------------------------------------------------------------------------
# Persistence semantics
# ---------------------------------------------------------------------------


def test_creates_file_and_parent_on_first_append(tmp_path: Path) -> None:
    target = tmp_path / "deep" / "nested" / "events.jsonl"
    assert not target.exists()
    events.append_event(
        type="session_start",
        session_id="sess-1",
        actor="harness",
        payload={},
        path=target,
    )
    assert target.exists()
    assert target.parent.is_dir()


def test_appends_one_line_per_call_no_truncation(tmp_path: Path) -> None:
    target = tmp_path / "events.jsonl"
    for i in range(5):
        events.append_event(
            type="commit",
            session_id="sess-1",
            actor="harness",
            payload={"i": i},
            path=target,
        )
    lines = target.read_text(encoding="utf-8").splitlines()
    assert len(lines) == 5
    for i, line in enumerate(lines):
        rec = json.loads(line)
        assert rec["payload"]["i"] == i
        assert "_truncated" not in rec


def test_writer_never_truncates_file(tmp_path: Path) -> None:
    """Pre-existing content must survive every append."""
    target = tmp_path / "events.jsonl"
    events.append_event(
        type="session_start",
        session_id="sess-1",
        actor="harness",
        payload={"first": True},
        path=target,
    )
    pre = target.read_text(encoding="utf-8")
    for _ in range(3):
        events.append_event(
            type="tool_call",
            session_id="sess-1",
            actor="harness",
            payload={},
            path=target,
        )
    post = target.read_text(encoding="utf-8")
    assert post.startswith(pre), "writer must not rewrite or replace existing content"


# ---------------------------------------------------------------------------
# 8 KB soft cap
# ---------------------------------------------------------------------------


def test_oversized_payload_is_truncated_with_marker(tmp_path: Path) -> None:
    target = tmp_path / "events.jsonl"
    big = "x" * 9000  # > 8 KB on its own
    events.append_event(
        type="tool_call",
        session_id="sess-1",
        actor="harness",
        payload={"blob": big},
        path=target,
    )
    line = target.read_text(encoding="utf-8").splitlines()[0]
    assert len(line.encode("utf-8")) <= events.LINE_BYTE_CAP - 1
    rec = json.loads(line)
    assert rec.get("_truncated") is True
    assert rec["payload"].get("_truncated_field") == "payload"
    assert rec["payload"].get("_original_bytes", 0) > 0


def test_normal_payload_is_not_marked_truncated(tmp_path: Path) -> None:
    target = tmp_path / "events.jsonl"
    events.append_event(
        type="commit",
        session_id="sess-1",
        actor="harness",
        payload={"hash": "abc1234", "files": ["a.py", "b.py"]},
        path=target,
    )
    rec = json.loads(target.read_text(encoding="utf-8").splitlines()[0])
    assert "_truncated" not in rec


# ---------------------------------------------------------------------------
# JSON Schema files exist + parse
# ---------------------------------------------------------------------------


def test_schemas_present_and_valid_json() -> None:
    schemas_dir = _LIB_DIR / "schemas"
    for name in ("events", "delegation", "token-ledger"):
        path = schemas_dir / f"{name}.schema.json"
        assert path.exists(), f"missing schema file: {path}"
        data = json.loads(path.read_text(encoding="utf-8"))
        assert data["$id"].endswith(f"{name}.schema.json")
        assert "required" in data
        assert "properties" in data


def test_event_schema_enum_matches_python_constant() -> None:
    schema = json.loads(
        (_LIB_DIR / "schemas" / "events.schema.json").read_text(encoding="utf-8")
    )
    schema_enum = tuple(schema["properties"]["type"]["enum"])
    assert schema_enum == events.EVENT_TYPES, (
        "events.schema.json type enum drifted from events.EVENT_TYPES; "
        "keep them in lockstep"
    )


# ---------------------------------------------------------------------------
# Delegation + token-ledger writers
# ---------------------------------------------------------------------------


def test_delegation_writer_round_trip(tmp_path: Path) -> None:
    target = tmp_path / "delegation.jsonl"
    rec = events.append_delegation(
        session_id="sess-1",
        delegation_id="del-1",
        tier="tier2",
        model="claude-sonnet-4-6",
        target="plan",
        verdict="approve",
        actor="harness",
        feature="F-008",
        tokens_in=1200,
        tokens_out=800,
        cost_usd=0.012,
        wall_time_ms=4500,
        summary="LGTM",
        path=target,
    )
    line = target.read_text(encoding="utf-8").splitlines()[0]
    parsed = json.loads(line)
    assert parsed["delegation_id"] == "del-1"
    assert parsed["verdict"] == "approve"
    assert parsed["tokens_in"] == 1200


def test_delegation_validation_rejects_bad_verdict(tmp_path: Path) -> None:
    try:
        events.append_delegation(
            session_id="sess-1",
            delegation_id="del-1",
            tier="tier2",
            model="claude-sonnet-4-6",
            target="plan",
            verdict="lgtm",  # not in enum
            actor="harness",
            path=tmp_path / "delegation.jsonl",
        )
    except events.ValidationError:
        return
    raise AssertionError("expected ValidationError for bad verdict")


def test_token_ledger_writer_round_trip(tmp_path: Path) -> None:
    target = tmp_path / "token-ledger.jsonl"
    events.append_token_ledger(
        session_id="sess-1",
        model="claude-haiku-4-5",
        tier="tier2",
        tokens_in=400,
        tokens_out=120,
        actor="critic-haiku",
        feature="F-008",
        cache_read_tokens=0,
        cache_write_tokens=0,
        cost_usd=0.0008,
        path=target,
    )
    rec = json.loads(target.read_text(encoding="utf-8").splitlines()[0])
    assert rec["tier"] == "tier2"
    assert rec["tokens_in"] == 400


def test_token_ledger_rejects_negative_tokens(tmp_path: Path) -> None:
    try:
        events.append_token_ledger(
            session_id="sess-1",
            model="claude-haiku-4-5",
            tier="tier2",
            tokens_in=-1,
            tokens_out=0,
            path=tmp_path / "token-ledger.jsonl",
        )
    except events.ValidationError:
        return
    raise AssertionError("expected ValidationError for negative tokens")


# ---------------------------------------------------------------------------
# Concurrency (the AC-3 acceptance test)
# ---------------------------------------------------------------------------


def _worker_append(args: tuple) -> None:
    """Spawned subprocess body for the concurrent-writers test."""
    target, worker_id, n = args
    sys.path.insert(0, str(_LIB_DIR))
    import events as ev  # re-import in subprocess

    for i in range(n):
        ev.append_event(
            type="tool_call",
            session_id=f"sess-{worker_id}",
            actor=f"worker-{worker_id}",
            payload={"i": i, "wid": worker_id},
            path=target,
        )


def test_4x1000_concurrent_appends_produce_4000_valid_lines(tmp_path: Path) -> None:
    target = tmp_path / "events.jsonl"
    workers = 4
    per_worker = 1000

    ctx = mp.get_context("fork" if sys.platform != "win32" else "spawn")
    procs = [
        ctx.Process(target=_worker_append, args=((target, wid, per_worker),))
        for wid in range(workers)
    ]
    for p in procs:
        p.start()
    for p in procs:
        p.join(timeout=120)
        assert p.exitcode == 0, f"worker exited with code {p.exitcode}"

    lines = target.read_text(encoding="utf-8").splitlines()
    assert len(lines) == workers * per_worker, (
        f"expected {workers * per_worker} lines, got {len(lines)}"
    )

    # Each line must parse and validate.
    counts = [0] * workers
    for line in lines:
        rec = json.loads(line)
        events.validate_event(rec)
        counts[rec["payload"]["wid"]] += 1
    assert counts == [per_worker] * workers, f"per-worker counts: {counts}"


# ---------------------------------------------------------------------------
# Direct-run harness (works without pytest installed)
# ---------------------------------------------------------------------------


def _discover_tests() -> Iterable[tuple[str, callable]]:
    g = globals()
    for name in sorted(g):
        if name.startswith("test_") and callable(g[name]):
            yield name, g[name]


def _run_directly() -> int:
    import inspect
    import tempfile

    failures: list[tuple[str, BaseException]] = []
    passed = 0

    for name, fn in _discover_tests():
        sig = inspect.signature(fn)
        with tempfile.TemporaryDirectory() as td:
            kwargs = {}
            if "tmp_path" in sig.parameters:
                kwargs["tmp_path"] = Path(td)
            try:
                fn(**kwargs)
            except BaseException as exc:  # noqa: BLE001
                failures.append((name, exc))
                print(f"FAIL {name}: {exc}")
            else:
                passed += 1
                print(f"PASS {name}")

    print(f"\n{passed} passed, {len(failures)} failed")
    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(_run_directly())
