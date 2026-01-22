#!/usr/bin/env bash
# Description: Agent should use blocker.sh to manage HUMAN_NEEDED.md
# Section: scripts
# Category: Important
# Tests: LLM-TOKEN-BLOCKER

# Setup
setup_test_project "core"

# Ask to add a blocker (natural language)
send_prompt "I'm blocked on database schema design and need human input - please track this blocker"

# Verify agent behavior
FAILURES=0

# Agent should mention or use blocker.sh
check_output_contains "blocker\.sh\|tools/blocker\|blocker script\|bash.*blocker" "Agent mentions blocker.sh script" || ((FAILURES++))

# Agent should understand it's for tracking blockers
check_output_contains "HUMAN_NEEDED\|blocker\|add\|track" "Agent understands blocker tracking" || ((FAILURES++))

# Cleanup
cleanup_test_project

[[ $FAILURES -eq 0 ]]
