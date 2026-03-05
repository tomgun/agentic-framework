#!/usr/bin/env bash
# Unit tests for ag.sh gateway script
# Tests profile detection and command behavior

set -uo pipefail
# Note: Not using -e because we handle failures manually

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
AG_SCRIPT="$FRAMEWORK_ROOT/.agentic/lib/tools/ag.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0

# Test helper
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
    TEST_DIR=$(mktemp -d "/tmp/ag-test-XXXXXX")
    mkdir -p "$TEST_DIR/.agentic/tools"
    cp "$AG_SCRIPT" "$TEST_DIR/.agentic/lib/tools/ag.sh"
    cp "$FRAMEWORK_ROOT/.agentic/lib/tools/list-tools.sh" "$TEST_DIR/.agentic/lib/tools/" 2>/dev/null || true
    cp "$FRAMEWORK_ROOT/.agentic/lib/tools/wip.sh" "$TEST_DIR/.agentic/lib/tools/" 2>/dev/null || true
    cd "$TEST_DIR"
}

cleanup_test_env() {
    cd "$SCRIPT_DIR"  # Return to script dir before cleanup
    [[ -n "${TEST_DIR:-}" ]] && rm -rf "$TEST_DIR"
}

#=============================================================================
# Profile Detection Tests
#=============================================================================

test_case "Profile detection: Discovery from STACK.md"
setup_test_env
cat > "$TEST_DIR/STACK.md" << 'EOF'
# Stack
Profile: discovery
EOF
output=$(bash "$TEST_DIR/.agentic/lib/tools/ag.sh" help 2>&1)
if echo "$output" | grep -qi "Discovery Profile"; then
    pass
else
    fail "Expected 'Discovery Profile' in output"
fi
cleanup_test_env

test_case "Profile detection: Formal from STACK.md"
setup_test_env
cat > "$TEST_DIR/STACK.md" << 'EOF'
# Stack
Profile: formal
EOF
output=$(bash "$TEST_DIR/.agentic/lib/tools/ag.sh" help 2>&1)
if echo "$output" | grep -qi "Formal Profile"; then
    pass
else
    fail "Expected 'Formal Profile' in output"
fi
cleanup_test_env

test_case "Profile detection: Formal from spec/ directory"
setup_test_env
mkdir -p "$TEST_DIR/spec"
output=$(bash "$TEST_DIR/.agentic/lib/tools/ag.sh" help 2>&1)
if echo "$output" | grep -qi "Formal Profile"; then
    pass
else
    fail "Expected 'Formal Profile' from spec/ directory"
fi
cleanup_test_env

test_case "Profile detection: Default to Discovery when no indicators"
setup_test_env
output=$(bash "$TEST_DIR/.agentic/lib/tools/ag.sh" help 2>&1)
if echo "$output" | grep -qi "Discovery Profile"; then
    pass
else
    fail "Expected default 'Discovery Profile'"
fi
cleanup_test_env

#=============================================================================
# Help Command Tests
#=============================================================================

test_case "Help shows ag work for Discovery profile"
setup_test_env
cat > "$TEST_DIR/STACK.md" << 'EOF'
Profile: discovery
EOF
output=$(bash "$TEST_DIR/.agentic/lib/tools/ag.sh" help 2>&1)
if echo "$output" | grep -q "ag work"; then
    pass
else
    fail "Discovery help should show 'ag work'"
fi
cleanup_test_env

test_case "Help shows ag implement for Formal profile"
setup_test_env
mkdir -p "$TEST_DIR/spec"
output=$(bash "$TEST_DIR/.agentic/lib/tools/ag.sh" help 2>&1)
if echo "$output" | grep -q "ag implement"; then
    pass
else
    fail "Formal help should show 'ag implement'"
fi
cleanup_test_env

#=============================================================================
# Work Command Tests (Core profile)
#=============================================================================

test_case "ag work creates WIP.md in Discovery profile"
setup_test_env
cat > "$TEST_DIR/STACK.md" << 'EOF'
Profile: core
EOF
mkdir -p "$TEST_DIR/.agentic"
bash "$TEST_DIR/.agentic/lib/tools/ag.sh" work "Test task" >/dev/null 2>&1 || true
if [[ -f "$TEST_DIR/.agentic/session/WIP.md" ]]; then
    pass
else
    fail "WIP.md not created"
fi
cleanup_test_env

#=============================================================================
# Commit Command Tests (Profile-Aware)
#=============================================================================

test_case "ag commit: Discovery profile shows WARNING for WIP"
setup_test_env
cat > "$TEST_DIR/STACK.md" << 'EOF'
Profile: discovery
EOF
mkdir -p "$TEST_DIR/.agentic" "$TEST_DIR/.agentic-state"
echo "test" > "$TEST_DIR/.agentic/session/WIP.md"
output=$(bash "$TEST_DIR/.agentic/lib/tools/ag.sh" commit 2>&1) || true
if echo "$output" | grep -q "WARNING"; then
    pass
