# Plan: Clean & Professional Session Dashboard

## Context

When starting a session, the user sees noisy Claude Code UI output:
```
● Skill(session-start)
● Read 3 files (ctrl+o to expand)
● Bash(bash .agentic/lib/tools/wip.sh check 2>/dev/null || true)
● Bash(bash .agentic/lib/tools/backlog.sh current 2>/dev/null || true)
● Read 2 more files
● [dashboard text]
```

**Problems:**
1. Multiple tool calls create visual noise (5+ visible lines before actual content)
2. Raw bash commands with `2>/dev/null || true` look messy
3. The dashboard text itself is functional but bland — not inspiring or polished

**Goal:** Reduce visible tool calls to 1–2, and make the dashboard output professional and motivating.

## Approach

### Part 1: Single-Script Scanner (`dashboard.sh`)

Create `.agentic/lib/tools/dashboard.sh` that consolidates ALL scanning into one call. Outputs structured key-value sections that the agent can parse.

Calls internally: `wip.sh check`, `status.sh`, `backlog.sh`, `todo.sh`, JOURNAL.md tail, HUMAN_NEEDED.md, AGENTS.json, VERSION, doctor.sh --quick.

Output format:
```
===VERSION===
0.51.0
===WIP===
clean
===STATUS===
ADR-001 roadmap execution: F-0180 (Review Checkpoint Framework) is next
===JOURNAL_LAST===
F-0194 shipped (AGENTS.json + worktrees) as v0.51.0
===BACKLOG_CURRENT===
F-0181|Autonomous Formal Profile|.agentic/spec/acceptance/F-0181.md
===BACKLOG_NEXT===
F-0182|Critical Review Agent
===BACKLOG_TOTAL===
9
===BLOCKERS===
0
===TODO_COUNT===
3
===AGENTS===
none
===HEALTH===
ok
===TIP===
Run `ag sync` to detect drift across memory, specs, and docs.
```

This means the user sees only: `● Bash(dashboard.sh)` instead of 5+ tool calls.

### Part 2: Redesigned Dashboard Template (SKILL.md)

Update the skill instructions to:
1. Run the single `dashboard.sh` script
2. Read JOURNAL.md (one Read call for deeper context)
3. Format a polished dashboard

New dashboard template (emoji-accented style):

```
Agentic Framework · v0.51.0
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📋 Last session   F-0194 shipped as v0.51.0
🎯 Focus          ADR-001 roadmap execution
✅ Health         Clean · No blockers

📌 Backlog
   Current → F-0181  Autonomous Formal Profile
   Next    → F-0182  Critical Review Agent
   Queue     7 remaining

⚡ Next steps
   1. Start building — ag implement F-0181
   2. Plan first — ag plan F-0181
   3. View queue — ag backlog list

💡 Tip: Use `ag sync` to detect drift across specs and docs.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Conditional sections** (appear only when relevant):
- ⚠️ Interrupted work alert (when WIP detected)
- 🚫 Blockers section (when HUMAN_NEEDED has active items)
- 👥 Active agents (when other agents are working)
- ⏰ Stale backlog warning (when current item > 7 days old)

## Files to Change

| # | File | Change |
|---|------|--------|
| 1 | `.agentic/lib/tools/dashboard.sh` | **NEW** — consolidated scanner script |
| 2 | `.claude/skills/session-start/SKILL.md` | Rewrite instructions: single scan call + polished template |
| 3 | `.claude/skills/session-start/scripts/quick-scan.sh` | Deprecate (replaced by dashboard.sh) |

**Existing code to reuse:**
- `.agentic/lib/paths.sh` — all path variables
- `.agentic/lib/tools/wip.sh check` — WIP detection
- `.agentic/lib/tools/backlog_helpers.py json-all` — backlog data
- `.agentic/lib/tools/ag.sh` cmd_start tips array — reuse tip list
- `.agentic/lib/tools/doctor.sh --quick` — health check

## Implementation Details

### dashboard.sh
- Source `paths.sh` for all path variables
- Each section wrapped in `===SECTION===` markers
- Silent failures (continue if any tool missing)
- Parse last JOURNAL.md entry for summary line
- Parse STATUS.md "Current focus" section
- Call `backlog_helpers.py json-all` and format
- Count HUMAN_NEEDED active items
- Count TODO inbox items
- Check AGENTS.json for active agents
- Run `doctor.sh --quick` for health
- Pick random tip from embedded list
- Total: ~80-100 lines of bash

### SKILL.md Rewrite
- Step 1: Run `bash .agentic/lib/tools/dashboard.sh`
- Step 2: Read last 50 lines of JOURNAL.md for deeper context (one Read call)
- Step 3: Format dashboard using template
- Step 4: Handle special cases (interrupted work, blockers, stale backlog)
- Include the polished template with box-drawing characters
- Keep examples section updated

## Verification

1. Run `bash .agentic/lib/tools/dashboard.sh` directly — verify structured output
2. Start a new Claude Code session and say "hi" — verify:
   - Only 1-2 tool calls visible (dashboard.sh + journal read)
   - Dashboard renders cleanly with box-drawing characters
   - All data (version, focus, backlog, health) appears correctly
3. Test edge cases:
   - With interrupted work (create mock WIP entry)
   - With blockers in HUMAN_NEEDED.md
   - With empty backlog
   - With active agents
4. Run `bash tests/validate_framework.sh` — must still pass
