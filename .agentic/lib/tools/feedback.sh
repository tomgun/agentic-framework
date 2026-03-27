#!/usr/bin/env bash
# feedback.sh - Structured feedback capture and routing (token-efficient)
#
# Usage:
#   bash .agentic/lib/tools/feedback.sh add "text" [--bug|--feature|--ac F-XXXX AC-XXX]
#   bash .agentic/lib/tools/feedback.sh log [--pending]
#   bash .agentic/lib/tools/feedback.sh route FB-XXXX
#   bash .agentic/lib/tools/feedback.sh classify FB-XXXX bug|feature|ac-adjust
#   bash .agentic/lib/tools/feedback.sh done FB-XXXX ["resolution"]
#
# Classification heuristics (keyword-based, no LLM):
#   bug: broken, crash, error, fails, regression, not working, bug, wrong
#   feature: would be nice, add, new feature, could you, wish, request
#   ac-adjust: contains AC- or references specific criteria
#   unclear: anything else -> routed to TODO.md as unclassified
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../paths.sh"
# FEEDBACK_LOG_FILE provided by paths.sh

# Auto-flush: commit state to main after mutating operations.
_try_flush() {
    if [[ -f "$SCRIPT_DIR/state-commit.sh" ]]; then
        bash "$SCRIPT_DIR/state-commit.sh" --auto-flush 2>/dev/null || true
    fi
}

# Create file if doesn't exist
if [[ ! -f "${FEEDBACK_LOG_FILE}" ]]; then
    template="${AGENTIC_ROOT}/spec/FEEDBACK_LOG.template.md"
    if [[ -f "${template}" ]]; then
        cp "${template}" "${FEEDBACK_LOG_FILE}"
    else
        cat > "${FEEDBACK_LOG_FILE}" <<'HEADER'
# Feedback Log

<!-- format: feedback-v0.1.0 -->

Purpose: structured capture of user feedback after testing working software. Items are classified (bug/feature/ac-adjust/unclear) and routed to the appropriate target (ISSUES.md, TODO.md, or acceptance criteria).

## Pending

<!-- Use: bash .agentic/lib/tools/feedback.sh add "feedback text" -->

_No items_

## Routed

<!-- Classified + routed items move here with target reference -->
HEADER
    fi
fi

# ---------------------------------------------------------------------------
# Classification heuristics
# ---------------------------------------------------------------------------
_classify() {
    local text="$1"
    local lower
    lower=$(echo "$text" | tr '[:upper:]' '[:lower:]')

    # AC-adjust: contains AC- reference
    if echo "$lower" | grep -qE 'ac-[0-9]{3}'; then
        echo "ac-adjust"
        return
    fi

    # Bug keywords (loose trailing match to catch verb forms: crashes, errors, etc.)
    if echo "$lower" | grep -qE '\b(broken|crash|error|fail|regression|not working|bug|wrong)'; then
        echo "bug"
        return
    fi

    # Feature keywords
    if echo "$lower" | grep -qE '(would be nice|add |new feature|could you|wish|request)'; then
        echo "feature"
        return
    fi

    echo "unclear"
}

