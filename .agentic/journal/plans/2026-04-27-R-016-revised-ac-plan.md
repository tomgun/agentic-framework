---
plan_id: R-016-revised-ac
date: 2026-04-27
backlog_ref: 2026-04-26-redesign-backlog.md §R-016
status: APPROVED
profile: autonomous_formal
plan_review_enabled: yes
reviewers: critic, advocate
deps_unchanged: R-001, R-002, R-003, R-004, R-005, R-010 (all shipped)
---

# R-016 — revised AC list (Phase 0 verification battery), v6

**Status:** APPROVED (round 6 — both Critic and Advocate CONVERGED). Round 6 mandate was "find ~1 more bug or confirm stabilization." Result: zero new architectural bugs in v6. One shared finding (Tier 0 shim at `.agentic/hooks/*` unbaselined → pre-existing R-001/R-004 gap, not v6 defect; documented in out-of-scope table). One Critic low-severity finding (B-test AC-specific assertion granularity) is implementation-time detail.

Round trajectory summary: R1=4 high → R2=2 high → R3=1 high → R4=4 high → R5=2 high → R6=0 new. v6 is the convergence point. Six rounds of dialectical review surfaced 13 architectural bugs total; all addressed.

Revision history at bottom.

## Why this revision exists

Original R-016 in the redesign-backlog (lines 416–443) lifted B01–B12 verbatim from the sibling close-out-hardening doc. That sibling doc proposed surfaces (`.close-out-pending` sentinel, PreToolUse path-deny, content classification, `state_enforcement` levels) that Phase 0 (R-001..R-015) didn't ship. Only 2 of 12 original B-tests cleanly attack a Phase 0 surface.

This revision realigns the attack-vector list to Phase 0 surfaces declared in R-016's own `Deps:` block. **Bounded-change principle:** attack vectors derive from declared dependencies; nothing else changes (goal, deliverable shape, deps, effort ±0.5d, placement, other R-NNNs).

## Goal (unchanged from original R-016)

Adversarial test suite proving Phase 0 Tier 0 catches each documented bypass attempt cross-profile (discovery, formal, autonomous_formal). Output: pass/fail matrix written to `tests/bypass/results/<timestamp>.json`.

## Phase 0 surface inventory (anchor for attack vectors)

| Surface | Location | Trigger | Profile gating |
|---------|----------|---------|----------------|
| R-001 AC0 (integrity) | precommit_gate.py:323 → integrity.py:verify_all | Hook/agent file SHA mismatches `integrity.json` | All profiles; CI-only `INTEGRITY_SKIP=1` |
| R-001 AC1 (tests) | precommit_gate.py:382 | Code changes staged + test command non-zero | Skip when `pre_commit_hook=no`, no test command, or state-only commit |
| R-001 AC2 (contracts) | precommit_gate.py:464 | `ag contract check` non-zero | Skipped when `AGENT_FIX_MODE=1` |
| R-001 AC3 (plan-approved) | precommit_gate.py:505 | `plan_review_enabled: yes` + code changes + sentinel missing | Only when `plan_review_enabled=yes`; skipped in fix mode |
| R-001 AC4 (journal freshness) | precommit_gate.py:528 | JOURNAL.md mtime + 5s < HEAD commit time | formal/autonomous_formal only |
| R-001 AC5 (shipped contracts) | precommit_gate.py:688 | shipped+protected contract changed without new `migrations:` entry | All profiles |
| R-001 AC7 (skip audit) | precommit_gate.py:917 | `AGENT_SKIP_GATE=1` + reason → `gate_skipped` event | All profiles |
| R-002 AC2 (full tests) | prepush_gate.py | Range-shape integration test command non-zero | All profiles |
| R-002 AC3 (coverage) | prepush_gate.py:372 (check_contract_coverage) | `ag contract coverage` < threshold (default 80) | All profiles |
| R-002 AC5 (range migrations) | prepush_gate.py | Walks `<remote_oid>..<local_oid>` for shipped-contract changes without migration | All profiles |
| R-002 AC6 (skip audit) | prepush_gate.py:725 | `AGENT_SKIP_GATE=1` → `gate_skipped` + `push_attempt` events | All profiles |
| R-004 (integrity baseline) | integrity.py | SHA-256 of `.git/hooks/pre-{commit,push}`, `.agentic/lib/hooks/*.py`, `.claude/settings.json[hooks]`, `.claude/agents/*.md` | All profiles |
| R-005 (chmod 444) | contract.sh::_contract_lock_shipped | shipped+protected `.yaml` files mode 444 | POSIX only (Windows skip) |
| R-010 (fix mode) | precommit_gate.py:466,507 | `AGENT_FIX_MODE=1` skips AC2 + AC3; AC1, AC4, AC5 still fire | All profiles |

**Surfaces explicitly out-of-scope for the 12-test budget** (documented at end):
- R-001 AC6 (no-verify breadcrumb): informational only, doesn't block
- R-002 AC4 (doc drift): complex SUT (drift.sh), formal+ only — separate verification needed
- R-003 (`ag merge`): user-invoked command, not always-fire hook — different verification model
- AC5 rename-bypass: a logic gap *within* AC5 (rename → looks like new file → skip). Logic-fix issue, not bypass-test
- AC1 state-only-commit smuggle: code-changes path classifier could be smuggled — separate concern
- INTEGRITY_SKIP audit path (CI-only environment)

## Revised B01–B12 — each test annotated with code path traced

Every test scaffolds a fresh project via `tests/bypass/lib/battery.sh::scaffold_project <profile>` (a wrapper that fixes the autonomous_formal gap in `helpers.sh::scaffold_test_project`), seeds required fixtures, performs the attack, runs the gate, asserts the expected outcome.

### B01 — Tests required on code change (R-001 AC1)

**Fixture required:** `bypass_seed_failing_test` writes `tests/test_bar.sh` that exits 1 if `src/foo.py` contains the literal "BROKEN", and writes STACK.md `test_fast: bash tests/test_bar.sh`.

**Attack:** Stage `Edit src/foo.py` adding "BROKEN"; run `git commit`.

**Code path traced:** `precommit_gate.check_tests` (precommit_gate.py:382) → `_resolve_test_command` returns `bash tests/test_bar.sh` (line 272) → `subprocess.run` → rc=1 → `GateResult.from_reason(messages.TESTS_FAILING, ...)` (line 461). Block.

**Expected outcome:** all 3 profiles → block (AC1).

### B02 — Pre-push contract coverage below threshold (R-002 AC3)

