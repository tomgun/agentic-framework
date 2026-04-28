#!/usr/bin/env bash
# B12_prepush_range.sh — R-002 AC5 (pre-push range walk catches no-verify-
# bypassed shipped-contract migrations).
#
# Attack: 3 commits via `git commit --no-verify` (silently bypasses pre-commit),
#         the third including a shipped+protected contract edit without a new
#         migrations entry. Then `git push`.
# Expected: pre-push gate walks <remote_oid>..<local_oid>, runs migration-
#           presence check on every commit in range, the third trips it → block.
#
# Code path traced:
#   prepush_gate reads <local_ref local_oid remote_ref remote_oid> from stdin
#       (line 260-272) →
#   For each push range, walks `git rev-list <remote>..<local>` →
#   For each commit, applies migration-presence check →
#   Third commit's diff has F-9005 with shipped+protected and no new
#       migrations entry → block (line 480+ AC5 in prepush_gate.py).
#
# Profile matrix: all profiles → push blocked. AC5 (range form) is profile-agnostic.
#
# Notes:
# - This test deliberately exercises the --no-verify honest limit acknowledged
#   in precommit_gate.py docstring. Pre-commit doesn't see those commits;
#   pre-push catches the cumulative range.
# - Replaces the v1 B02/B03 (which were duplicates of this); v6 B02/B03 cover
#   different surfaces (R-002 AC3 coverage and R-001 AC7 audit trail).

set -euo pipefail
B_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/battery.sh
source "$B_DIR/lib/battery.sh"

profile="${1:-discovery}"

(
    set -e
    scaffold_project "$profile"
    bypass_seed_plan_approved
    bypass_seed_shipped_contract F-9005 >/dev/null

    # Commit 1: state-only via --no-verify
    echo "B12 commit 1 marker" >> .agentic/journal/JOURNAL.md
    git add .agentic/journal/JOURNAL.md
    git commit --no-verify -m "B12 c1: state-only" --quiet

    # Commit 2: state-only via --no-verify
    echo "B12 commit 2 marker" >> .agentic/journal/JOURNAL.md
    git add .agentic/journal/JOURNAL.md
    git commit --no-verify -m "B12 c2: state-only" --quiet

    # Commit 3: the actual attack — shipped contract edit, no migration entry.
    chmod u+w "$CONTRACTS_DIR/F-9005.yaml"
    sed -i 's/structural fixture assertion/MUTATED via range-bypass/' \
        "$CONTRACTS_DIR/F-9005.yaml"
    chmod 444 "$CONTRACTS_DIR/F-9005.yaml"
    git add "$CONTRACTS_DIR/F-9005.yaml"
    git commit --no-verify -m "B12 c3: shipped-contract edit no migration" --quiet

    # Now push. Pre-push fires; range walk should catch commit 3.
    set +e
    out=$(git push origin HEAD --quiet 2>&1)
    rc=$?
    set -e

    code_path="prepush_gate.range_migration_check (R-002 AC5)"

    if [[ $rc -eq 0 ]]; then
        echo "FAIL|push succeeded — range AC5 did not catch commit 3|$code_path"
    elif echo "$out" | grep -qiE "AC5|migration|shipped.*contract|range"; then
        echo "PASS|push blocked by pre-push range AC5 (commit 3 caught)|$code_path"
    else
        ev=$(echo "$out" | head -3 | tr '\n' ';' | sed 's/|/_/g')
        echo "FAIL|blocked but not by range AC5; output: $ev|$code_path"
    fi
)
