#!/usr/bin/env bash
# test_nfr_test_check.sh — Tests for nfr-test-check.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL="$SCRIPT_DIR/../.agentic/lib/tools/nfr-test-check.sh"

FAILURES=0
PASSES=0

pass() { PASSES=$((PASSES + 1)); echo "  ✓ $1"; }
fail() { FAILURES=$((FAILURES + 1)); echo "  ✗ $1"; }

# --- Setup: temp project ---
TEST_TMPDIR=$(mktemp -d)
trap 'rm -rf "$TEST_TMPDIR"' EXIT

setup_project() {
    rm -rf "$TEST_TMPDIR/.agentic"
    mkdir -p "$TEST_TMPDIR/.agentic/spec/acceptance"
    mkdir -p "$TEST_TMPDIR/.agentic/lib/tools"
    mkdir -p "$TEST_TMPDIR/.agentic/lib"

    # Copy paths.sh and required tools
    cp "$SCRIPT_DIR/../.agentic/lib/paths.sh" "$TEST_TMPDIR/.agentic/lib/paths.sh"
    cp "$SCRIPT_DIR/../.agentic/lib/tools/nfr-applicable.sh" "$TEST_TMPDIR/.agentic/lib/tools/nfr-applicable.sh"
    cp "$TOOL" "$TEST_TMPDIR/.agentic/lib/tools/nfr-test-check.sh"

    # Create FEATURES.md with a test feature
    cat > "$TEST_TMPDIR/.agentic/spec/FEATURES.md" <<'FEAT'
## F-001: Test Feature
**Status**: shipped
**Description**: A test feature for NFR checking
FEAT
}

echo "=== nfr-test-check.sh tests ==="
echo ""

# --- Test 1: No NFR.md → exit 0 ---
echo "Test: No NFR.md"
setup_project
output=$(cd "$TEST_TMPDIR" && bash .agentic/lib/tools/nfr-test-check.sh F-001 2>&1)
rc=$?
if [[ $rc -eq 0 ]]; then
    pass "No NFR.md exits 0"
else
    fail "No NFR.md should exit 0 (got $rc)"
fi

# --- Test 2: No acceptance file → exit 0 ---
echo ""
echo "Test: No acceptance file"
setup_project
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
NFR
output=$(cd "$TEST_TMPDIR" && bash .agentic/lib/tools/nfr-test-check.sh F-001 2>&1)
rc=$?
if [[ $rc -eq 0 ]]; then
    pass "No acceptance file exits 0"
else
    fail "No acceptance file should exit 0"
fi

# --- Test 3: NFR referenced in ACs → covered ---
echo ""
echo "Test: NFR referenced in ACs (covered)"
setup_project
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
NFR
cat > "$TEST_TMPDIR/.agentic/spec/acceptance/F-001.md" <<'AC'
## Acceptance Criteria
- [ ] **AC-001**: Feature works correctly
- [ ] **AC-010**: Files stay under 100 lines (NFR-0001)
## Out of Scope
AC
output=$(cd "$TEST_TMPDIR" && bash .agentic/lib/tools/nfr-test-check.sh F-001 2>&1)
rc=$?
if [[ $rc -eq 0 ]] && echo "$output" | grep -q "✓"; then
    pass "Referenced NFR shows as covered"
else
    fail "Referenced NFR should be covered (rc=$rc)"
fi

# --- Test 4: NFR not referenced → gap ---
echo ""
echo "Test: NFR not referenced (gap)"
setup_project
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
NFR
cat > "$TEST_TMPDIR/.agentic/spec/acceptance/F-001.md" <<'AC'
## Acceptance Criteria
- [ ] **AC-001**: Feature works correctly
## Out of Scope
AC
output=$(cd "$TEST_TMPDIR" && bash .agentic/lib/tools/nfr-test-check.sh F-001 2>&1)
rc=$?
if [[ $rc -eq 1 ]] && echo "$output" | grep -q "✗"; then
    pass "Missing NFR shows as gap (exit 1)"
else
    fail "Missing NFR should show gap with exit 1 (rc=$rc)"
fi

# --- Test 5: Legacy ## NFR Compliance format recognized ---
echo ""
echo "Test: Legacy NFR Compliance format"
setup_project
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
NFR
cat > "$TEST_TMPDIR/.agentic/spec/acceptance/F-001.md" <<'AC'
## Acceptance Criteria
- [ ] **AC-001**: Feature works correctly
## NFR Compliance
- NFR-0001: Files under 100 lines — verified
## Out of Scope
AC
output=$(cd "$TEST_TMPDIR" && bash .agentic/lib/tools/nfr-test-check.sh F-001 2>&1)
rc=$?
if [[ $rc -eq 0 ]] && echo "$output" | grep -q "✓"; then
    pass "Legacy NFR Compliance format recognized"
else
    fail "Legacy NFR Compliance format should be recognized (rc=$rc)"
fi

# --- Test 6: Summary line present ---
echo ""
echo "Test: Summary line"
setup_project
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
NFR
cat > "$TEST_TMPDIR/.agentic/spec/acceptance/F-001.md" <<'AC'
## Acceptance Criteria
- [ ] **AC-001**: Feature works (NFR-0001)
## Out of Scope
AC
output=$(cd "$TEST_TMPDIR" && bash .agentic/lib/tools/nfr-test-check.sh F-001 2>&1)
if echo "$output" | grep -q "Summary"; then
    pass "Summary line present"
else
    fail "Output should have summary line"
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
