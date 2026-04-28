#!/usr/bin/env bash
# B03_audit_trail_skip_gate.sh — R-001 AC7 + R-002 AC6 (sanctioned skip path
# emits audit events).
#
# Attack: set AGENT_SKIP_GATE=1 + AGENT_SKIP_GATE_REASON; commit + push state-only
#         changes. Expected: gate exits 0, AND events.jsonl contains:
#           - precommit_gate.gate_skipped event (from R-001 AC7)
#           - prepush_gate.gate_skipped event (from R-002 AC6)
#           - prepush_gate.push_attempt event (from R-002 AC7)
#
# Code path traced:
#   precommit_gate.handle_skip_gate (line 917-928) emits gate_skipped with
#       payload.reason and exit 0.
#   prepush_gate.handle_skip_gate (line 725-736) emits gate_skipped +
#       push_attempt with payload.reason and exit 0.
#
# Profile matrix: all profiles → audit events present. The SUT here is the
# audit trail itself, not a block.
#
# Why this matters: a tampered events.py could silently disable the audit
# trail. B10 catches tampering with .agentic/lib/hooks/precommit_gate.py;
# B03 catches tampering with .agentic/lib/events.py (which would prevent
# events from being written even when the gate logic is intact).

set -euo pipefail
B_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/battery.sh
source "$B_DIR/lib/battery.sh"

profile="${1:-discovery}"

(
    set -e
    scaffold_project "$profile"

    # State-only commit — JOURNAL.md edit only. No code, so AC1/AC4/AC3 skip
    # by design even without skip-gate. We're here to verify the audit
    # events fire when --skip-gate is used.
    echo "B03 probe $(date +%s)" >> .agentic/journal/JOURNAL.md
    git add .agentic/journal/JOURNAL.md

    set +e
    out=$(AGENT_SKIP_GATE=1 AGENT_SKIP_GATE_REASON="B03 verification probe" \
        git commit -m "B03 skip-gate commit" 2>&1)
    rc=$?
    set -e

    code_path="precommit_gate.handle_skip_gate:917 + prepush_gate:725"

    if [[ $rc -ne 0 ]]; then
        echo "FAIL|commit failed under AGENT_SKIP_GATE=1 (exit=$rc); skip path broken|$code_path"
        exit 0
    fi

    # Push (also under skip-gate) to trigger prepush events.
    set +e
    AGENT_SKIP_GATE=1 AGENT_SKIP_GATE_REASON="B03 verification probe" \
        git push origin HEAD --quiet 2>&1 >/dev/null
    push_rc=$?
    set -e

    # Now verify all three events present.
    has_pre_skipped=0; has_push_skipped=0; has_push_attempt=0
    bypass_assert_event_present "gate_skipped" "precommit_gate" && has_pre_skipped=1
    bypass_assert_event_present "gate_skipped" "prepush_gate" && has_push_skipped=1
    bypass_assert_event_present "push_attempt" "prepush_gate" && has_push_attempt=1

    if [[ $has_pre_skipped -eq 1 && $has_push_skipped -eq 1 && $has_push_attempt -eq 1 ]]; then
        echo "PASS|all 3 audit events present (gate_skipped pre + push, push_attempt)|$code_path"
    else
        missing=""
        [[ $has_pre_skipped -eq 0 ]] && missing="$missing pre.gate_skipped"
        [[ $has_push_skipped -eq 0 ]] && missing="$missing push.gate_skipped"
        [[ $has_push_attempt -eq 0 ]] && missing="$missing push_attempt"
        echo "FAIL|missing audit events:$missing (push_rc=$push_rc)|$code_path"
    fi
)
