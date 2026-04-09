# Backlog Reassessment: Consolidate F-037/038/039 via Migration

## Context

The backlog has three standalone features (F-037, F-038, F-039) that are really enhancements to already-shipped features F-018 (Coordination Server) and F-030 (Autonomous Execution Engine). Per "no feature inflation," these should be new ACs on existing features.

**Challenge**: Shipped contracts are protected — `gate.py` (line 847-870) blocks edits to shipped specs in formal mode, requiring a migration first. Additionally, ACs lack individual lifecycle tracking, so there's no way to express "this AC is planned while the feature is shipped."

**Solution**: Two changes working together:
1. Add `status` field to assertions (schema evolution) so ACs can independently track lifecycle
2. Use the migration system (`migration.sh`) to properly add new ACs to shipped contracts

## Part A: AC-Level Status Field

### A1. Schema change

**File:** `.agentic/lib/schemas/contract.schema.json` (assertion definition, ~line 144)

Add to assertion properties:
```json
"status": {
  "type": "string",
  "enum": ["planned", "specced", "implementing", "verified", "shipped"],
  "default": "shipped",
  "description": "AC lifecycle. Defaults to shipped for backward compatibility with existing ACs."
}
```

### A2. Python dataclass

**File:** `.agentic/lib/contracts.py`

- `Assertion` dataclass (line 62): add `status: str = "shipped"`
- `from_dict()` (line 71): add `status=d.get("status", "shipped")`
- `to_dict()` (line 82): emit `status` only when not `"shipped"` (keep existing contracts clean)
- Add property `Contract.planned_assertions` → `[a for a in self.assertions if a.status == "planned"]`
- Add property `Contract.unshipped_assertions` → `[a for a in self.assertions if a.status != "shipped"]`

### A3. Verification behavior

**File:** `.agentic/lib/contracts.py` — `verify_assertion()` (line 448)

Non-shipped ACs should be skipped during verification (like `draft`), with reason "planned assertion — not yet implemented":

```python
if assertion.status != "shipped":
    return VerificationResult(
        assertion_id=assertion.id, passed=True, skipped=True,
        reason=f"{assertion.status} assertion — not yet implemented"
    )
```

### A4. Contract check reporting

**File:** `.agentic/lib/tools/commands/contract.sh` — `_contract_check()` (line 53)

After reporting pass/fail/skip, also show: `"N planned ACs (not yet implemented)"` when unshipped ACs exist. This surfaces the backlog of work remaining on a shipped feature.

### A5. Structural assertions filter

**File:** `.agentic/lib/contracts.py` — `structural_assertions` property (line 246)

Update to also exclude non-shipped: `a.type == "structural" and not a.draft and a.status == "shipped"`

## Part B: Consolidate F-037/038/039 via Migration

### B1. Create migration

Use the migration system to properly evolve the shipped contracts:

```bash
bash .agentic/lib/tools/migration.sh create "Consolidate F-037/038/039 into F-018 and F-030"
```

The migration records:
- **Trigger**: backlog reassessment — planned features describe enhancements to shipped capabilities
- **Reason**: F-037/038/039 describe work that enhances F-018 (MCP transport, multi-repo orchestration) and F-030 (scheduling enhancements). Per no-feature-inflation rule, these become new ACs on existing features.

### B2. Add ACs to F-018 contract (via `ag contract add-assertion`)

**File:** `.agentic/spec/contracts/F-018.yaml`

New ACs all with `status: planned`:

```yaml
# --- MCP Transport (consolidated from F-037) ---
- id: AC-002
  text: "MCP protocol server wraps existing coord tools for tool-native agent integration"
  type: structural
  status: planned

- id: AC-003
  text: "ag mcp start/stop/status lifecycle commands for MCP server"
  type: structural
  status: planned

- id: AC-004
  text: "Graceful degradation — framework operates normally without MCP server running"
  type: behavioral
  status: planned

# --- Multi-Repo Orchestration (consolidated from F-038) ---
- id: AC-005
  text: "Cross-repo shared backlog queries via umbrella resolution"
  type: behavioral
  status: planned

- id: AC-006
  text: "ag status --umbrella shows unified status across component repos"
  type: structural
  status: planned

- id: AC-007
  text: "Umbrella auto-syncs component repos before orchestration"
  type: behavioral
  status: planned
```

### B3. Add ACs to F-030 contract (via `ag contract add-assertion`)

**File:** `.agentic/spec/contracts/F-030.yaml`

```yaml
# --- Scheduling Enhancements (consolidated from F-039) ---
- id: AC-006
  text: "Scheduler reads Priority field from FEATURES.md and orders features accordingly"
  type: behavioral
  status: planned

- id: AC-007
  text: "Dynamic capacity sensing adjusts parallelism based on system load"
  type: behavioral
  status: planned

- id: AC-008
  text: "Independent ACs within a feature run in parallel worktrees"
  type: behavioral
  status: planned
```

### B4. Add migration entries to both contracts

Each contract gets a `migrations:` entry recording the consolidation:

```yaml
migrations:
  - id: M-001
    date: "2026-04-03"
    trigger: "consolidation"
    reason: "F-037/F-038 consolidated — planned enhancements to shipped coordination infrastructure"
    changes:
      - "Added AC-002 through AC-007 with status: planned (MCP transport + multi-repo orchestration)"
    approved_by: "user"
```

### B5. Deprecate standalone features

**File:** `.agentic/spec/FEATURES.md` — mark F-037, F-038, F-039 as `deprecated`

Add consolidation note: "Consolidated into F-018 (AC-002–AC-007)" / "Consolidated into F-030 (AC-006–AC-008)"

### B6. Update CONSOLIDATION_MAP.md

**File:** `.agentic/spec/CONSOLIDATION_MAP.md`

Add: `F-037 → F-018`, `F-038 → F-018`, `F-039 → F-030`

### B7. Clear and update backlog

**File:** `.agentic/BACKLOG.json`

- Remove F-037, F-038, F-039
- Optionally add F-018 and/or F-030 back to backlog (user decides if these planned ACs are next priority)

### B8. Status + journal

- `status.sh focus "Consolidated F-037/038/039 into F-018/F-030 with AC-level status tracking"`
- `journal.sh` with rationale

## Files to modify

| File | Change |
|------|--------|
| `.agentic/lib/schemas/contract.schema.json` | Add `status` to assertion definition |
| `.agentic/lib/contracts.py` | Add `status` to Assertion + skip in verify + new properties |
| `.agentic/lib/tools/commands/contract.sh` | Report planned AC count in `ag contract check` |
| `.agentic/spec/contracts/F-018.yaml` | Add 6 planned ACs + migration entry |
| `.agentic/spec/contracts/F-030.yaml` | Add 3 planned ACs + migration entry |
| `.agentic/spec/FEATURES.md` | Deprecate F-037, F-038, F-039 |
| `.agentic/BACKLOG.json` | Remove F-037/038/039 |
| `.agentic/spec/CONSOLIDATION_MAP.md` | Add consolidation entries |
| `.agentic/STATUS.md` | Update via status.sh |
| `.agentic/journal/JOURNAL.md` | Record via journal.sh |

## Verification

1. `ag contract check F-018` — existing AC-001 passes, new ACs show as "skipped (planned)"
2. `ag contract check F-030` — existing AC-001–005 pass, new ACs show as "skipped (planned)"
3. `ag contract validate` — all contracts pass schema validation with new `status` field
4. `ag backlog list` — F-037/038/039 gone
5. `bash tests/validate_framework.sh` passes
6. Existing contracts with no `status` field still work (default to `shipped`)
