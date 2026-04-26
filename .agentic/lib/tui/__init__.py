"""
tui — Mission-control TUI for the agentic framework (R-008).

Architecture:

  * `streams`  — pure-stdlib JSONL tailer. Reads events.jsonl /
                 delegation.jsonl / token-ledger.jsonl as they're appended.
                 No Textual / Rich dependency.

  * `state`    — pure-Python aggregator. Consumes parsed records from the
                 streams, projects per-panel state (active workers, recent
                 events ring, health status, token totals).

  * `panels.*` — five panel widgets that read from `state` and render via
                 Textual. Textual imports are lazy so the *package* is
                 importable without it; only running `ag tui` requires the
                 user to `pip install textual`.

  * `app`      — Textual App glue. Wires the tailer (running on a worker
                 thread) into `state`, then refreshes panels on a tick.

The split keeps tests runnable in environments without Textual installed
(this dev container; CI mirror images). Tests target streams, state, and
the panel data-shaping logic; the Textual rendering layer itself is
verified manually per the backlog's verify steps.

Public surface:

    from agentic.tui.state import DashboardState
    from agentic.tui.streams import StreamTail, StreamRecord
    from agentic.tui.app import run_tui     # raises RuntimeError if Textual
                                            # missing, with install hint
"""
from __future__ import annotations

__all__ = ["DashboardState", "StreamTail", "StreamRecord"]

# Re-export pure-Python layer; the app module is intentionally NOT imported
# here so the package stays importable when Textual is missing.
from .state import DashboardState  # noqa: F401  (re-export)
from .streams import StreamTail, StreamRecord  # noqa: F401  (re-export)
