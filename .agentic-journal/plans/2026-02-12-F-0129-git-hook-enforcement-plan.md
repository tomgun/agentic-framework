# F-0129: Git Hook Enforcement — Prevent Direct `git commit` Bypass

**Revision**: 3 — **APPROVED** after 3 review iterations

## Context

Two enforcement gaps discovered this session:

**Gap 1 — No git hooks installed**: Committed 3 times using `git add && git commit` directly, bypassing every quality gate. The pre-commit-check.sh (716 lines, 13 checks) exists in `.agentic/hooks/` but is never wired as an actual git hook. `.git/hooks/` contains only `.sample` files. `core.hooksPath` is not set.

**Gap 2 — `ag plan` requires acceptance criteria**: `cmd_plan()` lines 423-430 hard-block if `spec/acceptance/F-XXXX.md` doesn't exist. But the plan-review loop is a *planning* tool — it helps figure out WHAT to build. Requiring specs before you can plan is backwards. Acceptance criteria should gate implementation (`ag implement`), not planning (`ag plan`).

---

## Prerequisite Fix: Loosen `ag plan` gate

**File**: `.agentic/tools/ag.sh` lines 423-430

**Current** (hard block):
```bash
if [ ! -f "$acc_file" ]; then
    echo -e "${RED}BLOCKED: No acceptance criteria${NC}"
    exit 1
fi
```

**New** (advisory, not blocking):
```bash
if [ ! -f "$acc_file" ]; then
    echo -e "${YELLOW}Note: No acceptance criteria yet (spec/acceptance/${feature_id}.md)${NC}"
    echo "  The plan-review loop can help define what to build."
    echo "  Acceptance criteria will be required before 'ag implement'."
    echo ""
fi
```

~5 lines changed. `ag implement` has its own independent hard gate at line 574-583, so the enforcement chain remains intact: plan (advisory) → specs (manual) → implement (hard gate).

---

## Fix 1: Replace `.agentic/hooks/pre-commit` with dispatcher

**Current**: 25-line wrapper that only runs `validate_specs.py` (spec format check).
**New**: Dispatcher (~35 lines) that:
- Detects project root via `git rev-parse --show-toplevel`
- **CI detection**: If `CI=true`, `GITHUB_ACTIONS`, `GITLAB_CI`, `JENKINS_URL`, or `BUILDKITE` is set, exit 0
- Reads `pre_commit_hook` from STACK.md (default: `fast`)
- **Backward compat**: Maps `yes` → `fast`, `no` → skip
- If `no`: exit 0
- **Spec validation**: Only if `spec/FEATURES.md` exists (Core+PM indicator), run `validate_specs.py`. Skip silently for Core profile to avoid pip dependency failures.
- If `fast` (default): route to `pre-commit-check.sh --mode fast`
- If `full`: route to `pre-commit-check.sh --mode full`

## Fix 2: Add `--mode` flag to `.agentic/hooks/pre-commit-check.sh`

~15 lines near the top. Use internal `_FAST_MODE=1` flag (NOT `SKIP_TESTS=1` to avoid collision with user-facing escape hatch).

**All 13 checks classified for fast vs full mode:**

| Check | Description | Type | Fast mode |
|-------|------------|------|-----------|
| 1 | WIP.md must not exist | BLOCKING | **KEEP** |
| 2 | Shipped features have acceptance criteria | BLOCKING | **KEEP** |
| 3 | JOURNAL.md freshness | BLOCKING | **KEEP** |
| 3b | STATUS.md freshness | BLOCKING | **KEEP** |
| 3c | FEATURES.md freshness (Core+PM) | BLOCKING | **KEEP** |
| 4 | STACK.md version sanity | WARNING | skip |
| 5 | Batch size warning | WARNING | skip |
| 6 | Test execution | BLOCKING | **SKIP** (too slow) |
| 7 | Complexity limits | BLOCKING | **KEEP** |
| 8 | Untracked files | WARNING | skip |
| 9 | LLM test status (framework only) | advisory | skip |
| 10 | Instruction file sizes | advisory | skip |
| 11 | Branch policy for PR workflow | BLOCKING | **KEEP** |
| 12 | Workflow bypass detection (Core+PM) | WARNING | skip |

Fast mode keeps: 1, 2, 3, 3b, 3c, 7, 11 (all structural blocking checks except tests).
Fast mode skips: 4, 5, 6, 8, 9, 10, 12 (tests, warnings, advisories).

## Fix 3: Wire hooks via `core.hooksPath` in scaffold.sh

Replace current file-copy installation (lines 366-378) with:
```bash
git config core.hooksPath .agentic/hooks
```
- Install for **both** profiles (not just Core+PM)
- Core profile users: most Core+PM-specific checks self-skip (2, 3c, 12 already detect profile)
- Remove the old file-existence guard (line 367) since `core.hooksPath` doesn't create files
- Fallback to file copy for git < 2.9 (unlikely but safe)

## Fix 4: Add `ag hooks install|status|disable` command

Manual hook management for existing projects:
- `ag hooks install`: `git config core.hooksPath .agentic/hooks`
- `ag hooks status`: show current `core.hooksPath` config + whether hooks are active
- `ag hooks disable --confirm`: `git config --unset core.hooksPath` with warning message ("This disables all pre-commit quality gates") and requires `--confirm` flag

