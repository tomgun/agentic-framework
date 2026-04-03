# Backlog & TODO Reorganization After Major Refactoring

## Context

After shipping F-005 (Hierarchy + Decomposition + Renumber), F-031 (YAML Contracts), and the state machine hardening, the tracking files have accumulated stale entries. The TODO inbox has 93 items (many reference pre-consolidation state), HUMAN_NEEDED has ~34 entries referencing merged PRs, and the backlog needs minor reordering. This plan cleans up all three.

**Goal**: Close what's clearly done/obsolete, flag what needs investigation, reorder the backlog, and leave the inbox in an honest state.

---

## Phase 1: HUMAN_NEEDED Cleanup

**Problem**: 34 entries (HN-0036 through HN-0069) sit between the "Active items" header and the "Resolved" section. All reference PRs that are already merged. The "_No active items_" text at line 14 is correct but the entries below it are structurally orphaned.

**Action**: Run `ag sync` (it has auto-clear for merged PRs via `gh pr view`). If that doesn't clear them all (e.g., no `gh` available in this env), bulk-move them to the Resolved section with "Outcome: PR merged, 2026-03-25".

**File**: `.agentic/HUMAN_NEEDED.md`

---

## Phase 2: TODO Triage

### Tier 1: Close immediately — verified done/obsolete/duplicate (7 items)

| TODO | Verdict | Reason |
|------|---------|--------|
| **T-0014** | OBSOLETE | "Verify shipped ACs for F-0131–F-0135" — these legacy IDs were consolidated into F-001/F-002/F-004/F-025/F-026. Their ACs are now YAML contracts. |
| **T-0044** | DONE | "Post-merge dogfooding workflow" — shipped as F-0226, consolidated into DEV-003. |
| **T-0045** | DONE | "Collision-proof feature IDs" — shipped as F-0193, consolidated into F-003. 3-digit sequential renumbering further reduces collision risk. |
| **T-0056** | DONE | "Plan file naming regression" — verified fixed. `plan-scan.sh` line 218 now uses `$(date +%Y-%m-%d)-${primary_id}-plan.md`. |
| **T-0059** | DUPLICATE | "Configurable DoD per task type" — exact duplicate of backlog position 2 (task on F-002). |
| **T-0066** | DUPLICATE | "Support for protected main branch" — exact duplicate of backlog F-035. |
| **T-0050** | OBSOLETE | "Spec/backlog status drift" — `ag sync` now cross-checks FEATURES.md status vs BACKLOG.json. The contract system adds a third authoritative source. The original concern (silent divergence with no detection) was addressed. |

### Tier 2: Investigate during execution — quick verification before closing (5 items)

| TODO | What to check | Close if... |
|------|--------------|-------------|
| **T-0038** | "Visual verification for tiered verify loop" — was this absorbed into F-030's contract? Check if any AC covers screenshot/visual testing. | ...no AC covers it. If so, keep as valid enhancement idea. |
| **T-0039** | "E2E scaffolding — discover.py detection, setup guide" — vague. Check if `ag init` + discover.py already covers this. | ...the described functionality already exists in current scaffolding. |
| **T-0060** | "docs.sh --validate content classification" — F-0207 consolidated into F-012, but does docs.sh still exist with the same interface? | ...docs.sh was replaced or the enhancement no longer makes sense. |
| **T-0061** | "docs.sh cache scan results" — same context as T-0060. | ...same as T-0060. |
| **T-0058** | "TDD Mode enforcement" — is `tdd_mode.md` still present? Was any of this wired up during the v2 refactor? | ...it was wired up or the file was removed. |

### Tier 3: Keep — still valid but context has shifted (6 items worth noting)

| TODO | Note |
|------|------|
| **T-0032** | Cross-feature semantic checks — NOT obsolete. YAML contracts have structural assertions, not semantic cross-feature analysis. `operations.sh`, `nfr-coverage.sh` have some overlap but don't cover the full vision (terminology consistency, contradiction detection). Keep. |
| **T-0075** | ID centralization to other entity types — still valid. Renumbering only changed F-XXXX/DEV-XXXX patterns. T-XXXX, HN-XXXX, NFR-XXXX, I-XXXX are still ad-hoc. Keep, but lower priority since the main pain (feature IDs) is solved. |
| **T-0086** | Phase 3 spec protection audit — **NOT obsolete, still a live bug**. Verified: `context-for-role.sh` has 3 references to deleted files (ALWAYS_INJECT, guidelines/core-rules, checklists/). 4 ag commands degrade. YAML contracts replaced AC files but the context-loading system wasn't updated. Keep and consider promoting. |
| **T-0087** | AC check-off timing — the markdown checkbox model is gone, but the broader concern (evidence should travel with code, not be recorded post-merge) applies to contract assertion results too. Keep as process improvement idea. |
| **T-0090** | Remove plan.md from work/ artifact instructions — **NOT obsolete**. Verified: CLAUDE.md template still says "Write artifacts to `.agentic/work/F-XXXX/`: `plan.md`, `spec.md`, `review.md`, `journal.md`". These are never read by CLI. Valid cleanup. |
| **T-0091** | Same scope as T-0090 — merge into T-0090 rather than closing independently. |

