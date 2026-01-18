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

check_output_contains "WIP\|work.in.progress\|incomplete" "Agent mentions WIP/incomplete work" || ((FAILURES++))
check_output_contains "block\|cannot\|stop\|wait\|first" "Agent indicates blocking/waiting" || ((FAILURES++))
check_output_not_contains "committed\|successfully committed" "Agent did NOT commit" || ((FAILURES++))

# Cleanup
cleanup_test_project

[[ $FAILURES -eq 0 ]]
