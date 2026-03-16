#!/usr/bin/env bash
# nfr-health.sh — NFR health report: status, coverage, staleness, test coverage
#
# Usage:
#   bash nfr-health.sh                  # Full per-NFR report
#   bash nfr-health.sh --summary        # One-line status (for dashboard)
#   bash nfr-health.sh --json           # Machine-readable JSON
#   bash nfr-health.sh --coverage-only  # Backward-compatible coverage report
#   bash nfr-health.sh --component X    # Filter by component
#
# Exit codes:
#   0 = all NFRs met/unknown, or nothing to check (no NFR.md)
#   1 = issues found (partial or violated NFRs in detail mode)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../paths.sh"
cd "$PROJECT_ROOT"

if [ -t 1 ]; then
    BOLD='\033[1m'; GREEN='\033[0;32m'; RED='\033[0;31m'
    YELLOW='\033[1;33m'; BLUE='\033[0;34m'; DIM='\033[2m'; NC='\033[0m'
else
    BOLD='' GREEN='' RED='' YELLOW='' BLUE='' DIM='' NC=''
fi

# NFR_FILE, FEATURES_FILE, ACCEPTANCE_DIR provided by paths.sh

MODE="detail"
COMPONENT_FILTER=""

# Parse args
while [[ $# -gt 0 ]]; do
    case "$1" in
        --summary) MODE="summary"; shift ;;
        --json) MODE="json"; shift ;;
        --coverage-only) MODE="coverage"; shift ;;
        --component) COMPONENT_FILTER="$2"; shift 2 ;;
        --help|-h)
            echo "Usage: nfr-health.sh [--summary|--json|--coverage-only] [--component X]"
            exit 0 ;;
        *) shift ;;
    esac
done

if [[ ! -f "$NFR_FILE" ]]; then
    [[ "$MODE" == "summary" ]] && { echo "No NFRs defined"; exit 0; }
    [[ "$MODE" == "json" ]] && { echo '{"nfrs":[],"summary":"none"}'; exit 0; }
    echo "No NFR.md found."
    exit 0
fi

# --- Parse all NFR entries ---
NFR_IDS=$(grep -oE 'NFR-[0-9]{4}' "$NFR_FILE" 2>/dev/null | sort -u)

if [[ -z "$NFR_IDS" ]]; then
    [[ "$MODE" == "summary" ]] && { echo "No NFRs defined"; exit 0; }
    echo "No NFRs defined in NFR.md."
    exit 0
fi

# Count statuses from NFR.md (fast — just field parsing)
total=0; met=0; partial=0; violated=0; unknown=0

while IFS= read -r nfr_id; do
    [[ -z "$nfr_id" ]] && continue

    # Component filtering
    if [[ -n "$COMPONENT_FILTER" ]]; then
        applies=$(awk -v id="$nfr_id" '
            /^## / && $0 ~ id { found=1; next }
            found && /^- Applies to:/ { sub(/^- Applies to: */, ""); print; exit }
            found && /^## / { exit }
        ' "$NFR_FILE")
        if ! echo "$applies" | grep -qi "$COMPONENT_FILTER"; then
            continue
        fi
    fi

    total=$((total + 1))

    status=$(awk -v id="$nfr_id" '
        /^## / && $0 ~ id { found=1; next }
        found && /^- Current status:/ { sub(/^- Current status: */, ""); sub(/<!--.*/, ""); gsub(/^ *| *$/, ""); print; exit }
        found && /^## / { exit }
    ' "$NFR_FILE")

    case "$status" in
        met) met=$((met + 1)) ;;
        partial) partial=$((partial + 1)) ;;
        violated) violated=$((violated + 1)) ;;
        *) unknown=$((unknown + 1)) ;;
    esac
done <<< "$NFR_IDS"

