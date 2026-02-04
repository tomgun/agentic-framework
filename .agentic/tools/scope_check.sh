#!/usr/bin/env bash
# scope_check.sh - Compare declared scope to actual changes
#
# Reads IN_SCOPE from WIP.md, compares to staged files.
# WARNS on unexpected files (does not block).
#
# Usage:
#   bash .agentic/tools/scope_check.sh
#
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${PROJECT_ROOT}"

# State lives at project root, NOT inside .agentic (survives framework upgrades)
WIP_FILE=".agentic-state/WIP.md"

# If no WIP.md, skip check silently
if [[ ! -f "$WIP_FILE" ]]; then
  exit 0
fi

# Extract IN_SCOPE line (comma-separated file patterns)
DECLARED=$(grep "^IN_SCOPE:" "$WIP_FILE" 2>/dev/null | cut -d: -f2- | tr -d ' ' || echo "")

# If no scope declared, skip check
if [[ -z "$DECLARED" ]]; then
  exit 0
fi

# Get staged files
STAGED=$(git diff --cached --name-only 2>/dev/null || echo "")

if [[ -z "$STAGED" ]]; then
  exit 0
fi

# Check each staged file against declared patterns
DRIFT_FILES=""
while IFS= read -r file; do
  MATCHED=false

  # Check against each declared pattern (comma-separated)
  IFS=',' read -ra PATTERNS <<< "$DECLARED"
  for pattern in "${PATTERNS[@]}"; do
    pattern=$(echo "$pattern" | xargs)  # trim whitespace
    # Use glob matching
    if [[ "$file" == $pattern ]] || [[ "$file" == "$pattern"* ]]; then
      MATCHED=true
      break
    fi
  done

  if [[ "$MATCHED" == "false" ]]; then
    DRIFT_FILES="${DRIFT_FILES}${file}\n"
  fi
done <<< "$STAGED"

# Report drift if any
if [[ -n "$DRIFT_FILES" ]]; then
  echo ""
  echo "SCOPE DRIFT: Files changed outside declared scope"
  echo ""
  echo "Declared scope: $DECLARED"
  echo "Unexpected files:"
  echo -e "$DRIFT_FILES" | while read -r f; do
    [[ -n "$f" ]] && echo "  - $f"
  done
  echo ""
  echo "This is a WARNING, not blocking. Review if these changes are intentional."
  echo ""
fi
