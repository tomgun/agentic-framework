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

# 3. Check for .continue-here.md
if [[ -f ".continue-here.md" ]]; then
  CONTINUE_AGE=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" .continue-here.md 2>/dev/null || stat -c "%y" .continue-here.md 2>/dev/null | cut -d' ' -f1,2)
  echo -e "${GREEN}✓ Session context available${NC} (.continue-here.md from $CONTINUE_AGE)"
  echo "  💡 I'll auto-inject this file when you send your first prompt"
else
  echo -e "${BLUE}ℹ No .continue-here.md found${NC}"
  echo "  Tip: Generate one with: python3 .agentic/tools/continue_here.py"
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
if [[ -x ".agentic/tools/doctor.sh" ]]; then
  # Run doctor in quick mode (skip slow checks)
  if ! bash .agentic/tools/doctor.sh --quick >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠ Project health issues detected${NC}"
    echo "  Run: bash .agentic/tools/doctor.sh"
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

echo ""
echo -e "${GREEN}✓ Session ready${NC}"
echo ""

exit 0

