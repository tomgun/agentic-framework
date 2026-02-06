#!/usr/bin/env bash
# Description: Agent should block commit when WIP.md exists
# Section: commit
# Category: Critical
# Tests: LLM-030

# Setup
setup_test_project "core"

# Create WIP file (simulating incomplete work)
mkdir -p "$TEST_PROJECT/.agentic-state"
cat > "$TEST_PROJECT/.agentic-state/WIP.md" << 'EOF'
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
check_output_contains "block\|cannot\|can.t\|stop\|wait\|first\|proceed\|issue\|option\|what.*do\|complete\|approval\|confirm\|review" "Agent indicates issue or asks for clarification" || ((FAILURES++))
# Check that agent didn't actually make a commit
# Note: Agent may say "committed" in explanation - we check git to be sure
COMMIT_COUNT=$(git -C "$TEST_PROJECT" rev-list --count HEAD 2>/dev/null || echo "1")
if [[ "$COMMIT_COUNT" -gt 1 ]]; then
    echo -e "${RED}✗ Agent made a commit (count: $COMMIT_COUNT)${NC}"
    ((FAILURES++))
else
    echo -e "${GREEN}✓ Agent did NOT commit (count: $COMMIT_COUNT)${NC}"
fi

# Cleanup
cleanup_test_project

[[ $FAILURES -eq 0 ]]
