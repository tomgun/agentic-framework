#!/usr/bin/env bash
# LLM Behavioral Test Harness
#
# Runs automated behavioral tests against Claude Code using fresh project contexts.
# Each test creates a temp project, installs framework, sends prompts, checks outcomes.
#
# Usage:
#   bash tests/llm/harness.sh                    # Run all tests
#   bash tests/llm/harness.sh tests/llm/tests/001_session_start.sh  # Run specific test
#   bash tests/llm/harness.sh --list             # List available tests
#
# Test format:
#   Each test is a bash script that:
#   - Receives $TEST_PROJECT as the temp project path
#   - Receives $FRAMEWORK_ROOT as the framework source path
#   - Sends prompts via send_prompt "prompt text"
#   - Checks outcomes via check_output_contains "pattern"
#   - Returns 0 for pass, 1 for fail
#
# Environment:
#   CLAUDE_CMD - Path to claude CLI (default: claude)
#   KEEP_PROJECTS - Set to "1" to keep temp projects for debugging

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CLAUDE_CMD="${CLAUDE_CMD:-claude}"
KEEP_PROJECTS="${KEEP_PROJECTS:-0}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test state
TEST_PROJECT=""
LAST_OUTPUT=""
LAST_OUTPUT_FILE=""

#=============================================================================
# Test Helper Functions (available to test scripts)
#=============================================================================

# Create fresh test project with framework installed
setup_test_project() {
    local profile="${1:-core}"  # core or core-pm

    TEST_PROJECT=$(mktemp -d "/tmp/llm-test-XXXXXX")
    LAST_OUTPUT_FILE="$TEST_PROJECT/.test_output"

    echo -e "${BLUE}Setting up test project: $TEST_PROJECT${NC}"

    cd "$TEST_PROJECT"
    git init --quiet
    git config user.email "test@example.com"
    git config user.name "Test User"

    # Install framework
    bash "$FRAMEWORK_ROOT/install.sh" . --quiet 2>/dev/null || bash "$FRAMEWORK_ROOT/install.sh" .

    # Create minimal project structure based on profile
    if [[ "$profile" == "core-pm" ]]; then
        mkdir -p spec/acceptance
        echo "# Features" > spec/FEATURES.md
        echo "# Status" > STATUS.md
    fi

    # Initial commit so git commands work
    git add -A
    git commit -m "Initial setup" --quiet

    echo -e "${GREEN}✓ Test project ready${NC}"
    export TEST_PROJECT
}

# Send a prompt to Claude and capture output
send_prompt() {
    local prompt="$1"
    local max_turns="${2:-5}"  # Limit turns to keep tests fast

    echo -e "${BLUE}Sending prompt: ${NC}$prompt"

    cd "$TEST_PROJECT"

    # Run claude with the prompt, capture output
    # Using --print flag for non-interactive single response
    # Fallback to echo + pipe if --print not available
    if $CLAUDE_CMD --help 2>&1 | grep -q "\-\-print"; then
        LAST_OUTPUT=$($CLAUDE_CMD --print "$prompt" 2>&1) || true
    else
        # Use heredoc to send prompt and exit
        LAST_OUTPUT=$(echo "$prompt" | timeout 120 $CLAUDE_CMD 2>&1) || true
    fi

    echo "$LAST_OUTPUT" > "$LAST_OUTPUT_FILE"

    # Show truncated output
    echo -e "${BLUE}Output (truncated):${NC}"
    echo "$LAST_OUTPUT" | head -20
    if [[ $(echo "$LAST_OUTPUT" | wc -l) -gt 20 ]]; then
        echo "... ($(echo "$LAST_OUTPUT" | wc -l) total lines)"
    fi
    echo ""
}

# Check if output contains a pattern (case-insensitive)
check_output_contains() {
    local pattern="$1"
    local description="${2:-Pattern '$pattern' found}"

    if echo "$LAST_OUTPUT" | grep -qi "$pattern"; then
        echo -e "${GREEN}✓ $description${NC}"
        return 0
    else
        echo -e "${RED}✗ $description${NC}"
        echo -e "${RED}  Pattern not found: $pattern${NC}"
        return 1
    fi
}

# Check if output does NOT contain a pattern
check_output_not_contains() {
    local pattern="$1"
    local description="${2:-Pattern '$pattern' not found}"

    if echo "$LAST_OUTPUT" | grep -qi "$pattern"; then
        echo -e "${RED}✗ $description${NC}"
        echo -e "${RED}  Unwanted pattern found: $pattern${NC}"
        return 1
    else
        echo -e "${GREEN}✓ $description${NC}"
        return 0
    fi
}

