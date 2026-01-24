#!/usr/bin/env bash
# drift.sh: Detect and fix spec ↔ code drift
#
# Checks that specs/acceptance criteria match actual code state.
# When drift is detected, prompts user to decide which is correct.
#
# Usage:
#   bash .agentic/tools/drift.sh           # Interactive mode
#   bash .agentic/tools/drift.sh --check   # Check only, no prompts (CI mode)
#   bash .agentic/tools/drift.sh --report  # Generate drift report
#
# Note: Not using set -e because grep returns 1 when no matches (expected behavior)
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Mode
MODE="${1:-interactive}"
DRIFT_COUNT=0
FIXED_COUNT=0

#=============================================================================
# Utility Functions
#=============================================================================

log_check() {
    echo -e "${BLUE}Checking:${NC} $1"
}

log_ok() {
    echo -e "  ${GREEN}✓${NC} $1"
}

log_drift() {
    echo -e "  ${YELLOW}⚠${NC} $1"
    ((DRIFT_COUNT++))
}

log_error() {
    echo -e "  ${RED}✗${NC} $1"
}

prompt_fix() {
    local message="$1"
    local options="$2"

    if [[ "$MODE" == "--check" ]]; then
        return 1  # In check mode, don't prompt
    fi

    echo ""
    echo -e "${CYAN}$message${NC}"
    echo "$options"
    echo ""
    read -p "Choice: " choice
    echo "$choice"
}

#=============================================================================
# Drift Detection: FEATURES.md ↔ Code
#=============================================================================

check_features_drift() {
    local features_file="$ROOT_DIR/spec/FEATURES.md"

    if [[ ! -f "$features_file" ]]; then
        return 0  # No features file (Core profile)
    fi

    log_check "FEATURES.md ↔ Code alignment"

    # Parse shipped features
    local shipped_features=$(grep -E "^## F-[0-9]+" "$features_file" | while read line; do
        local fid=$(echo "$line" | grep -oE "F-[0-9]+")
        # Check if status is shipped
        local section=$(sed -n "/^## $fid/,/^## F-/p" "$features_file" | head -20)
        if echo "$section" | grep -qi "status:.*shipped"; then
            echo "$fid"
        fi
    done)

    for fid in $shipped_features; do
        # Check if acceptance criteria file exists
        local criteria_file="$ROOT_DIR/spec/acceptance/${fid}.md"
        if [[ -f "$criteria_file" ]]; then
            # Check if all criteria are marked complete
            local incomplete=$(grep -E "^- \[ \]" "$criteria_file" 2>/dev/null || true)
            if [[ -n "$incomplete" ]]; then
                log_drift "$fid marked 'shipped' but has incomplete criteria:"
                echo "$incomplete" | head -3 | sed 's/^/      /'

                if [[ "$MODE" == "interactive" ]]; then
                    local choice=$(prompt_fix \
                        "How to resolve $fid drift?" \
                        "  1. Mark criteria complete (code is correct)
  2. Reopen feature (spec is correct)
  3. Skip")

                    case "$choice" in
                        1)
                            # Mark all criteria complete
                            sed -i.bak 's/^- \[ \]/- [x]/' "$criteria_file"
                            rm -f "${criteria_file}.bak"
                            log_ok "Marked all criteria complete in $fid"
                            ((FIXED_COUNT++))
                            ;;
                        2)
                            # Reopen feature
                            sed -i.bak "s/status:.*shipped/status: in_progress/" "$features_file"
                            rm -f "${features_file}.bak"
                            log_ok "Reopened $fid (status: in_progress)"
                            ((FIXED_COUNT++))
                            ;;
                        *)
                            log_drift "Skipped $fid"
                            ;;
                    esac
                fi
            else
                log_ok "$fid: shipped with all criteria complete"
            fi
        fi
    done

    # Check in_progress features have recent activity
    local in_progress_features=$(grep -E "^## F-[0-9]+" "$features_file" | while read line; do
        local fid=$(echo "$line" | grep -oE "F-[0-9]+")
        local section=$(sed -n "/^## $fid/,/^## F-/p" "$features_file" | head -20)
        if echo "$section" | grep -qi "status:.*in_progress"; then
            echo "$fid"
        fi
    done)

    for fid in $in_progress_features; do
        # Check for recent commits mentioning this feature
        local recent_commits=$(git log --oneline --since="7 days ago" --grep="$fid" 2>/dev/null | wc -l | tr -d ' ')
        if [[ "$recent_commits" -eq 0 ]]; then
            # Check STATUS.md for mention
            if ! grep -q "$fid" "$ROOT_DIR/STATUS.md" 2>/dev/null; then
                log_drift "$fid is 'in_progress' but no recent activity (7 days)"

                if [[ "$MODE" == "interactive" ]]; then
                    local choice=$(prompt_fix \
                        "Feature $fid has no recent activity. What to do?" \
                        "  1. Keep as in_progress (still working on it)
  2. Mark as paused
  3. Mark as shipped (it's done)
  4. Skip")

                    case "$choice" in
                        2)
                            sed -i.bak "s/\(## $fid.*status:\s*\)in_progress/\1paused/" "$features_file"
                            rm -f "${features_file}.bak"
                            log_ok "Marked $fid as paused"
                            ((FIXED_COUNT++))
                            ;;
                        3)
                            bash "$SCRIPT_DIR/feature.sh" "$fid" status shipped 2>/dev/null || true
                            log_ok "Marked $fid as shipped"
                            ((FIXED_COUNT++))
                            ;;
                        *)
                            ;;
                    esac
                fi
            fi
        else
            log_ok "$fid: in_progress with recent activity"
        fi
    done
}

