#!/usr/bin/env python3
"""
Tests for `.agentic/lib/hooks/token_emit.py` (R-101).

Runs under pytest or directly: `python3 tests/hooks/test_token_emit.py`.

Coverage maps to the redesign-backlog AC list and the v3 plan's
`Component 6 — Tests`:

  - Fixture A: 5 assistant turns + 2 sidechain → 5 ledger records
  - Fixture B: re-run after +2 new turns → idempotent +2 only
  - Fixture C: malformed JSONL line → skip + telemetry
  - Fixture D: missing transcript → skip + telemetry, exit 0
  - Fixture E: feature attribution (4 cases mirroring §Component 4)
  - Schema-drift defensive logging (R9)
  - Concurrency: 4 different sessionIds → exact Σ of expected counts
"""
from __future__ import annotations

import json
import multiprocessing
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Iterable, Optional

_REPO_ROOT = Path(__file__).resolve().parents[2]
_LIB_DIR = _REPO_ROOT / ".agentic" / "lib"
_HOOKS_DIR = _LIB_DIR / "hooks"

sys.path.insert(0, str(_LIB_DIR))
sys.path.insert(0, str(_HOOKS_DIR))

import events  # noqa: E402
import token_emit  # noqa: E402


# ---------------------------------------------------------------------------
# Fixture builders
# ---------------------------------------------------------------------------


def _assistant_turn(
    *,
    session_id: str,
    uuid: str,
    timestamp: str = "2026-04-28T10:00:00.000Z",
    input_tokens: int = 100,
    output_tokens: int = 50,
    cache_read: int = 200,
    cache_creation: int = 30,
    model: str = "claude-opus-4-7",
    cwd: str = "/workspace",
    git_branch: str = "main",
    is_sidechain: bool = False,
    omit_usage: bool = False,
    omit_input_tokens: bool = False,
) -> dict:
    """Build a synthetic assistant transcript turn matching observed Claude Code shape."""
    msg: dict = {
        "model": model,
        "id": "msg_" + uuid[:10],
        "type": "message",
        "role": "assistant",
        "content": [{"type": "text", "text": "ok"}],
        "stop_reason": "end_turn",
    }
    if not omit_usage:
        usage: dict = {
            "output_tokens": output_tokens,
            "cache_read_input_tokens": cache_read,
            "cache_creation_input_tokens": cache_creation,
        }
        if not omit_input_tokens:
            usage["input_tokens"] = input_tokens
        msg["usage"] = usage
    return {
        "type": "assistant",
        "uuid": uuid,
        "sessionId": session_id,
        "timestamp": timestamp,
        "cwd": cwd,
        "gitBranch": git_branch,
        "isSidechain": is_sidechain,
        "message": msg,
    }


def _user_turn(*, session_id: str, uuid: str, timestamp: str = "2026-04-28T09:59:00.000Z") -> dict:
    return {
        "type": "user",
        "uuid": uuid,
        "sessionId": session_id,
        "timestamp": timestamp,
        "cwd": "/workspace",
        "gitBranch": "main",
        "isSidechain": False,
        "message": {"role": "user", "content": "hi"},
    }


