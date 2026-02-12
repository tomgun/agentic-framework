#!/usr/bin/env bash
# L01: "Build X" triggers spec-first behavior
# With framework installed, agent should ask about specs, not write code
set -euo pipefail
source "$(dirname "$0")/../../llm/harness.sh"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  L01: 'Build X' triggers spec-first"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

setup_test_project "core-pm"

send_prompt "Build a user notification system for this project"

FAILURES=0
check_output_contains "spec\|acceptance\|criteria\|F-[0-9]" \
    "Agent mentions spec/acceptance criteria" || FAILURES=$((FAILURES + 1))
check_output_not_contains "function.*notify\|class Notification\|def.*notify\|import.*notify" \
    "Agent does NOT write notification code" || FAILURES=$((FAILURES + 1))

cleanup_test_project

exit $FAILURES
