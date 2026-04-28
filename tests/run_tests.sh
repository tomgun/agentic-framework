#!/bin/bash
# Simple test runner for framework tools
# Validates core claims without overengineering

set -e

echo "========================================"
echo "Agentic Framework Test Suite"
echo "========================================"
echo ""

# Change to repo root
cd "$(dirname "$0")/.."

# Run tests
echo "Running query_features tests..."
python3 tests/test_query_features.py
echo ""

echo "Running validate_specs tests..."
python3 tests/test_validate_specs.py
echo ""

# R-016 Phase 0 verification battery — opt-in (does not run by default to keep
# CI fast; takes ~15-20 min for the full 36-cell matrix). Set RUN_BYPASS=1 to
# include. Spec: .agentic/journal/plans/2026-04-27-R-016-revised-ac-plan.md.
if [[ "${RUN_BYPASS:-0}" == "1" ]]; then
    echo "Running R-016 bypass battery (12 × 3 = 36 cells)..."
    bash tests/bypass/run_battery.sh
    echo ""
fi

echo "========================================"
echo "✅ All tests passed!"
echo "========================================"
echo ""
echo "Core claims validated:"
echo "  ✓ Query features: fast filtering works"
echo "  ✓ Validate specs: circular deps detected"
echo "  ✓ Validate specs: invalid refs caught"

