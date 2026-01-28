#!/usr/bin/env bash
# Description: Agent should use best models for everything in full_steam mode
# Section: context
# Category: Important
# Tests: F-0103

# Setup with Core+PM profile and full_steam mode
setup_test_project "core-pm"

# Set full_steam mode in STACK.md
sed -i '' 's/agent_mode: balanced/agent_mode: full_steam/' STACK.md 2>/dev/null || \
    sed -i 's/agent_mode: balanced/agent_mode: full_steam/' STACK.md

# Ask agent about model selection for search task
send_prompt "I need you to search the codebase for authentication code. In full_steam mode, what model would you use for this search?"

# Verify agent mentions using best model
FAILURES=0

# Agent should mention full_steam mode
check_output_contains "full_steam\|full steam\|maximum\|best" "Agent references full_steam mode" || ((FAILURES++))

# In full_steam mode, even search should use opus
if check_output_contains "opus" "Agent mentions opus for full_steam search"; then
    # Good - agent knows full_steam uses opus for everything
    :
else
    # Alternative: agent might mention "best" model
    check_output_contains "best\|top\|highest\|maximum quality" "Agent references best model choice" || ((FAILURES++))
fi

# Cleanup
cleanup_test_project

[[ $FAILURES -eq 0 ]]
