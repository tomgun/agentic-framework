#!/usr/bin/env bash
# journal.sh - Append formatted entries to JOURNAL.md (token-efficient)
#
# Usage:
#   bash .agentic/tools/journal.sh "Topic" "Accomplished" "Next steps" "Blockers"
#
# Token efficiency: APPENDS to file, never reads whole file
#
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
JOURNAL_FILE="${PROJECT_ROOT}/JOURNAL.md"

# Arguments
TOPIC="${1:-Untitled}"
ACCOMPLISHED="${2:-No details provided}"
NEXT_STEPS="${3:-TBD}"
BLOCKERS="${4:-None}"

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
  echo ""
} >> "${JOURNAL_FILE}"

echo "✓ Added entry to JOURNAL.md (appended, no full file read)"

