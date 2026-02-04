#!/usr/bin/env bash
# journal.sh - Append formatted entries to JOURNAL.md (token-efficient)
#
# Usage:
#   bash .agentic/tools/journal.sh "Topic" "Accomplished" "Next steps" "Blockers"
#   bash .agentic/tools/journal.sh "Topic" "Accomplished" "Next steps" "Blockers" \
#       --feature F-0116 --files 12 --commits abc123
#
# Token efficiency: APPENDS to file, never reads whole file
#
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
JOURNAL_FILE="${PROJECT_ROOT}/JOURNAL.md"

# Required positional arguments
TOPIC="${1:-Untitled}"
ACCOMPLISHED="${2:-No details provided}"
NEXT_STEPS="${3:-TBD}"
BLOCKERS="${4:-None}"
shift 4 2>/dev/null || true

# Optional metadata via flags
FEATURE=""
FILES_COUNT=""
COMMITS=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --feature) FEATURE="$2"; shift 2 ;;
        --files) FILES_COUNT="$2"; shift 2 ;;
        --commits) COMMITS="$2"; shift 2 ;;
        *) shift ;;  # Ignore unknown flags
    esac
done

# Generate timestamp
TIMESTAMP=$(date +"%Y-%m-%d %H:%M")

# Create journal if doesn't exist
if [[ ! -f "${JOURNAL_FILE}" ]]; then
  cat > "${JOURNAL_FILE}" <<'HEADER'
# JOURNAL

**Purpose**: Session-by-session log for tracking progress and maintaining context.

📖 **For format details, see:** `.agentic/spec/JOURNAL.reference.md`

---

## Session Log (most recent first)

HEADER
fi

# Append entry (never read existing content!)
{
  echo ""
  echo "### Session: ${TIMESTAMP} - ${TOPIC}"
  echo ""
  echo "**Accomplished**:"
  echo "${ACCOMPLISHED}" | sed 's/^/- /'
  echo ""
  echo "**Next steps**:"
  echo "${NEXT_STEPS}" | sed 's/^/- /'
  echo ""
  echo "**Blockers**: ${BLOCKERS}"

  # Add structured metadata if provided (for documentation patching)
  if [[ -n "$FEATURE" || -n "$FILES_COUNT" || -n "$COMMITS" ]]; then
      echo ""
      echo "**Metadata**:"
      [[ -n "$FEATURE" ]] && echo "- Feature: $FEATURE"
      [[ -n "$FILES_COUNT" ]] && echo "- Files changed: $FILES_COUNT"
      [[ -n "$COMMITS" ]] && echo "- Commits: $COMMITS"
  fi
  echo ""
} >> "${JOURNAL_FILE}"

echo "✓ Added entry to JOURNAL.md (appended, no full file read)"

