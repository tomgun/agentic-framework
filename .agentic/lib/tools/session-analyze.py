#!/usr/bin/env python3
"""session-analyze.py — Parse Claude Code JSONL session logs and detect workflow violations.

Usage:
    python3 session-analyze.py <session-log.jsonl>
    python3 session-analyze.py <session-log.jsonl> --json

Detects:
  - "stopped after plan exit": ExitPlanMode not followed by Agent spawn within 2 tool calls
  - "code before review": Write/Edit tool use when DRAFT plan exists (no APPROVED plan)
  - "skipped planning": implement trigger without prior plan mode entry

Each violation includes: type, timestamp, time wasted (gap to next user prompt).
"""

import json
import sys
import os
from datetime import datetime, timezone


def parse_jsonl(path: str) -> list[dict]:
    """Parse JSONL file, return list of message objects."""
    messages = []
    with open(path) as f:
        for line_num, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
                messages.append(obj)
            except json.JSONDecodeError:
                pass  # Skip malformed lines
    return messages


def extract_events(messages: list[dict]) -> list[dict]:
    """Extract structured events from raw JSONL messages.

    Returns list of dicts with: type, timestamp, tool_name, tool_input, text, role
    """
    events = []
    for msg in messages:
        ts_str = msg.get("timestamp")
        ts = None
        if ts_str:
            try:
                ts = datetime.fromisoformat(ts_str.replace("Z", "+00:00"))
            except (ValueError, TypeError):
                pass

        msg_type = msg.get("type")

        # User prompts
        if msg_type == "user":
            content = msg.get("message", {}).get("content", "")
            if isinstance(content, str) and not content.startswith("<local-command"):
                events.append({
                    "type": "user_prompt",
                    "timestamp": ts,
                    "text": content[:200],
                    "role": "user",
                })

        # Assistant messages (may contain tool_use blocks)
        elif msg_type in ("assistant",):
            inner = msg.get("message", {})
            content = inner.get("content", [])
            if isinstance(content, list):
                for block in content:
                    if not isinstance(block, dict):
                        continue
                    if block.get("type") == "tool_use":
                        events.append({
                            "type": "tool_use",
                            "timestamp": ts,
                            "tool_name": block.get("name", ""),
                            "tool_input": block.get("input", {}),
                            "role": "assistant",
                        })
                    elif block.get("type") == "text":
                        text = block.get("text", "")
                        if text.strip():
                            events.append({
                                "type": "assistant_text",
                                "timestamp": ts,
                                "text": text[:500],
                                "role": "assistant",
                            })

        # Tool results
        elif msg_type == "tool_result":
            pass  # We track tool_use, not results

    return events


