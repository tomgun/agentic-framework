# Plan: Backlog Cleanup Post-Consolidation

## Context

The backlog has 14 items, all typed as `"type": "feature"` with F-XXXX IDs. Two problems:

1. **None of the 14 F-XXXX IDs exist in the current FEATURES.md** (post F-0302 consolidation). `ag implement` will fail with "BLOCKED: F-XXXX not found in FEATURES.md", forcing agents to create new entries — re-fragmenting the registry.

2. **Many items are improvements to existing shipped features, not new capabilities**. Having them as F-XXXX features triggers the full lifecycle (plan, spec, AC, implement, verify, ship) when they should be scoped as work ON existing features.

3. **F-0213** was explicitly marked "merge into F-0302 scope" in CONSOLIDATION_MAP.md. F-0302 shipped. F-0213 is dead weight.

## Classification of Each Backlog Item

### DROP (1 item)
| ID | Name | Reason |
|----|------|--------|
| F-0213 | Unified Work Queue & Feature Registry Redesign | Explicitly merged into F-0302 scope (CONSOLIDATION_MAP.md line 65). F-0302 shipped. No plan exists. |

### CONVERT TO TASK (4 items) — improvements to existing features
| ID | Name | Owner Feature | Rationale |
|----|------|--------------|-----------|
| F-0223 | Later State Machine Gates Strengthening | F-0004 (Feature Tracking & Lifecycle) | Strengthening existing gates, not new capability. No plan. |
| F-0210 | Configurable Definition of Done per Task Type | F-0003 (Spec-Driven Development) | Configurability of existing DoD, not new capability. No plan. |
| F-0227 | End-to-End Workflow Integration Test | F-0122 (Testing Infrastructure) | Test infrastructure work, not user-facing. No plan. F-0215 `ag auto verify-framework` partially covers this. |
| F-0233 | Design Phase Formalization | F-0120 (Plan & Design Review) | Formalizing existing design phase. No plan. |

### KEEP AS FEATURE (9 items) — genuinely new capabilities
| ID | Name | Existing Plan? | Notes |
|----|------|---------------|-------|
| F-0193 | Collision-Proof Feature IDs | Yes, APPROVED | Ready for implementation |
| F-0243 | Complexity Tier Experiments | No | ADR-001 roadmap item |
| F-0220 | Protected Main Branch Support | **Misfiled** (plan is actually about doc enforcement, not branch protection) | Needs fresh plan |
| F-0211 | Project-Specific Customization Layer | No | Big enough for own lifecycle — new user-facing capability |
| F-0212 | Project Customization Auto-Sync | No | Related to F-0211, distinct deliverable |
| F-0228 | Workflow Definition File | No | Declarative workflow.yaml — genuinely new |
| F-0230 | MCP Coordination Server | No | ADR-001 Section 4, distinct from F-0185 HTTP JSON-RPC |
| F-0231 | Multi-Repo Umbrella | No | ADR-001 Section 3 |
| F-0232 | Full Autonomous Scheduling | No | ADR-001 Section 6 |

### Misfiled Plan: F-0220
`2026-03-19-F-0220-plan.md` is titled "Structural Doc Update Enforcement" — it's doc enforcement work (F-0118 scope), not protected main branch support. **Verified: the content was already shipped** — `docs.sh --check-freshness` and the gate in `done.sh` both exist. The plan file will get a misfiling note; F-0220 has no real plan and needs one from scratch.

## Proposed New Backlog

