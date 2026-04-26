"""
panels — Five mission-control panels (R-008).

Every module exposes a pure-Python `*_lines(snapshot)` function that returns
a list of pre-formatted lines/tuples. Tests target those directly. The
Textual widget classes (e.g., `HeaderPanel`) wrap the same data via lazy
import — running them requires `pip install textual`.
"""
from __future__ import annotations

from .header import header_lines  # noqa: F401  (re-export)
from .workers import worker_lines  # noqa: F401
from .events import event_lines  # noqa: F401
from .health import health_lines  # noqa: F401
from .drilldown import drilldown_lines  # noqa: F401

__all__ = ["header_lines", "worker_lines", "event_lines", "health_lines", "drilldown_lines"]
