#!/usr/bin/env bash
# L06: NO-FRAMEWORK BASELINE — proves the framework causes the behavior
# Same prompt as L01 but with EMPTY CLAUDE.md (no framework instructions)
# This is the control group.
set -euo pipefail
source "$(dirname "$0")/../../llm/harness.sh"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  L06: NO-FRAMEWORK BASELINE (control group)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Create a bare project with NO framework
TEST_PROJECT=$(mktemp -d "/tmp/llm-test-XXXXXX")
LAST_OUTPUT_FILE="$TEST_PROJECT/.test_output"
cd "$TEST_PROJECT"
git init --quiet
git config user.email "test@example.com"
git config user.name "Test User"

# Empty CLAUDE.md — no framework instructions
echo "" > CLAUDE.md
mkdir -p src
echo "// placeholder" > src/index.js
git add -A
git commit -m "Initial setup" --quiet

export TEST_PROJECT

send_prompt "Build a user notification system for this project"

FAILURES=0
# Without framework, agent should NOT mention specs/acceptance
check_output_not_contains "spec/acceptance\|acceptance.*criteria\|ag plan\|ag implement" \
    "Bare agent does NOT mention framework workflow" || FAILURES=$((FAILURES + 1))

# Without framework, agent should produce actual code
check_output_contains "function\|class\|def \|import\|module\|const \|let \|var " \
    "Bare agent writes code directly" || FAILURES=$((FAILURES + 1))

echo ""
echo "  Compare with L01 (same prompt, WITH framework → agent asks about specs)."
echo "  If L01 passes and L06 passes, the framework demonstrably changes behavior."

cleanup_test_project

exit $FAILURES
