# Plan Critic Review: Framework Simplification & Structural Enforcement

## 1. VERDICT: REQUEST_CHANGES (confidence: high)

The plan's diagnosis is excellent and the directional bet is correct — shifting from instruction-based to structurally-enforced workflows is the right move. However, the plan has significant feasibility gaps, missing migration strategy, underestimated scope in Phase 2, and several ambiguities that would cause implementation to stall or produce a half-finished system worse than the current one.

---

## 2. Missing Requirements / Ambiguous Scope

### 2.1 State mismatch between old and new state machines (CRITICAL)

The current state machine has 9+1 states:
```
planned -> specced -> criteria_set -> tests_written -> implementing ->
verified -> documented -> committed -> shipped (+ deprecated)
```

The proposed YAML has 10 states:
```
idea -> queued -> planning -> plan_review -> spec -> implementation ->
verification -> docs -> ready_to_ship -> shipped
```

These are **fundamentally different state models**. The plan never addresses:
- How do existing features in FEATURES.md (which use the old states) get migrated?
- What happens to features currently in `criteria_set` or `tests_written` states — states that don't exist in the new model?
- The old model separates `specced` and `criteria_set`; the new model merges them into `spec`. Is that intentional? What's lost?
- The old model has `committed` (post-commit, pre-merge); the new model has `ready_to_ship`. Are these the same thing?
- Where did `deprecated` go? It's reachable from any state in the current model.

### 2.2 STACK.md is not just workflow settings

The plan says `state_machine_af.yaml` replaces STACK.md workflow settings. But STACK.md (411 lines in the template) also contains:
- Language/runtime/framework declarations (used by agents to know the tech stack)
- Testing configuration (test commands, frameworks)
- Deployment configuration
- Documentation sources and verification
- Style/taste preferences
- License constraints
- Quality thresholds
- Component definitions for monorepos
- Contract declarations for multi-repo

The plan doesn't say what happens to all of this. Does it stay in STACK.md? Does it move to `state_machine_af.yaml`? If both files exist, which is the source of truth for what?

### 2.3 The `engine: v2` opt-in mechanism is undefined

Phase 1 says "Old `ag` commands continue working. New engine activated via `engine: v2` in config." But:
- Where is this flag checked? In `ag.sh`? In Python?
- Does it apply per-feature or globally? Can some features use v1 and others v2?
- What happens to features that were started under v1 when a user switches to v2?
- How do you run tests for v2 while v1 is still active?

### 2.4 The `ag` command name mapping has gaps

The plan maps 8 new commands but the current system has at least 30+ commands. Many are listed under "Commands that stay in bash" but the mapping is incomplete:
- `ag commit` -> `python3 -m agentic.workflow commit` — but commit is deeply bash-integrated (git operations, hook management, diff display)
- `ag merge`, `ag set`, `ag formalize`, `ag kickoff`, `ag coord`, `ag test`, `ag audit`, `ag nfr`, `ag qa`, `ag dogfood`, `ag analyze-session` — none are mentioned
- `ag auto *` commands are addressed in Phase 2 but unclear how they interact with Phase 1

### 2.5 "No escape hatches in formal mode" — what about lean mode?

The plan explicitly says formal mode has no escape hatches. But what about lean mode? The current system has `SKIP_BACKLOG`, `SKIP_SPEC_CHECK`, `SKIP_CLARITY` (26 occurrences across 5 command files). If lean mode preserves escape hatches, you've just recreated the same problem for most users (who will use lean mode by default).

---

## 3. Missing Edge Cases and Failure Modes

### 3.1 No backward compatibility / migration strategy for existing projects

This is the single biggest gap. The plan discusses migration in terms of *framework files* (what to add, what to remove) but never addresses:
- **Existing projects using the framework**: How does a team currently on v0.54 (with FEATURES.md, spec/acceptance/, journal/plans/) upgrade?
- **Data migration**: Features tracked in FEATURES.md need to be migrated to `.agentic/work/F-XXXX/item.yaml`. Who does this? Is there an `ag migrate` command?
- **In-flight work**: A team mid-feature with a plan in `journal/plans/` and ACs in `spec/acceptance/` — does the upgrade break their workflow?
- **Rollback**: If the upgrade breaks things, can they go back? Phase 3 deletes 474 files — that's not easily reversible.