# ---------------------------------------------------------------------------
# Get next FB-#### ID
# ---------------------------------------------------------------------------
_next_id() {
    local last_id
    last_id=$(grep -o "FB-[0-9]\{4\}" "${FEEDBACK_LOG_FILE}" 2>/dev/null | sort | tail -1 || echo "FB-0000")
    local next_num=$((10#${last_id#FB-} + 1))
    printf "FB-%04d" ${next_num}
}

# ---------------------------------------------------------------------------
# Arguments
# ---------------------------------------------------------------------------
ACTION="${1:-}"

if [[ -z "${ACTION}" ]]; then
    cat <<'USAGE'
Usage: bash feedback.sh <action> <args...>

Actions:
  add <text> [--bug|--feature|--ac F-XXXX AC-XXX]
      Classify and persist feedback to FEEDBACK_LOG.md

  log [--pending]
      Show feedback entries (--pending = unrouted only)

  route <FB-ID>
      Route a pending item to its target (ISSUES.md/TODO.md)

  classify <FB-ID> bug|feature|ac-adjust
      Reclassify a pending item

  done <FB-ID> [resolution]
      Mark a feedback item as resolved

Examples:
  bash feedback.sh add "the login button crashes on Safari"
  bash feedback.sh add "add dark mode" --feature
  bash feedback.sh add "needs retry logic" --ac F-0188 AC-003
  bash feedback.sh log --pending
  bash feedback.sh route FB-0001
  bash feedback.sh done FB-0001 "Fixed in I-0042"
USAGE
    exit 1
fi

TIMESTAMP=$(date +"%Y-%m-%d")

case "${ACTION}" in
    add)
        shift
        TEXT=""
        TYPE_OVERRIDE=""
        FEATURE_REF=""
        AC_REF=""

        # Parse arguments
        while [[ $# -gt 0 ]]; do
            case "$1" in
                --bug)
                    TYPE_OVERRIDE="bug"
                    shift
                    ;;
                --feature)
                    TYPE_OVERRIDE="feature"
                    shift
                    ;;
                --ac)
                    TYPE_OVERRIDE="ac-adjust"
                    shift
                    FEATURE_REF="${1:-}"
                    shift || true
                    AC_REF="${1:-}"
                    shift || true
                    ;;
                *)
                    if [[ -z "${TEXT}" ]]; then
                        TEXT="$1"
                    fi
                    shift
                    ;;
            esac
        done

        if [[ -z "${TEXT}" ]]; then
            echo "Error: Feedback text required"
            echo "Usage: bash feedback.sh add \"text\" [--bug|--feature|--ac F-XXXX AC-XXX]"
            exit 1
        fi

        # Classify
        if [[ -n "${TYPE_OVERRIDE}" ]]; then
            TYPE="${TYPE_OVERRIDE}"
        else
            TYPE=$(_classify "${TEXT}")
        fi

        NEXT_ID=$(_next_id)

        # Remove "_No items_" placeholder if present in Pending section
        if grep -q "^_No items_" "${FEEDBACK_LOG_FILE}"; then
            sed -i.bak '/_No items_/d' "${FEEDBACK_LOG_FILE}"
            rm -f "${FEEDBACK_LOG_FILE}.bak"
        fi

        # Build entry
        ENTRY="### ${NEXT_ID}: ${TEXT}\n- **Added**: ${TIMESTAMP}\n- **Type**: ${TYPE}"
        if [[ -n "${FEATURE_REF}" ]]; then
            ENTRY="${ENTRY}\n- **Feature**: ${FEATURE_REF}"
        fi
        if [[ -n "${AC_REF}" ]]; then
            ENTRY="${ENTRY}\n- **AC**: ${AC_REF}"
        fi

        # Insert before ## Routed using awk
        awk -v entry="${ENTRY}" '
            /^## Routed/ {
                # Split entry on \n and print each line
                n = split(entry, lines, "\\n")
                for (i = 1; i <= n; i++) print lines[i]
                print ""
            }
            { print }
        ' "${FEEDBACK_LOG_FILE}" > "${FEEDBACK_LOG_FILE}.tmp"
        mv "${FEEDBACK_LOG_FILE}.tmp" "${FEEDBACK_LOG_FILE}"

        echo "✓ Added ${NEXT_ID}: ${TEXT}"
        echo "  Type: ${TYPE}"
        if [[ -n "${FEATURE_REF}" ]]; then
            echo "  Feature: ${FEATURE_REF}"
        fi
        if [[ -n "${AC_REF}" ]]; then
            echo "  AC: ${AC_REF}"
        fi
        _try_flush
        ;;

    log)
        FILTER="${2:-}"

        if [[ "${FILTER}" == "--pending" ]]; then
            ITEMS=$(awk '/^## Pending/,/^## Routed/' "${FEEDBACK_LOG_FILE}" | grep "^### FB-" || true)
        else
            ITEMS=$(grep "^### FB-" "${FEEDBACK_LOG_FILE}" || true)
        fi

        if [[ -z "${ITEMS}" ]]; then
            if [[ "${FILTER}" == "--pending" ]]; then
                echo "Feedback log: 0 pending items"
            else
                echo "Feedback log: 0 items"
            fi
        else
            COUNT=$(echo "${ITEMS}" | wc -l | tr -d ' ')
            if [[ "${FILTER}" == "--pending" ]]; then
                echo "Feedback log: ${COUNT} pending item(s)"
            else
                echo "Feedback log: ${COUNT} item(s)"
            fi
            echo ""
            echo "${ITEMS}" | sed 's/^### /  /'
        fi
        ;;

    route)
        FB_ID="${2:-}"

        if [[ -z "${FB_ID}" ]]; then
            echo "Error: FB-ID required"
            echo "Usage: bash feedback.sh route <FB-ID>"
            exit 1
        fi

        if [[ ! "${FB_ID}" =~ ^FB-[0-9]{4}$ ]]; then
            echo "Error: ID must be in format FB-####"
            exit 1
        fi

        # Check if item exists in Pending
        if ! awk '/^## Pending/,/^## Routed/' "${FEEDBACK_LOG_FILE}" | grep -q "^### ${FB_ID}:"; then
            echo "Error: ${FB_ID} not found in Pending"
            exit 1
        fi

        # Extract type and title from the item block
        TYPE=$(awk -v id="### ${FB_ID}:" '
            BEGIN { found=0 }
            $0 ~ "^"id { found=1; next }
            found && /^(###|## )/ { exit }
            found && /\*\*Type\*\*:/ { sub(/.*\*\*Type\*\*: */, ""); print; exit }
        ' "${FEEDBACK_LOG_FILE}")
        TITLE=$(grep "^### ${FB_ID}:" "${FEEDBACK_LOG_FILE}" | head -1 | sed "s/^### ${FB_ID}: //")

        # Route based on type
        ROUTE_TARGET=""
        case "${TYPE}" in
            bug)
                echo "Routing ${FB_ID} as bug → ISSUES.md"
                bash "${SCRIPT_DIR}/quick_issue.sh" "${TITLE}" "medium" 2>/dev/null && true
                ROUTE_TARGET="ISSUES.md"
                ;;
            feature|unclear)
                echo "Routing ${FB_ID} → TODO.md"
                if [[ "${TYPE}" == "unclear" ]]; then
                    bash "${SCRIPT_DIR}/todo.sh" add "${TITLE}" "Unclassified ${FB_ID}" 2>/dev/null && true
                else
                    bash "${SCRIPT_DIR}/todo.sh" add "${TITLE}" "From ${FB_ID}" 2>/dev/null && true
                fi
                ROUTE_TARGET="TODO.md"
                ;;
            ac-adjust)
                echo "Routing ${FB_ID} as AC adjustment (logged in FEEDBACK_LOG.md)"
                ROUTE_TARGET="FEEDBACK_LOG.md (AC adjustment)"
                ;;
            *)
                echo "Routing ${FB_ID} → TODO.md (unknown type)"
                bash "${SCRIPT_DIR}/todo.sh" add "${TITLE}" "Unclassified ${FB_ID}" 2>/dev/null && true
                ROUTE_TARGET="TODO.md"
                ;;
        esac

        # Extract the full item block from Pending
        ITEM_BLOCK=$(awk -v id="### ${FB_ID}:" '
            BEGIN { found=0 }
            $0 ~ "^"id { found=1 }
            found && /^(### |## )/ && !($0 ~ "^"id) { found=0 }
            found { print }
        ' "${FEEDBACK_LOG_FILE}")

        # Remove from Pending section
        awk -v id="### ${FB_ID}:" '
            BEGIN { skip=0 }
            $0 ~ "^"id { skip=1; next }
            skip && /^(###|## )/ { skip=0 }
            skip && /^$/ && !seen_blank { seen_blank=1; next }
            skip { next }
            !skip { print; seen_blank=0 }
        ' "${FEEDBACK_LOG_FILE}" > "${FEEDBACK_LOG_FILE}.tmp"
        mv "${FEEDBACK_LOG_FILE}.tmp" "${FEEDBACK_LOG_FILE}"

        # Append to Routed section with target
        ROUTED_ENTRY="${ITEM_BLOCK}\n- **Routed**: ${TIMESTAMP} → ${ROUTE_TARGET}"
        awk -v entry="${ROUTED_ENTRY}" '
            { print }
            /^## Routed/ {
                getline; print
                n = split(entry, lines, "\\n")
                for (i = 1; i <= n; i++) print lines[i]
                print ""
            }
        ' "${FEEDBACK_LOG_FILE}" > "${FEEDBACK_LOG_FILE}.tmp"
        mv "${FEEDBACK_LOG_FILE}.tmp" "${FEEDBACK_LOG_FILE}"

        echo "✓ Routed ${FB_ID} → ${ROUTE_TARGET}"
        _try_flush
        ;;

    classify)
        FB_ID="${2:-}"
        NEW_TYPE="${3:-}"

        if [[ -z "${FB_ID}" ]] || [[ -z "${NEW_TYPE}" ]]; then
            echo "Error: FB-ID and type required"
            echo "Usage: bash feedback.sh classify <FB-ID> bug|feature|ac-adjust"
            exit 1
        fi

        if [[ ! "${FB_ID}" =~ ^FB-[0-9]{4}$ ]]; then
            echo "Error: ID must be in format FB-####"
            exit 1
        fi

        if [[ "${NEW_TYPE}" != "bug" && "${NEW_TYPE}" != "feature" && "${NEW_TYPE}" != "ac-adjust" ]]; then
            echo "Error: Type must be bug, feature, or ac-adjust"
            exit 1
        fi

        # Check item exists in Pending
        if ! awk '/^## Pending/,/^## Routed/' "${FEEDBACK_LOG_FILE}" | grep -q "^### ${FB_ID}:"; then
            echo "Error: ${FB_ID} not found in Pending"
            exit 1
        fi

        # Update the Type line (awk for macOS portability)
        awk -v id="### ${FB_ID}:" -v new_type="${NEW_TYPE}" '
            $0 ~ "^"id { in_block=1 }
            in_block && /^\- \*\*Type\*\*:/ { print "- **Type**: " new_type; in_block=0; next }
            in_block && /^(###|## )/ && !($0 ~ "^"id) { in_block=0 }
            { print }
        ' "${FEEDBACK_LOG_FILE}" > "${FEEDBACK_LOG_FILE}.tmp"
        mv "${FEEDBACK_LOG_FILE}.tmp" "${FEEDBACK_LOG_FILE}"

        echo "✓ Reclassified ${FB_ID} as ${NEW_TYPE}"
        _try_flush
        ;;

    done)
        FB_ID="${2:-}"
        RESOLUTION="${3:-resolved}"

        if [[ -z "${FB_ID}" ]]; then
            echo "Error: FB-ID required"
            echo "Usage: bash feedback.sh done <FB-ID> [resolution]"
            exit 1
        fi

        if [[ ! "${FB_ID}" =~ ^FB-[0-9]{4}$ ]]; then
            echo "Error: ID must be in format FB-####"
            exit 1
        fi

        # Check item exists (in either Pending or Routed)
        if ! grep -q "^### ${FB_ID}:" "${FEEDBACK_LOG_FILE}"; then
            echo "Error: ${FB_ID} not found"
            exit 1
        fi

        # Add resolved marker after last metadata line in block (awk for portability)
        awk -v id="### ${FB_ID}:" -v ts="${TIMESTAMP}" -v res="${RESOLUTION}" '
            $0 ~ "^"id { in_block=1 }
            in_block && /^$/ { print "- **Resolved**: " ts " — " res; in_block=0 }
            in_block && /^(###|## )/ && !($0 ~ "^"id) { print "- **Resolved**: " ts " — " res; print ""; in_block=0 }
            { print }
            END { if (in_block) print "- **Resolved**: " ts " — " res }
        ' "${FEEDBACK_LOG_FILE}" > "${FEEDBACK_LOG_FILE}.tmp"
        mv "${FEEDBACK_LOG_FILE}.tmp" "${FEEDBACK_LOG_FILE}"

        echo "✓ Resolved ${FB_ID}: ${RESOLUTION}"
        _try_flush
        ;;

    *)
        echo "Error: Unknown action '${ACTION}'"
        echo "Valid actions: add, log, route, classify, done"
        exit 1
        ;;
esac
