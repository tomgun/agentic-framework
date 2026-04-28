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

    # Block happened. Verify it was AC1 specifically. The gate prints the
    # blocking AC labels on stderr (precommit_gate.py:803-880 print_blocked).
    # In addition, check_tests emits a test_run event with returncode != 0.
    if echo "$out" | grep -qiE "AC1|tests fail|test failed|tests failing"; then
        echo "PASS|commit blocked by AC1 (exit=$rc; tests-required fired)|$code_path"
    elif bypass_assert_event_present "test_run" "precommit_gate"; then
        # Fall back to events.jsonl — test_run event present means AC1 ran.
        echo "PASS|commit blocked (exit=$rc); test_run event in events.jsonl|$code_path"
    else
        # Block was for some other reason — record evidence for forensic review.
        local_evidence=$(echo "$out" | head -3 | tr '\n' ';' | sed 's/|/_/g')
        echo "FAIL|blocked but not by AC1 (exit=$rc); output: $local_evidence|$code_path"
    fi
)
