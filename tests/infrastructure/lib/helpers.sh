#!/usr/bin/env bash
# helpers.sh — Shared functions for infrastructure validation tests
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
DIM='\033[2m'
NC='\033[0m'

FRAMEWORK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
TESTS_PASSED=0
TESTS_FAILED=0
TEST_NAME=""

# ─── Test output ───

section_header() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

pass_test() {
    local msg="${1:-$TEST_NAME}"
    echo -e "  ${GREEN}PASS${NC} $msg"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

fail_test() {
    local msg="${1:-$TEST_NAME}"
    local detail="${2:-}"
    echo -e "  ${RED}FAIL${NC} $msg"
    [[ -n "$detail" ]] && echo -e "       ${DIM}$detail${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

skip_test() {
    local msg="${1:-$TEST_NAME}"
    echo -e "  ${YELLOW}SKIP${NC} $msg"
}

# ─── Assertions ───

assert_exit_code() {
    local expected="$1"
    local actual="$2"
    local msg="${3:-exit code should be $expected}"
    if [[ "$actual" -eq "$expected" ]]; then
        pass_test "$msg"
    else
        fail_test "$msg" "expected exit $expected, got $actual"
    fi
}

assert_output_contains() {
    local output="$1"
    local pattern="$2"
    local msg="${3:-output contains '$pattern'}"
    if echo "$output" | grep -qi "$pattern"; then
        pass_test "$msg"
    else
        fail_test "$msg" "pattern not found in output"
    fi
}

assert_output_not_contains() {
    local output="$1"
    local pattern="$2"
    local msg="${3:-output does not contain '$pattern'}"
    if echo "$output" | grep -qi "$pattern"; then
        fail_test "$msg" "unwanted pattern found in output"
    else
        pass_test "$msg"
    fi
}

assert_file_exists() {
    local filepath="$1"
    local msg="${2:-file exists: $filepath}"
    if [[ -f "$filepath" ]]; then
        pass_test "$msg"
    else
        fail_test "$msg"
    fi
}

assert_file_executable() {
    local filepath="$1"
    local msg="${2:-file is executable: $filepath}"
    if [[ -x "$filepath" ]]; then
        pass_test "$msg"
    else
        fail_test "$msg"
    fi
}

# ─── Scaffold ───

scaffold_test_project() {
    local profile="${1:-discovery}"  # discovery or formal

    local test_dir
    test_dir=$(mktemp -d "/tmp/infra-test-XXXXXX")

    cd "$test_dir"
    git init --quiet
    git config user.email "test@example.com"
    git config user.name "Test User"

    # Ensure CI detection doesn't skip hooks
    unset CI GITHUB_ACTIONS GITLAB_CI JENKINS_URL BUILDKITE 2>/dev/null || true

    # Install framework (non-interactive)
    echo "n" | bash "$FRAMEWORK_ROOT/install.sh" . >/dev/null 2>&1

    # Profile-specific setup
    if [[ "$profile" == "formal" ]]; then
        mkdir -p spec/contracts spec/acceptance
        echo "# Features" > spec/FEATURES.md
    fi

    # Create durable artifacts so staleness checks can work
    mkdir -p .agentic-journal
    echo "# Journal" > .agentic/journal/JOURNAL.md
    echo "# Status" > STATUS.md

    # Initial commit
    git add -A
    git commit -m "Initial setup" --quiet --no-verify

    echo "$test_dir"
}

# attempt_commit: makes a trivial change, touches JOURNAL + STATUS, commits
# Returns exit code from git commit
attempt_commit() {
    local project_dir="${1:-.}"
    cd "$project_dir"

    # Make a trivial change
    echo "// change $(date +%s)" >> dummy.txt

    # Touch journal and status so staleness checks pass
    touch .agentic/journal/JOURNAL.md
    touch STATUS.md

    # Small sleep to ensure mtime > last commit time
    sleep 1

    git add -A

    local output exit_code
    output=$(git commit -m "test commit" 2>&1) && exit_code=0 || exit_code=$?

    echo "$output"
    return $exit_code
}

# attempt_commit_raw: makes a trivial change but does NOT touch JOURNAL/STATUS
# For testing staleness checks
attempt_commit_raw() {
    local project_dir="${1:-.}"
    cd "$project_dir"

    # Make a trivial change
    echo "// change $(date +%s)" >> dummy.txt

    git add -A

    local output exit_code
    output=$(git commit -m "test commit" 2>&1) && exit_code=0 || exit_code=$?

    echo "$output"
    return $exit_code
}

# ─── Cleanup ───

cleanup_test_project() {
    local project_dir="$1"
    if [[ -n "$project_dir" && -d "$project_dir" && "$project_dir" == /tmp/infra-test-* ]]; then
        rm -rf "$project_dir"
    fi
}

# ─── Summary ───

print_summary() {
    local total=$((TESTS_PASSED + TESTS_FAILED))
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}  ALL $total TESTS PASSED${NC}"
    else
        echo -e "${RED}  $TESTS_FAILED/$total TESTS FAILED${NC}"
    fi
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    return $TESTS_FAILED
}
