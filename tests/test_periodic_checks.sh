#!/usr/bin/env bash
# Unit tests for periodic-checks.sh
# Tests state file management, frequency evaluation, session counting

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PERIODIC_SCRIPT="$FRAMEWORK_ROOT/.agentic/tools/periodic-checks.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASSED=0
FAILED=0

test_case() {
    local name="$1"
    echo -n "Testing: $name... "
}

pass() {
    echo -e "${GREEN}PASS${NC}"
    ((PASSED++))
}

fail() {
    local msg="${1:-}"
    echo -e "${RED}FAIL${NC}"
    [[ -n "$msg" ]] && echo "  $msg"
    ((FAILED++))
}

# Create temp test project
setup_test_env() {
    TEST_DIR=$(mktemp -d "/tmp/periodic-test-XXXXXX")
    mkdir -p "$TEST_DIR/.agentic/tools"
    mkdir -p "$TEST_DIR/.agentic/lib"
    mkdir -p "$TEST_DIR/.agentic/presets"
    mkdir -p "$TEST_DIR/.agentic-state"

    # Copy required scripts
    cp "$PERIODIC_SCRIPT" "$TEST_DIR/.agentic/tools/"
    cp "$FRAMEWORK_ROOT/.agentic/lib/settings.sh" "$TEST_DIR/.agentic/lib/"
    cp "$FRAMEWORK_ROOT/.agentic/presets/profiles.conf" "$TEST_DIR/.agentic/presets/"
    cp "$FRAMEWORK_ROOT/.agentic/tools/retro_check.sh" "$TEST_DIR/.agentic/tools/" 2>/dev/null || true

    # Create minimal STACK.md
    cat > "$TEST_DIR/STACK.md" << 'EOF'
## Settings
- profile: discovery
EOF

    cd "$TEST_DIR"
    git init -q 2>/dev/null || true
}

cleanup_test_env() {
    cd "$SCRIPT_DIR"
    [[ -n "${TEST_DIR:-}" ]] && rm -rf "$TEST_DIR"
}

# =============================================================================
# State File Tests
# =============================================================================

test_case "State file creation on first run"
setup_test_env
bash .agentic/tools/periodic-checks.sh --increment > /dev/null 2>&1
if [ -f ".agentic-state/sync-state.conf" ]; then
    pass
else
    fail "sync-state.conf not created"
fi
cleanup_test_env

test_case "Session counter increments"
setup_test_env
result1=$(bash .agentic/tools/periodic-checks.sh --increment 2>/dev/null)
result2=$(bash .agentic/tools/periodic-checks.sh --increment 2>/dev/null)
result3=$(bash .agentic/tools/periodic-checks.sh --increment 2>/dev/null)
if [ "$result3" = "3" ]; then
    pass
else
    fail "Expected session 3, got: $result3"
fi
cleanup_test_env

test_case "State file preserves values across runs"
setup_test_env
bash .agentic/tools/periodic-checks.sh --increment > /dev/null 2>&1
bash .agentic/tools/periodic-checks.sh --increment > /dev/null 2>&1
local_count=$(grep '^session_count=' .agentic-state/sync-state.conf 2>/dev/null | sed 's/session_count=//')
local_sync=$(grep '^last_sync=' .agentic-state/sync-state.conf 2>/dev/null | sed 's/last_sync=//')
if [ "$local_count" = "2" ] && [ -n "$local_sync" ]; then
    pass
else
    fail "count=$local_count, sync=$local_sync"
fi
cleanup_test_env

# =============================================================================
# Frequency Evaluation Tests
# =============================================================================

test_case "Quiet mode: no output when no issues"
setup_test_env
output=$(bash .agentic/tools/periodic-checks.sh --quiet 2>&1)
if [ -z "$output" ]; then
    pass
else
    fail "Expected empty output, got: $output"
fi
cleanup_test_env

test_case "Full mode: reports session number"
setup_test_env
output=$(bash .agentic/tools/periodic-checks.sh 2>&1)
if echo "$output" | grep -q "session #1"; then
    pass
else
    fail "Expected 'session #1' in output: $output"
fi
cleanup_test_env

# =============================================================================
# Orphaned Plan Detection Tests
# =============================================================================

test_case "Graceful when ~/.claude/plans/ doesn't exist"
setup_test_env
output=$(bash .agentic/tools/periodic-checks.sh 2>&1)
exit_code=$?
if [ "$exit_code" -eq 0 ]; then
    pass
else
    fail "Non-zero exit code: $exit_code"
fi
cleanup_test_env

# =============================================================================
# Integration Tests
# =============================================================================

test_case "Multiple runs: session counter increments correctly"
setup_test_env
for i in 1 2 3 4 5; do
    bash .agentic/tools/periodic-checks.sh --increment > /dev/null 2>&1
done
final=$(grep '^session_count=' .agentic-state/sync-state.conf | sed 's/session_count=//')
if [ "$final" = "5" ]; then
    pass
else
    fail "Expected 5, got: $final"
fi
cleanup_test_env

test_case "State file has correct format"
setup_test_env
bash .agentic/tools/periodic-checks.sh --quiet > /dev/null 2>&1
# Verify no empty lines or malformed entries
bad_lines=$(grep -v '^#' .agentic-state/sync-state.conf 2>/dev/null | grep -v '^$' | grep -v '^[a-z_.].*=.*$' | wc -l | tr -d ' ')
if [ "$bad_lines" = "0" ]; then
    pass
else
    fail "$bad_lines malformed lines in state file"
fi
cleanup_test_env

# =============================================================================
# Summary
# =============================================================================

echo ""
echo "========================="
echo "Results: $PASSED passed, $FAILED failed"
echo "========================="

if [ "$FAILED" -gt 0 ]; then
    exit 1
fi
exit 0
