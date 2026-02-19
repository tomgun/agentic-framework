#!/usr/bin/env bash
# todo.sh - Manage TODO.md inbox items (token-efficient)
#
# Usage:
#   bash .agentic/tools/todo.sh add "Description" ["Context"]
#   bash .agentic/tools/todo.sh done T-0001 ["Resolution"]
#   bash .agentic/tools/todo.sh drop T-0001 ["Reason"]
#   bash .agentic/tools/todo.sh triage T-0001 feature|issue ["Notes"]
#   bash .agentic/tools/todo.sh list
#
# Token efficiency: Appends new items, moves specific items (minimal I/O)
#
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TODO_FILE="${PROJECT_ROOT}/TODO.md"

# Create file if doesn't exist
if [[ ! -f "${TODO_FILE}" ]]; then
  template="${PROJECT_ROOT}/.agentic/spec/TODO.template.md"
  if [[ -f "${template}" ]]; then
    cp "${template}" "${TODO_FILE}"
  else
    cat > "${TODO_FILE}" <<'HEADER'
# TODO

<!-- format: todo-v0.1.0 -->

Purpose: quick-capture inbox for ideas, tasks, and reminders. Triage to FEATURES.md or ISSUES.md when ready, or resolve directly.

## Inbox

<!-- Use: bash .agentic/tools/todo.sh add "description" -->

_No items_

## Done

<!-- Resolved/triaged items move here with outcome -->
HEADER
  fi
fi

# Arguments
ACTION="${1:-}"

if [[ -z "${ACTION}" ]]; then
  cat <<'USAGE'
Usage: bash todo.sh <action> <args...>

Actions:
  add <description> [context]
      Add new item to TODO.md inbox

  done <T-ID> [resolution]
      Mark item as resolved, move to Done section

  drop <T-ID> [reason]
      Drop item with reason, move to Done section

  triage <T-ID> feature|issue [notes]
      Record item as promoted to FEATURES.md or ISSUES.md
      (Agent creates the feature/issue entry separately)

  list
      Show inbox items (count + titles)

Examples:
  # Add item
  bash todo.sh add "Try context7 MCP integration" "Discussed in session"

  # Resolve item
  bash todo.sh done T-0001 "Shipped in v0.26.0"

  # Drop item
  bash todo.sh drop T-0002 "No longer relevant"

  # Triage to feature
  bash todo.sh triage T-0003 feature "Promoted to F-0140"
USAGE
  exit 1
fi

TIMESTAMP=$(date +"%Y-%m-%d")

