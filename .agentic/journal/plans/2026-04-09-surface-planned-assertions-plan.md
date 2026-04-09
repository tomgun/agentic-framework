# Plan: Surface Planned Assertions + Agent-Agnostic Enforcement Hierarchy

**Status**: APPROVED

## Context

YAML contract assertions have `status: planned | specced | implementing | verified | shipped`. When `status != "shipped"`, `verify_assertion()` (contracts.py:497) silently skips them. No workflow gate, dashboard, or sync check ever surfaces leftover non-shipped assertions. The `planned_assertions` (line 292) and `unshipped_assertions` (line 296) properties on the Contract dataclass exist but are **never called from any workflow gate**.

Concrete case: F-025 had AC-006 through AC-009 stuck at `status: planned` after PR #230 shipped. The agent had to be explicitly told to update them.

Secondary issue: The enforcement hierarchy across instruction files says "Claude hooks" everywhere, even in Cursor/Copilot/Codex files. Cursor's `.cursor/rules/agentic-enforcement.mdc` is already correct ("Cursor hooks") but the `cursorrules.txt` template still says "Claude hooks".

## Part 1: Planned Assertions — 4 Mechanisms

### Mechanism A: `ag done` Gate 4 — Planned Assertion Advisory

**File:** `.agentic/lib/tools/commands/done.sh`
**Insert at:** Line 342 (after verification gate, before intent-driven execution)
**~25 lines**

After the existing three gates (plan review, phase completion, verification), add a new advisory-only check. Load the contract, call `unshipped_assertions`. If any exist AND `contract.lifecycle in (shipped, shipping, ongoing)`, print a yellow warning:

```
⚠ F-025 has 4 unshipped assertion(s):
  planned (3): AC-006, AC-007, AC-008
  implementing (1): AC-009
  Promote when ready: ag contract promote F-025
```

**Advisory, not blocking** — legitimate to ship with some ACs deferred. No `--force` needed.

**Trigger condition:** `feature_id` is set AND contract file exists AND `contract.lifecycle in (shipped, shipping, ongoing)` AND `len(unshipped_assertions) > 0`.

**False positive risk:** Low. Only fires for shipped/shipping/ongoing contracts. In-progress (`exploring`, `implementing`, etc.) contracts are excluded — planned assertions there are expected.

---

### Mechanism B: `ag contract promote F-XXX [AC-ID]`

**File:** `.agentic/lib/tools/commands/contract.sh`
**Add to:** Case statement (line 10-28), help text (line 34-46), new function `_contract_promote`
**~70 lines**

New subcommand that:
1. Loads the contract
2. If `AC-ID` given: promote that single assertion from current status → `shipped`
3. If no `AC-ID`: promote ALL unshipped assertions
4. Print what changed: `✓ AC-006: planned → shipped`
5. Save via `save_contract()` (contracts.py:353)
6. Suggest: `Run ag contract check F-XXX to verify`

**Design decisions:**
- **No verify-before-promote.** Many planned assertions are behavioral (no verify command) or have no verify written yet. Running verify would block legitimate promotions. Keep promote as a pure metadata operation.
- **No migration required.** `planned → shipped` is not a breaking change. Migrations track `shipped → changed/removed` which is the breaking direction. However, if `contract.protection == "contract"`, auto-generate a migration entry with trigger `user_request` for audit trail.
- **`to_dict()` strips status field when shipped** (contracts.py:103-104). This is correct behavior — `shipped` is the default. The YAML diff will show the `status:` lines disappearing, which is expected.

---

### Mechanism C: `ag sync` Phase 4b — Assertion Status Drift

**File:** `.agentic/lib/tools/sync.sh`
**New function:** `phase_assertion_status` after `phase_spec_drift` (line 635)
**Add calls:** Line 1089 (quiet mode, after `phase_unregistered_code`) and line 1124 (normal mode, after `phase_spec_drift`)
**~40 lines**

For each contract in `contracts/`, if `lifecycle in (shipped, shipping, ongoing)` and `unshipped_assertions` exist, report as drift:

```
AC status: 2 contract(s) have unshipped assertions
            F-018: 6 unshipped (AC-002, AC-003, AC-004, AC-005, AC-006, AC-007)
            F-025: 3 unshipped (AC-006, AC-007, AC-008)
            Run: ag contract promote <feature-id>
```

In quiet mode: `record_issue` only, no verbose output. Respects existing quiet mode pattern.

**Trigger condition:** Contract lifecycle is shipped/shipping/ongoing AND has unshipped assertions. This ensures in-progress features aren't flagged.

---

### Mechanism D: `verify-contracts.sh` — Planned Assertion Summary

**File:** `.agentic/lib/tools/verify-contracts.sh`
**Modify:** Python block, after line 127 (summary output)
**~15 lines**

After the existing summary line, add:

```
⚠ 4 unshipped assertion(s):
  F-025: AC-006, AC-007, AC-008
  Run: ag contract promote <feature-id>
```

