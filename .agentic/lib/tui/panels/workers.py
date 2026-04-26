"""
workers.py — Active worker panel (R-008 AC2).

One row per active actor with: status indicator, current step, time on task.
Reads `events.jsonl` filtered by `type=session_start/end + tool_call` —
projection done in `state.py`; this panel only formats.
"""
from __future__ import annotations

from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from ..state import DashboardSnapshot


def _fmt_busy(seconds: int) -> str:
    if seconds <= 0:
        return "0s"
    if seconds < 60:
        return f"{seconds}s"
    m, s = divmod(seconds, 60)
    if m < 60:
        return f"{m}m{s:02d}s"
    h, m = divmod(m, 60)
    return f"{h}h{m:02d}m"


def worker_lines(snap: "DashboardSnapshot") -> list[str]:
    if not snap.workers:
        return ["(no active workers)"]
    out: list[str] = []
    for w in snap.workers:
        # ◉ active   ◐ partial    ○ idle
        marker = "◉"
        # Strip newlines from current_step so it stays one row.
        step = w.current_step.replace("\n", " ").strip()[:60]
        out.append(f"{marker} {w.actor:<20} {step:<60} [{_fmt_busy(w.busy_seconds)}]")
    return out


def make_panel():
    from textual.widgets import Static  # type: ignore

    class WorkersPanel(Static):
        DEFAULT_CSS = "WorkersPanel { height: auto; min-height: 4; border: solid $accent; padding: 0 1; }"

        def update_from(self, snap: "DashboardSnapshot") -> None:
            body = "WORKERS\n" + "\n".join(worker_lines(snap))
            self.update(body)

    return WorkersPanel("")
