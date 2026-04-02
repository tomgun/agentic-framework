#!/usr/bin/env bash
# test_intel_phase_queries.sh — Tests for F-041 Intelligence Engine Phase 4
#
# Tests:
#   1. ag intel architecture — outputs ADR, NFR, quality check sections
#   2. ag intel spec F-XXXX — outputs feature landscape, contract patterns
#   3. ag intel implement F-XXXX — outputs conventions, patterns
#   4. ag intel test F-XXXX — outputs test strategy, infrastructure
#   5. ag intel help — lists Phase 4 commands
#   6. Zero-arg mode — all commands work without F-XXXX
#   7. Formal profile — warns when F-XXXX missing
#   8. Discovery mode — filters [formal] items in quality checklist

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PASS=0
FAIL=0
TOTAL=0

pass() { echo "  ✅ $1"; PASS=$((PASS + 1)); TOTAL=$((TOTAL + 1)); }
fail() { echo "  ❌ $1: $2"; FAIL=$((FAIL + 1)); TOTAL=$((TOTAL + 1)); }

# Strip ANSI escape codes
strip_ansi() { sed 's/\x1b\[[0-9;]*m//g'; }

# Run an intel function in a temp project context
run_intel() {
    local project_dir="$1"
    local func="$2"
    shift 2
    local args=("$@")

    ROOT_DIR="$project_dir" \
    _AGENTIC_SETTINGS_LOADED="" _AGENTIC_PATHS_LOADED="" \
    _SETTINGS_ROOT_DIR="$project_dir" _SETTINGS_STACK_FILE="$project_dir/STACK.md" \
    bash -c '
        source "'"$REPO_ROOT"'/.agentic/lib/paths.sh" 2>/dev/null || true
        source "'"$REPO_ROOT"'/.agentic/lib/settings.sh" 2>/dev/null || true
        PROFILE=$(get_setting "profile" "discovery" 2>/dev/null || echo "discovery")
        RED="\033[0;31m" GREEN="\033[0;32m" YELLOW="\033[1;33m" BLUE="\033[0;34m" BOLD="\033[1m" DIM="\033[2m" NC="\033[0m"
        ROOT_DIR="'"$project_dir"'"
        source "'"$project_dir"'/.agentic/lib/tools/commands/intel.sh"
        '"$func"' '"${args[*]:-}"'
    ' 2>&1 | strip_ansi
}

