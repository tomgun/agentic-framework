#!/usr/bin/env bash
# Tests for F-0209: TDD Mode — wip.sh --phase flag and check-tdd-phases
#
# Integration tests for:
#   - wip.sh checkpoint --phase RED|GREEN|REFACTOR
#   - agents_helpers.py check-tdd-phases validation
#   - wip.sh complete TDD gate

set -euo pipefail

PASS=0
FAIL=0
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

pass() { echo "✓ $1"; PASS=$((PASS + 1)); }
fail() { echo "✗ $1"; FAIL=$((FAIL + 1)); }

# --- Helpers ---

setup_tmpdir() {
  TMPDIR=$(mktemp -d)
  mkdir -p "$TMPDIR/.agentic/session"
  mkdir -p "$TMPDIR/.agentic/lib/tools"
  mkdir -p "$TMPDIR/.agentic/lib/presets"
  mkdir -p "$TMPDIR/.agentic/spec"

  # Minimal git repo
  git -C "$TMPDIR" init -q 2>/dev/null
  git -C "$TMPDIR" config user.email "test@test.com"
  git -C "$TMPDIR" config user.name "Test"
  touch "$TMPDIR/.gitkeep"
  git -C "$TMPDIR" add . && git -C "$TMPDIR" commit -q -m "init"

  # Copy framework tools into temp project
  cp "$PROJECT_ROOT/.agentic/lib/tools/agents_helpers.py" "$TMPDIR/.agentic/lib/tools/"
  cp "$PROJECT_ROOT/.agentic/lib/tools/wip.sh" "$TMPDIR/.agentic/lib/tools/"
  cp "$PROJECT_ROOT/.agentic/lib/paths.sh" "$TMPDIR/.agentic/lib/"
  cp "$PROJECT_ROOT/.agentic/lib/paths.py" "$TMPDIR/.agentic/lib/"
  cp "$PROJECT_ROOT/.agentic/lib/settings.sh" "$TMPDIR/.agentic/lib/"

  # Create minimal profiles.conf (needed by settings.sh)
  cat > "$TMPDIR/.agentic/lib/presets/profiles.conf" <<'EOF'
discovery.development_mode=standard
formal.development_mode=standard
autonomous_formal.development_mode=standard
EOF

  # Create minimal STACK.md with standard mode (default)
  cat > "$TMPDIR/STACK.md" <<'EOF'
# Stack

## Settings
- development_mode: standard
EOF

  # Init empty AGENTS.json
  echo "[]" > "$TMPDIR/.agentic/session/AGENTS.json"
}

cleanup_tmpdir() {
  rm -rf "$TMPDIR"
}

# Run agents_helpers.py in the temp project
agents_py() {
  python3 "$TMPDIR/.agentic/lib/tools/agents_helpers.py" --project-root "$TMPDIR" "$@"
}

# Run wip.sh in the temp project
run_wip() {
  cd "$TMPDIR" && bash .agentic/lib/tools/wip.sh "$@"
}

echo ""
echo "═══════════════════════════════════════"
echo "F-0209: TDD Phase Integration Tests"
echo "═══════════════════════════════════════"
echo ""

# --- Test 1: Happy path — RED then GREEN ---
setup_tmpdir
agents_py activate "F-TEST" "test feature" "" ""
agents_py checkpoint "F-TEST" "RED: test for behavior fails"
agents_py checkpoint "F-TEST" "GREEN: behavior passes"
EXIT=0
agents_py check-tdd-phases 2>/dev/null || EXIT=$?
if [[ $EXIT -eq 0 ]]; then
  pass "T1: RED-GREEN happy path → exit 0"
else
  fail "T1: RED-GREEN happy path → expected exit 0, got $EXIT"
fi
cleanup_tmpdir

# --- Test 2: Multi-cycle RED-GREEN-RED-GREEN ---
setup_tmpdir
agents_py activate "F-TEST" "test feature" "" ""
agents_py checkpoint "F-TEST" "RED: first test"
agents_py checkpoint "F-TEST" "GREEN: first pass"
agents_py checkpoint "F-TEST" "RED: second test"
agents_py checkpoint "F-TEST" "GREEN: second pass"
EXIT=0
agents_py check-tdd-phases 2>/dev/null || EXIT=$?
if [[ $EXIT -eq 0 ]]; then
  pass "T2: Multi-cycle RED-GREEN-RED-GREEN → exit 0"