case "${ACTION}" in
  add)
    DESCRIPTION="${2:-}"
    CONTEXT="${3:-}"

    if [[ -z "${DESCRIPTION}" ]]; then
      echo "Error: Description required"
      echo "Usage: bash todo.sh add \"Description\" [\"Context\"]"
      exit 1
    fi

    # Get next T-#### ID
    LAST_ID=$(grep -o "T-[0-9]\{4\}" "${TODO_FILE}" 2>/dev/null | sort | tail -1 || echo "T-0000")
    NEXT_NUM=$((10#${LAST_ID#T-} + 1))
    NEXT_ID=$(printf "T-%04d" ${NEXT_NUM})

    # Remove "_No items_" placeholder if present
    if grep -q "^_No items_" "${TODO_FILE}"; then
      sed -i.bak '/_No items_/d' "${TODO_FILE}"
      rm -f "${TODO_FILE}.bak"
    fi

    # Single-write: insert before ## Done using awk (portable across macOS/Linux)
    awk -v id="${NEXT_ID}" -v desc="${DESCRIPTION}" -v ts="${TIMESTAMP}" -v ctx="${CONTEXT}" '
      /^## Done/ {
        print "### " id ": " desc
        print "- **Added**: " ts
        if (ctx != "") print "- **Context**: " ctx
        print ""
      }
      { print }
    ' "${TODO_FILE}" > "${TODO_FILE}.tmp"
    mv "${TODO_FILE}.tmp" "${TODO_FILE}"

    echo "✓ Added ${NEXT_ID}: ${DESCRIPTION}"
    ;;

  done)
    TODO_ID="${2:-}"
    RESOLUTION="${3:-resolved}"

    if [[ -z "${TODO_ID}" ]]; then
      echo "Error: T-ID required"
      echo "Usage: bash todo.sh done <T-ID> [resolution]"
      exit 1
    fi

    # Validate T-ID format
    if [[ ! "${TODO_ID}" =~ ^T-[0-9]{4}$ ]]; then
      echo "Error: ID must be in format T-####"
      exit 1
    fi

    # Check if item exists in Inbox (between ## Inbox and ## Done)
    if ! awk '/^## Inbox/,/^## Done/' "${TODO_FILE}" | grep -q "^### ${TODO_ID}:"; then
      echo "Error: ${TODO_ID} not found in Inbox"
      exit 1
    fi

    # Extract item block (from ### T-#### to next ### or ## Done)
    ITEM_TITLE=$(awk '/^## Inbox/,/^## Done/' "${TODO_FILE}" | grep "^### ${TODO_ID}:" | head -1)

    # Remove item from Inbox section
    # Use awk to delete the block: from ### T-#### line to next ### or ## line
    awk -v id="### ${TODO_ID}:" '
      BEGIN { skip=0 }
      $0 ~ "^"id { skip=1; next }
      skip && /^(###|## )/ { skip=0 }
      skip && /^$/ && !seen_blank { seen_blank=1; next }
      skip { next }
      !skip { print; seen_blank=0 }
    ' "${TODO_FILE}" > "${TODO_FILE}.tmp"
    mv "${TODO_FILE}.tmp" "${TODO_FILE}"

    # Append to Done section (awk for macOS portability)
    awk -v title="${ITEM_TITLE}" -v ts="${TIMESTAMP}" -v res="${RESOLUTION}" '
      /^## Done/ { print; getline; print; print ""; print title; print "- **Resolved**: " ts " — " res; next }
      { print }
    ' "${TODO_FILE}" > "${TODO_FILE}.tmp"
    mv "${TODO_FILE}.tmp" "${TODO_FILE}"

    echo "✓ Resolved ${TODO_ID}: ${RESOLUTION}"
    ;;

  drop)
    TODO_ID="${2:-}"
    REASON="${3:-dropped}"

    if [[ -z "${TODO_ID}" ]]; then
      echo "Error: T-ID required"
      echo "Usage: bash todo.sh drop <T-ID> [reason]"
      exit 1
    fi

    if [[ ! "${TODO_ID}" =~ ^T-[0-9]{4}$ ]]; then
      echo "Error: ID must be in format T-####"
      exit 1
    fi

    if ! awk '/^## Inbox/,/^## Done/' "${TODO_FILE}" | grep -q "^### ${TODO_ID}:"; then
      echo "Error: ${TODO_ID} not found in Inbox"
      exit 1
    fi

    ITEM_TITLE=$(awk '/^## Inbox/,/^## Done/' "${TODO_FILE}" | grep "^### ${TODO_ID}:" | head -1)

    # Remove from Inbox
    awk -v id="### ${TODO_ID}:" '
      BEGIN { skip=0 }
      $0 ~ "^"id { skip=1; next }
      skip && /^(###|## )/ { skip=0 }
      skip && /^$/ && !seen_blank { seen_blank=1; next }
      skip { next }
      !skip { print; seen_blank=0 }
    ' "${TODO_FILE}" > "${TODO_FILE}.tmp"
    mv "${TODO_FILE}.tmp" "${TODO_FILE}"

    # Append to Done (awk for macOS portability)
    awk -v title="${ITEM_TITLE}" -v ts="${TIMESTAMP}" -v reason="${REASON}" '
      /^## Done/ { print; getline; print; print ""; print title; print "- **Dropped**: " ts " — " reason; next }
      { print }
    ' "${TODO_FILE}" > "${TODO_FILE}.tmp"
    mv "${TODO_FILE}.tmp" "${TODO_FILE}"

    echo "✓ Dropped ${TODO_ID}: ${REASON}"
    ;;

  triage)
    TODO_ID="${2:-}"
    TARGET="${3:-}"
    NOTES="${4:-}"

    if [[ -z "${TODO_ID}" ]] || [[ -z "${TARGET}" ]]; then
      echo "Error: T-ID and target required"
      echo "Usage: bash todo.sh triage <T-ID> feature|issue [notes]"
      exit 1
    fi

    if [[ ! "${TODO_ID}" =~ ^T-[0-9]{4}$ ]]; then
      echo "Error: ID must be in format T-####"
      exit 1
    fi

    if [[ "${TARGET}" != "feature" && "${TARGET}" != "issue" ]]; then
      echo "Error: Target must be 'feature' or 'issue'"
      exit 1
    fi

    if ! awk '/^## Inbox/,/^## Done/' "${TODO_FILE}" | grep -q "^### ${TODO_ID}:"; then
      echo "Error: ${TODO_ID} not found in Inbox"
      exit 1
    fi

    ITEM_TITLE=$(awk '/^## Inbox/,/^## Done/' "${TODO_FILE}" | grep "^### ${TODO_ID}:" | head -1)

    # Remove from Inbox
    awk -v id="### ${TODO_ID}:" '
      BEGIN { skip=0 }
      $0 ~ "^"id { skip=1; next }
      skip && /^(###|## )/ { skip=0 }
      skip && /^$/ && !seen_blank { seen_blank=1; next }
      skip { next }
      !skip { print; seen_blank=0 }
    ' "${TODO_FILE}" > "${TODO_FILE}.tmp"
    mv "${TODO_FILE}.tmp" "${TODO_FILE}"

    # Build resolution note
    if [[ "${TARGET}" == "feature" ]]; then
      RESOLUTION="Promoted to FEATURES.md"
    else
      RESOLUTION="Promoted to ISSUES.md"
    fi
    if [[ -n "${NOTES}" ]]; then
      RESOLUTION="${RESOLUTION} — ${NOTES}"
    fi

    # Append to Done (awk for macOS portability)
    awk -v title="${ITEM_TITLE}" -v ts="${TIMESTAMP}" -v res="${RESOLUTION}" '
      /^## Done/ { print; getline; print; print ""; print title; print "- **Triaged**: " ts " — " res; next }
      { print }
    ' "${TODO_FILE}" > "${TODO_FILE}.tmp"
    mv "${TODO_FILE}.tmp" "${TODO_FILE}"

    echo "✓ Triaged ${TODO_ID} → ${TARGET}: ${NOTES:-promoted}"
    echo "Note: Create the ${TARGET} entry separately (e.g., feature.sh or quick_issue.sh)"
    ;;

  list)
    # Section-aware: count only items between ## Inbox and ## Done
    ITEMS=$(awk '/^## Inbox/,/^## Done/' "${TODO_FILE}" | grep "^### T-" || true)

    if [[ -z "${ITEMS}" ]]; then
      echo "TODO inbox: 0 items"
    else
      COUNT=$(echo "${ITEMS}" | wc -l | tr -d ' ')
      echo "TODO inbox: ${COUNT} item(s)"
      echo ""
      echo "${ITEMS}" | sed 's/^### /  /'
    fi
    ;;

  *)
    echo "Error: Unknown action '${ACTION}'"
    echo "Valid actions: add, done, drop, triage, list"
    exit 1
    ;;
esac
