# Epic Plan: Opportunity Map — Complete Framework Maturity

**Status**: APPROVED
**Epic ID**: E-0001 (Opportunity Map)
**Features**: 19 features across 6 waves (Wave 0 added per review)
**Last existing feature**: F-0219 → new IDs start at F-0220

## Context

The framework (v0.61.0, 157 shipped features) has a comprehensive opportunity map in `docs/FRAMEWORK_WORKFLOW.md` Section 18 identifying 18 gaps across quality gates, structural refactoring, customization, and visionary architecture. Three items are specifically highlighted:

1. **End-to-End Workflow Integration Test** — no single test exercises the full 9-phase lifecycle
2. **Workflow Definition File** — workflow spread across 60+ files, needs single declarative source of truth
3. **Code Annotation Enforcement** — `@feature`/`@acceptance` annotations defined but never enforced

### Revision Notes (Post-Dialectical Review)

- Added **Wave 0** to address 11 in-progress features before starting new work
- **Fixed false dependencies**: F-0193 moved to Wave 2 (independent of F-0213), F-0210 moved to Wave 2 (independent of F-0213), F-0228 dependency on F-0221 removed
- **Resized** F-0193 from L to XL (blast radius across all F-XXXX references), F-0222 from S to S-M
- **Decomposed** F-0213 into 3 child features (registry split, unified queue, dependency graph)
- Added **migration/upgrade path** requirements per feature
- Added **success metrics** per wave
- Added **test strategy** per feature (structural + LLM tests)
- Leverages **F-0215** (Autonomous Framework Verification) infrastructure for E2E tests

---

## Feature Inventory

| ID | Feature | Wave | Size | Depends On | Risk |
|----|---------|------|------|-----------|------|
| — | Close/park 11 in-progress features | 0 | M | — | Low |
| F-0222 | State Machine Enforcement = Blocking | 1 | S-M | — | Low |
| F-0224 | Smoke Test Evidence | 1 | S | — | Low |
| F-0225 | Spec Evolution Metrics | 1 | S | — | Low |
| F-0229 | Code Annotation Enforcement | 1 | S-M | — | Low |
| F-0226 | Post-Merge Dogfooding | 1 | S-M | — | Low |
| F-0221 | ag.sh Decomposition | 2 | XL | — | High |
| F-0223 | Later State Machine Gates Strengthening | 2 | M | F-0222 | Med |
| F-0220 | Protected Main Branch Support | 2 | L | — | Med-High |
| F-0193 | Collision-Proof Feature IDs | 2 | XL | — | High |
| F-0210 | Configurable DoD per Task Type | 2 | M | — | Med |
| F-0213a | Feature Registry Split (child of F-0213) | 3 | L | F-0221 | Med |
| F-0213b | Unified Work Queue (child of F-0213) | 3 | L | F-0213a | High |
| F-0213c | Dependency Graph (child of F-0213) | 3 | M | F-0213b | Med |
| F-0228 | Workflow Definition File | 3 | L | F-0222, F-0223 | Med |
| F-0211 | Customization Layer | 4 | L | F-0210 | Med |
| F-0212 | Customization Auto-Sync | 4 | M-L | F-0211 | Med |
| F-0227 | End-to-End Workflow Integration Test | 4 | M | F-0222, F-0223, F-0228 | Low |
| F-0233 | Design Phase Formalization | 4 | M | F-0228 | Med |
| F-0230 | MCP Coordination Server | 5 | XL | — | High |
| F-0231 | Multi-Repo Umbrella | 5 | XL | F-0230, F-0213b | Very High |
| F-0232 | Full Autonomous Scheduling | 5 | XL | F-0213c, F-0230 | High |

---

## Dependency Graph