# Create temp project with all Phase 4 dependencies
create_project() {
    local dir
    dir=$(mktemp -d)
    mkdir -p "$dir/.agentic/intel" "$dir/.agentic/lib/tools/commands" "$dir/.agentic/lib/presets"
    mkdir -p "$dir/.agentic/spec/adr" "$dir/.agentic/spec/contracts"
    mkdir -p "$dir/.agentic/journal" "$dir/.agentic/session"
    mkdir -p "$dir/tests"

    # Copy required libraries
    cp "$REPO_ROOT/.agentic/lib/settings.sh" "$dir/.agentic/lib/"
    cp -r "$REPO_ROOT/.agentic/lib/presets" "$dir/.agentic/lib/" 2>/dev/null || true
    cp "$REPO_ROOT/.agentic/lib/paths.sh" "$dir/.agentic/lib/" 2>/dev/null || true
    cp "$REPO_ROOT/.agentic/lib/tools/commands/intel.sh" "$dir/.agentic/lib/tools/commands/"

    # STACK.md — discovery profile
    cat > "$dir/STACK.md" << 'EOF'
# Stack

## Settings
- profile: discovery
- state_enforcement: off
- feature_tracking: no

## Technical
- Language: bash
- Testing: bats
EOF

    # ADR file
    cat > "$dir/.agentic/spec/adr/ADR-001-test.md" << 'EOF'
# ADR-001: Test Architecture Decision

Status: accepted

## Decision

Use modular architecture for all components.
EOF

    # NFR file
    cat > "$dir/.agentic/spec/NFR.md" << 'EOF'
# Non-Functional Requirements

## NFR-0001: Performance
All CLI commands must complete in under 5 seconds.

## NFR-0002: Compatibility
Support bash 4+ on Linux and macOS.
EOF

    # CONTEXT_PACK
    cat > "$dir/CONTEXT_PACK.md" << 'EOF'
# Context Pack

## Overview
Test project for intel phase queries.

## Architecture
Modular bash scripts.
EOF

    # Conventions
    cat > "$dir/.agentic/conventions.md" << 'EOF'
# Conventions

## Naming
Use snake_case for functions and variables.

## Testing
Write tests alongside code.
EOF

    # Patterns
    cat > "$dir/.agentic/intel/patterns.yaml" << 'EOF'
version: 1
patterns:
  - id: P-0001
    text: "Always validate inputs"
    reason: "Prevents injection attacks"
    scope: "*.sh"
    severity: error
    source: manual

  - id: P-0002
    text: "Use explicit return codes"
    reason: "Implicit returns are fragile"
    scope: "*.sh"
    severity: warning
    source: manual
EOF

    # Quality checklist with [formal] items
    cat > "$dir/.agentic/intel/quality-checklist.yaml" << 'EOF'
version: 1
source: bootstrap
stack: "bash"
dimensions:
  usability:
    planning:
      - "Check user workflow impact"
    spec:
      - "Define clear error messages"
    implementation:
      - "Add --help to all commands"
    testing:
      - "Test with real user scenarios"
  architecture:
    planning:
      - "Review ADRs for conflicts"
    spec:
      - "Identify integration points"
    implementation:
      - "Follow modular patterns"
    testing:
      - "Integration tests for boundaries"
  code_quality:
    planning:
      - "Plan for code review"
    spec:
      - "Define quality criteria"
    implementation:
      - "Run shellcheck on all scripts"
    testing:
      - "Measure test coverage"
  testability:
    planning:
      - "Design testable interfaces"
    spec:
      - "Specify test requirements"
    implementation:
      - "Mock external dependencies"
    testing:
      - "Test isolation verification"
  spec_adherence:
    planning:
      - "Formal spec review process [formal]"
      - "Check spec completeness"
    spec:
      - "AC must be verifiable [formal]"
      - "Link to NFRs"
    implementation:
      - "Contract assertion coverage [formal]"
      - "Trace code to spec"
    testing:
      - "Verify all ACs have tests [formal]"
      - "Run contract verify commands"
EOF

    # Test strategy
    cat > "$dir/.agentic/intel/test-strategy.yaml" << 'EOF'
version: 1
source: bootstrap
stack: "bash"
levels:
  unit:
    focus: "Individual function behavior"
    framework: "bats"
    colocate: false
    patterns:
      - "Test one function per test case"
    antipatterns:
      - "Testing internal implementation details"
  integration:
    focus: "Component interaction"
    framework: "bats"
    colocate: false
    patterns:
      - "Test with real file system"
    antipatterns:
      - "Mocking everything"
EOF

    # Contract
    cat > "$dir/.agentic/spec/contracts/F-099.yaml" << 'EOF'
id: F-099
name: Test Feature
lifecycle: implementing
assertions:
  - id: AC-001
    text: Test assertion
    type: behavioral
  - id: AC-002
    text: Structural check
    type: structural
EOF

    # FEATURES.md
    cat > "$dir/.agentic/spec/FEATURES.md" << 'EOF'
# Features

## F-099: Test Feature

**Status**: in_progress

## F-098: Previous Feature

**Status**: shipped
EOF

    # ISSUES.md
    cat > "$dir/.agentic/ISSUES.md" << 'EOF'
# Known Issues

## Edge case in pattern matching
Glob patterns don't match deeply nested paths.

## Performance regression in scan
Large repos take >10s to scan.
EOF

    # Init git for file counting
    cd "$dir" && git init -q && git add -A && git commit -q -m "init" 2>/dev/null || true

    echo "$dir"
}

cleanup_project() {
    [[ -d "$1" ]] && rm -rf "$1"
}

echo ""
echo "=== F-041 Phase 4: Phase-Aware Query Tests ==="
echo ""

TMP_DIR=$(create_project)
trap "cleanup_project '$TMP_DIR'" EXIT

# --- Test 1: architecture command ---
echo "Test 1: ag intel architecture"
output=$(run_intel "$TMP_DIR" "_intel_architecture")

echo "$output" | grep -q "Architecture Decision Records" && pass "shows ADR section" || fail "missing ADR section" ""
echo "$output" | grep -q "ADR-001" && pass "lists ADR-001" || fail "missing ADR-001" ""
echo "$output" | grep -q "Non-Functional Requirements" && pass "shows NFR section" || fail "missing NFR section" ""
echo "$output" | grep -q "NFR-0001" && pass "lists NFR entries" || fail "missing NFR entries" ""
echo "$output" | grep -q "Context Pack Summary" && pass "shows context pack" || fail "missing context pack" ""
echo "$output" | grep -q "Quality Checks" && pass "shows quality checks" || fail "missing quality checks" ""

# --- Test 2: spec command ---
echo ""
echo "Test 2: ag intel spec F-099"
output=$(run_intel "$TMP_DIR" "_intel_spec" "F-099")

echo "$output" | grep -q "Active Spec: F-099" && pass "shows active spec" || fail "missing active spec" ""
echo "$output" | grep -q "Feature Landscape" && pass "shows feature landscape" || fail "missing feature landscape" ""
echo "$output" | grep -q "Contract Patterns" && pass "shows contract patterns" || fail "missing contract patterns" ""
echo "$output" | grep -q "NFR Constraints" && pass "shows NFR constraints" || fail "missing NFR constraints" ""
echo "$output" | grep -q "Quality Checks" && pass "shows quality checks" || fail "missing quality checks" ""

