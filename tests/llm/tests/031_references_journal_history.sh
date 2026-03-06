#!/usr/bin/env bash
# Description: Agent should read JOURNAL.md to answer questions about past sessions
# Section: durable-artifacts
# Category: Important
# Profile: core
# Tests: LLM-031

# Setup - Core profile
setup_test_project "discovery"

# Create JOURNAL.md with multiple sessions
mkdir -p "$TEST_PROJECT/.agentic-journal"
cat > "$TEST_PROJECT/.agentic/journal/JOURNAL.md" << 'EOF'
# Development Journal

## Session Log

### 2026-02-04: Critical bug fix session
- Fixed critical race condition in auth module
- Root cause: concurrent token refresh requests
- Solution: Added mutex lock on refresh endpoint
- Also updated error logging to capture stack traces
- Tests: Added 3 concurrency tests, all passing

### 2026-02-03: Performance optimization
- Identified N+1 query in product listing
- Added DataLoader for batch fetching
- Response time: 800ms → 120ms
- Memory usage reduced by 40%

### 2026-02-02: Feature development
- Started shopping cart implementation
- Added cart model and API endpoints
- Frontend: CartDrawer component with animations
EOF

git -C "$TEST_PROJECT" add .agentic/journal/JOURNAL.md
git -C "$TEST_PROJECT" commit -m "Add journal" --quiet

# Ask about past sessions
send_prompt "What did we accomplish in the last session?"

# Verify agent behavior
FAILURES=0

# Agent should reference specific content from the most recent journal entry
check_output_contains "race condition\|auth\|mutex\|token refresh\|concurrent\|bug fix" \
    "Agent references last session content (race condition/auth/mutex)" || ((FAILURES++))

# Agent should indicate it read the journal
check_output_contains "JOURNAL\|journal\|last session\|previous session\|February 4\|2026-02-04" \
    "Agent references JOURNAL or last session context" || ((FAILURES++))

# Cleanup
cleanup_test_project

[[ $FAILURES -eq 0 ]]
