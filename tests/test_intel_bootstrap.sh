#!/usr/bin/env bash
# test_intel_bootstrap.sh — Tests for F-041 Intelligence Engine Phase 3
#
# Tests:
#   1. ag intel bootstrap — runs without error, outputs stack analysis
#   2. bootstrap detects STACK.md fields (language, framework, pkg manager)
#   3. bootstrap detects package.json dependencies
#   4. bootstrap detects Python project files
#   5. bootstrap detects directory structure
#   6. bootstrap works without STACK.md (codebase detection only)
#   7. bootstrap outputs quality-checklist.yaml generation template
#   8. bootstrap outputs test-strategy.yaml generation template
#   9. bootstrap outputs pattern generation instructions
#  10. ag intel retro — runs without error on empty project
#  11. retro loads existing patterns
#  12. retro shows ISSUES.md content
#  13. retro shows LESSONS.md content
#  14. retro shows shipped features from FEATURES.md
#  15. retro identifies unextracted lessons
#  16. bootstrap handles partial STACK.md gracefully

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PASS=0
FAIL=0
TOTAL=0

pass() { echo "  ✅ $1"; PASS=$((PASS + 1)); TOTAL=$((TOTAL + 1)); }
fail() { echo "  ❌ $1: $2"; FAIL=$((FAIL + 1)); TOTAL=$((TOTAL + 1)); }

# Create a temp project with various stack files for testing
create_project() {
    local dir
    dir=$(mktemp -d)
    mkdir -p "$dir/.agentic/intel" "$dir/.agentic/lib/tools/commands" "$dir/.agentic/lib/presets"
    mkdir -p "$dir/.agentic/lib/claude-hooks" "$dir/.agentic/journal" "$dir/.agentic/spec"
    mkdir -p "$dir/.agentic/session"

    # Copy required libraries
    cp "$REPO_ROOT/.agentic/lib/settings.sh" "$dir/.agentic/lib/"
    cp -r "$REPO_ROOT/.agentic/lib/presets" "$dir/.agentic/lib/" 2>/dev/null || true
    cp "$REPO_ROOT/.agentic/lib/paths.sh" "$dir/.agentic/lib/" 2>/dev/null || true
    cp "$REPO_ROOT/.agentic/lib/tools/commands/intel.sh" "$dir/.agentic/lib/tools/commands/"
    cp "$REPO_ROOT/.agentic/lib/tools/fwlog.sh" "$dir/.agentic/lib/tools/" 2>/dev/null || true

    echo "$dir"
}

cleanup_project() {
    rm -rf "$1" 2>/dev/null || true
}

# Minimal ag.sh stub that sources intel.sh
run_intel() {
    local project_dir="$1"
    shift
    (
        ROOT_DIR="$project_dir"
        SCRIPT_DIR="$project_dir/.agentic/lib/tools"
        # Source settings and paths
        source "$project_dir/.agentic/lib/settings.sh" 2>/dev/null || true
        PROFILE=$(_get_setting "profile" 2>/dev/null || echo "discovery")
        # Color codes
        RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m'
        BLUE='\033[0;34m' BOLD='\033[1m' DIM='\033[2m' NC='\033[0m'
        # Source intel
        source "$project_dir/.agentic/lib/tools/commands/intel.sh"
        cmd_intel "$@"
    )
}

echo ""
echo "=== F-041 Phase 3: Bootstrap + Quality Intelligence ==="
echo ""

# ===================================================================
# Bootstrap Tests
# ===================================================================
echo "--- Bootstrap ---"

# --- Test 1: bootstrap runs without error ---
PROJECT=$(create_project)
cat > "$PROJECT/STACK.md" << 'EOF'
# Stack

## Languages & runtimes
- Language(s): TypeScript
- Runtime(s): Node.js 20

## Tooling
- Package manager: pnpm
- App framework: Next.js

## Summary
- Domain: e-commerce
- Primary platform: Web
EOF

OUTPUT=$(run_intel "$PROJECT" bootstrap 2>&1)
RC=$?

if [[ $RC -eq 0 ]] && echo "$OUTPUT" | grep -q "Stack Analysis"; then
    pass "1. ag intel bootstrap runs and shows Stack Analysis"
else
    fail "1. ag intel bootstrap failed (rc=$RC)" "$(echo "$OUTPUT" | tail -5)"
fi

# --- Test 2: detects STACK.md fields ---
if echo "$OUTPUT" | grep -q "TypeScript" && \
   echo "$OUTPUT" | grep -q "pnpm" && \
   echo "$OUTPUT" | grep -q "Next.js"; then
    pass "2. bootstrap detects language, pkg manager, framework from STACK.md"
else
    fail "2. bootstrap missed STACK.md fields" "$(echo "$OUTPUT" | grep -E 'Language|Package|Framework')"
fi

cleanup_project "$PROJECT"

# --- Test 3: detects package.json dependencies ---
PROJECT=$(create_project)
cat > "$PROJECT/package.json" << 'EOF'
{
  "name": "test-app",
  "dependencies": {
    "react": "^18.0.0",
    "next": "^14.0.0"
  },
  "devDependencies": {
    "vitest": "^1.0.0",
    "playwright": "^1.40.0"
  }
}
EOF

