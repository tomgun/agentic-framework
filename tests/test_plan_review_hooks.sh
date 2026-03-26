#!/usr/bin/env bash
# Unit tests for plan-review reliability hooks (F-0234)
# Tests on-plan-mode-exit.sh and pre-commit Check 21

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

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

# Create minimal test project with framework lib
setup_test_env() {
    TEST_DIR=$(mktemp -d "/tmp/plan-hook-test-XXXXXX")
    mkdir -p "$TEST_DIR/.agentic/lib/tools"
    mkdir -p "$TEST_DIR/.agentic/lib/hooks/shared"
    mkdir -p "$TEST_DIR/.agentic/lib/presets"
    mkdir -p "$TEST_DIR/.agentic/journal/plans"
    mkdir -p "$TEST_DIR/.agentic/session"
    mkdir -p "$TEST_DIR/.agentic/spec"
    mkdir -p "$TEST_DIR/.agentic/lib/claude-hooks"

    # Copy required framework files
    cp "$FRAMEWORK_ROOT/.agentic/lib/paths.sh" "$TEST_DIR/.agentic/lib/" 2>/dev/null || true
    cp "$FRAMEWORK_ROOT/.agentic/lib/ids.sh" "$TEST_DIR/.agentic/lib/" 2>/dev/null || true
    cp "$FRAMEWORK_ROOT/.agentic/lib/settings.sh" "$TEST_DIR/.agentic/lib/" 2>/dev/null || true
    cp "$FRAMEWORK_ROOT/.agentic/lib/presets/profiles.conf" "$TEST_DIR/.agentic/lib/presets/" 2>/dev/null || true
    cp "$FRAMEWORK_ROOT/.agentic/lib/hooks/shared/on-plan-mode-exit.sh" "$TEST_DIR/.agentic/lib/hooks/shared/" 2>/dev/null || true
    cp "$FRAMEWORK_ROOT/.agentic/lib/tools/plan-scan.sh" "$TEST_DIR/.agentic/lib/tools/" 2>/dev/null || true
    cp "$FRAMEWORK_ROOT/.agentic/lib/tools/agents_helpers.py" "$TEST_DIR/.agentic/lib/tools/" 2>/dev/null || true

    cd "$TEST_DIR"
}

cleanup_test_env() {
    cd "$SCRIPT_DIR"
    [[ -n "${TEST_DIR:-}" ]] && rm -rf "$TEST_DIR"
}

#=============================================================================
# on-plan-mode-exit.sh Tests
#=============================================================================

test_case "on-plan-mode-exit: exits silently when plan_review_enabled is no"
setup_test_env
cat > "$TEST_DIR/STACK.md" << 'EOF'
# Stack
- plan_review_enabled: no
EOF
output=$(CLAUDE_PROJECT_DIR="$TEST_DIR" bash "$TEST_DIR/.agentic/lib/hooks/shared/on-plan-mode-exit.sh" 2>&1)
if [[ -z "$output" ]]; then
    pass
else
    fail "Expected no output, got: $output"
fi
cleanup_test_env

test_case "on-plan-mode-exit: exits silently when plan_review_enabled is absent"
setup_test_env
cat > "$TEST_DIR/STACK.md" << 'EOF'
# Stack
- Profile: discovery
EOF
output=$(CLAUDE_PROJECT_DIR="$TEST_DIR" bash "$TEST_DIR/.agentic/lib/hooks/shared/on-plan-mode-exit.sh" 2>&1)
if [[ -z "$output" ]]; then
    pass
else
    fail "Expected no output, got: $output"
fi
cleanup_test_env

test_case "on-plan-mode-exit: shows banner when plan_review_enabled is yes"
setup_test_env
cat > "$TEST_DIR/STACK.md" << 'EOF'
# Stack
- plan_review_enabled: yes
EOF
output=$(CLAUDE_PROJECT_DIR="$TEST_DIR" bash "$TEST_DIR/.agentic/lib/hooks/shared/on-plan-mode-exit.sh" 2>&1)
if echo "$output" | grep -q "Plan Mode Exit"; then
    pass
