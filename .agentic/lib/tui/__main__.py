"""
__main__ — Entry point so `python3 -m tui` launches the dashboard.

Argparse here, not in app.py, so the importable surface stays small.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

from .app import run_tui


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(prog="ag tui", description="Mission-control TUI for the agentic framework")
    p.add_argument("--journal-dir", default=".agentic/journal",
                   help="Path to the JSONL streams directory")
    p.add_argument("--feature", default="—", help="Current feature ID (display only)")
    p.add_argument("--profile", default="—", help="STACK.md profile (display only)")
    p.add_argument("--mode", default="—", help="ADR-002 mode (display only)")
    p.add_argument("--quota-window", type=int, default=None,
                   help="Pro/Max session quota window in tokens (display only)")
    p.add_argument("--from-start", action="store_true",
                   help="Replay JSONL from the start instead of tailing from EOF")
    args = p.parse_args(argv)

    try:
        return run_tui(
            journal_dir=Path(args.journal_dir),
            feature=args.feature,
            profile=args.profile,
            mode=args.mode,
            quota_window_tokens=args.quota_window,
            from_start=args.from_start,
        )
    except RuntimeError as e:
        sys.stderr.write(str(e) + "\n")
        return 2


if __name__ == "__main__":
    sys.exit(main())
