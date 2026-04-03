# Plan: Framework Simplification & Structural Enforcement

## Context

The framework has grown to **554 files** in `.agentic/lib/`, **122 shell scripts**, and **12 skills** — yet still fails at basic workflow steps: saving plans after plan mode, running reviews, updating docs after implementation. The root cause is **instruction-based enforcement** — agents are TOLD to do things but nothing FORCES them.

The user's research document (`2026-03-20-minimal-reliable-agentic-development.md`) identifies the fix: **shift correctness from "the model remembered" to "the system makes skipping impossible"** via a file-backed workflow engine with a state machine, artifact contracts, and machine-checkable gates.

The framework's own principles already agree (D2: Deterministic Enforcement, INSTRUCTION_ARCHITECTURE.md: "Never rely on memory"). The gap is that the framework doesn't live up to its own principles — too much complexity, too many instruction layers, and enforcement that leaks through bash escape hatches.

**Goals:**
1. **Simplify** — dramatically reduce file count, consolidate instruction layers
2. **Make it reliable** — structural enforcement that makes skipping steps impossible

**Key Decisions (from user):**
- Keep `ag` command name (preserve muscle memory)
- Config file named `state_machine_af.yaml`
- Strict sequential phases (new system alongside old, then remove old)
- Include auto system in refactor (engine, epic, scheduler rearchitected)
- Minimal PR triage needed (maybe one open PR)

---

## Dialectical Review Revisions

This plan was reviewed by Critic + Advocate agents. Key revisions applied:
1. **Phase 2 timeline expanded** from ~1 week to ~2-3 weeks (auto system is 5,520 lines across 7 deeply-integrated files)
2. **Role prompts expanded** from 4 to 7 (bug fixing, session management, and exploration are not "phases" — they need their own prompts)
3. **State model mapping added** — current 9 states mapped to proposed 10 states
4. **STACK.md fate defined** — only workflow settings move to `state_machine_af.yaml`; tech stack, testing, deployment stay in STACK.md
5. **Escape hatch policy added** — formal: none; lean: audit-logged overrides
6. **WIP commit concept added** — in-progress work can be committed without completing the full pipeline
7. **Phase 3 made incremental** — remove files in batches, not big-bang
8. **Early LLM proof-of-concept** — test minimal CLAUDE.md in Phase 1, not Phase 3

**No migration strategy needed** — framework is still in beta, no production projects to migrate.

**Overall timeline adjusted: ~6-8 weeks (not ~4-5 weeks)**

---

## Diagnosis: Why the Framework Fails at What It Promises

| Failure | Root Cause | Current "Fix" | Why It Fails |
|---------|-----------|---------------|--------------|
| Agent doesn't save plan after plan mode | Instruction-based (hook TELLS agent to save) | F-0234 ExitPlanMode hook | Hook output is advisory; agent ignores in long sessions |
| Agent skips dialectical review | Instruction-based (memory-seed, CLAUDE.md say "auto-continue") | Plan convergence system (plan_convergence.py) | Agent rationalizes "plan is simple, review unnecessary" |
| Agent doesn't update docs | Instruction-based (implementing-features skill says "update docs") | drift.sh, docs.sh | Checked at commit time — too late; agent says "done" before running checks |
| Agent starts coding without spec | Instruction-based (trigger words say "spec first") | `ag implement` checks for AC file | 8 escape hatches (`SKIP_SPEC_CHECK=1` etc.) in implement.sh |

**Pattern**: Every failure is the same — the framework INSTRUCTS but doesn't ENFORCE. Enforcement exists (pre-commit hooks, state machine) but has escape hatches and runs too late.

---

## Architecture: From Instruction-Driven to State-Machine-Driven

### Current (3 layers, 554 files, instruction-heavy)

```
Constitution (40-line CLAUDE.md × 4 tools)
  → Playbooks (442-line auto_orchestration + 12 skills + 9 checklists + 20 workflows + 9 quality docs)
    → State (STACK.md, STATUS.md, FEATURES.md, JOURNAL.md, AGENTS.json)
      → Defense (pre-commit hooks, tool hooks, memory-seed)
```

### Proposed (2 layers, ~80 files, enforcement-heavy)

