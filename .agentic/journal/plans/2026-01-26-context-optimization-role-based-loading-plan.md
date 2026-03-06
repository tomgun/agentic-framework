# Context Optimization: Role-Based Context Loading

## Goal
- Agents automatically load ONLY relevant context for their role/task
- Orchestrator spawns specialized agents with minimal, focused context
- Reduce token waste from loading unnecessary files
- Enforce context budgets programmatically

## Current State (Problems)

### 1. No Automated Context Selection
- Role definitions have "Context to Read" sections (advisory only)
- Agents manually decide what to read
- No enforcement of token budgets
- Pattern: 51KB agent_operating_guidelines.md loaded for ALL agents

### 2. Token-Efficient Scripts Only Partially Deliver
- journal.sh: True append-only (40x cheaper)
- status.sh: Reads entire file via awk (2-10x cheaper, not 40x)
- feature.sh: Reads entire FEATURES.md (expensive on large files)

### 3. No Task-Type → Context Mapping
- Auto-orchestration detects task patterns ("implement F-####")
- But doesn't specify what context each role needs
- Handoff notes describe context in prose, not programmatically

---

## Implementation Plan

### Phase 1: Context Manifests for Roles

**Create `.agentic/agents/context-manifests/`** with per-role context specs:

```yaml
# .agentic/agents/context-manifests/implementation-agent.yaml
role: implementation-agent
token_budget: 5000
required:
  - spec/acceptance/F-{feature_id}.md
  - STACK.md[build_commands]  # Section only
  - CONTEXT_PACK.md[entry_points]
optional:
  - .agentic/quality/programming_standards.md
exclude:
  - spec/PRD.md
  - docs/research/
  - JOURNAL.md
```

**Files to create:**
- `implementation-agent.yaml` (~5K tokens)
- `research-agent.yaml` (~3K tokens)
- `test-agent.yaml` (~4K tokens)
- `review-agent.yaml` (~6K tokens)
- `spec-update-agent.yaml` (~3K tokens)
- `orchestrator-agent.yaml` (~2K tokens)

### Phase 2: Context Assembly Tool

**Create `.agentic/tools/context-for-role.sh`**

```bash
#!/bin/bash
# Usage: context-for-role.sh <role> [feature_id]
# Output: Concatenated relevant context within token budget

ROLE=$1
FEATURE_ID=$2

# Read manifest
MANIFEST=".agentic/agents/context-manifests/${ROLE}.yaml"

# Assemble context from required files
# Support section extraction: STACK.md[build_commands]
# Track token count, warn if over budget

# Output assembled context to stdout
```

**Features:**
- Section extraction from files (not full file)
- Token counting with budget enforcement
- Variable substitution ({feature_id})
- Dry-run mode to show what would be loaded

### Phase 3: Orchestrator Integration

**Update `.agentic/agents/claude/subagents/orchestrator-agent.md`**

Add explicit context loading for delegated agents:

```markdown
## Delegating with Minimal Context

When spawning a specialized agent, use context-for-role.sh:

```bash
# Get context for implementation agent working on F-0042
CONTEXT=$(bash .agentic/tools/context-for-role.sh implementation-agent F-0042)
```

Then pass to Task tool:
```
Task: Implement F-0042. Here's your context:
$CONTEXT

Make the tests pass.
```
```

### Phase 4: True Append-Only for status.sh and feature.sh

**Problem:** These scripts read entire files via awk.

**Solution A: Header-based field indexing**
- Add byte offsets in file header
- Update specific byte ranges only
- Complex but maximally efficient

**Solution B: Separate metadata files (RECOMMENDED)**
- `STATUS.md` remains human-readable
- `.agentic/state/status.json` for quick updates
- Script updates JSON, regenerates STATUS.md on demand

```bash
# .agentic/state/status.json
{
  "focus": "Implementing F-0042",
  "progress": "60%",
  "next": "Add tests",
  "blocker": null,
  "updated": "2026-01-26T10:00:00Z"
}
```

**status.sh changes:**
```bash
# Update JSON (fast)
jq '.focus = "New focus"' .agentic/state/status.json > tmp && mv tmp .agentic/state/status.json

# Regenerate STATUS.md only when needed (on read or session end)
```

### Phase 5: Lazy Loading for Large Files

**Split `agent_operating_guidelines.md` (51KB) into:**

