#!/usr/bin/env python3
"""
Tests for `.agentic/lib/watch.py` (R-009 · ag watch).

Run via pytest, or directly with `python3 tests/test_watch.py`.
"""
from __future__ import annotations

import io
import json
import os
import sys
import threading
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path

_LIB_DIR = Path(__file__).resolve().parent.parent / ".agentic" / "lib"
sys.path.insert(0, str(_LIB_DIR))

import watch  # noqa: E402


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _write_event(path: Path, **fields) -> dict:
    rec = {
        "ts": fields.pop("ts", "2026-04-27T10:00:00.000Z"),
        "session_id": fields.pop("session_id", "sess-1"),
        "type": fields.pop("type", "commit"),
        "feature": fields.pop("feature", "F-008"),
        "actor": fields.pop("actor", "harness"),
        "payload": fields.pop("payload", {}),
    }
    rec.update(fields)
    with open(path, "a", encoding="utf-8") as fh:
        fh.write(json.dumps(rec) + "\n")
    return rec


# ---------------------------------------------------------------------------
# parse_filter
# ---------------------------------------------------------------------------


def test_parse_filter_basic():
    assert watch.parse_filter("type=commit") == ("type", "commit")
    assert watch.parse_filter("feature=F-008") == ("feature", "F-008")


def test_parse_filter_value_with_equals():
    # First `=` splits; remainder is value
    assert watch.parse_filter("payload=k=v") == ("payload", "k=v")


def test_parse_filter_rejects_no_equals():
    try:
        watch.parse_filter("typecommit")
    except ValueError:
        return
    raise AssertionError("expected ValueError for missing =")


def test_parse_filter_rejects_empty_key_or_value():
    for bad in ("=value", "key=", "="):
        try:
            watch.parse_filter(bad)
        except ValueError:
            continue
        raise AssertionError(f"expected ValueError for {bad!r}")


# ---------------------------------------------------------------------------
# matches_filters
# ---------------------------------------------------------------------------


def test_matches_filters_empty_passes():
    assert watch.matches_filters({"type": "commit"}, []) is True


def test_matches_filters_single_match():
    rec = {"type": "commit", "feature": "F-008"}
    assert watch.matches_filters(rec, [("type", "commit")]) is True
    assert watch.matches_filters(rec, [("type", "test_run")]) is False


def test_matches_filters_anded():
    rec = {"type": "commit", "feature": "F-008"}
    assert watch.matches_filters(
        rec, [("type", "commit"), ("feature", "F-008")]
    ) is True
    # One mismatch fails the whole filter
    assert watch.matches_filters(
        rec, [("type", "commit"), ("feature", "F-009")]
    ) is False


def test_matches_filters_missing_field():
    assert watch.matches_filters({}, [("type", "commit")]) is False


# ---------------------------------------------------------------------------
# parse_since
# ---------------------------------------------------------------------------


def test_parse_since_relative_minutes():
    now = datetime(2026, 4, 27, 10, 0, 0, tzinfo=timezone.utc)
    assert watch.parse_since("30m", now=now) == now - timedelta(minutes=30)


def test_parse_since_relative_hours():
    now = datetime(2026, 4, 27, 10, 0, 0, tzinfo=timezone.utc)
    assert watch.parse_since("2h", now=now) == now - timedelta(hours=2)


def test_parse_since_relative_days():
    now = datetime(2026, 4, 27, 10, 0, 0, tzinfo=timezone.utc)
    assert watch.parse_since("7d", now=now) == now - timedelta(days=7)


def test_parse_since_iso_z():
    dt = watch.parse_since("2026-04-26T14:00:00Z")
    assert dt == datetime(2026, 4, 26, 14, 0, 0, tzinfo=timezone.utc)


def test_parse_since_loose_datetime():
    dt = watch.parse_since("2026-04-26 14:00")
    assert dt == datetime(2026, 4, 26, 14, 0, 0, tzinfo=timezone.utc)


def test_parse_since_loose_date_only():
    dt = watch.parse_since("2026-04-26")
    assert dt == datetime(2026, 4, 26, 0, 0, 0, tzinfo=timezone.utc)


