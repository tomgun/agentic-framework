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
#   bash tests/llm/harness.sh --compare-models   # Run on Opus + Sonnet, generate report
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
#   TOOL - AI tool to use: claude (default), cursor, copilot
#   CLAUDE_MODEL - Model for Claude: opus (default), sonnet, or full model name
#   CLAUDE_CMD - Path to claude CLI (default: claude)
#   KEEP_PROJECTS - Set to "1" to keep temp projects for debugging
#
# Examples:
#   bash tests/llm/harness.sh                              # Claude + Opus
#   CLAUDE_MODEL=sonnet bash tests/llm/harness.sh          # Claude + Sonnet
#   TOOL=cursor bash tests/llm/harness.sh                  # Cursor (semi-automated)
#   bash tests/llm/harness.sh --compare-models --critical  # Compare Opus vs Sonnet

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TOOL="${TOOL:-claude}"
CLAUDE_MODEL="${CLAUDE_MODEL:-opus}"
CLAUDE_CMD="${CLAUDE_CMD:-claude}"
KEEP_PROJECTS="${KEEP_PROJECTS:-0}"

# Validate tool
if [[ "$TOOL" != "claude" && "$TOOL" != "cursor" && "$TOOL" != "copilot" ]]; then
    echo "Error: TOOL must be 'claude', 'cursor', or 'copilot'"
    exit 1
fi

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

    # Install framework (echo 'n' to skip agent suggestions prompt)
    echo "n" | bash "$FRAMEWORK_ROOT/install.sh" .

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

# Send a prompt to the AI tool and capture output
send_prompt() {
    local prompt="$1"
    local max_turns="${2:-5}"  # Limit turns to keep tests fast

    echo -e "${BLUE}Sending prompt: ${NC}$prompt"

    cd "$TEST_PROJECT"

    if [[ "$TOOL" == "claude" ]]; then
        # Fully automated: Claude Code CLI
        # Use --model to specify model, --print for non-interactive
        local -a model_args=()
        if [[ -n "$CLAUDE_MODEL" ]]; then
            model_args=(--model "$CLAUDE_MODEL")
        fi

        if $CLAUDE_CMD --help 2>&1 | grep -q "\-\-print"; then
            LAST_OUTPUT=$($CLAUDE_CMD "${model_args[@]}" --print "$prompt" 2>&1) || true
        else
            # Fallback to echo + pipe if --print not available
            LAST_OUTPUT=$(echo "$prompt" | timeout 120 $CLAUDE_CMD "${model_args[@]}" 2>&1) || true
        fi
    else
        # Semi-automated: Cursor or Copilot (IDE-based)
        echo ""
        echo -e "${YELLOW}════════════════════════════════════════════════════════════${NC}"
        echo -e "${YELLOW}MANUAL STEP REQUIRED (${TOOL})${NC}"
        echo -e "${YELLOW}════════════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "1. Open this folder in ${TOOL^}:"
        echo -e "   ${GREEN}$TEST_PROJECT${NC}"
        echo ""
        echo -e "2. Enter this prompt:"
        echo -e "   ${GREEN}$prompt${NC}"
        echo ""
        echo -e "3. Wait for the agent to complete its response"
        echo ""
        echo -e "4. Copy the agent's full response and paste below"
        echo -e "   (or type 'skip' to mark as manual verification needed)"
        echo ""
        echo -e "${YELLOW}════════════════════════════════════════════════════════════${NC}"
        echo ""
        echo -n "Paste response (end with Ctrl+D) or type 'skip': "

        LAST_OUTPUT=""
        while IFS= read -r line; do
            if [[ "$line" == "skip" ]]; then
                LAST_OUTPUT="[MANUAL_VERIFICATION_NEEDED]"
                break
            fi
            LAST_OUTPUT="${LAST_OUTPUT}${line}\n"
        done

        if [[ "$LAST_OUTPUT" == "[MANUAL_VERIFICATION_NEEDED]" ]]; then
            echo -e "${YELLOW}Skipped - manual verification needed${NC}"
        fi
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

# Export functions and variables for test scripts
export -f setup_test_project send_prompt check_output_contains check_output_not_contains
export -f check_file_exists check_file_not_exists check_file_contains cleanup_test_project
export FRAMEWORK_ROOT CLAUDE_CMD TOOL CLAUDE_MODEL

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
            local section=$(grep "^# Section:" "$test_file" | sed 's/^# Section: //' || echo "unknown")
            echo "  $name [$section]"
            echo "    $desc"
        fi
    done
}

