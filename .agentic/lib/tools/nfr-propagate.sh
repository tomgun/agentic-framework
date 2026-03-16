#!/usr/bin/env bash
# nfr-propagate.sh — NFR propagation: derive, check staleness, sync
#
# Usage:
#   bash nfr-propagate.sh derive F-XXXX     # Draft ### NFR Constraints section
#   bash nfr-propagate.sh check [--all]     # Check NFR staleness across features
#   bash nfr-propagate.sh sync F-XXXX       # Compare current AC vs derive output
#
# Exit codes: 0 = clean, 1 = issues found

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

# NFR_FILE, FEATURES_FILE, ACCEPTANCE_DIR provided by paths.sh

# --- derive: generate ### NFR Constraints section for a feature ---
cmd_derive() {
    local fid="$1"
    if [[ -z "$fid" ]]; then
        echo "Usage: nfr-propagate.sh derive <F-XXXX>"
        exit 1
    fi

    if [[ ! -f "$NFR_FILE" ]]; then
        echo "No NFR.md found."
        exit 0
    fi

    # Get applicable NFRs (piped = no ANSI)
    local applicable
    applicable=$(bash "$SCRIPT_DIR/nfr-applicable.sh" "$fid" 2>/dev/null)
    local applicable_ids
    applicable_ids=$(echo "$applicable" | grep -oE 'NFR-[0-9]+' | sort -u)

    if [[ -z "$applicable_ids" ]]; then
        echo "<!-- NFRs: none applicable — evaluated $(date +%Y-%m-%d) -->"
        exit 0
    fi

    echo "### NFR Constraints (P1 — required)"
    echo "**Verify independently**: Check each constraint against the feature implementation"
    echo ""

    local ac_num=10
    while IFS= read -r nfr_id; do
        [[ -z "$nfr_id" ]] && continue

        # Extract statement from NFR.md
        local statement
        statement=$(awk -v id="$nfr_id" '
            /^## / && $0 ~ id { found=1; next }
            found && /^- Statement:/ { sub(/^- Statement: */, ""); print; exit }
            found && /^## / { exit }
        ' "$NFR_FILE")

        if [[ -n "$statement" ]]; then
            printf -- '- [ ] **AC-%03d**: %s (%s)\n' "$ac_num" "$statement" "$nfr_id"
            ac_num=$((ac_num + 1))
        fi
    done <<< "$applicable_ids"
}

# --- check: detect NFR staleness across features ---
cmd_check() {
    local check_all=0
    local target_fid=""
    if [[ "${1:-}" == "--all" ]]; then
        check_all=1
    elif [[ -n "${1:-}" ]]; then
        target_fid="$1"
    else
        check_all=1
    fi

    if [[ ! -f "$NFR_FILE" ]] || [[ ! -f "$FEATURES_FILE" ]]; then
        echo "No NFR.md or FEATURES.md found."
        exit 0
    fi

    local nfr_mtime
    nfr_mtime=$(stat -c %Y "$NFR_FILE" 2>/dev/null || stat -f %m "$NFR_FILE" 2>/dev/null)

    echo -e "${BOLD}NFR Staleness Check${NC}"
    echo ""

    local stale=0
    local checked=0

    # Get feature IDs to check
    local fids
    if [[ $check_all -eq 1 ]]; then
        fids=$(grep -oE '^## F-[0-9]+' "$FEATURES_FILE" | sed 's/^## //')
    else
        fids="$target_fid"
    fi

    while IFS= read -r fid; do
        [[ -z "$fid" ]] && continue
        local ac_file="$ACCEPTANCE_DIR/${fid}.md"
        [[ -f "$ac_file" ]] || continue

        # Check if this AC references any NFRs
        if ! grep -qE 'NFR-[0-9]+' "$ac_file" 2>/dev/null; then
            continue
        fi

        checked=$((checked + 1))
        local ac_mtime
        ac_mtime=$(stat -c %Y "$ac_file" 2>/dev/null || stat -f %m "$ac_file" 2>/dev/null)

        if [[ "$nfr_mtime" -gt "$ac_mtime" ]]; then
            echo -e "  ${YELLOW}⚠${NC} ${fid}: NFR.md newer than acceptance file"
            stale=$((stale + 1))
        else
            echo -e "  ${GREEN}✓${NC} ${fid}: up to date"
        fi
    done <<< "$fids"

    echo ""
    echo -e "${BOLD}Checked${NC}: ${checked} feature(s), ${stale} stale"

    [[ $stale -gt 0 ]] && exit 1
    exit 0
}

# --- sync: compare current AC NFR constraints vs derive output ---
cmd_sync() {
    local fid="$1"
    if [[ -z "$fid" ]]; then
        echo "Usage: nfr-propagate.sh sync <F-XXXX>"
        exit 1
    fi

    local ac_file="$ACCEPTANCE_DIR/${fid}.md"
    if [[ ! -f "$ac_file" ]]; then
        echo "No acceptance file for ${fid}."
        exit 0
    fi

    if [[ ! -f "$NFR_FILE" ]]; then
        echo "No NFR.md found."
        exit 0
    fi

    echo -e "${BOLD}NFR Sync: ${fid}${NC}"
    echo ""

    # Get what derive would produce
    local desired_ids
    desired_ids=$(bash "$SCRIPT_DIR/nfr-applicable.sh" "$fid" 2>/dev/null | grep -oE 'NFR-[0-9]+' | sort -u)

    # Get what's currently in the AC file (scoped extraction)
    local current_content
    current_content=$(sed -n '/^## Acceptance Criteria/,/^## [^A]/p' "$ac_file" 2>/dev/null || true)
    current_content+=$(sed -En '/^###{0,1} NFR Constraints/,/^###{0,1} [^N]/p' "$ac_file" 2>/dev/null || true)
    current_content+=$(sed -En '/^###{0,1} NFR Compliance/,/^###{0,1} [^N]/p' "$ac_file" 2>/dev/null || true)
    local current_ids
    current_ids=$(echo "$current_content" | grep -oE 'NFR-[0-9]+' 2>/dev/null | sort -u || true)

    # Check for legacy format
    local has_legacy=0
    if grep -qE '^##(#)? NFR Compliance' "$ac_file" 2>/dev/null; then
        has_legacy=1
    fi

    local issues=0

    # Missing: in desired but not in current
    while IFS= read -r nfr_id; do
        [[ -z "$nfr_id" ]] && continue
        if ! echo "$current_ids" | grep -q "^${nfr_id}$"; then
            echo -e "  ${RED}MISSING${NC}: ${nfr_id} — applicable but not in ACs"
            issues=$((issues + 1))
        fi
    done <<< "$desired_ids"

    # Extra: in current but not in desired
    while IFS= read -r nfr_id; do
        [[ -z "$nfr_id" ]] && continue
        if ! echo "$desired_ids" | grep -q "^${nfr_id}$"; then
            echo -e "  ${YELLOW}EXTRA${NC}: ${nfr_id} — in ACs but not applicable"
            issues=$((issues + 1))
        fi
    done <<< "$current_ids"

    if [[ $has_legacy -eq 1 ]]; then
        echo -e "  ${YELLOW}LEGACY${NC}: Uses ## NFR Compliance format — consider migrating"
        echo -e "  ${DIM}Run: bash .agentic/lib/tools/nfr-migrate.sh ${fid}${NC}"
        issues=$((issues + 1))
    fi

    if [[ $issues -eq 0 ]]; then
        echo -e "  ${GREEN}✓${NC} NFR constraints are in sync"
    else
        echo ""
        echo -e "${BOLD}Issues${NC}: ${issues} found"
        echo -e "${DIM}Run: bash .agentic/lib/tools/nfr-propagate.sh derive ${fid}${NC}"
    fi

    [[ $issues -gt 0 ]] && exit 1
    exit 0
}

# --- Main dispatch ---
MODE="${1:-}"
shift 2>/dev/null || true

case "$MODE" in
    derive) cmd_derive "${1:-}" ;;
    check)  cmd_check "${1:-}" ;;
    sync)   cmd_sync "${1:-}" ;;
    --help|-h)
        echo "Usage: nfr-propagate.sh <mode> [args]"
        echo ""
        echo "Modes:"
        echo "  derive F-XXXX     Generate ### NFR Constraints section"
        echo "  check [--all]     Check NFR staleness across features"
        echo "  sync F-XXXX       Compare current ACs vs expected NFR constraints"
        exit 0
        ;;
    *)
        echo "Usage: nfr-propagate.sh <derive|check|sync> [args]"
        exit 1
        ;;
esac
