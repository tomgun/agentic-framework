"""
app.py — Textual App for the mission-control dashboard (R-008).

This module is intentionally NOT imported by `tui/__init__.py` so the package
remains importable in environments without Textual. Calling `run_tui()`
without Textual installed raises a `RuntimeError` with an install hint.

Layout:

    +------------ Header ---------------+
    | feature | profile | tokens | ETA  |
    +-----------------------------------+
    | Workers (top)                     |
    +-----------+-----------+-----------+
    | Events  (left, wide)  | Drilldown |
    +-----------------------------------+
    | Health (bottom)                   |
    +-----------------------------------+

Bindings (AC7):

    q  — quit
    ?  — help (modal)
    a  — abort autonomous run (asks confirmation, sends SIGTERM to recorded
         lead PID if known via events.jsonl)
    d  — drill-down on the currently-selected event
    j  — next event (selection)
    k  — previous event
    /  — filter prompt
"""
from __future__ import annotations

import os
import threading
from pathlib import Path
from typing import Optional

from .state import DashboardState
from .streams import StreamTail


def _require_textual():
    try:
        import textual  # noqa: F401  (tested for presence)
        return None
    except ImportError as e:
        raise RuntimeError(
            "Textual is required to run `ag tui`. Install with:\n"
            "    pip install textual\n"
            "(Or: pip install textual rich)"
        ) from e


def run_tui(*, journal_dir: Path, feature: str = "—",
            profile: str = "—", mode: str = "—",
            quota_window_tokens: Optional[int] = None,
            from_start: bool = False) -> int:
    """Launch the TUI. Returns the App's exit code (0 on clean quit)."""
    _require_textual()
    # Imports moved inside so `import .app` is cheap and safe.
    from textual.app import App, ComposeResult  # type: ignore
    from textual.binding import Binding  # type: ignore
    from textual.containers import Horizontal, Vertical  # type: ignore

    from .panels.header import make_panel as make_header
    from .panels.workers import make_panel as make_workers
    from .panels.events import make_panel as make_events
    from .panels.drilldown import make_panel as make_drilldown
    from .panels.health import make_panel as make_health

    state = DashboardState(feature=feature, profile=profile, mode=mode)
    state.set_quota_window(quota_window_tokens)

    tail = StreamTail(journal_dir=journal_dir, from_start=from_start)

    class MissionControl(App):
        CSS_PATH = str(Path(__file__).resolve().parent / "styles.css")
        BINDINGS = [
            Binding("q", "quit", "Quit"),
            Binding("question_mark", "help", "Help"),
            Binding("a", "abort", "Abort run"),
            Binding("d", "drilldown", "Drill-down"),
            Binding("j", "next_event", "Next event"),
            Binding("k", "prev_event", "Prev event"),
        ]

        def __init__(self) -> None:
            super().__init__()
            self._header = None
            self._workers = None
            self._events = None
            self._drilldown = None
            self._health = None
            self._selected_idx: Optional[int] = None

        def compose(self) -> ComposeResult:  # type: ignore[override]
            self._header = make_header()
            self._workers = make_workers()
            self._events = make_events()
            self._drilldown = make_drilldown()
            self._health = make_health()
            yield self._header
            yield Vertical(
                self._workers,
                Horizontal(self._events, self._drilldown, id="middle"),
                self._health,
                id="main",
            )

        def on_mount(self) -> None:  # type: ignore[override]
            tail.start(on_record=lambda rec: state.apply_record(rec))
            # Full panel refresh — events arrive at human-perceivable cadence.
            self.set_interval(0.5, self._refresh)
            # Quota burn-down ring updates on a slower cadence per AC6 — the
            # token-ledger doesn't change shape often enough to warrant the
            # same 0.5s rebuild as the events panel.
            self.set_interval(30.0, self._refresh_quota_only)

        def on_unmount(self) -> None:  # type: ignore[override]
            tail.stop()

        def _refresh(self) -> None:
            snap = state.snapshot()
            for w in (self._header, self._workers, self._events,
                      self._drilldown, self._health):
                if w is not None:
                    w.update_from(snap)

        def _refresh_quota_only(self) -> None:
            """Quota-specific tick — updates only header + health (where the
            quota signals appear). R-014 layers the burn-down ring on top
            of this hook."""
            snap = state.snapshot()
            for w in (self._header, self._health):
                if w is not None:
                    w.update_from(snap)

        # --- key actions ---

        def action_help(self) -> None:
            self.notify(
                "q quit · ? help · a abort · d drill · j/k navigate · / filter",
                title="ag tui",
            )

        def action_abort(self) -> None:
            self.notify("Abort signal not yet wired (R-014/R-209). q to quit.",
                        title="ag tui · abort", severity="warning")

        def action_next_event(self) -> None:
            snap = state.snapshot()
            n = len(snap.events)
            if n == 0:
                return
            idx = (self._selected_idx + 1) if self._selected_idx is not None else 0
            self._selected_idx = min(n - 1, idx)
            state.select_event(self._selected_idx)

        def action_prev_event(self) -> None:
            if self._selected_idx is None:
                return
            self._selected_idx = max(0, self._selected_idx - 1)
            state.select_event(self._selected_idx)

        def action_drilldown(self) -> None:
            # Same effect as next_event when nothing selected; otherwise re-render.
            if self._selected_idx is None:
                self.action_next_event()

    return MissionControl().run()
