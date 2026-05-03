"""statusline.py — Claude Code status line for the Agentic Framework.

Reads the Claude Code statusLine envelope on stdin and prints a single-line
status to stdout:

    agentic-framework | feat/R-101 | ctx 47% | 23% 5h, 18% 7d - reset 22:30, Sun 14:00 EEST (updated at main agent response) | R-101 PR review

Components:
  * **project** — repo name from `git config remote.origin.url` (so it
    survives Docker mount-point dirs like `/workspace`); falls back to git
    toplevel basename, then cwd basename.
  * **branch** — current git branch.
  * **ctx %** — latest assistant turn's `input_tokens + cache_read_input_tokens
    + cache_creation_input_tokens` against the model's context window. Source:
    `transcript_path` from stdin. Falls back to "ctx —" if no usage block.
  * **rate-limit cluster** — single bar segment built from
    `envelope.rate_limits`. Shape:
        `N% 5h, M% 7d - reset HH:MM, Day HH:MM TZ (updated at main agent response)`
    Pcts and resets list each window in the order present. One shared TZ
    label at the end of the reset block. The trailing parenthetical is
    ANSI-dimmed — anchors that values are a snapshot from the last
    main-agent turn (`/usage` triggers a refresh). Hidden entirely when
    the envelope has no usable rate_limits.
  * **task** — first non-comment "## Current focus" item from
    `.agentic/STATUS.md`, fallback to AGENTS.json `feature_id`, fallback to
    HEAD commit subject.

This is a TELEMETRY surface: every component fails open. Any individual
section that errors is replaced with `?` rather than crashing the line.

Stdlib only. Zero config — reads what Claude Code pipes in.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

# ANSI: dim the freshness anchor so it reads as a footnote rather than data.
# Claude Code passes ANSI through to the terminal. Fail-safe: if the terminal
# strips them, the parenthetical still reads correctly as plain text.
_DIM = "\x1b[2m"
_RESET = "\x1b[0m"

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
# Rate limits — read from Claude Code envelope
# ---------------------------------------------------------------------------


def quota_from_blob(envelope: dict, key: str) -> Optional[tuple[float, Optional[datetime]]]:
    """Return (pct, reset_dt) from `envelope.rate_limits.<key>`.

    `key` is "five_hour" or "seven_day". Returns None when the envelope
    has no usable percentage for that window. `reset_dt` is None when the
    envelope omits `resets_at`.
    """
    rl = envelope.get("rate_limits") or {}
    section = rl.get(key) or {}
    pct_raw = section.get("used_percentage")
    if pct_raw is None:
        return None
    try:
        pct = float(pct_raw)
    except (TypeError, ValueError):
        return None
    resets_at = section.get("resets_at")
    reset_dt: Optional[datetime] = None
    if resets_at is not None:
        try:
            reset_dt = datetime.fromtimestamp(int(resets_at), tz=timezone.utc)
        except (TypeError, ValueError, OSError, OverflowError):
            reset_dt = None
    return (pct, reset_dt)


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


def _repo_name_from_remote(cwd: str) -> Optional[str]:
    """Repo name parsed from `git config remote.origin.url`.

    Resilient to mount-point directory names (e.g. `/workspace` inside
    Docker, where the toplevel basename is meaningless). Handles common
    URL forms: `git@host:user/repo.git`, `https://host/user/repo`,
    trailing slashes, and the `.git` suffix.
    """
    url = _git("config", "--get", "remote.origin.url", cwd=cwd)
    if not url:
        return None
    cleaned = url.rstrip("/")
    if cleaned.endswith(".git"):
        cleaned = cleaned[:-4]
    last = cleaned.rsplit("/", 1)[-1].rsplit(":", 1)[-1]
    return last or None


def project_name(cwd: str) -> str:
    """Project label for the bar.

    Order: git remote name (survives Docker mount-point dirs) → toplevel
    basename → cwd basename → "?".
    """
    remote = _repo_name_from_remote(cwd)
    if remote:
        return remote
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


def _tz_label(local_dt: datetime) -> str:
    """Best-effort timezone marker for a localized datetime.

    Prefers the IANA abbreviation from `%Z` (e.g. "EEST", "PST"). On systems
    where `%Z` returns empty or a numeric offset, falls back to a normalized
    `UTC±N` form derived from `%z`. Returns "" if neither is available.
    """
    name = local_dt.strftime("%Z")
    if name and not name.startswith("+") and not name.startswith("-"):
        return name
    offset = local_dt.strftime("%z")
    if not offset or len(offset) < 5:
        return ""
    sign = offset[0]
    try:
        hours = int(offset[1:3])
        minutes = int(offset[3:5])
    except ValueError:
        return ""
    if hours == 0 and minutes == 0:
        return "UTC"
    if minutes == 0:
        return f"UTC{sign}{hours}"
    return f"UTC{sign}{hours}:{minutes:02d}"


def _hhmm_with_optional_day(dt: datetime, *, now: Optional[datetime] = None) -> str:
    """HH:MM if within 24h, else `Day HH:MM`. No timezone — caller appends
    one shared TZ for the whole reset cluster."""
    now = now or datetime.now(timezone.utc)
    local = dt.astimezone()
    if (dt - now).total_seconds() / 3600.0 < 24:
        return local.strftime("%H:%M")
    return local.strftime("%a %H:%M")


def _format_rate_limit_cluster(envelope: dict) -> Optional[str]:
    """Render the rate-limit segment of the bar, or None if no data.

    Shape: `N% 5h, M% 7d - reset HH:MM, Day HH:MM TZ <dim>(updated at main
    agent response)<reset>`. The reset block uses one shared TZ label;
    individual reset entries are skipped when their window omits
    `resets_at`. The trailer is dim-styled (ANSI) so it reads as a
    footnote, not data.
    """
    five = quota_from_blob(envelope, "five_hour")
    seven = quota_from_blob(envelope, "seven_day")
    if five is None and seven is None:
        return None

    pct_bits: list[str] = []
    reset_bits: list[str] = []
    tz_label = ""
    now = datetime.now(timezone.utc)

    if five is not None:
        pct, reset_dt = five
        pct_bits.append(f"{pct:.0f}% 5h")
        if reset_dt is not None:
            local = reset_dt.astimezone()
            reset_bits.append(local.strftime("%H:%M"))
            tz_label = _tz_label(local) or tz_label

    if seven is not None:
        pct, reset_dt = seven
        pct_bits.append(f"{pct:.0f}% 7d")
        if reset_dt is not None:
            reset_bits.append(_hhmm_with_optional_day(reset_dt, now=now))
            tz_label = _tz_label(reset_dt.astimezone()) or tz_label

    bits = ", ".join(pct_bits)
    if reset_bits:
        bits += " - reset " + ", ".join(reset_bits)
        if tz_label:
            bits += " " + tz_label
    bits += f" {_DIM}(updated at main agent response){_RESET}"
    return bits


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

    # Rate-limit cluster — from envelope.rate_limits.{five_hour,seven_day}.
    # Format: "N% 5h, M% 7d - reset HH:MM, Day HH:MM TZ <dim>(updated at
    # main agent response)<reset>". Reset block omitted if no item carries
    # `resets_at`; either window may be missing.
    rl_part = _safe("rl", lambda: _format_rate_limit_cluster(envelope) or "")
    if rl_part:
        parts.append(rl_part)

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
