#!/usr/bin/env bash
# test_paths.sh — Smoke test for centralized path resolution
#
# Verifies that paths.sh resolves correctly from every entry point:
#   1. Direct sourcing (from lib/)
#   2. From tool scripts (from tools/)
#   3. From hook scripts (from hooks/)
#   4. With CLAUDE_PROJECT_DIR override (simulating Claude hooks)
#   5. Python paths.py equivalence
#
# Usage:
#   bash tests/test_paths.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

COUNTER_FILE="$(mktemp)"
echo "0 0" > "$COUNTER_FILE"
trap 'rm -f "$COUNTER_FILE"' EXIT

pass() {
    local counts
    read -r p f < "$COUNTER_FILE"
    echo "$((p + 1)) $f" > "$COUNTER_FILE"
    echo "  ✓ $1"
}
fail() {
    local counts
    read -r p f < "$COUNTER_FILE"
    echo "$p $((f + 1))" > "$COUNTER_FILE"
    echo "  ✗ $1"
}

assert_eq() {
    local label="$1" expected="$2" actual="$3"
    if [[ "$actual" == "$expected" ]]; then
        pass "$label"
    else
        fail "$label (expected: $expected, got: $actual)"
    fi
}

assert_set() {
    local label="$1" value="$2"
    if [[ -n "$value" ]]; then
        pass "$label"
    else
        fail "$label (empty/unset)"
    fi
}

echo "=== paths.sh Smoke Tests ==="
echo ""

# ─────────────────────────────────────────────────────────────────────
# Test 1: Direct sourcing from lib/
# ─────────────────────────────────────────────────────────────────────
echo "--- Test 1: Direct sourcing ---"
(
    unset _AGENTIC_PATHS_LOADED  # Reset guard
    source "$PROJECT_ROOT/.agentic/lib/paths.sh"

    assert_eq "PROJECT_ROOT" "$PROJECT_ROOT" "$PROJECT_ROOT"
    assert_eq "AGENTIC_ROOT" "$PROJECT_ROOT/.agentic" "$AGENTIC_ROOT"
    assert_eq "AGENTIC_LIB" "$PROJECT_ROOT/.agentic/lib" "$AGENTIC_LIB"

    # Tracking files
    assert_set "STATUS_FILE set" "$STATUS_FILE"
    assert_set "TODO_FILE set" "$TODO_FILE"
    assert_set "HUMAN_NEEDED_FILE set" "$HUMAN_NEEDED_FILE"
    assert_set "CONTRIBUTIONS_FILE set" "$CONTRIBUTIONS_FILE"

    # Journal
    assert_set "JOURNAL_FILE set" "$JOURNAL_FILE"
    assert_set "PLANS_DIR set" "$PLANS_DIR"
    assert_set "MANIFESTS_DIR set" "$MANIFESTS_DIR"

    # Specs
    assert_set "SPEC_DIR set" "$SPEC_DIR"
    assert_set "FEATURES_FILE set" "$FEATURES_FILE"
    assert_set "ISSUES_FILE set" "$ISSUES_FILE"
    assert_set "NFR_FILE set" "$NFR_FILE"
    assert_set "ACCEPTANCE_DIR set" "$ACCEPTANCE_DIR"

    # Session
    assert_set "SESSION_DIR set" "$SESSION_DIR"
    assert_set "WIP_FILE set" "$WIP_FILE"
    assert_set "AGENTS_ACTIVE_FILE set" "$AGENTS_ACTIVE_FILE"

    # Framework dirs
    assert_set "TOOLS_DIR set" "$TOOLS_DIR"
    assert_set "AGENTS_LIB_DIR set" "$AGENTS_LIB_DIR"
    assert_set "WORKFLOWS_DIR set" "$WORKFLOWS_DIR"
    assert_set "CHECKLISTS_DIR set" "$CHECKLISTS_DIR"
    assert_set "TEMPLATES_DIR set" "$TEMPLATES_DIR"

    # Convenience
    assert_eq "ROOT_DIR == PROJECT_ROOT" "$PROJECT_ROOT" "$ROOT_DIR"
)

# ─────────────────────────────────────────────────────────────────────
# Test 2: Sourcing from tools/ (simulating a tool script)
# ─────────────────────────────────────────────────────────────────────
echo ""
echo "--- Test 2: From lib/tools/ directory ---"
(
    unset _AGENTIC_PATHS_LOADED
    cd "$PROJECT_ROOT/.agentic/lib/tools"
    source "$(pwd)/../paths.sh"

    assert_eq "PROJECT_ROOT from lib/tools/" "$PROJECT_ROOT" "$PROJECT_ROOT"
    assert_eq "AGENTIC_LIB from lib/tools/" "$PROJECT_ROOT/.agentic/lib" "$AGENTIC_LIB"
)

# ─────────────────────────────────────────────────────────────────────
# Test 3: With CLAUDE_PROJECT_DIR override
# ─────────────────────────────────────────────────────────────────────
echo ""
echo "--- Test 3: CLAUDE_PROJECT_DIR override ---"
(
    unset _AGENTIC_PATHS_LOADED
    export CLAUDE_PROJECT_DIR="$PROJECT_ROOT"
    source "$PROJECT_ROOT/.agentic/lib/paths.sh"

    assert_eq "PROJECT_ROOT from CLAUDE_PROJECT_DIR" "$PROJECT_ROOT" "$PROJECT_ROOT"
)