```
Config (state_machine_af.yaml: states, transitions, gates, modes, profiles, verification)
  → CLI State Machine (`ag` commands backed by Python engine)
    → Artifacts (per-work-item directories with plan.md, spec.md, review.md, etc.)
      → Tool Adapters (generated CLAUDE.md, .cursorrules, etc. — thin pointers)
```

**The key shift**: Instead of 442 lines of workflow instructions that agents must remember, the CLI REFUSES to proceed without required artifacts. The agent's job becomes "produce artifacts" not "remember the workflow."

---

## Phase 1: Core State Machine CLI (~1 week)

Build new system alongside old. Old `ag` commands continue working. New engine activated via `engine: v2` in config.

### 1.1 Create `state_machine_af.yaml` — Single Configuration File

Replaces: STACK.md workflow settings, scattered profile configs, hardcoded states in state_machine.py

```yaml
version: 1

workflow:
  states: [idea, queued, planning, plan_review, spec, implementation, verification, docs, ready_to_ship, shipped]
  transitions:
    - { from: idea, to: queued }
    - { from: queued, to: planning }
    - { from: planning, to: plan_review, requires: [plan.md] }
    - { from: plan_review, to: spec, requires: [review.md], gate: plan_approved }
    - { from: spec, to: implementation, requires: [spec.md] }
    - { from: implementation, to: verification, requires: [tests_exist] }
    - { from: verification, to: docs, requires: [verification_pass] }
    - { from: docs, to: ready_to_ship, requires: [docs_updated, pr.md] }
    - { from: ready_to_ship, to: shipped, gate: pr_merged }

modes:
  formal:
    skip_transitions: []  # No skipping in formal
    required_artifacts:
      spec: [spec.md]
      implementation: [spec.md, plan.md]
      shipped: [contract_snapshot.md]
  lean:
    skip_transitions:
      - { from: queued, to: implementation }  # Skip planning for small tasks
      - { from: planning, to: implementation }  # Skip review for lean
    required_artifacts:
      implementation: [journal.md]
      shipped: []

profiles:
  hands_on:
    gates: { plan_review: human, spec_review: human, code_review: human, merge: human }
  guided:
    gates: { plan_review: human, spec_review: human, code_review: ai, merge: human }
  autonomous:
    gates: { plan_review: ai, spec_review: ai, code_review: ai, merge: human }

verification:
  commands:
    - { name: tests, run: "make test" }
    - { name: lint, run: "make lint" }

docs_policy:
  require_update_on_code_change: true
  docs_paths: ["docs/**", "README.md"]
```

**Key files to create:**
- `.agentic/state_machine_af.yaml` — the workflow config
- `.agentic/schemas/af-state-machine-schema.json` — JSON Schema for validation
- `.agentic/schemas/af-item-schema.json` — JSON Schema for work item YAML

### 1.2 Per-Work-Item Directories

Replaces: scattered files across spec/acceptance/, journal/plans/, journal/evidence/, FEATURES.md central registry

```
.agentic/work/
  F-0244/
    item.yaml        # Status, mode, profile, metadata, transition log
    plan.md          # Plan artifact
    spec.md          # Acceptance criteria + spec (merged from separate files)
    review.md        # Adversarial review output
    journal.md       # Per-feature decisions and changes
    verification.json # Test results
    pr.md            # PR description
    handoff.md       # Session handoff context
```

**`item.yaml` example:**
```yaml
id: F-0244
title: Password reset flow
type: feature
status: planning
mode: formal
profile: guided
priority: 1
branch: feat/F-0244
created: "2026-03-20"
updated: "2026-03-20"
transitions:
  - { from: idea, to: planning, at: "2026-03-20T14:30:00Z", by: agent }
```

### 1.3 Python State Machine Engine

Replaces: ag.sh dispatch + 37 bash command modules → unified Python engine

**New files** (in `.agentic/lib/auto/`):
- `workflow.py` — main entry point, maps `ag` commands to transition sequences
- `preconditions.py` — artifact existence checks extracted from bash
- `artifacts.py` — artifact contract enforcement (per mode/profile)
- `transitions.py` — `TransitionOrchestrator` that atomically runs gates + reviews + state update

**Reused** (existing Python):
- `state_machine.py` — enhanced with config-driven states/transitions from state_machine_af.yaml
- `gates.py` — enhanced with per-profile gate registry
- `settings.py` — reads state_machine_af.yaml alongside STACK.md
- `intents.py` — write-ahead logging for crash recovery

