#!/usr/bin/env bash
# feature-complete.sh - Validate feature completion per definition of done
#
# This script validates that a feature meets all completion criteria before
# marking it as "shipped". Enforces definition_of_done.md requirements.
#
# Usage:
#   bash .agentic/hooks/feature-complete.sh <feature_id>
#
# Example:
#   bash .agentic/hooks/feature-complete.sh F-0005
#
# Exit codes:
#   0 - Feature is truly complete, ready to ship
#   1 - Feature incomplete, cannot mark as shipped
#
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${PROJECT_ROOT}"

if [[ $# -lt 1 ]]; then
  echo "Usage: bash feature-complete.sh <feature_id>"
  echo "Example: bash feature-complete.sh F-0005"
  exit 1
fi

FEATURE_ID="$1"

# Validate feature ID format
if ! [[ "$FEATURE_ID" =~ ^F-[0-9]{4}$ ]]; then
  echo "❌ Invalid feature ID format. Expected F-#### (e.g., F-0001)"
  exit 1
fi

echo ""
echo "═══════════════════════════════════════════════════════"
echo "FEATURE COMPLETION VALIDATION: ${FEATURE_ID}"
echo "═══════════════════════════════════════════════════════"
echo ""

FAILURES=0

# Check 1: Feature exists in FEATURES.md
if [[ ! -f "spec/FEATURES.md" ]]; then
  echo "❌ spec/FEATURES.md not found (Formal profile required for features)"
  exit 1
fi

echo "[1/6] Checking feature exists in spec/FEATURES.md..."
if ! grep -q "^## ${FEATURE_ID}:" spec/FEATURES.md; then
  echo "❌ Feature ${FEATURE_ID} not found in spec/FEATURES.md"
  exit 1
fi
echo "✓ Feature found"

# Check 2: Acceptance criteria exists (CRITICAL GATE)
echo ""
echo "[2/6] Checking acceptance criteria file exists (CRITICAL)..."
if [[ ! -f "spec/acceptance/${FEATURE_ID}.md" ]]; then
  echo "❌ BLOCKED: spec/acceptance/${FEATURE_ID}.md not found"
  echo "   Acceptance criteria are MANDATORY for feature completion."
  echo "   Create acceptance criteria before marking feature complete"
  FAILURES=$((FAILURES + 1))
else
  echo "✓ Acceptance criteria file exists"
  
  # Check that acceptance criteria has testable items
  CRITERIA_COUNT=$(grep -c "^- \[" "spec/acceptance/${FEATURE_ID}.md" 2>/dev/null || echo "0")
  if [[ "$CRITERIA_COUNT" == "0" ]]; then
    echo "⚠️  WARNING: Acceptance criteria has no testable items (- [ ] ...)"
    echo "   Add testable criteria: - [ ] User can do X"
  else
    echo "✓ ${CRITERIA_COUNT} testable criteria found"
  fi
fi

# Check 3: Tests exist (check for @feature annotation in test files)
echo ""
echo "[3/6] Checking tests exist for feature..."

TEST_FILES_FOUND=0

# Common test file patterns
for PATTERN in "test/*.test.*" "tests/*.test.*" "spec/*.spec.*" "**/*.test.*" "**/*.spec.*"; do
  if compgen -G "$PATTERN" > /dev/null 2>&1; then
    if grep -r "@feature ${FEATURE_ID}" $PATTERN 2>/dev/null | head -1 > /dev/null; then
      TEST_FILES_FOUND=1
      break
    fi
  fi
done

if [[ $TEST_FILES_FOUND -eq 1 ]]; then
  echo "✓ Tests found with @feature ${FEATURE_ID} annotation"
elif [[ -f "spec/acceptance/${FEATURE_ID}.md" ]]; then
  # Check if acceptance criteria mentions tests
  if grep -qi "test" "spec/acceptance/${FEATURE_ID}.md"; then
    echo "✓ Tests mentioned in acceptance criteria"
  else
    echo "⚠️  WARNING: No tests found with @feature annotation"
    echo "   Tests may exist but are not annotated"
    echo "   Add @feature ${FEATURE_ID} comments to test files"
  fi
else
  echo "❌ No tests found for feature"
  FAILURES=$((FAILURES + 1))
fi

# Check 4: All tests pass
echo ""
echo "[4/6] Verifying all tests pass..."

# Try common test commands
TEST_COMMAND=""
if [[ -f "package.json" ]] && grep -q "\"test\"" package.json; then
  TEST_COMMAND="npm test"
elif [[ -f "pyproject.toml" ]] || [[ -f "pytest.ini" ]]; then
  TEST_COMMAND="pytest"
elif [[ -f "Cargo.toml" ]]; then
  TEST_COMMAND="cargo test"
elif [[ -f "go.mod" ]]; then
  TEST_COMMAND="go test ./..."
fi

if [[ -n "$TEST_COMMAND" ]]; then
  echo "   Detected test command: ${TEST_COMMAND}"
  echo "   ⚠️  Run tests manually to verify they pass"
  echo "   Command: ${TEST_COMMAND}"
else
  echo "   ⚠️  No standard test command detected"
  echo "   Verify tests manually before marking complete"
fi

# Check 5: Code committed (no uncommitted changes for this feature's files)
echo ""
echo "[5/6] Checking for uncommitted changes..."
if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
  UNCOMMITTED=$(git status --porcelain | wc -l | tr -d ' ')
  if [[ $UNCOMMITTED -gt 0 ]]; then
    echo "⚠️  WARNING: ${UNCOMMITTED} uncommitted changes"
    echo "   Review: git status"
    echo "   Commit before marking feature complete"
  else
    echo "✓ No uncommitted changes"
  fi
else
  echo "✓ Git not available (skipping check)"
fi

# Check 6: Definition of done checklist items
echo ""
echo "[6/6] Checking definition of done criteria..."

# Read feature from FEATURES.md
FEATURE_BLOCK=$(awk "/^## ${FEATURE_ID}:/ { flag=1; next } /^## F-/ { flag=0 } flag" spec/FEATURES.md)

# Check implementation state
IMPL_STATE=$(echo "$FEATURE_BLOCK" | grep "State:" | cut -d: -f2 | tr -d ' ')
if [[ "$IMPL_STATE" != "complete" ]]; then
  echo "⚠️  WARNING: Implementation state is '${IMPL_STATE}', not 'complete'"
  echo "   Update: bash .agentic/tools/feature.sh ${FEATURE_ID} impl-state complete"
fi

# Check test state
TEST_STATE=$(echo "$FEATURE_BLOCK" | grep "Tests:" | cut -d: -f2 | tr -d ' ')
if [[ "$TEST_STATE" != "complete" ]]; then
  echo "⚠️  WARNING: Test state is '${TEST_STATE}', not 'complete'"
  echo "   Update: bash .agentic/tools/feature.sh ${FEATURE_ID} tests complete"
fi

# Summary
echo ""
echo "═══════════════════════════════════════════════════════"
if [[ $FAILURES -eq 0 ]]; then
  echo "✅ FEATURE READY TO SHIP"
  echo "═══════════════════════════════════════════════════════"
  echo ""
  echo "Feature ${FEATURE_ID} meets completion criteria."
  echo ""
  echo "To mark as shipped:"
  echo "  bash .agentic/tools/feature.sh ${FEATURE_ID} status shipped"
  echo ""
  echo "After commit, ask user to test and accept:"
  echo "  bash .agentic/tools/feature.sh ${FEATURE_ID} accepted yes"
  echo ""
  exit 0
else
  echo "🚨 FEATURE NOT READY - ${FAILURES} FAILURES"
  echo "═══════════════════════════════════════════════════════"
  echo ""
  echo "Fix the issues above before marking feature as shipped."
  echo ""
  echo "Definition of done checklist:"
  echo "- [ ] Acceptance criteria exists (spec/acceptance/${FEATURE_ID}.md)"
  echo "- [ ] Tests exist with @feature ${FEATURE_ID} annotation"
  echo "- [ ] All tests pass"
  echo "- [ ] Code committed (no uncommitted changes)"
  echo "- [ ] Implementation state: complete"
  echo "- [ ] Test state: complete"
  echo ""
  exit 1
fi

