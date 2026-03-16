#!/usr/bin/env bash
# test_nfr_propagate.sh — Tests for nfr-propagate.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL="$SCRIPT_DIR/../.agentic/lib/tools/nfr-propagate.sh"

FAILURES=0
PASSES=0

pass() { PASSES=$((PASSES + 1)); echo "  ✓ $1"; }
fail() { FAILURES=$((FAILURES + 1)); echo "  ✗ $1"; }

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

setup_project() {
    rm -rf "$TMPDIR/.agentic"
    mkdir -p "$TMPDIR/.agentic/spec/acceptance"
    mkdir -p "$TMPDIR/.agentic/lib/tools"
    mkdir -p "$TMPDIR/.agentic/lib"
    cp "$SCRIPT_DIR/../.agentic/lib/paths.sh" "$TMPDIR/.agentic/lib/paths.sh"
    cp "$SCRIPT_DIR/../.agentic/lib/tools/nfr-applicable.sh" "$TMPDIR/.agentic/lib/tools/nfr-applicable.sh"
    cp "$TOOL" "$TMPDIR/.agentic/lib/tools/nfr-propagate.sh"

    cat > "$TMPDIR/.agentic/spec/FEATURES.md" <<'FEAT'
## F-0001: Test Feature
**Status**: shipped
**Description**: A test feature for propagation testing
FEAT

    cat > "$TMPDIR/.agentic/spec/NFR.md" <<'NFR'
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
}

echo "=== nfr-propagate.sh tests ==="
echo ""

# --- Test 1: derive produces ### NFR Constraints section ---
echo "Test: derive output format"
setup_project
output=$(cd "$TMPDIR" && bash .agentic/lib/tools/nfr-propagate.sh derive F-0001 2>&1)
if echo "$output" | grep -q "### NFR Constraints"; then
    pass "Derive produces ### NFR Constraints header"
else
    fail "Derive should produce ### NFR Constraints header"
fi
if echo "$output" | grep -q "NFR-0001"; then
    pass "Derive includes applicable NFR ID"
else
    fail "Derive should include NFR-0001"
fi

# --- Test 2: derive with no applicable NFRs ---
echo ""
echo "Test: derive with no applicable NFRs"
setup_project
# Make NFR scoped to something that doesn't match
sed -i 's/all features (global)/component:audio/' "$TMPDIR/.agentic/spec/NFR.md" 2>/dev/null || \
    sed -i '' 's/all features (global)/component:audio/' "$TMPDIR/.agentic/spec/NFR.md"
output=$(cd "$TMPDIR" && bash .agentic/lib/tools/nfr-propagate.sh derive F-0001 2>&1)
if echo "$output" | grep -q "none applicable"; then
    pass "Derive shows none applicable when no match"
else
    fail "Derive should show none applicable"
fi

# --- Test 3: check detects staleness ---
echo ""
echo "Test: check detects staleness"
setup_project
cat > "$TMPDIR/.agentic/spec/acceptance/F-0001.md" <<'AC'
## Acceptance Criteria
- [ ] **AC-010**: Files under 100 lines (NFR-0001)
## Out of Scope
AC
# Make NFR.md newer than AC file
sleep 1
echo "# updated" >> "$TMPDIR/.agentic/spec/NFR.md"
output=$(cd "$TMPDIR" && bash .agentic/lib/tools/nfr-propagate.sh check --all 2>&1)
rc=$?
if [[ $rc -eq 1 ]] && echo "$output" | grep -q "stale\|newer"; then
    pass "Check detects staleness (exit 1)"
else
    fail "Check should detect staleness when NFR.md is newer (rc=$rc)"
fi

# --- Test 4: sync detects missing NFR ---
echo ""
echo "Test: sync detects missing NFR"
setup_project
cat > "$TMPDIR/.agentic/spec/acceptance/F-0001.md" <<'AC'
## Acceptance Criteria
- [ ] **AC-001**: Feature works correctly
## Out of Scope
AC
output=$(cd "$TMPDIR" && bash .agentic/lib/tools/nfr-propagate.sh sync F-0001 2>&1)
rc=$?
if [[ $rc -eq 1 ]] && echo "$output" | grep -q "MISSING"; then
    pass "Sync detects missing NFR (exit 1)"
else
    fail "Sync should detect missing NFR-0001 (rc=$rc)"
fi

# --- Test 5: sync detects legacy format ---
echo ""
echo "Test: sync detects legacy format"
setup_project
cat > "$TMPDIR/.agentic/spec/acceptance/F-0001.md" <<'AC'
## Acceptance Criteria
- [ ] **AC-001**: Feature works
## NFR Compliance
- NFR-0001: Files under 100 lines
## Out of Scope
AC
output=$(cd "$TMPDIR" && bash .agentic/lib/tools/nfr-propagate.sh sync F-0001 2>&1)
if echo "$output" | grep -q "LEGACY\|nfr-migrate"; then
    pass "Sync detects legacy format and suggests migration"
else
    fail "Sync should detect legacy NFR Compliance format"
fi

# --- Test 6: sync reports clean when in sync ---
echo ""
echo "Test: sync reports clean"
setup_project
cat > "$TMPDIR/.agentic/spec/acceptance/F-0001.md" <<'AC'
## Acceptance Criteria
- [ ] **AC-001**: Feature works
### NFR Constraints (P1 — required)
- [ ] **AC-010**: Files under 100 lines (NFR-0001)
## Out of Scope
AC
output=$(cd "$TMPDIR" && bash .agentic/lib/tools/nfr-propagate.sh sync F-0001 2>&1)
rc=$?
if [[ $rc -eq 0 ]] && echo "$output" | grep -q "in sync"; then
    pass "Sync reports clean when in sync"
else
    fail "Sync should report clean (rc=$rc)"
fi

# --- Test 7: help flag ---
echo ""
echo "Test: help flag"
output=$(cd "$TMPDIR" && bash .agentic/lib/tools/nfr-propagate.sh --help 2>&1)
rc=$?
if [[ $rc -eq 0 ]] && echo "$output" | grep -q "derive\|check\|sync"; then
    pass "--help shows all modes"
else
    fail "--help should show derive, check, sync"
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
