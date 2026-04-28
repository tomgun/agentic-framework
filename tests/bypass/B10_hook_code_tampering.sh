#!/usr/bin/env bash
# B10_hook_code_tampering.sh — R-004 AC0 (integrity check catches Python hook tampering).
#
# Precondition: INTEGRITY_SKIP and CI unset (asserted by battery::assert_env_hygiene
#               at orchestrator start).
# Fixture: `ag integrity update` mints baseline.
# Attack: append `# tampered` to .agentic/lib/hooks/precommit_gate.py; commit.
# Expected: AC0 fires FIRST (before any later check) → block.
#
# Code path traced:
#   check_integrity (precommit_gate.py:323) runs first in _CHECKS list →
#   integrity.verify_all (integrity.py:340 region) → SHA-256 of
#       .agentic/lib/hooks/precommit_gate.py mismatches baseline →
#   result.mismatches non-empty →
#   GateResult.from_reason(messages.INTEGRITY_TAMPERED, ...) (line 362).
#
# Profile matrix: all profiles → block (R-004 is profile-agnostic per plan
# §"Phase 0 surface inventory").

set -euo pipefail
B_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/battery.sh
source "$B_DIR/lib/battery.sh"

profile="${1:-discovery}"

(
    set -e
    scaffold_project "$profile"
    bypass_seed_plan_approved

    # Mint baseline. AC0 short-circuits with "no baseline; pass" until we do.
    bash .agentic/lib/tools/ag.sh integrity update >/dev/null 2>&1 || true

    # Verify baseline file exists; without it B10 cannot test integrity.
    if [[ ! -f .agentic/integrity.json ]]; then
        echo "SKIP-by-design|ag integrity update did not produce a baseline (env-dependent)|R-004:integrity.py"
        exit 0
    fi

    # Tamper with the gate code. Appending to the file changes the SHA.
    echo "# B10 tamper marker $(date +%s)" >> .agentic/lib/hooks/precommit_gate.py

    # Need to stage SOMETHING for the commit to be non-empty. Stage a benign
    # state file change (touch JOURNAL.md so it's modified). Tampering itself
    # need not be staged — integrity verifies on-disk file content.
    echo "B10 marker $(date +%s)" >> .agentic/journal/JOURNAL.md
    git add .agentic/journal/JOURNAL.md

    set +e
    out=$(git commit -m "B10 attack: hook tampering" 2>&1)
    rc=$?
    set -e

    code_path="precommit_gate.check_integrity:362 (R-004)"

    if [[ $rc -eq 0 ]]; then
        echo "FAIL|hook tampering not detected — AC0 did not block|$code_path"
    elif bypass_assert_gate_blocked_by_ac "AC0" "precommit"; then
        # Review fix #1: structured event assertion.
        echo "PASS|AC0 caught hook tampering (gate_blocked event with AC0; integrity baseline mismatch)|$code_path"
    else
        ev=$(echo "$out" | head -3 | tr '\n' ';' | sed 's/|/_/g')
        echo "FAIL|blocked but not by AC0; no AC0 in gate_blocked event; output: $ev|$code_path"
    fi
)
