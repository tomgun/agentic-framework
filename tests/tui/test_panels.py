#!/usr/bin/env python3
"""
Tests for the TUI package (R-008).

Mirrors the R-007/R-001/R-002 pattern: pytest-free direct runner. Tests
target the pure-Python layer (streams, state, panel data shaping). The
Textual rendering is verified manually per the backlog's verify steps —
this container has no Textual installed, by design.

Coverage:
  * `streams.read_jsonl` + `_iter_new_lines` tailing & rotation
  * `StreamTail` callback delivery + parse-error path
  * `DashboardState` event ingestion → snapshot projection
  * Color hint table for the documented event types
  * Each panel's `*_lines(snap)` shaper
"""
from __future__ import annotations

import inspect
import json
import os
import sys
import tempfile
import threading
import time
from dataclasses import replace
from pathlib import Path
from typing import Iterable

_REPO_ROOT = Path(__file__).resolve().parents[2]
_LIB_DIR = _REPO_ROOT / ".agentic" / "lib"
sys.path.insert(0, str(_LIB_DIR))

from tui import streams, state  # noqa: E402
from tui.panels import header, workers as workers_panel, events as events_panel, health, drilldown  # noqa: E402
from tui.streams import StreamRecord, StreamTail, read_jsonl  # noqa: E402
from tui.state import (  # noqa: E402
    DashboardSnapshot, DashboardState, color_hint_for,
    EventSnapshot, HeaderSnapshot, HealthSnapshot,
)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _ev(*, ts="2026-04-26T14:30:00.000Z", type="tool_call",
        actor="harness", feature=None, payload=None):
    return {
        "ts": ts, "type": type, "actor": actor,
        "feature": feature, "payload": payload or {},
        "session_id": "s1",
    }


def _seed_state(events=()):
    ds = DashboardState(feature="F-008", profile="formal", mode="—",
                        clock=lambda: 1_000.0)
    for e in events:
        ds.apply_record(StreamRecord(stream="events", line_no=0, record=e))
    return ds


# ---------------------------------------------------------------------------
# streams.read_jsonl + tailer
# ---------------------------------------------------------------------------


def test_read_jsonl_handles_missing_and_corrupt_lines(tmp_path: Path):
    p = tmp_path / "x.jsonl"
    # Missing file -> empty list
    assert read_jsonl(p) == []
    # File with valid + invalid + empty lines
    p.write_text('{"a":1}\n\nnot-json\n{"b":2}\n')
    out = read_jsonl(p)
    assert out == [{"a": 1}, {"b": 2}]


def test_iter_new_lines_picks_up_appends(tmp_path: Path):
    p = tmp_path / "x.jsonl"
    p.write_text('{"x":1}\n')
    stop = threading.Event()
    received: list[str] = []

    def reader():
        for line in streams._iter_new_lines(
            p, from_start=True, poll_interval=0.05, stop_event=stop,
        ):
            received.append(line)
            if len(received) >= 2:
                stop.set()

    t = threading.Thread(target=reader, daemon=True)
    t.start()
    time.sleep(0.1)
    with p.open("a") as f:
        f.write('{"x":2}\n')
    t.join(timeout=2.0)
    assert received[:2] == ['{"x":1}', '{"x":2}']


def test_streamtail_dispatches_records_to_callback(tmp_path: Path):
    journal = tmp_path / "journal"
    journal.mkdir()
    (journal / "events.jsonl").write_text('')  # exists but empty
    received: list[StreamRecord] = []
    tail = StreamTail(journal_dir=journal, poll_interval=0.05, from_start=True)
    tail.start(on_record=received.append)
    try:
        with (journal / "events.jsonl").open("a") as f:
            f.write(json.dumps(_ev(type="commit", actor="alice")) + "\n")
            f.write(json.dumps(_ev(type="test_run", actor="harness",
                                   payload={"returncode": 0})) + "\n")
        # Wait up to 2s for the tailer to deliver both records.
        deadline = time.monotonic() + 2.0
        while time.monotonic() < deadline and len(received) < 2:
            time.sleep(0.05)
    finally:
        tail.stop()
    types = [r.type for r in received]
    assert "commit" in types and "test_run" in types


