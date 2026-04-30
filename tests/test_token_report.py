"""Tests for `quota.build_token_report` (R-101 read-side projection).

Runs under pytest or directly: `python3 tests/test_token_report.py`.
"""
from __future__ import annotations

import contextlib
import json
import shutil
import sys
import tempfile
from datetime import datetime, timedelta, timezone
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT / ".agentic" / "lib"))

import quota  # noqa: E402  (import after sys.path mutation)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


@contextlib.contextmanager
def _tmpdir():
    d = tempfile.mkdtemp(prefix="token-report-")
    try:
        yield Path(d)
    finally:
        shutil.rmtree(d, ignore_errors=True)


def _record(
    *,
    ts: datetime,
    session_id: str,
    model: str = "claude-opus-4-7",
    tier: str = "tier1",
    tokens_in: int = 1000,
    tokens_out: int = 200,
    cache_read: int = 5000,
    feature=None,
) -> dict:
    rec = {
        "ts": ts.isoformat().replace("+00:00", "Z"),
        "session_id": session_id,
        "model": model,
        "tier": tier,
        "tokens_in": tokens_in,
        "tokens_out": tokens_out,
        "cache_read_tokens": cache_read,
        "actor": "assistant",
    }
    if feature is _UNSET:
        rec["feature"] = "F-006"
    elif feature is not None:
        rec["feature"] = feature
    return rec


_UNSET = object()


def _record_with_default_feature(**kwargs) -> dict:
    """Helper that defaults feature='F-006' unless caller passes feature=None."""
    if "feature" not in kwargs:
        kwargs["feature"] = "F-006"
    return _record(**kwargs)


def _write_ledger(path: Path, records: list[dict]) -> None:
    path.write_text(
        "\n".join(json.dumps(r, separators=(",", ":")) for r in records) + "\n",
        encoding="utf-8",
    )


# ---------------------------------------------------------------------------
# build_token_report — basic shapes
# ---------------------------------------------------------------------------


def test_empty_ledger_returns_empty_report() -> None:
    with _tmpdir() as tmp:
        ledger = tmp / "token-ledger.jsonl"
        report = quota.build_token_report(token_ledger_path=ledger)

        assert report.current_session is None
        assert report.rolling_window == []
        assert report.by_tier == {}
        assert report.by_model == {}
        assert report.by_feature == {}
        assert report.record_count == 0


def test_single_session_populates_current_and_rolling() -> None:
    with _tmpdir() as tmp:
        ledger = tmp / "token-ledger.jsonl"
        base = datetime(2026, 4, 28, 10, 0, tzinfo=timezone.utc)
        _write_ledger(
            ledger,
            [
                _record_with_default_feature(ts=base, session_id="sess-1", tokens_in=1000, tokens_out=200),
                _record_with_default_feature(
                    ts=base + timedelta(minutes=10),
                    session_id="sess-1",
                    tokens_in=2000,
                    tokens_out=400,
                ),
            ],
        )

        report = quota.build_token_report(token_ledger_path=ledger)
        assert report.current_session is not None
        assert report.current_session.session_id == "sess-1"
        assert report.current_session.tokens_in == 3000
        assert report.current_session.tokens_out == 600
        assert report.current_session.record_count == 2
        assert len(report.rolling_window) == 1
        assert report.record_count == 2


def test_current_session_picks_most_recent_by_last_seen() -> None:
    with _tmpdir() as tmp:
        ledger = tmp / "token-ledger.jsonl"
        base = datetime(2026, 4, 28, 10, 0, tzinfo=timezone.utc)
        _write_ledger(
            ledger,
            [
                _record_with_default_feature(ts=base, session_id="sess-old"),
                _record_with_default_feature(ts=base + timedelta(minutes=30), session_id="sess-old"),
                _record_with_default_feature(ts=base + timedelta(minutes=45), session_id="sess-new"),
                _record_with_default_feature(ts=base + timedelta(minutes=60), session_id="sess-new"),
            ],
        )
        report = quota.build_token_report(token_ledger_path=ledger)
        assert report.current_session is not None
        assert report.current_session.session_id == "sess-new"
        assert report.rolling_window[0].session_id == "sess-new"
        assert report.rolling_window[1].session_id == "sess-old"


