# V2 Engine Architecture — Q&A Reference

**Date**: 2026-03-21
**Context**: Answers to architectural questions about how the v2 workflow engine presents features, manages backlogs, handles spec migrations, and supports autonomous execution.

---

## 1. How Are Features, Backlog, and Work Items Presented?

### Work Items (v2): Directory + YAML Per Feature

Each feature gets a directory at `.agentic/work/F-XXXX/` containing:

| File | Purpose | Required For Transition |
|------|---------|------------------------|
| `item.yaml` | Canonical state, metadata, append-only transition log | Always present |
| `plan.md` | Implementation plan (scope, approach, risks) | `planning → plan_review` |
| `review.md` | Dialectical review synthesis (Critic + Advocate) | `plan_review → spec` |
| `spec.md` | Acceptance criteria | `spec → implementation` |
| `verification.json` | Test results | `verification → docs` |
| `journal.md` | Per-feature session notes | Optional |
| `pr.md` | PR details | Created when shipping |
| `handoff.md` | Phase handoff notes | Optional |

**`item.yaml` structure**:
```yaml
id: F-XXXX
title: Feature Title
type: feature
status: implementation        # Current v2 state
mode: formal                  # formal | lean
profile: guided               # guided | hands_on | autonomous
priority: 0
created: 2026-03-20
updated: 2026-03-21
branch: feat/v2-workflow-engine
transitions:                  # Append-only audit log
  - {from: planning, to: plan_review, at: ..., by: agent, reason: ...}
  - {from: plan_review, to: spec, at: ..., by: agent, skipped: false}
```

### FEATURES.md (v1 Compatibility)

`FEATURES.md` remains as a human-readable registry. A sync hook (`features_sync.py`) auto-updates it on every v2 state transition using this mapping:

| v2 State | v1 Status |
|----------|-----------|
| idea | planned |
| queued | planned |
| planning | planned |
| plan_review | specced |
| spec | criteria_set |
| implementation | implementing |
| verification | verified |
| docs | documented |
| ready_to_ship | committed |
| shipped | shipped |

### Backlog (BACKLOG.json)

Ordered JSON array — position matters:

```json
[
  {
    "type": "feature",          // or "task" for ad-hoc work
    "id": "F-0240",
    "description": "Framework Execution Log",
    "added_at": "2026-03-20T14:38:31Z",
    "added_by": "agent",
    "became_current_at": "2026-03-20T14:38:31Z",
    "depends_on": ["F-0239"],   // optional
    "refs": ["path/to/plan.md"] // optional
  }
]
```

- Position 0 = current work (`became_current_at` set)
- Position 1+ = queued
- `ag next` returns position 0
- `ag backlog done` validates feature is shipped before removing

---

## 2. TODOs, Issues, and Backlog Promotion

### Three Registries, One Queue

| Storage | Purpose | Item IDs | Backlog-able? |
|---------|---------|----------|---------------|
| **FEATURES.md** | Feature registry | F-XXXX | Yes — `backlog.sh add F-XXXX` |
| **ISSUES.md** | Bug/debt registry | I-XXXX | Indirect — create fix feature first |
| **TODO.md** | Idea inbox | T-XXXX | Indirect — triage to feature first |
| **BACKLOG.json** | Prioritized work queue | F-XXXX or task | N/A (is the queue) |

### Promotion Flow

```
Idea capture:   ag todo "description"         → TODO.md (T-XXXX)
Triage:         todo.sh triage T-0001 feature → FEATURES.md (F-XXXX)
Prioritize:     ag backlog add F-XXXX         → BACKLOG.json
Work:           ag implement F-XXXX           → picks from queue position 0
```

Ad-hoc tasks skip the feature registry:
```
Quick task:     ag backlog add --task "Research X"  → BACKLOG.json (type: "task")
```

Issues follow a similar path: identify bug → create feature for the fix → add to backlog.

---

## 3. State Machine: 10 States, Artifact-Gated Transitions

```
idea → queued → planning → plan_review → spec → implementation → verification → docs → ready_to_ship → shipped
                                                                                                    ↓
                                                                                              deprecated (terminal)
```

### Regression Transitions (Backward Movement)

The state machine explicitly supports going backward when specs or code need rework:

```yaml
- { from: implementation, to: spec, type: regression }       # Requirements changed mid-build
- { from: verification, to: implementation, type: regression } # Tests found code issues
- { from: verification, to: spec, type: regression }          # Tests found spec was wrong
- { from: ready_to_ship, to: implementation, type: regression } # Code review found issues
- { from: shipped, to: spec, type: regression }               # Post-ship spec revision needed
```

Regressions require an explicit `reason` and are audit-logged in `item.yaml`.

### Two Modes

| Aspect | Formal | Lean |
|--------|--------|------|
| Escape hatches | None — CLI hard-fails | Allowed, audit-logged |
| Skip transitions | None | `queued→implementation`, `planning→implementation`, etc. |
| Artifact requirements | Strict (every artifact required) | Minimal |
| Spec contract enforcement | Blocking | Advisory |

### Three Profiles (Gate Routing)

| Gate | hands_on | guided | autonomous |
|------|----------|--------|------------|
| plan_approved | human | human | AI (critical_agent) |
| spec_review | human | human | AI |
| code_review | human | AI | AI |
| verification_review | human | AI | AI |
| merge | human | human | human (or AI) |

---

## 4. Formal Spec Migrations

### Migration-Based Delta Tracking (F-0147)

When a shipped spec changes, the framework requires a **migration** — an atomic, versioned record of the change.

