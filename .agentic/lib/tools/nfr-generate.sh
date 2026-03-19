#!/usr/bin/env bash
# nfr-generate.sh — Generate NFR recommendations from catalog based on project type
#
# Reads STACK.md Primary platform (or --project-type override), loads nfr-catalog.md,
# outputs structured NFR suggestions filtered by priority tier.
#
# Usage:
#   bash nfr-generate.sh                        # Auto-detect from STACK.md
#   bash nfr-generate.sh --project-type web      # Override project type
#   bash nfr-generate.sh --project-type api --all # Include P3 entries
#   bash nfr-generate.sh --components "frontend,backend"  # Component-scoped
#   bash nfr-generate.sh --project-type web --limit 8     # Cap at 8 entries
#   bash nfr-generate.sh --project-type web --machine      # Pipe-delimited output
#
# Output: One block per NFR suggestion with ID, category, statement, priority, applies-to
# Machine output: pipe-delimited lines (ID|category|statement|measure|enforced|priority|section)
#
# Exit codes:
#   0 = suggestions found (or nothing to do: no catalog)
#   1 = error (unknown project type with no fallback, missing catalog)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../paths.sh"
cd "$PROJECT_ROOT"

# Colors (disabled when piped)
if [ -t 1 ]; then
    BOLD='\033[1m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
    BLUE='\033[0;34m'; DIM='\033[2m'; NC='\033[0m'
else
    BOLD='' GREEN='' YELLOW='' BLUE='' DIM='' NC=''
fi

CATALOG="$SCRIPT_DIR/../init/nfr-catalog.md"
STACK_FILE="$PROJECT_ROOT/STACK.md"

# --- Argument parsing ---
PROJECT_TYPE=""
COMPONENTS=""
INCLUDE_ALL=0
LIMIT=0
MACHINE=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --project-type) PROJECT_TYPE="$2"; shift 2 ;;
        --components) COMPONENTS="$2"; shift 2 ;;
        --all) INCLUDE_ALL=1; shift ;;
        --limit) LIMIT="$2"; shift 2 ;;
        --machine) MACHINE=1; shift ;;
        --help|-h)
            echo "Usage: nfr-generate.sh [--project-type <type>] [--components <list>] [--all] [--limit N] [--machine]"
            echo ""
            echo "Options:"
            echo "  --project-type  Override stack detection (web, api, mobile, game, audio, cli, desktop, library, data-pipeline)"
            echo "  --components    Comma-separated component list for P2 filtering"
            echo "  --all           Include P3 (structural/CI-only) entries"
            echo "  --limit N       Cap output at N entries (applied after filtering)"
            echo "  --machine       Pipe-delimited output, no header/footer (for piping to nfr-write-batch.sh)"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# --- Detect project type from STACK.md if not overridden ---
if [[ -z "$PROJECT_TYPE" ]]; then
    if [[ -f "$STACK_FILE" ]]; then
        PROJECT_TYPE=$(grep -E '^\s*-?\s*Primary platform:' "$STACK_FILE" 2>/dev/null \
            | sed 's/.*: *//' | sed 's/<!--.*-->//' | tr -d ' ' | tr '[:upper:]' '[:lower:]' || echo "")
    fi
fi

if [[ -z "$PROJECT_TYPE" ]]; then
    echo -e "${YELLOW}Could not detect project type from STACK.md.${NC}"
    echo "Use --project-type to specify: web, api, mobile, game, audio, cli, desktop, library, data-pipeline"
    exit 1
fi

# --- Map project type to catalog section names ---
# Returns one section name per line (avoids fragile multi-word reassembly)
map_type_to_sections() {
    local ptype="$1"
    # Type-specific sections FIRST so --limit prioritizes domain-relevant entries
    case "$ptype" in
        web|webapp|web-app|frontend)
            echo "Web App" ;;
        api|backend|service|server)
            echo "API / Backend" ;;
        mobile|ios|android|react-native)
            echo "Mobile" ;;
        game|gaming)
            echo "Game" ;;
        audio|dsp|audio-dsp)
            echo "Audio / DSP" ;;
        cli|command-line)
            echo "CLI" ;;
        desktop|electron|tauri)
            echo "Desktop" ;;
        library|sdk|lib|package)
            echo "Library / SDK" ;;
        data-pipeline|pipeline|etl|data)
            echo "Data Pipeline" ;;
        *)
            echo -e "${YELLOW}Unknown project type: $ptype — showing Universal only${NC}" >&2
            ;;
    esac
    echo "Universal"
    echo "Framework Promises"
}