#=============================================================================
# Drift Detection: CONTEXT_PACK.md ↔ Files
#=============================================================================

check_context_pack_drift() {
    local context_file="$ROOT_DIR/CONTEXT_PACK.md"

    if [[ ! -f "$context_file" ]]; then
        return 0
    fi

    log_check "CONTEXT_PACK.md ↔ File structure"

    # Extract file references from CONTEXT_PACK.md
    local referenced_files=$(grep -oE '\b(src|lib|app|pkg)/[a-zA-Z0-9_/.-]+\.(ts|js|py|go|rs|java|rb|sh|md)\b' "$context_file" 2>/dev/null || true)

    local missing_count=0
    for file in $referenced_files; do
        if [[ ! -f "$ROOT_DIR/$file" ]]; then
            if [[ $missing_count -eq 0 ]]; then
                log_drift "CONTEXT_PACK.md references files that don't exist:"
            fi
            echo "      - $file"
            ((missing_count++))
        fi
    done

    if [[ $missing_count -gt 0 ]]; then
        if [[ "$MODE" == "interactive" ]]; then
            local choice=$(prompt_fix \
                "$missing_count file(s) referenced in CONTEXT_PACK.md don't exist." \
                "  1. Open CONTEXT_PACK.md to fix manually
  2. Skip")

            case "$choice" in
                1)
                    echo "Opening CONTEXT_PACK.md..."
                    ${EDITOR:-vim} "$context_file"
                    ((FIXED_COUNT++))
                    ;;
            esac
        fi
    else
        log_ok "All referenced files exist"
    fi
}

#=============================================================================
# Drift Detection: STATUS.md ↔ Reality
#=============================================================================

check_status_drift() {
    local status_file="$ROOT_DIR/STATUS.md"

    if [[ ! -f "$status_file" ]]; then
        log_drift "STATUS.md missing (required for both profiles)"
        return 0
    fi

    log_check "STATUS.md ↔ Current state"

    # Check if "Current focus" is stale
    local current_focus=$(grep -A1 "## Current focus" "$status_file" 2>/dev/null | tail -1 | sed 's/^- //')

    if [[ -n "$current_focus" && "$current_focus" != "<!--"* ]]; then
        # Check if there are recent commits related to the focus
        local focus_keywords=$(echo "$current_focus" | tr ' ' '\n' | grep -E '^[A-Za-z]{4,}' | head -3 | tr '\n' '|' | sed 's/|$//')

        if [[ -n "$focus_keywords" ]]; then
            local recent_related=$(git log --oneline --since="3 days ago" 2>/dev/null | grep -iE "$focus_keywords" | wc -l | tr -d ' ')

            if [[ "$recent_related" -eq 0 ]]; then
                log_drift "Current focus '$current_focus' has no recent commits (3 days)"

                if [[ "$MODE" == "interactive" ]]; then
                    local choice=$(prompt_fix \
                        "STATUS.md focus may be stale. Update?" \
                        "  1. Update focus now
  2. Keep current focus
  3. Skip")

                    case "$choice" in
                        1)
                            read -p "New focus: " new_focus
                            if [[ -n "$new_focus" ]]; then
                                bash "$SCRIPT_DIR/status.sh" focus "$new_focus" 2>/dev/null || true
                                log_ok "Updated focus to: $new_focus"
                                ((FIXED_COUNT++))
                            fi
                            ;;
                    esac
                fi
            else
                log_ok "Current focus has recent activity"
            fi
        fi
    fi

    # Check for WIP.md without STATUS.md mention
    if [[ -f "$ROOT_DIR/.agentic/WIP.md" ]]; then
        local wip_feature=$(grep -E "^Feature:" "$ROOT_DIR/.agentic/WIP.md" 2>/dev/null | head -1 | sed 's/Feature: //')
        if [[ -n "$wip_feature" ]]; then
            if ! grep -q "$wip_feature" "$status_file" 2>/dev/null; then
                log_drift "WIP.md has '$wip_feature' but STATUS.md doesn't mention it"
            fi
        fi
    fi
}

