#!/usr/bin/env bash
set -euo pipefail

echo "=== Repo brief ==="
echo

if [[ -f CONTEXT_PACK.md ]]; then
  echo "--- CONTEXT_PACK.md (top) ---"
  sed -n '1,80p' CONTEXT_PACK.md
  echo
else
  echo "Missing: CONTEXT_PACK.md"
  echo
fi

if [[ -f STATUS.md ]]; then
  echo "--- STATUS.md (top) ---"
  sed -n '1,120p' STATUS.md
  echo
else
  echo "Missing: STATUS.md"
  echo
fi

if [[ -f STACK.md ]]; then
  echo "--- STACK.md (top) ---"
  sed -n '1,120p' STACK.md
  echo
else
  echo "Missing: STACK.md"
  echo
fi

echo "Next actions:"
echo "- Read the relevant /spec sections"
echo "- Pick one small task and follow .agentic/workflows/dev_loop.md"


