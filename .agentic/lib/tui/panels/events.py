"""
events.py — Live event stream panel (R-008 AC3).

Color-coded recent events with optional cost annotations. Color hint comes
from `state.color_hint_for()` so panels stay dumb.
"""
from __future__ import annotations

from typing import TYPE_CHECKING, Iterable

if TYPE_CHECKING:
    from ..state import DashboardSnapshot, EventSnapshot


def _hhmmss(ts_iso: str) -> str:
    # events.jsonl uses ISO8601 with 'T' separator and trailing Z.
    if not ts_iso or "T" not in ts_iso:
        return "--:--:--"
    after_t = ts_iso.split("T", 1)[1]
    return after_t[:8] if len(after_t) >= 8 else after_t


def _fmt_cost(cost: object) -> str:
    if isinstance(cost, int) and cost > 0:
        return f"{cost:>5}t"
    return "      "


def event_lines(snap: "DashboardSnapshot", *, max_rows: int = 20) -> list[tuple[str, str]]:
    """Returns [(line, color_hint)]; consumer decides how to color.
    Most recent last (matches scrollback intuition)."""
    events = snap.events[-max_rows:]
    return [
        (
            f"{_hhmmss(ev.ts)}  {ev.type:<16} {ev.summary[:60]:<60} {_fmt_cost(ev.cost_tokens)}",
            ev.color_hint,
        )
        for ev in events
    ]


def filter_events(events: Iterable["EventSnapshot"], *,
                  rec_type: str = "", actor: str = "",
                  feature: str = "") -> list["EventSnapshot"]:
    """Composable filter — used by the events panel for its keyboard filters."""
    out = []
    for ev in events:
        if rec_type and ev.type != rec_type:
            continue
        if actor and ev.actor != actor:
            continue
        if feature and ev.feature != feature:
            continue
        out.append(ev)
    return out


def make_panel():
    from textual.widgets import Static  # type: ignore

    class EventsPanel(Static):
        DEFAULT_CSS = "EventsPanel { height: 1fr; border: solid $primary; padding: 0 1; }"

        def update_from(self, snap: "DashboardSnapshot") -> None:
            rows = event_lines(snap)
            body = "EVENTS\n" + "\n".join(line for line, _ in rows)
            self.update(body)

    return EventsPanel("")