```
Wave 0: Close/park 11 in-progress features

Wave 1 (all independent, parallelizable):
  F-0222 (blocking mode)    ──┐
  F-0224 (smoke evidence)    │
  F-0225 (spec metrics)      ├── No dependencies
  F-0229 (annotation enf.)   │
  F-0226 (post-merge)       ─┘

Wave 2 (mostly independent, large batch):
  F-0222 ──► F-0223 (later gates need blocking mode)
  F-0221 (ag.sh decomp) — independent
  F-0220 (protected main) — independent
  F-0193 (collision-proof IDs) — independent [CHANGED: was Wave 3]
  F-0210 (configurable DoD) — independent [CHANGED: was Wave 3]

Wave 3 (architecture):
  F-0221 ──► F-0213a (registry split needs modular ag.sh)
  F-0213a ──► F-0213b (unified queue after registry is split)
  F-0213b ──► F-0213c (dependency graph after queue exists)
  F-0222 + F-0223 ──► F-0228 (workflow def needs settled gates)
  [CHANGED: F-0228 no longer depends on F-0221]

Wave 4 (integration):
  F-0210 ──► F-0211 (customization layer hosts custom DoDs)
  F-0211 ──► F-0212 (auto-sync needs layer)
  F-0228 ──► F-0227 (E2E test driven by workflow YAML)
  F-0228 ──► F-0233 (workflow def codifies new phase)

Wave 5 (visionary, future):
  F-0230 (MCP) — can start after Wave 3
  F-0230 + F-0213b ──► F-0231 (multi-repo)
  F-0213c + F-0230 ──► F-0232 (autonomous scheduling)
```

---

## Wave 0: Close Open Work

**Goal**: Ship or park the 11 in-progress features before starting new work.

The current in-progress features (F-0121, F-0144, F-0148, F-0149, F-0150, F-0151, F-0152, F-0153, F-0191, F-0192, F-0196, F-0214) must be triaged:
- **Ship**: Features close to done → complete and merge
- **Park**: Features that are stalled → mark as `planned` with journal entry explaining why
- **Deprecate**: Features superseded by this epic → mark `deprecated`

**Action**: Run `ag backlog list` and triage each. Register all 19 new features in FEATURES.md with initial descriptions.

**Success metric**: Zero features in `implementing`/`in_progress` state (except actively worked items).

---

## Wave 1: Quick Wins (Independent, parallelizable)

**Success metrics**: validate_framework.sh check count increases by 10+, state machine transitions block on invalid Formal transitions (test evidence), annotation coverage reported on dashboard.

### F-0222: State Machine Enforcement = Blocking (S-M)
**Scope**: Add `state_enforcement: blocking` option to profiles. When enabled, `FeatureStateMachine` rejects transitions that fail gate checks instead of logging warnings.
**Key files**:
- `.agentic/lib/auto/state_machine.py` (line 124: `enforce: bool = False`) — resolve from setting
- `.agentic/lib/auto/gates.py` — no change, gates already return `allowed: bool`
- `.agentic/lib/presets/profiles.conf` — `state_enforcement=blocking` for formal + autonomous_formal
- `.agentic/lib/settings.sh` — expose new setting
**Acceptance criteria**:
- AC1: `state_enforcement: blocking` causes gate failures to block transitions (formal + autonomous_formal)
- AC2: Discovery profile remains advisory (warns but allows)
- AC3: SKIP_TRANSITIONS (e.g., planned→shipped for retroactive tracking) still work in blocking mode
- AC4: Error messages tell users what they need to satisfy the gate
- AC5: Existing features in inconsistent states are not broken (enforcement applies to new transitions only)
**Tests**: Structural test in validate_framework.sh + LLM behavioral test (agent respects blocking)
**Upgrade path**: Default remains `advisory` — users opt in by setting `state_enforcement: blocking`

