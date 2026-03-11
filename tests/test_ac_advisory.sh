#!/usr/bin/env bash
# Test: AC check-off advisory in pre-commit-check.sh (T-0051)
#
# Validates that pre-commit emits advisory warnings when in_progress
# features have unchecked acceptance criteria.

set -euo pipefail

PASS=0
FAIL=0
TOTAL=0

assert_contains() {
  local label="$1" output="$2" expected="$3"
  TOTAL=$((TOTAL + 1))
  if echo "$output" | grep -qF "$expected"; then
    echo "  ✓ $label"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $label"
    echo "    Expected to find: $expected"
    echo "    In output: $(echo "$output" | head -5)"
    FAIL=$((FAIL + 1))
  fi
}

assert_not_contains() {
  local label="$1" output="$2" unexpected="$3"
  TOTAL=$((TOTAL + 1))
  if echo "$output" | grep -qF "$unexpected"; then
    echo "  ✗ $label"
    echo "    Found unexpected: $unexpected"
    FAIL=$((FAIL + 1))
  else
    echo "  ✓ $label"
    PASS=$((PASS + 1))
  fi
}

TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

setup_project() {
  rm -rf "$TMPDIR"/.agentic
  mkdir -p "$TMPDIR/.agentic/spec/acceptance"
  mkdir -p "$TMPDIR/.agentic/lib"
}

