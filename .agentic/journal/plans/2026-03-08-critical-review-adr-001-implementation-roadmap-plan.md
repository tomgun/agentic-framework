# Critical Review: ADR-001 Implementation Roadmap

**Verdict: REQUEST CHANGES**

The roadmap is strategically sound in its "state machine first" reordering, but has significant gaps in migration safety, underestimates the blast radius of the 4-to-9-status change, and omits several categories of work that will be required. The self-bootstrapping claim is aspirational, not realistic without explicit coexistence design. Below are detailed findings.

---

## 1. Order Correctness

### What's right
The decision to reorder from the ADR's suggested sequence (Components -> Epics -> State Machine -> MCP -> Multi-repo -> Autonomous) to (State Machine -> Components -> Reviews -> Epics -> MCP -> Autonomous) is well-reasoned. The state machine IS the spine. Building it first means all subsequent phases use `ag transition` as their primitive. This is a genuine improvement over the ADR's suggested order.

### Problems found

**Phase 2 (Components) could start in parallel with Phase 1.** Components are "metadata decoration" (the roadmap's own words, line 76). They don't depend on the state machine. The `## Components` section in STACK.md, the `components.py` parser, and the `context-for-role.sh` filtering are all independent of the state machine. Only the "component-aware gates" line (line 60, 70) creates a dependency. The roadmap should split Phase 2 into 2a (registry + parsing, parallel with Phase 1) and 2b (gate integration, after Phase 1).

**Phase 3 claims to deliver `autonomous_formal` profile, but the profile can't be tested until Phase 6.** The roadmap says Phase 3 delivers the profile (line 95), but the profile's value is that review checkpoints run in an autonomous loop. Without the scheduler (Phase 6), the `autonomous_formal` profile is just a configuration with no runner. It should be *defined* in Phase 3 but *finalized* in Phase 6 (which the roadmap acknowledges at line 225: "Finalize `autonomous_formal` defaults"). This creates a confusing ownership story -- where does the profile actually ship?

**Phase 4 (Epics) depends on Phase 2 for component scoping, but the roadmap doesn't call this out explicitly.** Line 161 says "Epics require components (to scope children)" but the Phase 4 key files table doesn't MODIFY `components.py`. If component scoping is needed for `ag decompose` to assign children to components, that's a Phase 2 dependency the code table doesn't reflect.

---

## 2. Scope Realism

### Feature count assessment
13 features across 6 phases is reasonable for the *scope of new code*, but dramatically undercounts the *modification surface*. The roadmap lists ~25 files to create/modify across all phases, but does not account for:

- 12 Claude Skills that reference the current 4-status model (found in `.claude/skills/`)
- 10 checklists that reference `planned / in_progress / shipped` (found in `.agentic/lib/checklists/`)
- `validate_formats.py` which hard-codes `valid_statuses = {"shipped", "in_progress", "planned", "deprecated"}` (line 47)
- `pre-commit-check.sh` which greps for `status.*shipped` (line 160)
- `feature-complete.sh` which validates status transitions
- The `before_commit.md` checklist which tells agents to check status is `planned / in_progress / shipped` (line 124)
- `feature_implementation.md` which says "Status: `planned` -> `in_progress` -> `shipped`" (line 135)
- `ag.sh` which tells users to "Update FEATURES.md status to 'in_progress'" (line 739)

**Estimated true modification surface: 40-50 files, not 25.** This is a significant undercount.

### Phase 3 is too large
Phase 3 bundles four distinct things: review checkpoint routing, CriticalAgent implementation, taste/style settings, and `autonomous_formal` profile. Each is a feature with its own acceptance criteria. The "~3 features" estimate is probably 4, and the CriticalAgent alone (spawning a separate agent instance with adversarial prompting, capturing structured verdicts) is the hardest single piece of work in the entire roadmap. This phase should be split.

### Phase 6 is too large
Phase 6 bundles the autonomous scheduler AND multi-repo umbrella. These are orthogonal concerns. Multi-repo could be a separate phase or even a separate ADR implementation. The roadmap acknowledges this ("multi-repo adds cross-repo handling orthogonal to everything else," line 231) but bundles them anyway.

---

## 3. Gaps: ADR Sections Under-Represented

### ADR Section 5.2 (Taste & Aesthetics): Partially covered
The roadmap mentions taste settings in Phase 3 (line 94) and creates `prompts/taste_review.md` (line 117), but doesn't address:
- Where `style_guide`, `design_system`, `api_style` settings get loaded into agent context
- How the critical agent's taste review differs from its code review
- The "hierarchy of guidance" (ADR lines 298-307) -- this is a design document, not just a setting

### ADR Section 7 (Open Questions): Completely ignored
The ADR explicitly lists 10 open questions (lines 469-489). The roadmap doesn't address ANY of them, nor does it say "these are deferred." Several are directly relevant:
- **Q6 (State machine persistence format)**: The roadmap assumes state lives in FEATURES.md's `status` field but never explicitly decides this. This is a Phase 1 design decision that must be made before coding.
- **Q7 (Regression cascade depth)**: The roadmap says "cascade rules" (line 24) but doesn't address configurability.
- **Q8 (Critical agent model selection)**: The roadmap creates a CriticalAgent class but doesn't specify model selection. The ADR asks whether the critical agent should always use the best model. This affects Phase 3 design.
- **Q4 (CONTEXT_PACK granularity)**: Relevant to Phase 2 (component-scoped context).

### ADR "Consequences" section: Not addressed
The ADR identifies "Python state machine adds a runtime dependency (currently bash-only)" as a negative consequence (line 506). The roadmap doesn't address how to handle Python being unavailable (many projects are JS-only). Is Python now a hard requirement for the framework? This is a **breaking change for framework users who don't have Python**.

Wait -- the framework already uses Python (engine.py, crunch.py, task.py, verify.py, query_features.py, validate_formats.py). So Python is already a dependency. But this should still be made explicit.

---

## 4. Migration Risk

### The 4-to-9 status change is the biggest risk in the entire roadmap, and it's underestimated.

**Current state (hard-coded in multiple files):**
- `feature.sh`: validates `planned | in_progress | shipped | deprecated` (4 values)
- `validate_formats.py`: hard-codes `valid_statuses = {"shipped", "in_progress", "planned", "deprecated"}`
- `pre-commit-check.sh`: greps for `status.*shipped` to find shipped features
- `crunch.py`: regex matches `planned|in-progress` to find work
- `query_features.py`: sorts by `["shipped", "in_progress", "planned"]`
- 10 checklists: reference `planned / in_progress / shipped`
- 12 Skills: generated from checklist/workflow content, inherit status references

**The roadmap's mitigation (line 36):** "Extend status values from 4->9, backward compat aliases (`in_progress` -> `implementing`)"

This is backwards. The alias should be `implementing` -> `in_progress` (for reading old data), not the other way around. When reading a FEATURES.md that says `in_progress`, the state machine should treat it as `implementing`. When writing, it should write the new value. The roadmap's arrow direction suggests it's mapping old to new, which is correct for upgrade.sh, but the language is ambiguous.

**What could break:**
1. `crunch.py._read_planned_features()` regex-matches `planned|in-progress`. After Phase 1, features in states like `specced`, `criteria_set`, `tests_written` are NOT `planned` and NOT `in-progress`. They would be invisible to crunch mode. The crunch runner must be updated to understand ALL pre-implementing states as "needs work" and `implementing` as "in progress."
2. `pre-commit-check.sh` checks shipped features have acceptance criteria. With 9 states, should it check `committed` features too? Or only `shipped`? The new states between `verified` and `shipped` are ambiguous.
3. `validate_formats.py` will reject ANY of the 5 new status values until updated. **This means Phase 1 cannot ship without updating validate_formats.py, but the roadmap doesn't list it as a key file.**
4. Skills are generated from checklists and workflows. If the checklists say "update status to in_progress" but the state machine uses "implementing," agents will write invalid status values. **Skills must be regenerated after checklist updates, and the checklist updates are not in the roadmap.**

### Backward compatibility claim is dubious for Phase 1
The roadmap says "advisory mode -- warns on invalid transitions, doesn't block" (line 23). But the *format* change (9 status values instead of 4) is not advisory -- it's a data format change. `validate_formats.py` will reject new values. The pre-commit hook will reject new values. This is not "backward compatible" -- it's a format migration.

---

## 5. Self-Bootstrapping Claim

> "After Phase 1, the framework tracks itself through the new lifecycle while building subsequent phases." (line 41, paraphrased at line 252)

### This is unrealistic without explicit coexistence design.

**Problem:** The framework currently has 136 features in FEATURES.md (14+22+12+10+11+7+15+10+12+17+6 = 136). All have status values from the 4-value set. After Phase 1:

1. **New features (F-0177+)** would use the 9-state model. Fine.
2. **Existing shipped features (125 of them)** have `status: shipped`. This maps cleanly to the new `shipped` state. Fine.
3. **Existing in-progress features (7 of them)** have `status: in_progress`. What state do they map to? `implementing`? But they might actually be in `specced` or `criteria_set` or `tests_written`. There's no way to know from the current data.
4. **Existing planned features (3 of them)** have `status: planned`. This maps cleanly. Fine.

The real problem: **the framework's existing 7 in-progress features have lost information.** The migration can only map them all to `implementing` (the most conservative assumption), but their ACTUAL state in the 9-state model might be different. This means the state machine will show them as `implementing` when they might actually be `criteria_set`.

**Recommendation:** Phase 1 should include an explicit audit of in-progress features and manual state assignment, not just automated migration.

### Coexistence friction
During Phase 1 development, the developer (you) will be using the framework to build the state machine. But the state machine isn't built yet. So you'll be using the 4-status model to track the feature that creates the 9-status model. This is fine conceptually but means the "self-bootstrapping" claim only applies AFTER Phase 1 ships, not during it.

---

## 6. Current Code Integration

### The plan mostly accounts for existing code, but misses integration points.

**`engine.py`**: The AutoEngine processes features by loading acceptance criteria and spawning Claude per AC. The state machine doesn't change this core loop, but the roadmap doesn't explain how `engine.py` learns about state transitions. Does `_implement_ac()` call `ag transition` after passing? Who triggers the `implementing -> verified` transition? The roadmap is silent on this.

**`task.py`**: TaskRunner creates branches, implements ACs, commits, and creates PRs. This is essentially a manual implementation of `planned -> ... -> committed`. The state machine should wrap TaskRunner, not replace it. But the roadmap doesn't show how TaskRunner gets state-machine awareness.

**`crunch.py`**: The roadmap says Phase 4 modifies crunch.py for "dependency-ordered processing" (line 156), and Phase 6 evolves it into "scheduler-backed parallel execution" (line 216). This is TWO major rewrites of the same file, in different phases. That's a recipe for rework. Consider: should crunch.py be left alone until Phase 6, and Phase 4 just adds `epic.py` with its own processing logic?

**`verify.py`**: Not mentioned anywhere in the roadmap, but it's the test-running loop. The state machine's `implementing -> verified` transition gate ("all acceptance tests pass, smoke test passes") is essentially verify.py. The roadmap doesn't show how the gate delegates to verify.py.

**`control.py`**: Not mentioned. The existing control socket (Unix domain socket for pause/resume/stop) will need to coexist with the MCP server in Phase 5. No mention of this potential conflict.

### Hardcoded regex in crunch.py
`_read_planned_features()` uses a regex that matches `planned|in-progress` in a table format (pipe-delimited). But FEATURES.md doesn't use tables -- it uses markdown headers with key-value fields. Looking at the actual FEATURES.md format:
```
## F-0001: Project Initialization
**Status**: shipped
```
The regex `r"\|\s*(F-\d{4})\s*\|.*?\|\s*(planned|in-progress)\s*\|"` wouldn't match this format at all. **This means crunch.py's `_read_planned_features()` is already broken against the current FEATURES.md format.** This is a pre-existing bug, but the roadmap should note it since Phase 1 modifies feature.sh and query_features.py, which interact with the same data.

---

## 7. Missing Pieces

The roadmap omits the following categories of work:

### 7a. Checklist updates (10 files)
Every checklist that references status values needs updating:
- `before_commit.md` (line 124: "planned / in_progress / shipped")
- `feature_implementation.md` (line 135: "planned -> in_progress -> shipped")
- `feature_complete.md`
- `feature_start.md`
- `spec_writing.md`
- `session_start.md`
- `session_end.md`
- Others

### 7b. Skill regeneration
12 Skills in `.claude/skills/` are generated from checklists and workflows. After updating checklists, skills must be regenerated or they'll give agents stale instructions. The roadmap doesn't mention `generate-skills.sh` or any skill updates.

### 7c. CLAUDE.md / .cursorrules / instruction file updates
The root-level instruction files are generated by `setup-agent.sh`. If the framework's workflow model changes (9 states instead of 4), these files may need template updates. Not mentioned.

### 7d. Pre-commit hook updates
`pre-commit-check.sh` has:
- Check 2: "shipped features have acceptance criteria" (greps for `status.*shipped`)
- Check 16: "Status downgrade protection for shipped features"

With 9 states, these checks need to understand the new state space. A `committed` feature might need different protection than a `shipped` one. **Not mentioned in any phase.**

### 7e. `validate_formats.py` update
Hard-codes `valid_statuses = {"shipped", "in_progress", "planned", "deprecated"}`. Must be updated in Phase 1 or every commit with new status values will fail validation. **Not listed in Phase 1's key files table.**

### 7f. `doctor.py` update
If doctor.py validates feature statuses, it needs the new values.

### 7g. Documentation
- `docs/INSTRUCTION_ARCHITECTURE.md` needs updating (three-layer architecture may change)
- `CHANGELOG.md` entries for each phase
- `FRAMEWORK_DEVELOPMENT.md` if the dev workflow changes
- Feature acceptance criteria files for the ~13 new features (the roadmap mentions registering features in FEATURES.md but doesn't budget time for writing acceptance criteria)

### 7h. Existing tests
`tests/test_validate_specs.py` likely tests the 4-status validation. Must be updated.

---

## 8. The `autonomous_formal` Profile

### Design is sound in principle, unsound in specifics.

The profile matrix (lines 98-109) shows review defaults across three profiles. The design intent is clear: `autonomous_formal` is "formal but with critical_agent instead of human for most reviews."

### Edge cases not addressed:

1. **What happens when the critical agent escalates?** The ADR says it can escalate to human (line 285). But in `autonomous_formal` mode, escalation means blocking. Does the scheduler know about escalation? Does it move to the next feature? The roadmap doesn't describe the escalation -> scheduler interaction.

2. **What if the critical agent is unavailable?** (Model API down, rate-limited, etc.) Does the transition block indefinitely? Fall back to `auto`? Fall back to `human`? No error handling described.

3. **The `review_code: critical_agent` setting in `autonomous_formal` is dangerous.** Code review is the last line of defense before merge. If the critical agent rubber-stamps (a risk the ADR explicitly acknowledges at line 514), bad code ships. The profile should at minimum support a `critical_agent_then_human` mode for code review, or require that code review in `autonomous_formal` still goes through PR review (which is external to the agent system).

4. **Profile switching mid-feature.** If a feature starts in `formal` (human reviews) and the user switches to `autonomous_formal`, what happens to pending reviews? Are they re-routed? Or do they stay as `human`? Not addressed.

5. **`review_merge: human` in `autonomous_formal`.** This means even in "autonomous" mode, every feature blocks on human merge approval. For a 10-feature epic, that's 10 human touchpoints. Is this actually autonomous? The profile name overpromises.

---

## 9. Testing Strategy

### Unit tests are planned; integration tests are not.

The roadmap lists test files for each phase:
- `tests/test_state_machine.py` (Phase 1)
- `tests/test_components.py` (Phase 2)
- `tests/test_review.py` (Phase 3)
- `tests/test_epic.py` (Phase 4)
- `tests/test_mcp_server.py` (Phase 5)
- `tests/test_scheduler.py`, `tests/test_umbrella.py` (Phase 6)

### Missing:

1. **No integration tests between phases.** The state machine + review checkpoints + components must work together. Where is `test_state_machine_with_reviews.py`? Where is `test_component_aware_gates.py`?

2. **No end-to-end test.** The verification section (line 267) says "`ag auto epic` can execute a multi-feature epic with review checkpoints." This is an E2E test but there's no test file for it. Who verifies this claim?

3. **No test for backward compatibility.** The roadmap claims existing projects upgrade cleanly (line 266). Where is the test that takes a FEATURES.md with old 4-status values, runs `upgrade.sh`, and verifies the migration worked?

4. **No test for the crunch.py -> scheduler evolution.** Phase 6 evolves crunch.py into scheduler-backed execution. The existing crunch tests (if any) might break. No mention of updating them.

5. **LLM behavioral tests.** The framework has an LLM test suite (`tests/llm/`). New agent behaviors (critical agent reviews, autonomous transitions) should have LLM behavioral tests. Not mentioned.

6. **`validate_framework.sh` updates.** The roadmap says it must pass (line 265), but doesn't budget work for updating it to understand the new state space.

---

## 10. Visual Sketch Alignment

I examined the sketch at `.agentic/journal/plans/2026-03-07_agentic_flows_sketch.png`. The sketch shows two flow diagrams:

### Left diagram (conceptual flow):
Shows a progression through high-level stages with boxes for research, decomposition, and implementation, with a key question at the bottom: "Where does 'autonomous agent review' substitute for human review?" The roadmap addresses this through the critical agent (Phase 3).

### Right diagram (detailed flow):
Shows a more detailed pipeline with:
1. User input at the top
2. Decomposition into features
3. Per-feature flow through spec -> criteria -> tests -> implement -> verify -> document -> commit -> ship
4. **Feedback arrows going backward** (from verify back to implement, from review back to spec)
5. A question about "is this whole box automatable?"
6. PR creation and merge as separate steps
7. Cross-feature dependency handling

### Alignment issues:

1. **The feedback arrows (backward flow) in the sketch map to regression transitions in the ADR.** The roadmap includes regression transitions in Phase 1 (line 24: "Regression transitions + cascade rules"). This aligns.

2. **The "is this whole box automatable?" question from the sketch** is answered by the `autonomous_formal` profile. Alignment is good.

3. **The sketch shows "Update reference files, update changelog" as a step.** The roadmap's state machine has a `documented` state (line 20) that covers this. Alignment is good.

4. **The sketch shows dependency arrows between features within an epic.** The roadmap covers this in Phase 4 (epic decomposition) and Phase 6 (scheduler with dependency ordering). Alignment is good.

5. **The sketch's left diagram asks about agent-as-reviewer.** Phase 3's CriticalAgent directly answers this. Alignment is good.

6. **MISSING from roadmap: The sketch shows a "collect user input + research + visual refs" step at the top.** The roadmap's Phase 6 mentions "User prompt + research + visual guidelines + style refs" (quoting the ADR, line 402) but doesn't create any tooling for collecting/organizing this input. This is a gap -- who gathers the user's vision, style references, and research before decomposition starts?

---

## Summary of Required Changes

### Must fix before approving:

1. **Add `validate_formats.py` to Phase 1 key files** -- currently hard-codes 4 status values, will reject all new states.
2. **Add checklist/skill update sweep to Phase 1** -- at least 10 checklists and 12 skills reference old status values.
3. **Add pre-commit-check.sh to Phase 1 key files** -- checks 2, 15, 16 reference status values.
4. **Address the crunch.py regex bug** -- it doesn't match the current FEATURES.md format. Either fix it in Phase 1 or explicitly defer.
5. **Explicitly decide ADR Open Question 6** (state persistence format) before Phase 1 coding begins.
6. **Split Phase 3** -- CriticalAgent is big enough to be its own phase. Don't bundle it with taste settings AND the profile.
7. **Add integration test plan** -- the current testing strategy is unit-test-only.

### Should fix:

8. Clarify the `in_progress -> implementing` alias direction in migration.
9. Explain how `engine.py` and `task.py` learn about state transitions (who calls `ag transition` during autonomous execution?).
10. Note that `verify.py` is the implementation of the `implementing -> verified` gate.
11. Address critical agent escalation -> scheduler interaction.
12. Budget time for acceptance criteria files for the ~13 new features (the roadmap says "registers features in FEATURES.md with acceptance criteria before coding" but doesn't count this as work).
13. Consider separating multi-repo (Phase 6) into its own phase.

### Nice to have:

14. Start Phase 2a (component registry parsing) in parallel with Phase 1.
15. Add LLM behavioral tests for critical agent behavior.
16. Address user input collection gap from the visual sketch.