def test_explicit_session_id_overrides_recency() -> None:
    with _tmpdir() as tmp:
        ledger = tmp / "token-ledger.jsonl"
        base = datetime(2026, 4, 28, 10, 0, tzinfo=timezone.utc)
        _write_ledger(
            ledger,
            [
                _record_with_default_feature(ts=base, session_id="sess-old"),
                _record_with_default_feature(ts=base + timedelta(minutes=30), session_id="sess-new"),
            ],
        )
        report = quota.build_token_report(
            token_ledger_path=ledger, session_id="sess-old"
        )
        assert report.current_session is not None
        assert report.current_session.session_id == "sess-old"


# ---------------------------------------------------------------------------
# Rolling-window cap + breakdowns
# ---------------------------------------------------------------------------


def test_rolling_window_caps_to_n_sessions() -> None:
    """35 sessions × 4 records each → window=30 keeps the 30 most-recent."""
    with _tmpdir() as tmp:
        ledger = tmp / "token-ledger.jsonl"
        base = datetime(2026, 4, 1, 0, 0, tzinfo=timezone.utc)
        records = []
        for s in range(35):
            for r in range(4):
                records.append(
                    _record_with_default_feature(
                        ts=base + timedelta(hours=s, minutes=r * 5),
                        session_id=f"sess-{s:02d}",
                        tokens_in=100 * (s + 1),
                        tokens_out=20,
                        feature=f"F-{s:03d}",
                    )
                )
        _write_ledger(ledger, records)

        report = quota.build_token_report(token_ledger_path=ledger, window_sessions=30)
        assert len(report.rolling_window) == 30
        assert report.record_count == 140
        assert report.rolling_window[0].session_id == "sess-34"
        assert report.rolling_window[-1].session_id == "sess-05"
        assert "F-000" not in report.by_feature
        assert "F-005" in report.by_feature


def test_breakdowns_aggregate_across_rolling_window() -> None:
    with _tmpdir() as tmp:
        ledger = tmp / "token-ledger.jsonl"
        base = datetime(2026, 4, 28, 10, 0, tzinfo=timezone.utc)
        _write_ledger(
            ledger,
            [
                _record_with_default_feature(
                    ts=base,
                    session_id="sess-1",
                    model="claude-opus-4-7",
                    tier="tier1",
                    tokens_in=1000,
                    tokens_out=200,
                    feature="F-006",
                ),
                _record_with_default_feature(
                    ts=base + timedelta(minutes=10),
                    session_id="sess-1",
                    model="claude-haiku-4-5",
                    tier="tier1",
                    tokens_in=500,
                    tokens_out=100,
                    feature="F-006",
                ),
                _record_with_default_feature(
                    ts=base + timedelta(minutes=30),
                    session_id="sess-2",
                    model="claude-opus-4-7",
                    tier="tier2",
                    tokens_in=300,
                    tokens_out=70,
                    feature="F-008",
                ),
            ],
        )

        report = quota.build_token_report(token_ledger_path=ledger)

        assert report.by_tier == {"tier1": 1800, "tier2": 370}
        assert report.by_model == {"claude-opus-4-7": 1570, "claude-haiku-4-5": 600}
        assert report.by_feature == {"F-006": 1800, "F-008": 370}


def test_untagged_feature_label() -> None:
    """Records with no `feature` field land in the (untagged) bucket."""
    with _tmpdir() as tmp:
        ledger = tmp / "token-ledger.jsonl"
        base = datetime(2026, 4, 28, 10, 0, tzinfo=timezone.utc)
        _write_ledger(
            ledger,
            [
                _record_with_default_feature(
                    ts=base,
                    session_id="sess-1",
                    feature=None,
                    tokens_in=500,
                    tokens_out=100,
                ),
            ],
        )
        report = quota.build_token_report(token_ledger_path=ledger)
        assert "(untagged)" in report.by_feature
        assert report.by_feature["(untagged)"] == 600


