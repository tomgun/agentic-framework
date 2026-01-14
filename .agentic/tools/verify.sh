#!/usr/bin/env bash
set -euo pipefail

echo "⚠️  DEPRECATED: Use 'doctor.sh --full' instead"
echo "   This tool will be removed in v0.12.0"
echo ""

echo "=== agentic verify (comprehensive) ==="
echo ""

# Run doctor checks
echo "Step 1: Running doctor..."
if command -v python3 >/dev/null 2>&1; then
  python3 .agentic/tools/doctor.py
elif command -v python >/dev/null 2>&1; then
  python .agentic/tools/doctor.py
else
  echo "Python not found. Install Python 3 to use doctor checks."
  exit 1
fi

echo ""
echo "---"
echo ""

# Run verification checks
echo "Step 2: Running verification..."
if command -v python3 >/dev/null 2>&1; then
  python3 .agentic/tools/verify.py
elif command -v python >/dev/null 2>&1; then
  python .agentic/tools/verify.py
else
  echo "Python not found."
  exit 1
fi

echo ""
echo "---"
echo ""

# Optional: run tests if STACK.md specifies a test command
echo "Step 3: Checking for test command in STACK.md..."
if [ -f "STACK.md" ]; then
  # Try to extract test command (simple grep approach)
  TEST_CMD=$(grep -i -E "^[\s-]*test.*:|test command:" STACK.md | head -1 | sed 's/^[^:]*://; s/^[[:space:]]*//; s/`//g' || echo "")
  
  if [ -n "$TEST_CMD" ]; then
    echo "Found test command: $TEST_CMD"
    echo ""
    read -p "Run tests? (y/N) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      echo "Running: $TEST_CMD"
      eval "$TEST_CMD"
    else
      echo "Skipping tests."
    fi
  else
    echo "No test command found in STACK.md. Add one to enable automated testing."
  fi
else
  echo "STACK.md not found. Skipping test execution check."
fi

echo ""
echo "=== verify complete ==="

