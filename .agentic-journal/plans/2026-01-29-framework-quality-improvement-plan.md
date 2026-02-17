# Framework Quality Improvement Plan: Making It SHINE

## Executive Summary

**Current State**: Framework is production-ready (96% features shipped, 74/77). Quality gates exist, documentation comprehensive, multi-environment support works.

**Core Problem**: Framework relies on agents REMEMBERING 4000+ lines of instructions instead of ENFORCING compliance via gates. The infrastructure for enforcement exists (doctor.py, pre-commit hooks) but is underutilized.

**Strategy**: Shift from "instructions" to "enforcement" while reducing cognitive load. Preserve what works.

---

## Critical Gaps (Priority Order)

| Gap | Impact | Root Cause |
|-----|--------|------------|
| Instructions vs Gates | HIGH | Agents asked to remember, nothing enforces |
| Cognitive Overload | HIGH | 194 files, 1297-line guidelines, 571-line CLAUDE.md |
| Tool Discoverability | MEDIUM | 60+ tools, no unified interface |
| Multiple Paths | MEDIUM | 4+ ways to do session start, unclear which is "right" |

---

## Phase 1: Quick Wins (Week 1)

### 1.1 Create Gateway Script (`ag`)
**File**: `.agentic/tools/ag.sh` (new)

Single entry point that runs appropriate gates automatically:
```bash
ag start          # Session start checks + context summary
ag implement F-XX # Verify acceptance exists, start WIP
ag commit         # All pre-commit gates
ag done           # Feature complete validation
ag tools          # List all tools by category
ag help           # Show commands
```

**Why**: Agents call ONE script instead of remembering which gate to run when.

**Multi-agent support**: Works identically for Claude Code, Cursor, Codex, and Copilot. The scripts are agent-agnostic bash - any AI agent can call them. Output is plain text suitable for all environments.

### 1.2 Add Enforcement Summary to ALL Agent Instruction Files
**Files** (all agents need this):
- `CLAUDE.md` (Claude Code)
- `.agentic/agents/codex/codex-instructions.md` (Codex)
- `.agentic/agents/copilot/copilot-instructions.md` (Copilot)
- `.agentic/agents/cursor/agents-setup.md` (Cursor)

Add 10-line block at TOP showing what's actually ENFORCED vs GUIDANCE:
```markdown
## ENFORCED GATES (Block on failure)
1. Pre-commit: WIP.md exists → BLOCKED
2. Pre-commit: Untracked files → WARNING
3. Feature impl: No acceptance criteria → doctor.sh fails
4. Batch size: >10 files changed → WARNING

Everything below is GUIDANCE. Gates above are ENFORCEMENT.
```

**Why**: LLMs lose attention after 500 lines. Front-load what matters. All agents benefit from clarity on what's enforced.

### 1.3 Create Tool Discovery Menu
**File**: `.agentic/tools/list-tools.sh` (new)

```
$ ag tools

VERIFICATION
  doctor.sh       The verification command (--full, --phase, --pre-commit)

SESSION
  wip.sh          Track work-in-progress
  journal.sh      Milestone logging
  session_log.sh  Quick checkpoints

FEATURES (Core+PM)
  feature.sh      Update FEATURES.md
  query_features.py  Search/filter features
```

**Why**: Agents don't know what tools exist. Make them discoverable.

---

## Phase 2: Core Improvements (Week 2-3)

### 2.1 Make doctor.sh THE Single Source of Truth

**Files to modify**:
- `.agentic/tools/doctor.py` - Enhance phase checks
- `CLAUDE.md` - Simplify to "run doctor.sh --phase X"
- Checklists become reference, not primary instructions

**Current**: 8 checklists (2198 lines) duplicate phase requirements
**After**: `doctor.sh --phase planning|implement|commit` checks everything

**Why**: One command to rule them all. No memorization needed.

### 2.2 Consolidate Instruction Files (SAFE APPROACH)

**Constraint**: ADR-001 - CLAUDE.md must be self-contained (bootstrap reliability). Cannot replace content with file references.

**Safe target sizes**:
- `CLAUDE.md`: 571 → ~350 lines (remove internal duplication only)
- `agent_operating_guidelines.md`: 1297 → ~800 lines (remove overlap with CLAUDE.md)

