#!/usr/bin/env bash
# Description: Agent should use status.sh instead of rewriting STATUS.md
# Section: scripts
# Category: Important
# Tests: LLM-TOKEN-STATUS

# Setup
setup_test_project "core"

# Ask to update status (natural language, not mentioning file directly)
send_prompt "Update the current focus to 'Implementing user authentication'"

# Verify agent behavior
FAILURES=0

# Agent should mention or use status.sh (or the script path)
check_output_contains "status\.sh\|tools/status\|status script\|bash.*status" "Agent mentions status.sh script" || ((FAILURES++))

# Agent should NOT just edit the whole file
check_output_not_contains "I.ll edit STATUS.md\|rewrite.*STATUS\|replace.*STATUS" "Agent doesn't rewrite whole file" || ((FAILURES++))

# Cleanup
cleanup_test_project

[[ $FAILURES -eq 0 ]]
