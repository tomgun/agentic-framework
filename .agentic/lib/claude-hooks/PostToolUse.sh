#!/usr/bin/env bash
# PostToolUse.sh: Run quick quality checks after code edits
#
# This hook runs after Claude uses any tool (file edits, terminal commands, etc.)
# It performs fast, non-blocking quality checks to catch issues early.
#
# Triggered by: Claude Code PostToolUse hook
# Timeout: 2 seconds

# Bootstrap: ensure lib/ is extracted (inline check avoids fork when lib exists)
[[ -d "${CLAUDE_PROJECT_DIR:-.}/.agentic/lib/tools" ]] || bash "${CLAUDE_PROJECT_DIR:-.}/.agentic/bootstrap.sh" 2>/dev/null || true

set -euo pipefail

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-.}"
cd "$PROJECT_ROOT"
source "$PROJECT_ROOT/.agentic/lib/paths.sh" 2>/dev/null || true
source "$PROJECT_ROOT/.agentic/lib/tools/fwlog.sh" 2>/dev/null || true
source "$PROJECT_ROOT/.agentic/lib/tools/btrace.sh" 2>/dev/null || true
flog "hook:post-tool-use" "fire" "" "start"

# Skip if not an agentic project
if [[ ! -d ".agentic" ]]; then
  exit 0
fi

