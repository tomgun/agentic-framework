#!/usr/bin/env bash
# Unit tests for sync.sh phase 3b (unregistered shipped code detection)
# Tests that commits without F-#### references are flagged when they look like features

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

# Create temp test project with git repo and feature_tracking=yes
setup_test_env() {
    TEST_DIR=$(mktemp -d "/tmp/unreg-feature-test-XXXXXX")
    mkdir -p "$TEST_DIR/.agentic/tools"
    mkdir -p "$TEST_DIR/.agentic/lib"
    mkdir -p "$TEST_DIR/.agentic/presets"
    mkdir -p "$TEST_DIR/.agentic-state"
    mkdir -p "$TEST_DIR/.agentic-journal"

    # Copy required scripts
    cp "$FRAMEWORK_ROOT/.agentic/lib/tools/sync.sh" "$TEST_DIR/.agentic/lib/tools/"
    cp "$FRAMEWORK_ROOT/.agentic/lib/tools/blocker.sh" "$TEST_DIR/.agentic/lib/tools/" 2>/dev/null || true
    cp "$FRAMEWORK_ROOT/.agentic/lib/tools/memory-check.sh" "$TEST_DIR/.agentic/lib/tools/" 2>/dev/null || true
    cp "$FRAMEWORK_ROOT/.agentic/lib/tools/check-environment.sh" "$TEST_DIR/.agentic/lib/tools/" 2>/dev/null || true
    cp "$FRAMEWORK_ROOT/.agentic/lib/tools/periodic-checks.sh" "$TEST_DIR/.agentic/lib/tools/" 2>/dev/null || true
    cp "$FRAMEWORK_ROOT/.agentic/lib/tools/drift.sh" "$TEST_DIR/.agentic/lib/tools/" 2>/dev/null || true
    cp "$FRAMEWORK_ROOT/.agentic/lib/tools/doc-check.sh" "$TEST_DIR/.agentic/lib/tools/" 2>/dev/null || true
    cp "$FRAMEWORK_ROOT/.agentic/lib/tools/status.sh" "$TEST_DIR/.agentic/lib/tools/" 2>/dev/null || true
    cp "$FRAMEWORK_ROOT/.agentic/lib/settings.sh" "$TEST_DIR/.agentic/lib/"
    cp "$FRAMEWORK_ROOT/.agentic/lib/presets/profiles.conf" "$TEST_DIR/.agentic/lib/presets/"

    # Create STACK.md with feature_tracking=yes
    cat > "$TEST_DIR/STACK.md" << 'EOF'
## Settings
- profile: formal
- feature_tracking: yes
EOF

    # Initialize git repo
    cd "$TEST_DIR"
    git init -q
    git add -A
    git commit -q -m "Initial commit" --allow-empty

    # Create FEATURES.md and other state files
    mkdir -p "$TEST_DIR/spec"
    echo "# FEATURES" > "$TEST_DIR/spec/FEATURES.md"
    touch "$TEST_DIR/STATUS.md"
    touch "$TEST_DIR/HUMAN_NEEDED.md"
    echo "# Journal" > "$TEST_DIR/.agentic/journal/JOURNAL.md"

    # Set sync date to 30 days ago so all commits are in window
    mkdir -p "$TEST_DIR/.agentic-state"
    echo "last_sync=$(date -v-30d '+%Y-%m-%d' 2>/dev/null || date -d '30 days ago' '+%Y-%m-%d')" > "$TEST_DIR/.agentic/session/sync-state.conf"

    git add -A
    git commit -q -m "Setup state files"
}

cleanup_test_env() {
    cd "$FRAMEWORK_ROOT"
    rm -rf "$TEST_DIR"
}

# ============================================================================
# Tests
# ============================================================================

echo "=== Unregistered Features Detection Tests ==="
echo ""

# Test 1: Commit with F-#### reference should NOT be flagged
test_case "Commit with F-#### reference is not flagged"
setup_test_env
cd "$TEST_DIR"
# Create 3+ source files with at least 1 new
echo "class Foo:" > src_a.py
echo "class Bar:" > src_b.py
echo "class Baz:" > src_c.py
mkdir -p lib
echo "def helper():" > lib/helper.py
git add -A
git commit -q -m "feat: add user auth (F-0001)"
output=$(bash .agentic/lib/tools/sync.sh --quiet 2>&1)
if echo "$output" | grep -q "unregistered"; then
    fail "F-#### commit was incorrectly flagged"
else
    pass
fi
cleanup_test_env

# Test 2: Commit without F-#### touching 3+ src files with 1 new SHOULD be flagged
test_case "Commit without F-#### with 3+ files is flagged"
setup_test_env
cd "$TEST_DIR"
echo "class Foo:" > src_a.py
echo "class Bar:" > src_b.py
echo "class Baz:" > src_c.py
mkdir -p lib
echo "def helper():" > lib/helper.py
git add -A
git commit -q -m "add user authentication system"
output=$(bash .agentic/lib/tools/sync.sh --quiet 2>&1)
if echo "$output" | grep -q "unregistered"; then
    pass
