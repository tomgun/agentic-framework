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

set -euo pipefail

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-.}"
cd "$PROJECT_ROOT"
source "$PROJECT_ROOT/.agentic/lib/paths.sh" 2>/dev/null || true
source "$PROJECT_ROOT/.agentic/lib/tools/fwlog.sh" 2>/dev/null || true
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

echo ""
echo -e "${GREEN}✓ Session ready${NC}"
echo ""

exit 0

