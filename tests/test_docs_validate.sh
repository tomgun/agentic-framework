#!/usr/bin/env bash
# test_docs_validate.sh - Integration tests for docs.sh --validate
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

echo "=== docs.sh --validate tests ==="

# --- Test 1: registered-but-missing ---
echo ""
echo "Test 1: registered-but-missing"
cat > "$TMPDIR/STACK.md" << 'EOF'
## Docs
- doc: docs/missing.md    | architecture | feature_done
- doc: README.md          | readme       | pr
EOF
echo "# Readme" > "$TMPDIR/README.md"

OUTPUT=$(ROOT_DIR="$TMPDIR" bash "$TMPDIR/.agentic/lib/tools/docs.sh" --validate 2>&1) || true
if echo "$OUTPUT" | grep -q "registered-but-missing: docs/missing.md"; then
    pass "Detects missing registered file"
else
    fail "Should detect docs/missing.md as missing"
fi

# --- Test 2: existing-but-unregistered ---
echo ""
echo "Test 2: existing-but-unregistered"
echo "# Guide" > "$TMPDIR/docs/guide.md"

OUTPUT=$(ROOT_DIR="$TMPDIR" bash "$TMPDIR/.agentic/lib/tools/docs.sh" --validate 2>&1) || true
if echo "$OUTPUT" | grep -q "unregistered: docs/guide.md"; then
    pass "Detects unregistered doc in docs/"
else
    fail "Should detect docs/guide.md as unregistered"
fi

# --- Test 3: clean state ---
echo ""
echo "Test 3: clean state"
cat > "$TMPDIR/STACK.md" << 'EOF'
## Docs
- doc: docs/guide.md      | architecture | feature_done
- doc: README.md          | readme       | pr
EOF

OUTPUT=$(ROOT_DIR="$TMPDIR" bash "$TMPDIR/.agentic/lib/tools/docs.sh" --validate 2>&1)
EXIT_CODE=$?
if [[ $EXIT_CODE -eq 0 ]]; then
    pass "Clean state returns exit 0"
else
    fail "Clean state should return exit 0, got $EXIT_CODE"
fi

# --- Test 4: directory entries ---
echo ""
echo "Test 4: directory entries"
mkdir -p "$TMPDIR/docs/adr"
echo "# ADR 1" > "$TMPDIR/docs/adr/001-decision.md"
cat > "$TMPDIR/STACK.md" << 'EOF'
## Docs
- doc: docs/guide.md      | architecture | feature_done
- doc: docs/adr/          | adr          | manual
- doc: README.md          | readme       | pr
EOF

OUTPUT=$(ROOT_DIR="$TMPDIR" bash "$TMPDIR/.agentic/lib/tools/docs.sh" --validate 2>&1)
EXIT_CODE=$?
if [[ $EXIT_CODE -eq 0 ]]; then
    pass "Directory entry handled correctly"
else
    fail "Files inside registered directory should not be flagged"
fi

# --- Test 5: exclusions ---
echo ""
echo "Test 5: config files excluded from unregistered scan"
echo "# Stack" > "$TMPDIR/CLAUDE.md"
echo "# Context" > "$TMPDIR/CONTEXT_PACK.md"
mkdir -p "$TMPDIR/.agentic/lib/tools"
echo "# Internal" > "$TMPDIR/.agentic/lib/tools/internal.md"

OUTPUT=$(ROOT_DIR="$TMPDIR" bash "$TMPDIR/.agentic/lib/tools/docs.sh" --validate 2>&1) || true
if echo "$OUTPUT" | grep -q "unregistered: CLAUDE.md"; then
    fail "CLAUDE.md should be excluded from unregistered scan"
else
    pass "Config files excluded from scan"
fi

# --- Test 6: --coverage output ---
echo ""
echo "Test 6: --coverage groups by type"
cat > "$TMPDIR/STACK.md" << 'EOF'
## Docs
- doc: docs/guide.md      | architecture | feature_done
- doc: docs/adr/          | adr          | manual
- doc: README.md          | readme       | pr
EOF

OUTPUT=$(ROOT_DIR="$TMPDIR" bash "$TMPDIR/.agentic/lib/tools/docs.sh" --coverage 2>&1)
if echo "$OUTPUT" | grep -q "architecture"; then
    pass "--coverage shows type grouping"
else
    fail "--coverage should show type groups"
fi

if echo "$OUTPUT" | grep -q "docs/guide.md"; then
    pass "--coverage lists paths"
else
    fail "--coverage should list doc paths"
fi

# --- Summary ---
echo ""
echo "═══════════════════════════════════"
echo "Passed: $PASSED  Failed: $FAILED"
echo "═══════════════════════════════════"
[[ $FAILED -eq 0 ]] && exit 0 || exit 1