def detect_violations(events: list[dict]) -> list[dict]:
    """Detect workflow violations in event stream."""
    violations = []
    plan_mode_exited = False
    plan_approved = False
    plan_mode_entered = False
    last_plan_exit_ts = None
    last_plan_exit_idx = None
    code_before_review_files = []  # Group consecutive violations

    for i, evt in enumerate(events):
        # Track plan mode entry
        if evt["type"] == "tool_use" and evt["tool_name"] == "EnterPlanMode":
            plan_mode_entered = True

        # Track plan mode exit
        if evt["type"] == "tool_use" and evt["tool_name"] == "ExitPlanMode":
            plan_mode_exited = True
            plan_approved = False  # Reset — plan is DRAFT after exit
            last_plan_exit_ts = evt["timestamp"]
            last_plan_exit_idx = i

        # Track plan approval (agent text with plan status APPROVED)
        if evt["type"] == "assistant_text":
            text = evt.get("text", "")
            if "Status**: APPROVED" in text or "status: APPROVED" in text.lower() or \
               "plan is APPROVED" in text or "marked APPROVED" in text:
                plan_approved = True

        # Violation 1: Stopped after plan exit
        # ExitPlanMode should be followed by Agent tool (spawning reviewers) within ~3 tool calls
        if plan_mode_exited and last_plan_exit_idx is not None:
            # Look at the next few events after plan exit
            if evt["type"] == "user_prompt" and i > last_plan_exit_idx:
                # User had to prompt again — agent stopped and waited
                tool_calls_between = [
                    e for e in events[last_plan_exit_idx + 1:i]
                    if e["type"] == "tool_use"
                ]
                agent_spawned = any(
                    e["tool_name"] == "Agent" for e in tool_calls_between
                )
                if not agent_spawned and len(tool_calls_between) < 5:
                    time_wasted = None
                    if last_plan_exit_ts and evt["timestamp"]:
                        time_wasted = (evt["timestamp"] - last_plan_exit_ts).total_seconds()
                    violations.append({
                        "type": "stopped_after_plan_exit",
                        "description": "Agent stopped after ExitPlanMode instead of auto-continuing to review",
                        "timestamp": _fmt_ts(last_plan_exit_ts),
                        "time_wasted_seconds": time_wasted,
                        "user_prompt": evt.get("text", "")[:100],
                    })
                    plan_mode_exited = False  # Reset to avoid duplicate detection

        # Violation 2: Code before review (grouped — one violation per draft phase, not per file)
        if evt["type"] == "tool_use" and evt["tool_name"] in ("Write", "Edit", "MultiEdit"):
            file_path = evt.get("tool_input", {}).get("file_path", "")
            # Skip spec/test/plan files and framework state files
            if file_path and not _is_allowlisted(file_path):
                if plan_mode_exited and not plan_approved:
                    code_before_review_files.append(file_path)

        # When plan gets approved or new plan mode entered, flush grouped violations
        if plan_approved and code_before_review_files:
            violations.append({
                "type": "code_before_review",
                "description": f"Writing code before plan APPROVED ({len(code_before_review_files)} files)",
                "timestamp": _fmt_ts(last_plan_exit_ts),
                "files": code_before_review_files[:20],  # Cap list
            })
            code_before_review_files = []

        # Violation 3: Skipped planning
        if evt["type"] == "tool_use" and evt["tool_name"] == "Bash":
            cmd = evt.get("tool_input", {}).get("command", "")
            if "ag implement" in cmd or "ag.sh implement" in cmd:
                if not plan_mode_entered:
                    violations.append({
                        "type": "skipped_planning",
                        "description": "ag implement called without prior plan mode entry",
                        "timestamp": _fmt_ts(evt["timestamp"]),
                    })

    # Flush any remaining grouped code_before_review violations
    if code_before_review_files:
        violations.append({
            "type": "code_before_review",
            "description": f"Writing code before plan APPROVED ({len(code_before_review_files)} files)",
            "timestamp": _fmt_ts(last_plan_exit_ts),
            "files": code_before_review_files[:20],
        })

    return violations


def _is_allowlisted(path: str) -> bool:
    """Check if file path is in the allowlist (spec, test, plan, journal)."""
    parts = path.lower()
    for prefix in ("spec/", "tests/", "test/", "/tests/", "/test/",
                    "journal/", ".agentic/session/",
                    "memory/", ".agentic/todo", ".agentic/status",
                    ".agentic/human_needed", ".agentic/contributions",
                    "backlog.json", "features.md", "issues.md",
                    "changelog", "stack.md", "overview.md"):
        if prefix in parts:
            return True
    if path.endswith("-plan.md"):
        return True
    if ".claude/plans/" in path or ".cursor/plans/" in path:
        return True
    return False


def _fmt_ts(ts) -> str:
    """Format timestamp for display."""
    if ts is None:
        return "unknown"
    return ts.strftime("%H:%M:%S")