# --- Token tracking (Phase 2: F-041 Intelligence Engine) ---
# Read tool info from stdin, log events for session metrics.
# Pure bash extraction — no Python fork. Appends one line per event (<1ms).
# NOTE: This consumes stdin. All downstream code in this script must not read stdin.
_POST_STDIN=$(cat 2>/dev/null || true)
_POST_TOOL=""
_POST_FILE=""
if [[ -n "$_POST_STDIN" ]]; then
  if [[ "$_POST_STDIN" =~ \"tool_name\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
    _POST_TOOL="${BASH_REMATCH[1]}"
  fi
  if [[ "$_POST_STDIN" =~ \"file_path\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
    _POST_FILE="${BASH_REMATCH[1]}"
  fi
fi

btrace "PostToolUse" "enter" "{\"tool\":\"${_POST_TOOL:-unknown}\",\"file\":\"${_POST_FILE:-}\"}" 2>/dev/null || true

if [[ -n "$_POST_TOOL" ]]; then
  _TK_EVENTS=".agentic/session/token-events.log"
  case "$_POST_TOOL" in
    Read)
      _TK_EST=0
      if [[ -n "$_POST_FILE" && -f "$_POST_FILE" ]]; then
        _TK_SZ=$(wc -c < "$_POST_FILE" 2>/dev/null || echo 0)
        _TK_SZ="${_TK_SZ## }"
        _TK_EST=$(( _TK_SZ / 4 ))
      fi
      echo "R|${_POST_FILE:-unknown}|${_TK_EST}" >> "$_TK_EVENTS" 2>/dev/null || true
      ;;
    Write|Edit|MultiEdit)
      _TK_EST=0
      if [[ -n "$_POST_FILE" && -f "$_POST_FILE" ]]; then
        _TK_SZ=$(wc -c < "$_POST_FILE" 2>/dev/null || echo 0)
        _TK_SZ="${_TK_SZ## }"
        _TK_EST=$(( _TK_SZ / 4 ))
      fi
      echo "W|${_POST_FILE:-unknown}|${_TK_EST}" >> "$_TK_EVENTS" 2>/dev/null || true
      # Track design doc writes for catalog enforcement (F-042)
      # FEATURES.md = formal feature tracking; OVERVIEW.md = lightweight design doc
      case "${_POST_FILE:-}" in
        *FEATURES.md|*OVERVIEW.md) touch ".agentic/session/.cap_updated" 2>/dev/null || true ;;
      esac
      # --- Plan approval detection (evidence-based) ---
      # When a review.md is written with structural markers from Critic/Advocate agents,
      # create the .plan-approved sentinel. This is evidence-based — the review file
      # must contain markers from independent reviewers, not just a status change.
      if [[ ! -f ".agentic/session/.plan-approved" ]]; then
        case "${_POST_FILE:-}" in
          *review.md|*review*.md)
            if [[ -f "$_POST_FILE" ]]; then
              _REV_MARKERS=0
              grep -qi 'Critic' "$_POST_FILE" 2>/dev/null && ((_REV_MARKERS++)) || true
              grep -qi 'Advocate' "$_POST_FILE" 2>/dev/null && ((_REV_MARKERS++)) || true
              grep -qi 'Synthesis\|Convergence\|Recommendation' "$_POST_FILE" 2>/dev/null && ((_REV_MARKERS++)) || true
              if [[ "$_REV_MARKERS" -ge 2 ]]; then
                mkdir -p ".agentic/session" 2>/dev/null || true
                echo "Review evidence verified at $(date -u +%Y-%m-%dT%H:%M:%SZ) from ${_POST_FILE}" > ".agentic/session/.plan-approved"
                btrace "PostToolUse" "plan_approved" "{\"review_file\":\"${_POST_FILE##*/}\",\"markers\":$_REV_MARKERS}" 2>/dev/null || true
              fi
            fi
            ;;
        esac
      fi
      # --- Plan content validation (advisory) ---
      # When a plan file is written, check it mentions acceptance criteria, tests,
      # and verification. Advisory only — plans are iterative, but gaps should be visible.
      case "${_POST_FILE:-}" in
        *plan*.md|*-plan.md)
          if [[ -f "$_POST_FILE" ]]; then
            _PC_MISSING=""
            grep -qi 'acceptance.criter\|contract\|spec.*assert\|\bAC\b' "$_POST_FILE" 2>/dev/null || _PC_MISSING="${_PC_MISSING}acceptance criteria, "
            grep -qi 'test\|verif' "$_POST_FILE" 2>/dev/null || _PC_MISSING="${_PC_MISSING}tests/verification, "
            if [[ -n "$_PC_MISSING" ]]; then
              _PC_MISSING="${_PC_MISSING%, }"
              echo "📋 Plan content gap: missing ${_PC_MISSING}." >&2
              echo "   Plans should cover specs, code, tests, and docs together." >&2
              btrace "PostToolUse" "plan_content_gap" "{\"missing\":\"${_PC_MISSING}\"}" 2>/dev/null || true
            fi
          fi
          ;;
      esac
      ;;
  esac

  # --- Pending-decision resolution (F-041: Auto-capture pipeline) ---
  # When agent acts (Write/Edit/Bash) after a pending-decision exists, the decision
  # was implicitly confirmed by action. Log it and clean up.
  _PD_FILE=".agentic/session/pending-decision.txt"
  if [[ -f "$_PD_FILE" ]]; then
    case "$_POST_TOOL" in
      Write|Edit|MultiEdit|Bash)
        _PD_TEXT=$(head -1 "$_PD_FILE" 2>/dev/null || true)
        if [[ -n "$_PD_TEXT" ]]; then
          _PD_SAFE=$(printf '%s' "$_PD_TEXT" | tr '|' '/' | tr '\n' ' ')
          mkdir -p ".agentic/session" 2>/dev/null || true
          echo "$(date -u +%Y-%m-%dT%H:%M:%SZ)|action_confirmed|${_PD_SAFE}" >> ".agentic/session/decision-buffer.log" 2>/dev/null || true
          btrace "PostToolUse" "decision_enacted" "{\"tool\":\"${_POST_TOOL}\"}" 2>/dev/null || true
          echo "📝 Decision enacted: \"${_PD_TEXT:0:80}\". Logged to decision buffer." >&2
          rm -f "$_PD_FILE" 2>/dev/null || true
        fi
        ;;
    esac
  fi

  # --- Token budget awareness (Change 6b) ---
  # Every 5th Read event, check for repeated reads and total token cost.
  # Pushes one-time warning when thresholds exceeded.
  if [[ "$_POST_TOOL" == "Read" && -f "$_TK_EVENTS" && ! -f ".agentic/session/.token_budget_warned" ]]; then
    _TK_READ_COUNT=$(grep -c '^R|' "$_TK_EVENTS" 2>/dev/null || echo 0)
    _TK_READ_COUNT="${_TK_READ_COUNT## }"
    if [[ $(( _TK_READ_COUNT % 5 )) -eq 0 && "${_TK_READ_COUNT:-0}" -ge 5 ]]; then
      # Check for repeated reads (same file 3+ times)
      _TK_TOP_REPEAT=""
      _TK_TOP_COUNT=0
      if command -v sort >/dev/null 2>&1; then
        _TK_TOP_LINE=$(grep '^R|' "$_TK_EVENTS" 2>/dev/null | cut -d'|' -f2 | sort | uniq -c | sort -rn | head -1)
        _TK_TOP_COUNT=$(echo "$_TK_TOP_LINE" | awk '{print $1}')
        _TK_TOP_COUNT="${_TK_TOP_COUNT## }"; _TK_TOP_COUNT="${_TK_TOP_COUNT%% }"
        _TK_TOP_REPEAT=$(echo "$_TK_TOP_LINE" | awk '{print $2}')
      fi
      if [[ "${_TK_TOP_COUNT:-0}" -ge 3 ]]; then
        _TK_TOP_BASENAME="${_TK_TOP_REPEAT##*/}"
        echo "" >&2
        echo "📊 TOKEN: ${_TK_TOP_BASENAME} read ${_TK_TOP_COUNT} times. Consider keeping notes to avoid re-reading." >&2
        echo "" >&2
        touch ".agentic/session/.token_budget_warned" 2>/dev/null || true
      fi
      # Check total estimated tokens
      if [[ ! -f ".agentic/session/.token_budget_warned" ]]; then
        _TK_TOTAL=$(awk -F'|' '{sum += $3} END {print sum+0}' "$_TK_EVENTS" 2>/dev/null || echo 0)
        _TK_TOTAL="${_TK_TOTAL## }"
        if [[ "${_TK_TOTAL:-0}" -ge 500000 ]]; then
          echo "" >&2
          echo "📊 TOKEN BUDGET: ~${_TK_TOTAL} estimated context tokens used this session." >&2
          echo "   Consider compacting context or wrapping up current task." >&2
          echo "" >&2
          touch ".agentic/session/.token_budget_warned" 2>/dev/null || true
        fi
      fi
    fi
  fi
