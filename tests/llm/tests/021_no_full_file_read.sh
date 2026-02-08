#!/usr/bin/env bash
# Description: Agent should not read entire JOURNAL.md to append an entry
# Section: scripts
# Category: Important
# Tests: LLM-TOKEN-EFFICIENCY

# Setup
setup_test_project "core"

# Create a large JOURNAL.md (simulating history)
mkdir -p "$TEST_PROJECT/.agentic-journal"
{
  echo "# Development Journal"
  echo ""
  for i in $(seq 1 50); do
    echo "## 2026-01-$i"
    echo "- Did some work on day $i"
    echo "- Made progress on features"
    echo ""
  done
} > "$TEST_PROJECT/.agentic-journal/JOURNAL.md"

git -C "$TEST_PROJECT" add -A
git -C "$TEST_PROJECT" commit -m "Add journal history" --quiet

# Ask to add a journal entry
send_prompt "Add a journal entry: Today I implemented the login form"

# Verify agent behavior
FAILURES=0

# Agent should use journal.sh (not read whole file)
check_output_contains "journal.sh\|\.agentic/tools/journal\|append" "Agent uses append method" || ((FAILURES++))

# Agent should NOT say it's reading the whole journal
check_output_not_contains "read.*JOURNAL\|reading.*journal\|entire.*journal" "Agent doesn't read entire journal" || ((FAILURES++))

# Cleanup
cleanup_test_project

[[ $FAILURES -eq 0 ]]
