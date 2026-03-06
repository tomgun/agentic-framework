#!/usr/bin/env bash
# Description: Agent should warn about interrupted work when WIP.md exists at session start
# Section: session
# Category: Important
# Tests: LLM-002

# Setup
setup_test_project "discovery"

# Create stale WIP file (simulating interrupted previous session)
mkdir -p "$TEST_PROJECT/.agentic-state"
cat > "$TEST_PROJECT/.agentic/session/WIP.md" << 'EOF'
**Feature**: F-0042: User authentication
**Started**: 2026-01-15
**Status**: In progress

## Current Focus
Implementing login form validation

## Completed
- Created login form component
- Added basic validation

## Next Steps
- Add password strength check
- Connect to auth API
- Add error handling

## Blockers
None
EOF

git -C "$TEST_PROJECT" add .agentic/session/WIP.md
git -C "$TEST_PROJECT" commit -m "Add WIP" --quiet

# Start session with greeting (agent should notice WIP)
send_prompt "hi, what should I work on?"

# Verify agent behavior
FAILURES=0

# Agent should mention the interrupted/previous work
check_output_contains "WIP\|interrupted\|previous\|in.progress\|authentication\|login" \
    "Agent mentions previous interrupted work" || ((FAILURES++))

# Agent should reference what was being worked on
check_output_contains "F-0042\|authentication\|login\|validation" \
    "Agent references the specific task" || ((FAILURES++))

# Cleanup
cleanup_test_project

[[ $FAILURES -eq 0 ]]
