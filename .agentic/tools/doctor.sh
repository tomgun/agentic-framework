#!/usr/bin/env bash
set -euo pipefail

# Get the directory where this script lives
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Determine Python command
if command -v python3 >/dev/null 2>&1; then
  PYTHON=python3
elif command -v python >/dev/null 2>&1; then
  PYTHON=python
else
  echo "Python not found. Install Python 3 to use .agentic/tools/doctor.sh."
  exit 1
fi

# Pass all arguments to doctor.py
$PYTHON "$SCRIPT_DIR/doctor.py" "$@"
