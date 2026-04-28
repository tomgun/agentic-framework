#!/usr/bin/env bash
# B08_chmod_recovery_ac5_second_wall.sh — R-005 deliberately bypassed → R-001
# AC5 fires as the second wall.
#
# Attack: same shape as B06, but FRAMED as "R-005 first wall is the documented
# escape path (chmod u+w → edit → chmod 444); does AC5 catch it at commit time?"
# B06 and B08 exercise the same SUT (check_shipped_contract_migrations) but
# this test exists to prove the two-wall composition holds — R-005 + AC5 are
# layered defenses, not redundant.
#
# Fixture: bypass_seed_shipped_contract F-9004 (separate ID from B06's F-9002
# so the cells are independent under the orchestrator's serial-but-fresh-scaffold
# model — within ONE B-test the scaffold is brand new, so collision-free either
# way; the distinct ID is for forensic clarity in events.jsonl).
#
# Code path: identical to B06 — check_shipped_contract_migrations (line 688).
# The "second wall" narrative is in this B-test's existence, not in code path.

set -euo pipefail
B_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/battery.sh
source "$B_DIR/lib/battery.sh"

profile="${1:-discovery}"

(
    set -e
    scaffold_project "$profile"
    bypass_seed_plan_approved
    bypass_seed_shipped_contract F-9004 >/dev/null

    # R-005 first wall deliberately bypassed.
    chmod u+w "$CONTRACTS_DIR/F-9004.yaml"
    sed -i 's/structural fixture assertion/MUTATED via chmod recovery/' \
        "$CONTRACTS_DIR/F-9004.yaml"
    chmod 444 "$CONTRACTS_DIR/F-9004.yaml"

    git add "$CONTRACTS_DIR/F-9004.yaml"

    set +e
    out=$(git commit -m "B08 attack: chmod recovery; AC5 must be second wall" 2>&1)
    rc=$?
    set -e

    code_path="precommit_gate.check_shipped_contract_migrations:717 (second wall after R-005 bypass)"

    if [[ $rc -eq 0 ]]; then
        echo "FAIL|R-005 bypassed AND AC5 missed — both walls breached|$code_path"
    elif bypass_assert_gate_blocked_by_ac "AC5" "precommit"; then
        # Review fix #1: structured event assertion.
        echo "PASS|AC5 caught the chmod-recovery attack (gate_blocked event with AC5; second wall holds)|$code_path"
    else
        ev=$(echo "$out" | head -3 | tr '\n' ';' | sed 's/|/_/g')
        echo "FAIL|blocked but not by AC5; no AC5 in gate_blocked event; output: $ev|$code_path"
    fi
)
