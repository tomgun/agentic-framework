#!/usr/bin/env bash
# pre-commit-check.sh - Enforce quality gates before commit
#
# This hook validates project state before allowing commits.
# BLOCKS commit if validation fails (exit code 1).
#
# Usage:
#   bash .agentic/hooks/pre-commit-check.sh
#
# Checks:
#   1. WIP.md must not exist (work must be complete)
#   2. Shipped features must have acceptance criteria
#   3. In-progress features must have recent JOURNAL entry (<24h)
#   4. STACK.md version matches reality (where detectable)
#
# Exit codes:
#   0 - All checks pass, commit allowed
#   1 - Validation failed, commit blocked
#
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${PROJECT_ROOT}"

echo ""
echo "═══════════════════════════════════════════════════════"
echo "Pre-Commit Quality Gates"
echo "═══════════════════════════════════════════════════════"
echo ""

FAILURES=0

# Check 1: WIP.md must not exist
echo "[1/4] Checking for incomplete work (WIP.md)..."
if [[ -f "WIP.md" ]]; then
  echo "❌ BLOCKED: WIP.md exists - work is incomplete!"
  echo ""
  echo "   Work-in-progress must be completed before committing."
  echo "   Options:"
  echo "   1. Complete work: bash .agentic/tools/wip.sh complete"
  echo "   2. If work IS complete, remove WIP lock:"
  echo "      bash .agentic/tools/wip.sh complete"
  echo "   3. If work is NOT complete, finish it first"
  echo ""
  FAILURES=$((FAILURES + 1))
else
  echo "✓ No WIP.md found (work complete)"
fi

# Check 2: Shipped features must have acceptance criteria
if [[ -f "spec/FEATURES.md" ]]; then
  echo ""
  echo "[2/4] Checking shipped features have acceptance criteria..."
  
  # Extract feature IDs marked as shipped
  SHIPPED_FEATURES=$(grep -A3 "^## F-" spec/FEATURES.md | grep -B3 "Status: shipped" | grep "^## F-" | cut -d: -f1 | sed 's/^## //' || echo "")
  
  if [[ -n "$SHIPPED_FEATURES" ]]; then
    MISSING_ACCEPTANCE=""
    while IFS= read -r FEATURE_ID; do
      if [[ ! -f "spec/acceptance/${FEATURE_ID}.md" ]]; then
        MISSING_ACCEPTANCE="${MISSING_ACCEPTANCE}${FEATURE_ID}, "
      fi
    done <<< "$SHIPPED_FEATURES"
    
    if [[ -n "$MISSING_ACCEPTANCE" ]]; then
      echo "❌ BLOCKED: Shipped features missing acceptance criteria!"
      echo ""
      echo "   Features marked 'shipped' without acceptance files:"
      echo "   ${MISSING_ACCEPTANCE%, }"
      echo ""
      echo "   Create acceptance criteria:"
      echo "   - Use .agentic/spec/FEATURES.template.md as reference"
      echo "   - Define what 'done' means for each feature"
      echo "   - Or change status to 'in_progress' if not truly shipped"
      echo ""
      FAILURES=$((FAILURES + 1))
    else
      echo "✓ All shipped features have acceptance criteria"
    fi
  else
    echo "✓ No shipped features to check"
  fi
else
  echo ""
  echo "[2/4] Skipping shipped features check (Core profile, no spec/FEATURES.md)"
fi

# Check 3: In-progress features must have recent JOURNAL entry
if [[ -f "spec/FEATURES.md" ]] && [[ -f "JOURNAL.md" ]]; then
  echo ""
  echo "[3/4] Checking in-progress features have recent activity..."
  
  IN_PROGRESS_FEATURES=$(grep -A3 "^## F-" spec/FEATURES.md | grep -B3 "Status: in_progress" | grep "^## F-" | cut -d: -f1 | sed 's/^## //' || echo "")
  
  if [[ -n "$IN_PROGRESS_FEATURES" ]]; then
    # Check if JOURNAL.md was updated in last 24 hours
    if command -v stat >/dev/null 2>&1; then
      if [[ "$(uname)" == "Darwin" ]]; then
        JOURNAL_AGE_SECONDS=$(( $(date +%s) - $(stat -f %m JOURNAL.md) ))
      else
        JOURNAL_AGE_SECONDS=$(( $(date +%s) - $(stat -c %Y JOURNAL.md) ))
      fi
      
      ONE_DAY=$((24 * 60 * 60))
      if [[ $JOURNAL_AGE_SECONDS -gt $ONE_DAY ]]; then
        echo "⚠️  WARNING: In-progress features exist but JOURNAL.md not updated in 24h"
        echo ""
        echo "   Features in progress:"
        echo "$IN_PROGRESS_FEATURES" | sed 's/^/   - /'
        echo ""
        echo "   Recommendation:"
        echo "   - Update JOURNAL.md with progress summary"
        echo "   - Or change status if features are stale"
        echo ""
        echo "   (This is a warning, not blocking commit)"
        echo ""
      else
        echo "✓ In-progress features have recent JOURNAL entry"
      fi
    else
      echo "✓ Cannot check JOURNAL age (stat command unavailable)"
    fi
  else
    echo "✓ No in-progress features to check"
  fi
else
  echo ""
  echo "[3/4] Skipping in-progress features check (no spec/FEATURES.md or JOURNAL.md)"
fi

# Check 4: STACK.md version sanity (where detectable)
if [[ -f "STACK.md" ]]; then
  echo ""
  echo "[4/4] Checking STACK.md version consistency..."
  
  # Example: Check Node.js version if package.json exists
  if [[ -f "package.json" ]] && command -v node >/dev/null 2>&1; then
    STACK_NODE_VERSION=$(grep -i "node" STACK.md | grep -oP '\d+\.\d+' | head -1 || echo "")
    ACTUAL_NODE_VERSION=$(node --version | grep -oP '\d+\.\d+' | head -1 || echo "")
    
    if [[ -n "$STACK_NODE_VERSION" ]] && [[ -n "$ACTUAL_NODE_VERSION" ]]; then
      STACK_MAJOR=$(echo "$STACK_NODE_VERSION" | cut -d. -f1)
      ACTUAL_MAJOR=$(echo "$ACTUAL_NODE_VERSION" | cut -d. -f1)
      
      if [[ "$STACK_MAJOR" != "$ACTUAL_MAJOR" ]]; then
        echo "⚠️  WARNING: Node.js version mismatch"
        echo "   STACK.md: $STACK_NODE_VERSION"
        echo "   Actual: $ACTUAL_NODE_VERSION"
        echo "   Consider updating STACK.md"
        echo ""
        echo "   (This is a warning, not blocking commit)"
        echo ""
      else
        echo "✓ Node.js version consistent"
      fi
    else
      echo "✓ Cannot verify Node.js version (not specified or detected)"
    fi
  else
    echo "✓ No detectable version checks available"
  fi
else
  echo ""
  echo "[4/4] Skipping STACK.md check (file not found)"
fi

# Summary
echo ""
echo "═══════════════════════════════════════════════════════"
if [[ $FAILURES -eq 0 ]]; then
  echo "✅ ALL QUALITY GATES PASSED"
  echo "═══════════════════════════════════════════════════════"
  echo ""
  echo "Commit is ready. All checks passed."
  echo ""
  exit 0
else
  echo "🚨 COMMIT BLOCKED - $FAILURES FAILURES"
  echo "═══════════════════════════════════════════════════════"
  echo ""
  echo "Fix the issues above before committing."
  echo "Quality gates exist to prevent incomplete work from being committed."
  echo ""
  exit 1
fi