def test_parse_since_invalid_raises():
    for bad in ("", "not-a-time", "5x", "tomorrow"):
        try:
            watch.parse_since(bad)
        except ValueError:
            continue
        raise AssertionError(f"expected ValueError for {bad!r}")


# ---------------------------------------------------------------------------
# Color taxonomy (R-009 AC-2)
# ---------------------------------------------------------------------------


def test_color_for_known_red_types():
    assert watch._color_for("gate_blocked") == watch._RED
    assert watch._color_for("human_needed") == watch._RED


def test_color_for_known_yellow_types():
    assert watch._color_for("gate_skipped") == watch._YELLOW
    assert watch._color_for("hotfix_commit") == watch._YELLOW


def test_color_for_known_green_types():
    assert watch._color_for("commit") == watch._GREEN
    assert watch._color_for("test_run") == watch._GREEN
    assert watch._color_for("session_start") == watch._GREEN


def test_color_for_unknown_falls_back_to_blue():
    assert watch._color_for("totally_made_up") == watch._BLUE


# ---------------------------------------------------------------------------
# format_record
# ---------------------------------------------------------------------------


def test_format_record_no_color_is_plain():
    rec = {
        "ts": "2026-04-27T10:00:00.000Z",
        "type": "commit",
        "feature": "F-008",
        "actor": "harness",
        "payload": {"sha": "deadbeef"},
    }
    line = watch.format_record(rec, color=False)
    assert "\033[" not in line  # no ANSI codes
    assert "commit" in line
    assert "F-008" in line
    assert "harness" in line
    assert "sha=deadbeef" in line


def test_format_record_color_includes_ansi():
    rec = {
        "ts": "2026-04-27T10:00:00.000Z",
        "type": "gate_blocked",
        "feature": "F-008",
        "actor": "precommit",
        "payload": {},
    }
    line = watch.format_record(rec, color=True)
    assert watch._RED in line
    assert watch._RESET in line


def test_format_record_handles_empty_payload():
    rec = {
        "ts": "2026-04-27T10:00:00.000Z",
        "type": "commit",
        "feature": None,
        "actor": "harness",
        "payload": {},
    }
    line = watch.format_record(rec, color=False)
    assert "commit" in line


def test_format_record_truncates_large_payload():
    rec = {
        "ts": "2026-04-27T10:00:00.000Z",
        "type": "commit",
        "feature": "F-008",
        "actor": "harness",
        "payload": {f"k{i}": i for i in range(20)},
    }
    line = watch.format_record(rec, color=False)
    # First 4 keys + a `(+N)` overflow marker
    assert "(+16)" in line


# ---------------------------------------------------------------------------
# watch() once-mode (script-friendly)
# ---------------------------------------------------------------------------


def test_watch_once_emits_existing_records(tmp_path: Path):
    p = tmp_path / "events.jsonl"
    _write_event(p, type="commit", feature="F-008")
    _write_event(p, type="test_run", feature="F-009")
    out = io.StringIO()
    n = watch.watch(p, color=False, once=True, from_start=True, out=out)
    assert n == 2
    body = out.getvalue()
    assert "commit" in body
    assert "test_run" in body


def test_watch_once_filter_by_type(tmp_path: Path):
    p = tmp_path / "events.jsonl"
    _write_event(p, type="commit", feature="F-008")
    _write_event(p, type="test_run", feature="F-008")
    _write_event(p, type="commit", feature="F-009")
    out = io.StringIO()
    n = watch.watch(
        p,
        color=False,
        once=True,
        from_start=True,
        filters=[("type", "commit")],
        out=out,
    )
    assert n == 2
    assert "test_run" not in out.getvalue()


def test_watch_once_filter_by_feature(tmp_path: Path):
    p = tmp_path / "events.jsonl"
    _write_event(p, type="commit", feature="F-008")
    _write_event(p, type="commit", feature="F-009")
    out = io.StringIO()
    n = watch.watch(
        p,
        color=False,
        once=True,
        from_start=True,
        filters=[("feature", "F-008")],
        out=out,
    )
    assert n == 1