def test_streamtail_calls_on_error_for_bad_lines(tmp_path: Path):
    journal = tmp_path / "journal"
    journal.mkdir()
    (journal / "events.jsonl").write_text('')
    errors = []
    tail = StreamTail(journal_dir=journal, poll_interval=0.05, from_start=True)
    tail.start(
        on_record=lambda rec: None,
        on_error=lambda stream, raw, exc: errors.append((stream, raw)),
    )
    try:
        (journal / "events.jsonl").open("a").write("garbage line not json\n")
        time.sleep(0.3)
    finally:
        tail.stop()
    # Bad line should land in errors, not crash the tailer
    assert any("garbage" in raw for _, raw in errors)


# ---------------------------------------------------------------------------
# DashboardState — color hints
# ---------------------------------------------------------------------------


def test_color_hint_for_known_types():
    assert color_hint_for("commit", {}) == "green"
    assert color_hint_for("gate_blocked", {}) == "yellow"
    assert color_hint_for("human_needed", {}) == "red"
    assert color_hint_for("session_start", {}) == "blue"
    assert color_hint_for("intel_invoked", {}) == "dim"


def test_color_hint_test_run_failure_overrides_to_red():
    assert color_hint_for("test_run", {"returncode": 0}) == "green"
    assert color_hint_for("test_run", {"returncode": 1}) == "red"
    assert color_hint_for("test_run", {"returncode": 1, "skipped": True}) == "green"


def test_color_hint_critic_verdict_severity():
    assert color_hint_for("critic_verdict", {"verdict": "approve"}) == "blue"
    assert color_hint_for("critic_verdict", {"verdict": "request_changes"}) == "yellow"
    assert color_hint_for("critic_verdict", {"verdict": "escalate"}) == "red"


def test_color_hint_push_attempt_blocked_is_red():
    assert color_hint_for("push_attempt", {}) == "blue"
    assert color_hint_for("push_attempt", {"blocked": True}) == "red"


# ---------------------------------------------------------------------------
# DashboardState — event ingestion
# ---------------------------------------------------------------------------


def test_event_ring_bounded():
    """Bounded ring evicts oldest first — verify both length AND that the
    most recently appended record is present (would catch a 'drop everything
    on overflow' impl)."""
    ds = DashboardState(event_ring_size=5, clock=lambda: 1_000.0)
    for i in range(20):
        ds.apply_record(StreamRecord(
            stream="events", line_no=0,
            record=_ev(type="tool_call", payload={"i": i, "tool": f"tool-{i}"}),
        ))
    snap = ds.snapshot()
    assert len(snap.events) <= 5
    # The most recently appended event MUST still be in the ring.
    assert snap.events, "ring should never be empty after 20 appends"
    last_summary = snap.events[-1].summary
    assert "tool-19" in last_summary, f"expected tool-19 to survive eviction, got {last_summary!r}"
    # The first event (i=0) MUST have been dropped.
    summaries = [ev.summary for ev in snap.events]
    assert not any("tool-0 " in s or s.endswith("tool-0") for s in summaries), \
        f"oldest event should have been evicted, got {summaries}"


def test_workers_added_and_aged_out():
    times = [1000.0]

    def clock():
        return times[0]

    ds = DashboardState(worker_idle_seconds=60.0, clock=clock)
    ds.apply_record(StreamRecord(stream="events", line_no=0,
                                 record=_ev(type="session_start", actor="alice")))
    snap1 = ds.snapshot()
    assert any(w.actor == "alice" for w in snap1.workers)
    # Advance time past the idle threshold without further activity
    times[0] = 1200.0
    snap2 = ds.snapshot()
    assert all(w.actor != "alice" for w in snap2.workers)


def test_session_end_removes_worker():
    ds = DashboardState(clock=lambda: 1_000.0)
    ds.apply_record(StreamRecord(stream="events", line_no=0,
                                 record=_ev(type="session_start", actor="alice")))
    ds.apply_record(StreamRecord(stream="events", line_no=0,
                                 record=_ev(type="session_end", actor="alice")))
    assert ds.snapshot().workers == []