### Tier 4: Keep as-is — clearly still valid (~40 items)

Grouped by theme (no changes needed):
- **Active bugs**: T-0077 (plan-scan duplicates), T-0078 (env leak), T-0093 (doc freshness gate too broad)
- **LLM test gaps**: T-0083, T-0084, T-0085
- **Hook infrastructure**: T-0068–T-0074, T-0076
- **Enhancement ideas**: T-0001, T-0002, T-0003, T-0021–T-0025, T-0029, T-0040, T-0041, T-0043, T-0052, T-0053, T-0062–T-0065, T-0067, T-0088, T-0089, T-0092

---

## Phase 3: Backlog Reorder

### Assessment of current items

| Pos | Item | Verdict |
|-----|------|---------|
| 0 | "Strengthen later state machine gates" (F-003 task) | **KEEP at 0** — verified: `state_machine.py` still defaults to advisory mode, no `--strict` flag exists. Still needed. |
| 1 | F-035 Protected Main Branch | **KEEP** — user-facing gap, hit today during `ag done`. |
| 2 | "Configurable DoD per task type" (F-002 task) | **MOVE DOWN** — lower urgency now that YAML contracts provide structure. |
| 3 | F-036 Workflow Definition File | **KEEP** — declarative workflow definition. |
| 4 | "E2E workflow integration test" (DEV-002 task) | **MOVE UP** — post-refactor confidence is highest leverage. |
| 5 | F-033 Project-Specific Customization Layer | KEEP |
| 6 | F-034 Project Customization Auto-Sync | KEEP (depends F-033) |
| 7 | "Design phase formalization" (F-004 task) | KEEP |
| 8 | F-037 MCP Coordination Server | KEEP — ADR-001 wave 5 |
| 9 | F-038 Multi-Repo Umbrella | KEEP (depends F-037) |
| 10 | F-039 Full Autonomous Scheduling | KEEP (depends F-037) |

### Proposed new order

| Pos | Item | Change |
|-----|------|--------|
| 0 | Strengthen state machine gates (F-003 task) | unchanged |
| 1 | F-035 Protected Main Branch | unchanged |
| 2 | **Doc freshness gate scoping fix** (F-012 task) | **PROMOTE from T-0093** — active bug, forces fake markers |
| 3 | E2E workflow integration test (DEV-002 task) | moved up from 4 |
| 4 | F-036 Workflow Definition File | moved from 3 |
| 5 | F-033 Project-Specific Customization Layer | unchanged |
| 6 | F-034 Project Customization Auto-Sync | unchanged |
| 7 | Configurable DoD (F-002 task) | moved down from 2 |
| 8 | Design phase formalization (F-004 task) | moved from 7 |
| 9 | F-037 MCP Coordination Server | unchanged |
| 10 | F-038 Multi-Repo Umbrella | unchanged |
| 11 | F-039 Full Autonomous Scheduling | unchanged |

**Net change**: +1 item (T-0093 promoted), "Configurable DoD" and "E2E test" swap regions, everything else stays.

---

## Phase 4: Execution Steps

1. **`ag sync`** — auto-clear merged HN entries
2. **Edit TODO.md** — strikethrough + close reason for 7 Tier 1 items. Merge T-0091 into T-0090.
3. **Investigate 5 Tier 2 items** — quick grep/read checks, close if confirmed
4. **Edit BACKLOG.json** — reorder per Phase 3 table, add T-0093 as promoted task
5. **`ag flush --features`** — commit all state changes

**Files modified**:
- `.agentic/HUMAN_NEEDED.md` — move ~34 entries to Resolved
- `.agentic/TODO.md` — close 7-12 items, merge T-0091→T-0090
- `.agentic/BACKLOG.json` — reorder + add 1 promoted item

---

## Verification

- `ag backlog list` shows new ordering with T-0093 at position 2
- Active TODO count drops by 7-12
- `grep "^### HN-" .agentic/HUMAN_NEEDED.md` between Active and Resolved sections returns 0
- No items reference features that no longer exist without explanation
