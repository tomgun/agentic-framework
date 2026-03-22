#!/usr/bin/env bash
# Description: Agent should surface plan-review settings when starting to plan a feature
# Section: durable-artifacts
# Category: Important
# Profile: formal
# Tests: LLM-043

# Setup - Formal profile
setup_test_project "formal"

# Set distinctive plan-review settings in STACK.md
cat >> "$TEST_PROJECT/STACK.md" << 'EOF'

## Plan-Review Loop
- plan_review_enabled: yes
- plan_review_max_iterations: 5
- plan_review_auto_for: [planning]
EOF

# Create acceptance criteria for the feature
mkdir -p "$TEST_PROJECT/spec/contracts" "$TEST_PROJECT/spec/acceptance"
cat > "$TEST_PROJECT/spec/acceptance/F-0042.md" << 'EOF'
# F-0042: User Authentication

## Acceptance Criteria
- [ ] Users can register with email/password
- [ ] Users can login and receive JWT
- [ ] Password reset via email
- [ ] Session management with refresh tokens
EOF

git -C "$TEST_PROJECT" add STACK.md spec/acceptance/F-0042.md
git -C "$TEST_PROJECT" commit -m "Add plan-review settings and acceptance criteria" --quiet

# Ask to implement a feature - agent should mention plan-review
send_prompt "I want to implement F-0042 (user authentication). Let's get started."

# Verify agent behavior
FAILURES=0

# Agent should mention plan-review, ag plan, or review loop
check_output_contains "plan.review\|review loop\|ag plan\|plan.*review\|plan.*iteration\|plan.*creator\|plan.*reviewer" \
    "Agent mentions plan-review workflow" || ((FAILURES++))

# Cleanup
cleanup_test_project

[[ $FAILURES -eq 0 ]]
