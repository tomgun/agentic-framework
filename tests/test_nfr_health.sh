#!/usr/bin/env bash
# test_nfr_health.sh — Tests for nfr-health.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL="$SCRIPT_DIR/../.agentic/lib/tools/nfr-health.sh"

FAILURES=0
PASSES=0

pass() { PASSES=$((PASSES + 1)); echo "  ✓ $1"; }
fail() { FAILURES=$((FAILURES + 1)); echo "  ✗ $1"; }

TEST_TMPDIR=$(mktemp -d)
trap 'rm -rf "$TEST_TMPDIR"' EXIT

setup_project() {
    rm -rf "$TEST_TMPDIR/.agentic"
    mkdir -p "$TEST_TMPDIR/.agentic/spec/acceptance"
    mkdir -p "$TEST_TMPDIR/.agentic/lib/tools"
    mkdir -p "$TEST_TMPDIR/.agentic/lib"
    cp "$SCRIPT_DIR/../.agentic/lib/paths.sh" "$TEST_TMPDIR/.agentic/lib/paths.sh"
    cp "$SCRIPT_DIR/../.agentic/lib/tools/nfr-coverage.sh" "$TEST_TMPDIR/.agentic/lib/tools/nfr-coverage.sh"
    cp "$TOOL" "$TEST_TMPDIR/.agentic/lib/tools/nfr-health.sh"

    cat > "$TEST_TMPDIR/.agentic/spec/FEATURES.md" <<'FEAT'
## F-0001: Test Feature
**Status**: shipped
FEAT

    cat > "$TEST_TMPDIR/.agentic/spec/NFR.md" <<'NFR'
## NFR-0001: Size limit
- Category: maintainability
- Statement: Files under 100 lines
- Applies to: all features (global)
- How to measure: wc -l
- Where enforced:
  - Tests: none
  - CI: none
- Current status: met

## NFR-0002: Performance
- Category: performance
- Statement: Response time under 200ms
- Applies to: all features (global)
- How to measure: load test
- Where enforced:
  - Tests: none
  - CI: none
- Current status: partial
NFR
}

echo "=== nfr-health.sh tests ==="
echo ""

# --- Test 1: Summary mode ---
echo "Test: Summary mode"
setup_project
output=$(cd "$TEST_TMPDIR" && bash .agentic/lib/tools/nfr-health.sh --summary 2>&1)
if echo "$output" | grep -q "2 defined"; then
    pass "Summary shows correct count"
else
    fail "Summary should show '2 defined' (got: $output)"
fi
if echo "$output" | grep -q "1 met"; then
    pass "Summary shows met count"
else
    fail "Summary should show '1 met'"
fi

# --- Test 2: JSON mode ---
echo ""
echo "Test: JSON mode"
setup_project
output=$(cd "$TEST_TMPDIR" && bash .agentic/lib/tools/nfr-health.sh --json 2>&1)
if echo "$output" | grep -q '"total":2'; then
    pass "JSON has correct total in summary"
else
    fail "JSON should have total:2 (got: $output)"
fi
if echo "$output" | grep -q '"met":1'; then
    pass "JSON has correct met count"
else
    fail "JSON should have met:1"
fi
if echo "$output" | grep -q '"nfrs":\[' && echo "$output" | grep -q '"id":"NFR-0001"'; then
    pass "JSON has per-NFR details array"
else
    fail "JSON should have per-NFR nfrs array with NFR-0001"
fi
if echo "$output" | grep -q '"status":"partial"'; then
    pass "JSON has per-NFR status"
else
    fail "JSON should show partial status for NFR-0002"
fi

# --- Test 3: No NFR.md ---
echo ""
echo "Test: No NFR.md"
setup_project
rm "$TEST_TMPDIR/.agentic/spec/NFR.md"
output=$(cd "$TEST_TMPDIR" && bash .agentic/lib/tools/nfr-health.sh --summary 2>&1)
if echo "$output" | grep -qi "no NFR"; then
    pass "No NFR.md handled gracefully"
else
    fail "Should handle missing NFR.md"
fi

# --- Test 4: Detail mode shows per-NFR info ---
echo ""
echo "Test: Detail mode"
setup_project
output=$(cd "$TEST_TMPDIR" && bash .agentic/lib/tools/nfr-health.sh 2>&1)
if echo "$output" | grep -q "NFR-0001" && echo "$output" | grep -q "NFR-0002"; then
    pass "Detail mode shows both NFRs"
else
    fail "Detail mode should show both NFRs"
fi
if echo "$output" | grep -q "Summary"; then
    pass "Detail mode has summary"
else
    fail "Detail mode should have summary"
fi

# --- Test 5: Help flag ---
echo ""
echo "Test: Help flag"
output=$(cd "$TEST_TMPDIR" && bash .agentic/lib/tools/nfr-health.sh --help 2>&1)
rc=$?
if [[ $rc -eq 0 ]] && echo "$output" | grep -q "summary\|json\|coverage"; then
    pass "--help shows modes"
else
    fail "--help should show modes"
fi

# --- Test 6: Partial/violated counted as issues ---
echo ""
echo "Test: Issues detected for non-met status"
setup_project
output=$(cd "$TEST_TMPDIR" && bash .agentic/lib/tools/nfr-health.sh 2>&1)
rc=$?
if [[ $rc -eq 1 ]]; then
    pass "Exit code 1 when partial/violated NFRs exist"
else
    fail "Should exit 1 with partial NFR (got rc=$rc)"
fi

# --- Summary ---
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Passed: $PASSES | Failed: $FAILURES"
if [[ $FAILURES -gt 0 ]]; then
    echo "FAILED"
    exit 1
else
    echo "ALL PASSED"
    exit 0
fi
