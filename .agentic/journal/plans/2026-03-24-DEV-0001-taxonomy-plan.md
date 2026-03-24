# Plan: Framework Feature Taxonomy — Capabilities vs. Dev Infrastructure

## Context

FEATURES.md currently treats all entries as peers with `F-XXXX` IDs, mixing user-facing capabilities with internal development tooling. The `F-` prefix carries semantic meaning: *Feature = something users adopt*. Internal infrastructure and research experiments are not features in that sense.

The fix has two parts:
1. **New ID namespace**: `DEV-XXXX` for all development infrastructure and research items
2. **Organizational grouping**: a parent container `DEV-0001` under which all internal items are grouped

Existing internal features (F-0122, F-0199, F-0243) keep their `F-` IDs — renaming would be disruptive. But they get marked with `Type:` + `Parent: DEV-0001` to make their nature visible. New internal items going forward get `DEV-XXXX` IDs.

> **Note on T-0089**: T-0089 (TODO) tracks user-defined custom prefixes (teams defining `AUTH-`, `PAY-`, etc. in their own projects). `DEV-` is distinct — it's a first-party framework namespace, like `NFR-`. T-0089 remains open and unaffected by this change.

**The three internal features being categorized:**
- **F-0122** Testing Infrastructure (validate_framework.sh, LLM tests, QA registry, simulation testing) — permanent infrastructure, parent: DEV-0001
- **F-0199** Instruction File Integrity (template/root file drift detection, `ag dogfood`) — permanent infrastructure, parent: DEV-0001
- **F-0243** Complexity Tier Experiments — time-bounded research, parent: DEV-0001

---

## Changes

### 1. Extend the ID schema to support `DEV-XXXX`

**`contract.schema.json`** — update `id` pattern:
```json
"pattern": "^(F|DEV|NFR)-[0-9]{4,}$"
```

Also update `parent` field pattern to allow `DEV-XXXX`:
```json
"pattern": "^(F|DEV|E)-[0-9]{4,}$"
```

### 2. Create parent container `DEV-0001`

**`.agentic/spec/FEATURES.md`** — add a new section before Legacy Archive:

```markdown
---

## Development Infrastructure

Work tracked here uses the same `ag` workflow as capabilities — specs, plans,
ACs, shipping ceremony. These are how the framework is built and validated.
Not user-facing.

| Type | Meaning |
|------|---------|
| `infrastructure` | Permanent internal tooling (maintained indefinitely) |
| `research` | Time-bounded experiment (concludes when question is answered) |

### DEV-0001: Framework Development Infrastructure

**Status**: ongoing | **Type**: meta

Organizational parent for all framework development tooling and research.

**Children**: F-0122, F-0199, F-0243
**Contract**: `spec/contracts/DEV-0001.yaml`
```

**`.agentic/spec/contracts/DEV-0001.yaml`** — create:

```yaml
id: DEV-0001
name: Framework Development Infrastructure
lifecycle: ongoing
profile: both
category: dev-infrastructure
tags: [meta, internal]
children:
  - F-0122
  - F-0199
  - F-0243
description: |
  Organizational parent for framework development tooling, QA infrastructure,
  and research experiments. Not a user-facing capability. Children use the full
  ag workflow for rigor while being clearly distinguished from capabilities.
assertions:
  - id: AC-001
    text: "DEV-0001 section exists in FEATURES.md"
    type: structural
    verify: "grep -q 'DEV-0001' .agentic/spec/FEATURES.md"
  - id: AC-002
    text: "Internal features have Type annotations in FEATURES.md"
    type: structural
    verify: "grep -q 'Type.*infrastructure\\|Type.*research' .agentic/spec/FEATURES.md"
  - id: AC-003
    text: "DEV-XXXX pattern is supported in contract schema"
    type: structural
    verify: "grep -q 'DEV' .agentic/lib/schemas/contract.schema.json"
```

### 3. Update the 3 existing FEATURES.md entries

In each entry, add `**Type**:` and `**Parent**:` to the metadata line:

**F-0122 Testing Infrastructure**
- Change `**Category**: quality` → `**Category**: dev-infrastructure`
- Add: `**Type**: infrastructure | **Parent**: DEV-0001`

**F-0199 Instruction File Integrity**
- Change `**Category**: agent-system` → `**Category**: dev-infrastructure`
- Add: `**Type**: infrastructure | **Parent**: DEV-0001`

**F-0243 Complexity Tier Experiments**
- Change `**Category**: core-workflow` → `**Category**: dev-infrastructure`
- Add: `**Type**: research | **Parent**: DEV-0001`

### 4. Update the category table at top of FEATURES.md

Add `Dev Infrastructure` row (3 children + DEV-0001). Adjust counts: remove F-0122 from `Quality`, F-0199 from `Agent System`, F-0243 from `Core Workflow`.

