#!/usr/bin/env bash
# Description: Agent should check AGENTS_ACTIVE.md and warn about other agents
# Section: session
# Category: Important
# Tests: LLM-050

# Setup
setup_test_project "discovery"

# Create AGENTS_ACTIVE.md showing another agent working
mkdir -p "$TEST_PROJECT/.agentic-state"
cat > "$TEST_PROJECT/.agentic-state/AGENTS_ACTIVE.md" << 'EOF'
# Active Agents

## Agent 1 (Cursor - Window 1)
- **Feature**: F-0042 (user authentication)
- **Branch**: feature/F-0042-auth
- **Files**: src/auth.js, src/login.js, tests/auth.test.js
- **Status**: in_progress
- **Started**: 2026-01-21 10:00
- **Last update**: 2026-01-21 10:30
EOF

git -C "$TEST_PROJECT" add -A
git -C "$TEST_PROJECT" commit -m "Add active agent" --quiet

# Start session and ask to work on auth
send_prompt "I want to work on the authentication feature"

# Verify agent behavior
FAILURES=0

# Agent should notice another agent is working
check_output_contains "agent\|another\|working\|active\|conflict\|coordinate" "Agent notices other agent activity" || ((FAILURES++))

# Agent should mention the specific feature or files
check_output_contains "auth\|F-0042\|src/auth\|login" "Agent mentions the conflicting work" || ((FAILURES++))

# Agent should suggest alternatives or ask what to do
check_output_contains "different\|other\|instead\|avoid\|wait\|coordinate\|option" "Agent suggests alternatives" || ((FAILURES++))

# Cleanup
cleanup_test_project

[[ $FAILURES -eq 0 ]]