**How `ag` commands change:**
```bash
# ag.sh becomes a thin dispatcher:
ag implement F-XXXX  →  python3 -m agentic.workflow implement F-XXXX
ag done F-XXXX       →  python3 -m agentic.workflow done F-XXXX
ag plan F-XXXX       →  python3 -m agentic.workflow plan F-XXXX
ag commit            →  python3 -m agentic.workflow commit
ag transition F-XXXX implementing  →  python3 -m agentic.workflow transition F-XXXX implementing
```

**The critical behavior** — `ag transition` reads `state_machine_af.yaml`, checks:
1. Is this a valid transition from current state?
2. Are required artifacts present in `.agentic/work/F-XXXX/`?
3. Does the gate pass (human/ai/skip per profile)?
4. If any check fails → **hard error with specific message** (no escape hatches in formal mode)

### 1.4 `ag` Command Mapping

| New Command | What It Does | Replaces |
|---------|-------------|----------|
| `ag init` | Create state_machine_af.yaml, schemas, work/ dir | `ag init` (enhanced) |
| `ag start F-XXXX` | Create work item dir, move to planning | `ag implement` (setup portion) |
| `ag transition F-XXXX <state>` | Enforce transition with preconditions | `ag transition` + scattered bash |
| `ag check F-XXXX` | Validate all required artifacts exist | `doctor.sh` (partial) |
| `ag verify F-XXXX` | Run verification commands, record results | `ag auto verify` (partial) |
| `ag ship F-XXXX` | Check ready_to_ship, generate PR | `ag done` (shipping portion) |
| `ag status` | Show current work items and states | `ag status` (enhanced) |
| `ag next` | Show next item from backlog | `ag backlog` (partial) |

**Commands that stay in bash** (no state logic):
- `ag sync`, `ag help`, `ag tools`, `ag run`
- `ag backlog`, `ag todo`, `ag feedback`, `ag docs`, `ag flush`
- Token-efficient scripts: `journal.sh`, `status.sh`, `feature.sh`, `blocker.sh`, `todo.sh`

### 1.5 Existing Infrastructure to Preserve

| Keep | Why | Adaptation |
|------|-----|-----------|
| Token-efficient scripts | 40-line surgical edits, proven | Point to new paths |
| Pre-commit hooks | 21 structural gates, backstop | Simplify — many checks move to transitions |
| Feature IDs (F-XXXX) | Established convention | No change |
| Claude Code hooks | Tool-native enforcement | Wire to `ag check` |
| LLM test suite | Behavioral validation | Update for new commands |

### 1.6 State Model Mapping (current → new)

| Current State | New State | Notes |
|--------------|-----------|-------|
| (not tracked) | `idea` | NEW — inbox/capture |
| (not tracked) | `queued` | NEW — prioritized in backlog |
| `planned` | `planning` | Renamed for clarity |
| (embedded in plan review) | `plan_review` | NEW — explicit review gate |
| `specced` + `criteria_set` | `spec` | Merged — ACs are part of spec |
| `implementing` + `tests_written` | `implementation` | Merged — tests are part of implementation |
| `verified` | `verification` | Same concept |
| `documented` | `docs` | Same concept |
| `committed` | `ready_to_ship` | Renamed — commit != shipped |
| `shipped` | `shipped` | Same |
| `deprecated` | `deprecated` | Preserved as terminal state from any |

### 1.7 STACK.md Fate

`state_machine_af.yaml` replaces ONLY workflow/state/mode/profile settings from STACK.md. Everything else stays in STACK.md:
- Tech stack info (language, framework, package manager)
- Testing config (test commands, coverage)
- Deployment info
- Component registry
- Quality thresholds
- Docs registry

### 1.8 Escape Hatch Policy

- **Formal mode**: No escape hatches. CLI hard-fails if preconditions aren't met.
- **Lean mode**: Escape hatches available but **audit-logged** — every skip is recorded in `item.yaml` transition log with reason.
- Current escape hatches (`SKIP_SPEC_CHECK`, `SKIP_BACKLOG`, `SKIP_CLARITY`, etc.) are removed from bash. Lean mode's `skip_transitions` in config replaces them.

### 1.9 WIP Commits