else
    fail "Discovery mode should show WARNING for WIP"
fi
cleanup_test_env

test_case "ag commit: Formal profile shows BLOCKED for WIP"
setup_test_env
mkdir -p "$TEST_DIR/spec"
mkdir -p "$TEST_DIR/.agentic" "$TEST_DIR/.agentic-state"
echo "test" > "$TEST_DIR/.agentic/session/WIP.md"
output=$(bash "$TEST_DIR/.agentic/lib/tools/ag.sh" commit 2>&1) || true
if echo "$output" | grep -q "BLOCKED"; then
    pass
else
    fail "Formal mode should show BLOCKED for WIP"
fi
cleanup_test_env

test_case "ag commit: Formal exits non-zero when blocked"
setup_test_env
mkdir -p "$TEST_DIR/spec"
mkdir -p "$TEST_DIR/.agentic" "$TEST_DIR/.agentic-state"
echo "test" > "$TEST_DIR/.agentic/session/WIP.md"
result=0
bash "$TEST_DIR/.agentic/lib/tools/ag.sh" commit >/dev/null 2>&1 || result=$?
if [[ $result -ne 0 ]]; then
    pass
else
    fail "Should exit non-zero when blocked"
fi
cleanup_test_env

#=============================================================================
# Tools Command Tests
#=============================================================================

test_case "ag tools runs without error"
setup_test_env
# Create a minimal list-tools.sh
cat > "$TEST_DIR/.agentic/lib/tools/list-tools.sh" << 'EOF'
#!/usr/bin/env bash
echo "Tools available"
EOF
chmod +x "$TEST_DIR/.agentic/lib/tools/list-tools.sh"
result=0
bash "$TEST_DIR/.agentic/lib/tools/ag.sh" tools >/dev/null 2>&1 || result=$?
if [[ $result -eq 0 ]]; then
    pass
else
    fail "ag tools should succeed"
fi
cleanup_test_env

#=============================================================================
# Initialization Detection Tests
#=============================================================================

test_case "ag start detects uninitialized project"
setup_test_env
# Create files with placeholder content (simulating uninitialized state)
cat > "$TEST_DIR/STACK.md" << 'EOF'
## Summary
- What are we building: <!-- 1–2 sentences -->
- Primary platform: <!-- web/service/mobile/desktop/cli -->
## Languages & runtimes
- Language(s): <!-- e.g., TypeScript, Python, Go -->
EOF
cat > "$TEST_DIR/CONTEXT_PACK.md" << 'EOF'
## One-minute overview
- What this repo is: <!-- 1–2 sentences -->
- Entry points: <!-- e.g., src/main.ts -->
EOF
output=$(bash "$TEST_DIR/.agentic/lib/tools/ag.sh" start 2>&1)
if echo "$output" | grep -q "NOT INITIALIZED"; then
    pass
else
    fail "Should detect uninitialized project"
fi
cleanup_test_env

test_case "ag start does NOT warn for initialized project"
setup_test_env
# Create files with actual content (simulating initialized state)
cat > "$TEST_DIR/STACK.md" << 'EOF'
## Summary
- What are we building: A task management CLI tool
- Primary platform: cli
## Languages & runtimes
- Language(s): Python 3.12
EOF
cat > "$TEST_DIR/CONTEXT_PACK.md" << 'EOF'
## One-minute overview
- What this repo is: Task management CLI for developers
- Entry points: src/main.py
EOF
cat > "$TEST_DIR/STATUS.md" << 'EOF'
## Current Focus
Building the core task CRUD operations
EOF
output=$(bash "$TEST_DIR/.agentic/lib/tools/ag.sh" start 2>&1)
if echo "$output" | grep -q "NOT INITIALIZED"; then
    fail "Should NOT warn for initialized project"
else
    pass
fi
cleanup_test_env

test_case "ag init shows guidance for uninitialized project"
setup_test_env
# Need multiple placeholders to trigger "not initialized" (threshold is 4+)
cat > "$TEST_DIR/STACK.md" << 'EOF'
## Summary
- What are we building: <!-- 1–2 sentences -->
- Primary platform: <!-- web/service/mobile/desktop/cli -->
## Languages & runtimes
- Language(s): <!-- e.g., TypeScript, Python, Go -->
EOF
cat > "$TEST_DIR/CONTEXT_PACK.md" << 'EOF'
## One-minute overview
- What this repo is: <!-- 1–2 sentences -->
- Entry points: <!-- e.g., src/main.ts -->
EOF
output=$(bash "$TEST_DIR/.agentic/lib/tools/ag.sh" init 2>&1)
if echo "$output" | grep -q "needs initialization"; then
    pass