### F-0224: Smoke Test Evidence (S)
**Scope**: Gate in `ag done` checking for smoke test artifact at `.agentic/journal/evidence/F-XXXX-smoke.*`. New setting `smoke_test_evidence: required|recommended|off`.
**Key files**:
- `.agentic/lib/tools/ag.sh` — `cmd_done` (~line 1564), add evidence check
- `.agentic/lib/checklists/feature_complete.md` — reference evidence requirement
- `.agentic/lib/checklists/smoke_testing.md` — add evidence creation guidance
- `.agentic/lib/presets/profiles.conf` — default `off` for discovery, `recommended` for formal
**Acceptance criteria**:
- AC1: `ag done` blocks when `smoke_test_evidence: required` and no artifact exists
- AC2: Accepts any file matching `evidence/F-XXXX-smoke.*` (log, png, txt)
- AC3: `ag auto verify --visual` output auto-saves as evidence artifact
- AC4: Discovery profile defaults to `off`
**Tests**: Structural test checking gate behavior
**Upgrade path**: Default `off`, no impact on existing projects

### F-0225: Spec Evolution Metrics (S)
**Scope**: New `spec-metrics.sh` scanning AC files for `[Discovered]` markers, counting spec churn via git log. Surface in `ag audit --metrics` and retrospective checklist.
**Key files**:
- New: `.agentic/lib/tools/spec-metrics.sh`
- `.agentic/lib/tools/ag.sh` — extend `cmd_audit` with `--metrics` flag
- `.agentic/lib/checklists/retrospective.md` — reference metrics
- `.agentic/lib/tools/dashboard.sh` — optional metrics line
**Acceptance criteria**:
- AC1: Counts `[Discovered]` markers per feature across AC files
- AC2: Reports spec churn (git log of AC file modifications, grouped by feature)
- AC3: `ag audit --metrics` outputs both counts in structured format
- AC4: Retrospective checklist references metrics for process learning
**Tests**: Structural test with sample AC files
**Synergy**: Data feeds F-0210's task-type heuristics (high discovery rate = complex feature)

### F-0229: Code Annotation Enforcement (S-M)
**Scope**: Wire existing `coverage.py` into pre-commit as Check 21. When a feature transitions to `shipped`, validate that at least one `@feature F-XXXX` annotation exists. Controlled by `annotation_enforcement: off|advisory|blocking`.
**Key files**:
- `.agentic/lib/hooks/pre-commit-check.sh` — add Check 21 calling `coverage.py --json`
- `.agentic/lib/tools/coverage.py` — add `--check` mode (exit code for enforcement)
- `.agentic/lib/presets/profiles.conf` — default `off` for discovery, `advisory` for formal
- `.agentic/lib/workflows/code_annotations.md` — update with enforcement details
**Acceptance criteria**:
- AC1: Pre-commit Check 21 runs `coverage.py --check` on staged files, warns/blocks per setting
- AC2: `ag done` gate checks annotation coverage for shipping feature
- AC3: Enforcement level configurable per profile (off/advisory/blocking)
- AC4: Existing projects without annotations not broken (default: off)
- AC5: Performance: only scans staged/changed files, not entire codebase
- AC6: Threshold: at least 1 `@feature` annotation per shipped feature (not 100% coverage)
**Tests**: Structural test + LLM test (agent adds `@feature` during implementation)
**Upgrade path**: Default `off`, 157 shipped features grandfathered

### F-0226: Post-Merge Dogfooding (S-M, from T-0044)
**Scope**: New `post-merge-verify.sh` running after framework PR merge. Leverages F-0215 infrastructure (`framework_verify.py`, scenario YAML files in `.agentic/lib/auto/scenarios/`).
**Key files**:
- New: `.agentic/lib/tools/post-merge-verify.sh`
- `.agentic/lib/auto/framework_verify.py` — extend with post-merge scenario
- `.agentic/lib/tools/ag.sh` — extend `cmd_auto` verify-framework with `--post-merge`
**Acceptance criteria**:
- AC1: Runs `ag start` in temp directory and verifies dashboard output
- AC2: Compares root instruction files against `.agentic/lib/agents/` templates
- AC3: Validates JSON files (BACKLOG.json, AGENTS.json) and MD files parse correctly
- AC4: Runs critical subset of validate_framework.sh (structural tests only)
- AC5: Exit code 0 = clean, non-zero = list of issues
**Tests**: Test the verify script itself against a known-good project

