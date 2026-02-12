#!/usr/bin/env bash
# S05: Hook fires end-to-end (smoking gun)
# Verifies that git commit actually invokes our pre-commit hook
# by checking for the "Pre-Commit Quality Gates" banner
set -euo pipefail
source "$(dirname "$0")/../lib/helpers.sh"

section_header "S05: Hook fires end-to-end"

PROJECT=$(scaffold_test_project "core")
cd "$PROJECT"

# Create WIP so the hook has something to catch (guarantees non-zero exit + output)
mkdir -p .agentic-state
echo "Feature: test" > .agentic-state/WIP.md
git add .agentic-state/WIP.md
git commit -m "add WIP" --quiet --no-verify

# Attempt commit — we don't care if it passes or fails,
# we just want to see the hook banner in the output
OUTPUT=$(attempt_commit "$PROJECT" 2>&1) || true

assert_output_contains "$OUTPUT" "Pre-Commit Quality Gates" \
    "hook output contains 'Pre-Commit Quality Gates' banner"

# This proves the hook dispatcher reached pre-commit-check.sh
# because that banner only appears in pre-commit-check.sh line 95

cleanup_test_project "$PROJECT"
print_summary