# --- Summary mode (for dashboard — fast, no cross-referencing) ---
if [[ "$MODE" == "summary" ]]; then
    parts=()
    [[ $met -gt 0 ]] && parts+=("${met} met")
    [[ $partial -gt 0 ]] && parts+=("${partial} partial")
    [[ $violated -gt 0 ]] && parts+=("${violated} violated")
    [[ $unknown -gt 0 ]] && parts+=("${unknown} unknown")
    summary="${total} defined"
    [[ ${#parts[@]} -gt 0 ]] && summary="${summary}, $(IFS=', '; echo "${parts[*]}")"
    echo "$summary"
    exit 0
fi

# --- JSON mode (per-NFR details + summary) ---
if [[ "$MODE" == "json" ]]; then
    printf '{"summary":{"total":%d,"met":%d,"partial":%d,"violated":%d,"unknown":%d},"nfrs":[' \
        "$total" "$met" "$partial" "$violated" "$unknown"
    first=1
    while IFS= read -r nfr_id; do
        [[ -z "$nfr_id" ]] && continue
        if [[ -n "$COMPONENT_FILTER" ]]; then
            applies=$(awk -v id="$nfr_id" '
                /^## / && $0 ~ id { found=1; next }
                found && /^- Applies to:/ { sub(/^- Applies to: */, ""); print; exit }
                found && /^## / { exit }
            ' "$NFR_FILE")
            echo "$applies" | grep -qi "$COMPONENT_FILTER" || continue
        fi
        nfr_name=$(awk -v id="$nfr_id" '/^## / && $0 ~ id {sub(/^## NFR-[0-9]+: */,""); print; exit}' "$NFR_FILE")
        nfr_status=$(awk -v id="$nfr_id" '
            /^## / && $0 ~ id { found=1; next }
            found && /^- Current status:/ { sub(/^- Current status: */, ""); sub(/<!--.*/, ""); gsub(/^ *| *$/, ""); print; exit }
            found && /^## / { exit }
        ' "$NFR_FILE")
        [[ -z "$nfr_status" ]] && nfr_status="unknown"
        # Escape quotes in name for JSON safety
        nfr_name=$(echo "$nfr_name" | sed 's/"/\\"/g')
        [[ $first -eq 0 ]] && printf ','
        printf '{"id":"%s","name":"%s","status":"%s"}' "$nfr_id" "$nfr_name" "$nfr_status"
        first=0
    done <<< "$NFR_IDS"
    printf ']}\n'
    exit 0
fi

# --- Coverage-only mode (backward compat with nfr-coverage.sh) ---
if [[ "$MODE" == "coverage" ]]; then
    bash "$SCRIPT_DIR/nfr-coverage.sh" "${COMPONENT_FILTER:-summary}"
    exit $?
fi

# --- Detail mode ---
echo -e "${BOLD}NFR Health Report${NC}"
[[ -n "$COMPONENT_FILTER" ]] && echo -e "${DIM}Filtered by component: ${COMPONENT_FILTER}${NC}"
echo ""

issues=0

while IFS= read -r nfr_id; do
    [[ -z "$nfr_id" ]] && continue

    # Component filtering
    if [[ -n "$COMPONENT_FILTER" ]]; then
        applies=$(awk -v id="$nfr_id" '
            /^## / && $0 ~ id { found=1; next }
            found && /^- Applies to:/ { sub(/^- Applies to: */, ""); print; exit }
            found && /^## / { exit }
        ' "$NFR_FILE")
        if ! echo "$applies" | grep -qi "$COMPONENT_FILTER"; then
            continue
        fi
    fi

    nfr_name=$(awk -v id="$nfr_id" '/^## / && $0 ~ id {sub(/^## NFR-[0-9]+: */,""); print; exit}' "$NFR_FILE")

    status=$(awk -v id="$nfr_id" '
        /^## / && $0 ~ id { found=1; next }
        found && /^- Current status:/ { sub(/^- Current status: */, ""); sub(/<!--.*/, ""); gsub(/^ *| *$/, ""); print; exit }
        found && /^## / { exit }
    ' "$NFR_FILE")

    # Status indicator
    case "$status" in
        met) status_icon="${GREEN}●${NC}" ;;
        partial) status_icon="${YELLOW}◐${NC}"; issues=$((issues + 1)) ;;
        violated) status_icon="${RED}○${NC}"; issues=$((issues + 1)) ;;
        *) status_icon="${DIM}?${NC}" ;;
    esac

    # Coverage: count referencing features
    ref_count=0
    if [[ -f "$FEATURES_FILE" ]]; then
        ref_count=$(grep -rl "$nfr_id" "$ACCEPTANCE_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')
    fi

    echo -e "  ${status_icon} ${BOLD}${nfr_id}${NC}: ${nfr_name}"
    echo -e "    Status: ${status:-unknown} | Features: ${ref_count} | ${DIM}$(awk -v id="$nfr_id" '/^## / && $0 ~ id {found=1; next} found && /^- Applies to:/ {sub(/^- Applies to: */,""); print; exit} found && /^## / {exit}' "$NFR_FILE")${NC}"
    echo ""
done <<< "$NFR_IDS"

echo -e "${BOLD}Summary${NC}: ${total} NFRs — ${met} met, ${partial} partial, ${violated} violated, ${unknown} unknown"

[[ $issues -gt 0 ]] && exit 1
exit 0
