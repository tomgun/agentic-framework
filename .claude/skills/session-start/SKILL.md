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
  version: "0.52.0"
---

# Session Start

Initialize a new session by checking project state and presenting a polished dashboard.

## Instructions

### Step 1: Run Dashboard Scanner

Run the consolidated scanner (one Bash call replaces all individual checks):

```bash
bash .claude/skills/session-start/scripts/dashboard.sh 2>/dev/null
```

Parse the output by section markers (`===SECTION===`). Extract all key-value pairs.

### Step 2: Read Journal for Context

Read the last 50 lines of `.agentic/journal/JOURNAL.md` to get deeper context about recent sessions.

### Step 3: Render Dashboard

Using the parsed data, render this dashboard. Use emoji-accented style:

```
<project-name> · v{VERSION}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📋 Last session   {JOURNAL_LAST summary, one line}
🎯 Focus          {STATUS first line}
✅ Health         {HEALTH summary} · {BLOCKERS count} blockers

📌 Backlog
   Current → {current_id}  {current_desc}
   Next    → {next_id}  {next_desc}
   Queue     {remaining} remaining

⚡ Next steps
   1. {Primary action based on context}
   2. {Secondary action}
   3. {Tertiary action or "View queue — ag backlog list"}

💡 Tip: {TIP}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Formatting rules:**
- Use the horizontal bar (━) for top and bottom borders
- Align values after labels using spaces for a clean columnar look
- Keep the "Last session" summary to one short line
- For "Health": say "Clean" if HEALTH is "ok" and BLOCKERS is 0; otherwise summarize issues

**Conditional sections** (insert these BETWEEN the Health line and Backlog section, only when relevant):

- **Interrupted work** (WIP != "clean"):
  ```
  ⚠️ Interrupted   {WIP_DETAIL feature} — {changed_files} uncommitted files
                    Options: continue, review (`git diff`), or clear (`wip.sh complete`)
  ```

- **Blockers** (BLOCKERS > 0):
  ```
  🚫 Blockers      {count} items need human input — check HUMAN_NEEDED.md
  ```

- **Active agents** (AGENTS != "none"):
  ```
  👥 Agents        {agent summary from AGENTS output}
  ```

- **Stale backlog** (STALE == "yes"):
  ```
  ⏰ Stale          Current backlog item is >7 days old — review priority
  ```

- **Upgrade pending** (UPGRADE == "pending"):
  ```
  🔄 Upgrade        Pending — read `.agentic/.upgrade_pending`
  ```

### Step 4: Determine Next Steps

Choose 3 suggested actions based on context:

- **If WIP interrupted**: First action should be "Resume interrupted work on {feature}"
- **If blockers exist**: Include "Address blockers in HUMAN_NEEDED.md"
- **If backlog has items**: Include "Start building — `ag implement {current_id}`" and "Plan first — `ag plan {current_id}`"
- **If backlog is empty**: Suggest "Seed backlog — `ag backlog add`" or "Explore — `ag sync`"
- **Always include** at least one exploratory option like "View queue — `ag backlog list`" or "Check health — `ag verify`"

### Step 5: Handle Critical Special Cases

These require immediate attention before normal workflow:

- **Upgrade pending**: Mention it prominently. User should handle before new work.
- **Interrupted work**: Do NOT proceed to suggest new features. Focus on recovery.
- **Memory stale**: If health mentions memory issues, note it in next steps.

## Examples

**Example 1: Clean start**

Tool calls visible to user: `Bash(dashboard.sh)` + `Read(JOURNAL.md)`

Output:
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
   1. Start building — `ag implement F-0181`
   2. Plan first — `ag plan F-0181`
   3. View queue — `ag backlog list`

💡 Tip: Use `ag sync` to detect drift across specs and docs.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Example 2: Interrupted work + blockers**

```
Agentic Framework · v0.49.0
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📋 Last session   Started F-0180 review checkpoint framework
🎯 Focus          ADR-001 Phase 3
⚠️ Interrupted   F-0180 — 5 uncommitted files
                  Options: continue, review (`git diff`), or clear (`wip.sh complete`)
🚫 Blockers      2 items need human input — check HUMAN_NEEDED.md
✅ Health         Needs attention · 2 blockers

📌 Backlog
   Current → F-0180  Review Checkpoint Framework
   Next    → F-0181  Autonomous Formal Profile
   Queue     7 remaining

⚡ Next steps
   1. Resume interrupted work on F-0180
   2. Address 2 blockers in HUMAN_NEEDED.md
   3. Review changes — `git diff`

💡 Tip: Run `ag verify --full` for a comprehensive health check.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Example 3: Empty backlog**

```
My Project · v1.2.0
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📋 Last session   Shipped auth improvements
🎯 Focus          No active focus set
✅ Health         Clean · No blockers

📌 Backlog
   Empty — no queued work items

⚡ Next steps
   1. Seed backlog — `ag backlog add F-XXXX`
   2. Run health check — `ag verify`
   3. Explore — `ag sync --check`

💡 Tip: Use `ag specs` to generate specs for existing code.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Troubleshooting

**Error: dashboard.sh not found**
Cause: Skill scripts directory missing or path incorrect.
Solution: Verify `.claude/skills/session-start/scripts/dashboard.sh` exists and is executable.

**Error: Empty sections in dashboard output**
Cause: Individual tools (backlog_helpers.py, doctor.py) may be missing or python3 unavailable.
Solution: Script handles missing tools gracefully with fallback values. Check `python3 --version`.

**Error: STATUS.md or JOURNAL.md not found**
Cause: Project not initialized or first session.
Solution: Normal for new projects. Dashboard will show "No focus set" / "First session".

## References

- Dashboard scanner: `scripts/dashboard.sh`
- Legacy scanner (deprecated): `scripts/quick-scan.sh`
- Full session start protocol: `references/session_start.md`
