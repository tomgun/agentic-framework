# Plan: Implement Subagent Context Research Findings

## Research Results

### Critical Finding (confirmed across all tools)

**All major AI coding tools use context-isolated subagents.** The instruction file serves the orchestrating/principal agent, NOT subagents:

| Tool | Instruction File | Subagent Inherits It? | Evidence |
|------|-----------------|----------------------|----------|
| Claude Code | CLAUDE.md | **NO** — official docs explicit | "Subagents receive only this system prompt" |
| Cursor 2.4+ | .cursorrules | **NO** — context-isolated | "use their own context" (tools inherited, not instructions) |
| GitHub Copilot | copilot-instructions.md | **Unclear** — "attached to every session" but subagents are "context-isolated" | Contradictory signals |
| OpenAI Codex | AGENTS.md | **N/A** — subagents experimental | Instructions loaded "once per run" for main session |

### Architectural Implication

The framework's instruction files (.cursorrules, CLAUDE.md, copilot-instructions.md, codex-instructions.md) are READ ONLY BY THE ORCHESTRATOR. This means:

1. **Instruction files can be 100% optimized for the orchestrator** — no need to worry about confusing subagents
2. **Subagent quality depends on what the orchestrator PASSES in task prompts**, not instruction file content
3. **The Task Tool Delegation table in instruction files is critical** — it tells the orchestrator WHAT to pass to subagents
4. **Context manifests (.agentic/agents/context-manifests/) become the primary mechanism** for subagent context

### What This Means for "Making the Framework Shine"

The framework already HAS the right architecture:
- Context manifests define per-role token budgets
- Subagent definitions (.agentic/agents/claude/subagents/) define role-specific instructions
- `context-for-role.sh` assembles minimal context per role

What's MISSING is the **bridge**: the instruction files don't tell the orchestrator to USE these mechanisms. The orchestrator needs clear instructions to:
1. Use context manifests when spawning subagents
2. Pass focused, role-specific context (not dump everything)
3. Use `ag plan` before `ag implement` (already done in previous commit)

## Proposed Changes

### 1. Update L-0003 with multi-tool findings

**File**: `.agentic-journal/lessons/L-0003-instruction-file-architecture.md`

Add the cross-tool research table confirming that context isolation is an industry-wide pattern, not Claude-specific. Include sources.

### 2. Add subagent context guidance to instruction files (minimal, within 100-line budget)

The instruction files already have the "Task Tool Delegation" table. Add ONE line after it:

```
Subagent context: Use `.agentic/tools/context-for-role.sh <role> <feature-id>` to assemble minimal context per subagent.
```

This is a 1-line addition to each file. It bridges the gap between "the framework has context manifests" and "the orchestrator actually uses them."

**Files** (4 instruction files + root CLAUDE.md = 5):
- `.agentic/agents/claude/CLAUDE.md`
- `.agentic/agents/codex/codex-instructions.md`
- `.agentic/agents/copilot/copilot-instructions.md`
- `.agentic/agents/cursor/cursorrules.txt`
- `CLAUDE.md` (root — framework development)

### 3. Update subagent definition template to be self-contained

The subagent definitions in `.agentic/agents/claude/subagents/` currently say things like "See: .agentic/agents/roles/implementation_agent.md" — this is exactly the "read file X" pattern that ADR-001 says agents skip.

Since subagents DON'T inherit the instruction file, the subagent definitions ARE the only instructions they get. They must be self-contained.

**Action**: Audit the subagent definitions and ensure they don't rely on "See file X" references for critical instructions. The key rules from agent_operating_guidelines.md that subagents need should be INLINE in their definition.

**Files**: Check all files in `.agentic/agents/claude/subagents/` — fix any that reference external files for critical behavior.

### 4. Update ADR-001 with cross-tool confirmation

**File**: `spec/adr/ADR-001-claude-md-self-contained.md`

Add a section noting that the self-containment principle is validated across all tools — instruction files serve only the orchestrator, and subagents need self-contained definitions too.

### 5. Update CONTRIBUTIONS.md

Add the cross-tool research finding to the v0.22.0 section.

## Files to Create/Modify

| File | Action | Lines Added |
|------|--------|-------------|
| `.agentic-journal/lessons/L-0003-*` | EDIT | ~20 lines (research table) |
| `.agentic/agents/claude/CLAUDE.md` | EDIT | 1 line |
| `.agentic/agents/codex/codex-instructions.md` | EDIT | 1 line |
| `.agentic/agents/copilot/copilot-instructions.md` | EDIT | 1 line |
| `.agentic/agents/cursor/cursorrules.txt` | EDIT | 1 line |
| `CLAUDE.md` (root) | EDIT | 1 line |
| `spec/adr/ADR-001-*` | EDIT | ~10 lines |
| `.agentic/agents/claude/subagents/*.md` | EDIT | Varies — make self-contained |
| `CONTRIBUTIONS.md` | EDIT | ~5 lines |

## Line Budget Check

Current instruction file sizes:
- Root CLAUDE.md: 92 lines → 93 (under 100)
- Claude CLAUDE.md: 79 → 80 (under 100)
- Codex: 71 → 72 (under 100)
- Copilot: 69 → 70 (under 100)
- Cursor: 71 → 72 (under 100)

All remain well under 100 lines.

## What This Does NOT Do

- Does NOT restructure instruction files as "routers"
- Does NOT expand instruction files past 100 lines
- Does NOT test the ag-command hypothesis (deferred)
- Does NOT add new LLM tests (good follow-up but separate task)

## Verification

1. `bash tests/validate_framework.sh` passes
2. All instruction files ≤ 100 lines
3. Subagent definitions are self-contained (no critical "See file X" references)
4. L-0003 includes multi-tool evidence table with sources
