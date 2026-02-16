#!/usr/bin/env bash
# S02: WIP.md blocks commit via hook
# Creating .agentic-state/WIP.md should prevent git commit
set -euo pipefail
source "$(dirname "$0")/../lib/helpers.sh"

section_header "S02: WIP.md blocks commit"

PROJECT=$(scaffold_test_project "discovery")
cd "$PROJECT"

# Create WIP lock
mkdir -p .agentic-state
echo "Feature: test" > .agentic-state/WIP.md
git add .agentic-state/WIP.md
git commit -m "add WIP" --quiet --no-verify

# Now attempt a normal commit — hook should block
OUTPUT=$(attempt_commit "$PROJECT" 2>&1) && EXIT_CODE=0 || EXIT_CODE=$?

assert_exit_code 1 "$EXIT_CODE" "commit blocked when WIP.md exists"
assert_output_contains "$OUTPUT" "WIP\|BLOCKED\|incomplete" "output mentions WIP/BLOCKED"

cleanup_test_project "$PROJECT"
print_summary
