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
    mkdir -p "$TEST_DIR/.agentic/lib/tools"
    mkdir -p "$TEST_DIR/.agentic/lib/presets"
    mkdir -p "$TEST_DIR/.agentic/session"
    cp "$AG_SCRIPT" "$TEST_DIR/.agentic/lib/tools/ag.sh"
    # Copy command modules (F-0221: ag.sh sources these)
    if [ -d "$FRAMEWORK_ROOT/.agentic/lib/tools/commands" ]; then
        mkdir -p "$TEST_DIR/.agentic/lib/tools/commands"
        cp "$FRAMEWORK_ROOT/.agentic/lib/tools/commands/"*.sh "$TEST_DIR/.agentic/lib/tools/commands/" 2>/dev/null || true
    fi
    cp "$FRAMEWORK_ROOT/.agentic/lib/tools/list-tools.sh" "$TEST_DIR/.agentic/lib/tools/" 2>/dev/null || true
    cp "$FRAMEWORK_ROOT/.agentic/lib/tools/wip.sh" "$TEST_DIR/.agentic/lib/tools/" 2>/dev/null || true
    cp "$FRAMEWORK_ROOT/.agentic/lib/tools/intent-helpers.sh" "$TEST_DIR/.agentic/lib/tools/" 2>/dev/null || true
    cp "$FRAMEWORK_ROOT/.agentic/lib/tools/ac-parse.sh" "$TEST_DIR/.agentic/lib/tools/" 2>/dev/null || true
    cp "$FRAMEWORK_ROOT/.agentic/lib/paths.sh" "$TEST_DIR/.agentic/lib/" 2>/dev/null || true
    cp "$FRAMEWORK_ROOT/.agentic/lib/ids.sh" "$TEST_DIR/.agentic/lib/" 2>/dev/null || true
    cp "$FRAMEWORK_ROOT/.agentic/lib/settings.sh" "$TEST_DIR/.agentic/lib/" 2>/dev/null || true
    cp "$FRAMEWORK_ROOT/.agentic/lib/presets/profiles.conf" "$TEST_DIR/.agentic/lib/presets/" 2>/dev/null || true
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
if echo "$output" | grep -q "No formal feature tracking"; then
    pass
else
    fail "Expected 'No formal feature tracking' for discovery profile"
fi
cleanup_test_env

test_case "Profile detection: Formal from STACK.md"
setup_test_env
cat > "$TEST_DIR/STACK.md" << 'EOF'
# Stack
Profile: formal
EOF
output=$(bash "$TEST_DIR/.agentic/lib/tools/ag.sh" help 2>&1)
if echo "$output" | grep -q "Feature Tracking"; then
    pass
else
    fail "Expected 'Feature Tracking' for formal profile"
fi
cleanup_test_env

test_case "Profile detection: Formal from spec/ directory"
setup_test_env
mkdir -p "$TEST_DIR/.agentic/spec"
output=$(bash "$TEST_DIR/.agentic/lib/tools/ag.sh" help 2>&1)
if echo "$output" | grep -q "Feature Tracking"; then
    pass
else
    fail "Expected 'Feature Tracking' from .agentic/spec/ directory"
fi
cleanup_test_env

test_case "Profile detection: Default to Discovery when no indicators"
setup_test_env
output=$(bash "$TEST_DIR/.agentic/lib/tools/ag.sh" help 2>&1)
if echo "$output" | grep -q "No formal feature tracking"; then
    pass
else
    fail "Expected default 'No formal feature tracking'"
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
mkdir -p "$TEST_DIR/.agentic/spec"
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
mkdir -p "$TEST_DIR/.agentic/spec"
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
mkdir -p "$TEST_DIR/.agentic/spec"
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
    mkdir -p "$TEST_DIR/.agentic/spec/acceptance"
    cat > "$TEST_DIR/.agentic/spec/acceptance/F-0042.md" << 'EOF'
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
cat > "$TEST_DIR/.agentic/spec/FEATURES.md" << 'EOF'
## F-0042: Test Feature
- Status: in_progress
EOF
output=$(bash "$TEST_DIR/.agentic/lib/tools/ag.sh" implement F-0042 2>&1) || true
if echo "$output" | grep -q "No.*plan found\|consider running.*ag plan"; then
    pass
else
    fail "Expected warning about missing plan when auto_for includes implement"
fi
cleanup_test_env

#=============================================================================
# Done Command: FEATURES.md Auto-Ship + Backlog Advance Tests
#=============================================================================