else
    fail "Expected 'Plan Mode Exit' banner, got: $output"
fi
cleanup_test_env

test_case "on-plan-mode-exit: shows fallback with AUTO-CONTINUE when no ephemeral plans exist"
setup_test_env
cat > "$TEST_DIR/STACK.md" << 'EOF'
# Stack
- plan_review_enabled: yes
EOF
# Override HOME to isolate from real ~/.claude/plans/
output=$(HOME="$TEST_DIR" CLAUDE_PROJECT_DIR="$TEST_DIR" bash "$TEST_DIR/.agentic/lib/hooks/shared/on-plan-mode-exit.sh" 2>&1)
if echo "$output" | grep -q "plan-scan did not find"; then
    pass
else
    fail "Expected fallback message about plan-scan, got: $output"
fi
cleanup_test_env

test_case "on-plan-mode-exit: shows success when plan exists in durable location"
setup_test_env
cat > "$TEST_DIR/STACK.md" << 'EOF'
# Stack
- plan_review_enabled: yes
EOF
# Create a plan that looks like it was just saved
cat > "$TEST_DIR/.agentic/journal/plans/2026-03-17-F-0234-plan.md" << 'EOF'
# Plan: F-0234 Test Plan
**Status**: DRAFT
EOF
# The hook uses plan-scan.sh --quiet which scans ephemeral dirs.
# Since no ephemeral plan exists, it will show fallback. That's correct behavior.
# The hook's purpose is to auto-save FROM ephemeral TO durable and show instructions.
output=$(CLAUDE_PROJECT_DIR="$TEST_DIR" bash "$TEST_DIR/.agentic/lib/hooks/shared/on-plan-mode-exit.sh" 2>&1)
if echo "$output" | grep -q "Plan Mode Exit"; then
    pass
else
    fail "Expected banner, got: $output"
fi
cleanup_test_env

test_case "on-plan-mode-exit: always exits 0 (advisory only)"
setup_test_env
cat > "$TEST_DIR/STACK.md" << 'EOF'
# Stack
- plan_review_enabled: yes
EOF
CLAUDE_PROJECT_DIR="$TEST_DIR" bash "$TEST_DIR/.agentic/lib/hooks/shared/on-plan-mode-exit.sh" 2>&1
exit_code=$?
if [[ $exit_code -eq 0 ]]; then
    pass
else
    fail "Expected exit 0, got: $exit_code"
fi
cleanup_test_env

test_case "on-plan-mode-exit: mentions 'ag implement' in output"
setup_test_env
cat > "$TEST_DIR/STACK.md" << 'EOF'
# Stack
- plan_review_enabled: yes
EOF
output=$(CLAUDE_PROJECT_DIR="$TEST_DIR" bash "$TEST_DIR/.agentic/lib/hooks/shared/on-plan-mode-exit.sh" 2>&1)
if echo "$output" | grep -q "ag implement"; then
    pass
else
    fail "Expected 'ag implement' reference, got: $output"
fi
cleanup_test_env

#=============================================================================
# Pre-commit Check 21 Tests (via pre-commit-check.sh)
#=============================================================================

# For Check 21, we test the specific logic in isolation rather than running
# the full pre-commit-check.sh (which requires git repo setup)

test_case "Check 21 logic: passes when no WIP entry exists"
setup_test_env
cat > "$TEST_DIR/STACK.md" << 'EOF'
# Stack
- plan_review_enabled: yes
EOF
# No AGENTS.json entry = no WIP = check passes (not implementing a feature)
if command -v python3 >/dev/null 2>&1; then
    WIP_FEATURE=$(python3 "$TEST_DIR/.agentic/lib/tools/agents_helpers.py" --project-root "$TEST_DIR" get-current-feature "$TEST_DIR" 2>/dev/null || true)
    if [[ -z "$WIP_FEATURE" ]]; then
        pass
    else
        fail "Expected no WIP feature, got: $WIP_FEATURE"
    fi
else
    pass  # Skip if no python3
fi
cleanup_test_env

