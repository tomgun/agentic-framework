#!/usr/bin/env bash
# Description: Skills-primary: "commit changes" should activate committing-changes skill (pre-commit gates)
# Section: skills
# Category: Important
# Tests: LLM-068

# Setup with Discovery profile
setup_test_project "discovery"

# Create a staged change
echo "console.log('hello');" > "$TEST_PROJECT/index.js"
git -C "$TEST_PROJECT" add index.js

# Ask to commit — should trigger committing-changes skill
send_prompt "I want to commit these changes"

# Verify agent follows committing-changes skill behavior
FAILURES=0

# Agent should mention journal/status updates, pre-commit, or showing changes first
check_output_contains "journal\|status\|pre.commit\|show.*change\|review.*change\|diff\|ag commit\|JOURNAL\|STATUS" \
    "Agent references commit workflow steps (journal, status, pre-commit, review)" || ((FAILURES++))

# Agent should NOT just run git commit without mentioning any workflow
check_output_not_contains "^git commit.*-m\|^committed successfully\|^done.*committed" \
    "Agent does NOT auto-commit without workflow" || ((FAILURES++))

# Cleanup
cleanup_test_project

[[ $FAILURES -eq 0 ]]
