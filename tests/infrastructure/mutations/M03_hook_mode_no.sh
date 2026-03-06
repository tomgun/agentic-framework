#!/usr/bin/env bash
# M03: Set pre_commit_hook: no → config disables everything
# MUTATION TEST: proves one config line can disable all quality gates
set -euo pipefail
source "$(dirname "$0")/../lib/helpers.sh"

section_header "M03: Mutation — set pre_commit_hook: no"

PROJECT=$(scaffold_test_project "discovery")
cd "$PROJECT"

# Create WIP to give hook something to catch
mkdir -p .agentic-state
echo "Feature: test" > .agentic/session/WIP.md
git add .agentic/session/WIP.md
git commit -m "add WIP" --quiet --no-verify

# ── Baseline: hook should block ──
OUTPUT=$(attempt_commit "$PROJECT" 2>&1) && EXIT_CODE=0 || EXIT_CODE=$?
assert_exit_code 1 "$EXIT_CODE" "BASELINE: commit blocked with pre_commit_hook: fast"

# Reset
git reset HEAD~0 2>/dev/null || true
git checkout -- . 2>/dev/null || true
rm -f dummy.txt

# ── Mutation: set pre_commit_hook: no in STACK.md ──
if grep -q "pre_commit_hook:" STACK.md 2>/dev/null; then
    sed -i.bak 's/pre_commit_hook:.*/pre_commit_hook: no/' STACK.md
else
    echo "- pre_commit_hook: no" >> STACK.md
fi
rm -f STACK.md.bak
git add STACK.md
git commit -m "disable hooks" --quiet --no-verify

OUTPUT=$(attempt_commit "$PROJECT" 2>&1) && EXIT_CODE=0 || EXIT_CODE=$?
assert_exit_code 0 "$EXIT_CODE" "MUTATION: commit succeeds with pre_commit_hook: no (all gates off!)"

echo ""
echo -e "  ${GREEN}PROVEN:${NC} One config line (pre_commit_hook: no) disables everything."
echo -e "         STACK.md is a trust boundary — must be human-controlled."

cleanup_test_project "$PROJECT"
print_summary
