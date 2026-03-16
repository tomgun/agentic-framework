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
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

setup_project() {
    local platform="$1"
    rm -rf "$TMPDIR/.agentic"
    mkdir -p "$TMPDIR/.agentic/spec"
    cat > "$TMPDIR/STACK.md" <<STACKEOF
## Stack
- Primary platform: $platform
STACKEOF
}

echo "=== nfr-generate.sh tests ==="
echo ""

# --- Test 1: Web project gets web + universal + framework entries ---
echo "Test: Web project type detection"
setup_project "web"
output=$(cd "$TMPDIR" && bash "$TOOL" --project-type web 2>&1)
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
output=$(cd "$TMPDIR" && bash "$TOOL" --project-type api 2>&1)
if echo "$output" | grep -q "A-01"; then
    pass "API project includes A-01 (response time)"
else
    fail "API project missing A-01"
fi

# --- Test 3: CLI project type ---
echo ""
echo "Test: CLI project type"
output=$(cd "$TMPDIR" && bash "$TOOL" --project-type cli 2>&1)
if echo "$output" | grep -q "C-01"; then
    pass "CLI project includes C-01 (startup time)"
else
    fail "CLI project missing C-01"
fi

# --- Test 4: Library/SDK project type (new) ---
echo ""
echo "Test: Library/SDK project type"
output=$(cd "$TMPDIR" && bash "$TOOL" --project-type library 2>&1)
if echo "$output" | grep -q "L-01"; then
    pass "Library project includes L-01 (backward compat)"
else
    fail "Library project missing L-01"
fi

# --- Test 5: Data Pipeline project type (new) ---
echo ""
echo "Test: Data Pipeline project type"
output=$(cd "$TMPDIR" && bash "$TOOL" --project-type data-pipeline 2>&1)
if echo "$output" | grep -q "P-01"; then
    pass "Pipeline project includes P-01 (zero data loss)"
else
    fail "Pipeline project missing P-01"
fi

# --- Test 6: P3 entries excluded by default ---
echo ""
echo "Test: P3 entries excluded by default"
output=$(cd "$TMPDIR" && bash "$TOOL" --project-type web 2>&1)
if echo "$output" | grep -q "F-01"; then
    fail "P3 entry F-01 should be excluded by default"
else
    pass "P3 entries correctly excluded"
fi

# --- Test 7: P3 entries included with --all ---
echo ""
echo "Test: P3 entries included with --all"
output=$(cd "$TMPDIR" && bash "$TOOL" --project-type web --all 2>&1)
if echo "$output" | grep -q "F-01"; then
    pass "P3 entry F-01 included with --all"
else
    fail "P3 entry F-01 missing with --all"
fi

# --- Test 8: Output has priority labels ---
echo ""
echo "Test: Output shows priority labels"
output=$(cd "$TMPDIR" && bash "$TOOL" --project-type web 2>&1)
if echo "$output" | grep -q "\[P1\]"; then
    pass "Output contains [P1] labels"
else
    fail "Output missing [P1] labels"
fi

# --- Test 9: Unknown project type shows warning ---
echo ""
echo "Test: Unknown project type"
output=$(cd "$TMPDIR" && bash "$TOOL" --project-type zzzunknown 2>&1)
if echo "$output" | grep -qi "unknown\|Universal"; then
    pass "Unknown type falls back gracefully"
else
    fail "Unknown type should show warning or fall back"
fi

# --- Test 10: Total count in output ---
echo ""
echo "Test: Total count shown"
output=$(cd "$TMPDIR" && bash "$TOOL" --project-type cli 2>&1)
if echo "$output" | grep -q "Total:"; then
    pass "Output shows total count"
else
    fail "Output missing total count"
fi

# --- Test 11: Help flag ---
echo ""
echo "Test: Help flag"
output=$(cd "$TMPDIR" && bash "$TOOL" --help 2>&1)
rc=$?
if [[ $rc -eq 0 ]] && echo "$output" | grep -q "project-type"; then
    pass "--help shows usage"
else
    fail "--help should show usage and exit 0"
fi

# --- Test 12: Mobile project type ---
echo ""
echo "Test: Mobile project type"
output=$(cd "$TMPDIR" && bash "$TOOL" --project-type mobile 2>&1)
if echo "$output" | grep -q "M-01"; then
    pass "Mobile project includes M-01 (startup time)"
else
    fail "Mobile project missing M-01"
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
