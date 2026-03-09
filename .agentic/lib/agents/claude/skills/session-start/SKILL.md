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
  version: "${VERSION}"
---

# Session Start

Initialize a new session by checking project state and presenting a polished dashboard.

## Instructions

### Step 1: Run Dashboard (ONE tool call)

```bash
bash .agentic/lib/tools/dashboard.sh 2>/dev/null
```

This is the ONLY tool call. No Read calls, no ad-hoc checks. The script consolidates all state (STATUS, JOURNAL, BACKLOG, WIP, BLOCKERS, AGENTS, HEALTH) and renders the final dashboard.

### Step 2: Output Verbatim

Output the dashboard.sh result as your first text response. **No preamble, no narration, no reformatting.** Do not add "Welcome back!", do not summarize it differently, do not wrap in markdown. Copy the output exactly.

### Step 3: Handle Critical Special Cases

After outputting the dashboard, check if the output contains any of these — and if so, note them briefly:

- **Upgrade pending** (🔄 line present): User should handle before new work.
- **Interrupted work** (⚠️ line present): Focus on recovery, don't suggest new features.
- **Memory stale** (health mentions memory): Note it as action item.

## Examples

**Example: Clean start**

One tool call visible: `Bash(dashboard.sh)`

Agent text output (verbatim from script):
```
My Project · v1.2.0
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📋 Last session   Shipped auth improvements
🎯 Focus          API rate limiting
✅ Health         Clean · No blockers

📌 Backlog
   Current → F-0042  Rate limit middleware
   Next    → F-0043  Usage dashboard
   Queue     3 remaining

⚡ Next steps
   1. Start building — `ag implement F-0042`
   2. Plan first — `ag plan F-0042`
   3. View queue — `ag backlog list`

💡 Tip: Use `ag sync` to detect drift across specs and docs.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Troubleshooting

**Error: dashboard.sh not found**
Cause: Tool script missing or path incorrect.
Solution: Verify `.agentic/lib/tools/dashboard.sh` exists and is executable.

**Error: STATUS.md or JOURNAL.md not found**
Cause: Project not initialized or first session.
Solution: Normal for new projects. Dashboard will show "No focus set" / "First session".

## References

- Dashboard scanner: `.agentic/lib/tools/dashboard.sh`
- Full session start protocol: `references/session_start.md`
