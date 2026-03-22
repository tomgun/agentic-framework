#!/usr/bin/env bash
# formalize.sh — Promote TODO items to formal spec structure
#
# Migrates TODO.md inbox items (T-XXXX) into FEATURES.md entries + AC stubs.
# Reuses quick_feature.sh and todo.sh triage — no duplicated logic.
# Does NOT change the profile (per ADR-002 §2).
#
# Usage:
#   bash formalize.sh                    # List promotable items
#   bash formalize.sh T-XXXX [T-YYYY]   # Promote specific items
#   bash formalize.sh --all              # Promote all open items
#   bash formalize.sh --dry-run [...]    # Preview without changes
#   bash formalize.sh --help             # Show usage

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${ROOT_DIR:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../paths.sh"
source "$SCRIPT_DIR/../settings.sh"

cd "$PROJECT_ROOT"

# Colors (disabled if not TTY)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    # BLUE intentionally omitted — unused
    BOLD='\033[1m'
    DIM='\033[2m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BOLD='' DIM='' NC=''
fi

DRY_RUN=false
PROMOTED=0
FAILED=0
FAILED_IDS=()
CREATED_FILES=()

# ---------------------------------------------------------------------------
# Functions
# ---------------------------------------------------------------------------

show_usage() {
    cat <<'EOF'
Usage: ag formalize [options] [T-XXXX ...]

Promote TODO inbox items to formal spec structure (FEATURES.md + AC stubs).

OPTIONS:
    (no args)              List promotable inbox items
    T-XXXX [T-YYYY ...]   Promote specific items
    --all                  Promote all open inbox items
    --dry-run              Preview without modifying files
    --help, -h             Show this help

EXAMPLES:
    ag formalize                        # See what can be promoted
    ag formalize T-0001                 # Promote one item
    ag formalize T-0001 T-0003          # Promote multiple items
    ag formalize --all --dry-run        # Preview bulk promotion
    ag formalize --all                  # Promote everything

Each promoted item gets:
  - A FEATURES.md entry (status: planned, auto-assigned F-ID)
  - A contract stub at .agentic/spec/contracts/F-XXXX.yaml
  - TODO item marked as triaged (moved to Done section)
EOF
}

ensure_spec_structure() {
    mkdir -p "$SPEC_DIR" "$ACCEPTANCE_DIR" "$ADR_DIR"

    if [[ ! -f "$FEATURES_FILE" ]]; then
        echo -e "${YELLOW}Creating $FEATURES_FILE...${NC}"
        cat > "$FEATURES_FILE" << 'TMPL'
# Features

<!-- format: features-v0.2.0 -->

## Summary

| Category | Total |
|----------|-------|
| All | 0 |

---

TMPL
        CREATED_FILES+=("$FEATURES_FILE")
    fi
}

list_promotable() {
    if [[ ! -f "$TODO_FILE" ]]; then
        return
    fi
    # Extract T-XXXX lines from Inbox section, skip struck-through
    awk '/^## Inbox/,/^## Done/' "$TODO_FILE" \
        | grep '^### T-[0-9]\{4\}:' \
        | grep -v '^### ~~T-' \
        | sed 's/^### //' \
        | while IFS= read -r line; do
            local tid
            tid=$(echo "$line" | grep -oE 'T-[0-9]{4}')
            local title
            title=$(echo "$line" | sed 's/^T-[0-9]\{4\}: //')
            echo "${tid}|${title}"
        done
}

promote_one() {
    local t_id="$1"

    # Validate format
    if [[ ! "$t_id" =~ ^T-[0-9]{4}$ ]]; then
        echo -e "${RED}Error: Invalid ID format '$t_id' (expected T-XXXX)${NC}"
        return 1
    fi

    # Check item exists in Inbox
    if ! awk '/^## Inbox/,/^## Done/' "$TODO_FILE" | grep -q "^### ${t_id}:"; then
        echo -e "${RED}Error: ${t_id} not found in TODO inbox${NC}"
        return 1
    fi

    # Check not struck-through
    if awk '/^## Inbox/,/^## Done/' "$TODO_FILE" | grep -q "^### ~~${t_id}:"; then
        echo -e "${DIM}Skipping ${t_id} (closed/struck-through)${NC}"
        return 1
    fi

    # Extract title
    local raw_line
    raw_line=$(awk '/^## Inbox/,/^## Done/' "$TODO_FILE" | grep "^### ${t_id}:" | head -1)
    local title
    title=$(echo "$raw_line" | sed "s/^### ${t_id}: //")

    if [[ -z "$title" ]]; then
        echo -e "${RED}Error: Could not extract title for ${t_id}${NC}"
        return 1
    fi

    # Dry-run mode
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${DIM}Would promote: ${t_id} → F-XXXX: ${title}${NC}"
        return 0
    fi

    # Call quick_feature.sh, capture output, strip ANSI codes
    local qf_output
    qf_output=$(bash "$SCRIPT_DIR/quick_feature.sh" "$title" 2>&1 | sed 's/\x1b\[[0-9;]*m//g')

    # Parse F-ID from output
    local f_id
    f_id=$(echo "$qf_output" | grep -oE "$FEATURE_ID_ERE" | head -1)

    if [[ -z "$f_id" ]]; then
        echo -e "${RED}Error: Failed to create feature for ${t_id}. quick_feature.sh output:${NC}"
        echo "$qf_output"
        return 1
    fi

    # Create contract stub (new format in contracts dir)
    local ac_file="${CONTRACTS_DIR}/${f_id}.yaml"
    local today
    today=$(date +"%Y-%m-%d")
    cat > "$ac_file" <<EOF
# ${f_id}: ${title}

**Promoted from**: ${t_id} (${today})

## Acceptance Criteria

- [ ] **AC-001**: [TODO: Define acceptance criterion]
EOF
    CREATED_FILES+=("$ac_file")

    # Triage the TODO item (suppress stdout but keep stderr for diagnostics)
    if ! bash "$SCRIPT_DIR/todo.sh" triage "$t_id" feature "Promoted to ${f_id}" >/dev/null; then
        echo -e "${YELLOW}Warning: ${t_id} triage failed — feature ${f_id} was created but TODO not moved to Done${NC}"
    fi

    echo -e "${GREEN}✓${NC} ${t_id} → ${f_id}: ${title}"
    return 0
}

print_summary() {
    local total=$((PROMOTED + FAILED))

    echo ""
    if [[ $PROMOTED -gt 0 ]]; then
        echo -e "${GREEN}Promoted ${PROMOTED}/${total} item(s)${NC}"
    fi
    if [[ $FAILED -gt 0 ]]; then
        echo -e "${RED}Failed ${FAILED}/${total}: ${FAILED_IDS[*]}${NC}"
    fi

    if [[ ${#CREATED_FILES[@]} -gt 0 ]]; then
        echo ""
        echo "Created files:"
        for f in "${CREATED_FILES[@]}"; do
            echo "  $f"
        done
    fi

    # Settings advisory
    local ft st
    ft=$(get_setting "feature_tracking" "no")
    st=$(get_setting "spec_directory" "")
    if [[ "$ft" != "yes" || -z "$st" ]]; then
        echo ""
        echo -e "${YELLOW}Advisory:${NC}"
        if [[ "$ft" != "yes" ]]; then
            echo "  feature_tracking is not enabled. Run: ag set feature_tracking yes"
        fi
        if [[ -z "$st" ]]; then
            echo "  spec_directory is not set. Run: ag set spec_directory .agentic/spec"
        fi
    fi
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

T_IDS=()
ALL_MODE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h)
            show_usage
            exit 0
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --all)
            ALL_MODE=true
            shift
            ;;
        T-[0-9][0-9][0-9][0-9])
            T_IDS+=("$1")
            shift
            ;;
        *)
            echo -e "${RED}Unknown argument: $1${NC}"
            echo "Run: ag formalize --help"
            exit 1
            ;;
    esac
done

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

# No args: list promotable items
if [[ ${#T_IDS[@]} -eq 0 && "$ALL_MODE" == false ]]; then
    items=$(list_promotable)
    if [[ -z "$items" ]]; then
        echo "No promotable items in TODO inbox."
        exit 0
    fi
    echo -e "${BOLD}Promotable TODO items:${NC}"
    echo ""
    idx=1
    echo "$items" | while IFS='|' read -r tid title; do
        printf "  %2d. %s: %s\n" "$idx" "$tid" "$title"
        idx=$((idx + 1))
    done
    echo ""
    echo "Promote with: ag formalize T-XXXX [T-YYYY ...]"
    echo "Promote all:  ag formalize --all"
    exit 0
fi

# Ensure spec structure exists
if [[ "$DRY_RUN" == false ]]; then
    ensure_spec_structure
fi

# Collect IDs to promote
if [[ "$ALL_MODE" == true ]]; then
    items=$(list_promotable)
    if [[ -z "$items" ]]; then
        echo "No promotable items in TODO inbox."
        exit 0
    fi
    while IFS='|' read -r tid _title; do
        T_IDS+=("$tid")
    done <<< "$items"
fi

if [[ "$DRY_RUN" == true ]]; then
    echo -e "${BOLD}Dry run — no files will be modified${NC}"
    echo ""
fi

# Promote each item
for tid in "${T_IDS[@]}"; do
    if promote_one "$tid"; then
        PROMOTED=$((PROMOTED + 1))
    else
        FAILED=$((FAILED + 1))
        FAILED_IDS+=("$tid")
    fi
done

# Summary
if [[ "$DRY_RUN" == false ]]; then
    print_summary
fi
