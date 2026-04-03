# Plan: Design Document Traceability

## Context

When users create big design documents (ADRs, roadmaps, kickoff visions, epic plans), those documents spawn multiple features over days/weeks. Nothing tracks completion against the original design. Users re-describe ideas because they forgot what was already planned. The user asked: "do we have a mechanism to come back (and to remember to come back) to the original plan and review if everything has been specced and implemented?"

## Why Not Auto-Scan for F-IDs

The initial approach was to grep design docs for F-XXXX references. Critical review found this doesn't work:
- **ADR-001** (the motivating example) describes features in prose. F-IDs get assigned later during decomposition — they don't exist when the design doc is written.
- **Per-feature plans** (28 of 88) trivially reference their own F-ID — noise, not signal.
- **Reference docs** like HOW_IT_WORKS.md contain 93 F-IDs — documentation, not design intent.
- **OVERVIEW.md** contains zero F-IDs.

The link between "ADR-001 said we need components" and "F-0179 implements component registry" exists only in human memory — which is exactly the problem.

## Approach: Explicit Annotation + Dashboard Reminder

Two complementary mechanisms:

### 1. `**Source**:` annotation on features (the linkage)

When features are created from a design document, the agent annotates the FEATURES.md entry:

```markdown
## F-0179: Component Registry
**Status**: shipped
**Source**: spec/adr/ADR-001-multi-component-architecture.md
```

This creates the link that auto-scan can't infer. The annotation happens at feature creation time (during `ag decompose`, `ag kickoff`, or manual planning) — when the agent has both the design doc and the new feature in context.

**Why `Source` not `Design`**: "Source" is clearer — it answers "where did this feature come from?" It's also consistent with how `**Parent**:` already works for epics.

### 2. `design-trace.sh` tool (the tracker)

A shell script that reads `**Source**:` annotations from FEATURES.md and builds a reverse index: design doc → features → statuses → completion %.

**Modes** (v1, minimal):
- `design-trace.sh` — Summary: each source doc with completion %
- `design-trace.sh --doc <path>` — Single document's features and statuses
- `design-trace.sh --quiet` — One-line for dashboard integration

**Algorithm**:
1. Grep FEATURES.md for `**Source**:` fields
2. Group features by source document
3. Look up each feature's status
4. Compute shipped/total per source
5. Report only incomplete sources (unless `--all`)

**Output example**:
```
Design Traceability Report

  spec/adr/ADR-001-multi-component-architecture.md
    Features: 6 linked
    Shipped:  4/6 (67%)
    Pending:  F-0186 (planned), F-0188 (implementing)

  .agentic/journal/plans/2026-03-08-epic-quality-plan.md
    Features: 4 linked
    Shipped:  4/4 (100%) ✓

Summary: 1 source doc(s) with pending features
```

### 3. Dashboard line (the reminder)

Conditional line after NFR health, only when incomplete sources exist:

```
📐 Design trace    1 doc(s) with pending features — run: design-trace.sh
```

### 4. Instruction integration (the creation-time prompt)

The key to making this work: agents must be told to add `**Source**:` when creating features from design docs. Three integration points:

- **`ag decompose`**: When decomposing an epic, child features inherit `**Source**: <epic's source or epic's AC file>`
- **`ag kickoff --approve`**: When promoting staged features, record `**Source**: .agentic/OVERVIEW.md` (or the kickoff vision path)
- **memory-seed.md**: Trigger — when creating a feature that references a design doc, add `**Source**: <path>`
- **planning-features skill**: Step guidance — "If this feature derives from a design document (ADR, roadmap, epic plan), add `**Source**: <path>` to the FEATURES.md entry"

## Files to Modify

| File | Change | Lines |
|------|--------|-------|
| `.agentic/lib/tools/design-trace.sh` | **NEW** — core tool | ~100 |
| `.agentic/lib/tools/feature.sh` | Add `source` to field list (copy `parent` pattern) | ~5 |
| `.agentic/lib/tools/query_features.py` | Add `source` to parser elif chain | ~2 |
| `.agentic/lib/tools/dashboard.sh` | Conditional design trace line | ~5 |
| `.agentic/lib/auto/epic.py` | In `create_child_features()`, propagate parent's Source to children | ~5 |
| `.agentic/lib/init/memory-seed.md` | Add Source annotation trigger | ~3 |
| `tests/validate_framework.sh` | Structural test: design-trace.sh exists | ~3 |

**Total**: 1 new file + 6 modified (~120 new lines)

## What This Does NOT Do (Intentional Scope Limits)

- **Does not auto-detect design docs** — requires explicit `**Source**:` annotation. This is honest: the link between prose design and feature IDs can't be auto-inferred.
- **Does not block anything** — purely advisory reporting.
- **Does not modify sync.sh** — dashboard line is sufficient for session-start reminders. sync.sh can be a follow-up.
- **Does not add `--json` or `--feature` modes** — v1 is minimal. Add later if needed.

## Bootstrapping Existing Features

For the current framework repo, we'd need to backfill `**Source**:` on features that came from ADR-001, ADR-002, and major epic plans. This is a one-time manual effort (~20 features) but validates the tool immediately. Can be done as part of the implementation PR.

## Verification

1. Add `**Source**: spec/adr/ADR-001-multi-component-architecture.md` to 3-4 features in FEATURES.md
2. `bash design-trace.sh` reports ADR-001 with correct shipped/total
3. `bash design-trace.sh --quiet` returns non-empty when incomplete sources exist
4. `bash design-trace.sh --quiet` returns empty when all source-linked features are shipped
5. `bash dashboard.sh 2>/dev/null` includes 📐 line when incomplete sources exist
6. `bash feature.sh F-XXXX source spec/adr/ADR-001.md` sets the field
7. Projects with no `**Source**:` annotations: tool produces empty output, exits 0
8. `validate_framework.sh` passes
