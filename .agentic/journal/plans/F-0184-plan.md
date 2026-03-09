# F-0184: Epic Decomposition — Implementation Plan (v2)

**Status**: APPROVED
**Revision**: v2 — addresses dialectical review R1-R5, G1/G4/G5, O1

## Context

F-0184 adds `ag decompose F-XXXX` — analyze an epic's acceptance criteria, identify components, propose child features, route through `review_decomposition` checkpoint. ADR-001 Phase 5, Section 2. Dependencies (F-0179 components, F-0180 review checkpoints) are shipped.

## What Already Exists (reuse, don't rebuild)

- **query_features.py** — `get_children()`, `print_children()`, `--children` CLI already work. Parses `parent` field. **AC-007 is done.**
- **components.py** — `ComponentRegistry`, `load_registry()`, `parse_components_table()`. For AC-002.
- **review.py** — `review_decomposition` setting exists in STACK.md/profiles.conf. `get_setting()` resolves it. We do NOT wire it into `TRANSITION_REVIEW_MAP` (see DD-2).
- **feature.sh** — updates FEATURES.md fields. Needs `parent` field support for updating existing entries.
- **state_machine.py** — transitions, gates. No parent-child logic yet.

## New Files

| File | Purpose |
|------|---------|
| `.agentic/lib/auto/epic.py` | Epic status derivation, decomposition proposal, child creation, review orchestration |
| `tests/test_epic.py` | Unit tests for all epic logic |

## Modified Files

| File | Change |
|------|--------|
| `.agentic/lib/tools/ag.sh` | Add `decompose` command dispatch |
| `.agentic/lib/tools/feature.sh` | Support `parent` field updates on existing entries |
| `.agentic/lib/auto/state_machine.py` | Post-transition hook: recompute parent epic status |

Note: `review.py` is NOT modified. Decomposition uses `get_setting()` directly (see DD-2).

## Design Decisions

### DD-1: Decomposition produces a structured scaffold, not smart proposals

~~Dual LLM/heuristic~~ → Single approach: `propose_decomposition()` reads the epic's AC file, splits on AC-NNN lines, and produces a scaffold — one child feature per AC group. If a component registry exists, it tags each child with a matching component based on path/keyword overlap in the AC text. If no match, the component field is omitted.

**Child dict structure:**
```python
{
    "id": "F-XXXX",           # Next available ID
    "name": str,              # Derived from AC section heading or AC-NNN text
    "parent": "F-YYYY",       # The epic ID
    "component": str | None,  # From registry match, or None
    "ac_lines": list[str],    # The AC lines scoped to this child
}
```

The agent (which IS the LLM) can refine the scaffold before confirming. The module is deterministic and testable without LLM.

### DD-2: Review checkpoint uses `get_setting()` directly, NOT `check_review()`

**Why**: `check_review()` routes through `TRANSITION_REVIEW_MAP` using `(from_state, to_state)` pairs. Decomposition is not a state transition — `"decomposed"` is not a `FeatureState`, and `resolve_review()` would crash trying `FeatureState("decomposed")`.

**Instead**: `decompose()` in `epic.py` calls `get_setting(project_root, "review_decomposition", "skip")` directly, then:
- `skip` → proceed automatically
- `human` → print the proposal, return it without creating children, print instructions ("review and re-run with --confirm")
- `critical_agent` → spawn adversarial review of the proposal (future; treat as `human` for v1)

This keeps the review infrastructure clean and avoids polluting state-machine concepts with non-state actions.

### DD-3: Epic status is derived, not transitioned — uses `feature.sh` directly

`recompute_epic_status()` calls `feature.sh` to update the epic's status, intentionally bypassing `sm.transition()`. Rationale:
- Epic status is a **derived value** from children's states, not an independent lifecycle decision
- Routing through `transition()` would trigger gates, reviews, and recursive parent recomputation
- **Max depth guard**: recompute checks depth (parent of parent of...) and stops at depth 3 to prevent runaway recursion in pathological data

### DD-4: Graceful without components

If no component registry exists, decomposition still works — child features just won't have a Component field. `load_registry()` returns empty `ComponentRegistry` when STACK.md has no `## Components` section.

