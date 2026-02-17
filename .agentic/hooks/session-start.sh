#!/usr/bin/env bash
# session-start.sh - Enforce session start protocol
#
# This script provides the MANDATORY reading list for agents at session start.
# Ensures agents have proper context before beginning work.
#
# Usage:
#   bash .agentic/hooks/session-start.sh
#
# Output:
#   - List of files agent MUST read
#   - Priority order (critical first)
#   - Token budget estimates
#   - Detected project state (WIP, blockers, etc.)
#
# This should be run AUTOMATICALLY at session start (e.g., via Claude hooks)
# or MANUALLY by agent as first action.
#
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${PROJECT_ROOT}"

# Source shared settings
source "${PROJECT_ROOT}/.agentic/lib/settings.sh"

echo ""
echo "═══════════════════════════════════════════════════════"
echo "SESSION START PROTOCOL"
echo "═══════════════════════════════════════════════════════"
echo ""

PROFILE=$(get_setting "profile" "discovery")

echo "Project Profile: ${PROFILE}"
echo ""

# CRITICAL: Check for interrupted work FIRST
echo "═══════════════════════════════════════════════════════"
echo "🚨 CRITICAL: Checking for Interrupted Work"
echo "═══════════════════════════════════════════════════════"
echo ""

if [[ -x ".agentic/tools/wip.sh" ]]; then
  if bash .agentic/tools/wip.sh check; then
    echo "✓ No interrupted work detected - clean state"
  else
    echo ""
    echo "⚠️  STOP: Interrupted work detected!"
    echo "    Do NOT proceed with new work until this is resolved."
    echo "    Review the recovery options above and decide with user."
    echo ""
  fi
else
  echo "⚠️  wip.sh not found - cannot check for interrupted work"
fi

echo ""
echo "═══════════════════════════════════════════════════════"
echo "MANDATORY READING LIST (Token Budget: ~2-3K tokens)"
echo "═══════════════════════════════════════════════════════"
echo ""

# Always read
echo "📖 ALWAYS READ (regardless of profile):"
echo ""
echo "1. CONTEXT_PACK.md (~500-1000 tokens)"
echo "   - Where code lives"
echo "   - How to run/test"
echo "   - Architecture snapshot"
echo "   - Known constraints"
echo ""

# STATUS.md is required for all profiles (v0.12.0+)
echo "2. STATUS.md (~300-800 tokens)"
echo "   - Current focus"
echo "   - What's in progress"
echo "   - Next steps"
echo "   - Known blockers"
echo ""
if [[ -f "OVERVIEW.md" ]]; then
  echo "   Optional: OVERVIEW.md exists - read for detailed project vision"
  echo ""
fi

# Check STATUS.md freshness — auto-infer state if stale
if [[ -f "STATUS.md" ]]; then
  if [[ "$(uname)" == "Darwin" ]]; then
    STATUS_AGE=$(( ($(date +%s) - $(stat -f %m STATUS.md)) / 86400 ))
  else
    STATUS_AGE=$(( ($(date +%s) - $(stat -c %Y STATUS.md)) / 86400 ))
  fi
  if [[ $STATUS_AGE -gt 7 ]]; then
    echo "   ⚠️  WARNING: STATUS.md last updated ${STATUS_AGE} days ago!"
    echo "      Auto-inferring current state from history..."
    echo ""
    if [[ -x ".agentic/tools/status.sh" ]]; then
      bash .agentic/tools/status.sh infer 2>/dev/null || true
      echo ""
      echo "   → Review the inferred state above."
      echo "   → To apply: bash .agentic/tools/status.sh infer --apply"
      echo "   → Or update STATUS.md manually with better context."
      echo ""
    else
      echo "      Update it early this session."
      echo ""
    fi
  fi
fi

echo "3. JOURNAL.md - Last 2-3 entries (~500-1000 tokens)"
echo "   - Recent progress"
echo "   - What worked/didn't work"
echo "   - Avoid repeating mistakes"
echo "   (Location: .agentic-journal/JOURNAL.md or JOURNAL.md)"
echo ""

# Check for blockers
if [[ -f "HUMAN_NEEDED.md" ]]; then
  BLOCKER_COUNT=$(grep -c "^### HN-" HUMAN_NEEDED.md 2>/dev/null || echo "0")
  if [[ $BLOCKER_COUNT -gt 0 ]]; then
    echo "4. ⚠️  HUMAN_NEEDED.md - ${BLOCKER_COUNT} blocker(s) present"
    echo "   - PRIORITY: Address blockers before new work"
    echo "   - Ask user which to resolve first"
    echo ""
  fi
