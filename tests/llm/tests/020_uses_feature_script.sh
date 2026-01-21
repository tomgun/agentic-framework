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

# Ask to update feature status
send_prompt "Mark F-0001 as shipped in FEATURES.md"

# Verify agent behavior
FAILURES=0

# Agent should mention or use feature.sh
check_output_contains "feature.sh\|\.agentic/tools/feature" "Agent mentions feature.sh script" || ((FAILURES++))

# Agent should understand the update
check_output_contains "F-0001\|status\|shipped\|update" "Agent understands feature update" || ((FAILURES++))

# Cleanup
cleanup_test_project

[[ $FAILURES -eq 0 ]]
