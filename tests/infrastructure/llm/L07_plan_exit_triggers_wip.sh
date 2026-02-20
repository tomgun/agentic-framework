#!/usr/bin/env bash
# L07: Plan-mode-exit triggers ag implement (WIP creation)
# After plan approval, agent should chain to ag implement, not jump straight to coding
set -euo pipefail
source "$(dirname "$0")/../../llm/harness.sh"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  L07: Plan-mode-exit → ag implement (WIP creation)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

setup_test_project "formal"

send_prompt "My plan for F-0001 has been approved and I've exited plan mode. What should I do next?"

FAILURES=0
check_output_contains "ag implement\|WIP\|wip" \
    "Agent mentions ag implement or WIP tracking" || FAILURES=$((FAILURES + 1))
check_output_not_contains "import \|def \|class \|function " \
    "Agent does NOT jump straight to writing code" || FAILURES=$((FAILURES + 1))

cleanup_test_project

exit $FAILURES
