#!/usr/bin/env bash
# framework_age.sh - Check if framework is outdated and suggest updates
#
# Usage:
#   bash .agentic/tools/framework_age.sh
#   bash .agentic/tools/framework_age.sh --quiet  # Exit code only
#
# Exit codes:
#   0 - Framework is current (<30 days)
#   1 - Framework is aging (30-90 days)
#   2 - Framework is old (>90 days)
#
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${PROJECT_ROOT}"

QUIET=false
if [[ "${1:-}" == "--quiet" ]]; then
  QUIET=true
fi

# Get framework version
FRAMEWORK_VERSION=$(cat .agentic/../VERSION 2>/dev/null || echo "unknown")

# Try to get framework date from git
FRAMEWORK_DATE=$(git -C .agentic log -1 --format=%cd --date=short 2>/dev/null || echo "unknown")

if [[ "${FRAMEWORK_DATE}" == "unknown" ]]; then
  if [[ "${QUIET}" == "false" ]]; then
    echo "⚠️  Cannot determine framework age (no git history)"
    echo "   Framework version: ${FRAMEWORK_VERSION}"
  fi
  exit 1
fi

# Calculate age in days
CURRENT_TIMESTAMP=$(date +%s)
FRAMEWORK_TIMESTAMP=$(date -d "${FRAMEWORK_DATE}" +%s 2>/dev/null || date -j -f "%Y-%m-%d" "${FRAMEWORK_DATE}" "+%s" 2>/dev/null || echo "0")

if [[ "${FRAMEWORK_TIMESTAMP}" == "0" ]]; then
  if [[ "${QUIET}" == "false" ]]; then
    echo "⚠️  Cannot parse framework date: ${FRAMEWORK_DATE}"
  fi
  exit 1
fi

DAYS_OLD=$(( (CURRENT_TIMESTAMP - FRAMEWORK_TIMESTAMP) / 86400 ))

# Detect AI environment from STACK.md
AI_ENV="unknown"
if [[ -f "STACK.md" ]]; then
  AI_ENV=$(grep -A1 "## Agentic framework" STACK.md | grep "AI Environment:" | cut -d: -f2 | tr -d ' ' || echo "unknown")
fi

if [[ "${QUIET}" == "true" ]]; then
  # Just exit with code
  if [[ $DAYS_OLD -gt 90 ]]; then
    exit 2
  elif [[ $DAYS_OLD -gt 30 ]]; then
    exit 1
  else
    exit 0
  fi
fi

# Full output
echo "═══════════════════════════════════════════════════════"
echo "Agentic Framework Age Check"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "Framework version: ${FRAMEWORK_VERSION}"
echo "Last updated: ${FRAMEWORK_DATE} (${DAYS_OLD} days ago)"
echo "AI environment: ${AI_ENV}"
echo ""

if [[ $DAYS_OLD -gt 90 ]]; then
  echo "🚨 STATUS: OUTDATED (>3 months old)"
  echo ""
  echo "AI coding tools evolve rapidly. This framework may be missing:"
  echo "- New features in ${AI_ENV}"
  echo "- Improved workflows and optimizations"
  echo "- Bug fixes and quality improvements"
  echo ""
  echo "═══════════════════════════════════════════════════════"
  echo "STRONGLY RECOMMEND: Research Current Best Practices"
  echo "═══════════════════════════════════════════════════════"
  echo ""
  echo "Ask your AI agent to:"
  echo ""
  echo "  \"Research latest capabilities for ${AI_ENV}:"
  echo "   1. Check official documentation"
  echo "   2. Update .agentic/support/environment_research.md"
  echo "   3. Suggest any framework adjustments"
  echo "   4. Document findings in JOURNAL.md\""
  echo ""
  case "${AI_ENV}" in
    claude)
      echo "Claude Code research areas:"
      echo "- Hooks (SessionStart, PostToolUse, PreCompact, Stop)"
      echo "- Context window improvements"
      echo "- New APIs or capabilities"
      echo "- Projects integration"
      echo "Docs: https://docs.anthropic.com/claude/desktop"
      ;;
    cursor)
      echo "Cursor research areas:"
      echo "- Agentic mode updates"
      echo "- Composer improvements"
      echo "- @ mention capabilities"
      echo "- Rules format changes"
      echo "Docs: https://cursor.sh/docs"
      ;;
    copilot)
      echo "Copilot research areas:"
      echo "- Context window changes"
      echo "- Workspace features"
      echo "- New instruction capabilities"
      echo "- GitHub integration updates"
      echo "Docs: https://docs.github.com/copilot"
      ;;
    multi|unknown)
      echo "Research all environments you use:"
      echo "- Claude Code: https://docs.anthropic.com/claude/desktop"
      echo "- Cursor: https://cursor.sh/docs"
      echo "- Copilot: https://docs.github.com/copilot"
      ;;
  esac
  echo ""
  exit 2
  
elif [[ $DAYS_OLD -gt 30 ]]; then
  echo "⚠️  STATUS: AGING (>1 month old)"
  echo ""
  echo "Framework is still usable, but may be missing recent improvements."
  echo ""
  echo "═══════════════════════════════════════════════════════"
  echo "OPTIONAL: Check for Updates"
  echo "═══════════════════════════════════════════════════════"
  echo ""
  echo "Consider researching:"
  echo "- Latest ${AI_ENV} features"
  echo "- New workflow optimizations"
  echo "- Bug fixes or improvements"
  echo ""
  echo "To update: Ask agent to review latest ${AI_ENV} docs and"
  echo "           update .agentic/support/environment_research.md"
  echo ""
  exit 1
  
else
  echo "✅ STATUS: CURRENT (<1 month old)"
  echo ""
  echo "Framework is up to date. No action needed."
  echo ""
  exit 0
fi

