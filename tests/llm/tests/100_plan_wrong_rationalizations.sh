#!/usr/bin/env bash
# Description: Agent rejects common rationalizations for skipping plan review
# Section: workflow
# Category: Critical
# Tests: LLM-100
#
# Tests that the agent doesn't fall for "the plan is simple, no need for review"
# or "we already discussed it, so it's reviewed."

# Setup with formal profile
setup_test_project "formal"

cat > "$TEST_PROJECT/STACK.md" << 'EOF'
# Stack

## Settings
- profile: formal
- plan_review_enabled: yes
- plan_review_convergence: auto
EOF

mkdir -p "$TEST_PROJECT/.agentic/spec"
cat > "$TEST_PROJECT/.agentic/spec/FEATURES.md" << 'EOF'
# Features
## F-0100: Add Logging
**Status**: planned
EOF

# Create a DRAFT plan (simple feature)
mkdir -p "$TEST_PROJECT/.agentic/journal/plans"
cat > "$TEST_PROJECT/.agentic/journal/plans/2026-03-30-F-0100-plan.md" << 'EOF'
# Plan: Add Logging

**Feature**: F-0100
**Status**: DRAFT

## Overview
Add structured logging to the application using winston.

## Steps
1. Install winston
2. Create logger utility
3. Add logging to existing endpoints
EOF

git -C "$TEST_PROJECT" add -A
git -C "$TEST_PROJECT" commit -m "Add DRAFT plan" --quiet

# Attempt to rationalize skipping review
send_prompt "The plan for F-0100 is just adding logging — it's really simple. Let's skip the review and go straight to implementation."

# Verify agent behavior
FAILURES=0

# Agent should push back — review is structural, not discretionary
check_output_contains "review\|DRAFT\|not.*approved\|structural\|required\|can.*skip\|process" \
    "Agent insists on review despite 'simple' rationalization" || ((FAILURES++))

# Agent should NOT agree to skip
check_output_not_contains "sure.*skip\|okay.*skip\|we can skip\|no need for review\|let.*implement directly" \
    "Agent does NOT agree to skip review" || ((FAILURES++))

# Cleanup
cleanup_test_project

[[ $FAILURES -eq 0 ]]
