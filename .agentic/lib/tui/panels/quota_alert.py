"""
quota_alert.py — Modal alert for the 95% quota threshold (R-014 AC4).

Pure-logic side (`should_show_modal`) is testable without Textual; the
Textual side (`make_modal_screen`) is constructed lazily so this module
imports cleanly in environments without Textual installed.

Triggering policy:
  * Rising edge to 95% pushes the modal once per episode.
  * Acknowledgement (or modal dismissal) marks the episode handled — the
    modal does not re-show on every 30s tick.
  * If the alert level drops below 95% and rises again, that's a new
    episode and the modal fires again.

The Abort button calls the host App's `action_abort` — currently a notify
placeholder pending real signal-to-lead-PID wiring (tracked under R-209).
The modal therefore delivers the user-facing prompt today and the abort
side becomes real once R-209 lands without further changes here.
"""
from __future__ import annotations

from typing import Optional


def should_show_modal(
    prev_alert: Optional[str],
    cur_alert: Optional[str],
    acknowledged: bool,
) -> bool:
    """Return True iff a fresh 95% episode warrants showing the modal.

    `acknowledged` tracks whether the user has dismissed the modal for the
    current 95% episode; the caller resets it to False whenever
    `cur_alert` drops below 95%.
    """
    if cur_alert != "95%":
        return False
    if acknowledged:
        return False
    return prev_alert != "95%"


def make_modal_screen():
    """Construct the Textual ModalScreen class. Raises ImportError if
    Textual missing."""
    from textual.app import ComposeResult  # type: ignore
    from textual.containers import Vertical  # type: ignore
    from textual.screen import ModalScreen  # type: ignore
    from textual.widgets import Button, Static  # type: ignore

    class QuotaAlertScreen(ModalScreen):
        DEFAULT_CSS = """
        QuotaAlertScreen { align: center middle; }
        QuotaAlertScreen > Vertical {
            width: 60;
            height: auto;
            padding: 1 2;
            background: $panel;
            border: thick $error;
        }
        QuotaAlertScreen Static.title { text-style: bold; color: $error; }
        QuotaAlertScreen Static.body { padding: 1 0; }
        QuotaAlertScreen Button { margin: 0 1; }
        """

        def __init__(self, *, pct: float) -> None:
            super().__init__()
            self._pct = pct

        def compose(self) -> ComposeResult:  # type: ignore[override]
            yield Vertical(
                Static("⚠ Quota at 95%", classes="title"),
                Static(
                    f"Current usage is {self._pct:.0f}% of the configured "
                    "Pro/Max window ceiling. Continuing risks hitting the "
                    "rate limit mid-run.\n\nAbort the autonomous run now?",
                    classes="body",
                ),
                Button("Abort run", id="abort", variant="error"),
                Button("Acknowledge & continue", id="ack", variant="primary"),
            )

        def on_button_pressed(self, event) -> None:  # type: ignore[override]
            choice = event.button.id
            self.dismiss(choice)

    return QuotaAlertScreen
