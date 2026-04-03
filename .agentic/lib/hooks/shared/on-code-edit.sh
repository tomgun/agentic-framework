#!/usr/bin/env bash
# on-code-edit.sh — Shared hook for post-code-edit enforcement (advisory)
#
# Called by tool-specific wrappers (Claude Code PostToolUseCodeEdit, etc.)
# after the agent edits a code file via Write/Edit/MultiEdit.
#
# Checks (in order):
#   1. No-WIP warning: code edit with zero features in implementing state
#   2. DRAFT plan warning: code edit while unapproved plan exists
#
# Both checks extract the edited file path from stdin and skip allowlisted paths.
# Exit code: always 0 (advisory — never blocks the agent)
#
# Stdin: JSON with tool_name + tool_input (from Claude Code PostToolUse hook)

# Bootstrap: ensure lib/ is extracted (inline check avoids fork when lib exists)
[[ -d "${CLAUDE_PROJECT_DIR:-.}/.agentic/lib/tools" ]] || bash "${CLAUDE_PROJECT_DIR:-.}/.agentic/bootstrap.sh" 2>/dev/null || true

set -uo pipefail

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-${PROJECT_ROOT:-.}}"
cd "$PROJECT_ROOT" 2>/dev/null || exit 0

# Fast path: skip if not an agentic project
[[ -d ".agentic" ]] || exit 0

# Source framework settings and ID patterns
source "$PROJECT_ROOT/.agentic/lib/settings.sh" 2>/dev/null || exit 0
source "$PROJECT_ROOT/.agentic/lib/paths.sh" 2>/dev/null || true
source "$PROJECT_ROOT/.agentic/lib/tools/btrace.sh" 2>/dev/null || true

# --- Read stdin ONCE (consumed on read, shared by all checks) ---
STDIN_DATA=""
if [[ ! -t 0 ]]; then
  STDIN_DATA=$(cat)
fi

# --- Extract file_path from tool_input JSON ---
EDITED_FILE=""
if [[ -n "$STDIN_DATA" ]]; then
  if command -v jq >/dev/null 2>&1; then
    EDITED_FILE=$(echo "$STDIN_DATA" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
  fi
  if [[ -z "$EDITED_FILE" ]]; then
    EDITED_FILE=$(echo "$STDIN_DATA" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
  fi
fi

# If we couldn't extract a file path, skip all checks
[[ -n "$EDITED_FILE" ]] || exit 0

# --- Allowlist: paths safe to edit regardless of workflow state ---
_is_allowlisted() {
  case "$1" in
    spec/*|*/spec/*|*/.agentic/spec/*) return 0 ;;
    journal/*|*/journal/*|*/.agentic/journal/*) return 0 ;;
    .agentic/session/*|*/.agentic/session/*) return 0 ;;
    .agentic/*) return 0 ;;
    tests/*|test/*|*/tests/*|*/test/*|*_test.*|*_spec.*|*.test.*|*.spec.*) return 0 ;;
    memory/*|*/memory/*|*/MEMORY.md|MEMORY.md) return 0 ;;
    *-plan.md|*-plan-*.md) return 0 ;;
    *.md|*.json|*.yaml|*.yml|*.toml) return 0 ;;
  esac
  return 1
}

# Skip all checks for allowlisted paths
_is_allowlisted "$EDITED_FILE" && exit 0

# =========================================================================
# CHECK 1: No-WIP — warn if zero features are in implementing state
# =========================================================================
# Defense-in-depth: complements PreToolUse F-0251 gate (which may fail on
# error/timeout). If that gate failed-open, this is the next line of defense.
FEATURES_FILE=""
if [[ -f ".agentic/spec/FEATURES.md" ]]; then
  FEATURES_FILE=".agentic/spec/FEATURES.md"
fi
if [[ -n "$FEATURES_FILE" ]]; then
  if ! grep -qiE 'status:\s*(implementing|in.review|testing)' "$FEATURES_FILE" 2>/dev/null; then
    btrace "PostToolUse:on-code-edit" "wip_check" "{\"features_implementing\":0,\"file\":\"${EDITED_FILE}\"}" 2>/dev/null || true
    echo ""
    echo "🚨 NO ACTIVE WORK ITEM — code edit without any feature in 'implementing' state."
    echo "   All features are still planned. Run \`ag start F-XXXX\` then \`ag implement F-XXXX\`."
    echo "   Editing: $EDITED_FILE"
    echo ""
  fi
fi

# =========================================================================
# CHECK 2: DRAFT plan — warn if unapproved plan exists
# =========================================================================
PLAN_REVIEW=$(get_setting "plan_review_enabled" "no" 2>/dev/null || echo "no")
[[ "$PLAN_REVIEW" == "yes" ]] || exit 0

