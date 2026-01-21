#!/usr/bin/env bash
# Description: Agent should use blocker.sh to manage HUMAN_NEEDED.md
# Section: scripts
# Category: Important
# Tests: LLM-TOKEN-BLOCKER

# Setup
setup_test_project "core"

# Ask to add a blocker
send_prompt "I need help with the database schema design - add this to HUMAN_NEEDED.md as a blocker"

# Verify agent behavior
FAILURES=0

# Agent should mention or use blocker.sh
check_output_contains "blocker.sh\|\.agentic/tools/blocker" "Agent mentions blocker.sh script" || ((FAILURES++))

# Agent should understand it's for tracking blockers
check_output_contains "HUMAN_NEEDED\|blocker\|add\|track" "Agent understands blocker tracking" || ((FAILURES++))

# Cleanup
cleanup_test_project

[[ $FAILURES -eq 0 ]]
