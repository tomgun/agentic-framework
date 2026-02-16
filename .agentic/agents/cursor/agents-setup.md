# Cursor Agent Setup

This guide explains how to use Cursor's agent capabilities with the Agentic Framework.

---

## ENFORCED GATES (Profile-Aware)

| Gate | Formal | Discovery |
|------|--------|-----------|
| Acceptance criteria | **BLOCKS** - `ag implement` requires acceptance | N/A - use `ag work` |
| WIP before commit | **BLOCKS** - must complete WIP first | WARNING only |
| Pre-commit checks | **BLOCKS** - full validation | Light check, no block |

**Formal**: Formal tracking with enforced gates. **Discovery**: Lighter guidance.

**Quick Commands**: `ag start` | `ag implement F-XXXX` (Formal) | `ag work "desc"` (Discovery) | `ag commit` | `ag done` | `ag tools`

---

## Agent Boundaries (Quick Reference)

**Full details**: `.agentic/agents/shared/agent_operating_guidelines.md#agent-boundaries`

| ✅ ALWAYS (Autonomous) | ⚠️ ASK FIRST | 🚫 NEVER |
|------------------------|--------------|----------|
| Run tests before "done" | Add dependencies | Commit without approval |
| Update specs with code | Change architecture | Push to main directly |
| Follow existing patterns | Delete files/functionality | Modify secrets/.env |
| Use token-efficient scripts | Modify public APIs | Guess at requirements |

---

## Overview

Cursor supports custom agents through:
1. **Agent Mode** - Built-in agentic execution
2. **Custom Rules** - `.cursor/rules/*.mdc` files
3. **Composer** - Multi-file editing with agent behavior
4. **Background Agents** - Parallel task execution

## Quick Setup

Run the setup script to copy all role definitions to Cursor's format:

```bash
bash .agentic/tools/setup-agent.sh cursor-agents
```

This creates:
- `.cursor/agents/` directory with all role definitions
- Updated `.cursorrules` with agent references

## Manual Setup

### 1. Create Agent Rules Directory

```bash
mkdir -p .cursor/rules
```

### 2. Copy Role Definitions

Each role becomes a Cursor rule file:

**`.cursor/rules/research-agent.mdc`**
```markdown
---
name: Research Agent
description: Investigate tech choices and best practices
trigger: manual
---

# Research Agent

You are a specialized research agent.

## Your Role
Read and follow: .agentic/agents/roles/research_agent.md

## Key Points
- Read CONTEXT_PACK.md for project context
- Create research docs in docs/research/
- Update pipeline file when done
- Hand off to Planning Agent

## Pipeline
Always update: .agentic/pipeline/F-{id}-pipeline.md
```

### 3. Use Agent Mode

In Cursor, enable Agent Mode (Cmd/Ctrl + Shift + A) and reference the agent:

```
@research-agent Research authentication options for F-0042
```

Or mention the role file:

```
Act as the Research Agent defined in .agentic/agents/roles/research_agent.md
Research auth strategies for our Next.js app.
```

## Using Cursor Composer for Pipelines

### Start a Feature Pipeline

1. Open Composer (Cmd/Ctrl + I)
2. Reference multiple agents:

```
I want to implement F-0042 (User Authentication) using the agent pipeline.

1. First, create .agentic/pipeline/F-0042-pipeline.md
2. Act as Research Agent (.agentic/agents/roles/research_agent.md)
3. Research auth options for Next.js + TypeScript
4. Update the pipeline with findings

When done, I'll invoke the next agent.
```

### Sequential Agent Invocation

After each phase completes, start the next:

```
Research is complete. Now act as Planning Agent.
Read .agentic/agents/roles/planning_agent.md
Read the research from docs/research/auth-[date].md
Create acceptance criteria in spec/acceptance/F-0042.md
Update the pipeline.
```

## Parallel Agents in Cursor

### Using Multiple Cursor Windows

1. Create git worktrees for independent features:
   ```bash
   git worktree add ../project-F0042 -b feature/F-0042
   git worktree add ../project-F0043 -b feature/F-0043
   ```

2. Open each worktree in separate Cursor windows

3. In each window, work on different features

### Using Background Tasks

Cursor can run background agents. Start a task:

```
In the background, run the Test Agent for F-0042.
Read spec/acceptance/F-0042.md and write failing tests.
Update the pipeline when done.
I'll continue with other work.
```

## Agent File Format for Cursor

If Cursor supports `.cursor/agents/` directory, create files like:

**`.cursor/agents/implementation-agent.md`**
```markdown
# Implementation Agent

## Activation
Use this agent for implementing features after tests are written.

## Context Files
- spec/acceptance/F-{id}.md
- tests/**/*.test.ts
- src/

## Instructions
See: .agentic/agents/roles/implementation_agent.md

## Key Rules
1. Run tests first to see failures
2. Implement minimum code to pass
3. Follow existing patterns in src/
4. Update STATUS.md with progress
5. Update pipeline when done

## Handoff
Update pipeline and hand off to Review Agent
```

## Integration with Agentic Framework

### Pipeline Coordination

All Cursor agents should:
1. Read `.agentic/pipeline/F-####-pipeline.md` at start
2. Update pipeline when completing their phase
3. Add handoff notes for next agent
4. Not skip pipeline updates

### Shared Resources

When multiple agents work on same project:
- Use worktrees for different features
- Lock files in AGENTS_ACTIVE.md
- Don't modify shared files simultaneously

## Best Practices

1. **One window, one feature** - Use worktrees for parallelism
2. **Reference role files** - Always point to `.agentic/agents/roles/`
3. **Update pipeline** - Critical for handoffs
4. **Use @ mentions** - Reference files with @file for context
5. **Check status first** - Read pipeline before starting

## Troubleshooting

### Agent not following role
Make sure to explicitly reference the role file:
```
Read and follow .agentic/agents/roles/[agent].md
```

### Context too large
Tell agent to focus on specific files:
```
Only read: spec/acceptance/F-0042.md and tests/auth.test.ts
```

### Lost state after session
Pipeline file preserves state. Tell next session:
```
Read .agentic/pipeline/F-0042-pipeline.md and continue from where we left off.
```