**Fixture required:** `bypass_seed_uncovered_feature` writes `.agentic/spec/contracts/F-T01.yaml`:
```yaml
feature_id: F-T01
lifecycle: in_progress
protection: contract
assertions:
  - id: A1
    text: "uncovered assertion 1"
    type: structural
    status: planned
  - id: A2
    text: "uncovered assertion 2"
    type: structural
    status: planned
  - id: A3
    text: "uncovered assertion 3"
    type: structural
    status: planned
migrations: []
```
Sets STACK.md `contract_coverage_threshold: 80`. **Precondition assertion:** before seeding, the helper runs `ag contract coverage` and asserts the parsed `Total assertions:` line shows 0 — round-3 Critic correction: with zero contracts, `coverage_pct` returns 0 (not 100), so the precondition cannot use `Coverage: 100%` as the marker. The right zero-baseline marker is `Total assertions: 0`. If `Total assertions:` is non-zero (`install.sh` shipped framework-baseline contracts), B02 SKIPs with a "scaffold not bare" outcome rather than producing a misleading PASS/FAIL.

**Attack:** Commit the contract via `AGENT_SKIP_GATE=1 AGENT_SKIP_GATE_REASON='B02 fixture' git commit -am 'seed F-T01'` (resolves round-2 Critic open question #7 — does NOT depend on `ag commit --skip-gate` working end-to-end in scaffold; the env-var path is what `ag commit --skip-gate` actually sets, per ag.sh); `git push`.

**Code path traced:** `prepush_gate.check_contract_coverage` (prepush_gate.py:372) → invokes `ag contract coverage` → parses "Coverage: 0%" (3 assertions, 0 tests) → 0 < 80 → block.

**Expected outcome:** all 3 profiles → block (R-002 AC3).

### B03 — Audit-trail integrity on `--skip-gate` (R-001 AC7 + R-002 AC6)

**Fixture required:** none beyond default scaffold + a local bare remote at `/tmp/<scaffold>/remote.git` (already set up by `battery.sh::scaffold_project` for B12 reuse).

**Attack:** On a state-only commit (e.g., `JOURNAL.md` edit), run `AGENT_SKIP_GATE=1 AGENT_SKIP_GATE_REASON='verification probe' git commit -am 'state probe'`; then `AGENT_SKIP_GATE=1 AGENT_SKIP_GATE_REASON='verification probe' git push`. Read `.agentic/journal/events.jsonl`.

**Code path traced:** `precommit_gate.handle_skip_gate` (precommit_gate.py:917-928) emits `gate_skipped` event; `prepush_gate.handle_skip_gate` (prepush_gate.py:725-736) emits `gate_skipped` + `push_attempt`. Verification: `events.jsonl` (path: `.agentic/journal/events.jsonl` per R-007) contains both records with non-empty `reason` field matching `'verification probe'`.

**Expected outcome:** all 3 profiles → both events present in events.jsonl with correct schema (`type`, `session_id`, `actor`, `payload.reason`). SUT here is the audit trail itself, not a block; pass = events written + parseable, fail = events missing or malformed.

### B04 — Plan-approved sentinel removal (R-001 AC3)

**Fixture required:** `bypass_seed_plan_approved` touches `.agentic/session/.plan-approved`. STACK.md must have `plan_review_enabled: yes` for the test to be valid in formal+ profiles.

**Attack:** `rm .agentic/session/.plan-approved`; stage code change; `git commit`.

**Code path traced:** `check_plan_approved` (precommit_gate.py:505) → `plan_review_enabled` true (formal+) → `sentinel.exists()` false → `GateResult.from_reason(messages.PLAN_NOT_APPROVED, ...)` (line 519). Block.

**Expected outcome:**
- discovery: AC3 skipped (`plan_review_enabled=no` per profiles.conf:14) → SKIP-by-design (matrix cell records "AC3 not enforced in this profile; commit proceeds; B04 attack is profile-skipped").
- formal, autonomous_formal: block.

### B05 — Journal staleness via mtime rollback (R-001 AC4)

**Fixture required:** `bypass_seed_journal` writes `.agentic/journal/JOURNAL.md` with a recent entry; commits it; then runs `python3 -c "import os; os.utime('.agentic/journal/JOURNAL.md', (86400, 86400))"` to roll mtime to UTC epoch 86400 (1970-01-02 00:00:00 UTC).

**Attack:** Stage code change; `git commit`.

**Code path traced:** `check_journal_freshness` (precommit_gate.py:528) → `is_formal_like` true → `_has_code_changes` true → `journal_mtime` (86400) + 5 < `head_ts` (~1.7e9 in 2026) → `GateResult.from_reason(messages.JOURNAL_STALE, ...)` (line 572). Block.

**Expected outcome:**
- discovery: AC4 skipped (`is_formal_like` false) → SKIP-by-design.
- formal, autonomous_formal: block.

**Why python `os.utime` (vs `touch -t` or `git checkout --`):** `git checkout -- JOURNAL.md` resets *content* to HEAD but updates *mtime* to NOW — newer than HEAD's commit time, so AC4 *passes* the freshness check (v1's bug). `touch -t` interprets timestamp in *local* time, which on TZ-positive systems (e.g., Helsinki UTC+3) maps 1970-01-02 local to a *negative* UTC epoch and rejects on some `touch` implementations (round-2 Critic finding). `os.utime` takes a UTC epoch directly — portable across timezones and POSIX implementations.

### B06 — Shipped contract edit without migration (R-001 AC5)

**Fixture required:** `bypass_seed_shipped_contract F-T02` performs the full shipped+protected lifecycle:

1. **Write YAML** at `.agentic/spec/contracts/F-T02.yaml` with literal content:
   ```yaml
   feature_id: F-T02
   lifecycle: shipped
   protection: contract
   assertions:
     - id: A1
       text: "fixture assertion"
       type: structural
       status: shipped
   migrations: []
   ```
   The seeder writes `lifecycle: shipped` and `protection: contract` directly, NOT via `ag contract promote` — `_contract_promote` only flips per-assertion `status`, never the top-level `lifecycle:` field (round-2 Critic finding; verified at contract.sh:901-971).
2. **Commit the shipped version** via `AGENT_SKIP_GATE=1 AGENT_SKIP_GATE_REASON='fixture seed' git commit -am 'seed F-T02'`. AC5 compares HEAD blob vs staged (precommit_gate.py:697-700); without HEAD having the shipped+protected version, `_git_show_head` returns None and AC5 short-circuits, falsely passing the attack.
3. **`chmod 444`** to match R-005's locked state. (R-005 first wall is tested separately in B07.)

