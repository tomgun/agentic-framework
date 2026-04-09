#!/usr/bin/env bash
# test_intel_patterns.sh — Tests for F-041 Intelligence Engine Phase 1
#
# Tests:
#   1. ag intel patterns — lists all patterns from patterns.yaml
#   2. ag intel check — matches patterns by scope glob
#   3. ag intel learn — adds new pattern with auto-incremented ID
#   4. PreToolUse.sh — injects pattern warnings for Write/Edit
#   5. PreToolUse.sh — no warnings for non-matching paths
#   6. Scope matching — various glob patterns work correctly

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PASS=0
FAIL=0
TOTAL=0

pass() { echo "  ✅ $1"; PASS=$((PASS + 1)); TOTAL=$((TOTAL + 1)); }
fail() { echo "  ❌ $1: $2"; FAIL=$((FAIL + 1)); TOTAL=$((TOTAL + 1)); }

# Create a temp project with intel directory and patterns
create_project() {
    local dir
    dir=$(mktemp -d)
    mkdir -p "$dir/.agentic/intel" "$dir/.agentic/lib/tools/commands" "$dir/.agentic/lib/presets"
    mkdir -p "$dir/.agentic/lib/claude-hooks" "$dir/.agentic/journal" "$dir/.agentic/spec"

    # Copy required libraries
    cp "$REPO_ROOT/.agentic/lib/settings.sh" "$dir/.agentic/lib/"
    cp -r "$REPO_ROOT/.agentic/lib/presets" "$dir/.agentic/lib/" 2>/dev/null || true
    cp "$REPO_ROOT/.agentic/lib/paths.sh" "$dir/.agentic/lib/" 2>/dev/null || true
    cp "$REPO_ROOT/.agentic/lib/tools/commands/intel.sh" "$dir/.agentic/lib/tools/commands/"
    cp "$REPO_ROOT/.agentic/lib/claude-hooks/PreToolUse.sh" "$dir/.agentic/lib/claude-hooks/"

    # Minimal STACK.md
    cat > "$dir/STACK.md" << 'EOF'
# Stack

## Settings
- profile: discovery
- state_enforcement: off
- feature_tracking: no
EOF

    # Seed patterns
    cat > "$dir/.agentic/intel/patterns.yaml" << 'EOF'
version: 1
patterns:
  - id: P-0001
    text: "Hook stdout must be JSON only"
    reason: "Non-JSON breaks hook protocol"
    scope: "*.hook.sh"
    severity: error
    source: manual

  - id: P-0002
    text: "Use cross-platform sed patterns"
    reason: "BSD and GNU sed differ"
    scope: "*.sh"
    severity: warning
    source: L-0001

  - id: P-0003
    text: "Validate inputs at system boundaries"
    reason: "Internal code is trusted"
    scope: "*.py"
    severity: info
    source: manual
EOF

    echo "$dir"
}

cleanup() {
    [[ -n "${PROJECT_DIR:-}" ]] && rm -rf "$PROJECT_DIR"
}
trap cleanup EXIT

echo "=== F-041 Intelligence Engine: Phase 1 Tests ==="
echo ""

# --- Setup ---
PROJECT_DIR=$(create_project)

