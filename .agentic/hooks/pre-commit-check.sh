#!/usr/bin/env bash
# pre-commit-check.sh - Enforce quality gates before commit
#
# This hook validates project state before allowing commits.
# BLOCKS commit if validation fails (exit code 1).
#
# Usage:
#   bash .agentic/hooks/pre-commit-check.sh [--mode fast|full]
#
# Checks:
#   1.  .agentic-state/WIP.md must not exist (work must be complete)
#   2.  Shipped features must have acceptance criteria
#   3.  JOURNAL.md updated since last commit (BLOCKING)
#   4.  STACK.md version matches reality (where detectable)
#   5.  Batch size warning (>10 files = too large, should re-plan)
#   6.  Test execution (BLOCKING - tests must pass)
#   7.  Complexity limits (BLOCKING - max files, lines, file length)
#   8.  Untracked files warning (new files not git added)
#   9.  LLM behavioral test status (advisory, framework dev only)
#   10. Agent instruction file size limits (prevents context bloat)
#   3c. FEATURES.md updated when feature spec files changed (BLOCKING, Formal only)
#   3d. NFR.md updated when NFR spec files changed (BLOCKING, Formal only)
#   11. Branch policy for PR workflow (blocks commit to main if pull_request mode)
#   13. Test co-presence check (advisory, full mode only — warns when source files lack tests)
#
# Escape hatches (use sparingly, blocked on main/master):
#   SKIP_TESTS=1      Skip test execution
#   SKIP_COMPLEXITY=1  Skip complexity limits
#   SKIP_STALENESS=1   Skip JOURNAL/STATUS/FEATURES staleness checks
#
# Exit codes:
#   0 - All checks pass, commit allowed
#   1 - Validation failed, commit blocked
#
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${PROJECT_ROOT}"

# Source shared settings
source "${PROJECT_ROOT}/.agentic/lib/settings.sh"

# === Mode flag ===
# --mode fast: skip slow/advisory checks (4,5,6,8,9,10,12,13)
# --mode full: run all checks (default when called directly)
_FAST_MODE=0
for _arg in "$@"; do
    case "$_arg" in
        --mode)
            :  # next arg is the value
            ;;
        fast)
            _FAST_MODE=1
            ;;
        full)
            _FAST_MODE=0
            ;;
    esac
done

# === Escape Hatches ===
# For legitimate bypasses (WIP branches, urgent hotfixes)
# NEVER use on main/master - blocked below

CURRENT_BRANCH=""
if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
  CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
fi

# Block escape hatches on main/master
if [[ "$CURRENT_BRANCH" == "main" || "$CURRENT_BRANCH" == "master" ]]; then
  if [[ -n "${SKIP_TESTS:-}" || -n "${SKIP_COMPLEXITY:-}" || -n "${SKIP_STALENESS:-}" ]]; then
    echo "❌ BLOCKED: Cannot use SKIP_* environment variables on $CURRENT_BRANCH"
    echo "   Escape hatches are only allowed on feature branches."
    exit 1
  fi
fi

# Show escape hatch warnings
if [[ -n "${SKIP_TESTS:-}" ]]; then
  echo "⚠️  SKIP_TESTS set - skipping test execution"
  echo "   Only use for WIP commits on feature branches!"
  echo ""
fi

if [[ -n "${SKIP_COMPLEXITY:-}" ]]; then
  echo "⚠️  SKIP_COMPLEXITY set - skipping complexity limits"
  echo "   Only use for large refactors with review!"
  echo ""
fi

if [[ -n "${SKIP_STALENESS:-}" ]]; then
  echo "⚠️  SKIP_STALENESS set - skipping JOURNAL/STATUS staleness checks"
  echo "   Only use for quick fixes on feature branches!"
  echo ""
fi

echo ""
echo "═══════════════════════════════════════════════════════"
echo "Pre-Commit Quality Gates"
echo "═══════════════════════════════════════════════════════"
echo ""

