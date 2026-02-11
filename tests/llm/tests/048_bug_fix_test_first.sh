#!/usr/bin/env bash
# Description: Agent should suggest writing a failing test before fixing a bug
# Section: trigger
# Category: Important
# Tests: LLM-048

# Setup with Core profile
setup_test_project "core"

# Create a simple app with a bug scenario
cat > "$TEST_PROJECT/src/session.js" << 'EOF'
class SessionManager {
  constructor(timeout = 30 * 60 * 1000) {
    this.timeout = timeout;
    this.sessions = new Map();
  }

  createSession(userId) {
    const session = {
      userId,
      createdAt: Date.now(),
      expiresAt: Date.now() + this.timeout
    };
    this.sessions.set(userId, session);
    return session;
  }

  isValid(userId) {
    const session = this.sessions.get(userId);
    if (!session) return false;
    return Date.now() < session.expiresAt;
  }
}

module.exports = { SessionManager };
EOF

git -C "$TEST_PROJECT" add src/
git -C "$TEST_PROJECT" commit -m "Add session manager" --quiet

# Report a bug
send_prompt "There's a bug: users get logged out after 5 minutes even though sessions should last 30 minutes. Can you fix it?"

# Verify agent behavior
FAILURES=0

# Agent should mention writing a test or reproducing first
check_output_contains "test\|reproduc\|verify\|failing.*test\|test.*first\|write.*test\|TDD" \
    "Agent mentions writing a test or reproducing the bug first" || ((FAILURES++))

# Agent should NOT just jump to changing code without mentioning tests
check_output_not_contains "here.s the fix.*no test\|fixed it.*commit\|I.ve updated.*session" \
    "Agent does NOT immediately fix without mentioning tests" || ((FAILURES++))

# Cleanup
cleanup_test_project

[[ $FAILURES -eq 0 ]]