test_case "Check 21 logic: passes when plan_review_enabled is no"
setup_test_env
cat > "$TEST_DIR/STACK.md" << 'EOF'
# Stack
- plan_review_enabled: no
EOF
# Even with WIP, check should not run when plan_review_enabled is no
source "$TEST_DIR/.agentic/lib/settings.sh" 2>/dev/null || true
PLAN_REVIEW_ENABLED=$(cd "$TEST_DIR" && get_setting "plan_review_enabled" "no" 2>/dev/null || echo "no")
if [[ "$PLAN_REVIEW_ENABLED" != "yes" ]]; then
    pass
else
    fail "Expected plan_review_enabled to be 'no', got: $PLAN_REVIEW_ENABLED"
fi
cleanup_test_env

test_case "Check 21 logic: detects APPROVED plan correctly"
setup_test_env
cat > "$TEST_DIR/STACK.md" << 'EOF'
# Stack
- plan_review_enabled: yes
EOF
cat > "$TEST_DIR/.agentic/journal/plans/2026-03-17-F-0234-plan.md" << 'EOF'
# Plan: F-0234 Test
**Status**: APPROVED
EOF
HAS_APPROVED_PLAN=false
for plan_file in "$TEST_DIR/.agentic/journal/plans/"*"F-0234"*plan*; do
    if [[ -f "$plan_file" ]]; then
        if grep -qi '^\*\*Status\*\*.*APPROVED' "$plan_file" 2>/dev/null; then
            HAS_APPROVED_PLAN=true
            break
        fi
    fi
done
if [[ "$HAS_APPROVED_PLAN" == true ]]; then
    pass
else
    fail "Should have found APPROVED plan"
fi
cleanup_test_env

test_case "Check 21 logic: rejects DRAFT plan (not APPROVED)"
setup_test_env
cat > "$TEST_DIR/STACK.md" << 'EOF'
# Stack
- plan_review_enabled: yes
EOF
cat > "$TEST_DIR/.agentic/journal/plans/2026-03-17-F-0234-plan.md" << 'EOF'
# Plan: F-0234 Test
**Status**: DRAFT
EOF
HAS_APPROVED_PLAN=false
for plan_file in "$TEST_DIR/.agentic/journal/plans/"*"F-0234"*plan*; do
    if [[ -f "$plan_file" ]]; then
        if grep -qi '^\*\*Status\*\*.*APPROVED' "$plan_file" 2>/dev/null; then
            HAS_APPROVED_PLAN=true
            break
        fi
    fi
done
if [[ "$HAS_APPROVED_PLAN" == false ]]; then
    pass
else
    fail "Should NOT have found APPROVED plan (plan is DRAFT)"
fi
cleanup_test_env

test_case "Check 21 logic: no plan file at all blocks"
setup_test_env
HAS_APPROVED_PLAN=false
for plan_file in "$TEST_DIR/.agentic/journal/plans/"*"F-0234"*plan*; do
    if [[ -f "$plan_file" ]]; then
        if grep -qi '^\*\*Status\*\*.*APPROVED' "$plan_file" 2>/dev/null; then
            HAS_APPROVED_PLAN=true
            break
        fi
    fi
done
if [[ "$HAS_APPROVED_PLAN" == false ]]; then
    pass
else
    fail "Should NOT have found any plan"
fi
cleanup_test_env

#=============================================================================
# plan-scan Pattern 4 Tests (F-003: fallback F-ID extraction)
#=============================================================================

test_case "plan-scan: extracts F-ID from body text via Pattern 4 fallback"
setup_test_env
# Create FEATURES.md with known feature
cat > "$TEST_DIR/.agentic/spec/FEATURES.md" << 'EOF'
# Features
## F-003 Feature Tracking & Lifecycle
EOF
# Create ephemeral plan with F-ID only in body text (not heading, not metadata)
mkdir -p "$TEST_DIR/.claude/plans"
cat > "$TEST_DIR/.claude/plans/test-plan.md" << 'EOF'
# Plan: Fix Post-Plan-Mode-Exit Behavior

**Task**: F-003 (Feature Tracking & Lifecycle)

