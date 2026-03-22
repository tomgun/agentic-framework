#!/usr/bin/env bash
# pre-commit-check.sh - Enforce quality gates before commit
#
# This hook validates project state before allowing commits.
# BLOCKS commit if validation fails (exit code 1).
#
# Usage:
#   bash .agentic/lib/hooks/pre-commit-check.sh [--mode fast|full]
#
# Checks:
#   1.  .agentic/session/WIP.md must not exist (work must be complete)
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
#   14. Shipped spec changes require migration (BLOCKING)
#   15. Test file deletion blocked if referenced by shipped feature (BLOCKING)
#   16. Status downgrade protection for shipped features (BLOCKING)
#   19. Doc registry health (advisory, respects docs_gate setting)
#   20. TDD phase ordering (BLOCKING when development_mode: tdd, safety net)
#   21. Approved plan required when plan_review_enabled (BLOCKING)
#   22. Annotation enforcement for newly-shipped features (respects annotation_enforcement setting)
#   23. YAML contract protection — shipped contracts require migration entry (BLOCKING)
#
# Escape hatches (use sparingly, blocked on main/master):
#   SKIP_TESTS=1      Skip test execution
#   SKIP_COMPLEXITY=1  Skip complexity limits
#   SKIP_STALENESS=1   Skip JOURNAL/STATUS/FEATURES staleness checks
#   SKIP_TDD=1         Skip TDD phase ordering check
#
# Exit codes:
#   0 - All checks pass, commit allowed
#   1 - Validation failed, commit blocked
#
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "${PROJECT_ROOT}"

# Source shared settings
source "${PROJECT_ROOT}/.agentic/lib/paths.sh"
source "${PROJECT_ROOT}/.agentic/lib/settings.sh"
source "${PROJECT_ROOT}/.agentic/lib/tools/fwlog.sh" 2>/dev/null || true

# === Mode flag ===
# --mode fast: skip slow/advisory checks (4,5,6,8,9,10,12,13,19,22)
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

_PC_MODE="full"; [[ "$_FAST_MODE" -eq 1 ]] && _PC_MODE="fast"
if type flog &>/dev/null; then
    flog "pre-commit" "run" "$_PC_MODE" "start"
    trap 'flog "pre-commit" "run" "$_PC_MODE" "end:$?"' EXIT
fi

# === Escape Hatches ===
# For legitimate bypasses (WIP branches, urgent hotfixes)
# NEVER use on main/master - blocked below

CURRENT_BRANCH=""
if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
  CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
fi

# Block escape hatches on main/master
if [[ "$CURRENT_BRANCH" == "main" || "$CURRENT_BRANCH" == "master" ]]; then
  if [[ -n "${SKIP_TESTS:-}" || -n "${SKIP_COMPLEXITY:-}" || -n "${SKIP_STALENESS:-}" || -n "${SKIP_TDD:-}" ]]; then
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
if [[ -f ".agentic/lib/tools/scope_check.sh" ]]; then
  SCOPE_OUTPUT=$(bash .agentic/lib/tools/scope_check.sh 2>/dev/null || true)
  if [[ -n "$SCOPE_OUTPUT" ]]; then
    echo "$SCOPE_OUTPUT"
    echo "───────────────────────────────────────────────────────"
    echo ""
  fi
fi

FAILURES=0

# Check 1: .agentic/session/WIP.md must not exist
echo "[1/16] Checking for incomplete work (.agentic/session/WIP.md)..."
if [[ -f ".agentic/session/WIP.md" ]]; then
  echo "❌ BLOCKED: .agentic/session/WIP.md exists - work is incomplete!"
  echo ""
  echo "   Work-in-progress must be completed before committing."
  echo "   Options:"
  echo "   1. Complete work: bash .agentic/lib/tools/wip.sh complete"
  echo "   2. If work IS complete, remove WIP lock:"
  echo "      bash .agentic/lib/tools/wip.sh complete"
  echo "   3. If work is NOT complete, finish it first"
  echo ""
  FAILURES=$((FAILURES + 1))
else
  echo "✓ No .agentic/session/WIP.md found (work complete)"
fi

