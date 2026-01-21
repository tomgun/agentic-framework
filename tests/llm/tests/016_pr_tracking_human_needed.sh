#!/usr/bin/env bash
# Description: Agent should track PRs in HUMAN_NEEDED.md (v0.12.0 feature)
# Section: commit
# Category: Important
# Tests: LLM-PR-TRACKING

# Setup - Core+PM project
setup_test_project "core-pm"

# Make a change and ask to create PR
mkdir -p "$TEST_PROJECT/src"
echo "// New feature" > "$TEST_PROJECT/src/feature.js"
git -C "$TEST_PROJECT" add -A
git -C "$TEST_PROJECT" commit -m "Add feature" --quiet

# Ask to create PR (simulated - we can't actually create GitHub PR in test)
send_prompt "I've committed the changes. Now create a pull request for this feature."

# Verify agent behavior
FAILURES=0

# Agent should mention tracking the PR
check_output_contains "HUMAN_NEEDED\|track\|blocker\|review" "Agent mentions PR tracking" || ((FAILURES++))

# Agent should mention the PR workflow
check_output_contains "PR\|pull.request\|branch\|merge\|review" "Agent discusses PR workflow" || ((FAILURES++))

# Cleanup
cleanup_test_project

[[ $FAILURES -eq 0 ]]
