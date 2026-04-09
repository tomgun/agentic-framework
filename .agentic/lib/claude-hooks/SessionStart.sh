#!/usr/bin/env bash
# SessionStart.sh: Validate environment and load session context
#
# This hook runs automatically when a Claude session starts.
# It performs quick health checks and provides context for the session.
#
# Triggered by: Claude Code SessionStart hook
# Timeout: 5 seconds
#
# Exit codes:
# 0 = Success (optional warning messages OK)
# Non-zero = Hook failed (Claude may show error, but will continue)

# Bootstrap: ensure lib/ is extracted (inline check avoids fork when lib exists)
[[ -d "${CLAUDE_PROJECT_DIR:-.}/.agentic/lib/tools" ]] || bash "${CLAUDE_PROJECT_DIR:-.}/.agentic/bootstrap.sh" 2>/dev/null || true

set -euo pipefail

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-.}"
cd "$PROJECT_ROOT"
source "$PROJECT_ROOT/.agentic/lib/paths.sh" 2>/dev/null || true
source "$PROJECT_ROOT/.agentic/lib/tools/fwlog.sh" 2>/dev/null || true
source "$PROJECT_ROOT/.agentic/lib/tools/btrace.sh" 2>/dev/null || true
# Rotate previous log
[[ -f "${FRAMEWORK_LOG:-}" ]] && mv "$FRAMEWORK_LOG" "${FRAMEWORK_LOG}.prev" 2>/dev/null || true
flog "hook:session-start" "fire" "" "start"

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Agentic AF Session Start${NC}"
echo ""

# 0. Clear session-scoped sentinels from previous session (safety net for crashes)
# Stop.sh clears these normally; this catches cases where Stop.sh didn't run.
rm -f .agentic/session/.plan-approved 2>/dev/null || true
rm -f .agentic/session/.plan-review-skipped 2>/dev/null || true
rm -f .agentic/session/.plan-advisory-shown 2>/dev/null || true
rm -f .agentic/session/.spec-first-checked 2>/dev/null || true
rm -f .agentic/session/.spec-first-skipped 2>/dev/null || true
rm -f .agentic/session/.correction_hint_shown 2>/dev/null || true

# 1. Check if this is an agentic project
if [[ ! -d ".agentic" ]]; then
  echo -e "${YELLOW}⚠ Not an Agentic AF project (no .agentic/ folder)${NC}"
  echo "Run: bash install.sh /path/to/your-project"
  exit 0  # Not an error, just not our framework
fi

# 2. Check framework version
if [[ -f ".agentic/STACK.md" ]]; then
  FRAMEWORK_VERSION=$(grep -E "framework_version:" .agentic/STACK.md | head -1 | awk '{print $2}' || echo "unknown")
  echo -e "📦 Framework version: ${GREEN}${FRAMEWORK_VERSION}${NC}"
fi

# btrace: session start event (resolve version from VERSION file, falling back to STACK.md)
_BT_PROFILE=$(grep -E '^\s*-\s*profile:' "$PROJECT_ROOT/STACK.md" 2>/dev/null | head -1 | sed 's/.*:\s*//' | tr -d '[:space:]' || echo "unknown")
_BT_SID=$(cat "$PROJECT_ROOT/.agentic/session/.current-session-id" 2>/dev/null | tr -d '[:space:]' || echo "unknown")
_BT_VERSION="${FRAMEWORK_VERSION:-unknown}"
[[ "$_BT_VERSION" == "unknown" && -f "$PROJECT_ROOT/.agentic/lib/VERSION" ]] && _BT_VERSION=$(cat "$PROJECT_ROOT/.agentic/lib/VERSION" 2>/dev/null | tr -d '[:space:]') || true
[[ "$_BT_VERSION" == "unknown" && -f "$PROJECT_ROOT/VERSION" ]] && _BT_VERSION=$(cat "$PROJECT_ROOT/VERSION" 2>/dev/null | tr -d '[:space:]') || true
btrace "SessionStart" "enter" "{\"profile\":\"${_BT_PROFILE}\",\"version\":\"${_BT_VERSION}\",\"session_id\":\"${_BT_SID}\",\"btrace_level\":\"${_BTRACE_LEVEL:-off}\"}" 2>/dev/null || true

# 3. Check for STATUS.md (primary session context)
if [[ -f "STATUS.md" ]]; then
  # Extract current focus if present
  CURRENT_FOCUS=$(grep -A 1 "## Current Focus" STATUS.md 2>/dev/null | tail -1 | head -c 60 || echo "")
  if [[ -n "$CURRENT_FOCUS" && "$CURRENT_FOCUS" != "## Current Focus" ]]; then
    echo -e "${GREEN}✓ Session context available${NC}"
    echo "  📍 Focus: $CURRENT_FOCUS"
  else
    echo -e "${BLUE}ℹ STATUS.md exists but no focus set${NC}"
  fi
else
  echo -e "${YELLOW}⚠ No STATUS.md found${NC}"
  echo "  Run: ag init (to initialize project)"
fi

# 4. Check for blockers
if [[ -f "HUMAN_NEEDED.md" ]]; then
  BLOCKER_COUNT=$(grep -c "^## H-" HUMAN_NEEDED.md 2>/dev/null || echo "0")
  if [[ "$BLOCKER_COUNT" -gt 0 ]]; then
    echo -e "${YELLOW}⚠ ${BLOCKER_COUNT} blocker(s) in HUMAN_NEEDED.md${NC}"
    echo "  Review these before continuing development"
  fi
