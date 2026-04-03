# Analysis: Idea-to-Working-Software Pipeline — Autonomy Levels & Gaps

## Context

The user asks: given all our framework features, how would the **complete lifecycle** (idea → specced → tested → implemented → deployed working software) work across different user involvement levels? What exists, what's missing, and what configurations are possible?

This is a **strategic gap analysis**, not a single feature plan. It identifies the framework's current capabilities, maps them against three autonomy levels, and surfaces the gaps that need new features or strengthening.

> **Review applied**: Fresh adversarial review identified 12 issues (2 CRITICAL, 4 HIGH). Key fixes incorporated: reordered implementation sequence, acknowledged auto-commit complexity across 28+ files, recognized modes as a configuration spectrum not a taxonomy, identified F-0188 overlap, added kickoff validation via staging area. See "Reviewer Issues Addressed" section at the end.

---

## The Three Modes (ordered by autonomy: least → most)

### Mode 1: "Tech Lead" (User controls pace and quality)
- User: reviews feature plans, reviews PRs/code, controls backlog, may write specs and code
- Framework: implements, tests, creates PRs, manages state
- This is essentially what the framework does today with `formal` profile
- Profile: `formal` with `review_code: human`, `review_merge: human`
- Autonomy level: LOW — human in the loop at every significant transition

### Mode 2: "Product Visionary" (User drives what, not how)
- User provides: vision, taste/aesthetic preferences, NFRs, architecture opinions, feedback on working software
- User does NOT: review code, review PRs, write specs, control implementation details
- Framework handles: decomposition, specs, plans, implementation, testing, code review (critical agent), deployment preview
- User interaction: interviews, research review, seeing/testing running software, giving feedback
- Profile: `autonomous_formal` with taste settings + preview capability
- Autonomy level: MEDIUM — human drives direction, framework handles execution
- Transition: starts as discovery exploration, transitions to formal specs based on approved plans

### Mode 3: "Fully Autonomous" (Framework does everything from prompt)
- User provides: initial prompt + research + style guidelines
- Framework does: decompose → plan → spec → implement → review → ship → preview
- Only escalates to user when genuinely stuck or for final acceptance
- Profile: `autonomous_formal` with `review_merge: critical_agent` (or new `auto` merge mode)
- Autonomy level: HIGH — human only for final acceptance and escalations

---

## Current State: What Works Today

### Strong Foundation (Modes 1/2/3)
| Capability | Status | Key Files |
|---|---|---|
| Three profiles (discovery/formal/autonomous_formal) | Shipped | `profiles.conf` |
| Configurable review checkpoints per transition | Shipped (F-0184) | `review.py`, `state_machine.py` |
| Critical review agent (adversarial AI reviewer) | Shipped (F-0182) | `critical_agent.py` |
| Feature state machine (9 states, forward + regression) | Shipped (F-0177) | `state_machine.py` |
| Epic decomposition (epic → child features) | Shipped (F-0191) | `epic.py` |
| Ordered backlog with dependencies | Shipped | `backlog_helpers.py` |
| Dialectical plan review (Critic + Advocate) | Shipped (F-0120) | `ag plan` |
| Multi-agent coordination (AGENTS.json, worktrees) | Shipped (F-0194) | `agents_helpers.py` |
| NFR system (cross-cutting constraints) | Shipped | `spec/NFR.md` |
| Spec-first enforcement (blocking in formal) | Shipped | `feature_start.md` |
| Pre-commit quality gates (17 checks) | Shipped | `before_commit.md` |
| Session continuity (journal, status, context pack) | Shipped | state files |
| Auto-discovery for brownfield projects | Shipped | `discover.py` |

### Recently Shipped: Coordination Server + Autonomous Scheduler (F-0185 + F-0186)

These two features are significant and change the gap analysis:

**Coordination Server (F-0185)** — HTTP JSON-RPC 2.0 on port 4185:
- 8 tools: `claim_feature`, `release_feature`, `transition_state`, `get_unblocked`, `poll_changes`, `report_status`, `request_review`, `submit_review`
- Bearer token auth, thread-safe dispatch, stale PID cleanup
- Files remain source of truth (graceful degradation without server)
- 909 tests, all passing

