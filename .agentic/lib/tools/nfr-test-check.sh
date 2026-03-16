#!/usr/bin/env bash
# nfr-test-check.sh — Check NFR test coverage for a feature
#
# Given a feature ID, reports: applicable NFRs, which have test references
# in the AC file, which are missing.
#
# Usage:
#   bash nfr-test-check.sh F-XXXX
#
# Exit codes:
#   0 = all covered, or nothing to check (no NFR.md, no AC file, no applicable NFRs)
#   1 = gaps found (applicable NFRs not referenced in ACs)
#
# Parsing: Scoped extraction from ## Acceptance Criteria, ### NFR Constraints,
# and ## NFR Compliance sections only (NOT whole-file grep).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../paths.sh"
cd "$PROJECT_ROOT"

# Colors (disabled when piped)
if [ -t 1 ]; then
    BOLD='\033[1m'; GREEN='\033[0;32m'; RED='\033[0;31m'
    YELLOW='\033[1;33m'; DIM='\033[2m'; NC='\033[0m'
else
    BOLD='' GREEN='' RED='' YELLOW='' DIM='' NC=''
fi

FEATURE_ID="${1:-}"
if [[ -z "$FEATURE_ID" ]]; then
    echo "Usage: bash nfr-test-check.sh <F-XXXX>"
    exit 1
fi

# NFR_FILE, ACCEPTANCE_DIR provided by paths.sh
ACCEPT_FILE="${ACCEPTANCE_DIR}/${FEATURE_ID}.md"

# --- Check prerequisites ---
if [[ ! -f "$NFR_FILE" ]]; then
    echo "No NFR.md found — no NFR constraints to check."
    exit 0
fi

if [[ ! -f "$ACCEPT_FILE" ]]; then
    echo -e "${YELLOW}No acceptance file for ${FEATURE_ID} — cannot check NFR coverage.${NC}"
    exit 0
fi

# --- Get applicable NFRs (piped = no ANSI) ---
applicable_output=$(bash "$SCRIPT_DIR/nfr-applicable.sh" "$FEATURE_ID" 2>/dev/null)
applicable_ids=$(echo "$applicable_output" | grep -oE 'NFR-[0-9]+' | sort -u)

if [[ -z "$applicable_ids" ]]; then
    echo -e "${DIM}No applicable NFRs for ${FEATURE_ID}.${NC}"
    exit 0
fi

# --- Extract NFR references from SCOPED sections only ---
# Extract content from: ## Acceptance Criteria, ### NFR Constraints, ## NFR Compliance
scoped_content=$(sed -n '/^## Acceptance Criteria/,/^## [^A]/p' "$ACCEPT_FILE" 2>/dev/null || true)
nfr_constraints=$(sed -En '/^###{0,1} NFR Constraints/,/^###{0,1} [^N]/p' "$ACCEPT_FILE" 2>/dev/null || true)
nfr_compliance=$(sed -En '/^###{0,1} NFR Compliance/,/^###{0,1} [^N]/p' "$ACCEPT_FILE" 2>/dev/null || true)

# Combine scoped sections and extract NFR references
all_scoped="${scoped_content}${nfr_constraints}${nfr_compliance}"
referenced_ids=$(echo "$all_scoped" | grep -oE 'NFR-[0-9]+' 2>/dev/null | sort -u || true)

# --- Compare applicable vs referenced ---
echo -e "${BOLD}NFR Test Coverage: ${FEATURE_ID}${NC}"
echo ""

gaps=0
covered=0

while IFS= read -r nfr_id; do
    [[ -z "$nfr_id" ]] && continue

    # Get NFR name from NFR.md
    nfr_name=$(awk -v id="$nfr_id" '/^## / && $0 ~ id {sub(/^## NFR-[0-9]+: */,""); print; exit}' "$NFR_FILE")

    if echo "$referenced_ids" | grep -q "^${nfr_id}$"; then
        echo -e "  ${GREEN}✓${NC} ${nfr_id}: ${nfr_name}"
        covered=$((covered + 1))
    else
        echo -e "  ${RED}✗${NC} ${nfr_id}: ${nfr_name} ${YELLOW}— not referenced in ACs${NC}"
        gaps=$((gaps + 1))
    fi
done <<< "$applicable_ids"

echo ""
echo -e "${BOLD}Summary${NC}: ${covered} covered, ${gaps} gap(s)"

if [[ $gaps -gt 0 ]]; then
    echo ""
    echo -e "${YELLOW}Action: Add NFR constraints to ${ACCEPT_FILE}${NC}"
    echo -e "${DIM}Run: bash .agentic/lib/tools/nfr-applicable.sh ${FEATURE_ID} for details${NC}"
    exit 1
fi

exit 0