---

## Wave 2: Structural Refactoring + Independent Architecture

### F-0221: ag.sh Decomposition (XL)
**Scope**: Extract 36 `cmd_*` functions from the 4,008-line monolith into individual files under `.agentic/lib/commands/`. Keep `ag.sh` as ~200-line dispatcher.
**Key files**:
- `.agentic/lib/tools/ag.sh` — refactor to dispatcher
- New: `.agentic/lib/commands/` — one file per command
- Shared helpers stay in `settings.sh`, `paths.sh`, `intent-helpers.sh`, `ac-parse.sh`
**Acceptance criteria**:
- AC1: All 36 `ag` commands produce identical output before/after
- AC2: `ag.sh` dispatcher is <300 lines
- AC3: Each command file is self-contained (sources its own dependencies)
- AC4: `validate_framework.sh` passes with no regressions
- AC5: All LLM tests pass unchanged
- AC6: Tab completion still works
**Approach**:
1. First: extract shared infrastructure (color codes, helper functions, path resolution) into `.agentic/lib/commands/_shared.sh`
2. Then: extract 3-5 "leaf" commands (cmd_todo, cmd_version, cmd_feedback — small, few deps) to prove the pattern
3. Then: extract remaining commands in batches of 3-5, validate_framework.sh between each
4. Last: extract complex commands (cmd_implement, cmd_done, cmd_auto)
**Risk mitigation**: Each extraction is a separate commit. Revert single commit if tests fail.
**Test strategy**: LLM test plan required as prerequisite — verify agents still route to correct commands
**Upgrade path**: Transparent to users — `ag` commands work identically

### F-0223: Later State Machine Gates Strengthening (M)
**Scope**: Upgrade gates 6-8 in `gates.py` from advisory-only to conditionally blocking:
- Gate 6 (verified→documented): Journal freshness + status freshness
- Gate 7 (documented→committed): Pre-commit checks pass + tests pass
- Gate 8 (committed→shipped): PR exists and reviewed (if `git_workflow: pull_request`)
**Key files**:
- `.agentic/lib/auto/gates.py` — gates 6-8 (~lines 310-435)
- `.agentic/lib/auto/state_machine.py` — gate registration
- `.agentic/lib/presets/profiles.conf` — per-gate enforcement levels
**Acceptance criteria**:
- AC1: Gate 6 blocks when journal stale (>24h) in blocking mode
- AC2: Gate 7 blocks when uncommitted test failures in blocking mode
- AC3: Gate 8 blocks when no reviewed PR (if PR workflow) in blocking mode
- AC4: All three advisory in discovery profile
- AC5: Graceful degradation when `gh` CLI unavailable (gate 8 skips PR check)
**Depends on**: F-0222 (blocking mode infrastructure)
**Tests**: Structural tests per gate + LLM test for gate 8 (PR check)

### F-0220: Protected Main Branch Support (L, from T-0066)
**Scope**: `ag flush` and `ag done` assume direct-to-main push. Add `main_branch_mode: direct|protected|auto-detect`.
**Key files**:
- `.agentic/lib/tools/state-commit.sh` (313 lines, core of `ag flush`)
- `.agentic/lib/tools/ag.sh` — `cmd_done` VERSION bump routing
- `.agentic/lib/presets/profiles.conf` — new `main_branch_mode` setting
- `.agentic/lib/settings.sh` — auto-detect via `gh api`
**Acceptance criteria**:
- AC1: `ag flush` creates `state/flush-<timestamp>` branch when protected mode
- AC2: PR auto-created with "state-only" label
- AC3: `ag done` VERSION bump goes into feature PR when protected
- AC4: Auto-detect checks GitHub branch protection rules via `gh` API
- AC5: Fallback to `direct` when `gh` unavailable
- AC6: state-commit.sh allowlist still applies
**Upgrade path**: Default `direct`, no impact. Users with branch protection opt in.

