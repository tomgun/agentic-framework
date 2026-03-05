#!/usr/bin/env bash
# Unit tests for check-gates.sh Gate 4 (plan-review gate)
#
# Tests:
#   - Gate 4 passes when plan_review_enabled != yes
#   - Gate 4 fails when plan_review_enabled=yes and no approved plan
#   - Gate 4 passes when plan_review_enabled=yes and approved plan exists

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASSED=0
FAILED=0

test_case() { echo -n "Testing: $1... "; }
pass() { echo -e "${GREEN}PASS${NC}"; ((PASSED++)); }
fail() { echo -e "${RED}FAIL${NC}"; [[ -n "${1:-}" ]] && echo "  $1"; ((FAILED++)); }

GATES_SCRIPT="$FRAMEWORK_ROOT/.claude/skills/implementing-features/scripts/check-gates.sh"

echo ""
echo "=== check-gates.sh Gate 4 (plan-review) ==="
echo ""

# ── Setup temp project ──

setup_gate_env() {
    local test_dir
    test_dir=$(mktemp -d "/tmp/gate-test-XXXXXX")
    cd "$test_dir"

    # Minimal framework structure
    mkdir -p .agentic/tools .agentic/journal/plans spec/acceptance .claude/skills/implementing-features/scripts

    # Copy check-gates.sh
    cp "$GATES_SCRIPT" .claude/skills/implementing-features/scripts/check-gates.sh

    # Create a minimal wip.sh that always succeeds
    cat > .agentic/lib/tools/wip.sh << 'EOF'
#!/bin/bash
[[ "${1:-}" == "check" ]] && exit 0
EOF
    chmod +x .agentic/lib/tools/wip.sh

    # Create feature entry and acceptance
    echo "## F-0050: Test Feature" > spec/FEATURES.md
    echo "# Acceptance" > spec/acceptance/F-0050.md

    echo "$test_dir"
}

cleanup_gate_env() {
    local dir="$1"
    cd "$SCRIPT_DIR"
    [[ -n "$dir" && -d "$dir" && "$dir" == /tmp/gate-test-* ]] && rm -rf "$dir"
}

# ── Test: Gate 4 skips when plan_review_enabled is not yes ──

test_case "Gate 4 skips when plan_review_enabled != yes"
TEST_DIR=$(setup_gate_env)
cd "$TEST_DIR"
cat > "$TEST_DIR/STACK.md" << 'EOF'
plan_review_enabled: no
EOF
output=$(bash "$TEST_DIR/.claude/skills/implementing-features/scripts/check-gates.sh" F-0050 2>&1) && exit_code=0 || exit_code=$?
if [[ $exit_code -eq 0 ]] && echo "$output" | grep -q "Plan review not required"; then
    pass
else
    fail "expected pass with 'Plan review not required' (got exit $exit_code)"
fi
cleanup_gate_env "$TEST_DIR"

# ── Test: Gate 4 skips when STACK.md has no plan_review setting ──

test_case "Gate 4 skips when plan_review_enabled absent"
TEST_DIR=$(setup_gate_env)
cd "$TEST_DIR"
cat > "$TEST_DIR/STACK.md" << 'EOF'
Profile: formal
EOF
output=$(bash "$TEST_DIR/.claude/skills/implementing-features/scripts/check-gates.sh" F-0050 2>&1) && exit_code=0 || exit_code=$?
if [[ $exit_code -eq 0 ]] && echo "$output" | grep -q "Plan review not required"; then
    pass
else
    fail "expected pass when setting absent"
fi
cleanup_gate_env "$TEST_DIR"

# ── Test: Gate 4 fails when plan_review_enabled=yes but no plan ──

test_case "Gate 4 fails without approved plan"
TEST_DIR=$(setup_gate_env)
cd "$TEST_DIR"
cat > "$TEST_DIR/STACK.md" << 'EOF'
plan_review_enabled: yes
EOF
output=$(bash "$TEST_DIR/.claude/skills/implementing-features/scripts/check-gates.sh" F-0050 2>&1) && exit_code=0 || exit_code=$?
if [[ $exit_code -eq 1 ]] && echo "$output" | grep -q "no approved plan"; then
    pass
else
    fail "expected failure with 'no approved plan' (got exit $exit_code)"
fi
cleanup_gate_env "$TEST_DIR"

# ── Test: Gate 4 passes with approved plan ──

test_case "Gate 4 passes with approved plan"
TEST_DIR=$(setup_gate_env)
cd "$TEST_DIR"
cat > "$TEST_DIR/STACK.md" << 'EOF'
plan_review_enabled: yes
EOF
cat > "$TEST_DIR/.agentic/journal/plans/F-0050-test-plan.md" << 'EOF'
# Plan: F-0050

Status: APPROVED

## Steps
1. Do the thing
EOF
output=$(bash "$TEST_DIR/.claude/skills/implementing-features/scripts/check-gates.sh" F-0050 2>&1) && exit_code=0 || exit_code=$?
if [[ $exit_code -eq 0 ]] && echo "$output" | grep -q "Approved plan exists"; then
    pass
else
    fail "expected pass with 'Approved plan exists' (got exit $exit_code)"
fi
cleanup_gate_env "$TEST_DIR"

# ── Test: Gate 4 finds plan with date-prefixed naming convention ──

test_case "Gate 4 finds date-prefixed plan file"
TEST_DIR=$(setup_gate_env)
cd "$TEST_DIR"
cat > "$TEST_DIR/STACK.md" << 'EOF'
plan_review_enabled: yes
EOF
cat > "$TEST_DIR/.agentic/journal/plans/2026-03-01-F-0050-plan.md" << 'EOF'
# Plan

Status: APPROVED
EOF
output=$(bash "$TEST_DIR/.claude/skills/implementing-features/scripts/check-gates.sh" F-0050 2>&1) && exit_code=0 || exit_code=$?
if [[ $exit_code -eq 0 ]] && echo "$output" | grep -q "Approved plan exists"; then
    pass
else
    fail "expected pass with date-prefixed plan naming"
fi
cleanup_gate_env "$TEST_DIR"

# ── Summary ──

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
TOTAL=$((PASSED + FAILED))
if [[ $FAILED -eq 0 ]]; then
    echo -e "${GREEN}ALL $TOTAL TESTS PASSED${NC}"
else
    echo -e "${RED}$FAILED/$TOTAL TESTS FAILED${NC}"
    exit 1
fi
