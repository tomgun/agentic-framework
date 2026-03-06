# Research Report: Spec-Driven Development Toolkit Analysis

**Date**: 2026-03-01
**Purpose**: Evaluate a prominent open-source SDD (Spec-Driven Development) toolkit and extract actionable insights for our agentic framework.

---

## 1. Executive Summary

I studied a prominent open-source SDD toolkit that positions specifications as **executable blueprints** — the primary artifact that generates working code. It supports 20+ AI coding agents through a unified slash-command interface and a modular extension system.

**Bottom line**: The two systems have complementary strengths. Their toolkit excels at **spec quality** (structured clarification, consistency analysis, requirement meta-validation). Our framework excels at **execution safety** (structural gates, session continuity, WIP tracking, migration audit trails). Both rely on a mix of deterministic and behavioral enforcement — the difference is emphasis, not kind.

**Top actionable insights** (in priority order):
1. **Structured clarification + quality validation** for spec-writing (their strongest innovation — resurfacing a capability we had early in the project)
2. **Upgrade-safe user-extension directory** (critical for adoption — `.agentic/` gets replaced; was already on our task list)
3. **Spec format evolution** — priority tags on AC groups, Behavior section, "verify independently" per group
4. **Execution order + parallelization markers** — [P] markers in plans for multi-agent dispatch

**Out of scope for this plan** (separate future work):
- **Verification loop** (test→fix→retest) — our own idea, not from the toolkit
- **Auto-dev loop** — depends on verification loop

---

## 2. Architecture Comparison

