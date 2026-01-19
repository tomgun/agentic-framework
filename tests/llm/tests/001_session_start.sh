#!/usr/bin/env bash
# Description: Agent should greet with context on session start
# Category: Critical
# Tests: LLM-001

# Setup
setup_test_project "core"

# Send simple greeting
send_prompt "hi"

# Verify agent behavior
FAILURES=0

check_output_contains "session\|project\|welcome\|status\|context\|here" "Agent mentions session/project context" || ((FAILURES++))
check_output_contains "CONTEXT_PACK\|context\|project" "Agent references project context" || ((FAILURES++))
check_file_not_exists ".agentic/WIP.md" "No WIP created for simple greeting" || ((FAILURES++))

# Cleanup
cleanup_test_project

[[ $FAILURES -eq 0 ]]