### DD-5: `create_child_features` writes FEATURES.md directly (append)

`feature.sh` can only update fields on existing entries. Creating new child feature sections requires appending to FEATURES.md. `create_child_features()` appends new `## F-XXXX: Name` sections with all fields (Status, Parent, Component) and creates corresponding `spec/acceptance/F-XXXX.md` files. `feature.sh` `parent` support is only for updating an existing feature's parent after the fact.

## Preconditions & Validation

Before `ag decompose F-XXXX` proceeds:
1. Feature must exist in FEATURES.md
2. Feature must have an AC file at `spec/acceptance/F-XXXX.md`
3. Feature must be in `planned` or `specced` state (not already implementing)
4. **Idempotency**: if children already exist (`get_children()` returns non-empty), refuse with message "F-XXXX already has N children. Use --force to re-decompose."

## Execution Order

### Phase 1: Foundation
- Add `parent` field support to feature.sh (new case branch in awk)
- **Checkpoint**: existing tests still pass

### Phase 2: Core (epic.py)
- `derive_epic_status(children_statuses: list[str]) → str | None` — AC-005
  - Returns `None` for empty list (no children yet)
  - Handles `deprecated`: excluded from derivation (as if not present); if ALL deprecated → `deprecated`
- `recompute_epic_status(project_root, epic_id, _depth=0)` — AC-006
  - Reads children via query_features, derives status, updates via feature.sh if changed
  - Max depth guard: `_depth >= 3` → return without action
- `propose_decomposition(project_root, epic_id) → list[dict]` — AC-001, AC-002
  - Reads AC file, splits on AC-NNN groups, matches components
  - Returns child dicts (see DD-1 structure)
- `create_child_features(project_root, epic_id, children: list[dict])` — AC-004, AC-008
  - Appends sections to FEATURES.md, creates AC files with component-scoped criteria
  - Assigns next available F-XXXX IDs
- `decompose(project_root, epic_id, force=False, confirm=False)` — AC-003
  - Validates preconditions → proposes → checks review_decomposition setting → creates (if skip or confirm)
- CLI entry point: `main()` with argparse (`--force`, `--confirm` flags)

### Phase 3: Integration
- Add `decompose` to ag.sh dispatch
- Hook `recompute_epic_status` into state_machine.py `transition()` — after successful `feature.sh` call (line ~377), read child's `parent` field; if present, call `recompute_epic_status(project_root, parent_id)`. Only fires when the transitioning feature has a parent — zero cost for non-children.
- **Checkpoint**: run validate_framework.sh

### Phase 4: Tests
- test_epic.py covering:
  - `derive_epic_status`: all-shipped, mixed states, regression detection, deprecated handling, empty list
  - `propose_decomposition`: with/without components, AC parsing
  - `create_child_features`: FEATURES.md append, AC file creation, ID allocation
  - `recompute_epic_status`: depth guard, status change vs no-change
  - `decompose`: idempotency check, precondition validation, review mode blocking
  - Integration: child transition triggers parent recomputation

## Epic Status Derivation Rules (AC-005, AC-006)

```
Input: list of child status strings (excluding deprecated children, unless ALL are deprecated)

If empty (no children): return None (don't change epic status)
If ALL children deprecated: return "deprecated"
If ALL children shipped: return "shipped"
If ANY child is implementing/verified/documented/committed: return "implementing"
If ALL children are criteria_set or earlier: return "criteria_set"
Otherwise: return min(children states by STATE_ORDER)
```

Note: AC-005's "integration verification" requirement is deferred — it requires a mechanism to define and run integration checks that doesn't exist yet. The derivation rules cover the "all children shipped" condition; integration verification can be added as a gate on the epic's `shipped` transition in a follow-up.

## Verification

1. `bash tests/validate_framework.sh` — all existing tests pass
2. `python3 -m pytest tests/test_epic.py -v` — new tests pass
3. Manual: create a mock epic in FEATURES.md with AC file, run `ag decompose`, verify child features created with correct Parent field
4. Verify `query_features.py --children F-XXXX` shows created children
5. Verify `review_decomposition: human` blocks and prints proposal without creating children
6. Verify child transition triggers parent status recomputation