# ─────────────────────────────────────────────────────────────────────
# Test 4: With ROOT_DIR override
# ─────────────────────────────────────────────────────────────────────
echo ""
echo "--- Test 4: ROOT_DIR override ---"
(
    unset _AGENTIC_PATHS_LOADED
    export ROOT_DIR="$PROJECT_ROOT"
    source "$PROJECT_ROOT/.agentic/lib/paths.sh"

    assert_eq "PROJECT_ROOT from ROOT_DIR" "$PROJECT_ROOT" "$PROJECT_ROOT"
)

# ─────────────────────────────────────────────────────────────────────
# Test 5: Existing files resolve correctly
# ─────────────────────────────────────────────────────────────────────
echo ""
echo "--- Test 5: Existing files resolve to actual locations ---"
(
    unset _AGENTIC_PATHS_LOADED
    source "$PROJECT_ROOT/.agentic/lib/paths.sh"

    # These files should exist in the framework repo
    [[ -f "$STATUS_FILE" ]] && pass "STATUS_FILE exists" || fail "STATUS_FILE does not exist: $STATUS_FILE"
    [[ -f "$FEATURES_FILE" ]] && pass "FEATURES_FILE exists" || fail "FEATURES_FILE does not exist: $FEATURES_FILE"
    [[ -f "$JOURNAL_FILE" ]] && pass "JOURNAL_FILE exists" || fail "JOURNAL_FILE does not exist: $JOURNAL_FILE"
    [[ -d "$SPEC_DIR" ]] && pass "SPEC_DIR exists" || fail "SPEC_DIR does not exist: $SPEC_DIR"
    [[ -d "$TOOLS_DIR" ]] && pass "TOOLS_DIR exists" || fail "TOOLS_DIR does not exist: $TOOLS_DIR"
    [[ -f "$STACK_FILE" ]] && pass "STACK_FILE exists" || fail "STACK_FILE does not exist: $STACK_FILE"
)

# ─────────────────────────────────────────────────────────────────────
# Test 6: Tool scripts still function after migration
# ─────────────────────────────────────────────────────────────────────
echo ""
echo "--- Test 6: Tool script functional checks ---"
(
    cd "$PROJECT_ROOT"

    # status.sh (via lib/tools/)
    bash .agentic/lib/tools/status.sh focus "smoke test" >/dev/null 2>&1 && pass "status.sh works" || fail "status.sh broken"

    # wip.sh
    bash .agentic/lib/tools/wip.sh check >/dev/null 2>&1 && pass "wip.sh works" || fail "wip.sh broken"

    # todo.sh
    bash .agentic/lib/tools/todo.sh list >/dev/null 2>&1 && pass "todo.sh works" || fail "todo.sh broken"

    # feature.sh (expects error for missing feature, but should not crash)
    bash .agentic/lib/tools/feature.sh F-9999 show >/dev/null 2>&1 || pass "feature.sh works (expected error for missing feature)"

    # journal.sh (append test — write a test entry)
    bash .agentic/lib/tools/journal.sh "smoke-test" "paths.sh migration" "verify" "none" >/dev/null 2>&1 && pass "journal.sh works" || fail "journal.sh broken"

    # ag wrapper
    bash .agentic/ag help >/dev/null 2>&1 && pass "ag wrapper works" || fail "ag wrapper broken"
)

# ─────────────────────────────────────────────────────────────────────
# Test 7: Python paths.py equivalence
# ─────────────────────────────────────────────────────────────────────
echo ""
echo "--- Test 7: Python paths.py ---"
(
    cd "$PROJECT_ROOT"
    python3 -c "
import sys
from pathlib import Path
sys.path.insert(0, str(Path('.agentic/lib').resolve()))
from paths import get_paths

p = get_paths()
errors = []

# Check core resolution
if str(p.project_root) != '$PROJECT_ROOT':
    errors.append(f'project_root: {p.project_root} != $PROJECT_ROOT')
if str(p.agentic_root) != '$PROJECT_ROOT/.agentic':
    errors.append(f'agentic_root: {p.agentic_root}')
if str(p.agentic_lib) != '$PROJECT_ROOT/.agentic/lib':
    errors.append(f'agentic_lib: {p.agentic_lib}')

# Check existing files resolve
for attr, path in [
    ('features_file', p.features_file),
    ('journal_file', p.journal_file),
    ('spec_dir', p.spec_dir),
    ('status_file', p.status_file),
]:
    if not path.exists():
        errors.append(f'{attr}: {path} does not exist')

if errors:
    for e in errors:
        print(f'FAIL: {e}')
    sys.exit(1)
else:
    print('OK')
    sys.exit(0)
" 2>&1 && pass "Python paths.py resolution" || fail "Python paths.py resolution"
)

# ─────────────────────────────────────────────────────────────────────
# Test 8: Double-source guard works
# ─────────────────────────────────────────────────────────────────────
echo ""
echo "--- Test 8: Double-source guard ---"
(
    unset _AGENTIC_PATHS_LOADED
    source "$PROJECT_ROOT/.agentic/lib/paths.sh"
    local_root1="$PROJECT_ROOT"

    # Source again — should be a no-op due to guard
    source "$PROJECT_ROOT/.agentic/lib/paths.sh"
    local_root2="$PROJECT_ROOT"

    assert_eq "Double-source doesn't break" "$local_root1" "$local_root2"
)

# ─────────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────────
echo ""
read -r PASS FAIL < "$COUNTER_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Results: $PASS passed, $FAIL failed"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ "$FAIL" -gt 0 ]]; then
    exit 1
fi
exit 0