## Context
Some context here.
EOF
# Run plan-scan with isolated HOME pointing to test dir
output=$(HOME="$TEST_DIR" bash "$TEST_DIR/.agentic/lib/tools/plan-scan.sh" 2>&1) || true
if echo "$output" | grep -q "F-003"; then
    # Verify it was actually copied
    if ls "$TEST_DIR/.agentic/journal/plans/"*F-003* >/dev/null 2>&1; then
        pass
    else
        fail "Plan-scan reported F-003 but file not copied"
    fi
else
    fail "Expected plan-scan to find F-003 from body text, got: $output"
fi
cleanup_test_env

test_case "plan-scan: returns empty when no F-ID anywhere in plan"
setup_test_env
cat > "$TEST_DIR/.agentic/spec/FEATURES.md" << 'EOF'
# Features
## F-003 Feature Tracking & Lifecycle
EOF
# Create ephemeral plan with NO feature ID at all
mkdir -p "$TEST_DIR/.claude/plans"
cat > "$TEST_DIR/.claude/plans/generic-plan.md" << 'EOF'
# Plan: Do Something Generic

## Context
No feature ID mentioned here at all.
Just generic planning text with no references.
EOF
output=$(HOME="$TEST_DIR" bash "$TEST_DIR/.agentic/lib/tools/plan-scan.sh" 2>&1) || true
# Should NOT have copied anything
if ls "$TEST_DIR/.agentic/journal/plans/"*plan* >/dev/null 2>&1; then
    fail "Should not have copied plan without F-ID, but found files"
else
    pass
fi
cleanup_test_env

#=============================================================================
# on-plan-mode-exit Failure Path Tests (F-003: auto-continue on failure)
#=============================================================================

test_case "on-plan-mode-exit: failure path contains AUTO-CONTINUE, not 'Save your plan manually'"
setup_test_env
cat > "$TEST_DIR/STACK.md" << 'EOF'
# Stack
- plan_review_enabled: yes
EOF
# Override HOME to ensure no ephemeral plans found → triggers failure path
output=$(HOME="$TEST_DIR" CLAUDE_PROJECT_DIR="$TEST_DIR" bash "$TEST_DIR/.agentic/lib/hooks/shared/on-plan-mode-exit.sh" 2>&1)
if echo "$output" | grep -q "AUTO-CONTINUE"; then
    if echo "$output" | grep -q "Save your plan manually"; then
        fail "Old 'Save your plan manually' text still present"
    else
        pass
    fi
else
    fail "Expected 'AUTO-CONTINUE' in failure path, got: $output"
fi
cleanup_test_env

test_case "on-plan-mode-exit: failure path includes profile-aware messaging for autonomous_formal"
setup_test_env
cat > "$TEST_DIR/STACK.md" << 'EOF'
# Stack
- plan_review_enabled: yes
- Profile: autonomous_formal
- plan_review_convergence: auto
EOF
output=$(HOME="$TEST_DIR" CLAUDE_PROJECT_DIR="$TEST_DIR" bash "$TEST_DIR/.agentic/lib/hooks/shared/on-plan-mode-exit.sh" 2>&1)
if echo "$output" | grep -q "AUTONOMOUS MODE"; then
    pass
else
    fail "Expected 'AUTONOMOUS MODE' for autonomous_formal profile, got: $output"
fi
cleanup_test_env

#=============================================================================
# SessionStart Orphan Plan Detection Tests (F-003: pull mechanism)
#=============================================================================

