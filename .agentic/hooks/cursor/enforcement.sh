#!/usr/bin/env bash
# Cursor enforcement hook adapter
#
# Handles: PreToolUse, Stop
# Cursor hooks communicate via stdin JSON and exit codes:
#   exit 0 = allow, exit 2 = deny (fail-closed)
#
# PreToolUse gates:
#   1. Python gate module (TDD, destructive ops, etc.)
#   2. Plan approval gate (blocks code edits without approved plan)
#   3. Spec-before-code (blocks impl before spec in formal profiles)

set -euo pipefail

PROJECT_ROOT="${PROJECT_ROOT:-.}"
cd "$PROJECT_ROOT"

# Skip if not an agentic project
[[ -d ".agentic" ]] || exit 0

# Read hook input from stdin
INPUT=""
if [[ ! -t 0 ]]; then
  INPUT=$(cat)
fi

# Determine hook event from environment or first argument
HOOK_EVENT="${CURSOR_HOOK_EVENT:-${1:-}}"

# Parse tool name and input using jq (required for Cursor — no manual JSON parsing)
if ! command -v jq >/dev/null 2>&1; then
  echo "jq required for Cursor hooks" >&2
  exit 2  # Fail-closed
fi

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // .tool // ""' 2>/dev/null || echo "")
TOOL_INPUT=$(echo "$INPUT" | jq -c '.tool_input // .input // {}' 2>/dev/null || echo "{}")

# Helper: deny with message
_deny() {
  echo "$1" >&2
  exit 2
}

