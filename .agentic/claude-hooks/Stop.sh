#!/usr/bin/env bash
# Stop.sh: Workflow integrity check before ending session
#
# This hook runs when a Claude session is ending (user closes chat, etc.)
# It reminds about uncommitted work and documentation updates.
#
# Triggered by: Claude Code Stop hook
# Timeout: 5 seconds

set -euo pipefail

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-.}"
cd "$PROJECT_ROOT"

# Skip if not an agentic project
if [[ ! -d ".agentic" ]]; then
  exit 0
fi

echo ""
echo "👋 Session ending - final checks..."
echo ""

WARNINGS=0

# 0. Check for .agentic/WIP.md (work in progress lock)
if [[ -f ".agentic/WIP.md" ]]; then
  echo "🚨 .agentic/WIP.md exists - work may be incomplete!"
  echo "   Feature in progress (check .agentic/WIP.md for details)"
  echo "   Options:"
  echo "   - Complete work: bash .agentic/tools/wip.sh complete"
  echo "   - Leave for next session: OK if intentional handoff"
  echo "   - Review: git status && git diff"
  WARNINGS=$((WARNINGS + 1))
fi

# 1. Check for uncommitted changes
if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
  UNCOMMITTED=$(git status --porcelain | wc -l | tr -d ' ')
  if [[ "$UNCOMMITTED" -gt 0 ]]; then
    echo "⚠️  $UNCOMMITTED uncommitted change(s)"
    echo "   Run: git status"
    WARNINGS=$((WARNINGS + 1))
  fi
fi

# 2. Check if JOURNAL.md was updated recently
if [[ -f "JOURNAL.md" ]]; then
  if command -v stat >/dev/null 2>&1; then
    if [[ "$(uname)" == "Darwin" ]]; then
      JOURNAL_AGE_SECONDS=$(( $(date +%s) - $(stat -f %m JOURNAL.md) ))
    else
      JOURNAL_AGE_SECONDS=$(( $(date +%s) - $(stat -c %Y JOURNAL.md) ))
    fi
    
    ONE_HOUR=$((60 * 60))
    if [[ $JOURNAL_AGE_SECONDS -gt $ONE_HOUR ]]; then
      echo "⚠️  JOURNAL.md not updated in this session"
      echo "   Consider adding session summary"
      WARNINGS=$((WARNINGS + 1))
    fi
  fi
fi

# 3. Check if STATUS.md exists and has Project Phase
if [[ -f "STATUS.md" ]]; then
  if ! grep -q "## Project Phase" STATUS.md 2>/dev/null; then
    echo "💡 Tip: Add Project Phase section to STATUS.md"
    echo "   Phase: discovery | building"
  fi
else
  echo "⚠️  No STATUS.md found"
  echo "   Run: bash .agentic/init/scaffold.sh"
  WARNINGS=$((WARNINGS + 1))
fi

# 4. Check for in-progress features (Core+PM mode)
if [[ -f "spec/FEATURES.md" ]]; then
  IN_PROGRESS=$(grep -c "status: in_progress" spec/FEATURES.md 2>/dev/null || echo "0")
  if [[ "$IN_PROGRESS" -gt 0 ]]; then
    echo "📝 $IN_PROGRESS feature(s) in progress"
    echo "   Remember to update status in FEATURES.md"
  fi
fi

# 5. Summary
echo ""
if [[ $WARNINGS -eq 0 ]]; then
  echo "✓ All good! See you next time."
else
  echo "⚠️  $WARNINGS reminder(s) above"
  echo ""
  echo "Session end checklist:"
  echo "- [ ] Commit changes (git add + git commit)"
  echo "- [ ] Update JOURNAL.md with session summary"
  echo "- [ ] Update STATUS.md (Project Phase, current focus)"
fi
echo ""

exit 0

