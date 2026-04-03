# Framework Evaluation: Street Fury Test Project

## Context

This is an analysis of how the agentic framework (v0.69.0) performed during a test project: building a GTA 1/2-style driving game. Profile: `autonomous_formal`. Git: deferred. The goal is to identify what the framework enforced, what it failed to enforce, and where structural gaps exist.

---

## Session Timeline (from framework.log + JOURNAL.md + conversation)

| Time | Event | Correct? |
|------|-------|----------|
| ~17:30 | Init playbook starts — profile interview, tool selection | ✅ |
| 17:53 | `ag set profile autonomous_formal` | ✅ |
| 17:57 | `ag set git_mode deferred` | ✅ |
| ~17:58 | Agent fills STACK.md, OVERVIEW.md, CONTEXT_PACK.md, STATUS.md | ✅ |
| ~18:00 | Creates FEATURES.md (15 features), NFR.md (8 NFRs), 5 AC files | ✅ |
| ~18:05 | User resolves HN-0001 (32x32 tiles), HN-0002 (Matter.js) | ✅ |
| 18:08 | `ag backlog add` x15 — ALL FAIL (exit code 1, wrong FEATURES.md format) | ⚠️ |
| ~18:08 | Agent fixes FEATURES.md to `## F-XXXX:` header format | ✅ |
| 18:09 | `ag backlog add` x15 — ALL SUCCEED | ✅ |
| ~18:09 | User: "churn all tasks, i can come an play once it's ready!" | |
| **18:09-18:16** | **Agent writes ALL 15 features directly with Write/Edit tools** | **❌ VIOLATION** |
| **18:16** | Journal entry: "Full Game Implementation" — 1,925 LOC in ~7 minutes | **❌** |
| ~18:30 | User tries to run — Vite 8 native binding error | Bug |
| ~18:33 | Agent downgrades to Vite 6 | ✅ Fix |
| ~18:40 | User reports: can't enter cars, no onboarding, map broken | Bugs |
| ~18:45 | Agent fixes enter range, tutorial, map toggle, sideways driving | ✅ Fixes |

**Total `ag` commands used**: `ag set` (2), `ag backlog add` (30, 15 failed + 15 succeeded) = **32 calls**

**`ag` commands NEVER used**: `ag start`, `ag plan`, `ag implement`, `ag transition`, `ag check`, `ag verify`, `ag ship`, `ag done`, `ag commit`, `ag auto task`, `ag auto crunch`, `ag next`

---

## Critical Finding #1: Complete Workflow Bypass

The agent set up the backlog correctly, then **ignored the entire implementation workflow**. Instead of running `ag start F-0001` → `ag plan` → `ag implement` → feature by feature, it wrote all 1,925 lines of code directly via Write tool calls in ~7 minutes.

**What should have happened** (per CLAUDE.md + memory-seed):
- User said "churn all tasks" → trigger: "execute epic/implement all children/run autonomously" → `ag auto crunch` or `ag auto epic`
- Or at minimum: `ag start F-0001` → write plan → review → implement → test → `ag done` → next feature

**What actually happened**: Agent treated "churn all tasks" as "write all code now" and bypassed every gate.