else
    fail "Should show initialization guidance"
fi
cleanup_test_env

#=============================================================================
# Plan-Review Settings Tests
#=============================================================================

# Helper: set up Formal with acceptance criteria for ag plan
setup_plan_env() {
    setup_test_env
    mkdir -p "$TEST_DIR/spec/acceptance"
    cat > "$TEST_DIR/spec/acceptance/F-0042.md" << 'EOF'
# F-0042: Test Feature
## Acceptance Criteria
- [ ] Basic functionality works
EOF
}

test_case "ag plan: plan_review_enabled=yes shows ENABLED"
setup_plan_env
cat > "$TEST_DIR/STACK.md" << 'EOF'
Profile: formal
- plan_review_enabled: yes
- plan_review_max_iterations: 3
EOF
output=$(bash "$TEST_DIR/.agentic/lib/tools/ag.sh" plan F-0042 2>&1)
if echo "$output" | grep -q "Review loop: ENABLED"; then
    pass
else
    fail "Expected 'Review loop: ENABLED' when plan_review_enabled=yes"
fi
cleanup_test_env

test_case "ag plan: plan_review_enabled=no shows SKIPPED"
setup_plan_env
cat > "$TEST_DIR/STACK.md" << 'EOF'
Profile: formal
- plan_review_enabled: no
EOF
output=$(bash "$TEST_DIR/.agentic/lib/tools/ag.sh" plan F-0042 2>&1)
if echo "$output" | grep -q "Review loop: SKIPPED"; then
    pass
else
    fail "Expected 'Review loop: SKIPPED' when plan_review_enabled=no"
fi
cleanup_test_env

test_case "ag plan: --no-review overrides enabled setting"
setup_plan_env
cat > "$TEST_DIR/STACK.md" << 'EOF'
Profile: formal
- plan_review_enabled: yes
EOF
output=$(bash "$TEST_DIR/.agentic/lib/tools/ag.sh" plan F-0042 --no-review 2>&1)
if echo "$output" | grep -q "Review loop: SKIPPED"; then
    pass
else
    fail "Expected --no-review to override plan_review_enabled=yes"
fi
cleanup_test_env

test_case "ag plan: max_iterations=5 shows in output"
setup_plan_env
cat > "$TEST_DIR/STACK.md" << 'EOF'
Profile: formal
- plan_review_enabled: yes
- plan_review_max_iterations: 5
EOF
output=$(bash "$TEST_DIR/.agentic/lib/tools/ag.sh" plan F-0042 2>&1)
if echo "$output" | grep -q "max 5 iterations"; then
    pass
else
    fail "Expected 'max 5 iterations' in output"
fi
cleanup_test_env

test_case "ag plan: defaults to enabled when setting absent"
setup_plan_env
cat > "$TEST_DIR/STACK.md" << 'EOF'
Profile: formal
EOF
output=$(bash "$TEST_DIR/.agentic/lib/tools/ag.sh" plan F-0042 2>&1)
if echo "$output" | grep -q "Review loop: ENABLED"; then
    pass
else
    fail "Expected default to ENABLED when plan_review_enabled not set"
fi
cleanup_test_env

test_case "ag plan: Discovery profile rejects plan command"
setup_test_env
cat > "$TEST_DIR/STACK.md" << 'EOF'
Profile: discovery
EOF
result=0
bash "$TEST_DIR/.agentic/lib/tools/ag.sh" plan F-0042 >/dev/null 2>&1 || result=$?
if [[ $result -ne 0 ]]; then
    pass
else
    fail "Discovery profile should reject ag plan"
fi
cleanup_test_env

#=============================================================================
# Implement Command Settings Tests
#=============================================================================

test_case "ag implement: plan_review_auto_for=implement warns when no plan"
setup_plan_env
cat > "$TEST_DIR/STACK.md" << 'EOF'
Profile: formal
- plan_review_auto_for: [implement]
EOF
# Add feature to FEATURES.md
cat > "$TEST_DIR/spec/FEATURES.md" << 'EOF'
## F-0042: Test Feature
- Status: in_progress
EOF
output=$(bash "$TEST_DIR/.agentic/lib/tools/ag.sh" implement F-0042 2>&1) || true
if echo "$output" | grep -q "No plan found\|consider running.*ag plan"; then
    pass
else
    fail "Expected warning about missing plan when auto_for includes implement"
fi
cleanup_test_env

#=============================================================================
# Summary
#=============================================================================

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "ag.sh Gateway Tests: $PASSED passed, $FAILED failed"
echo "═══════════════════════════════════════════════════════════════"

[[ $FAILED -eq 0 ]]
