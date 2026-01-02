#!/usr/bin/env bash
set -euo pipefail

if command -v python3 >/dev/null 2>&1; then
  python3 .agentic/tools/sync_docs.py
  exit 0
fi

if command -v python >/dev/null 2>&1; then
  python .agentic/tools/sync_docs.py
  exit 0
fi

echo "Python not found. Install Python 3 to use docs sync tooling."
exit 1