In-progress work can be committed without completing the full pipeline:
- `ag commit` works at any state — it's a git operation, not a state transition
- State transitions are separate from git commits
- `ag ship` is the only command that requires `ready_to_ship` state

### 1.10 Early LLM Proof-of-Concept

At the end of Phase 1, test the minimal ~30-line CLAUDE.md with a real agent session:
- Give agent a feature task with the new system active
- Verify it uses `ag` commands without being told the full workflow
- This validates the core thesis before removing old files in Phase 3

### 1.11 Phase 1 Does NOT Remove Anything

Old `ag` commands and all 554 files remain. New engine is opt-in via `engine: v2` in state_machine_af.yaml. This allows testing the new system while the old one still works.

---

## Phase 2: Auto System Rearchitecture (~2-3 weeks)

The autonomous execution system (250KB+ Python) is rearchitected to use the new state machine CLI as its backbone.

### 2.1 What Changes in the Auto System

| Component | Current | New |
|-----------|---------|-----|
| `engine.py` (24KB) | Orchestrates agents, manages its own state | Delegates state transitions to `TransitionOrchestrator` |
| `epic.py` (24KB) | Epic decomposition + execution | Creates work items in `.agentic/work/`, uses transitions |
| `critical_agent.py` (24KB) | Adversarial review as separate system | Becomes a `gate: ai` implementation in transition gates |
| `kickoff.py` (45KB) | Vision-to-backlog pipeline | Creates work items in new format directly |
| `plan_convergence.py` (18KB) | Dialectical review system | Becomes the `plan_review` gate (invoked by transition) |
| `review.py` (27KB) | Review decision routing | Becomes gate dispatch (human/ai/skip per profile) |
| `scheduler.py` (27KB) | Task scheduling | Uses backlog from state_machine_af.yaml + work item priorities |

### 2.2 Key Architectural Changes

**Before**: Auto system had its own state tracking (`auto-state.json`, `crunch-state.json`) separate from feature states in FEATURES.md.

**After**: Auto system reads/writes feature state exclusively through `TransitionOrchestrator`. No separate state files. The work item's `item.yaml` IS the single source of truth.

**Before**: `engine.py` spawned Claude instances with custom prompts assembled from 24 context manifests.

**After**: `engine.py` spawns Claude instances with role prompts from `.agentic/prompts/`. Context is the work item directory contents + project context.

### 2.3 Files to Refactor

- `engine.py` → Use `TransitionOrchestrator` for state changes
- `epic.py` → Create `item.yaml` per child feature in `.agentic/work/`
- `critical_agent.py` → Extract core review logic; wire as `ai` gate implementation
- `kickoff.py` → Create work items in new format
- `plan_convergence.py` → Wire as `plan_review` gate
- `review.py` → Simplify to gate dispatch
- `scheduler.py` → Read work item priorities from `item.yaml` files

### 2.4 Auto Commands Preserved

All `ag auto` commands keep working:
- `ag auto verify F-XXXX`
- `ag auto task F-XXXX`
- `ag auto epic F-XXXX`
- `ag auto pipeline`
- `ag auto crunch`

The difference is internal: they use `TransitionOrchestrator` instead of ad-hoc state management.

---

## Phase 3: Instruction Consolidation & File Reduction (~1 week)

This is the simplification payoff. With the CLI enforcing workflows, most instruction files become unnecessary.

### 3.1 Eliminate Redundant Instruction Layers

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

**Why this works**: The CLI enforces the workflow. Instructions don't need to describe the workflow — they just need to say "use `ag` commands" and teach HOW to produce good artifacts.

### 3.2 New CLAUDE.md (Template)

```markdown
# Project Instructions

## Workflow
All work is managed by `ag` commands. The CLI enforces the workflow — never skip steps.

- `ag status` — see current work
- `ag start F-XXXX` — begin working on a feature
- `ag transition F-XXXX <state>` — advance the workflow
- `ag check F-XXXX` — validate artifacts before proceeding
- `ag verify F-XXXX` — run tests and record results
- `ag ship F-XXXX` — prepare for shipping

## Artifacts
Write artifacts to `.agentic/work/F-XXXX/`:
- `plan.md` — before coding
- `spec.md` — acceptance criteria
- `review.md` — adversarial review
- `journal.md` — decisions and changes

## Rules
- Never auto-commit in interactive sessions
- Never fabricate APIs or behavior
- Use token-efficient scripts for state files (journal.sh, status.sh)
- Ask when uncertain
```

