# Plan: Design Phase Formalization (F-004 improvement)

**Status**: APPROVED (revision 3 — incorporates round 2 review findings)

## Context

The framework's 9-state lifecycle goes `planned → specced → criteria_set → ...`. For projects with complex architecture, there's a gap: after planning *what* to build, teams may need a formal *design* step (ADRs, design docs) before writing specs. Currently this is informal — no gate enforces it, no state tracks it.

This adds an optional `designed` state between `planned` and `specced`, controlled by `design_phase: off|optional|required` (default: `off`). Zero impact for existing projects.

Originally F-0233 in the opportunity map, now tracked as improvement to shipped F-004.

## Design Decisions

**D1: Gate-layer policy enforcement.** `planned → specced` remains a structurally valid forward transition. The gate blocks only when `design_phase: required`. Follows the `docs_gate` pattern in `gate_verified_to_documented`.

**D2: Three-valued `design_phase` setting with distinct semantics.**
- `off` (default): `planned → designed` blocked by gate. `get_next_states()` hides `designed`. Existing flow unchanged.
- `optional`: Both `planned → designed` and `planned → specced` available. User chooses path.
- `required`: `planned → specced` blocked by gate. Must go through `designed` first.

**D3: New contract lifecycle value `"designing"`.** Ensures round-trip fidelity — `designed` state survives write-then-read through YAML contracts. Without this, `designed` maps to `"exploring"` which reads back as `planned`.

**D4: `get_next_states()` filters by `design_phase` setting.** Prevents advertising unavailable transitions in `--next` and `--unblocked` CLI output.

## Approach

### Phase 1: Contract System (`contracts.py`)

**File**: `.agentic/lib/contracts.py` (line 328)

1. Add `"designing"` to `_VALID_LIFECYCLES` set

### Phase 2: State Machine (`state_machine.py`)

**File**: `.agentic/lib/auto/state_machine.py`

1. Add `DESIGNED = "designed"` to `FeatureState` enum between `PLANNED` and `SPECCED` (line ~54)
   - `STATE_ORDER` auto-derives from enum iteration order — no manual change needed
2. Add forward transitions: `(PLANNED, DESIGNED)` and `(DESIGNED, SPECCED)`
   - Keep `(PLANNED, SPECCED)` as-is — gate layer handles policy
3. Add skip transition: `(DESIGNED, IMPLEMENTING)` for lean workflows
4. Add regression transitions: `(SPECCED, DESIGNED)`, `(IMPLEMENTING, DESIGNED)`
   - Note: Existing regressions like `(SHIPPED, SPECCED)` don't need `→ DESIGNED` variants. Users can do two transitions (`shipped → specced → designed`) if a major redesign is needed. Keeps transition tables minimal.
5. Add lifecycle mappings with round-trip fidelity:
   - `LIFECYCLE_TO_STATE["designing"] = DESIGNED`
   - `STATE_TO_LIFECYCLE[DESIGNED] = "designing"` (new lifecycle value, not "exploring")
6. Modify `get_next_states()` (line 527): read `design_phase` setting, filter:
   - When `off`: exclude `DESIGNED` from results
   - When `required`: exclude `SPECCED` from `planned`'s results (gate still blocks too, but clean UX)
   - When `optional`: show both
7. Update docstring: "10-state feature lifecycle"

### Phase 3: Gates (`gates.py`)

**File**: `.agentic/lib/auto/gates.py`

1. **New `gate_planned_to_designed()`**: Read `design_phase` setting. If `off`, return `GateResult.blocked()`. Otherwise check feature exists in FEATURES.md (reuse `_read_feature_block()`).
2. **New `gate_designed_to_specced()`**: Check for design artifacts — either:
   - An ADR file (`.md`) in `paths.adr_dir` containing the feature ID, OR
   - A design doc at `paths.work_dir / feature_id / "design.md"`
3. **Modify `gate_planned_to_specced()`** (line 139): When `design_phase == "required"`, return `GateResult.blocked(["design_phase is required — transition to 'designed' first"])`.
4. Add both new gates to `DEFAULT_GATES` list (line 624)

### Phase 4: Review Map (`review.py`)

**File**: `.agentic/lib/auto/review.py`

Add to `TRANSITION_REVIEW_MAP` (line 89):
- `("planned", "designed"): "review_design"` (design review)
- `("designed", "specced"): "review_spec"` (spec readiness review — semantically distinct from design review)
- `("designed", "implementing"): "review_design"` (skip transition — design approval)

### Phase 5: Profile Defaults (`profiles.conf`)

**File**: `.agentic/lib/presets/profiles.conf`

Add to all three profiles:
- `discovery.design_phase=off` + `discovery.review_design=skip`
- `formal.design_phase=off` + `formal.review_design=critical_agent`
- `autonomous_formal.design_phase=off` + `autonomous_formal.review_design=critical_agent`

### Phase 6: Downstream State Lists (blast radius)

These files have hardcoded state lists that must include `"designed"`:

1. **`epic.py`** (`.agentic/lib/auto/epic.py`):
   - Line 61: Add `"designed"` to `_STATE_ORDER` between `"planned"` and `"specced"`
   - Line 109: Add `"designed"` to `early_states` set (designed is pre-implementation)
   - Line 535: Add `"designed"` to decomposition-allowed states

2. **`crunch.py`** (`.agentic/lib/auto/crunch.py`):
   - Line 252: Add `"designed"` to workable feature status filter

