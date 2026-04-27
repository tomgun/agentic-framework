#!/usr/bin/env python3
"""
Tests for `.agentic/lib/quota.py` (R-013 · ag intel report --quota).

Run via pytest, or directly: `python3 tests/test_quota.py`.
"""
from __future__ import annotations

import json
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

_LIB_DIR = Path(__file__).resolve().parent.parent / ".agentic" / "lib"
sys.path.insert(0, str(_LIB_DIR))

import quota  # noqa: E402


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


_NOW = datetime(2026, 4, 27, 12, 0, 0, tzinfo=timezone.utc)


def _ts(offset_seconds: int) -> str:
    """Return ISO8601 Z timestamp `offset_seconds` before _NOW."""
    return (_NOW - timedelta(seconds=offset_seconds)).strftime(
        "%Y-%m-%dT%H:%M:%S.000Z"
    )


def _write_ledger(path: Path, entries: list[dict]) -> None:
    with open(path, "w", encoding="utf-8") as fh:
        for e in entries:
            fh.write(json.dumps(e) + "\n")


# ---------------------------------------------------------------------------
# compute_quota — core
# ---------------------------------------------------------------------------


def test_empty_ledger_yields_zero(tmp_path: Path):
    p = tmp_path / "token-ledger.jsonl"
    p.write_text("", encoding="utf-8")
    rep = quota.compute_quota(
        token_ledger_path=p, ceiling_tokens=1_500_000, now=_NOW
    )
    assert rep.tokens_total == 0
    assert rep.record_count == 0
    assert rep.quota_pct == 0.0


def test_missing_file_treated_as_empty(tmp_path: Path):
    p = tmp_path / "missing.jsonl"
    rep = quota.compute_quota(
        token_ledger_path=p, ceiling_tokens=1_500_000, now=_NOW
    )
    assert rep.tokens_total == 0
    assert rep.record_count == 0


def test_in_window_record_counted(tmp_path: Path):
    p = tmp_path / "tl.jsonl"
    _write_ledger(
        p,
        [
            {
                "ts": _ts(60),  # 1 min ago, well inside 5h window
                "session_id": "s1",
                "model": "sonnet-4-6",
                "tier": "tier2",
                "tokens_in": 1000,
                "tokens_out": 500,
            }
        ],
    )
    rep = quota.compute_quota(
        token_ledger_path=p, ceiling_tokens=1_500_000, now=_NOW
    )
    assert rep.tokens_total == 1500
    assert rep.tokens_in == 1000
    assert rep.tokens_out == 500
    assert rep.by_tier == {"tier2": 1500}
    assert rep.by_model == {"sonnet-4-6": 1500}
    assert rep.record_count == 1


def test_out_of_window_record_excluded(tmp_path: Path):
    p = tmp_path / "tl.jsonl"
    _write_ledger(
        p,
        [
            {
                "ts": _ts(6 * 3600),  # 6h ago — outside 5h window
                "session_id": "s1",
                "model": "sonnet",
                "tier": "tier2",
                "tokens_in": 100,
                "tokens_out": 100,
            },
            {
                "ts": _ts(60),
                "session_id": "s1",
                "model": "sonnet",
                "tier": "tier2",
                "tokens_in": 200,
                "tokens_out": 200,
            },
        ],
    )
    rep = quota.compute_quota(
        token_ledger_path=p, ceiling_tokens=1_500_000, now=_NOW
    )
    assert rep.tokens_total == 400
    assert rep.record_count == 1


def test_breakdown_by_tier_and_model(tmp_path: Path):
    p = tmp_path / "tl.jsonl"
    _write_ledger(
        p,
        [
            {
                "ts": _ts(60),
                "session_id": "s",
                "model": "sonnet-4-6",
                "tier": "tier2",
                "tokens_in": 100,
                "tokens_out": 100,
            },
            {
                "ts": _ts(120),
                "session_id": "s",
                "model": "haiku-4-5",
                "tier": "tier3",
                "tokens_in": 50,
                "tokens_out": 50,
            },
            {
                "ts": _ts(180),
                "session_id": "s",
                "model": "sonnet-4-6",
                "tier": "tier1",
                "tokens_in": 75,
                "tokens_out": 25,
            },
        ],
    )
    rep = quota.compute_quota(
        token_ledger_path=p, ceiling_tokens=1_000_000, now=_NOW
    )
    assert rep.by_tier == {"tier1": 100, "tier2": 200, "tier3": 100}
    assert rep.by_model == {"sonnet-4-6": 300, "haiku-4-5": 100}


