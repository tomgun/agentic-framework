#!/usr/bin/env bash
# Unit tests for check-spec-health.sh and ag spec command
#
# Tests:
#   - check-spec-health.sh with valid shipped feature
#   - check-spec-health.sh with missing acceptance file
#   - check-spec-health.sh with unknown feature
#   - check-spec-health.sh --all
#   - ag spec (no args) prints checklist
#   - ag spec F-XXXX delegates to health check
#   - ag spec --check delegates to health check --all

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0

test_case() {
    local name="$1"
    echo -n "Testing: $name... "
}

pass() {
    echo -e "${GREEN}PASS${NC}"
    ((PASSED++))
}

fail() {
    local msg="${1:-}"
    echo -e "${RED}FAIL${NC}"
    [[ -n "$msg" ]] && echo "  $msg"
    ((FAILED++))
}

#=============================================================================
# check-spec-health.sh tests (run against actual framework repo)
#=============================================================================

echo ""
echo "=== check-spec-health.sh ==="
echo ""

HEALTH_SCRIPT="$FRAMEWORK_ROOT/.agentic/lib/tools/check-spec-health.sh"

test_case "check-spec-health.sh exists and is executable"
if [[ -x "$HEALTH_SCRIPT" ]]; then
    pass
else
    fail "not found or not executable"
fi

test_case "check-spec-health.sh with no args shows usage"
output=$(bash "$HEALTH_SCRIPT" 2>&1) && exit_code=0 || exit_code=$?
if [[ $exit_code -eq 1 ]] && echo "$output" | grep -q "Usage"; then
    pass
else
    fail "expected exit 1 and usage text"
fi

test_case "check-spec-health.sh F-0001 (shipped feature)"
cd "$FRAMEWORK_ROOT"
output=$(bash "$HEALTH_SCRIPT" F-0001 2>&1) && exit_code=0 || exit_code=$?
if [[ $exit_code -eq 0 ]] && echo "$output" | grep -q "Found in FEATURES.md"; then
    pass
else
    fail "expected exit 0 and feature found (got exit $exit_code)"
fi

test_case "check-spec-health.sh F-0001 shows status"
if echo "$output" | grep -qi "status.*shipped"; then
    pass
else
    fail "expected status output"
fi

test_case "check-spec-health.sh F-0001 finds acceptance file"
if echo "$output" | grep -q "Acceptance file exists"; then
    pass
else
    fail "expected 'Acceptance file exists'"
fi

test_case "check-spec-health.sh F-9999 (non-existent feature)"
output=$(bash "$HEALTH_SCRIPT" F-9999 2>&1) && exit_code=0 || exit_code=$?
if [[ $exit_code -ne 0 ]] && echo "$output" | grep -q "Not found"; then
    pass
else
    fail "expected error for non-existent feature"
fi

test_case "check-spec-health.sh --all runs without fatal error"
output=$(bash "$HEALTH_SCRIPT" --all 2>&1) && exit_code=0 || exit_code=$?
if echo "$output" | grep -q "Checked:"; then
    pass
else
    fail "expected 'Checked:' summary line"
fi

test_case "check-spec-health.sh --all checks multiple features"
feature_count=$(echo "$output" | grep "Checked:" | grep -oE "[0-9]+" | head -1)
if [[ -n "$feature_count" && "$feature_count" -gt 50 ]]; then
    pass
else
    fail "expected >50 features checked, got ${feature_count:-0}"
fi

#=============================================================================
# ag spec command tests
#=============================================================================

echo ""
echo "=== ag spec command ==="
echo ""

AG_SCRIPT="$FRAMEWORK_ROOT/.agentic/lib/tools/ag.sh"
cd "$FRAMEWORK_ROOT"

test_case "ag spec (no args) prints checklist"
output=$(bash "$AG_SCRIPT" spec 2>&1) && exit_code=0 || exit_code=$?
if echo "$output" | grep -qi "Spec-Writing Checklist\|SPEC-WRITING"; then
    pass
else
    fail "expected checklist content"
fi

test_case "ag spec mentions workflow file"
if echo "$output" | grep -q "spec_writing.md"; then
    pass
else
    fail "expected reference to spec_writing.md"
fi

test_case "ag spec F-0001 runs health check"
output=$(bash "$AG_SCRIPT" spec F-0001 2>&1) && exit_code=0 || exit_code=$?
if echo "$output" | grep -q "Spec Health Check.*F-0001\|Found in FEATURES.md"; then
    pass
else
    fail "expected health check output for F-0001"
fi

test_case "ag spec --check runs health check on all"
output=$(bash "$AG_SCRIPT" spec --check 2>&1) && exit_code=0 || exit_code=$?
if echo "$output" | grep -q "Checked:"; then
    pass
else
    fail "expected all-features health check output"
fi

test_case "ag help includes spec command"
output=$(bash "$AG_SCRIPT" help 2>&1)
if echo "$output" | grep -q "spec.*Write/check spec\|spec.*feature"; then
    pass
else
    fail "expected spec in help output"
fi

#=============================================================================
# Summary
#=============================================================================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
TOTAL=$((PASSED + FAILED))
if [[ $FAILED -eq 0 ]]; then
    echo -e "${GREEN}ALL $TOTAL TESTS PASSED${NC}"
else
    echo -e "${RED}$FAILED/$TOTAL TESTS FAILED${NC}"
    exit 1
fi