**Safe approach**:
1. ADD enforcement summary at top (10 lines) - clarity, not removal
2. Remove internal CLAUDE.md duplication (same thing said 2-3 times)
3. Keep all protocols, triggers, session start - these MUST stay
4. In agent_operating_guidelines.md, remove content already in CLAUDE.md

**NOT doing**:
- Replacing CLAUDE.md sections with "see X file" references
- Removing session start protocol
- Removing feature-start blocking rules

### 2.3 Verification Status in Context

**Files**: `.agentic/tools/status.sh`, `ag.sh`

Show verification state in session greeting:
```
Last verified: 2 hours ago, 0 issues
Current phase: implement
WIP: F-0042 (started 3 hours ago)
```

**Why**: Creates accountability. Agents see if gates were run.

---

## Phase 3: UX Polish (Week 4+)

### 3.1 Unified `ag` Command Wrapper
Wrap all 60+ tools under consistent interface:
```bash
ag verify [--full|--phase X]
ag feature update F-XX status shipped
ag session start|end
ag blocker add|resolve
```

### 3.2 Workflow State Machine Diagram
Single visual showing valid transitions and gates:
```
START → PLANNING → IMPLEMENT → COMPLETE → COMMIT
         ↓           ↓           ↓          ↓
     acceptance   WIP.md      tests    pre-commit
     must exist   tracked     pass     gates
```

### 3.3 Deduplicate Documentation
Audit 194 files for duplication. Create single source of truth per concept.
Key areas: session start protocol, token efficiency scripts, feature workflow.

---

## What We're NOT Doing

| Not Doing | Why |
|-----------|-----|
| Rewriting framework | 96% works fine - fix presentation, not architecture |
| Adding features | 77 features is enough - reduce cognitive load instead |
| Removing profiles | Flexibility valuable for different project sizes |
| AI compliance checking | Recursive problem - simple scripts more reliable |
| Restructuring .agentic/ | Would break existing projects |

---

## Success Metrics

| Metric | Current | Target |
|--------|---------|--------|
| CLAUDE.md lines | 571 | <250 |
| Instructions to read at start | ~5000 tokens | ~1000 tokens |
| Tools discoverable in 1 command | No | Yes |
| Gate compliance visible | Hidden | Shown in status |

---

## Implementation Order (Approved Scope: Option 3)

**Phase 1 - New Files (Safe)**
1. `ag.sh` gateway script - NEW file, zero risk
2. `list-tools.sh` discovery menu - NEW file, zero risk

**Phase 2 - Additive Edits**
3. Enforcement summary at TOP of CLAUDE.md - 10 lines, additive
4. doctor.sh phase check enhancements - extend existing logic

**Phase 3 - Careful Consolidation**
5. CLAUDE.md internal deduplication (571 → ~350 lines) - remove repetition only
6. agent_operating_guidelines.md cleanup (1297 → ~800 lines) - remove CLAUDE.md overlap
7. Verification status display in session greeting
8. Additional tools unified under `ag` wrapper

---

## Key Files

| File | Action |
|------|--------|
| `.agentic/tools/ag.sh` | CREATE - gateway script (agent-agnostic) |
| `.agentic/tools/list-tools.sh` | CREATE - tool discovery |
| `CLAUDE.md` | EDIT - add enforcement summary, deduplicate (~350 lines) |
| `.agentic/agents/codex/codex-instructions.md` | EDIT - add enforcement summary |
| `.agentic/agents/copilot/copilot-instructions.md` | EDIT - add enforcement summary |
| `.agentic/agents/cursor/agents-setup.md` | EDIT - add enforcement summary |
| `.agentic/tools/doctor.py` | EDIT - enhance phase checks |
| `.agentic/agents/shared/agent_operating_guidelines.md` | EDIT - remove CLAUDE.md overlap (~800 lines) |

---

## Verification Plan

1. Run `bash tests/validate_framework.sh` - must pass
2. Test `ag` commands in fresh project
3. Verify CLAUDE.md changes don't break Claude Code behavior
4. Test in scratch project before merging