fi

# --- Advisory artifact check (hooks-first: uses gate.py) ---
# After tool use, check artifact status for active feature. Advisory only.
# PreToolUse already handles blocking for Write/Edit — this adds awareness
# for other tools (Bash, Read, Agent, etc.).
ARTIFACT_JSON=$(PYTHONPATH="$PROJECT_ROOT/.agentic/lib" python3 -m gate check-artifacts --project-root "$PROJECT_ROOT" 2>/dev/null || true)

if [[ -n "$ARTIFACT_JSON" ]]; then
  # Parse feature + issues from JSON
  if command -v jq >/dev/null 2>&1; then
    FEAT=$(echo "$ARTIFACT_JSON" | jq -r '.feature // ""' 2>/dev/null)
    ISSUES=$(echo "$ARTIFACT_JSON" | jq -r '.issues // [] | join("; ")' 2>/dev/null)
  else
    FEAT=$(echo "$ARTIFACT_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('feature',''))" 2>/dev/null || true)
    ISSUES=$(echo "$ARTIFACT_JSON" | python3 -c "import sys,json; print('; '.join(json.load(sys.stdin).get('issues',[])))" 2>/dev/null || true)
  fi
  if [[ -n "$ISSUES" ]]; then
    echo "📋 ${FEAT}: ${ISSUES}"
  fi
fi

# Only run linter checks after file writes (not after reads)
# PostToolUse receives JSON on stdin with tool_name, tool_input, tool_response
# This generic hook matches all tools (matcher: ".*"), so we infer from file modifications
RECENT_CHANGES=$(find . -type f -mmin -1 -not -path "./.git/*" -not -path "./.agentic/.cache/*" 2>/dev/null | head -5)

if [[ -z "$RECENT_CHANGES" ]]; then
  # No recent changes, skip checks
  exit 0
fi

# Run fast linter checks only (no tests, those are slow)
# This is advisory only - doesn't block Claude, just provides feedback

HAS_ISSUES=false

# Check for common syntax errors (if applicable stack)
if [[ -f "package.json" ]] && command -v npx >/dev/null 2>&1; then
  # JavaScript/TypeScript project
  if npx eslint --quiet --max-warnings 0 . 2>/dev/null; then
    :  # No issues
  else
    HAS_ISSUES=true
  fi
elif [[ -f "Cargo.toml" ]] && command -v cargo >/dev/null 2>&1; then
  # Rust project
  if cargo check --quiet 2>/dev/null; then
    :  # No issues
  else
    HAS_ISSUES=true
  fi
elif command -v python3 >/dev/null 2>&1 && find . -name "*.py" -mmin -1 2>/dev/null | grep -q .; then
  # Python project with recent .py changes
  if command -v ruff >/dev/null 2>&1; then
    if ruff check --quiet . 2>/dev/null; then
      :  # No issues
    else
      HAS_ISSUES=true
    fi
  fi
fi

if [[ "$HAS_ISSUES" == "true" ]]; then
  echo ""
  echo "⚠️  Quick lint check found issues. Run your linter to see details."
  echo ""
fi

# Auto-log checkpoint (every ~10 tool uses to avoid spam)
COUNTER_FILE=".agentic/.cache/tool_use_counter"
mkdir -p ".agentic/.cache" 2>/dev/null || true

if [[ -f "$COUNTER_FILE" ]]; then
  COUNT=$(cat "$COUNTER_FILE")
  COUNT=$((COUNT + 1))
else
  COUNT=1
fi

echo "$COUNT" > "$COUNTER_FILE"

# Log every 10th tool use as a checkpoint
if [[ $((COUNT % 10)) -eq 0 ]] && [[ -x ".agentic/lib/tools/session_log.sh" ]]; then
  bash .agentic/lib/tools/session_log.sh \
    "Checkpoint (${COUNT} actions)" \
    "Automatic checkpoint after ${COUNT} tool uses." \
    "checkpoint=auto,actions=${COUNT}" 2>/dev/null || true
fi

# Change 11: Suggest ag sync periodically (every 50 tool uses, max once)
if [[ $((COUNT % 50)) -eq 0 && ! -f ".agentic/session/.sync_suggested" ]]; then
  echo "" >&2
  echo "🔄 50+ tool uses — consider running \`ag sync\` to check artifact consistency." >&2
  echo "" >&2
  touch ".agentic/session/.sync_suggested" 2>/dev/null || true
fi

exit 0  # Always exit 0 (advisory only, don't block Claude)

