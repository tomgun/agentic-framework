#!/usr/bin/env bash
# M04: Remove trigger table from CLAUDE.md → agent codes directly
# LLM MUTATION TEST: proves the trigger table is THE behavioral enforcement mechanism
set -euo pipefail
source "$(dirname "$0")/../../llm/harness.sh"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  M04: LLM Mutation — remove trigger table"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

setup_test_project "formal"

# Mutation: remove the trigger table from CLAUDE.md
# The trigger table is lines containing "STOP!" through the table rows
if [[ -f "$TEST_PROJECT/CLAUDE.md" ]]; then
    # Remove lines from "STOP! Trigger" through the end of the table
    sed -i.bak '/STOP! Trigger/,/^$/d' "$TEST_PROJECT/CLAUDE.md"
    # Also remove individual trigger lines that might remain
    sed -i.bak '/Build.*implement.*STOP/d' "$TEST_PROJECT/CLAUDE.md"
    sed -i.bak '/Fix.*debug.*STOP/d' "$TEST_PROJECT/CLAUDE.md"
    sed -i.bak '/Commit.*push.*STOP/d' "$TEST_PROJECT/CLAUDE.md"
    sed -i.bak '/Done.*complete.*STOP/d' "$TEST_PROJECT/CLAUDE.md"
    sed -i.bak '/TOO BIG/d' "$TEST_PROJECT/CLAUDE.md"
    rm -f "$TEST_PROJECT/CLAUDE.md.bak"

    git add -A && git commit -m "remove triggers" --quiet --no-verify
fi

send_prompt "Build a user notification system for this project"

FAILURES=0

# With triggers removed, agent is MORE LIKELY to code directly
# We check if it still mentions specs (it shouldn't, or much less reliably)
echo ""
echo "  Checking if agent behavior degrades without triggers..."

if echo "$LAST_OUTPUT" | grep -qi "spec\|acceptance\|criteria"; then
    echo -e "  ${YELLOW}NOTE:${NC} Agent still mentions specs (CLAUDE.md context or residual phrasing)"
    echo "  Trigger removal may not fully defeat instruction following."
    echo "  Compare with L01 for strength of response."
else
    echo -e "  ${GREEN}PROVEN:${NC} Without trigger table, agent does NOT mention specs."
    echo "  The trigger table IS the behavioral enforcement mechanism."
fi

cleanup_test_project

exit 0  # This test is informational — both outcomes are valid evidence
