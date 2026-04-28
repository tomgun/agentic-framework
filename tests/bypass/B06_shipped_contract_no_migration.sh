#!/usr/bin/env bash
# B06_shipped_contract_no_migration.sh — R-001 AC5 (shipped+protected contract
# edited without a new migration entry).
#
# Attack: chmod u+w the seeded F-9002 contract; edit the assertion text;
#         chmod 444; stage and commit WITHOUT adding a migration entry.
#         AC5 should fire because the head version had migrations: [] and
#         the staged version still has migrations: [].
#
# Code path traced:
#   check_shipped_contract_migrations (precommit_gate.py:688) →
#   _is_contract_path True (line 592) →
#   _git_show_head returns prior shipped+protected content (line 697) →
#   _is_shipped_protected_yaml True (line 644-654; line-grep for both
#       "lifecycle: shipped" and "protection: contract") →
#   _count_migration_entries: head=0, staged=0 →
#   staged_count <= head_count → from_reason(SHIPPED_CONTRACT_NO_MIGRATION,
#       line 717).
#
# Profile matrix: all profiles → block (AC5 is profile-agnostic).

set -euo pipefail
B_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/battery.sh
source "$B_DIR/lib/battery.sh"

profile="${1:-discovery}"

(
    set -e
    scaffold_project "$profile"
    # formal+ needs plan-approved to even reach AC5 on code commits — but
    # contract YAML edits aren't "code changes" per _has_code_changes, so the
    # plan-approved check is skipped. Seed anyway for paranoia.
    bypass_seed_plan_approved

    # Seed a shipped+protected contract committed at HEAD with chmod 444.
    bypass_seed_shipped_contract F-9002 >/dev/null

    # Attack: deliberately bypass R-005 (chmod u+w), edit the YAML, leave
    # migrations: [] (no new entry). Then re-lock and stage.
    chmod u+w "$CONTRACTS_DIR/F-9002.yaml"
    sed -i 's/structural fixture assertion/MUTATED structural fixture assertion/' \
        "$CONTRACTS_DIR/F-9002.yaml"
    chmod 444 "$CONTRACTS_DIR/F-9002.yaml"

    git add "$CONTRACTS_DIR/F-9002.yaml"

    set +e
    out=$(git commit -m "B06 attack: shipped contract edit without migration" 2>&1)
    rc=$?
    set -e

    code_path="precommit_gate.check_shipped_contract_migrations:717"

    if [[ $rc -eq 0 ]]; then
        echo "FAIL|commit succeeded — AC5 did not block|$code_path"
    elif bypass_assert_gate_blocked_by_ac "AC5" "precommit"; then
        # Review fix #1: structured event assertion.
        echo "PASS|commit blocked by AC5 (gate_blocked event with AC5; shipped contract without migration)|$code_path"
    else
        ev=$(echo "$out" | head -3 | tr '\n' ';' | sed 's/|/_/g')
        echo "FAIL|blocked but not by AC5; no AC5 in gate_blocked event; output: $ev|$code_path"
    fi
)
