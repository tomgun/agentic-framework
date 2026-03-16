#!/usr/bin/env bash
# test_nfr_capture.sh — Tests for nfr-capture.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL="$SCRIPT_DIR/../.agentic/lib/tools/nfr-capture.sh"

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
    cp "$SCRIPT_DIR/../.agentic/lib/tools/nfr-propagate.sh" "$TEST_TMPDIR/.agentic/lib/tools/nfr-propagate.sh" 2>/dev/null || true
    cp "$SCRIPT_DIR/../.agentic/lib/tools/nfr-applicable.sh" "$TEST_TMPDIR/.agentic/lib/tools/nfr-applicable.sh" 2>/dev/null || true
    cp "$TOOL" "$TEST_TMPDIR/.agentic/lib/tools/nfr-capture.sh"
}

echo "=== nfr-capture.sh tests ==="
echo ""

# --- Test 1: No statement → exit 1 ---
echo "Test: No statement"
setup_project
output=$(cd "$TEST_TMPDIR" && bash .agentic/lib/tools/nfr-capture.sh 2>&1)
rc=$?
if [[ $rc -eq 1 ]]; then
    pass "No statement exits 1"
else
    fail "No statement should exit 1 (got $rc)"
fi

# --- Test 2: Captures NFR with correct ID ---
echo ""
echo "Test: Capture assigns NFR-0001 when no existing NFRs"
setup_project
output=$(cd "$TEST_TMPDIR" && bash .agentic/lib/tools/nfr-capture.sh "Responses must include request-id" 2>&1)
rc=$?
if [[ $rc -eq 0 ]] && echo "$output" | grep -q "NFR-0001"; then
    pass "First capture assigns NFR-0001"
else
    fail "First capture should assign NFR-0001 (rc=$rc)"
fi
if [[ -f "$TEST_TMPDIR/.agentic/spec/NFR.md" ]]; then
    pass "NFR.md created"
else
    fail "NFR.md should be created"
fi

# --- Test 3: Increments ID from existing NFRs ---
echo ""
echo "Test: Increments ID from existing"
setup_project
cat > "$TEST_TMPDIR/.agentic/spec/NFR.md" <<'NFR'
## NFR-0003: Existing constraint
- Category: performance
- Statement: Something
- Applies to: all
- How to measure: test
- Where enforced:
  - Tests: none
  - CI: none
- Current status: met
NFR
output=$(cd "$TEST_TMPDIR" && bash .agentic/lib/tools/nfr-capture.sh "New constraint" 2>&1)
if echo "$output" | grep -q "NFR-0004"; then
    pass "Increments to NFR-0004"
else
    fail "Should increment to NFR-0004 after NFR-0003"
fi

# --- Test 4: Statement written to NFR.md ---
echo ""
echo "Test: Statement appears in NFR.md"
setup_project
cd "$TEST_TMPDIR" && bash .agentic/lib/tools/nfr-capture.sh "API latency must be under 200ms" 2>/dev/null
if grep -q "API latency must be under 200ms" "$TEST_TMPDIR/.agentic/spec/NFR.md"; then
    pass "Statement written to NFR.md"
else
    fail "Statement should appear in NFR.md"
fi

# --- Test 5: Category and applies-to flags ---
echo ""
echo "Test: Category and applies-to flags"
setup_project
cd "$TEST_TMPDIR" && bash .agentic/lib/tools/nfr-capture.sh "Must encrypt data at rest" --category security --applies-to "all endpoints" 2>/dev/null
if grep -q "Category: security" "$TEST_TMPDIR/.agentic/spec/NFR.md"; then
    pass "--category flag sets category"
else
    fail "--category should set category field"
fi
if grep -q "Applies to: all endpoints" "$TEST_TMPDIR/.agentic/spec/NFR.md"; then
    pass "--applies-to flag sets scope"
else
    fail "--applies-to should set applies-to field"
fi

# --- Test 6: Shell metacharacters in statement are safe ---
echo ""
echo "Test: Shell metacharacters safe"
setup_project
cd "$TEST_TMPDIR" && bash .agentic/lib/tools/nfr-capture.sh 'Response must include `request-id` header and $cost field' 2>/dev/null
if grep -q 'request-id' "$TEST_TMPDIR/.agentic/spec/NFR.md" && grep -q '\$cost' "$TEST_TMPDIR/.agentic/spec/NFR.md"; then
    pass "Backticks and dollar signs preserved safely"
else
    fail "Shell metacharacters should be preserved literally"
fi

# --- Test 7: Help usage ---
echo ""
echo "Test: No-arg shows usage"
output=$(cd "$TEST_TMPDIR" && bash .agentic/lib/tools/nfr-capture.sh 2>&1)
if echo "$output" | grep -qi "usage"; then
    pass "No-arg shows usage"
else
    fail "No-arg should show usage"
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
