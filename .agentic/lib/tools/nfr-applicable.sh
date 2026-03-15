#!/usr/bin/env bash
# nfr-applicable.sh — List NFRs applicable to a feature
#
# Reads NFR.md, matches each NFR's "Applies to:" field against the feature's
# category/description from FEATURES.md. Lists applicable NFRs so the agent
# can write testable ACs for them.
#
# Usage:
#   bash .agentic/lib/tools/nfr-applicable.sh F-XXXX
#
# Output: List of applicable NFR IDs with their statements.
# The AGENT writes the actual ACs — this tool only lists which NFRs apply.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../paths.sh"
cd "$PROJECT_ROOT"

# Colors
if [ -t 1 ]; then
    GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'
    BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'
else
    GREEN='' YELLOW='' BLUE='' BOLD='' DIM='' NC=''
fi

FEATURE_ID="${1:-}"
if [[ -z "$FEATURE_ID" ]]; then
    echo "Usage: bash .agentic/lib/tools/nfr-applicable.sh <F-XXXX>"
    exit 0
fi

NFR_FILE=".agentic/spec/NFR.md"
FEATURES_FILE=".agentic/spec/FEATURES.md"

# Check if NFR.md exists and has content
if [[ ! -f "$NFR_FILE" ]]; then
    echo "No NFRs defined (.agentic/spec/NFR.md not found)."
    echo "Consider running: ag nfr discover"
    exit 0
fi

if ! grep -qE '^## NFR-[0-9]+' "$NFR_FILE" 2>/dev/null; then
    echo "No NFRs defined in .agentic/spec/NFR.md (template only)."
    echo "Consider running: ag nfr discover"
    exit 0
fi

# Get feature description/category from FEATURES.md for keyword matching
feature_context=""
if [[ -f "$FEATURES_FILE" ]]; then
    feature_context=$(sed -n "/^## ${FEATURE_ID}:/,/^## F-/p" "$FEATURES_FILE" | head -20 | tr '[:upper:]' '[:lower:]')
fi

echo -e "${BOLD}NFRs applicable to ${FEATURE_ID}:${NC}"
echo ""

matched=0

# Collect NFR entries: ID|statement|applies_to
nfr_entries=()
current_nfr=""
current_statement=""
current_applies=""

while IFS= read -r line; do
    if echo "$line" | grep -qE '^## NFR-[0-9]+:'; then
        if [[ -n "$current_nfr" ]]; then
            nfr_entries+=("${current_nfr}|${current_statement}|${current_applies}")
        fi
        current_nfr=$(echo "$line" | grep -oE 'NFR-[0-9]+')
        current_statement=$(echo "$line" | sed "s/^## ${current_nfr}: //")
        current_applies=""
        continue
    fi
    if echo "$line" | grep -qiE '^- Applies to:'; then
        current_applies=$(echo "$line" | sed 's/^- Applies to:[[:space:]]*//' | tr '[:upper:]' '[:lower:]')
    fi
done < "$NFR_FILE"

# Capture last entry
if [[ -n "$current_nfr" ]]; then
    nfr_entries+=("${current_nfr}|${current_statement}|${current_applies}")
fi

# Check each NFR for applicability
for entry in "${nfr_entries[@]}"; do
    IFS='|' read -r nfr_id statement applies_to <<< "$entry"
    confidence="high"
    applicable=0

    # Global NFRs always apply (match "global" or "all work" or "all features")
    if echo "$applies_to" | grep -qiE 'global|all work|all features'; then
        applicable=1
        confidence="high"
    elif [[ -n "$feature_context" && -n "$applies_to" ]]; then
        # Keyword overlap matching
        applies_words=$(echo "$applies_to" | tr -cs '[:alnum:]' '\n' | awk 'length >= 4' | grep -viE '^(that|this|with|from|they|have|been|when|will|each|must|only|also|into|than|them)$' || true)
        for word in $applies_words; do
            if echo "$feature_context" | grep -qiw "$word"; then
                applicable=1
                confidence="low"
                break
            fi
        done
    fi

    if [[ "$applicable" -eq 1 ]]; then
        matched=$((matched + 1))
        marker=""
        [[ "$confidence" == "low" ]] && marker=" ${DIM}(?)${NC}"
        echo -e "  ${GREEN}${nfr_id}${NC}: ${statement}${marker}"
        echo -e "    ${DIM}Applies to: ${applies_to}${NC}"
        echo ""
    fi
done

if [[ "$matched" -eq 0 ]]; then
    echo -e "  ${DIM}No applicable NFRs found for this feature.${NC}"
fi

exit 0