# Extract just the AC advisory logic into a standalone test harness
run_ac_advisory() {
  local root_dir="$1"
  bash -c "
    ROOT_DIR='$root_dir'
    FEATURES_FILE=\"\$ROOT_DIR/.agentic/spec/FEATURES.md\"
    AC_DIR=\"\$ROOT_DIR/.agentic/spec/acceptance\"
    if [[ -f \"\$FEATURES_FILE\" && -d \"\$AC_DIR\" ]]; then
      IN_PROGRESS_IDS=\$(grep -B 3 '^\*\*Status\*\*: in_progress' \"\$FEATURES_FILE\" \\
        | grep -oP '^## \KF-[0-9]+' | sort -u 2>/dev/null || true)
      AC_WARNINGS=''
      for fid in \$IN_PROGRESS_IDS; do
        AC_FILE=\"\$AC_DIR/\$fid.md\"
        if [[ -f \"\$AC_FILE\" ]]; then
          TOTAL=\$(grep -cE '^\s*- \[[ x]\]' \"\$AC_FILE\" 2>/dev/null) || TOTAL=0
          UNCHECKED=\$(grep -cE '^\s*- \[ \]' \"\$AC_FILE\" 2>/dev/null) || UNCHECKED=0
          CHECKED=\$((TOTAL - UNCHECKED))
          if [[ \"\$UNCHECKED\" -gt 0 ]]; then
            AC_WARNINGS=\"\${AC_WARNINGS}\n   \$fid: \$CHECKED/\$TOTAL acceptance criteria checked off\"
          fi
        fi
      done
      if [[ -n \"\$AC_WARNINGS\" ]]; then
        echo ''
        echo -e \"⚠️  Advisory: In-progress features with unchecked acceptance criteria:\$AC_WARNINGS\"
        echo '   Consider checking off completed ACs in this commit'
      fi
    fi
  " 2>/dev/null
}

echo "=== T-0051: AC Check-Off Advisory Tests ==="
echo ""

# --- Test 1: Feature with unchecked ACs produces advisory ---
echo "Test 1: Unchecked ACs produce advisory"
setup_project
cat > "$TMPDIR/.agentic/spec/FEATURES.md" << 'EOF'
## F-0999: Test Feature

**Status**: in_progress
EOF
cat > "$TMPDIR/.agentic/spec/acceptance/F-0999.md" << 'EOF'
# F-0999
## Acceptance Criteria
- [ ] **AC-001**: First criterion
- [ ] **AC-002**: Second criterion
- [x] **AC-003**: Third criterion (done)
EOF
OUTPUT=$(run_ac_advisory "$TMPDIR")
assert_contains "Shows advisory warning" "$OUTPUT" "Advisory: In-progress features with unchecked acceptance criteria"
assert_contains "Shows feature ID and count" "$OUTPUT" "F-0999: 1/3 acceptance criteria checked off"

# --- Test 2: All ACs checked = no advisory ---
echo ""
echo "Test 2: All ACs checked = no advisory"
setup_project
cat > "$TMPDIR/.agentic/spec/FEATURES.md" << 'EOF'
## F-0999: Test Feature

**Status**: in_progress
EOF
cat > "$TMPDIR/.agentic/spec/acceptance/F-0999.md" << 'EOF'
# F-0999
- [x] **AC-001**: First criterion
- [x] **AC-002**: Second criterion
EOF
OUTPUT=$(run_ac_advisory "$TMPDIR")
assert_not_contains "No advisory when all checked" "$OUTPUT" "Advisory"

# --- Test 3: Shipped features are ignored ---
echo ""
echo "Test 3: Shipped features ignored"
setup_project
cat > "$TMPDIR/.agentic/spec/FEATURES.md" << 'EOF'
## F-0999: Test Feature

**Status**: shipped
EOF
cat > "$TMPDIR/.agentic/spec/acceptance/F-0999.md" << 'EOF'
# F-0999
- [ ] **AC-001**: Unchecked but shipped
EOF
OUTPUT=$(run_ac_advisory "$TMPDIR")
assert_not_contains "No advisory for shipped features" "$OUTPUT" "Advisory"

# --- Test 4: No AC file = no advisory ---
echo ""
echo "Test 4: In-progress feature without AC file = no advisory"
setup_project
cat > "$TMPDIR/.agentic/spec/FEATURES.md" << 'EOF'
## F-0999: Test Feature

**Status**: in_progress
EOF
OUTPUT=$(run_ac_advisory "$TMPDIR")
assert_not_contains "No advisory without AC file" "$OUTPUT" "Advisory"

# --- Test 5: Multiple features ---
echo ""
echo "Test 5: Multiple in-progress features"
setup_project
cat > "$TMPDIR/.agentic/spec/FEATURES.md" << 'EOF'
## F-0998: First Feature

**Status**: in_progress

## F-0999: Second Feature

**Status**: in_progress

## F-1000: Shipped Feature

**Status**: shipped
EOF
cat > "$TMPDIR/.agentic/spec/acceptance/F-0998.md" << 'EOF'
- [ ] **AC-001**: Unchecked
- [x] **AC-002**: Checked
EOF
cat > "$TMPDIR/.agentic/spec/acceptance/F-0999.md" << 'EOF'
- [ ] **AC-001**: Unchecked
- [ ] **AC-002**: Unchecked
- [ ] **AC-003**: Unchecked
EOF
OUTPUT=$(run_ac_advisory "$TMPDIR")
assert_contains "Shows F-0998" "$OUTPUT" "F-0998: 1/2 acceptance criteria checked off"
assert_contains "Shows F-0999" "$OUTPUT" "F-0999: 0/3 acceptance criteria checked off"
assert_not_contains "Does not show F-1000" "$OUTPUT" "F-1000"

# --- Test 6: Spurious feature ID in heading text (review finding #5) ---
echo ""
echo "Test 6: Only heading feature IDs extracted (not body references)"
setup_project
cat > "$TMPDIR/.agentic/spec/FEATURES.md" << 'EOF'
## F-0998: Feature (depends on F-0997)

**Status**: in_progress
EOF
cat > "$TMPDIR/.agentic/spec/acceptance/F-0997.md" << 'EOF'
- [ ] **AC-001**: This is F-0997 not F-0998
EOF
cat > "$TMPDIR/.agentic/spec/acceptance/F-0998.md" << 'EOF'
- [x] **AC-001**: All done
EOF
OUTPUT=$(run_ac_advisory "$TMPDIR")
assert_not_contains "F-0997 not spuriously extracted" "$OUTPUT" "F-0997"

# --- Summary ---
echo ""
echo "═══════════════════════════════════"
if [[ $FAIL -eq 0 ]]; then
  echo "✅ ALL $TOTAL TESTS PASSED"
else
  echo "❌ $FAIL/$TOTAL TESTS FAILED"
fi
echo "═══════════════════════════════════"
exit $FAIL