## Fix 5: Add hook check to `ag sync` (Phase 6)

New phase in sync.sh after phase 5 (tool parity):
- Check if `core.hooksPath` is configured to `.agentic/hooks`
- Full mode: auto-fix by running `git config core.hooksPath .agentic/hooks`
- Quiet mode: count as an issue in the summary
- Check mode: report but don't fix

## Fix 6: Add hook status to `ag start`

If hooks aren't configured, show warning in session dashboard (like the existing sync probe).

## Fix 7: Update STACK.md template + upgrade.sh

**STACK.template.md**: Uncomment and update existing line 208 from `<!-- - pre_commit_hook: yes -->` to active `pre_commit_hook: fast` with values documented as `fast|full|no` (backward compat: `yes` maps to `fast`).

**upgrade.sh**:
- Configure `core.hooksPath` during framework upgrades
- Clean up stale `.git/hooks/pre-commit` if it was file-copied by old scaffold.sh (check if it contains `validate_specs.py` — if so, it's ours and safe to remove)
- Map existing `pre_commit_hook: yes` to `fast` in STACK.md

---

## Files to modify

| File | Change | ~Lines |
|------|--------|--------|
| `.agentic/tools/ag.sh` | Loosen `ag plan` gate + `ag hooks` cmd + start warning | ~55 |
| `.agentic/hooks/pre-commit` | Replace with dispatcher (CI detect + validate_specs + routing) | ~35 |
| `.agentic/hooks/pre-commit-check.sh` | Add `--mode` flag with `_FAST_MODE` internal var | ~15 |
| `.agentic/init/scaffold.sh` | `core.hooksPath` instead of file copy, remove old guard | ~15 |
| `.agentic/tools/sync.sh` | New phase 6: git hook check | ~25 |
| `.agentic/init/STACK.template.md` | Uncomment + update `pre_commit_hook` setting | ~3 |
| `.agentic/tools/upgrade.sh` | Hook config + stale file cleanup + value migration | ~15 |

Total: ~7 files, ~165 lines.

## Verification

1. `bash tests/validate_framework.sh` — 184+ pass
2. `ag plan F-XXXX` works WITHOUT acceptance criteria (shows advisory note)
3. `ag implement F-XXXX` still BLOCKS without acceptance criteria
4. `git config core.hooksPath` returns `.agentic/hooks`
5. `git commit` with staged changes — hook fires, validate_specs + checks run
6. `pre_commit_hook: yes` in STACK.md — maps to fast mode (backward compat)
7. `pre_commit_hook: no` in STACK.md — hook skips gracefully
8. `CI=true git commit` — hook skips (CI detection)
9. `ag sync --check` — reports hook status
10. `ag hooks status` — shows "INSTALLED"
11. `ag hooks disable` without `--confirm` — rejects with warning
12. New project via scaffold — hooks auto-configured
13. Upgrade from old scaffold — stale `.git/hooks/pre-commit` cleaned up

## Review History

### Review 1 — REVISION_NEEDED (3 critical, 6 important)
- CRITICAL: STACK.template.md already has `pre_commit_hook: yes` on line 208 → Fixed: uncomment + evolve
- CRITICAL: Check numbering wrong throughout → Fixed: full 13-check table with correct numbers
- CRITICAL: Spec validation regression (validate_specs.py lost) → Fixed: dispatcher runs it before routing
- IMPORTANT: Pre-commit is 25 lines, not 26 → Fixed
- IMPORTANT: Check 10 unassigned → Fixed: skip in fast mode
- IMPORTANT: SKIP_TESTS collision → Fixed: use internal `_FAST_MODE` var
- IMPORTANT: CI environments blocked → Fixed: CI detection in dispatcher
- IMPORTANT: `ag hooks remove` lacks safeguards → Fixed: renamed to `disable --confirm`
- IMPORTANT: Stale `.git/hooks/pre-commit` after upgrade → Fixed: cleanup in upgrade.sh

### Review 2 — REVISION_NEEDED (1 critical, 1 important, 5 suggestions)
- CRITICAL: validate_specs.py breaks Core profile (pip deps missing) → Fixed: only run when `spec/FEATURES.md` exists (Core+PM indicator)
- IMPORTANT: CI detection misses Jenkins/GitLab → Fixed: added `GITLAB_CI`, `JENKINS_URL`, `BUILDKITE`
- SUGGESTION: Display counter inconsistency → Will clean up during --mode implementation
- SUGGESTION: `--confirm` flag is new UX pattern → Accepted, appropriate for destructive action
- SUGGESTION: Documentation for ag plan gate change → Will update auto_orchestration.md
- SUGGESTION: Check count "13" ambiguous → Table has 13 rows, clear enough

### Review 3 — APPROVED
- Verified both Review 2 fixes properly addressed
- No new CRITICAL or IMPORTANT issues found
- Confirmed `cmd_implement()` hard gate at lines 574-583 is independent
- Check table classification verified against source
- Scope (7 files, ~165 lines) confirmed reasonable
