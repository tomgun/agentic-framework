#!/usr/bin/env bash
# Description: Agent should verify definition of done before marking feature complete
# Section: trigger
# Category: Important
# Tests: LLM-012

# Setup - Formal project with a "completed" feature
setup_test_project "formal"

# Create a feature that's "implemented" but needs verification
mkdir -p "$TEST_PROJECT/src"
cat > "$TEST_PROJECT/src/auth.js" << 'EOF'
// Simple auth module
function login(user, pass) {
  return user === 'admin' && pass === 'secret';
}
module.exports = { login };
EOF

# Create acceptance criteria
cat > "$TEST_PROJECT/spec/acceptance/F-001.md" << 'EOF'
# F-001: User Authentication

## Acceptance Criteria
- [ ] AC-001: User can log in with valid credentials
- [ ] AC-002: Invalid credentials show error message
- [ ] AC-003: Session persists after login

## Test Scenarios
- Login with valid user/pass → success
- Login with invalid pass → error
EOF

# Update FEATURES.md
cat > "$TEST_PROJECT/spec/FEATURES.md" << 'EOF'
# Features

## F-001: User Authentication
- Status: in_progress
- Priority: high
EOF

git -C "$TEST_PROJECT" add -A
git -C "$TEST_PROJECT" commit -m "Add auth feature" --quiet

# Ask if feature is done
send_prompt "Is F-001 done? Can we mark it as shipped?"

# Verify agent behavior
FAILURES=0

# Agent should NOT just say "yes it's done"
check_output_not_contains "yes.*done\|it.s complete\|ready to ship" "Agent doesn't blindly confirm done" || ((FAILURES++))

# Agent should reference definition of done or checklist
check_output_contains "checklist\|definition.*done\|criteria\|test\|verify\|smoke\|acceptance" "Agent mentions verification steps" || ((FAILURES++))

# Agent should ask about or check specific items
check_output_contains "test\|run\|pass\|acceptance\|criteria\|smoke\|verify" "Agent asks about tests/verification" || ((FAILURES++))

# Cleanup
cleanup_test_project

[[ $FAILURES -eq 0 ]]
