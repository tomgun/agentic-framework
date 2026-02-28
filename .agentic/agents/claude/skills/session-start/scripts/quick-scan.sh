#!/usr/bin/env bash
# quick-scan.sh: Quick project state scan for session start
# Delegates to framework tools — this is a thin wrapper.
set -euo pipefail

echo "=== Session State Scan ==="
echo ""

# WIP check
echo "--- WIP Status ---"
bash .agentic/tools/wip.sh check 2>/dev/null || true

echo ""
echo "--- Current Focus ---"
grep -A2 "^## Current" STATUS.md 2>/dev/null | head -5 || echo "(no STATUS.md)"

echo ""
echo "--- Active Blockers ---"
if grep -q "^_No active items_" HUMAN_NEEDED.md 2>/dev/null; then
    echo "None"
else
    grep "^### HN-" HUMAN_NEEDED.md 2>/dev/null | head -5 || echo "None"
fi

echo ""
echo "--- TODO Items ---"
bash .agentic/tools/todo.sh list 2>/dev/null | head -10 || echo "None"

echo ""
echo "--- Upgrade Pending ---"
if [[ -f ".agentic/.upgrade_pending" ]]; then
    echo "⚠ Upgrade pending — read .agentic/.upgrade_pending"
else
    echo "None"
fi