# Show diff stats prominently (helps human review proportionality)
if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
  STAGED_COUNT=$(git diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')
  if [[ $STAGED_COUNT -gt 0 ]]; then
    echo "Change Summary:"
    git diff --cached --stat 2>/dev/null | tail -10
    TOTAL_LINES=$(git diff --cached --numstat 2>/dev/null | awk '{sum+=$1+$2} END {print sum+0}')
    echo ""
    echo "Total: ${TOTAL_LINES} lines changed across ${STAGED_COUNT} files"
    echo "Does this seem proportional to the task?"
    echo ""
    echo "───────────────────────────────────────────────────────"
    echo ""
  fi
fi

# Check for scope drift (warning only)
if [[ -f ".agentic/tools/scope_check.sh" ]]; then
  SCOPE_OUTPUT=$(bash .agentic/tools/scope_check.sh 2>/dev/null || true)
  if [[ -n "$SCOPE_OUTPUT" ]]; then
    echo "$SCOPE_OUTPUT"
    echo "───────────────────────────────────────────────────────"
    echo ""
  fi
fi

FAILURES=0

# Check 1: .agentic-state/WIP.md must not exist
echo "[1/13] Checking for incomplete work (.agentic-state/WIP.md)..."
if [[ -f ".agentic-state/WIP.md" ]]; then
  echo "❌ BLOCKED: .agentic-state/WIP.md exists - work is incomplete!"
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
  echo "✓ No .agentic-state/WIP.md found (work complete)"
fi

# Check 2: Shipped features must have acceptance criteria
if [[ -f "spec/FEATURES.md" ]]; then
  echo ""
  echo "[2/13] Checking shipped features have acceptance criteria..."
  
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
  echo "[2/13] Skipping shipped features check (Discovery profile, no spec/FEATURES.md)"
  echo ""
  echo "  📋 Discovery checklist (review, not blocking):"
  echo "     □ Defined what success looks like (even 2-3 bullet points)"
  echo "     □ Tested it actually works"
fi

# Check 3: JOURNAL.md updated since last commit (BLOCKING)
# Uses commit-relative staleness: was JOURNAL.md modified after the last commit?
# This catches multiple commits in quick succession where only the first gets journaled.
# Works correctly in git worktrees (git log resolves per-worktree HEAD).
JOURNAL_PATH=""
if [[ -f ".agentic-journal/JOURNAL.md" ]]; then
  JOURNAL_PATH=".agentic-journal/JOURNAL.md"
elif [[ -f "JOURNAL.md" ]]; then
  JOURNAL_PATH="JOURNAL.md"
fi

if [[ -n "$JOURNAL_PATH" ]]; then
  echo ""
  echo "[3/13] Checking JOURNAL.md freshness..."

  if [[ -n "${SKIP_STALENESS:-}" ]]; then
    echo "  ⚠ Skipped (SKIP_STALENESS set)"
  else
    LAST_COMMIT_TIME=$(git log -1 --format=%ct 2>/dev/null || echo "")

    if [[ -z "$LAST_COMMIT_TIME" ]]; then
      echo "✓ First commit - JOURNAL.md check skipped"
    elif git diff --cached --name-only 2>/dev/null | grep -q "JOURNAL.md"; then
      echo "✓ JOURNAL.md is being updated in this commit"
    elif command -v stat >/dev/null 2>&1; then
      if [[ "$(uname)" == "Darwin" ]]; then
        JOURNAL_MTIME=$(stat -f %m "$JOURNAL_PATH")
      else
        JOURNAL_MTIME=$(stat -c %Y "$JOURNAL_PATH")
      fi

      if [[ $JOURNAL_MTIME -gt $LAST_COMMIT_TIME ]]; then
        echo "✓ JOURNAL.md updated since last commit"
      else
        echo "❌ BLOCKED: JOURNAL.md not updated since last commit"
        echo ""
        echo "   Update before committing:"
        echo "   bash .agentic/tools/journal.sh \"Topic\" \"Done\" \"Next\" \"Blockers\""
        echo ""
        echo "   To skip (feature branches only): SKIP_STALENESS=1 git commit ..."
        echo ""
        FAILURES=$((FAILURES + 1))
      fi
    else
      echo "✓ Cannot check JOURNAL age (stat command unavailable)"
    fi
  fi
else
  echo ""
  echo "[3/13] Skipping JOURNAL.md check (file not found)"
fi

# Check 3b: STATUS.md updated since last commit (BLOCKING)
if [[ -f "STATUS.md" ]]; then
  echo ""
  echo "[3b/13] Checking STATUS.md freshness..."

  if [[ -n "${SKIP_STALENESS:-}" ]]; then
    echo "  ⚠ Skipped (SKIP_STALENESS set)"
  else
    LAST_COMMIT_TIME=${LAST_COMMIT_TIME:-$(git log -1 --format=%ct 2>/dev/null || echo "")}

    if [[ -z "$LAST_COMMIT_TIME" ]]; then
      echo "✓ First commit - STATUS.md check skipped"
    elif git diff --cached --name-only 2>/dev/null | grep -q "STATUS.md"; then
      echo "✓ STATUS.md is being updated in this commit"
    elif command -v stat >/dev/null 2>&1; then
      if [[ "$(uname)" == "Darwin" ]]; then
        STATUS_MTIME=$(stat -f %m STATUS.md)
      else
        STATUS_MTIME=$(stat -c %Y STATUS.md)
      fi

      if [[ $STATUS_MTIME -gt $LAST_COMMIT_TIME ]]; then
        echo "✓ STATUS.md updated since last commit"
      else
        echo "❌ BLOCKED: STATUS.md not updated since last commit"
        echo ""
        echo "   Update before committing:"
        echo "   bash .agentic/tools/status.sh focus \"Current task\""
        echo ""
        echo "   To skip (feature branches only): SKIP_STALENESS=1 git commit ..."
        echo ""
        FAILURES=$((FAILURES + 1))
      fi
    else
      echo "✓ Cannot check STATUS.md age (stat command unavailable)"
    fi
  fi
fi

# Check 3c: FEATURES.md updated when feature spec files changed (Formal, BLOCKING)
FEATURE_SPEC_STAGED=$(git diff --cached --name-only 2>/dev/null | grep "^spec/" | grep -v "^spec/NFR\.md$" | grep -v "^spec/acceptance/NFR-" | grep -v "^$" || true)
if [[ -n "$FEATURE_SPEC_STAGED" ]] && [[ -f "spec/FEATURES.md" ]]; then
  echo ""
  echo "[3c/13] Checking FEATURES.md freshness (feature spec files staged)..."

  if [[ -n "${SKIP_STALENESS:-}" ]]; then
    echo "  ⚠ Skipped (SKIP_STALENESS set)"
  else
    # Check if FEATURES.md is also staged (being updated)
    if git diff --cached --name-only 2>/dev/null | grep -q "FEATURES.md"; then
      echo "✓ FEATURES.md is staged alongside spec changes"
    else
      # Check mtime like JOURNAL/STATUS pattern
      LAST_COMMIT_TIME=${LAST_COMMIT_TIME:-$(git log -1 --format=%ct 2>/dev/null || echo "")}
      if [[ -n "$LAST_COMMIT_TIME" ]]; then
        if command -v stat >/dev/null 2>&1; then
          if [[ "$(uname)" == "Darwin" ]]; then
            FEATURES_MTIME=$(stat -f %m "spec/FEATURES.md" 2>/dev/null || echo "0")
          else
            FEATURES_MTIME=$(stat -c %Y "spec/FEATURES.md" 2>/dev/null || echo "0")
          fi

          if [[ "$FEATURES_MTIME" -lt "$LAST_COMMIT_TIME" ]]; then
            echo "❌ BLOCKED: FEATURES.md not updated but spec files are staged"
            echo "   Staged spec files: $(echo $FEATURE_SPEC_STAGED | tr '\n' ' ')"
            echo ""
            echo "   Update with: bash .agentic/tools/feature.sh F-#### status <status>"
            echo ""
            echo "   To skip (feature branches only): SKIP_STALENESS=1 git commit ..."
            echo ""
            FAILURES=$((FAILURES + 1))
          else
            echo "✓ FEATURES.md updated since last commit"
          fi
        fi
      fi
    fi
  fi
fi

# Check 3d: NFR.md updated when NFR spec files changed (Formal, BLOCKING)
NFR_SPEC_STAGED=$(git diff --cached --name-only 2>/dev/null | grep -E "^spec/(NFR\.md|acceptance/NFR-)" || true)
if [[ -n "$NFR_SPEC_STAGED" ]] && [[ -f "spec/NFR.md" ]]; then
  echo ""
  echo "[3d/13] Checking NFR.md freshness (NFR spec files staged)..."

  if [[ -n "${SKIP_STALENESS:-}" ]]; then
    echo "  ⚠ Skipped (SKIP_STALENESS set)"
  else
    if git diff --cached --name-only 2>/dev/null | grep -q "^spec/NFR\.md$"; then
      echo "✓ NFR.md is staged alongside NFR spec changes"
    else
      LAST_COMMIT_TIME=${LAST_COMMIT_TIME:-$(git log -1 --format=%ct 2>/dev/null || echo "")}
      if [[ -n "$LAST_COMMIT_TIME" ]]; then
        if command -v stat >/dev/null 2>&1; then
          if [[ "$(uname)" == "Darwin" ]]; then
            NFR_MTIME=$(stat -f %m "spec/NFR.md" 2>/dev/null || echo "0")
          else
            NFR_MTIME=$(stat -c %Y "spec/NFR.md" 2>/dev/null || echo "0")
          fi

          if [[ "$NFR_MTIME" -lt "$LAST_COMMIT_TIME" ]]; then
            echo "❌ BLOCKED: NFR.md not updated but NFR spec files are staged"
            echo "   Staged NFR files: $(echo $NFR_SPEC_STAGED | tr '\n' ' ')"
            echo ""
            echo "   To skip (feature branches only): SKIP_STALENESS=1 git commit ..."
            echo ""
            FAILURES=$((FAILURES + 1))
          else
            echo "✓ NFR.md updated since last commit"
          fi
        fi
      fi
    fi
  fi
fi

# Check 4: STACK.md version sanity (where detectable)
if [[ $_FAST_MODE -eq 1 ]]; then
  : # skip in fast mode
elif [[ -f "STACK.md" ]]; then
  echo ""
  echo "[4/13] Checking STACK.md version consistency..."
  
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
  echo "[4/13] Skipping STACK.md check (file not found)"
fi

# Check 5: Batch size warning (small batches = quality)
if [[ $_FAST_MODE -eq 1 ]]; then
  : # skip in fast mode
elif command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
  echo ""
  echo "[5/13] Checking batch size (small batches = quality)..."

  # Count staged files
  CHANGED_FILES=$(git diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')

  # Derive warning thresholds from max_files_per_commit setting
  MAX_FILES_SETTING=$(get_setting "max_files_per_commit" "10")
  WARN_THRESHOLD=$(( MAX_FILES_SETTING * 7 / 10 ))  # floor(max * 0.7)
  STRONG_WARN_THRESHOLD=$MAX_FILES_SETTING

  if [[ $CHANGED_FILES -gt $STRONG_WARN_THRESHOLD ]]; then
    echo "⚠️  WARNING: ${CHANGED_FILES} files changed (max: ${MAX_FILES_SETTING})"
    echo ""
    echo "   This is a LARGE commit. Consider:"
    echo "   - Is this really ONE feature? Should it be split?"
    echo "   - Can you extract some changes into a separate commit?"
    echo "   - Small batches = easier review, safer rollback"
    echo ""
    echo "   (This is a warning, not blocking commit — Check 7 enforces the limit)"
    echo ""
  elif [[ $CHANGED_FILES -gt $WARN_THRESHOLD ]]; then
    echo "⚠️  Note: ${CHANGED_FILES} files changed (approaching limit of ${MAX_FILES_SETTING})"
    echo "   Consider if this could be smaller"
  elif [[ $CHANGED_FILES -gt 0 ]]; then
    echo "✓ ${CHANGED_FILES} files changed (good batch size)"
  else
    echo "✓ No staged files (nothing to commit)"
  fi
else
  echo "✓ Git not available (skipping batch size check)"
fi

# Check 6: Test execution (BLOCKING)
if [[ $_FAST_MODE -eq 1 ]]; then
  : # skip tests in fast mode (too slow for pre-commit)
elif [[ -n "${SKIP_TESTS:-}" ]]; then
  echo ""
  echo "═══════════════════════════════════════════════════════════════════════"
  echo "[6/13] Running tests..."
  echo "  ⚠ Skipped (SKIP_TESTS set)"
else
  echo ""
  echo "═══════════════════════════════════════════════════════════════════════"
  echo "[6/13] Running tests..."
  # Prefer fast tests for pre-commit, fall back to full test command
  TEST_CMD=""
  if [[ -f "STACK.md" ]]; then
    TEST_CMD=$(grep -iE "^[- ]*test_fast:" "STACK.md" 2>/dev/null | head -1 | sed 's/.*: *//' || true)
    if [[ -z "$TEST_CMD" ]]; then
      TEST_CMD=$(grep -iE "^[- ]*test:" "STACK.md" 2>/dev/null | head -1 | sed 's/.*: *//' || true)
    fi
  fi

  if [[ -n "$TEST_CMD" ]]; then
    # Security: Only allow known test runners (whitelist)
    case "$TEST_CMD" in
      pytest*|python\ -m\ pytest*|python3\ -m\ pytest*|\
      npm\ test*|npm\ run\ test*|yarn\ test*|pnpm\ test*|\
      cargo\ test*|go\ test*|\
      bash\ tests/*|bash\ validate*|./tests/*|\
      ruby\ -r*|rspec*|bundle\ exec\ rspec*|\
      jest*|npx\ jest*|\
      make\ test*|\
      swift\ test*|dotnet\ test*|\
      gradle\ test*|./gradlew\ test*|\
      mvn\ test*|./mvnw\ test*)
        # Portable timeout (macOS uses gtimeout from coreutils)
        TEST_TIMEOUT=${TEST_TIMEOUT:-300}
        run_with_timeout() {
          local timeout_val="$1"
          local cmd="$2"
          if command -v timeout &>/dev/null; then
            timeout "$timeout_val" bash -c "$cmd"
          elif command -v gtimeout &>/dev/null; then
            gtimeout "$timeout_val" bash -c "$cmd"
          else
            # No timeout available, run without
            bash -c "$cmd"
          fi
        }

        echo "  Running: $TEST_CMD"
        if TEST_OUTPUT=$(run_with_timeout "$TEST_TIMEOUT" "$TEST_CMD" 2>&1); then
          echo "  ✓ Tests passed"
        else
          TEST_EXIT_CODE=$?
          echo "  ❌ BLOCKED: Tests failed"
          if [[ $TEST_EXIT_CODE -eq 124 ]]; then
            echo "     (Timed out after ${TEST_TIMEOUT}s)"
          fi
          echo "  Last 15 lines of output:"
          echo "$TEST_OUTPUT" | tail -15 | sed 's/^/    /'
          FAILURES=$((FAILURES + 1))
        fi
        ;;
      *)
        echo "  ⚠ Unknown test command format: $TEST_CMD"
        echo "    Allowed: pytest, npm test, cargo test, go test, bash tests/*, jest, etc."
        echo "    Add to whitelist in pre-commit-check.sh if this is a legitimate test runner"
        ;;
    esac
  else
    echo "  ⚠ No test command found in STACK.md"
    echo "    Add 'test_fast: <quick tests>' for pre-commit checks"
    echo "    Add 'test: <full suite>' for CI"
  fi
fi

# Check 7: Complexity limits (BLOCKING)
echo ""
echo "═══════════════════════════════════════════════════════════════════════"
echo "[7/13] Checking complexity limits..."

if [[ -n "${SKIP_COMPLEXITY:-}" ]]; then
  echo "  ⚠ Skipped (SKIP_COMPLEXITY set)"
else
  COMPLEXITY_FAILURES=0

  # Read limits via settings resolution (explicit > preset > default)
  MAX_FILES=$(get_setting "max_files_per_commit" "10")
  MAX_ADDED_LINES=$(get_setting "max_added_lines" "500")
  MAX_CODE_FILE_LEN=$(get_setting "max_code_file_length" "500")

  if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
    # Count staged files (excluding deletions)
    STAGED_COUNT=$(git diff --cached --name-only --diff-filter=d 2>/dev/null | wc -l | tr -d ' ')
    if [[ $STAGED_COUNT -gt $MAX_FILES ]]; then
      echo "  ❌ BLOCKED: $STAGED_COUNT files staged (max: $MAX_FILES)"
      echo "     Split into smaller commits for easier review and safer rollback"
      COMPLEXITY_FAILURES=$((COMPLEXITY_FAILURES + 1))
    else
      echo "  ✓ File count: $STAGED_COUNT/$MAX_FILES"
    fi

    # Count ADDED lines only (not total file size, not deletions)
    ADDED_LINES=$(git diff --cached --numstat 2>/dev/null | awk '{sum += $1} END {print sum+0}')
    if [[ $ADDED_LINES -gt $MAX_ADDED_LINES ]]; then
      echo "  ❌ BLOCKED: $ADDED_LINES lines added (max: $MAX_ADDED_LINES)"
      echo "     Split into smaller commits"
      COMPLEXITY_FAILURES=$((COMPLEXITY_FAILURES + 1))
    else
      echo "  ✓ Added lines: $ADDED_LINES/$MAX_ADDED_LINES"
    fi

    # File-type aware length limits (configurable code extensions)
    CODE_EXTENSIONS="py|js|ts|tsx|jsx|go|rs|rb|java|c|cpp|h|sh|swift|kt|scala|cs|php|vue|svelte"
    if [[ -f "STACK.md" ]]; then
      STACK_CODE_EXT=$(grep -iE "code_extensions:" "STACK.md" 2>/dev/null | sed 's/.*: *//' | tr ',' '|' || true)
      [[ -n "$STACK_CODE_EXT" ]] && CODE_EXTENSIONS="$STACK_CODE_EXT"
    fi

    LONG_FILES=0
    while IFS= read -r file; do
      if [[ -f "$file" ]] && [[ "$file" =~ \.($CODE_EXTENSIONS)$ ]]; then
        LINES=$(wc -l < "$file" 2>/dev/null | tr -d ' ')
        if [[ $LINES -gt $MAX_CODE_FILE_LEN ]]; then
          echo "  ❌ BLOCKED: $file has $LINES lines (max for code: $MAX_CODE_FILE_LEN)"
          LONG_FILES=$((LONG_FILES + 1))
        fi
      fi
    done < <(git diff --cached --name-only --diff-filter=d 2>/dev/null)

    if [[ $LONG_FILES -gt 0 ]]; then
      COMPLEXITY_FAILURES=$((COMPLEXITY_FAILURES + 1))
    else
      echo "  ✓ File lengths within limits"
    fi

    # Optional: Run complexity tool if configured (whitelist only)
    if [[ -f "STACK.md" ]]; then
      COMPLEXITY_CMD=$(grep -iE "complexity_check:" "STACK.md" 2>/dev/null | sed 's/.*: *//' || true)
      if [[ -n "$COMPLEXITY_CMD" ]]; then
        case "$COMPLEXITY_CMD" in
          radon*|complexity-report*|gocyclo*|eslint*|lizard*|sonar*)
            echo "  Running complexity analysis: $COMPLEXITY_CMD"
            if ! bash -c "$COMPLEXITY_CMD" 2>/dev/null; then
              echo "  ⚠ Complexity warning (non-blocking)"
            fi
            ;;
          *)
            echo "  ⚠ Unknown complexity tool: $COMPLEXITY_CMD (skipped)"
            ;;
        esac
      fi
    fi
  else
    echo "  ✓ Git not available (skipping complexity check)"
  fi

  if [[ $COMPLEXITY_FAILURES -gt 0 ]]; then
    FAILURES=$((FAILURES + COMPLEXITY_FAILURES))
  fi