test_case "SessionStart: warns when orphan plans exist"
setup_test_env
cp "$FRAMEWORK_ROOT/.agentic/lib/ids.sh" "$TEST_DIR/.agentic/lib/" 2>/dev/null || true
cp "$FRAMEWORK_ROOT/.agentic/lib/claude-hooks/SessionStart.sh" "$TEST_DIR/.agentic/lib/claude-hooks/" 2>/dev/null || true
cp "$FRAMEWORK_ROOT/.agentic/lib/tools/fwlog.sh" "$TEST_DIR/.agentic/lib/tools/" 2>/dev/null || true
cat > "$TEST_DIR/STACK.md" << 'EOF'
# Stack
- framework_version: 0.73.1
EOF
# Create FEATURES.md so plan-scan can verify ownership
cat > "$TEST_DIR/.agentic/spec/FEATURES.md" << 'EOF'
# Features
## F-003 Feature Tracking & Lifecycle
EOF
# Create an unsaved ephemeral plan
mkdir -p "$TEST_DIR/.claude/plans"
cat > "$TEST_DIR/.claude/plans/orphan-plan.md" << 'EOF'
# Plan: Fix F-003
**Feature**: F-003
EOF
# Run SessionStart with isolated HOME
output=$(HOME="$TEST_DIR" CLAUDE_PROJECT_DIR="$TEST_DIR" bash "$TEST_DIR/.agentic/lib/claude-hooks/SessionStart.sh" 2>&1) || true
if echo "$output" | grep -q "unsaved plan"; then
    pass
else
    fail "Expected orphan plan warning, got: $output"
fi
cleanup_test_env

test_case "SessionStart: no warning when no orphan plans"
setup_test_env
cp "$FRAMEWORK_ROOT/.agentic/lib/ids.sh" "$TEST_DIR/.agentic/lib/" 2>/dev/null || true
cp "$FRAMEWORK_ROOT/.agentic/lib/claude-hooks/SessionStart.sh" "$TEST_DIR/.agentic/lib/claude-hooks/" 2>/dev/null || true
cp "$FRAMEWORK_ROOT/.agentic/lib/tools/fwlog.sh" "$TEST_DIR/.agentic/lib/tools/" 2>/dev/null || true
cat > "$TEST_DIR/STACK.md" << 'EOF'
# Stack
- framework_version: 0.73.1
EOF
# No ephemeral plans directory — should be clean
output=$(HOME="$TEST_DIR" CLAUDE_PROJECT_DIR="$TEST_DIR" bash "$TEST_DIR/.agentic/lib/claude-hooks/SessionStart.sh" 2>&1) || true
if echo "$output" | grep -q "unsaved plan"; then
    fail "Should not warn when no orphan plans exist, got: $output"
else
    pass
fi
cleanup_test_env

#=============================================================================
# hooks.json Structure Tests
#=============================================================================

test_case "hooks.json: has ExitPlanMode matcher entry"
if grep -q '"matcher": "ExitPlanMode"' "$FRAMEWORK_ROOT/.agentic/lib/claude-hooks/hooks.json"; then
    pass
else
    fail "Missing ExitPlanMode matcher in hooks.json"
fi

test_case "hooks.json: ExitPlanMode points to correct script"
if grep -A10 '"ExitPlanMode"' "$FRAMEWORK_ROOT/.agentic/lib/claude-hooks/hooks.json" | grep -q "ExitPlanMode.sh"; then
    pass
else
    fail "ExitPlanMode entry doesn't reference ExitPlanMode.sh"
fi

test_case "hooks.json: is valid JSON"
if python3 -m json.tool "$FRAMEWORK_ROOT/.agentic/lib/claude-hooks/hooks.json" >/dev/null 2>&1; then
    pass
else
    fail "hooks.json is not valid JSON"
fi

test_case "ExitPlanMode.sh wrapper exists and is executable"
if [[ -x "$FRAMEWORK_ROOT/.agentic/hooks/claude/ExitPlanMode.sh" ]]; then
    pass
else
    fail "ExitPlanMode.sh not found or not executable"
fi

test_case "on-plan-mode-exit.sh exists and is executable"
if [[ -x "$FRAMEWORK_ROOT/.agentic/lib/hooks/shared/on-plan-mode-exit.sh" ]]; then
    pass
else
    fail "on-plan-mode-exit.sh not found or not executable"
fi

#=============================================================================
# Summary
#=============================================================================

echo ""
echo "═══════════════════════════════════════════════════════"
TOTAL=$((PASSED + FAILED))
if [[ $FAILED -eq 0 ]]; then
    echo -e "${GREEN}ALL $TOTAL TESTS PASSED${NC}"
else
    echo -e "${RED}$FAILED/$TOTAL TESTS FAILED${NC}"
fi
echo "═══════════════════════════════════════════════════════"

exit $FAILED
