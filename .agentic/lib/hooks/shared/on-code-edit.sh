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

# Fast path: no DRAFT plans
[[ -n "$DRAFT_PLANS" ]] || exit 0

# --- Output loud warning ---
echo ""
echo "🚨🚨🚨 UNAPPROVED PLAN — STOP CODING 🚨🚨🚨"
echo ""
echo "You are editing code with an unapproved plan!"
echo "DRAFT plan(s) exist: ${DRAFT_PLANS}"
echo "Plan file(s): ${DRAFT_FILES}"
echo ""
echo "STOP writing code. Run the convergence loop:"
echo "  1. Spawn Critic + Advocate agents (parallel, fresh context)"
echo "  2. Synthesize findings into Revision Guidance"
echo "  3. If refinements needed → revise plan → re-run reviewers"
echo "  4. Loop until reviewers converge OR max iterations hit"
echo "  5. Mark plan APPROVED only after convergence"
echo "  6. THEN write code via \`ag implement\`"
echo ""
echo "Pre-commit Check 21 will BLOCK your commit anyway."
echo "🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨"
echo ""

exit 0