fi

# 5. Quick health check (optional, fast only)
if [[ -x ".agentic/lib/tools/doctor.sh" ]]; then
  # Run doctor in quick mode (skip slow checks)
  if ! bash .agentic/lib/tools/doctor.sh --quick >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠ Project health issues detected${NC}"
    echo "  Run: bash .agentic/lib/tools/doctor.sh"
  fi
fi

# 6. Check git status
if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
  UNCOMMITTED=$(git status --porcelain | wc -l | tr -d ' ')
  if [[ "$UNCOMMITTED" -gt 0 ]]; then
    echo -e "${BLUE}📝 ${UNCOMMITTED} uncommitted change(s)${NC}"
  fi
  
  LAST_COMMIT=$(git log -1 --format="%h %s" 2>/dev/null || echo "none")
  echo -e "🔗 Last commit: ${LAST_COMMIT}"
fi

# 6.5. Orphan plan detection (session-boundary safety net)
# "Pull" mechanism: every new session checks for plans that were never saved
# durably. Even if the ExitPlanMode hook failed, the next session catches it.
if [[ -x ".agentic/lib/tools/plan-scan.sh" ]]; then
    ORPHAN_COUNT=$(bash .agentic/lib/tools/plan-scan.sh --check 2>/dev/null | grep -oE '[0-9]+ unsaved' | grep -oE '[0-9]+' || echo "0")
    if [[ "$ORPHAN_COUNT" -gt 0 ]]; then
        echo -e "${YELLOW}📝 $ORPHAN_COUNT unsaved plan(s) found in ephemeral locations${NC}"
        echo "  FIRST ACTION: run plan-scan to save, then review before implementing"
        echo "  bash .agentic/lib/tools/plan-scan.sh"
    fi
fi

# 7. Multi-session collision prevention (F-0195)
# Register this session and warn if others are active on the same checkout.
# $PPID is stable across hook invocations (wrappers use exec bash).
AGENTIC_LIB="$PROJECT_ROOT/.agentic/lib"
if [[ -f "$AGENTIC_LIB/tools/agents_helpers.py" ]]; then
  python3 "$AGENTIC_LIB/tools/agents_helpers.py" \
    --project-root "$PROJECT_ROOT" cleanup-stale 2>/dev/null || true
  python3 "$AGENTIC_LIB/tools/agents_helpers.py" \
    --project-root "$PROJECT_ROOT" session-register "$PROJECT_ROOT" "claude-code" --pid "$PPID" 2>/dev/null || true
  OTHERS=$(python3 "$AGENTIC_LIB/tools/agents_helpers.py" \
    --project-root "$PROJECT_ROOT" count-others "$PROJECT_ROOT" --pid "$PPID" 2>/dev/null || echo "0")
  if [[ "$OTHERS" -gt 0 ]]; then
    echo -e "${RED}⚠️  COLLISION RISK: $OTHERS other session(s) active on this checkout.${NC}"
    echo "   FORBIDDEN: git stash, git checkout ., git restore ., git reset --hard, git clean -f"
    echo "   SAFE alternatives: commit first, use a worktree (ag worktree), or ask human."
  fi
fi

# 8. Intelligence bootstrap nudge (Change 7: auto-bootstrap)
# If features exist but quality intelligence hasn't been created, suggest bootstrap.
# Intelligence is a CORE VALUE for ALL profiles — not restricted to formal.
if [[ -f ".agentic/spec/FEATURES.md" && ! -f ".agentic/intel/quality-checklist.yaml" ]]; then
  _FEAT_COUNT=$(grep -c "^## F-" ".agentic/spec/FEATURES.md" 2>/dev/null || echo 0)
  _FEAT_COUNT="${_FEAT_COUNT## }"
  if [[ "${_FEAT_COUNT:-0}" -gt 0 ]]; then
    echo -e "${BLUE}🧠 Quality intelligence not yet created (${_FEAT_COUNT} features exist).${NC}"
    echo "   Run: ag intel bootstrap — generates quality checklist + test strategy for your stack"
  fi
fi

# 8b. Orphaned intent detection (Change 14: crash recovery surfacing)
if [[ -f ".agentic/session/intents.json" ]]; then
  _ORPHAN_INTENTS=$(python3 -c "
import json, sys
try:
    data = json.load(open(sys.argv[1]))
    intents = data if isinstance(data, list) else data.get('intents', [])
    orphans = [i for i in intents if i.get('status') == 'active']
    print(len(orphans))
except: print(0)
" ".agentic/session/intents.json" 2>/dev/null || echo 0)
  _ORPHAN_INTENTS="${_ORPHAN_INTENTS## }"
  if [[ "${_ORPHAN_INTENTS:-0}" -gt 0 ]]; then
    echo -e "${YELLOW}⚠️  ${_ORPHAN_INTENTS} orphaned intent(s) detected (previous session crash?)${NC}"
    echo "   Run: ag intent list — to see and adopt/clear them"
    echo "   Run: ag sync — to auto-reconcile"
  fi
fi

# 8c. Kickoff staging detection (Change 13: surfacing)
if [[ -d ".agentic/staging" ]]; then
  echo -e "${BLUE}📋 Pending kickoff staging exists.${NC}"
  echo "   Run: ag kickoff --review — to review generated features"
fi

echo ""
echo -e "${GREEN}✓ Session ready${NC}"
echo ""

exit 0

