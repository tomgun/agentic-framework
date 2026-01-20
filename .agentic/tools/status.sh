#!/usr/bin/env bash
# status.sh - Update specific sections of STATUS.md (token-efficient)
#
# Usage:
#   bash .agentic/tools/status.sh focus "Working on F-0003"
#   bash .agentic/tools/status.sh progress "60% complete"
#   bash .agentic/tools/status.sh next "Deploy to staging"
#   bash .agentic/tools/status.sh blocker "Waiting for API key"
#   bash .agentic/tools/status.sh blocker "None"  # Clear blocker
#
# Token efficiency: Updates single field, minimal file I/O
#
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STATUS_FILE="${PROJECT_ROOT}/STATUS.md"

# Check if STATUS.md exists
if [[ ! -f "${STATUS_FILE}" ]]; then
  echo "Error: STATUS.md not found."
  echo "Run: bash .agentic/init/scaffold.sh"
  exit 1
fi

# Arguments
FIELD="${1:-}"
VALUE="${2:-}"

if [[ -z "${FIELD}" ]] || [[ -z "${VALUE}" ]]; then
  cat <<'USAGE'
Usage: bash status.sh <field> <value>

Fields:
  focus     - Current focus/task
  progress  - Progress description
  next      - Next immediate step
  blocker   - Current blocker (use "None" to clear)

Examples:
  bash status.sh focus "Implementing F-0003: User login"
  bash status.sh progress "70% - 3 of 5 criteria complete"
  bash status.sh next "Add email verification"
  bash status.sh blocker "Waiting for design mockups"
  bash status.sh blocker "None"
USAGE
  exit 1
fi

# Update timestamp
TIMESTAMP=$(date +"%Y-%m-%d %H:%M")

# Update the appropriate section
case "${FIELD}" in
  focus)
    # Update "## Current session state" section
    # Use awk for macOS compatibility (BSD sed doesn't handle c\ well)
    awk -v value="${VALUE}" -v ts="${TIMESTAMP}" '
      /^## Current session state/ { in_section=1; print; next }
      /^## / && in_section { in_section=0; printed=1; print "- " value " (Updated: " ts ")"; print ""; print }
      in_section && /^- / { if (!printed) { print "- " value " (Updated: " ts ")"; printed=1 }; next }
      in_section && /^$/ && printed { next }
      { print }
      END { if (in_section && !printed) print "- " value " (Updated: " ts ")" }
    ' "${STATUS_FILE}" > "${STATUS_FILE}.tmp" && mv "${STATUS_FILE}.tmp" "${STATUS_FILE}"
    echo "✓ Updated focus in STATUS.md"
    ;;
    
  progress)
    # Look for "Progress:" or "Status:" line and update it
    # Use awk for macOS compatibility
    if grep -q "^- Progress:" "${STATUS_FILE}"; then
      awk -v value="${VALUE}" -v ts="${TIMESTAMP}" '
        /^- Progress:/ { print "- Progress: " value " (" ts ")"; next }
        { print }
      ' "${STATUS_FILE}" > "${STATUS_FILE}.tmp" && mv "${STATUS_FILE}.tmp" "${STATUS_FILE}"
    elif grep -q "^- Status:" "${STATUS_FILE}"; then
      awk -v value="${VALUE}" -v ts="${TIMESTAMP}" '
        /^- Status:/ { print "- Status: " value " (" ts ")"; next }
        { print }
      ' "${STATUS_FILE}" > "${STATUS_FILE}.tmp" && mv "${STATUS_FILE}.tmp" "${STATUS_FILE}"
    else
      # Add after Current session state header
      awk -v value="${VALUE}" -v ts="${TIMESTAMP}" '
        { print }
        /^## Current session state/ { print "- Progress: " value " (" ts ")" }
      ' "${STATUS_FILE}" > "${STATUS_FILE}.tmp" && mv "${STATUS_FILE}.tmp" "${STATUS_FILE}"
    fi
    echo "✓ Updated progress in STATUS.md"
    ;;
    
  next)
    # Update "## Next immediate step" section
    # Use awk for macOS compatibility (BSD sed doesn't handle c\ well)
    awk -v value="${VALUE}" '
      /^## Next immediate step/ { in_section=1; print; next }
      /^## / && in_section { in_section=0; printed=1; print "- " value; print ""; print }
      in_section && /^- / { if (!printed) { print "- " value; printed=1 }; next }
      in_section && /^$/ && printed { next }
      { print }
      END { if (in_section && !printed) print "- " value }
    ' "${STATUS_FILE}" > "${STATUS_FILE}.tmp" && mv "${STATUS_FILE}.tmp" "${STATUS_FILE}"
    echo "✓ Updated next step in STATUS.md"
    ;;
    
  blocker)
    # Update blockers section
    # Use awk for macOS compatibility (BSD sed doesn't handle c\ well)
    if [[ "${VALUE}" == "None" ]]; then
      awk '
        /^## Blockers/ { in_section=1; print; next }
        /^## / && in_section { in_section=0; printed=1; print "- None"; print ""; print }
        in_section && /^- / { if (!printed) { print "- None"; printed=1 }; next }
        in_section && /^$/ && printed { next }
        { print }
        END { if (in_section && !printed) print "- None" }
      ' "${STATUS_FILE}" > "${STATUS_FILE}.tmp" && mv "${STATUS_FILE}.tmp" "${STATUS_FILE}"
    else
      awk -v value="${VALUE}" -v ts="${TIMESTAMP}" '
        /^## Blockers/ { in_section=1; print; next }
        /^## / && in_section { in_section=0; printed=1; print "- " value " (Added: " ts ")"; print ""; print }
        in_section && /^- / { if (!printed) { print "- " value " (Added: " ts ")"; printed=1 }; next }
        in_section && /^$/ && printed { next }
        { print }
        END { if (in_section && !printed) print "- " value " (Added: " ts ")" }
      ' "${STATUS_FILE}" > "${STATUS_FILE}.tmp" && mv "${STATUS_FILE}.tmp" "${STATUS_FILE}"
    fi
    echo "✓ Updated blocker in STATUS.md"
    ;;
    
  *)
    echo "Error: Unknown field '${FIELD}'"
    echo "Valid fields: focus, progress, next, blocker"
    exit 1
    ;;
esac

echo "Note: Changes applied to STATUS.md. Review with 'git diff STATUS.md'"

