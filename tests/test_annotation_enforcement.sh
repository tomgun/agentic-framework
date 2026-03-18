#!/usr/bin/env bash
# Tests for F-0229: Code Annotation Enforcement (Check 22)
#
# Tests the pre-commit annotation enforcement gate that checks
# newly-shipped features for @feature annotations.
#
# @feature F-0229

set -euo pipefail

PASS=0
FAIL=0
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# --- Helpers ---

setup_tmpdir() {
  TMPDIR=$(mktemp -d)
  mkdir -p "$TMPDIR/.agentic/spec/acceptance"
  mkdir -p "$TMPDIR/.agentic/lib/tools"
  mkdir -p "$TMPDIR/.agentic/lib/presets"
  mkdir -p "$TMPDIR/src"

  # Minimal git repo
  git -C "$TMPDIR" init -q 2>/dev/null
  git -C "$TMPDIR" config user.email "test@test.com"
  git -C "$TMPDIR" config user.name "Test"

  # Create minimal settings infrastructure
  cat > "$TMPDIR/.agentic/lib/settings.sh" << 'SETTINGS_EOF'
get_setting() {
  local key="$1" default="${2:-}"
  # Check for STACK.md override
  if [[ -f "$PROJECT_ROOT/STACK.md" ]]; then
    local val
    val=$(grep -E "^${key}:" "$PROJECT_ROOT/STACK.md" 2>/dev/null | head -1 | sed 's/^[^:]*: *//')
    if [[ -n "$val" ]]; then
      echo "$val"
      return
    fi
  fi
  echo "$default"
}
SETTINGS_EOF

  cat > "$TMPDIR/.agentic/lib/paths.sh" << 'PATHS_EOF'
# Stub paths
PATHS_EOF

  # Create initial FEATURES.md with already-shipped features (grandfathered)
  cat > "$TMPDIR/.agentic/spec/FEATURES.md" << 'FEATURES_EOF'
# Features

## F-0001: Already Shipped Feature

**Status**: shipped
**Category**: Core

## F-0002: Another Old Feature

**Status**: shipped
**Category**: Core
FEATURES_EOF

  git -C "$TMPDIR" add . && git -C "$TMPDIR" commit -q -m "init"
}

cleanup_tmpdir() {
  rm -rf "$TMPDIR"
}

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "  ✓ $desc"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $desc (expected='$expected', got='$actual')"
    FAIL=$((FAIL + 1))
  fi
}

assert_contains() {
  local desc="$1" haystack="$2" needle="$3"
  if echo "$haystack" | grep -qF "$needle"; then
    echo "  ✓ $desc"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $desc (output does not contain '$needle')"
    FAIL=$((FAIL + 1))
  fi
}

assert_not_contains() {
  local desc="$1" haystack="$2" needle="$3"
  if ! echo "$haystack" | grep -qF "$needle"; then
    echo "  ✓ $desc"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $desc (output unexpectedly contains '$needle')"
    FAIL=$((FAIL + 1))
  fi
}

