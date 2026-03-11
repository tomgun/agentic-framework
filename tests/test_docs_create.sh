#!/usr/bin/env bash
# test_docs_create.sh - Integration tests for docs.sh --create
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DOCS_SH="$PROJECT_ROOT/.agentic/lib/tools/docs.sh"

PASSED=0
FAILED=0

pass() { echo "  ✓ $1"; PASSED=$((PASSED + 1)); }
fail() { echo "  ✗ $1"; FAILED=$((FAILED + 1)); }

# --- Setup: create a temp project to test against ---
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

mkdir -p "$TMPDIR/docs" "$TMPDIR/.agentic/lib/tools" "$TMPDIR/.agentic/lib/agents/shared"

# Copy docs.sh and dependencies
cp "$DOCS_SH" "$TMPDIR/.agentic/lib/tools/"
cp "$PROJECT_ROOT/.agentic/lib/agents/shared/doc_types.md" "$TMPDIR/.agentic/lib/agents/shared/" 2>/dev/null || true

# Create minimal paths.sh and settings.sh stubs
cat > "$TMPDIR/.agentic/lib/paths.sh" << 'EOF'
ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
EOF
cat > "$TMPDIR/.agentic/lib/settings.sh" << 'EOF'
get_setting() { echo "${2:-}"; }
EOF

# Create STACK.md with Docs section
cat > "$TMPDIR/STACK.md" << 'EOF'
## Docs
- doc: README.md          | readme       | pr

## Constraints
EOF

echo "# Readme" > "$TMPDIR/README.md"

echo "=== docs.sh --create tests ==="

# --- Test 1: happy path ---
echo ""
echo "Test 1: create new doc"
OUTPUT=$(ROOT_DIR="$TMPDIR" bash "$TMPDIR/.agentic/lib/tools/docs.sh" --create docs/api-guide.md --type architecture --trigger feature_done 2>&1)

if [[ -f "$TMPDIR/docs/api-guide.md" ]]; then
    pass "File created"
else
    fail "File not created at docs/api-guide.md"
fi

if grep -q "api-guide" "$TMPDIR/STACK.md"; then
    pass "Registered in STACK.md"
else
    fail "Entry not found in STACK.md"
fi

CONTENT=$(cat "$TMPDIR/docs/api-guide.md")
if echo "$CONTENT" | grep -q "# Architecture"; then
    pass "Template content correct"
else
    fail "Template content wrong: $CONTENT"
fi

# --- Test 2: idempotency ---
echo ""
echo "Test 2: duplicate registration"
OUTPUT=$(ROOT_DIR="$TMPDIR" bash "$TMPDIR/.agentic/lib/tools/docs.sh" --create docs/api-guide.md --type architecture --trigger feature_done 2>&1)
if echo "$OUTPUT" | grep -q "Already registered"; then
    pass "Duplicate detected"
else
    fail "Should report already registered"
fi

# Count entries — should be exactly 1 for api-guide
COUNT=$(grep -c "api-guide" "$TMPDIR/STACK.md")
if [[ $COUNT -eq 1 ]]; then
    pass "No duplicate entry in STACK.md"
else
    fail "Expected 1 entry, found $COUNT"
fi

# --- Test 3: invalid type ---
echo ""
echo "Test 3: invalid type rejection"
OUTPUT=$(ROOT_DIR="$TMPDIR" bash "$TMPDIR/.agentic/lib/tools/docs.sh" --create docs/foo.md --type invalid_type --trigger manual 2>&1) || true
if echo "$OUTPUT" | grep -q "invalid type"; then
    pass "Invalid type rejected"
else
    fail "Should reject invalid type"
fi

# --- Test 4: existing file without --force ---
echo ""
echo "Test 4: existing file rejection"
echo "# Existing" > "$TMPDIR/docs/existing.md"
OUTPUT=$(ROOT_DIR="$TMPDIR" bash "$TMPDIR/.agentic/lib/tools/docs.sh" --create docs/existing.md --type readme --trigger manual 2>&1) || true
if echo "$OUTPUT" | grep -q "file already exists"; then
    pass "Existing file rejected without --force"
else
    fail "Should reject existing file"
fi

# --- Test 5: existing file with --force ---
echo ""
echo "Test 5: --force registers existing file"
OUTPUT=$(ROOT_DIR="$TMPDIR" bash "$TMPDIR/.agentic/lib/tools/docs.sh" --create docs/existing.md --type readme --trigger manual --force 2>&1)
if echo "$OUTPUT" | grep -q "registered only"; then
    pass "Existing file registered with --force"
else
    fail "Should register existing file with --force"
fi

# --- Test 6: invalid trigger ---
echo ""
echo "Test 6: invalid trigger rejection"
OUTPUT=$(ROOT_DIR="$TMPDIR" bash "$TMPDIR/.agentic/lib/tools/docs.sh" --create docs/bar.md --type readme --trigger invalid_trigger 2>&1) || true
if echo "$OUTPUT" | grep -q "invalid trigger"; then
    pass "Invalid trigger rejected"
else
    fail "Should reject invalid trigger"
fi

# --- Summary ---
echo ""
echo "═══════════════════════════════════"
echo "Passed: $PASSED  Failed: $FAILED"
echo "═══════════════════════════════════"
[[ $FAILED -eq 0 ]] && exit 0 || exit 1