### 3.2 Crash recovery during transitions

The current system has `intents.py` (574 lines) for write-ahead logging of crash recovery. The plan mentions preserving it but doesn't address:
- How does `TransitionOrchestrator` integrate with intents?
- If a transition fails halfway (artifacts checked, gate partially run), what's the recovery path?
- The per-work-item `item.yaml` records transitions — but who cleans up partial transitions?

### 3.3 Concurrent agent access to `.agentic/work/F-XXXX/`

The current system has `AGENTS.json` for multi-agent coordination. The new per-work-item directories are a more granular locking surface. But:
- Two agents could try to advance the same feature simultaneously
- File-level locking on `item.yaml` is not addressed
- The current system uses worktrees; do worktrees each get their own `.agentic/work/` copy?

### 3.4 What happens when `ag transition` fails?

The plan says transitions produce "hard error with specific message." But what does the *agent* do next? The current system has 12 skills and 9 checklists that tell agents how to recover. With 4 role prompts, the recovery guidance is dramatically reduced. An agent hitting "Error: plan.md not found for transition to spec" needs to know: "write a plan.md file." The role prompt system needs to handle error recovery, not just happy-path guidance.

---

## 4. Risks

### 4.1 Phase 2 scope is drastically underestimated (HIGH RISK)

The 7 files targeted for refactor are **5,520 lines of Python** (not "250KB+" as the plan says — that would be closer to the entire auto/ directory at 15,234 lines across 28 files). But even 5,520 lines is a massive refactor. Each file is deeply integrated:

- `engine.py` (675 lines): Manages Unix domain sockets, PID files, threading, spawning Claude instances. This isn't just "delegate to TransitionOrchestrator" — it's the runtime execution engine.
- `kickoff.py` (1,321 lines): The largest single file, responsible for vision-to-backlog pipeline. Converting this to create `item.yaml` files means re-implementing the entire output format.
- `scheduler.py` (767 lines): Priority scheduling with dependency resolution. Replacing this with "read priorities from item.yaml" loses the scheduling algorithm.

"~1 week" for this is not realistic for a single developer. Each of these files took weeks to develop and has non-trivial test coverage (10 test files in `tests/` covering auto system). The refactor would break all those tests.

### 4.2 4 role prompts cannot replace 35 subagent roles (MEDIUM-HIGH RISK)

The current system has 35 subagent roles covering specialized domains: `security-agent.md`, `db-agent.md`, `aws-agent.md`, `perf-agent.md`, `ux-agent.md`, etc. Collapsing these into 4 generic role prompts (planner, reviewer, implementer, verifier) loses domain-specific guidance.

When implementing a database migration, the `db-agent.md` provides database-specific review criteria. The generic `reviewer.md` won't have this. The plan's response would be "the CLI can load additional context" but this is never specified.

### 4.3 Phase 3 file deletion is irreversible and high-blast-radius (HIGH RISK)

Deleting 474 files in a single phase is extremely risky:
- Battle-tested edge-case handling buried in those files will be lost
- The 602-line `auto_orchestration.md` and 12 skills encode years of discovered failure modes
- Even with git history, reconstructing lost logic is costly
- The plan's own risk table says "Lose battle-tested patterns" but the mitigation ("Preserve token-efficient scripts, pre-commit hooks, feature IDs") covers maybe 5% of the lost content

### 4.4 The "agents will just use `ag` commands" assumption may not hold (MEDIUM RISK)

The plan assumes that a 30-line CLAUDE.md saying "use `ag` commands" will be sufficient for agents. But:
- Agents need to know *when* to use which command. The current trigger-word tables and skills provide this routing.
- A 30-line CLAUDE.md means all intelligence is in the CLI's error messages. Are those messages rich enough to guide an agent?
- What about tasks that don't fit the state machine? Bug fixes, refactoring, documentation-only changes, infrastructure work. The current system has dedicated skills for these.

### 4.5 Two-file state problem

With `state_machine_af.yaml` for workflow config and `item.yaml` per work item, plus the existing `STACK.md` for non-workflow config, you now have three config surfaces. The plan doesn't resolve whether STACK.md survives, gets merged, or gets replaced.

---

## 5. Test Plan Adequacy

### 5.1 Phase 1 tests are thin

