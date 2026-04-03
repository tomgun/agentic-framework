# Capabilities

<!-- spec-format: features-v0.5.0 -->

**Purpose**: A human + machine readable registry of what this product can do — built, in progress, and planned.

This file is the **capability catalog**. Every significant capability should be registered here.

---

## Entry Formats

### Discovery (lightweight — no formal IDs)

```markdown
## Search
**Status**: built
Full-text product search with filters across name, category, price range.
Decisions: Used Elasticsearch over Postgres FTS for scale.
```

**Status values**: `built` | `in_progress` | `planned`

### Formal (full ceremony — F-XXXX IDs + contracts)

```markdown
## F-####: Search
**Status**: shipped | **Category**: domain
**Contract**: [`spec/contracts/F-####.yaml`](contracts/F-####.yaml)
Description of what this feature does.
```

**Status values**: `planned` | `specced` | `criteria_set` | `tests_written` | `implementing` | `verified` | `documented` | `committed` | `shipped` | `deprecated`
- Backward-compat alias: `in_progress` is accepted as equivalent to `implementing`

**Specifications**: Each feature has a YAML contract in `spec/contracts/F-####.yaml` with machine-verifiable assertions.
- Create: `ag contract create F-####` or `ag spec F-####`
- Check: `ag contract check F-####`

---

## Capabilities

<!-- Add capability entries below, most recent first -->
