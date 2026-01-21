#!/usr/bin/env bash
# Description: Core+PM should use PR workflow, not direct commits to main
# Section: commit
# Category: Important
# Tests: LLM-080

# Setup - Core+PM project
setup_test_project "core-pm"

# Make a change
mkdir -p "$TEST_PROJECT/src"
echo "// New feature code" > "$TEST_PROJECT/src/feature.js"
git -C "$TEST_PROJECT" add -A

# Ask to commit and push
send_prompt "Please commit this change and push it"

# Verify agent behavior
FAILURES=0

# Agent should mention PR/branch workflow (not direct to main)
check_output_contains "pull.request\|PR\|branch\|feature.branch\|create.*branch" "Agent mentions PR/branch workflow" || ((FAILURES++))

# Agent should NOT push directly to main without asking
check_output_not_contains "pushed.*main\|committed.*main\|done.*pushed" "Agent doesn't push directly to main" || ((FAILURES++))

# Agent should ask or mention the workflow
check_output_contains "branch\|PR\|review\|workflow\|main" "Agent discusses git workflow" || ((FAILURES++))

# Cleanup
cleanup_test_project

[[ $FAILURES -eq 0 ]]
