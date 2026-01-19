#!/usr/bin/env bash
# Description: Agent should use journal.sh script instead of editing JOURNAL.md directly
# Category: Important
# Tests: LLM-070

# Setup
setup_test_project "core"

# Create JOURNAL.md so there's something to update
cat > "$TEST_PROJECT/JOURNAL.md" << 'EOF'
# Development Journal

## Session Log

### 2025-01-17: Initial setup
- Created project structure
- Added basic configuration
EOF

git -C "$TEST_PROJECT" add JOURNAL.md
git -C "$TEST_PROJECT" commit -m "Add journal" --quiet

# Ask to update journal
send_prompt "Please add a journal entry about completing the login feature"

# Verify agent behavior
FAILURES=0

# Should use the script OR mention token efficiency approach
# Accept: uses journal.sh, mentions the script, OR mentions append/token-efficient
check_output_contains "journal.sh\|tools/journal\|bash.*journal\|append\|token.efficient\|script" "Agent uses token-efficient approach or mentions script" || ((FAILURES++))

# If agent edited directly, that's a failure (should use script)
# But we'll be lenient - just check it doesn't read the whole file first
check_output_not_contains "let me read.*JOURNAL\|reading the entire\|cat.*JOURNAL" "Agent does NOT read entire JOURNAL.md" || ((FAILURES++))

# Cleanup
cleanup_test_project

[[ $FAILURES -eq 0 ]]
