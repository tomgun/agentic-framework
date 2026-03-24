# Plan: Framework Simplification & Structural Enforcement

**Status**: IN PROGRESS (Phase 1 ✅, Phase 2 ✅, Phase 3 ✅, Phase 4 ✅)
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

## Phase 2: Auto System Rearchitecture (~3-4 weeks) — NEXT

**Reviewed**: 2026-03-20 (Critic + Advocate dialectical review, 2 iterations → APPROVED)
**Review notes**: Iteration 1 found 4 high-confidence concerns (dual-truth, dependency graph, missing execution model, lossy state mapping) + 6 gaps. All resolved in revision. Iteration 2 confirmed convergence with 2 minor fixes (artifact location, missing files in map) applied inline.

The autonomous execution system (26 Python files, ~13K lines) is rearchitected to use the v2 state machine as its backbone. The refactor proceeds in 4 sub-phases with a compatibility layer ensuring no breakage between steps.

### Architecture: Three Layers

```
┌─────────────────────────────────────────────┐
│  CLI Commands (ag auto task/epic/crunch/...) │  ← unchanged surface
├─────────────────────────────────────────────┤
│  Execution Layer (task.py, verify.py)        │  ← retains AC iteration,
│  spawn_claude, test-fix loops, PR creation   │     Claude spawning, commits
├─────────────────────────────────────────────┤
│  Orchestration Layer (TransitionOrchestrator)│  ← NEW: state transitions,
│  work items, artifact checks, gate dispatch  │     audit trail, enforcement
├─────────────────────────────────────────────┤
│  Compatibility Shim (features_sync.py)       │  ← NEW: writes FEATURES.md
│  Keeps FEATURES.md in sync during migration  │     on every v2 transition
└─────────────────────────────────────────────┘
```

**Key insight**: The execution layer (how Claude implements ACs) is orthogonal to the orchestration layer (what state the feature is in). Phase 2 replaces the orchestration backbone without rewriting the execution logic.

### Sub-Phase 2A: Compatibility Shim + Gate Dispatch (~3-4 days)

**Problem**: 11 files read FEATURES.md directly. If v2 transitions only write `item.yaml`, downstream consumers see stale state.

**Solution**: `features_sync.py` — a write-through shim that keeps FEATURES.md in sync whenever `TransitionOrchestrator.transition()` fires.

```python
# features_sync.py (new, ~80 lines)
class FeaturesSyncHook:
    """Post-transition hook: maps v2 state → v1 state, writes FEATURES.md via feature.sh"""
    def on_transition(self, feature_id, from_state, to_state):
        v1_state = REVERSE_STATE_MAP[to_state]  # v2→v1 mapping
        run_feature_sh(feature_id, "status", v1_state)
```

Wire into `TransitionOrchestrator.transition()` as a post-transition callback. This means ALL existing code that reads FEATURES.md keeps working unchanged. The shim is removed in Phase 3 when FEATURES.md consumers are eliminated.

Also in 2A — **gate dispatch module** (`gate_dispatch.py`, ~150 lines):
- Receives `(gate_name, profile, feature_id, context)` from TransitionOrchestrator
- Routes to: `human` (block + log to HUMAN_NEEDED), `ai` (call CriticalAgent), `skip` (audit-log only)
- Replaces `review.py`'s scattered `get_review_mode()` + manual routing
- `plan_convergence.py`'s `ConvergenceLoop` wired as the `plan_approved` gate handler (multi-step process behind a single gate interface — gate handlers are NOT limited to synchronous checks)

**Files created**: `features_sync.py`, `gate_dispatch.py`
**Files modified**: `transitions.py` (add post-transition hook + gate handler dispatch)
**Tests**: Unit tests for shim (transition → FEATURES.md state matches), gate routing

### Sub-Phase 2B: State Consumers (~4-5 days)

Migrate modules that READ feature state to use v2 work items (with FEATURES.md shim as safety net).

