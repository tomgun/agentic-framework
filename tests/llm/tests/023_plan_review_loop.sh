#!/usr/bin/env bash
# Description: Agent should use plan-review loop for complex features (Core+PM)
# Section: planning
# Category: Important
# Tests: LLM-023 (F-0120)

# Setup with Core+PM profile (plan_review_enabled by default)
setup_test_project "core-pm"

# Enable plan-review in STACK.md (should already be enabled by default for Core+PM)
# Verify it's in the config
grep -q "plan_review_enabled" "$TEST_PROJECT/STACK.md" || {
    echo "plan_review_enabled: yes" >> "$TEST_PROJECT/STACK.md"
}

# Create acceptance criteria for a complex feature
mkdir -p "$TEST_PROJECT/spec/acceptance"
cat > "$TEST_PROJECT/spec/acceptance/F-0042.md" << 'EOF'
# F-0042: User Authentication - Acceptance Criteria

## Overview
Add user authentication with login, logout, and session management.

## Acceptance Criteria

### AC-1: Login
- [ ] User can log in with email and password
- [ ] Invalid credentials show error message
- [ ] Session persists across page refreshes

### AC-2: Logout
- [ ] User can log out
- [ ] Session is cleared on logout

### AC-3: Protected Routes
- [ ] Unauthenticated users redirected to login
- [ ] Authenticated users can access protected routes
EOF

git -C "$TEST_PROJECT" add spec/acceptance/F-0042.md
git -C "$TEST_PROJECT" commit -m "Add F-0042 acceptance criteria" --quiet

# Ask to plan a complex feature
send_prompt "Create a plan for implementing F-0042 (user authentication)"

# Verify agent behavior
FAILURES=0

# Agent should mention plan-review or planning workflow
check_output_contains "plan\|review\|.agentic-state/plans\|plan_review\|Plan.*Creator\|Plan.*Reviewer" \
    "Agent mentions planning/plan-review workflow" || ((FAILURES++))

# Agent should reference or read the acceptance criteria
check_output_contains "F-0042\|acceptance\|criteria\|AC-1\|AC-2\|AC-3\|login\|logout\|authentication" \
    "Agent references acceptance criteria" || ((FAILURES++))

# Agent should NOT immediately write implementation code
check_output_not_contains "^\`\`\`javascript.*function.*login\|^\`\`\`typescript.*async.*authenticate\|class.*Auth.*{" \
    "Agent does NOT immediately write implementation code" || ((FAILURES++))

# Cleanup
cleanup_test_project

[[ $FAILURES -eq 0 ]]
