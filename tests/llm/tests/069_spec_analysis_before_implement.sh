#!/usr/bin/env bash
# Description: Spec analysis step: implementing with spec_analysis=on should mention spec-analyze before coding
# Section: skills
# Category: Important
# Tests: LLM-069

# Setup with Formal profile (spec_analysis defaults to on)
setup_test_project "formal"

# Create a feature with acceptance criteria that has a vague term (triggers ambiguity finding)
mkdir -p "$TEST_PROJECT/spec/contracts" "$TEST_PROJECT/spec/acceptance"
cat > "$TEST_PROJECT/spec/FEATURES.md" << 'EOF'
# Features

## F-0020: Notification System

**Status**: planned
**Priority**: high

**Description**: Add user notification system.

**Acceptance**: See `spec/contracts/F-0020.yaml`
EOF

cat > "$TEST_PROJECT/spec/acceptance/F-0020.md" << 'EOF'
# F-0020: Notification System

## Acceptance Criteria

- **AC-001**: Users receive notifications for new messages
- **AC-002**: Notification delivery must be fast and responsive
- **AC-003**: Users can configure notification preferences
EOF

# Ensure spec_analysis is on in STACK.md
cat >> "$TEST_PROJECT/STACK.md" << 'EOF'

- spec_analysis: on
EOF

git -C "$TEST_PROJECT" add -A
git -C "$TEST_PROJECT" commit -m "Add notification feature spec" --quiet

# Ask to implement the feature
send_prompt "Implement F-0020, the notification system"

# Verify agent mentions spec analysis / ambiguity / findings before coding
FAILURES=0

# Agent should reference spec analysis, ambiguity, or findings from spec-analyze.sh
check_output_contains "spec.analy\|ambig\|vague\|finding\|MEDIUM\|spec-analyze\|advisory\|metric" \
    "Agent mentions spec analysis or findings before implementation" || ((FAILURES++))

# Agent should still reference the normal workflow too (acceptance criteria/contracts, plan)
check_output_contains "acceptance\|criteria\|contract\|plan\|ag implement\|F-0020" \
    "Agent also references standard implementation workflow" || ((FAILURES++))

# Cleanup
cleanup_test_project

[[ $FAILURES -eq 0 ]]
