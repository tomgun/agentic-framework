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
    from .panels.quota_alert import make_modal_screen, should_show_modal

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
            self._prev_quota_alert: Optional[str] = None
            self._quota_modal_acknowledged = False
            self._QuotaAlertScreen = make_modal_screen()

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
            # Quota tick handles the tooltip rebuild + health resync. Token
            # ledger doesn't change shape often, so 30s is plenty. set_interval
            # doesn't fire immediately on register, so seed once now so the
            # tooltip isn't empty until the first 30s tick.
            self.set_interval(30.0, self._refresh_quota_only)
            self._refresh_quota_only()

        def on_unmount(self) -> None:  # type: ignore[override]
            tail.stop()

        def _refresh(self) -> None:
            snap = state.snapshot()
            for w in (self._header, self._workers, self._events,
                      self._drilldown, self._health):
                if w is not None:
                    w.update_from(snap)
            # Modal trigger lives on the fast tick so the rising edge to 95%
            # is caught within ~0.5s rather than waiting up to 30s for the
            # quota refresh — the underlying snapshot data is already fresh
            # via the streams tail.
            self._maybe_show_quota_modal(snap)

        def _refresh_quota_only(self) -> None:
            """Quota-specific 30s tick — refreshes the by-tier tooltip on the
            header (more expensive than the line text) and lets the health
            panel resync. The modal trigger runs on the 0.5s `_refresh`
            tick (see `_maybe_show_quota_modal`)."""
            snap = state.snapshot()
            if self._header is not None:
                self._header.update_tooltip_from(snap)
            if self._health is not None:
                self._health.update_from(snap)

        def _maybe_show_quota_modal(self, snap) -> None:
            """Push the 95% modal on rising edge. Reset acknowledgement when
            the alert level drops below 95% so the next episode re-prompts."""
            cur = snap.health.quota_alert
            if cur != "95%":
                self._quota_modal_acknowledged = False
            if should_show_modal(self._prev_quota_alert, cur,
                                 self._quota_modal_acknowledged):
                # Default fallback: the alert is "95%" so quota_pct must be
                # >= 95.0; this branch only runs in pathological races where
                # the snapshot lost it. Use an explicit None check so a
                # legitimate 0.0 reading wouldn't fall back to 95.
                pct = snap.header.quota_pct if snap.header.quota_pct is not None else 95.0
                self.push_screen(
                    self._QuotaAlertScreen(pct=pct),
                    self._handle_quota_modal_choice,
                )
            self._prev_quota_alert = cur

        def _handle_quota_modal_choice(self, choice) -> None:
            self._quota_modal_acknowledged = True
            if choice == "abort":
                self.action_abort()

        # --- key actions ---

        def action_help(self) -> None:
            self.notify(
                "q quit · ? help · a abort · d drill · j/k navigate · / filter",
                title="ag tui",
            )

        def action_abort(self) -> None:
            # R-014 ships the modal that calls into here; the actual signal-
            # to-lead-PID wiring is tracked under R-209. Until then this is
            # a notify so the user sees a confirmation that the modal's
            # Abort path was reached.
            self.notify(
                "Abort acknowledged. Signal-to-lead-PID wiring lands in "
                "R-209; press q to quit this dashboard now.",
                title="ag tui · abort",
                severity="warning",
            )

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