case "$HOOK_EVENT" in
  PreToolUse|pre_tool_use)
    # --- Gate 1: Python gate module (TDD, destructive ops, etc.) ---
    GATE_OUTPUT=$(PYTHONPATH="$PROJECT_ROOT/.agentic/lib" python3 -m gate pretool \
      --tool "${TOOL_NAME}" \
      --input "${TOOL_INPUT}" \
      --project-root "$PROJECT_ROOT" 2>&1) || {
      DECISION=$(echo "$GATE_OUTPUT" | jq -r '.decision // "deny"' 2>/dev/null || echo "deny")
      if [[ "$DECISION" == "deny" ]]; then
        REASONS=$(echo "$GATE_OUTPUT" | jq -r '.reasons // [] | join(". ")' 2>/dev/null || echo "Blocked by policy")
        _deny "$REASONS"
      fi
    }

    # --- Shared: Extract file_path for Write/Edit gates ---
    # Cursor tool names vary: file_edit, multi_edit, Write, Edit
    _EDIT_FILE_PATH=""
    case "$TOOL_NAME" in
      Write|Edit|MultiEdit|file_edit|multi_edit)
        _EDIT_FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.file_path // .path // ""' 2>/dev/null || echo "")
        ;;
    esac

    if [[ -n "$_EDIT_FILE_PATH" ]]; then
      # Classify: doc/config/spec (allowed) vs implementation (gated)
      _IS_DOC_FILE=0
      case "$_EDIT_FILE_PATH" in
        *plan*.md|*CLAUDE.md|*cursorrules*|*memory-seed*|*JOURNAL*|*STATUS*|*HUMAN_NEEDED*|*TODO*|*CONTRIBUTIONS*|*OVERVIEW*|*FEATURES*|*STACK*|*CONTEXT_PACK*|*review*|*spec/*|*contracts/*|"")
          _IS_DOC_FILE=1 ;;
      esac

      # Source settings once for all gates
      source "$PROJECT_ROOT/.agentic/lib/settings.sh" 2>/dev/null || true

      # --- Gate 2: Plan approval ---
      if [[ "$_IS_DOC_FILE" -eq 0 && ! -f ".agentic/session/.plan-approved" && ! -f ".agentic/session/.plan-review-skipped" ]]; then
        _PLAN_REVIEW=$(get_setting "plan_review_enabled" "no" 2>/dev/null || echo "no")
        if [[ "$_PLAN_REVIEW" == "yes" ]]; then
          _deny "No approved plan for this session. Run \`ag implement F-XXXX\` or \`ag plan skip\`. plan_review_enabled=yes requires approval before code edits."
        fi
      fi

      # --- Gate 3: Spec-before-code ---
      if [[ "$_IS_DOC_FILE" -eq 0 && ! -f ".agentic/session/.spec-first-checked" && ! -f ".agentic/session/.spec-first-skipped" ]]; then
        _SF_FT=$(get_setting "feature_tracking" "no" 2>/dev/null || echo "no")
        _TK_EVENTS=".agentic/session/token-events.log"
        _SF_HAS_SPEC=0
        if [[ -f "$_TK_EVENTS" ]]; then
          grep -q '^W|.*spec/\|^W|.*contracts/' "$_TK_EVENTS" 2>/dev/null && _SF_HAS_SPEC=1
        fi
        if [[ "$_SF_HAS_SPEC" -eq 0 ]]; then
          if [[ "$_SF_FT" == "yes" ]]; then
            _deny "Spec-before-code: writing implementation file before any spec/contract. Write specs first or skip: \`ag plan skip\`"
          else
            echo "💡 Consider writing specs before code — \`ag intel remember\` captures decisions." >&2
            touch ".agentic/session/.spec-first-checked" 2>/dev/null || true
          fi
        else
          touch ".agentic/session/.spec-first-checked" 2>/dev/null || true
        fi
      fi
    fi
    ;;

  Stop|stop)
    # --- Gate: Verification ---
    GATE_OUTPUT=$(PYTHONPATH="$PROJECT_ROOT/.agentic/lib" python3 -m gate stop \
      --project-root "$PROJECT_ROOT" 2>&1) || {
      DECISION=$(echo "$GATE_OUTPUT" | jq -r '.decision // "deny"' 2>/dev/null || echo "deny")
      if [[ "$DECISION" == "deny" ]]; then
        REASONS=$(echo "$GATE_OUTPUT" | jq -r '.reasons // [] | join(". ")' 2>/dev/null || echo "Verification not passed")
        _deny "$REASONS"
      fi
    }

    # --- Decision buffer audit ---
    _DB_FILE=".agentic/session/decision-buffer.log"
    if [[ -f "$_DB_FILE" ]]; then
      _DB_COUNT=$(wc -l < "$_DB_FILE" 2>/dev/null || echo 0)
      _DB_COUNT="${_DB_COUNT## }"; _DB_COUNT="${_DB_COUNT%% }"; _DB_COUNT="${_DB_COUNT%%[!0-9]*}"; _DB_COUNT="${_DB_COUNT:-0}"
      if [[ "${_DB_COUNT:-0}" -gt 0 ]]; then
        echo "📝 ${_DB_COUNT} decision signal(s) detected this session." >&2
        echo "   Review: \`cat .agentic/session/decision-buffer.log\`" >&2
        echo "   Batch capture: \`ag intel batch-remember --from-buffer\`" >&2
      fi
    fi

    # --- Clean up session sentinels ---
    rm -f .agentic/session/.plan-approved 2>/dev/null || true
    rm -f .agentic/session/.plan-review-skipped 2>/dev/null || true
    rm -f .agentic/session/.plan-advisory-shown 2>/dev/null || true
    rm -f .agentic/session/.spec-first-checked 2>/dev/null || true
    rm -f .agentic/session/.spec-first-skipped 2>/dev/null || true
    rm -f .agentic/session/.correction_hint_shown 2>/dev/null || true
    rm -f .agentic/session/decision-buffer.log 2>/dev/null || true
    rm -f .agentic/session/pending-decision.txt 2>/dev/null || true
    ;;

  *)
    # Unknown hook event — allow (don't block on unknown events)
    ;;
esac

# If we get here, allow
exit 0