# Helper: set up a formal project with feature infrastructure for ag done tests
setup_done_env() {
    setup_test_env
    mkdir -p "$TEST_DIR/.agentic/spec/acceptance"
    mkdir -p "$TEST_DIR/.agentic/journal/manifests"
    mkdir -p "$TEST_DIR/.agentic/lib/auto"
    # Copy all tool scripts needed by ag done
    for tool in backlog_helpers.py backlog.sh feature.sh manifest.sh drift.sh doctor.sh intent-helpers.sh; do
        cp "$FRAMEWORK_ROOT/.agentic/lib/tools/$tool" "$TEST_DIR/.agentic/lib/tools/" 2>/dev/null || true
    done
    cp "$FRAMEWORK_ROOT/.agentic/lib/auto/state_machine.py" "$TEST_DIR/.agentic/lib/auto/" 2>/dev/null || true
    # Create STACK.md for formal profile
    cat > "$TEST_DIR/STACK.md" << 'EOF'
Profile: formal
- state_enforcement: off
EOF
    # Create FEATURES.md with an in_progress feature
    cat > "$TEST_DIR/.agentic/spec/FEATURES.md" << 'EOF'
# Features

## F-0042: Test Feature

**Status**: in_progress

**Description**: A test feature for done command tests

**Acceptance**: spec/acceptance/F-0042.md
EOF
    # Create acceptance criteria
    cat > "$TEST_DIR/.agentic/spec/acceptance/F-0042.md" << 'EOF'
# F-0042: Test Feature

## Acceptance Criteria
- [x] AC-001: Basic functionality works
EOF
    # Init git so manifest.sh doesn't fail
    git -C "$TEST_DIR" init --quiet 2>/dev/null || true
    git -C "$TEST_DIR" add -A 2>/dev/null || true
    git -C "$TEST_DIR" commit -m "init" --quiet 2>/dev/null || true
}

test_case "ag done: auto-marks feature as shipped in FEATURES.md"
setup_done_env
# Verify feature is NOT shipped before
if grep -A5 "^## F-0042:" "$TEST_DIR/.agentic/spec/FEATURES.md" | grep -qi "shipped"; then
    fail "Pre-condition: feature should not be shipped yet"
    cleanup_test_env
else
    # Run ag done
    output=$(bash "$TEST_DIR/.agentic/lib/tools/ag.sh" done F-0042 2>&1) || true
    # Feature should now be shipped
    if grep -A5 "^## F-0042:" "$TEST_DIR/.agentic/spec/FEATURES.md" | grep -qi "shipped"; then
        pass
    else
        fail "ag done should auto-mark feature as shipped in FEATURES.md"
    fi
    cleanup_test_env
fi

test_case "ag done: advances backlog even when feature is not at position 0"
setup_done_env
# Create BACKLOG.json with F-0042 at position 1 (not current)
mkdir -p "$TEST_DIR/.agentic"
cat > "$TEST_DIR/.agentic/BACKLOG.json" << 'EOF'
[
  {"id": "F-0099", "description": "Other feature"},
  {"id": "F-0042", "description": "Test Feature"}
]
EOF
git -C "$TEST_DIR" add -A 2>/dev/null || true
git -C "$TEST_DIR" commit -m "add backlog" --quiet 2>/dev/null || true
# Run ag done
output=$(bash "$TEST_DIR/.agentic/lib/tools/ag.sh" done F-0042 2>&1) || true
# F-0042 should be removed from backlog
if python3 "$TEST_DIR/.agentic/lib/tools/backlog_helpers.py" --project-root "$TEST_DIR" list 2>/dev/null | grep -q "F-0042"; then
    fail "F-0042 should be removed from backlog after ag done"
else
    pass
fi
cleanup_test_env

test_case "ag done: shows feedback when removing non-current feature from backlog"
setup_done_env
# Create BACKLOG.json with F-0042 at position 1 (not current)
cat > "$TEST_DIR/.agentic/BACKLOG.json" << 'EOF'
[
  {"id": "F-0099", "description": "Other feature"},
  {"id": "F-0042", "description": "Test Feature"}
]
EOF
git -C "$TEST_DIR" add -A 2>/dev/null || true
git -C "$TEST_DIR" commit -m "add backlog" --quiet 2>/dev/null || true
output=$(bash "$TEST_DIR/.agentic/lib/tools/ag.sh" done F-0042 2>&1) || true
if echo "$output" | grep -qi "backlog"; then
    pass
else
    fail "ag done should show backlog feedback even for non-current features"
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