| File | Lines | Change | Complexity |
|------|-------|--------|------------|
| `state_machine.py` (606) | State queries | Add `v2_adapter` that delegates to `TransitionOrchestrator` when `engine: v2`. `FeatureStateMachine` becomes a thin wrapper. | Medium |
| `gates.py` (469) | Precondition checks | Replace ad-hoc gate functions with `preconditions.py` checks. Keep `register_default_gates()` as adapter for v1 callers. | Medium |
| `review.py` (794) | Review routing | Simplify to: read gate config from profile → delegate to `gate_dispatch.py`. Retain `check_review()` / `resolve_review()` API for callers. | Medium |
| `critical_agent.py` (650) | AI review | Extract core `review()` into `gate_dispatch.py`'s `ai` handler. `CriticalAgent` class retained but invoked through gate dispatch, not directly. | Low |
| `plan_convergence.py` (551) | Plan review | `ConvergenceLoop` becomes the handler behind `plan_approved` gate. No internal changes needed — just the invocation path changes. | Low |
| `coord_tools.py` (266) | Status queries | Replace `FeatureStateMachine` import with `work_items.list_items()`. | Low |
| `intents.py` (574) | Recovery | Add v2 work item awareness to orphan detection (check `.agentic/work/` for stale items). | Low |

**Preserving fine-grained gates**: v1 distinguishes `specced → criteria_set → tests_written → implementing` with distinct checks. v2 collapses to `spec → implementation`. The enforcement survives as **artifact preconditions**:
- `spec → implementation` requires: `spec.md` — the artifact check must point to `spec/acceptance/{feature_id}.md` (NOT `{work_dir}/spec.md`). Update `state_machine_af.yaml` artifact location accordingly, or have the spec workflow copy/symlink to the work dir.
- `implementation → verification` requires: `tests_exist` — this is an EXIT gate from implementation (tests must exist before you can claim verification), not an entry gate. This matches natural workflow: write code, then verify tests exist before moving to verification.
- The `tests_exist` artifact check is improved from the naive `grep -rl` to: `python3 -c "import sys; sys.exit(0 if any(Path('tests').rglob(f'*{feature_id}*')) else 1)"` — checks for test files named after the feature, not just string mentions

**Tests**: Integration tests: create work item → transition through full lifecycle → verify FEATURES.md stays in sync at every step

### Sub-Phase 2C: Execution Layer Integration (~5-7 days)

The core execution chain (`scheduler → task → engine → verify → spawn_claude`) gets wired to use TransitionOrchestrator for state management while preserving execution logic.

| File | Lines | Change | Complexity |
|------|-------|--------|------------|
| `engine.py` (675) | Execution engine | Replace `EngineState._state` tracking with work item status reads. Replace `_save_state()` with `TransitionOrchestrator.transition()`. Retain: `ControlServer` (socket infra), AC iteration loop, `spawn_claude` calls, complexity estimation. | High |
| `task.py` (609) | Task runner | Replace `engine_state.set_ac_status()` with work item artifact writes (write AC results to `.agentic/work/F-XXXX/ac_results.yaml`). Replace `_commit_ac()` review check with gate dispatch. Retain: branch creation, per-AC Claude spawning, verify loop, PR creation. | High |
| `scheduler.py` (767) | Scheduling | Replace `FeatureWork` tracking dict with `work_items.list_by_status()`. Replace `_get_actionable()` with `TransitionOrchestrator.can_transition()`. Replace `_is_review_blocked()` with gate status check. Retain: component scoping, parallel dispatch, result aggregation. | High |
| `verify.py` (931) | Test-fix loop | Mostly unchanged — already stateless. Add: write `verification.json` artifact to work item dir on completion (enables `verification_pass` precondition check). | Low |
| `crunch.py` (340) | Batch wrapper | Minimal change — delegates to scheduler. Update `SchedulerResult` mapping to use v2 states. | Low |
| `pipeline.py` (352) | Epic pipeline | Update to create work items via `work_items.create()` after kickoff promotion. | Low |
| `parallel.py` (427) | Parallel exec | Unchanged — spawns subprocesses that run `ag auto task`, which handles v2 internally. | None |

**Execution model (the critical gap from the original plan)**:

The execution model does NOT change. TransitionOrchestrator manages *what state the feature is in*. The execution chain manages *how work gets done*:

```
scheduler._get_actionable()
  → TransitionOrchestrator.can_transition(F-XXXX, "implementation")  # replaces: read FEATURES.md
  → TaskRunner.run(F-XXXX)
    → engine._load_acceptance_criteria()  # unchanged: reads spec/acceptance/F-XXXX.md
    → for ac in criteria:
        spawn_claude(ac_prompt)           # unchanged: spawns Claude per AC
        verify_loop.run()                 # unchanged: test-fix cycle
        write_ac_result(work_item_dir)    # NEW: artifact to work item dir
    → TransitionOrchestrator.transition(F-XXXX, "verification")  # replaces: feature.sh
    → verify_loop.run_full()              # unchanged
    → write_verification_json()           # NEW: artifact to work item dir
    → TransitionOrchestrator.transition(F-XXXX, "docs")          # replaces: feature.sh
    → create_pr()                         # unchanged
```