# Check 2: Shipped features must have acceptance criteria
if [[ -f ".agentic/spec/FEATURES.md" ]]; then
  echo ""
  echo "[2/16] Checking shipped features have acceptance criteria..."
  
  # Extract feature IDs marked as shipped
  # Format: **Status**: shipped (markdown bold wrapping)
  SHIPPED_FEATURES=$(grep -A5 "^## F-" .agentic/spec/FEATURES.md | grep -B5 -i "status.*shipped" | grep "^## F-" | cut -d: -f1 | sed 's/^## //' || echo "")
  
  if [[ -n "$SHIPPED_FEATURES" ]]; then
    MISSING_ACCEPTANCE=""
    while IFS= read -r FEATURE_ID; do
      if [[ ! -f ".agentic/spec/acceptance/${FEATURE_ID}.md" ]]; then
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
      echo "   - Use .agentic/lib/templates/FEATURES.template.md as reference"
      echo "   - Define what 'done' means for each feature"
      echo "   - Or change status to 'implementing' if not truly shipped"
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
  echo "[2/16] Skipping shipped features check (Discovery profile, no .agentic/spec/FEATURES.md)"
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
if [[ -f ".agentic/journal/JOURNAL.md" ]]; then
  JOURNAL_PATH=".agentic/journal/JOURNAL.md"
elif [[ -f "JOURNAL.md" ]]; then
  JOURNAL_PATH="JOURNAL.md"
fi

if [[ -n "$JOURNAL_PATH" ]]; then
  echo ""
  echo "[3/16] Checking JOURNAL.md freshness..."

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
        echo "   bash .agentic/lib/tools/journal.sh \"Topic\" \"Done\" \"Next\" \"Blockers\""
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
  echo "[3/16] Skipping JOURNAL.md check (file not found)"
fi

# Check 3b: STATUS.md updated since last commit (BLOCKING)
if [[ -f "STATUS.md" ]]; then
  echo ""
  echo "[3b/16] Checking STATUS.md freshness..."

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
        echo "   bash .agentic/lib/tools/status.sh focus \"Current task\""
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
FEATURE_SPEC_STAGED=$(git diff --cached --name-only 2>/dev/null | grep "^spec/" | grep -v "^spec/NFR\.md$" | grep -v "^.agentic/spec/acceptance/NFR-" | grep -v "^$" || true)
if [[ -n "$FEATURE_SPEC_STAGED" ]] && [[ -f ".agentic/spec/FEATURES.md" ]]; then
  echo ""
  echo "[3c/16] Checking FEATURES.md freshness (feature spec files staged)..."

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
            FEATURES_MTIME=$(stat -f %m ".agentic/spec/FEATURES.md" 2>/dev/null || echo "0")
          else
            FEATURES_MTIME=$(stat -c %Y ".agentic/spec/FEATURES.md" 2>/dev/null || echo "0")
          fi

          if [[ "$FEATURES_MTIME" -lt "$LAST_COMMIT_TIME" ]]; then
            echo "❌ BLOCKED: FEATURES.md not updated but spec files are staged"
            echo "   Staged spec files: $(echo $FEATURE_SPEC_STAGED | tr '\n' ' ')"
            echo ""
            echo "   Update with: bash .agentic/lib/tools/feature.sh F-#### status <status>"
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
if [[ -n "$NFR_SPEC_STAGED" ]] && [[ -f ".agentic/spec/NFR.md" ]]; then
  echo ""
  echo "[3d/16] Checking NFR.md freshness (NFR spec files staged)..."

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
            NFR_MTIME=$(stat -f %m ".agentic/spec/NFR.md" 2>/dev/null || echo "0")
          else
            NFR_MTIME=$(stat -c %Y ".agentic/spec/NFR.md" 2>/dev/null || echo "0")
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
  echo "[4/16] Checking STACK.md version consistency..."
  
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
  echo "[4/16] Skipping STACK.md check (file not found)"
fi

# Check 5: Batch size warning (small batches = quality)
if [[ $_FAST_MODE -eq 1 ]]; then
  : # skip in fast mode
elif command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
  echo ""
  echo "[5/16] Checking batch size (small batches = quality)..."

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
  echo "[6/16] Running tests..."
  echo "  ⚠ Skipped (SKIP_TESTS set)"
else
  echo ""
  echo "═══════════════════════════════════════════════════════════════════════"
  echo "[6/16] Running tests..."
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
echo "[7/16] Checking complexity limits..."

