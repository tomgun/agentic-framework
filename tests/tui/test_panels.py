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
    # R-014: percentage rendered next to a colored ring char rather than in
    # bare parens. The percentage itself remains visible to the user.
    assert "25%" in line


def test_header_lines_ring_segment_progression():
    """R-014 AC1 — quarter-circle ring chars track fill bands."""
    cases = [
        (0.0, "○"),
        (10.0, "◔"),
        (24.9, "◔"),
        (25.0, "◐"),
        (49.0, "◐"),
        (50.0, "◕"),
        (74.0, "◕"),
        (75.0, "●"),
        (100.0, "●"),
    ]
    for pct, expected in cases:
        assert header._ring_segment(pct) == expected, (pct, expected)
    # No quota → empty disc
    assert header._ring_segment(None) == "○"


def test_header_lines_color_thresholds():
    """R-014 AC2 — green<70, yellow<85, dark_orange<95, red≥95."""
    cases = [
        (0.0, "green"),
        (69.9, "green"),
        (70.0, "yellow"),
        (84.9, "yellow"),
        (85.0, "dark_orange"),
        (94.9, "dark_orange"),
        (95.0, "red"),
        (100.0, "red"),
    ]
    for pct, expected in cases:
        assert header._color_for_pct(pct) == expected, (pct, expected)
    assert header._color_for_pct(None) is None


def test_header_lines_ring_emits_color_markup():
    """R-014 AC1 + AC2 — the rendered header includes the ring char wrapped
    in Rich color markup matching the threshold."""
    for tokens, expected_color, expected_ring in [
        (300, "green", "◐"),       # 30% -> green half-disc
        (750, "yellow", "●"),      # 75% -> yellow full-disc
        (900, "dark_orange", "●"), # 90% -> orange full-disc
        (970, "red", "●"),         # 97% -> red full-disc
    ]:
        ds = DashboardState(clock=lambda: 1_000.0)
        ds.set_quota_window(1000)
        ds.apply_record(StreamRecord(stream="token-ledger", line_no=0, record={
            "ts": "x", "session_id": "s", "model": "haiku", "tier": "tier1",
            "tokens_in": tokens, "tokens_out": 0,
        }))
        line = header.header_lines(ds.snapshot())[0]
        assert f"[bold {expected_color}]" in line, (tokens, expected_color, line)
        assert expected_ring in line, (tokens, expected_ring, line)


def test_header_by_tier_accumulates_from_token_ledger():
    """R-014 AC3 prerequisite — token-ledger records carry a `tier` field
    and the snapshot exposes a per-tier breakdown."""
    ds = DashboardState(clock=lambda: 1_000.0)
    ds.set_quota_window(1000)
    for tier, ti, to in [("tier1", 100, 50), ("tier2", 200, 0), ("tier1", 50, 0)]:
        ds.apply_record(StreamRecord(stream="token-ledger", line_no=0, record={
            "ts": "x", "session_id": "s", "model": "haiku", "tier": tier,
            "tokens_in": ti, "tokens_out": to,
        }))
    snap = ds.snapshot()
    assert snap.header.by_tier == {"tier1": 200, "tier2": 200}
    assert snap.header.tokens_total == 400


def test_header_by_tier_tooltip_format():
    """R-014 AC3 — tooltip lists per-tier tokens with percentages."""
    ds = DashboardState(clock=lambda: 1_000.0)
    ds.set_quota_window(1000)
    ds.apply_record(StreamRecord(stream="token-ledger", line_no=0, record={
        "ts": "x", "session_id": "s", "model": "haiku", "tier": "tier1",
        "tokens_in": 300, "tokens_out": 0,
    }))
    ds.apply_record(StreamRecord(stream="token-ledger", line_no=0, record={
        "ts": "x", "session_id": "s", "model": "opus", "tier": "tier2",
        "tokens_in": 100, "tokens_out": 0,
    }))
    tooltip = header.by_tier_tooltip(ds.snapshot())
    assert "tier1" in tooltip and "300" in tooltip
    assert "tier2" in tooltip and "100" in tooltip
    assert "75.0%" in tooltip  # tier1 share of 400
    assert "25.0%" in tooltip  # tier2 share of 400


def test_header_by_tier_tooltip_empty_when_no_records():
    snap = _empty_snap()
    tooltip = header.by_tier_tooltip(snap)
    assert "No token-ledger records" in tooltip


# ---------------------------------------------------------------------------
# R-101 — per-session + rolling-window header line
# ---------------------------------------------------------------------------


def test_r101_state_tracks_per_session_totals():
    ds = DashboardState(clock=lambda: 1_000.0)
    for ti, sid, feature in [
        (1000, "sess-A", "F-006"),
        (2000, "sess-A", "F-006"),
        (500, "sess-B", "F-008"),
    ]:
        ds.apply_record(StreamRecord(stream="token-ledger", line_no=0, record={
            "ts": "x", "session_id": sid, "model": "haiku", "tier": "tier1",
            "tokens_in": ti, "tokens_out": 0, "feature": feature,
        }))
    snap = ds.snapshot()
    # Most-recent session is sess-B (last apply call)
    assert snap.header.current_session_id == "sess-B"
    assert snap.header.current_session_tokens == 500
    # Rolling window aggregates both sessions
    assert snap.header.rolling_window_tokens == 3500
    assert snap.header.rolling_window_sessions == 2
    # Top feature across rolling window: F-006 wins (3000 vs 500)
    assert snap.header.top_feature_label == "F-006"
    assert snap.header.top_feature_tokens == 3000


