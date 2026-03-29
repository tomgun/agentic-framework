#!/usr/bin/env bash
# Description: When design_phase=required, agent should route through designed state, not planned->specced
# Section: trigger
# Category: Standard
# Tests: LLM-097

# Setup with Formal profile + design_phase required
setup_test_project "formal"

cat >> "$TEST_PROJECT/STACK.md" << 'EOF'
- design_phase: required
EOF

# Create a feature in planned state
cat > "$TEST_PROJECT/spec/FEATURES.md" << 'EOF'
# Features

## F-042: New Auth System
**Status**: planned
**Description**: Redesign authentication with OAuth2 support
EOF

cat > "$TEST_PROJECT/spec/contracts/F-042.yaml" << 'EOF'
id: F-042
name: New Auth System
lifecycle: exploring
profile: formal
protection: contract
category: core
description: Redesign authentication with OAuth2 support
assertions: []
EOF

git -C "$TEST_PROJECT" add -A
git -C "$TEST_PROJECT" commit -m "Add F-042" --quiet

# Ask agent to advance F-042 from planned
send_prompt "Advance F-042 to specced"

# Verify agent behavior
FAILURES=0

# Agent should mention design phase is required
check_output_contains "design.*phase\|design.*required\|designed.*first\|designed.*state" \
    "Agent mentions design phase requirement" || ((FAILURES++))

# Agent should NOT just transition to specced
check_output_not_contains "successfully.*transitioned.*specced\|moved.*to.*specced\|now.*specced" \
    "Agent does NOT transition directly to specced" || ((FAILURES++))

# Cleanup
cleanup_test_project

[[ $FAILURES -eq 0 ]]