4 test scenarios for the core of the new system is insufficient:
- No negative path testing beyond "try transition without plan.md"
- No concurrent access testing
- No crash recovery testing
- No test for mode-switching (formal to lean mid-feature)
- No test for the `engine: v2` flag behavior

### 5.2 Phase 2 tests don't address regression

3 test scenarios for refactoring 5,520 lines of Python. The existing test suite has 10+ test files covering the auto system. The plan should specify:
- All existing auto system tests must pass after refactor (or have explicit mapping to new tests)
- Integration tests for TransitionOrchestrator + engine interaction
- Stress tests for concurrent work items

### 5.3 Phase 3 tests are aspirational, not verifiable

"Agent compliance: New 30-line CLAUDE.md session — agent uses `ag` commands without full workflow instructions" is not a reproducible test. It's an LLM behavioral test that depends on the model, context, and session. The current LLM test suite (171 test files, 19K lines) is much more thorough.

### 5.4 No end-to-end integration test

There's no test that walks a feature through the entire lifecycle (idea -> shipped) using the new system and verifies all artifacts were correctly produced and all gates fired.

---

## 6. Specific Concerns

### 6.1 Is the 85% file reduction realistic and safe?

The math checks out (554 -> ~80), but "realistic" and "safe" are different questions. The reduction is achievable by deletion, but the question is whether the remaining 80 files contain equivalent capability. They don't — the plan explicitly acknowledges losing 35 subagent roles, 12 skills, 9 checklists, 20+ workflow docs. This is capability reduction, not just file reduction.

**Verdict**: Realistic in terms of file count. Unsafe in terms of capability preservation. The framework will be simpler but less capable until role prompts are proven to cover the same ground.

### 6.2 Can 4 role prompts replace 12 skills + 36 subagents?

No, not directly. The 12 skills cover different *activities* (implementing, fixing bugs, writing tests, reviewing, committing, completing, planning, exploring, researching, writing specs, updating docs, session start). The 4 role prompts cover different *phases* (planning, reviewing, implementing, verifying).

Missing coverage:
- **Bug fixing**: Not a "phase" — it's a different workflow. The `fixing-bugs` skill has specific guidance (write failing test first, bisect, etc.) that doesn't fit into planner/reviewer/implementer/verifier.
- **Session management**: `session-start` skill handles dashboard, orphaned plan detection, memory-seed refresh. Where does this go?
- **Research/exploration**: `exploring-codebase` and `researching-topics` are not phase-based activities.
- **Committing**: The `committing-changes` skill has 10+ steps (pre-commit checks, journal update, status update, feature status, git operations). The `verifier.md` prompt would need to be enormous to cover all of this.

### 6.3 Is the auto system refactor feasible in ~1 week?

No. The 7 targeted files total 5,520 lines, but they have dependencies on 21 other Python files in `auto/` (15,234 lines total). Refactoring the core 7 without touching the other 21 is unlikely — `engine.py` imports from `spawn_claude`, `task.py`, `crunch.py`, `pipeline.py`, `parallel.py`, etc.

A more realistic estimate is 3-4 weeks for Phase 2, with significant risk of destabilizing the autonomous system.

### 6.4 Does `state_machine_af.yaml` cover all real-world needs?

The example YAML shows a simple linear workflow with 10 states and mode/profile modifiers. Real-world needs not covered:
- **Parallel states**: A feature can be in `implementation` while a sub-task is in `verification`. The flat state model doesn't handle this.
- **Conditional transitions**: "If lean mode AND small change, skip from queued directly to implementation" — the skip_transitions array handles this but it's coarse.
- **Custom states**: User projects may need states like `design_review`, `security_review`, `staging`, `qa`. The plan says "resist adding states" but real projects need them.
- **Timeouts / SLAs**: No mechanism for "if stuck in plan_review for > 2 days, escalate."
- **Sub-features / epics**: The flat `work/F-XXXX/` model doesn't represent parent-child relationships between epic and child features.

### 6.5 Migration path for existing projects