def test_r101_header_lines_emit_session_summary_when_data_present():
    ds = DashboardState(clock=lambda: 1_000.0)
    ds.apply_record(StreamRecord(stream="token-ledger", line_no=0, record={
        "ts": "x", "session_id": "sess-A", "model": "haiku", "tier": "tier1",
        "tokens_in": 200_000, "tokens_out": 87_000, "feature": "F-006",
    }))
    lines = header.header_lines(ds.snapshot())
    assert len(lines) == 2
    assert "Session" in lines[1]
    assert "287K" in lines[1]
    assert "Roll" in lines[1]
    assert "F-006" in lines[1]


def test_r101_header_lines_skip_session_summary_when_no_data():
    snap = _empty_snap()
    lines = header.header_lines(snap)
    # No token-ledger data → only the original line, no R-101 second line
    assert len(lines) == 1


def test_r101_header_lines_skip_session_summary_for_records_without_session_id():
    """Records without a session_id still increment the global tokens_total
    (legacy behavior) but cannot contribute to the per-session view, so the
    R-101 line should not appear when ALL records lack session_id."""
    ds = DashboardState(clock=lambda: 1_000.0)
    ds.apply_record(StreamRecord(stream="token-ledger", line_no=0, record={
        # No session_id field
        "ts": "x", "model": "haiku", "tier": "tier1",
        "tokens_in": 100, "tokens_out": 0,
    }))
    lines = header.header_lines(ds.snapshot())
    assert len(lines) == 1


def test_r101_top_feature_prefers_tagged_over_untagged():
    """When a session has both tagged and (untagged) work, the panel should
    surface the tagged label. Falls back to (untagged) only when nothing
    else is present."""
    ds = DashboardState(clock=lambda: 1_000.0)
    # Untagged record (lots of tokens) + tagged record (fewer tokens)
    ds.apply_record(StreamRecord(stream="token-ledger", line_no=0, record={
        "ts": "x", "session_id": "sess-A", "model": "haiku", "tier": "tier1",
        "tokens_in": 5_000, "tokens_out": 0,  # no feature → (untagged)
    }))
    ds.apply_record(StreamRecord(stream="token-ledger", line_no=0, record={
        "ts": "x", "session_id": "sess-A", "model": "haiku", "tier": "tier1",
        "tokens_in": 1_000, "tokens_out": 0, "feature": "F-006",
    }))
    snap = ds.snapshot()
    assert snap.header.top_feature_label == "F-006"
    assert snap.header.top_feature_tokens == 1_000


def test_r101_session_window_pruning_bounded():
    """Distinct session count above 2× window prunes oldest by last-seen."""
    tick = {"v": 0.0}
    ds = DashboardState(clock=lambda: tick["v"])
    ds._session_window = 3  # smaller window for the test
    # Push 7 distinct sessions with monotonically increasing seen-time
    for i in range(7):
        tick["v"] = float(i)
        ds.apply_record(StreamRecord(stream="token-ledger", line_no=0, record={
            "ts": "x", "session_id": f"sess-{i}", "model": "haiku", "tier": "tier1",
            "tokens_in": 100, "tokens_out": 0,
        }))
    # After crossing 2× window (6), pruning fires; memory bounded.
    assert len(ds._session_totals) <= ds._session_window * 2
    # The most recent sessions (sess-4..sess-6) must still be present.
    for sid in ("sess-4", "sess-5", "sess-6"):
        assert sid in ds._session_totals


def test_quota_modal_rising_edge_triggers_once_per_episode():
    """R-014 AC4 — modal fires on rising edge to 95% and not until the
    alert level drops and re-rises. Ack suppresses re-show within the
    same episode."""
    from tui.panels.quota_alert import should_show_modal

    # Rising edge from no-alert → 95% triggers
    assert should_show_modal(prev_alert=None, cur_alert="95%",
                              acknowledged=False) is True
    # Rising edge from 85% → 95% triggers
    assert should_show_modal(prev_alert="85%", cur_alert="95%",
                              acknowledged=False) is True
    # Already at 95% on previous tick — no re-trigger
    assert should_show_modal(prev_alert="95%", cur_alert="95%",
                              acknowledged=False) is False
    # Acknowledged — suppressed even on transition
    assert should_show_modal(prev_alert="85%", cur_alert="95%",
                              acknowledged=True) is False
    # Below threshold — never shown
    assert should_show_modal(prev_alert="85%", cur_alert="85%",
                              acknowledged=False) is False
    assert should_show_modal(prev_alert=None, cur_alert=None,
                              acknowledged=False) is False


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