# --- Extract NFR entries from a catalog section ---
# Parses markdown table rows, outputs structured blocks
extract_section_entries() {
    local section_name="$1"
    local in_section=0
    local in_table=0

    while IFS= read -r line; do
        # Detect section header
        if echo "$line" | grep -qE "^## ${section_name}"; then
            in_section=1
            in_table=0
            continue
        fi
        # Next section starts
        if [[ $in_section -eq 1 ]] && echo "$line" | grep -qE '^## '; then
            break
        fi
        # Skip table header and separator
        if [[ $in_section -eq 1 ]]; then
            if echo "$line" | grep -qE '^\| ID '; then
                in_table=1
                continue
            fi
            if echo "$line" | grep -qE '^\|--'; then
                continue
            fi
            # Parse table row
            if [[ $in_table -eq 1 ]] && echo "$line" | grep -qE '^\| [A-Z]-'; then
                local nfr_id category statement measure enforced priority
                nfr_id=$(echo "$line" | awk -F'|' '{print $2}' | tr -d ' ')
                category=$(echo "$line" | awk -F'|' '{print $3}' | sed 's/^ *//;s/ *$//')
                statement=$(echo "$line" | awk -F'|' '{print $4}' | sed 's/^ *//;s/ *$//')
                measure=$(echo "$line" | awk -F'|' '{print $5}' | sed 's/^ *//;s/ *$//')
                enforced=$(echo "$line" | awk -F'|' '{print $6}' | sed 's/^ *//;s/ *$//')
                priority=$(echo "$line" | awk -F'|' '{print $7}' | sed 's/^ *//;s/ *$//')

                # Default priority if column missing (backward compat with old catalog)
                [[ -z "$priority" ]] && priority="P1"

                echo "${nfr_id}|${category}|${statement}|${measure}|${enforced}|${priority}|${section_name}"
            fi
            # End of table
            if [[ $in_table -eq 1 ]] && [[ -z "$line" || "$line" == "---" || "$line" =~ ^\*\* ]]; then
                in_table=0
            fi
        fi
    done < "$CATALOG"
}

# --- Filter by priority and components ---
filter_entries() {
    local components_lower
    components_lower=$(echo "$COMPONENTS" | tr '[:upper:]' '[:lower:]' | tr ',' ' ')

    while IFS='|' read -r nfr_id category statement measure enforced priority section; do
        [[ -z "$nfr_id" ]] && continue

        case "$priority" in
            P1) ;; # Always include
            P2)
                # Include if components match or no component filter specified
                if [[ -n "$COMPONENTS" ]]; then
                    local cat_lower
                    cat_lower=$(echo "$category" | tr '[:upper:]' '[:lower:]')
                    local matched=0
                    for comp in $components_lower; do
                        if echo "$statement $cat_lower" | grep -qiw "$comp"; then
                            matched=1
                            break
                        fi
                    done
                    [[ $matched -eq 0 ]] && continue
                fi
                ;;
            P3)
                # Only include with --all
                [[ $INCLUDE_ALL -eq 0 ]] && continue
                ;;
        esac

        echo "${nfr_id}|${category}|${statement}|${measure}|${enforced}|${priority}|${section}"
    done
}

# --- Main ---
if [[ ! -f "$CATALOG" ]]; then
    echo "NFR catalog not found at $CATALOG"
    exit 1
fi

sections=$(map_type_to_sections "$PROJECT_TYPE")
count=0

# Header (human mode only)
if [[ $MACHINE -eq 0 ]]; then
    echo -e "${BOLD}NFR Recommendations for: ${PROJECT_TYPE}${NC}"
    echo -e "${DIM}Sections: $(echo "$sections" | tr '\n' ', ' | sed 's/, $//')${NC}"
    echo ""
fi

# Collect all entries (one section per line from map_type_to_sections)
all_entries=""
while IFS= read -r section; do
    [[ -z "$section" ]] && continue
    entries=$(extract_section_entries "$section")
    if [[ -n "$entries" ]]; then
        all_entries="${all_entries}${entries}"$'\n'
    fi
done <<< "$sections"

# Filter and output
filtered=$(echo "$all_entries" | filter_entries)

if [[ -z "$filtered" ]]; then
    if [[ $MACHINE -eq 0 ]]; then
        echo -e "${YELLOW}No NFR suggestions found for project type: ${PROJECT_TYPE}${NC}"
    fi
    exit 1
fi

while IFS='|' read -r nfr_id category statement measure enforced priority section; do
    [[ -z "$nfr_id" ]] && continue
    count=$((count + 1))

    # Apply --limit (post-filter cap)
    if [[ $LIMIT -gt 0 && $count -gt $LIMIT ]]; then
        break
    fi

    if [[ $MACHINE -eq 1 ]]; then
        # Pipe-delimited output for machine consumption
        echo "${nfr_id}|${category}|${statement}|${measure}|${enforced}|${priority}|${section}"
    else
        local_color="$GREEN"
        [[ "$priority" == "P2" ]] && local_color="$YELLOW"
        [[ "$priority" == "P3" ]] && local_color="$DIM"

        echo -e "${local_color}[${priority}]${NC} ${BOLD}${nfr_id}${NC}: ${statement}"
        echo -e "  ${DIM}Category: ${category} | Section: ${section}${NC}"
        echo -e "  ${DIM}Measure: ${measure}${NC}"
        echo ""
    fi
done <<< "$filtered"

# Footer (human mode only)
if [[ $MACHINE -eq 0 ]]; then
    # Adjust count if limit was applied
    if [[ $LIMIT -gt 0 && $count -gt $LIMIT ]]; then
        count=$LIMIT
    fi
    echo -e "${BOLD}Total: ${count} suggestion(s)${NC}"
    [[ $INCLUDE_ALL -eq 0 ]] && echo -e "${DIM}Use --all to include P3 (structural/CI-only) entries${NC}"
fi

exit 0
