#!/usr/bin/env bash
# M02: Delete pre-commit hook file → hooks can't dispatch
# MUTATION TEST: proves the hook file is critical infrastructure
set -euo pipefail
source "$(dirname "$0")/../lib/helpers.sh"

section_header "M02: Mutation — delete pre-commit hook file"

PROJECT=$(scaffold_test_project "core")
cd "$PROJECT"

# Create WIP to give hook something to catch
mkdir -p .agentic-state
echo "Feature: test" > .agentic-state/WIP.md
git add .agentic-state/WIP.md
git commit -m "add WIP" --quiet --no-verify

# ── Baseline: hook should block ──
OUTPUT=$(attempt_commit "$PROJECT" 2>&1) && EXIT_CODE=0 || EXIT_CODE=$?
assert_exit_code 1 "$EXIT_CODE" "BASELINE: commit blocked with hook file present"

# Reset
git reset HEAD~0 2>/dev/null || true
git checkout -- . 2>/dev/null || true
rm -f dummy.txt

# ── Mutation: delete the pre-commit hook file ──
rm .agentic/hooks/pre-commit

OUTPUT=$(attempt_commit "$PROJECT" 2>&1) && EXIT_CODE=0 || EXIT_CODE=$?
assert_exit_code 0 "$EXIT_CODE" "MUTATION: commit succeeds without hook file (hooks gone!)"

echo ""
echo -e "  ${GREEN}PROVEN:${NC} Deleting the pre-commit hook file removes all enforcement."
echo -e "         core.hooksPath still points to .agentic/hooks/ but there's nothing to run."

cleanup_test_project "$PROJECT"
print_summary