def test_cache_reads_excluded_from_total(tmp_path: Path):
    p = tmp_path / "tl.jsonl"
    _write_ledger(
        p,
        [
            {
                "ts": _ts(60),
                "session_id": "s",
                "model": "sonnet",
                "tier": "tier2",
                "tokens_in": 100,
                "tokens_out": 100,
                "cache_read_tokens": 10_000,
            }
        ],
    )
    rep = quota.compute_quota(
        token_ledger_path=p, ceiling_tokens=1_500_000, now=_NOW
    )
    assert rep.tokens_total == 200
    assert rep.cache_read_tokens == 10_000


def test_malformed_lines_skipped(tmp_path: Path):
    p = tmp_path / "tl.jsonl"
    p.write_text(
        "not-json\n"
        + json.dumps(
            {
                "ts": _ts(60),
                "session_id": "s",
                "model": "sonnet",
                "tier": "tier2",
                "tokens_in": 50,
                "tokens_out": 50,
            }
        )
        + "\n"
        + "{broken\n",
        encoding="utf-8",
    )
    rep = quota.compute_quota(
        token_ledger_path=p, ceiling_tokens=1_500_000, now=_NOW
    )
    assert rep.tokens_total == 100
    assert rep.record_count == 1


# ---------------------------------------------------------------------------
# Alert thresholds (AC-3)
# ---------------------------------------------------------------------------


def _ledger_with_total(p: Path, total: int) -> None:
    _write_ledger(
        p,
        [
            {
                "ts": _ts(60),
                "session_id": "s",
                "model": "sonnet",
                "tier": "tier2",
                "tokens_in": total // 2,
                "tokens_out": total - total // 2,
            }
        ],
    )


def test_alert_none_below_70(tmp_path: Path):
    p = tmp_path / "tl.jsonl"
    _ledger_with_total(p, 600_000)  # 60% of 1M
    rep = quota.compute_quota(
        token_ledger_path=p, ceiling_tokens=1_000_000, now=_NOW
    )
    assert rep.alert_level is None


def test_alert_70_at_70pct(tmp_path: Path):
    p = tmp_path / "tl.jsonl"
    _ledger_with_total(p, 700_000)
    rep = quota.compute_quota(
        token_ledger_path=p, ceiling_tokens=1_000_000, now=_NOW
    )
    assert rep.alert_level == "70%"


def test_alert_85_at_85pct(tmp_path: Path):
    p = tmp_path / "tl.jsonl"
    _ledger_with_total(p, 850_000)
    rep = quota.compute_quota(
        token_ledger_path=p, ceiling_tokens=1_000_000, now=_NOW
    )
    assert rep.alert_level == "85%"


def test_alert_95_at_95pct(tmp_path: Path):
    p = tmp_path / "tl.jsonl"
    _ledger_with_total(p, 950_000)
    rep = quota.compute_quota(
        token_ledger_path=p, ceiling_tokens=1_000_000, now=_NOW
    )
    assert rep.alert_level == "95%"


def test_alert_pause_advice_at_85(tmp_path: Path):
    p = tmp_path / "tl.jsonl"
    _ledger_with_total(p, 850_000)
    rep = quota.compute_quota(
        token_ledger_path=p, ceiling_tokens=1_000_000, now=_NOW
    )
    advice_text = " ".join(rep.advice).lower()
    assert "tier 3" in advice_text or "--teams" in advice_text


def test_no_advice_when_below_threshold(tmp_path: Path):
    p = tmp_path / "tl.jsonl"
    _ledger_with_total(p, 100_000)
    rep = quota.compute_quota(
        token_ledger_path=p, ceiling_tokens=1_000_000, now=_NOW
    )
    assert rep.advice == []


# ---------------------------------------------------------------------------
# Projection
# ---------------------------------------------------------------------------


def test_projection_extrapolates_linearly(tmp_path: Path):
    """600k tokens with an earliest record 2h ago → rate uses 2h, not 5h."""
    p = tmp_path / "tl.jsonl"
    # Two records: one 2h ago (sets the earliest_record_ts), one 60s ago.
    _write_ledger(
        p,
        [
            {
                "ts": _ts(2 * 3600),
                "session_id": "s",
                "model": "sonnet",
                "tier": "tier2",
                "tokens_in": 200_000,
                "tokens_out": 100_000,
            },
            {
                "ts": _ts(60),
                "session_id": "s",
                "model": "sonnet",
                "tier": "tier2",
                "tokens_in": 200_000,
                "tokens_out": 100_000,
            },
        ],
    )
    rep = quota.compute_quota(
        token_ledger_path=p, ceiling_tokens=1_000_000, now=_NOW
    )
    assert rep.projected_exhaustion is not None
    delta = (rep.projected_exhaustion - _NOW).total_seconds()
    # 600k tokens over ~2h → 83.3 tok/s. Remaining 400k / 83.3 ≈ 4800s = 80m.
    # Verify it's in the right order of magnitude (1–3 hours).
    assert 60 * 60 < delta < 4 * 3600