else
  fail "T2: Multi-cycle → expected exit 0, got $EXIT"
fi
cleanup_tmpdir

# --- Test 3: RED-GREEN-REFACTOR ---
setup_tmpdir
agents_py activate "F-TEST" "test feature" "" ""
agents_py checkpoint "F-TEST" "RED: test fails"
agents_py checkpoint "F-TEST" "GREEN: test passes"
agents_py checkpoint "F-TEST" "REFACTOR: cleaned up"
EXIT=0
agents_py check-tdd-phases 2>/dev/null || EXIT=$?
if [[ $EXIT -eq 0 ]]; then
  pass "T3: RED-GREEN-REFACTOR → exit 0"
else
  fail "T3: RED-GREEN-REFACTOR → expected exit 0, got $EXIT"
fi
cleanup_tmpdir

# --- Test 4: Batch test-first RED-RED-GREEN-GREEN ---
setup_tmpdir
agents_py activate "F-TEST" "test feature" "" ""
agents_py checkpoint "F-TEST" "RED: test A"
agents_py checkpoint "F-TEST" "RED: test B"
agents_py checkpoint "F-TEST" "GREEN: A passes"
agents_py checkpoint "F-TEST" "GREEN: B passes"
EXIT=0
agents_py check-tdd-phases 2>/dev/null || EXIT=$?
if [[ $EXIT -eq 0 ]]; then
  pass "T4: Batch RED-RED-GREEN-GREEN → exit 0"
else
  fail "T4: Batch → expected exit 0, got $EXIT"
fi
cleanup_tmpdir

# --- Test 5: GREEN before RED → exit 2 ---
setup_tmpdir
agents_py activate "F-TEST" "test feature" "" ""
agents_py checkpoint "F-TEST" "GREEN: passes without RED first"
EXIT=0
agents_py check-tdd-phases 2>/dev/null || EXIT=$?
if [[ $EXIT -eq 2 ]]; then
  pass "T5: GREEN before RED → exit 2 (ordering violation)"
else
  fail "T5: GREEN before RED → expected exit 2, got $EXIT"
fi
cleanup_tmpdir

# --- Test 6: Zero phase entries → exit 3 ---
setup_tmpdir
agents_py activate "F-TEST" "test feature" "" ""
agents_py checkpoint "F-TEST" "normal checkpoint without phase"
EXIT=0
agents_py check-tdd-phases 2>/dev/null || EXIT=$?
if [[ $EXIT -eq 3 ]]; then
  pass "T6: Zero phase entries → exit 3"
else
  fail "T6: Zero phase entries → expected exit 3, got $EXIT"
fi
cleanup_tmpdir

# --- Test 7: No active entries → exit 1 ---
setup_tmpdir
EXIT=0
agents_py check-tdd-phases 2>/dev/null || EXIT=$?
if [[ $EXIT -eq 1 ]]; then
  pass "T7: No active entries → exit 1"
else
  fail "T7: No active entries → expected exit 1, got $EXIT"
fi
cleanup_tmpdir