else
    fail "Expected unregistered feature detection but got: $output"
fi
cleanup_test_env

# Test 3: Commit touching only 2 files should NOT be flagged (below threshold)
test_case "Commit with only 2 files is not flagged"
setup_test_env
cd "$TEST_DIR"
echo "class Foo:" > src_a.py
echo "class Bar:" > src_b.py
git add -A
git commit -q -m "add small utility"
output=$(bash .agentic/lib/tools/sync.sh --quiet 2>&1)
if echo "$output" | grep -q "unregistered"; then
    fail "Sub-threshold commit was incorrectly flagged"
else
    pass
fi
cleanup_test_env

# Test 4: Commit touching 3+ files but none new should NOT be flagged
test_case "Commit with 3+ modified (0 new) is not flagged"
setup_test_env
cd "$TEST_DIR"
# Create files first (with F-#### so setup commit doesn't trigger detection)
echo "v1" > src_a.py
echo "v1" > src_b.py
echo "v1" > src_c.py
git add -A
git commit -q -m "feat: initial files (F-0099)"
# Now modify (not add) all three — no new files
echo "v2" > src_a.py
echo "v2" > src_b.py
echo "v2" > src_c.py
git add -A
git commit -q -m "refactor all modules"
output=$(bash .agentic/lib/tools/sync.sh --quiet 2>&1)
if echo "$output" | grep -q "unregistered"; then
    fail "Modify-only commit was incorrectly flagged"
else
    pass
fi
cleanup_test_env

# Test 5: Test files should be excluded from count
test_case "Test-only commits are not flagged"
setup_test_env
cd "$TEST_DIR"
mkdir -p tests
echo "def test_a():" > tests/test_a.py
echo "def test_b():" > tests/test_b.py
echo "def test_c():" > tests/test_c.py
echo "def test_d():" > tests/test_d.py
git add -A
git commit -q -m "add test suite"
output=$(bash .agentic/lib/tools/sync.sh --quiet 2>&1)
if echo "$output" | grep -q "unregistered"; then
    fail "Test-only commit was incorrectly flagged"
else
    pass
fi
cleanup_test_env

# Test 6: feature_tracking=no should skip entirely
test_case "feature_tracking=no skips detection"
setup_test_env
cd "$TEST_DIR"
# Override to no
cat > "$TEST_DIR/STACK.md" << 'EOF'
## Settings
- profile: discovery
- feature_tracking: no
EOF
echo "class Foo:" > src_a.py
echo "class Bar:" > src_b.py
echo "class Baz:" > src_c.py
echo "class Qux:" > src_d.py
git add -A
git commit -q -m "add everything without feature ref"
output=$(bash .agentic/lib/tools/sync.sh --quiet 2>&1)
if echo "$output" | grep -q "unregistered"; then
    fail "Detection ran despite feature_tracking=no"
else
    pass
fi
cleanup_test_env

# Test 7: Full mode output shows details
test_case "Full mode shows commit details"
setup_test_env
cd "$TEST_DIR"
echo "class Foo:" > src_a.py
echo "class Bar:" > src_b.py
echo "class Baz:" > src_c.py
mkdir -p lib
echo "def helper():" > lib/helper.py
git add -A
git commit -q -m "add payment processing"
output=$(bash .agentic/lib/tools/sync.sh 2>&1)
if echo "$output" | grep -q "may be unregistered" && echo "$output" | grep -q "payment processing"; then
    pass
else
    fail "Expected detailed output with commit message. Got: $output"
fi
cleanup_test_env

# Test 8: .agentic/ files should be excluded
test_case ".agentic/ files are excluded from source count"
setup_test_env
cd "$TEST_DIR"
mkdir -p .agentic/tools
echo "#!/bin/bash" > .agentic/lib/tools/new_tool.sh
echo "helper" > .agentic/lib/tools/helper.sh
echo "lib" > .agentic/lib/tools/lib.sh
echo "extra" > .agentic/lib/tools/extra.sh
echo "only_one_src" > src_a.py
git add -A
git commit -q -m "add framework tools"
output=$(bash .agentic/lib/tools/sync.sh --quiet 2>&1)
if echo "$output" | grep -q "unregistered"; then
    fail ".agentic/ files counted as source files"
else
    pass
fi
cleanup_test_env

# ============================================================================
# Summary
# ============================================================================
echo ""
echo "=================================="
echo -e "Results: ${GREEN}$PASSED passed${NC}, ${RED}$FAILED failed${NC}"
echo "=================================="

exit $FAILED
