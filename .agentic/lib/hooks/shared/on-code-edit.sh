#!/usr/bin/env bash
# on-code-edit.sh — Shared hook logic for post-code-edit DRAFT plan detection
#
# Called by tool-specific wrappers (Claude Code PostToolUseCodeEdit, etc.)
# after the agent edits a code file via Write/Edit/MultiEdit.
#
# Logic:
#   1. Fast path: exit immediately if plan_review not enabled or no DRAFT plans
#   2. Extract edited file path from tool input on stdin
#   3. Skip warning for allowlisted paths (spec/, journal/, session/, tests/, memory, plans)
#   4. Output loud warning with specific DRAFT plan reference
#
# Exit code: always 0 (advisory — never blocks the agent)
#
# Stdin: JSON with tool_name + tool_input (from Claude Code PostToolUse hook)

set -uo pipefail

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-${PROJECT_ROOT:-.}}"
cd "$PROJECT_ROOT" 2>/dev/null || exit 0

# Fast path: skip if not an agentic project
[[ -d ".agentic" ]] || exit 0

# Source framework settings
source "$PROJECT_ROOT/.agentic/lib/settings.sh" 2>/dev/null || exit 0

# Fast path: skip if plan review not enabled
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
    PLAN_FID=$(basename "$plan_file" | grep -oE 'F-[0-9]{4,}' | head -1)
    DRAFT_PLANS="${DRAFT_PLANS}${PLAN_FID:-unknown} "
    DRAFT_FILES="${DRAFT_FILES}${plan_file} "
  fi
done

# Fast path: no DRAFT plans
[[ -n "$DRAFT_PLANS" ]] || exit 0

# Read stdin to extract file path from tool input
STDIN_DATA=""
if [[ ! -t 0 ]]; then
  STDIN_DATA=$(cat)
fi

# Extract file_path from tool_input JSON
EDITED_FILE=""
if [[ -n "$STDIN_DATA" ]]; then
  # Try to extract file_path from JSON (works with jq or grep fallback)
  if command -v jq >/dev/null 2>&1; then
    EDITED_FILE=$(echo "$STDIN_DATA" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
  fi
  if [[ -z "$EDITED_FILE" ]]; then
    # Grep fallback: look for file_path in JSON
    EDITED_FILE=$(echo "$STDIN_DATA" | grep -oP '"file_path"\s*:\s*"([^"]+)"' | head -1 | sed 's/.*"file_path"\s*:\s*"\([^"]*\)".*/\1/')
  fi
fi

# --- Allowlist: skip warning for non-code files ---
# These are safe to edit even with a DRAFT plan (spec work, test work, memory, etc.)
if [[ -n "$EDITED_FILE" ]]; then
  case "$EDITED_FILE" in
    spec/*|*/spec/*|*/.agentic/spec/*) exit 0 ;;
    journal/*|*/journal/*|*/.agentic/journal/*) exit 0 ;;
    .agentic/session/*|*/.agentic/session/*) exit 0 ;;
    tests/*|test/*|*/tests/*|*/test/*|*_test.*|*_spec.*|*.test.*|*.spec.*) exit 0 ;;
    memory/*|*/memory/*|*/MEMORY.md|MEMORY.md) exit 0 ;;
    *-plan.md|*-plan-*.md) exit 0 ;;
    .agentic/TODO.md|.agentic/HUMAN_NEEDED.md|.agentic/STATUS.md) exit 0 ;;
    */.agentic/TODO.md|*/.agentic/HUMAN_NEEDED.md|*/.agentic/STATUS.md) exit 0 ;;
    .agentic/CONTRIBUTIONS.md|.agentic/ISSUES.md) exit 0 ;;
    */.agentic/CONTRIBUTIONS.md|*/.agentic/ISSUES.md) exit 0 ;;
  esac
fi

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
