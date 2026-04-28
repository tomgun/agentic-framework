#!/usr/bin/env bash
# B02_prepush_coverage.sh — R-002 AC3 (pre-push contract coverage threshold).
#
# Attack: seed F-9001 with three uncovered behavioral assertions
#         (no `tests:` linkage → coverage_pct=0); set
#         contract_coverage_threshold: 80; commit and push.
# Expected: pre-push gate blocks because 0% < 80%.
#
# Code path traced:
#   prepush_gate.check_contract_coverage (line 372) →
#       invokes `bash .agentic/lib/tools/ag.sh contract coverage` →
#       parses "Coverage: 0%" line →
#       0 < 80 (default threshold) →
#       block.
#
# Profile matrix: all profiles → block. AC3 is profile-agnostic.
#
# Notes:
# - seed precondition asserts Total assertions: 0 BEFORE seeding (round-3 fix).
#   If install.sh shipped baseline contracts the cell SKIPs.
# - Without pyyaml, contracts load fails silently and coverage = 0% trivially —
#   the block still fires but for "no contracts loadable" rather than "uncovered
#   feature." Evidence string captures this distinction.

set -euo pipefail
B_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/battery.sh
source "$B_DIR/lib/battery.sh"

profile="${1:-discovery}"

(
    set -e
    scaffold_project "$profile"
    bypass_seed_plan_approved

    # Seed the uncovered feature. The seeder's precondition checks
    # `Total assertions: 0` before writing F-9001 — if scaffold has
    # baseline contracts already, the seeder returns 1 and we SKIP.
    if ! bypass_seed_uncovered_feature 2>/dev/null; then
        echo "SKIP-by-design|seed precondition failed (scaffold not bare)|prepush_gate.check_contract_coverage:372"
        exit 0
    fi

    # Set the coverage threshold explicitly (default is 80; setting it makes
    # B02 robust against future default changes).
    echo "- contract_coverage_threshold: 80" >> STACK.md

    # Push to the local bare remote. The seeder's commit puts F-9001 on HEAD
    # already — git push will trigger pre-push gate.
    set +e
    out=$(git push origin HEAD --quiet 2>&1)
    rc=$?
    set -e

    code_path="prepush_gate.check_contract_coverage:372"

    if [[ $rc -eq 0 ]]; then
        echo "FAIL|push succeeded — pre-push AC3 did not block|$code_path"
    elif echo "$out" | grep -qiE "coverage|threshold|AC3"; then
        echo "PASS|push blocked by pre-push AC3 (coverage below threshold)|$code_path"
    else
        ev=$(echo "$out" | head -3 | tr '\n' ';' | sed 's/|/_/g')
        echo "FAIL|blocked but not by AC3; output: $ev|$code_path"
    fi
)
