# Roadmap: ADR-001 Implementation — Multi-Component Architecture & Workflow Engine

## Context

ADR-001 (`.agentic/spec/adr/ADR-001-multi-component-architecture.md`) defines 6 interconnected capabilities: components, epics, MCP coordination, formal state machine, review checkpoints with critical agent, and full autonomous flow. This roadmap plans the implementation order across 7 phases (~15 features).

**Key strategic decision**: State machine first (not components). The user's insight — "do you already have such ability, or do we want to build that first?" — means the spine should exist before decoration.

**Reference**: Visual sketch at `.agentic/journal/plans/2026-03-07_agentic_flows_sketch.png`

### Design Decision: State Persistence (ADR Open Question 6)

**Decided**: State lives in FEATURES.md `status` field (the existing field, extended from 4 to 9 values). Rationale:
- Single source of truth (no sync between separate state file and FEATURES.md)
- Git-tracked history of state changes for free
- Backward compatible — existing tools already read/write this field
- MCP (Phase 6) caches state in memory but files remain authoritative

The state machine reads from and writes to FEATURES.md via `feature.sh` / `query_features.py`. No separate state file.

---

## Phase 1: Formal State Machine (Core)

**ADR Section**: 5 (forward transitions + regressions)
**Delivers**: The 9-state feature lifecycle as testable Python code, fully integrated with existing tooling

### What Gets Built

- `FeatureStateMachine` class with 9 states: `planned → specced → criteria_set → tests_written → implementing → verified → documented → committed → shipped`
- Gate functions per transition (e.g., `planned → specced` requires FEATURES.md entry + description)
- Regression transitions + cascade rules (backward transitions from ADR Section 5)
- `ag transition F-XXXX <target>` command
- Starts in **advisory mode** — warns on invalid transitions, doesn't block (build confidence first)
- **Full blast radius update**: all files that hard-code the 4-status set get updated to support 9 states

### Blast Radius — Status Value Migration

The 4→9 status change touches far more than the state machine itself:

