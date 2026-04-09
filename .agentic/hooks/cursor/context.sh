#!/usr/bin/env bash
# Cursor context hook adapter
#
# Injects project state and advisory warnings into Cursor's context.
# Cursor context hooks output to stdout (injected into model context).
#
# Hook events handled:
# - SessionStart: project state, interrupted work, collision detection
# - UserPromptSubmit: stale artifacts, DRAFT plan detection, decision signal detection

set -euo pipefail

PROJECT_ROOT="${PROJECT_ROOT:-.}"
cd "$PROJECT_ROOT"

# Skip if not an agentic project
[[ -d ".agentic" ]] || exit 0

HOOK_EVENT="${CURSOR_HOOK_EVENT:-${1:-}}"

# Read user prompt from stdin for UserPromptSubmit
USER_PROMPT=""
if [[ ! -t 0 ]]; then
  USER_PROMPT=$(cat)
  # Try to extract prompt text from JSON (Cursor may send JSON or plain text)
  if command -v jq >/dev/null 2>&1; then
    _JP=$(echo "$USER_PROMPT" | jq -r '.prompt // .text // .content // empty' 2>/dev/null || true)
    [[ -n "$_JP" ]] && USER_PROMPT="$_JP"
  fi
fi

case "$HOOK_EVENT" in
  SessionStart|session_start)
    # Clear session-scoped sentinels from previous session (safety net for crashes)
    # Stop handler clears these normally; this catches cases where Stop didn't run.
    rm -f .agentic/session/.plan-approved 2>/dev/null || true
    rm -f .agentic/session/.plan-review-skipped 2>/dev/null || true
    rm -f .agentic/session/.plan-advisory-shown 2>/dev/null || true
    rm -f .agentic/session/.spec-first-checked 2>/dev/null || true
    rm -f .agentic/session/.spec-first-skipped 2>/dev/null || true
    rm -f .agentic/session/.correction_hint_shown 2>/dev/null || true

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
    ACTIVE=$(PYTHONPATH="$PROJECT_ROOT/.agentic/lib" python3 -m gate resolve --project-root "$PROJECT_ROOT" 2>/dev/null || true)
    if [[ -n "$ACTIVE" ]]; then
      echo "🎯 Active feature: $ACTIVE"
    fi
    ;;

  UserPromptSubmit|user_prompt_submit)
    # --- Stale artifact check ---
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

    # --- Plan advisory (one-time nudge) ---
    if [[ ! -f ".agentic/session/.plan-approved" && ! -f ".agentic/session/.plan-review-skipped" \
          && ! -f ".agentic/session/.plan-advisory-shown" ]]; then
      source "$PROJECT_ROOT/.agentic/lib/settings.sh" 2>/dev/null || true
      PLAN_REVIEW=$(get_setting "plan_review_enabled" "no" 2>/dev/null || echo "no")
      if [[ "$PLAN_REVIEW" == "yes" ]]; then
        echo ""
        echo "📋 Plan review required (plan_review_enabled=yes)."
        echo "   Code edits blocked until review evidence exists."
        echo "   Complete Critic + Advocate review → save to .agentic/work/F-XXXX/review.md"
        echo "   Or skip: \`ag plan skip\`"
        echo ""
        touch ".agentic/session/.plan-advisory-shown" 2>/dev/null || true
      fi
    fi

    # --- Decision signal detection (F-041: Auto-capture pipeline) ---
    if [[ -n "$USER_PROMPT" ]]; then
      _DB_FILE=".agentic/session/decision-buffer.log"
      _DB_SIGNAL=""
      _DB_SAFE_PROMPT=$(printf '%s' "${USER_PROMPT:0:200}" | tr '|' '/' | tr '\n' ' ')

      # Signal A: Instructions — "always use X", "never push Y", "from now on"
      if echo "$USER_PROMPT" | grep -qiE '(^|\b)(always (use|do|run|add|include|check|write|keep|put|make|ensure|require)|never (push|commit|use|do|run|delete|remove|skip|merge|deploy|write)|don.t ever|from now on|going forward|make sure to|I want you to|rule:|convention:)\b'; then
        _DB_SIGNAL="instruction"
        echo ""
        echo "📝 INSTRUCTION auto-captured. To also enforce at write-time:"
        echo "   \`ag intel learn \"...\" --reason \"user instruction\" --scope \"*\"\`"
        echo ""
      fi

      # Signal B: Decisions — "let's go with", "I decide", "use X instead of Y"
      if [[ -z "$_DB_SIGNAL" ]] && echo "$USER_PROMPT" | grep -qiE '(^|\b)(let.s (go|use|stick) with|I decide|we.ll use|I prefer|use .* instead of|go with|decision:)\b'; then
        _DB_SIGNAL="decision"
        echo ""
        echo "📝 DECISION auto-captured to project memory."
        echo ""
      fi

      # Signal C: Corrections — "no, don't/that's wrong/I said/not like that"
      if [[ -z "$_DB_SIGNAL" ]] && echo "$USER_PROMPT" | grep -qiE '^(no[,. ]+.+(don.t|stop|instead|should|wrong|not)|stop[,. ]+.+(doing|that|this)|wrong|that.s not|I said|actually[,. ]+.+(should|use|do|want)|not like that|I meant)\b'; then
        _DB_SIGNAL="correction"
        echo ""
        echo "📝 CORRECTION auto-captured as learning."
        echo ""
      fi

      # Signal D: Confirmations (only if pending decision exists)
      if [[ -z "$_DB_SIGNAL" ]] && echo "$USER_PROMPT" | grep -qiE '^\s*(yes|yeah|yep|ok|okay|sure|approved?|go ahead|do it|sounds good|lgtm|confirmed?|proceed|ship it|that works)\s*[.!]?\s*$'; then
        _PD_FILE=".agentic/session/pending-decision.txt"
        if [[ -f "$_PD_FILE" ]]; then
          _PD_TEXT=$(head -1 "$_PD_FILE" 2>/dev/null || true)
          if [[ -n "$_PD_TEXT" ]]; then
            _DB_SIGNAL="confirmation"
            _DB_SAFE_PROMPT=$(printf '%s' "$_PD_TEXT" | tr '|' '/' | tr '\n' ' ')
            _PD_DISPLAY=$(printf '%s' "${_PD_TEXT:0:120}" | tr '`$"' "...")
            echo ""
            printf '📝 DECISION CONFIRMED: "%s"\n' "$_PD_DISPLAY"
            echo ""
            rm -f "$_PD_FILE" 2>/dev/null || true
          fi
        fi
      fi

      # Write to decision buffer + auto-capture via ag intel remember
      if [[ -n "$_DB_SIGNAL" ]]; then
        mkdir -p ".agentic/session" 2>/dev/null || true
        echo "$(date -u +%Y-%m-%dT%H:%M:%SZ)|${_DB_SIGNAL}|${_DB_SAFE_PROMPT}" >> "$_DB_FILE"

        _PM_TYPE="preference"
        case "$_DB_SIGNAL" in
          instruction) _PM_TYPE="preference" ;;
          decision|confirmation) _PM_TYPE="decision" ;;
          correction) _PM_TYPE="learning" ;;
        esac
        _AG_TOOL="$PROJECT_ROOT/.agentic/lib/tools/ag.sh"
        if [[ -f "$_AG_TOOL" ]]; then
          bash "$_AG_TOOL" intel remember "$_DB_SAFE_PROMPT" \
            --type "$_PM_TYPE" \
            --context "auto-captured from ${_DB_SIGNAL} signal" \
            --source hook_auto_capture 2>/dev/null || true
        fi
      fi
    fi
    ;;

  *)
    # Unknown event — no output
    ;;
esac

exit 0