3. **`validate_formats.py`** (`.agentic/lib/tools/validate_formats.py`):
   - Line 48: Add `"designed"` to `valid_statuses` set

4. **`doctor.py`** (`.agentic/lib/tools/doctor.py`):
   - Line 358: Add `"designed"` to `STATUS_VALUES` set

5. **`feature_stats.py`** (`.agentic/lib/tools/feature_stats.py`):
   - Line 122: Add `"designed"` to `status_order` between `"planned"` and `"specced"`

### Phase 7: YAML Workflow (`state_machine_af.yaml`)

**File**: `state_machine_af.yaml`

1. Add `designing` to states list
2. Add transitions: `planning → designing`, `designing → spec`
3. Add `designed: designing` to `state_mapping`
4. Add `design.md` artifact definition

### Phase 8: Contract Update (`F-004.yaml`)

**File**: `.agentic/spec/contracts/F-004.yaml`

Add new assertions:
- AC-004: `designed` state exists in FeatureState enum
- AC-005: `design_phase` setting controls transition availability (off/optional/required)
- AC-006: Gate checks for design artifacts (ADR or design.md)
- AC-007: Contract round-trip fidelity — `designed` state survives write/read through YAML contracts

### Phase 9: Tests (`test_state_machine.py`)

**File**: `tests/test_state_machine.py`

1. Update `test_all_nine_states_plus_deprecated` → 10 states + deprecated (len == 11)
2. Add `TestDesignedState` class:
   - `test_planned_to_designed_valid` — forward transition allowed
   - `test_designed_to_specced_valid` — forward transition allowed
   - `test_planned_to_specced_still_valid_when_off` — direct path works when `design_phase: off`
   - `test_planned_to_specced_blocked_when_required` — gate blocks when `design_phase: required`
   - `test_planned_to_designed_blocked_when_off` — gate blocks entry to designed when off
   - `test_designed_in_state_order` — positioned between planned and specced
   - `test_design_gate_checks_artifacts` — gate passes with ADR or design.md
   - `test_design_gate_blocks_without_artifacts` — gate blocks without artifacts
   - `test_regression_specced_to_designed` — regression works
   - `test_skip_designed_to_implementing` — skip works
   - `test_get_next_states_off_hides_designed` — `get_next_states()` excludes designed when off
   - `test_get_next_states_optional_shows_both` — shows designed and specced
   - `test_get_next_states_required_hides_specced` — hides specced from planned
   - `test_contract_roundtrip_designed` — write designed → read back → get designed (not planned)
   - `test_cascade_implementing_to_specced_excludes_designed` — designed is at index 1 (before specced at index 2), so NOT in the invalidation range for `implementing → specced`

3. Add to `tests/test_epic.py`:
   - `test_designed_is_early_state` — `derive_epic_status(["planned", "designed"]) == "criteria_set"`

### Phase 10: Validation & Documentation

1. Run `pytest tests/test_state_machine.py -v` — all pass
2. Run `bash tests/validate_framework.sh` — framework validation passes
3. Add structural test for `designed` state in validate_framework.sh
4. Update docs referencing "9-state": HOW_IT_WORKS.md, DEVELOPER_GUIDE.md, FRAMEWORK_WORKFLOW.md → "10-state"
5. Update memory-seed if it references state list

## Critical files (all files to modify)

| File | Change | Risk |
|------|--------|------|
| `.agentic/lib/contracts.py:328` | Add "designing" to `_VALID_LIFECYCLES` | Low |
| `.agentic/lib/auto/state_machine.py` | Enum, transitions, lifecycle maps, `get_next_states` | Medium |
| `.agentic/lib/auto/gates.py` | 2 new gates, modify 1 existing | Low |
| `.agentic/lib/auto/review.py:89` | TRANSITION_REVIEW_MAP entries | Low |
| `.agentic/lib/presets/profiles.conf` | design_phase + review_design defaults | Low |
| `.agentic/lib/auto/epic.py` | _STATE_ORDER, early_states, decomposition gate | Low |
| `.agentic/lib/auto/crunch.py:252` | Workable feature filter | Low |
| `.agentic/lib/tools/validate_formats.py:48` | valid_statuses set | Low |
| `.agentic/lib/tools/doctor.py:358` | STATUS_VALUES set | Low |
| `.agentic/lib/tools/feature_stats.py:122` | status_order list | Low |
| `state_machine_af.yaml` | YAML workflow additions | Low |
| `.agentic/spec/contracts/F-004.yaml` | Contract assertions | None |
| `tests/test_state_machine.py` | New test class + update counts | None |
| `tests/validate_framework.sh` | Structural test for designed | None |

14 files total (within 5-10 guideline per commit if split into 2 commits: core + downstream).

## Reusable code

- `_read_feature_block()` in gates.py — reuse for `gate_planned_to_designed`
- `GateResult.blocked()` / `GateResult.ok()` — existing patterns
- `get_setting()` from settings.py — reads `design_phase` setting (works automatically, no changes needed)
- `get_paths()` from paths.py — `paths.adr_dir`, `paths.work_dir`

## Verification

1. `pytest tests/test_state_machine.py -v` — all tests pass including new ones
2. `bash tests/validate_framework.sh` — framework validation passes
3. Manual smoke test: set `design_phase: required` in STACK.md, verify `planned → specced` blocked, `planned → designed → specced` works
4. Verify backward compat: with `design_phase: off`, every existing transition/gate/query produces identical results
5. Contract round-trip: transition to designed, read contract, verify state is `designed` not `planned`