# Check if a file exists in the test project
check_file_exists() {
    local filepath="$1"
    local description="${2:-File '$filepath' exists}"

    if [[ -f "$TEST_PROJECT/$filepath" ]]; then
        echo -e "${GREEN}✓ $description${NC}"
        return 0
    else
        echo -e "${RED}✗ $description${NC}"
        return 1
    fi
}

# Check if a file does NOT exist
check_file_not_exists() {
    local filepath="$1"
    local description="${2:-File '$filepath' does not exist}"

    if [[ -f "$TEST_PROJECT/$filepath" ]]; then
        echo -e "${RED}✗ $description${NC}"
        return 1
    else
        echo -e "${GREEN}✓ $description${NC}"
        return 0
    fi
}

# Check if file contains pattern
check_file_contains() {
    local filepath="$1"
    local pattern="$2"
    local description="${3:-File '$filepath' contains '$pattern'}"

    if [[ -f "$TEST_PROJECT/$filepath" ]] && grep -qi "$pattern" "$TEST_PROJECT/$filepath"; then
        echo -e "${GREEN}✓ $description${NC}"
        return 0
    else
        echo -e "${RED}✗ $description${NC}"
        return 1
    fi
}

# Cleanup test project
cleanup_test_project() {
    if [[ "$KEEP_PROJECTS" == "1" ]]; then
        echo -e "${YELLOW}Keeping test project: $TEST_PROJECT${NC}"
    elif [[ -n "$TEST_PROJECT" ]] && [[ -d "$TEST_PROJECT" ]]; then
        rm -rf "$TEST_PROJECT"
        echo -e "${BLUE}Cleaned up test project${NC}"
    fi
}

# Export functions for test scripts
export -f setup_test_project send_prompt check_output_contains check_output_not_contains
export -f check_file_exists check_file_not_exists check_file_contains cleanup_test_project
export FRAMEWORK_ROOT CLAUDE_CMD

#=============================================================================
# Test Runner
#=============================================================================

run_test() {
    local test_file="$1"
    local test_name=$(basename "$test_file" .sh)

    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo -e "${BLUE}Running: $test_name${NC}"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""

    # Run test in subshell to isolate state
    if (source "$test_file"); then
        echo ""
        echo -e "${GREEN}══ PASSED: $test_name ══${NC}"
        return 0
    else
        echo ""
        echo -e "${RED}══ FAILED: $test_name ══${NC}"
        return 1
    fi
}

list_tests() {
    echo "Available LLM behavioral tests:"
    echo ""
    for test_file in "$SCRIPT_DIR/tests"/*.sh; do
        if [[ -f "$test_file" ]]; then
            local name=$(basename "$test_file" .sh)
            local desc=$(grep "^# Description:" "$test_file" | sed 's/^# Description: //' || echo "No description")
            echo "  $name"
            echo "    $desc"
        fi
    done
}

main() {
    if [[ "${1:-}" == "--list" ]]; then
        list_tests
        exit 0
    fi

    echo ""
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║         LLM Behavioral Test Harness                          ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Framework: $FRAMEWORK_ROOT"
    echo "Claude CLI: $CLAUDE_CMD"
    echo ""

    local tests_to_run=()
    local passed=0
    local failed=0

    if [[ $# -gt 0 ]]; then
        tests_to_run=("$@")
    else
        for test_file in "$SCRIPT_DIR/tests"/*.sh; do
            [[ -f "$test_file" ]] && tests_to_run+=("$test_file")
        done
    fi

    if [[ ${#tests_to_run[@]} -eq 0 ]]; then
        echo "No tests found in $SCRIPT_DIR/tests/"
        echo "Create test files like: tests/llm/tests/001_session_start.sh"
        exit 1
    fi

    echo "Running ${#tests_to_run[@]} test(s)..."

    for test_file in "${tests_to_run[@]}"; do
        if run_test "$test_file"; then
            ((passed++))
        else
            ((failed++))
        fi
    done

    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "RESULTS: $passed passed, $failed failed ($(( passed + failed )) total)"
    echo "═══════════════════════════════════════════════════════════════"

    [[ $failed -eq 0 ]]
}

# Only run main if not being sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