def test_projection_active_span_shorter_than_window(tmp_path: Path):
    """600k burned in the last 2 minutes should project FAR sooner than
    the same 600k spread evenly over a 2h active span."""
    p = tmp_path / "tl_bursty.jsonl"
    # All 600k in the last 2 minutes (one record sets active_span=floor of 60s)
    _write_ledger(
        p,
        [
            {
                "ts": _ts(120),
                "session_id": "s",
                "model": "sonnet",
                "tier": "tier2",
                "tokens_in": 300_000,
                "tokens_out": 300_000,
            },
        ],
    )
    rep_bursty = quota.compute_quota(
        token_ledger_path=p, ceiling_tokens=1_000_000, now=_NOW
    )
    bursty_delta = (rep_bursty.projected_exhaustion - _NOW).total_seconds()

    # Steady scenario: same 600k but with an early record at 2h ago
    p2 = tmp_path / "tl_steady.jsonl"
    _write_ledger(
        p2,
        [
            {
                "ts": _ts(2 * 3600),
                "session_id": "s",
                "model": "sonnet",
                "tier": "tier2",
                "tokens_in": 100,
                "tokens_out": 100,
            },
            {
                "ts": _ts(120),
                "session_id": "s",
                "model": "sonnet",
                "tier": "tier2",
                "tokens_in": 300_000,
                "tokens_out": 299_800,
            },
        ],
    )
    rep_steady = quota.compute_quota(
        token_ledger_path=p2, ceiling_tokens=1_000_000, now=_NOW
    )
    steady_delta = (rep_steady.projected_exhaustion - _NOW).total_seconds()

    # Bursty projection must be visibly shorter than the steady one
    assert bursty_delta < steady_delta
    # Bursty must be conservative — under an hour
    assert bursty_delta < 3600


def test_projection_floors_at_one_minute(tmp_path: Path):
    """A single record 5s ago shouldn't yield 'exhausted in seconds' nonsense."""
    p = tmp_path / "tl.jsonl"
    _write_ledger(
        p,
        [
            {
                "ts": _ts(5),  # would yield active_span = 5s without the floor
                "session_id": "s",
                "model": "sonnet",
                "tier": "tier2",
                "tokens_in": 100,
                "tokens_out": 100,
            },
        ],
    )
    rep = quota.compute_quota(
        token_ledger_path=p, ceiling_tokens=1_000_000, now=_NOW
    )
    delta = (rep.projected_exhaustion - _NOW).total_seconds()
    # 200 tokens / 60s floor = 3.3 tok/s; remaining ≈ 999800 / 3.3 ≈ 83h.
    # Floor must protect us from a tiny-N projection.
    assert delta > 60 * 60


def test_no_projection_without_ceiling(tmp_path: Path):
    p = tmp_path / "tl.jsonl"
    _ledger_with_total(p, 100_000)
    rep = quota.compute_quota(
        token_ledger_path=p, ceiling_tokens=None, now=_NOW
    )
    assert rep.projected_exhaustion is None
    assert rep.quota_pct is None
    assert rep.alert_level is None


def test_no_projection_when_zero_tokens(tmp_path: Path):
    p = tmp_path / "tl.jsonl"
    p.write_text("", encoding="utf-8")
    rep = quota.compute_quota(
        token_ledger_path=p, ceiling_tokens=1_000_000, now=_NOW
    )
    assert rep.projected_exhaustion is None


# ---------------------------------------------------------------------------
# Rendering
# ---------------------------------------------------------------------------


def test_render_human_readable_includes_key_fields(tmp_path: Path):
    p = tmp_path / "tl.jsonl"
    _write_ledger(
        p,
        [
            {
                "ts": _ts(60),
                "session_id": "s",
                "model": "sonnet-4-6",
                "tier": "tier2",
                "tokens_in": 50_000,
                "tokens_out": 50_000,
            }
        ],
    )
    rep = quota.compute_quota(
        token_ledger_path=p, ceiling_tokens=1_000_000, now=_NOW
    )
    text = quota.render_report(rep, color=False)
    assert "100,000" in text
    assert "1,000,000" in text
    assert "10.0%" in text
    assert "tier2" in text
    assert "sonnet-4-6" in text


