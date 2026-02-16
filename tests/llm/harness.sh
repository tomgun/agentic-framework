#!/usr/bin/env bash
# LLM Behavioral Test Harness
#
# Runs automated behavioral tests against Claude Code using fresh project contexts.
# Each test creates a temp project, installs framework, sends prompts, checks outcomes.
#
# Usage:
#   bash tests/llm/harness.sh                    # Run all tests
#   bash tests/llm/harness.sh --resume           # Resume from last run (skip passed tests)
#   bash tests/llm/harness.sh --status           # Show current run status
#   bash tests/llm/harness.sh --reset            # Clear saved state, start fresh
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
#   TOOL - AI tool to use: claude (default), codex, cursor, cursor-cli, copilot
#   CLAUDE_MODEL - Model for Claude: opus (default), sonnet, or full model name
#   CLAUDE_CMD - Path to claude CLI (default: claude)
#   CODEX_MODEL - Model for Codex: gpt-5-codex (default), gpt-5-codex-mini
#   CODEX_CMD - Path to codex CLI (default: codex)
#   CURSOR_CMD - Path to cursor agent CLI (default: cursor-agent or agent)
#   KEEP_PROJECTS - Set to "1" to keep temp projects for debugging
#
# Examples:
#   bash tests/llm/harness.sh                              # Claude + Opus
#   CLAUDE_MODEL=sonnet bash tests/llm/harness.sh          # Claude + Sonnet
#   TOOL=codex bash tests/llm/harness.sh                   # Codex (automated)
#   TOOL=cursor-cli bash tests/llm/harness.sh              # Cursor CLI (automated)
#   TOOL=cursor bash tests/llm/harness.sh                  # Cursor IDE (semi-automated)
#   TOOL=copilot bash tests/llm/harness.sh                 # Copilot (semi-automated)
#   bash tests/llm/harness.sh --compare-models --critical  # Compare Opus vs Sonnet

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TOOL="${TOOL:-claude}"
CLAUDE_MODEL="${CLAUDE_MODEL:-opus}"
CLAUDE_CMD="${CLAUDE_CMD:-claude}"
CODEX_MODEL="${CODEX_MODEL:-gpt-5-codex}"
CODEX_CMD="${CODEX_CMD:-codex}"
# Cursor CLI - try cursor-agent first, fall back to agent
CURSOR_CMD="${CURSOR_CMD:-}"
if [[ -z "$CURSOR_CMD" ]]; then
    if command -v cursor-agent &>/dev/null; then
        CURSOR_CMD="cursor-agent"
    elif command -v agent &>/dev/null; then
        CURSOR_CMD="agent"
    else
        CURSOR_CMD="cursor-agent"  # Default, will fail gracefully if not installed
    fi
fi
KEEP_PROJECTS="${KEEP_PROJECTS:-0}"

# Portable timeout: prefer GNU timeout, fall back to gtimeout (macOS + coreutils), then perl
if command -v timeout &>/dev/null; then
    TIMEOUT_CMD="timeout"
elif command -v gtimeout &>/dev/null; then
    TIMEOUT_CMD="gtimeout"
else
    # Pure-bash fallback using background process
    TIMEOUT_CMD=""
fi

run_with_timeout() {
    local secs="$1"; shift
    if [[ -n "$TIMEOUT_CMD" ]]; then
        "$TIMEOUT_CMD" "$secs" "$@"
    else
        # Bash fallback: run in background, kill after timeout
        "$@" &
        local pid=$!
        ( sleep "$secs"; kill "$pid" 2>/dev/null ) &
        local watchdog=$!
        wait "$pid" 2>/dev/null
        local rc=$?
        kill "$watchdog" 2>/dev/null
        wait "$watchdog" 2>/dev/null
        return $rc
    fi
}

# Validate tool
if [[ "$TOOL" != "claude" && "$TOOL" != "codex" && "$TOOL" != "cursor" && "$TOOL" != "cursor-cli" && "$TOOL" != "copilot" ]]; then
    echo "Error: TOOL must be 'claude', 'codex', 'cursor', 'cursor-cli', or 'copilot'"
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

# State persistence for incremental runs
STATE_FILE="$SCRIPT_DIR/.test-state"
RESUME_MODE="${RESUME_MODE:-0}"

#=============================================================================
# State Management Functions
#=============================================================================