### 3.3 Role Prompts Replace Skills + Checklists + Workflows

7 role prompts loaded by the CLI at the right moment:

**Phase-based (loaded on state transitions):**
- `.agentic/prompts/planner.md` — How to write plan.md (replaces planning-features skill)
- `.agentic/prompts/reviewer.md` — How to review adversarially (replaces reviewing-code skill)
- `.agentic/prompts/implementer.md` — How to implement with tests + docs (replaces implementing-features + writing-tests + updating-documentation skills)
- `.agentic/prompts/verifier.md` — How to verify and prepare PR (replaces committing-changes + completing-work skills)

**Activity-based (loaded on demand):**
- `.agentic/prompts/debugger.md` — Bug fixing: failing-test-first, bisect, root cause (replaces fixing-bugs skill)
- `.agentic/prompts/session.md` — Session start: dashboard, orphan detection, context recovery (replaces session-start skill)
- `.agentic/prompts/explorer.md` — Codebase navigation, research, exploration (replaces exploring-codebase + researching-topics skills)

When the agent calls `ag transition F-XXXX implementation`, the CLI prints the implementer prompt. When the agent encounters a bug, it loads the debugger prompt. The agent doesn't need to remember which role to adopt — the CLI tells them.

### 3.4 Files to Remove/Archive

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

### 4.1 Generated Tool-Specific Files

Instead of maintaining 4+ instruction files manually, generate them from `state_machine_af.yaml`:

```bash
ag export claude    → generates .claude/CLAUDE.md
ag export cursor    → generates .cursor/rules/ag.mdc
ag export copilot   → generates .github/copilot-instructions.md
ag export codex     → generates AGENTS.md
```

All exports contain the same core content (use `ag` commands, produce artifacts) with tool-specific formatting.

### 4.2 Optional MCP Server

MCP tools (minimal surface):
- `ag.status()` — current work items
- `ag.transition(id, state)` — enforce transition
- `ag.check(id)` — validate artifacts
- `ag.verify(id)` — run verification
- `ag.read_artifact(id, name)` — read work item artifact

**Strongest enforcement**: if the agent can ONLY interact through MCP tools (no direct state file editing), skipping becomes truly impossible.

### 4.3 Claude Code Hooks → `ag check`

```json
{
  "hooks": [
    {
      "event": "PostToolUse",
      "matcher": { "tool_name": "ExitPlanMode" },
      "command": "ag check $FEATURE_ID --phase plan_review"
    },
    {
      "event": "PreToolUse",
      "matcher": { "tool_name": "Write|Edit" },
      "command": "ag check --active-work-required"
    }
  ]
}
```

---

## Backlog Impact Assessment

### Features ABSORBED by this refactor (no longer separate items)

| Feature | Title | Why Absorbed |
|---------|-------|-------------|
| F-0223 | State Machine Gates Strengthening | Core of Phase 1 — the new CLI IS the strengthened state machine |
| F-0228 | Workflow Definition File | `state_machine_af.yaml` IS this feature |
| F-0233 | Design Phase Formalization | Part of state machine transitions |
| F-0213 | Unified Work Queue & Feature Registry Redesign | New `work/` directory layout IS this |
| F-0210 | Configurable Definition of Done per Task Type | Mode/profile config in state_machine_af.yaml |
| F-0211 | Project-Specific Customization Layer | state_machine_af.yaml customization replaces this |
| F-0212 | Project Customization Auto-Sync | Export generation replaces this |

### Features that REMAIN (orthogonal to refactor)

| Feature | Title | Why It Stays |
|---------|-------|-------------|
| F-0220 | Protected Main Branch Support | Git workflow, not architecture |
| F-0193 | Collision-Proof Feature IDs | Still needed for ID generation |
| F-0242 | Simulation Testing | Testing approach, still relevant |
| F-0243 | Complexity Tier Experiments | Research, still relevant |
| F-0227 | E2E Workflow Integration Test | Scope changes to test new CLI |

### Features that become LATER PHASES

| Feature | Title | Phase |
|---------|-------|-------|
| F-0230 | MCP Coordination Server | Phase 4 |
| F-0231 | Multi-Repo Umbrella | Phase 4+ |
| F-0232 | Full Autonomous Scheduling | Phase 4+ |