OUTPUT=$(run_intel "$PROJECT" bootstrap 2>&1)
if echo "$OUTPUT" | grep -q "React" && \
   echo "$OUTPUT" | grep -q "Next.js" && \
   echo "$OUTPUT" | grep -q "vitest" && \
   echo "$OUTPUT" | grep -q "playwright"; then
    pass "3. bootstrap detects React, Next.js, vitest, playwright from package.json"
else
    fail "3. bootstrap missed package.json deps" "$(echo "$OUTPUT" | grep -E 'Framework|Test')"
fi

cleanup_project "$PROJECT"

# --- Test 4: detects Python project ---
PROJECT=$(create_project)
cat > "$PROJECT/requirements.txt" << 'EOF'
django==4.2
pytest==7.4
EOF
cat > "$PROJECT/pyproject.toml" << 'EOF'
[tool.poetry]
name = "test"
EOF

OUTPUT=$(run_intel "$PROJECT" bootstrap 2>&1)
if echo "$OUTPUT" | grep -qi "python" && \
   echo "$OUTPUT" | grep -qi "Django"; then
    pass "4. bootstrap detects Python + Django from requirements.txt"
else
    fail "4. bootstrap missed Python detection" "$(echo "$OUTPUT" | grep -iE 'Language|Framework')"
fi

cleanup_project "$PROJECT"

# --- Test 5: detects directory structure ---
PROJECT=$(create_project)
mkdir -p "$PROJECT/src" "$PROJECT/tests" "$PROJECT/docs" "$PROJECT/components"

OUTPUT=$(run_intel "$PROJECT" bootstrap 2>&1)
if echo "$OUTPUT" | grep -q "src/" && \
   echo "$OUTPUT" | grep -q "tests/" && \
   echo "$OUTPUT" | grep -q "docs/"; then
    pass "5. bootstrap detects directory structure (src/, tests/, docs/)"
else
    fail "5. bootstrap missed directories" "$(echo "$OUTPUT" | grep 'Directories')"
fi

cleanup_project "$PROJECT"

# --- Test 6: works without STACK.md ---
PROJECT=$(create_project)
cat > "$PROJECT/package.json" << 'EOF'
{"name": "test", "dependencies": {"express": "^4.0.0"}, "devDependencies": {"jest": "^29.0.0"}}
EOF

OUTPUT=$(run_intel "$PROJECT" bootstrap 2>&1)
RC=$?

if [[ $RC -eq 0 ]] && echo "$OUTPUT" | grep -q "No STACK.md" && \
   echo "$OUTPUT" | grep -qi "Express"; then
    pass "6. bootstrap works without STACK.md, detects Express from package.json"
else
    fail "6. bootstrap without STACK.md failed (rc=$RC)" "$(echo "$OUTPUT" | head -10)"
fi

cleanup_project "$PROJECT"

# --- Test 7: outputs quality-checklist.yaml template ---
PROJECT=$(create_project)
cat > "$PROJECT/STACK.md" << 'EOF'
# Stack
## Languages & runtimes
- Language(s): Python
EOF

OUTPUT=$(run_intel "$PROJECT" bootstrap 2>&1)
if echo "$OUTPUT" | grep -q "quality-checklist.yaml" && \
   echo "$OUTPUT" | grep -q "dimensions:" && \
   echo "$OUTPUT" | grep -q "usability:" && \
   echo "$OUTPUT" | grep -q "architecture:" && \
   echo "$OUTPUT" | grep -q "code_quality:" && \
   echo "$OUTPUT" | grep -q "testability:" && \
   echo "$OUTPUT" | grep -q "spec_adherence:"; then
    pass "7. bootstrap outputs quality-checklist.yaml template with 5 dimensions"
else
    fail "7. bootstrap missing quality-checklist template" "$(echo "$OUTPUT" | grep -c dimension)"
fi

# --- Test 8: outputs test-strategy.yaml template ---
if echo "$OUTPUT" | grep -q "test-strategy.yaml" && \
   echo "$OUTPUT" | grep -q "unit:" && \
   echo "$OUTPUT" | grep -q "component:" && \
   echo "$OUTPUT" | grep -q "integration:" && \
   echo "$OUTPUT" | grep -q "e2e:"; then
    pass "8. bootstrap outputs test-strategy.yaml template with 4 levels"
else
    fail "8. bootstrap missing test-strategy template" "$(echo "$OUTPUT" | grep -cE 'unit:|component:|integration:|e2e:')"
fi

# --- Test 9: outputs pattern generation instructions ---
if echo "$OUTPUT" | grep -q "ag intel learn" && \
   echo "$OUTPUT" | grep -q "anti-patterns"; then
    pass "9. bootstrap outputs pattern generation instructions with ag intel learn"
else
    fail "9. bootstrap missing pattern instructions" ""
fi

cleanup_project "$PROJECT"

