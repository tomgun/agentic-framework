"""
header.py — Top header panel (R-008 AC1, R-014 ring + colors + tooltip).

Shows: feature ID, profile, mode, total tokens with quota burn-down ring,
elapsed, ETA. The pure `header_lines(snapshot)` function returns Rich-markup
strings that both the Textual widget and the unit tests consume. Tests
inspect substrings (percentages, ring chars, color tags); the Textual
Static widget renders the markup as colored text.

R-014 additions:
  * `_ring_segment(pct)` — Unicode quarter-circle progression (○◔◐◕●).
  * `_color_for_pct(pct)` — alert-level color: green<70, yellow<85,
    dark_orange<95, red≥95. Returned as a Rich color name; callers wrap
    text in `[name]…[/]` markup.
  * `header_lines` emits the colored ring next to the percentage when a
    quota window is configured.
  * The Textual `HeaderPanel` widget sets a tooltip with by-tier breakdown
    pulled from `snap.header.by_tier`.
"""
from __future__ import annotations

from typing import TYPE_CHECKING, Optional

if TYPE_CHECKING:
    from ..state import DashboardSnapshot


# Quarter-circle progression. Each step covers a 25% fill band. 100% lands
# on the filled disc.
_RING_CHARS: tuple[tuple[float, str], ...] = (
    (1.0, "○"),    # 0% — empty disc
    (25.0, "◔"),   # 1–24% — one-quarter
    (50.0, "◐"),   # 25–49% — half
    (75.0, "◕"),   # 50–74% — three-quarter
    (101.0, "●"),  # 75–100% — full
)


def _ring_segment(pct: Optional[float]) -> str:
    """Return the Unicode ring char for `pct` (0–100). None → empty disc."""
    if pct is None:
        return "○"
    for upper, char in _RING_CHARS:
        if pct < upper:
            return char
    return "●"


def _color_for_pct(pct: Optional[float]) -> Optional[str]:
    """Return Rich color name for `pct`. None when no ceiling / safe band."""
    if pct is None:
        return None
    if pct >= 95.0:
        return "red"
    if pct >= 85.0:
        return "dark_orange"
    if pct >= 70.0:
        return "yellow"
    return "green"


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
    """Return the header line(s) as Rich-markup strings.

    When the snapshot has a quota window, the percentage is rendered as a
    colored ring (`◔ 25%`) wrapped in `[<color>]…[/]` so Textual prints it
    in the alert color. Without a window, the raw token count is shown.
    """
    h = snap.header
    parts = [
        f"feature={h.feature}",
        f"profile={h.profile}",
        f"mode={h.mode}",
    ]
    if h.quota_window_tokens and h.quota_pct is not None:
        ring = _ring_segment(h.quota_pct)
        color = _color_for_pct(h.quota_pct)
        pct_str = f"{h.quota_pct:.0f}%"
        if color:
            parts.append(
                f"tokens={h.tokens_total:,} [bold {color}]{ring} {pct_str}[/]"
            )
        else:
            parts.append(f"tokens={h.tokens_total:,} {ring} {pct_str}")
    else:
        parts.append(f"tokens={h.tokens_total:,}")
    parts.append(f"elapsed={_fmt_duration(h.elapsed_seconds)}")
    if h.eta_seconds is not None:
        parts.append(f"ETA={_fmt_duration(h.eta_seconds)}")
    return ["  |  ".join(parts)]


def by_tier_tooltip(snap: "DashboardSnapshot") -> str:
    """Format the by-tier breakdown for the header tooltip (R-014 AC3).

    Empty when no token-ledger entries have been ingested yet.
    """
    by_tier = snap.header.by_tier or {}
    total = snap.header.tokens_total
    if not by_tier:
        return "No token-ledger records yet."
    lines = ["Token usage by tier:"]
    for tier in sorted(by_tier):
        tokens = by_tier[tier]
        pct = f" ({100.0 * tokens / total:.1f}%)" if total else ""
        lines.append(f"  {tier:<10} {tokens:>10,}{pct}")
    return "\n".join(lines)


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
            self.tooltip = by_tier_tooltip(snap)

    return HeaderPanel("")
