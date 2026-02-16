#!/usr/bin/env bash
# PreCompact.sh: Preserve critical state before context compaction
#
# This hook runs before Claude compacts the context window (when it gets full).
# It saves critical information so you don't lose progress.
#
# Triggered by: Claude Code PreCompact hook
# Timeout: 10 seconds

set -euo pipefail

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-.}"
cd "$PROJECT_ROOT"

# Skip if not an agentic project
if [[ ! -d ".agentic" ]]; then
  exit 0
fi

echo ""
echo "💾 Context compaction detected - preserving state..."
echo ""

# 0. Update WIP checkpoint if exists (prevent loss of in-progress work)
if [[ -f ".agentic-state/WIP.md" ]] && [[ -x ".agentic/tools/wip.sh" ]]; then
  bash .agentic/tools/wip.sh checkpoint "Context compaction triggered" 2>/dev/null || true
  echo "✓ Updated WIP checkpoint"
fi

# 1. Auto-log to SESSION_LOG.md (append-only, token-efficient)
if [[ -x ".agentic/tools/session_log.sh" ]]; then
  CURRENT_TASK="Unknown"
  if [[ -f "STATUS.md" ]]; then
    CURRENT_TASK=$(grep -A2 "## Current session state" STATUS.md | tail -1 | sed 's/^[[:space:]]*//' || echo "Working")
  else
    echo "⚠ No STATUS.md found"
  fi

  bash .agentic/tools/session_log.sh \
    "Context compaction checkpoint" \
    "Saving state before context reset. Last task: ${CURRENT_TASK}" \
    "checkpoint=pre-compact" 2>/dev/null || true

  echo "✓ Auto-logged to SESSION_LOG.md"
fi

# 2. Verify STATUS.md exists for resume
if [[ -f "STATUS.md" ]]; then
  echo "✓ STATUS.md exists - agent will read at resume"
else
  echo "⚠ No STATUS.md found - create one for better session continuity"
fi

# 3. Add JOURNAL.md entry (if we have significant uncommitted work)
if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
  UNCOMMITTED=$(git status --porcelain | wc -l | tr -d ' ')
  JOURNAL_PATH=""
  if [[ -f ".agentic-journal/JOURNAL.md" ]]; then
    JOURNAL_PATH=".agentic-journal/JOURNAL.md"
  elif [[ -f "JOURNAL.md" ]]; then
    JOURNAL_PATH="JOURNAL.md"
  fi

  if [[ "$UNCOMMITTED" -gt 0 ]] && [[ -n "$JOURNAL_PATH" ]]; then
    TIMESTAMP=$(date "+%Y-%m-%d %H:%M")
    echo "" >> "$JOURNAL_PATH"
    echo "## $TIMESTAMP - Context Compaction" >> "$JOURNAL_PATH"
    echo "" >> "$JOURNAL_PATH"
    echo "Context window reached capacity. State preserved in STATUS.md." >> "$JOURNAL_PATH"
    echo "" >> "$JOURNAL_PATH"
    echo "Uncommitted changes:" >> "$JOURNAL_PATH"
    git status --short | head -10 >> "$JOURNAL_PATH"
    echo "" >> "$JOURNAL_PATH"
    echo "✓ Added JOURNAL.md entry"
  fi
fi

# 4. Save current feature status (if Formal mode)
if [[ -f "spec/FEATURES.md" ]]; then
  IN_PROGRESS=$(grep -c "status: in_progress" spec/FEATURES.md 2>/dev/null || echo "0")
  if [[ "$IN_PROGRESS" -gt 0 ]]; then
    echo "Note: $IN_PROGRESS feature(s) in progress (check FEATURES.md after resuming)"
  fi
fi

# 5. Remind about HUMAN_NEEDED.md
if [[ -f "HUMAN_NEEDED.md" ]]; then
  BLOCKER_COUNT=$(grep -c "^## H-" HUMAN_NEEDED.md 2>/dev/null || echo "0")
  if [[ "$BLOCKER_COUNT" -gt 0 ]]; then
    echo "⚠ Reminder: $BLOCKER_COUNT blocker(s) in HUMAN_NEEDED.md"
  fi
fi

echo ""
echo "✓ State preservation complete"
echo ""
echo "After compaction, agent will resume by reading STATUS.md"
echo "(following session_start.md checklist)"
echo ""

exit 0