# --- Test 8: wip.sh checkpoint --phase RED prefixes correctly ---
setup_tmpdir
run_wip start F-TEST "test feature" "file1" >/dev/null
run_wip checkpoint --phase RED "test for behavior fails" >/dev/null
PROGRESS=$(python3 -c "
import json
with open('$TMPDIR/.agentic/session/AGENTS.json') as f:
    data = json.load(f)
for e in data:
    if e.get('feature_id') == 'F-TEST':
        for p in e.get('progress', []):
            if p.startswith('RED:'):
                print(p)
")
if [[ "$PROGRESS" == "RED: test for behavior fails" ]]; then
  pass "T8: wip.sh --phase RED prefixes correctly in AGENTS.json"
else
  fail "T8: Expected 'RED: test for behavior fails', got '$PROGRESS'"
fi
cleanup_tmpdir

# --- Test 9: wip.sh checkpoint --phase INVALID → error ---
setup_tmpdir
run_wip start F-TEST "test feature" "file1" >/dev/null
EXIT=0
run_wip checkpoint --phase INVALID "should fail" 2>/dev/null || EXIT=$?
if [[ $EXIT -ne 0 ]]; then
  pass "T9: --phase INVALID → error exit"
else
  fail "T9: --phase INVALID → expected non-zero exit"
fi
cleanup_tmpdir

# --- Test 10: Case insensitivity → stored uppercase ---
setup_tmpdir
run_wip start F-TEST "test feature" "file1" >/dev/null
run_wip checkpoint --phase red "lowercase phase" >/dev/null
PROGRESS=$(python3 -c "
import json
with open('$TMPDIR/.agentic/session/AGENTS.json') as f:
    data = json.load(f)
for e in data:
    if e.get('feature_id') == 'F-TEST':
        for p in e.get('progress', []):
            if p.startswith('RED:'):
                print(p)
")
if [[ "$PROGRESS" == "RED: lowercase phase" ]]; then
  pass "T10: Case insensitive → stored as 'RED:'"
else
  fail "T10: Expected 'RED: lowercase phase', got '$PROGRESS'"
fi
cleanup_tmpdir

# --- Test 11: Backward compat — checkpoint without --phase works ---
setup_tmpdir
run_wip start F-TEST "test feature" "file1" >/dev/null
run_wip checkpoint "plain note" >/dev/null
PROGRESS=$(python3 -c "
import json
with open('$TMPDIR/.agentic/session/AGENTS.json') as f:
    data = json.load(f)
for e in data:
    if e.get('feature_id') == 'F-TEST':
        for p in e.get('progress', []):
            print(p)
")
if echo "$PROGRESS" | grep -q "plain note"; then
  pass "T11: Backward compat — plain checkpoint works"
else
  fail "T11: Expected 'plain note' in progress"
fi
cleanup_tmpdir

# --- Test 12: wip.sh complete blocks with TDD mode + no phases ---
setup_tmpdir
# Switch to TDD mode
sed -i 's/development_mode: standard/development_mode: tdd/' "$TMPDIR/STACK.md"
run_wip start F-TEST "test feature" "file1" >/dev/null
run_wip checkpoint "plain note without phases" >/dev/null
EXIT=0
run_wip complete 2>/dev/null || EXIT=$?
if [[ $EXIT -ne 0 ]]; then
  pass "T12: wip.sh complete blocks with TDD mode + no phases"
else
  fail "T12: wip.sh complete should block with TDD mode and no phases"
fi
cleanup_tmpdir

# --- Test 13: wip.sh complete succeeds with TDD mode + RED+GREEN ---
setup_tmpdir
sed -i 's/development_mode: standard/development_mode: tdd/' "$TMPDIR/STACK.md"
run_wip start F-TEST "test feature" "file1" >/dev/null
run_wip checkpoint --phase RED "test fails" >/dev/null
run_wip checkpoint --phase GREEN "test passes" >/dev/null
EXIT=0
run_wip complete 2>/dev/null || EXIT=$?
if [[ $EXIT -eq 0 ]]; then
  pass "T13: wip.sh complete succeeds with TDD mode + RED+GREEN"
else
  fail "T13: wip.sh complete should succeed with valid phases, got exit $EXIT"
fi
cleanup_tmpdir

# --- Test 14: Standard mode — complete proceeds without phase check ---
setup_tmpdir
run_wip start F-TEST "test feature" "file1" >/dev/null
run_wip checkpoint "no phases needed" >/dev/null
EXIT=0
run_wip complete 2>/dev/null || EXIT=$?
if [[ $EXIT -eq 0 ]]; then
  pass "T14: Standard mode — complete proceeds without phase check"
else
  fail "T14: Standard mode complete should succeed, got exit $EXIT"
fi
cleanup_tmpdir

# --- Summary ---
echo ""
echo "═══════════════════════════════════════"
echo "Results: $PASS passed, $FAIL failed"
echo "═══════════════════════════════════════"
echo ""

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
exit 0