if [[ -n "${SKIP_COMPLEXITY:-}" ]]; then
  echo "  ⚠ SKIP_COMPLEXITY set — showing bypassed files:"

  # Show which files are actually over-limit (so agent can make informed decision)
  MAX_CODE_FILE_LEN_BT=$(get_setting "max_code_file_length" "500")
  CODE_EXTENSIONS_BT="py|js|ts|tsx|jsx|go|rs|rb|java|c|cpp|h|sh|swift|kt|scala|cs|php|vue|svelte"
  if [[ -f "STACK.md" ]]; then
    STACK_CODE_EXT_BT=$(grep -iE "code_extensions:" "STACK.md" 2>/dev/null | sed 's/.*: *//' | tr ',' '|' || true)
    [[ -n "$STACK_CODE_EXT_BT" ]] && CODE_EXTENSIONS_BT="$STACK_CODE_EXT_BT"
  fi

  OVERLIMIT_COUNT=0
  while IFS= read -r file; do
    [[ "$file" == .agentic/* ]] && continue
    if [[ -f "$file" ]] && [[ "$file" =~ \.($CODE_EXTENSIONS_BT)$ ]]; then
      LINES=$(wc -l < "$file" 2>/dev/null | tr -d ' ')
      if [[ $LINES -gt $MAX_CODE_FILE_LEN_BT ]]; then
        OVERLIMIT_COUNT=$((OVERLIMIT_COUNT + 1))
        echo "  ⚠️  $file: $LINES lines (limit: $MAX_CODE_FILE_LEN_BT)"
      fi
    fi
  done < <(git diff --cached --name-only --diff-filter=d 2>/dev/null)

  if [[ $OVERLIMIT_COUNT -gt 0 ]]; then
    echo ""
    echo "  Consider: ag todo \"Refactor over-limit files\" or split before next commit"
    echo "  SKIP_COMPLEXITY should be temporary, not permanent."
  else
    echo "  (No staged files currently over the limit)"
  fi
else
  COMPLEXITY_FAILURES=0

  # Read limits via settings resolution (explicit > preset > default)
  MAX_FILES=$(get_setting "max_files_per_commit" "10")
  MAX_ADDED_LINES=$(get_setting "max_added_lines" "500")
  MAX_CODE_FILE_LEN=$(get_setting "max_code_file_length" "500")

  # Downgrade batch-size limits to warnings on feature branches in PR workflow
  BATCH_ADVISORY=0
  GIT_WORKFLOW=$(get_setting "git_workflow" "direct")
  if [[ "$GIT_WORKFLOW" == "pull_request" && "$CURRENT_BRANCH" != "main" && "$CURRENT_BRANCH" != "master" ]]; then
    BATCH_ADVISORY=1
  fi

  if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
    # Count staged files (excluding deletions)
    STAGED_COUNT=$(git diff --cached --name-only --diff-filter=d 2>/dev/null | wc -l | tr -d ' ')
    if [[ $STAGED_COUNT -gt $MAX_FILES ]]; then
      if [[ $BATCH_ADVISORY -eq 1 ]]; then
        echo "  ⚠ Advisory: $STAGED_COUNT files staged (guideline: $MAX_FILES) — OK on feature branch, PR is the review unit"
      else
        echo "  ❌ BLOCKED: $STAGED_COUNT files staged (max: $MAX_FILES)"
        echo "     Split into smaller commits for easier review and safer rollback"
        COMPLEXITY_FAILURES=$((COMPLEXITY_FAILURES + 1))
      fi
    else
      echo "  ✓ File count: $STAGED_COUNT/$MAX_FILES"
    fi

    # Count ADDED lines only (not total file size, not deletions)
    ADDED_LINES=$(git diff --cached --numstat 2>/dev/null | awk '{sum += $1} END {print sum+0}')
    if [[ $ADDED_LINES -gt $MAX_ADDED_LINES ]]; then
      if [[ $BATCH_ADVISORY -eq 1 ]]; then
        echo "  ⚠ Advisory: $ADDED_LINES lines added (guideline: $MAX_ADDED_LINES) — OK on feature branch, PR is the review unit"
      else
        echo "  ❌ BLOCKED: $ADDED_LINES lines added (max: $MAX_ADDED_LINES)"
        echo "     Split into smaller commits"
        COMPLEXITY_FAILURES=$((COMPLEXITY_FAILURES + 1))
      fi
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
      # Skip framework-owned and test infrastructure files
      [[ "$file" == .agentic/* ]] && continue
      [[ "$file" == tests/* ]] && continue
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
  echo "[8/16] Checking for untracked files in project directories..."
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
elif [[ -f ".agentic/lib/tools/llm-test-status.sh" ]] && [[ -f "tests/VERIFICATION_REPORT.md" ]]; then
  echo ""
  echo "[9/16] Checking LLM behavioral test status..."
  if bash .agentic/lib/tools/llm-test-status.sh --quiet 2>/dev/null; then
    echo "✓ LLM behavioral tests are current"
  else
    echo "💡 Tip: LLM behavioral tests may need updating"
    echo "   Run: bash .agentic/lib/tools/llm-test-status.sh"
    echo "   (This is advisory, not blocking commit)"
  fi
fi

# Check 10: Agent instruction file size limits (prevents context bloat)
if [[ $_FAST_MODE -eq 1 ]]; then
  : # skip in fast mode
else
echo ""
echo "[10/16] Checking agent instruction file sizes..."

SIZE_WARNINGS=0

# CLAUDE.md limit: 500 lines
if [[ -f ".agentic/lib/agents/claude/CLAUDE.md" ]]; then
  CLAUDE_LINES=$(wc -l < ".agentic/lib/agents/claude/CLAUDE.md" | tr -d ' ')
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
if [[ -f ".agentic/lib/agents/shared/agent_operating_guidelines.md" ]]; then
  GUIDELINES_LINES=$(wc -l < ".agentic/lib/agents/shared/agent_operating_guidelines.md" | tr -d ' ')
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
elif [[ -f ".agentic/spec/FEATURES.md" ]]; then
  echo ""
  echo "[12/16] Checking workflow compliance (Formal)..."

  # Only check when new files are being added in implementation directories
  NEW_IMPL_FILES=$(git diff --cached --name-only --diff-filter=A 2>/dev/null | grep -E '^(src/|lib/|app/|\.agentic/lib/tools/|\.agentic/hooks/)' || true)

  if [[ -n "$NEW_IMPL_FILES" ]]; then
    # Check if WIP tracking is active with a feature ID
    HAS_FEATURE_WIP=false
    if [[ -f ".agentic/session/WIP.md" ]]; then
      if grep -qE "$FEATURE_ID_ERE" ".agentic/session/WIP.md" 2>/dev/null; then
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
echo "[11/16] Checking branch policy..."

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
  echo "[13/16] Checking test co-presence (advisory)..."

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

# Check 14: Shipped spec changes require migration (BLOCKING)
if [[ -f ".agentic/spec/FEATURES.md" ]]; then
  echo ""
  echo "[14/16] Checking shipped spec protection..."

  SHIPPED_SPEC_STAGED=$(git diff --cached --name-only 2>/dev/null | grep -E "^.agentic/spec/acceptance/(F|NFR)-[0-9]+\.md$" || true)
  CHECK14_FAIL=0
  if [[ -n "$SHIPPED_SPEC_STAGED" ]]; then
    # Pre-fetch migration diff once (avoids pipefail+SIGPIPE bug with grep -q)
    MIGRATION_STAGED=$(git diff --cached --name-only 2>/dev/null | grep -E "^.agentic/spec/migrations/[0-9]+.*\.md$" || true)
    MIGRATION_DIFF=""
    if [[ -n "$MIGRATION_STAGED" ]]; then
      MIGRATION_DIFF=$(git diff --cached -- .agentic/spec/migrations/ 2>/dev/null || true)
    fi
    for spec_file in $SHIPPED_SPEC_STAGED; do
      FID=$(basename "$spec_file" .md)
      # Match **Status**: shipped format in FEATURES.md
      IS_SHIPPED=$(grep -A5 "^## ${FID}:" .agentic/spec/FEATURES.md 2>/dev/null | grep -i "status.*shipped" || true)
      if [[ -n "$IS_SHIPPED" ]]; then
        if [[ -z "$MIGRATION_STAGED" ]] || ! echo "$MIGRATION_DIFF" | grep -q "$FID"; then
          echo "❌ BLOCKED: Shipped feature $FID acceptance criteria modified without migration"
          echo "  Create: bash .agentic/lib/tools/migration.sh create 'Update $FID ...'"
          FAILURES=$((FAILURES + 1))
          CHECK14_FAIL=1
        fi
      fi
    done
    if [[ $CHECK14_FAIL -eq 0 ]]; then
      echo "✓ Shipped spec changes have migration coverage"
    fi
  else
    echo "✓ No shipped spec acceptance files modified"
  fi
fi

# Check 15: Deleting test files referenced by shipped features (BLOCKING)
if [[ -f ".agentic/spec/FEATURES.md" ]]; then
  echo ""
  echo "[15/16] Checking shipped feature test protection..."

  DELETED_TEST_FILES=$(git diff --cached --diff-filter=D --name-only 2>/dev/null | grep -E "^tests/" || true)
  CHECK15_FAIL=0
  if [[ -n "$DELETED_TEST_FILES" ]]; then
    for test_file in $DELETED_TEST_FILES; do
      REFERENCING_SPECS=$(grep -rl "$test_file" .agentic/spec/acceptance/ 2>/dev/null || true)
      for spec in $REFERENCING_SPECS; do
        FID=$(basename "$spec" .md)
        IS_SHIPPED=$(grep -A5 "^## ${FID}:" .agentic/spec/FEATURES.md 2>/dev/null | grep -i "status.*shipped" || true)
        if [[ -n "$IS_SHIPPED" ]]; then
          echo "❌ BLOCKED: Cannot delete $test_file — referenced by shipped feature $FID"
          FAILURES=$((FAILURES + 1))
          CHECK15_FAIL=1
        fi
      done
    done
  fi
  if [[ $CHECK15_FAIL -eq 0 ]]; then
    echo "✓ No shipped feature test files being deleted"
  fi
fi

# Check 16: Status downgrade protection for shipped features (BLOCKING)
if [[ -f ".agentic/spec/FEATURES.md" ]]; then
  echo ""
  echo "[16/16] Checking shipped feature status protection..."

  if git diff --cached --name-only 2>/dev/null | grep -q "^.agentic/spec/FEATURES.md$"; then
    # Look for lines where "shipped" was removed (- line)
    # Parse each diff hunk to find the feature ID from the nearest ## F-XXXX heading
    HAS_DOWNGRADE=0
    DOWNGRADED_IDS=""
    DIFF_OUTPUT=$(git diff --cached -U20 .agentic/spec/FEATURES.md 2>/dev/null || true)
    LAST_FID=""
    while IFS= read -r line; do
      # Reset context at hunk boundaries
      if echo "$line" | grep -qE "^@@"; then
        LAST_FID=""
      fi
      # Track current feature context from context/added/removed lines
      if echo "$line" | grep -qE "^[ +@-].*## F-[0-9]+:"; then
        LAST_FID=$(echo "$line" | grep -oE "F-[0-9]+" | head -1)
      fi
      # Detect removed shipped status — must be on a deletion line (starts with -)
      if echo "$line" | grep -qE "^-.*[Ss]tatus.*shipped"; then
        if [[ -n "$LAST_FID" ]]; then
          DOWNGRADED_IDS="$DOWNGRADED_IDS $LAST_FID"
          HAS_DOWNGRADE=1
        fi
      fi
    done <<< "$DIFF_OUTPUT"
    if [[ $HAS_DOWNGRADE -eq 1 ]]; then
      # Check if migration covers the downgraded features
      # Pre-fetch diff to avoid pipefail+SIGPIPE bug with grep -q
      MIGRATION_STAGED_16=$(git diff --cached --name-only 2>/dev/null | grep -E "^.agentic/spec/migrations/[0-9]+.*\.md$" || true)
      MIGRATION_DIFF_16=""
      if [[ -n "$MIGRATION_STAGED_16" ]]; then
        MIGRATION_DIFF_16=$(git diff --cached -- .agentic/spec/migrations/ 2>/dev/null || true)
      fi
      UNCOVERED_IDS=""
      for DID in $DOWNGRADED_IDS; do
        if [[ -z "$MIGRATION_STAGED_16" ]] || ! echo "$MIGRATION_DIFF_16" | grep -q "$DID"; then
          UNCOVERED_IDS="$UNCOVERED_IDS $DID"
        fi
      done
      if [[ -n "$UNCOVERED_IDS" ]]; then
        echo "❌ BLOCKED: Shipped feature status downgraded without migration:$UNCOVERED_IDS"
        echo "  Create: bash .agentic/lib/tools/migration.sh create 'Deprecate ...'"
        FAILURES=$((FAILURES + 1))
      else
        echo "✓ Shipped feature status changes covered by migration"
      fi
    else
      echo "✓ No shipped feature status downgrades"
    fi
  else
    echo "✓ FEATURES.md not modified"
  fi
fi

# Check 18: Instruction sync advisory (framework-dev only)
# Warns if ag.sh changed but instruction files weren't modified in the same commit
if [[ $_FAST_MODE -eq 0 ]] && [[ -f ".agentic/lib/tools/instruction-sync.sh" ]]; then
  AG_SH_STAGED=$(git diff --cached --name-only 2>/dev/null | grep -c "ag\.sh" || true)
  if [[ "$AG_SH_STAGED" -gt 0 ]]; then
    echo ""
    echo "[18/18] Checking instruction file sync (ag.sh staged)..."
    INSTR_FILES_STAGED=$(git diff --cached --name-only 2>/dev/null | grep -cE "(CLAUDE\.md|cursorrules|copilot-instructions|codex-instructions|auto_orchestration|memory-seed)" || true)
    if [[ "$INSTR_FILES_STAGED" -eq 0 ]]; then
      echo "⚠️  WARNING: ag.sh modified but no instruction files updated"
      echo "   If you added/changed ag commands, update instruction files too."
      echo "   Run: bash .agentic/lib/tools/instruction-sync.sh"
      echo ""
      echo "   (This is advisory, not blocking commit)"
    else
      echo "✓ ag.sh and instruction files both staged"
    fi
  fi
fi

# Check 17: Run custom gates from .agentic/local/extensions/gates/
EXT_GATES_DIR="${PROJECT_ROOT}/.agentic/local/extensions/gates"
if [[ -d "$EXT_GATES_DIR" ]]; then
  GATE_FILES=$(find "$EXT_GATES_DIR" -name '*.sh' -type f 2>/dev/null | sort)
  if [[ -n "$GATE_FILES" ]]; then
    echo ""
    echo "[17/17] Running custom quality gates..."
    while IFS= read -r gate; do
      [[ -f "$gate" ]] || continue
      gate_name=$(basename "$gate")
      gate_output=$(bash "$gate" 2>&1)
      gate_exit=$?
      if [[ $gate_exit -eq 0 ]]; then
        echo "  ✓ $gate_name passed"
      else
        echo "  ❌ BLOCKED: Custom gate failed: $gate_name"
        echo "$gate_output" | sed 's/^/    /'
        FAILURES=$((FAILURES + 1))
      fi
    done <<< "$GATE_FILES"
  fi
fi

# Check 19: Doc registry health (respects docs_gate: off/warning/blocking)
if [[ $_FAST_MODE -eq 0 ]]; then
  DOCS_GATE=$(get_setting "docs_gate" "off" 2>/dev/null || echo "off")
  if [[ "$DOCS_GATE" != "off" ]]; then
    DOCS_SH="${PROJECT_ROOT}/.agentic/lib/tools/docs.sh"
    if [[ -f "$DOCS_SH" ]]; then
      echo ""
      echo "[19] Doc registry health..."
      VALIDATE_OUTPUT=$(bash "$DOCS_SH" --validate 2>/dev/null) || true
      MISSING_COUNT=$(echo "$VALIDATE_OUTPUT" | grep -c "registered-but-missing" || true)
      UNREG_COUNT=$(echo "$VALIDATE_OUTPUT" | grep -c "unregistered:" || true)
      if [[ "$MISSING_COUNT" -gt 0 ]] || [[ "$UNREG_COUNT" -gt 0 ]]; then
        [[ "$UNREG_COUNT" -gt 0 ]] && echo "  ⚠ ${UNREG_COUNT} unregistered doc(s) found"
        if [[ "$MISSING_COUNT" -gt 0 ]]; then
          if [[ "$DOCS_GATE" == "blocking" ]]; then
            echo "  ❌ ${MISSING_COUNT} registered doc(s) missing from disk"
            echo "  Run: bash .agentic/lib/tools/docs.sh --validate"
            FAILURES=$((FAILURES + 1))
          else
            echo "  ⚠ ${MISSING_COUNT} registered doc(s) missing from disk"
            echo "  Run: bash .agentic/lib/tools/docs.sh --validate"
          fi
        fi
      else
        echo "  ✓ Doc registry healthy"
      fi
    fi
  fi
fi

# --- Advisory: QA propagation items ---
QA_TRACKER="$ROOT_DIR/.agentic/session/.qa-tracker.json"
if [[ -f "$QA_TRACKER" ]] && command -v python3 &>/dev/null; then
  PENDING_COUNT=$(python3 -c "
import json
try:
    with open('$QA_TRACKER') as f:
        data = json.load(f)
    pending = data.get('propagation', {}).get('pending', [])
    total = sum(sum(1 for i in p.get('items', []) if i.get('status') == 'open') for p in pending)
    print(total)
except: print(0)
" 2>/dev/null || echo "0")
  if [[ "$PENDING_COUNT" -gt 0 ]]; then
    echo ""
    echo "⚠️  Advisory: $PENDING_COUNT open QA propagation item(s)"
    echo "   Run: ag audit --status  or  bash .agentic/lib/tools/qa-tracker.sh pending"
  fi
fi

# --- Advisory: Unchecked acceptance criteria for in_progress features (T-0051) ---
if [[ -f ".agentic/spec/FEATURES.md" ]]; then
  # Heading-only extraction avoids spurious matches from body text
  IN_PROGRESS_FEATURES=$(grep -B 3 -i "status.*in_progress" .agentic/spec/FEATURES.md | grep -oP '^## \KF-[0-9]+' || echo "")

  if [[ -n "$IN_PROGRESS_FEATURES" ]]; then
    AC_WARNINGS=""
    while IFS= read -r fid; do
      AC_FILE=".agentic/spec/acceptance/${fid}.md"
      if [[ -f "$AC_FILE" ]]; then
        TOTAL=$(grep -cE '^\s*- \[ \]' "$AC_FILE") || TOTAL=0
        if [[ "$TOTAL" -gt 0 ]]; then
          AC_WARNINGS="${AC_WARNINGS}\n   ${fid}: ${TOTAL} unchecked AC(s) in ${AC_FILE}"
        fi
      fi
    done <<< "$IN_PROGRESS_FEATURES"

    if [[ -n "$AC_WARNINGS" ]]; then
      echo ""
      echo "⚠️  Advisory: In-progress features with unchecked acceptance criteria"
      echo -e "$AC_WARNINGS"
      echo "   Consider checking off completed ACs before committing."
    fi
  fi
fi

# Check 20: TDD phase ordering (BLOCKING when development_mode: tdd)
# Safety net — primary enforcement is at `wip.sh complete`
if [[ $_FAST_MODE -eq 0 ]]; then
  DEV_MODE=$(get_setting "development_mode" "standard" 2>/dev/null || echo "standard")
  if [[ "$DEV_MODE" == "tdd" ]]; then
    if [[ -n "${SKIP_TDD:-}" ]]; then
      echo ""
      echo "[20] TDD phase ordering (SKIPPED via SKIP_TDD)"
    elif command -v python3 >/dev/null 2>&1; then
      echo ""
      echo "[20] Checking TDD phase ordering (safety net)..."
      TDD_EXIT=0
      TDD_OUTPUT=$(python3 .agentic/lib/tools/agents_helpers.py --project-root "$PROJECT_ROOT" check-tdd-phases 2>&1) || TDD_EXIT=$?
      if [[ $TDD_EXIT -eq 0 ]]; then
        echo "  ✓ TDD phase ordering OK"
      elif [[ $TDD_EXIT -eq 2 ]]; then
        echo "  ❌ BLOCKED: TDD phase ordering violated: GREEN before RED"
        echo "     $TDD_OUTPUT"
        echo "     Use: wip.sh checkpoint --phase RED|GREEN|REFACTOR"
        FAILURES=$((FAILURES + 1))
      elif [[ $TDD_EXIT -eq 3 ]]; then
        echo "  ❌ BLOCKED: TDD mode active but no phase checkpoints recorded"
        echo "     Use: wip.sh checkpoint --phase RED \"test for [behavior] fails\""
        FAILURES=$((FAILURES + 1))
      else
        # Exit 1 = no active entries (already completed) — pass silently
        echo "  ✓ TDD check passed (no active WIP entries)"
      fi
    fi
  fi
fi

# Check 21: Approved plan required when plan_review_enabled (BLOCKING)
# Only gates feature implementation work — requires WIP entry in AGENTS.json
if [[ $_FAST_MODE -eq 0 ]]; then
  PLAN_REVIEW_ENABLED=$(get_setting "plan_review_enabled" "no" 2>/dev/null || echo "no")
  if [[ "$PLAN_REVIEW_ENABLED" == "yes" ]] && command -v python3 >/dev/null 2>&1; then
    WIP_FEATURE=""
    WIP_FEATURE=$(python3 .agentic/lib/tools/agents_helpers.py --project-root "$PROJECT_ROOT" get-current-feature "$PROJECT_ROOT" 2>/dev/null || true)

    if [[ -n "$WIP_FEATURE" ]] && is_feature_id "$WIP_FEATURE"; then
      echo ""
      echo "[21] Checking for APPROVED plan ($WIP_FEATURE)..."

      # Look for an APPROVED plan in the durable plans directory
      HAS_APPROVED_PLAN=false
      for plan_file in "$PROJECT_ROOT/.agentic/journal/plans/"*"${WIP_FEATURE}"*plan*; do
        if [[ -f "$plan_file" ]]; then
          if grep -qi '^\*\*Status\*\*.*APPROVED' "$plan_file" 2>/dev/null; then
            HAS_APPROVED_PLAN=true
            break
          fi
        fi
      done

      if [[ "$HAS_APPROVED_PLAN" == true ]]; then
        echo "  ✓ APPROVED plan found for $WIP_FEATURE"
      else
        echo "  ❌ BLOCKED: plan_review_enabled is yes but no APPROVED plan for $WIP_FEATURE."
        echo "     Run \`ag implement $WIP_FEATURE\` to trigger dialectical review first."
        FAILURES=$((FAILURES + 1))
      fi
    fi
  fi
fi

# Check 22: Annotation enforcement for newly-shipped features
# @feature F-0229
# Only checks features transitioning to shipped in this commit (grandfathering).
# Skipped in fast mode and when annotation_enforcement=off.
if [[ $_FAST_MODE -eq 0 ]]; then
  ANNOTATION_ENFORCEMENT=$(get_setting "annotation_enforcement" "off" 2>/dev/null || echo "off")
  if [[ "$ANNOTATION_ENFORCEMENT" != "off" ]] && command -v python3 >/dev/null 2>&1; then
    echo ""
    echo "[22] Checking annotation coverage for newly-shipped features..."

    # Parse staged diff to find features transitioning to shipped
    NEWLY_SHIPPED=()
    STAGED_DIFF=$(git diff --cached --unified=10 -- ".agentic/spec/FEATURES.md" 2>/dev/null || true)
    if [[ -n "$STAGED_DIFF" ]]; then
      # Find added lines with "**Status**: shipped" and look for feature headers above them
      CURRENT_FEATURE=""
      while IFS= read -r line; do
        # Track feature headers (both added and context lines)
        if [[ "$line" =~ ^[\ +]##\ (F-[0-9]{4,}): ]]; then
          CURRENT_FEATURE="${BASH_REMATCH[1]}"
        fi
        # Detect newly-added shipped status (lines starting with +)
        if [[ "$line" =~ ^\+\*\*Status\*\*:\ *shipped ]] && [[ -n "$CURRENT_FEATURE" ]]; then
          NEWLY_SHIPPED+=("$CURRENT_FEATURE")
        fi
      done <<< "$STAGED_DIFF"
    fi

    if [[ ${#NEWLY_SHIPPED[@]} -eq 0 ]]; then
      echo "  ✓ No features transitioning to shipped — skipped"
    else
      # Get missing annotations from coverage.py
      # NOTE: coverage.py exits 1 when issues found — || true inside subshell
      # preserves stdout while suppressing the exit code under set -e
      COVERAGE_JSON=$(python3 .agentic/lib/tools/coverage.py --json 2>/dev/null || true)
      if [[ -z "$COVERAGE_JSON" ]]; then
        COVERAGE_JSON='{"issues":[]}'
      fi
      MISSING_FEATURES=$(echo "$COVERAGE_JSON" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for issue in data.get('issues', []):
    if issue['type'] == 'missing_annotation':
        print(issue['feature'])
" 2>/dev/null || true)

      ANNOTATION_VIOLATIONS=0
      for fid in "${NEWLY_SHIPPED[@]}"; do
        if echo "$MISSING_FEATURES" | grep -q "^${fid}$"; then
          ANNOTATION_VIOLATIONS=$((ANNOTATION_VIOLATIONS + 1))
          if [[ "$ANNOTATION_ENFORCEMENT" == "blocking" ]]; then
            echo "  ❌ $fid: no @feature annotations found in codebase"
            FAILURES=$((FAILURES + 1))
          else
            echo "  ⚠ $fid: no @feature annotations found in codebase (advisory)"
          fi
        else
          echo "  ✓ $fid: has @feature annotations"
        fi
      done

      if [[ $ANNOTATION_VIOLATIONS -eq 0 ]]; then
        echo "  ✓ All newly-shipped features have annotations"
      elif [[ "$ANNOTATION_ENFORCEMENT" == "advisory" ]]; then
        echo "  ℹ Add @feature annotations to key implementation files"
        echo "    See: .agentic/lib/workflows/code_annotations.md"
      elif [[ "$ANNOTATION_ENFORCEMENT" == "blocking" ]]; then
        echo "  ℹ Add @feature annotations before committing"
        echo "    See: .agentic/lib/workflows/code_annotations.md"
      fi
    fi
  fi
fi

# Check 23: YAML contract protection for shipped contracts (BLOCKING)
# @feature F-0302
# When a shipped contract (protection: contract) is modified, require a migration entry.
CONTRACTS_DIR_CHECK="${CONTRACTS_DIR:-${AGENTIC_ROOT}/spec/contracts}"
if [[ -d "$CONTRACTS_DIR_CHECK" ]] && command -v python3 >/dev/null 2>&1; then
  # Only check MODIFIED contracts (not newly added ones) — new files don't need migration
  CONTRACT_STAGED=$(git diff --cached --diff-filter=M --name-only 2>/dev/null | grep -E "^\.agentic/spec/contracts/.*\.yaml$" || true)
  if [[ -n "$CONTRACT_STAGED" ]]; then
    echo ""
    echo "[23] Checking YAML contract protection..."
    CHECK23_FAIL=0
    for contract_file in $CONTRACT_STAGED; do
      [[ -f "$contract_file" ]] || continue
      # Check if contract is shipped + protected
      IS_PROTECTED=$(PYTHONPATH="$ROOT_DIR/.agentic/lib" python3 -c "
import sys
from pathlib import Path
from contracts import load_contract
try:
    c = load_contract(Path('$contract_file'))
    print('yes' if c.is_protected else 'no')
except Exception:
    print('no')
" 2>/dev/null || echo "no")
      if [[ "$IS_PROTECTED" == "yes" ]]; then
        CID=$(basename "$contract_file" .yaml)
        # Check for staged migration entry in the contract itself
        HAS_MIGRATION=$(git diff --cached -- "$contract_file" 2>/dev/null | grep -c "^+.*id: M-" || true)
        if [[ "$HAS_MIGRATION" -eq 0 ]]; then
          echo "❌ BLOCKED: Shipped contract $CID modified without migration entry"
          echo "  Add migration: ag contract add-migration $CID --trigger <type> --reason \"reason\""
          FAILURES=$((FAILURES + 1))
          CHECK23_FAIL=1
        fi
      fi
    done
    if [[ $CHECK23_FAIL -eq 0 ]]; then
      echo "✓ Contract changes have migration coverage (or are unprotected)"
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

