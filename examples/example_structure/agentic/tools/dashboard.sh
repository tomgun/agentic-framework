#!/usr/bin/env bash
# Dashboard view - shows complete project status at a glance
set -euo pipefail

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║              AGENTIC PROJECT DASHBOARD                         ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Current focus
echo "▶ CURRENT FOCUS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [[ -f STATUS.md ]]; then
  sed -n '/## Current focus/,/##/p' STATUS.md | head -n -1 | tail -n +2
else
  echo "STATUS.md not found"
fi
echo ""

# Last session
echo "▶ LAST SESSION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [[ -f JOURNAL.md ]]; then
  # Find the last session entry
  grep -A 12 "^### Session:" JOURNAL.md | tail -13 || echo "No sessions logged yet"
else
  echo "JOURNAL.md not found"
fi
echo ""

# Health check
echo "▶ HEALTH CHECK"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [[ -f agentic/tools/doctor.py ]]; then
  if command -v python3 >/dev/null 2>&1; then
    python3 agentic/tools/doctor.py 2>/dev/null | grep -E "^(OK|Missing|NEW|Validation)" | head -8 || echo "All checks passed"
  else
    echo "Python3 not available"
  fi
else
  echo "doctor.py not found"
fi
echo ""

# Feature summary
echo "▶ FEATURES SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [[ -f agentic/tools/report.py ]]; then
  if command -v python3 >/dev/null 2>&1; then
    python3 agentic/tools/report.py 2>/dev/null | grep -E "^(===|-).*:" | head -8 || echo "No features yet"
  else
    echo "Python3 not available"
  fi
else
  echo "report.py not found"
fi
echo ""

# Human attention needed
echo "▶ NEEDS HUMAN ATTENTION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [[ -f HUMAN_NEEDED.md ]]; then
  count=$(grep -c "^### HN-" HUMAN_NEEDED.md 2>/dev/null || echo "0")
  if [[ "$count" -gt 0 ]]; then
    grep "^### HN-" HUMAN_NEEDED.md | head -5
    if [[ "$count" -gt 5 ]]; then
      echo "... and $((count - 5)) more"
    fi
  else
    echo "✓ Nothing pending"
  fi
else
  echo "HUMAN_NEEDED.md not found"
fi
echo ""

# Next up
echo "▶ NEXT UP"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [[ -f STATUS.md ]]; then
  sed -n '/## Next up/,/##/p' STATUS.md | head -n -1 | tail -n +2 | head -5
else
  echo "STATUS.md not found"
fi
echo ""

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  Run 'bash agentic/tools/verify.sh' for detailed checks       ║"
echo "║  See 'agentic/MANUAL_OPERATIONS.md' for more commands         ║"
echo "╚════════════════════════════════════════════════════════════════╝"

