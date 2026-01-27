# ADR-001: CLAUDE.md Must Be Self-Contained

## Status

Accepted

## Date

2026-01-26

## Context

CLAUDE.md (located at `.agentic/agents/claude/CLAUDE.md`) is the bootstrap file for Claude agents. When Claude Code loads a project with the Agentic Framework, CLAUDE.md is the ONE file guaranteed to be read and processed.

There is also `agent_operating_guidelines.md` which contains comprehensive guidelines for all AI agents (not just Claude). Some content appears in both files.

A contributor attempted to "consolidate" CLAUDE.md by removing "duplicate" content and replacing it with a reference: "See agent_operating_guidelines.md for details." This reduced CLAUDE.md from 512 lines to 113 lines.

This consolidation broke the bootstrap mechanism.

## Decision

**CLAUDE.md must be self-contained with all essential operational instructions inline.**

Content that appears in both CLAUDE.md and agent_operating_guidelines.md is **intentional redundancy**, not duplication to be eliminated.

### What CLAUDE.md must contain (inline, not by reference):

1. Session start protocol (proactive greeting, context loading)
2. Token-efficient scripts with examples
3. Feature gates (acceptance criteria before code)
4. Key checklists references
5. Small batch development rules
6. Documentation sync requirements
7. Commit protocols

### What can reference other files:

1. Detailed principle explanations → PRINCIPLES.md
2. Workflow deep-dives → .agentic/workflows/
3. Quality standards details → .agentic/quality/
4. Subagent definitions → .agentic/agents/claude/subagents/

## Rationale

1. **Bootstrap problem**: To read agent_operating_guidelines.md, the agent must first know it exists. That knowledge comes from CLAUDE.md. If CLAUDE.md just says "go read that file," the agent might skim it, miss things, or skip it entirely when focused on user requests.

2. **Guaranteed touchpoint**: CLAUDE.md is the ONLY file guaranteed to be read by Claude. Everything else requires the agent to "pull" information. Self-contained bootstrap eliminates pull dependencies for critical instructions.

3. **Reliability over DRY**: The DRY (Don't Repeat Yourself) principle optimizes for maintainability. But for bootstrap files, reliability is more important. It's better to maintain two copies of critical instructions than to have agents miss them.

4. **Different purposes**:
   - `agent_operating_guidelines.md` = comprehensive reference for all tools
   - `CLAUDE.md` = operational bootstrap for Claude specifically

   Same content, different purposes.

## Consequences

### Must do:
- Maintain CLAUDE.md and agent_operating_guidelines.md separately
- When updating critical instructions, update BOTH files
- Accept that this creates maintenance burden

### Must NOT do:
- Consolidate CLAUDE.md to reduce "duplication"
- Replace inline instructions with "see X for details"
- Assume agents will follow reference links reliably

### Trade-offs accepted:
- Higher maintenance cost (two files to update)
- Apparent duplication in codebase
- Larger CLAUDE.md file size

These trade-offs are acceptable because bootstrap reliability is more important than DRY compliance.

## Related

- `agent_operating_guidelines.md` - comprehensive reference (this ADR explains why it's separate)
- Similar pattern applies to other tool-specific files (CURSOR.md, COPILOT.md if created)
