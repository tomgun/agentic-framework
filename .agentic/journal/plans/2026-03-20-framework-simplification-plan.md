# Plan: Framework Simplification & Structural Enforcement

**Status**: IN PROGRESS (Phase 1 complete, Phases 2-4 remaining)
**Timeline**: ~6-8 weeks total
**Branch**: feat/v2-workflow-engine (PR #177)

---

## Phase 1: Core State Machine CLI (~1 week) ✅ COMPLETE

Built the new v2 workflow engine alongside the old system:
- `state_machine_af.yaml` — single config file (10 states, 14 transitions, 2 modes, 3 profiles)
- Python engine in `.agentic/lib/auto/v2/` (config, work_items, preconditions, transitions, workflow)
- Per-work-item dirs (`.agentic/work/F-XXXX/`) with item.yaml + artifact files
- 7 role prompts (`.agentic/prompts/`) loaded JIT on transitions
- `ag.sh` routes `ag start/transition/check/verify/ship/status/info/next` to v2 when `engine: v2`
- 46+ tests, review fixes applied (security, atomicity, parser safety)

---

## Phase 2: Auto System Rearchitecture (~2-3 weeks) — NEXT

The autonomous execution system (250KB+ Python) is rearchitected to use the new state machine CLI as its backbone.

### What Changes

| Component | Current | New |
|-----------|---------|-----|
| `engine.py` (24KB) | Orchestrates agents, manages its own state | Delegates state transitions to `TransitionOrchestrator` |
| `epic.py` (24KB) | Epic decomposition + execution | Creates work items in `.agentic/work/`, uses transitions |
| `critical_agent.py` (24KB) | Adversarial review as separate system | Becomes a `gate: ai` implementation in transition gates |
| `kickoff.py` (45KB) | Vision-to-backlog pipeline | Creates work items in new format directly |
| `plan_convergence.py` (18KB) | Dialectical review system | Becomes the `plan_review` gate (invoked by transition) |
| `review.py` (27KB) | Review decision routing | Becomes gate dispatch (human/ai/skip per profile) |
| `scheduler.py` (27KB) | Task scheduling | Uses backlog from state_machine_af.yaml + work item priorities |

### Key Changes

- **Before**: Auto system had its own state tracking (`auto-state.json`, `crunch-state.json`) separate from feature states in FEATURES.md.
- **After**: Auto system reads/writes feature state exclusively through `TransitionOrchestrator`. No separate state files. The work item's `item.yaml` IS the single source of truth.
- **Before**: `engine.py` spawned Claude instances with custom prompts assembled from 24 context manifests.
- **After**: `engine.py` spawns Claude instances with role prompts from `.agentic/prompts/`. Context is the work item directory contents + project context.

### Files to Refactor

- `engine.py` → Use `TransitionOrchestrator` for state changes
- `epic.py` → Create `item.yaml` per child feature in `.agentic/work/`
- `critical_agent.py` → Extract core review logic; wire as `ai` gate implementation
- `kickoff.py` → Create work items in new format
- `plan_convergence.py` → Wire as `plan_review` gate
- `review.py` → Simplify to gate dispatch
- `scheduler.py` → Read work item priorities from `item.yaml` files

### Auto Commands Preserved

All `ag auto` commands keep working:
- `ag auto verify F-XXXX`
- `ag auto task F-XXXX`
- `ag auto epic F-XXXX`
- `ag auto pipeline`
- `ag auto crunch`

---

## Phase 3: Instruction Consolidation & File Reduction (~1 week)

With the CLI enforcing workflows, most instruction files become unnecessary.

### Eliminate Redundant Instruction Layers

**Current instruction surface (what agents must process):**
- CLAUDE.md (40 lines) × 4 tool variants
- auto_orchestration.md (442 lines)
- agent_operating_guidelines.md (127 lines)
- 12 Skills with SKILL.md + references (thousands of lines)
- 9 checklists (hundreds of lines)
- 20+ workflow documents
- 9 quality standards
- memory-seed.md (137 lines)

**Proposed instruction surface:**
- CLAUDE.md (~30 lines) — points to `ag` CLI commands, nothing else
- 7 Role Prompts (~50 lines each) — loaded by CLI at the right moment
- 1 project context file (generated from state_machine_af.yaml + current state)

### New CLAUDE.md (Template) — already created as CLAUDE.v2.md

### Role Prompts Replace Skills + Checklists + Workflows

7 role prompts (already created in Phase 1):
- Phase-based: planner.md, reviewer.md, implementer.md, verifier.md
- Activity-based: debugger.md, session.md, explorer.md

### Files to Remove/Archive (in batches, not big-bang)

| Category | Files | Count | Action |
|----------|-------|-------|--------|
| Skills | `.claude/skills/*`, `.agentic/lib/agents/claude/skills/*` | ~60 | Archive → replace with 7 role prompts |
| Checklists | `.agentic/lib/checklists/*` | 10 | Absorb into CLI preconditions + role prompts |
| Workflow docs | `.agentic/lib/workflows/*` | 20+ | Archive (reference only) |
| Quality standards | `.agentic/lib/quality/*` | 9 | Consolidate into `conventions.md` |
| auto_orchestration.md | `.agentic/lib/agents/shared/` | 1 | Remove — CLI replaces workflow instructions |
| agent_operating_guidelines.md | `.agentic/lib/agents/shared/` | 1 | Remove — CLI replaces behavioral rules |
| Subagent roles | `.agentic/lib/agents/claude/subagents/*` | 36 | Reduce to 7 role prompts |
| Context manifests | `.agentic/lib/agents/shared/context-manifests/*` | 24 | Absorb into role prompts |
| memory-seed.md | `.agentic/lib/init/` | 1 | Reduce to ~10 lines ("use `ag` commands") |
| Old command modules | `.agentic/lib/tools/commands/*` | 37 | Remove (replaced by Python workflow.py) |
| Scattered docs | Various README.md, guides | 30+ | Consolidate into 1 DEVELOPER_GUIDE |

**Estimated reduction: 554 files → ~80 files (85% reduction)**

---

## Phase 4: Tool Adapters & MCP (~1-2 weeks)

### Generated Tool-Specific Files

```bash
ag export claude    → generates .claude/CLAUDE.md
ag export cursor    → generates .cursor/rules/ag.mdc
ag export copilot   → generates .github/copilot-instructions.md
ag export codex     → generates AGENTS.md
```

### Optional MCP Server

MCP tools (minimal surface):
- `ag.status()`, `ag.transition(id, state)`, `ag.check(id)`, `ag.verify(id)`, `ag.read_artifact(id, name)`

Strongest enforcement: if the agent can ONLY interact through MCP tools, skipping becomes truly impossible.

### Claude Code Hooks → `ag check`

Wire PostToolUse/PreToolUse hooks to `ag check` for enforcement at the tool level.

---

## Backlog Impact

### Features ABSORBED by this refactor
F-0223, F-0228, F-0233, F-0213, F-0210, F-0211, F-0212

### Features that REMAIN (orthogonal)
F-0220, F-0193, F-0242, F-0243, F-0227

### Features that become LATER PHASES
F-0230 (MCP), F-0231 (Multi-Repo), F-0232 (Full Scheduling)

---

## What Stays (proven patterns)
1. `ag` command name
2. Token-efficient scripts (journal.sh, status.sh, feature.sh, blocker.sh, todo.sh)
3. Pre-commit hooks (simplified to call `ag check`)
4. Feature IDs (F-XXXX)
5. Two modes: formal + lean
6. Three profiles: hands_on, guided, autonomous
7. Claude Code hooks (rewired to `ag check`)
8. Core Python modules (state_machine.py, gates.py, settings.py — enhanced)