def test_render_no_ceiling_shows_raw_total(tmp_path: Path):
    p = tmp_path / "tl.jsonl"
    _write_ledger(
        p,
        [
            {
                "ts": _ts(60),
                "session_id": "s",
                "model": "sonnet",
                "tier": "tier2",
                "tokens_in": 1000,
                "tokens_out": 1000,
            }
        ],
    )
    rep = quota.compute_quota(token_ledger_path=p, ceiling_tokens=None, now=_NOW)
    text = quota.render_report(rep, color=False)
    assert "2,000" in text
    assert "no ceiling configured" in text


def test_render_json_emits_valid_json(tmp_path: Path):
    p = tmp_path / "tl.jsonl"
    _write_ledger(
        p,
        [
            {
                "ts": _ts(60),
                "session_id": "s",
                "model": "sonnet",
                "tier": "tier2",
                "tokens_in": 100,
                "tokens_out": 100,
            }
        ],
    )
    rep = quota.compute_quota(
        token_ledger_path=p, ceiling_tokens=1_000_000, now=_NOW
    )
    blob = quota.render_report(rep, color=False, json_output=True)
    parsed = json.loads(blob)
    assert parsed["tokens_total"] == 200
    assert parsed["ceiling_tokens"] == 1_000_000
    assert parsed["by_tier"] == {"tier2": 200}


def test_alert_renders_in_color(tmp_path: Path):
    p = tmp_path / "tl.jsonl"
    _ledger_with_total(p, 950_000)
    rep = quota.compute_quota(
        token_ledger_path=p, ceiling_tokens=1_000_000, now=_NOW
    )
    text = quota.render_report(rep, color=True)
    assert "ALERT 95%" in text
    assert "\033[" in text  # ANSI escape


# ---------------------------------------------------------------------------
# CLI entry
# ---------------------------------------------------------------------------


def test_main_runs_on_empty_ledger(tmp_path: Path, capsys):
    p = tmp_path / "token-ledger.jsonl"
    p.write_text("", encoding="utf-8")
    rc = quota.main([
        "--token-ledger", str(p),
        "--no-color",
    ])
    assert rc == 0
    out = capsys.readouterr().out
    assert "Quota Report" in out


def test_main_json_flag(tmp_path: Path, capsys):
    """CLI uses wall-clock now; use a timestamp relative to actual now."""
    p = tmp_path / "token-ledger.jsonl"
    real_now = datetime.now(timezone.utc)
    ts_recent = (real_now - timedelta(seconds=60)).strftime(
        "%Y-%m-%dT%H:%M:%S.000Z"
    )
    _write_ledger(
        p,
        [
            {
                "ts": ts_recent,
                "session_id": "s",
                "model": "sonnet",
                "tier": "tier2",
                "tokens_in": 100,
                "tokens_out": 100,
            }
        ],
    )
    rc = quota.main([
        "--token-ledger", str(p),
        "--ceiling-tokens", "1000000",
        "--no-color",
        "--json",
    ])
    assert rc == 0
    blob = capsys.readouterr().out
    parsed = json.loads(blob)
    assert parsed["tokens_total"] == 200


# ---------------------------------------------------------------------------
# Standalone
# ---------------------------------------------------------------------------


if __name__ == "__main__":
    import tempfile
    import traceback

    funcs = [
        (name, fn)
        for name, fn in globals().items()
        if name.startswith("test_") and callable(fn)
    ]
    passed = failed = 0

    class _CapsysShim:
        def __init__(self):
            self._buf = []

        def readouterr(self):
            from io import StringIO
            buf = StringIO()
            buf.write("".join(self._buf))
            self._buf.clear()

            class Out:
                pass
            o = Out()
            o.out = buf.getvalue()
            o.err = ""
            return o

    import contextlib
    import io

    class _Capsys:
        def __init__(self, buf):
            self._buf = buf

        def readouterr(self):
            class Out:
                pass
            o = Out()
            o.out = self._buf.getvalue()
            o.err = ""
            self._buf.truncate(0)
            self._buf.seek(0)
            return o

    real_stdout = sys.stdout
    for name, fn in funcs:
        sig_params = fn.__code__.co_varnames[: fn.__code__.co_argcount]
        try:
            kwargs = {}
            with tempfile.TemporaryDirectory() as tmp:
                if "tmp_path" in sig_params:
                    kwargs["tmp_path"] = Path(tmp)
                if "capsys" in sig_params:
                    buf = io.StringIO()
                    with contextlib.redirect_stdout(buf):
                        kwargs["capsys"] = _Capsys(buf)
                        fn(**kwargs)
                else:
                    fn(**kwargs)
            passed += 1
            print(f"ok    {name}", file=real_stdout)
        except Exception:
            failed += 1
            print(f"FAIL  {name}", file=real_stdout)
            traceback.print_exc(file=real_stdout)
    print(f"\n{passed} passed, {failed} failed", file=real_stdout)
    sys.exit(1 if failed else 0)
