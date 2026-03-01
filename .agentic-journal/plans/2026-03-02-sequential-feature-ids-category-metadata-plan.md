# Plan: Fix Feature Numbering — Sequential IDs + Category Metadata

## Context

The current feature numbering uses fixed 10-slot ranges per category (Core=F-0001-0010, Quality=F-0011-0020, etc.). Three categories are already full (Core, Developer Experience, Design Principles), and 47 features sit in an "overflow" range (F-0101+) with no category meaning. 41% of features have already lost the category-in-ID benefit. The system needs a scheme where categories can grow without hitting ceilings.

## Decision: Drop category encoding from IDs

**Keep F-XXXX sequential. Category becomes metadata, not a range.**

Why this wins over alternatives:
- **Zero migration cost** — 559 files reference F-XXXX patterns, 114 acceptance files, 40 plans. Renumbering is a multi-day, high-risk project.
- **The category-in-ID benefit is already broken** — 41% of features are in overflow. Nobody memorizes the 10-range lookup table; people read the feature name.
- **Tooling already works this way** — `quick_feature.sh` allocates purely sequentially. Category ranges were never enforced by code.
- **Unlimited growth** — F-9999 gives 9,999 features (currently 114 after heavy development). No per-category ceiling.

Alternatives considered and rejected:
- Wider fixed ranges (F-01xx): catastrophic migration, still hits ceilings eventually
- Category prefix (CORE-001): breaks all regex/tooling, massive migration
- Hybrid (old + new format): permanent dual-format complexity tax
- Sparse ranges with rebalancing: high-risk rebalance operations, ranges shift unpredictably

## Changes

### 1. Update FEATURES.md category table
Replace the fixed-range table with a category summary that doesn't imply ranges:

```
| Category | Count | Shipped | In Progress | Planned |
|----------|-------|---------|-------------|---------|
| Core     | 11    | 10      | 1           | 0       |
| Quality  | 7     | 7       | 0           | 0       |
...
```

Remove the `(F-0001-0010)` range notation from category headers.

**File:** `spec/FEATURES.md`

### 2. Add `**Category**` field to feature entries
Each feature in FEATURES.md gets a `**Category**: <name>` metadata field (alongside existing Status, Priority, etc.).

**File:** `spec/FEATURES.md` — backfill all 114 features (mechanical: the existing range mapping tells us which category each belongs to, overflow features get categorized by their actual topic)

### 3. Add `--category` flag to quick_feature.sh
When creating new features, accept `--category core` to auto-populate the category field.

**File:** `.agentic/tools/quick_feature.sh` (~line 56-66)

### 4. Add category filtering to query_features.py
Parse the `**Category**:` field, add `--category=core` filter option.

**File:** `.agentic/tools/query_features.py`

### 5. Update feature_stats.py grouping
Group by metadata category instead of ID range.

**File:** `.agentic/tools/feature_stats.py` (if it exists) or equivalent stats tooling

### 6. Update documentation
- Remove range-based category references from FEATURES.md preamble
- Update spec schema docs to include Category as a standard field
- Update any "how to add a feature" instructions

**Files:** `spec/FEATURES.md`, `.agentic/spec/SPEC_SCHEMA.md`, `docs/naming_and_lifecycle.md` (if exists)

## Verification

1. Run `bash tests/validate_framework.sh` — must pass
2. Run `bash .agentic/tools/quick_feature.sh --category core "Test Feature"` — verify it creates a feature with category metadata
3. Verify `query_features.py` can filter by category
4. Spot-check that the FEATURES.md category summary table counts match the actual features
