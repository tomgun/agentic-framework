# Spec System Overhaul — Final Plan

## Context

The framework's spec system has 217 features that describe how it was built, not what it IS. ACs are markdown checklists checked once and forgotten. Tests aren't linked to specs. Shipped behavior can silently disappear during refactoring. This overhaul redesigns the spec system from the ground up using YAML contracts as the source of truth, with a user_input mechanism that makes specs the control interface for driving changes.

**Core principle**: "Perfection is when you can't remove anything." The end state is ~30-40 features with comprehensive, machine-verifiable, automatically-protected contracts.

**Actual scope**: 217 feature entries (F-0001 through F-0301 with gaps), but the category summary table only accounts for 126 — 91 features are untracked in the header table. Plus 4 NFRs, 208 AC files (9 features missing ACs), 14 backlog items, and an unknown number of behaviors not tracked as features at all. The spec system isn't even maintaining its own integrity.

---

## Design Decisions

| Decision | Choice | Why |
|----------|--------|-----|
| Spec format | YAML contracts | Long-term parsing reliability; standard parsers in every language; markdown is ambiguous |
| Feature count | ~30-40 consolidated | 217 is history, not state; real capabilities are ~30-40 |
| Old features | Archived | Move to `docs/archive/`; blast radius is chore work, not a blocker |
| Capability vs Feature | Same thing | No separate capability layer; consolidated features ARE capabilities |
| User input | `user_input` field in YAML | Specs become control interface; user edits spec → agent handles implementation |
| Test linkage | Assertions reference tests | Every AC assertion maps to specific test files |
| Protection | Pre-commit + migration | Shipped contract changes require explicit migration entry |

---

## The Contract Format

```yaml
# .agentic/spec/contracts/F-0003.yaml
id: F-0003
name: Spec-Driven Development
status: shipped
since: v0.1.0
profile: formal  # formal | discovery | both
protection: contract  # contract | advisory | none
consolidated_from: [F-0005, F-0006, F-0010, F-0043, F-0128, F-0132, F-0148, F-0152, F-0251]

description: |
  Formal-profile projects manage features through YAML contract specifications
  with testable acceptance criteria. Features have lifecycle states, enforcement
  gates, and migration-protected shipped contracts.

# Human writes change requests here.
# Agent detects non-empty user_input → updates tests → code → migration → spec → clears field.
user_input: ""

assertions:
  - id: AC-001
    text: "Formal profile creates spec/ directory with contracts/ and FEATURES.md"
    type: structural
    verify: |
      test -d "$PROJECT/.agentic/spec/contracts" &&
      test -f "$PROJECT/.agentic/spec/FEATURES.md"
    tests:
      - tests/validate_framework.sh::F-0003
      - tests/test_validate_specs.py::test_formal_scaffold

  - id: AC-002
    text: "ag implement blocks when feature has no contract file"
    type: behavioral
    verify: null  # behavioral = verified via LLM/integration tests only
    tests:
      - tests/llm/tests/003_acceptance_first.sh
      - tests/llm/tests/010_feature_needs_spec.sh

  - id: AC-003
    text: "Shipped contract changes require migration entry"
    type: structural
    verify: "bash tests/infrastructure/structural/S11_shipped_spec_protection.sh"
    tests:
      - tests/infrastructure/structural/S11_shipped_spec_protection.sh

  - id: AC-004
    text: "Contract YAML is parseable by standard YAML parser"
    type: structural
    verify: "python3 -c 'import yaml; yaml.safe_load(open(\"spec/contracts/F-0003.yaml\"))'"
    tests:
      - tests/test_validate_specs.py::test_contract_yaml_valid

nfr_refs: [NFR-0004]  # Links to relevant NFRs
lifecycle: shipped    # See "Contract Lifecycle" section below

# BDD scenarios for human readability (not parsed for verification)
scenarios:
  - name: "New formal project gets spec directory"
    given: "Empty target directory"
    when: "Run ag init --profile formal"
    then: "spec/ created with contracts/ subdirectory and FEATURES.md"

  - name: "Implementation blocked without spec"
    given: "Formal project, F-0099 in FEATURES.md with no contract file"
    when: "Agent runs ag implement F-0099"
    then: "Command exits with BLOCKED, message references missing contract"
```

