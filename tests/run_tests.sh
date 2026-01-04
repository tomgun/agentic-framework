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

echo "========================================"
echo "✅ All tests passed!"
echo "========================================"
echo ""
echo "Core claims validated:"
echo "  ✓ Query features: fast filtering works"
echo "  ✓ Validate specs: circular deps detected"
echo "  ✓ Validate specs: invalid refs caught"