fi

# Check 8: Untracked files in project directories
if [[ $_FAST_MODE -eq 1 ]]; then
  : # skip in fast mode
elif command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
  echo ""
  echo "[8/13] Checking for untracked files in project directories..."
  # Directories that should typically have files tracked
  CHECK_DIRS=("src" "lib" "app" "assets" "public" "tests" "test" "spec" "docs" "scripts")
  
  UNTRACKED=$(git status --porcelain 2>/dev/null | grep '^??' | cut -c4- || true)
  
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

# Check 9: LLM behavioral test status (advisory, framework development only)
if [[ $_FAST_MODE -eq 1 ]]; then
  : # skip in fast mode
elif [[ -f ".agentic/tools/llm-test-status.sh" ]] && [[ -f "tests/VERIFICATION_REPORT.md" ]]; then
  echo ""
  echo "[9/13] Checking LLM behavioral test status..."
  if bash .agentic/tools/llm-test-status.sh --quiet 2>/dev/null; then
    echo "✓ LLM behavioral tests are current"
  else
    echo "💡 Tip: LLM behavioral tests may need updating"
    echo "   Run: bash .agentic/tools/llm-test-status.sh"
    echo "   (This is advisory, not blocking commit)"
  fi
fi

# Check 10: Agent instruction file size limits (prevents context bloat)
if [[ $_FAST_MODE -eq 1 ]]; then
  : # skip in fast mode
