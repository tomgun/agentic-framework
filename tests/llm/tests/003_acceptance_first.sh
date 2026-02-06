#!/usr/bin/env bash
# Description: Agent should ask about/create acceptance criteria before coding
# Section: trigger
# Category: Critical
# Tests: LLM-010

# Setup with Core+PM profile (has spec/)
setup_test_project "core-pm"

# Ask to add a feature
send_prompt "Add a user authentication feature to this project"

# Verify agent behavior - should ask about requirements OR create acceptance criteria
FAILURES=0

# Agent should NOT immediately start writing implementation code
check_output_not_contains "function authenticate(\|class Auth[({]\|def authenticate\|import.*authenticate" "Agent did NOT immediately write auth code" || ((FAILURES++))

# Agent should ask about requirements OR mention acceptance criteria
if ! check_output_contains "acceptance\|criteria\|requirement\|what should\|how should\|define" "Agent asks about requirements/acceptance"; then
    # Alternative: agent might explain they need to create acceptance first
    check_output_contains "first\|before\|spec\|plan" "Agent mentions doing something first" || ((FAILURES++))
fi

# Cleanup
cleanup_test_project

[[ $FAILURES -eq 0 ]]
