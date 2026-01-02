#!/usr/bin/env bash
set -euo pipefail

if command -v python3 >/dev/null 2>&1; then
  python3 .agentic/tools/consistency.py "$@"
elif command -v python >/dev/null 2>&1; then
  python .agentic/tools/consistency.py "$@"
else
  echo "Python not found. Install Python 3 to use consistency.sh."
  exit 1
fi