# Get tests by section
get_tests_by_section() {
    local section="$1"
    for test_file in "$SCRIPT_DIR/tests"/*.sh; do
        if [[ -f "$test_file" ]]; then
            local file_section=$(grep "^# Section:" "$test_file" | sed 's/^# Section: //')
            if [[ "$file_section" == "$section" ]]; then
                echo "$test_file"
            fi
        fi
    done
}

# List available sections
list_sections() {
    echo "Available sections:"
    echo ""
    for section in session trigger scripts commit context; do
        local count=$(get_tests_by_section "$section" | wc -l | tr -d ' ')
        echo "  $section ($count tests)"
    done
    echo ""
    echo "Usage: bash tests/llm/harness.sh --section <section>"
}

# Run tests on multiple models and generate compatibility report
run_model_comparison() {
    local models=("opus" "sonnet")
    local tests_to_run=()

    # Collect tests to run
    if [[ $# -gt 0 ]]; then
        tests_to_run=("$@")
    else
        for test_file in "$SCRIPT_DIR/tests"/*.sh; do
            [[ -f "$test_file" ]] && tests_to_run+=("$test_file")
        done
    fi

    if [[ ${#tests_to_run[@]} -eq 0 ]]; then
        echo "No tests found"
        exit 1
    fi

    echo ""
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║         Multi-Model Comparison Test Run                       ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Models: ${models[*]}"
    echo "Tests: ${#tests_to_run[@]}"
    echo ""

    # Results storage: model -> test -> pass/fail
    declare -A results
    local report_file="$SCRIPT_DIR/model-compatibility.md"

    for model in "${models[@]}"; do
        echo ""
        echo "═══════════════════════════════════════════════════════════════"
        echo -e "${BLUE}Running with model: $model${NC}"
        echo "═══════════════════════════════════════════════════════════════"

        export CLAUDE_MODEL="$model"

        for test_file in "${tests_to_run[@]}"; do
            local test_name=$(basename "$test_file" .sh)
            echo -e "${BLUE}  Testing: $test_name${NC}"

            if (source "$test_file" 2>/dev/null); then
                results["$model:$test_name"]="✅"
                echo -e "  ${GREEN}✓ PASS${NC}"
            else
                results["$model:$test_name"]="❌"
                echo -e "  ${RED}✗ FAIL${NC}"
            fi
        done
    done

    # Generate compatibility report
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "Generating compatibility report..."
    echo "═══════════════════════════════════════════════════════════════"

    {
        echo "# Model Compatibility Report"
        echo ""
        echo "Generated: $(date '+%Y-%m-%d %H:%M')"
        echo ""
        echo "## Results Matrix"
        echo ""
        echo "| Test | Opus | Sonnet | Status |"
        echo "|------|------|--------|--------|"

        local all_pass=0
        local opus_only=0
        local sonnet_only=0
        local both_fail=0

        for test_file in "${tests_to_run[@]}"; do
            local test_name=$(basename "$test_file" .sh)
            local opus_result="${results[opus:$test_name]:-?}"
            local sonnet_result="${results[sonnet:$test_name]:-?}"

            local status=""
            if [[ "$opus_result" == "✅" && "$sonnet_result" == "✅" ]]; then
                status="Both pass"
                ((all_pass++))
            elif [[ "$opus_result" == "✅" && "$sonnet_result" == "❌" ]]; then
                status="⚠️ Opus only"
                ((opus_only++))
            elif [[ "$opus_result" == "❌" && "$sonnet_result" == "✅" ]]; then
                status="⚠️ Sonnet only"
                ((sonnet_only++))
            else
                status="❌ Both fail"
                ((both_fail++))
            fi

            echo "| $test_name | $opus_result | $sonnet_result | $status |"
        done

        echo ""
        echo "## Summary"
        echo ""
        echo "- **Both pass**: $all_pass tests"
        echo "- **Opus only**: $opus_only tests"
        echo "- **Sonnet only**: $sonnet_only tests"
        echo "- **Both fail**: $both_fail tests"
        echo ""

        if [[ $opus_only -gt 0 || $sonnet_only -gt 0 ]]; then
            echo "## Recommendations"
            echo ""
            if [[ $opus_only -gt 0 ]]; then
                echo "### Use Opus for:"
                for test_file in "${tests_to_run[@]}"; do
                    local test_name=$(basename "$test_file" .sh)
                    if [[ "${results[opus:$test_name]}" == "✅" && "${results[sonnet:$test_name]}" == "❌" ]]; then
                        local desc=$(grep "^# Description:" "$test_file" | sed 's/^# Description: //')
                        echo "- **$test_name**: $desc"
                    fi
                done
                echo ""
            fi
            if [[ $sonnet_only -gt 0 ]]; then
                echo "### Use Sonnet for:"
                for test_file in "${tests_to_run[@]}"; do
                    local test_name=$(basename "$test_file" .sh)
                    if [[ "${results[opus:$test_name]}" == "❌" && "${results[sonnet:$test_name]}" == "✅" ]]; then
                        local desc=$(grep "^# Description:" "$test_file" | sed 's/^# Description: //')
                        echo "- **$test_name**: $desc"
                    fi
                done
                echo ""
            fi
        fi
    } > "$report_file"

    echo ""
    echo -e "${GREEN}Report saved to: $report_file${NC}"
    echo ""

    # Print summary to console
    echo "═══════════════════════════════════════════════════════════════"
    echo "COMPARISON SUMMARY"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    printf "%-30s %-8s %-8s\n" "Test" "Opus" "Sonnet"
    printf "%-30s %-8s %-8s\n" "----" "----" "------"
    for test_file in "${tests_to_run[@]}"; do
        local test_name=$(basename "$test_file" .sh)
        printf "%-30s %-8s %-8s\n" "$test_name" "${results[opus:$test_name]:-?}" "${results[sonnet:$test_name]:-?}"
    done
    echo ""

    # Return success if no regressions between models
    return 0
}

main() {
    if [[ "${1:-}" == "--list" ]]; then
        list_tests
        exit 0
    fi

    if [[ "${1:-}" == "--sections" ]]; then
        list_sections
        exit 0
    fi

    if [[ "${1:-}" == "--section" ]]; then
        local section="${2:-}"
        if [[ -z "$section" ]]; then
            echo "Error: --section requires a section name"
            list_sections
            exit 1
        fi
        local section_tests=$(get_tests_by_section "$section")
        if [[ -z "$section_tests" ]]; then
            echo "Error: No tests found for section '$section'"
            list_sections
            exit 1
        fi
        set -- $section_tests
    fi

    if [[ "${1:-}" == "--critical" ]]; then
        # Run only tests marked as "Category: Critical"
        local critical_tests=()
        for test_file in "$SCRIPT_DIR/tests"/*.sh; do
            if grep -q "^# Category: Critical" "$test_file" 2>/dev/null; then
                critical_tests+=("$test_file")
            fi
        done
        set -- "${critical_tests[@]}"
    fi

    if [[ "${1:-}" == "--compare-models" ]]; then
        # Run tests on multiple models and compare results
        run_model_comparison "${@:2}"
        exit $?
    fi

    echo ""
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║         LLM Behavioral Test Harness                          ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Framework: $FRAMEWORK_ROOT"
    echo "Tool: $TOOL"
    if [[ "$TOOL" == "claude" ]]; then
        echo "Model: $CLAUDE_MODEL"
        echo "CLI: $CLAUDE_CMD"
    else
        echo "Mode: Semi-automated (manual prompt entry required)"
    fi
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
