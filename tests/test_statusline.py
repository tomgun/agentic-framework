"""Tests for the rate-limit segments in statusline.py.

The framework statusline reads `rate_limits` from the Claude Code envelope
(zero-config) and renders 5h / wk percentages with reset times, plus a
"(values from last main agent response)" hint anchoring the snapshot's freshness.

Runs under pytest or directly: `python3 tests/test_statusline.py`.
"""
from __future__ import annotations

import sys
from datetime import datetime, timezone
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT / ".agentic" / "lib" / "tools"))

import statusline  # noqa: E402


# ---------------------------------------------------------------------------
# quota_from_blob
# ---------------------------------------------------------------------------


def test_quota_from_blob_returns_none_when_rate_limits_missing():
    assert statusline.quota_from_blob({}, "five_hour") is None
    assert statusline.quota_from_blob({"rate_limits": {}}, "five_hour") is None
    assert statusline.quota_from_blob({"rate_limits": {"five_hour": {}}}, "five_hour") is None


def test_quota_from_blob_returns_pct_and_reset():
    envelope = {
        "rate_limits": {
            "five_hour": {"used_percentage": 42, "resets_at": 1_800_000_000},
        }
    }
    pct, reset_dt = statusline.quota_from_blob(envelope, "five_hour")
    assert pct == 42.0
    assert reset_dt == datetime.fromtimestamp(1_800_000_000, tz=timezone.utc)


def test_quota_from_blob_returns_pct_with_no_reset_when_resets_at_missing():
    envelope = {"rate_limits": {"seven_day": {"used_percentage": 7}}}
    pct, reset_dt = statusline.quota_from_blob(envelope, "seven_day")
    assert pct == 7.0
    assert reset_dt is None


def test_quota_from_blob_tolerates_malformed_resets_at():
    envelope = {
        "rate_limits": {
            "five_hour": {"used_percentage": 50, "resets_at": "not-a-number"},
        }
    }
    pct, reset_dt = statusline.quota_from_blob(envelope, "five_hour")
    assert pct == 50.0
    assert reset_dt is None


def test_quota_from_blob_returns_none_for_malformed_pct():
    envelope = {"rate_limits": {"five_hour": {"used_percentage": "huge"}}}
    assert statusline.quota_from_blob(envelope, "five_hour") is None


# ---------------------------------------------------------------------------
# build_statusline integration
# ---------------------------------------------------------------------------


def _envelope(rate_limits=None):
    """Minimal envelope; cwd points at the repo so git/task fields don't ?-out."""
    env = {"cwd": str(PROJECT_ROOT), "model": {"id": "claude-opus-4-7"}}
    if rate_limits is not None:
        env["rate_limits"] = rate_limits
    return env


import re

ANSI_RE = re.compile(r"\x1b\[[0-9;]*m")
DIM = "\x1b[2m"
RESET = "\x1b[0m"


def _strip_ansi(s: str) -> str:
    return ANSI_RE.sub("", s)


def test_statusline_renders_both_rate_limit_windows_with_shared_tz_and_trailer():
    line = statusline.build_statusline(_envelope({
        "five_hour": {"used_percentage": 23, "resets_at": 1_800_000_000},
        "seven_day": {"used_percentage": 18, "resets_at": 1_800_500_000},
    }))
    plain = _strip_ansi(line)
    # Pcts: "23% 5h, 18% 7d"
    assert "23% 5h" in plain
    assert "18% 7d" in plain
    assert "23% 5h, 18% 7d" in plain
    # Reset block: single dash, comma-separated times, one shared TZ at end
    m = re.search(r"23% 5h, 18% 7d - reset \d\d:\d\d, [A-Z][a-z]{2} \d\d:\d\d [A-Za-z+:\-0-9]+", plain)
    assert m, f"expected combined reset block in: {plain!r}"
    # Trailer present
    assert "(updated at main agent response)" in plain


def test_statusline_trailer_is_ansi_dimmed():
    line = statusline.build_statusline(_envelope({
        "five_hour": {"used_percentage": 50, "resets_at": 1_800_000_000},
    }))
    assert f"{DIM}(updated at main agent response){RESET}" in line


def test_statusline_renders_only_5h_when_seven_day_missing():
    line = statusline.build_statusline(_envelope({
        "five_hour": {"used_percentage": 60, "resets_at": 1_800_000_000},
    }))
    plain = _strip_ansi(line)
    assert "60% 5h" in plain
    assert "7d" not in plain
    assert "(updated at main agent response)" in plain


def test_statusline_renders_pct_without_reset_block_when_resets_at_missing():
    line = statusline.build_statusline(_envelope({
        "five_hour": {"used_percentage": 75},
    }))
    plain = _strip_ansi(line)
    assert "75% 5h" in plain
    # No "- reset …" block when no window has a reset time
    assert " - reset " not in plain
    assert "(updated at main agent response)" in plain


def test_statusline_omits_segment_and_trailer_when_no_rate_limits():
    line = statusline.build_statusline(_envelope())
    plain = _strip_ansi(line)
    assert " 5h" not in plain
    assert " 7d" not in plain
    assert "updated at main agent response" not in plain