```
.agentic/agents/shared/
├── agent_operating_guidelines.md  (5KB core rules)
├── guidelines/
│   ├── anti-hallucination.md      (2KB)
│   ├── token-efficiency.md        (3KB)
│   ├── quality-standards.md       (4KB)
│   ├── multi-agent.md             (3KB)
│   └── checklists-reference.md    (2KB)
```

**Core file loads guidelines on-demand:**
```markdown
## Anti-Hallucination Rules
See: `.agentic/agents/shared/guidelines/anti-hallucination.md`
(Load only if generating code or making claims about files)
```

### Phase 6: Consolidate Duplicated Instructions

**Remove duplication (~2,500 tokens saved):**

| Content | Currently In | Keep In | Remove From |
|---------|--------------|---------|-------------|
| Session start protocol | CLAUDE.md, session_start.md, agent_operating_guidelines.md | agent_operating_guidelines.md | CLAUDE.md (reference only) |
| Token-efficient scripts | CLAUDE.md, agent_operating_guidelines.md | agent_operating_guidelines.md | CLAUDE.md (reference only) |

**CLAUDE.md becomes:**
```markdown
# Claude Instructions

Read `.agentic/agents/shared/agent_operating_guidelines.md` for full instructions.

## Quick Reference
- Session start: Read STATUS.md, CONTEXT_PACK.md, check HUMAN_NEEDED.md
- Use scripts: journal.sh, status.sh, feature.sh (see guidelines)
- Never auto-commit
```

---

## File Changes Summary

### New Files
| File | Purpose |
|------|---------|
| `.agentic/agents/context-manifests/*.yaml` | Per-role context specifications |
| `.agentic/tools/context-for-role.sh` | Context assembly tool |
| `.agentic/state/status.json` | Fast status updates |
| `.agentic/agents/shared/guidelines/*.md` | Split guideline sections |

### Modified Files
| File | Change |
|------|--------|
| `.agentic/tools/status.sh` | Use JSON backend |
| `.agentic/tools/feature.sh` | Consider JSON backend |
| `.agentic/agents/claude/subagents/orchestrator-agent.md` | Add context loading instructions |
| `.agentic/agents/shared/agent_operating_guidelines.md` | Split into smaller files |
| `CLAUDE.md` | Reduce to quick reference |
| `.agentic/workflows/auto_orchestration.md` | Add role → context mapping |

---

## Implementation Order

1. **Context manifests** (Phase 1) - Define what each role needs
2. **context-for-role.sh** (Phase 2) - Tool to assemble context
3. **Orchestrator integration** (Phase 3) - Use tool in delegation
4. **Split guidelines** (Phase 5) - Reduce mandatory context load
5. **JSON backend for status.sh** (Phase 4) - True append-only
6. **Consolidate duplications** (Phase 6) - Remove redundant content

---

## Verification

```bash
# 1. Test context assembly
bash .agentic/tools/context-for-role.sh implementation-agent F-0001
# Should output ~5K tokens of focused context

# 2. Verify token budgets
bash .agentic/tools/context-for-role.sh --dry-run implementation-agent F-0001
# Should show: "Token budget: 5000, Actual: 4823"

# 3. Test status.sh performance
time bash .agentic/tools/status.sh focus "Test"
# Should be <100ms (vs current ~200ms)

# 4. Verify guidelines split
wc -c .agentic/agents/shared/agent_operating_guidelines.md
# Should be ~5KB (vs current 51KB)

# 5. LLM behavioral test
# Run test that verifies orchestrator uses minimal context
```

---

## Token Savings Projection

| Change | Current | After | Savings |
|--------|---------|-------|---------|
| Implementation agent context | ~18K tokens | ~5K tokens | 72% |
| Research agent context | ~15K tokens | ~3K tokens | 80% |
| agent_operating_guidelines.md | 12,794 tokens | ~1,250 tokens (core) | 90% |
| Session start duplications | 2,500 tokens | 0 tokens | 100% |
| status.sh operation | ~200 tokens | ~50 tokens | 75% |

**Total session start savings: ~60-70%**

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| YAML parsing complexity | Use simple format, fallback to full context |
| Section extraction fragile | Define clear section markers in files |
| JSON/MD sync issues | Regenerate MD from JSON on session end |
| Agents ignore manifests | Add validation in orchestrator |