### F-0193: Collision-Proof Feature IDs (XL) [MOVED from Wave 3]
**Scope**: Replace sequential F-XXXX with collision-proof scheme. Support both old (`F-\d{4}`) and new formats during transition.
**Key files**: Every file with `F-\d{4}` regex — feature.sh, ag.sh, gates.py, state_machine.py, coverage.py, all test files, acceptance file paths, plan file names
**Approach**:
1. Add `id_format: sequential|hash` setting (default: `sequential` for backward compat)
2. Update all regexes to accept both `F-\d{4}` and `F-[a-f0-9]{5,8}`
3. New features get hash IDs when `id_format: hash`
4. Existing features keep their IDs (never migrate old IDs)
5. Migration script updates regex patterns in user projects
**Acceptance criteria**:
- AC1: Both ID formats work in all tools simultaneously
- AC2: No existing user project breaks (existing F-XXXX IDs preserved)
- AC3: New hash IDs are deterministic (based on feature name + timestamp, not random)
- AC4: Acceptance file paths, plan names, journal refs all accept both formats
- AC5: `upgrade.sh` includes regex migration for user projects
**Risk**: Blast radius is enormous — 15+ files with hardcoded `F-\d{4}`. Must be extremely thorough.
**Tests**: Structural tests for both ID formats, regression tests for all existing tools

### F-0210: Configurable DoD per Task Type (M) [MOVED from Wave 3]
**Scope**: Define task types (implementation, spike, docs, bugfix, refactor) with per-type completion checklists. `ag done` reads task type and loads appropriate checklist.
**Key files**: `.agentic/lib/tools/ag.sh` (cmd_done), `.agentic/lib/checklists/feature_complete.md`, `.agentic/lib/presets/profiles.conf`
**Acceptance criteria**:
- AC1: Task types defined in STACK.md or per-feature metadata
- AC2: `ag done` selects checklist based on task type
- AC3: Default type = "implementation" preserves current behavior
- AC4: Spike type skips "tests passing" requirement
- AC5: Docs type skips "code quality check"
**Upgrade path**: Default type = implementation, no change for existing projects

---

## Wave 3: Architecture Features

**Success metrics**: FEATURES.md split into shipped registry + active queue, workflow YAML defines all 9 phases, `workflow-validate.sh` catches drift.

### F-0213a: Feature Registry Split (L, child of F-0213)
**Scope**: Split FEATURES.md into shipped registry (read-only contracts) + active work tracking. Shipped features (157) stay in `FEATURES_SHIPPED.md` (contract, never modified without migration). Active features move to `FEATURES_ACTIVE.md`.
**Key files**:
- `.agentic/spec/FEATURES.md` → split into `FEATURES_SHIPPED.md` + `FEATURES_ACTIVE.md`
- `.agentic/lib/tools/feature.sh` — read from both files
- `.agentic/lib/tools/query_features.py` — query both files
- All tools that read FEATURES.md — wrapper functions for backward compat
**Approach**: Overlay — wrapper functions read both files. Old `FEATURES.md` path still works via symlink or redirect during transition.
**Depends on**: F-0221 (modular ag.sh reduces merge conflict risk when touching feature commands)

### F-0213b: Unified Work Queue (L, child of F-0213)
**Scope**: Replace BACKLOG.json with unified queue supporting heterogeneous items (F-, T-, I-, E-). Items carry type metadata (implementation, spike, docs, etc.).
**Key files**:
- `.agentic/lib/tools/backlog.sh` — new queue format
- `.agentic/lib/tools/ag.sh` — cmd_backlog
- `.agentic/BACKLOG.json` → `WORK_QUEUE.json`
**Depends on**: F-0213a (registry split provides clean active-work tracking)

