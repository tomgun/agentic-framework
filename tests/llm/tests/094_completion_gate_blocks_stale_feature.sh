#!/usr/bin/env bash
# Description: Agent acknowledges completion gate block and suggests ag done for stale prior feature
# Section: workflow
# Category: Critical
# Tests: LLM-094

# Setup with formal profile
setup_test_project "formal"

cat > "$TEST_PROJECT/STACK.md" << 'EOF'
# Stack

## Settings
- profile: formal
- acceptance_criteria: blocking
- plan_review_enabled: yes
- git_workflow: pull_request
EOF

# Create two features: F-0100 is "planned" but has commits, F-0101 is next
mkdir -p "$TEST_PROJECT/.agentic/spec/acceptance"
cat > "$TEST_PROJECT/.agentic/spec/FEATURES.md" << 'EOF'
# Features

## F-0100: Auth Middleware

**Status**: planned

---

## F-0101: User Dashboard

**Status**: planned

---
EOF

# Create backlog with F-0100 at position 0, F-0101 at position 1
cat > "$TEST_PROJECT/.agentic/BACKLOG.json" << 'EOF'
[
  {"type": "feature", "id": "F-0100", "description": "Auth Middleware"},
  {"type": "feature", "id": "F-0101", "description": "User Dashboard"}
]
EOF

# Simulate F-0100 having implementation commits on main
git -C "$TEST_PROJECT" add -A
git -C "$TEST_PROJECT" commit -m "feat: auth middleware implementation (F-0100)" --quiet

# Ask agent to implement F-0101 — should recognize the stale F-0100 blocks it
send_prompt "I want to implement F-0101 (User Dashboard). F-0100 has merged code on main but is still marked planned. What should I do?"

# Verify agent behavior
FAILURES=0

# Agent should mention ag done for the stale feature
check_output_contains "ag done.*F-0100\|ag done.*0100\|complete.*F-0100\|finish.*F-0100" \
    "Agent suggests ag done F-0100 for the stale feature" || ((FAILURES++))

# Agent should recognize F-0100 is blocking or needs to be resolved first
check_output_contains "block\|stale\|planned.*commit\|merged.*planned\|ship\|complete.*first\|before.*implement" \
    "Agent recognizes F-0100 is stale/blocking" || ((FAILURES++))

# Agent should mention the --force bypass as an option
check_output_contains "force\|bypass\|override\|skip" \
    "Agent mentions force/bypass option" || ((FAILURES++))

# Cleanup
cleanup_test_project

[[ $FAILURES -eq 0 ]]