# --- Test 16: handles partial STACK.md ---
PROJECT=$(create_project)
cat > "$PROJECT/STACK.md" << 'EOF'
# Stack
## Summary
- Domain: healthcare
EOF
# No language, no framework — should still work
OUTPUT=$(run_intel "$PROJECT" bootstrap 2>&1)
RC=$?

if [[ $RC -eq 0 ]] && echo "$OUTPUT" | grep -q "healthcare"; then
    pass "16. bootstrap handles partial STACK.md (domain only)"
else
    fail "16. partial STACK.md failed (rc=$RC)" "$(echo "$OUTPUT" | grep Domain)"
fi

cleanup_project "$PROJECT"

# ===================================================================
# Retro Tests
# ===================================================================
echo ""
echo "--- Retro ---"

# --- Test 10: retro runs without error on empty project ---
PROJECT=$(create_project)
OUTPUT=$(run_intel "$PROJECT" retro 2>&1)
RC=$?

if [[ $RC -eq 0 ]] && echo "$OUTPUT" | grep -q "Intelligence Retro"; then
    pass "10. ag intel retro runs on empty project"
else
    fail "10. ag intel retro failed (rc=$RC)" "$(echo "$OUTPUT" | tail -5)"
fi

cleanup_project "$PROJECT"

# --- Test 11: retro loads existing patterns ---
PROJECT=$(create_project)
cat > "$PROJECT/.agentic/intel/patterns.yaml" << 'EOF'
version: 1
description: Test patterns
patterns:

  - id: P-0001
    text: "Don't hardcode secrets"
    reason: "Security risk"
    scope: "*.py"
    severity: error
    source: manual

  - id: P-0002
    text: "Use constants for magic numbers"
    reason: "Readability"
    scope: "*.ts"
    severity: warning
    source: manual
EOF

OUTPUT=$(run_intel "$PROJECT" retro 2>&1)
if echo "$OUTPUT" | grep -q "2 existing patterns loaded"; then
    pass "11. retro loads and counts existing patterns"
else
    fail "11. retro didn't load patterns" "$(echo "$OUTPUT" | grep 'pattern')"
fi

# --- Test 12: retro shows ISSUES.md content ---
cat > "$PROJECT/.agentic/ISSUES.md" << 'EOF'
# Issues

## Memory leak in auth handler
Status: Open
Severity: High
Token refresh not releasing connections.

## Flaky test in checkout
Status: Open
Severity: Medium
Race condition in payment mock.
EOF

OUTPUT=$(run_intel "$PROJECT" retro 2>&1)
if echo "$OUTPUT" | grep -q "2 issue(s)" && \
   echo "$OUTPUT" | grep -q "Issues Analysis"; then
    pass "12. retro analyzes ISSUES.md (found 2 issues)"
else
    fail "12. retro missed ISSUES.md" "$(echo "$OUTPUT" | grep -i issue)"
fi

# --- Test 13: retro shows LESSONS.md content ---
cat > "$PROJECT/.agentic/LESSONS.md" << 'EOF'
# Lessons Learned

## L-0001: Always validate input at API boundaries
Never trust client-side validation alone.

## L-0002: Use database transactions for multi-step operations
Partial writes caused data corruption in billing.
EOF

OUTPUT=$(run_intel "$PROJECT" retro 2>&1)
if echo "$OUTPUT" | grep -q "Lessons Analysis" && \
   echo "$OUTPUT" | grep -q "lesson(s)"; then
    pass "13. retro analyzes LESSONS.md"
else
    fail "13. retro missed LESSONS.md" "$(echo "$OUTPUT" | grep -i lesson)"
fi

# --- Test 14: retro shows shipped features ---
mkdir -p "$PROJECT/.agentic/spec"
cat > "$PROJECT/.agentic/spec/FEATURES.md" << 'EOF'
# Features

| ID | Name | Status |
| F-001 | Auth | **Status**: shipped |
| F-002 | Checkout | **Status**: shipped |
| F-003 | Search | **Status**: implementing |
EOF

OUTPUT=$(run_intel "$PROJECT" retro 2>&1)
if echo "$OUTPUT" | grep -q "shipped feature(s)"; then
    pass "14. retro shows shipped features from FEATURES.md"
else
    fail "14. retro missed FEATURES.md" "$(echo "$OUTPUT" | grep -i shipped)"
fi

# --- Test 15: retro identifies unextracted lessons ---
# Lessons L-0001 and L-0002 are NOT in patterns.yaml, should be flagged
if echo "$OUTPUT" | grep -q "Lessons NOT yet in patterns.yaml" && \
   echo "$OUTPUT" | grep -q "L-0001"; then
    pass "15. retro identifies lessons not yet captured as patterns"
else
    fail "15. retro didn't flag unextracted lessons" "$(echo "$OUTPUT" | grep -A3 'NOT yet')"
fi

cleanup_project "$PROJECT"

# ===================================================================
# Summary
# ===================================================================
echo ""
echo "=== Results: ${PASS}/${TOTAL} passed, ${FAIL} failed ==="
echo ""

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
