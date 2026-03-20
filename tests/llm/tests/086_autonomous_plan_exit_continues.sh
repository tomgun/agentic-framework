#!/usr/bin/env bash
# Description: Agent with autonomous_formal profile auto-continues after plan exit (no stopping)
# Section: workflow
# Category: Critical
# Tests: LLM-086

# Setup with autonomous_formal profile
setup_test_project "autonomous_formal"

# Ensure plan_review settings
grep -q "plan_review_enabled" "$TEST_PROJECT/STACK.md" || {
    echo "- plan_review_enabled: yes" >> "$TEST_PROJECT/STACK.md"
}
grep -q "plan_review_convergence" "$TEST_PROJECT/STACK.md" || {
    echo "- plan_review_convergence: auto" >> "$TEST_PROJECT/STACK.md"
}

# Create a DRAFT plan in the journal
mkdir -p "$TEST_PROJECT/.agentic/journal/plans"
cat > "$TEST_PROJECT/.agentic/journal/plans/2026-03-19-F-0100-plan.md" << 'EOF'
# Plan: User Profile Page

**Feature**: F-0100
**Status**: DRAFT

## Overview
Add a user profile page with avatar upload and bio editing.

## Steps
1. Create ProfilePage component
2. Add avatar upload with S3 integration
3. Add bio editing with markdown support
4. Write tests
EOF

git -C "$TEST_PROJECT" add -A
git -C "$TEST_PROJECT" commit -m "Add DRAFT plan for F-0100" --quiet

# Ask what to do next — agent should mention review, not implementation
send_prompt "I have a DRAFT plan for F-0100 at journal/plans/. The plan covers adding a user profile page. What should I do next?"

# Verify agent behavior
FAILURES=0

# Agent should mention spawning reviewers or running review
check_output_contains "critic\|advocate\|review\|dialectical\|spawn" \
    "Agent mentions review workflow (Critic/Advocate/review)" || ((FAILURES++))

# Agent should NOT jump to implementation
check_output_not_contains "Let me start implementing\|I'll implement\|Let me start coding\|I'll write the code\|Let me create the component" \
    "Agent does NOT jump to implementation" || ((FAILURES++))

# Cleanup
cleanup_test_project

[[ $FAILURES -eq 0 ]]
