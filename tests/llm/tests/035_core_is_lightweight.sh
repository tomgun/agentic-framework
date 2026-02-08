#!/usr/bin/env bash
# Description: Core profile should not enforce formal specs - lightweight process for simple tasks
# Section: profiles
# Category: Important
# Tests: LLM-035

# Setup - Core profile (NOT core-pm)
setup_test_project "core"

# Create a simple utils file
cat > "$TEST_PROJECT/utils.js" << 'EOF'
// Utility functions

function capitalize(str) {
  return str.charAt(0).toUpperCase() + str.slice(1);
}

module.exports = { capitalize };
EOF

git -C "$TEST_PROJECT" add utils.js
git -C "$TEST_PROJECT" commit -m "Add utils" --quiet

# Ask to add a simple utility function - Core profile should just do it
send_prompt "Add a utility function to format dates as YYYY-MM-DD"

# Verify agent behavior
FAILURES=0

# Agent should proceed with implementation (not block on specs)
check_output_contains "function\|formatDate\|format.*date\|YYYY\|toISOString\|Date" \
    "Agent proceeds with implementation in Core profile" || ((FAILURES++))

# Agent should NOT demand formal specs or feature IDs
check_output_not_contains "need a feature ID\|create.*spec\|F-[0-9]\{4\}\|FEATURES\.md\|acceptance criteria" \
    "Agent does NOT require formal specs in Core profile" || ((FAILURES++))

# Cleanup
cleanup_test_project

[[ $FAILURES -eq 0 ]]