# Initialize or load state file
init_state() {
    if [[ ! -f "$STATE_FILE" ]]; then
        echo "# LLM Test State - $(date '+%Y-%m-%d %H:%M')" > "$STATE_FILE"
        echo "# Format: test_name:result (pass|fail|skip|pending)" >> "$STATE_FILE"
        echo "RUN_DATE=$(date '+%Y-%m-%d %H:%M')" >> "$STATE_FILE"
        echo "MODEL=$CLAUDE_MODEL" >> "$STATE_FILE"
    fi
}

# Save test result to state
save_result() {
    local test_name="$1"
    local result="$2"  # pass, fail, rate_limit

    # Remove any existing entry for this test
    if [[ -f "$STATE_FILE" ]]; then
        grep -v "^$test_name:" "$STATE_FILE" > "$STATE_FILE.tmp" || true
        mv "$STATE_FILE.tmp" "$STATE_FILE"
    fi

    # Add new result
    echo "$test_name:$result" >> "$STATE_FILE"
}

# Get test result from state
get_result() {
    local test_name="$1"
    if [[ -f "$STATE_FILE" ]]; then
        grep "^$test_name:" "$STATE_FILE" 2>/dev/null | cut -d: -f2 || echo ""
    fi
}

# Check if test should be skipped (already passed in this run)
should_skip_test() {
    local test_name="$1"
    if [[ "$RESUME_MODE" == "1" ]]; then
        local result=$(get_result "$test_name")
        if [[ "$result" == "pass" ]]; then
            return 0  # Skip - already passed
        fi
    fi
    return 1  # Don't skip
}

# Save durable results report (git-tracked) after a complete run
save_results_report() {
    local passed="$1"
    local failed="$2"
    local total=$(( passed + failed ))

    local results_dir="$SCRIPT_DIR/results"
    mkdir -p "$results_dir"

    local fw_version="unknown"
    if [[ -f "$FRAMEWORK_ROOT/VERSION" ]]; then
        fw_version=$(head -1 "$FRAMEWORK_ROOT/VERSION")
    fi

    local run_date
    run_date=$(date '+%Y-%m-%d')
    local run_time
    run_time=$(date '+%H:%M')
    local filename="${run_date}_${TOOL}.md"
    local filepath="$results_dir/$filename"

    {
        echo "# LLM Test Results: ${TOOL} — ${run_date}"
        echo ""
        echo "| Field | Value |"
        echo "|-------|-------|"
        echo "| **Date** | ${run_date} ${run_time} |"
        echo "| **Framework Version** | ${fw_version} |"
        echo "| **Tool** | ${TOOL} |"
        echo "| **Model** | ${CLAUDE_MODEL:-default} |"
        echo "| **Passed** | ${passed}/${total} |"
        echo "| **Failed** | ${failed}/${total} |"
        echo "| **Pass Rate** | $(( passed * 100 / (total > 0 ? total : 1) ))% |"
        echo ""
        echo "## Per-Test Results"
        echo ""
        echo "| Test | Result |"
        echo "|------|--------|"

        if [[ -f "$STATE_FILE" ]]; then
            grep -E "^[0-9]" "$STATE_FILE" | sort | while IFS=: read -r name result; do
                if [[ "$result" == "pass" ]]; then
                    echo "| ${name} | ✅ |"
                elif [[ "$result" == "fail" ]]; then
                    echo "| ${name} | ❌ |"
                elif [[ "$result" == "rate_limit" ]]; then
                    echo "| ${name} | ⚠️ rate limited |"
                else
                    echo "| ${name} | ${result} |"
                fi
            done
        fi

        echo ""
        echo "---"
        echo "_Generated by \`tests/llm/harness.sh\` — commit this file to track history._"
    } > "$filepath"

    echo ""
    echo -e "${GREEN}Results saved to: ${filepath}${NC}"
    echo -e "${BLUE}Commit with: git add ${filepath} && git commit -m 'test: LLM results ${run_date} ${TOOL}'${NC}"
}