For JSON output (line 94-104): add `"unshipped": total_unshipped` to summary dict. No consumers parse this today — it's forward-looking infrastructure.

**Note:** `ag contract check` (contract.sh) already surfaces this for single-feature and recursive checks (lines 134, 169). This closes the gap for the standalone script used by `ag done`'s verification gate.

---

## Part 2: Agent-Agnostic Enforcement Hierarchy — 6 Files

Straightforward text replacements. Rule: agent-specific files name their own hooks; agent-agnostic files say "Agent hooks".

| File | Line(s) | Change |
|------|---------|--------|
| `.cursorrules` | 68, 71 | "Claude hooks" → "Cursor hooks"; "non-Claude tools" → "non-Cursor tools" |
| `.agentic/lib/agents/cursor/cursorrules.txt` | 68, 71 | Same as above |
| `.agentic/lib/agents/copilot/copilot-instructions.md` | 65 | "Claude hooks" → "Agent hooks (where supported)" |
| `.agentic/lib/agents/codex/codex-instructions.md` | 67 | "Claude hooks" → "Agent hooks (where supported)" |
| `.agentic/lib/init/memory-seed.md` | 57 | "Claude hooks" → "Agent hooks"; "non-Claude tools only" → "non-agent-hook tools" |
| `FRAMEWORK_DEVELOPMENT.md` | 834, 840, 842, 848, 851 | "Claude hooks" → "Agent hooks" in table + key principle + when-to-use sections. Add "(Claude: PreToolUse.sh etc., Cursor: hooks.json)" to examples column. |

**Files NOT touched** (already correct):
- `CLAUDE.md` (root) — correctly says "Claude hooks" (this IS the Claude file)
- `.agentic/lib/agents/claude/CLAUDE.md` — same
- `.cursor/rules/agentic-enforcement.mdc` — already says "Cursor hooks"
- `.agentic/lib/agents/cursor/rules/agentic-enforcement.mdc` — already says "Cursor hooks"

---

## Implementation Order

1. **`ag contract promote`** (contract.sh) — resolution path, needed before surfacing mechanisms reference it
2. **`verify-contracts.sh`** — smallest surfacing change, immediately visible
3. **`ag done` Gate 4** (done.sh) — primary surfacing at the right workflow moment
4. **`ag sync` Phase 4b** (sync.sh) — safety net for when `ag done` is skipped
5. **Enforcement hierarchy text** (6 files) — independent, can be done in parallel or as separate commit

## Files Modified (total: 10)

**Substantive changes (4 files):**
1. `.agentic/lib/tools/commands/contract.sh` — new `promote` subcommand
2. `.agentic/lib/tools/verify-contracts.sh` — unshipped assertion summary
3. `.agentic/lib/tools/commands/done.sh` — Gate 4 advisory
4. `.agentic/lib/tools/sync.sh` — Phase 4b assertion status drift

**Text replacements (6 files):**
5. `.cursorrules`
6. `.agentic/lib/agents/cursor/cursorrules.txt`
7. `.agentic/lib/agents/copilot/copilot-instructions.md`
8. `.agentic/lib/agents/codex/codex-instructions.md`
9. `.agentic/lib/init/memory-seed.md`
10. `FRAMEWORK_DEVELOPMENT.md`

**No changes needed:**
- `contracts.py` — `unshipped_assertions`, `planned_assertions`, `save_contract()` already exist
- `ag.sh` — routing already dispatches to `cmd_contract`

## What NOT to Build

- **Blocking gate** — advisory is sufficient; blocking requires `--force` escape hatch complexity
- **SessionStart/dashboard advisory** — sync drift check covers this (dashboard runs `ag sync --quiet`)
- **Pre-commit assertion check** — wrong moment (mid-implementation), hard to map files to features
- **Auto-promote on `ag done`** — too aggressive; developer should explicitly decide
- **Migration for planned→shipped** — over-engineering; migrations are for breaking changes (shipped→changed). Exception: auto-generate migration only when `protection: contract`.
- **Verify-before-promote** — would block promotion of behavioral ACs and ACs without verify commands
- **Coverage report fix** — `coverage_report()` counts planned ACs as gaps; separate follow-up

## Verification

1. **Manual test with F-025.yaml:** Temporarily set some assertions back to `status: planned`, run `ag contract check F-025`, `ag verify F-025`, `ag done F-025 --dry-run` if available, `ag sync` — verify all four mechanisms surface the planned assertions
2. **`ag contract promote F-025`** — verify assertions promoted, YAML updated, status lines removed from output
3. **`ag contract promote F-025 AC-006`** — verify single assertion promoted
4. **`ag sync --quiet`** — verify quiet mode reports issue count without verbose output
5. **`bash tests/validate_framework.sh`** — must pass
6. **Edge case: contract with lifecycle=exploring** — verify NO warning fires
7. **Edge case: all assertions already shipped** — verify no spurious output
