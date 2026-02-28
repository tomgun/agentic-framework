---
name: session-start
description: >
  Initialize session, check for interrupted work, show dashboard with current
  status and suggested next steps. Use when: first message in conversation,
  user says "start", "where were we", "what's the status", "ag start",
  or returns after being away.
  Do NOT use for: mid-session tasks, implementing features, committing code.
compatibility: "Requires Claude Code with shell access and ag commands."
allowed-tools: [Read, Bash, Glob, Grep]
metadata:
  author: agentic-framework
  version: "${VERSION}"
---

# Session Start

Initialize a new session by checking project state and presenting a dashboard.

## Instructions

### Step 1: Quick Context Scan (Silent)

Read these files silently (do not dump raw content to user):

```bash
cat STATUS.md 2>/dev/null || true
cat HUMAN_NEEDED.md 2>/dev/null | head -20 || true
bash .agentic/tools/wip.sh check 2>/dev/null || true
bash .agentic/tools/todo.sh list 2>/dev/null || true
```

Also read the last 2-3 entries from `.agentic-journal/JOURNAL.md`.

### Step 2: Check for Interrupted Work

If `wip.sh check` reports interrupted work:

Present to user:
- What feature was in progress
- What files were changed (`git diff --stat`)
- Options: continue, review changes, or roll back

**Do not proceed to new work until interrupted work is addressed.**

### Step 3: Greet with Dashboard

Present a structured greeting:

```
Welcome back! Here's where we are:

**Last session**: [Summary from JOURNAL.md]
**Current focus**: [From STATUS.md]
**Progress**: [What's done, what's in progress]

**Next steps** (pick one or tell me something else):
1. [Next planned task]
2. [Second option]
3. [Address blockers — if any in HUMAN_NEEDED.md]

**Available workflows**: `ag plan` | `ag sync` | `ag implement F-XXXX`
```

### Step 4: Handle Special Cases

- **HUMAN_NEEDED.md has items**: Surface them before asking what to work on
- **Upgrade pending** (`.agentic/.upgrade_pending`): Follow the TODO in that file
- **Other agents active** (`.agentic-state/AGENTS_ACTIVE.md`): Register self, avoid their files
- **Memory stale**: Run `bash .agentic/tools/memory-check.sh`

## Examples

**Example 1: Clean start, no interruptions**
Steps taken:
1. Read STATUS.md — focus is "Infrastructure validation tests"
2. WIP check — clean, no interrupted work
3. Read JOURNAL.md — last session fixed doc architecture
4. Check HUMAN_NEEDED — no active items
Dashboard: "Last session: doc architecture review. Current focus: infra tests. Next: run LLM tests or start new feature."

**Example 2: Interrupted work detected**
Steps taken:
1. WIP check — F-0125 was in progress, interrupted 2 hours ago
2. git diff shows 3 uncommitted files
Dashboard: "Previous work on F-0125 was interrupted. 3 uncommitted changes. Continue, review, or roll back?"

## Troubleshooting

**Error: STATUS.md not found**
Cause: Project not initialized with agentic framework.
Solution: Run `bash .agentic/init/scaffold.sh` or check if this is a framework project.

**Error: JOURNAL.md empty or missing**
Cause: First session or journal was never created.
Solution: This is normal for new projects. Proceed with available context from STATUS.md.

## References

- For full session start protocol: see `references/session_start.md`
