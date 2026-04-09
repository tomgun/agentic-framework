#!/usr/bin/env bash
# Cursor PostToolUse hook adapter
#
# Handles:
#   1. Plan approval detection (evidence-based: Critic/Advocate markers in review.md)
#   2. Plan content validation (advisory: checks plans mention ACs + tests)
#   3. Pending-decision resolution (when agent acts after pending-decision)

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

# Parse tool name and file path
if ! command -v jq >/dev/null 2>&1; then
  exit 0  # PostToolUse is advisory — don't block if jq missing
fi

_POST_TOOL=$(echo "$INPUT" | jq -r '.tool_name // .tool // ""' 2>/dev/null || echo "")
_POST_INPUT=$(echo "$INPUT" | jq -c '.tool_input // .input // {}' 2>/dev/null || echo "{}")
_POST_FILE=$(echo "$_POST_INPUT" | jq -r '.file_path // .path // ""' 2>/dev/null || echo "")

# --- Plan approval detection (evidence-based) ---
# When a review.md is written with Critic/Advocate markers, create .plan-approved sentinel
case "$_POST_TOOL" in
  Write|Edit|MultiEdit|file_edit|multi_edit)
    if [[ ! -f ".agentic/session/.plan-approved" && -n "$_POST_FILE" ]]; then
      case "$_POST_FILE" in
        *review.md|*review*.md)
          if [[ -f "$_POST_FILE" ]]; then
            _REV_MARKERS=0
            grep -qi 'Critic' "$_POST_FILE" 2>/dev/null && ((_REV_MARKERS++)) || true
            grep -qi 'Advocate' "$_POST_FILE" 2>/dev/null && ((_REV_MARKERS++)) || true
            grep -qi 'Synthesis\|Convergence\|Recommendation' "$_POST_FILE" 2>/dev/null && ((_REV_MARKERS++)) || true
            if [[ "$_REV_MARKERS" -ge 2 ]]; then
              mkdir -p ".agentic/session" 2>/dev/null || true
              echo "Review evidence verified at $(date -u +%Y-%m-%dT%H:%M:%SZ) from ${_POST_FILE}" > ".agentic/session/.plan-approved"
            fi
          fi
          ;;
      esac
    fi

    # --- Plan content validation (advisory) ---
    if [[ -n "$_POST_FILE" ]]; then
      case "$_POST_FILE" in
        *plan*.md|*-plan.md)
          if [[ -f "$_POST_FILE" ]]; then
            _PC_MISSING=""
            grep -qiE 'acceptance.criter|contract|spec.*assert|\bAC[-_ ]' "$_POST_FILE" 2>/dev/null || _PC_MISSING="${_PC_MISSING}acceptance criteria, "
            grep -qiE '\btests?\b|testing|verification|validate' "$_POST_FILE" 2>/dev/null || _PC_MISSING="${_PC_MISSING}tests/verification, "
            if [[ -n "$_PC_MISSING" ]]; then
              _PC_MISSING="${_PC_MISSING%, }"
              echo "📋 Plan content gap: missing ${_PC_MISSING}." >&2
              echo "   Plans should cover specs, code, tests, and docs together." >&2
            fi
          fi
          ;;
      esac
    fi
    ;;
esac

# --- Pending-decision resolution (F-041) ---
# When agent acts after a pending-decision exists, the decision was enacted.
# Advisory only — the LLM decides whether to capture.
_PD_FILE=".agentic/session/pending-decision.txt"
if [[ -f "$_PD_FILE" ]]; then
  case "$_POST_TOOL" in
    Write|Edit|MultiEdit|file_edit|multi_edit|Shell|Bash)
      _PD_TEXT=$(head -1 "$_PD_FILE" 2>/dev/null || true)
      if [[ -n "$_PD_TEXT" ]]; then
        echo "✅ Decision enacted: \"${_PD_TEXT:0:80}\"" >&2
        echo "   If this is a lasting preference: \`ag intel remember \"...\" --type decision\`" >&2
        rm -f "$_PD_FILE" 2>/dev/null || true
      fi
      ;;
  esac
fi

exit 0
