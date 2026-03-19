#!/usr/bin/env bash
# test_nfr_write_batch.sh — Tests for nfr-write-batch.sh
#
# Verifies: stdin parsing, NFR ID sequencing, field mapping,
# enforced field parsing, merge with existing NFRs, empty input.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL="$SCRIPT_DIR/../.agentic/lib/tools/nfr-write-batch.sh"

FAILURES=0
PASSES=0

pass() { PASSES=$((PASSES + 1)); echo "  ✓ $1"; }
fail() { FAILURES=$((FAILURES + 1)); echo "  ✗ $1"; }

# --- Setup: temp project ---
TEST_TMPDIR=$(mktemp -d)
trap 'rm -rf "$TEST_TMPDIR"' EXIT

setup_project() {
    rm -rf "$TEST_TMPDIR/.agentic" "$TEST_TMPDIR/.git"
    mkdir -p "$TEST_TMPDIR/.agentic/spec"
    git -C "$TEST_TMPDIR" init -q 2>/dev/null
    cat > "$TEST_TMPDIR/STACK.md" <<STACKEOF
## Stack
- Primary platform: web
STACKEOF
}

# Helper: run batch writer with ROOT_DIR + NFR_FILE overrides so paths.sh resolves to tmpdir
run_batch() {
    _AGENTIC_PATHS_LOADED="" ROOT_DIR="$TEST_TMPDIR" NFR_FILE="$TEST_TMPDIR/.agentic/spec/NFR.md" bash "$TOOL" 2>&1
}

echo "=== nfr-write-batch.sh tests ==="
echo ""

# --- Test 1: Empty stdin exits with error ---
echo "Test: Empty stdin"
setup_project
output=$(echo "" | run_batch)
rc=$?
if [[ $rc -ne 0 ]]; then
    pass "Empty stdin exits with error (rc=$rc)"
else
    fail "Empty stdin should exit with error"
fi

# --- Test 2: Single entry creates NFR-0001 ---
echo ""
echo "Test: Single entry"
setup_project
echo "W-01|performance|LCP under 2.5s|Lighthouse|Tests|P1|Web App" | run_batch
if grep -q "## NFR-0001: LCP under 2.5s" "$TEST_TMPDIR/.agentic/spec/NFR.md"; then
    pass "Single entry creates NFR-0001"
else
    fail "Single entry should create NFR-0001"
fi

# --- Test 3: Multiple entries get sequential IDs ---
echo ""
echo "Test: Sequential IDs"
setup_project
printf 'W-01|performance|LCP under 2.5s|Lighthouse|Tests|P1|Web App\nW-02|performance|Bundle under 200KB|Build output|CI|P1|Web App\nU-01|reliability|Zero crashes in prod|Error rate|Tests + monitoring|P1|Universal\n' | run_batch >/dev/null
if grep -q "## NFR-0001:" "$TEST_TMPDIR/.agentic/spec/NFR.md" && \
   grep -q "## NFR-0002:" "$TEST_TMPDIR/.agentic/spec/NFR.md" && \
   grep -q "## NFR-0003:" "$TEST_TMPDIR/.agentic/spec/NFR.md"; then
    pass "Multiple entries get NFR-0001, NFR-0002, NFR-0003"
else
    fail "Should create sequential IDs (NFR-0001 through NFR-0003)"
fi

# --- Test 4: Merge with existing NFRs (starts after max ID) ---
echo ""
echo "Test: Merge with existing NFRs"
setup_project
cat > "$TEST_TMPDIR/.agentic/spec/NFR.md" <<'NFREOF'
# NFR (Non-Functional Requirements)

## NFR-0003: Existing requirement
- Category: reliability
- Statement: Existing requirement
NFREOF
echo "W-01|performance|LCP under 2.5s|Lighthouse|Tests|P1|Web App" | run_batch >/dev/null
if grep -q "## NFR-0004: LCP under 2.5s" "$TEST_TMPDIR/.agentic/spec/NFR.md"; then
    pass "New entry starts at NFR-0004 (after existing NFR-0003)"
else
    fail "Should start at NFR-0004 when NFR-0003 exists"
fi
# Verify existing content preserved
if grep -q "## NFR-0003: Existing requirement" "$TEST_TMPDIR/.agentic/spec/NFR.md"; then
    pass "Existing NFR-0003 preserved (merge, not overwrite)"
else
    fail "Existing NFR-0003 should be preserved"
