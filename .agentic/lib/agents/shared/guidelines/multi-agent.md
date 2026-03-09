---
summary: "Multi-agent coordination: register, avoid conflicts, handoff"
trigger: "multi agent, coordination, parallel, conflict"
tokens: ~1400
phase: implementation
---

# Multi-Agent Coordination

**Purpose**: Enable multiple agents to work on different features simultaneously without conflicts.

---

## When Multi-Agent Applies

- Multiple AI assistants working on same codebase
- Parallel feature development using Git worktrees
- Agent handoffs between environments (Claude → Cursor → Copilot)

---

## Coordination File: AGENTS.json

**Location**: `.agentic/session/AGENTS.json` (always in main repo, not worktrees)

**At session start, check for other agents:**
```bash
python3 .agentic/lib/tools/agents_helpers.py --project-root . list
```

**If other agents are active:**
- See what files they're working on
- Choose different files/features
- Register yourself via `wip.sh start`

**Registration is automatic** — `wip.sh start` and `ag implement` create AGENTS.json entries.

---

## Rules for Parallel Work

1. **One feature per agent** - Each agent works on ONE feature at a time
2. **Avoid file conflicts** - Don't touch files another agent is modifying
3. **Use worktrees** - Separate Git worktrees for parallel features (`worktree_mode: always` in STACK.md)
4. **Communicate via AGENTS.json** - Single registry for all agent/WIP state

---

## AGENTS.json as Lock Registry

Entries track active work with status and timestamps:

| Status | Meaning | Action |
|--------|---------|--------|
| `created` | Worktree created, work not started | Safe to wait |
| `active` (< 5 min) | Agent actively working | Wait or coordinate |
| `active` (> 60 min) | Agent likely crashed | Review changes, decide |
| `created` (> 30 min) | Stale entry, agent crashed before starting | Clean up |

**Never start new work while another agent has a fresh active entry.**

---

## Git Worktrees for Parallel Features

**Automatic (recommended):** Set `worktree_mode: always` in STACK.md.
`ag implement F-XXXX` auto-creates a worktree and registers in AGENTS.json.

**Manual:**
```bash
# Create worktree for F-0043
bash .agentic/lib/tools/worktree.sh create F-0043 "API endpoints"

# Agent works in ../project-f-0043/
# Main agent continues in ./

# When done, clean up
bash .agentic/lib/tools/worktree.sh auto-remove F-0043
```

**Benefits:**
- Complete isolation between agents
- No merge conflicts during work
- Single AGENTS.json in main repo tracks all worktrees
- Can run tests independently

---

## Environment Handoffs

**When switching tools (Claude → Cursor → Copilot):**

### Before switching:
```bash
bash .agentic/lib/tools/wip.sh checkpoint "Handing off to Cursor"
```

### In new environment:
```bash
bash .agentic/lib/tools/wip.sh check
# Output: "✓ Recent checkpoint — Active handoff detected"
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
| Other agents active? | Session start | `agents_helpers.py list` |
| WIP exists? | Session start | `wip.sh check` |
| Register yourself | Starting work | `wip.sh start` (auto) |
| Deregister | Work complete | `wip.sh complete` (auto) |
| Before handoff | Environment switch | `wip.sh checkpoint` |

**Parallel work is safe when agents coordinate via AGENTS.json.**
