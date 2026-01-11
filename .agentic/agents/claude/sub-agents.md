# Claude Code Sub-Agent Integration

This guide explains how to use Claude Code's native sub-agent capabilities with the Agentic Framework.

---

## Overview

Claude Code supports **sub-agents** - independent agent instances that:
- Have their own context window
- Can run concurrently (up to 10+)
- Don't interfere with each other
- Report back to the main agent

## Quick Start: Use the Orchestrator

The fastest way to use sub-agents:

```
Read .agentic/agents/claude/subagents/orchestrator-agent.md and coordinate feature F-0042
```

The orchestrator will:
1. Delegate to specialized agents
2. Verify quality gates at each step
3. Ensure specs, tests, and docs are updated
4. Block if quality criteria not met

## Setting Up Sub-Agents

### 1. Reference Role Definitions

Tell Claude about the available roles:

```
The project has specialized agent roles defined in .agentic/agents/claude/subagents/
Available agents (9 total):
- orchestrator-agent.md  ← Start here! Coordinates all others
- research-agent.md
- planning-agent.md
- test-agent.md
- implementation-agent.md
- review-agent.md
- spec-update-agent.md
- documentation-agent.md
- git-agent.md
```

**Tip**: Use the **orchestrator-agent** to manage features. It delegates to others and ensures compliance.

### 2. Start a Feature Pipeline

```
Create a pipeline for F-0042 (User Authentication).
Read .agentic/agents/roles/ to understand available agents.
Create .agentic/pipeline/F-0042-pipeline.md to track progress.
```

### 3. Spawn Specialized Agents

Tell the main agent to delegate:

```
Spawn a research agent for F-0042.
Use the role definition from .agentic/agents/roles/research_agent.md
Research auth strategies for Next.js and update the pipeline when done.
```

Or use Claude's background agent feature:

```
In the background, run a test agent for F-0042.
Write failing tests based on spec/acceptance/F-0042.md
Update .agentic/pipeline/F-0042-pipeline.md when complete.
```

## Full Feature Pipeline Example

### Step 1: Create Pipeline

```
Create feature pipeline for F-0042 (User Authentication):

1. Create .agentic/pipeline/F-0042-pipeline.md
2. Initialize with all agents in pending state
3. Start with Research Agent

Use the template from .agentic/spec/PIPELINE.template.md
```

### Step 2: Research Phase

```
As Research Agent (see .agentic/agents/roles/research_agent.md):

Research authentication options for Next.js 15:
- Compare Auth.js, Clerk, custom JWT
- Consider our stack: Next.js, TypeScript, Postgres
- Create docs/research/auth-strategies-[date].md
- Update pipeline with findings
```

### Step 3: Planning Phase

```
As Planning Agent (see .agentic/agents/roles/planning_agent.md):

Based on the research:
- Define acceptance criteria in spec/acceptance/F-0042.md
- Update spec/FEATURES.md with F-0042
- Create ADR-0005 for auth decision
- Update pipeline with handoff notes
```

### Step 4: Test Phase

```
As Test Agent (see .agentic/agents/roles/test_agent.md):

Write failing tests for F-0042:
- Read spec/acceptance/F-0042.md
- Create tests/auth.test.ts
- All tests should FAIL (red phase)
- Update pipeline with test count
```

### Step 5: Implementation Phase

```
As Implementation Agent (see .agentic/agents/roles/implementation_agent.md):

Make the tests pass:
- Run tests first to see failures
- Implement minimum code to pass
- All tests should now PASS
- Update pipeline with files changed
```

### Step 6-8: Review, Spec Update, Documentation, Git

Continue the pattern for remaining agents.

## Parallel Agent Execution

For independent tasks, run agents in parallel:

```
Run these agents in parallel:

1. Research Agent on F-0042 (User Auth)
2. Research Agent on F-0043 (Payment Integration)

Each should:
- Update their own pipeline file
- Not modify shared files (FEATURES.md)
- Report completion to main agent
```

## Pipeline File Format

`.agentic/pipeline/F-####-pipeline.md`:

```markdown
<!-- format: pipeline-v0.1.0 -->
# Pipeline: F-0042 (User Authentication)

## Status
- Current agent: Implementation Agent
- Phase: in_progress
- Started: 2026-01-02 14:00

## Completed Agents
- [x] Research Agent (10:30) → docs/research/auth-2026-01-02.md
- [x] Planning Agent (11:30) → spec/acceptance/F-0042.md
- [x] Test Agent (13:00) → tests/auth.test.ts (15 tests, all RED)
- [ ] Implementation Agent (started 14:00)

## Pending Agents
- [ ] Review Agent
- [ ] Spec Update Agent
- [ ] Documentation Agent
- [ ] Git Agent

## Handoff Notes
### Research → Planning
- Recommendation: Auth.js for Next.js
- Key finding: Need to handle JWT refresh
- See: docs/research/auth-2026-01-02.md

### Planning → Test
- 6 acceptance criteria defined
- Focus on: login, logout, session persistence
- Edge cases: expired tokens, concurrent sessions

### Test → Implementation
- 15 tests written (unit + integration)
- All currently failing as expected
- Run: npm test -- --grep "F-0042"
```

## Best Practices

1. **One agent per task** - Don't ask an agent to do multiple roles
2. **Clear handoffs** - Always update pipeline with notes
3. **Check pipeline first** - Before starting, read current state
4. **Don't skip agents** - Follow the pipeline order
5. **Limit parallelism** - Start with 2-3 concurrent agents max

## Troubleshooting

### Agent not seeing context
Make sure the pipeline file exists and is updated by previous agent.

### Merge conflicts
When multiple agents work on same files, have them work sequentially or use different files.

### Agent stuck
Check the pipeline file for the last handoff notes. Resume from there.

