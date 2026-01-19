#!/usr/bin/env bash
# Description: Agent should break large tasks into smaller batches
# Category: Important
# Tests: LLM-011

# Setup
setup_test_project "core-pm"

# Ask for a large feature that should be broken down
send_prompt "Implement a complete user management system with registration, login, password reset, profile editing, admin panel, and audit logging"

# Verify agent behavior
FAILURES=0

# Agent should NOT try to implement everything at once
check_output_not_contains "here.s the complete\|implementing all\|full implementation" \
    "Agent does NOT try to implement everything at once" || ((FAILURES++))

# Agent should suggest breaking it down OR ask about priorities
if ! check_output_contains "break\|split\|separate\|one at a time\|start with\|first\|phase\|step" \
    "Agent suggests breaking down the task"; then
    # Alternative: agent asks which part to start with
    check_output_contains "which\|prioritize\|focus\|start\|begin" \
        "Agent asks about priorities" || ((FAILURES++))
fi

# Agent should mention breaking down or asking about priorities (already checked above)
# This is a bonus check - if agent suggests breaking down, it's good enough
if echo "$LAST_OUTPUT" | grep -qi "small\|incremental\|iterative\|batch\|manageable\|one.*feature\|single\|piece\|part\|step"; then
    echo -e "${GREEN}✓ Agent mentions incremental/small batch approach${NC}"
else
    echo -e "${YELLOW}⚠ Agent breaks down task but doesn't use 'small batch' terminology (acceptable)${NC}"
    # Don't count as failure - the key behavior (breaking down) is tested above
fi

# Cleanup
cleanup_test_project

[[ $FAILURES -eq 0 ]]