**Autonomous Scheduler (F-0186)** — `ag auto epic F-XXXX`:
- Discovers non-shipped children of an epic, processes them through the state machine
- Component-scoped workers (each feature's agent sees only relevant code)
- **Non-blocking reviews**: while one feature awaits human/critical agent review, scheduler advances other features
- All-blocked detection: polls for review resolution when every feature is waiting
- Escalation → HUMAN_NEEDED.md, continues with other work
- Engine state: pause/resume/stop
- Progress persistence: `.agentic/session/scheduler-state.json` for resume
- 573 tests, all passing
- Subcommands: `ag auto init`, `ag auto status`, `ag auto pause/resume/stop`, `ag auto feedback`

**Impact on gap analysis**: The scheduler already handles the MIDDLE of the pipeline (given an epic with children → process them autonomously). The critical gaps are now at the FRONT (vision → epic → children) and the EDGES (auto-commit/merge, preview, feedback).

### What Works for Each Mode Today

**Mode 1 (Tech Lead)**: Most complete. This is the framework's sweet spot. User reviews plans, code, PRs. Controls backlog. Framework handles implementation.

**Mode 2 (Product Visionary)**: Partially there. Has autonomous_formal profile, critical agent, and the scheduler can crunch through features autonomously. Missing: taste system, preview capability, vision-to-backlog pipeline, feedback capture from working software.

**Mode 3 (Fully Autonomous)**: Execution engine exists (`ag auto epic`), but no way to get from prompt to the epic it needs. Also requires auto-commit/merge — a significant change touching 28+ files where "never auto-commit" is a constitutional principle. And `task.py` already auto-commits in automated execution, creating an undocumented exception that needs to be reconciled.

---

## Gap Analysis: What's Missing

### Gap 1: Vision-to-Backlog Pipeline ("Big Bang Decomposition")
**Severity: CRITICAL for Modes A and C**

**Current state**: User must manually create features one by one: write FEATURES.md entry → write acceptance criteria → add to backlog. `ag decompose` works for ONE existing epic → children. No way to go from "build me an X" to a full backlog.

**What's needed**: An `ag kickoff` or `ag vision` command that:
1. Takes a product vision (prompt, research docs, style references)
2. Conducts structured interview (if Mode 2) or analyzes autonomously (if Mode 3)
3. Generates: OVERVIEW.md, initial FEATURES.md with epics, acceptance criteria stubs
4. Decomposes epics into implementable features (using `ag decompose` under the hood)
5. Populates BACKLOG.json with dependency-aware ordering
6. Routes through review checkpoint (`review_decomposition`) before proceeding

**This is THE biggest gap**. Without it, neither Mode 2 nor Mode 3 can work from a single prompt. The user must do significant manual setup work that the framework should automate.

**Related existing infrastructure**: `ag decompose`, `ag spec`, `ag specs`, `init_playbook.md`, `discover.py` — pieces exist but aren't connected into a single pipeline.

### Gap 2: User Expertise & Role Configuration
**Severity: HIGH for Mode 2, MEDIUM for Mode 3**

**Current state**: Three profiles control agent behavior, but nothing captures the USER's characteristics — expertise level, areas of interest, what they want to control, what they want to delegate.

**What's needed**: A `## User role` section in STACK.md or a dedicated config:
```
user_role: product_visionary | tech_lead | hands_off
user_expertise: [frontend, ux, data-modeling]  # areas user wants input on
user_delegates: [code-review, testing, deployment]  # areas user trusts agent
check_in_frequency: per_epic | per_feature | per_milestone
feedback_mode: working_software | pr_review | both
```

This would let the framework know WHEN to interrupt the user (only for their expertise areas) and when to proceed autonomously. A product visionary with UX expertise gets consulted on UI decisions but not backend architecture; the reverse for a backend expert.

### Gap 3: Taste & Style System (F-0183)
**Severity: HIGH for Mode 2, MEDIUM for Mode 3**

**Current state**: Spec written (`F-0183.md`), not implemented. `review_taste` setting exists in profiles.conf but has no backing implementation.

**What's needed**:
- STACK.md `## Style & taste` section with `style_guide`, `design_system`, `api_style`
- Style context loading into critical agent for taste reviews
- `taste_review.md` prompt template
- This is already spec'd — just needs implementation

### Gap 4: Preview / Running Software Capability
**Severity: HIGH for Mode 2, MEDIUM for Mode 3**

**Current state**: Smoke test checklist exists (manual verification). No automated way to spin up running software for user to interact with.

**What's needed**: An `ag preview` or `ag demo` command that:
- Detects stack from STACK.md (Next.js → `npm run dev`, FastAPI → `uvicorn`, etc.)
- Starts the dev server in background
- Reports URL/access info to user
- Optionally captures screenshots for review
- For Mode 2: this is how the user interacts with the product instead of reading code

**Complexity note**: This is simpler than it sounds — most stacks have a `dev` command. The framework just needs to know how to run it and present the result.

### Gap 5: Feedback Capture from Working Software
**Severity: HIGH for Mode 2**

**Current state**: User gives feedback via chat. Agent manually captures as issues/features. No structured feedback-to-action pipeline.

**What's needed**: After user tests working software via preview:
- Structured feedback format: "what works", "what doesn't", "what's missing"
- Auto-conversion to: bug reports (→ ISSUES.md), feature requests (→ TODO.md/FEATURES.md), acceptance criteria adjustments
- Iteration loop: feedback → prioritize → implement → preview again
- This makes Mode 2 a true design-review loop, not just "approve specs then see result"

### Gap 6: Auto-Commit / Auto-Merge Mode
**Severity: CRITICAL for Mode 3**

**Current state**: Framework ALWAYS requires human approval for commit. `review_merge: human` is the default even in autonomous_formal. There is no mode where the framework can commit and merge without human intervention.

**What's needed**:
- `review_commit: critical_agent | auto` — lets critical agent approve commits
- `review_merge: critical_agent` — lets critical agent approve merges (already in profiles.conf as an option, but the current code always has `human` as the minimum)
- Safety: require all tests pass + critical agent approval + no regressions
- Escape hatch: any escalation → blocks for human

**This is philosophically significant**: the framework's "never auto-commit" rule is core. Mode 3 needs a deliberate override that's clearly opted-into, not a default.

### Gap 7: Discovery-to-Formal Transition with Artifact Preservation
**Severity: MEDIUM for Mode 2**

**Current state**: `enable-formal.sh` creates formal directory structure. But discovery-phase work (journal entries, plans, TODO items, informal decisions) isn't automatically migrated into formal spec structure.

**What's needed**: When transitioning from discovery → formal:
- TODO items → FEATURES.md entries with auto-assigned IDs
- Journal plans → formal plan files
- Informal decisions → ADR stubs
- This makes Mode 2's discovery-then-formalize flow seamless

### Gap 8: Integration Verification Across Features
**Severity: MEDIUM for Mode 3**

**Current state**: Each feature is verified independently. No cross-feature integration test gate for epics.

**What's needed**: When an epic's children are all `verified`:
- Run integration test suite (if defined in epic's acceptance criteria)
- Verify cross-component contracts
- Only then mark epic as `verified`
- This is mentioned in ADR-001 Section 6 but not implemented

### Gap 9: Vision-to-Scheduler Bridge (Replaces "End-to-End Orchestrator")
**Severity: HIGH for Mode 3 (downgraded from CRITICAL — scheduler exists)**

**Current state**: `ag auto epic F-XXXX` already handles the scheduling loop: discovers children, spawns component-scoped workers, manages non-blocking reviews, persists progress, supports pause/resume/stop. The coordination server provides real-time agent management. **The scheduler IS the orchestrator.**

**What's actually missing**: The front-end that feeds the scheduler:
1. Takes a vision prompt → produces an epic with children (Gap 1)
2. Connects the kickoff output to `ag auto epic`
3. Integration verification gate when all children of an epic reach `verified`

**What's needed**: Not a new orchestrator — just an `ag auto "prompt"` variant that:
```
ag auto "Build a task management app with auth, boards, and real-time updates"
  → ag kickoff (vision → epic with children, Gap 1)
  → ag auto epic F-XXXX (EXISTING scheduler handles the rest)
  → integration verification (per epic, Gap 8)
  → preview (spin up for user, Gap 4)
```

This is substantially simpler than originally assessed. The scheduler + coordination server handle 80% of what F-0188 (End-to-End Autonomous Flow) describes. The remaining work is the vision-to-backlog front-end and the integration verification gate.

---

## User Role Selection Matrix

What combinations are possible, and what each requires:

| Aspect | Mode 2 (Visionary) | Mode 1 (Tech Lead) | Mode 3 (Autonomous) |
|---|---|---|---|
| **Profile** | autonomous_formal | formal | autonomous_formal |
| **review_code** | critical_agent | human | critical_agent |
| **review_merge** | human (final acceptance) | human | critical_agent (NEW) |
| **review_taste** | human (user's expertise) | skip or critical_agent | critical_agent |
| **Vision input** | Interview + research | User writes specs | Single prompt |
| **Feedback loop** | Working software | PR review | Automated tests |
| **Backlog control** | User prioritizes | User controls fully | Auto-generated |
| **Commit flow** | Auto (critical agent) | Human approval | Auto (critical agent) |
| **Key gaps** | Gaps 1,2,3,4,5,7 | Minimal | Gaps 1,6,8,9 |
| **Effort to enable** | Large (6-8 features) | Small (polish) | Large (4-5 features) |

### Possible Hybrid: "Guided Autonomous"
A fourth mode worth considering:
- Framework works autonomously per-feature
- User reviews per-EPIC (not per-feature): sees a batch of completed features, tests working software
- Faster than Mode 2 (no per-feature check-in), safer than Mode 3 (human validates chunks)
- Would use: `check_in_frequency: per_epic` + `feedback_mode: working_software`

---

## Priority Recommendations

### Revised after F-0185/F-0186 analysis

The scheduler + coordination server provide the execution engine. The gaps are now concentrated at the **entry point** (vision → backlog) and **edges** (taste, preview, feedback, auto-merge).

### For Mode 2 (Product Visionary) — the most novel and valuable
1. **Gap 1: Vision-to-Backlog Pipeline** (enables the whole flow — THE critical gap)
2. **Gap 3: Taste & Style System** (F-0183, already spec'd, quick win)
3. **Gap 2: User Role Configuration** (so framework knows what to ask about)
4. **Gap 4: Preview Capability** (how user sees results)
5. **Gap 5: Feedback Capture** (closes the iteration loop)

### For Mode 3 (Fully Autonomous) — closer than expected
1. **Gap 1: Vision-to-Backlog Pipeline** (same as Mode 2 — feeds `ag auto epic`)
2. **Gap 6: Auto-Commit/Merge Mode** (removes last human bottleneck)
3. **Gap 8: Integration Verification** (epic-level quality gate)
4. Gap 9 is now mostly solved by the scheduler — just needs the vision front-end (Gap 1)

### Shared foundation (benefits all modes)
- **Gap 1** is the single linchpin — both Mode 2 and Mode 3 need it
- **Gap 3** (F-0183) is already spec'd and a quick win
- The scheduler (`ag auto epic`) is ready to consume whatever Gap 1 produces

---

## Current Pipeline Flow (What Works End-to-End Today)

```
TODAY (Mode 1 - Tech Lead):
  User → writes feature spec manually
       → ag plan F-XXXX (with dialectical review)
       → ag implement F-XXXX (worktree + WIP tracking)
       → agent implements + tests
       → ag commit (human reviews diff)
       → PR created (human reviews PR)
       → human merges
       → ag done F-XXXX (bump version, advance backlog)
       → next feature

WORKS WELL. This is the 90% case.

TODAY (Mode 3 partial — via ag auto epic):
  User → manually creates epic + children in FEATURES.md
       → ag auto epic F-XXXX
       → scheduler discovers children, queries get_unblocked()
       → spawns component-scoped workers for each unblocked feature
       → workers: plan → spec → implement → test → verify → document → commit
       → review checkpoints: critical_agent handles most, human for merge
       → non-blocking: while F-0101 awaits review, F-0102 advances
       → escalations → HUMAN_NEEDED.md
       → supports pause/resume/stop
       → persists progress for resume across sessions

THIS WORKS. The scheduler IS the orchestrator. But the USER must set up the epic + children manually.

DESIRED (Mode 2 - Product Visionary):
  User → provides vision prompt + style preferences + constraints
       → ag kickoff (NEW) → interviews user → generates epics/features/backlog
       → ag auto epic F-XXXX (EXISTING scheduler handles execution)
       → critical agent reviews code & taste (F-0183 needed)
       → ag preview (NEW) → user sees working software
       → user gives feedback → captured as issues/features (NEW)
       → iterate until user accepts
       → ship

GAPS: kickoff, taste system (F-0183), preview, feedback capture, user role config

DESIRED (Mode 3 - Fully Autonomous):
  User → single prompt
       → ag auto "prompt" (NEW front-end for kickoff → scheduler)
       → kickoff produces epic + children
       → ag auto epic handles the rest (EXISTING)
       → review_merge: critical_agent (NEW — currently always human)
       → integration verification (NEW — epic-level gate)
       → deliver working software

GAPS: kickoff front-end, auto-merge mode, integration verification
      (scheduler + coordination server already handle the execution)
```

---

## Verification Plan (How to Test This Analysis)

This is an analysis document, not an implementation. To verify:
1. Walk through each gap with the user to validate priorities
2. Create feature specs (F-XXXX) for each gap the user wants to address
3. Determine implementation order based on dependencies
4. Start with Gap 1 (Vision-to-Backlog) as it unblocks both Mode 2 and Mode 3

---

## Key Architectural Insight

The framework's current architecture is **bottom-up**: individual features are well-managed (spec → plan → implement → review → ship). The gap is **top-down**: there's no way to go from a product vision to a structured backlog of features automatically.

The existing building blocks (decompose, scheduler, critical agent, state machine) are solid. What's missing is the **orchestration layer** that chains them together, and the **user interaction layer** that adapts to different involvement styles.

The three modes (A/B/C) aren't three separate systems — they're the same pipeline with different **checkpoint configurations** and a **vision-to-backlog front-end**. The investment is mostly in:
1. Building the front-end (kickoff/vision pipeline)
2. Adding the preview/feedback loop
3. Allowing configurable autonomy at the commit/merge boundary

---

## DELIVERABLES

Based on user decisions:
- **Kickoff**: Tiered — quick mode (single prompt) + deep mode (interview pipeline)
- **Auto-commit/merge**: Full auto with explicit opt-in (new `review_commit` setting)
- **ADR**: Unified covering all three user-involvement modes

### Deliverable 1: ADR-002 — User Involvement Modes

**File**: `.agentic/spec/adr/ADR-002-user-involvement-modes.md`

**Structure**:

```
# ADR-002: User Involvement Modes

## Summary
Defines three user-involvement modes (Product Visionary, Tech Lead, Fully Autonomous)
as composable configurations over the existing profile + review checkpoint system.

## 1. The Three Modes (ordered by autonomy: least → most)
### 1.1 Mode 1: Tech Lead
  - user_role: tech_lead
  - Autonomy: LOW
  - Characteristic: user controls pace and quality at feature level
  - Reviews plans, PRs, code. Controls backlog. May write specs and code.
  - This is the current framework sweet spot (formal profile)

### 1.2 Mode 2: Product Visionary
  - user_role: visionary
  - Autonomy: MEDIUM
  - Characteristic: user drives WHAT, framework handles HOW
  - Interview-driven kickoff, taste/aesthetic control, preview-based feedback
  - Delegates: code review, testing, implementation, commits
  - Controls: vision, taste, NFRs, architecture decisions (in expertise areas), final acceptance

### 1.3 Mode 3: Fully Autonomous
  - user_role: autonomous
  - Autonomy: HIGH
  - Characteristic: framework does everything from prompt to working software
  - Single-prompt kickoff, all reviews via critical agent, auto-commit/merge
  - User provides: initial prompt + style refs + constraints
  - User receives: working software + report

## 2. Configuration Architecture
### 2.1 Modes as Init Shorthand, Not Meta-Configuration
  - IMPORTANT (from review): The three modes are points on a CONTINUOUS SPECTRUM, not discrete categories
  - During `ag init`, offer mode selection as a convenient way to set initial defaults
  - After init, only INDIVIDUAL SETTINGS matter — no `user_role` setting persisted
  - Users freely override any setting. A user who picks "visionary" but sets `review_merge: critical_agent` is in their own valid configuration
  - This is the SAME pattern as `profile:` — it sets defaults, individual settings override

### 2.2 Mode → Default Settings Mapping (least → most autonomous)
  These are INITIAL DEFAULTS, not locked bundles:
  | Setting | Mode 1 (Tech Lead) | Mode 2 (Visionary) | Mode 3 (Autonomous) |
  |---------|-----------|-----------|------------|
  | profile | formal | autonomous_formal | autonomous_formal |
  | review_commit | human | critical_agent | critical_agent |
  | review_merge | human | human | critical_agent |
  | review_taste | skip | human | critical_agent |
  | kickoff_mode | manual | interview | prompt |
  | feedback_mode | pr_review | working_software | automated |
  | check_in_frequency | per_feature | per_epic | on_escalation |

### 2.3 User Expertise (DEFERRED)
  - Reviewer correctly noted: mapping user expertise to feature transitions is undefined
  - DEFERRED: revisit after real usage patterns emerge from Mode 2 users
  - If needed later: simple per-feature annotation ("I want to review this") rather than expertise taxonomy

## 3. Vision-to-Backlog Pipeline (ag kickoff)

### 3.1 Two Distinct Implementations (from review)
  The reviewer correctly identified these are fundamentally different architectures:

  **Script mode** (`ag kickoff "prompt"`):
  - Non-interactive. Takes prompt + optional --style/--research refs
  - Generates artifacts in STAGING AREA: `.agentic/session/kickoff-draft/`
  - Produces: OVERVIEW.md draft, FEATURES.md entries, acceptance criteria stubs, BACKLOG.json
  - Validates: no ID conflicts, no circular deps, criteria are testable
  - Routes through `review_decomposition` checkpoint
  - On approval: copies from staging to real spec files (like discovery proposals today)
  - Reuses: `ag decompose` (for epic → children), `backlog_helpers.py` (for ordering)

  **Playbook mode** (`ag kickoff --interview` or selected during `ag init`):
  - Interactive multi-turn conversation (like init_playbook.md pattern)
  - Implemented as a PLAYBOOK/SKILL, not a script
  - Phase 1: Vision interview (what, why, who, success criteria)
  - Phase 2: Taste interview (aesthetics, design system, API style)
  - Phase 3: Architecture interview (constraints, NFRs from nfr-catalog.md)
  - Phase 4: Generate to staging area (same output as script mode)
  - Phase 5: User reviews/edits staging artifacts → approve
  - NOTE: Web research NOT included in MVP (requires WebSearch integration, not yet available in automated pipelines)

### 3.2 Staging Area & Validation (from review)
  - All kickoff output goes to `.agentic/session/kickoff-draft/` first
  - Uses `<!-- PROPOSAL -->` markers (same pattern as discovery in init_playbook.md)
  - Validation: feature ID uniqueness, dependency acyclicity, criteria non-empty
  - `ag kickoff --approve` or `ag approve-kickoff` moves to real files
  - Rollback: delete staging directory to discard

### 3.3 Integration with Scheduler
  - After kickoff approval → ag auto epic F-XXXX (existing scheduler)
  - Kickoff is the front-end; scheduler is the execution engine

## 4. New Review Boundary: review_commit
### 4.1 Problem
  - Current: "never auto-commit" is a CONSTITUTIONAL PRINCIPLE baked into 28+ files
  - Appears in: core-rules.md, all agent templates, memory-seed.md, PRINCIPLES.md, git_workflow.md, LLM test 005, NFR catalog, committing-changes skill
  - Mode 3 needs autonomous commit to function

### 4.2 Key Insight (from review): Two Commit Contexts Already Exist
  - **Interactive agent sessions**: "never auto-commit" applies — agent shows diff, waits for human
  - **Automated task execution**: `task.py._commit_ac()` (lines 341-361) ALREADY auto-commits without human review
  - The framework already has an undocumented exception for automated execution
  - Solution: FORMALIZE this distinction rather than changing the constitutional rule

### 4.3 Solution
  - New setting: `review_commit: human | critical_agent`
  - `human` (default): current behavior for interactive sessions
  - `critical_agent`: adversarial review of diff, auto-commits if approved. For automated/scheduler contexts.
  - `review_merge: critical_agent` also now allowed (for Mode 3)
  - The "never auto-commit" rule becomes: "never auto-commit IN INTERACTIVE SESSIONS unless review_commit is explicitly set to critical_agent"
  - Automated execution (scheduler/task.py) continues working as-is

### 4.4 Implementation Scope (from review — this is NOT a small change)
  Files requiring conditional logic for review_commit:
  - `.agentic/lib/agents/shared/guidelines/core-rules.md`
  - All agent templates (CLAUDE.md, cursorrules, copilot, codex, windsurf)
  - `.agentic/lib/init/memory-seed.md`
  - `.agentic/lib/PRINCIPLES.md`
  - `.agentic/lib/workflows/git_workflow.md`
  - LLM regression test `005_no_auto_commit.sh` (make conditional)
  - NFR catalog entry
  - `committing-changes` skill
  - `profiles.conf` (add new setting)

  This is a ~15-file change, not a single setting flip. Must be its own feature with thorough testing.

### 4.5 Safety
  - Formal profile default stays `human`; only autonomous_formal overrides to critical_agent
  - Critical agent evaluates: all tests pass, no secrets in diff, no regressions, ACs met
  - Any escalation → blocks for human
  - Discovery profile: `human` (no auto-commit for lightweight projects)

## 5. Preview & Feedback Loop
### 5.1 ag preview
  - Detects stack from STACK.md → starts dev server
  - Reports URL/access info
  - Optional: captures screenshots for async review

### 5.2 Feedback Capture
  - User tests working software → provides structured feedback
  - Framework captures as: bugs → ISSUES.md, features → TODO.md, acceptance → criteria updates
  - Iteration loop: feedback → reprioritize → implement → preview again

## 6. Open Questions
  - Should user_role be set during init (init_playbook.md) or separately?
  - Should expertise areas auto-detect from user's git history?
  - How does review_commit interact with pre-commit hooks?
  - Should ag preview be part of the scheduler loop (auto-preview after each epic)?

## Consequences
  - Positive: Framework adapts to user's working style, enables true autonomy
  - Negative: More configuration surface, more edge cases
  - Risk: Auto-commit/merge could produce low-quality output if critical agent is weak
```

### Deliverable 2: Feature Specs

**F-0188 overlap resolution** (from review): F-0188 ("End-to-End Autonomous Flow") already covers much of what Gaps 1 and 9 describe. Rather than creating parallel features, we DECOMPOSE F-0188 into children. The new gaps become children of F-0188 where applicable, or standalone features otherwise.

| Feature | Gap | Priority | Dependencies | Relation to F-0188 |
|---------|-----|----------|-------------|-------------------|
| **F-0183: Taste & Style System** | Gap 3 | P1 | Already spec'd | Standalone |
| **F-XXXX: Vision-to-Backlog Pipeline (ag kickoff)** | Gap 1 | P1 | None | Child of F-0188 |
| **F-XXXX: Preview Capability (ag preview)** | Gap 4 | P2 | None | Child of F-0188 |
| **F-XXXX: Auto-Commit/Merge Mode** | Gap 6 | P2 | None | Standalone (~15 file change) |
| **F-XXXX: Epic Integration Verification** | Gap 8 | P2 | F-0186 | Child of F-0188 |
| **F-XXXX: Discovery-to-Formal Migration** | Gap 7 | P3 | ag kickoff | Standalone (check enable-formal.sh + migration.sh first) |
| **F-XXXX: Feedback Capture System** | Gap 5 | P3 (deferred) | Preview + real usage data | Child of F-0188 |
| Init mode selection (not a feature) | Gap 2 | P3 | Most settings exist first | Update to init_playbook.md |

**Implementation order** (from review — capabilities first, configuration later):
1. **F-0183: Taste & Style System** — already spec'd, quick win, no dependencies
2. **F-XXXX: Vision-to-Backlog Pipeline (ag kickoff)** — THE linchpin. Feeds `ag auto epic`.
3. **F-XXXX: Preview Capability** — enables feedback loop, MVP scoped to single-process stacks
4. **F-XXXX: Auto-Commit/Merge Mode** — significant (~15 files), formalizes existing task.py exception
5. **F-XXXX: Epic Integration Verification** — quality gate for epics with multiple children
6. **Init mode selection** — update init_playbook.md with mode shortcuts after settings exist
7. **F-XXXX: Discovery-to-Formal Migration** — assess enable-formal.sh + migration.sh first
8. **F-XXXX: Feedback Capture** — DEFERRED until preview generates real usage patterns

**Rationale for reorder** (reviewer caught this): Previous order put user role config first and vision-to-backlog at position 4, despite vision-to-backlog being "THE linchpin." User role config is just init_playbook.md changes — it doesn't require new infrastructure. Build capabilities first, wire up the init shortcuts after.

### Deliverable 3: Updated plan file analysis (this document)

Already done — reflects F-0185/F-0186 reality, user decisions on scope.

---

## Verification

To verify the analysis and deliverables:
1. **ADR**: Review with user for architectural correctness
2. **Feature specs**: Create F-XXXX entries in FEATURES.md with acceptance criteria
3. **Backlog**: Add new features to BACKLOG.json in priority order
4. **Smoke test**: Walk through each mode's desired flow and verify which steps work vs block
5. **Framework validation**: `bash tests/validate_framework.sh` passes after ADR + specs added

---

## Reviewer Issues Addressed

Fresh adversarial review produced 12 issues. Here's how each was resolved:

| # | Severity | Issue | Resolution |
|---|----------|-------|------------|
| 1 | HIGH | Modes are a spectrum, not taxonomy | Fixed: modes are init shortcuts, not persisted settings. Section 2.1 rewritten. |
| 2 | CRITICAL | Implementation order contradicts dependency analysis | Fixed: vision-to-backlog moved to position 2, user role config moved to position 6. |
| 3 | CRITICAL | Auto-commit touches 28+ files, not "a setting" | Fixed: Section 4 rewritten acknowledging scope, task.py exception, ~15 file change. |
| 4 | HIGH | Kickoff interview mode underspecified | Fixed: split into script (non-interactive) + playbook (multi-turn). Web research deferred. |
| 5 | MEDIUM | Preview complexity dismissed | Fixed: acknowledged in Gap 4 description. MVP scoped to single-process stacks. |
| 6 | HIGH | F-0188 overlap creates duplicate tracking | Fixed: new features become CHILDREN of F-0188 where applicable. |
| 7 | MEDIUM | Discovery-to-formal ignores enable-formal.sh | Fixed: implementation order notes "assess enable-formal.sh + migration.sh first." |
| 8 | MEDIUM | Feedback capture premature | Fixed: demoted to P3, deferred until preview generates real patterns. |
| 9 | MEDIUM | user_expertise impractical | Fixed: deferred from ADR. Revisit after real Mode 2 usage. |
| 10 | LOW | Mode A/B/C vs 1/2/3 naming inconsistency | Fixed: standardized on 1/2/3 throughout. |
| 11 | LOW | Completion percentages unjustified | Fixed: removed percentages, replaced with qualitative descriptions. |
| 12 | HIGH | Missing kickoff validation / bad output handling | Fixed: staging area (.agentic/session/kickoff-draft/) with PROPOSAL markers added to Section 3.2. |