**Storage**: `.agentic/spec/migrations/` with sequential numbered files + `_index.json` registry.

**Each migration captures**:
- Migration ID (sequential)
- Date, author, type (feature/evolution/fix)
- Context & Why (problem/need)
- Changes (features added/modified/deprecated with F-XXXX IDs)
- Acceptance Criteria (testable)
- Rollback Plan (step-by-step undo)
- Related Files (audit trail)

**Commands**:
```bash
migration.sh create "Description"   # Create atomic spec change
migration.sh list                    # All migrations
migration.sh show <id>              # Read one
migration.sh search "term"          # Find migrations
migration.sh apply                  # Regenerate FEATURES.md from migrations
```

### Three Pre-Commit Gates (Structural Enforcement)

These are blocking checks in `pre-commit-check.sh` — not behavioral rules agents might forget, but hard gates that reject commits:

**Check 14: Shipped Spec Modification Requires Migration**
- Any edit to `spec/acceptance/F-XXXX.md` for a shipped feature MUST have a corresponding migration file staged
- Error: `❌ BLOCKED: Shipped feature F-XXXX acceptance criteria modified without migration`

**Check 15: Test File Deletion Protection**
- Cannot delete test files referenced by shipped feature acceptance criteria

**Check 16: Shipped Feature Status Downgrade Protection**
- Shipped features cannot have status downgraded (shipped → in_progress, etc.) without a migration

### Drift Detection (F-0098)

`drift.sh` detects misalignment between specs and code across multiple dimensions:

| Drift Type | What It Detects |
|-----------|-----------------|
| Status drift | Shipped feature with incomplete acceptance criteria |
| Code drift | AC completeness vs feature status mismatch |
| Test drift | Features with ACs but no test references |
| Doc drift | CONTEXT_PACK references to nonexistent files |
| Endpoint drift | API routes not mentioned in specs |
| Stale features | In-progress features with no activity 7+ days |

Wired into the state machine as an artifact check for `docs → ready_to_ship`.

### Five Protection Levels

1. **Initial draft** — rough ACs evolve during implementation
2. **Discovered markers** — `[Discovered]` prefix flags spec changes found during coding
3. **Migration creation** — formal delta tracking for shipped spec changes
4. **Pre-commit gates** — Checks 14-16 block commits violating contract
5. **Regression transitions** — state machine enforces backflow when spec must change

---

## 5. Autonomous End-to-End Pipeline

### One Command: Vision → Shipped

```bash
# From freeform vision (Claude decomposes into features automatically):
ag auto pipeline --vision "Build a todo app with auth and notifications"

# From pre-structured features (programmatic/test use):
ag auto pipeline --features-json '[...]' --epic-name "Platform"
```

**Sequence** (with `--vision`, adds a vision phase at the start):

1. **Kickoff** (`ag kickoff`): Vision → staging area (OVERVIEW.md, FEATURES.md stubs, AC files, BACKLOG.json)
2. **Promote**: Assign real feature IDs, link to epic, populate backlog in dependency order
3. **Schedule** (`AutonomousScheduler.run_epic`):
   ```
   Loop until all shipped or max_errors:
     Find unblocked features (available transitions)
     Skip review-blocked (non-blocking)
     For each unblocked feature:
       TaskRunner: per-AC → spawn Claude → implement → test → commit
       VerifyLoop: unit → integration → e2e tiers
       Create PR
       Gate check (critical_agent or human)
       If blocked: mark review_blocked, continue others
       If passed: transition to shipped
   ```
4. **Integration verification**: Cross-component tests before marking epic shipped

### Parallel Execution

```bash
ag auto epic F-0100 --parallel --max-parallel 3
```

Creates N worktrees, runs N features simultaneously with rolling slot management.

### Supporting Commands

```bash
ag auto task F-XXXX              # Single feature autonomous implementation
ag auto crunch [--features ...]  # Batch multi-feature
ag auto epic F-XXXX              # Epic execution loop
ag auto verify                   # Test-fix loop
ag auto verify-epic F-XXXX       # Integration verification
ag auto pipeline                 # Full vision → shipped
ag auto status / pause / resume  # Engine control
```

### Vision-to-Features (Automated)

With `--vision`, the pipeline spawns Claude to decompose freeform vision text into structured features_data automatically. It reads project context (STACK.md, CONTEXT_PACK.md, NFR.md) to inform the decomposition. The epic name and overview are derived from the vision output.

For programmatic/test use, `--features-json` still accepts pre-structured data directly.

---

## 6. Handoff Between Phases

There are no separate "handoff documents" — **the artifacts themselves are the handoffs**. The `TransitionOrchestrator` enforces this atomically:

1. Validate transition exists in `state_machine_af.yaml`
2. Check artifact preconditions (file must exist and be non-empty)
3. Check gate (routed by profile to human/AI/skip)
4. Update `item.yaml` with append-only transition log entry
5. Sync to FEATURES.md (backward compat)
6. Emit role prompt for next phase (JIT guidance)

The artifact preconditions create natural handoff points:
- Plan written → ready for review
- Review synthesized → ready for spec
- Spec locked → ready for implementation
- Tests exist → ready for verification
- Tests pass → ready for docs
- Docs current → ready to ship
- PR merged → shipped

---

## 7. Key Design Insight

The v1 approach relied on agents remembering the workflow from instruction files. The v2 approach makes **the CLI enforce the workflow structurally** — transitions are refused if artifacts are missing, specs can't be modified without migrations, and the state machine makes the process deterministic rather than behavioral.