#=============================================================================
# Drift Detection: Tests ↔ Acceptance Criteria
#=============================================================================

check_tests_drift() {
    local acceptance_dir="$ROOT_DIR/spec/acceptance"

    if [[ ! -d "$acceptance_dir" ]]; then
        return 0  # No acceptance criteria (Core profile)
    fi

    log_check "Acceptance criteria ↔ Tests"

    # For each acceptance criteria file
    for criteria_file in "$acceptance_dir"/*.md; do
        [[ -f "$criteria_file" ]] || continue

        local fid=$(basename "$criteria_file" .md)

        # Extract criteria items
        local criteria=$(grep -E "^- \[.\]" "$criteria_file" 2>/dev/null || true)

        if [[ -z "$criteria" ]]; then
            continue
        fi

        # Check if tests mention the feature ID
        local test_coverage=$(grep -rl "$fid" "$ROOT_DIR/tests" "$ROOT_DIR/test" "$ROOT_DIR/spec" 2>/dev/null | grep -E '\.(test|spec)\.(ts|js|py)$' | wc -l | tr -d ' ')

        local criteria_count=$(echo "$criteria" | wc -l | tr -d ' ')

        if [[ "$test_coverage" -eq 0 && "$criteria_count" -gt 0 ]]; then
            log_drift "$fid has $criteria_count criteria but no test files reference it"
        else
            log_ok "$fid: $criteria_count criteria, $test_coverage test file(s)"
        fi
    done
}

#=============================================================================
# Drift Detection: Code → Specs (undocumented code)
#=============================================================================

check_undocumented_code() {
    log_check "Code → Specs (undocumented functionality)"

    local spec_content=""
    local context_content=""

    # Gather all spec content for searching
    if [[ -d "$ROOT_DIR/spec" ]]; then
        spec_content=$(cat "$ROOT_DIR/spec"/*.md 2>/dev/null || true)
    fi
    if [[ -f "$ROOT_DIR/CONTEXT_PACK.md" ]]; then
        context_content=$(cat "$ROOT_DIR/CONTEXT_PACK.md")
    fi
    if [[ -f "$ROOT_DIR/PRODUCT.md" ]]; then
        context_content="$context_content $(cat "$ROOT_DIR/PRODUCT.md")"
    fi

    local all_docs="$spec_content $context_content"
    local undocumented=()

    # Check for common code patterns not mentioned in specs
    # This is language-agnostic, looking for common export patterns

    # Find source directories (including .agentic/tools for framework projects)
    local src_dirs=""
    for dir in src lib app pkg cmd internal .agentic/tools; do
        [[ -d "$ROOT_DIR/$dir" ]] && src_dirs="$src_dirs $ROOT_DIR/$dir"
    done

    if [[ -z "$src_dirs" ]]; then
        log_ok "No standard source directories found"
        return 0
    fi

    # TypeScript/JavaScript: exported functions, classes, components
    local ts_exports=$(grep -rh "^export \(const\|function\|class\|default\)" $src_dirs --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" 2>/dev/null | \
        grep -oE "(function|class|const) [A-Z][a-zA-Z0-9]+" | \
        awk '{print $2}' | sort -u || true)

    # Python: class and function definitions
    local py_exports=$(grep -rh "^class \|^def \|^async def " $src_dirs --include="*.py" 2>/dev/null | \
        grep -oE "(class|def) [A-Za-z_][A-Za-z0-9_]+" | \
        awk '{print $2}' | grep -v "^_" | sort -u || true)

    # Go: exported functions (capitalized)
    local go_exports=$(grep -rh "^func [A-Z]" $src_dirs --include="*.go" 2>/dev/null | \
        grep -oE "func [A-Z][a-zA-Z0-9]+" | \
        awk '{print $2}' | sort -u || true)

    # Combine all exports
    local all_exports=$(echo -e "$ts_exports\n$py_exports\n$go_exports" | grep -v "^$" | sort -u)

    if [[ -z "$all_exports" ]]; then
        log_ok "No exported code found to check"
        return 0
    fi

    local undoc_count=0
    local checked_count=0

    for export in $all_exports; do
        ((checked_count++))
        # Skip common/generic names
        if [[ "$export" =~ ^(Test|Mock|Stub|Helper|Utils?|Config|Setup|Init|Main|App|Index)$ ]]; then
            continue
        fi

        # Check if mentioned in any documentation
        if ! echo "$all_docs" | grep -qi "$export"; then
            if [[ $undoc_count -eq 0 ]]; then
                log_drift "Code exports not mentioned in specs/CONTEXT_PACK:"
            fi
            echo "      - $export"
            ((undoc_count++))
            if [[ $undoc_count -ge 10 ]]; then
                echo "      ... and more (showing first 10)"
                break
            fi
        fi
    done

    if [[ $undoc_count -gt 0 ]]; then
        echo ""
        echo -e "  ${CYAN}Tip:${NC} Non-coders can't discover undocumented code."
        echo "       Add to CONTEXT_PACK.md or create specs for these."

        if [[ "$MODE" == "interactive" ]]; then
            local choice=$(prompt_fix \
                "Found $undoc_count undocumented export(s). What to do?" \
                "  1. Open CONTEXT_PACK.md to document them
  2. Skip (document later)
  3. These are internal, don't need docs")

            case "$choice" in
                1)
                    ${EDITOR:-vim} "$ROOT_DIR/CONTEXT_PACK.md"
                    ((FIXED_COUNT++))
                    ;;
                3)
                    log_ok "Marked as internal (no docs needed)"
                    ;;
            esac
        fi
    else
        log_ok "All $checked_count exports are documented"
    fi
}

#=============================================================================
# Drift Detection: API Endpoints → Specs
#=============================================================================

check_undocumented_endpoints() {
    log_check "API Endpoints → Specs"

    local spec_content=""
    if [[ -d "$ROOT_DIR/spec" ]]; then
        spec_content=$(cat "$ROOT_DIR/spec"/*.md 2>/dev/null || true)
    fi
    if [[ -f "$ROOT_DIR/CONTEXT_PACK.md" ]]; then
        spec_content="$spec_content $(cat "$ROOT_DIR/CONTEXT_PACK.md")"
    fi

    # Find API route definitions (common patterns)
    local routes=""

    # Express.js / Node
    routes=$(grep -rh "app\.\(get\|post\|put\|delete\|patch\)\|router\.\(get\|post\|put\|delete\|patch\)" "$ROOT_DIR" \
        --include="*.ts" --include="*.js" 2>/dev/null | \
        grep -oE "(get|post|put|delete|patch)\(['\"][^'\"]+['\"]" | \
        sed "s/['\"]//g" | sed 's/(/ /' || true)

    # Python Flask/FastAPI
    routes="$routes $(grep -rh "@app\.\(get\|post\|put\|delete\|route\)\|@router\." "$ROOT_DIR" \
        --include="*.py" 2>/dev/null | \
        grep -oE "(get|post|put|delete|route)\(['\"][^'\"]+['\"]" | \
        sed "s/['\"]//g" | sed 's/(/ /' || true)"

    # Go net/http or common frameworks
    routes="$routes $(grep -rh "HandleFunc\|Handle\|GET\|POST\|PUT\|DELETE" "$ROOT_DIR" \
        --include="*.go" 2>/dev/null | \
        grep -oE "['\"][/][^'\"]+['\"]" | tr -d "'\""  || true)"

    routes=$(echo "$routes" | grep -v "^$" | sort -u)

    if [[ -z "$routes" ]]; then
        log_ok "No API routes detected"
        return 0
    fi

    local undoc_count=0
    for route in $routes; do
        # Extract just the path part
        local path=$(echo "$route" | grep -oE "/[a-zA-Z0-9/_:-]+" | head -1)
        if [[ -n "$path" ]] && ! echo "$spec_content" | grep -q "$path"; then
            if [[ $undoc_count -eq 0 ]]; then
                log_drift "API endpoints not documented in specs:"
            fi
            echo "      - $path"
            ((undoc_count++))
        fi
    done

    if [[ $undoc_count -eq 0 ]]; then
        log_ok "All API endpoints documented"
    else
        echo ""
        echo -e "  ${CYAN}Tip:${NC} API endpoints should be in CONTEXT_PACK.md or spec/API.md"
    fi
}

#=============================================================================
# Main
#=============================================================================

main() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║         Spec ↔ Code Drift Detection                          ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Mode: $MODE"
    echo "Root: $ROOT_DIR"
    echo ""

    check_features_drift
    echo ""
    check_context_pack_drift
    echo ""
    check_status_drift
    echo ""
    check_tests_drift
    echo ""
    check_undocumented_code
    echo ""
    check_undocumented_endpoints

    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    if [[ $DRIFT_COUNT -eq 0 ]]; then
        echo -e "${GREEN}No drift detected. Specs and code are aligned.${NC}"
    else
        echo -e "${YELLOW}Found $DRIFT_COUNT drift issue(s).${NC}"
        if [[ $FIXED_COUNT -gt 0 ]]; then
            echo -e "${GREEN}Fixed $FIXED_COUNT issue(s).${NC}"
        fi
        if [[ "$MODE" == "--check" ]]; then
            exit 1
        fi
    fi
    echo "═══════════════════════════════════════════════════════════════"
}

main "$@"