def test_session_top_attributes_pick_largest() -> None:
    """Per-session top_model/top_tier/top_feature pick highest-burn label."""
    with _tmpdir() as tmp:
        ledger = tmp / "token-ledger.jsonl"
        base = datetime(2026, 4, 28, 10, 0, tzinfo=timezone.utc)
        _write_ledger(
            ledger,
            [
                _record_with_default_feature(
                    ts=base,
                    session_id="sess-1",
                    model="claude-opus-4-7",
                    tokens_in=10000,
                    tokens_out=2000,
                    feature="F-006",
                ),
                _record_with_default_feature(
                    ts=base + timedelta(minutes=10),
                    session_id="sess-1",
                    model="claude-haiku-4-5",
                    tokens_in=500,
                    tokens_out=100,
                    feature="F-008",
                ),
            ],
        )
        report = quota.build_token_report(token_ledger_path=ledger)
        assert report.current_session is not None
        assert report.current_session.top_model == "claude-opus-4-7"
        assert report.current_session.top_feature == "F-006"


# ---------------------------------------------------------------------------
# Robustness: malformed records, out-of-order ts
# ---------------------------------------------------------------------------


def test_malformed_lines_are_skipped() -> None:
    with _tmpdir() as tmp:
        ledger = tmp / "token-ledger.jsonl"
        base = datetime(2026, 4, 28, 10, 0, tzinfo=timezone.utc)
        good = json.dumps(_record_with_default_feature(ts=base, session_id="sess-1"))
        ledger.write_text(
            good + "\nthis is not json\n" + good + "\n",
            encoding="utf-8",
        )
        report = quota.build_token_report(token_ledger_path=ledger)
        assert report.record_count == 2


def test_records_without_session_id_are_skipped() -> None:
    with _tmpdir() as tmp:
        ledger = tmp / "token-ledger.jsonl"
        base = datetime(2026, 4, 28, 10, 0, tzinfo=timezone.utc)
        rec = _record_with_default_feature(ts=base, session_id="sess-1")
        bad = dict(rec)
        bad.pop("session_id")
        ledger.write_text(
            json.dumps(rec) + "\n" + json.dumps(bad) + "\n",
            encoding="utf-8",
        )
        report = quota.build_token_report(token_ledger_path=ledger)
        assert report.record_count == 1


def test_out_of_order_timestamps_resolve_by_last_seen() -> None:
    with _tmpdir() as tmp:
        ledger = tmp / "token-ledger.jsonl"
        base = datetime(2026, 4, 28, 10, 0, tzinfo=timezone.utc)
        _write_ledger(
            ledger,
            [
                _record_with_default_feature(ts=base + timedelta(minutes=60), session_id="sess-A"),
                _record_with_default_feature(ts=base + timedelta(minutes=10), session_id="sess-A"),
                _record_with_default_feature(ts=base + timedelta(minutes=45), session_id="sess-B"),
                _record_with_default_feature(ts=base + timedelta(minutes=20), session_id="sess-B"),
            ],
        )
        report = quota.build_token_report(token_ledger_path=ledger)
        assert report.current_session is not None
        assert report.current_session.session_id == "sess-A"


# ---------------------------------------------------------------------------
# Render — JSON shape stability
# ---------------------------------------------------------------------------


