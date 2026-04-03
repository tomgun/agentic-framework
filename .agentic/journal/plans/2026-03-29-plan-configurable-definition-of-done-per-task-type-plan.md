# Plan: Configurable Definition of Done per Task Type

## Context

The framework currently enforces one implicit DoD ("spec + code + tests + docs = done") uniformly across all features. This is hardcoded in `done.sh` (lines 717-732), `feature-complete.sh` (6 checks), and `gates.py` (8 gates). A spike/research feature goes through identical gates as a production capability — blocking on tests that don't apply.

This improvement (to F-002) makes DoD explicit, configurable, and task-type-aware. Users define which checks apply per task type. Default "implementation" type preserves exact current behavior.

## Design Decisions

**D1: DoD definitions live in `.agentic/lib/presets/dod.conf`** — follows `profiles.conf`/`constraints.conf` convention. Structured config, LLM-readable, not STACK.md (which is scalar key-value only).

**D2: Task type resolution cascade** — explicit `--type` flag > contract `task_type` field > FEATURES.md Type field > default "implementation". Current features all resolve to "implementation".

**D3: Gates skip via internal type check** — gate functions call `resolve_task_type()` internally and return `GateResult.ok()` with advisory when skipped for that type. No GateFunc signature change needed.

**D4: Five default types** — `implementation` (full DoD), `spike` (skip test gates + docs gate), `bugfix` (full, stricter test-first), `docs` (skip test + code quality gates), `infrastructure` (same as implementation).

## Implementation Phases

### Phase 1: DoD Configuration (2 new files)

**New: `.agentic/lib/presets/dod.conf`**
```conf
# format: dod-v1.0
# type.check_key=enforcement
# enforcement: required | skip | advisory
# Checks: ac_met, tests_exist, tests_pass, docs_updated, code_reviewed, smoke_tested, journal_updated, features_updated

implementation.ac_met=required
implementation.tests_exist=required
implementation.tests_pass=required
implementation.docs_updated=required
implementation.code_reviewed=required
implementation.smoke_tested=required
implementation.journal_updated=required
implementation.features_updated=required

spike.ac_met=advisory
spike.tests_exist=skip
spike.tests_pass=skip
spike.docs_updated=skip
spike.code_reviewed=advisory
spike.smoke_tested=advisory
spike.journal_updated=required
spike.features_updated=required

bugfix.ac_met=required
bugfix.tests_exist=required
bugfix.tests_pass=required
bugfix.docs_updated=advisory
bugfix.code_reviewed=required
bugfix.smoke_tested=required
bugfix.journal_updated=required
bugfix.features_updated=required

docs.ac_met=advisory
docs.tests_exist=skip
docs.tests_pass=skip
docs.docs_updated=required
docs.code_reviewed=advisory
docs.smoke_tested=skip
docs.journal_updated=required
docs.features_updated=required

infrastructure.ac_met=required
infrastructure.tests_exist=required
infrastructure.tests_pass=required
infrastructure.docs_updated=required
infrastructure.code_reviewed=required
infrastructure.smoke_tested=required
infrastructure.journal_updated=required
infrastructure.features_updated=required
```

**New: `.agentic/lib/dod.py`** (~100 lines)
- `parse_dod_conf(project_root) -> dict[str, dict[str, str]]` — parse config
- `resolve_task_type(feature_id, project_root, explicit_type=None) -> str` — cascade resolution
- `get_dod_items(task_type) -> list[tuple[str, str, str]]` — returns (check_key, label, enforcement)
- `get_skipped_gates(task_type) -> set[str]` — which gates to skip for this type
- Mapping: `tests_exist`/`tests_pass` → gates 3+5; `docs_updated` → gate 6

### Phase 2: Wire into `done.sh` (1 modified file)

**Modify: `.agentic/lib/tools/commands/done.sh`**
- Add `--type <type>` flag parsing alongside `--force-phases` (line ~188)
- Replace hardcoded checklist (lines 717-732) with dynamic lookup:
  ```bash
  local resolved_type
  resolved_type=$(python3 "$AGENTIC_LIB/dod.py" resolve-type "$feature_id" ${explicit_type:+--type "$explicit_type"} 2>/dev/null) || resolved_type="implementation"

  local checklist_output
  checklist_output=$(python3 "$AGENTIC_LIB/dod.py" checklist --type "$resolved_type" 2>/dev/null) || checklist_output=""

  if [ -n "$checklist_output" ]; then
      echo "$checklist_output"
  else
      # Fallback: exact current hardcoded list
      echo "  [ ] All acceptance criteria met"
      ...
  fi
  ```
- Show resolved type in output: `"Definition of Done (type: spike):"`
- For discovery mode (lines 197-218): same logic but simpler fallback

