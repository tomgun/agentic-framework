---
name: session-start
description: >
  Initialize session, check for interrupted work, show dashboard with current
  status and suggested next steps. Use when: first message in conversation,
  user says "start", "where were we", "what's the status", "ag start",
  or returns after being away.
  Do NOT use for: mid-session tasks, implementing features, committing code.
compatibility: "Requires Claude Code with shell access and ag commands."
allowed-tools: [Read, Bash]
metadata:
  author: agentic-framework
  version: "0.62.0"
---
# Session Start

Run `bash .agentic/lib/tools/dashboard.sh 2>/dev/null` — ONE tool call, nothing else.

Output the result **verbatim** as your first text response.
No preamble, no narration, no reformatting.

After outputting the dashboard, note any critical flags:
- Upgrade pending (needs handling before new work)
- Interrupted work (focus on recovery)
- Memory stale (action item)