```
Pos  Type     ID/Desc                                                      Refs
───  ───────  ────────────────────────────────────────────────────────────  ──────
 0   feature  F-0193 Collision-Proof Feature IDs                           plan: APPROVED
 1   feature  F-0243 Complexity Tier Experiments                           —
 2   task     Strengthen later state machine gates (advisory→blocking)     F-0004
 3   feature  F-0220 Protected Main Branch Support                         plan: needs rewrite
 4   task     Configurable Definition of Done per task type                F-0003
 5   feature  F-0228 Workflow Definition File                              —
 6   task     E2E workflow integration test (full lifecycle)               F-0122
 7   feature  F-0211 Project-Specific Customization Layer                  —
 8   feature  F-0212 Project Customization Auto-Sync                       depends: F-0211
 9   task     Design phase formalization                                   F-0120
10   feature  F-0230 MCP Coordination Server                               ADR-001 wave 5
11   feature  F-0231 Multi-Repo Umbrella                                   ADR-001 wave 5
12   feature  F-0232 Full Autonomous Scheduling                            ADR-001 wave 5
```

13 items (9 features, 4 tasks). F-0213 dropped.

**Ordering rationale**: F-0193 first (approved plan, foundational — fixes ID system before more features use it). F-0243 next (was already current). Tasks interspersed near related features. F-0211/F-0212 grouped together (F-0212 depends on F-0211). ADR-001 wave 5 items at the end (long-term).

## Implementation Steps

### Step 1: Add 9 new entries to FEATURES.md
Add minimal planned entries for: F-0193, F-0211, F-0212, F-0220, F-0228, F-0230, F-0231, F-0232, F-0243.
Keep legacy IDs (they're referenced in plans, ADR-001, CONSOLIDATION_MAP).

Format per entry (matching consolidated style):
```markdown
## F-XXXX: Title

**Status**: planned | **Category**: <category> | **Profile**: <profile>

<1-line description from archive>
```

Also update the category table at the top — add a `Planned` column, update counts. No YAML contracts needed for planned features (contracts are created at implementation time).

**Files**: `.agentic/spec/FEATURES.md`

### Step 2: Rewrite BACKLOG.json
Write the full 13-item JSON array directly (not via `ag backlog add` commands — simpler and avoids 13 sequential CLI calls). 9 features use `"type": "feature"` with IDs; 4 tasks use `"type": "task"` with descriptions. Include `"notes": "Originally F-XXXX"` on each task for traceability.

Feature items include `"depends_on"` where applicable (F-0212 depends on F-0211, F-0231 depends on F-0230, F-0232 depends on F-0230).

**Note**: Task items have no `"id"` field, so they can't be removed via `ag backlog remove <id>` — only by editing BACKLOG.json directly or adding position-based removal later. This is a known UX gap in the backlog system, not a blocker.

**Files**: `.agentic/BACKLOG.json`

### Step 3: Update CONSOLIDATION_MAP.md
Update "Planned Features" table: mark F-0213 as "subsumed by F-0302", note task conversions.

**Files**: `.agentic/spec/CONSOLIDATION_MAP.md`

### Step 4: Fix misfiled F-0220 plan
Add a header note to `2026-03-19-F-0220-plan.md` explaining the content is doc enforcement (F-0118 scope), not protected main branch support. The plan is preserved but marked as misfiled.

**Files**: `.agentic/journal/plans/2026-03-19-F-0220-plan.md`

### Step 5: Update STATUS.md focus
Run `status.sh focus` to reflect new current item (F-0193).

**Files**: `.agentic/STATUS.md` (via script)

## Reference Preservation
- F-0193 plan (`2026-03-17-F-0193-plan.md`): Preserved, still valid, APPROVED
- F-0220 plan (`2026-03-19-F-0220-plan.md`): Preserved with misfiling note
- All other items: No plans exist, nothing to preserve
- Archive at `docs/archive/FEATURES-v0.72.md`: Untouched, full history remains

## Verification
1. `ag backlog list` shows 13 items with correct types and ordering
2. `grep "^## F-0193:" .agentic/spec/FEATURES.md` finds the entry (and same for all 9 features)
3. CONSOLIDATION_MAP.md "Planned Features" section matches new classifications
4. `grep -r "F-0213" --include="*.json" --include="*.md" . | grep -v archive | grep -v CONSOLIDATION` — no orphaned refs to dropped item
5. FEATURES.md category table counts are accurate (Total should be 42: 33 existing + 9 planned)