Add brief note after table:
```markdown
> **Feature types** (shown where relevant): `capability` — user-facing (default,
> unlabeled) · `infrastructure` — permanent dev tooling · `research` — time-bounded
> experiment · `meta` — organizational container
>
> Development infrastructure items (`DEV-XXXX`) use the full `ag` workflow but are
> not user-facing capabilities.
```

### 5. Update existing contracts for the 3 internal features

**`F-0122.yaml`** — add:
```yaml
parent: DEV-0001
tags: [infrastructure, internal]
category: dev-infrastructure
```

**`F-0199.yaml`** — add:
```yaml
parent: DEV-0001
tags: [infrastructure, internal]
category: dev-infrastructure
```

**`F-0243.yaml`** — create (no contract exists yet):
```yaml
id: F-0243
name: Complexity Tier Experiments
lifecycle: shipped
parent: DEV-0001
tags: [research, internal]
category: dev-infrastructure
description: |
  Empirical comparison harness for discovery/formal/autonomous_formal profiles.
  Research item: concludes when profile comparison is documented.
assertions:
  - id: AC-001
    text: "tier_experiment.py exists with TierMetrics dataclass"
    type: structural
    verify: "grep -q 'class TierMetrics' .agentic/lib/auto/tier_experiment.py"
  - id: AC-002
    text: "complexity_tiers.yaml has 3 tiers with review_plan override"
    type: structural
    verify: "grep -q 'review_plan: critical_agent' .agentic/lib/auto/experiments/complexity_tiers.yaml"
  - id: AC-003
    text: "ag auto tier-experiment is wired in auto.sh"
    type: structural
    verify: "grep -q 'tier-experiment' .agentic/lib/tools/commands/auto.sh"
```

### 6. Add `ongoing` as a valid lifecycle value in contract schema

Currently `lifecycle` is an enum: `exploring | specifying | implementing | verifying | shipping | shipped | deprecated`.

Add `ongoing` for meta/container items that never complete:
```json
"lifecycle": {
  "enum": ["exploring", "specifying", "implementing", "verifying", "shipping", "shipped", "deprecated", "ongoing"]
}
```

### 7. Add structural gates to `validate_framework.sh`

```bash
# DEV-0001: Framework Development Infrastructure
if grep -q "DEV-0001" .agentic/spec/FEATURES.md; then
  pass "DEV-0001: dev-infrastructure section exists in FEATURES.md"
else
  fail "DEV-0001: dev-infrastructure section missing from FEATURES.md"
fi

if grep -q "Type.*infrastructure\|Type.*research" .agentic/spec/FEATURES.md; then
  pass "DEV-0001: Type annotations present on internal features"
else
  fail "DEV-0001: Type annotations missing from internal features"
fi

if [ -f ".agentic/spec/contracts/DEV-0001.yaml" ]; then
  pass "DEV-0001: contract exists"
else
  fail "DEV-0001: DEV-0001.yaml contract missing"
fi
```

---

## What Does NOT Change

- `ag` tooling — no new commands, no behavior changes
- BACKLOG.json — F-0243 stays as current work item, unchanged
- Existing `F-0122`, `F-0199`, `F-0243` IDs — kept as-is (renaming is too disruptive)
- The `ag` workflow for dev infrastructure — identical to capabilities

---

## Order of Operations

1. Commit F-0243 implementation (already done, tests pass) — clears current work item
2. This reorganization as a separate commit — or bundled with F-0243 if preferred

---

## Critical Files

| File | Change |
|------|--------|
| `.agentic/lib/schemas/contract.schema.json` | Add `DEV` to id/parent patterns; add `ongoing` to lifecycle enum |
| `.agentic/spec/FEATURES.md` | Add DEV-0001 section; update F-0122, F-0199, F-0243 metadata; update category table |
| `.agentic/spec/contracts/DEV-0001.yaml` | Create new |
| `.agentic/spec/contracts/F-0122.yaml` | Add parent, tags, category |
| `.agentic/spec/contracts/F-0199.yaml` | Add parent, tags, category |
| `.agentic/spec/contracts/F-0243.yaml` | Create new |
| `tests/validate_framework.sh` | Add DEV-0001 structural gates |

---

## Verification

```bash
bash tests/validate_framework.sh
# ✓ DEV-0001: dev-infrastructure section exists in FEATURES.md
# ✓ DEV-0001: Type annotations present on internal features
# ✓ DEV-0001: contract exists

grep "Type.*\(infrastructure\|research\|meta\)" .agentic/spec/FEATURES.md
# Shows F-0122, F-0199, F-0243, DEV-0001

python3 .agentic/lib/tools/contracts.py validate .agentic/spec/contracts/DEV-0001.yaml
# Validates clean against updated schema
```
