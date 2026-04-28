#!/usr/bin/env bash
# B09_fix_mode_preserves_ac1.sh — R-010 fix mode skips AC2/AC3 but preserves AC1.
#
# Attack: set AGENT_FIX_MODE=1; stage broken code (no test fix); commit.
# Expected: AC2 (contracts) + AC3 (plan-approved) skip per fix-mode short-circuits;
#           AC1 (tests) still fires → block.
#
# Code path traced:
#   _build_context (precommit_gate.py:275) → fix_mode=True (env AGENT_FIX_MODE=1)
#   check_contracts (line 466): fix_mode → return early "hotfix mode; contracts skipped"
#   check_plan_approved (line 507): fix_mode → return early "hotfix mode; plan check skipped"
#   check_tests (line 382): NO fix_mode short-circuit → runs test_fast →
#       rc=1 → from_reason(TESTS_FAILING) at line 461.
#
# Profile matrix: all profiles → block at AC1. Fix mode doesn't depend on profile.
# This validates R-010 AC2 ("Pre-commit still requires: a test added/modified, ...").

set -euo pipefail
B_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/battery.sh
source "$B_DIR/lib/battery.sh"

profile="${1:-discovery}"

(
    set -e
    scaffold_project "$profile"
    bypass_seed_failing_test

    mkdir -p src
    echo "# BROKEN sentinel" > src/foo.py
    git add src/foo.py

    set +e
    # AGENT_FIX_MODE=1 turns on R-010's fix mode. The gate's _build_context
    # reads this env var directly (precommit_gate.py:279).
    out=$(AGENT_FIX_MODE=1 git commit -m "B09 attack: fix mode without test" 2>&1)
    rc=$?
    set -e

    code_path="precommit_gate.check_tests:461 (under AGENT_FIX_MODE=1)"

    if [[ $rc -eq 0 ]]; then
        echo "FAIL|fix mode bypassed AC1 — R-010 contract violated|$code_path"
    elif bypass_assert_gate_blocked_by_ac "AC1" "precommit"; then
        # Review fix #1: structured event assertion.
        echo "PASS|AC1 fires under fix mode (gate_blocked event with AC1; R-010 preserves tests gate)|$code_path"
    else
        ev=$(echo "$out" | head -3 | tr '\n' ';' | sed 's/|/_/g')
        echo "FAIL|blocked but not by AC1; no AC1 in gate_blocked event; output: $ev|$code_path"
    fi
)
