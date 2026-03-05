#!/usr/bin/env bash
# Unit tests for sync.sh phase 8 (PR cleanup) and ag.sh active blocker count
# Tests that merged/closed PRs are auto-resolved from HUMAN_NEEDED.md

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

# Create temp test project with HUMAN_NEEDED.md containing an active PR entry
setup_test_env() {
    TEST_DIR=$(mktemp -d "/tmp/pr-cleanup-test-XXXXXX")
    mkdir -p "$TEST_DIR/.agentic/tools"
    mkdir -p "$TEST_DIR/.agentic/lib"
    mkdir -p "$TEST_DIR/.agentic/presets"
    mkdir -p "$TEST_DIR/.agentic-state"
    mkdir -p "$TEST_DIR/.agentic-journal"
    mkdir -p "$TEST_DIR/bin"

    # Copy required scripts
    cp "$FRAMEWORK_ROOT/.agentic/lib/tools/sync.sh" "$TEST_DIR/.agentic/lib/tools/"
    cp "$FRAMEWORK_ROOT/.agentic/lib/tools/blocker.sh" "$TEST_DIR/.agentic/lib/tools/"
    cp "$FRAMEWORK_ROOT/.agentic/lib/tools/memory-check.sh" "$TEST_DIR/.agentic/lib/tools/" 2>/dev/null || true
    cp "$FRAMEWORK_ROOT/.agentic/lib/tools/check-environment.sh" "$TEST_DIR/.agentic/lib/tools/" 2>/dev/null || true
    cp "$FRAMEWORK_ROOT/.agentic/lib/tools/periodic-checks.sh" "$TEST_DIR/.agentic/lib/tools/" 2>/dev/null || true
    cp "$FRAMEWORK_ROOT/.agentic/lib/tools/drift.sh" "$TEST_DIR/.agentic/lib/tools/" 2>/dev/null || true
    cp "$FRAMEWORK_ROOT/.agentic/lib/tools/doc-check.sh" "$TEST_DIR/.agentic/lib/tools/" 2>/dev/null || true
    cp "$FRAMEWORK_ROOT/.agentic/lib/tools/status.sh" "$TEST_DIR/.agentic/lib/tools/" 2>/dev/null || true
    cp "$FRAMEWORK_ROOT/.agentic/lib/settings.sh" "$TEST_DIR/.agentic/lib/"
    cp "$FRAMEWORK_ROOT/.agentic/lib/presets/profiles.conf" "$TEST_DIR/.agentic/lib/presets/"

    # Create minimal STACK.md
    cat > "$TEST_DIR/STACK.md" << 'EOF'
## Settings
- profile: discovery
EOF

    cd "$TEST_DIR"
    git init -q 2>/dev/null || true
    git commit --allow-empty -m "init" -q 2>/dev/null || true
}

# Create a HUMAN_NEEDED.md with active PR entries
create_human_needed_with_prs() {
    cat > "$TEST_DIR/HUMAN_NEEDED.md" << 'EOF'
# HUMAN_NEEDED

<!-- format: human-needed-v0.1.0 -->

**Purpose**: Track items requiring human input, decisions, or intervention.

---

## Active items needing attention

### HN-0010: PR #99: Test feature
- **Type**: review
- **Added**: 2026-03-01
- **Context**: Test PR entry

### HN-0011: PR #100: Another feature
- **Type**: review
- **Added**: 2026-03-01
- **Context**: Another test PR

### HN-0012: Non-PR blocker: Need API key
- **Type**: credential
- **Added**: 2026-03-01
- **Context**: Not a PR entry

---

## Resolved

<!-- Archive resolved items here with date and outcome -->

### HN-0001: PR #50: Old feature
- **Resolved**: 2026-02-01
- **Outcome**: PR merged
EOF
}

# Create a mock gh that returns a configurable state
create_mock_gh() {
    local state="${1:-MERGED}"
    cat > "$TEST_DIR/bin/gh" << SCRIPT
#!/usr/bin/env bash
# Mock gh CLI — returns $state for any pr view call
if [[ "\$1" == "pr" && "\$2" == "view" ]]; then
    echo "$state"
    exit 0
fi
exit 1
SCRIPT
    chmod +x "$TEST_DIR/bin/gh"
}

# Create a mock gh that returns different states per PR number
create_mock_gh_per_pr() {
    cat > "$TEST_DIR/bin/gh" << 'SCRIPT'
#!/usr/bin/env bash
# Mock gh CLI — PR 99 is MERGED, PR 100 is OPEN
if [[ "$1" == "pr" && "$2" == "view" ]]; then
    pr_num="$3"
    case "$pr_num" in
        99) echo "MERGED" ;;
        100) echo "OPEN" ;;
        *) echo "OPEN" ;;
    esac
    exit 0
fi
exit 1
SCRIPT
    chmod +x "$TEST_DIR/bin/gh"
}

cleanup_test_env() {
    cd "$SCRIPT_DIR"
    [[ -n "${TEST_DIR:-}" ]] && rm -rf "$TEST_DIR"
}

# =============================================================================
# Phase 8: PR Cleanup Tests
# =============================================================================