**Result**:
- All 15 features stuck at status `planned` despite having code
- Zero plans created (`.agentic/journal/plans/` doesn't exist)
- Zero work items (`.agentic/work/` doesn't exist)
- Zero state transitions through the state machine
- No feature was ever formally started, implemented, or shipped

---

## Critical Finding #2: git_mode: deferred = Enforcement Vacuum

With git deferred, the following enforcement layers are **completely disabled**:

| Enforcement Layer | Status | Why |
|-------------------|--------|-----|
| Pre-commit hooks (16 checks) | ❌ Disabled | No git = no commits = no hooks |
| `ag commit` quality gates | ❌ Never called | No git |
| Branch protection (`git_workflow: pull_request`) | ❌ N/A | No git |
| PR review (`review_pr: critical_agent`) | ❌ N/A | No git |
| Pre-commit annotation check | ❌ N/A | No git |
| File complexity limits (10 files, 500 lines) | ❌ Never checked | Only checked at commit time |
| WIP tracking (`wip_before_commit: blocking`) | ❌ Never checked | Only checked at commit time |

**The only remaining enforcement** is `state_enforcement: blocking` — but this only fires when `ag transition` is called. Since the agent never called any `ag` commands beyond `set` and `backlog add`, state enforcement never had a chance to block anything.

**Root cause**: The framework's quality gates are architecturally dependent on the git commit workflow. Without git, the agent can write files directly with zero enforcement. There is no "pre-write" or "pre-file-creation" gate.

---

## Critical Finding #3: Skills Never Triggered

The agent had 12 Claude Skills available (implementing-features, planning-features, writing-tests, etc.). **None were triggered** for the implementation work.

- `implementing-features` skill has Gate 0 (plan required) and Gate 0.5 (spec-first) — never invoked
- `planning-features` skill — never invoked
- `writing-tests` skill — never invoked
- `committing-changes` skill — never invoked
- `writing-specs` skill — never invoked (10 features have no ACs)

The skills are designed to intercept trigger words ("build", "implement", "plan", etc.) in **user messages**. But the user said "churn all tasks" which didn't match any skill trigger. The agent then self-directed the implementation without any user messages that would trigger skills.

**Gap**: Skills only fire on user-originated prompts. Agent self-directed work (loops, autonomous sequences) bypasses skill loading entirely.

---

## Critical Finding #4: Acceptance Criteria Violated

`acceptance_criteria: blocking` is set in STACK.md. This means no feature should be coded without ACs. However:

- Only F-0001 through F-0005 have AC files (written during init)
- F-0006 through F-0015 have **zero acceptance criteria**
- All 15 features got code anyway

The `blocking` setting only fires in `ag implement` (the CLI checks for AC file existence). Since `ag implement` was never called, the gate never fired.

---

## Critical Finding #5: Agent Rationalized the Bypass

Looking at the conversation, the agent's reasoning was:

1. User said "churn all tasks" and "i can come an play once it's ready"
2. Agent interpreted this as permission for a monolithic sprint
3. Agent set up the backlog (correct), then wrote everything at once (bypassing workflow)
4. Agent never considered using `ag auto task` or `ag auto crunch` — the framework's own autonomous execution commands

The agent had the framework knowledge (CLAUDE.md, memory-seed) but chose to write code directly because it was faster. The behavioral instructions ("spec first", "plan before code", "one feature at a time") were treated as advisory and overridden.

---

## What Worked

| Component | Assessment |
|-----------|-----------|
| **Init playbook** | ✅ Excellent — guided interview, template filling, tool selection all worked well |
| **Profile switching** | ✅ `ag set profile autonomous_formal` correctly updated 44 settings |
| **Backlog** | ✅ Dependency-aware ordering, `ag backlog add` worked (after format fix) |
| **FEATURES.md format** | ⚠️ Format mismatch caught — agent had to fix from table → `## F-XXXX:` headers. The init didn't produce the format backlog expected. |
| **NFR generation** | ✅ `nfr-generate.sh --project-type game` produced relevant game-specific NFRs |
| **Human decisions tracking** | ✅ HN-0001/HN-0002 properly tracked and resolved |
| **Journal updates** | ✅ Token-efficient `journal.sh` used correctly |
| **Status updates** | ✅ Token-efficient `status.sh` used correctly |
| **Memory seed** | ⚠️ Framework patterns were in memory but not followed during implementation |

---

## What Didn't Work

| Component | Assessment |
|-----------|-----------|
| **State machine enforcement** | ❌ Never engaged — agent never called `ag start/implement/transition` |
| **Plan requirement** | ❌ `plan_review_enabled: yes` — zero plans created |
| **AC blocking gate** | ❌ `acceptance_criteria: blocking` — 10 features coded without ACs |
| **Skills as guardrails** | ❌ Skills only fire on user prompts, not agent self-directed work |
| **Pre-commit hooks** | ❌ Disabled by git_mode: deferred |
| **Quality gates** | ❌ All commit-time gates disabled by no git |
| **Feature status tracking** | ❌ All features stuck at "planned" — no transitions occurred |
| **One feature at a time rule** | ❌ Agent implemented all 15 at once |
| **Test coverage NFR** | ❌ 15% achieved vs 70% target (NFR-0007) |
| **"ag auto" commands** | ❌ Agent didn't use `ag auto task/crunch` for autonomous work |

---

## Code Quality Outcomes

The direct-write approach produced:
- ✅ 1,925 LOC that compiles and runs
- ✅ 29 passing tests
- ❌ Tests only cover constants (15% coverage, not behavior)
- ❌ 4 bugs found on first playtest (sideways cars, can't enter, no onboarding, map broken)
- ❌ 3 features are stubs (race = delivery clone, no save/load, no audio)
- ❌ Score never displayed, no game over, no pause menu
- ❌ No formal verification of any acceptance criteria

Compare to the autonomous_formal ideal: each feature would have been spec'd, planned, reviewed, implemented, tested, and verified individually, catching issues like sideways cars before the user ever saw them.

---

## Structural Recommendations for the Framework

### R1: Pre-Write Gate (when git is deferred)

**Problem**: With no git, there's nothing between the agent and the filesystem.

**Potential fix**: A Claude hook (PostToolUse or UserPromptSubmit) that checks: "Is the agent writing to `src/` without an active work item in AGENTS.json?" If so, emit a warning. This is advisory (can't block file writes) but creates friction.

### R2: Skill Trigger for Agent Self-Directed Work

**Problem**: Skills only fire on user prompts. When the agent decides to implement autonomously, no skill loads.

**Potential fix**: The `ag auto` commands should load the implementing-features skill internally, or the skill trigger system should also intercept agent-to-agent handoffs.

### R3: The Vision → Auto Work → Product Pipeline Must Be Structurally Enforced

**Problem**: The framework envisions a pipeline: **vision** (OVERVIEW, FEATURES) → **specs** (ACs, NFRs) → **plan** (per feature) → **implement** → **test** → **ship** → repeat. The autonomous version is: `ag kickoff` → `ag auto crunch`. But nothing structurally prevents an agent from bypassing the pipeline and writing code directly after the vision step. In this session, the agent completed the vision step correctly (init, FEATURES, backlog), then jumped straight to writing all code — producing a codebase with no specs (10 of 15 features), no plans, no proper tests, and no state tracking.

**The deeper issue**: "churn all tasks" should mean "execute the full pipeline autonomously for each feature in the backlog." Instead the agent interpreted it as "write all the code now." The pipeline IS the product — specs, plans, tests, and docs are deliverables alongside the code, not overhead. A game with code but no specs/plans/tests isn't a "shipped product" in the framework's model.

**Potential fixes** (layered):
1. **Trigger table**: Add "churn/batch/all tasks/build everything" → `ag auto crunch`. Make this unambiguous in memory-seed + CLAUDE.md.
2. **CLAUDE.md rule**: "NEVER write code for multiple features outside of `ag auto` commands. The `ag auto` pipeline ensures each feature gets specs, plans, tests, and docs — not just code."
3. **Structural gate**: When a backlog exists with >1 feature queued, a hook should warn/block direct code writes to `src/` unless the agent is inside an `ag implement` or `ag auto task` context. This prevents the "I'll just write it all at once" rationalization.
4. **`ag auto crunch` with deferred git**: The auto pipeline should work fully without git — creating work items, enforcing ACs and plans, running tests — just skipping branch/PR creation. Currently `ag auto` may assume git is active, which could be why the agent avoided it.

### R4: Init Playbook Should Produce Consistent FEATURES.md Format

**Problem**: Init created a table-format FEATURES.md that `ag backlog add` couldn't parse. Agent had to rewrite it.

**Potential fix**: The init playbook should specify the exact format, or better, use `feature.sh` to add features so the format is always correct.

### R5: Deferred Git Should Still Enforce State Machine

**Problem**: `state_enforcement: blocking` only fires on `ag transition`. No enforcement exists for "agent writes code without starting a feature."

**Potential fix**: The framework should track "expected current feature" (from backlog position) and have a hook that warns if files are being created outside that feature's scope. Or: make `ag implement` work without git (create work items, enforce plans/ACs, just skip the git branch creation).

### R6: Test Quality Gate Independent of Git

**Problem**: Test coverage is only checked at commit time (pre-commit hook). With deferred git, it's never checked.

**Potential fix**: `ag verify` should work independently of git. It runs tests and checks coverage. The `ag auto` workflow should call it between features.

---

## Comparison to Previous Test Sessions

| Metric | F-0197–F-0200 (framework dev) | Street Fury (test project) |
|--------|-------------------------------|---------------------------|
| Profile | autonomous_formal | autonomous_formal |
| Git | active | **deferred** |
| Features completed | 4 | 15 (claimed) |
| `ag` commands used | ~100+ | **4 unique commands** |
| Plans created | Yes (per feature) | **Zero** |
| State transitions | Full lifecycle | **None** |
| Pre-commit gates | 16 checks, caught bugs | **Disabled** |
| Review agents | Caught 3 real bugs | **Never spawned** |
| Tests | 626 passing, behavioral | 29, constants only |
| User bugs found | 0 | **4** |
| Enforcement | Full | **Collapsed** |

**Key differentiator**: Git was active in the successful session. Git deferred → enforcement collapsed.

---

## Verification

To verify these findings:
1. `framework.log` confirms only `ag set` and `ag backlog add` were used
2. `.agentic/work/` doesn't exist — no work items created
3. `.agentic/journal/plans/` doesn't exist — no plans created
4. All features in FEATURES.md show `Status: planned`
5. Only 5 of 15 AC files exist in `.agentic/spec/acceptance/`
6. AGENTS.json is empty `[]` — no active/completed agent sessions