| Dimension | Studied Toolkit | Our Framework |
|-----------|----------------|---------------|
| **Core metaphor** | Specs generate code (one-shot pipeline) | Specs generate code (iterative TDD: spec → criteria → tests → impl → evolve) |
| **Three layers** | Constitution → Commands → Artifacts | Constitution → Playbooks → State |
| **Spec format** | User stories + FRs + success criteria | Feature specs (FEATURES.md with rich metadata) + acceptance files (AC-###) + NFR.md. ACs are more precise and testable than user stories; the new Behavior section provides the user-story benefit (technology-agnostic "why") without replacing ACs. |
| **Plan format** | Research + data model + contracts | Free-form markdown stored in `.agentic-journal/plans/`. Common sections include problem, approach, files to modify, and risks — but format is not mandated. |
| **Task breakdown** | Explicit T### IDs, [P] parallel markers, user-story grouping | Implicit via AC checkboxes, no formal task IDs |
| **Quality gates** | Template-based (LLM constraint), checklist-before-implement | Script-based (exit 1 blocks) + behavioral, pre-commit hooks |
| **Enforcement mix** | Mostly behavioral (prompt instructions) | Mixed: structural (bash scripts) for commits, behavioral for safety rules (anti-hallucination, no auto-commit) |
| **Multi-agent** | 20+ agents via command format translation | 4 instruction-file agents + 30 subagent roles + multi-agent orchestration (AGENTS_ACTIVE.md, worktrees, feature pipelines, context injection via `context-for-role.sh`) |
| **Extension system** | Full plugin architecture (manifests, catalogs, hooks) | Skills system (12 skills, template-generated). User-extension directory (`.agentic-local/extensions/`) now supports custom skills, gates, hooks, and rules that survive framework upgrades. |
| **Session continuity** | None (stateless between sessions) | Full (STATUS.md, WIP.md, JOURNAL.md, session-start) |
| **Governance** | Immutable constitution with amendment process | PRINCIPLES.md with derivation DAG |

**Key difference in philosophy**: The toolkit is **generative** (specs → code), our framework is **protective** (specs gate what code is allowed). Both are spec-first, but the emphasis differs.

---

## 3. What We Can Learn (Ideas Worth Stealing)

### 3.1 Structured Clarification Workflow (HIGH VALUE — resurfacing existing capability)

**What they do**: A dedicated `/clarify` command with a 9-category ambiguity taxonomy:
1. Functional Scope & Behavior
2. Domain & Data Model
3. Interaction & UX Flow
4. Non-Functional Quality Attributes
5. Integration & External Dependencies
6. Edge Cases & Failure Handling
7. Constraints & Tradeoffs
8. Terminology & Consistency
9. Completion Signals

Each question is multiple-choice (2-5 options) with a recommended answer and reasoning. Max 5 questions per session. Answers are recorded incrementally into the spec's "Clarifications" section.

**Why it matters for us**: We currently rely on ad-hoc `AskUserQuestion` calls during planning. A structured clarification pass with a taxonomy would:
- Catch gaps earlier (before plan mode)
- Make specs more complete before implementation starts
- Reduce mid-implementation surprises
- Give users a predictable, low-effort way to fill in gaps

**How to apply**: Our framework already has spec clarification capability (currently buried/not prominent). Resurface it in the `writing-specs` skill and enhance with the studied toolkit's structured taxonomy approach. After generating initial acceptance criteria, run a coverage scan against the taxonomy. Present gaps as multiple-choice questions. Record answers as `[Clarified]` markers in the acceptance file.

---

### 3.2 Cross-Artifact Consistency Analysis (HIGH VALUE)

**What they do**: A `/analyze` command that runs 6 detection passes across all spec artifacts:
1. **Duplication** — near-duplicate requirements
2. **Ambiguity** — vague adjectives without metrics ("fast", "scalable")
3. **Underspecification** — requirements missing object or measurable outcome
4. **Constitution alignment** — conflicts with project MUST principles
5. **Coverage gaps** — requirements with zero tasks; tasks with no requirement
6. **Inconsistency** — terminology drift, data mismatches

Findings are severity-rated (CRITICAL/HIGH/MEDIUM/LOW) with line-number references.

**Why it matters for us**: Our `check-spec-health.sh` validates structure (file exists, format correct) but not **semantic** consistency. We don't catch:
- ACs that contradict each other
- NFRs that are vague ("should be fast")
- Features with ACs that don't map to any test
- Terminology drift across spec files

**How to apply**: Add a `spec-analyze` tool or extend `check-spec-health.sh` with LLM-powered semantic checks. Run automatically before `ag implement` as a soft gate (warn, don't block). Key checks: AC↔test coverage mapping, NFR measurability audit, cross-feature terminology consistency.

---

### 3.3 "Checklists as Unit Tests for English" (MEDIUM-HIGH VALUE)

**What they do**: Their checklist command validates **requirement writing quality**, not implementation correctness. It asks questions like:
- "Are the number and layout of featured episodes specified?" (Completeness)
- "Is 'prominent display' quantified with specific sizing/positioning?" (Clarity)
- "Are hover state requirements consistent across all interactive elements?" (Consistency)

This is distinct from acceptance testing — it tests **whether the spec itself is well-written**.

**Why it matters for us**: Our acceptance criteria template has good structure but no meta-validation. We validate that ACs exist and are formatted correctly, but not that they're **clear, complete, and testable**. A spec-quality checklist would catch problems like:
- ACs that are implementation-specific rather than behavior-focused
- Missing edge case coverage
- Unmeasurable success criteria

**How to apply**: Add a `spec-quality-check` phase to `writing-specs` skill. After ACs are written, generate a checklist that validates the ACs themselves. Could be 8 dimensions: Completeness, Clarity, Consistency, Acceptance Quality, Scenario Coverage, Edge Cases, NFR Coverage, Dependencies.

---

### 3.4 Constitution as Explicit Governance Document (MEDIUM VALUE)

**What they do**: A formal constitution with numbered articles, amendment process, versioning, and ratification dates. Constitutional gates block progress during planning if principles are violated. Example articles: 
- Article III: Test-First (non-negotiable TDD)
- Article VII: Simplicity (max 3 projects)
- Article VIII: Anti-abstraction

**What we already have**: PRINCIPLES.md with 13 principles organized as Foundation → Design → Operational, plus a derivation DAG. This is actually **more sophisticated** in terms of traceability (every rule traces to a foundation principle).

**Where they're ahead**: Their constitution has **explicit gates in the planning workflow**. A plan cannot proceed if it violates a constitutional article. Violations must be documented with justification. Our principles are instruction-based (behavioral) rather than gate-based (structural).

**How to apply**: Note — this applies to framework development itself only, not to user projects. PRINCIPLES.md is framework-internal governance. User projects have their own governance (or none). A principles compliance gate would be framework-dev specific and is not a general feature to implement.

---

### 3.5 Formal Task Breakdown with Parallelization Markers (MEDIUM VALUE)

**What they do**: Explicit task IDs (T001-T999), parallel markers [P], user-story grouping [US1], dependency chains, phased execution (Setup → Foundational → Stories → Polish). Each task has an exact file path. The [P] parallel markers are directly useful for multi-agent dispatch — parallelizable ACs can be assigned to different agents.

**What we have**: Acceptance criteria serve as our task list (AC-001 through AC-NNN), but they describe **outcomes**, not **steps**. No explicit parallelization markers. No dependency chains between ACs.

**The gap**: For complex features, our AC-based approach can leave the agent unclear on execution order. Which AC to tackle first? Which can be done in parallel? What are the blocking dependencies?

**How to apply**: For features with >5 ACs, add a "Task Order" section to the plan file that maps ACs to execution phases: `Phase 1 (foundation): AC-001, AC-002 | Phase 2 (parallel): AC-003 [P], AC-004 [P] | Phase 3 (integration): AC-005`. This keeps ACs as the source of truth but adds execution guidance.

---

### 3.6 Multi-Agent Format Translation (LOW-MEDIUM VALUE)

**What they do**: A single command template gets translated into 20+ agent-specific formats:
- Markdown with YAML frontmatter (Claude, Cursor, Copilot)
- TOML (Gemini, Qwen)
- Different directory conventions per agent

**What we have**: 4 agent instruction files (CLAUDE.md, .cursorrules, copilot-instructions.md, codex-instructions.md) generated from templates via `setup-agent.sh`. Our skills system is Claude Code-specific. Contents are currently similar across tools, but tool-specific instructions may diverge as each tool's capabilities grow.

**The gap**: Our multi-agent support is functional but not automated. Adding a new agent means manually creating an instruction file. The studied toolkit automates this with a config-driven approach.

**How to apply**: Consider a `generate-agent-instructions.sh` that takes our canonical `.agentic/` templates and generates agent-specific files. Lower priority — we only support 4 agents and they don't change often. But the pattern is worth noting if we expand agent support.

---

### 3.7 Extension/Plugin Architecture (LOW VALUE for now)

**What they do**: Full plugin system with manifests, catalogs (org + community), lifecycle hooks, versioned compatibility, config layering (defaults → project → local → env vars).

**What we have**: Skills system (12 skills) that are generated from templates. No third-party extension mechanism.

**Assessment**: A public plugin system is over-engineered for our current stage. However, project-level extension (custom skills, gates, rules that survive upgrades) is a confirmed need from production projects. Implemented as `.agentic-local/extensions/` in F-0148 — a lightweight approach that reuses existing formats without introducing plugin infrastructure.

---

## 4. SWOT Analysis

### Strengths (of the studied toolkit relative to us)

| Strength | Impact | Our Gap |
|----------|--------|---------|
| **20+ agent support** | Massive adoption surface | We support 4 agents |
| **Clarification taxonomy** | Catches spec gaps systematically | We rely on ad-hoc questions |
| **Consistency analysis** | Finds contradictions across artifacts | We only check structure, not semantics |
| **Spec-quality checklists** | Meta-validates requirement writing | We validate format, not quality |
| **Formal task breakdown** | Clear execution order with parallelism | Our ACs describe outcomes, not steps |
| **Extension ecosystem** | Community can add workflows | Our skills are framework-internal |

### Weaknesses (of the studied toolkit relative to us)

| Weakness | Impact | Our Advantage | Nuance |
|----------|--------|---------------|--------|
| **No session continuity** | Every session starts cold | STATUS.md, JOURNAL.md, WIP.md | But: their stateless model avoids stale-state bugs |
| **No commit-time enforcement** | No pre-commit validation | 16-check pre-commit script | Fair comparison — our safety rules (R1, R2) are also behavioral |
| **No WIP tracking** | Can start multiple features | WIP.md lock prevents multi-feature chaos | |
| **No journal/history** | No learning across sessions | JOURNAL.md captures lessons | But: simpler onboarding without state files |
| **No NFR tracking** | Non-functional requirements are informal | NFR.md with IDs, enforcement, measurement | |
| **No commit quality gates** | No pre-commit validation | 16-check pre-commit script | |
| **No dogfooding** | Doesn't use itself to develop | Framework develops using its own patterns | |

### Opportunities (what we could gain by adopting ideas)

| Opportunity | Effort | Value | Priority | Token Cost |
|-------------|--------|-------|----------|------------|
| Clarification + quality validation for spec-writing (merged R1/R3) | Small | High | P1 | ~2K tokens per spec (one LLM pass) |
| Semantic consistency analysis | Medium | High | P1 | ~5-10K tokens per analysis (reads all spec artifacts) |
| **User-extension directory** (upgrade-safe customization) | Medium | High | P2 | Zero (structural change) |
| Spec format evolution (priority tags, verify-independently) | Small | Medium | P2 | Zero (template change) |
| Execution order in plans + checkpoint validation | Small | Medium | P3 | Zero (workflow change) |
| AC-level coverage tracking | Medium | Medium | P3 | ~3K tokens per feature (LLM maps tests→ACs) |
| Verification loop (test→fix→retest) | Large | Very High | P2* | High: ~10-50K tokens per loop (multiple fix cycles) |

*R10 (verification loop) is NOT from the studied toolkit — it's an opportunity gap we identified. They're explicitly human-in-the-loop. Marked P2 because it depends on proving feasibility first.

### Threats (risks of adopting or not adopting)

| Threat | If we adopt | If we don't |
|--------|------------|-------------|
| **Over-engineering** | Risk adding complexity without proportional value | No risk |
| **Template bloat** | More templates = more maintenance | Keep it simple |
| **Adoption competition** | N/A | Other frameworks may offer features users expect |
| **Semantic analysis reliability** | LLM-based checks can be inconsistent | Miss real consistency issues |
| **Multi-agent drift** | More agents = more maintenance surface | Users on unsupported agents can't use framework |

---

## 5. Recommendation Details

> Consolidated priority table with token costs, effort, and phasing is in **§12**.

**R1. Resurface + Enhance Spec Clarification** (existing capability buried in framework; enhance with studied toolkit's patterns)
- In `writing-specs` skill: after initial AC generation, run a single LLM pass that combines:
  - Coverage scan against 6-category taxonomy (functional, data model, edge cases, NFRs, integrations, completion signals)
  - Quality check: "Are ACs behavior-focused? Measurable? Edge cases covered?"
- Present max 5 questions as multiple-choice with recommended answers
- Record answers as `[Clarified]` items in acceptance file
- Files: `.claude/skills/writing-specs/SKILL.md`, `.agentic/spec/acceptance.template.md`

**R2. Semantic Consistency Analysis**
- New tool: `.agentic/tools/spec-analyze.sh` (wraps LLM call)
- Start with 3 checks only: ambiguity detection, AC↔test coverage gaps, NFR measurability
- Run as advisory gate before `ag implement` (warn, don't block)
- Must be skippable for offline/air-gapped development
- Files: new script + integration into `implementing-features` skill
- See §12 Feasibility Notes for latency, false positive, and offline concerns

**R3. User-Extension Directory** — see §7 for full design

**R4. Spec Format Evolution** — see §8 for template changes

**R5. Verification Loop** — see §11 for design and risk assessment

*(What NOT to adopt: see §12)*

---

## 6. Key Architectural Insight

The systems differ not in kind but in **emphasis** of enforcement:

- **Their approach**: Almost entirely behavioral — templates constrain LLM behavior. If the LLM ignores a template, nothing structurally breaks. Upside: works with any LLM that can follow instructions. Downside: no safety net.
- **Our approach**: Mixed — structural gates (pre-commit hooks, `exit 1`) for commit-time rules, but behavioral enforcement for our most critical safety rules (R1 Anti-Hallucination, R2 No Auto-Commits). We're more reliable at commit time, but our pre-commit rules are actually behavioral too.

**Honest assessment**: We're not as "deterministic" as we sometimes claim. Our structural enforcement is strong for what it covers (commit quality, file limits, feature tracking), but it doesn't cover our most important safety invariants. Those remain prompt-based, just like the studied toolkit.

**Their stateless design also has genuine advantages** we shouldn't dismiss: no stale state, no state corruption, simpler mental model, easier onboarding. Our session state (STATUS.md, WIP.md, JOURNAL.md) is powerful but also a maintenance surface — state files can drift, get stale, or confuse new users.

**The synthesis**: Keep structural enforcement for commit-time rules. Add their advisory checks (clarification, consistency) as soft gates. And honestly evaluate whether some of our state files earn their keep or just add complexity.

---

## 7. The User-Space Customization Problem (Revised Assessment)

My initial report dismissed the extension/plugin architecture as over-engineered. After considering the upgrade dynamics, I'm revising that assessment. The core problem:

> `.agentic/` is framework-owned and gets **completely replaced** on upgrade. Users who want to customize agent behavior, add new skills, or modify workflows have limited options that survive upgrades.

### Current Extension Points (and their limits)

| Mechanism | Survives Upgrade | What It Allows | Limitation |
|-----------|-----------------|----------------|------------|
| `subagents-project/` injection | Yes | Add rules to existing skills | Can't create new skills or workflows |
| Custom skills (no `author: agentic-framework`) | Yes | Full new skills in `.claude/skills/` | Undocumented, Claude Code-specific, no lifecycle hooks |
| STACK.md settings | Yes | Toggle features, set thresholds | Limited to predefined settings |
| Root CLAUDE.md | Fragile (regenerated) | Extend instruction file | Can be overwritten by `setup-agent.sh` |

**The gap**: There's no formal, documented, upgrade-safe mechanism for users to:
- Add entirely new workflow skills
- Modify existing workflow behavior beyond rule injection
- Add custom quality gates or pre-commit checks
- Integrate project-specific tools (linters, deploy scripts)
- Share customizations across projects in an org

### What the Studied Toolkit Offers Here

Their extension system solves this with:
1. **Extension manifests** (`extension.yml`) — declarative description of what the extension provides
2. **User-owned directory** (`.specify/extensions/`) — separate from framework code
3. **Lifecycle hooks** (`after_tasks`, `after_implement`) — inject behavior at defined points
4. **Config layering** (defaults → project → local → env vars) — flexible configuration
5. **Catalog system** — discover and share extensions

This is more than we need, but the **core idea** — a user-owned extension directory with a contract — is exactly right.

### Proposed Approach for Our Framework

**Option A: Lightweight User Extensions (Recommended)**

Create a user-owned directory that survives upgrades and integrates with the skill/gate system:

```
project-root/
├── .agentic/                     # Framework-owned, replaced on upgrade
├── .agentic-extensions/          # User-owned, preserved on upgrade
│   ├── skills/                   # Custom skills (same format as .agentic skills)
│   │   └── deploy-to-staging/
│   │       ├── SKILL.md
│   │       └── scripts/
│   ├── gates/                    # Custom quality gates (bash scripts, exit 1 = block)
│   │   └── check-api-contracts.sh
│   ├── hooks/                    # Custom pre/post hooks
│   │   └── after-implement.sh
│   └── rules/                    # Rule injection files (replaces subagents-project/)
│       └── implementation-rules.md
```

**Key design decisions**:
- Same formats as framework (SKILL.md, bash gates) — no new concepts to learn
- `generate-skills.sh` scans both `.agentic/agents/claude/skills/` AND `.agentic-extensions/skills/`
- `pre-commit-check.sh` runs both framework gates AND `.agentic-extensions/gates/`
- `upgrade.sh` explicitly preserves `.agentic-extensions/`
- No manifest/catalog system needed yet — just directories and conventions

**Option B: Full Extension Architecture (Like the studied toolkit)**

Manifests, catalogs, versioned compatibility, hook registration. More formal, more maintainable at scale, but significantly more complexity. Worth it only if:
- We have multiple orgs sharing extensions
- Extension compatibility across framework versions is a real problem
- We need a discovery/marketplace mechanism

**Option C: Status Quo with Better Documentation**

Document the existing `subagents-project/` and custom-skill mechanisms. Add more injection points to cover common customization needs. Lowest effort, but doesn't solve the fundamental problem of limited customization surface.

### Revised Priority

| Opportunity | Effort | Value | Priority |
|-------------|--------|-------|----------|
| User extension directory (Option A) | Medium | **High** | **P2** (was P5) |
| Extension manifest system (Option B) | Large | Medium | P4 |

The priority bump is because this isn't just a nice-to-have — it's an **upgrade-safety** and **adoption** concern. Users who can't safely customize will either:
1. Edit `.agentic/` directly (breaks on upgrade)
2. Fork the framework (loses upgrade path)
3. Give up on customization (limits adoption)

---

## 8. Deep Dive: Spec Format & Storage

### What the Studied Toolkit Does

Each feature gets its own **directory** with a pipeline of generated artifacts:

```
specs/001-user-auth/
├── spec.md          # WHAT: user stories (P1/P2/P3), FRs, success criteria
├── plan.md          # HOW: technical context, constitution check, project structure
├── research.md      # UNKNOWNS: technology research findings
├── data-model.md    # ENTITIES: models, relationships, validation rules
├── quickstart.md    # SMOKE TEST: key validation scenarios
├── contracts/       # INTERFACES: API specs, schemas, CLI commands
│   └── api-spec.json
├── checklists/
│   └── requirements.md  # META-VALIDATION: is the spec itself well-written?
└── tasks.md         # EXECUTION: phased task breakdown with dependencies
```

**Spec format** (`spec.md`) has three mandatory sections:
1. **User Scenarios & Testing** — P1/P2/P3 priority stories with Given/When/Then acceptance scenarios and independent test descriptions
2. **Requirements** — FR-001/FR-002 with MUST/SHOULD language, key entities with attributes
3. **Success Criteria** — SC-001/SC-002 with technology-agnostic measurable outcomes

**Key format decisions**:
- User stories have **explicit priority AND value justification** ("Why P1: core monetization flow")
- Each story has an **independent test** description — "can be validated alone without other stories"
- Requirements use RFC-style MUST/SHOULD/MAY language
- Success criteria are forbidden from mentioning technology ("users complete checkout in <3 min" not "API returns 200 in <200ms")
- Max 3 `[NEEDS CLARIFICATION]` markers per spec — forces decision-making, prevents indefinite ambiguity

### What We Currently Do

Feature specs live in two places:
- `spec/FEATURES.md` — centralized registry with rich metadata (25+ fields per feature)
- `spec/acceptance/F-####.md` — per-feature acceptance criteria (grouped AC-### checkboxes)

**Our acceptance file format**:
```markdown
# F-0001: Feature Name
Tests: [unit/integration/behavioral test descriptions]
## Acceptance Criteria
### Core Behavior
- [ ] **AC-001**: [criterion]
- [ ] **AC-002**: [criterion]
### Edge Cases
- [ ] **AC-003**: [criterion]
## NFR Compliance
## Out of Scope
```

### What We Could Learn

**Insight 1: Our specs lack the "WHAT vs HOW" separation** (adopted — implemented as Behavior section in F-0148)

The toolkit enforces a hard boundary: `spec.md` (WHAT the user needs) is **technology-agnostic**. `plan.md` (HOW to build it) is where technology enters. Our acceptance criteria often mix both — an AC might say "CLI command `ag todo` writes to TODO.md" which blends behavior with implementation.

**Recommendation**: Consider splitting acceptance files into two sections:
- **Behavior** (technology-agnostic): "User can capture ideas for later without interrupting current work"
- **Verification** (implementation-specific): "Running `ag todo 'idea'` appends to TODO.md"

This makes specs more durable — the behavior survives refactors, even if the CLI interface changes.

**Insight 2: Priority + value justification on acceptance criteria**

The toolkit's P1/P2/P3 priority per user story, with a **why** for each priority, is elegant. It answers: "If we can only ship half this feature, which half matters?" Our ACs have no priority — they're implicitly all-or-nothing.

**Recommendation**: Add optional priority tags to AC groups:
```markdown
### Core Behavior (P1 — MVP, required for feature to be useful)
- [ ] **AC-001**: ...
### Enhanced UX (P2 — improves experience but feature works without it)
- [ ] **AC-004**: ...
```

This enables incremental delivery and helps agents decide execution order.

**Insight 3: Independent testability per story/group**

Each user story in the toolkit has an "Independent Test" field — a description of how to verify that story works **in isolation**. This is powerful for parallel development and MVP delivery.

**Recommendation**: Add an "Independent Test" line per AC group:
```markdown
### Core Behavior (P1)
**Verify independently**: Run `ag todo "test"` and confirm entry appears in TODO.md
- [ ] **AC-001**: ...
```

**Other patterns considered but skipped**:
- *Success criteria vs acceptance criteria*: They separate measurable outcomes (SC-###) from testable conditions (AC-###). For developer tooling, our ACs already serve both purposes. Skip.
- *Directory-per-feature vs flat files*: Their `specs/001-feature-name/` directories make sense when features have 5-7 artifacts. Our flat `spec/acceptance/F-####.md` with a centralized registry scales better at 100+ features. Keep flat, but consider hybrid if we add per-feature artifacts (clarification logs, analysis reports) later.

### Concrete Format Improvement Proposal

Evolve acceptance template from:
```markdown
# F-####: Name
## Tests
## Acceptance Criteria
### Group
- [ ] **AC-001**: criterion
## NFR Compliance
## Out of Scope
```

To:
```markdown
# F-####: Name

## Behavior (what the user needs — technology-agnostic)
Brief description of the user's goal and why it matters.

## Acceptance Criteria

### Core Behavior (P1 — MVP)
**Verify independently**: [how to test this group alone]
- [ ] **AC-001**: [criterion]
- [ ] **AC-002**: [criterion]

### Enhanced Experience (P2 — better but optional)
**Verify independently**: [how to test this group alone]
- [ ] **AC-003**: [criterion]

### Edge Cases
- [ ] **AC-004**: [criterion]

## Verification
### Tests
- Unit: [file → what it tests]
- Integration: [scenario]

## NFR Compliance
## Out of Scope
```

Changes from current format:
1. Added **Behavior** section (technology-agnostic intent)
2. Added **priority tags** to AC groups (P1/P2)
3. Added **"Verify independently"** per group
4. Moved Tests under Verification (clearer hierarchy)
5. Kept everything else the same (backward compatible)

---

## 9. Deep Dive: Task Decomposition & Execution Order

### What the Studied Toolkit Does

Their task breakdown (`tasks.md`) is highly structured. Note: phased execution may be a better expression of D4 (Small Batch) than file-count limits — tracked as a design insight for future consideration.

```markdown
# Tasks: User Authentication

## Phase 1: Setup (Shared Infrastructure)
- [ ] T001 Create project structure per plan
- [ ] T002 Initialize Python project with FastAPI
- [ ] T003 [P] Configure linting tools

## Phase 2: Foundational (Blocking Prerequisites)
⚠️ NO user story work until Phase 2 complete
- [ ] T004 Setup database schema
- [ ] T005 [P] Implement auth middleware
- [ ] T006 [P] Create base test fixtures

## Phase 3: User Story 1 — Login (P1)
**Independent Test**: User can log in and receive a token
- [ ] T010 [P] [US1] Write contract test for POST /auth/login
- [ ] T011 [P] [US1] Create User model (src/models/user.py)
- [ ] T012 [US1] Implement login service (depends on T011)
- [ ] T013 [US1] Create login endpoint (depends on T012)
- [ ] T014 [US1] Integration test: full login flow
✅ CHECKPOINT: Login works independently

## Phase 4: User Story 2 — Registration (P2)
...

## Dependencies & Execution Order
- Phase 1: No dependencies (run first)
- Phase 2: Depends on Phase 1 (BLOCKS all stories)
- Phase 3+: All depend on Phase 2; stories are independent of each other
```

**Key patterns**:
- **[P] markers** identify tasks that can run in parallel (different files, no data dependencies)
- **[US1]/[US2] labels** link tasks to user stories for traceability
- **Explicit dependency chains**: "depends on T011" in description
- **Checkpoints** after each story: pause and validate before proceeding
- **Phase structure**: Setup → Foundation (blocking) → Stories (independent) → Polish
- **File paths in every task**: "Create User model (src/models/user.py)"

### What We Currently Do

Our task decomposition is **implicit** — acceptance criteria serve as the task list:
```markdown
### Core Behavior
- [ ] **AC-001**: ag todo command captures text to TODO.md
- [ ] **AC-002**: TODO.md entries have timestamps
```

Agents decide execution order based on their understanding of the ACs. There's no explicit phasing, parallelization markers, or dependency tracking between ACs. The `TASK.template.md` exists but is rarely used — most features go straight from acceptance criteria to implementation.

### Gap Analysis

| Aspect | Toolkit | Us | Gap Severity |
|--------|---------|-----|-------------|
| Execution order | Explicit phases | Agent decides | Medium — works for small features, breaks for complex ones |
| Parallelization | [P] markers | None | Low — single-agent usually, but matters for multi-agent |
| Dependencies | "depends on T011" | Implicit | Medium — agent may start with wrong AC |
| Checkpoints | After each story | After all ACs | Medium — no incremental validation |
| File paths | In every task | In plan (if exists) | Low — agent finds files anyway |
| Task IDs | T001-T999 | AC-001-AC-999 | None — our AC IDs serve same purpose |

### What We Should Adopt

**Recommendation A: Add "Execution Order" to plans for complex features (>5 ACs)**

Don't change the acceptance file. Instead, add an execution order section to the plan:

```markdown
## Execution Order

### Phase 1: Foundation (do first, blocks everything)
- AC-001, AC-002 (project setup, base infrastructure)

### Phase 2: Core Behavior (P1 — MVP)
- AC-003 [P], AC-004 [P] (independent, can parallelize)
- AC-005 (depends on AC-003 + AC-004)
✅ CHECKPOINT: Core feature works

### Phase 3: Enhanced (P2)
- AC-006, AC-007

### Phase 4: Edge Cases
- AC-008, AC-009, AC-010
```

This is lightweight (a section in an existing document) and keeps ACs as source of truth.

**Recommendation B: Add checkpoint validation to implementing-features skill**

After completing each P1 AC group, pause and validate before proceeding to P2. Add to the skill:

```
After completing all P1 acceptance criteria:
1. Run relevant tests
2. Do a quick smoke test (manual or automated)
3. Report status to user: "P1 complete — core feature works. Proceed to P2?"
```

This is the toolkit's checkpoint pattern, adapted to our skill-based workflow.

**Recommendation C: Add [P] markers when creating plans (optional)**

When the plan has an execution order section, mark ACs that can be worked in parallel:
```
- AC-003 [P], AC-004 [P]  ← different files, no dependency
```

This is primarily useful for multi-agent scenarios (which we support but rarely use). Low priority unless multi-agent adoption increases.

**Recommendation D: Skip formal T### task IDs**

Our AC-### IDs already serve the same purpose. Adding a separate T### layer would create redundancy and maintenance overhead. The toolkit needs T### because their specs don't have AC-### — their user stories are narrative, not checkboxed criteria.

### What NOT to Adopt from Their Task System

| Pattern | Why Skip |
|---------|----------|
| **Separate tasks.md file** | Redundant with our acceptance files. ACs are already our task list. However, execution order and parallelization tracking within plans is valuable — implemented as [P] markers and phased execution in F-0148. Foundation for future auto-dev loops. |
| **T### IDs separate from AC###** | Double-tracking creates drift. One ID system is better. |
| **User story labels [US1]** | Our AC groups already serve this purpose (### Core Behavior, ### Edge Cases). |
| **File paths in every task** | Over-specified. Agents find files. Plans already list key files. |
| **Implementation strategy section** (MVP First, Incremental, Parallel Team) | Our "one feature at a time, small batch" principle already handles this. |

---

## 10. Deep Dive: Spec Migration & Traceability Guarantees

### Spec Migration: Different Maturity Levels

The studied toolkit has no formal spec migration system — specs live in git and are the user's responsibility. Their upgrade process protects the `specs/` directory from overwrites, but offers no audit trail, no shipped-spec protection, no rollback plans. Their constitution file can even be overwritten on upgrade (acknowledged known issue).

Our framework has a more mature migration system: migration files with context and rollback plans, pre-commit checks that structurally block shipped spec modifications, `[Discovered]`/`[Revised]`/`[Future]` markers, and status downgrade protection.

**Assessment**: Our migration system is more sophisticated. However, their simpler approach (just git) has lower cognitive overhead. The question is whether our migration ceremony earns its cost — for a framework used by small teams, it likely does; for rapid prototyping, it may be friction.

### Spec → Test → Code Traceability: Both Have Gaps

**How the studied toolkit handles traceability**:
- User stories (P1/P2/P3) → Tasks (T### with [US1] labels) → File paths in task descriptions
- Tests are **optional** in task generation (only if explicitly requested)
- The `/analyze` command checks **coverage gaps** (requirements with zero tasks, tasks with no requirements)
- But: no automated verification that test assertions actually match acceptance criteria
- Traceability is **naming-convention-based** (`test_F0001_*.py`), not semantic

**How our framework handles traceability**:
- F-#### → `spec/acceptance/F-####.md` → `@feature F-####` code annotations → `test_F####_*.py` test files
- `coverage.py` scans for `@feature` annotations and builds feature→file mappings
- `verify.py` and `doctor.py` enforce cross-reference integrity
- Pre-commit hooks validate that shipped features have complete tests
- But: relies on developers maintaining `@feature` annotations; no assertion→criteria mapping

**The gap both systems share**: Neither verifies that test assertions **semantically cover** acceptance criteria. Both rely on developer discipline to ensure tests actually test what the spec says. This is the hardest traceability problem — it would require LLM-powered semantic analysis to bridge.

### What We Could Learn: The `/analyze` Coverage Gap Detection

The one thing the studied toolkit does better here is their `/analyze` command's **coverage gap detection**:
- "Requirement FR-003 has no corresponding task"
- "Task T014 doesn't trace to any requirement"
- "User Story 2 has acceptance scenarios but no test tasks"

**Our equivalent**: `coverage.py` checks code annotations, but doesn't check **AC → test mapping**. We can tell you which features have code, but not which **specific acceptance criteria** have tests.

**Recommendation R7: AC-level coverage tracking**

Extend `coverage.py` to check not just feature-level coverage but AC-level:

```
Feature F-0042: 6/8 ACs have corresponding test assertions
  ✅ AC-001: covered by test_F0042_core.py:test_todo_captures_text
  ✅ AC-002: covered by test_F0042_core.py:test_todo_has_timestamp
  ❌ AC-003: NO TEST FOUND — "rate limiting on rapid captures"
  ❌ AC-004: NO TEST FOUND — "duplicate detection"
```

This would use naming conventions + LLM analysis to map individual test functions to specific ACs. Run as a soft gate (informational, not blocking) since the mapping will be imperfect.

### Summary Table: Migration & Traceability

| Capability | Studied Toolkit | Our Framework | Gap |
|-----------|----------------|---------------|-----|
| **Spec migration tracking** | None | Full (migrations, markers, rollback) | They have the gap |
| **Shipped spec protection** | None | 3 blocking pre-commit checks | They have the gap |
| **Spec evolution markers** | `[NEEDS CLARIFICATION]` only | `[Discovered]`, `[Revised]`, `[Future]` | They have the gap |
| **Feature→code traceability** | Task file paths | `@feature` annotations + coverage.py | Roughly even |
| **Feature→test traceability** | Naming convention | Naming convention + verify.py | Roughly even |
| **Cross-artifact consistency** | `/analyze` command (6 checks) | verify.py + doctor.py + consistency.py | **We lack semantic checks** |
| **Coverage gap detection** | Requirement↔task mapping | Feature-level only, not AC-level | **We lack AC-level mapping** |
| **Test↔AC semantic mapping** | None | None | **Both have this gap** |

---

## 11. Beyond the Studied Toolkit: Autonomous Loops

> **Note**: This section goes beyond comparing with the studied toolkit. It documents an opportunity gap identified during research. The studied toolkit explicitly does NOT do any of this — they halt on errors and require human intervention. Their philosophy: *"Where human supervision is not in the loop, it's generating code that cannot be reasonably maintained."*

### The Opportunity

No mainstream spec-driven framework offers autonomous verification or development loops. Autonomous coding agents (Devin, SWE-Agent, OpenHands) have test→fix loops but lack spec discipline. Combining spec-driven rigor with autonomous execution is greenfield. Two capabilities to consider:

### Capability A: Verification Loop (test → fix → retest → converge)

**Concept**: After implementation, run an autonomous cycle that:
1. Runs test suite
2. Captures failures (test output, screenshots, error logs)
3. Analyzes failures against acceptance criteria
4. Generates fixes
5. Applies fixes
6. Re-runs tests
7. Repeats until all tests pass OR max iterations reached
8. Reports final state to human

**Key design considerations**:
- **Bounded iterations**: Must have a max (e.g., 3-5 cycles) to prevent infinite loops
- **Escalation**: If auto-fix fails after N attempts, escalate to human with diagnostic report
- **Scope control**: Only fix failures related to current feature's ACs — don't touch unrelated code
- **Rollback safety**: Each fix attempt should be reversible (git stash/branch per attempt)
- **Screenshot/visual verification**: For UI work, capture screenshots and compare against expectations
- **Human approval gate**: Even after convergence, show diff to human before committing

**Where it fits in our workflow**:
```
ag implement F-XXXX
  → agent implements ACs
  → VERIFICATION LOOP STARTS
    → run tests → failures? → analyze → fix → retest
    → converge or escalate
  → show results to human
  → human approves → ag commit
```

### Capability B: Automatic Development Loop (spec → finished feature)

**Concept**: Given a spec (or even just a few lines of intent), autonomously:
1. Generate/refine acceptance criteria
2. Create implementation plan
3. Execute plan (implement code)
4. Run verification loop (Capability A)
5. Update documentation
6. Present finished feature to human for review

**This is essentially chaining our existing skills**: `writing-specs` → `planning-features` → `implementing-features` → verification loop → `completing-work`

**Key design considerations**:
- **Autonomy levels**: How much human involvement at each stage?
  - **Supervised**: Human approves spec, plan, and final result (3 checkpoints)
  - **Semi-autonomous**: Human approves spec only; rest is autonomous until final review
  - **Fully autonomous**: Human provides intent; everything else is autonomous until final PR
- **Quality guarantees**: Without human review at each stage, quality depends entirely on:
  - Spec quality (garbage in → garbage out)
  - Test coverage (if tests are weak, auto-fix may produce bad code that passes)
  - Gate strength (our pre-commit hooks catch structural issues, but not semantic ones)
- **Risk management**: Autonomous development on a feature branch is safe; on main is dangerous
- **Token/cost management**: Multiple cycles of implement→test→fix can be expensive

### Comparison: What Exists in the Ecosystem

| Tool/Framework | Verification Loop | Auto-Dev Loop |
|---------------|-------------------|---------------|
| Studied toolkit | No (halts on error) | No (human runs each command) |
| Claude Code (native) | No built-in loop | No |
| Cursor | No | Composer can chain edits but no test loop |
| Devin | Yes (runs tests, iterates) | Yes (accepts issues, produces PRs) |
| SWE-Agent | Yes (test→fix cycles) | Yes (from issue to patch) |
| OpenHands | Yes (sandbox execution loops) | Yes (from task to implementation) |

**Our opportunity**: The spec-driven frameworks (like the studied toolkit) don't have this. The autonomous agents (Devin, SWE-Agent) have it but lack spec discipline. We could be the first to combine **spec-driven rigor with autonomous execution loops**.

### Risk Assessment

| Risk | Mitigation |
|------|-----------|
| **Infinite fix loops** | Bounded iterations (max 3-5), escalation to human |
| **Silent quality degradation** | Pre-commit hooks still enforce structural gates |
| **Spec drift during auto-fix** | Only fix code, never auto-modify specs |
| **Cost explosion** | Token budget per loop, abort if exceeded |
| **False confidence** | Tests passing ≠ feature working; require smoke test checkpoint |
| **Security vulnerabilities from auto-fix** | Security-sensitive code paths should always require human review |

### Recommended Approach

**Start with Capability A (Verification Loop)** — it's lower risk and higher immediate value:
1. After implementation, run tests automatically
2. On failure: analyze, attempt fix, retest (max 3 cycles)
3. On convergence: report to human
4. On exhaustion: report failures with diagnostic context to human

**Defer Capability B (Auto-Dev Loop)** until Capability A is proven:
- Auto-dev depends on auto-verify working reliably
- The skill chain already exists (spec → plan → implement → complete)
- The missing piece is the verification loop between implement and complete

---

## 12. Consolidated Recommendations

### Priority List

| # | Recommendation | Effort | Value | Token Cost | Feature ID | Source |
|---|---------------|--------|-------|------------|------------|--------|
| R1 | **Resurface + enhance spec clarification** (we have this buried; enhance with studied toolkit's taxonomy scan + meta-checklist) | Small | High | ~2K tokens/spec | TBD | §3.1, §3.3 |
| R2 | **Semantic consistency analysis** (cross-artifact checks before implement) | Medium | High | ~5-10K tokens/analysis | TBD | §3.2 |
| R3 | **User-extension directory** (.agentic-extensions/, upgrade-safe) | Medium | High | Zero | TBD | §7 |
| R4 | **Spec format evolution** (priority tags on AC groups, "verify independently") | Small | Medium | Zero | TBD | §8 |
| R5 | **Verification loop** (test→fix→retest, bounded 3-5 cycles) | Large | Very High | ~10-50K tokens/loop | TBD | §11 |
| R6 | Execution order section in plans + checkpoint validation | Small | Medium | Zero | — | §9 |
| R7 | AC-level coverage tracking in coverage.py | Medium | Medium | ~3K tokens/feature | — | §10 |
| R8 | Auto-dev loop (spec→feature, skill chaining) | Very Large | High | Very high | — | §11 |

### Feasibility Notes

**R2 (Semantic consistency analysis)**: Requires careful design.
- Which LLM? Must use the same model powering the agent (no external API call assumption).
- Latency: 5-10K tokens = ~10-20 seconds. Acceptable as a pre-implement gate, not as a per-edit check.
- False positive rate: LLM-based analysis will have ~10-20% false positives. Must be advisory (warn), not blocking (exit 1).
- Air-gapped development: Won't work offline. Must be skippable.
- Recommendation: Start with 3 checks only (ambiguity detection, AC↔test coverage gaps, NFR measurability). Add more checks after validating false positive rate.

**R5 (Verification loop)**: Requires feasibility proof before full investment.
- Start with a simple prototype: run tests → if failure → show error + suggest fix → human approves → apply → retest.
- Graduate to autonomous only after human-in-the-loop version proves reliable.
- Must respect token budget (abort after N tokens, not just N iterations).
- Security-sensitive code must always escalate to human review.

### Complexity Budget (KISS Check)

Adopting all 8 recommendations would add significant complexity. Evaluated against F3 (Token Optimization) and KISS:

| What gets added | Complexity cost | Justified? |
|----------------|----------------|------------|
| R1: One LLM pass during spec-writing | Low — single scan, already in agent context | Yes |
| R2: LLM analysis before implement | Medium — new tool, false positive management | Yes, but start with 3 checks |
| R3: New directory, generate-skills.sh changes | Medium — structural change, upgrade.sh updates | Yes — solves real adoption blocker |
| R4: Template change to acceptance files | Low — additive, backward compatible | Yes |
| R5: Verification loop infrastructure | High — new orchestration, token management, rollback | Defer until prototype proven |
| R6: Section in plan docs | Negligible | Yes |
| R7: LLM-powered coverage mapping | Medium — new tool, accuracy concerns | Defer — R2 covers most value |
| R8: Full skill chaining | Very high — depends on R5 working | Defer until R5 proven |

**Recommended phasing**: Adopt R1, R3, R4, R6 first (low complexity, high value). Then R2 (medium complexity, needs false positive validation). Then R5 prototype. R7 and R8 only after R5 proven.

**Total new pre-implementation gates if all adopted**: R1 (during spec-writing) + R2 (before implement) = 2 new gates. R6 is during planning (existing phase). This is manageable — the concern about "5 new gates" from the review was based on the un-merged recommendation list.

### What NOT to Adopt

| Idea | Why Skip |
|------|----------|
| **Full plugin/catalog architecture** | A lightweight `.agentic-extensions/` directory (R3) captures 80% of the value at 20% of the complexity. |
| **One-shot spec→code pipeline** | Both systems are spec-driven. The difference is execution model: their one-shot pipeline (spec → plan → tasks → implement all at once) vs our iterative TDD (spec → criteria → tests → implement → evolve). Their model enables rapid pivots; ours is more robust for evolving projects. Not a paradigm we're missing — a different execution strategy. |
| **Separate T### task IDs** | Redundant with AC-###. |
| **Directory-per-feature storage** | Our flat approach scales better at 100+ features. |
| **20+ agent support** | Depth > breadth. 4 agents covers 90%+ of users. |
| **User story format replacing ACs** | ACs are more precise and directly testable. |

---

## 13. Summary

The studied toolkit and our framework have **complementary strengths**:
- They excel at the **front-end of the spec lifecycle**: structured clarification, consistency analysis, requirement meta-validation
- We excel at the **back-end**: structural enforcement, session continuity, migration audit trails, commit quality gates

Both rely on a mix of deterministic and behavioral enforcement — the difference is emphasis, not kind. Our enforcement is stronger at commit time; theirs is stronger at spec-writing time.

**Highest-value actions**: Adopt their clarification + quality validation during spec-writing (R1), add upgrade-safe user extensions (R3), evolve spec format with priority tags (R4). These are low-complexity, high-return.

**Biggest opportunity gap**: Neither system (nor any spec-driven framework we found) offers autonomous verification loops. Combining spec-driven rigor with test→fix→retest automation (R5) would be a genuine differentiator — but requires careful prototyping before committing to full implementation.

**Honest self-assessment**: Our framework's enforcement advantage is narrower than we sometimes claim. Our most critical safety rules (anti-hallucination, no auto-commit) are behavioral, just like theirs. And their stateless design has genuine simplicity advantages we shouldn't dismiss.
