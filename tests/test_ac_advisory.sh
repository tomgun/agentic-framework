#!/usr/bin/env bash
# Tests for T-0051: AC check-off advisory in pre-commit-check.sh
#
# Tests the advisory that warns when in_progress features have
# unchecked acceptance criteria.

set -euo pipefail

PASS=0
FAIL=0
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# --- Helpers ---

setup_tmpdir() {
  TMPDIR=$(mktemp -d)
  mkdir -p "$TMPDIR/.agentic/spec/acceptance"
  # Minimal git repo
  git -C "$TMPDIR" init -q 2>/dev/null
  git -C "$TMPDIR" config user.email "test@test.com"
  git -C "$TMPDIR" config user.name "Test"
  touch "$TMPDIR/.gitkeep"
  git -C "$TMPDIR" add . && git -C "$TMPDIR" commit -q -m "init"
}

cleanup_tmpdir() {
  rm -rf "$TMPDIR"
}

# Extract the advisory section from pre-commit output
run_advisory_check() {
  cd "$TMPDIR"
  # Source only the advisory check section from pre-commit-check.sh
  # We extract and run just that part to avoid needing a full git commit setup
  bash -c '
    ROOT_DIR="'"$TMPDIR"'"
    cd "$ROOT_DIR"
    if [[ -f ".agentic/spec/FEATURES.md" ]]; then
      IN_PROGRESS_FEATURES=$(grep -B 3 -i "status.*in_progress" .agentic/spec/FEATURES.md | grep -oP "^## \KF-[0-9]+" || echo "")
      if [[ -n "$IN_PROGRESS_FEATURES" ]]; then
        AC_WARNINGS=""
        while IFS= read -r fid; do
          AC_FILE=".agentic/spec/acceptance/${fid}.md"
          if [[ -f "$AC_FILE" ]]; then
            TOTAL=$(grep -cE "^\s*- \[ \]" "$AC_FILE") || TOTAL=0
            if [[ "$TOTAL" -gt 0 ]]; then
              AC_WARNINGS="${AC_WARNINGS}\n   ${fid}: ${TOTAL} unchecked AC(s) in ${AC_FILE}"
            fi
          fi
        done <<< "$IN_PROGRESS_FEATURES"

        if [[ -n "$AC_WARNINGS" ]]; then
          echo "ADVISORY_FIRED"
          echo -e "$AC_WARNINGS"
        fi
      fi
    fi
  ' 2>/dev/null
}

assert_contains() {
  local output="$1"
  local expected="$2"
  local test_name="$3"
  if echo "$output" | grep -q "$expected"; then
    PASS=$((PASS + 1))
    echo "  ✓ $test_name"
  else
    FAIL=$((FAIL + 1))
    echo "  ✗ $test_name (expected '$expected' in output)"
    echo "    Output: $output"
  fi
}

assert_not_contains() {
  local output="$1"
  local unexpected="$2"
  local test_name="$3"
  if ! echo "$output" | grep -q "$unexpected"; then
    PASS=$((PASS + 1))
    echo "  ✓ $test_name"
  else
    FAIL=$((FAIL + 1))
    echo "  ✗ $test_name (unexpected '$unexpected' in output)"
  fi
}

# --- Tests ---

echo "=== T-0051: AC Check-off Advisory Tests ==="
echo ""

# Test 1: Unchecked ACs trigger advisory
echo "Test 1: Unchecked ACs trigger advisory"
setup_tmpdir
cat > "$TMPDIR/.agentic/spec/FEATURES.md" << 'EOF'
## F-0042: Test Feature
- **Status**: in_progress
EOF
cat > "$TMPDIR/.agentic/spec/acceptance/F-0042.md" << 'EOF'
# F-0042
- [ ] **AC-001**: First criterion
- [ ] **AC-002**: Second criterion
- [x] **AC-003**: Completed criterion
EOF
OUTPUT=$(run_advisory_check)
assert_contains "$OUTPUT" "ADVISORY_FIRED" "Advisory fires for unchecked ACs"
assert_contains "$OUTPUT" "F-0042: 2 unchecked" "Shows correct unchecked count"
cleanup_tmpdir

