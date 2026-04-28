# R-016 — Phase 0 verification battery

Adversarial test suite proving Phase 0 Tier 0 catches each documented bypass attempt cross-profile (discovery, formal, autonomous_formal). 12 attack vectors × 3 profiles = 36-cell pass/fail matrix.

**Spec:** `.agentic/journal/plans/2026-04-27-R-016-revised-ac-plan.md` (v6 APPROVED).
**Backlog ref:** `2026-04-26-redesign-backlog.md` §R-016.

## Layout

```
tests/bypass/
├── lib/
│   └── battery.sh            # scaffold_project, seed helpers, env-hygiene, cleanup trap
├── results/                  # <timestamp>.json output files (gitignored)
├── B01_tests_required.sh     # one B-test per file
├── B02_prepush_coverage.sh
├── ...
├── B12_prepush_range.sh
├── known-fails.yaml          # manifest of accepted FAILs (empty by default)
├── run_battery.sh            # orchestrator: 12 × 3 = 36 cells, writes results JSON
└── README.md                 # this file
```

## Pass criteria

The orchestrator exits 0 (verification complete) when every cell has outcome PASS or SKIP-by-design, OR every FAIL cell appears in `known-fails.yaml` with a non-empty `reason` and either `journal_ref:` or `r_nnn:`. Exits 2 otherwise.

`known-fails.yaml` is appended to only by post-Phase-0 review, not by individual B-tests or the orchestrator.

## Adding a B-test

1. Create `B<NN>_<short_name>.sh` following the shape of an existing B-test.
2. Source `lib/battery.sh`.
3. Use `scaffold_project <profile>` to get a fresh project; helpers seed required fixtures.
4. Perform the attack, run the gate, assert outcome.
5. Emit a result JSON line (PASS / SKIP-by-design / FAIL) to stdout for the orchestrator.

Each B-test is annotated with a "Code path traced" comment block that lists the exact gate function and line the attack should trigger. If the attack ever stops triggering that path, the annotation is the first place to look.

## Cross-profile semantics

Each B-test is run 3× by the orchestrator, once per profile. Per-test "all profiles" annotations describe the EXPECTED outcome per profile, not test-skips. Profile-skip cells (e.g., AC4 journal-freshness in discovery, B07 chmod on Windows) are recorded as **SKIP-by-design** and are documented behavior, not failures.

## Runtime prerequisites

- `pyyaml` (used by `contracts.py` for contract loading + validation). Without it, `ag contract coverage` and `contracts.py validate` degrade to no-op states and B-tests that depend on contract loading produce misleading results. Install via `pip install pyyaml`.
- A non-root POSIX runtime for B07 (chmod 444 doesn't deny root). The orchestrator skips B07 with `SKIP-by-design` if `id -u` returns 0.

## Honest limit

The Tier 0 dispatch shim at `.agentic/hooks/pre-{commit,push}` is NOT in `integrity.py`'s baseline path list (`_FULL_FILE_PATHS` only baselines `.git/hooks/pre-{commit,push}`). An attacker who replaces the shim itself can bypass Tier 0 without tripping integrity. This battery does not test shim-location tampering — it tests the surfaces R-001/R-004 declared. The unbaselined-shim issue is a pre-existing R-001/R-004 framework gap (see `2026-04-27-R-016-revised-ac-plan.md` §"Out of scope").
