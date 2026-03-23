# FEATURES
<!-- spec-format: features-v0.4.0 -->

**Purpose**: A human + machine readable registry of features with stable IDs, status, and YAML contract specifications.

📖 **For detailed format documentation, see:** `.agentic/spec/FEATURES.reference.md`

---

## Quick Reference

**Status**: `planned` | `specced` | `criteria_set` | `tests_written` | `implementing` | `verified` | `documented` | `committed` | `shipped` | `deprecated`
- Backward-compat alias: `in_progress` is accepted as equivalent to `implementing`

**Specifications**: Each feature has a YAML contract in `spec/contracts/F-####.yaml` with machine-verifiable assertions.
- Create: `ag contract create F-####` or `ag spec F-####`
- Check: `ag contract check F-####`
- List: `ag contract list`

**Feature template** (copy/paste when adding features):

```markdown
## F-####: FeatureName

**Status**: planned | **Category**: domain
**Contract**: [`spec/contracts/F-####.yaml`](contracts/F-####.yaml)

Description of what this feature does.
```

---

## Features

<!-- Add feature entries below, most recent first -->