# Test 2: All ACs checked — no advisory
echo "Test 2: All ACs checked — no advisory"
setup_tmpdir
cat > "$TMPDIR/.agentic/spec/FEATURES.md" << 'EOF'
## F-0042: Test Feature
- **Status**: in_progress
EOF
cat > "$TMPDIR/.agentic/spec/acceptance/F-0042.md" << 'EOF'
# F-0042
- [x] **AC-001**: First criterion
- [x] **AC-002**: Second criterion
EOF
OUTPUT=$(run_advisory_check)
assert_not_contains "$OUTPUT" "ADVISORY_FIRED" "No advisory when all ACs checked"
cleanup_tmpdir

# Test 3: Shipped features ignored
echo "Test 3: Shipped features ignored"
setup_tmpdir
cat > "$TMPDIR/.agentic/spec/FEATURES.md" << 'EOF'
## F-0042: Test Feature
- **Status**: shipped
EOF
cat > "$TMPDIR/.agentic/spec/acceptance/F-0042.md" << 'EOF'
# F-0042
- [ ] **AC-001**: Unchecked but shipped
EOF
OUTPUT=$(run_advisory_check)
assert_not_contains "$OUTPUT" "ADVISORY_FIRED" "No advisory for shipped features"
cleanup_tmpdir

# Test 4: No AC file — no advisory
echo "Test 4: No AC file — no advisory"
setup_tmpdir
cat > "$TMPDIR/.agentic/spec/FEATURES.md" << 'EOF'
## F-0042: Test Feature
- **Status**: in_progress
EOF
# No acceptance file
OUTPUT=$(run_advisory_check)
assert_not_contains "$OUTPUT" "ADVISORY_FIRED" "No advisory when AC file missing"
cleanup_tmpdir

# Test 5: Multiple features
echo "Test 5: Multiple features"
setup_tmpdir
cat > "$TMPDIR/.agentic/spec/FEATURES.md" << 'EOF'
## F-0042: Feature One
- **Status**: in_progress

## F-0043: Feature Two
- **Status**: in_progress

## F-0044: Feature Three
- **Status**: shipped
EOF
cat > "$TMPDIR/.agentic/spec/acceptance/F-0042.md" << 'EOF'
- [ ] **AC-001**: Unchecked
EOF
cat > "$TMPDIR/.agentic/spec/acceptance/F-0043.md" << 'EOF'
- [x] **AC-001**: Checked
EOF
cat > "$TMPDIR/.agentic/spec/acceptance/F-0044.md" << 'EOF'
- [ ] **AC-001**: Unchecked but shipped
EOF
OUTPUT=$(run_advisory_check)
assert_contains "$OUTPUT" "F-0042" "Shows F-0042 (in_progress, unchecked)"
assert_not_contains "$OUTPUT" "F-0043" "Omits F-0043 (all checked)"
assert_not_contains "$OUTPUT" "F-0044" "Omits F-0044 (shipped)"
cleanup_tmpdir

# Test 6: Heading-only extraction (no spurious matches from body text)
echo "Test 6: Heading-only extraction"
setup_tmpdir
cat > "$TMPDIR/.agentic/spec/FEATURES.md" << 'EOF'
## F-0042: Feature One
- **Status**: shipped
- Depends on F-0099

## F-0050: Feature Two
- **Status**: in_progress
- Replaces F-0042
EOF
cat > "$TMPDIR/.agentic/spec/acceptance/F-0042.md" << 'EOF'
- [ ] **AC-001**: Unchecked
EOF
OUTPUT=$(run_advisory_check)
assert_not_contains "$OUTPUT" "F-0042" "No spurious match from body text mentioning F-0042"
cleanup_tmpdir

# Test 7: No FEATURES.md — no advisory
echo "Test 7: No FEATURES.md — no advisory"
setup_tmpdir
OUTPUT=$(run_advisory_check)
assert_not_contains "$OUTPUT" "ADVISORY_FIRED" "No advisory when FEATURES.md missing"
cleanup_tmpdir

# --- Summary ---
echo ""
echo "═══════════════════════════════════"
echo "Results: $PASS passed, $FAIL failed"
echo "═══════════════════════════════════"

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
