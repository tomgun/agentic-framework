"""
health.py — Health bar panel (R-008 AC4).

Green/yellow/red status, escalation count, quota threshold alert.
"""
from __future__ import annotations

from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from ..state import DashboardSnapshot


_STATUS_GLYPH = {"green": "✓", "yellow": "⚠", "red": "✗"}


def health_lines(snap: "DashboardSnapshot") -> list[str]:
    h = snap.health
    glyph = _STATUS_GLYPH.get(h.status, "?")
    parts = [f"{glyph} {h.status.upper()}"]
    if h.escalations:
        parts.append(f"escalations={h.escalations}")
    if h.last_blocked_reason:
        parts.append(f"last block: {h.last_blocked_reason}")
    if h.quota_alert:
        parts.append(f"quota {h.quota_alert}")
    return ["  |  ".join(parts)]


def make_panel():
    from textual.widgets import Static  # type: ignore

    class HealthPanel(Static):
        DEFAULT_CSS = "HealthPanel { dock: bottom; height: 1; padding: 0 1; background: $primary-darken-3; }"

        def update_from(self, snap: "DashboardSnapshot") -> None:
            self.update("\n".join(health_lines(snap)))

    return HealthPanel("")
