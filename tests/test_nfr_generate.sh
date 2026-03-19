#!/usr/bin/env bash
# test_nfr_generate.sh — Tests for nfr-generate.sh
#
# Verifies: project type detection, priority filtering, catalog parsing,
# component matching, output format.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL="$SCRIPT_DIR/../.agentic/lib/tools/nfr-generate.sh"

FAILURES=0
PASSES=0

pass() { PASSES=$((PASSES + 1)); echo "  ✓ $1"; }
fail() { FAILURES=$((FAILURES + 1)); echo "  ✗ $1"; }

# --- Setup: temp project with STACK.md ---
TEST_TMPDIR=$(mktemp -d)
trap 'rm -rf "$TEST_TMPDIR"' EXIT

setup_project() {
    local platform="$1"
    rm -rf "$TEST_TMPDIR/.agentic"
    mkdir -p "$TEST_TMPDIR/.agentic/spec"
    cat > "$TEST_TMPDIR/STACK.md" <<STACKEOF
## Stack
- Primary platform: $platform
STACKEOF
}

echo "=== nfr-generate.sh tests ==="
echo ""

# --- Test 1: Web project gets web + universal + framework entries ---
echo "Test: Web project type detection"
setup_project "web"
output=$(cd "$TEST_TMPDIR" && bash "$TOOL" --project-type web 2>&1)
if echo "$output" | grep -q "W-01"; then
    pass "Web project includes W-01 (LCP)"
else
    fail "Web project missing W-01 (LCP)"
fi
if echo "$output" | grep -q "U-01"; then
    pass "Web project includes U-01 (Universal)"
else
    fail "Web project missing U-01 (Universal)"
fi

# --- Test 2: API project type ---
echo ""
echo "Test: API project type"
output=$(cd "$TEST_TMPDIR" && bash "$TOOL" --project-type api 2>&1)
if echo "$output" | grep -q "A-01"; then
    pass "API project includes A-01 (response time)"
else
    fail "API project missing A-01"
fi

# --- Test 3: CLI project type ---
echo ""
echo "Test: CLI project type"
output=$(cd "$TEST_TMPDIR" && bash "$TOOL" --project-type cli 2>&1)
if echo "$output" | grep -q "C-01"; then
    pass "CLI project includes C-01 (startup time)"
else
    fail "CLI project missing C-01"
fi

# --- Test 4: Library/SDK project type (new) ---
echo ""
echo "Test: Library/SDK project type"
output=$(cd "$TEST_TMPDIR" && bash "$TOOL" --project-type library 2>&1)
if echo "$output" | grep -q "L-01"; then
    pass "Library project includes L-01 (backward compat)"
else
    fail "Library project missing L-01"
fi

# --- Test 5: Data Pipeline project type (new) ---
echo ""
echo "Test: Data Pipeline project type"
output=$(cd "$TEST_TMPDIR" && bash "$TOOL" --project-type data-pipeline 2>&1)
if echo "$output" | grep -q "P-01"; then
    pass "Pipeline project includes P-01 (zero data loss)"
else
    fail "Pipeline project missing P-01"
fi

# --- Test 6: P3 entries excluded by default ---
echo ""
echo "Test: P3 entries excluded by default"
output=$(cd "$TEST_TMPDIR" && bash "$TOOL" --project-type web 2>&1)
if echo "$output" | grep -q "F-01"; then
    fail "P3 entry F-01 should be excluded by default"
else
    pass "P3 entries correctly excluded"
fi

# --- Test 7: P3 entries included with --all ---
echo ""
echo "Test: P3 entries included with --all"
output=$(cd "$TEST_TMPDIR" && bash "$TOOL" --project-type web --all 2>&1)
if echo "$output" | grep -q "F-01"; then
    pass "P3 entry F-01 included with --all"
else
    fail "P3 entry F-01 missing with --all"
fi

# --- Test 8: Output has priority labels ---
echo ""
echo "Test: Output shows priority labels"
output=$(cd "$TEST_TMPDIR" && bash "$TOOL" --project-type web 2>&1)
if echo "$output" | grep -q "\[P1\]"; then
    pass "Output contains [P1] labels"
else
    fail "Output missing [P1] labels"
fi

# --- Test 9: Unknown project type shows warning ---
echo ""
echo "Test: Unknown project type"
output=$(cd "$TEST_TMPDIR" && bash "$TOOL" --project-type zzzunknown 2>&1)
if echo "$output" | grep -qi "unknown\|Universal"; then
    pass "Unknown type falls back gracefully"
else
    fail "Unknown type should show warning or fall back"
fi

