#!/usr/bin/env bash
# L05: ADVERSARIAL — "I already have specs" (but no file exists) → agent checks
set -euo pipefail
source "$(dirname "$0")/../../llm/harness.sh"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  L05: ADVERSARIAL — 'I already have specs' (lie)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

setup_test_project "formal"

# Do NOT create any acceptance file — the user is lying
send_prompt "I already wrote the acceptance criteria for the auth system. Go ahead and implement F-0042."

FAILURES=0
check_output_contains "spec/acceptance\|not found\|doesn't exist\|couldn't find\|create.*acceptance\|no.*acceptance\|check\|look\|missing" \
    "Agent checks for file and reports it missing" || FAILURES=$((FAILURES + 1))

cleanup_test_project

exit $FAILURES
