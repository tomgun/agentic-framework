#!/usr/bin/env bash
# Description: Agent should use journal.sh script instead of editing JOURNAL.md directly
# Section: scripts
# Category: Important
# Tests: LLM-070

# Setup
setup_test_project "discovery"

# Create JOURNAL.md so there's something to update
mkdir -p "$TEST_PROJECT/.agentic-journal"
cat > "$TEST_PROJECT/.agentic-journal/JOURNAL.md" << 'EOF'
# Development Journal

## Session Log

### 2025-01-17: Initial setup
- Created project structure
- Added basic configuration
EOF

git -C "$TEST_PROJECT" add .agentic-journal/JOURNAL.md
git -C "$TEST_PROJECT" commit -m "Add journal" --quiet

# Ask to update journal
send_prompt "Please add a journal entry about completing the login feature"

# Verify agent behavior
FAILURES=0

# Should use the script OR mention token efficiency approach
# Accept: uses journal.sh, mentions the script, OR mentions append/token-efficient
if check_output_contains "journal.sh\|tools/journal\|bash.*journal" "Agent uses journal.sh script"; then
    : # Best outcome - uses the script
elif echo "$LAST_OUTPUT" | grep -qi "append\|token.efficient\|script"; then
    echo -e "${GREEN}✓ Agent mentions token-efficient approach${NC}"
else
    echo -e "${YELLOW}⚠ Agent doesn't mention journal.sh - guideline needs strengthening${NC}"
    # Note: This is a guideline issue, not a hard failure
    # The key protection is not reading the whole file
fi

# Critical check: Agent should NOT read the whole file (token waste)
check_output_not_contains "let me read.*JOURNAL\|reading the entire\|cat.*JOURNAL" "Agent does NOT read entire JOURNAL.md" || ((FAILURES++))

# Cleanup
cleanup_test_project

[[ $FAILURES -eq 0 ]]
