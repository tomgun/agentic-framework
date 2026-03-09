#!/usr/bin/env bash
# Description: Agent should be aware of multi-agent coordination when parallel work is discussed
# Section: multi-agent
# Category: Important
# Profile: core
# Tests: LLM-033

# Setup - Core profile
setup_test_project "discovery"

# Create AGENTS.json with an active agent working on auth
mkdir -p "$TEST_PROJECT/.agentic/session"
cat > "$TEST_PROJECT/.agentic/session/AGENTS.json" << 'EOF'
[
  {
    "feature_id": "F-0099",
    "description": "User Authentication",
    "worktree": "",
    "branch": "feat/auth",
    "agent": "claude-agent-1",
    "started": "2026-02-07T00:00:00Z",
    "last_checkpoint": "2026-02-07T00:00:00Z",
    "status": "active",
    "progress": ["Login form and JWT integration"],
    "files": ["src/auth/*.ts", "tests/auth/*.test.ts"]
  }
]
EOF

# Force-add the gitignored file
git -C "$TEST_PROJECT" add -f .agentic/session/AGENTS.json
git -C "$TEST_PROJECT" commit -m "Add active agents" --quiet

# Ask about parallel work on a different feature
send_prompt "I want to start working on the payment feature while my colleague works on auth in parallel"

# Verify agent behavior
FAILURES=0

# Agent should mention coordination or parallel work awareness
check_output_contains "AGENTS.json\|AGENTS_ACTIVE\|coordination\|parallel\|worktree\|conflict\|branch\|isolat\|concurrent\|separate" \
    "Agent mentions multi-agent coordination or parallel work" || ((FAILURES++))

# Cleanup
cleanup_test_project

[[ $FAILURES -eq 0 ]]
