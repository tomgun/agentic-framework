#!/usr/bin/env bash
# nfr-capture.sh — Capture an informal invariant as a structured NFR
#
# Usage:
#   bash nfr-capture.sh "API responses must always include a request-id header"
#   bash nfr-capture.sh "statement" --category security --applies-to "all endpoints"
#
# Assigns next NFR-XXXX ID, writes to NFR.md, optionally checks propagation.
# Multi-agent safe: checks for other active agents before writing.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../paths.sh"
cd "$PROJECT_ROOT"

if [ -t 1 ]; then
    BOLD='\033[1m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
else
    BOLD='' GREEN='' YELLOW='' NC=''
fi

NFR_FILE=".agentic/spec/NFR.md"
TODO_FILE=".agentic/TODO.md"

# --- Parse args ---
STATEMENT="${1:-}"
shift 2>/dev/null || true

CATEGORY="<!-- set category -->"
APPLIES_TO="<!-- set scope -->"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --category) CATEGORY="$2"; shift 2 ;;
        --applies-to) APPLIES_TO="$2"; shift 2 ;;
        *) shift ;;
    esac
done

if [[ -z "$STATEMENT" ]]; then
    echo "Usage: nfr-capture.sh \"invariant statement\" [--category X] [--applies-to Y]"
    exit 1
fi

# --- Multi-agent safety check ---
if command -v python3 >/dev/null 2>&1 && [[ -f "$SCRIPT_DIR/agents_helpers.py" ]]; then
    others=$(python3 "$SCRIPT_DIR/agents_helpers.py" --project-root "$PROJECT_ROOT" count-others "$(pwd)" --pid $PPID 2>/dev/null || echo "0")
    if [[ "$others" -gt 0 ]]; then
        echo -e "${YELLOW}Another agent is active — logging to TODO.md instead of NFR.md${NC}"
        echo "- [ ] NFR candidate: ${STATEMENT}" >> "$TODO_FILE"
        echo -e "${GREEN}✓${NC} Logged to TODO.md for human resolution"
        exit 0
    fi
fi

# --- Find next NFR ID ---
if [[ -f "$NFR_FILE" ]]; then
    max_id=$(grep -oE 'NFR-[0-9]+' "$NFR_FILE" 2>/dev/null | sed 's/NFR-//' | sort -n | tail -1)
    next_num=$((${max_id:-0} + 1))
else
    next_num=1
    # Create NFR.md from template if it doesn't exist
    if [[ -f "$SCRIPT_DIR/../templates/NFR.template.md" ]]; then
        cp "$SCRIPT_DIR/../templates/NFR.template.md" "$NFR_FILE"
        # Remove the example entry
        sed -i '/^## NFR-####:/,$d' "$NFR_FILE" 2>/dev/null || true
    else
        mkdir -p "$(dirname "$NFR_FILE")"
        echo "# NFR (Non-Functional Requirements)" > "$NFR_FILE"
        echo "" >> "$NFR_FILE"
    fi
fi

NFR_ID=$(printf "NFR-%04d" "$next_num")

# --- Append to NFR.md ---
cat >> "$NFR_FILE" <<NFREOF

## ${NFR_ID}: ${STATEMENT}
- Category: ${CATEGORY}
- Statement: ${STATEMENT}
- Applies to: ${APPLIES_TO}
- How to measure: <!-- define measurement -->
- Where enforced:
  - Tests: none
  - CI: none
- Current status: unknown
- Notes: Captured from constraint language
NFREOF

echo -e "${GREEN}✓${NC} Created ${BOLD}${NFR_ID}${NC}: ${STATEMENT}"
echo -e "  Written to ${NFR_FILE}"
echo ""
echo -e "${YELLOW}Action needed${NC}: Fill in Category, Applies to, and How to measure fields"

# --- Optional: check propagation ---
if [[ -f "$SCRIPT_DIR/nfr-propagate.sh" ]]; then
    echo ""
    echo -e "${BOLD}Propagation check:${NC}"
    bash "$SCRIPT_DIR/nfr-propagate.sh" check --all 2>/dev/null || true
fi

exit 0
