"""
drilldown.py — Drill-down detail panel (R-008 AC5).

Keyboard `d` selects an event and the drilldown panel expands its details:
diff, test output, contract assertions, decision rationale. The full record
is in events.jsonl on disk; this panel reads from the snapshot's
`selected_event` field which is set by `DashboardState.select_event(idx)`.
"""
from __future__ import annotations

from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from ..state import DashboardSnapshot


def drilldown_lines(snap: "DashboardSnapshot") -> list[str]:
    sel = snap.selected_event
    if sel is None:
        return ["(no event selected — press `d` on a row)"]
    return [
        f"timestamp : {sel.ts}",
        f"type      : {sel.type}",
        f"actor     : {sel.actor}",
        f"feature   : {sel.feature}",
        f"summary   : {sel.summary}",
        f"cost      : {sel.cost_tokens or 0} tokens",
        f"color     : {sel.color_hint}",
    ]


def make_panel():
    from textual.widgets import Static  # type: ignore

    class DrilldownPanel(Static):
        DEFAULT_CSS = "DrilldownPanel { height: auto; min-height: 8; border: solid $secondary; padding: 0 1; }"

        def update_from(self, snap: "DashboardSnapshot") -> None:
            self.update("DRILL-DOWN\n" + "\n".join(drilldown_lines(snap)))

    return DrilldownPanel("")
