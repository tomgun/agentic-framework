# Agent Guidelines Modules

This directory contains focused guideline modules extracted from `agent_operating_guidelines.md` for **lazy loading** - agents load only what they need.

## Available Modules

| Module | Purpose | When to Load |
|--------|---------|--------------|
| `core-rules.md` | Constitutional minimum: no fabrication, no auto-commit, token scripts, ask when uncertain | **Always** (auto-injected by `context-for-role.sh` for ALL roles) |
| `anti-hallucination.md` | Comprehensive verification rules, check-before-creating | Always (core rule) |
| `token-efficiency.md` | Scripts, delegation, context optimization | When updating docs |
| `multi-agent.md` | Coordination, AGENTS_ACTIVE.md, worktrees | Parallel agent work |
| `wip-tracking.md` | Work-in-progress, recovery | Interrupted sessions |
| `small-batch.md` | Breaking large tasks, commit limits | Implementation |

## How Context-for-Role Uses These

The `context-for-role.sh` tool uses context manifests to determine which guidelines each role needs:

```yaml
# Example: implementation-agent loads
optional:
  - .agentic/agents/shared/guidelines/anti-hallucination.md
  - .agentic/agents/shared/guidelines/small-batch.md
exclude:
  - .agentic/agents/shared/guidelines/multi-agent.md  # Not needed for single agent
```

## Migration Status

- [x] Directory structure created
- [x] anti-hallucination.md extracted
- [x] token-efficiency.md extracted
- [x] multi-agent.md extracted
- [x] wip-tracking.md extracted
- [x] small-batch.md extracted
- [x] Update agent_operating_guidelines.md to reference modules (434 → 110 lines)
- [x] Consolidate CLAUDE.md duplications (512 → 113 lines, 78% reduction)

## Token Savings

| Before | After | Savings |
|--------|-------|---------|
| Full guidelines: 51KB (~12,800 tokens) | Core + 1 module: ~8KB (~2,000 tokens) | 84% |

Agents load full guidelines only when needed. Most tasks need only 1-2 modules.