**Attack:** `chmod u+w`; edit contract assertion in-place (e.g., change A1's `text:` field) without adding new `migrations:` entry; `chmod 444` back; stage; `git commit`.

**Code path traced:** `check_shipped_contract_migrations` (precommit_gate.py:688) → `_is_contract_path` true (line 592, matches `.yaml` + `spec/contracts/`) → `_git_show_head` returns prior shipped+protected content → `_is_shipped_protected_yaml` true (line 644-654, both `lifecycle: shipped` and `protection: contract` lines present) → `_count_migration_entries` head=0, staged=0 → `0 <= 0` → `GateResult.from_reason(messages.SHIPPED_CONTRACT_NO_MIGRATION, ...)` (line 717). Block.

**Expected outcome:** all 3 profiles → block (AC5 is profile-agnostic).

### B07 — R-005 chmod 444 prevents direct edit (two-step)

**Fixture required:** `bypass_seed_shipped_contract F-T03` (as B06, including write+commit+chmod 444). Seeder reads contract path from `CONTRACTS_DIR` env (resolved by `paths.sh:115` based on which directory the scaffolded project actually has) rather than hardcoding `.agentic/spec/contracts/` — round-2 Critic flagged that `helpers.sh::scaffold_test_project` formal profile creates `spec/contracts/` not `.agentic/spec/contracts/`. v3 wrapper `battery.sh::scaffold_project` pins all profiles to `.agentic/spec/contracts/` for consistency; B07 reads `$CONTRACTS_DIR/F-T03.yaml` either way.

**Attack:** Two assertions:
1. **Assert chmod 444 was applied.** `stat -c %a` (Linux) / `stat -f %p` (macOS) returns "444" on the shipped contract YAML.
2. **Attempt direct write.** `python3 -c "import os; open(os.environ['CONTRACTS_DIR']+'/F-T03.yaml', 'a').write('x')"`.

**Code path traced:** R-005 first wall is OS-level. `contract.sh::_contract_lock_shipped` runs `chmod 444` (line 67-70). POSIX denies write to non-owners on mode 444 → `PermissionError(errno=EACCES)`.

**Expected outcome:**
- Linux + macOS, all 3 profiles: both assertions pass (chmod = 444 AND PermissionError on write) → PASS.
- Windows: SKIP-by-design (chmod semantics don't apply).
- Running as root (`id -u` == 0): SKIP-by-design (root bypasses POSIX 444). Test asserts environment is non-root before running.

### B08 — chmod recovery → AC5 second wall (R-005 + R-001 AC5)

**Fixture required:** Same as B06 (`bypass_seed_shipped_contract F-T04`, including write+commit+chmod 444). The commit-then-edit phase is critical here for the same reason as B06 — without HEAD having the shipped+protected version, AC5 short-circuits.

**Attack:** `chmod u+w`; edit assertion; `chmod 444`; stage; `git commit` *without* adding migration entry.

**Code path traced:** R-005 deliberately bypassed (the documented escape path is `ag contract migrate` — using raw chmod is the adversarial probe). AC5 fires at commit time as the second wall: same path as B06.

**Expected outcome:** all 3 profiles → block (AC5 second wall).

### B09 — Fix mode preserves AC1 (R-010)

**Fixture required:** `bypass_seed_failing_test` (same as B01) — writes a failing test command + STACK.md test_fast.

**Attack:** Set `AGENT_FIX_MODE=1`; stage code change adding "BROKEN"; `git commit`.

**Code path traced:** `_build_context` (precommit_gate.py:275) reads `fix_mode = True`. `check_contracts` (line 466) returns "hotfix mode; contracts skipped" → AC2 skip. `check_plan_approved` (line 507) returns "hotfix mode; plan check skipped" → AC3 skip. `check_tests` (line 382) does NOT have fix-mode short-circuit → runs test command → fails → block.

**Expected outcome:** all 3 profiles → block at AC1; AC2 + AC3 skipped (verifying R-010 contract — fix mode relaxes spec/plan but preserves tests).

### B10 — Hook code tampering (R-004 AC0)

**Precondition:** `INTEGRITY_SKIP` env unset; `CI` env unset (otherwise integrity.py:33-37 skips). The `battery.sh::scaffold_project` helper unsets both before each test.

**Fixture required:** Run `ag integrity update` to mint baseline.

**Attack:** Append `# tampered` line to `.agentic/lib/hooks/precommit_gate.py`; stage code change; `git commit`.

**Code path traced:** `check_integrity` (precommit_gate.py:323) → `integrity.verify_all` reads baseline, computes current SHA-256 of `.agentic/lib/hooks/precommit_gate.py`, mismatches → `result.mismatches` non-empty → `GateResult.from_reason(messages.INTEGRITY_TAMPERED, ...)` (line 362). Block (runs first, before tests/contracts/etc.).

**Expected outcome:** all 3 profiles → block (integrity is profile-agnostic).

### B11 — `.claude/settings.json[hooks]` tampering (R-004 AC0)

**Precondition + Fixture:** Same as B10.

**Attack:** Modify the `hooks` field in `.claude/settings.json` (e.g., add a no-op entry); stage code change; `git commit`.

**Code path traced:** `integrity.verify_all` includes `.claude/settings.json[hooks]` per R-004 AC1 baselined paths (uses partial-document hashing — only the `hooks` field, not whole file). Mismatch → block.

**Expected outcome:** all 3 profiles → block.

### B12 — Pre-push range catches no-verify-bypassed migrations (R-002 AC5)

**Fixture required:** `bypass_seed_shipped_contract F-T05` (write+commit+chmod 444). Same commit-then-edit invariant as B06/B08.

**Attack:**
1. `git commit --no-verify` 3 commits in a row, the third including a shipped-contract edit (after `chmod u+w`) without a migration entry.
2. `git push` to a local file remote (`git init --bare /tmp/<scaffold>/remote.git` set up by `battery.sh::scaffold_project`).

**Code path traced:** Pre-commit hook silently skipped by git on `--no-verify` (acknowledged honest-limit). On push, prepush_gate walks `<remote_oid>..<local_oid>` (every commit in the range), runs migration-presence check on each. Third commit fails → exit 2 → push aborted.

**Expected outcome:** all 3 profiles → push blocked (R-002 AC5). Pre-push also exercises the --no-verify honest-limit pair (replaces v1 B02/B03 which were duplicates of this).

## Cross-profile matrix shape

12 tests × 3 profiles = 36 cells. Cell outcomes:

- **PASS**: gate fired and blocked / OS denied / event written, as expected
- **SKIP-by-design**: profile-skip is the documented expected behavior (e.g., AC4 in discovery, B07 on Windows, B07 as root)
- **FAIL**: gate did not fire when it should have, or fired when it should not have, or test infrastructure broken

The orchestrator (`tests/bypass/run_battery.sh`) iterates each B-test 3× regardless of whether profile-skip is encoded in the test. Per-test "all profiles" annotations are assertions about expected outcome, not test-skips.

Output schema (`tests/bypass/results/<timestamp>.json`):
```json
{
  "ts": "2026-04-27T...Z",
  "phase": "Phase 0",
  "matrix": [
    {"test": "B01", "profile": "discovery", "outcome": "PASS",
     "evidence": "exit=2; reason=TESTS_FAILING; rc_seen=1",
     "code_path": "check_tests:461"},
    ...
  ],
  "summary": {"pass": N, "skip_by_design": N, "fail": N}
}
```

## Out of scope (carry forward)

These surfaces are explicitly outside R-016's bypass-test budget. Recorded so they aren't silently lost:

| Surface | Why out of scope | Future home suggestion |
|---------|------------------|------------------------|
| Original sibling-doc B05 (path-smuggle Edit) | Phase 0 has no PreToolUse content classifier | Future Tier-1+ R-NNN |
| Original sibling-doc B06 (STACK.md edit while sentinel) | Phase 0 has no PreToolUse path-deny | Future R-NNN |
| Original sibling-doc B10 (silent **Files:** edit) | Phase 0 has no PreToolUse content classifier | Future R-NNN |
| R-001 AC6 (no-verify breadcrumb) | Informational; doesn't block | Could be observability test, not bypass test |
| R-002 AC4 (doc drift via drift.sh) | Complex SUT; formal+ only; not bypass-shaped | Separate verification item |
| R-003 (`ag merge`) | User-invoked command, not always-fire hook — different verification model (`--no-verify` doesn't apply) | Workflow-integration test, not bypass test |
| AC5 rename-bypass attack | Logic gap *within* AC5 (rename → new-file path skips check); fix-the-gate issue, not bypass-test | Open as separate issue against R-001 |
| AC1 state-only-commit smuggle | Code-changes path classifier could be evaded by labelling code as state | Separate concern; needs classifier hardening, not bypass test |
| INTEGRITY_SKIP audit path | CI-only environment | Out-of-scope for local battery |
| Tier 0 shim location unbaselined (`.agentic/hooks/pre-{commit,push}`) | integrity.py `_FULL_FILE_PATHS` only baselines `.git/hooks/pre-{commit,push}`; v6 places shims at `.agentic/hooks/` due to ag.sh `_ensure_hooks` interaction (round-5 fix). Attacker could `echo "exit 0" > .agentic/hooks/pre-commit` to bypass Tier 0 without tripping integrity. | **Pre-existing R-001/R-004 framework gap, not R-016 defect.** Future R-NNN should extend `_FULL_FILE_PATHS` to include `.agentic/hooks/pre-{commit,push}`. Identified by round-6 dialectical review; both reviewers agreed this is out-of-scope for R-016 plan revision. |

This list is informational. Per the user's "delicate plan, no improvisation" guidance, **no new R-NNNs are minted by this revision.** Whichever future R-NNN ships the missing surface inherits the corresponding test.

## Implementation breakdown

**Effort:** 5.5d (was 5d in v1; +0.5d for Day-1 scaffolding expansion accepted by user).

**Files to create:**
- `tests/bypass/lib/battery.sh` — scaffolding helpers wrapping `tests/infrastructure/lib/helpers.sh`. Adds: autonomous_formal STACK.md writer, `bypass_seed_failing_test`, `bypass_seed_shipped_contract`, `bypass_seed_plan_approved`, `bypass_seed_journal_with_past_mtime`, `bypass_assert_event_present`, env-hygiene check (unset INTEGRITY_SKIP, CI), /tmp cleanup trap.
- `tests/bypass/B01_tests_required.sh` through `tests/bypass/B12_prepush_range.sh`
- `tests/bypass/run_battery.sh` — orchestrator; iterates 12 tests × 3 profiles; writes `tests/bypass/results/<timestamp>.json`.
- `tests/bypass/README.md` — purpose, how to add tests, cross-profile semantics, env-hygiene contract.

**Files to modify:**
- `tests/run_tests.sh` — add advisory entry that runs the bypass battery (does not run by default to keep CI fast; opt-in via `RUN_BYPASS=1`).

**Pattern reuse:** `tests/infrastructure/structural/S05_hook_fires_end_to_end.sh` is the existing pattern (scaffold project → attempt → assert output). Each B-test follows that shape with bypass-specific seeders.

**Day-by-day:**
- **Day 1** (scaffolding, expanded): `battery.sh::scaffold_project <profile>` which calls `helpers.sh::scaffold_test_project` then performs the following setup:

  **(a) Tier 0 hook shim installation** *(round-5 fix — v5 assumed `core.hooksPath` defaulted to `.agentic/hooks` after install.sh, but `helpers.sh::scaffold_test_project` runs install.sh in non-interactive `discovery` mode where `scaffold.sh`'s `GIT_MODE=deferred` SKIPS the `core.hooksPath` write. Without explicit set, `core.hooksPath` is UNSET → git uses `.git/hooks/` (empty) → no hook fires. v6 fix: explicitly `git config core.hooksPath .agentic/hooks` regardless of scaffold profile)*:
  ```bash
  # Overwrite the legacy bash hook with the Tier 0 Python shim.
  cat > .agentic/hooks/pre-commit <<'EOF'
  #!/usr/bin/env bash
  exec python3 "$(git rev-parse --show-toplevel)/.agentic/lib/hooks/precommit_gate.py" "$@"
  EOF
  chmod +x .agentic/hooks/pre-commit
  cat > .agentic/hooks/pre-push <<'EOF'
  #!/usr/bin/env bash
  exec python3 "$(git rev-parse --show-toplevel)/.agentic/lib/hooks/prepush_gate.py" "$@"
  EOF
  chmod +x .agentic/hooks/pre-push

  # Explicitly point git at .agentic/hooks/ — required because helpers.sh's
  # discovery-profile scaffold leaves core.hooksPath unset. ag.sh::_ensure_hooks
  # would set it later on first ag invocation, but Day-1 stub (h2) runs
  # before any ag invocation, so the explicit set is required for ordering.
  git config core.hooksPath .agentic/hooks
  ```
  Note: `exec` in bash preserves stdin (POSIX semantics), so the pre-push shim correctly forwards git's ref-protocol stdin to `prepush_gate.py`. v5 Day-1 stub (h) verifies this empirically with a real push.

  **(b) Profile-specific STACK.md keys** *(review_* keys spelled out for install.sh-default parity; Tier 0 gates do NOT consume them — round-3 Critic medium clarification)*:
  - **discovery:** `profile: discovery`, `plan_review_enabled: no`, `pre_commit_hook: fast`
  - **formal:** `profile: formal`, `plan_review_enabled: yes`, `pre_commit_hook: fast`, `review_plan: critical_agent` *(non-SUT)*, `review_code: human` *(non-SUT)*, `review_merge: human` *(non-SUT)*, `contract_coverage_threshold: 80`
  - **autonomous_formal:** `profile: autonomous_formal`, `plan_review_enabled: yes`, `pre_commit_hook: fast`, `review_plan: critical_agent` *(non-SUT)*, `review_code: critical_agent` *(non-SUT)*, `review_regression: critical_agent` *(non-SUT)*, `review_merge: human` *(non-SUT)*, `contract_coverage_threshold: 80`

  Tier 0 gates only read `profile`, `plan_review_enabled`, `pre_commit_hook`, `test_fast`/`test`, `contract_coverage_threshold` (precommit_gate.py:276-290; prepush_gate.py:275-289). The review_* keys are included so the scaffolded STACK.md matches `ag init` output, not because B-test outcomes depend on them.

  **(c) Seed helpers** with canonical YAML schemas *(round-4 fix — v4 schemas (`feature_id:`, `id: A1`) didn't match `Contract.from_dict` requirements, causing `load_all_contracts` to silently skip the contract while the plan asserted it loaded successfully)*:

  - `bypass_seed_failing_test` — writes `tests/test_bar.sh` exiting 1 when `src/foo.py` contains "BROKEN", and STACK.md `test_fast: bash tests/test_bar.sh`.

  - `bypass_seed_shipped_contract <feature_id>` *(round-5 fix — feature IDs use all-digit form `F-9001..F-9005` to satisfy contracts.py:367 `_ID_PATTERN = ^(F|DEV|E|NFR)-\d{3,}(\.[1-9]\d*)*$`; v5's `F-T01..F-T05` would be rejected by `validate_contract`, breaking any code path that calls it on these fixtures)* — writes the canonical schema below (matches contracts.py validation: `id:` not `feature_id:`, assertion ids match `^AC-\d{3,}$`, `name:` ≥3 chars, `description:` ≥10 chars, structural assertions require `verify:`, `lifecycle:` ∈ `_VALID_LIFECYCLES` set including `shipped`):
    ```yaml
    id: F-9002          # all-digit ID per _ID_PATTERN; F-9002..F-9005 used across B06/B07/B08/B12
    name: Shipped Contract Fixture
    description: |
      Shipped+protected contract fixture for AC5 second-wall testing.
    lifecycle: shipped
    profile: both
    protection: contract
    assertions:
      - id: AC-001
        text: structural fixture assertion
        type: structural
        verify: "test -f /tmp/never-checked"
        status: shipped
    migrations: []
    ```
    Then commits via `AGENT_SKIP_GATE=1 git commit` (so HEAD has the shipped+protected version — required for AC5's HEAD-vs-staged comparison at precommit_gate.py:697-700) and chmod 444s the file.

  - `bypass_seed_uncovered_feature` *(round-5 fix — uses `F-9001` not `F-T01`)* — writes a contract with **behavioral** assertions (which don't require `verify:` per validate_contract:415) so they count in `total_assertions` but lack test linkage, producing `coverage_pct=0`:
    ```yaml
    id: F-9001          # all-digit ID per _ID_PATTERN
    name: Uncovered Feature Fixture
    description: |
      Adversarial fixture for B02 coverage attack — three uncovered behavioral assertions.
    lifecycle: implementing
    profile: both
    protection: none
    assertions:
      - id: AC-001
        text: uncovered behavioral assertion 1
        type: behavioral
        status: planned
      - id: AC-002
        text: uncovered behavioral assertion 2
        type: behavioral
        status: planned
      - id: AC-003
        text: uncovered behavioral assertion 3
        type: behavioral
        status: planned
    migrations: []
    ```
    Precondition assertion (round-3 Critic fix retained): before seeding, parse `bash .agentic/lib/tools/ag.sh contract coverage` output and assert `Total assertions: 0`. If non-zero (`install.sh` shipped baseline contracts), B02 SKIPs.

  - `bypass_seed_plan_approved` — touches `.agentic/session/.plan-approved`.

  - `bypass_seed_journal_with_past_mtime` — uses `python3 -c "import os; os.utime('.agentic/journal/JOURNAL.md', (86400, 86400))"` for UTC-anchored portable mtime rollback.

  - `bypass_seed_claude_settings` *(round-5 fix — v5's B11 (`.claude/settings.json[hooks]` tampering) silently fails because `install.sh` deliberately excludes `.claude/` (created by `setup-agent.sh claude`, not `install.sh`). integrity.py silently skips missing partial-JSON paths, so B11 has nothing to attack. Fix: write a minimal `.claude/settings.json` with a non-empty `hooks` field so B11 has a target)* — writes `.claude/settings.json` with content:
    ```json
    {
      "hooks": {
        "PreToolUse": []
      }
    }
    ```
    Then runs `ag integrity update` to baseline the file (so B11's tampering attack creates a real hash mismatch).

  Each seeder explicitly `export CONTRACTS_DIR=$(...)` after sourcing paths.sh, since paths.sh:163 omits CONTRACTS_DIR from its export list.

  **(d) Env-hygiene check** (asserts `INTEGRITY_SKIP` and `CI` unset before each test; aborts loudly if contaminated).

  **(e) /tmp cleanup trap** (cleans `/tmp/infra-test-<scaffold>` on test crash; `--keep-temp` flag opts out for forensics).

  **(f) Local bare remote** at `/tmp/<scaffold>/remote.git` initialized via `git init --bare` for B03 + B12 push targets. No server-side hooks needed; client-side prepush gate is the SUT.

  **(g) `run_battery.sh` skeleton** with serial execution, manifest-driven `known-fails.yaml` parsing, results JSON emitter, exit 2 on unlisted FAIL.

  **(h) Day-1 stub B-test** verifies wiring, context, schema, and pre-push stdin:

  1. **Context readability:** `python3 .agentic/lib/hooks/precommit_gate.py --print-context` returns expected profile/test_command/plan_review_enabled per scaffolded STACK.md.

  2. **Pre-commit Tier 0 wiring** *(round-4 fix — v4's banner-grep approach failed because `print_passed()` is gated on `sys.stderr.isatty()` at precommit_gate.py:843-846; under stderr capture, the banner is suppressed even when Tier 0 IS firing)*: perform a state-only `git commit` (touch JOURNAL.md, stage, commit) and read `.agentic/journal/events.jsonl`. Assert at least one event of type `contract_check` (or `test_run`) was appended with `actor: precommit_gate` AND timestamp after the commit. The legacy bash hook does not write to events.jsonl; presence of any `precommit_gate`-actored event proves the Tier 0 shim from step (a) is wired correctly. **Independent of stderr isatty, terminal type, or color settings.**

  3. **Seeder schema validation** *(round-4 fix — v4 seeder YAML failed `Contract.from_dict` validation; `load_all_contracts` silently skipped the contract; downstream B-tests would have measured the wrong state)*: after each seed helper runs, invoke `bash .agentic/lib/tools/ag.sh contract list` and assert the seeded `id:` (e.g., `F-T01`, `F-T02`) appears. Failure indicates schema mismatch — abort battery before any B-test runs.

  4. **Pre-push wiring + stdin forwarding** *(round-4 fix — v4 didn't explicitly verify pre-push shim stdin)*: do a real `git push` of one state-only commit to the local bare remote at `/tmp/<scaffold>/remote.git`. Read events.jsonl. Assert a `push_attempt` event was appended with `actor: prepush_gate`. The range walk requires reading stdin; the push_attempt event firing proves stdin reached the gate.

  5. **Schema validation via contracts.py CLI** *(round-5 Advocate fix — v5.4's `ag contract list` uses non-validating load (load_all_contracts catches+skips errors); a fixture that loads-but-fails-strict-validation passes h3 but breaks downstream code paths that call validate_contract)*: after each seed, run `python3 .agentic/lib/contracts.py validate <seeded.yaml>`. Assert exit code 0. Catches `_ID_PATTERN` violations (round-5 high #2), missing required fields, etc., before any B-test runs.
- **Day 2:** B01 (tests required), B05 (journal staleness), B06 (shipped contract migration), B07 (chmod 444 first wall).
- **Day 3:** B08 (chmod recovery → AC5 second wall), B09 (fix mode), B10 (hook code tampering), B11 (settings.json[hooks] tampering).
- **Day 4:** B02 (pre-push coverage), B03 (audit-trail integrity), B12 (pre-push range), B04 (plan-approved sentinel).
- **Day 5:** Full-battery dry-run; results matrix verification; README; journal entry; tests/run_tests.sh entry.
- **Day 5.5 (buffer):** Address failures discovered during dry-run; refine seeders if cross-profile assertions don't match observed behavior.

## Verification (manifest-driven, deterministically enforceable)

`bash tests/bypass/run_battery.sh` runs all 36 cells, writes a results JSON, and reads `tests/bypass/known-fails.yaml` (created empty in this revision; populated by the post-Phase-0 review).

**Pass criteria:**

The orchestrator exits 0 (verification complete) when, for every cell in the 36-cell matrix:
- outcome ∈ {PASS, SKIP-by-design}, OR
- outcome == FAIL AND the cell `(test, profile)` appears in `known-fails.yaml` with a non-empty `reason` and either a `journal_ref:` (path to journal entry citing the gap) or an `r_nnn:` (future R-NNN owning the fix).

The orchestrator exits 2 (verification incomplete) when ≥1 cell has outcome FAIL without a `known-fails.yaml` entry.

`known-fails.yaml` schema:
```yaml
known_fails:
  - test: B0X
    profile: discovery|formal|autonomous_formal
    reason: "1-line description of the Phase 0 gap"
    journal_ref: ".agentic/journal/JOURNAL.md#YYYY-MM-DD-..."   # OR
    r_nnn: "R-NNN"
```

This makes "every FAIL must be linked" deterministically enforceable by the orchestrator (round-2 Critic finding: v2's prose-only criterion required manual review). No "soft pass." No 2-FAIL tolerance. The post-Phase-0 review is the only sanctioned writer of `known-fails.yaml`.

## What this revision does NOT change

- R-016's **goal** (Phase 0 verification evidence)
- R-016's **deliverable shape** (12 × 3 = 36 matrix, pass/fail format)
- R-016's **declared deps** (R-001, R-002, R-003, R-004, R-005, R-010 — all shipped)
- R-016's **placement** (Phase 0 closeout, before Phase 1 starts)
- Any other R-NNN in the redesign-backlog
- The mutation-test (M01–M14) out-of-scope clause from the original

**Derived consequence (not a separate scope change):** Filenames in `Files to create:` track the realigned attack-vector names (e.g., `B01_tests_required.sh` vs original `B01_no_verify.sh`). This is a direct consequence of the attack-vector realignment — when the test changes, the file naming follows.

**Effort:** 5d → 5.5d (+0.5d for Day-1 scaffolding expansion). Accepted by user.

## Open questions for reviewers (v3)

Round-2 questions that v3 resolved:
- ~~Q1 Pass-threshold strictness~~ — resolved via manifest-driven `known-fails.yaml`.
- ~~Q4 Env hygiene~~ — resolved: pre-test invariant check fails loudly if INTEGRITY_SKIP/CI contaminated.
- ~~Q5 Parallelism~~ — resolved: serial; correctness > speed (~10–20 min runtime acceptable for a battery that runs rarely).
- ~~Q6 /tmp cleanup~~ — resolved: trap + cleanup; `--keep-temp` opt-in for forensic mode.
- ~~Q7 ag-installation in scaffold~~ — resolved: B02/B03/B12 use `AGENT_SKIP_GATE=1 git commit` directly (the env-var path that `ag commit --skip-gate` sets internally); does not depend on scaffolded `ag` end-to-end.

Remaining for round-3 reviewers (or post-approval implementation refinement):

1. **B07 root-user handling.** Skip-on-root is documented and asserted via `id -u` check. Is auto-detect sufficient, or should the test require a non-root runtime as a hard precondition that aborts the whole battery?
2. **B12 no-verify scenario timing.** v3 attempts the 3 prior commits at runtime (not pre-baked). Confirm: is runtime --no-verify portable across git versions (some hooks reject --no-verify at server-config level)?
3. **`known-fails.yaml` initial population.** v3 ships an empty manifest. The post-Phase-0 review is the only sanctioned writer. If round-3 / implementation surfaces a Phase 0 gap before that review, what's the path to populate the manifest? My read: surfaced gaps go to JOURNAL.md as known-limitation entries; the post-Phase-0 review then transcribes them into the manifest. This keeps writer-discipline tight.

## Revision history

**v6 dialectical review — CONVERGED** (round 6, both reviewers APPROVE):
- Critic verdict: APPROVE / CONVERGED. Zero new architectural bugs across 9 inspected code paths (contracts.py CLI, legacy pre-commit-check.sh, integrity.py baseline enumeration, _git_show_head initial-commit case, AC1 timeout, ag.sh self-heal interaction, events.jsonl path resolution, integrity baseline minting, migration counter edge cases). One medium finding (unbaselined shim location) flagged as **pre-existing R-001/R-004 gap, not v6 defect** — added to out-of-scope table. One low finding (per-AC assertion granularity in B-tests) flagged as implementation-time detail.
- Advocate verdict: APPROVE / CONVERGED. All four v6 fixes verified against actual code (v6.1 via ag.sh:215-231 + scaffold.sh:519-537; v6.2 via contracts.py:367 `_ID_PATTERN`; v6.3 via integrity.py partial-JSON baselining; v6.4 via contracts.py:971-984 CLI). Trajectory finally inflected — round 6 broke the "each round finds new architectural bug" pattern.

**Implementation-time notes (not plan-spec changes; from round-6 Critic low-severity finding):**
- Each B-test should assert two things on the gate result: (a) exit code = 2 (block) AND (b) the specific `AC<N>` label appears in stderr or in the `gate_blocked` event's `payload.failures` list. The gate runs all checks and reports all failures (precommit_gate.py:866-880); per-AC assertion ensures the test exercises its claimed SUT, not a different gate that happened to fire.

**v5 → v6 changes** (responding to round-5 dialectical review; both reviewers REVISE — Critic found v5.2 hook-shim assumption is wrong; Advocate found `_ID_PATTERN` violation):

| # | Change | Source | Severity |
|---|--------|--------|----------|
| v6.1 | Day-1 (a): explicit `git config core.hooksPath .agentic/hooks` after writing the shim files. v5 assumed `core.hooksPath` defaulted to `.agentic/hooks` post-install, but helpers.sh's discovery-profile scaffold leaves it UNSET → git uses `.git/hooks/` (empty) → no hook fires. v6 forces the config write regardless of scaffold profile. | Round-5 Critic high #1 | Bug fix (architectural) |
| v6.2 | Seeder fixture IDs: `F-T01..F-T05` → `F-9001..F-9005`. contracts.py:367 `_ID_PATTERN = ^(F|DEV|E|NFR)-\d{3,}(...)$` rejects letter-suffixed IDs; any code path calling validate_contract on v5 fixtures would fail. v6 uses all-digit IDs that pass the pattern and don't collide with real F-NNNN production features. | Round-5 Advocate high | Bug fix (architectural) |
| v6.3 | New seeder `bypass_seed_claude_settings` writes minimal `.claude/settings.json` with non-empty `hooks` field + runs `ag integrity update` to baseline it. Required for B11; install.sh deliberately excludes `.claude/` (created by `setup-agent.sh`), so without explicit seed B11 silently fails-without-firing. | Round-5 Critic medium | Bug fix |
| v6.4 | Day-1 stub h5: `python3 .agentic/lib/contracts.py validate <seeded.yaml>` post-seed. v5.4's `ag contract list` uses non-validating load (catches+skips errors); a load-passes-validate-fails fixture would slip past h3 but break downstream code paths. h5 catches at Day-1. | Round-5 Advocate medium | Defensive |

**v4 → v5 changes** (responding to round-4 dialectical review; Critic = REVISE with 2 new high-severity, Advocate = REVISE with 1 new high-severity — both reviewers agreed v4 is broken):

| # | Change | Source | Severity |
|---|--------|--------|----------|
| v5.1 | Day-1 (h2) wiring assertion: replaced banner-grep (broken by `print_passed` isatty gate at precommit_gate.py:843-846) with events.jsonl assertion (look for `contract_check` or `test_run` event with `actor: precommit_gate`). Independent of isatty/TTY/color settings. | Round-4 Critic high #1 | Bug fix (architectural) |
| v5.2 | Hook shim location: relocated from `.git/hooks/pre-{commit,push}` to `.agentic/hooks/pre-{commit,push}`, OVERWRITING the legacy bash hook installed by install.sh. Avoids interaction with `ag.sh::_ensure_hooks` (lines 215-231) which restores `core.hooksPath=.agentic/hooks` on every ag invocation, silently defeating the `.git/hooks/` shim. | Round-4 Critic high #3 (raised by Advocate) | Bug fix (architectural) |
| v5.3 | Seeder YAML schemas: now match `Contract.from_dict` canonical structure — `id:` (not `feature_id:`), `name:` ≥3 chars, `description:` ≥10 chars, assertion ids `^AC-\d{3,}$`, structural assertions include `verify:`, `lifecycle:` ∈ `_VALID_LIFECYCLES`. B02 uses `behavioral` assertions (no `verify:` required) for uncovered-coverage scenario; B06/B07/B08/B12 use `structural` assertions with `verify:` for shipped+protected scenarios. | Round-4 Critic high #2 | Bug fix (architectural) |
| v5.4 | Day-1 (h3) seeder schema validation: after each seed runs, invoke `ag contract list` and assert seeded `id` appears. Catches schema mismatch immediately, before B-tests measure silent-load-failure state. | Round-4 Critic high #2 | Defensive |
| v5.5 | Day-1 (h4) pre-push stdin forwarding: do real `git push` to bare remote, assert `push_attempt` event appears in events.jsonl. Proves stdin reaches the gate. | Round-4 Advocate medium | Defensive |

**v3 → v4 changes** (responding to round-3 dialectical review; Critic = REVISE / NOT_CONVERGED with 1 new high-severity, Advocate = APPROVE / CONVERGED):

| # | Change | Source | Severity |
|---|--------|--------|----------|
| v4.1 | Day-1 (a): explicit Tier 0 hook shim installation in `.git/hooks/pre-commit` and `.git/hooks/pre-push`, with `core.hooksPath` unset to ensure `.git/hooks/` takes precedence over inherited `.agentic/hooks/` (legacy bash hook). Stub B-test verifies the Tier 0 banner appears in stderr, proving wiring not just import. | Round-3 Critic high #1 | Bug fix (architectural) |
| v4.2 | Day-1 (h): stub B-test now does state-only commit AND asserts Tier 0 banner (`pre-commit gate:`) appears in stderr; not just `--print-context` import-test. | Round-3 Critic high #1 | Defensive |
| v4.3 | B02 precondition: parse `Total assertions:` line from `ag contract coverage` (NOT `Coverage: 100%`, which is unreachable for zero-contract state since `coverage_pct=0` when total=0). | Round-3 Critic medium | Bug fix |
| v4.4 | Seeder helpers: explicit `export CONTRACTS_DIR=$(...)` after sourcing paths.sh, since paths.sh:163 export list omits CONTRACTS_DIR. | Round-3 Critic low | Bug fix |
| v4.5 | Day-1 (b): review_* STACK.md keys annotated as `(non-SUT)` — kept for `ag init` parity, but Tier 0 gates do not consume them. | Round-3 Critic low | Specification clarity |

**v2 → v3 changes** (responding to round-2 dialectical review; Critic = REVISE / NOT_CONVERGED, Advocate = APPROVE / CONVERGED):

| # | Change | Source | Severity |
|---|--------|--------|----------|
| v3.1 | B06/B08/B12 seeder: explicit YAML write of `lifecycle: shipped` and `protection: contract` (NOT via `ag contract promote` alone, which only flips per-assertion status). | Round-2 Critic high #1 | Bug fix |
| v3.2 | B06/B08/B12 seeder: commit-then-edit phase made explicit. Seeder commits the shipped+protected version BEFORE the attack, so AC5's `_git_show_head` returns prior content (not None, which would short-circuit the check). | Round-2 Critic high #2 | Bug fix |
| v3.3 | Pass criteria: replaced prose-only "every FAIL linked to journal/issue" with manifest-driven `tests/bypass/known-fails.yaml` (deterministically enforceable by orchestrator; orchestrator exits 2 on unlisted FAILs). | Round-2 Critic medium | Refinement |
| v3.4 | Day-1 deliverable: spelled out exact STACK.md keys per profile (discovery/formal/autonomous_formal — six keys for autonomous_formal vs implicit "writer" in v2). | Round-2 Critic medium | Specification |
| v3.5 | B07 path: now reads from `$CONTRACTS_DIR` env (resolved by paths.sh), with `battery.sh::scaffold_project` pinning all profiles to `.agentic/spec/contracts/`. | Round-2 Critic medium | Bug fix |
| v3.6 | B05 attack: replaced `touch -t 197001020000.00` (timezone-fragile in TZ+ regions) with `python3 os.utime('...', (86400, 86400))` (UTC-anchored, portable). | Round-2 Critic medium | Bug fix |
| v3.7 | B02 fixture: explicit YAML schema for uncovered feature; pre-test assertion that scaffold has no baseline-covered contracts (or SKIP if it does). | Round-2 Critic low #7 | Specification |
| v3.8 | B02/B03/B12 scaffold: replaced `ag commit --skip-gate` invocation with direct `AGENT_SKIP_GATE=1 AGENT_SKIP_GATE_REASON=... git commit` (the env-var path that ag.sh sets internally; does not depend on scaffolded ag.sh end-to-end). | Round-2 Critic low #8 (open Q7 resolution) | Bug fix |
| v3.9 | Day-1 stub B-test: runs `precommit_gate.py --print-context` to verify profile/test_command/plan_review_enabled match scaffold expectations. | Round-2 Critic low #8 | Defensive |
| v3.10 | Open questions reduced from 7 to 3; resolved questions explicitly struck through with resolution noted. | Round-2 Critic improvisation flag | Cleanup |
| v3.11 | Local bare remote at `/tmp/<scaffold>/remote.git` declared in Day-1 scaffolding (B03 + B12 prerequisite, was implicit in v2). | Round-2 Critic medium | Specification |

**v1 → v2 changes** (responding to round-1 dialectical review):

| # | Change | Source | Severity |
|---|--------|--------|----------|
| 1 | Day-1 adds explicit autonomous_formal scaffolding branch (`battery.sh::scaffold_project`) | Critic high #1 | Bug fix |
| 2 | B01 attack: now requires `bypass_seed_failing_test` + code change marker; was just "stage code without test" | Critic high #2 | Bug fix |
| 3 | B05 attack: now `touch -t 197001020000.00` to roll mtime back; was `git checkout -- JOURNAL.md` (which updates mtime to NOW) | Critic high #3 | Bug fix |
| 4 | B06/B07/B08/B12 fixtures: explicit `bypass_seed_shipped_contract` helper | Critic high #4 | Bug fix |
| 5 | v1 B02/B03 (--no-verify duplicates of B12) replaced with new B02 (R-002 AC3 coverage) and new B03 (R-001/R-002 audit-trail integrity) | Critic medium #5,6,7 | Coverage gap |
| 6 | Pass criteria tightened from "≥34/36" to "36/36 PASS|SKIP-by-design with each FAIL linked to issue/journal" | Critic + Advocate | Refinement |
| 7 | B07: now two-step assertion (chmod=444 AND PermissionError on write); added root-user skip | Advocate concession | Refinement |
| 8 | Each B-test now annotated with "Code path traced" referencing precommit_gate.py / prepush_gate.py / integrity.py / contract.sh by line | Critic root cause: v1 attacks didn't actually trigger SUTs | Defensive |
| 9 | Filenames in `Files to create:` annotated as derived from attack-vector realignment | Advocate concession | Transparency |
| 10 | `tests/run_tests.sh` integration moved from Day-5 paragraph to explicit `Files to modify:` list | Critic improvisation flag | Transparency |
| 11 | Out-of-scope expanded: R-003 (different verification model), R-002 AC4 doc drift, AC5 rename-bypass, AC1 state-only smuggle, INTEGRITY_SKIP audit | Critic missed-surfaces list | Scope clarity |
| 12 | New open questions: env hygiene, parallelism, /tmp cleanup, scaffold ag-installation, scaffolded validate_framework.sh | Critic open-questions-missing | Scoping |
| 13 | Each B-test now lists its required fixtures (linked to Day-1 seeder helpers) | Critic root cause | Defensive |
| 14 | Effort 5d → 5.5d (Day-1 scaffolding expansion) | User-accepted | Bookkeeping |

**Test count:** preserved at 12 (deliverable-shape invariant). Composition changed: v1 B02 + B03 (--no-verify variants, duplicates of B12) replaced with R-002 AC3 coverage + audit-trail integrity. Reasoning in synthesis (chat).

**Test-name continuity:** B-prefix preserved for continuity with original R-016 numbering, but each test now describes its actual SUT (B01_tests_required.sh, B12_prepush_range.sh, etc.) rather than sibling-doc legacy names.
