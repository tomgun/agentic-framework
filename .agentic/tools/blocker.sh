#!/usr/bin/env bash
# blocker.sh - Manage HUMAN_NEEDED.md items (token-efficient)
#
# Usage:
#   bash .agentic/tools/blocker.sh add "Description" "Type" "Details"
#   bash .agentic/tools/blocker.sh resolve HN-0001 "Resolution details"
#
# Token efficiency: Appends new items, updates specific items (minimal I/O)
#
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BLOCKER_FILE="${PROJECT_ROOT}/HUMAN_NEEDED.md"

# Create file if doesn't exist
if [[ ! -f "${BLOCKER_FILE}" ]]; then
  cat > "${BLOCKER_FILE}" <<'HEADER'
# HUMAN_NEEDED

<!-- format: human-needed-v0.1.0 -->

**Purpose**: Track items requiring human input, decisions, or intervention.

📖 **For examples and guidelines, see:** `.agentic/spec/HUMAN_NEEDED.reference.md`

---

## Active items needing attention

<!-- Agents: Add entries here when you need human help -->

---

## Resolved

<!-- Archive resolved items here with date and outcome -->
HEADER
fi

# Arguments
ACTION="${1:-}"
DESCRIPTION="${2:-}"
TYPE="${3:-}"
DETAILS="${4:-}"

if [[ -z "${ACTION}" ]]; then
  cat <<'USAGE'
Usage: bash blocker.sh <action> <args...>

Actions:
  add <description> <type> <details>
      Add new blocker to HUMAN_NEEDED.md
      Types: dependency | credential | decision | access | external
      
  resolve <HN-ID> <resolution>
      Move blocker to resolved section

Examples:
  # Add blocker
  bash blocker.sh add \
    "Install GUT plugin" \
    "dependency" \
    "GUT testing plugin needs manual install via Godot Asset Library"
  
  # Resolve blocker
  bash blocker.sh resolve HN-0001 "Installed GUT plugin successfully"
USAGE
  exit 1
fi

TIMESTAMP=$(date +"%Y-%m-%d")

case "${ACTION}" in
  add)
    if [[ -z "${DESCRIPTION}" ]] || [[ -z "${TYPE}" ]]; then
      echo "Error: Missing required arguments for 'add'"
      echo "Usage: bash blocker.sh add <description> <type> <details>"
      exit 1
    fi
    
    # Get next HN-#### ID
    LAST_ID=$(grep -o "HN-[0-9]\{4\}" "${BLOCKER_FILE}" | sort | tail -1 || echo "HN-0000")
    NEXT_NUM=$((10#${LAST_ID#HN-} + 1))
    NEXT_ID=$(printf "HN-%04d" ${NEXT_NUM})
    
    # Insert before "## Resolved" section (places in Active section)
    sed -i.bak "/^## Resolved/i\\
\\
### ${NEXT_ID}: ${DESCRIPTION}\\
- **Type**: ${TYPE}\\
- **Added**: ${TIMESTAMP}\\
- **Context**: ${DETAILS}\\
- **Why human needed**: Requires human action/decision\\
- **Impact**: Blocking: [specify what's blocked]\\
\\
" "${BLOCKER_FILE}"
    rm -f "${BLOCKER_FILE}.bak"
    
    echo "✓ Added ${NEXT_ID}: ${DESCRIPTION}"
    echo "Note: Human should review HUMAN_NEEDED.md"
    ;;
    
  resolve)
    if [[ -z "${DESCRIPTION}" ]]; then
      echo "Error: Missing HN-ID or resolution"
      echo "Usage: bash blocker.sh resolve <HN-ID> <resolution>"
      exit 1
    fi
    
    HN_ID="${DESCRIPTION}"
    RESOLUTION="${TYPE}"
    
    # Validate HN-ID format
    if [[ ! "${HN_ID}" =~ ^HN-[0-9]{4}$ ]]; then
      echo "Error: HN-ID must be in format HN-####"
      exit 1
    fi
    
    # Check if blocker exists
    if ! grep -q "^### ${HN_ID}:" "${BLOCKER_FILE}"; then
      echo "Error: ${HN_ID} not found in HUMAN_NEEDED.md"
      exit 1
    fi
    
    # Extract blocker text
    BLOCKER_TEXT=$(sed -n "/^### ${HN_ID}:/,/^$/p" "${BLOCKER_FILE}" | head -n -1)
    BLOCKER_TITLE=$(echo "${BLOCKER_TEXT}" | head -1)
    
    # Remove from Active section
    sed -i.bak "/^### ${HN_ID}:/,/^$/d" "${BLOCKER_FILE}"
    
    # Add to Resolved section
    sed -i.bak "/^## Resolved/a\\
\\
${BLOCKER_TITLE}\\
- **Resolved**: ${TIMESTAMP}\\
- **Resolution**: ${RESOLUTION}\\
" "${BLOCKER_FILE}"
    rm -f "${BLOCKER_FILE}.bak"
    
    echo "✓ Resolved ${HN_ID}"
    echo "Note: Review with 'git diff HUMAN_NEEDED.md'"
    ;;
    
  *)
    echo "Error: Unknown action '${ACTION}'"
    echo "Valid actions: add, resolve"
    exit 1
    ;;
esac

