#!/usr/bin/env bash
# on-plan-mode-exit.sh — Shared hook logic for plan-mode-exit transition
#
# Called by tool-specific wrappers (Claude Code ExitPlanMode, etc.)
# when the agent exits plan mode. Enforces plan-save + review instructions.
#
# Logic:
#   1. Check plan_review_enabled in STACK.md
#   2. If enabled, run plan-scan.sh to save ephemeral plan to durable location
#   3. Detect profile + convergence mode for profile-aware messaging
#   4. Output banner with next-step instructions (review before implementing)
#
# Exit code: always 0 (advisory — never blocks the agent)

# Bootstrap: ensure lib/ is extracted (no-op if already present)
bash "${CLAUDE_PROJECT_DIR:-.}/.agentic/bootstrap.sh" 2>/dev/null || true

set -uo pipefail

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-${PROJECT_ROOT:-.}}"
cd "$PROJECT_ROOT" 2>/dev/null || exit 0

# Source framework settings
source "$PROJECT_ROOT/.agentic/lib/paths.sh" 2>/dev/null || exit 0
source "$PROJECT_ROOT/.agentic/lib/settings.sh" 2>/dev/null || exit 0

# --- Check if plan review is enabled ---
PLAN_REVIEW=$(get_setting "plan_review_enabled" "no" 2>/dev/null || echo "no")

if [[ "$PLAN_REVIEW" != "yes" ]]; then
    # Plan review not enabled — nothing to enforce
    exit 0
fi

# --- Detect profile + convergence for profile-aware messaging ---
PROFILE=$(_get_profile 2>/dev/null || echo "discovery")
CONVERGENCE=$(get_setting "plan_review_convergence" "manual" 2>/dev/null || echo "manual")

# --- Run plan-scan to save ephemeral plan to durable location ---
SCAN_OUTPUT=""
if [[ -x "$PROJECT_ROOT/.agentic/lib/tools/plan-scan.sh" ]]; then
    SCAN_OUTPUT=$(bash "$PROJECT_ROOT/.agentic/lib/tools/plan-scan.sh" --quiet 2>&1) || true
fi

# --- Output banner ---
echo ""
echo "═══════════════════════════════════════════════════════"
echo "📋 Plan Mode Exit — Review Required"
echo "═══════════════════════════════════════════════════════"

if [[ -n "$SCAN_OUTPUT" ]] && echo "$SCAN_OUTPUT" | grep -q "saved"; then
    # Plan was saved successfully — extract feature ID from plan filename
    LATEST_PLAN=$(ls -t "$PROJECT_ROOT/.agentic/journal/plans/"*-plan.md 2>/dev/null | head -1)
    FEATURE_ID="F-XXXX"
    if [[ -n "$LATEST_PLAN" ]]; then
        PLAN_BASENAME=$(basename "$LATEST_PLAN")
        # Extract F-XXXX from filename like 2026-03-17-F-0234-plan.md
        PARSED_FID=$(echo "$PLAN_BASENAME" | grep -oE "$FEATURE_ID_ERE" | head -1)
        [[ -n "$PARSED_FID" ]] && FEATURE_ID="$PARSED_FID"
        echo "✅ Plan saved as DRAFT → .agentic/journal/plans/$PLAN_BASENAME"
    else
        echo "✅ Plan saved as DRAFT → .agentic/journal/plans/"
    fi
    echo ""

    # Profile-aware messaging: autonomous_formal + auto = NO human needed
    if [[ "$PROFILE" == "autonomous_formal" && "$CONVERGENCE" == "auto" ]]; then
        echo "🚀 AUTONOMOUS MODE — NO HUMAN APPROVAL NEEDED"
        echo ""
        echo "⚠️  Plan is NOT approved. AUTO-CONTINUE NOW (do NOT stop):"
        echo "  1. Spawn Critic + Advocate agents (parallel, fresh context)"
        echo "  2. Synthesize with Revision Guidance"
        echo "  3. Auto-approve when reviewers converge (no human input needed)"
        echo "  4. Run \`ag implement $FEATURE_ID\`"
        echo ""
        echo "This is autonomous_formal with auto convergence."
        echo "You MUST continue immediately — stopping here is a VIOLATION."
    elif [[ "$CONVERGENCE" == "auto" ]]; then
        echo "⚠️  Plan is NOT approved. AUTO-CONTINUE now:"
        echo "  1. Spawn Critic + Advocate agents (parallel, fresh context)"
        echo "  2. Synthesize with Revision Guidance"
        echo "  3. Auto-approve on convergence (convergence: auto)"
        echo "  4. After APPROVED → run \`ag implement $FEATURE_ID\`"
        echo ""
        echo "Do NOT stop and wait — start the review immediately."
    else
        echo "⚠️  Plan is NOT approved. AUTO-CONTINUE now:"
        echo "  1. Spawn Critic + Advocate agents (parallel, fresh context)"
        echo "  2. Synthesize with Revision Guidance"
        echo "  3. Present synthesis to user → user decides (convergence: manual)"
        echo "  4. After APPROVED → run \`ag implement $FEATURE_ID\`"
        echo ""
        echo "Do NOT stop and wait — start the review immediately."
    fi
else
    # No plan found — timing issue or plan not in ephemeral location
    echo "⚠️  Plan mode exited but no plan file found in ephemeral locations."
    echo ""
    echo "Save your plan manually:"
    echo "  cp ~/.claude/plans/<plan-file> .agentic/journal/plans/YYYY-MM-DD-F-XXXX-plan.md"
    echo ""
    echo "Then run \`ag implement F-XXXX\` for dialectical review."
fi

echo "═══════════════════════════════════════════════════════"
echo ""

exit 0