# --- Test 10: Total count in output ---
echo ""
echo "Test: Total count shown"
output=$(cd "$TEST_TMPDIR" && bash "$TOOL" --project-type cli 2>&1)
if echo "$output" | grep -q "Total:"; then
    pass "Output shows total count"
else
    fail "Output missing total count"
fi

# --- Test 11: Help flag ---
echo ""
echo "Test: Help flag"
output=$(cd "$TEST_TMPDIR" && bash "$TOOL" --help 2>&1)
rc=$?
if [[ $rc -eq 0 ]] && echo "$output" | grep -q "project-type"; then
    pass "--help shows usage"
else
    fail "--help should show usage and exit 0"
fi

# --- Test 12: Mobile project type ---
echo ""
echo "Test: Mobile project type"
output=$(cd "$TEST_TMPDIR" && bash "$TOOL" --project-type mobile 2>&1)
if echo "$output" | grep -q "M-01"; then
    pass "Mobile project includes M-01 (startup time)"
else
    fail "Mobile project missing M-01"
fi

# --- Test 13: Components filter includes matching P2 entries ---
echo ""
echo "Test: Components filter"
setup_project "web"
output=$(cd "$TEST_TMPDIR" && bash "$TOOL" --project-type web --components "security" 2>&1)
if echo "$output" | grep -q "W-05\|CSRF"; then
    pass "Components filter includes security-related P2 entries"
else
    fail "Components filter should include security-related P2 entries (W-05)"
fi

# --- Test 14: Audio/DSP project type ---
echo ""
echo "Test: Audio/DSP project type"
output=$(cd "$TEST_TMPDIR" && bash "$TOOL" --project-type audio 2>&1)
if echo "$output" | grep -q "D-01"; then
    pass "Audio project includes D-01 (heap allocations)"
else
    fail "Audio project missing D-01"
fi

# --- Test 15: --limit caps output to N entries ---
echo ""
echo "Test: --limit caps output"
output=$(cd "$TEST_TMPDIR" && bash "$TOOL" --project-type web --limit 4 2>&1)
total=$(echo "$output" | grep -c '^\[P[123]\]')
if [[ $total -le 4 ]]; then
    pass "--limit 4 caps output to $total entries (≤4)"
else
    fail "--limit 4 should cap at 4 entries, got $total"
fi

# --- Test 16: --limit prioritizes type-specific over Universal ---
echo ""
echo "Test: --limit prioritizes type-specific entries"
output=$(cd "$TEST_TMPDIR" && bash "$TOOL" --project-type web --limit 4 2>&1)
if echo "$output" | grep -q "W-01"; then
    pass "--limit includes type-specific W-01 before Universal entries"
else
    fail "--limit should include type-specific W-01"
fi

# --- Test 17: --machine outputs pipe-delimited format ---
echo ""
echo "Test: --machine output format"
output=$(cd "$TEST_TMPDIR" && bash "$TOOL" --project-type cli --machine 2>&1)
if echo "$output" | head -1 | grep -qE '^[A-Z]-[0-9]+\|'; then
    pass "--machine outputs pipe-delimited lines"
else
    fail "--machine should output pipe-delimited lines"
fi
# Verify no header/footer
if echo "$output" | grep -q "NFR Recommendations\|Total:"; then
    fail "--machine should have no header/footer"
else
    pass "--machine has no header/footer"
fi

# --- Test 18: --machine line count matches entry count ---
echo ""
echo "Test: --machine line count consistency"
human_count=$(cd "$TEST_TMPDIR" && bash "$TOOL" --project-type cli 2>&1 | grep -c '^\[P[123]\]')
machine_count=$(cd "$TEST_TMPDIR" && bash "$TOOL" --project-type cli --machine 2>&1 | grep -cE '^[A-Z]-')
if [[ $human_count -eq $machine_count ]]; then
    pass "--machine line count ($machine_count) matches human entry count ($human_count)"
else
    fail "--machine count ($machine_count) should match human count ($human_count)"
fi

# --- Test 19: --limit preserves human-readable format ---
echo ""
echo "Test: --limit preserves human format"
output=$(cd "$TEST_TMPDIR" && bash "$TOOL" --project-type web --limit 2 2>&1)
if echo "$output" | grep -q "Total:"; then
    pass "--limit still shows Total in human mode"
else
    fail "--limit should preserve human-readable format with Total"
fi

# --- Test 20: --help shows --limit and --machine ---
echo ""
echo "Test: --help shows new flags"
output=$(cd "$TEST_TMPDIR" && bash "$TOOL" --help 2>&1)
if echo "$output" | grep -q "\-\-limit" && echo "$output" | grep -q "\-\-machine"; then
    pass "--help documents --limit and --machine"
else
    fail "--help should document --limit and --machine flags"
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