test_case "sync --quiet: merged PRs reported as issues"
setup_test_env
create_human_needed_with_prs
create_mock_gh "MERGED"
output=$(PATH="$TEST_DIR/bin:$PATH" bash .agentic/lib/tools/sync.sh --quiet 2>&1)
if echo "$output" | grep -q "PR #"; then
    pass
else
    fail "Expected PR issue in quiet output, got: $output"
fi
cleanup_test_env

test_case "sync full: merged PRs auto-resolved from HUMAN_NEEDED.md"
setup_test_env
create_human_needed_with_prs
create_mock_gh "MERGED"
PATH="$TEST_DIR/bin:$PATH" bash .agentic/lib/tools/sync.sh 2>&1 > /dev/null
# After sync, active section should NOT contain the PR entries
active_prs=$(awk '/^## Active items/,/^---$/' "$TEST_DIR/HUMAN_NEEDED.md" | grep -c "^### HN-.*PR #" || true)
if [ "$active_prs" = "0" ]; then
    pass
else
    fail "Expected 0 active PR entries, found: $active_prs"
fi
cleanup_test_env

test_case "sync full: non-PR entries preserved in active section"
setup_test_env
create_human_needed_with_prs
create_mock_gh "MERGED"
PATH="$TEST_DIR/bin:$PATH" bash .agentic/lib/tools/sync.sh 2>&1 > /dev/null
# Non-PR entry (HN-0012) should still be active
if awk '/^## Active items/,/^---$/' "$TEST_DIR/HUMAN_NEEDED.md" | grep -q "HN-0012"; then
    pass
else
    fail "Non-PR blocker HN-0012 was incorrectly removed"
fi
cleanup_test_env

test_case "sync full: only merged/closed PRs resolved, open PRs kept"
setup_test_env
create_human_needed_with_prs
create_mock_gh_per_pr  # PR 99=MERGED, PR 100=OPEN
PATH="$TEST_DIR/bin:$PATH" bash .agentic/lib/tools/sync.sh 2>&1 > /dev/null
active_section=$(awk '/^## Active items/,/^---$/' "$TEST_DIR/HUMAN_NEEDED.md")
has_99=$(echo "$active_section" | grep -c "PR #99" || true)
has_100=$(echo "$active_section" | grep -c "PR #100" || true)
if [ "$has_99" = "0" ] && [ "$has_100" = "1" ]; then
    pass
else
    fail "Expected PR #99 removed and PR #100 kept. #99=$has_99, #100=$has_100"
fi
cleanup_test_env

test_case "sync full: resolved entries use Outcome field (not Resolution)"
setup_test_env
create_human_needed_with_prs
create_mock_gh "MERGED"
PATH="$TEST_DIR/bin:$PATH" bash .agentic/lib/tools/sync.sh 2>&1 > /dev/null
if grep -qF '**Outcome**' "$TEST_DIR/HUMAN_NEEDED.md"; then
    pass
else
    fail "Resolved entry missing **Outcome** field"
fi
cleanup_test_env

test_case "sync: graceful when gh CLI missing"
setup_test_env
create_human_needed_with_prs
# Don't add mock gh to PATH — use a PATH without gh
output=$(PATH="/usr/bin:/bin" bash .agentic/lib/tools/sync.sh --quiet 2>&1)
exit_code=$?
if [ "$exit_code" -eq 0 ]; then
    pass
else
    fail "sync should not fail when gh is missing (exit=$exit_code)"
fi
cleanup_test_env

test_case "sync --quiet: no PR output when no active PR entries"
setup_test_env
# HUMAN_NEEDED with no active entries
cat > "$TEST_DIR/HUMAN_NEEDED.md" << 'EOF'
# HUMAN_NEEDED

---

## Active items needing attention

_No active items_

---

## Resolved
EOF
create_mock_gh "MERGED"
output=$(PATH="$TEST_DIR/bin:$PATH" bash .agentic/lib/tools/sync.sh --quiet 2>&1)
if echo "$output" | grep -q "PR"; then
    fail "Unexpected PR output when no active PR entries: $output"
else
    pass
fi
cleanup_test_env

# =============================================================================
# ag.sh Blocker Count Tests
# =============================================================================

test_case "blocker count: only counts active section entries"
setup_test_env
create_human_needed_with_prs
# 3 active (HN-0010, HN-0011, HN-0012) + 1 resolved (HN-0001) = 4 total
# Should count only 3 (active)
blocker_count=$(awk '/^## Active items/,/^---$/' "$TEST_DIR/HUMAN_NEEDED.md" 2>/dev/null | grep -c "^### HN-" || true)
if [ "$blocker_count" = "3" ]; then
    pass
else
    fail "Expected 3 active blockers, got: $blocker_count"
fi
cleanup_test_env

test_case "blocker count: zero when all entries resolved"
setup_test_env
cat > "$TEST_DIR/HUMAN_NEEDED.md" << 'EOF'
# HUMAN_NEEDED

---

## Active items needing attention

_No active items_

---

## Resolved

### HN-0001: PR #50: Old feature
- **Resolved**: 2026-02-01
- **Outcome**: PR merged
EOF
blocker_count=$(awk '/^## Active items/,/^---$/' "$TEST_DIR/HUMAN_NEEDED.md" 2>/dev/null | grep -c "^### HN-" || true)
if [ "$blocker_count" = "0" ]; then
    pass
else
    fail "Expected 0 active blockers, got: $blocker_count"
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