else
echo ""
echo "[10/13] Checking agent instruction file sizes..."

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
fi  # end fast mode skip for check 10

# Check 12: Workflow bypass detection (Formal only)
# Did the agent use ag implement (which creates WIP with a feature ID)?
if [[ $_FAST_MODE -eq 1 ]]; then
  : # skip in fast mode
elif [[ -f "spec/FEATURES.md" ]]; then
  echo ""
  echo "[12/13] Checking workflow compliance (Formal)..."

  # Only check when new files are being added in implementation directories
  NEW_IMPL_FILES=$(git diff --cached --name-only --diff-filter=A 2>/dev/null | grep -E '^(src/|lib/|app/|\.agentic/tools/|\.agentic/hooks/)' || true)

  if [[ -n "$NEW_IMPL_FILES" ]]; then
    # Check if WIP tracking is active with a feature ID
    HAS_FEATURE_WIP=false
    if [[ -f ".agentic-state/WIP.md" ]]; then
      if grep -qE 'F-[0-9]{4}' ".agentic-state/WIP.md" 2>/dev/null; then
        HAS_FEATURE_WIP=true
      fi
    fi

    if [[ "$HAS_FEATURE_WIP" = false ]]; then
      echo "⚠️  WARNING: New implementation files without feature tracking"
      echo "   New files: $(echo "$NEW_IMPL_FILES" | wc -l | tr -d ' ')"
      echo ""
      echo "   Formal requires: ag implement F-XXXX before coding."
      echo "   This creates WIP tracking with a feature ID."
      echo ""
      echo "   If this is intentional (refactor, config), ignore this warning."
      echo ""
      echo "   (This is a warning, not blocking commit)"
    else
      echo "✓ Feature WIP tracking active"
    fi
  else
    echo "✓ No new implementation files (workflow check skipped)"
  fi
