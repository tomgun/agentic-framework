#!/usr/bin/env bash
# S03: Stale JOURNAL.md blocks commit
# Not updating JOURNAL.md after last commit should block next commit
set -euo pipefail
source "$(dirname "$0")/../lib/helpers.sh"

section_header "S03: Stale JOURNAL.md blocks commit"

PROJECT=$(scaffold_test_project "core")
cd "$PROJECT"

# Wait to ensure mtime gap
sleep 2

# Attempt commit WITHOUT touching JOURNAL.md
OUTPUT=$(attempt_commit_raw "$PROJECT" 2>&1) && EXIT_CODE=0 || EXIT_CODE=$?

assert_exit_code 1 "$EXIT_CODE" "commit blocked when JOURNAL.md is stale"
assert_output_contains "$OUTPUT" "JOURNAL\|not updated" "output mentions JOURNAL staleness"

cleanup_test_project "$PROJECT"
print_summary
