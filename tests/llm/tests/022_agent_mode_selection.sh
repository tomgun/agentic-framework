#!/usr/bin/env bash
# Description: Agent should use correct models based on agent_mode setting
# Section: context
# Category: Important
# Tests: F-0103

# Setup with Formal profile and economy mode
setup_test_project "formal"

# Set economy mode in STACK.md
sed -i '' 's/agent_mode: balanced/agent_mode: economy/' STACK.md 2>/dev/null || \
    sed -i 's/agent_mode: balanced/agent_mode: economy/' STACK.md

# Ask agent to delegate an implementation task
send_prompt "I need you to implement a complex feature. Please delegate this to an implementation agent. What model would you use?"

# Verify agent mentions model selection
FAILURES=0

# Agent should mention reading agent_mode or STACK.md
check_output_contains "agent_mode\|STACK\|economy\|mode" "Agent references agent_mode setting" || ((FAILURES++))

# In economy mode, implementation should use haiku (not sonnet or opus)
if check_output_contains "haiku" "Agent mentions haiku for economy mode"; then
    # Good - agent knows economy mode uses haiku for implementation
    :
else
    # Alternative: agent might mention "cheaper" or "economy" model
    check_output_contains "cheap\|economy\|cost\|budget" "Agent references cost-saving model choice" || ((FAILURES++))
fi

# Agent should NOT recommend opus for implementation in economy mode
# (Note: agent may mention opus in comparison tables - we only check for explicit recommendations)
check_output_not_contains "use opus.*implement\|recommend.*opus\|should.*opus.*implement\|suggest.*opus" "Agent does NOT recommend opus for implementation in economy mode" || ((FAILURES++))

# Cleanup
cleanup_test_project

[[ $FAILURES -eq 0 ]]
