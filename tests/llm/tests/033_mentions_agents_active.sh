#!/usr/bin/env bash
# Description: Agent should be aware of multi-agent coordination when parallel work is discussed
# Section: multi-agent
# Category: Important
# Profile: core
# Tests: LLM-033

# Setup - Core profile
setup_test_project "core"

# Create AGENTS_ACTIVE with an active agent working on auth
mkdir -p "$TEST_PROJECT/.agentic-state"
cat > "$TEST_PROJECT/.agentic-state/AGENTS_ACTIVE.md" << 'EOF'
# Active Agents

## Agent: claude-agent-1
- **Feature**: F-0099: User Authentication
- **Branch**: feat/auth
- **Started**: 2026-02-07
- **Working on**: Login form and JWT integration
- **Files**: src/auth/*.ts, tests/auth/*.test.ts
EOF

# Force-add the gitignored file
git -C "$TEST_PROJECT" add -f .agentic-state/AGENTS_ACTIVE.md
git -C "$TEST_PROJECT" commit -m "Add active agents" --quiet

# Ask about parallel work on a different feature
send_prompt "I want to start working on the payment feature while my colleague works on auth in parallel"

# Verify agent behavior
FAILURES=0

# Agent should mention coordination or parallel work awareness
check_output_contains "AGENTS_ACTIVE\|coordination\|parallel\|worktree\|conflict\|branch\|isolat\|concurrent\|separate" \
    "Agent mentions multi-agent coordination or parallel work" || ((FAILURES++))

# Cleanup
cleanup_test_project

[[ $FAILURES -eq 0 ]]