def test_json_output_has_stable_shape() -> None:
    with _tmpdir() as tmp:
        ledger = tmp / "token-ledger.jsonl"
        base = datetime(2026, 4, 28, 10, 0, tzinfo=timezone.utc)
        _write_ledger(
            ledger,
            [
                _record_with_default_feature(
                    ts=base, session_id="sess-1", tokens_in=1000, tokens_out=200
                )
            ],
        )
        report = quota.build_token_report(token_ledger_path=ledger)
        out = quota.render_token_report(report, color=False, json_output=True)
        parsed = json.loads(out)

        assert set(parsed) == {
            "current_session",
            "rolling_window",
            "by_tier",
            "by_model",
            "by_feature",
            "record_count",
            "window_sessions",
        }
        assert set(parsed["current_session"]) == {
            "session_id",
            "started_at",
            "ended_at",
            "tokens_in",
            "tokens_out",
            "tokens_total",
            "cache_read_tokens",
            "record_count",
            "top_model",
            "top_tier",
            "top_feature",
        }
        reparsed = json.loads(json.dumps(parsed, sort_keys=True))
        assert reparsed == parsed


def test_human_render_handles_empty() -> None:
    with _tmpdir() as tmp:
        ledger = tmp / "token-ledger.jsonl"
        report = quota.build_token_report(token_ledger_path=ledger)
        out = quota.render_token_report(report, color=False, json_output=False)
        assert "no data yet" in out


def test_human_render_shows_current_and_rolling() -> None:
    with _tmpdir() as tmp:
        ledger = tmp / "token-ledger.jsonl"
        base = datetime(2026, 4, 28, 10, 0, tzinfo=timezone.utc)
        _write_ledger(
            ledger,
            [
                _record_with_default_feature(
                    ts=base, session_id="sess-1", tokens_in=10000, tokens_out=2000
                ),
                _record_with_default_feature(
                    ts=base + timedelta(minutes=10),
                    session_id="sess-1",
                    tokens_in=12000,
                    tokens_out=3500,
                ),
            ],
        )
        report = quota.build_token_report(token_ledger_path=ledger)
        out = quota.render_token_report(report, color=False, json_output=False)
        assert "current session" in out
        assert "Rolling 1 sessions" in out
        assert "27" in out  # 10K+2K+12K+3.5K = 27.5K → "27K" present


# ---------------------------------------------------------------------------
# G5 — golden-master quota report regression
# ---------------------------------------------------------------------------


def test_quota_golden_master_stable() -> None:
    """Compute --report quota --json against the committed fixture and assert
    stable equality with the expected output. This guards M1 (cache_creation
    must NOT be summed into tokens_in)."""
    fixture = PROJECT_ROOT / "tests" / "fixtures" / "quota-fixture.jsonl"
    expected_path = PROJECT_ROOT / "tests" / "fixtures" / "quota-fixture-expected.json"
    assert fixture.exists(), "G5 fixture missing"
    assert expected_path.exists(), "G5 expected output missing"

    pinned_now = datetime(2026, 4, 28, 13, 0, tzinfo=timezone.utc)
    report = quota.compute_quota(
        token_ledger_path=fixture,
        ceiling_tokens=200_000,
        window_seconds=18_000,
        now=pinned_now,
    )
    actual = json.loads(quota.render_report(report, color=False, json_output=True))
    expected = json.loads(expected_path.read_text(encoding="utf-8"))

    assert json.dumps(actual, sort_keys=True) == json.dumps(expected, sort_keys=True)


def test_quota_golden_master_tokens_in_excludes_cache_creation() -> None:
    """Direct guard on M1: tokens_in must equal the raw input_tokens sum."""
    fixture = PROJECT_ROOT / "tests" / "fixtures" / "quota-fixture.jsonl"
    expected_in = 0
    expected_cache_write = 0
    for line in fixture.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        rec = json.loads(line)
        expected_in += rec["tokens_in"]
        expected_cache_write += rec.get("cache_write_tokens", 0)

    pinned_now = datetime(2026, 4, 28, 13, 0, tzinfo=timezone.utc)
    report = quota.compute_quota(
        token_ledger_path=fixture,
        ceiling_tokens=200_000,
        window_seconds=18_000,
        now=pinned_now,
    )
    assert report.tokens_in == expected_in
    assert report.tokens_in < expected_in + expected_cache_write


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
