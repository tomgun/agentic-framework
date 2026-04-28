"""
quota.py — Pro/Max session quota usage analytics (R-013).

Reads `.agentic/journal/token-ledger.jsonl` and projects current usage in a
rolling time window (default 5 hours, matching Anthropic Pro/Max session
windows). Returns a structured report with per-tier and per-model breakdowns,
threshold alerts, and a linear-extrapolation projection of when the configured
ceiling will be reached at the current rate.

Design notes
------------
* Stdlib only. Reads the JSONL line-by-line; tolerates malformed records.
* The window is *now-relative*; passing an explicit `now` makes results
  deterministic for tests.
* Thresholds (70 / 85 / 95 %) match the R-013 AC and are wired into the TUI's
  health-bar logic in R-014.
* Linear projection is intentionally naive: `tokens_per_second × seconds_until
  ceiling`. Real bursty workloads exhaust the quota sooner; the TUI ring (R-014)
  surfaces a more conservative trailing-window rate. This module is the source
  of truth for both.

Honest limit
------------
Anthropic does not expose actual remaining-quota via API; this module estimates
based on the local token-ledger.jsonl, which is itself populated by harness
hooks. If those hooks miss a request (e.g., parallel session in a worktree
without `events.append_token_ledger` wired), the report under-counts.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Optional


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------


DEFAULT_WINDOW_SECONDS = 5 * 60 * 60  # 5h, matches Anthropic Pro/Max window
ALERT_THRESHOLDS = (0.70, 0.85, 0.95)


# ---------------------------------------------------------------------------
# Result types
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class QuotaReport:
    window_seconds: int
    window_start: datetime
    window_end: datetime
    ceiling_tokens: Optional[int]
    tokens_total: int
    tokens_in: int
    tokens_out: int
    cache_read_tokens: int
    by_tier: dict[str, int]
    by_model: dict[str, int]
    record_count: int
    quota_pct: Optional[float]   # 0.0 .. 100.0 (None when ceiling unknown)
    alert_level: Optional[str]   # "70%" | "85%" | "95%" | None
    projected_exhaustion: Optional[datetime]
    advice: list[str] = field(default_factory=list)


# ---------------------------------------------------------------------------
# Reading + parsing
# ---------------------------------------------------------------------------


def _parse_ts(record: dict) -> Optional[datetime]:
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


def _iter_records(path: Path):
    if not path.exists():
        return
    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                rec = json.loads(line)
            except json.JSONDecodeError:
                continue
            if isinstance(rec, dict):
                yield rec


def _coerce_int(value) -> int:
    if isinstance(value, bool):
        return 0
    if isinstance(value, int):
        return value if value >= 0 else 0
    if isinstance(value, float):
        return int(value) if value >= 0 else 0
    return 0


# ---------------------------------------------------------------------------
# Computation
# ---------------------------------------------------------------------------


def _compute_alert(pct: Optional[float]) -> Optional[str]:
    if pct is None:
        return None
    fraction = pct / 100.0
    # Pick the highest threshold reached.
    for label, t in (("95%", 0.95), ("85%", 0.85), ("70%", 0.70)):
        if fraction >= t:
            return label
    return None


def _project_exhaustion(
    *,
    tokens_in_window: int,
    earliest_record_ts: Optional[datetime],
    window_start: datetime,
    now: datetime,
    ceiling: int,
) -> Optional[datetime]:
    """Linear extrapolation: at current rate, when does usage hit ceiling?

    The denominator is the **active** time spent burning tokens, capped by the
    window length. Specifically: ``elapsed = now - max(window_start, earliest_record_ts)``.
    A user who burned 600k tokens in the last 5 minutes gets a far shorter
    projection than someone who burned the same amount evenly across 5 hours,
    which matches subjective intuition. When the active span is shorter than
    one minute we floor at 60s to avoid divide-by-zero-ish projections that
    would look like "exhaustion in 3 seconds" from a single record.
    """
    if ceiling <= 0 or tokens_in_window <= 0:
        return None
    if earliest_record_ts is None:
        active_start = window_start
    else:
        active_start = max(window_start, earliest_record_ts)
    elapsed = (now - active_start).total_seconds()
    if elapsed < 60:
        elapsed = 60.0
    rate_tokens_per_sec = tokens_in_window / elapsed
    if rate_tokens_per_sec <= 0:
        return None
    remaining = max(0, ceiling - tokens_in_window)
    if remaining == 0:
        return now
    secs = remaining / rate_tokens_per_sec
    if secs > 365 * 24 * 3600:  # absurd projection — skip
        return None
    return now + timedelta(seconds=secs)


def _build_advice(*, alert: Optional[str], by_tier: dict[str, int]) -> list[str]:
    if alert is None:
        return []
    notes: list[str] = []
    if alert in ("85%", "95%"):
        notes.append(
            "Pause Tier 3 worker dispatch (--teams) — burn rate is too high."
        )
    if alert == "95%":
        notes.append(
            "Consider stopping Tier 2 critic invocations until window resets."
        )
    if alert == "70%" and by_tier.get("tier2", 0) > 0:
        notes.append(
            "70% threshold reached — Tier 2 critic invocations are the largest "
            "single contributor; consider switching the critic model to Haiku "
            "(or skipping critic on low-risk diffs) until the window resets."
        )
    return notes


def compute_quota(
    *,
    token_ledger_path: Path,
    ceiling_tokens: Optional[int],
    window_seconds: int = DEFAULT_WINDOW_SECONDS,
    now: Optional[datetime] = None,
) -> QuotaReport:
    """
    Compute quota usage over the trailing `window_seconds` ending at `now`.

    `ceiling_tokens=None` is allowed: the report will have `quota_pct=None`
    and no alert; consumers display raw totals only.
    """
    now = now or datetime.now(timezone.utc)
    window_start = now - timedelta(seconds=window_seconds)

    tokens_total = 0
    tokens_in = 0
    tokens_out = 0
    cache_read = 0
    by_tier: dict[str, int] = {}
    by_model: dict[str, int] = {}
    record_count = 0
    earliest_ts: Optional[datetime] = None

    for rec in _iter_records(token_ledger_path):
        ts = _parse_ts(rec)
        if ts is None or ts < window_start or ts > now:
            continue
        if earliest_ts is None or ts < earliest_ts:
            earliest_ts = ts
        record_count += 1
        ti = _coerce_int(rec.get("tokens_in"))
        to = _coerce_int(rec.get("tokens_out"))
        cr = _coerce_int(rec.get("cache_read_tokens"))
        # Quota counts billable tokens: tokens_in + tokens_out. Cache reads are
        # tracked separately for cost analysis but don't burn quota.
        line_total = ti + to
        tokens_total += line_total
        tokens_in += ti
        tokens_out += to
        cache_read += cr

        tier = rec.get("tier") or "unknown"
        if not isinstance(tier, str):
            tier = "unknown"
        by_tier[tier] = by_tier.get(tier, 0) + line_total

        model = rec.get("model") or "unknown"
        if not isinstance(model, str):
            model = "unknown"
        by_model[model] = by_model.get(model, 0) + line_total

    quota_pct: Optional[float] = None
    if ceiling_tokens and ceiling_tokens > 0:
        quota_pct = round(100.0 * tokens_total / ceiling_tokens, 1)

    alert = _compute_alert(quota_pct)
    projection = (
        _project_exhaustion(
            tokens_in_window=tokens_total,
            earliest_record_ts=earliest_ts,
            window_start=window_start,
            now=now,
            ceiling=ceiling_tokens,
        )
        if ceiling_tokens
        else None
    )
    advice = _build_advice(alert=alert, by_tier=by_tier)

    return QuotaReport(
        window_seconds=window_seconds,
        window_start=window_start,
        window_end=now,
        ceiling_tokens=ceiling_tokens,
        tokens_total=tokens_total,
        tokens_in=tokens_in,
        tokens_out=tokens_out,
        cache_read_tokens=cache_read,
        by_tier=by_tier,
        by_model=by_model,
        record_count=record_count,
        quota_pct=quota_pct,
        alert_level=alert,
        projected_exhaustion=projection,
        advice=advice,
    )


# ---------------------------------------------------------------------------
# Rendering
# ---------------------------------------------------------------------------


_RESET = "\033[0m"
_BOLD = "\033[1m"
_DIM = "\033[2m"
_RED = "\033[31m"
_GREEN = "\033[32m"
_YELLOW = "\033[33m"


def _color_for_alert(alert: Optional[str], color: bool) -> str:
    if not color or alert is None:
        return ""
    if alert == "95%":
        return _RED
    if alert == "85%":
        return _RED
    if alert == "70%":
        return _YELLOW
    return ""


def _fmt_int(n: int) -> str:
    return f"{n:,}"


def _fmt_duration(seconds: float) -> str:
    seconds = int(max(0, seconds))
    h = seconds // 3600
    m = (seconds % 3600) // 60
    s = seconds % 60
    if h:
        return f"{h}h {m}m"
    if m:
        return f"{m}m {s}s"
    return f"{s}s"


def render_report(
    report: QuotaReport,
    *,
    color: bool = True,
    json_output: bool = False,
) -> str:
    """Render a `QuotaReport` for human consumption (or `--json`)."""
    if json_output:
        return json.dumps(
            {
                "window_seconds": report.window_seconds,
                "window_start": report.window_start.isoformat(),
                "window_end": report.window_end.isoformat(),
                "ceiling_tokens": report.ceiling_tokens,
                "tokens_total": report.tokens_total,
                "tokens_in": report.tokens_in,
                "tokens_out": report.tokens_out,
                "cache_read_tokens": report.cache_read_tokens,
                "quota_pct": report.quota_pct,
                "alert_level": report.alert_level,
                "by_tier": report.by_tier,
                "by_model": report.by_model,
                "record_count": report.record_count,
                "projected_exhaustion": (
                    report.projected_exhaustion.isoformat()
                    if report.projected_exhaustion
                    else None
                ),
                "advice": report.advice,
            },
            indent=2,
        )

    lines: list[str] = []
    bold = _BOLD if color else ""
    dim = _DIM if color else ""
    reset = _RESET if color else ""
    alert_color = _color_for_alert(report.alert_level, color)

    window_h = report.window_seconds // 3600
    window_label = f"{window_h}h" if window_h else f"{report.window_seconds}s"

    lines.append(f"{bold}Quota Report — last {window_label} window{reset}")
    lines.append("═" * 60)
    lines.append(
        f"Window:   {dim}{report.window_start.isoformat()} → "
        f"{report.window_end.isoformat()}{reset}"
    )

    if report.ceiling_tokens:
        bar_len = 32
        if report.quota_pct is not None:
            filled = min(bar_len, int(report.quota_pct / 100 * bar_len))
        else:
            filled = 0
        bar = "█" * filled + "░" * (bar_len - filled)
        pct_str = f"{report.quota_pct:.1f}%" if report.quota_pct is not None else "—"
        lines.append(
            f"Tokens:   {alert_color}{bold}{_fmt_int(report.tokens_total)}{reset}"
            f" / {_fmt_int(report.ceiling_tokens)}  "
            f"{alert_color}{bar}{reset} {alert_color}{bold}{pct_str}{reset}"
        )
    else:
        lines.append(
            f"Tokens:   {bold}{_fmt_int(report.tokens_total)}{reset}  "
            f"{dim}(no ceiling configured — set "
            f"quota_pro_max_window_tokens in STACK.md){reset}"
        )

    if report.alert_level:
        prefix = (
            f"{alert_color}⚠ ALERT {report.alert_level}{reset}"
            if color
            else f"⚠ ALERT {report.alert_level}"
        )
        lines.append(f"Status:   {prefix}")
    elif report.ceiling_tokens:
        ok = f"{_GREEN}✓ ok{reset}" if color else "✓ ok"
        lines.append(f"Status:   {ok}")

    if report.projected_exhaustion:
        seconds = (
            report.projected_exhaustion - report.window_end
        ).total_seconds()
        lines.append(
            f"Projection: {dim}exhaustion at "
            f"{report.projected_exhaustion.isoformat()} "
            f"(~{_fmt_duration(seconds)} at current rate){reset}"
        )

    lines.append("")
    if report.by_tier:
        lines.append(f"{bold}By tier{reset}")
        for tier in sorted(report.by_tier):
            tokens = report.by_tier[tier]
            pct = (
                f" ({100.0 * tokens / report.tokens_total:.1f}%)"
                if report.tokens_total
                else ""
            )
            lines.append(f"   {tier:<10} {_fmt_int(tokens):>12}{pct}")
        lines.append("")

    if report.by_model:
        lines.append(f"{bold}By model{reset}")
        for model in sorted(report.by_model, key=lambda m: -report.by_model[m]):
            tokens = report.by_model[model]
            pct = (
                f" ({100.0 * tokens / report.tokens_total:.1f}%)"
                if report.tokens_total
                else ""
            )
            lines.append(f"   {model:<24} {_fmt_int(tokens):>12}{pct}")
        lines.append("")

    if report.advice:
        lines.append(f"{bold}Advice{reset}")
        for note in report.advice:
            lines.append(f"   • {note}")
        lines.append("")

    lines.append(
        f"{dim}Records counted: {report.record_count}. Cache reads "
        f"({_fmt_int(report.cache_read_tokens)}) excluded from quota.{reset}"
    )
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def _build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="ag intel report --quota",
        description="Pro/Max quota usage report from token-ledger.jsonl.",
    )
    p.add_argument(
        "--token-ledger",
        type=Path,
        default=None,
        help="Path to token-ledger.jsonl (default: .agentic/journal/token-ledger.jsonl).",
    )
    p.add_argument(
        "--journal-dir",
        type=Path,
        default=None,
        help="Override journal directory.",
    )
    p.add_argument(
        "--window-seconds",
        type=int,
        default=DEFAULT_WINDOW_SECONDS,
        help="Trailing window length in seconds (default: 18000 = 5h).",
    )
    p.add_argument(
        "--ceiling-tokens",
        type=int,
        default=None,
        help="Pro/Max window ceiling. Read from STACK.md when omitted.",
    )
    p.add_argument(
        "--no-color",
        action="store_true",
        help="Disable ANSI colors.",
    )
    p.add_argument(
        "--json",
        action="store_true",
        help="Emit JSON instead of human-readable report.",
    )
    return p


def main(argv: Optional[list[str]] = None) -> int:
    args = _build_parser().parse_args(argv)

    if args.token_ledger is not None:
        path = args.token_ledger
    else:
        journal = args.journal_dir or Path.cwd() / ".agentic" / "journal"
        path = journal / "token-ledger.jsonl"

    report = compute_quota(
        token_ledger_path=path,
        ceiling_tokens=args.ceiling_tokens,
        window_seconds=args.window_seconds,
    )
    color = not args.no_color and sys.stdout.isatty() and os.environ.get(
        "NO_COLOR"
    ) is None
    print(render_report(report, color=color, json_output=args.json))
    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
