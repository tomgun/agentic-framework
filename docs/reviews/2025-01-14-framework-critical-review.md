# Critical Review: Agentic Framework - A Different Perspective

**Date**: 2025-01-14
**Reviewer**: Claude Opus 4.5 (independent review)
**Framework Version**: v0.10.0
**Focus**: Determinism, cognitive load, and the "magic command" question

---

## Executive Summary

The Agentic Framework has grown into a comprehensive but overwhelming system. The previous review (v0.10.0 improvement plan) focused on **tool consolidation** and **documentation reduction**. While valid, I believe there's a more fundamental issue:

> **The framework gives LLMs human-style instructions when LLMs need machine-style gates.**

This review proposes a different approach: **shift from instruction-based to gate-based architecture**.

---

## By The Numbers

| Metric | Count | Problem |
|--------|-------|---------|
| `agent_operating_guidelines.md` | 1,185 lines | No LLM reads 1000+ lines reliably |
| `CLAUDE.md` (root) | 271 lines | Duplicates guidelines |
| Checklists (8 files) | 2,198 lines total | Overlap with guidelines |
| Tools (shell + Python) | 60 files | Tool overlap, unclear when to use which |
| Workflows | 30 files | Many never get referenced |
| **Total instruction surface** | ~4,000+ lines | Impossible to internalize |

---

## The Core Problem: Instructions vs Gates

### Current Approach (Instruction-Based)

```
"When user says 'implement', STOP and check acceptance criteria first.
 This is NON-NEGOTIABLE. CRITICAL. MANDATORY."
```

**Why this fails:**
1. LLMs read sequentially and forget earlier content
2. Emphatic language ("CRITICAL!", "NON-NEGOTIABLE!") loses impact after repetition
3. 1000+ lines = lots of instructions to forget
4. Instructions rely on agent **remembering** to follow them

### Better Approach (Gate-Based)

```
[Hook/Tool] Before any edit operation:
  → Run `verify-ready.sh --phase=pre-implementation`
  → BLOCK if acceptance criteria missing
  → No instruction needed - the gate enforces it
```

**Why gates work:**
1. Gates are **automatic** - no remembering required
2. Gates are **blocking** - can't proceed until passed
3. Gates are **verifiable** - pass/fail, not "maybe followed"
4. One gate replaces 100 lines of instructions

---

## The Determinism Problem

### Why Agents Forget Things

1. **Instruction overload**: 4000+ lines cannot be retained
2. **No verification**: Agent claims "done" without proof
3. **Honor system**: We *tell* agents to check, but don't *make* them
4. **Context decay**: Long sessions lose early instructions

### The User's Question: "Magic Command"

The user asked about a "magic command" that makes agents verify everything. The framework already has pieces of this:

- `doctor.sh` - checks project health
- `verify.sh` - validates specs
- Pre-commit hooks - run checks before commit

But these are:
- **Optional** (agent can skip them)
- **Scattered** (multiple tools to remember)
- **Passive** (must be invoked, not automatic)

---

## Proposed Solution: The Verification Loop

### Concept: Mandatory Verification at Phase Transitions

Instead of instructions, implement **phase gates** that automatically run verification:

```
PHASES:
  START     → [gate: wip-check, context-load]
  PLANNING  → [gate: acceptance-exists]
  IMPLEMENT → [gate: tests-exist, acceptance-mapped]
  COMPLETE  → [gate: all-tests-pass, docs-synced, specs-updated]
  COMMIT    → [gate: full-verification]
```

Each phase transition requires passing the gate. No instructions needed - the system enforces it.

### The Magic Command: `/verify`

Create a single command that:
1. Detects current phase
2. Runs appropriate verification
3. Reports what's missing
4. Blocks progression if gates fail

```bash
# User runs (or agent runs automatically):
/verify

# Output:
Current phase: IMPLEMENTATION
Feature: F-0042 (User Authentication)

GATE CHECK:
  [PASS] Acceptance criteria exist (spec/acceptance/F-0042.md)
  [PASS] Tests exist (tests/auth/login.test.ts)
  [FAIL] Tests not passing (3 failures)
  [FAIL] FEATURES.md not updated (Status: planned, should be in_progress)

ACTION REQUIRED:
  1. Fix failing tests
  2. Update FEATURES.md status

Cannot proceed to COMPLETE phase until gates pass.
```

### Implementation in Different Tools

| Tool | Implementation |
|------|----------------|
| **Claude Code** | Hooks: PreToolExecution checks phase |
| **Cursor** | Rules: Must run /verify before save |
| **Copilot** | Instructions: Call verify before response |
| **Any tool** | Convention: /verify slash command |

---

## The Orchestrator Gap

The framework has an `orchestrator-agent.md` that's supposed to coordinate everything. But:

1. **Never referenced** in main instruction files
2. **Agents work solo** instead of being orchestrated
3. **Quality gates** are defined but not enforced

### Fix: Make Orchestrator the Default

```markdown
# In CLAUDE.md (simplified to ~50 lines)

## Feature Work Flow

1. When "implement F-####" detected:
   → Orchestrator takes control
   → Orchestrator delegates to specialized agents
   → Orchestrator enforces gates between phases

2. Agents don't need to remember checklists:
   → Orchestrator runs verification at each transition
   → Agents focus on their specialty
```

---

## Instruction Consolidation: A Different Take

The previous review suggested creating `QUICK_REFERENCE.md` (~100 lines). I suggest going further:

### Current State
```
agent_operating_guidelines.md  → 1,185 lines (the "bible")
CLAUDE.md                      → 271 lines (duplicates bible)
8 checklists                   → 2,198 lines (duplicates both)
```

