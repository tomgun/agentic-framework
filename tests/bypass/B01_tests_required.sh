#!/usr/bin/env bash
# B01_tests_required.sh — R-001 AC1 (tests required on code change).
#
# Attack: stage `src/foo.py` containing "BROKEN" sentinel (no test added);
#         the seeded test_fast command fails when the sentinel is present.
# Expected: all profiles → commit blocked by AC1 (TESTS_FAILING).
#
# Code path traced:
#   _build_context (precommit_gate.py:275) reads test_fast from STACK.md →
#   _resolve_test_command (line 242-272) returns "bash tests/test_bar.sh" →
#   check_tests (line 382) → has_code_changes(staged) returns True →
#   subprocess.run("bash tests/test_bar.sh") rc=1 →
#   GateResult.from_reason(messages.TESTS_FAILING, ...) (line 461).
#
# Profile matrix:
#   discovery       → block (AC1; pre_commit_hook=fast in scaffold default)
#   formal          → block
#   autonomous_formal → block
#
# B-test contract:
#   stdin: profile arg ($1)
#   stdout: single line "OUTCOME|evidence|code_path"
#           OUTCOME ∈ {PASS, SKIP-by-design, FAIL}

set -euo pipefail
B_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/battery.sh
source "$B_DIR/lib/battery.sh"

profile="${1:-discovery}"

# Subshell so scaffold cd/exports are scoped to this run.
(
    set -e
    scaffold_project "$profile"
    bypass_seed_failing_test

    # Stage the broken-code attack.
    mkdir -p src
    echo "# BROKEN sentinel — fails tests/test_bar.sh by design" > src/foo.py
    git add src/foo.py

    # Attempt commit; the Tier 0 shim runs precommit_gate.py which should
    # invoke test_fast, see rc=1, and block via TESTS_FAILING.
    set +e
    out=$(git commit -m "B01 attack: BROKEN code without test fix" 2>&1)
    rc=$?
    set -e

    code_path="precommit_gate.check_tests:461"

    if [[ $rc -eq 0 ]]; then
        echo "FAIL|commit succeeded with exit 0 — AC1 did not block|$code_path"
        exit 0
    fi

    # Review fix #1: assert via structured gate_blocked event in events.jsonl
    # (payload.failures contains {ac: AC1}) rather than grepping stderr prose.
    # Survives messages.py wording changes; pivots on the AC ID, not text.
    if bypass_assert_gate_blocked_by_ac "AC1" "precommit"; then
        echo "PASS|commit blocked by AC1 (exit=$rc; gate_blocked event with AC1)|$code_path"
    else
        local_evidence=$(echo "$out" | head -3 | tr '\n' ';' | sed 's/|/_/g')
        echo "FAIL|blocked but not by AC1 (exit=$rc); no AC1 in gate_blocked event; output: $local_evidence|$code_path"
    fi
)
