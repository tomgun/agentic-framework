#!/usr/bin/env bash
# verify-fix.sh: Verify a bug fix by running tests
# Delegates to framework tools — this is a thin wrapper.
set -euo pipefail

TEST_FILE="${1:-}"

if [[ -z "$TEST_FILE" ]]; then
    echo "Usage: verify-fix.sh <test-file-or-pattern>"
    echo "Runs the specified test to verify the bug fix, then the full suite."
    exit 1
fi

echo "=== Bug Fix Verification ==="
echo ""

# Step 1: Run the specific regression test
echo "--- Running regression test: $TEST_FILE ---"
if [[ -f "$TEST_FILE" ]]; then
    # Try common test runners
    if [[ "$TEST_FILE" == *.py ]]; then
        python -m pytest "$TEST_FILE" -v 2>&1 || { echo "✗ Regression test failed"; exit 1; }
    elif [[ "$TEST_FILE" == *.sh ]]; then
        bash "$TEST_FILE" 2>&1 || { echo "✗ Regression test failed"; exit 1; }
    elif [[ "$TEST_FILE" == *.test.* || "$TEST_FILE" == *.spec.* ]]; then
        npx jest "$TEST_FILE" 2>&1 || { echo "✗ Regression test failed"; exit 1; }
    else
        echo "Unknown test type. Run manually."
        exit 1
    fi
    echo "✓ Regression test passes"
else
    echo "Test file not found: $TEST_FILE"
    exit 1
fi

echo ""
echo "--- Full suite ---"
echo "Run your project's test suite manually to check for regressions."