def _write_transcript(path: Path, turns: Iterable[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        for t in turns:
            fh.write(json.dumps(t) + "\n")


def _read_ledger(path: Path) -> list[dict]:
    if not path.exists():
        return []
    out: list[dict] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.strip():
            out.append(json.loads(line))
    return out


def _make_sandbox() -> Path:
    """Return a tmp dir with .agentic/journal and .agentic/session."""
    base = Path(tempfile.mkdtemp(prefix="r101-test-"))
    (base / ".agentic" / "journal").mkdir(parents=True)
    (base / ".agentic" / "session").mkdir(parents=True)
    return base


# ---------------------------------------------------------------------------
# Fixture A — 5 assistant turns + 2 sidechain → 5 records, sidechain skipped
# ---------------------------------------------------------------------------


def test_fixture_a_emits_one_record_per_assistant_turn_skips_sidechain():
    sandbox = _make_sandbox()
    try:
        sid = "session-A"
        transcript = sandbox / "transcripts" / f"{sid}.jsonl"
        ledger = sandbox / ".agentic" / "journal" / "token-ledger.jsonl"
        turns = [
            _user_turn(session_id=sid, uuid="u-0"),
            _assistant_turn(session_id=sid, uuid="a-1", input_tokens=100, output_tokens=50),
            _assistant_turn(session_id=sid, uuid="a-2", input_tokens=200, output_tokens=80),
            _assistant_turn(session_id=sid, uuid="sc-1", is_sidechain=True),
            _assistant_turn(session_id=sid, uuid="a-3", input_tokens=150, output_tokens=60),
            _assistant_turn(session_id=sid, uuid="sc-2", is_sidechain=True),
            _assistant_turn(session_id=sid, uuid="a-4", input_tokens=300, output_tokens=120),
            _assistant_turn(session_id=sid, uuid="a-5", input_tokens=50, output_tokens=20),
        ]
        _write_transcript(transcript, turns)

        wm: dict = {}
        n = token_emit.emit_for_transcript(transcript, wm, ledger_path=ledger)

        assert n == 5
        records = _read_ledger(ledger)
        assert len(records) == 5
        # Exact-equality on token sums per the v3 plan G2 criterion.
        assert sum(r["tokens_in"] for r in records) == 100 + 200 + 150 + 300 + 50
        assert sum(r["tokens_out"] for r in records) == 50 + 80 + 60 + 120 + 20
        # tokens_in does NOT include cache_creation; G5 regression guard.
        assert all(r["tokens_in"] not in (130, 230, 180, 330, 80) for r in records)
        # All records carry the sessionId.
        assert {r["session_id"] for r in records} == {sid}
        # tier is "tier1" always for main-session work.
        assert {r["tier"] for r in records} == {"tier1"}
        # Watermark advanced to the last assistant uuid.
        assert wm[sid]["last_uuid"] == "a-5"
    finally:
        shutil.rmtree(sandbox, ignore_errors=True)


# ---------------------------------------------------------------------------
# Fixture B — idempotent re-run: append +2 new turns, second invocation emits
# only those two, watermark advances correctly.
# ---------------------------------------------------------------------------


def test_fixture_b_idempotent_resume_from_watermark():
    sandbox = _make_sandbox()
    try:
        sid = "session-B"
        transcript = sandbox / "transcripts" / f"{sid}.jsonl"
        ledger = sandbox / ".agentic" / "journal" / "token-ledger.jsonl"

        first_batch = [
            _assistant_turn(session_id=sid, uuid="b-1", input_tokens=10, output_tokens=5),
            _assistant_turn(session_id=sid, uuid="b-2", input_tokens=20, output_tokens=10),
            _assistant_turn(session_id=sid, uuid="b-3", input_tokens=30, output_tokens=15),
        ]
        _write_transcript(transcript, first_batch)

        wm: dict = {}
        n1 = token_emit.emit_for_transcript(transcript, wm, ledger_path=ledger)
        assert n1 == 3
        assert wm[sid]["last_uuid"] == "b-3"

        # Append two more turns; re-run.
        with open(transcript, "a", encoding="utf-8") as fh:
            fh.write(json.dumps(_assistant_turn(session_id=sid, uuid="b-4", input_tokens=40, output_tokens=20)) + "\n")
            fh.write(json.dumps(_assistant_turn(session_id=sid, uuid="b-5", input_tokens=50, output_tokens=25)) + "\n")

        n2 = token_emit.emit_for_transcript(transcript, wm, ledger_path=ledger)
        assert n2 == 2
        assert wm[sid]["last_uuid"] == "b-5"

        # Re-running with no new turns should be a no-op.
        n3 = token_emit.emit_for_transcript(transcript, wm, ledger_path=ledger)
        assert n3 == 0

        records = _read_ledger(ledger)
        assert len(records) == 5
        assert sum(r["tokens_in"] for r in records) == 10 + 20 + 30 + 40 + 50
    finally:
        shutil.rmtree(sandbox, ignore_errors=True)


# ---------------------------------------------------------------------------
# Fixture C — malformed JSONL line in the middle is skipped; surrounding
# turns still emitted.
# ---------------------------------------------------------------------------


def test_fixture_c_malformed_line_skipped_with_telemetry():
    sandbox = _make_sandbox()
    try:
        sid = "session-C"
        transcript = sandbox / "transcripts" / f"{sid}.jsonl"
        ledger = sandbox / ".agentic" / "journal" / "token-ledger.jsonl"

        good_a = _assistant_turn(session_id=sid, uuid="c-1", input_tokens=10, output_tokens=5)
        good_b = _assistant_turn(session_id=sid, uuid="c-2", input_tokens=20, output_tokens=10)
        transcript.parent.mkdir(parents=True, exist_ok=True)
        with open(transcript, "w", encoding="utf-8") as fh:
            fh.write(json.dumps(good_a) + "\n")
            fh.write("{this is not valid json\n")
            fh.write(json.dumps(good_b) + "\n")

        # Point events.append_event at a sandboxed path so we can read it back.
        ev_path = sandbox / ".agentic" / "journal" / "events.jsonl"
        old_default = events.default_events_path
        events.default_events_path = lambda: ev_path  # type: ignore
        try:
            wm: dict = {}
            n = token_emit.emit_for_transcript(transcript, wm, ledger_path=ledger)
        finally:
            events.default_events_path = old_default  # type: ignore

        assert n == 2
        records = _read_ledger(ledger)
        assert {r["tokens_in"] for r in records} == {10, 20}

        ev_records = _read_ledger(ev_path)
        skip_events = [e for e in ev_records if e.get("type") == "token_emit_skipped"]
        assert any(
            e.get("payload", {}).get("reason") == "malformed_jsonl" for e in skip_events
        ), f"expected malformed_jsonl skip event, got: {ev_records}"
    finally:
        shutil.rmtree(sandbox, ignore_errors=True)


# ---------------------------------------------------------------------------
# Fixture D — missing transcript file: hook skips, exits 0, emits telemetry.
# ---------------------------------------------------------------------------


def test_fixture_d_missing_transcript_emits_skip_event():
    sandbox = _make_sandbox()
    try:
        ledger = sandbox / ".agentic" / "journal" / "token-ledger.jsonl"
        ev_path = sandbox / ".agentic" / "journal" / "events.jsonl"
        nonexistent = sandbox / "no-such-transcript.jsonl"

        old_default = events.default_events_path
        events.default_events_path = lambda: ev_path  # type: ignore
        try:
            wm: dict = {}
            n = token_emit.emit_for_transcript(nonexistent, wm, ledger_path=ledger)
        finally:
            events.default_events_path = old_default  # type: ignore

        assert n == 0
        assert not ledger.exists()
        ev_records = _read_ledger(ev_path)
        assert any(
            e.get("type") == "token_emit_skipped"
            and e.get("payload", {}).get("reason") == "transcript_missing"
            for e in ev_records
        )
    finally:
        shutil.rmtree(sandbox, ignore_errors=True)


# ---------------------------------------------------------------------------
# Fixture E — feature attribution: 4 cases mirroring v3 §Component 4.
# ---------------------------------------------------------------------------


def test_feature_attribution_branch_primary():
    """Case (i): gitBranch matches feat/F-XXXX → feature_id from regex."""
    assert token_emit.parse_branch_feature("feat/F-0006-token-ledger") == "F-0006"
    assert token_emit.parse_branch_feature("feat/F-0123") == "F-0123"
    assert token_emit.parse_branch_feature("fix/F-9999-bug") == "F-9999"
    assert token_emit.parse_branch_feature("hotfix/F-0042") == "F-0042"


def test_feature_attribution_branch_no_match():
    """Cases that should not match the branch regex."""
    assert token_emit.parse_branch_feature("main") is None
    assert token_emit.parse_branch_feature("feat/something-else") is None
    assert token_emit.parse_branch_feature("chore/state") is None
    assert token_emit.parse_branch_feature(None) is None
    assert token_emit.parse_branch_feature("") is None
    # Out-of-grammar: 2-digit IDs
    assert token_emit.parse_branch_feature("feat/F-12") is None


def test_feature_attribution_agents_json_secondary():
    """Case (ii): branch doesn't match; AGENTS.json worktree match yields feature_id."""
    sandbox = _make_sandbox()
    try:
        # Make sandbox a real git repo so _git_toplevel resolves.
        subprocess.run(
            ["git", "init", "-q"], cwd=sandbox, check=True, capture_output=True
        )
        toplevel = subprocess.run(
            ["git", "-C", str(sandbox), "rev-parse", "--show-toplevel"],
            capture_output=True,
            text=True,
            check=True,
        ).stdout.strip()

        agents_path = sandbox / ".agentic" / "session" / "AGENTS.json"
        agents_path.write_text(
            json.dumps(
                [
                    {
                        "feature_id": "F-0006",
                        "worktree": toplevel,
                        "branch": "feat/F-0006-x",
                        "status": "active",
                    }
                ]
            )
        )

        result = token_emit.current_feature(
            cwd=str(sandbox),
            git_branch="main",  # branch primary fails
            agents_path=agents_path,
        )
        assert result == "F-0006"
    finally:
        shutil.rmtree(sandbox, ignore_errors=True)


def test_feature_attribution_none_fallback():
    """Case (iii): no branch match, no AGENTS.json entry → None."""
    sandbox = _make_sandbox()
    try:
        subprocess.run(
            ["git", "init", "-q"], cwd=sandbox, check=True, capture_output=True
        )
        agents_path = sandbox / ".agentic" / "session" / "AGENTS.json"
        agents_path.write_text("[]")
        result = token_emit.current_feature(
            cwd=str(sandbox),
            git_branch="chore/something",
            agents_path=agents_path,
        )
        assert result is None
    finally:
        shutil.rmtree(sandbox, ignore_errors=True)


def test_feature_attribution_worktree_match_when_cwd_inside():
    """Case (iv): cwd points inside worktree subdir; toplevel resolution finds match."""
    sandbox = _make_sandbox()
    try:
        subprocess.run(
            ["git", "init", "-q"], cwd=sandbox, check=True, capture_output=True
        )
        nested = sandbox / "src" / "deep"
        nested.mkdir(parents=True)
        toplevel = subprocess.run(
            ["git", "-C", str(sandbox), "rev-parse", "--show-toplevel"],
            capture_output=True,
            text=True,
            check=True,
        ).stdout.strip()

        agents_path = sandbox / ".agentic" / "session" / "AGENTS.json"
        agents_path.write_text(
            json.dumps([{"feature_id": "F-0006", "worktree": toplevel}])
        )

        result = token_emit.current_feature(
            cwd=str(nested),  # nested cwd, not toplevel
            git_branch="main",
            agents_path=agents_path,
        )
        assert result == "F-0006"
    finally:
        shutil.rmtree(sandbox, ignore_errors=True)


# ---------------------------------------------------------------------------
# Schema-drift defensive logging (R9)
# ---------------------------------------------------------------------------


def test_schema_drift_emits_telemetry_when_input_tokens_missing():
    sandbox = _make_sandbox()
    try:
        sid = "session-drift"
        transcript = sandbox / "transcripts" / f"{sid}.jsonl"
        ledger = sandbox / ".agentic" / "journal" / "token-ledger.jsonl"
        ev_path = sandbox / ".agentic" / "journal" / "events.jsonl"

        # Turn with usage but missing input_tokens (the failure shape R9 guards against).
        bad_turn = _assistant_turn(
            session_id=sid, uuid="d-1", omit_input_tokens=True
        )
        good_turn = _assistant_turn(
            session_id=sid, uuid="d-2", input_tokens=42, output_tokens=10
        )
        _write_transcript(transcript, [bad_turn, good_turn])

        old_default = events.default_events_path
        events.default_events_path = lambda: ev_path  # type: ignore
        try:
            wm: dict = {}
            n = token_emit.emit_for_transcript(transcript, wm, ledger_path=ledger)
        finally:
            events.default_events_path = old_default  # type: ignore

        assert n == 1  # only good turn emitted
        ev_records = _read_ledger(ev_path)
        drift_events = [e for e in ev_records if e.get("type") == "token_emit_schema_change"]
        assert any(
            "input_tokens" not in e.get("payload", {}).get("observed_keys", [])
            for e in drift_events
        )
    finally:
        shutil.rmtree(sandbox, ignore_errors=True)


# ---------------------------------------------------------------------------
# Concurrency — 4 different sessionIds writing to the same ledger.
#
# Each subprocess targets its own transcript + sessionId; the shared ledger
# (with flock in events._append_jsonl) must come out with exactly Σ(per-session
# expected counts) records.
# ---------------------------------------------------------------------------


def _concurrency_worker(args):
    transcript_path_s, ledger_path_s = args
    sys.path.insert(0, str(_LIB_DIR))
    sys.path.insert(0, str(_HOOKS_DIR))
    import token_emit as te  # noqa: E402

    wm: dict = {}
    n = te.emit_for_transcript(Path(transcript_path_s), wm, ledger_path=Path(ledger_path_s))
    return n


def test_concurrency_four_sessions_no_corruption():
    sandbox = _make_sandbox()
    try:
        ledger = sandbox / ".agentic" / "journal" / "token-ledger.jsonl"
        per_session = 5
        configs = []
        expected_total = 0
        for i in range(4):
            sid = f"concurrent-{i}"
            transcript = sandbox / "transcripts" / f"{sid}.jsonl"
            turns = [
                _assistant_turn(
                    session_id=sid, uuid=f"{sid}-u{j}", input_tokens=10 + j, output_tokens=5
                )
                for j in range(per_session)
            ]
            _write_transcript(transcript, turns)
            configs.append((str(transcript), str(ledger)))
            expected_total += per_session

        with multiprocessing.Pool(processes=4) as pool:
            results = pool.map(_concurrency_worker, configs)

        assert sum(results) == expected_total

        records = _read_ledger(ledger)
        assert len(records) == expected_total

        # Per-session subsets each match their own transcript exactly.
        by_session: dict[str, list[dict]] = {}
        for r in records:
            by_session.setdefault(r["session_id"], []).append(r)
        assert len(by_session) == 4
        for sid, recs in by_session.items():
            assert len(recs) == per_session, f"{sid}: {len(recs)} != {per_session}"
    finally:
        shutil.rmtree(sandbox, ignore_errors=True)


# ---------------------------------------------------------------------------
# Watermark prune — entries older than 30d are dropped.
# ---------------------------------------------------------------------------


def test_watermark_prune_drops_stale_entries():
    from datetime import datetime, timedelta, timezone

    now = datetime(2026, 4, 28, tzinfo=timezone.utc)
    fresh_ts = (now - timedelta(days=5)).isoformat().replace("+00:00", "Z")
    stale_ts = (now - timedelta(days=45)).isoformat().replace("+00:00", "Z")

    data = {
        "fresh-session": {"last_uuid": "u1", "last_seen": fresh_ts},
        "stale-session": {"last_uuid": "u2", "last_seen": stale_ts},
        "malformed-1": "not-a-dict",
        "malformed-2": {"last_uuid": "u3"},  # no last_seen
    }
    out = token_emit._prune_watermarks(data, now=now)
    assert "fresh-session" in out
    assert "stale-session" not in out
    assert "malformed-1" not in out
    assert "malformed-2" not in out


# ---------------------------------------------------------------------------
# Direct-run fallback for environments without pytest.
# ---------------------------------------------------------------------------


if __name__ == "__main__":
    failures: list[str] = []
    for name, obj in list(globals().items()):
        if name.startswith("test_") and callable(obj):
            try:
                obj()
                print(f"  ✓ {name}")
            except AssertionError as e:
                failures.append(f"{name}: {e}")
                print(f"  ✗ {name}: {e}")
            except Exception as e:
                failures.append(f"{name}: {type(e).__name__}: {e}")
                print(f"  ✗ {name}: {type(e).__name__}: {e}")
    if failures:
        print(f"\n{len(failures)} failure(s).")
        sys.exit(1)
    print(f"\nAll tests passed.")