**Prompt enrichment**: Role prompts (`.agentic/prompts/implementer.md` etc.) provide phase guidance. Per-AC specificity comes from the same source as today: the AC text, feature spec, and project context. The role prompt is PREPENDED to the existing prompt, not a replacement. `engine.py`'s prompt assembly narrows with each AC:

```python
prompt = role_prompt + "\n\n"              # phase guidance (NEW)
prompt += f"Feature: {feature_id}\n"       # unchanged
prompt += f"AC: {ac.text}\n"               # unchanged
prompt += f"Complexity: {estimate}\n"      # unchanged
prompt += feedback_section                 # unchanged (from ControlServer)
prompt += project_context                  # unchanged (from STACK.md/CONTEXT_PACK.md)
```

**ControlServer** (engine.py:126-255): Retained as-is. It reads/writes `EngineState` for pause/resume/stop — this is *runtime execution state* (is the engine paused?), not *feature lifecycle state* (is the feature in implementation?). These are separate concerns. EngineState keeps `_state` (idle/running/paused/stopping/stopped), `_current_ac`, `_progress`, `_feedback`. Only `_progress` tracking changes — AC results also write to work item dir for durability.

**Tests**: End-to-end test: `ag auto task F-TEST` creates work item, transitions through states, produces artifacts in `.agentic/work/F-TEST/`, and FEATURES.md stays in sync via shim.

### Sub-Phase 2D: Feature Management (~3-4 days)

| File | Lines | Change | Complexity |
|------|-------|--------|------------|
| `epic.py` (762) | Epic management | Replace FEATURES.md parsing (13 helper functions) with `work_items` API. `decompose_epic()` creates child work items via `work_items.create(parent=epic_id)`. `_get_children_statuses()` → `work_items.list_items()` filtered by parent. Still writes FEATURES.md via shim. | High |
| `kickoff.py` (1321) | Vision pipeline | After `promote_staging_with_ids()`, also create work items via `work_items.create()` for each promoted feature. Existing FEATURES.md write path kept (shim ensures sync). | Medium |
| `framework_verify.py` (2066) | Framework validation | Read-only consumer of FEATURES.md — works unchanged via shim. No refactoring in Phase 2 (defer to Phase 3). | None |
| `pr_review.py` (428) | PR review | No state deps. Unchanged. | None |
| `self_heal.py` (237) | Error recovery | No state deps. Unchanged. | None |
| `reviewer_catalog.py` (137) | Reviewer roles | Consumed by `plan_convergence.py` and `gate_dispatch.py`. Unchanged. | None |
| `components.py` (328) | Component registry | No state deps. Unchanged. | None |
| `umbrella.py` (274) | Multi-repo | No state deps. Unchanged. | None |
| `visual.py` (171) | Rendering | No state deps. Unchanged. | None |
| `control.py` (192) | Socket control | No state deps. Unchanged. | None |
| `init.py` (238) | Framework init | No state deps. Unchanged. | None |

### Full Dependency Map (26 files)

**Refactored** (13 files): engine.py, task.py, scheduler.py, epic.py, kickoff.py, review.py, critical_agent.py, plan_convergence.py, state_machine.py, gates.py, verify.py, crunch.py, pipeline.py
**New** (2 files): features_sync.py, gate_dispatch.py
**Adapted** (2 files): coord_tools.py, intents.py
**Unchanged** (13 files): parallel.py, pr_review.py, framework_verify.py, self_heal.py, reviewer_catalog.py, components.py, umbrella.py, visual.py, control.py, init.py, __init__.py (spawn_claude), integration_verify.py (reads feature state but via shim — no changes needed), coord_server.py (HTTP coordination — no state deps)

### Refactoring Order (dependency-safe)

```
Sub-phase 2A (no deps):
  features_sync.py (new) → transitions.py (hook)
  gate_dispatch.py (new) → transitions.py (gate handler)

Sub-phase 2B (state consumers, any order):
  state_machine.py → gates.py → review.py → critical_agent.py
  plan_convergence.py (independent)
  coord_tools.py, intents.py (independent)

Sub-phase 2C (execution chain, bottom-up):
  verify.py (add artifact write) → task.py → engine.py → scheduler.py
  crunch.py, pipeline.py (thin wrappers, last)

Sub-phase 2D (feature management):
  epic.py → kickoff.py (both touch FEATURES.md heavily)
```

