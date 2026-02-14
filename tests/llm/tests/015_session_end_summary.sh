#!/usr/bin/env bash
# Description: Agent should provide structured handoff summary at session end
# Section: session
# Category: Important
# Tests: LLM-003

# Setup
setup_test_project "core"

# Simulate some work was done
cat > "$TEST_PROJECT/STATUS.md" << 'EOF'
# Project Status

## Current Focus
Implementing user login feature

## Progress
- Created login form component
- Added basic validation

## Next Steps
- Connect to API
- Add error handling
EOF

git -C "$TEST_PROJECT" add -A
git -C "$TEST_PROJECT" commit -m "Update status" --quiet

# End session
send_prompt "I need to stop working now, please end the session"

# Verify agent behavior
FAILURES=0

# Agent should provide summary of what was done
check_output_contains "done\|completed\|progress\|worked\|implemented\|summary" "Agent summarizes work done" || ((FAILURES++))

# Agent should mention next steps or handoff
check_output_contains "next\|continue\|todo\|remaining\|handoff\|pick.*up" "Agent mentions next steps" || ((FAILURES++))

# Agent should mention updating docs/journal
check_output_contains "journal\|status\|update\|log\|record" "Agent mentions documentation update" || ((FAILURES++))

# Cleanup
cleanup_test_project

[[ $FAILURES -eq 0 ]]
