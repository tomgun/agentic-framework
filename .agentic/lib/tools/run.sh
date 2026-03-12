#!/usr/bin/env bash
# run.sh — Show how to run this project
#
# Detects stack from STACK.md + auto-detection and displays
# dev server, build, and test commands. All detection logic
# lives in discover.py:preview_info() — this is a thin wrapper.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../paths.sh"

# Colors (disabled if not TTY)
if [[ -t 1 ]]; then
    BOLD='\033[1m'
    DIM='\033[2m'
    GREEN='\033[32m'
    YELLOW='\033[33m'
    CYAN='\033[36m'
    NC='\033[0m'
else
    BOLD='' DIM='' GREEN='' YELLOW='' CYAN='' NC=''
fi

# Check STACK.md exists
if [[ ! -f "$STACK_FILE" ]]; then
    echo -e "${YELLOW}⚠ No STACK.md found. Run 'ag init' first.${NC}"
    echo "  Auto-detecting from codebase..."
    echo ""
fi

# Get preview info from discover.py (single source of truth)
PREVIEW_JSON=$(python3 "$SCRIPT_DIR/discover.py" --root "$ROOT_DIR" --preview 2>/dev/null) || {
    echo -e "${YELLOW}⚠ Could not detect project stack.${NC}"
    echo "  Ensure STACK.md is configured or project has standard config files."
    exit 1
}

# Parse JSON fields
_jq() { echo "$PREVIEW_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); $1" 2>/dev/null; }

LANGUAGE=$(_jq "print(d.get('language') or 'unknown')")
FRAMEWORK=$(_jq "print(d.get('framework') or '')")
PLATFORM=$(_jq "print(d.get('platform') or '')")
PM=$(_jq "print(d.get('package_manager') or '')")
DEV_CMD=$(_jq "print(d.get('dev_command') or '')")
BUILD_CMD=$(_jq "print(d.get('build_command') or '')")
TEST_UNIT=$(_jq "print((d.get('test_commands') or {}).get('unit') or '')")
TEST_INT=$(_jq "print((d.get('test_commands') or {}).get('integration') or '')")
TEST_E2E=$(_jq "print((d.get('test_commands') or {}).get('e2e') or '')")
WARNINGS=$(_jq "
w = d.get('warnings', [])
for x in w: print(x)
")
SOURCES=$(_jq "
s = d.get('sources', {})
for k,v in s.items(): print(f'{k}={v}')
")

# Helper: show source attribution
_src() {
    local key="$1"
    local src
    src=$(echo "$SOURCES" | grep "^${key}=" | cut -d= -f2)
    if [[ "$src" == "stack.md" ]]; then
        echo -e "${DIM}(from STACK.md)${NC}"
    elif [[ "$src" == "auto" ]]; then
        echo -e "${DIM}(auto-detected)${NC}"
    fi
}

# Display
echo ""
echo -e "${BOLD}How to Run${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Stack
echo -e "${CYAN}Stack:${NC}     $LANGUAGE${FRAMEWORK:+ / $FRAMEWORK}${PM:+ / $PM} $(_src language)"
[[ -n "$PLATFORM" ]] && echo -e "${CYAN}Platform:${NC}  $PLATFORM $(_src platform)"

# Dev Server
echo ""
if [[ -n "$DEV_CMD" ]]; then
    echo -e "${CYAN}Dev Server:${NC}  ${GREEN}${DEV_CMD}${NC} $(_src dev_command)"
else
    echo -e "${CYAN}Dev Server:${NC}  ${DIM}(not detected)${NC}"
fi

# Build
if [[ -n "$BUILD_CMD" ]]; then
    echo -e "${CYAN}Build:${NC}       ${GREEN}${BUILD_CMD}${NC} $(_src build_command)"
fi

# Tests
if [[ -n "$TEST_UNIT" || -n "$TEST_INT" || -n "$TEST_E2E" ]]; then
    echo ""
    echo -e "${CYAN}Tests:${NC}"
    [[ -n "$TEST_UNIT" ]] && echo -e "  Unit:        ${GREEN}${TEST_UNIT}${NC}"
    [[ -n "$TEST_INT" ]] && echo -e "  Integration: ${GREEN}${TEST_INT}${NC}"
    [[ -n "$TEST_E2E" ]] && echo -e "  E2E/LLM:     ${GREEN}${TEST_E2E}${NC}"
fi

# Warnings
if [[ -n "$WARNINGS" ]]; then
    echo ""
    while IFS= read -r warn; do
        [[ -n "$warn" ]] && echo -e "${YELLOW}⚠ ${warn}${NC}"
    done <<< "$WARNINGS"
fi

echo ""