# --- Test 1: ag intel patterns lists all patterns ---
echo "Test 1: ag intel patterns lists all patterns"
OUTPUT=$(ROOT_DIR="$PROJECT_DIR" \
    _AGENTIC_SETTINGS_LOADED="" _AGENTIC_PATHS_LOADED="" \
    _SETTINGS_ROOT_DIR="$PROJECT_DIR" _SETTINGS_STACK_FILE="$PROJECT_DIR/STACK.md" \
    bash -c '
        source "'"$REPO_ROOT"'/.agentic/lib/paths.sh" 2>/dev/null || true
        source "'"$REPO_ROOT"'/.agentic/lib/settings.sh" 2>/dev/null || true
        RED="\033[0;31m" GREEN="\033[0;32m" YELLOW="\033[1;33m" BLUE="\033[0;34m" BOLD="\033[1m" DIM="\033[2m" NC="\033[0m"
        ROOT_DIR="'"$PROJECT_DIR"'"
        source "'"$PROJECT_DIR"'/.agentic/lib/tools/commands/intel.sh"
        _intel_patterns
    ' 2>&1)

if echo "$OUTPUT" | grep -q "P-0001" && echo "$OUTPUT" | grep -q "P-0002" && echo "$OUTPUT" | grep -q "P-0003"; then
    pass "lists all 3 patterns"
else
    fail "missing patterns" "$OUTPUT"
fi

if echo "$OUTPUT" | grep -q "3 pattern(s) shown"; then
    pass "shows correct count"
else
    fail "wrong count" "$OUTPUT"
fi

# --- Test 2: ag intel patterns --scope filters correctly ---
echo ""
echo "Test 2: ag intel patterns --scope filters by path"
OUTPUT=$(ROOT_DIR="$PROJECT_DIR" \
    _AGENTIC_SETTINGS_LOADED="" _AGENTIC_PATHS_LOADED="" \
    _SETTINGS_ROOT_DIR="$PROJECT_DIR" _SETTINGS_STACK_FILE="$PROJECT_DIR/STACK.md" \
    bash -c '
        source "'"$REPO_ROOT"'/.agentic/lib/paths.sh" 2>/dev/null || true
        source "'"$REPO_ROOT"'/.agentic/lib/settings.sh" 2>/dev/null || true
        RED="\033[0;31m" GREEN="\033[0;32m" YELLOW="\033[1;33m" BLUE="\033[0;34m" BOLD="\033[1m" DIM="\033[2m" NC="\033[0m"
        ROOT_DIR="'"$PROJECT_DIR"'"
        source "'"$PROJECT_DIR"'/.agentic/lib/tools/commands/intel.sh"
        _intel_patterns --scope "test.py"
    ' 2>&1)

if echo "$OUTPUT" | grep -q "P-0003" && ! echo "$OUTPUT" | grep -q "P-0001"; then
    pass "filters to *.py patterns only"
else
    fail "filter not working" "$OUTPUT"
fi

# --- Test 3: ag intel check matches patterns by scope ---
echo ""
echo "Test 3: ag intel check matches patterns by scope"
OUTPUT=$(ROOT_DIR="$PROJECT_DIR" \
    _AGENTIC_SETTINGS_LOADED="" _AGENTIC_PATHS_LOADED="" \
    _SETTINGS_ROOT_DIR="$PROJECT_DIR" _SETTINGS_STACK_FILE="$PROJECT_DIR/STACK.md" \
    bash -c '
        source "'"$REPO_ROOT"'/.agentic/lib/paths.sh" 2>/dev/null || true
        source "'"$REPO_ROOT"'/.agentic/lib/settings.sh" 2>/dev/null || true
        RED="\033[0;31m" GREEN="\033[0;32m" YELLOW="\033[1;33m" BLUE="\033[0;34m" BOLD="\033[1m" DIM="\033[2m" NC="\033[0m"
        ROOT_DIR="'"$PROJECT_DIR"'"
        source "'"$PROJECT_DIR"'/.agentic/lib/tools/commands/intel.sh"
        _intel_check "deploy.sh"
    ' 2>&1)

if echo "$OUTPUT" | grep -q "P-0002"; then
    pass "matches *.sh pattern"
else
    fail "no match for .sh file" "$OUTPUT"
fi

# Check that *.py pattern doesn't match .sh file
if ! echo "$OUTPUT" | grep -q "P-0003"; then
    pass "does not match *.py for .sh file"
else
    fail "false positive for .py pattern" "$OUTPUT"
fi

# --- Test 4: ag intel check — no matches returns clean exit ---
echo ""
echo "Test 4: ag intel check with no matching patterns"
OUTPUT=$(ROOT_DIR="$PROJECT_DIR" \
    _AGENTIC_SETTINGS_LOADED="" _AGENTIC_PATHS_LOADED="" \
    _SETTINGS_ROOT_DIR="$PROJECT_DIR" _SETTINGS_STACK_FILE="$PROJECT_DIR/STACK.md" \
    bash -c '
        source "'"$REPO_ROOT"'/.agentic/lib/paths.sh" 2>/dev/null || true
        source "'"$REPO_ROOT"'/.agentic/lib/settings.sh" 2>/dev/null || true
        RED="\033[0;31m" GREEN="\033[0;32m" YELLOW="\033[1;33m" BLUE="\033[0;34m" BOLD="\033[1m" DIM="\033[2m" NC="\033[0m"
        ROOT_DIR="'"$PROJECT_DIR"'"
        source "'"$PROJECT_DIR"'/.agentic/lib/tools/commands/intel.sh"
        _intel_check "image.png"
    ' 2>&1)
RC=$?

# Strip locale warnings from output
OUTPUT=$(echo "$OUTPUT" | grep -v "^bash: warning: setlocale" || true)
if [[ $RC -eq 0 ]] && [[ -z "$OUTPUT" ]]; then
    pass "no output and exit 0 for non-matching path"
else
    fail "unexpected output or exit code" "rc=$RC output=$OUTPUT"
fi

# --- Test 5: ag intel learn adds pattern with correct ID ---
echo ""
echo "Test 5: ag intel learn adds new pattern"
OUTPUT=$(ROOT_DIR="$PROJECT_DIR" \
    _AGENTIC_SETTINGS_LOADED="" _AGENTIC_PATHS_LOADED="" \
    _SETTINGS_ROOT_DIR="$PROJECT_DIR" _SETTINGS_STACK_FILE="$PROJECT_DIR/STACK.md" \
    bash -c '
        source "'"$REPO_ROOT"'/.agentic/lib/paths.sh" 2>/dev/null || true
        source "'"$REPO_ROOT"'/.agentic/lib/settings.sh" 2>/dev/null || true
        RED="\033[0;31m" GREEN="\033[0;32m" YELLOW="\033[1;33m" BLUE="\033[0;34m" BOLD="\033[1m" DIM="\033[2m" NC="\033[0m"
        ROOT_DIR="'"$PROJECT_DIR"'"
        source "'"$PROJECT_DIR"'/.agentic/lib/tools/commands/intel.sh"
        _intel_learn "Never use eval in shell scripts" --reason "Code injection risk" --scope "*.sh" --severity error
    ' 2>&1)

if echo "$OUTPUT" | grep -q "P-0004"; then
    pass "auto-incremented to P-0004"
else
    fail "wrong ID" "$OUTPUT"
fi

# Verify it was actually written to the file
if grep -q "P-0004" "$PROJECT_DIR/.agentic/intel/patterns.yaml"; then
    pass "pattern written to file"
else
    fail "pattern not in file" "$(cat "$PROJECT_DIR/.agentic/intel/patterns.yaml")"
fi

if grep -q "Never use eval" "$PROJECT_DIR/.agentic/intel/patterns.yaml"; then
    pass "pattern text persisted"
else
    fail "text not found" ""
fi

# --- Test 6: PreToolUse.sh pattern warnings for Write ---
echo ""
echo "Test 6: PreToolUse.sh injects pattern warnings for Write"

# We need to create a minimal gate.py stub since PreToolUse calls it
mkdir -p "$PROJECT_DIR/.agentic/lib"
cat > "$PROJECT_DIR/.agentic/lib/gate.py" << 'GATEOF'
import sys, json
# Stub gate: always allow
print(json.dumps({"decision": "allow"}))
sys.exit(0)
GATEOF

# Create __init__.py so gate is importable as module
touch "$PROJECT_DIR/.agentic/lib/__init__.py"

# Create fwlog.sh stub
cat > "$PROJECT_DIR/.agentic/lib/tools/fwlog.sh" << 'FWEOF'
flog() { :; }
FWEOF

HOOK_OUTPUT=$(echo '{"tool_name":"Write","tool_input":{"file_path":"deploy.sh","content":"echo hello"}}' | \
    CLAUDE_PROJECT_DIR="$PROJECT_DIR" \
    PYTHONPATH="$PROJECT_DIR/.agentic/lib" \
    bash "$PROJECT_DIR/.agentic/lib/claude-hooks/PreToolUse.sh" 2>&1) || true

if echo "$HOOK_OUTPUT" | grep -q "P-0002"; then
    pass "PreToolUse warns about *.sh pattern"
else
    fail "no pattern warning in hook output" "$HOOK_OUTPUT"
fi

if echo "$HOOK_OUTPUT" | grep -q "Pattern warnings"; then
    pass "shows 'Pattern warnings' header"
else
    fail "missing header" "$HOOK_OUTPUT"
fi

# --- Test 7: PreToolUse.sh no warnings for non-matching path ---
echo ""
echo "Test 7: PreToolUse.sh no pattern warnings for non-matching path"

HOOK_OUTPUT=$(echo '{"tool_name":"Write","tool_input":{"file_path":"image.png","content":"binary"}}' | \
    CLAUDE_PROJECT_DIR="$PROJECT_DIR" \
    PYTHONPATH="$PROJECT_DIR/.agentic/lib" \
    bash "$PROJECT_DIR/.agentic/lib/claude-hooks/PreToolUse.sh" 2>&1) || true

if ! echo "$HOOK_OUTPUT" | grep -q "Pattern warnings"; then
    pass "no pattern warnings for non-matching file"
else
    fail "unexpected warnings" "$HOOK_OUTPUT"
fi

# --- Test 8: PreToolUse.sh skips pattern check for Read tool ---
echo ""
echo "Test 8: PreToolUse.sh skips patterns for Read tool"

HOOK_OUTPUT=$(echo '{"tool_name":"Read","tool_input":{"file_path":"deploy.sh"}}' | \
    CLAUDE_PROJECT_DIR="$PROJECT_DIR" \
    PYTHONPATH="$PROJECT_DIR/.agentic/lib" \
    bash "$PROJECT_DIR/.agentic/lib/claude-hooks/PreToolUse.sh" 2>&1) || true

if ! echo "$HOOK_OUTPUT" | grep -q "Pattern warnings"; then
    pass "no pattern check for Read tool"
else
    fail "unexpected pattern check for Read" "$HOOK_OUTPUT"
fi

# --- Test 9: Severity icons display correctly ---
echo ""
echo "Test 9: Severity icons"
OUTPUT=$(ROOT_DIR="$PROJECT_DIR" \
    _AGENTIC_SETTINGS_LOADED="" _AGENTIC_PATHS_LOADED="" \
    _SETTINGS_ROOT_DIR="$PROJECT_DIR" _SETTINGS_STACK_FILE="$PROJECT_DIR/STACK.md" \
    bash -c '
        source "'"$REPO_ROOT"'/.agentic/lib/paths.sh" 2>/dev/null || true
        source "'"$REPO_ROOT"'/.agentic/lib/settings.sh" 2>/dev/null || true
        RED="\033[0;31m" GREEN="\033[0;32m" YELLOW="\033[1;33m" BLUE="\033[0;34m" BOLD="\033[1m" DIM="\033[2m" NC="\033[0m"
        ROOT_DIR="'"$PROJECT_DIR"'"
        source "'"$PROJECT_DIR"'/.agentic/lib/tools/commands/intel.sh"
        _intel_check "test.hook.sh"
    ' 2>&1)

# P-0001 (error, *.hook.sh) and P-0002 (warning, *.sh) should match
if echo "$OUTPUT" | grep -q "🚨.*P-0001"; then
    pass "error severity shows 🚨 icon"
else
    fail "wrong icon for error" "$OUTPUT"
fi

if echo "$OUTPUT" | grep -q "⚠️.*P-0002"; then
    pass "warning severity shows ⚠️ icon"
else
    fail "wrong icon for warning" "$OUTPUT"
fi

# --- Test 10: No patterns file = graceful handling ---
echo ""
echo "Test 10: Missing patterns file handled gracefully"
mv "$PROJECT_DIR/.agentic/intel/patterns.yaml" "$PROJECT_DIR/.agentic/intel/patterns.yaml.bak"

OUTPUT=$(ROOT_DIR="$PROJECT_DIR" \
    _AGENTIC_SETTINGS_LOADED="" _AGENTIC_PATHS_LOADED="" \
    _SETTINGS_ROOT_DIR="$PROJECT_DIR" _SETTINGS_STACK_FILE="$PROJECT_DIR/STACK.md" \
    bash -c '
        source "'"$REPO_ROOT"'/.agentic/lib/paths.sh" 2>/dev/null || true
        source "'"$REPO_ROOT"'/.agentic/lib/settings.sh" 2>/dev/null || true
        RED="\033[0;31m" GREEN="\033[0;32m" YELLOW="\033[1;33m" BLUE="\033[0;34m" BOLD="\033[1m" DIM="\033[2m" NC="\033[0m"
        ROOT_DIR="'"$PROJECT_DIR"'"
        source "'"$PROJECT_DIR"'/.agentic/lib/tools/commands/intel.sh"
        _intel_check "test.sh"
    ' 2>&1)
RC=$?

if [[ $RC -eq 0 ]]; then
    pass "exits 0 when no patterns file"
else
    fail "non-zero exit" "rc=$RC"
fi

mv "$PROJECT_DIR/.agentic/intel/patterns.yaml.bak" "$PROJECT_DIR/.agentic/intel/patterns.yaml"

# --- Test 11: ag intel check --json returns JSON array ---
echo ""
echo "Test 11: ag intel check --json"
OUTPUT=$(ROOT_DIR="$PROJECT_DIR" \
    _AGENTIC_SETTINGS_LOADED="" _AGENTIC_PATHS_LOADED="" \
    _SETTINGS_ROOT_DIR="$PROJECT_DIR" _SETTINGS_STACK_FILE="$PROJECT_DIR/STACK.md" \
    bash -c '
        source "'"$REPO_ROOT"'/.agentic/lib/paths.sh" 2>/dev/null || true
        source "'"$REPO_ROOT"'/.agentic/lib/settings.sh" 2>/dev/null || true
        RED="\033[0;31m" GREEN="\033[0;32m" YELLOW="\033[1;33m" BLUE="\033[0;34m" BOLD="\033[1m" DIM="\033[2m" NC="\033[0m"
        ROOT_DIR="'"$PROJECT_DIR"'"
        source "'"$PROJECT_DIR"'/.agentic/lib/tools/commands/intel.sh"
        _intel_check "deploy.sh" --json
    ' 2>&1)

if echo "$OUTPUT" | grep -q '"id":"P-0002"'; then
    pass "--json includes matching pattern"
else
    fail "--json missing match" "$OUTPUT"
fi

if echo "$OUTPUT" | grep -qE '^\['; then
    pass "--json output is array"
else
    fail "--json not array format" "$OUTPUT"
fi

# --json with no matches returns empty array
OUTPUT_EMPTY=$(ROOT_DIR="$PROJECT_DIR" \
    _AGENTIC_SETTINGS_LOADED="" _AGENTIC_PATHS_LOADED="" \
    _SETTINGS_ROOT_DIR="$PROJECT_DIR" _SETTINGS_STACK_FILE="$PROJECT_DIR/STACK.md" \
    bash -c '
        source "'"$REPO_ROOT"'/.agentic/lib/paths.sh" 2>/dev/null || true
        source "'"$REPO_ROOT"'/.agentic/lib/settings.sh" 2>/dev/null || true
        RED="\033[0;31m" GREEN="\033[0;32m" YELLOW="\033[1;33m" BLUE="\033[0;34m" BOLD="\033[1m" DIM="\033[2m" NC="\033[0m"
        ROOT_DIR="'"$PROJECT_DIR"'"
        source "'"$PROJECT_DIR"'/.agentic/lib/tools/commands/intel.sh"
        _intel_check "image.png" --json
    ' 2>&1)

OUTPUT_EMPTY=$(echo "$OUTPUT_EMPTY" | grep -v "^bash: warning: setlocale" || true)
if [[ "$OUTPUT_EMPTY" == "[]" ]]; then
    pass "--json returns [] for no matches"
else
    fail "--json empty not []" "$OUTPUT_EMPTY"
fi

# --- Test 12: ag intel remove removes a pattern ---
echo ""
echo "Test 12: ag intel remove"

# Add a pattern we'll remove
OUTPUT=$(ROOT_DIR="$PROJECT_DIR" \
    _AGENTIC_SETTINGS_LOADED="" _AGENTIC_PATHS_LOADED="" \
    _SETTINGS_ROOT_DIR="$PROJECT_DIR" _SETTINGS_STACK_FILE="$PROJECT_DIR/STACK.md" \
    bash -c '
        source "'"$REPO_ROOT"'/.agentic/lib/paths.sh" 2>/dev/null || true
        source "'"$REPO_ROOT"'/.agentic/lib/settings.sh" 2>/dev/null || true
        RED="\033[0;31m" GREEN="\033[0;32m" YELLOW="\033[1;33m" BLUE="\033[0;34m" BOLD="\033[1m" DIM="\033[2m" NC="\033[0m"
        ROOT_DIR="'"$PROJECT_DIR"'"
        source "'"$PROJECT_DIR"'/.agentic/lib/tools/commands/intel.sh"
        _intel_remove "P-0002"
    ' 2>&1)

if echo "$OUTPUT" | grep -q "Removed pattern P-0002"; then
    pass "remove reports success"
else
    fail "remove failed" "$OUTPUT"
fi

if ! grep -q "P-0002" "$PROJECT_DIR/.agentic/intel/patterns.yaml"; then
    pass "P-0002 no longer in file"
else
    fail "P-0002 still in file" ""
fi

# Verify P-0001 and P-0003 still exist
if grep -q "P-0001" "$PROJECT_DIR/.agentic/intel/patterns.yaml" && grep -q "P-0003" "$PROJECT_DIR/.agentic/intel/patterns.yaml"; then
    pass "other patterns preserved"
else
    fail "other patterns lost" ""
fi

# Try removing non-existent pattern
OUTPUT=$(ROOT_DIR="$PROJECT_DIR" \
    _AGENTIC_SETTINGS_LOADED="" _AGENTIC_PATHS_LOADED="" \
    _SETTINGS_ROOT_DIR="$PROJECT_DIR" _SETTINGS_STACK_FILE="$PROJECT_DIR/STACK.md" \
    bash -c '
        source "'"$REPO_ROOT"'/.agentic/lib/paths.sh" 2>/dev/null || true
        source "'"$REPO_ROOT"'/.agentic/lib/settings.sh" 2>/dev/null || true
        RED="\033[0;31m" GREEN="\033[0;32m" YELLOW="\033[1;33m" BLUE="\033[0;34m" BOLD="\033[1m" DIM="\033[2m" NC="\033[0m"
        ROOT_DIR="'"$PROJECT_DIR"'"
        source "'"$PROJECT_DIR"'/.agentic/lib/tools/commands/intel.sh"
        _intel_remove "P-9999"
    ' 2>&1)

if echo "$OUTPUT" | grep -q "not found"; then
    pass "remove non-existent pattern errors"
else
    fail "no error for non-existent" "$OUTPUT"
fi

# --- Test 13: ag intel learn validates severity ---
echo ""
echo "Test 13: severity validation"
OUTPUT=$(ROOT_DIR="$PROJECT_DIR" \
    _AGENTIC_SETTINGS_LOADED="" _AGENTIC_PATHS_LOADED="" \
    _SETTINGS_ROOT_DIR="$PROJECT_DIR" _SETTINGS_STACK_FILE="$PROJECT_DIR/STACK.md" \
    bash -c '
        source "'"$REPO_ROOT"'/.agentic/lib/paths.sh" 2>/dev/null || true
        source "'"$REPO_ROOT"'/.agentic/lib/settings.sh" 2>/dev/null || true
        RED="\033[0;31m" GREEN="\033[0;32m" YELLOW="\033[1;33m" BLUE="\033[0;34m" BOLD="\033[1m" DIM="\033[2m" NC="\033[0m"
        ROOT_DIR="'"$PROJECT_DIR"'"
        source "'"$PROJECT_DIR"'/.agentic/lib/tools/commands/intel.sh"
        _intel_learn "test" --reason "test" --scope "*.sh" --severity "critical"
    ' 2>&1)
RC=$?

if echo "$OUTPUT" | grep -q "invalid severity"; then
    pass "rejects invalid severity"
else
    fail "accepted invalid severity" "$OUTPUT"
fi

# Valid severity should work
OUTPUT=$(ROOT_DIR="$PROJECT_DIR" \
    _AGENTIC_SETTINGS_LOADED="" _AGENTIC_PATHS_LOADED="" \
    _SETTINGS_ROOT_DIR="$PROJECT_DIR" _SETTINGS_STACK_FILE="$PROJECT_DIR/STACK.md" \
    bash -c '
        source "'"$REPO_ROOT"'/.agentic/lib/paths.sh" 2>/dev/null || true
        source "'"$REPO_ROOT"'/.agentic/lib/settings.sh" 2>/dev/null || true
        RED="\033[0;31m" GREEN="\033[0;32m" YELLOW="\033[1;33m" BLUE="\033[0;34m" BOLD="\033[1m" DIM="\033[2m" NC="\033[0m"
        ROOT_DIR="'"$PROJECT_DIR"'"
        source "'"$PROJECT_DIR"'/.agentic/lib/tools/commands/intel.sh"
        _intel_learn "valid test" --reason "test" --scope "*.sh" --severity "error"
    ' 2>&1)

if echo "$OUTPUT" | grep -q "Added pattern"; then
    pass "accepts valid severity 'error'"
else
    fail "rejected valid severity" "$OUTPUT"
fi

# ===========================================================================
# Project Memory Tests
# ===========================================================================

# Helper to run intel commands in test project
run_intel() {
    ROOT_DIR="$PROJECT_DIR" \
    _AGENTIC_SETTINGS_LOADED="" _AGENTIC_PATHS_LOADED="" \
    _SETTINGS_ROOT_DIR="$PROJECT_DIR" _SETTINGS_STACK_FILE="$PROJECT_DIR/STACK.md" \
    bash -c '
        source "'"$REPO_ROOT"'/.agentic/lib/paths.sh" 2>/dev/null || true
        source "'"$REPO_ROOT"'/.agentic/lib/settings.sh" 2>/dev/null || true
        RED="\033[0;31m" GREEN="\033[0;32m" YELLOW="\033[1;33m" BLUE="\033[0;34m" BOLD="\033[1m" DIM="\033[2m" NC="\033[0m"
        ROOT_DIR="'"$PROJECT_DIR"'"
        source "'"$PROJECT_DIR"'/.agentic/lib/tools/commands/intel.sh"
        '"$1"'
    ' 2>&1
}

# --- Test 14: ag intel remember creates project memory entry ---
echo ""
echo "Test 14: ag intel remember"

# Create empty project memory
cat > "$PROJECT_DIR/.agentic/intel/project-memory.yaml" << 'EOF'
version: 1
entries: []
EOF

OUTPUT=$(run_intel '_intel_remember "Prefers small functions" --context "Corrected 60-line func"')

if echo "$OUTPUT" | grep -q "Remembered C-0001"; then
    pass "remember creates C-0001"
else
    fail "remember failed" "$OUTPUT"
fi

if grep -q "C-0001" "$PROJECT_DIR/.agentic/intel/project-memory.yaml" && \
   grep -q "preference" "$PROJECT_DIR/.agentic/intel/project-memory.yaml"; then
    pass "entry written with default type=preference"
else
    fail "entry not in file" ""
fi

# --- Test 15: ag intel remember with --type ---
echo ""
echo "Test 15: remember with --type learning"
OUTPUT=$(run_intel '_intel_remember "Auth uses JWT cookies" --type learning')

if echo "$OUTPUT" | grep -q "C-0002.*learning"; then
    pass "learning type accepted"
else
    fail "learning type failed" "$OUTPUT"
fi

# --- Test 16: ag intel remember validates type ---
echo ""
echo "Test 16: remember validates type"
OUTPUT=$(run_intel '_intel_remember "test" --type bogus')

if echo "$OUTPUT" | grep -q "invalid type"; then
    pass "rejects invalid type"
else
    fail "accepted invalid type" "$OUTPUT"
fi

# --- Test 17: ag intel memory lists entries ---
echo ""
echo "Test 17: project memory list"
OUTPUT=$(run_intel '_intel_memory')

if echo "$OUTPUT" | grep -q "C-0001" && echo "$OUTPUT" | grep -q "C-0002"; then
    pass "lists both entries"
else
    fail "missing entries" "$OUTPUT"
fi

if echo "$OUTPUT" | grep -q "2 entry"; then
    pass "correct count"
else
    fail "wrong count" "$OUTPUT"
fi

# --- Test 18: project memory --type filters ---
echo ""
echo "Test 18: project memory type filter"
OUTPUT=$(run_intel '_intel_memory --type learning')

if echo "$OUTPUT" | grep -q "C-0002" && ! echo "$OUTPUT" | grep -q "C-0001"; then
    pass "filters to learning only"
else
    fail "filter not working" "$OUTPUT"
fi

# --- Test 19: ag intel forget removes entry ---
echo ""
echo "Test 19: forget"
OUTPUT=$(run_intel '_intel_forget C-0001')

if echo "$OUTPUT" | grep -q "Forgot C-0001"; then
    pass "forget reports success"
else
    fail "forget failed" "$OUTPUT"
fi

if ! grep -q "C-0001" "$PROJECT_DIR/.agentic/intel/project-memory.yaml"; then
    pass "C-0001 removed from file"
else
    fail "C-0001 still in file" ""
fi

if grep -q "C-0002" "$PROJECT_DIR/.agentic/intel/project-memory.yaml"; then
    pass "C-0002 preserved"
else
    fail "C-0002 lost" ""
fi

# --- Test 20: forget non-existent entry ---
echo ""
echo "Test 20: forget non-existent"
OUTPUT=$(run_intel '_intel_forget C-9999')

if echo "$OUTPUT" | grep -q "not found"; then
    pass "forget errors on missing ID"
else
    fail "no error" "$OUTPUT"
fi

# --- Summary ---
echo ""
echo "═══════════════════════════════════════════"
echo "Results: $PASS passed, $FAIL failed (of $TOTAL)"
echo "═══════════════════════════════════════════"

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
exit 0
