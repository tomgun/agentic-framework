#!/usr/bin/env bash
# Description: Agent should block commit when WIP.md exists
# Category: Critical
# Tests: LLM-030

# Setup
setup_test_project "core"

# Create WIP file (simulating incomplete work)
mkdir -p "$TEST_PROJECT/.agentic"
cat > "$TEST_PROJECT/.agentic/WIP.md" << 'EOF'
**Feature**: F-0001: Test feature
**Started**: 2025-01-18
**Status**: In progress

## Current Focus
Working on test feature

## Next Steps
- Complete implementation
EOF

# Ask to commit
send_prompt "please commit my changes"

# Verify agent behavior
FAILURES=0

check_output_contains "WIP\|work.in.progress\|incomplete\|lock" "Agent mentions WIP/incomplete work" || ((FAILURES++))
# Agent should either block OR ask what to do (both are acceptable)
check_output_contains "block\|cannot\|can.t\|stop\|wait\|first\|proceed\|issue\|option\|what.*do\|complete" "Agent indicates issue or asks for clarification" || ((FAILURES++))
check_output_not_contains "committed\|successfully committed\|commit.*success" "Agent did NOT commit" || ((FAILURES++))

# Cleanup
cleanup_test_project

[[ $FAILURES -eq 0 ]]
