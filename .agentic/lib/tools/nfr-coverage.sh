#!/usr/bin/env bash
# nfr-coverage.sh - NFR coverage analysis across features
#
# Usage:
#   bash nfr-coverage.sh              # Summary: which features reference each NFR
#   bash nfr-coverage.sh --detail     # Detailed: show exact acceptance criteria per NFR
#   bash nfr-coverage.sh NFR-XXXX     # Single NFR coverage
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../paths.sh"

NFR_FILE="${PROJECT_ROOT}/.agentic/spec/NFR.md"
FEATURES_FILE="${PROJECT_ROOT}/.agentic/spec/FEATURES.md"
ACCEPTANCE_DIR="${PROJECT_ROOT}/.agentic/spec/acceptance"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

if [[ ! -f "$NFR_FILE" ]]; then
    echo "No NFR.md found at $NFR_FILE"
    exit 0
fi

MODE="${1:-summary}"
FILTER_NFR=""

case "$MODE" in
    --detail) MODE="detail" ;;
    --help|-h) echo "Usage: nfr-coverage.sh [--detail|NFR-XXXX]"; exit 0 ;;
    NFR-*) FILTER_NFR="$MODE"; MODE="single" ;;
    summary) ;;
    *) echo "Unknown option: $MODE"; exit 1 ;;
esac

# Extract all NFR IDs
NFR_IDS=$(grep -oE 'NFR-[0-9]{4}' "$NFR_FILE" 2>/dev/null | sort -u)

if [[ -z "$NFR_IDS" ]]; then
    echo "No NFRs defined in $NFR_FILE"
    exit 0
fi

echo -e "${BOLD}NFR Coverage Report${NC}"
echo ""

# Get NFR names
get_nfr_name() {
    local nfr_id="$1"
    awk -v id="$nfr_id" '/^## / && $0 ~ id {sub(/^## NFR-[0-9]+: */,""); print; exit}' "$NFR_FILE"
}

# Find features referencing an NFR
get_referencing_features() {
    local nfr_id="$1"
    if [[ -f "$FEATURES_FILE" ]]; then
        awk -v nfr="$nfr_id" '
            /^## F-[0-9]{4}:/ { fid=$2; sub(/:$/,"",fid); fname=$0; sub(/^## F-[0-9]+: */,"",fname) }
            fid && $0 ~ nfr { print fid " " fname; fid="" }
        ' "$FEATURES_FILE"
    fi
}

# Check acceptance file for NFR compliance section
check_acceptance_nfr() {
    local fid="$1"
    local nfr_id="$2"
    local ac_file="$ACCEPTANCE_DIR/${fid}.md"
    if [[ -f "$ac_file" ]]; then
        if grep -q "$nfr_id\|NFR Compliance" "$ac_file" 2>/dev/null; then
            echo "has-compliance"
        else
            echo "no-compliance"
        fi
    else
        echo "no-file"
    fi
}

total_nfrs=0
total_refs=0
nfrs_with_zero=0

for nfr_id in $NFR_IDS; do
    if [[ "$MODE" == "single" && "$nfr_id" != "$FILTER_NFR" ]]; then
        continue
    fi

    total_nfrs=$((total_nfrs + 1))
    nfr_name=$(get_nfr_name "$nfr_id")
    refs=$(get_referencing_features "$nfr_id")
    ref_count=$(echo "$refs" | grep -c '^F-' || true)
    total_refs=$((total_refs + ref_count))

    if [[ $ref_count -eq 0 ]]; then
        nfrs_with_zero=$((nfrs_with_zero + 1))
        echo -e "  ${YELLOW}${nfr_id}${NC}: ${nfr_name} — ${RED}0 features${NC}"
    else
        echo -e "  ${GREEN}${nfr_id}${NC}: ${nfr_name} — ${GREEN}${ref_count} feature(s)${NC}"
    fi

    if [[ "$MODE" == "detail" || "$MODE" == "single" ]] && [[ -n "$refs" ]]; then
        echo "$refs" | while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            local_fid=$(echo "$line" | awk '{print $1}')
            local_fname=$(echo "$line" | cut -d' ' -f2-)
            compliance=$(check_acceptance_nfr "$local_fid" "$nfr_id")
            case "$compliance" in
                has-compliance) status="${GREEN}✓${NC}" ;;
                no-compliance) status="${YELLOW}?${NC}" ;;
                no-file) status="${RED}✗${NC}" ;;
            esac
            echo -e "    ${status} ${local_fid}: ${local_fname}"
        done
    fi
done

echo ""
echo -e "${BOLD}Summary${NC}: ${total_nfrs} NFRs, ${total_refs} total references"
if [[ $nfrs_with_zero -gt 0 ]]; then
    echo -e "  ${YELLOW}⚠${NC} ${nfrs_with_zero} NFR(s) with zero feature references"
fi
