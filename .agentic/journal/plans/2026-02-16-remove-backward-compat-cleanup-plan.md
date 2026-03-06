# Plan: Remove Backward Compatibility + Final Cleanup

## Context

The profile rename (Core→Discovery, Core+PM→Formal) is 95% done. Two things remain:
1. **Remove backward compatibility** — normalization code that still accepts old values (`core`, `core+product`, `core+pm`, `core-pm`) should be stripped. Only `discovery` and `formal` are valid now.
2. **Final text cleanup** — remaining old references in active files (not historical).

## Part 1: Remove Normalization Code (~14 files)

Strip old-value-to-new-value mapping. After this, only `discovery` and `formal` are accepted.

### Shell files — remove case branches

| File | Line(s) | Change |
|------|---------|--------|
| `.agentic/tools/ag.sh` | 31-34 | Remove `core)` and `core+product|core+pm|core-pm)` case branches. Keep `discovery)`, `formal)`, `*) infer` |
| `.agentic/tools/sync.sh` | 61-63 | Same pattern as ag.sh |
| `.agentic/init/scaffold.sh` | 55-64 | Remove normalization block + comment. Remove old values from `usage()` line 22. Error on unknown values. |
| `.agentic/tools/upgrade.sh` | 272-277 | Remove `*core+product*|*core+pm*` and `*core*` branches. Keep `*formal*`, `*discovery*` |
| `.agentic/tools/upgrade.sh` | 425-443 | Remove entire migration block that rewrites old Profile values in STACK.md |
| `.agentic/tools/upgrade.sh` | 597 | Update feature registry entry: remove "(old values still accepted)" from line 600 |
| `tests/llm/harness.sh` | 296-300 | Remove normalization case block + comment in `setup_test_project()` |
| `tests/infrastructure/lib/helpers.sh` | 106-110 | Remove normalization case block + comment in `scaffold_test_project()` |

### Python files — remove mapping dicts

| File | Line(s) | Change |
|------|---------|--------|
| `.agentic/tools/phase_detect.py` | 13-17 | Replace `_normalize_profile()` — remove old keys, keep only `discovery`→`discovery`, `formal`→`formal` |
| `.agentic/tools/doctor.py` | 314-318 | Same |
| `.agentic/tools/verify.py` | 17-21 | Same |
| `.agentic/tools/discover.py` | 1362-1375 | Remove `"core"`, `"core+product"` from `choices=[]`. Remove `profile_map` normalization. |
| `.agentic/tools/render_proposals.py` | 397-435 | Remove `"core"`, `"core+product"` from `choices=[]`. Remove `profile_map` normalization. |
| `.agentic/tools/continue_here.py` | 140-144 | Remove `'profile: core+product'`, `'profile: core+pm'`, `'profile: core'` from detection. Only check `'profile: formal'` and `'profile: discovery'`. |

## Part 2: Delete `enable-product-management.sh`

- Delete `.agentic/tools/enable-product-management.sh` (old backward-compat script; `enable-formal.sh` is the replacement)

## Part 3: Update `spec/acceptance/F-0002.md`

Remove references to old values being normalized:
- AC1: Remove "(old values `core`/`core+product` normalized)"
- AC2: Remove "(old values normalized)"
- AC8: Remove entire line (was about backward compat)
- Verification: Remove "Old AGENTIC_PROFILE=core still works (normalization)"

## Part 4: Update `tests/validate_framework.sh`

- Line 101: Remove `\|core+pm\|core+product` from grep pattern (only check for `formal`)
- Line 1231: Remove comment about testing old value normalization

## Part 5: Text Cleanup in Active Files (use sonnet model)

Remaining old-name references in non-historical, non-archived active files. Launch sonnet agents for bulk text replacement.

### scaffold.sh remaining text
- Line 235: Comment `# Core profile → direct` → `# Discovery profile → direct`
- Line 298: Comment `# Configure git hooks for Core profile too` → `# Configure git hooks for Discovery profile too`

### upgrade.sh feature registry
- Line 597: `"both Core and Core+PM profiles"` → `"both Discovery and Formal profiles"`
- Line 600: `"Core→Discovery, Core+PM→Formal (old values still accepted)"` → `"Core→Discovery, Core+PM→Formal"`

## Files NOT to touch

- **Historical**: CHANGELOG.md, CONTRIBUTIONS.md, JOURNAL.md, SESSION_LOG.md, `.agentic-journal/plans/*`, `docs/reviews/*`
- **Archived examples**: `examples/archived/*` (frozen snapshots)

## Verification

1. `bash tests/validate_framework.sh` — 194/194 pass
2. `python3 -m pytest tests/test_phase_detect.py -v` — 6/6 pass
3. `bash tests/test_ag_gateway.sh` — 20/21 pass (1 pre-existing)
4. `python3 -m pytest tests/test_discover.py -v` — 75/75 pass
5. Grep for old values in active files confirms zero hits (excluding historical/archived/examples)
6. `AGENTIC_PROFILE=core bash .agentic/init/scaffold.sh` → should ERROR (no longer accepted)