fi

# Check 11: Branch policy for PR workflow (BLOCKS commit to main/master)
echo ""
echo "[11/13] Checking branch policy..."

if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
  CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  GIT_WORKFLOW=$(get_setting "git_workflow" "direct")

  if [[ "$GIT_WORKFLOW" == "pull_request" ]] && [[ "$CURRENT_BRANCH" =~ ^(main|master)$ ]]; then
    echo "❌ BLOCKED: Direct commit to $CURRENT_BRANCH with PR workflow"
    echo ""
    echo "   Your STACK.md has git_workflow: pull_request"
    echo "   This means you want changes reviewed before merging to main."
    echo ""
    echo "   Options:"
    echo "   1. Create a feature branch: git checkout -b feature/description"
    echo "   2. Hotfix bypass: git commit --no-verify (use sparingly)"
    echo "   3. Change workflow: Set git_workflow: direct in STACK.md"
    echo ""
    FAILURES=$((FAILURES + 1))
  elif [[ "$GIT_WORKFLOW" == "pull_request" ]]; then
    echo "✓ On branch '$CURRENT_BRANCH' (PR workflow allows feature branches)"
  elif [[ "$GIT_WORKFLOW" == "direct" ]]; then
    echo "✓ Direct workflow - commits to any branch allowed"
  else
    echo "✓ No git_workflow setting found (defaulting to allow)"
  fi
