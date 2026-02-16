#!/usr/bin/env bash
# Description: Agent should use status.sh instead of rewriting STATUS.md
# Section: scripts
# Category: Important
# Tests: LLM-TOKEN-STATUS

# Setup
setup_test_project "discovery"

# Ask to update status (natural language, not mentioning file directly)
send_prompt "Update the current focus to 'Implementing user authentication'"

# Verify agent behavior
FAILURES=0

# Ideal: Agent uses status.sh (optimization goal, not critical)
if check_output_contains "status\.sh\|tools/status\|status script\|bash.*status" "Agent mentions status.sh script"; then
    : # Best outcome
else
    echo -e "${YELLOW}⚠ Agent doesn't use status.sh - optimization opportunity${NC}"
    # Not a failure - real validation is actual project usage
fi

# Critical: Agent should NOT read/rewrite the whole file
check_output_not_contains "read.*entire\|rewrite.*STATUS\|cat STATUS" "Agent doesn't rewrite whole file" || ((FAILURES++))

# Cleanup
cleanup_test_project

[[ $FAILURES -eq 0 ]]