# --- Test 3: implement command ---
echo ""
echo "Test 3: ag intel implement F-099"
output=$(run_intel "$TMP_DIR" "_intel_implement" "F-099")

echo "$output" | grep -q "Active Spec: F-099" && pass "shows active spec" || fail "missing active spec" ""
echo "$output" | grep -q "Code Conventions" && pass "shows conventions" || fail "missing conventions" ""
echo "$output" | grep -q "Enforced Patterns" && pass "shows patterns" || fail "missing patterns" ""
echo "$output" | grep -q "2 active patterns" && pass "correct pattern count" || fail "wrong pattern count" ""
echo "$output" | grep -q "Quality Checks" && pass "shows quality checks" || fail "missing quality checks" ""

# --- Test 4: test command ---
echo ""
echo "Test 4: ag intel test F-099"
output=$(run_intel "$TMP_DIR" "_intel_test" "F-099")

echo "$output" | grep -q "Active Spec: F-099" && pass "shows active spec" || fail "missing active spec" ""
echo "$output" | grep -q "Test Strategy" && pass "shows test strategy" || fail "missing test strategy" ""
echo "$output" | grep -q "unit" && pass "shows unit level" || fail "missing unit level" ""
echo "$output" | grep -q "Test Infrastructure" && pass "shows test infrastructure" || fail "missing test infrastructure" ""
echo "$output" | grep -q "Known Issues" && pass "shows known issues" || fail "missing known issues" ""
echo "$output" | grep -q "2 known issue" && pass "correct issue count" || fail "wrong issue count" ""
echo "$output" | grep -q "Quality Checks" && pass "shows quality checks" || fail "missing quality checks" ""

# --- Test 5: help command ---
echo ""
echo "Test 5: ag intel help"
output=$(run_intel "$TMP_DIR" "_intel_help")

echo "$output" | grep -q "Phase-Aware Queries" && pass "shows section header" || fail "missing section header" ""
for cmd in architecture spec implement test; do
    echo "$output" | grep -q "$cmd" && pass "lists $cmd" || fail "missing $cmd" ""
done

# --- Test 6: zero-arg mode ---
echo ""
echo "Test 6: Zero-arg mode"
output=$(run_intel "$TMP_DIR" "_intel_implement")
echo "$output" | grep -q "Implementation Phase" && pass "implement works without F-XXXX" || fail "implement fails without F-XXXX" ""
echo "$output" | grep -qv "Active Spec:" && pass "no spec section without F-XXXX" || fail "unexpected spec section" ""

output=$(run_intel "$TMP_DIR" "_intel_test")
echo "$output" | grep -q "Testing Phase" && pass "test works without F-XXXX" || fail "test fails without F-XXXX" ""

output=$(run_intel "$TMP_DIR" "_intel_spec")
echo "$output" | grep -q "Spec" && pass "spec works without F-XXXX" || fail "spec fails without F-XXXX" ""

# --- Test 7: formal profile warns on missing F-XXXX ---
echo ""
echo "Test 7: Formal profile warning"
sed -i 's/profile: discovery/profile: formal/' "$TMP_DIR/STACK.md"

output=$(run_intel "$TMP_DIR" "_intel_implement")
echo "$output" | grep -q "Feature ID recommended" && pass "formal warns on missing F-XXXX" || fail "no formal warning" ""

output=$(run_intel "$TMP_DIR" "_intel_spec")
echo "$output" | grep -q "Feature ID recommended" && pass "spec warns in formal" || fail "spec no formal warning" ""

output=$(run_intel "$TMP_DIR" "_intel_test")
echo "$output" | grep -q "Feature ID recommended" && pass "test warns in formal" || fail "test no formal warning" ""

sed -i 's/profile: formal/profile: discovery/' "$TMP_DIR/STACK.md"

# --- Test 8: Discovery filters [formal] items ---
echo ""
echo "Test 8: Discovery mode filters [formal] items"
output=$(run_intel "$TMP_DIR" "_intel_quality_for_phase" "planning")

echo "$output" | grep -q "Check spec completeness" && pass "shows non-formal item" || fail "missing non-formal item" ""
echo "$output" | grep -qv "Formal spec review process" && pass "filters [formal] item" || fail "[formal] item not filtered" ""

# Check intent_adherence rename
echo "$output" | grep -q "intent_adherence" && pass "renames spec_adherence to intent_adherence" || fail "missing intent_adherence rename" ""

# --- Summary ---
echo ""
echo "======================================="
echo "Results: $PASS passed, $FAIL failed (of $TOTAL)"
echo "======================================="

exit $FAIL
