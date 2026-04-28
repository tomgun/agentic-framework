#!/usr/bin/env bash
# B05_journal_staleness.sh — R-001 AC4 (journal freshness, formal+ only).
#
# Attack: roll JOURNAL.md mtime back to UTC epoch 86400 (1970-01-02), then
#         stage a code change and commit. AC4 should block in formal+ because
#         journal mtime + 5 < HEAD commit time. AC4 is profile-skipped in
#         discovery (`is_formal_like` is False).
#
# Code path traced:
#   _build_context (precommit_gate.py:275) → is_formal_like via settings →
#   check_journal_freshness (line 528) → has_code_changes True →
#   journal.stat().st_mtime == 86400 →
#   journal_mtime + 5 < head_ts (~1.7e9 in 2026) →
#   GateResult.from_reason(messages.JOURNAL_STALE, ...) (line 572).
#
# Profile matrix:
#   discovery        → SKIP-by-design (AC4 not enforced; commit may pass or
#                                       block on other ACs depending on env)
#   formal           → block (AC4)
#   autonomous_formal → block (AC4)

set -euo pipefail
B_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/battery.sh
source "$B_DIR/lib/battery.sh"

profile="${1:-discovery}"

(
    set -e
    scaffold_project "$profile"

    # formal+ also requires plan-approved sentinel (AC3) to even reach AC4
    # for code commits — seed it so we measure AC4 specifically, not AC3.
    bypass_seed_plan_approved

    # Roll JOURNAL.md mtime back. UTC-anchored via os.utime is portable.
    bypass_seed_journal_with_past_mtime

    # Stage a code change.
    mkdir -p src
    echo "# B05 attack" > src/foo.py
    git add src/foo.py

    set +e
    out=$(git commit -m "B05 attack: stale journal under formal" 2>&1)
    rc=$?
    set -e

    code_path="precommit_gate.check_journal_freshness:572"

    case "$profile" in
        discovery)
            # AC4 is profile-skipped. The cell is SKIP-by-design — we don't
            # care about the commit outcome for THIS B-test (AC4 not the SUT).
            echo "SKIP-by-design|AC4 disabled in discovery (is_formal_like=False)|$code_path"
            ;;
        formal|autonomous_formal)
            if [[ $rc -eq 0 ]]; then
                echo "FAIL|commit succeeded — AC4 did not fire under formal+|$code_path"
            elif bypass_assert_gate_blocked_by_ac "AC4" "precommit"; then
                # Review fix #1: structured event assertion (gate_blocked.payload.failures has AC4).
                echo "PASS|commit blocked by AC4 (gate_blocked event with AC4)|$code_path"
            else
                ev=$(echo "$out" | head -3 | tr '\n' ';' | sed 's/|/_/g')
                echo "FAIL|blocked but not by AC4; no AC4 in gate_blocked event; output: $ev|$code_path"
            fi
            ;;
    esac
)
