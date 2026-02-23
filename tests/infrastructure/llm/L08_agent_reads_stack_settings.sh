#!/usr/bin/env bash
# L08: Agent reads and respects explicit STACK.md settings
# With git_workflow: direct, agent should NOT create branches/PRs when asked to commit
set -euo pipefail
source "$(dirname "$0")/../../llm/harness.sh"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  L08: Agent respects STACK.md settings (git_workflow: direct)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

setup_test_project "discovery"

# Verify STACK.md has git_workflow: direct (discovery default)
check_file_contains "STACK.md" "git_workflow: direct" \
    "STACK.md has git_workflow: direct"

send_prompt "I've made some changes to the code. How should I commit them?"

FAILURES=0
# Agent should suggest direct commit (not branching/PR)
check_output_contains "commit\|git commit\|ag commit" \
    "Agent mentions committing" || FAILURES=$((FAILURES + 1))
check_output_not_contains "pull request\|feature branch\|git checkout -b\|gh pr\|create a PR\|open a PR" \
    "Agent does NOT suggest PR workflow (git_workflow is direct)" || FAILURES=$((FAILURES + 1))

cleanup_test_project

exit $FAILURES