Not addressed at all. This is the most important missing piece. The framework has existing users (per STACK.md template, it's distributed). An upgrade path must:
1. Detect existing framework version
2. Migrate FEATURES.md entries to `work/F-XXXX/item.yaml` files
3. Migrate `spec/acceptance/F-XXXX.md` to `work/F-XXXX/spec.md`
4. Migrate `journal/plans/*F-XXXX-plan.md` to `work/F-XXXX/plan.md`
5. Preserve STACK.md non-workflow settings
6. Handle partial upgrades (Phase 1 only, not Phase 3)

---

## 7. Concrete Change Requests

1. **Add a Migration section to the plan**: Define `ag upgrade` command that migrates existing project data (FEATURES.md -> work/F-XXXX/, spec/acceptance/ -> work/F-XXXX/spec.md, journal/plans/ -> work/F-XXXX/plan.md). This must be part of Phase 1, not deferred.

2. **Reconcile the state models explicitly**: Document a mapping from old states (planned, specced, criteria_set, tests_written, implementing, verified, documented, committed, shipped, deprecated) to new states (idea, queued, planning, plan_review, spec, implementation, verification, docs, ready_to_ship, shipped). Handle deprecated. Handle the criteria_set/tests_written states that have no obvious new equivalent.

3. **Expand Phase 2 timeline to 3-4 weeks** and add an incremental strategy: Start with `engine.py` only, prove TransitionOrchestrator integration works, then move to other files one at a time. Do not attempt all 7 simultaneously.

4. **Add 2-3 more role prompts** to cover missing activities: `bug-fixer.md` (write failing test first, bisect), `session-manager.md` (session start, orphaned plans, memory), `researcher.md` (codebase exploration, topic research). 4 is too few; 7 is still a massive reduction from 47 (12 skills + 35 subagents).

5. **Define what happens to STACK.md**: Either (a) `state_machine_af.yaml` absorbs ALL of STACK.md (make this explicit with sections for tech stack, testing, deployment, etc.) or (b) STACK.md survives for non-workflow config and the plan documents the split clearly.

6. **Phase 3 should be incremental, not a big bang**: Instead of archiving all 474 files at once, remove them category by category (skills first, then checklists, then workflow docs, then subagents) with verification after each removal that the system still works. Add a rollback mechanism (a single `git revert` should restore a category).

7. **Add an escape hatch policy**: The plan says "no escape hatches in formal mode" but the current system has 26 escape hatches across 5 command files for good reason (bootstrapping, migration, edge cases). Define which escape hatches are truly removed vs. which are preserved with audit logging.

8. **Add error message design to Phase 1 scope**: If the CLI is the primary interface for agents, its error messages ARE the instruction surface. Budget time for designing clear, actionable error messages that tell agents exactly what to do next. Example: "Error: Cannot transition F-0244 to implementation. Missing: plan.md. Create a plan at .agentic/work/F-0244/plan.md describing your implementation approach. See: ag help plan"

9. **Address the epic/child-feature relationship**: The flat `work/F-XXXX/` directory doesn't model that F-0244 might be an epic with children F-0245, F-0246, F-0247. The current system handles this through `epic.py` decomposition. Define how parent-child relationships are stored in the new model (likely a `parent` field in `item.yaml` or a `children` list).

10. **Define the `ag check` contract precisely**: The plan lists `ag check F-XXXX` as a validation command but never defines what it validates. It's referenced in Claude Code hooks, pre-commit hooks, and as a general "validate artifacts" tool. Specify: what does it check for each state? What's the output format? Is it machine-parseable?

11. **Add explicit test count targets**: Phase 1 should have at minimum 20-30 test cases (state machine transitions, artifact validation, mode/profile interaction, error paths, concurrent access). Phase 2 should map each existing auto test to a new equivalent. Phase 3 should preserve all LLM behavioral tests (updated for new commands).

12. **Consider keeping skills as an optional enhancement layer**: Instead of deleting 12 skills entirely, keep the skill loading mechanism but make skills optional. The CLI enforces workflow; skills provide *quality guidance*. This preserves the three-layer architecture (config -> CLI -> optional skill prompts) while achieving the simplification goal.

---

## Summary

The plan correctly identifies the core problem (instruction-based enforcement doesn't work) and proposes the right architectural direction (state-machine-driven enforcement with artifact contracts). The Phase 1 design is solid in concept. But the plan has three fatal gaps:

1. **No migration strategy** for existing projects — this will block adoption
2. **Phase 2 is 3-4x underscoped** — 5,520 lines of deeply integrated Python can't be refactored in a week
3. **Phase 3 capability loss is unaddressed** — the plan counts files removed but not capabilities lost

Fix these three, address the 12 concrete change requests, and this plan becomes shippable.
