#!/usr/bin/env bash
# Description: Agent should use feature.sh to update FEATURES.md
# Section: scripts
# Category: Important
# Tests: LLM-TOKEN-FEATURE

# Setup - Core+PM has FEATURES.md
setup_test_project "core-pm"

# Create a feature entry
cat > "$TEST_PROJECT/spec/FEATURES.md" << 'EOF'
# Features

## F-0001: User Authentication
- Status: in_progress
- Priority: high
- Implementation: partial
- Tests: none
EOF

git -C "$TEST_PROJECT" add -A
git -C "$TEST_PROJECT" commit -m "Add feature" --quiet

# Ask to update feature status (natural language)
send_prompt "Feature F-0001 is complete and shipped - please update its status"

# Verify agent behavior
FAILURES=0

# Ideal: Agent uses feature.sh (optimization goal)
if check_output_contains "feature\.sh\|tools/feature\|feature script\|bash.*feature" "Agent mentions feature.sh script"; then
    : # Best outcome
else
    echo -e "${YELLOW}⚠ Agent doesn't use feature.sh - optimization opportunity${NC}"
fi

# Critical: Agent understands the update
check_output_contains "F-0001\|status\|shipped\|complete\|update" "Agent understands feature update" || ((FAILURES++))

# Cleanup
cleanup_test_project

[[ $FAILURES -eq 0 ]]
