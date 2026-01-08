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
  echo "Error: STATUS.md not found. This project may not use Core+PM mode."
  echo "For Core mode, use PRODUCT.md instead."
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
    sed -i.bak "/^## Current session state/,/^## / {
      /^## Current session state/!{
        /^## /!{
          /^- / c\\
- ${VALUE} (Updated: ${TIMESTAMP})
        }
      }
    }" "${STATUS_FILE}"
    rm -f "${STATUS_FILE}.bak"
    echo "✓ Updated focus in STATUS.md"
    ;;
    
  progress)
    # Look for "Progress:" or "Status:" line and update it
    if grep -q "^- Progress:" "${STATUS_FILE}"; then
      sed -i.bak "s/^- Progress:.*$/- Progress: ${VALUE} (${TIMESTAMP})/" "${STATUS_FILE}"
    elif grep -q "^- Status:" "${STATUS_FILE}"; then
      sed -i.bak "s/^- Status:.*$/- Status: ${VALUE} (${TIMESTAMP})/" "${STATUS_FILE}"
    else
      # Add after Current session state section
      sed -i.bak "/^## Current session state/a\\
- Progress: ${VALUE} (${TIMESTAMP})
" "${STATUS_FILE}"
    fi
    rm -f "${STATUS_FILE}.bak"
    echo "✓ Updated progress in STATUS.md"
    ;;
    
  next)
    # Update "## Next immediate step" section
    sed -i.bak "/^## Next immediate step/,/^## / {
      /^## Next immediate step/!{
        /^## /!{
          /^- / c\\
- ${VALUE}
        }
      }
    }" "${STATUS_FILE}"
    rm -f "${STATUS_FILE}.bak"
    echo "✓ Updated next step in STATUS.md"
    ;;
    
  blocker)
    # Update blockers section
    if [[ "${VALUE}" == "None" ]]; then
      sed -i.bak "/^## Blockers/,/^## / {
        /^## Blockers/!{
          /^## /!{
            /^- / c\\
- None
          }
        }
      }" "${STATUS_FILE}"
    else
      sed -i.bak "/^## Blockers/,/^## / {
        /^## Blockers/!{
          /^## /!{
            /^- / c\\
- ${VALUE} (Added: ${TIMESTAMP})
          }
        }
      }" "${STATUS_FILE}"
    fi
    rm -f "${STATUS_FILE}.bak"
    echo "✓ Updated blocker in STATUS.md"
    ;;
    
  *)
    echo "Error: Unknown field '${FIELD}'"
    echo "Valid fields: focus, progress, next, blocker"
    exit 1
    ;;
esac

echo "Note: Changes applied to STATUS.md. Review with 'git diff STATUS.md'"