| Category | Files | What Changes |
|----------|-------|-------------|
| Core state machine | `state_machine.py`, `gates.py` (NEW) | New code |
| Status validation | `validate_formats.py` (hard-codes `valid_statuses`) | Extend set to 9 values |
| Feature updates | `feature.sh` | Accept 9 values, backward-compat aliases |
| Feature queries | `query_features.py` | Sort order, filter support for 9 values |
| Pre-commit hooks | `pre-commit-check.sh` (checks 2, 14, 15, 16) | Understand new state space |
| Format validation | `validate_specs.py` | If it validates status values |
| Checklists (~10) | `before_commit.md`, `feature_implementation.md`, `feature_start.md`, `feature_complete.md`, etc. | Update status references from `planned/in_progress/shipped` to 9-state model |
| Skills (~12) | `.claude/skills/*/SKILL.md` | Regenerate via `generate-skills.sh` after checklist updates |
| Instruction files | `CLAUDE.md` template, `.cursorrules` template | Update if they reference status values |
| Autonomous mode | `crunch.py` (`_read_planned_features()`) | Fix regex bug (doesn't match current FEATURES.md format), understand all pre-implementing states as "needs work" |
| Dispatcher | `ag.sh` | Add `ag transition`, update status references in help text |

### Status Alias Strategy

**Reading** (backward compat): When reading FEATURES.md, `in_progress` is treated as `implementing`, `planned` stays `planned`, `shipped` stays `shipped`, `deprecated` stays `deprecated`. Old values are always accepted.

**Writing** (forward): New transitions write the 9-state values. `upgrade.sh` migrates `in_progress` → `implementing`. The 5 new intermediate states (`specced`, `criteria_set`, `tests_written`, `verified`, `documented`, `committed`) only appear for features that actively use the state machine.

**Coexistence**: Existing shipped/planned features don't need migration — their status values are valid in both models. Only `in_progress` features need manual audit to assign the correct 9-state position.

### Key Files

| Action | File | Change |
|--------|------|--------|
| NEW | `.agentic/lib/auto/state_machine.py` | FeatureState enum, Transition class, FeatureStateMachine |
| NEW | `.agentic/lib/auto/gates.py` | Gate functions per transition, returns `(bool, list[str])`. Note: `implementing → verified` gate delegates to `verify.py` for test execution |
| MODIFY | `.agentic/lib/tools/feature.sh` | Extend status values from 4→9, backward compat aliases |
| MODIFY | `.agentic/lib/tools/validate_formats.py` | Extend `valid_statuses` set to include 9 values |
| MODIFY | `.agentic/lib/tools/query_features.py` | Validate new status values, update sort order |
| MODIFY | `.agentic/lib/hooks/pre-commit-check.sh` | Update checks 2, 14, 15, 16 for 9-state model |
| MODIFY | `.agentic/lib/tools/ag.sh` | Add `ag transition` subcommand, update help text |
| MODIFY | `.agentic/lib/auto/crunch.py` | Fix `_read_planned_features()` regex to match actual FEATURES.md format; treat all pre-implementing states as "needs work" |
| MODIFY | `.agentic/lib/checklists/*.md` (~10 files) | Update status references |
| REGEN | `.claude/skills/*/SKILL.md` (~12 files) | Regenerate via `generate-skills.sh` |
| MODIFY | `.agentic/lib/presets/profiles.conf` | Add review checkpoint placeholder defaults |
| MODIFY | `upgrade.sh` | Map `in_progress` → `implementing`, add manual audit prompt for in-progress features |
| NEW | `tests/test_state_machine.py` | Every transition, gate, regression, cascade |
| NEW | `tests/test_status_migration.py` | Take old FEATURES.md, run upgrade, verify migration (integration test) |

### How Existing Autonomous Code Integrates

- **`engine.py`**: After each AC passes, `engine.py` calls `state_machine.transition(feature_id, VERIFIED)` (or the appropriate next state). The state machine validates the gate and updates FEATURES.md.
- **`task.py`**: TaskRunner wraps its branch→implement→commit→PR flow with state machine calls: `transition(IMPLEMENTING)` at start, `transition(COMMITTED)` after PR creation.
- **`verify.py`**: The `implementing → verified` gate delegates to verify.py's `VerifyLoop`. The gate function calls verify.py and checks its return value.
- **`crunch.py`**: Instead of regex-matching `planned|in-progress`, calls `state_machine.get_unblocked()` to find features with available transitions.

### Scope & Risk

~2 features + the blast radius sweep. This is the largest single phase. Risk: gate preconditions too strict → advisory mode mitigates. Risk: blast radius underestimated → the table above is comprehensive but integration tests catch remaining gaps.

---

## Phase 2: Components as Metadata

**ADR Section**: 1
**Delivers**: Component-scoped features with filtered context

### What Gets Built

- Optional `## Components` table in STACK.md (name | path | type | test_command)
- Optional `Component` field on features in FEATURES.md
- `context-for-role.sh` gains component-aware filtering (only load component's files/specs/tests)
- `discover.py` gains component auto-detection (monorepo directories with their own package.json/pyproject.toml)
- State machine gates become component-aware (use component-specific test commands)

### Key Files

| Action | File | Change |
|--------|------|--------|
| NEW | `.agentic/lib/auto/components.py` | Parse `## Components`, validate refs, path filtering |
| MODIFY | `.agentic/lib/tools/context-for-role.sh` | Component-scoped context assembly |
| MODIFY | `.agentic/lib/tools/discover.py` | Component detection for monorepos |
| MODIFY | `.agentic/lib/tools/query_features.py` | `--component` filter |
| MODIFY | `.agentic/lib/auto/gates.py` | Component-specific test commands in verify gates |
| MODIFY | `.agentic/lib/init/STACK.template.md` | Commented-out `## Components` section |
| NEW | `tests/test_components.py` | Registry parsing, validation, path resolution |

### Why Second

Purely additive, no breaking changes. With the state machine (Phase 1), component-scoped gates become possible. Component registry parsing is independent of the state machine — could theoretically start in parallel with Phase 1.

### Scope & Risk

~1 feature. Risk: path resolution across directory structures → optional section mitigates.

---

## Phase 3: Review Checkpoint Framework

**ADR Section**: 5.1 (review routing only, NOT the critical agent)
**Delivers**: Configurable review gates on state machine transitions, `autonomous_formal` profile definition

### What Gets Built

- Three review modes: `human | critical_agent | auto` — per transition, per profile
- Review checkpoint settings in STACK.md (`review_spec`, `review_criteria`, `review_plan`, `review_code`, `review_merge`, `review_decomposition`, `review_regression`, `review_taste`)
- `state_machine.transition()` checks review settings; if `human`, blocks and creates HUMAN_NEEDED entry; if `auto`, proceeds; if `critical_agent`, defers to Phase 4
- **New profile**: `autonomous_formal` defined in `profiles.conf` (Formal gates + agent reviews + auto-merge except final merge)
- `ag review F-XXXX <transition>` for human review flow
- Review artifact format (structured verdict stored alongside feature)

**Note**: `critical_agent` mode is defined but not yet implemented — it falls back to `human` until Phase 4 ships. This lets us define the settings and profile without building the hardest piece yet.

### Profile Review Defaults

| Checkpoint | Discovery | Formal | Autonomous Formal |
|-----------|-----------|--------|-------------------|
| review_spec | auto | critical_agent | critical_agent |
| review_criteria | auto | critical_agent | critical_agent |
| review_plan | auto | critical_agent | critical_agent |
| review_code | critical_agent | human | critical_agent |
| review_merge | human | human | human |
| review_decomposition | auto | critical_agent | critical_agent |
| review_regression | critical_agent | human | critical_agent |
| review_taste | auto | critical_agent | critical_agent |

### Key Files

| Action | File | Change |
|--------|------|--------|
| NEW | `.agentic/lib/auto/review.py` | ReviewCheckpoint, ReviewResult, review routing logic |
| MODIFY | `.agentic/lib/auto/state_machine.py` | `transition()` checks review settings before completing |
| MODIFY | `.agentic/lib/presets/profiles.conf` | Review defaults + `autonomous_formal` profile |
| MODIFY | `.agentic/lib/init/STACK.template.md` | `## Review checkpoints` and `## Style & taste` sections |
| MODIFY | `.agentic/lib/tools/ag.sh` | `ag review` subcommand |
| MODIFY | `upgrade.sh` | Add review settings to existing STACK.md |
| NEW | `tests/test_review.py` | Review routing, mode resolution, fallback behavior |
| NEW | `tests/test_state_machine_with_reviews.py` | Integration: state machine + review checkpoints together |

### Edge Cases

- **Profile switching mid-feature**: Pending reviews stay at their original mode. New transitions use the new profile.
- **`critical_agent` before Phase 4**: Falls back to `human` with a log message ("critical agent not yet available, routing to human").
- **`review_merge: human` in autonomous_formal**: Yes, this means human touchpoints. The profile name is accurate — "autonomous" refers to the work, not the merge. For fully autonomous merge, user sets `review_merge: critical_agent` explicitly (opt-in, not default).

### Scope & Risk

~2 features (review framework + profile). Risk: settings proliferation → sensible defaults per profile minimize configuration burden.

---

## Phase 4: Critical Agent

**ADR Section**: 5.1 (critical agent implementation), 5.2 (taste/style)
**Delivers**: Adversarial review agent, taste/style settings, functional `autonomous_formal` profile

### What Gets Built

- `CriticalAgent` class: spawns a separate Claude instance with adversarial prompt
- Read-only: can approve, request-changes, or escalate — cannot modify code/specs
- Structured review verdict stored as artifact alongside feature
- Style/taste settings: `style_guide`, `design_system`, `api_style` in STACK.md — loaded into critical agent context for taste-sensitive reviews
- Escalation handling: critical agent can escalate to human; scheduler (Phase 7) respects this
- Model selection: critical agent uses the `review` model from STACK.md `## Model customization` (defaults to best available)

### Key Files

| Action | File | Change |
|--------|------|--------|
| NEW | `.agentic/lib/auto/critical_agent.py` | CriticalAgent class, spawn logic, verdict parsing |
| NEW | `.agentic/lib/auto/prompts/critical_review.md` | Adversarial review prompt template (per transition type) |
| NEW | `.agentic/lib/auto/prompts/taste_review.md` | Style/taste review prompt |
| MODIFY | `.agentic/lib/auto/review.py` | `critical_agent` mode now delegates to CriticalAgent instead of falling back to human |
| MODIFY | `.agentic/lib/init/STACK.template.md` | `## Style & taste` section with `style_guide`, `design_system`, `api_style` |
| NEW | `tests/test_critical_agent.py` | Spawn, verdict parsing, escalation, model selection |

### Escalation → Scheduler Interaction

When the critical agent escalates:
1. Review result is stored with `status: escalated` and reasoning
2. Feature transition blocks (same as `human` mode)
3. HUMAN_NEEDED entry created with the critical agent's concerns
4. In Phase 7 (scheduler), the scheduler treats escalation like `human` — moves to next unblocked feature while waiting

### Error Handling

- **API unavailable**: Retry once, then fall back to `human` mode with log warning
- **Rate limited**: Queue and retry with backoff
- **Timeout**: Fall back to `human` mode

### Scope & Risk

~2 features (critical agent + taste). Risk: rubber-stamping → start with strict adversarial prompt, include "if in doubt, escalate" instruction. Risk: model quality → use best available model for review.

---

## Phase 5: Epics as Parent Features

**ADR Section**: 2
**Delivers**: Epic decomposition, parent-child cascade, `ag decompose`

### What Gets Built

- `Parent` field enforcement with cascade behavior
- `ag decompose F-XXXX`: analyze epic AC → identify components (using `components.py` from Phase 2) → propose child features → review checkpoint (`review_decomposition`)
- Epic status derived from children: epic ships when all children ship + integration verification passes
- Regression cascade: if a child regresses, epic status recomputes

### Key Files

| Action | File | Change |
|--------|------|--------|
| NEW | `.agentic/lib/auto/epic.py` | EpicDecomposer, EpicCascade |
| MODIFY | `.agentic/lib/auto/state_machine.py` | Parent-child cascade rules |
| MODIFY | `.agentic/lib/auto/components.py` | Decomposer uses component registry |
| MODIFY | `.agentic/lib/tools/ag.sh` | `ag decompose` subcommand |
| MODIFY | `.agentic/lib/tools/query_features.py` | Epic progress tracking, `--children` strengthened |
| MODIFY | `.agentic/lib/tools/feature.sh` | When updating child status, trigger parent recompute |
| NEW | `tests/test_epic.py` | Decomposition, cascade, integration verification |

### Why After Critical Agent

Decomposition goes through review checkpoint (`review_decomposition`). With the critical agent (Phase 4), this review is actually functional — the agent can challenge bad decompositions. Without it, the review falls back to human (acceptable but less autonomous).

### Scope & Risk

~2 features. Risk: decomposition quality depends on epic AC quality → review checkpoint mitigates.

---

## Phase 6: MCP Server for Agent Coordination

**ADR Section**: 4
**Delivers**: Real-time multi-agent coordination, 8 MCP tools, graceful file-based fallback

### What Gets Built

- Python MCP server with tools: `claim_feature`, `release_feature`, `transition_state`, `get_unblocked`, `subscribe_state`, `report_status`, `request_review`, `submit_review`
- Thin wrapper: each MCP tool delegates to existing Python classes (state_machine.py, review.py, components.py)
- `ag mcp start | stop | status` commands
- Graceful degradation: if MCP not running, framework uses file-based coordination
- Coexistence with existing `control.py` Unix domain socket (MCP server is a separate process, control.py manages AutoEngine within a process)

### Key Files

| Action | File | Change |
|--------|------|--------|
| NEW | `.agentic/lib/auto/mcp_server.py` | MCP server, tool registration |
| NEW | `.agentic/lib/auto/mcp_tools.py` | Tool implementations delegating to existing code |
| MODIFY | `.agentic/lib/tools/ag.sh` | `ag mcp` subcommands |
| MODIFY | `.agentic/lib/auto/engine.py` | Optional MCP integration (if available, use it) |
| NEW | `tests/test_mcp_server.py` | Tool invocation, fallback behavior |

### Why After Epics

MCP wraps already-proven primitives. The server is thin because all complexity lives in Phases 1-5.

### Scope & Risk

~2 features. Risk: MCP SDK maturity → thin wrapper + graceful degradation mitigate. Note: user has no MCP experience, so this phase includes learning time.

---

## Phase 7: Full Autonomous Flow + Multi-Repo

**ADR Section**: 3, 6
**Delivers**: Autonomous scheduler, multi-repo umbrella, `ag auto epic F-XXXX`

### What Gets Built

- `AutonomousScheduler`: `get_unblocked() → spawn worker → review gate → repeat` loop
- Non-blocking reviews: while one feature awaits human/escalated review, scheduler advances others
- Worker agents scoped to components, critical agents for review gates
- Evolve `crunch.py` into scheduler-backed execution (single rewrite, not two)
- Multi-repo umbrella: `Repo` column in component registry, cross-repo contract checking
- `ag auto epic F-XXXX` for autonomous epic execution
- User input collection: structured prompts for vision, style refs, research before decomposition begins (from visual sketch's top-level flow)

### Scheduler → Escalation Interaction

When the critical agent escalates during autonomous execution:
1. Feature blocks at the review checkpoint
2. Scheduler logs escalation and creates HUMAN_NEEDED entry
3. Scheduler continues with other unblocked features
4. When human resolves the review (approve/reject), scheduler picks up the feature again
5. If all remaining features are blocked on human review, scheduler reports status and waits

### Key Files

| Action | File | Change |
|--------|------|--------|
| NEW | `.agentic/lib/auto/scheduler.py` | AutonomousScheduler with non-blocking review loop |
| NEW | `.agentic/lib/auto/umbrella.py` | Multi-repo component resolution, contract checking |
| MODIFY | `.agentic/lib/auto/crunch.py` | Evolve into scheduler-backed execution (ONE rewrite) |
| MODIFY | `.agentic/lib/auto/components.py` | Support `Repo` column for multi-repo |
| MODIFY | `.agentic/lib/tools/ag.sh` | `ag auto epic` subcommand |
| MODIFY | `.agentic/lib/presets/profiles.conf` | Finalize `autonomous_formal` defaults |
| NEW | `tests/test_scheduler.py` | Scheduling loop, non-blocking reviews, escalation handling |
| NEW | `tests/test_umbrella.py` | Multi-repo resolution, contract validation |
| NEW | `tests/test_e2e_autonomous.py` | End-to-end: epic → decompose → schedule → implement → ship |

### Scope & Risk

~3 features. Risk: autonomous quality → `review_merge: human` by default. Risk: multi-repo atomicity → contract-first workflow.

---

## Cross-Phase Concerns

### Testing Strategy

| Type | What | When |
|------|------|------|
| **Unit tests** | State machine transitions, gates, components, review routing, critical agent, epic cascade, MCP tools, scheduler | Each phase |
| **Integration tests** | State machine + reviews, component-aware gates, epic + state machine cascade | After Phases 3, 5 |
| **Migration tests** | Old FEATURES.md → upgrade.sh → verify migration | Phase 1 |
| **Backward compat tests** | Old 4-status values accepted, old projects work | Phase 1 |
| **E2E test** | `ag auto epic` full flow | Phase 7 |
| **LLM behavioral tests** | Critical agent actually finds problems, doesn't rubber-stamp | Phase 4 |
| **`validate_framework.sh`** | Updated to understand 9-state model | Phase 1 |

### Documentation Updates (Per Phase)

Each phase updates:
- FEATURES.md (new feature entries with acceptance criteria — budgeted as part of each phase)
- CHANGELOG.md entry
- ADR-001 status (from "Proposed" to "Accepted" once Phase 1 ships, then updated as phases complete)
- Relevant checklists/skills (regenerated via `generate-skills.sh`)

### Upgrade Path

Each phase maintains backward compatibility:
- Phase 1: Old status values accepted as aliases; upgrade.sh migrates `in_progress` + manual audit for in-progress features
- Phase 2: Components section optional; omitting it preserves all current behavior
- Phase 3-4: Review settings default to current behavior per profile
- Phase 5: MCP optional; fallback to file-based
- Phase 6: Multi-repo optional; single-repo unchanged
- Phase 7: Autonomous optional; manual workflow preserved

---

## Summary

| Phase | ADR | Features | Delivers |
|-------|-----|----------|----------|
| 1 | §5 | ~2 | State machine (9 states, gates, regressions, full blast radius update) |
| 2 | §1 | ~1 | Component registry, scoped context, component-aware gates |
| 3 | §5.1 | ~2 | Review checkpoint framework, `autonomous_formal` profile |
| 4 | §5.1/5.2 | ~2 | Critical agent, taste/style settings |
| 5 | §2 | ~2 | Epic decomposition, parent-child cascade |
| 6 | §4 | ~2 | MCP server (8 tools), graceful degradation |
| 7 | §3/6 | ~3 | Autonomous scheduler, multi-repo umbrella, `ag auto epic` |

**Total**: ~14 features across 7 phases.

**Self-bootstrapping**: After Phase 1, NEW features (F-0177+) are tracked through the 9-state lifecycle. Existing shipped/planned features stay valid. In-progress features get manual audit during migration. The framework dogfoods from Phase 1 onward — but only for new features, not retroactively.

## How We Work Through This

- Each phase gets its own detailed plan (via `ag plan`) when we start it
- Each phase registers features in FEATURES.md with acceptance criteria before coding (budgeted as part of the phase)
- We start with Phase 1 immediately after this roadmap is approved
- The roadmap itself is saved to `.agentic/journal/plans/` as a durable artifact
- After each phase ships, we review the roadmap and adjust if needed

## Verification

After all phases:
- `bash tests/validate_framework.sh` passes
- `python3 -m pytest tests/ -x --ignore=tests/llm` passes
- Existing projects upgrade cleanly via `upgrade.sh`
- Framework's own NEW features tracked through 9-state lifecycle
- `ag auto epic` can execute a multi-feature epic with review checkpoints
- Critical agent produces meaningful reviews (validated by LLM behavioral tests)
