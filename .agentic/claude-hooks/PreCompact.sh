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
if [[ -f "WIP.md" ]] && [[ -x ".agentic/tools/wip.sh" ]]; then
  bash .agentic/tools/wip.sh checkpoint "Context compaction triggered" 2>/dev/null || true
  echo "✓ Updated WIP checkpoint"
fi

# 1. Auto-log to SESSION_LOG.md (append-only, token-efficient)
if [[ -x ".agentic/tools/session_log.sh" ]]; then
  CURRENT_TASK="Unknown"
  if [[ -f "STATUS.md" ]]; then
    CURRENT_TASK=$(grep -A2 "## Current session state" STATUS.md | tail -1 | sed 's/^[[:space:]]*//' || echo "Working")
  elif [[ -f "PRODUCT.md" ]]; then
    CURRENT_TASK=$(grep -m1 "^- \[ \]" PRODUCT.md | sed 's/^- \[ \] //' || echo "Working")
  fi
  
  bash .agentic/tools/session_log.sh \
    "Context compaction checkpoint" \
    "Saving state before context reset. Last task: ${CURRENT_TASK}" \
    "checkpoint=pre-compact" 2>/dev/null || true
  
  echo "✓ Auto-logged to SESSION_LOG.md"
fi

# 2. Generate fresh .continue-here.md
if [[ -x ".agentic/tools/continue_here.py" ]] && command -v python3 >/dev/null 2>&1; then
  echo "Generating .continue-here.md..."
  if python3 .agentic/tools/continue_here.py 2>/dev/null; then
    echo "✓ Session context preserved in .continue-here.md"
  else
    echo "⚠ Could not generate .continue-here.md (check Python setup)"
  fi
else
  echo "⚠ continue_here.py not available"
fi

# 3. Add JOURNAL.md entry (if we have significant uncommitted work)
if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
  UNCOMMITTED=$(git status --porcelain | wc -l | tr -d ' ')
  if [[ "$UNCOMMITTED" -gt 0 ]] && [[ -f "JOURNAL.md" ]]; then
    TIMESTAMP=$(date "+%Y-%m-%d %H:%M")
    echo "" >> JOURNAL.md
    echo "## $TIMESTAMP - Context Compaction" >> JOURNAL.MD
    echo "" >> JOURNAL.md
    echo "Context window reached capacity. State preserved in .continue-here.md." >> JOURNAL.md
    echo "" >> JOURNAL.md
    echo "Uncommitted changes:" >> JOURNAL.md
    git status --short | head -10 >> JOURNAL.md
    echo "" >> JOURNAL.md
    echo "✓ Added JOURNAL.md entry"
  fi
fi

# 4. Save current feature status (if Core+PM mode)
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
echo "After compaction, I'll resume with full context from .continue-here.md"
echo ""

exit 0

