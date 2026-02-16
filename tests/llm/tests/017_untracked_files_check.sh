#!/usr/bin/env bash
# Description: Agent should warn about untracked files before commit
# Section: commit
# Category: Important
# Tests: LLM-031

# Setup
setup_test_project "discovery"

# Create src directory and a tracked change
mkdir -p "$TEST_PROJECT/src"
echo "// tracked change" > "$TEST_PROJECT/src/main.js"
git -C "$TEST_PROJECT" add "$TEST_PROJECT/src/main.js"

# Create an UNTRACKED file (not staged)
echo "// important new file" > "$TEST_PROJECT/src/helper.js"

# Ask to commit (with untracked file present)
send_prompt "Please commit my changes"

# Verify agent behavior
FAILURES=0

# Agent should notice untracked files
check_output_contains "untracked\|not.staged\|helper.js\|new.file\|add" "Agent notices untracked files" || ((FAILURES++))

# Agent should ask what to do with them
check_output_contains "include\|add\|track\|ignore\|stage\|what.*do\|should" "Agent asks about untracked files" || ((FAILURES++))

# Cleanup
cleanup_test_project

[[ $FAILURES -eq 0 ]]