def test_gate_blocked_increments_escalations_and_sets_health_yellow():
    ds = _seed_state([
        _ev(type="gate_blocked",
            payload={"gate": "precommit",
                     "failures": [{"ac": "AC1", "title": "tests failing"}]})
    ])
    snap = ds.snapshot()
    assert snap.health.status == "yellow"
    assert snap.health.escalations == 1
    assert snap.health.last_blocked_reason and "tests failing" in snap.health.last_blocked_reason


def test_human_needed_sets_health_red_and_resolves():
    ds = _seed_state([_ev(type="human_needed", payload={"title": "credential"})])
    assert ds.snapshot().health.status == "red"
    ds.resolve_human_needed()
    assert ds.snapshot().health.status == "green"


def test_token_ledger_accumulates_into_header():
    ds = DashboardState(clock=lambda: 1_000.0)
    ds.set_quota_window(1_000)
    ds.apply_record(StreamRecord(stream="token-ledger", line_no=0, record={
        "ts": "x", "session_id": "s", "model": "haiku", "tier": "tier1",
        "tokens_in": 200, "tokens_out": 100,
    }))
    snap = ds.snapshot()
    assert snap.header.tokens_total == 300
    assert snap.header.quota_pct == 30.0


def test_quota_alerts_threshold_progression():
    ds = DashboardState(clock=lambda: 1_000.0)
    ds.set_quota_window(1000)
    for tokens, expected in [(699, None), (700, "70%"), (850, "85%"), (950, "95%")]:
        ds = DashboardState(clock=lambda: 1_000.0)
        ds.set_quota_window(1000)
        ds.apply_record(StreamRecord(stream="token-ledger", line_no=0, record={
            "ts": "x", "session_id": "s", "model": "haiku", "tier": "tier1",
            "tokens_in": tokens, "tokens_out": 0,
        }))
        snap = ds.snapshot()
        assert snap.health.quota_alert == expected, (tokens, expected, snap.health.quota_alert)


def test_event_selection_round_trip():
    ds = _seed_state([
        _ev(type="tool_call", payload={"tool": "Bash"}),
        _ev(type="commit", payload={"hash": "abc"}),
    ])
    snap = ds.snapshot()
    assert snap.selected_event is None
    ev = ds.select_event(1)
    assert ev is not None and ev.type == "commit"
    assert ds.snapshot().selected_event.type == "commit"
    ds.select_event(None)
    assert ds.snapshot().selected_event is None


# ---------------------------------------------------------------------------
# Panel shapers
# ---------------------------------------------------------------------------


def _empty_snap() -> DashboardSnapshot:
    return DashboardState(clock=lambda: 1_000.0).snapshot()


def test_header_lines_includes_feature_and_tokens():
    snap = _empty_snap()
    line = header.header_lines(snap)[0]
    assert "feature=" in line and "tokens=" in line


def test_header_lines_includes_quota_pct_when_window_set():
    ds = DashboardState(clock=lambda: 1_000.0)
    ds.set_quota_window(1000)
    ds.apply_record(StreamRecord(stream="token-ledger", line_no=0, record={
        "ts": "x", "session_id": "s", "model": "haiku", "tier": "tier1",
        "tokens_in": 250, "tokens_out": 0,
    }))
    line = header.header_lines(ds.snapshot())[0]
    assert "(25%)" in line


def test_worker_lines_handles_empty_state():
    snap = _empty_snap()
    out = workers_panel.worker_lines(snap)
    assert out == ["(no active workers)"]


def test_worker_lines_lists_active_workers():
    ds = _seed_state([
        _ev(type="session_start", actor="alice", feature="F-001"),
        _ev(type="task_dispatch", actor="alice",
            payload={"target": "AC-001 implement"}),
    ])
    snap = ds.snapshot()
    out = workers_panel.worker_lines(snap)
    joined = "\n".join(out)
    assert "alice" in joined and ("AC-001" in joined or "dispatch" in joined)