# Simulate the Check 22 logic extracted from pre-commit-check.sh
# This lets us test the logic in isolation without running the full hook.
run_check22() {
  local project_dir="$1"
  local enforcement_mode="${2:-off}"
  local fast_mode="${3:-0}"

  cd "$project_dir"
  export PROJECT_ROOT="$project_dir"

  # Simulate fast mode skip
  if [[ "$fast_mode" -eq 1 ]]; then
    echo "SKIPPED_FAST"
    return 0
  fi

  # Simulate off mode skip
  if [[ "$enforcement_mode" == "off" ]]; then
    echo "SKIPPED_OFF"
    return 0
  fi

  # Parse staged diff for newly-shipped features
  local NEWLY_SHIPPED=()
  local STAGED_DIFF
  STAGED_DIFF=$(git diff --cached --unified=10 -- ".agentic/spec/FEATURES.md" 2>/dev/null || true)

  if [[ -n "$STAGED_DIFF" ]]; then
    local CURRENT_FEATURE=""
    while IFS= read -r line; do
      if [[ "$line" =~ ^[\ +]##\ (F-[0-9]{4,}): ]]; then
        CURRENT_FEATURE="${BASH_REMATCH[1]}"
      fi
      if [[ "$line" =~ ^\+\*\*Status\*\*:\ *shipped ]] && [[ -n "$CURRENT_FEATURE" ]]; then
        NEWLY_SHIPPED+=("$CURRENT_FEATURE")
      fi
    done <<< "$STAGED_DIFF"
  fi

  if [[ ${#NEWLY_SHIPPED[@]} -eq 0 ]]; then
    echo "NO_NEW_SHIPPED"
    return 0
  fi

  # Check for @feature annotations in src/ files
  local FAILURES=0
  for fid in "${NEWLY_SHIPPED[@]}"; do
    # Simple annotation check: grep for @feature F-XXXX in source files
    if grep -rq "@feature ${fid}" "$project_dir/src/" 2>/dev/null; then
      echo "ANNOTATED:$fid"
    else
      echo "MISSING:$fid"
      if [[ "$enforcement_mode" == "blocking" ]]; then
        FAILURES=$((FAILURES + 1))
      fi
    fi
  done

  return $FAILURES
}

# --- Tests ---

echo "=== F-0229: Annotation Enforcement Tests ==="
echo ""

# Test 1: Setting defaults in profiles.conf
echo "[1] Profile defaults..."
PROFILES="$PROJECT_ROOT/.agentic/lib/presets/profiles.conf"
DISC_VAL=$(grep "^discovery.annotation_enforcement=" "$PROFILES" | cut -d= -f2)
FORM_VAL=$(grep "^formal.annotation_enforcement=" "$PROFILES" | cut -d= -f2)
AUTO_VAL=$(grep "^autonomous_formal.annotation_enforcement=" "$PROFILES" | cut -d= -f2)
assert_eq "discovery defaults to off" "off" "$DISC_VAL"
assert_eq "formal defaults to advisory" "advisory" "$FORM_VAL"
assert_eq "autonomous_formal defaults to blocking" "blocking" "$AUTO_VAL"

# Test 2: Off mode skips entirely
echo ""
echo "[2] Off mode skips check..."
setup_tmpdir
OUTPUT=$(run_check22 "$TMPDIR" "off" 0)
assert_eq "off mode returns SKIPPED_OFF" "SKIPPED_OFF" "$OUTPUT"
cleanup_tmpdir

# Test 3: Fast mode skips entirely
echo ""
echo "[3] Fast mode skips check..."
setup_tmpdir
OUTPUT=$(run_check22 "$TMPDIR" "advisory" 1)
assert_eq "fast mode returns SKIPPED_FAST" "SKIPPED_FAST" "$OUTPUT"
cleanup_tmpdir

# Test 4: Grandfathering — already-shipped features not flagged
echo ""
echo "[4] Grandfathering (already-shipped features)..."
setup_tmpdir
# No staged changes to FEATURES.md — nothing should trigger
OUTPUT=$(run_check22 "$TMPDIR" "blocking" 0)
assert_eq "no staged changes = no newly shipped" "NO_NEW_SHIPPED" "$OUTPUT"
cleanup_tmpdir

# Test 5: Newly-shipped feature without annotations (advisory)
echo ""
echo "[5] Advisory mode — warning for unannotated feature..."
setup_tmpdir
# Add a new feature and set it to shipped
cat >> "$TMPDIR/.agentic/spec/FEATURES.md" << 'EOF'

## F-0099: New Feature Being Shipped

**Status**: shipped
**Category**: Quality
EOF
git -C "$TMPDIR" add ".agentic/spec/FEATURES.md"
OUTPUT=$(run_check22 "$TMPDIR" "advisory" 0)
EXIT_CODE=$?
assert_contains "detects missing annotation" "$OUTPUT" "MISSING:F-0099"
assert_eq "advisory mode exits 0" "0" "$EXIT_CODE"
cleanup_tmpdir

# Test 6: Newly-shipped feature without annotations (blocking)
echo ""
echo "[6] Blocking mode — failure for unannotated feature..."
setup_tmpdir
cat >> "$TMPDIR/.agentic/spec/FEATURES.md" << 'EOF'

## F-0099: New Feature Being Shipped

**Status**: shipped
**Category**: Quality
EOF
git -C "$TMPDIR" add ".agentic/spec/FEATURES.md"
EXIT_CODE=0
OUTPUT=$(run_check22 "$TMPDIR" "blocking" 0) || EXIT_CODE=$?
assert_contains "detects missing annotation" "$OUTPUT" "MISSING:F-0099"
assert_eq "blocking mode exits non-zero" "1" "$EXIT_CODE"
cleanup_tmpdir

# Test 7: Newly-shipped feature WITH annotations passes
echo ""
echo "[7] Feature with annotations passes..."
setup_tmpdir
# Add annotated source file
cat > "$TMPDIR/src/feature.py" << 'PYEOF'
# @feature F-0099
def my_feature():
    pass
PYEOF
# Add new feature and set to shipped
cat >> "$TMPDIR/.agentic/spec/FEATURES.md" << 'EOF'

## F-0099: New Feature Being Shipped

**Status**: shipped
**Category**: Quality
EOF
git -C "$TMPDIR" add .
OUTPUT=$(run_check22 "$TMPDIR" "blocking" 0)
EXIT_CODE=$?
assert_contains "detects annotation" "$OUTPUT" "ANNOTATED:F-0099"
assert_eq "annotated feature exits 0" "0" "$EXIT_CODE"
cleanup_tmpdir

# Test 8: Mixed — one annotated, one not
echo ""
echo "[8] Mixed: one annotated, one not..."
setup_tmpdir
cat > "$TMPDIR/src/feature_a.py" << 'PYEOF'
# @feature F-0098
def feature_a():
    pass
PYEOF
cat >> "$TMPDIR/.agentic/spec/FEATURES.md" << 'EOF'

## F-0098: Annotated Feature

**Status**: shipped
**Category**: Quality

## F-0099: Unannotated Feature

**Status**: shipped
**Category**: Quality
EOF
git -C "$TMPDIR" add .
EXIT_CODE=0
OUTPUT=$(run_check22 "$TMPDIR" "blocking" 0) || EXIT_CODE=$?
assert_contains "F-0098 annotated" "$OUTPUT" "ANNOTATED:F-0098"
assert_contains "F-0099 missing" "$OUTPUT" "MISSING:F-0099"
assert_eq "blocking mode exits 1 for missing" "1" "$EXIT_CODE"
cleanup_tmpdir

# Test 9: Non-shipped status change doesn't trigger
echo ""
echo "[9] Non-shipped status change doesn't trigger..."
setup_tmpdir
cat >> "$TMPDIR/.agentic/spec/FEATURES.md" << 'EOF'

## F-0099: Feature Set to In-Progress

**Status**: in_progress
**Category**: Quality
EOF
git -C "$TMPDIR" add ".agentic/spec/FEATURES.md"
OUTPUT=$(run_check22 "$TMPDIR" "blocking" 0)
assert_eq "in_progress doesn't trigger" "NO_NEW_SHIPPED" "$OUTPUT"
cleanup_tmpdir

# Test 10: Check 22 exists in pre-commit-check.sh header
echo ""
echo "[10] Check 22 registered in pre-commit-check.sh..."
HOOK_FILE="$PROJECT_ROOT/.agentic/lib/hooks/pre-commit-check.sh"
assert_contains "Check 22 in header" "$(head -35 "$HOOK_FILE")" "22."
assert_contains "Check 22 in fast skip list" "$(head -55 "$HOOK_FILE")" "22"
assert_contains "Check 22 implementation" "$(cat "$HOOK_FILE")" "[22] Checking annotation coverage"

# Test 11: Enforcement section in code_annotations.md
echo ""
echo "[11] Enforcement docs updated..."
ANNOTATIONS_DOC="$PROJECT_ROOT/.agentic/lib/workflows/code_annotations.md"
assert_contains "enforcement section exists" "$(cat "$ANNOTATIONS_DOC")" "Pre-commit enforcement (Check 22)"
assert_contains "off mode documented" "$(cat "$ANNOTATIONS_DOC")" "Check 22 skipped entirely"
assert_contains "advisory mode documented" "$(cat "$ANNOTATIONS_DOC")" "advisory"
assert_contains "blocking mode documented" "$(cat "$ANNOTATIONS_DOC")" "blocking"

# Test 12: JSON parsing path works with real coverage.py output format
echo ""
echo "[12] JSON parsing of coverage.py output..."
# Simulate the exact JSON structure coverage.py --json produces
SYNTHETIC_JSON='{"tool":"coverage","issues":[{"type":"missing_annotation","feature":"F-0042","status":"shipped","description":"F-0042 is shipped but has no @feature annotations"},{"type":"missing_annotation","feature":"F-0099","status":"shipped","description":"F-0099 is shipped but has no @feature annotations"},{"type":"orphaned_annotation","feature":"F-9999","file":"src/old.py","description":"orphaned"}],"summary":{"total_features":5,"missing_annotations":2}}'

# Run the exact Python one-liner used in Check 22
PARSED=$(echo "$SYNTHETIC_JSON" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for issue in data.get('issues', []):
    if issue['type'] == 'missing_annotation':
        print(issue['feature'])
" 2>/dev/null) || PARSED=""

assert_contains "parses F-0042 from JSON" "$PARSED" "F-0042"
assert_contains "parses F-0099 from JSON" "$PARSED" "F-0099"
assert_not_contains "ignores orphaned_annotation type" "$PARSED" "F-9999"

# Test 13: fallback when tool is missing (mirrors hook's actual pattern)
echo ""
echo "[13] Fallback produces valid JSON when tool is absent..."
# The hook uses: $(cmd || true) then checks if empty. Mirror that exactly.
FALLBACK_JSON=$(no_such_command_coverage_py --json 2>/dev/null || true)
if [[ -z "$FALLBACK_JSON" ]]; then
  FALLBACK_JSON='{"issues":[]}'
fi
FALLBACK_PARSED=$(echo "$FALLBACK_JSON" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(len(data.get('issues', [])))
" 2>/dev/null || true)
assert_eq "fallback produces parseable JSON with 0 issues" "0" "$FALLBACK_PARSED"

# Test 14: Exit-code preservation — real output kept when command exits 1
echo ""
echo "[14] Exit-code handling: || true inside subshell preserves stdout..."
# coverage.py outputs valid JSON and exits 1. The correct pattern must keep that output.
# CORRECT: $(cmd || true) — || true inside subshell suppresses exit, stdout preserved
CORRECT_VAL=$(bash -c 'echo "{\"ok\":true}"; exit 1' 2>/dev/null || true)
assert_eq "correct pattern: preserves real output" '{"ok":true}' "$CORRECT_VAL"

# WRONG pattern 1: $(cmd || echo fallback) — concatenates both outputs
WRONG1_VAL=$(bash -c 'echo "{\"ok\":true}"; exit 1' 2>/dev/null || echo '{"ok":false}')
WRONG1_LINES=$(echo "$WRONG1_VAL" | wc -l | tr -d ' ')
assert_eq "wrong pattern 1: concatenated (2 lines)" "2" "$WRONG1_LINES"

# WRONG pattern 2: $(cmd) || VAR=fallback — discards real output
WRONG2_VAL=$(bash -c 'echo "{\"ok\":true}"; exit 1' 2>/dev/null) || WRONG2_VAL='{"ok":false}'
assert_eq "wrong pattern 2: uses fallback, loses real output" '{"ok":false}' "$WRONG2_VAL"

# Test 15: Hook uses correct || true pattern
echo ""
echo "[15] Hook uses correct || true pattern..."
HOOK_FILE="$PROJECT_ROOT/.agentic/lib/hooks/pre-commit-check.sh"
HOOK_CONTENT=$(cat "$HOOK_FILE")
# Should have: $(python3 ... --json 2>/dev/null || true)
assert_contains "correct coverage capture" "$HOOK_CONTENT" 'coverage.py --json 2>/dev/null || true)'
# Should NOT have the two wrong patterns
assert_not_contains "no concatenating fallback" "$HOOK_CONTENT" "coverage.py --json 2>/dev/null || echo"
assert_not_contains "no discarding fallback" "$HOOK_CONTENT" "coverage.py --json 2>/dev/null) || COVERAGE_JSON="

# --- Summary ---
echo ""
echo "═══════════════════════════════════════"
TOTAL=$((PASS + FAIL))
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
echo "═══════════════════════════════════════"

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
exit 0