def test_watch_once_since_filter(tmp_path: Path):
    p = tmp_path / "events.jsonl"
    _write_event(p, type="commit", ts="2026-04-26T10:00:00.000Z")
    _write_event(p, type="commit", ts="2026-04-27T10:00:00.000Z")
    out = io.StringIO()
    threshold = datetime(2026, 4, 27, 0, 0, 0, tzinfo=timezone.utc)
    n = watch.watch(
        p,
        color=False,
        once=True,
        from_start=True,
        since=threshold,
        out=out,
    )
    assert n == 1
    assert "2026-04-27" in out.getvalue()


def test_watch_once_skips_malformed_lines(tmp_path: Path):
    p = tmp_path / "events.jsonl"
    p.write_text(
        "not-json\n"
        + json.dumps({"ts": "2026-04-27T10:00:00.000Z", "type": "commit",
                      "feature": "F-008", "actor": "harness", "payload": {}}) + "\n"
        + "{ also broken\n",
        encoding="utf-8",
    )
    out = io.StringIO()
    n = watch.watch(p, color=False, once=True, from_start=True, out=out)
    assert n == 1


def test_watch_once_from_end_skips_existing(tmp_path: Path):
    p = tmp_path / "events.jsonl"
    _write_event(p, type="commit", feature="F-008")
    out = io.StringIO()
    n = watch.watch(p, color=False, once=True, from_start=False, out=out)
    assert n == 0


def test_watch_handles_missing_file_in_once_mode(tmp_path: Path):
    p = tmp_path / "missing.jsonl"
    out = io.StringIO()
    n = watch.watch(p, color=False, once=True, from_start=True, out=out)
    assert n == 0
    assert out.getvalue() == ""


# ---------------------------------------------------------------------------
# Live tail (background thread + file appends)
# ---------------------------------------------------------------------------


def test_watch_tails_appended_lines(tmp_path: Path):
    p = tmp_path / "events.jsonl"
    p.write_text("", encoding="utf-8")
    out = io.StringIO()
    stop_at = 2
    seen = {"count": 0}

    # Patch watch to stop once we've seen `stop_at` records via wrapped print.
    # Easier: run with a short timeout in a thread and then close the file.
    def runner():
        watch.watch(
            p,
            color=False,
            poll_interval=0.05,
            from_start=True,
            once=False,
            out=out,
        )

    t = threading.Thread(target=runner, daemon=True)
    t.start()

    time.sleep(0.1)
    _write_event(p, type="session_start", feature="F-008")
    time.sleep(0.2)
    _write_event(p, type="commit", feature="F-008")
    time.sleep(0.3)

    # Daemon thread can't be joined cleanly without an interrupt; for the test we
    # just inspect what's been emitted so far.
    body = out.getvalue()
    assert "session_start" in body
    assert "commit" in body
    seen["count"] += 1


# ---------------------------------------------------------------------------
# CLI argparse
# ---------------------------------------------------------------------------


def test_main_unknown_filter_returns_2(tmp_path: Path):
    rc = watch.main([
        "--path", str(tmp_path / "events.jsonl"),
        "--filter", "no-equals",
        "--once",
    ])
    assert rc == 2


def test_main_invalid_since_returns_2(tmp_path: Path):
    rc = watch.main([
        "--path", str(tmp_path / "events.jsonl"),
        "--since", "tomorrow",
        "--once",
    ])
    assert rc == 2


def test_main_runs_once_on_empty_file(tmp_path: Path):
    p = tmp_path / "events.jsonl"
    p.write_text("", encoding="utf-8")
    rc = watch.main([
        "--path", str(p),
        "--once",
        "--no-color",
    ])
    assert rc == 0


# ---------------------------------------------------------------------------
# Standalone runner
# ---------------------------------------------------------------------------


if __name__ == "__main__":
    import traceback

    funcs = [
        (name, fn)
        for name, fn in globals().items()
        if name.startswith("test_") and callable(fn)
    ]
    passed = failed = 0
    import tempfile
    for name, fn in funcs:
        sig_params = fn.__code__.co_varnames[: fn.__code__.co_argcount]
        try:
            if "tmp_path" in sig_params:
                with tempfile.TemporaryDirectory() as tmp:
                    fn(Path(tmp))
            else:
                fn()
            passed += 1
        except Exception:
            failed += 1
            print(f"FAIL  {name}")
            traceback.print_exc()
        else:
            print(f"ok    {name}")
    print(f"\n{passed} passed, {failed} failed")
    sys.exit(1 if failed else 0)