fi

# --- Test 5: Field mapping — category, statement, measure ---
echo ""
echo "Test: Field mapping"
setup_project
echo "A-01|latency|Response time under 200ms|p99 latency|Tests + code review|P1|API / Backend" | run_batch >/dev/null
nfr_content=$(cat "$TEST_TMPDIR/.agentic/spec/NFR.md")
if echo "$nfr_content" | grep -q "Category: latency" && \
   echo "$nfr_content" | grep -q "Statement: Response time under 200ms" && \
   echo "$nfr_content" | grep -q "How to measure: p99 latency" && \
   echo "$nfr_content" | grep -q "Applies to: API / Backend projects"; then
    pass "Category, statement, measure, applies-to fields mapped correctly"
else
    fail "Field mapping incorrect"
fi

# --- Test 6: Enforced field parsing — Tests yes, CI none ---
echo ""
echo "Test: Enforced field parsing (Tests only)"
setup_project
echo "W-04|security|No XSS|OWASP|Tests + code review|P1|Web App" | run_batch >/dev/null
nfr_content=$(cat "$TEST_TMPDIR/.agentic/spec/NFR.md")
if echo "$nfr_content" | grep -q "Tests: yes" && echo "$nfr_content" | grep -q "CI: none"; then
    pass "Enforced 'Tests + code review' → Tests: yes, CI: none"
else
    fail "Enforced field parsing incorrect for 'Tests + code review'"
fi

# --- Test 7: Enforced field parsing — CI yes, Tests none ---
echo ""
echo "Test: Enforced field parsing (CI only)"
setup_project
echo "W-02|performance|Bundle size|Build output|CI|P1|Web App" | run_batch >/dev/null
nfr_content=$(cat "$TEST_TMPDIR/.agentic/spec/NFR.md")
if echo "$nfr_content" | grep -q "Tests: none" && echo "$nfr_content" | grep -q "CI: yes"; then
    pass "Enforced 'CI' → Tests: none, CI: yes"
else
    fail "Enforced field parsing incorrect for 'CI'"
fi

# --- Test 8: Enforced field parsing — both Tests and CI ---
echo ""
echo "Test: Enforced field parsing (both)"
setup_project
echo "U-01|reliability|Zero crashes|Error rate|Tests + CI monitoring|P1|Universal" | run_batch >/dev/null
nfr_content=$(cat "$TEST_TMPDIR/.agentic/spec/NFR.md")
if echo "$nfr_content" | grep -q "Tests: yes" && echo "$nfr_content" | grep -q "CI: yes"; then
    pass "Enforced 'Tests + CI monitoring' → Tests: yes, CI: yes"
else
    fail "Enforced field parsing incorrect for 'Tests + CI monitoring'"
fi

# --- Test 9: Catalog ID preserved in Notes ---
echo ""
echo "Test: Catalog ID in Notes"
setup_project
echo "W-01|performance|LCP under 2.5s|Lighthouse|Tests|P1|Web App" | run_batch >/dev/null
if grep -q "Notes: Auto-generated from NFR catalog (W-01, P1)" "$TEST_TMPDIR/.agentic/spec/NFR.md"; then
    pass "Catalog ID (W-01) and priority (P1) preserved in Notes"
else
    fail "Notes should contain catalog ID and priority"
fi

# --- Test 10: No Priority field in output (matches nfr-capture.sh format) ---
echo ""
echo "Test: No Priority field in output"
setup_project
echo "W-01|performance|LCP under 2.5s|Lighthouse|Tests|P1|Web App" | run_batch >/dev/null
if grep -q "^- Priority:" "$TEST_TMPDIR/.agentic/spec/NFR.md"; then
    fail "Output should NOT contain a Priority field (format mismatch with nfr-capture.sh)"
else
    pass "No Priority field in output (matches nfr-capture.sh format)"
fi

# --- Test 11: Case-insensitive enforced parsing ---
echo ""
echo "Test: Case-insensitive enforced parsing"
setup_project
echo "M-01|performance|Startup|Profiling|Manual testing|P1|Mobile" | run_batch >/dev/null
nfr_content=$(cat "$TEST_TMPDIR/.agentic/spec/NFR.md")
if echo "$nfr_content" | grep -q "Tests: yes"; then
    pass "Case-insensitive: 'Manual testing' matches 'test' → Tests: yes"
else
    fail "Should match 'testing' case-insensitively for Tests field"
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
