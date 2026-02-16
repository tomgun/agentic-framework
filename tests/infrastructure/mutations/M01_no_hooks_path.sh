#!/usr/bin/env bash
# M01: Remove core.hooksPath → all enforcement silently gone
# MUTATION TEST: proves core.hooksPath is THE enforcement point
set -euo pipefail
source "$(dirname "$0")/../lib/helpers.sh"

section_header "M01: Mutation — remove core.hooksPath"

PROJECT=$(scaffold_test_project "discovery")
cd "$PROJECT"

# Create WIP to give hook something to catch
mkdir -p .agentic-state
echo "Feature: test" > .agentic-state/WIP.md
git add .agentic-state/WIP.md
git commit -m "add WIP" --quiet --no-verify

# ── Baseline: hook should block ──
OUTPUT=$(attempt_commit "$PROJECT" 2>&1) && EXIT_CODE=0 || EXIT_CODE=$?
assert_exit_code 1 "$EXIT_CODE" "BASELINE: commit blocked with hooks enabled"

# Reset the failed commit attempt
git reset HEAD~0 2>/dev/null || true
git checkout -- . 2>/dev/null || true
rm -f dummy.txt

# ── Mutation: remove core.hooksPath ──
git config --unset core.hooksPath

OUTPUT=$(attempt_commit "$PROJECT" 2>&1) && EXIT_CODE=0 || EXIT_CODE=$?
assert_exit_code 0 "$EXIT_CODE" "MUTATION: commit succeeds without core.hooksPath (hooks bypassed!)"

echo ""
echo -e "  ${GREEN}PROVEN:${NC} Without core.hooksPath, all 12 quality checks"
echo -e "         are silently bypassed. The hook file exists but git never calls it."

cleanup_test_project "$PROJECT"
print_summary
