#!/usr/bin/env bash
# S04: Branch policy blocks commit to main
# With git_workflow: pull_request, commits to main should be blocked
set -euo pipefail
source "$(dirname "$0")/../lib/helpers.sh"

section_header "S04: Branch policy blocks commit to main"

PROJECT=$(scaffold_test_project "core")
cd "$PROJECT"

# Set PR workflow in STACK.md
if grep -q "git_workflow:" STACK.md 2>/dev/null; then
    sed -i.bak 's/git_workflow:.*/git_workflow: pull_request/' STACK.md
else
    echo "- git_workflow: pull_request" >> STACK.md
fi
rm -f STACK.md.bak

# Commit the STACK.md change first (on main, with no-verify since we just changed policy)
git add STACK.md
git commit -m "set PR workflow" --quiet --no-verify

# Now attempt a normal commit on main — should be blocked
OUTPUT=$(attempt_commit "$PROJECT" 2>&1) && EXIT_CODE=0 || EXIT_CODE=$?

assert_exit_code 1 "$EXIT_CODE" "commit blocked on main with PR workflow"
assert_output_contains "$OUTPUT" "Direct commit\|main\|BLOCKED\|PR\|pull_request" "output mentions branch policy"

cleanup_test_project "$PROJECT"
print_summary