def test_event_lines_returns_color_hints():
    ds = _seed_state([
        _ev(type="commit", payload={"hash": "abc", "subject": "x"}),
        _ev(type="gate_blocked",
            payload={"gate": "precommit",
                     "failures": [{"ac": "AC1", "title": "tests"}]}),
    ])
    rows = events_panel.event_lines(ds.snapshot())
    colors = [c for _, c in rows]
    assert "green" in colors and "yellow" in colors


def test_event_lines_max_rows_truncates_oldest():
    ds = DashboardState(clock=lambda: 1_000.0)
    for i in range(50):
        ds.apply_record(StreamRecord(stream="events", line_no=0,
                                     record=_ev(type="tool_call",
                                                payload={"i": i})))
    rows = events_panel.event_lines(ds.snapshot(), max_rows=5)
    assert len(rows) == 5


def test_event_filter_helper_filters_by_type_and_actor():
    a = EventSnapshot(ts="t1", type="commit", actor="alice", feature="F",
                      summary="x", cost_tokens=None, color_hint="green")
    b = EventSnapshot(ts="t2", type="commit", actor="bob", feature="F",
                      summary="y", cost_tokens=None, color_hint="green")
    c = EventSnapshot(ts="t3", type="tool_call", actor="alice", feature="F",
                      summary="z", cost_tokens=None, color_hint="dim")
    out_alice = events_panel.filter_events([a, b, c], actor="alice")
    out_commit = events_panel.filter_events([a, b, c], rec_type="commit")
    assert len(out_alice) == 2 and all(e.actor == "alice" for e in out_alice)
    assert len(out_commit) == 2 and all(e.type == "commit" for e in out_commit)


def test_health_lines_green_when_clean():
    snap = _empty_snap()
    line = health.health_lines(snap)[0]
    assert "GREEN" in line


def test_health_lines_yellow_with_escalation():
    ds = _seed_state([
        _ev(type="gate_blocked",
            payload={"gate": "precommit",
                     "failures": [{"ac": "AC1", "title": "tests"}]})
    ])
    line = health.health_lines(ds.snapshot())[0]
    assert "YELLOW" in line and "escalations=1" in line


def test_drilldown_lines_no_selection_message():
    snap = _empty_snap()
    out = drilldown.drilldown_lines(snap)
    assert any("no event selected" in line for line in out)


def test_drilldown_lines_render_selected_event_fields():
    ds = _seed_state([_ev(type="commit", actor="alice",
                          payload={"hash": "abc123", "subject": "fix"})])
    ds.select_event(0)
    out = drilldown.drilldown_lines(ds.snapshot())
    joined = "\n".join(out)
    assert "type      : commit" in joined
    assert "actor     : alice" in joined


# ---------------------------------------------------------------------------
# CLI surface (without Textual)
# ---------------------------------------------------------------------------


def test_main_returns_2_with_install_hint_when_textual_missing(tmp_path: Path):
    """`python3 -m tui --journal-dir <tmp>` should exit 2 and print the
    install hint to stderr when Textual is absent. Skipped when Textual is
    installed — in that case `run_tui()` would actually try to draw a TUI
    and either succeed (interactive) or fail for unrelated reasons."""
    try:
        import textual  # noqa: F401
        # Textual is installed — this test isn't applicable. The full TUI
        # rendering path is verified manually per the backlog's verify steps.
        return
    except ImportError:
        pass
    proc = __import__("subprocess").run(
        [sys.executable, "-m", "tui", "--journal-dir", str(tmp_path)],
        cwd=str(_REPO_ROOT),
        env={**os.environ, "PYTHONPATH": str(_LIB_DIR)},
        capture_output=True, text=True, check=False, timeout=10,
    )
    assert proc.returncode == 2, proc.stderr
    assert "Textual" in proc.stderr or "textual" in proc.stderr


# ---------------------------------------------------------------------------
# Direct-run harness
# ---------------------------------------------------------------------------


def _discover_tests() -> Iterable[tuple[str, callable]]:
    g = globals()
    for name in sorted(g):
        if name.startswith("test_") and callable(g[name]):
            yield name, g[name]


def _run_directly() -> int:
    failures = []
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
