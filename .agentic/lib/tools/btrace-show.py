#!/usr/bin/env python3
"""btrace-show.py — Render behavioral trace as human-readable timeline.

Usage:
    python3 btrace-show.py <trace.jsonl> [--hook <name>] [--decision <allow|deny>] [--feature <id>]
"""

import json
import sys
from pathlib import Path

# ANSI colors
RED = "\033[0;31m"
GREEN = "\033[0;32m"
YELLOW = "\033[1;33m"
DIM = "\033[2m"
BOLD = "\033[1m"
NC = "\033[0m"


def render_timeline(trace_file: str, hook_filter: str = "", decision_filter: str = "") -> None:
    path = Path(trace_file)
    if not path.exists():
        print(f"{RED}File not found: {trace_file}{NC}", file=sys.stderr)
        sys.exit(1)

    events = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                events.append(json.loads(line))
            except json.JSONDecodeError:
                continue

    if not events:
        print("No events in trace file.")
        return

    # Header
    first_ts = events[0].get("ts", "?")
    last_ts = events[-1].get("ts", "?")
    total_denials = sum(
        1 for e in events if e.get("data", {}).get("decision") == "deny"
    )
    print(f"{BOLD}=== Behavioral Trace ({len(events)} events, {total_denials} denials) ==={NC}")
    print(f"{DIM}    {first_ts} → {last_ts}{NC}")
    print()

    for event in events:
        hook = event.get("hook", "?")
        phase = event.get("phase", "?")
        ts = event.get("ts", "?")
        data = event.get("data", {})

        # Apply filters
        if hook_filter and hook != hook_filter:
            continue
        decision = data.get("decision", "")
        if decision_filter and decision != decision_filter:
            continue

        # Format time
        time_part = ts.split("T")[1].rstrip("Z") if "T" in ts else ts

        # Color based on decision
        color = NC
        marker = ""
        if decision == "deny":
            color = RED
            marker = f" {RED}*** DENY ***{NC}"
        elif decision == "allow":
            color = GREEN

        # Build detail string
        details = []
        if "tool" in data:
            details.append(f"tool={data['tool']}")
        if "reason" in data and data["reason"]:
            details.append(f'reason="{data["reason"]}"')
        elif "reasons" in data and data["reasons"]:
            reasons_str = "; ".join(str(r) for r in data["reasons"][:2])
            details.append(f'reasons="{reasons_str}"')
        if "duration_ms" in data:
            details.append(f"{data['duration_ms']}ms")
        if "matches" in data:
            details.append(f"{data['matches']} pattern(s)")
        if "reads" in data:
            details.append(f"reads={data['reads']}")
        if "writes" in data:
            details.append(f"writes={data['writes']}")
        if "profile" in data:
            details.append(f"profile={data['profile']}")
        if "version" in data and data["version"] != "unknown":
            details.append(f"v{data['version']}")
        if "btrace_level" in data:
            details.append(f"btrace={data['btrace_level']}")
        if "exit_code" in data and decision:
            details.append(f"exit={data['exit_code']}")

        detail_str = f"  {DIM}{', '.join(details)}{NC}" if details else ""

        print(
            f"  {DIM}[{time_part}]{NC} {color}{hook:<25s} {phase:<20s}{NC}{marker}{detail_str}"
        )


def main() -> None:
    if len(sys.argv) < 2 or sys.argv[1] in ("--help", "-h"):
        print(__doc__)
        sys.exit(0)

    trace_file = sys.argv[1]
    hook_filter = ""
    decision_filter = ""

    i = 2
    while i < len(sys.argv):
        if sys.argv[i] == "--hook" and i + 1 < len(sys.argv):
            hook_filter = sys.argv[i + 1]
            i += 2
        elif sys.argv[i] == "--decision" and i + 1 < len(sys.argv):
            decision_filter = sys.argv[i + 1]
            i += 2
        else:
            i += 1

    render_timeline(trace_file, hook_filter, decision_filter)


if __name__ == "__main__":
    main()