fi

# Feature-tracking-specific reads
FT=$(get_setting "feature_tracking" "no")
if [[ "$FT" == "yes" ]]; then
  echo ""
  echo "📖 FEATURE TRACKING - ADDITIONAL READS:"
  echo ""
  echo "- spec/FEATURES.md - Overview of all features (scan, don't read all)"
  echo "- spec/acceptance/F-####.md - If working on specific feature"
  echo "- .agentic/workflows/definition_of_done.md - Quality gates"
  echo ""
fi

# Check for active pipeline
if [[ -f "STACK.md" ]]; then
  PIPELINE_ENABLED=$(grep "pipeline_enabled:" STACK.md | grep -i "yes" || echo "")
  if [[ -n "$PIPELINE_ENABLED" ]]; then
    echo ""
    echo "📖 PIPELINE MODE ACTIVE:"
    echo ""
    echo "- Check for .agentic/pipeline/F-####-pipeline.md"
    echo "- If exists: Read to determine your role"
    echo "- Load ONLY role-specific context (see sequential_agent_specialization.md)"
    echo ""
  fi
fi

echo "═══════════════════════════════════════════════════════"
echo "PROACTIVE CONTEXT SETTING"
echo "═══════════════════════════════════════════════════════"
echo ""

# Check for planned work (STATUS.md is now used by both profiles)
echo "📋 Checking for planned work..."
if [[ -f "STATUS.md" ]]; then
  NEXT_UP=$(grep "^## Next up" STATUS.md -A5 | tail -4 || echo "")
  if [[ -n "$NEXT_UP" ]]; then
    echo ""
    echo "Next up (from STATUS.md):"
    echo "$NEXT_UP"
    echo ""
    echo "Ask user: 'Should we start with these, or something else?'"
  fi
else
  echo "⚠️  No STATUS.md found - run: bash .agentic/init/scaffold.sh"
fi

# Check for stale work
JOURNAL_PATH=""
if [[ -f ".agentic-journal/JOURNAL.md" ]]; then
  JOURNAL_PATH=".agentic-journal/JOURNAL.md"
elif [[ -f "JOURNAL.md" ]]; then
  JOURNAL_PATH="JOURNAL.md"
fi

if [[ -n "$JOURNAL_PATH" ]]; then
  LAST_WORK=$(tail -20 "$JOURNAL_PATH" | grep "in progress\|working on" -i || echo "")
  if [[ -n "$LAST_WORK" ]]; then
    echo ""
    echo "⚠️  Possible stale work detected in JOURNAL.md"
    echo "   Check if previous work was completed or needs resuming"
    echo ""
  fi
fi

# Check for acceptance validation
if [[ "$FT" == "yes" ]] && [[ -f "spec/FEATURES.md" ]]; then
  SHIPPED_NOT_ACCEPTED=$(grep -A5 "^## F-" spec/FEATURES.md | grep -B5 "Status: shipped" | grep -B5 "Accepted: no" | grep "^## F-" || echo "")
  if [[ -n "$SHIPPED_NOT_ACCEPTED" ]]; then
    echo ""
    echo "✅ Features shipped but not accepted:"
    echo "$SHIPPED_NOT_ACCEPTED"
    echo "   Ask user: 'Should we validate these features?'"
    echo ""
  fi
fi

echo "═══════════════════════════════════════════════════════"
echo "SESSION START CHECKLIST"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "Before doing ANY work, you must:"
echo ""
echo "- [ ] Read all mandatory files listed above"
echo "- [ ] Check for interrupted work (wip.sh check)"
echo "- [ ] Surface blockers to user if any exist"
echo "- [ ] Present planned work options to user"
echo "- [ ] Acknowledge in first response what you've read"
echo ""
echo "Example acknowledgment:"
echo "  'Session started. Read: CONTEXT_PACK, STATUS, JOURNAL (last 3 entries).'"
echo "  'Current focus: [from STATUS]. Blockers: [X] / None.'"
echo "  'Options for this session: [list 2-3 from planned work]'"
echo ""

echo "═══════════════════════════════════════════════════════"
echo "READY TO BEGIN"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "Follow the checklist above before starting work."
echo "If anything is unclear, ask the user for clarification."
echo ""

exit 0