else
  echo "✓ Git not available (skipping branch policy check)"
fi

# Check 13: Test co-presence (advisory, full mode only)
# Warns when staged source files have no corresponding test file
if [[ $_FAST_MODE -eq 1 ]]; then
  : # skip in fast mode
else
  echo ""
  echo "═══════════════════════════════════════════════════════════════════════"
  echo "[13/13] Checking test co-presence (advisory)..."

  STAGED_SOURCE_FILES=$(git diff --cached --name-only 2>/dev/null | grep -E '\.(ts|tsx|js|jsx|py|go|rs|rb|java|swift|kt)$' | grep -vE '(\.test\.|\.spec\.|_test\.|test_|\.d\.ts$|__tests__|\.config\.|\.stories\.)' | grep -vE '^(tests?/|spec/|\.agentic/)' || true)
  UNTESTED_FILES=0
  UNTESTED_LIST=""

  while IFS= read -r src_file; do
    [[ -z "$src_file" ]] && continue
    # Skip non-source files (configs, types, declarations)
    base=$(basename "$src_file")
    case "$base" in
      index.*|types.*|constants.*|config.*|*.config.*|*.d.ts) continue ;;
    esac

    dir=$(dirname "$src_file")
    name="${base%.*}"
    ext="${base##*.}"

    # Build test patterns list — includes cross-extension checks for tsx→ts, jsx→js
    test_patterns=(
      "${dir}/${name}.test.${ext}"
      "${dir}/${name}.spec.${ext}"
      "${dir}/__tests__/${name}.test.${ext}"
      "tests/${dir}/${name}.test.${ext}"
      "test/${dir}/${name}.test.${ext}"
      "${dir}/test_${name}.py"
      "tests/test_${name}.py"
      "${dir}/${name}_test.go"
      "${dir}/${name}_test.rs"
    )
    # tsx/jsx components are often tested with plain ts/js test files
    case "$ext" in
      tsx) test_patterns+=("${dir}/${name}.test.ts" "${dir}/__tests__/${name}.test.ts") ;;
      jsx) test_patterns+=("${dir}/${name}.test.js" "${dir}/__tests__/${name}.test.js") ;;
    esac

    found_test=false
    for test_pattern in "${test_patterns[@]}"; do
      if [ -f "$test_pattern" ]; then
        found_test=true
        break
      fi
    done

    if [ "$found_test" = false ]; then
      UNTESTED_FILES=$((UNTESTED_FILES + 1))
      UNTESTED_LIST="${UNTESTED_LIST}\n   - ${src_file}"
    fi
  done <<< "$STAGED_SOURCE_FILES"

  if [[ $UNTESTED_FILES -gt 0 ]]; then
    echo "⚠️  $UNTESTED_FILES source file(s) with no test file detected:"
    echo -e "$UNTESTED_LIST"
    echo ""
    echo "   (Advisory only — not blocking commit)"
  else
    if [[ -n "$STAGED_SOURCE_FILES" ]]; then
      echo "✓ All staged source files have test files"
    else
      echo "✓ No source files staged (test check skipped)"
    fi
  fi
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

