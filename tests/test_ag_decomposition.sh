#!/usr/bin/env bash
# test_ag_decomposition.sh — Verify ag.sh decomposition (F-0221)
# Ensures all commands are accessible after extraction into modules.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
AG_SCRIPT="$FRAMEWORK_ROOT/.agentic/lib/tools/ag.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASSED=0
FAILED=0

test_case() { echo -n "Testing: $1... "; }
pass() { echo -e "${GREEN}PASS${NC}"; ((PASSED++)); }
fail() { echo -e "${RED}FAIL${NC}"; [[ -n "${1:-}" ]] && echo "  $1"; ((FAILED++)); }

# ---------------------------------------------------------------------------
# AC-012: ag.sh is < 500 lines
# ---------------------------------------------------------------------------
test_case "AC-012: ag.sh is under 500 lines"
LINE_COUNT=$(wc -l < "$AG_SCRIPT")
if [ "$LINE_COUNT" -lt 500 ]; then
    pass
else
    fail "ag.sh is $LINE_COUNT lines (expected < 500)"
fi

# ---------------------------------------------------------------------------
# AC-013: Each module is self-contained (sourced, no standalone execution)
# ---------------------------------------------------------------------------
test_case "AC-013: Modules have sourced-by-ag.sh header"
CMDS_DIR="$FRAMEWORK_ROOT/.agentic/lib/tools/commands"
ALL_GOOD=true
for f in "$CMDS_DIR"/*.sh; do
    if ! grep -q "Sourced by ag.sh" "$f" 2>/dev/null; then
        ALL_GOOD=false
        break
    fi
done
if $ALL_GOOD; then pass; else fail "Missing 'Sourced by ag.sh' in $f"; fi

test_case "AC-013: Modules do not redefine SCRIPT_DIR"
REDEFINES=$(grep -rl 'SCRIPT_DIR=' "$CMDS_DIR/" 2>/dev/null | grep -v '\.sh:$' || true)
if [ -z "$REDEFINES" ]; then pass; else fail "SCRIPT_DIR redefined in: $REDEFINES"; fi

# ---------------------------------------------------------------------------
# AC-014: Modules live at .agentic/lib/tools/commands/
# ---------------------------------------------------------------------------
test_case "AC-014: commands/ directory exists with modules"
MODULE_COUNT=$(ls "$CMDS_DIR"/*.sh 2>/dev/null | wc -l)
if [ "$MODULE_COUNT" -ge 10 ]; then
    pass
else
    fail "Expected >= 10 modules, found $MODULE_COUNT"
fi

# ---------------------------------------------------------------------------
# AC-015: All ag commands are accessible (behavioral equivalence)
# ---------------------------------------------------------------------------
COMMANDS=(
    "help"
    "set --show"
    "spec"
    "auto --help"
    "kickoff --help"
    "trace --help"
)

for cmd in "${COMMANDS[@]}"; do
    test_case "AC-015: ag $cmd produces output"
    output=$(bash "$AG_SCRIPT" $cmd 2>&1) || true
    if [ -n "$output" ]; then
        pass
    else
        fail "ag $cmd produced no output"
    fi
done

# Check specific function availability by grepping dispatch
test_case "AC-015: Dispatch covers all expected commands"
EXPECTED_CMDS="start init work plan implement spec specs todo feedback commit done merge docs hooks trace test agents tools auto coord backlog kickoff audit nfr intent sync verify status set run"
ALL_FOUND=true
MISSING=""
for cmd in $EXPECTED_CMDS; do
    if ! grep -q "    ${cmd})" "$AG_SCRIPT" 2>/dev/null; then
        ALL_FOUND=false
        MISSING="$MISSING $cmd"
    fi
done
# help uses help|--help|-h) pattern
if ! grep -q 'help|--help|-h)' "$AG_SCRIPT" 2>/dev/null; then
    ALL_FOUND=false
    MISSING="$MISSING help"
fi
if $ALL_FOUND; then pass; else fail "Missing dispatch entries:$MISSING"; fi

# ---------------------------------------------------------------------------
# Source integrity: ag.sh sources all modules
# ---------------------------------------------------------------------------
test_case "Source statements: ag.sh sources all 12 modules"
EXPECTED_MODULES="start plan implement commit done kickoff auto specs help diagnostics settings operations"
SOURCED=0
for mod in $EXPECTED_MODULES; do
    if grep -q "${mod}.sh" "$AG_SCRIPT" 2>/dev/null; then
        SOURCED=$((SOURCED + 1))
    fi
done
if [ "$SOURCED" -eq 12 ]; then pass; else fail "Found $SOURCED/12 source statements"; fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "ag.sh Decomposition Tests: $PASSED passed, $FAILED failed"
echo "ag.sh line count: $LINE_COUNT"
echo "Module count: $MODULE_COUNT"
echo "═══════════════════════════════════════════════════════════════"

exit $FAILED