def build_timeline(events: list[dict]) -> list[dict]:
    """Build a simplified timeline of key events."""
    timeline = []
    for evt in events:
        if evt["type"] == "user_prompt":
            timeline.append({
                "time": _fmt_ts(evt["timestamp"]),
                "actor": "User",
                "action": evt.get("text", "")[:80],
            })
        elif evt["type"] == "tool_use":
            name = evt["tool_name"]
            if name in ("ExitPlanMode", "EnterPlanMode", "Agent", "Write", "Edit",
                        "MultiEdit", "Bash", "Skill"):
                detail = ""
                if name == "Bash":
                    detail = evt.get("tool_input", {}).get("command", "")[:60]
                elif name == "Agent":
                    detail = evt.get("tool_input", {}).get("description", "")[:60]
                elif name in ("Write", "Edit"):
                    detail = evt.get("tool_input", {}).get("file_path", "")[:60]
                elif name == "Skill":
                    detail = evt.get("tool_input", {}).get("skill", "")[:60]
                timeline.append({
                    "time": _fmt_ts(evt["timestamp"]),
                    "actor": "Agent",
                    "action": f"{name}: {detail}" if detail else name,
                })
    return timeline


def print_report(violations: list[dict], timeline: list[dict], path: str):
    """Print human-readable analysis report."""
    print(f"\n{'='*60}")
    print(f"Session Analysis: {os.path.basename(path)}")
    print(f"{'='*60}\n")

    # Timeline
    print("## Timeline (key events)\n")
    print(f"{'Time':<12} {'Actor':<8} {'Action'}")
    print(f"{'-'*10}   {'-'*6}   {'-'*40}")
    for entry in timeline[:50]:  # Cap at 50 entries
        print(f"{entry['time']:<12} {entry['actor']:<8} {entry['action']}")

    # Violations
    print(f"\n## Violations ({len(violations)} found)\n")
    if not violations:
        print("No workflow violations detected.")
    else:
        total_wasted = 0
        for i, v in enumerate(violations, 1):
            print(f"### Violation {i}: {v['type']}")
            print(f"  Time: {v.get('timestamp', 'unknown')}")
            print(f"  Description: {v['description']}")
            if v.get("time_wasted_seconds"):
                mins = v["time_wasted_seconds"] / 60
                total_wasted += v["time_wasted_seconds"]
                print(f"  Time wasted: {mins:.1f} minutes")
            if v.get("user_prompt"):
                print(f"  User prompt: {v['user_prompt']}")
            if v.get("file_path"):
                print(f"  File: {v['file_path']}")
            if v.get("files"):
                print(f"  Files ({len(v['files'])}): {', '.join(v['files'][:5])}")
                if len(v['files']) > 5:
                    print(f"    ... and {len(v['files']) - 5} more")
            print()

        print(f"## Summary")
        print(f"  Total violations: {len(violations)}")
        types = {}
        for v in violations:
            types[v["type"]] = types.get(v["type"], 0) + 1
        for t, c in types.items():
            print(f"    {t}: {c}")
        if total_wasted > 0:
            print(f"  Total time wasted: {total_wasted / 60:.1f} minutes")


def print_json_report(violations: list[dict], timeline: list[dict], path: str):
    """Print machine-readable JSON report."""
    total_wasted = sum(v.get("time_wasted_seconds", 0) or 0 for v in violations)
    report = {
        "session": os.path.basename(path),
        "violations": violations,
        "violation_count": len(violations),
        "total_time_wasted_seconds": total_wasted,
        "timeline_events": len(timeline),
    }
    print(json.dumps(report, indent=2, default=str))


def main():
    if len(sys.argv) < 2 or sys.argv[1] in ("-h", "--help"):
        print(__doc__)
        sys.exit(0)

    path = sys.argv[1]
    json_mode = "--json" in sys.argv

    if not os.path.isfile(path):
        print(f"Error: File not found: {path}", file=sys.stderr)
        sys.exit(1)

    messages = parse_jsonl(path)
    if not messages:
        print(f"Error: No valid JSONL messages found in {path}", file=sys.stderr)
        sys.exit(1)

    events = extract_events(messages)
    violations = detect_violations(events)
    timeline = build_timeline(events)

    if json_mode:
        print_json_report(violations, timeline, path)
    else:
        print_report(violations, timeline, path)

    sys.exit(1 if violations else 0)


if __name__ == "__main__":
    main()