### Proposed State
```
QUICK_START.md        → 50 lines (just the gates and /verify)
PRINCIPLES.md         → Keep as-is (rationale, for reference)
orchestrator-agent.md → Enhanced (becomes the actual controller)
```

### The 50-Line Rule

Agents should need to read **at most 50 lines** to know what to do. Everything else should be:
- **Referenced on demand** (not read upfront)
- **Enforced by gates** (not remembered)
- **Kept for humans** (rationale, fine-tuning notes)

---

## The "Bloat" Problem

The user noted: "everytime we develop this framework new stuff gets added... cleaning is not done as well."

### Root Cause
Each problem gets a new file:
- Agent forgets tests → Add `test_strategy.md`
- Agent doesn't journal → Add `automatic_journaling.md`
- Agent skips review → Add `review_checklist.md`

### Solution: Subtraction-First Development

```markdown
# Before adding ANY new file:
1. Can this be a gate in existing verification?
2. Can this be merged into an existing workflow?
3. Can this be automated (not instructed)?

# Only add new file if:
- It's a genuinely new concept
- It can't be expressed as a gate
- It's short (<100 lines)
```

### Cleanup Checklist

| Current File | Disposition |
|--------------|-------------|
| `verify.sh` | Merge into `doctor.sh` |
| `consistency.sh` | Merge into `doctor.sh` |
| `validate_specs.py` | Merge into `doctor.sh` |
| `check-untracked.sh` | Merge into `doctor.sh` |
| `automatic_journaling.md` | Reduce to gate in verification |
| All checklists | Extract gates, archive rest |

---

## Concrete Recommendations

### Priority 1: Create the Verification Command

**File**: `.agentic/tools/verify.sh` (enhanced)

```bash
#!/bin/bash
# THE magic command - detects phase, runs appropriate checks

PHASE=$(detect_current_phase)

case $PHASE in
  start)     check_wip && check_context_loaded ;;
  planning)  check_acceptance_exists ;;
  implement) check_tests_exist && check_acceptance_mapped ;;
  complete)  check_all_tests_pass && check_docs_synced ;;
  commit)    full_verification ;;
esac

report_results
suggest_next_action
```

### Priority 2: Simplify Instructions to 50 Lines

**File**: `.agentic/QUICK_START.md`

```markdown
# Agent Quick Start

## The One Rule
Before any phase transition, run `/verify`.

## Phases
START → PLAN → IMPLEMENT → COMPLETE → COMMIT

## Commands
- `/verify` - Check current phase gates
- `/status` - Show feature state
- `/next` - What to do next

## If Stuck
Ask human. Add to HUMAN_NEEDED.md.

## Details
See `agent_operating_guidelines.md` for rationale.
See `PRINCIPLES.md` for philosophy.
```

### Priority 3: Hook /verify into Tool Workflows

**Claude Code Hooks** (already exists):
```yaml
PreToolExecution:
  - script: .agentic/hooks/check-phase.sh
```

**Cursor Rules**:
```json
{
  "beforeSave": "verify --quick"
}
```

### Priority 4: Activate Orchestrator

Make `orchestrator-agent.md` the default for feature work:
- Reference it prominently in CLAUDE.md
- Have it delegate to specialized agents
- Have it run /verify at each phase transition

---

## The Determinism Guarantee

With gates instead of instructions:

| Old World | New World |
|-----------|-----------|
| "Agent should check criteria" | Gate blocks without criteria |
| "Agent should update FEATURES.md" | Gate fails if not updated |
| "Agent should run tests" | Gate fails if tests fail |
| "Remember to journal" | Gate blocks commit without journal |

**Determinism** comes from **enforcement**, not **instruction**.

---

## For Other Tools (Cursor, etc.)

The `/verify` pattern works anywhere:

**Cursor**: Add to `.cursorrules`:
```
Before completing any feature:
1. Run: bash .agentic/tools/verify.sh
2. If any gates fail, fix before proceeding
3. Show verification output to user
```

**Generic**: The slash command `/verify` becomes the universal checkpoint. Every AI coding tool can implement it.

---

## Migration Path

1. **v0.11.0**: Add enhanced `verify.sh` (additive, no breaking changes)
2. **v0.12.0**: Simplify CLAUDE.md to 50 lines, reference verify.sh
3. **v0.13.0**: Archive redundant checklists (keep as "detailed reference")
4. **v0.14.0**: Make orchestrator the default entry point

---

## Summary: My Different Perspective

The previous review said: "Consolidate tools, reduce documentation."

I'm saying: **"Shift from instruction to enforcement."**

- Don't tell agents what to do in 1000 lines
- Make gates that block wrong actions
- One command (`/verify`) replaces all checklists
- Orchestrator coordinates, agents specialize
- Keep rationale docs for fine-tuning, not for agents to read

The result: Agents don't need to remember anything. The system remembers for them.

---

## Files To Create/Modify

| File | Action | Priority |
|------|--------|----------|
| `.agentic/tools/verify.sh` | Enhance to be THE verification command | P1 |
| `.agentic/QUICK_START.md` | NEW: 50-line agent instructions | P1 |
| `CLAUDE.md` | Reduce to point at QUICK_START + orchestrator | P2 |
| `.agentic/hooks/pre-phase.sh` | NEW: Hook /verify into workflows | P2 |
| Checklists | Archive, extract gates into verify.sh | P3 |
| `agent_operating_guidelines.md` | Keep as reference, not required reading | P3 |

---

**Review completed by**: Claude Opus 4.5
**Differs from previous review**: Focus on gates vs instructions, not just consolidation
