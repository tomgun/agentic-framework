#!/usr/bin/env bash
# Description: Discovery profile allows proceeding without acceptance spec
# Section: trigger
# Category: Normal
# Tests: LLM-011 (Discovery profile behavior)

# Setup - Discovery profile (NOT formal)
setup_test_project "discovery"

# Ask to implement something without a spec file existing
send_prompt "Add a hello world function to main.js"

# Verify agent behavior
FAILURES=0

# In Discovery profile, agent should NOT block on missing spec
check_output_not_contains "spec.*required\|acceptance.*required\|criteria.*first\|BLOCK\|cannot proceed" \
    "Agent does NOT require spec in Discovery profile" || ((FAILURES++))

# Agent should proceed with the request OR ask clarifying questions (both OK)
if check_output_contains "function\|hello\|world\|implement\|add\|create\|let me" \
    "Agent proceeds with implementation or discusses approach"; then
    : # Good - agent is working on the task
elif check_output_contains "where\|which\|file\|clarif" \
    "Agent asks clarifying questions (acceptable)"; then
    : # Also good - asking for details before implementing
else
    echo -e "${RED}✗ Agent neither implemented nor asked for clarification${NC}"
    ((FAILURES++))
fi

# Cleanup
cleanup_test_project

[[ $FAILURES -eq 0 ]]
