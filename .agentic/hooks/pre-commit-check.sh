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
#   1. .agentic/WIP.md must not exist (work must be complete)
#   2. Shipped features must have acceptance criteria
#   3. In-progress features must have recent JOURNAL entry (<24h)
#   4. STACK.md version matches reality (where detectable)
#   5. Batch size warning (>10 files = too large, should re-plan)
#   6. Untracked files warning (new files not git added)
#   7. LLM behavioral test status (advisory, framework dev only)
#   8. Agent instruction file size limits (prevents context bloat)
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

# Check 1: .agentic/WIP.md must not exist
echo "[1/8] Checking for incomplete work (.agentic/WIP.md)..."
if [[ -f ".agentic/WIP.md" ]]; then
  echo "❌ BLOCKED: .agentic/WIP.md exists - work is incomplete!"
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
  echo "✓ No .agentic/WIP.md found (work complete)"
fi

# Check 2: Shipped features must have acceptance criteria
if [[ -f "spec/FEATURES.md" ]]; then
  echo ""
  echo "[2/8] Checking shipped features have acceptance criteria..."
  
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
  echo "[2/8] Skipping shipped features check (Core profile, no spec/FEATURES.md)"
fi

# Check 3: In-progress features must have recent JOURNAL entry
if [[ -f "spec/FEATURES.md" ]] && [[ -f "JOURNAL.md" ]]; then
  echo ""
  echo "[3/8] Checking in-progress features have recent activity..."
  
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
  echo "[3/8] Skipping in-progress features check (no spec/FEATURES.md or JOURNAL.md)"
fi

# Check 4: STACK.md version sanity (where detectable)
if [[ -f "STACK.md" ]]; then
  echo ""
  echo "[4/8] Checking STACK.md version consistency..."
  
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
  echo "[4/8] Skipping STACK.md check (file not found)"
fi

# Check 5: Batch size warning (small batches = quality)
echo ""
echo "[5/8] Checking batch size (small batches = quality)..."

if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
  # Count staged files
  CHANGED_FILES=$(git diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')
  
  if [[ $CHANGED_FILES -gt 15 ]]; then
    echo "⚠️  WARNING: ${CHANGED_FILES} files changed in this commit"
    echo ""
    echo "   This is a LARGE commit. Consider:"
    echo "   - Is this really ONE feature? Should it be split?"
    echo "   - Can you extract some changes into a separate commit?"
    echo "   - Small batches = easier review, safer rollback"
    echo ""
    echo "   Guideline: <10 files per feature is ideal"
    echo ""
    echo "   (This is a warning, not blocking commit)"
    echo ""
  elif [[ $CHANGED_FILES -gt 10 ]]; then
    echo "⚠️  Note: ${CHANGED_FILES} files changed (moderate batch size)"
    echo "   Consider if this could be smaller"
  elif [[ $CHANGED_FILES -gt 0 ]]; then
    echo "✓ ${CHANGED_FILES} files changed (good batch size)"
  else
    echo "✓ No staged files (nothing to commit)"
  fi
else
  echo "✓ Git not available (skipping batch size check)"
fi

# Check 6: Untracked files in project directories
echo ""
echo "[6/8] Checking for untracked files in project directories..."

if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
  # Directories that should typically have files tracked
  CHECK_DIRS=("src" "lib" "app" "assets" "public" "tests" "test" "spec" "docs" "scripts")
  
  UNTRACKED=$(git status --porcelain 2>/dev/null | grep '^??' | cut -c4-)
  
  if [[ -n "$UNTRACKED" ]]; then
    RELEVANT=""
    while IFS= read -r file; do
      for dir in "${CHECK_DIRS[@]}"; do
        if [[ "$file" == "$dir/"* ]]; then
          RELEVANT="${RELEVANT}${file}\n"
          break
        fi
      done
    done <<< "$UNTRACKED"
    
    if [[ -n "$RELEVANT" ]]; then
      echo "⚠️  WARNING: Untracked files in project directories!"
      echo ""
      echo "   Files that may need to be tracked:"
      echo -e "$RELEVANT" | sort | uniq | while read -r file; do
        [[ -n "$file" ]] && echo "   ?? $file"
      done
      echo ""
      echo "   Options:"
      echo "   - git add <files>  # to track them"
      echo "   - Add to .gitignore if intentionally untracked"
      echo ""
      echo "   (This is a warning, not blocking commit)"
      echo ""
    else
      echo "✓ No untracked files in project directories"
    fi
  else
    echo "✓ No untracked files"
  fi
else
  echo "✓ Git not available (skipping untracked check)"
fi

# Check 7: LLM behavioral test status (advisory, framework development only)
if [[ -f ".agentic/tools/llm-test-status.sh" ]] && [[ -f "tests/LLM_TEST_RESULTS.md" ]]; then
  echo ""
  echo "[7/8] Checking LLM behavioral test status..."
  if bash .agentic/tools/llm-test-status.sh --quiet 2>/dev/null; then
    echo "✓ LLM behavioral tests are current"
  else
    echo "💡 Tip: LLM behavioral tests may need updating"
    echo "   Run: bash .agentic/tools/llm-test-status.sh"
    echo "   (This is advisory, not blocking commit)"
  fi
fi

# Check 8: Agent instruction file size limits (prevents context bloat)
echo ""
echo "[8/8] Checking agent instruction file sizes..."

SIZE_WARNINGS=0

# CLAUDE.md limit: 500 lines
if [[ -f ".agentic/agents/claude/CLAUDE.md" ]]; then
  CLAUDE_LINES=$(wc -l < ".agentic/agents/claude/CLAUDE.md" | tr -d ' ')
  if [[ $CLAUDE_LINES -gt 500 ]]; then
    echo "⚠️  WARNING: CLAUDE.md has $CLAUDE_LINES lines (limit: 500)"
    echo "   Large instruction files cause attention drift."
    echo "   Consider consolidating or moving content to referenced docs."
    SIZE_WARNINGS=$((SIZE_WARNINGS + 1))
  else
    echo "✓ CLAUDE.md: $CLAUDE_LINES/500 lines"
  fi
fi

# agent_operating_guidelines.md limit: 1200 lines
if [[ -f ".agentic/agents/shared/agent_operating_guidelines.md" ]]; then
  GUIDELINES_LINES=$(wc -l < ".agentic/agents/shared/agent_operating_guidelines.md" | tr -d ' ')
  if [[ $GUIDELINES_LINES -gt 1200 ]]; then
    echo "⚠️  WARNING: agent_operating_guidelines.md has $GUIDELINES_LINES lines (limit: 1200)"
    echo "   Consider consolidating or splitting into tool-specific files."
    SIZE_WARNINGS=$((SIZE_WARNINGS + 1))
  else
    echo "✓ agent_operating_guidelines.md: $GUIDELINES_LINES/1200 lines"
  fi
fi

if [[ $SIZE_WARNINGS -gt 0 ]]; then
  echo ""
  echo "   (File size warnings are advisory, not blocking commit)"
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