# Fast path: skip if no plan files exist at all
ls .agentic/journal/plans/*-plan.md >/dev/null 2>&1 || exit 0

# Check for DRAFT plans
DRAFT_PLANS=""
DRAFT_FILES=""
for plan_file in .agentic/journal/plans/*-plan.md; do
  [[ -f "$plan_file" ]] || continue
  if grep -q '^\*\*Status\*\*.*DRAFT' "$plan_file" 2>/dev/null || \
     grep -q '^Status:.*DRAFT' "$plan_file" 2>/dev/null; then
    PLAN_FID=$(basename "$plan_file" | grep -oE "$FEATURE_ID_ERE" | head -1)
    DRAFT_PLANS="${DRAFT_PLANS}${PLAN_FID:-unknown} "
    DRAFT_FILES="${DRAFT_FILES}${plan_file} "
  fi
done

# Output DRAFT warning if applicable (defense-in-depth — PreToolUse now blocks in formal)
if [[ -n "$DRAFT_PLANS" ]]; then
  btrace "PostToolUse:on-code-edit" "draft_check" "{\"draft_plans\":\"${DRAFT_PLANS}\",\"file\":\"${EDITED_FILE}\"}" 2>/dev/null || true
  echo ""
  echo "🚨🚨🚨 UNAPPROVED PLAN — STOP CODING 🚨🚨🚨"
  echo ""
  echo "DRAFT plan(s) exist: ${DRAFT_PLANS}"
  echo "Run convergence loop (Critic + Advocate), set APPROVED, then \`ag implement\`."
  echo "PreToolUse gate now blocks code edits with DRAFT plans (formal mode)."
  echo "🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨"
  echo ""
fi

# =========================================================================
# CHECK 3: Push implementation intelligence (first code edit after ag implement)
# =========================================================================
# Fires once per session. Pre-computed by ag implement → .impl-brief.md
if [[ -f ".agentic/session/.phase_implementing" && ! -f ".agentic/session/.impl_intel_pushed" ]]; then
  IMPL_BRIEF=".agentic/session/.impl-brief.md"
  if [[ -f "$IMPL_BRIEF" ]]; then
    echo ""
    echo "🧠 IMPLEMENTATION INTELLIGENCE:"
    cat "$IMPL_BRIEF" | grep "^-" | head -8
    echo ""
    touch ".agentic/session/.impl_intel_pushed" 2>/dev/null || true
  fi
fi

# =========================================================================
# CHECK 4: Spec drift detection (contract surface matching)
# =========================================================================
# If edited file matches patterns extracted from contract verify commands.
# Uses path-component matching (not substring) to reduce false positives:
# pattern "src/auth" matches "src/auth.py" and "src/auth/login.py"
# but NOT "src/oauth/token.py" (different path component).
if [[ -f ".agentic/session/.contract-surface.txt" ]]; then
  SURFACE_FILE=".agentic/session/.contract-surface.txt"
  # Normalize: strip project root prefix, ensure no leading ./
  EDIT_REL="${EDITED_FILE#./}"; EDIT_REL="${EDIT_REL#$PROJECT_ROOT/}"
  _SURFACE_HIT=""
  while IFS= read -r pattern; do
    [[ -z "$pattern" ]] && continue
    # Path-component match: pattern must appear at a / boundary or be the full path
    # e.g., pattern "src/auth" matches "src/auth.py" (starts with src/auth)
    # but not "src/oauth/x.py" (oauth != auth at component level)
    case "$EDIT_REL" in
      "${pattern}"*|*"/${pattern}"*) _SURFACE_HIT="$pattern"; break ;;
    esac
  done < "$SURFACE_FILE"
  if [[ -n "$_SURFACE_HIT" ]]; then
    PHASE_FID=""
    [[ -f ".agentic/session/.phase_implementing" ]] && PHASE_FID=$(cat ".agentic/session/.phase_implementing" 2>/dev/null)
    echo ""
    echo "📋 CONTRACT CHECK: $EDIT_REL may affect contract assertions${PHASE_FID:+ for $PHASE_FID}."
    echo "   Matched surface: $_SURFACE_HIT"
    echo "   Run: ag contract check ${PHASE_FID:-F-XXXX}"
    echo ""
  fi
fi

# =========================================================================
# CHECK 5: TDD nudge (non-test source edit without prior test writes)
# =========================================================================
# Fires once per session when source files edited before any test files
if [[ ! -f ".agentic/session/.tdd_nudge_fired" && -f ".agentic/session/token-events.log" ]]; then
  # Check if any test files have been written this session
  TEST_WRITES=$(grep '^W|' ".agentic/session/token-events.log" 2>/dev/null \
    | grep -cE '\|(tests?/|_test\.|\.test\.|\.spec\.|test_)' 2>/dev/null || echo 0)
  TEST_WRITES="${TEST_WRITES%%[!0-9]*}"; TEST_WRITES="${TEST_WRITES:-0}"
  SRC_WRITES=$(grep '^W|' ".agentic/session/token-events.log" 2>/dev/null \
    | grep -cE '\|(src/|lib/|app/|cmd/)' 2>/dev/null || echo 0)
  SRC_WRITES="${SRC_WRITES%%[!0-9]*}"; SRC_WRITES="${SRC_WRITES:-0}"
  if [[ "$TEST_WRITES" -eq 0 && "$SRC_WRITES" -ge 2 ]]; then
    echo ""
    echo "🧪 TDD REMINDER: ${SRC_WRITES} source files written, 0 test files."
    echo "   Write tests alongside code — the framework checks test existence at verify time."
    echo ""
    touch ".agentic/session/.tdd_nudge_fired" 2>/dev/null || true
  fi
fi

exit 0
