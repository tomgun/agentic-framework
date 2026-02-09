#!/usr/bin/env bash
# UserPromptSubmit.sh: Phase-aware verification hook
#
# This hook runs before Claude processes each user prompt.
# It checks for implementation triggers and validates acceptance criteria exist.
#
# Triggered by: Claude Code UserPromptSubmit hook
# Timeout: 3 seconds

set -euo pipefail

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-.}"
cd "$PROJECT_ROOT"

# --- Stale artifact reminder (commit-relative) ---
# When uncommitted changes exist and JOURNAL/STATUS haven't been updated since
# the last commit, remind the agent. Works correctly in git worktrees.
if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
  UNCOMMITTED=$(git status --porcelain 2>/dev/null | head -1)
  if [[ -n "$UNCOMMITTED" ]]; then
    LAST_COMMIT_TIME=$(git log -1 --format=%ct 2>/dev/null || echo "")
    if [[ -n "$LAST_COMMIT_TIME" ]] && command -v stat >/dev/null 2>&1; then
      STALE_ARTIFACTS=""

      # Check JOURNAL.md
      JOURNAL_PATH=""
      if [[ -f ".agentic-journal/JOURNAL.md" ]]; then
        JOURNAL_PATH=".agentic-journal/JOURNAL.md"
      elif [[ -f "JOURNAL.md" ]]; then
        JOURNAL_PATH="JOURNAL.md"
      fi
      if [[ -n "$JOURNAL_PATH" ]]; then
        if [[ "$(uname)" == "Darwin" ]]; then
          JOURNAL_MTIME=$(stat -f %m "$JOURNAL_PATH")
        else
          JOURNAL_MTIME=$(stat -c %Y "$JOURNAL_PATH")
        fi
        if [[ $JOURNAL_MTIME -le $LAST_COMMIT_TIME ]]; then
          STALE_ARTIFACTS="${STALE_ARTIFACTS}JOURNAL.md "
        fi
      fi

      # Check STATUS.md
      if [[ -f "STATUS.md" ]]; then
        if [[ "$(uname)" == "Darwin" ]]; then
          STATUS_MTIME=$(stat -f %m STATUS.md)
        else
          STATUS_MTIME=$(stat -c %Y STATUS.md)
        fi
        if [[ $STATUS_MTIME -le $LAST_COMMIT_TIME ]]; then
          STALE_ARTIFACTS="${STALE_ARTIFACTS}STATUS.md "
        fi
      fi

      if [[ -n "$STALE_ARTIFACTS" ]]; then
        echo ""
        echo "📋 REMINDER: You have uncommitted changes but ${STALE_ARTIFACTS}not updated since last commit."
        echo "   Update before your next commit:"
        if [[ "$STALE_ARTIFACTS" == *"JOURNAL"* ]]; then
          echo "   bash .agentic/tools/journal.sh \"Topic\" \"Done\" \"Next\" \"Blockers\""
        fi
        if [[ "$STALE_ARTIFACTS" == *"STATUS"* ]]; then
          echo "   bash .agentic/tools/status.sh focus \"Current task\""
        fi
        echo ""
      fi
    fi
  fi
fi

# --- Phase-aware verification (v0.11.0) ---
# Check if user prompt contains "implement" trigger and warn if no acceptance
USER_PROMPT="${CLAUDE_USER_PROMPT:-}"
if [[ "$USER_PROMPT" =~ [Ii]mplement.*(F-[0-9]{4}) ]]; then
  FEATURE_ID="${BASH_REMATCH[1]}"
  if [[ ! -f "spec/acceptance/${FEATURE_ID}.md" ]]; then
    echo ""
    echo "⚠️  GATE WARNING: No acceptance criteria for ${FEATURE_ID}"
    echo "   Create spec/acceptance/${FEATURE_ID}.md before implementing"
    echo "   Run: doctor.sh --phase planning ${FEATURE_ID}"
    echo ""
  fi
fi

exit 0

