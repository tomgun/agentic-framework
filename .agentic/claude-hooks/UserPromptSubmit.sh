#!/usr/bin/env bash
# UserPromptSubmit.sh: Phase-aware verification hook
#
# This hook runs before Claude processes each user prompt.
# It checks for implementation triggers and validates acceptance criteria exist.
#
# Triggered by: Claude Code UserPromptSubmit hook
# Timeout: 3 seconds

set -euo pipefail

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-.}"
cd "$PROJECT_ROOT"

# --- Phase-aware verification (v0.11.0) ---
# Check if user prompt contains "implement" trigger and warn if no acceptance
USER_PROMPT="${CLAUDE_USER_PROMPT:-}"
if [[ "$USER_PROMPT" =~ [Ii]mplement.*(F-[0-9]{4}) ]]; then
  FEATURE_ID="${BASH_REMATCH[1]}"
  if [[ ! -f "spec/acceptance/${FEATURE_ID}.md" ]]; then
    echo ""
    echo "⚠️  GATE WARNING: No acceptance criteria for ${FEATURE_ID}"
    echo "   Create spec/acceptance/${FEATURE_ID}.md before implementing"
    echo "   Run: doctor.sh --phase planning ${FEATURE_ID}"
    echo ""
  fi
fi

exit 0

