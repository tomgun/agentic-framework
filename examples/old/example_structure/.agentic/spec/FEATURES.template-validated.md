---
# YAML Frontmatter: Machine-readable source of truth
# Validated against .agentic/schemas/feature.schema.json
# IMPORTANT: Keep synchronized with Markdown below

features:
  - id: F-0001
    name: Example feature name
    status: planned  # planned | in_progress | shipped | deprecated
    parent: null  # null or F-#### for hierarchy
    dependencies: []  # List of F-#### that must be complete first
    complexity: M  # S | M | L | XL
    prd: spec/PRD.md#requirements
    requirements: [R-0001]
    nfrs: []  # List of NFR-#### if feature has specific constraints
    acceptance: spec/acceptance/F-0001.md
    verification:
      accepted: false  # true | false
      accepted_at: null  # YYYY-MM-DD or null
    implementation:
      state: none  # none | partial | complete
      code: []  # List of file paths
    tests:
      strategy: unit  # unit | integration | e2e | manual | mixed
      unit: todo  # todo | partial | complete | n/a
      integration: n/a
      acceptance: todo
      perf: n/a
    technical_debt: null  # string or null
    lessons: []  # List of strings or links to LESSONS.md
    notes: Anything agents should remember
---

# FEATURES (Template with Validation)

**Purpose**: A **single source of truth** for features - human-readable AND machine-validatable.

**IMPORTANT**: The YAML frontmatter above is the canonical data. The Markdown below is for human readability and additional context.

## How This Works

### Single Source of Truth
- ✅ **ONE file** contains both structured data (YAML) and human docs (Markdown)
- ✅ YAML frontmatter is the **authoritative source** (validated automatically)
- ✅ Markdown section provides context, explanations, diagrams

### Automatic Validation
Catches errors immediately:
- ✅ Typos in field names (`Statuss:` → Error!)
- ✅ Invalid values (`Status: done` → Error! Must be `planned|in_progress|shipped|deprecated`)
- ✅ Missing required fields
- ✅ Wrong ID formats (`F-1` → Error! Must be `F-####`)
- ✅ Invalid dates, wrong types

**Run validation:**
```bash
python3 .agentic/tools/validate_specs.py
```

### IDE Support (Optional)
Install VS Code "YAML" extension and add to `.vscode/settings.json`:
```json
{
  "yaml.schemas": {
    "./.agentic/schemas/feature.schema.json": ["spec/FEATURES.md"]
  }
}
```

Benefits:
- Autocomplete field names
- Inline validation errors
- Hover documentation
- Jump to schema definition

## Terminology (requirement vs feature)
- **Feature (F-####)** is canonical here: a ship-able capability we implement and validate.
- **Requirements are optional**:
  - If you use requirements, treat them as outcome/contract statements (often in `spec/PRD.md`) and link them from features.
  - If you don't, leave the "Requirements" field empty and rely on the feature acceptance criteria file instead.

## Status vocabulary
- `planned` | `in_progress` | `shipped` | `deprecated`

## How to reference
- Feature IDs: `F-0001`, `F-0002`, …
- Requirement IDs (optional, from PRD): `R-0001`, …
- NFR IDs (optional): `NFR-0001`, …
- Task IDs (optional): `T-0001`, …

## Feature index (optional)
- F-0001: Example feature name
- F-0002:

---

## F-0001: Example feature name
- Parent: none  <!-- or F-0000 for hierarchy -->
- Dependencies: none  <!-- F-0002 (complete), F-0003 (partial) -->
- Complexity: M <!-- S | M | L | XL -->
- Technical debt: <!-- links to LESSONS.md or notes -->
- Status: planned
- PRD: spec/PRD.md#requirements
- Requirements: R-0001
- NFRs: none  <!-- or NFR-#### list -->
- Acceptance: spec/acceptance/F-0001.md
- Verification:
  - Accepted: no       <!-- no | yes -->
  - Accepted at:       <!-- YYYY-MM-DD -->
- Implementation:
  - State: none  <!-- none | partial | complete -->
  - Code: <!-- file paths -->
- Tests:
  - Unit: todo  <!-- todo | partial | complete | n/a -->
  - Integration: n/a
  - Acceptance: todo
  - Perf/realtime: n/a
- Test strategy: unit <!-- unit | integration | e2e | manual -->
- Lessons/caveats:
  - <!-- link to spec/LESSONS.md or notes -->
- Notes:
  - Anything agents should remember

---

## Updating Features

### When using frontmatter (recommended):
1. **Update YAML first** (source of truth)
2. **Update Markdown** (for humans)
3. **Run validation**: `python3 .agentic/tools/validate_specs.py`
4. **Fix errors** if any

### When NOT using frontmatter (legacy):
- Just update Markdown
- Validation tools will skip

## Migration from Plain Markdown

**Don't need to migrate all at once!**

1. **Keep using plain Markdown** - works fine
2. **Add frontmatter when ready** - copy data from Markdown to YAML
3. **Run validation** - catches errors immediately
4. **Keep both in sync** - YAML is source of truth

**Tools work with both formats.**

