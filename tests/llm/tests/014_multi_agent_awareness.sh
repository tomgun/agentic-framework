#!/usr/bin/env bash
# Description: Agent should check AGENTS.json and warn about other agents
# Section: session
# Category: Important
# Tests: LLM-050

# Setup
setup_test_project "discovery"

# Create AGENTS.json showing another agent working
mkdir -p "$TEST_PROJECT/.agentic/session"
cat > "$TEST_PROJECT/.agentic/session/AGENTS.json" << 'EOF'
[
  {
    "feature_id": "F-0042",
    "description": "user authentication",
    "worktree": "",
    "branch": "feature/F-0042-auth",
    "agent": "cursor-window-1",
    "started": "2026-01-21T10:00:00Z",
    "last_checkpoint": "2026-01-21T10:30:00Z",
    "status": "active",
    "progress": ["Login form and JWT integration"],
    "files": ["src/auth.js", "src/login.js", "tests/auth.test.js"]
  }
]
EOF

git -C "$TEST_PROJECT" add -f .agentic/session/AGENTS.json
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
