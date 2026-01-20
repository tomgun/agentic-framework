#!/usr/bin/env bash
# llm-test-status.sh - Check LLM test status and remind if needed
#
# Usage:
#   bash .agentic/tools/llm-test-status.sh          # Check status
#   bash .agentic/tools/llm-test-status.sh --quiet  # Only warn if stale
#
# Exit codes:
#   0 - Tests are current (or no results file)
#   1 - Tests are stale (>30 days)

set -euo pipefail

QUIET=${1:-}
RESULTS_FILE="tests/LLM_TEST_RESULTS.md"
STALE_DAYS=30

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Get framework version
get_version() {
    if [[ -f ".agentic/VERSION" ]]; then
        cat .agentic/VERSION
    elif [[ -f "VERSION" ]]; then
        cat VERSION
    else
        echo "unknown"
    fi
}

# Parse last test date from results file
get_last_test_info() {
    if [[ ! -f "$RESULTS_FILE" ]]; then
        echo "none|none|none"
        return
    fi

    # Look for "Last Tested" in the status table
    local claude_date=$(grep "Claude Code" "$RESULTS_FILE" | head -1 | awk -F'|' '{print $3}' | xargs)
    local cursor_date=$(grep "Cursor" "$RESULTS_FILE" | head -1 | awk -F'|' '{print $3}' | xargs)
    local copilot_date=$(grep "Copilot" "$RESULTS_FILE" | head -1 | awk -F'|' '{print $3}' | xargs)

    echo "${claude_date:-none}|${cursor_date:-none}|${copilot_date:-none}"
}

# Check if date is stale (>30 days or "not yet")
is_stale() {
    local date_str="$1"

    if [[ "$date_str" == "none" ]] || [[ "$date_str" == "_not yet_" ]] || [[ "$date_str" == "-" ]]; then
        return 0  # Yes, stale (never tested)
    fi

    # Try to parse date and compare
    if command -v date >/dev/null 2>&1; then
        local test_date
        if [[ "$(uname)" == "Darwin" ]]; then
            test_date=$(date -j -f "%Y-%m-%d" "$date_str" +%s 2>/dev/null || echo "0")
        else
            test_date=$(date -d "$date_str" +%s 2>/dev/null || echo "0")
        fi

        if [[ "$test_date" == "0" ]]; then
            return 0  # Can't parse, assume stale
        fi

        local now=$(date +%s)
        local diff=$(( (now - test_date) / 86400 ))

        if [[ $diff -gt $STALE_DAYS ]]; then
            return 0  # Yes, stale
        fi
    fi

    return 1  # Not stale
}

# Main
main() {
    local version=$(get_version)
    local info=$(get_last_test_info)
    IFS='|' read -r claude cursor copilot <<< "$info"

    local any_stale=false
    local all_tested=true

    # Check each environment
    for env_date in "$claude" "$cursor" "$copilot"; do
        if is_stale "$env_date"; then
            any_stale=true
        fi
        if [[ "$env_date" == "none" ]] || [[ "$env_date" == "_not yet_" ]] || [[ "$env_date" == "-" ]]; then
            all_tested=false
        fi
    done

    # Quiet mode: only output if stale
    if [[ "$QUIET" == "--quiet" ]]; then
        if $any_stale; then
            echo -e "${YELLOW}⚠️  LLM behavioral tests may be stale. Run: cat tests/RUN_LLM_TESTS.md${NC}"
            return 1
        fi
        return 0
    fi

    # Full status output
    echo ""
    echo "═══════════════════════════════════════════════════════"
    echo "LLM Behavioral Test Status"
    echo "═══════════════════════════════════════════════════════"
    echo ""
    echo "Framework Version: $version"
    echo ""
    echo "Last Tested:"

    # Claude
    if is_stale "$claude"; then
        echo -e "  Claude Code:    ${YELLOW}${claude:-never}${NC} (stale)"
    else
        echo -e "  Claude Code:    ${GREEN}${claude}${NC}"
    fi

    # Cursor
    if is_stale "$cursor"; then
        echo -e "  Cursor:         ${YELLOW}${cursor:-never}${NC} (stale)"
    else
        echo -e "  Cursor:         ${GREEN}${cursor}${NC}"
    fi

    # Copilot
    if is_stale "$copilot"; then
        echo -e "  GitHub Copilot: ${YELLOW}${copilot:-never}${NC} (stale)"
    else
        echo -e "  GitHub Copilot: ${GREEN}${copilot}${NC}"
    fi

    echo ""

    if $any_stale; then
        echo -e "${YELLOW}Recommendation: Run LLM tests for stale environments${NC}"
        echo "  See: tests/RUN_LLM_TESTS.md"
        echo ""
        return 1
    else
        echo -e "${GREEN}✓ All environments tested recently${NC}"
        echo ""
        return 0
    fi
}

main "$@"
