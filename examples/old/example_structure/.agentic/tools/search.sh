#!/usr/bin/env bash
# Search tool - find features, specs, decisions, code by keyword
set -euo pipefail

if [[ $# -eq 0 ]]; then
  cat <<'EOF'
Usage: bash .agentic/tools/search.sh <keyword>

Searches across all project documentation for a keyword:
  - Features (FEATURES.md)
  - Acceptance criteria (spec/acceptance/)
  - ADRs (spec/adr/)
  - Status and Journal
  - Lessons learned
  - Code annotations (@feature)

Example:
  bash .agentic/tools/search.sh authentication
  bash .agentic/tools/search.sh "user profile"
EOF
  exit 1
fi

KEYWORD="$1"

echo "=== Searching for: $KEYWORD ==="
echo ""

# Search features
echo "▶ Features (FEATURES.md)"
if [[ -f spec/FEATURES.md ]]; then
  grep -i -n "$KEYWORD" spec/FEATURES.md | head -5 || echo "  (none found)"
else
  echo "  (FEATURES.md not found)"
fi
echo ""

# Search acceptance criteria
echo "▶ Acceptance Criteria (spec/acceptance/)"
if [[ -d spec/acceptance ]]; then
  grep -i -r -n "$KEYWORD" spec/acceptance/ 2>/dev/null | head -5 || echo "  (none found)"
else
  echo "  (spec/acceptance/ not found)"
fi
echo ""

# Search ADRs
echo "▶ Architecture Decisions (spec/adr/)"
if [[ -d spec/adr ]]; then
  grep -i -r -n "$KEYWORD" spec/adr/ 2>/dev/null | head -5 || echo "  (none found)"
else
  echo "  (spec/adr/ not found)"
fi
echo ""

# Search STATUS and JOURNAL
echo "▶ Status & Journal"
if [[ -f STATUS.md ]]; then
  grep -i -n "$KEYWORD" STATUS.md | head -3 || echo "  (none in STATUS.md)"
fi
if [[ -f JOURNAL.md ]]; then
  grep -i -n "$KEYWORD" JOURNAL.md | head -3 || echo "  (none in JOURNAL.md)"
fi
echo ""

# Search lessons
echo "▶ Lessons Learned (spec/LESSONS.md)"
if [[ -f spec/LESSONS.md ]]; then
  grep -i -n "$KEYWORD" spec/LESSONS.md | head -5 || echo "  (none found)"
else
  echo "  (LESSONS.md not found)"
fi
echo ""

# Search code annotations
echo "▶ Code Annotations (@feature)"
# Common source directories
SEARCH_DIRS=(src lib app components services)
for dir in "${SEARCH_DIRS[@]}"; do
  if [[ -d "$dir" ]]; then
    grep -i -r -n "@feature.*$KEYWORD" "$dir" 2>/dev/null | head -3 && break
  fi
done || echo "  (none found in src directories)"

echo ""
echo "Tip: Use 'grep -i -r \"$KEYWORD\" .' for full codebase search"

