"""
header.py — Top header panel (R-008 AC1).

Shows: feature ID, profile, mode, total tokens (vs quota %), elapsed, ETA.
The pure `header_lines(snapshot)` function returns formatted strings that
both the Textual widget and the unit tests consume.
"""
from __future__ import annotations

from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from ..state import DashboardSnapshot


def _fmt_duration(seconds: int) -> str:
    if seconds <= 0:
        return "0s"
    m, s = divmod(seconds, 60)
    h, m = divmod(m, 60)
    if h:
        return f"{h}h{m:02d}m"
    if m:
        return f"{m}m{s:02d}s"
    return f"{s}s"


def header_lines(snap: "DashboardSnapshot") -> list[str]:
    h = snap.header
    parts = [
        f"feature={h.feature}",
        f"profile={h.profile}",
        f"mode={h.mode}",
    ]
    if h.quota_window_tokens and h.quota_pct is not None:
        parts.append(f"tokens={h.tokens_total:,} ({h.quota_pct:.0f}%)")
    else:
        parts.append(f"tokens={h.tokens_total:,}")
    parts.append(f"elapsed={_fmt_duration(h.elapsed_seconds)}")
    if h.eta_seconds is not None:
        parts.append(f"ETA={_fmt_duration(h.eta_seconds)}")
    return ["  |  ".join(parts)]


# ---------------------------------------------------------------------------
# Textual widget — lazy imports so the module is importable without Textual
# ---------------------------------------------------------------------------


def make_panel():
    """Construct the Textual widget. Raises ImportError if Textual missing."""
    from textual.widgets import Static  # type: ignore

    class HeaderPanel(Static):
        DEFAULT_CSS = "HeaderPanel { dock: top; height: 1; padding: 0 1; background: $primary-darken-2; color: $text; }"

        def update_from(self, snap: "DashboardSnapshot") -> None:
            self.update("\n".join(header_lines(snap)))

    return HeaderPanel("")
