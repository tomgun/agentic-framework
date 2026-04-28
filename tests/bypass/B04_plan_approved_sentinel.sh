#!/usr/bin/env bash
# B04_plan_approved_sentinel.sh — R-001 AC3 (plan-approved sentinel required
# when plan_review_enabled: yes).
#
# Attack: in formal+ profile (plan_review_enabled=yes), seed the sentinel,
#         then `rm` it, stage a code change, commit. Expected: AC3 blocks.
#
# Code path traced:
#   check_plan_approved (precommit_gate.py:505) →
#       fix_mode False → not skipped →
#       plan_review_enabled True (formal+) → not skipped →
#       has_code_changes True → not skipped →
#       sentinel.exists() False (we rm'd it) →
#       GateResult.from_reason(messages.PLAN_NOT_APPROVED) at line 519.
#
# Profile matrix:
#   discovery        → SKIP-by-design (plan_review_enabled=no per profiles.conf:14)
#   formal           → block (AC3)
#   autonomous_formal → block (AC3)

set -euo pipefail
B_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/battery.sh
source "$B_DIR/lib/battery.sh"

profile="${1:-discovery}"

(
    set -e
    scaffold_project "$profile"

    code_path="precommit_gate.check_plan_approved:519"

    if [[ "$profile" == "discovery" ]]; then
        # AC3 is profile-skipped. SKIP-by-design.
        echo "SKIP-by-design|AC3 disabled in discovery (plan_review_enabled=no)|$code_path"
        exit 0
    fi

    # formal/autonomous_formal: seed sentinel then remove, attempt commit.
    bypass_seed_plan_approved
    rm -f .agentic/session/.plan-approved

    # Stage a code change so has_code_changes is True (AC3 only enforces on
    # code commits, not state-only commits).
    mkdir -p src
    echo "// B04 attack" > src/foo.py
    git add src/foo.py

    set +e
    out=$(git commit -m "B04 attack: sentinel removed" 2>&1)
    rc=$?
    set -e

    if [[ $rc -eq 0 ]]; then
        echo "FAIL|commit succeeded — AC3 did not block under $profile|$code_path"
    elif echo "$out" | grep -qiE "AC3|plan.approved|plan-approved|plan not approved"; then
        echo "PASS|AC3 blocked commit (plan-approved sentinel missing)|$code_path"
    else
        ev=$(echo "$out" | head -3 | tr '\n' ';' | sed 's/|/_/g')
        echo "FAIL|blocked but not by AC3; output: $ev|$code_path"
    fi
)