### Key Format Properties

- **`user_input`**: The spec-as-control-interface. User writes what they want changed. Agent picks it up and handles tests → code → migration → spec update → clear field.
- **`assertions`**: Machine-verifiable. `type: structural` has a `verify` command (exits 0 = pass). `type: behavioral` has `verify: null` (only verifiable via LLM/integration tests).
- **`tests`**: Every assertion links to specific test files. Bidirectional traceability.
- **`protection: contract`**: Pre-commit enforces that changes to shipped contracts require a migration entry.
- **`consolidated_from`**: Preserves provenance — which old F-XXXX features were merged into this one.
- **`scenarios`**: BDD scenarios for human readability. Not parsed for automated verification (that's what assertions are for).

### Contract Lifecycle & Backlog Integration

The contract format supports the full journey from idea to protected shipped spec:

```
ag todo "idea" → ag backlog add → ag plan F-XXXX → ag spec F-XXXX → ag implement → ag done → shipped
     │                │                  │                │               │            │
   TODO.md       BACKLOG.json      plan.md         contract.yaml    code+tests    protected
   (no spec)     (no spec yet)     (exploration)   (formal spec)    (building)    (contract)
```

**Lifecycle states** (in the `lifecycle` field):

| State | What exists | Protection | Who creates |
|-------|-------------|------------|-------------|
| `idea` | Entry in TODO.md only | None | `ag todo` |
| `backlog` | Entry in BACKLOG.json, maybe a one-liner in FEATURES.md | None | `ag backlog add` |
| `exploring` | Draft contract with description + rough assertions, marked speculative | None — assertions are drafts | `ag plan` creates draft |
| `specifying` | Contract with assertions being refined, tests being written | Advisory warnings on changes | `ag spec` formalizes |
| `implementing` | Contract approved, assertions locked for this iteration | Block assertion changes without migration | `ag implement` locks |
| `shipped` | Contract complete, all assertions verified | Full contract protection — changes require migration | `ag done` ships |
| `deprecated` | Contract archived, behavior removed | Migration required to deprecate | Manual |

**Discovery profile**: In discovery mode, work stays in `idea` → `backlog` → `exploring` without ever reaching `specifying`. There's no enforcement — it's lightweight tracking. The contract YAML is optional. When the user wants to formalize (e.g., switching to formal profile or promoting a discovery to production), they run `ag formalize` which creates a proper contract from what was learned.

**Draft contracts (exploring state)**:

```yaml
id: F-0099
name: Cool New Feature
lifecycle: exploring
protection: none          # No enforcement yet — still figuring it out

description: |
  We think this feature should do X, Y, Z but we're still exploring.

# Draft assertions — speculative, may change freely
assertions:
  - id: AC-001
    text: "Probably needs to do X"
    type: structural
    verify: null            # Don't know yet
    tests: []               # No tests yet
    draft: true             # Marked as draft — not enforced

notes: |
  Open questions:
  - Should this work in discovery mode too?
  - Performance implications unknown
  - Need to prototype before committing to assertions
```

**Backlog integration**: BACKLOG.json continues to reference feature IDs (F-XXXX). When a backlog item is promoted to active work:
1. `ag plan F-XXXX` creates a draft contract (`lifecycle: exploring`) if none exists
2. Exploration and planning happen with the draft contract as a living document
3. `ag spec F-XXXX` transitions to `specifying` — assertions become real, tests start being written
4. `ag implement F-XXXX` transitions to `implementing` — assertions are locked
5. `ag done F-XXXX` transitions to `shipped` — full protection activated

**Key principle**: You don't commit to formal specs until you understand what you're building. The contract format supports the messy exploration phase (with `draft: true` assertions and `notes`) without forcing premature formality. But once you DO commit (specifying → implementing), the spec becomes a real contract.

### Planning Hierarchy & Task Decomposition

The contract system supports a full planning-to-execution hierarchy:

```
Vision / Milestone Plan
  └── Epics (large capabilities, decompose into features)
       └── Features (with contracts, decompose into tasks)
            └── Tasks (implementation steps, go on backlog)
                 └── Assertions satisfied (tracked per task)
```

**Level 1: Vision / Milestone Planning**

At project start or after a milestone, `ag kickoff "vision"` (or a milestone review) produces:
- High-level epics or features
- Each gets a draft contract (`lifecycle: exploring`)
- Rough priority ordering → BACKLOG.json

**Level 2: Epic Decomposition**

An epic (large feature) decomposes into child features via `ag decompose F-XXXX`:
- Parent contract has `children: [F-0010, F-0011, F-0012]`
- Each child gets its own contract
- Epic's assertions may reference children: "All child features shipped"

**Level 3: Feature → Tasks**

A single feature's contract has assertions (AC-001, AC-002, ...). Implementation is broken into **tasks** — ordered steps that each address one or more assertions:

```yaml
# Inside the contract YAML
tasks:
  - id: T-001
    description: "Set up spec/ directory scaffolding"
    assertions: [AC-001, AC-004]   # Which ACs this task addresses
    status: done                    # planned | in_progress | done

  - id: T-002
    description: "Implement ag implement gate for missing AC file"
    assertions: [AC-002]
    status: in_progress

  - id: T-003
    description: "Add migration protection for shipped ACs"
    assertions: [AC-003]
    status: planned
```

**Level 4: Tasks on the Backlog**

The backlog operates at the TASK level within the current feature:
- `ag plan F-XXXX` creates the implementation plan AND populates the `tasks` list in the contract
- The tasks become the ordered work queue for that feature
- `ag next` shows the next task within the current feature
- When all tasks for a feature are done → all assertions should be verified → `ag done` ships it

**Backlog structure evolves**:
```json
[
  {"type": "task", "feature": "F-0003", "task": "T-002", "description": "Implement gate..."},
  {"type": "task", "feature": "F-0003", "task": "T-003", "description": "Add migration..."},
  {"type": "feature", "id": "F-0010", "description": "Next feature after F-0003"}
]
```

Tasks from the current feature come first, then the next feature. This preserves "one feature at a time" while making the work within a feature explicit and ordered.

**Milestone reviews**:

After shipping a set of features (a milestone), the team reviews:
- What shipped vs. what was planned
- Contract health across shipped features (`ag contract check`)
- What to plan next → new epics/features → new draft contracts
- `ag kickoff --review` or a manual planning session

The contract format captures the output of planning at every level — from high-level vision down to individual implementation tasks, each linked to the assertions they satisfy.

### Hierarchy Support

The format supports categories, epics, and parent-child relationships:

```yaml
id: F-0003
category: core-workflow        # Grouping for display and filtering
parent: null                   # Epic ID (e.g., E-0001) or parent feature ID
children: []                   # Child feature IDs for epics/decomposed features
tags: [formal-only, spec-system]  # Flexible tagging for cross-cutting concerns
```

**Category hierarchy**: Categories group related features for navigation (e.g., `core-workflow`, `multi-agent`, `autonomous`, `quality`). `ag contract list --category core-workflow` shows one group.

**Epic hierarchy**: An epic feature (e.g., E-0001) has `children: [F-0221, F-0222, F-0223, ...]`. Child features have `parent: E-0001`. This replaces the current `Epic:` field in FEATURES.md with a proper bidirectional link.

**Viewing**: `ag contract tree` shows the hierarchy. `ag contract list --flat` shows a flat list. Both are views over the same data.

### Spec Migration (Tracked Changes)

When a shipped spec needs to change — whether from external triggers, implementation discoveries, or user requests — the change is tracked in a `migrations` block within the contract:

```yaml
migrations:
  - id: M-2026-03-22-001
    date: 2026-03-22
    trigger: external           # external | implementation_discovery | user_request
    reason: "Dependency X changed API, old verify command no longer valid"
    changes:
      - "AC-003: updated verify command for new API"
      - "AC-007: added new assertion for backward compat"
    approved_by: user           # user | agent_review | auto (for advisory contracts)

  - id: M-2026-03-25-001
    date: 2026-03-25
    trigger: implementation_discovery
    reason: "Found that AC-002 is unverifiable in CI without mock server"
    changes:
      - "AC-002: changed type from structural to behavioral"
      - "AC-002: added integration test reference"
    approved_by: agent_review
```

**Migration triggers**:
- **`external`**: Something outside the project changed (dependency update, API change, compliance requirement, new platform constraint). Forces spec adaptation.
- **`implementation_discovery`**: During coding or testing, the team discovers the spec is wrong, incomplete, or unimplementable. Spec must be corrected.
- **`user_request`**: User explicitly wants to change shipped behavior (via `user_input` field or direct edit).

**Enforcement**: Pre-commit checks that any modification to a shipped contract's assertions has a corresponding migration entry with the same date. No silent changes.

**Audit trail**: `ag contract migrations F-0003` shows the full change history. `ag contract migrations --trigger external` shows all externally-forced changes across the project.

The existing `spec/migrations/` directory (17 dated files) continues to serve as the project-level migration log. The per-contract `migrations` block adds feature-level granularity.

---

## Phase 0: Feature Consolidation & Triage (2-3 sessions)

### Step 0.1: Batch-by-Capability Review

Walk through all 217 features grouped by ~30-40 proposed consolidated features. For each group, classify every F-XXXX as:

- **Core** → absorbed into the consolidated feature's assertions
- **Enforcement** → its ACs become assertions in the consolidated feature
- **Implementation Detail** → archived (F-0157 Directory Restructure, F-0221 ag.sh Decomposition, etc.)
- **Deprecated** → archived (F-0028, F-0033, F-0098, F-0106, F-0107, F-0108)
- **Design Constraint** → becomes NFR or cross-cutting assertion (F-0007, F-0071-F-0079)
- **Planned/Stale** → evaluate: still relevant? drop or keep in backlog

### Step 0.2: Finalize Feature List

Produce the consolidated feature list (~30-40 entries). Each entry has:
- New (or retained) F-XXXX ID
- Name
- Which old features it consolidates
- Draft assertion list (from reviewing old ACs)

### Step 0.3: Planned Feature Pruning

Review each planned/unimplemented feature with user:
- F-0193, F-0210-F-0213, F-0220, F-0223, F-0227-F-0228, F-0230-F-0233, F-0243
- Decision per feature: keep in backlog, drop, or merge into existing

**Output**: `spec/CONSOLIDATION_MAP.md` — table of old → new feature mapping

---

## Phase 1: Contract Infrastructure (2 sessions)

### Step 1.1: Contract Parser & Validator

Create `spec/contract_parser.py`:
- Parse YAML contract files
- Validate schema (required fields, assertion format)
- Extract structural assertions for verification
- Detect non-empty `user_input` fields (signals pending work)

### Step 1.2: `ag contract` Command

```bash
ag contract check              # Run all structural verify commands, report pass/fail
ag contract check F-0003       # Run one feature's assertions
ag contract coverage           # Show assertions with/without tests
ag contract pending            # Show features with non-empty user_input
ag contract list               # Show all contracts with status
```

### Step 1.3: Verification Runner

Create `verify-contracts.sh`:
- Reads all `.yaml` files in `spec/contracts/`
- Runs each structural assertion's `verify` command
- Reports pass/fail per feature, per assertion
- Outputs machine-readable results (JSON) for other tools

### Step 1.4: Pre-Commit Integration

Add to `pre-commit-check.sh`:
- When committing changes to `spec/contracts/*.yaml`: require migration entry for shipped contracts
- When committing code changes: run structural assertions for contracts that reference modified files
- Block commit if shipped contract assertion fails

**Files created**: `spec/contract_parser.py`, `commands/contract.sh`, `verify-contracts.sh`
**Files modified**: `pre-commit-check.sh`, `ag.sh`

---

## Phase 2: Contract Writing (4-6 sessions)

### Step 2.1: Write Contracts for Each Consolidated Feature

For each of the ~30-40 features:
1. Review all old AC files from constituent features
2. Identify valid vs. stale criteria (e.g., F-0003 references deleted PRD.md)
3. Write YAML contract with assertions, verify commands, test links, scenarios
4. Ensure every shipped feature has `protection: contract`

### Step 2.2: Test-AC Mapping

For each assertion:
- If a test exists: link it in the `tests` field
- If no test exists: flag the gap (add to a test-debt list)
- Goal: every structural assertion has a verify command AND at least one test

### Step 2.3: Migrate validate_framework.sh Assertions

The 640+ assertions in validate_framework.sh are valuable. For each:
- Map it to the corresponding contract assertion
- Port the verify logic into the contract's `verify` field
- Some may upgrade from file-existence to behavioral checks

### Step 2.4: User Input Workflow

Implement the `user_input` processing:
- `ag contract pending` lists features with non-empty `user_input`
- Agent workflow: detect pending → update tests → update code → create migration → update contract → clear `user_input`
- `ag implement` can trigger this when it detects pending user input on the current feature

**Files created**: `spec/contracts/F-XXXX.yaml` (~30-40 files)
**Files modified**: `engine.py` (load contracts instead of AC markdown)

---

## Phase 3: The Switchover (3-4 sessions)

One-go migration, no dual systems. Each sub-step produces a verifiable state.

### Step 3.1: Archive Old Files (verify: files moved, git clean)
- `git mv spec/acceptance/ docs/archive/acceptance/`
- `git mv spec/FEATURES.md docs/archive/FEATURES-v0.69.md`
- Contracts from Phase 2 are already in `spec/contracts/`
- New FEATURES.md written with ~30-40 consolidated entries pointing to contracts
- **Verify**: `ls spec/contracts/*.yaml | wc -l` matches expected count, old files in archive

### Step 3.2: Update Path Resolution (verify: paths resolve, imports work)
- `paths.py`: `contracts_dir` → `spec/contracts/`, remove `acceptance_dir` or point to archive
- `paths.sh`: `CONTRACTS_DIR`, update `ACCEPTANCE_DIR`
- **Verify**: `python3 -c "from agentic.lib.paths import get_paths; p=get_paths(); print(p.contracts_dir)"`

### Step 3.3: Update State Machine (verify: transitions work)
- `state_machine.py`: read lifecycle state from contract YAML instead of FEATURES.md status field
- Transition rules updated for new state names
- Gate checks read assertions from contracts
- **Verify**: `ag transition F-XXXX <state>` works, `ag status` shows correct states

### Step 3.4: Update ag Commands (verify: each command works)
Update one command at a time, verify each:
1. `ag implement` → load contract YAML, check assertions exist
2. `ag spec` → create/edit contract YAML via script commands
3. `ag done` → verify contract assertions, transition to shipped
4. `ag audit` → report contract health
5. `ag plan` → create draft contract if none exists
6. `engine.py` → parse contract assertions for autonomous loop
7. `ag contract` commands wired into main ag gateway
- **Verify per command**: Run the command, check output references contracts not AC markdown

### Step 3.5: Update Shell Scripts (~50 files) (verify: grep finds no old paths)
- Bulk update hardcoded `spec/acceptance` references in commands/*.sh, tools/*.sh
- Update error messages, help text, user-facing strings
- **Verify**: `grep -r "spec/acceptance" .agentic/lib/ --include="*.sh" | grep -v archive` returns nothing

### Step 3.6: Update Python Modules (~35 files) (verify: pytest passes)
- Most auto-fix via paths.py change
- Manual update for hardcoded path strings
- **Verify**: `pytest tests/ -x` passes

### Step 3.7: Update Tests (verify: test suite green)
- `validate_framework.sh`: delegate to `verify-contracts.sh` for contract-aware features
- `qa_registry.py`: read contract YAML, report by consolidated feature
- Update test fixtures that reference old paths
- **Verify**: `bash tests/validate_framework.sh` passes, `python3 tests/qa_registry.py` generates report

### Step 3.8: Update Instruction Files (verify: checklist complete)
All 11 instruction file locations:
- [ ] `.agentic/lib/agents/claude/CLAUDE.md`
- [ ] `.agentic/lib/agents/claude/skills/writing-specs/SKILL.md`
- [ ] `.agentic/lib/agents/claude/skills/implementing-features/SKILL.md`
- [ ] `.agentic/lib/agents/claude/skills/completing-work/SKILL.md`
- [ ] `.agentic/lib/init/memory-seed.md`
- [ ] `.cursorrules` / `.cursor/agents/`
- [ ] `.github/copilot-instructions.md`
- [ ] `.codex/instructions.md`
- [ ] `DEVELOPER_GUIDE.md`
- [ ] `HOW_IT_WORKS.md`
- [ ] `FRAMEWORK_DEVELOPMENT.md`
- **Verify**: `bash tests/validate_framework.sh` section on instruction files passes

**Files modified**: paths.py, paths.sh, state_machine.py, gates.py, FEATURES.md (rewrite), all commands/*.sh (~13), engine.py, ~35 Python modules, qa_registry.py, validate_framework.sh, ~11 instruction files, ~50 tool/script files

---

## Phase 4: Protection & V2 Cleanup (2 sessions)

### Step 4.1: Contract Protection Enforcement

- Pre-commit: shipped contract modifications blocked without migration entry
- `ag contract check` integrated into `ag verify`
- CI-compatible: `verify-contracts.sh` returns non-zero on failure

### Step 4.2: User Input Automation

- `ag start` checks for pending `user_input` fields and surfaces them
- Skill integration: when user_input detected, agent workflow triggers automatically
- Migration tracking: changes to shipped contracts produce dated migration entries in `spec/migrations/`

### Step 4.3: V2 Dead Code Cleanup

- Verify `.agentic/lib/auto/v2/` is truly unreachable (F-0248 claims shipped)
- If still present: delete (14 files, 3,217 lines)
- Fix `state_machine_af.yaml` engine field
- Audit dual gate systems (`gate.py` vs `auto/gates.py`), consolidate if possible

### Step 4.4: Stale Planned Feature Cleanup

- Remove planned features confirmed dropped in Phase 0
- Update BACKLOG.json to reference consolidated feature IDs
- Clean up any orphaned test references

**Files modified**: `pre-commit-check.sh`, `dashboard.sh`, potentially `v2/` (delete), `gate.py`/`gates.py`

---

## Phase 5: User Project Support (1-2 sessions)

### Step 5.1: Contract Templates

Update `scaffold.sh` and init templates:
- New projects get `spec/contracts/` directory
- Template contract YAML for first feature
- `ag spec F-XXXX` creates contract YAML (not markdown AC)

### Step 5.2: Migration Tool for Existing Projects

For projects already using the framework with markdown ACs:
- `ag migrate-specs` command
- Reads existing `spec/acceptance/*.md` files
- Generates corresponding `.yaml` contracts
- Preserves assertion content, adds structure
- Archives old markdown files

### Step 5.3: Documentation

- Update DEVELOPER_GUIDE.md with contract format
- Update HOW_IT_WORKS.md with new spec workflow
- Update memory-seed.md with contract-related trigger words
- Update relevant skills (writing-specs, implementing-features, etc.)

**Files modified**: `scaffold.sh`, init templates, DEVELOPER_GUIDE.md, HOW_IT_WORKS.md, memory-seed.md, skills

---

## Critical Files

| File | Role | Action |
|---|---|---|
| `.agentic/spec/FEATURES.md` | Feature registry (217 entries) | Rewrite with ~30-40 consolidated entries |
| `.agentic/spec/acceptance/` | AC markdown files (203) | Archive to `docs/archive/acceptance/` |
| `.agentic/spec/contracts/` | NEW: YAML contracts | Create ~30-40 contract files |
| `.agentic/lib/paths.py` | Central path resolver | Add contracts_dir, update acceptance_dir |
| `.agentic/lib/paths.sh` | Shell path resolver | Same |
| `.agentic/lib/auto/engine.py` | Autonomous engine | Parse contracts instead of AC markdown |
| `.agentic/lib/tools/commands/*.sh` | ag commands (~13 files) | Update to use contracts |
| `.agentic/lib/hooks/pre-commit-check.sh` | Quality gates | Add contract protection checks |
| `tests/validate_framework.sh` | Validation (5,908 lines) | Delegate to verify-contracts.sh |
| `tests/qa_registry.py` | Test-feature mapping | Read contracts, report by consolidated feature |
| `docs/CAPABILITY_SPEC.md` | System description draft | Update to match consolidated features |

---

## Verification

1. `ag contract check` passes all structural assertions for shipped features
2. `ag contract coverage` shows no shipped assertion without at least one test
3. `ag contract pending` shows no stale user_input (all processed)
4. Pre-commit blocks shipped contract modification without migration
5. FEATURES.md has ~30-40 entries describing what the system IS
6. Old 217-entry FEATURES.md preserved in `docs/archive/`
7. All existing tests still pass
8. `ag implement` and `ag auto task` work with contract format
9. New projects scaffold with contract YAML, not markdown ACs
10. A new reader understands the framework from FEATURES.md + contracts

---

## User Design Contributions

Key design insights from the user that shaped this plan:

1. **"Perfection is when you can't remove anything"** — The framing that specs should describe what the system IS, not its history. Drove the consolidation from 217 → ~30-40 features.

2. **Specs as control interface (`user_input` concept)** — The idea that users should be able to edit specs directly, and the agent automatically cascades changes to tests, implementation, and migration docs. This makes the spec the PRIMARY interface for driving changes, not just documentation.

3. **Long-term format reliability** — Pushed for YAML over structured markdown because parsing reliability matters more than familiarity. "Which format is more reliable in the long run?" changed the format decision.

4. **"If it is needed, then it is needed"** — Rejected the critic's conservatism about blast radius. 300+ file references to update is chore work for an AI, not a reason to compromise the design.

5. **Capabilities and features are the same thing** — Eliminated the unnecessary "capability layer" abstraction. Consolidate features rather than adding a concept on top.

6. **Scale assumption** — "User projects could have hundreds or thousands of features." Rejected the critic's assumption that user projects are small. The design must work at scale.

7. **"Use the best solution, not what we currently have"** — Explicit direction to design from first principles rather than constraining to the existing system.

---

## Design Decisions (Resolved)

### D1: Machine-First, Human-Readable Second
The contract format is **primarily for machines**. Names and descriptions provide human readability, but the structure is optimized for reliable parsing and automated verification. Agents don't write YAML directly — **scripts update contracts**, following the same pattern as the existing token-efficient scripts (journal.sh, status.sh, feature.sh):

```bash
ag contract set F-0003 lifecycle implementing
ag contract add-assertion F-0003 "ag implement blocks without AC" --type behavioral
ag contract add-migration F-0003 --trigger external --reason "API changed"
```

This solves the "YAML is hard for LLMs" problem — agents call scripts, scripts write valid YAML. Same pattern that already works for FEATURES.md and JOURNAL.md.

### D2: Unified State Machine
The contract `lifecycle` field IS the state machine. `state_machine.py` reads/writes from contract YAML. One source of truth.

**State mapping** (contract lifecycle = state machine states):

```
idea        → not yet in system (TODO.md only)
backlog     → queued (in BACKLOG.json, no contract yet)
exploring   → planning + plan_review (draft contract, rough assertions)
specifying  → spec (assertions being formalized, tests being written)
implementing → implementation (assertions locked, code being written)
verifying   → verification (assertions being checked against implementation)
shipping    → docs + ready_to_ship (docs updated, PR created)
shipped     → shipped (full contract protection)
deprecated  → deprecated (migration required)
```

`state_machine.py` is refactored to read state from contract YAML instead of FEATURES.md status field. Transition rules, gate checks, and forward/regression tables all apply to these states. The contract IS the state record.

### D3: Tasks Are Trackable Process Artifacts
Tasks live in the **plan file** (`.agentic/work/F-XXXX/plan.md`) but are **trackable by the system**, especially for autonomous work:

```yaml
# .agentic/work/F-XXXX/tasks.yaml (separate from contract)
feature: F-0003
tasks:
  - id: T-001
    description: "Set up spec/ directory scaffolding"
    assertions: [AC-001, AC-004]
    status: done
    completed_at: 2026-03-22T14:00:00Z

  - id: T-002
    description: "Implement ag implement gate"
    assertions: [AC-002]
    status: in_progress
    started_at: 2026-03-22T15:00:00Z
```

- Contract = permanent spec (what must be true). Never cluttered with ephemeral work.
- Tasks = process tracking (what to do next). Lives in work directory, cleaned up after shipping.
- `ag next` reads tasks.yaml to show what's next within the current feature.
- Autonomous engine reads tasks.yaml to know which task to work on.
- Each task maps to assertions it satisfies → completion is verifiable.
- Scripts manage tasks: `ag task add F-0003 "description" --assertions AC-001,AC-004`

### D4: One-Go Migration, Small Verifiable Phases
No dual systems. Each phase is a complete, self-contained change that can be verified before moving to the next. The key insight: **each phase produces a working system**, just incrementally closer to the target.

- Phase 0: Analysis only (no code changes)
- Phase 1: New tooling added (contract parser, commands, verification runner) — old system still works, new tooling is additive
- Phase 2: Contracts written alongside old AC files — both exist but new contracts are the authoritative source, old ACs archived
- Phase 3: Big switchover — all ag commands, engine, paths updated in ONE phase to use contracts. Old files archived. No in-between state.
- Phase 4-5: Polish and extend

Phase 3 is the critical one. It must be planned carefully with a clear execution order, and verified after each sub-step. But it's ONE switchover, not a gradual dual-system migration.

### D5: NFRs as Cross-Cutting Contracts
NFRs get their own contract type: `spec/contracts/NFR-0001.yaml`. Structure similar to feature contracts but assertions apply across multiple features:

```yaml
id: NFR-0001
name: Instruction File Size Limit
type: nfr
applies_to: all  # or [F-0003, F-0005, ...] for scoped NFRs

assertions:
  - id: NFR-001-A01
    text: "Constitution-layer instruction files < 100 lines"
    type: structural
    verify: "wc -l < 100 .agentic/lib/agents/claude/CLAUDE.md"
    tests: [tests/infrastructure/structural/S08_claude_md_under_100_lines.sh]
```

Feature contracts reference NFRs via `nfr_refs: [NFR-0001]`. `ag contract check` verifies both feature and NFR assertions. Cross-cutting constraints are first-class, not afterthoughts.

### D7: Machine-Oriented YAML, Human Docs On-Demand
YAML contracts are optimized for **machine consumption only** — no formatting compromises for human readability. Human-readable documentation is generated on-demand or on a regular schedule under `docs/` (e.g., `docs/specs/` or `docs/features/`). This means:
- Contracts can use terse field names, dense assertion formats, and machine-optimal structure
- Human docs are rendered views: formatted markdown with descriptions, scenarios, status badges
- `ag contract docs` (or similar) generates/refreshes the human-readable versions
- The YAML is the source of truth; the docs are derived artifacts (like API docs from OpenAPI)

### D6: Minimal Valid Contract (Progressive Disclosure)
Required fields only: `id`, `name`, `lifecycle`, `description`, one assertion. Everything else defaults:

```yaml
# Minimal valid contract — all you need to start
id: F-0099
name: Cool New Feature
lifecycle: exploring
description: "Does the thing"
assertions:
  - id: AC-001
    text: "The thing works"
```

Defaults: `protection: none`, `category: uncategorized`, `profile: both`, `consolidated_from: []`, `nfr_refs: []`, `migrations: []`, `scenarios: []`, `tags: []`. The script `ag contract set` adds fields as needed. The parser fills in defaults for missing fields.

---

## Effort Estimate

| Phase | Sessions | Risk | Dependencies |
|---|---|---|---|
| Phase 0: Consolidation & Triage | 2-3 | Low (analysis + documentation) | None |
| Phase 1: Contract Infrastructure | 2 | Low (new code, nothing changes) | Phase 0 |
| Phase 2: Contract Writing | 4-6 | Medium (content quality) | Phase 1 |
| Phase 3: Migration & Archive | 2-3 | High (300+ file updates) | Phase 2 |
| Phase 4: Protection & Cleanup | 2 | Medium (behavioral changes) | Phase 3 |
| Phase 5: User Project Support | 1-2 | Low (templates + docs) | Phase 3 |
| **Total** | **13-18** | | |

Phase 0-2 are additive (nothing breaks). Phase 3 is the big switchover. Phase 4-5 polish.