### Phase 3: Wire into gates (1 modified file)

**Modify: `.agentic/lib/auto/gates.py`**
- Add `_resolve_feature_type()` helper (follows `_read_feature_component()` pattern at lines 89-100):
  ```python
  def _resolve_feature_type(feature_id: str, project_root: Path) -> str:
      """Resolve task type from contract or FEATURES.md. Default: implementation."""
      # Check contract task_type field
      paths = get_paths(project_root)
      contract_file = paths.contracts_dir / f"{feature_id}.yaml"
      if contract_file.exists():
          try:
              from contracts import load_contract
              c = load_contract(contract_file)
              if hasattr(c, 'task_type') and c.task_type:
                  return c.task_type
          except Exception:
              pass
      # Check FEATURES.md Type field
      block = _read_feature_block(feature_id, project_root)
      if block:
          m = re.search(r"\*\*Type\*\*:\s*(\w+)", block)
          if m and m.group(1).lower() in ("spike", "research", "docs", "bugfix"):
              return m.group(1).lower()
      return "implementation"
  ```
- Modify `gate_criteria_set_to_tests_written` (gate 3): early return skip for spike/docs types
- Modify `gate_implementing_to_verified` (gate 5): skip test checks for spike/docs types
- Modify `gate_verified_to_documented` (gate 6): skip doc checks for spike types

### Phase 4: Contract schema + dataclass (2 modified files)

**Modify: `.agentic/lib/contracts.py`** — add `task_type` field to Contract:
```python
task_type: Optional[str] = None  # implementation | spike | bugfix | docs | infrastructure
```
Update `from_dict()` and `to_dict()` accordingly.

**Modify: `.agentic/lib/schemas/contract.schema.json`** — add optional `task_type`:
```json
"task_type": {
  "type": "string",
  "enum": ["implementation", "spike", "bugfix", "docs", "infrastructure"],
  "description": "Task type determines which DoD checks apply"
}
```

### Phase 5: Settings integration (2 modified files)

**Modify: `.agentic/lib/settings.sh`** — add `dod_type` to `show_all_settings()` array (advisory only, not per-profile).

**Modify: `.agentic/lib/presets/profiles.conf`** — no change needed. DoD types are per-feature, not per-profile. Profiles already control gate enforcement levels.

### Phase 6: Tests (1-2 files)

**New: `tests/test_dod.py`**
- Test `parse_dod_conf()` returns correct structure
- Test `resolve_task_type()` cascade (explicit > contract > FEATURES.md > default)
- Test `get_dod_items("implementation")` matches current hardcoded list exactly
- Test `get_skipped_gates("spike")` returns gates 3, 5, 6
- Test backward compat: no task_type → "implementation" → all gates active

**Modify: `tests/validate_framework.sh`** — add structural check for dod.conf existence.

### Phase 7: Instruction file updates (framework-dev)

Update: `.agentic/lib/agents/claude/CLAUDE.md` template, `memory-seed.md`, completing-work skill, writing-specs skill — mention `--type` flag on `ag done` and task type concept.

## Files Changed Summary

| File | Action | Phase |
|------|--------|-------|
| `.agentic/lib/presets/dod.conf` | NEW | 1 |
| `.agentic/lib/dod.py` | NEW | 1 |
| `.agentic/lib/tools/commands/done.sh` | MODIFY | 2 |
| `.agentic/lib/auto/gates.py` | MODIFY | 3 |
| `.agentic/lib/contracts.py` | MODIFY | 4 |
| `.agentic/lib/schemas/contract.schema.json` | MODIFY | 4 |
| `.agentic/lib/settings.sh` | MODIFY | 5 |
| `tests/test_dod.py` | NEW | 6 |
| `tests/validate_framework.sh` | MODIFY | 6 |
| Instruction files (CLAUDE.md, memory-seed, skills) | MODIFY | 7 |

**Total: ~10 files, 3 new + 7 modified** (within 5-10 file limit per commit if split across 2 commits: core + instruction files).

## Backward Compatibility

- All existing features resolve to "implementation" type (no task_type set anywhere)
- "implementation" type = all checks `required` = identical to current behavior
- `dod.py` failure → falls back to current hardcoded checklist in done.sh
- Contract schema change is additive (optional field with default None)
- No profile changes — DoD types are per-feature orthogonal to profiles

## Verification

1. **Unit tests**: `python3 -m pytest tests/test_dod.py -v`
2. **Framework validation**: `bash tests/validate_framework.sh`
3. **Manual smoke test**:
   - `ag done F-002` → shows "implementation" type, identical current checklist
   - Create a test contract with `task_type: spike`, run `ag done` → shows reduced checklist, gates 3+5 skipped
4. **Gate test**: Create spike-type feature, attempt state transition through tests_written → should skip with advisory
