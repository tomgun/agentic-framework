#!/usr/bin/env bash
# test_docs_freshness.sh - Tests for docs.sh --check-freshness
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DOCS_SH="$PROJECT_ROOT/.agentic/lib/tools/docs.sh"

PASSED=0
FAILED=0

pass() { echo "  ✓ $1"; PASSED=$((PASSED + 1)); }
fail() { echo "  ✗ $1"; FAILED=$((FAILED + 1)); }

# --- Setup: create a temp project with git repo ---
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

# Initialize git repo with a main branch and initial commit
cd "$TMPDIR"
git init -b main >/dev/null 2>&1
git config user.email "test@test.com"
git config user.name "Test"
echo "# Project" > README.md
git add -A >/dev/null 2>&1
git commit -m "initial" >/dev/null 2>&1

echo "=== docs.sh --check-freshness tests ==="

# --- Test 1: Recently committed doc → FRESH (exit 0) ---
echo ""
echo "Test 1: Recently committed doc is FRESH"

cat > "$TMPDIR/STACK.md" << 'EOF'
## Docs
- doc: docs/guide.md      | architecture | feature_done
EOF
mkdir -p "$TMPDIR/docs"
echo "# Guide v1" > "$TMPDIR/docs/guide.md"
git add -A >/dev/null 2>&1
git commit -m "add guide doc" >/dev/null 2>&1

EXIT_CODE=0
OUTPUT=$(ROOT_DIR="$TMPDIR" bash "$TMPDIR/.agentic/lib/tools/docs.sh" --check-freshness --trigger feature_done 2>&1) || EXIT_CODE=$?
if [[ $EXIT_CODE -eq 0 ]]; then
    pass "Recently committed doc returns exit 0"
else
    fail "Recently committed doc should be FRESH (exit 0), got exit $EXIT_CODE"
    echo "    Output: $OUTPUT"
fi

# --- Test 2: Stale doc → exit 1 ---
echo ""
echo "Test 2: Stale doc returns exit 1"

# Add 6 unrelated commits to push guide.md out of the 5-commit window
for i in $(seq 1 6); do
    echo "change $i" >> "$TMPDIR/README.md"
    git add README.md >/dev/null 2>&1
    git commit -m "unrelated commit $i" >/dev/null 2>&1
done

EXIT_CODE=0
OUTPUT=$(ROOT_DIR="$TMPDIR" bash "$TMPDIR/.agentic/lib/tools/docs.sh" --check-freshness --trigger feature_done 2>&1) || EXIT_CODE=$?
if [[ $EXIT_CODE -eq 1 ]]; then
    pass "Stale doc returns exit 1"
else
    fail "Stale doc should return exit 1, got exit $EXIT_CODE"
    echo "    Output: $OUTPUT"
fi

# Verify the stale doc is listed in output
if echo "$OUTPUT" | grep -q "stale.*docs/guide.md"; then
    pass "Stale output includes doc path"
else
    fail "Output should list stale doc path"
    echo "    Output: $OUTPUT"
fi

# --- Test 3: No feature_done docs → exit 0 ---
echo ""
echo "Test 3: No feature_done docs returns exit 0"

cat > "$TMPDIR/STACK.md" << 'EOF'
## Docs
- doc: docs/guide.md      | architecture | pr
- doc: README.md           | readme       | session
EOF

EXIT_CODE=0
OUTPUT=$(ROOT_DIR="$TMPDIR" bash "$TMPDIR/.agentic/lib/tools/docs.sh" --check-freshness --trigger feature_done 2>&1) || EXIT_CODE=$?
if [[ $EXIT_CODE -eq 0 ]]; then
    pass "No feature_done docs returns exit 0"
else
    fail "Should return exit 0 when no docs match trigger, got exit $EXIT_CODE"
fi

# --- Test 4: Missing registered doc → STALE (exit 1) ---
echo ""
echo "Test 4: Missing registered doc returns exit 1"

cat > "$TMPDIR/STACK.md" << 'EOF'
## Docs
- doc: docs/nonexistent.md | architecture | feature_done
EOF

EXIT_CODE=0
OUTPUT=$(ROOT_DIR="$TMPDIR" bash "$TMPDIR/.agentic/lib/tools/docs.sh" --check-freshness --trigger feature_done 2>&1) || EXIT_CODE=$?
if [[ $EXIT_CODE -eq 1 ]]; then
    pass "Missing doc returns exit 1"