### Testing Strategy

**Unit tests** (per sub-phase):
- 2A: `test_features_sync.py` — transition → FEATURES.md state correct for all 10 states
- 2A: `test_gate_dispatch.py` — human/ai/skip routing, convergence loop integration
- 2B: `test_state_machine_v2_adapter.py` — v2 adapter returns same results as v1 for all queries
- 2C: `test_task_v2.py` — TaskRunner writes artifacts to work item dir
- 2D: `test_epic_v2.py` — decompose creates child work items with parent links

**Integration tests** (end-to-end):
- `test_auto_task_e2e.py` — `ag auto task F-TEST`: work item created → ACs loaded → transitions fire → artifacts written → FEATURES.md in sync
- `test_auto_epic_e2e.py` — `ag auto epic F-TEST`: decompose → child work items → schedule → all children complete
- `test_auto_crunch_e2e.py` — `ag auto crunch`: batch scheduling uses work item priorities
**Validation gate**: `validate_framework.sh` must pass after each sub-phase commit. No sub-phase merges without green validation.

### Auto Commands Preserved

All `ag auto` commands keep working:
- `ag auto verify F-XXXX` — unchanged (verify.py is stateless, adds artifact write)
- `ag auto task F-XXXX` — uses TransitionOrchestrator for state, same execution model
- `ag auto epic F-XXXX` — creates child work items, schedules via v2
- `ag auto pipeline` — kickoff → work items → schedule
- `ag auto crunch` — batch wrapper, delegates to scheduler

### What the `docs_updated` Artifact Check Actually Does

The `|| true` in the YAML check is intentional for `lean` mode (escape hatches allowed). In `formal` mode, the artifact check is: does `.agentic/work/F-XXXX/docs_updated` marker file exist? This file is created by `task.py._check_and_update_docs()` after drift.sh confirms docs are current. The command-based check is a secondary verification, not the primary gate.

---

## Phase 3: Instruction Consolidation & File Reduction (~2-3 weeks)

**Reviewed**: 2026-03-20 (review found 3 critical issues, 4 important issues, 4 minor issues — all resolved in revision)

Phase 2 is complete — the v2 engine structurally enforces workflows via CLI (8 commands). Agents can't skip steps because the CLI blocks invalid transitions and loads role prompts JIT at each state.

~131 instruction files (~33K lines) that told agents WHAT to do are now redundant. Phase 3 removes the dead weight.

**Scope boundary**: Phase 3 is instruction consolidation only. FEATURES.md consumer migration and old command module migration (36 non-v2 commands) are separate future efforts. `features_sync.py` is explicitly KEPT.

### Sub-Phase 3A: Update `validate_framework.sh` for v2 Mode
- Add v2 detection (`engine: v2` in state_machine_af.yaml)
- v2 checks: YAML structure, 7 role prompts, conventions.md, work item dirs, skill stubs, tool templates
- v1 mode unchanged

### Sub-Phase 3B: Enrich Role Prompts + Create `conventions.md`
- Enrich 7 prompts from 209 → ~350 lines (absorb quality guidance CLI can't enforce)
- Create `.agentic/conventions.md` (~100 lines) from programming_standards + green_coding + small-batch
- 5 behavioral test scenarios must pass before proceeding

### Sub-Phase 3C: Simplify Skills + Templates + Tool Scripts
- Skills split: Tier 1 (v2-command, 15-25 lines) + Tier 2 (non-v2-command, 30-40 lines)
- Delete all `references/` subdirectories
- Update 4 tool templates, 3 root wrappers, ~8 tool scripts (context-for-role.sh etc.)

### Sub-Phase 3D: Delete Files (4 batches, 1 commit each)
- Batch 1: workflows/ (35 files, ~14K lines)
- Batch 2: checklists/ (10 files, ~2.9K lines)
- Batch 3: quality/ + shared guidelines (~15 files, ~5K lines, KEEP reviewer_roles.json)
- Batch 4: subagents/ (35 files) + memory-seed trim

### Sub-Phase 3E: Documentation + Migration Guide
- MIGRATION_v2.md, upgrade.sh, framework docs, auto-memory cleanup

**Dependency**: 3A‖3B → 3C → 3D → 3E
**Impact**: ~131 files / ~33K lines → ~25 files / ~3K lines

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
F-0220, F-0193, F-0242, DEV-0243, F-0227

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