# Show current state status
show_status() {
    if [[ ! -f "$STATE_FILE" ]]; then
        echo "No test run in progress. Start with: bash tests/llm/harness.sh"
        return
    fi

    echo ""
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║         LLM Test Run Status                                   ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo ""

    local run_date=$(grep "^RUN_DATE=" "$STATE_FILE" | cut -d= -f2)
    local model=$(grep "^MODEL=" "$STATE_FILE" | cut -d= -f2)
    echo "Run started: $run_date"
    echo "Model: $model"
    echo ""

    local passed=$(grep ":pass$" "$STATE_FILE" | wc -l | tr -d ' ')
    local failed=$(grep ":fail$" "$STATE_FILE" | wc -l | tr -d ' ')
    local rate_limited=$(grep ":rate_limit$" "$STATE_FILE" | wc -l | tr -d ' ')
    local total_tests=$(ls "$SCRIPT_DIR/tests"/*.sh 2>/dev/null | wc -l | tr -d ' ')
    local completed=$((passed + failed))
    local remaining=$((total_tests - completed))

    echo "Progress: $completed/$total_tests completed"
    echo "  ✓ Passed: $passed"
    echo "  ✗ Failed: $failed"
    if [[ $rate_limited -gt 0 ]]; then
        echo "  ⚠ Rate limited: $rate_limited (will retry on resume)"
    fi
    echo "  ○ Remaining: $remaining"
    echo ""

    if [[ $remaining -gt 0 || $rate_limited -gt 0 ]]; then
        echo "Resume with: bash tests/llm/harness.sh --resume"
    else
        echo "Run complete! Reset with: bash tests/llm/harness.sh --reset"
    fi
    echo ""
}

# Reset state for fresh run
reset_state() {
    if [[ -f "$STATE_FILE" ]]; then
        rm "$STATE_FILE"
        echo "State cleared. Ready for fresh test run."
    else
        echo "No state to clear."
    fi
}

# Detect rate limit in output
detect_rate_limit() {
    local output="$1"
    if echo "$output" | grep -qi "rate.limit\|hit your limit\|too many requests\|quota exceeded\|out of extra usage\|out of.*usage"; then
        return 0  # Rate limited
    fi
    return 1  # Not rate limited
}

#=============================================================================
# Test Helper Functions (available to test scripts)
#=============================================================================

# Create fresh test project with framework installed
setup_test_project() {
    local profile="${1:-discovery}"  # discovery or formal

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
    if [[ "$profile" == "formal" ]]; then
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
            LAST_OUTPUT=$(echo "$prompt" | run_with_timeout 120 $CLAUDE_CMD "${model_args[@]}" 2>&1) || true
        fi

        # Write output to shared file for rate limit detection across subshells
        echo "$LAST_OUTPUT" > "$SCRIPT_DIR/.last-output"

        # Check for rate limit and exit with special code
        if echo "$LAST_OUTPUT" | grep -qi "rate.limit\|hit your limit\|too many requests\|quota exceeded\|out of extra usage\|out of.*usage"; then
            echo -e "${YELLOW}⚠ Rate limit detected in response${NC}"
            exit 2  # Special exit code for rate limit
        fi
    elif [[ "$TOOL" == "codex" ]]; then
        # Fully automated: OpenAI Codex CLI
        # Use codex exec for non-interactive execution
        local -a model_args=()
        if [[ -n "$CODEX_MODEL" ]]; then
            model_args=(-c "model=$CODEX_MODEL")
        fi

        # codex exec runs non-interactively
        LAST_OUTPUT=$(run_with_timeout 120 $CODEX_CMD exec "${model_args[@]}" "$prompt" 2>&1) || true

        # Write output to shared file for rate limit detection across subshells
        echo "$LAST_OUTPUT" > "$SCRIPT_DIR/.last-output"

        # Check for rate limit and exit with special code
        if echo "$LAST_OUTPUT" | grep -qi "rate.limit\|hit your limit\|too many requests\|quota exceeded\|out of extra usage\|out of.*usage"; then
            echo -e "${YELLOW}⚠ Rate limit detected in response${NC}"
            exit 2  # Special exit code for rate limit
        fi
    elif [[ "$TOOL" == "cursor-cli" ]]; then
        # Fully automated: Cursor Agent CLI
        # Uses cursor-agent or agent command for headless execution
        if ! command -v "$CURSOR_CMD" &>/dev/null; then
            echo -e "${RED}Error: Cursor Agent CLI not found ($CURSOR_CMD)${NC}"
            echo "Install from: https://cursor.com/en/blog/cli"
            echo "Or use TOOL=cursor for semi-automated mode"
            exit 1
        fi

        # Run cursor agent in non-interactive print mode with --force to auto-approve
        LAST_OUTPUT=$(run_with_timeout 120 $CURSOR_CMD --print --force --workspace "$TEST_PROJECT" "$prompt" 2>&1) || true

        # Write output to shared file for rate limit detection across subshells
        echo "$LAST_OUTPUT" > "$SCRIPT_DIR/.last-output"

        # Check for rate limit and exit with special code
        if echo "$LAST_OUTPUT" | grep -qi "rate.limit\|hit your limit\|too many requests\|quota exceeded\|out of extra usage\|out of.*usage"; then
            echo -e "${YELLOW}⚠ Rate limit detected in response${NC}"
            exit 2  # Special exit code for rate limit
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
export FRAMEWORK_ROOT CLAUDE_CMD CODEX_CMD CURSOR_CMD TOOL CLAUDE_MODEL CODEX_MODEL SCRIPT_DIR

#=============================================================================
# Test Runner
#=============================================================================

run_test() {
    local test_file="$1"
    local test_name=$(basename "$test_file" .sh)

    # Check if we should skip (resume mode + already passed)
    if should_skip_test "$test_name"; then
        echo -e "${BLUE}Skipping: $test_name${NC} (already passed)"
        return 0
    fi

    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo -e "${BLUE}Running: $test_name${NC}"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""

    # Run test in subshell to isolate state
    local test_result=0
    (source "$test_file") || test_result=$?

    if [[ $test_result -eq 0 ]]; then
        echo ""
        echo -e "${GREEN}══ PASSED: $test_name ══${NC}"
        save_result "$test_name" "pass"
        return 0
    elif [[ $test_result -eq 2 ]]; then
        # Rate limit detected (exit code 2 from send_prompt)
        echo ""
        echo -e "${YELLOW}══ RATE LIMITED: $test_name ══${NC}"
        save_result "$test_name" "rate_limit"
        return 2
    else
        # Check shared output file for rate limit (backup detection)
        if [[ -f "$SCRIPT_DIR/.last-output" ]] && detect_rate_limit "$(cat "$SCRIPT_DIR/.last-output")"; then
            echo ""
            echo -e "${YELLOW}══ RATE LIMITED: $test_name ══${NC}"
            save_result "$test_name" "rate_limit"
            return 2
        fi
        echo ""
        echo -e "${RED}══ FAILED: $test_name ══${NC}"
        save_result "$test_name" "fail"
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

    if [[ "${1:-}" == "--status" ]]; then
        show_status
        exit 0
    fi

    if [[ "${1:-}" == "--reset" ]]; then
        reset_state
        exit 0
    fi

    if [[ "${1:-}" == "--resume" ]]; then
        RESUME_MODE=1
        shift
        if [[ ! -f "$STATE_FILE" ]]; then
            echo "No previous run to resume. Starting fresh."
        else
            echo -e "${BLUE}Resuming from previous run (skipping passed tests)${NC}"
        fi
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
    elif [[ "$TOOL" == "codex" ]]; then
        echo "Model: $CODEX_MODEL"
        echo "CLI: $CODEX_CMD"
    elif [[ "$TOOL" == "cursor-cli" ]]; then
        echo "CLI: $CURSOR_CMD"
    else
        echo "Mode: Semi-automated (manual prompt entry required)"
        echo "Tip: For automated mode, use: TOOL=claude, TOOL=codex, or TOOL=cursor-cli"
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

    # Initialize state tracking
    if [[ "$RESUME_MODE" != "1" ]]; then
        # Fresh run - reset state
        rm -f "$STATE_FILE"
    fi
    init_state

    local skipped=0
    local rate_limited=0

    for test_file in "${tests_to_run[@]}"; do
        local test_name=$(basename "$test_file" .sh)

        # Count already-passed tests as skipped
        if should_skip_test "$test_name"; then
            ((skipped++))
            ((passed++))
            echo -e "${BLUE}Skipping: $test_name${NC} (already passed)"
            continue
        fi

        local result=0
        run_test "$test_file" || result=$?

        if [[ $result -eq 0 ]]; then
            ((passed++))
        elif [[ $result -eq 2 ]]; then
            # Rate limited - stop running more tests
            ((rate_limited++))
            echo ""
            echo -e "${YELLOW}Stopping due to rate limit. Progress saved.${NC}"
            echo -e "${YELLOW}Resume later with: bash tests/llm/harness.sh --resume${NC}"
            break
        else
            ((failed++))
        fi
    done

    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "RESULTS: $passed passed, $failed failed ($(( passed + failed )) total)"
    if [[ $skipped -gt 0 ]]; then
        echo "  (including $skipped skipped from previous run)"
    fi
    if [[ $rate_limited -gt 0 ]]; then
        echo ""
        echo -e "${YELLOW}Rate limit hit. Resume with: bash tests/llm/harness.sh --resume${NC}"
    fi
    echo "═══════════════════════════════════════════════════════════════"

    # Save durable results report (git-tracked)
    if [[ $rate_limited -eq 0 ]]; then
        save_results_report "$passed" "$failed"
    fi

    [[ $failed -eq 0 && $rate_limited -eq 0 ]]
}

# Only run main if not being sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