### F-0213c: Dependency Graph (M, child of F-0213)
**Scope**: Add dependency tracking to work queue items. `ag backlog` shows blocked/unblocked items. Scheduler uses deps for ordering.
**Key files**:
- `.agentic/lib/tools/backlog.sh` — dep field in queue items
- `.agentic/lib/auto/scheduler.py` — dependency-aware scheduling
**Depends on**: F-0213b (queue must exist to add deps to)

### F-0228: Workflow Definition File (L)
**Scope**: Single declarative YAML file (`.agentic/lib/workflow.yaml`) defining: 9 lifecycle phases, required artifacts per phase, gates per transition, profile variations. Validation script checks implementations against definition. **Design YAML schema for testability** — F-0227 will drive E2E tests directly from this YAML.
**Key files**:
- New: `.agentic/lib/workflow.yaml` — single source of truth
- New: `.agentic/lib/tools/workflow-validate.sh` — checks implementations vs YAML
- `.agentic/lib/auto/state_machine.py` — validate phase list against YAML
- `.agentic/lib/auto/gates.py` — validate gate functions match YAML declarations
**Acceptance criteria**:
- AC1: YAML defines all 9 phases with entry/exit gates, required artifacts, profile overrides
- AC2: Validation script detects discrepancies between YAML and actual implementations
- AC3: `validate_framework.sh` includes workflow definition consistency checks
- AC4: State machine validates phase list against YAML at startup
- AC5: Each checklist/skill cross-referenced in YAML with file path
- AC6: Schema designed for machine-readable test generation (F-0227 compatibility)
**Approach**: V1 scope = 9 state transitions + gate functions + profile overrides. V2 = checklists, skills, workflow docs.
**Depends on**: F-0222 + F-0223 (gate semantics must be settled first)
**[CHANGED]**: Removed dependency on F-0221 — YAML describes the workflow, not the code structure

---

## Wave 4: Integration & Customization

**Success metrics**: E2E test exercises full 9-phase lifecycle in <60s, customization layer allows project-specific DoD/conventions.

### F-0211: Project-Specific Customization Layer (L, existing planned)
**Scope**: `.agentic/project/` directory with `dod.md`, `conventions.md`, `workflow-overrides.md`, `settings.yaml`. Framework reads at well-defined points. Files survive `upgrade.sh`.
**Resolution order**: project override > STACK.md > profile preset > default
**Depends on**: F-0210 (DoD must be configurable for customization layer to host custom DoDs)

### F-0212: Project Customization Auto-Sync (M-L, existing planned)
**Scope**: When `.agentic/project/` files change, regenerate affected artifacts. Prefer live-reading over sync.
**Depends on**: F-0211

### F-0227: End-to-End Workflow Integration Test (M)
**Scope**: Single test exercising full 9-phase lifecycle in a temp project. **Driven by F-0228's workflow.yaml** — walks each phase, verifies gates fire, checks artifacts created. Leverages **F-0215 infrastructure** (scenario YAML, `framework_verify.py`).
**Key files**:
- New: `tests/test_e2e_lifecycle.sh` (or `.py`)
- Reads: `.agentic/lib/workflow.yaml` (from F-0228) for expected gates/artifacts
- Leverages: `.agentic/lib/auto/framework_verify.py` (F-0215 infrastructure)
**Acceptance criteria**:
- AC1: Test creates temp project with formal profile
- AC2: Exercises all 9 state transitions via `ag` commands or state_machine.py directly
- AC3: Validates each gate fires (checks gate log/output)
- AC4: Validates all required artifacts created per phase (read from workflow.yaml)
- AC5: Detects gate ordering bugs (wrong gate for wrong transition)
- AC6: Runs in <60 seconds
- AC7: Integrated into `validate_framework.sh`
**Depends on**: F-0222 + F-0223 (gates blocking), F-0228 (YAML defines expectations)

