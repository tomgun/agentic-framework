#!/usr/bin/env bash
# Cursor context hook adapter
#
# Injects project state and advisory warnings into Cursor's context.
# Cursor context hooks output to stdout (injected into model context).
#
# Hook events handled:
# - SessionStart: project state, interrupted work, collision detection
# - UserPromptSubmit: stale artifacts, DRAFT plan detection, intent routing

set -euo pipefail

PROJECT_ROOT="${PROJECT_ROOT:-.}"
cd "$PROJECT_ROOT"

# Skip if not an agentic project
[[ -d ".agentic" ]] || exit 0

HOOK_EVENT="${CURSOR_HOOK_EVENT:-${1:-}}"

case "$HOOK_EVENT" in
  SessionStart|session_start)
    echo "🚀 Agentic Framework Session"

    # Framework version
    if [[ -f ".agentic/STACK.md" ]]; then
      VERSION=$(grep -E "framework_version:" .agentic/STACK.md | head -1 | awk '{print $2}' || echo "unknown")
      echo "📦 Version: $VERSION"
    fi

    # Current focus from STATUS.md
    if [[ -f "STATUS.md" ]]; then
      FOCUS=$(grep -A 1 "## Current Focus" STATUS.md 2>/dev/null | tail -1 | head -c 60 || echo "")
      [[ -n "$FOCUS" ]] && echo "📍 Focus: $FOCUS"
    fi

    # Uncommitted changes
    if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
      UNCOMMITTED=$(git status --porcelain | wc -l | tr -d ' ')
      [[ "$UNCOMMITTED" -gt 0 ]] && echo "📝 $UNCOMMITTED uncommitted change(s)"
    fi

    # Active feature status via gate
    ACTIVE=$(PYTHONPATH="$PROJECT_ROOT/.agentic/lib" python3 -c "
import sys; sys.path.insert(0, '$PROJECT_ROOT/.agentic/lib')
from gate import resolve_active_feature; from pathlib import Path
f = resolve_active_feature(Path('$PROJECT_ROOT'))
print(f or '')
" 2>/dev/null || true)
    if [[ -n "$ACTIVE" ]]; then
      echo "🎯 Active feature: $ACTIVE"
    fi
    ;;

  UserPromptSubmit|user_prompt_submit)
    # Stale artifact check
    if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
      UNCOMMITTED=$(git status --porcelain 2>/dev/null | head -1)
      if [[ -n "$UNCOMMITTED" ]]; then
        LAST_COMMIT_TIME=$(git log -1 --format=%ct 2>/dev/null || echo "")
        if [[ -n "$LAST_COMMIT_TIME" ]]; then
          STALE=""
          for f in ".agentic/journal/JOURNAL.md" "STATUS.md"; do
            if [[ -f "$f" ]]; then
              MTIME=$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f" 2>/dev/null || echo "0")
              [[ "$MTIME" -le "$LAST_COMMIT_TIME" ]] && STALE="$STALE $(basename $f)"
            fi
          done
          [[ -n "$STALE" ]] && echo "📋 REMINDER: $STALE not updated since last commit"
        fi
      fi
    fi

    # DRAFT plan detection
    if [[ -d ".agentic/journal/plans" ]]; then
      source "$PROJECT_ROOT/.agentic/lib/settings.sh" 2>/dev/null || true
      PLAN_REVIEW=$(get_setting "plan_review_enabled" "no" 2>/dev/null || echo "no")
      if [[ "$PLAN_REVIEW" == "yes" ]]; then
        DRAFTS=""
        for plan_file in .agentic/journal/plans/*-plan.md; do
          [[ -f "$plan_file" ]] || continue
          if grep -q 'DRAFT' "$plan_file" 2>/dev/null; then
            FID=$(basename "$plan_file" | grep -oE 'F-[0-9]{4,}' | head -1)
            DRAFTS="$DRAFTS ${FID:-unknown}"
          fi
        done
        [[ -n "$DRAFTS" ]] && echo "⚠️ DRAFT plan(s):$DRAFTS — review before coding"
      fi
    fi
    ;;

  *)
    # Unknown event — no output
    ;;
esac

exit 0