else
    fail "Missing doc should return exit 1, got exit $EXIT_CODE"
fi

if echo "$OUTPUT" | grep -q "stale (missing).*docs/nonexistent.md"; then
    pass "Missing doc output includes (missing) indicator"
else
    fail "Output should indicate doc is missing"
    echo "    Output: $OUTPUT"
fi

# --- Test 5: Empty registry → exit 0 ---
echo ""
echo "Test 5: Empty registry returns exit 0"

cat > "$TMPDIR/STACK.md" << 'EOF'
## Settings
- profile: discovery

## Docs
EOF

EXIT_CODE=0
OUTPUT=$(ROOT_DIR="$TMPDIR" bash "$TMPDIR/.agentic/lib/tools/docs.sh" --check-freshness --trigger feature_done 2>&1) || EXIT_CODE=$?
if [[ $EXIT_CODE -eq 0 ]]; then
    pass "Empty registry returns exit 0"
else
    fail "Empty registry should return exit 0, got exit $EXIT_CODE"
fi

# --- Test 6: Feature branch diff detection ---
echo ""
echo "Test 6: Doc modified on feature branch is FRESH"

cat > "$TMPDIR/STACK.md" << 'EOF'
## Docs
- doc: docs/guide.md      | architecture | feature_done
EOF
git -C "$TMPDIR" add STACK.md >/dev/null 2>&1
git -C "$TMPDIR" commit -m "update stack" >/dev/null 2>&1 || true

# Create a feature branch and modify the doc there
git -C "$TMPDIR" checkout -b feature/test-branch >/dev/null 2>&1
echo "# Guide v2 - updated on branch" > "$TMPDIR/docs/guide.md"
git -C "$TMPDIR" add docs/guide.md >/dev/null 2>&1
git -C "$TMPDIR" commit -m "update guide on branch" >/dev/null 2>&1

# Add unrelated commits to push past 5-commit window
for i in $(seq 1 6); do
    echo "branch change $i" >> "$TMPDIR/README.md"
    git -C "$TMPDIR" add README.md >/dev/null 2>&1
    git -C "$TMPDIR" commit -m "branch unrelated $i" >/dev/null 2>&1
done

EXIT_CODE=0
OUTPUT=$(ROOT_DIR="$TMPDIR" bash "$TMPDIR/.agentic/lib/tools/docs.sh" --check-freshness --trigger feature_done 2>&1) || EXIT_CODE=$?
if [[ $EXIT_CODE -eq 0 ]]; then
    pass "Doc modified on feature branch is FRESH via branch diff"
else
    fail "Branch-modified doc should be FRESH (exit 0), got exit $EXIT_CODE"
    echo "    Output: $OUTPUT"
fi

# Switch back to main for cleanup
git -C "$TMPDIR" checkout main >/dev/null 2>&1

# --- Test 7: Directory entries are skipped ---
echo ""
echo "Test 7: Directory entries are skipped in freshness check"

cat > "$TMPDIR/STACK.md" << 'EOF'
## Docs
- doc: docs/adr/           | adr          | feature_done
EOF
mkdir -p "$TMPDIR/docs/adr"
echo "# ADR 1" > "$TMPDIR/docs/adr/001.md"
git -C "$TMPDIR" add -A >/dev/null 2>&1
git -C "$TMPDIR" commit -m "add adr" >/dev/null 2>&1

EXIT_CODE=0
OUTPUT=$(ROOT_DIR="$TMPDIR" bash "$TMPDIR/.agentic/lib/tools/docs.sh" --check-freshness --trigger feature_done 2>&1) || EXIT_CODE=$?
if [[ $EXIT_CODE -eq 0 ]]; then
    pass "Directory entries skipped in freshness check"
else
    fail "Directory entries should be skipped, got exit $EXIT_CODE"
    echo "    Output: $OUTPUT"
fi

# --- Summary ---
echo ""
echo "═══════════════════════════════════"
echo "Passed: $PASSED  Failed: $FAILED"
echo "═══════════════════════════════════"
[[ $FAILED -eq 0 ]] && exit 0 || exit 1
