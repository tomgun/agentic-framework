#!/usr/bin/env bash
# Description: Agent should greet with context on session start
# Section: session
# Category: Critical
# Tests: LLM-001

# Setup
setup_test_project "core"

# Send simple greeting
send_prompt "hi"

# Verify agent behavior
FAILURES=0

check_output_contains "session\|welcome\|status\|here\|working on\|focus" "Agent mentions session context" || ((FAILURES++))
check_output_contains "CONTEXT_PACK\|framework\|agentic\|checklists" "Agent references framework/project info" || ((FAILURES++))
check_file_not_exists ".agentic-state/WIP.md" "No WIP created for simple greeting" || ((FAILURES++))

# Cleanup
cleanup_test_project

[[ $FAILURES -eq 0 ]]