### F-0233: Design Phase Formalization (M)
**Scope**: Add explicit "design" phase between planning and specification (10 states total). Opt-in via `design_phase: required|optional|off`.
**Key files**:
- `.agentic/lib/auto/state_machine.py` — add DESIGNED state
- `.agentic/lib/auto/gates.py` — new gate_planned_to_designed + gate_designed_to_specced
- `.agentic/lib/workflow.yaml` (from F-0228) — add phase
- `.agentic/lib/presets/profiles.conf` — `design_phase: off` default
**Acceptance criteria**:
- AC1: New DESIGNED state between PLANNED and SPECCED
- AC2: Existing features in PLANNED not blocked (opt-in, default off)
- AC3: SKIP_TRANSITIONS updated for backward compatibility
- AC4: When enabled, gate checks for design artifacts (ADR or design doc)
**Depends on**: F-0228 (workflow definition codifies new phase)

---

## Wave 5: Visionary Architecture (Future)

### F-0230: MCP Coordination Server (XL)
**Scope**: Extend existing `coord_server.py` (F-0185, 397 lines, HTTP JSON-RPC, bearer auth) with MCP protocol support. NOT a rewrite — wrap existing RPC dispatch in MCP transport layer.
**Key files**: `.agentic/lib/auto/coord_server.py`, `.agentic/lib/auto/coord_tools.py`
**Note**: Sizing is L if wrapping existing server, XL if adding new coordination capabilities beyond current 8 tools.

### F-0231: Multi-Repo Umbrella (XL)
**Scope**: Cross-repo coordination with shared contracts, unified backlog.
**Key files**: `.agentic/lib/auto/umbrella.py`, `.agentic/lib/auto/components.py`
**Depends on**: F-0230, F-0213b

### F-0232: Full Autonomous Scheduling (XL)
**Scope**: Scheduler finds unblocked transitions, spawns workers, critical agents review.
**Key files**: `.agentic/lib/auto/scheduler.py`, `.agentic/lib/auto/engine.py`
**Depends on**: F-0213c, F-0230

---

## Critical Path

```
Shortest path to user value:
  Wave 0 (triage) → Wave 1 (quick wins ship immediately)

Longest chain:
  F-0221 → F-0213a → F-0213b → F-0213c → F-0232
  F-0222 → F-0223 → F-0228 → F-0227

Bottleneck: F-0221 (ag.sh decomposition) blocks Wave 3 registry work
Mitigated: F-0228, F-0193, F-0210 no longer blocked by F-0221

Parallelism in Wave 2:
  F-0221 ║ F-0220 ║ F-0193 ║ F-0210 ║ F-0223 (all can run concurrently)
```

---

## Verification

### Per-Feature
- Each feature: `bash tests/validate_framework.sh` must pass
- Each feature touching gates/state: LLM behavioral test required
- Each feature: instruction files updated (CLAUDE.md, skills, checklists, memory-seed, auto_orchestration)
- Each feature changing data formats: `upgrade.sh` entry required

### Epic-Level
- F-0227 (E2E test) is the epic's own integration verification
- After Wave 4: `ag auto verify-framework` exercises full lifecycle
- Regression: all 70+ existing LLM tests must pass

### Framework-Dev Specific
- F-0226 (post-merge dogfooding) runs after each merge
- `validate_framework.sh` expanded with new tests per feature
- Dogfooding: `.agentic/` templates updated alongside root files

---

## Implementation Order (Recommended)

1. **Wave 0**: Triage 11 in-progress features. Register all 19 new features in FEATURES.md.
2. **Wave 1**: Ship quick wins as individual PRs (F-0222, F-0224, F-0225, F-0229, F-0226) — all parallelizable
3. **Wave 2**: Start F-0221 (bottleneck) + F-0193, F-0210, F-0220, F-0223 in parallel
4. **Wave 3**: F-0213a/b/c (sequential) + F-0228 (parallel with F-0213 chain)
5. **Wave 4**: F-0211 → F-0212, F-0227, F-0233 flow from Wave 3
6. **Wave 5**: Future — plan but don't commit to timeline