### TODOs that become MOOT

| TODO | Title | Why Moot |
|------|-------|----------|
| T-0083-T-0085 | LLM tests for workflow compliance | State machine enforces structurally |
| T-0052 | LLM-optimized format pass | YAML-first design addresses this |
| T-0053 | STACK.md to structured config | Replaced by state_machine_af.yaml |
| T-0021 | Clarify subagents vs skills | Both replaced by role prompts |
| T-0023 | Smarter memory-seed sync | Minimal memory with structural enforcement |
| T-0022 | Review specialization .conf | Simplified architecture |

### TODOs that REMAIN relevant

| TODO | Title | Notes |
|------|-------|-------|
| T-0003 | CI for LLM tests | Still useful for testing role prompts |
| T-0025 | NFRs as live invariants | Can be built on new architecture |
| T-0043 | AC scheduling phase | Phase 4 autonomous work |
| T-0001 | Progressive disclosure | Achieved by role prompts loaded JIT |

---

## Verification Plan

### Phase 1 Tests
1. **State machine enforcement**: Formal-mode feature, try `ag transition` to `implementation` without `plan.md` → must fail with clear error
2. **Artifact contracts**: Lean-mode feature, try to ship without tests → must fail
3. **Happy path**: Walk a feature through all states with all artifacts → must succeed
4. **Backward compat**: Old `ag` commands still work alongside new engine

### Phase 2 Tests
1. **Auto engine**: `ag auto task F-XXXX` uses `TransitionOrchestrator` internally
2. **Epic execution**: `ag auto epic` creates work items in `.agentic/work/`
3. **Review gates**: `critical_agent` review fires as part of transition, not separate system

### Phase 3 Tests
1. **Agent compliance**: New 30-line CLAUDE.md session — agent uses `ag` commands without full workflow instructions
2. **Role prompt delivery**: `ag transition F-XXXX implementation` prints implementer prompt → agent follows
3. **File count**: Verify ~80 files remain (down from 554)

### Phase 4 Tests
1. **MCP tools**: Agent calls `ag.transition()` via MCP → preconditions enforced
2. **Cross-tool**: Same workflow from Claude Code AND Cursor
3. **Export sync**: `ag export claude` matches `.claude/CLAUDE.md`

---

## Risk Assessment

| Risk | Mitigation |
|------|-----------|
| Rewrite takes too long | Phased — each phase independently valuable |
| Lose battle-tested patterns | Preserve token-efficient scripts, pre-commit hooks, feature IDs |
| Agents bypass CLI (run bash) | Pre-commit hooks as backstop; MCP in Phase 4 for stronger enforcement |
| Auto system refactor breaks things | Phase 2 has test coverage from existing auto tests |
| Over-engineering state machine | Start with research's 10-state machine, resist adding states |

---

## Summary: What Changes, What Stays

### Changes (the big moves)
1. **`state_machine_af.yaml`** replaces scattered config (STACK.md settings, profiles.conf, hardcoded states)
2. **Python `TransitionOrchestrator`** replaces 37 bash command modules with unified state-machine-driven transitions
3. **Per-work-item dirs** (`.agentic/work/F-XXXX/`) replace scattered files across spec/, journal/, FEATURES.md
4. **7 role prompts** replace 12 skills + 9 checklists + 20 workflows + 36 subagents
5. **Auto system** rearchitected onto state machine (single source of truth for state)
6. **Generated tool adapters** replace manually-maintained instruction files
7. **~30-line CLAUDE.md** replaces 40-line constitution + 442-line playbook + 127-line guidelines

### Stays (proven patterns)
1. `ag` command name (muscle memory preserved)
2. Token-efficient scripts (journal.sh, status.sh, feature.sh, blocker.sh, todo.sh)
3. Pre-commit hooks (simplified to call `ag check`)
4. Feature IDs (F-XXXX)
5. Two modes: formal + lean
6. Three profiles: hands-on, guided, autonomous
7. Claude Code hooks (rewired to `ag check`)
8. Core Python modules (state_machine.py, gates.py, settings.py — enhanced)

### The fundamental bet
**From**: "554 files of instructions that agents must remember to follow"
**To**: "1 config file + 1 CLI that makes skipping impossible + 7 role prompts for how to do each step"
