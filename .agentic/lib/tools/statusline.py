"""statusline.py — Claude Code status line for the Agentic Framework.

Reads the Claude Code statusLine envelope on stdin and prints a single-line
status to stdout:

    agentic-framework | feat/R-101 | ctx 47% | 5h 23% reset 22:30 | wk 18% reset Sun | R-101 PR review

Components:
  * **project** — basename of the git toplevel (or `cwd` fallback).
  * **branch** — current git branch.
  * **ctx %** — latest assistant turn's `input_tokens + cache_read_input_tokens
    + cache_creation_input_tokens` against the model's context window. Source:
    `transcript_path` from stdin. Falls back to "ctx —" if no usage block.
  * **5h quota %** — uses `quota.compute_quota` against the local
    `token-ledger.jsonl` and the STACK.md `quota_pro_max_window_tokens`
    setting. Reset shows the earliest in-window record's ts + 5h, formatted
    as local HH:MM. Hidden when no ceiling configured.
  * **wk quota %** — same projection over a rolling 7-day window, against
    `quota_pro_max_weekly_tokens` (Pro/Max plans have a separate weekly
    cap). Reset shows the abbreviated weekday when the earliest in-window
    record drops out (e.g. "Sun"). Hidden when no ceiling configured.
  * **task** — first non-comment "## Current focus" item from
    `.agentic/STATUS.md`, fallback to AGENTS.json `feature_id`, fallback to
    HEAD commit subject.

This is a TELEMETRY surface: every component fails open. Any individual
section that errors is replaced with `?` rather than crashing the line.

Stdlib only.

Honest limit on quota resets
----------------------------
Anthropic's plan-anchored 5h and 7d windows reset at wall-clock times tied
to your plan signup, which the API does not expose. The "reset" times here
are derived from the rolling-window edge of the local ledger — they're a
useful estimate, not a guaranteed match for the Anthropic dashboard.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

# Make `import quota` work — same trick our other tools use.
_LIB_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(_LIB_DIR))

import quota  # noqa: E402


# ---------------------------------------------------------------------------
# Model context-window table
# ---------------------------------------------------------------------------


# Mapping from model id substring → context window. Order matters: the first
# match wins, so put more-specific keys first. The `[1m]` suffix Anthropic
# uses on long-context skews must match before the bare model name.
_CONTEXT_WINDOWS: list[tuple[str, int]] = [
    ("[1m]", 1_000_000),
    ("opus-4-7", 200_000),
    ("opus-4", 200_000),
    ("sonnet-4-7", 200_000),
    ("sonnet-4-6", 200_000),
    ("sonnet-4-5", 200_000),
    ("sonnet-4", 200_000),
    ("haiku-4-5", 200_000),
    ("haiku-4", 200_000),
]


def context_window_for(model_id: Optional[str]) -> int:
    if not isinstance(model_id, str) or not model_id:
        return 200_000
    lowered = model_id.lower()
    for needle, window in _CONTEXT_WINDOWS:
        if needle in lowered:
            return window
    return 200_000


# ---------------------------------------------------------------------------
# Transcript: latest assistant turn → ctx tokens
# ---------------------------------------------------------------------------


def latest_usage(transcript_path: Optional[str]) -> Optional[dict]:
    """Return the `usage` block from the most recent assistant turn.

    Walks the transcript backward (last line first). Returns None if no
    suitable turn exists. Tolerates malformed lines.
    """
    if not transcript_path:
        return None
    p = Path(transcript_path).expanduser()
    if not p.exists():
        return None
    try:
        # Read whole file; transcripts are usually a few MB at most. We could
        # tail-read for speed, but stdlib reverse-line iteration is fiddly
        # and the statusLine command runs in the background.
        with open(p, "r", encoding="utf-8", errors="replace") as fh:
            lines = fh.readlines()
    except OSError:
        return None
    for raw in reversed(lines):
        raw = raw.strip()
        if not raw:
            continue
        try:
            rec = json.loads(raw)
        except json.JSONDecodeError:
            continue
        if not isinstance(rec, dict):
            continue
        if rec.get("type") != "assistant":
            continue
        if rec.get("isSidechain") is True:
            continue
        msg = rec.get("message")
        if not isinstance(msg, dict):
            continue
        usage = msg.get("usage")
        if isinstance(usage, dict):
            return usage
    return None


def ctx_used_tokens(usage: dict) -> int:
    """Effective context size for the next turn.

    `input_tokens` carries net-new prompt tokens; cache reads + cache writes
    were already part of the conversation history at request time. Summing
    all three approximates "how many tokens the next request will see".
    """
    total = 0
    for key in ("input_tokens", "cache_read_input_tokens", "cache_creation_input_tokens"):
        v = usage.get(key)
        if isinstance(v, int) and v > 0:
            total += v
    return total


# ---------------------------------------------------------------------------
# 5h quota window — reuse quota.compute_quota
# ---------------------------------------------------------------------------


def stack_md_setting(stack_path: Path, key: str) -> Optional[str]:
    """Best-effort STACK.md key reader. Matches `key: value` lines."""
    if not stack_path.exists():
        return None
    try:
        for line in stack_path.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if line.startswith(f"{key}:"):
                return line.split(":", 1)[1].strip()
    except OSError:
        return None
    return None


_FIVE_HOURS_SECONDS = 5 * 60 * 60
_SEVEN_DAYS_SECONDS = 7 * 24 * 60 * 60


def quota_summary(
    project_root: Path,
    *,
    ceiling_setting: str,
    window_seconds: int,
) -> Optional[tuple[float, Optional[datetime]]]:
    """Return (quota_pct, reset_ts) for one rolling-window projection.

    `ceiling_setting` names the STACK.md key; `window_seconds` selects 5h
    or 7d (or any other interval). `reset_ts` is the earliest in-window
    record's ts + window — i.e., the wall clock when that record drops out
    of the rolling window. Returns None when no ceiling is configured;
    returns (pct, None) when the ledger is empty.
    """
    ceiling_raw = stack_md_setting(project_root / "STACK.md", ceiling_setting)
    if not ceiling_raw:
        return None
    try:
        ceiling = int(ceiling_raw)
    except ValueError:
        return None
    if ceiling <= 0:
        return None

    ledger = project_root / ".agentic" / "journal" / "token-ledger.jsonl"
    now = datetime.now(timezone.utc)
    report = quota.compute_quota(
        token_ledger_path=ledger,
        ceiling_tokens=ceiling,
        window_seconds=window_seconds,
        now=now,
    )
    pct = report.quota_pct or 0.0

    # Reset = earliest in-window record + window_seconds. compute_quota
    # captures earliest_record_ts during its existing loop (added after a
    # review pass flagged the duplicate iteration), so callers don't have
    # to re-walk the ledger. With both 5h and 7d ceilings configured,
    # this halves per-prompt CPU on the statusline path.
    if report.earliest_record_ts is None:
        return (pct, None)
    from datetime import timedelta
    return (pct, report.earliest_record_ts + timedelta(seconds=window_seconds))


# ---------------------------------------------------------------------------
# Git: branch + project name
# ---------------------------------------------------------------------------


def _git(*args: str, cwd: str) -> Optional[str]:
    try:
        out = subprocess.run(
            ["git", "-C", cwd, *args],
            capture_output=True,
            text=True,
            timeout=2.0,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    if out.returncode != 0:
        return None
    return out.stdout.strip() or None


def project_name(cwd: str) -> str:
    toplevel = _git("rev-parse", "--show-toplevel", cwd=cwd)
    if toplevel:
        return Path(toplevel).name
    return Path(cwd).name or "?"


def git_branch(cwd: str) -> str:
    branch = _git("rev-parse", "--abbrev-ref", "HEAD", cwd=cwd)
    return branch or "?"


# ---------------------------------------------------------------------------
# Current task
# ---------------------------------------------------------------------------


def current_task(project_root: Path) -> str:
    """Best-effort current task. Tries STATUS.md focus, AGENTS.json, then HEAD subject."""
    status = project_root / ".agentic" / "STATUS.md"
    if status.exists():
        try:
            in_focus = False
            for line in status.read_text(encoding="utf-8").splitlines():
                line_stripped = line.strip()
                if line_stripped.startswith("## "):
                    in_focus = "current focus" in line_stripped.lower()
                    continue
                if in_focus and line_stripped.startswith("- "):
                    text = line_stripped[2:]
                    if text.startswith("**"):
                        # "**F-031: Spec System Overhaul …**" — strip bold + suffix
                        end = text.find("**", 2)
                        if end > 0:
                            text = text[2:end]
                    # Truncate at " — " to keep it short
                    if " — " in text:
                        text = text.split(" — ", 1)[0]
                    return text.strip()
        except OSError:
            pass

    agents = project_root / ".agentic" / "session" / "AGENTS.json"
    if agents.exists():
        try:
            data = json.loads(agents.read_text(encoding="utf-8"))
            if isinstance(data, list):
                for entry in data:
                    if isinstance(entry, dict) and entry.get("feature_id"):
                        title = entry.get("title") or entry["feature_id"]
                        return f"{entry['feature_id']}: {title}" if title != entry["feature_id"] else entry["feature_id"]
        except (OSError, json.JSONDecodeError):
            pass

    subject = _git("log", "-1", "--pretty=%s", cwd=str(project_root))
    if subject:
        # Strip leading "F-XXX commit N/M: " noise so the line stays compact.
        return subject[:60] + ("…" if len(subject) > 60 else "")
    return "—"


# ---------------------------------------------------------------------------
# Formatting
# ---------------------------------------------------------------------------


def fmt_pct(numerator: int, denominator: int) -> str:
    if denominator <= 0:
        return "—"
    pct = 100.0 * numerator / denominator
    return f"{pct:.0f}%"


def fmt_local_hhmm(dt: datetime) -> str:
    return dt.astimezone().strftime("%H:%M")


def fmt_local_day_or_hhmm(dt: datetime, *, now: Optional[datetime] = None) -> str:
    """Format weekly reset times more usefully than HH:MM.

    Within 24h: show "HH:MM" (a clock time tomorrow morning is more useful
    than "Tue"). Beyond 24h: show abbreviated weekday + HH:MM ("Sun 14:00").
    """
    now = now or datetime.now(timezone.utc)
    delta_hours = (dt - now).total_seconds() / 3600.0
    local = dt.astimezone()
    if delta_hours < 24:
        return local.strftime("%H:%M")
    return local.strftime("%a %H:%M")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


def _safe(label: str, fn) -> str:
    try:
        return fn()
    except Exception:
        return f"{label} ?"


def build_statusline(envelope: dict) -> str:
    cwd = envelope.get("cwd") or os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd()
    if not isinstance(cwd, str):
        cwd = os.getcwd()
    project_root = Path(cwd).resolve()

    parts: list[str] = []

    # Project + branch
    parts.append(_safe("proj", lambda: project_name(cwd)))
    parts.append(_safe("branch", lambda: git_branch(cwd)))

    # ctx %
    def _ctx() -> str:
        usage = latest_usage(envelope.get("transcript_path"))
        if not usage:
            return "ctx —"
        used = ctx_used_tokens(usage)
        model = (envelope.get("model") or {})
        model_id = model.get("id") if isinstance(model, dict) else None
        window = context_window_for(model_id)
        return f"ctx {fmt_pct(used, window)}"
    parts.append(_safe("ctx", _ctx))

    # 5h quota
    def _quota_5h() -> Optional[str]:
        summary = quota_summary(
            project_root,
            ceiling_setting="quota_pro_max_window_tokens",
            window_seconds=_FIVE_HOURS_SECONDS,
        )
        if summary is None:
            return None
        pct, reset_ts = summary
        bits = f"5h {pct:.0f}%"
        if reset_ts is not None:
            bits += f" reset {fmt_local_hhmm(reset_ts)}"
        return bits
    quota_5h_part = _safe("5h", lambda: _quota_5h() or "")
    if quota_5h_part:
        parts.append(quota_5h_part)

    # Weekly quota — Pro/Max plans have a separate 7d cap. STACK key is
    # quota_pro_max_weekly_tokens; absent → segment hidden.
    def _quota_weekly() -> Optional[str]:
        summary = quota_summary(
            project_root,
            ceiling_setting="quota_pro_max_weekly_tokens",
            window_seconds=_SEVEN_DAYS_SECONDS,
        )
        if summary is None:
            return None
        pct, reset_ts = summary
        bits = f"wk {pct:.0f}%"
        if reset_ts is not None:
            bits += f" reset {fmt_local_day_or_hhmm(reset_ts)}"
        return bits
    quota_wk_part = _safe("wk", lambda: _quota_weekly() or "")
    if quota_wk_part:
        parts.append(quota_wk_part)

    # Task
    parts.append(_safe("task", lambda: current_task(project_root)))

    return " | ".join(parts)


def main() -> int:
    try:
        raw = sys.stdin.read()
    except OSError:
        raw = ""
    envelope: dict = {}
    if raw.strip():
        try:
            parsed = json.loads(raw)
            if isinstance(parsed, dict):
                envelope = parsed
        except json.JSONDecodeError:
            pass

    line = build_statusline(envelope)
    print(line)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
