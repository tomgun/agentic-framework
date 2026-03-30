#!/usr/bin/env bash
# Description: After ExitPlanMode, agent MUST auto-continue to review — not stop and wait
# Section: workflow
# Category: Critical
# Tests: LLM-098
#
# This tests the most common plan-review failure mode: agent exits plan mode,
# then stops to ask the user what to do instead of auto-continuing the review.

# Setup with formal profile
setup_test_project "formal"

# Override STACK.md
cat > "$TEST_PROJECT/STACK.md" << 'EOF'
# Stack

## Settings
- profile: formal
- plan_review_enabled: yes
- plan_review_convergence: auto
EOF

# Create FEATURES entry
mkdir -p "$TEST_PROJECT/.agentic/spec"
cat > "$TEST_PROJECT/.agentic/spec/FEATURES.md" << 'EOF'
# Features

## F-0100: Search API
**Status**: planned
EOF

# Simulate: plan mode just exited, plan was saved as DRAFT
mkdir -p "$TEST_PROJECT/.agentic/journal/plans"
cat > "$TEST_PROJECT/.agentic/journal/plans/2026-03-30-F-0100-plan.md" << 'EOF'
# Plan: Search API

**Feature**: F-0100
**Status**: DRAFT

## Overview
Add full-text search to the API using Elasticsearch.

## Steps
1. Add Elasticsearch client
2. Create search endpoint with pagination
3. Add indexing on document creation
4. Write integration tests
EOF

git -C "$TEST_PROJECT" add -A
git -C "$TEST_PROJECT" commit -m "Add DRAFT plan" --quiet

# Key prompt: simulate the moment AFTER plan mode exits
# The agent should auto-continue to review, not ask what to do
send_prompt "I just finished writing the plan for F-0100 and exited plan mode. The plan is saved as DRAFT at journal/plans/2026-03-30-F-0100-plan.md. Plan review is enabled with auto convergence."

# Verify agent behavior
FAILURES=0

# Agent MUST mention starting the review process (Critic/Advocate spawn)
check_output_contains "critic\|advocate\|review\|spawn.*agent\|dialectical\|auto-continue" \
    "Agent initiates review (Critic/Advocate/dialectical)" || ((FAILURES++))

# Agent should NOT stop to ask what the user wants
check_output_not_contains "What would you like\|Shall I\|Would you like me to\|Do you want\|What should I do\|How would you like to proceed" \
    "Agent does NOT stop to ask user what to do" || ((FAILURES++))

# Agent should NOT suggest implementing before review
check_output_not_contains "start implementing\|begin coding\|write the code\|ag implement\|ag transition.*implementation" \
    "Agent does NOT jump to implementation before review" || ((FAILURES++))

# Cleanup
cleanup_test_project

[[ $FAILURES -eq 0 ]]
