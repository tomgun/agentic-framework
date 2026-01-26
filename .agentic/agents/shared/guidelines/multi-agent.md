# Multi-Agent Coordination

**Purpose**: Enable multiple agents to work on different features simultaneously without conflicts.

---

## When Multi-Agent Applies

- Multiple AI assistants working on same codebase
- Parallel feature development using Git worktrees
- Agent handoffs between environments (Claude → Cursor → Copilot)

---

## Coordination File: AGENTS_ACTIVE.md

**Location**: `.agentic/AGENTS_ACTIVE.md`

**At session start, check for other agents:**
```bash
cat .agentic/AGENTS_ACTIVE.md 2>/dev/null
```

**If other agents are active:**
- See what files they're working on
- Choose different files/features
- Register yourself

**Register yourself when starting work:**
```markdown
## Active Agents

| Agent | Feature | Files | Started |
|-------|---------|-------|---------|
| Claude-1 | F-0042 | src/auth/* | 2026-01-26 10:00 |
| YOUR-ID | F-0043 | src/api/* | 2026-01-26 10:30 |
```

**Deregister when done:**
- Remove your row from AGENTS_ACTIVE.md
- Or mark as complete

---

## Rules for Parallel Work

1. **One feature per agent** - Each agent works on ONE feature at a time
2. **Avoid file conflicts** - Don't touch files another agent is modifying
3. **Use worktrees** - Separate Git worktrees for parallel features
4. **Communicate via files** - AGENTS_ACTIVE.md, WIP.md, HUMAN_NEEDED.md

---

## WIP Files as Locks

**.agentic/WIP.md acts as a lock file:**

| WIP Age | Meaning | Action |
|---------|---------|--------|
| < 5 minutes | Agent actively working | Wait or coordinate |
| 5-60 minutes | Agent may have paused | Check AGENTS_ACTIVE.md |
| > 60 minutes | Agent likely crashed | Review changes, decide |

**Never start new work while another agent's WIP.md is fresh (<5 min).**

---

## Git Worktrees for Parallel Features

Each agent can have its own worktree:

```bash
# Create worktree for agent-2 working on F-0043
git worktree add ../project-F0043 -b feature/F-0043

# Agent-2 works in ../project-F0043/
# Main agent continues in ./

# When done, merge and clean up
git worktree remove ../project-F0043
```

**Benefits:**
- Complete isolation between agents
- No merge conflicts during work
- Each agent has own WIP.md
- Can run tests independently

---

## Environment Handoffs

**When switching tools (Claude → Cursor → Copilot):**

### Before switching:
```bash
bash .agentic/tools/wip.sh checkpoint "Handing off to Cursor"
```

### In new environment:
```bash
bash .agentic/tools/wip.sh check
# Output: "✓ Recent checkpoint (3 minutes ago) - Active handoff detected"
# Continue seamlessly!
```

---

## Proactive Session Start Check

**If AGENTS_ACTIVE.md has entries, tell user:**

```
👥 Another agent is working on F-0042 (src/auth/*).
I'll register myself and work on different files.
```

---

## Conflict Resolution

**If you discover file conflict:**
1. STOP modifying the conflicting file
2. Note in HUMAN_NEEDED.md
3. Work on different files
4. Or wait for other agent to finish

**Never force changes to files another agent is actively editing.**

---

## Summary

| Check | When | Tool |
|-------|------|------|
| Other agents active? | Session start | `cat .agentic/AGENTS_ACTIVE.md` |
| WIP exists? | Session start | `bash .agentic/tools/wip.sh check` |
| Register yourself | Starting work | Edit AGENTS_ACTIVE.md |
| Deregister | Work complete | Edit AGENTS_ACTIVE.md |
| Before handoff | Environment switch | `wip.sh checkpoint` |

**Parallel work is safe when agents coordinate via files.**