def test_statusline_includes_timezone_on_reset_block():
    # Render under a fixed TZ so the assertion is deterministic.
    import os
    import time
    saved_tz = os.environ.get("TZ")
    os.environ["TZ"] = "Europe/Helsinki"
    if hasattr(time, "tzset"):
        time.tzset()
    try:
        line = statusline.build_statusline(_envelope({
            "five_hour": {"used_percentage": 30, "resets_at": 1_800_000_000},
        }))
    finally:
        if saved_tz is None:
            os.environ.pop("TZ", None)
        else:
            os.environ["TZ"] = saved_tz
        if hasattr(time, "tzset"):
            time.tzset()
    plain = _strip_ansi(line)
    # Expect "30% 5h - reset HH:MM <TZ>" — TZ label after the time, alpha.
    m = re.search(r"30% 5h - reset \d\d:\d\d ([A-Za-z][A-Za-z0-9+:\-]*)", plain)
    assert m, f"expected TZ label after reset time in: {plain!r}"


def test_statusline_rate_limit_cluster_is_single_bar_segment():
    line = statusline.build_statusline(_envelope({
        "five_hour": {"used_percentage": 23, "resets_at": 1_800_000_000},
        "seven_day": {"used_percentage": 18, "resets_at": 1_800_500_000},
    }))
    plain = _strip_ansi(line)
    rl_segment = next(seg for seg in plain.split(" | ") if "5h" in seg)
    # All three pieces (5h, 7d, trailer) share one |-segment.
    assert "7d" in rl_segment
    assert "(updated at main agent response)" in rl_segment


def test_statusline_includes_model_display_name_when_present():
    line = statusline.build_statusline({
        "cwd": str(PROJECT_ROOT),
        "model": {"id": "claude-opus-4-7", "display_name": "Claude Opus 4.7"},
    })
    plain = _strip_ansi(line)
    assert "Claude Opus 4.7" in plain


def test_statusline_falls_back_to_model_id_when_display_name_missing():
    line = statusline.build_statusline({
        "cwd": str(PROJECT_ROOT),
        "model": {"id": "claude-opus-4-7"},
    })
    plain = _strip_ansi(line)
    assert "claude-opus-4-7" in plain
    assert "Claude Opus" not in plain


def test_statusline_omits_model_segment_when_envelope_lacks_model():
    line = statusline.build_statusline({"cwd": str(PROJECT_ROOT)})
    plain = _strip_ansi(line)
    parts = [p.strip() for p in plain.split("|")]
    for p in parts:
        assert "claude-" not in p.lower()
        assert "opus" not in p.lower()
        assert "sonnet" not in p.lower()
        assert "haiku" not in p.lower()


def test_model_label_returns_none_for_malformed_envelope():
    assert statusline.model_label({}) is None
    assert statusline.model_label({"model": None}) is None
    assert statusline.model_label({"model": "claude-opus"}) is None
    assert statusline.model_label({"model": {}}) is None
    assert statusline.model_label({"model": {"id": ""}}) is None


def test_repo_name_from_remote_handles_common_url_forms():
    # Direct unit test on the helper. Stub _git to return each URL form.
    saved_git = statusline._git
    try:
        urls = [
            ("https://github.com/user/agentic-framework.git", "agentic-framework"),
            ("https://github.com/user/agentic-framework/", "agentic-framework"),
            ("https://github.com/user/agentic-framework", "agentic-framework"),
            ("git@github.com:user/agentic-framework.git", "agentic-framework"),
            ("git@github.com:user/agentic-framework", "agentic-framework"),
        ]
        for url, expected in urls:
            statusline._git = lambda *a, cwd, _u=url, **kw: _u if a == ("config", "--get", "remote.origin.url") else None
            assert statusline._repo_name_from_remote("/anywhere") == expected, f"for url {url!r}"
    finally:
        statusline._git = saved_git


def test_repo_name_falls_back_when_no_remote():
    saved_git = statusline._git
    try:
        # No remote, but a toplevel exists.
        def fake_git(*args, cwd, **kw):
            if args == ("config", "--get", "remote.origin.url"):
                return None
            if args == ("rev-parse", "--show-toplevel"):
                return "/some/path/myrepo"
            return None
        statusline._git = fake_git
        assert statusline.project_name("/anywhere") == "myrepo"
    finally:
        statusline._git = saved_git


def test_project_name_uses_remote_inside_container_mountpoint():
    # Inside Docker the toplevel often resolves to "/workspace" — we want
    # the repo's actual name, parsed from the remote URL.
    saved_git = statusline._git
    try:
        def fake_git(*args, cwd, **kw):
            if args == ("config", "--get", "remote.origin.url"):
                return "https://github.com/tomgun/agentic-framework/"
            if args == ("rev-parse", "--show-toplevel"):
                return "/workspace"
            return None
        statusline._git = fake_git
        assert statusline.project_name("/workspace") == "agentic-framework"
    finally:
        statusline._git = saved_git


def test_statusline_omits_segment_when_rate_limits_present_but_pcts_missing():
    line = statusline.build_statusline(_envelope({
        "five_hour": {},
        "seven_day": {},
    }))
    plain = _strip_ansi(line)
    assert " 5h" not in plain
    assert " 7d" not in plain
    assert "updated at main agent response" not in plain


# ---------------------------------------------------------------------------
# Direct runner
# ---------------------------------------------------------------------------


if __name__ == "__main__":
    import inspect
    failures = 0
    tests = [
        (name, fn) for name, fn in globals().items()
        if name.startswith("test_") and inspect.isfunction(fn)
    ]
    for name, fn in tests:
        try:
            fn()
            print(f"  ok  {name}")
        except AssertionError as e:
            failures += 1
            print(f"FAIL  {name}: {e}")
        except Exception as e:
            failures += 1
            print(f"FAIL  {name}: {type(e).__name__}: {e}")
    print(f"\n{len(tests) - failures}/{len(tests)} passed")
    sys.exit(1 if failures else 0)
