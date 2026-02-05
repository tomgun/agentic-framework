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
#   bash .agentic/tools/drift.sh --json    # JSON output (machine-readable)
#   bash .agentic/tools/drift.sh --docs    # Check documentation drift
#   bash .agentic/tools/drift.sh --docs --manifest F-XXXX  # Check against specific manifest
#
# Note: Not using set -e because grep returns 1 when no matches (expected behavior)
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors (disabled for JSON mode)
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
DOCS_MODE=false
MANIFEST_FEATURE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --docs)
            DOCS_MODE=true
            MODE="--docs"
            shift
            ;;
        --manifest)
            shift
            MANIFEST_FEATURE="${1:-}"
            shift
            ;;
        --check|--report|--json|interactive)
            MODE="$1"
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# JSON output collection
JSON_ISSUES=()
JSON_MODE=false
if [[ "$MODE" == "--json" ]]; then
    JSON_MODE=true
    # Disable colors for JSON mode
    RED='' GREEN='' YELLOW='' BLUE='' CYAN='' NC=''
fi

#=============================================================================
# Utility Functions
#=============================================================================

# Add an issue to the JSON collection
# Usage: add_json_issue "type" "description" ["file"] ["feature"] ["extra_key" "extra_value"]
add_json_issue() {
    local type="$1"
    local description="$2"
    local file="${3:-}"
    local feature="${4:-}"
    local extra_key="${5:-}"
    local extra_value="${6:-}"

    local json="{\"type\":\"$type\",\"description\":\"$description\""
    [[ -n "$file" ]] && json="$json,\"file\":\"$file\""
    [[ -n "$feature" ]] && json="$json,\"feature\":\"$feature\""
    [[ -n "$extra_key" ]] && json="$json,\"$extra_key\":\"$extra_value\""
    json="$json}"

    JSON_ISSUES+=("$json")
}

log_check() {
    if [[ "$JSON_MODE" != "true" ]]; then
        echo -e "${BLUE}Checking:${NC} $1"
    fi
}

log_ok() {
    if [[ "$JSON_MODE" != "true" ]]; then
        echo -e "  ${GREEN}✓${NC} $1"
    fi
}

log_drift() {
    if [[ "$JSON_MODE" != "true" ]]; then
        echo -e "  ${YELLOW}⚠${NC} $1"
    fi
    ((DRIFT_COUNT++))
}

log_error() {
    if [[ "$JSON_MODE" != "true" ]]; then
        echo -e "  ${RED}✗${NC} $1"
    fi
}

prompt_fix() {
    local message="$1"
    local options="$2"

    if [[ "$MODE" == "--check" || "$JSON_MODE" == "true" ]]; then
        return 1  # In check/JSON mode, don't prompt
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

    # Detect format: table or heading-based
    local format="heading"
    if grep -qE "^\|[[:space:]]*F-[0-9]+" "$features_file"; then
        format="table"
    fi

    # Parse shipped features (support both formats)
    local shipped_features=""
    if [[ "$format" == "table" ]]; then
        # Table format: | F-0003 | Name | shipped | ... |
        shipped_features=$(grep -E "^\|[[:space:]]*F-[0-9]+" "$features_file" | \
            grep -i "shipped" | \
            grep -oE "F-[0-9]+" || true)
    else
        # Heading format: ## F-0003: Name with - Status: shipped
        shipped_features=$(grep -E "^## F-[0-9]+" "$features_file" | while read line; do
            local fid=$(echo "$line" | grep -oE "F-[0-9]+")
            # Check if status is shipped
            local section=$(sed -n "/^## $fid/,/^## F-/p" "$features_file" | head -20)
            if echo "$section" | grep -qi "status:.*shipped"; then
                echo "$fid"
            fi
        done)
    fi

    # Also check for pending features with high acceptance completion (status drift)
    local pending_features=""
    if [[ "$format" == "table" ]]; then
        pending_features=$(grep -E "^\|[[:space:]]*F-[0-9]+" "$features_file" | \
            grep -iE "(pending|planned)" | \
            grep -oE "F-[0-9]+" || true)
    else
        pending_features=$(grep -E "^## F-[0-9]+" "$features_file" | while read line; do
            local fid=$(echo "$line" | grep -oE "F-[0-9]+")
            local section=$(sed -n "/^## $fid/,/^## F-/p" "$features_file" | head -20)
            if echo "$section" | grep -qiE "status:.*(pending|planned)"; then
                echo "$fid"
            fi
        done)
    fi

    # Check pending features for acceptance criteria completion
    for fid in $pending_features; do
        local criteria_file="$ROOT_DIR/spec/acceptance/${fid}.md"
        if [[ -f "$criteria_file" ]]; then
            local total=$(grep -cE "^- \[.\]" "$criteria_file" 2>/dev/null || echo "0")
            local complete=$(grep -cE "^- \[x\]" "$criteria_file" 2>/dev/null || echo "0")
            if [[ "$total" -gt 0 ]]; then
                local pct=$((complete * 100 / total))
                if [[ "$pct" -ge 50 ]]; then
                    log_drift "$fid: marked 'pending' but acceptance criteria ${pct}% complete ($complete/$total)"
                    add_json_issue "status_drift" "$fid marked pending but ${pct}% complete" "$criteria_file" "$fid" "completion" "$pct"
                    [[ "$JSON_MODE" != "true" ]] && echo "      → Consider updating status to 'in_progress' or 'shipped'"
                fi
            fi
        fi
    done

    for fid in $shipped_features; do
        # Check if acceptance criteria file exists
        local criteria_file="$ROOT_DIR/spec/acceptance/${fid}.md"
        if [[ -f "$criteria_file" ]]; then
            # Check if all criteria are marked complete
            local incomplete=$(grep -E "^- \[ \]" "$criteria_file" 2>/dev/null || true)
            if [[ -n "$incomplete" ]]; then
                log_drift "$fid marked 'shipped' but has incomplete criteria:"
                add_json_issue "incomplete_shipped" "$fid marked shipped but has incomplete acceptance criteria" "$criteria_file" "$fid"
                [[ "$JSON_MODE" != "true" ]] && echo "$incomplete" | head -3 | sed 's/^/      /'

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
                add_json_issue "stale_in_progress" "$fid in_progress but no recent activity" "" "$fid"

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
            [[ "$JSON_MODE" != "true" ]] && echo "      - $file"
            add_json_issue "stale_reference" "CONTEXT_PACK.md references non-existent file" "$file" "" "referenced_in" "CONTEXT_PACK.md"
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
                add_json_issue "stale_focus" "STATUS.md focus has no recent commits" "STATUS.md" "" "focus" "$current_focus"

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
    if [[ -f "$ROOT_DIR/.agentic-state/WIP.md" ]]; then
        local wip_feature=$(grep -E "^Feature:" "$ROOT_DIR/.agentic-state/WIP.md" 2>/dev/null | head -1 | sed 's/Feature: //')
        if [[ -n "$wip_feature" ]]; then
            if ! grep -q "$wip_feature" "$status_file" 2>/dev/null; then
                log_drift "WIP.md has '$wip_feature' but STATUS.md doesn't mention it"
                add_json_issue "wip_status_mismatch" "WIP.md feature not mentioned in STATUS.md" "STATUS.md" "$wip_feature"
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
            add_json_issue "missing_tests" "$fid has acceptance criteria but no tests reference it" "$criteria_file" "$fid" "criteria_count" "$criteria_count"
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
    if [[ -f "$ROOT_DIR/OVERVIEW.md" ]]; then
        context_content="$context_content $(cat "$ROOT_DIR/OVERVIEW.md")"
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
            [[ "$JSON_MODE" != "true" ]] && echo "      - $export"
            add_json_issue "undocumented_code" "Code export not mentioned in documentation" "" "" "export" "$export"
            ((undoc_count++))
            if [[ $undoc_count -ge 10 ]]; then
                [[ "$JSON_MODE" != "true" ]] && echo "      ... and more (showing first 10)"
                break
            fi
        fi
    done

    if [[ $undoc_count -gt 0 ]]; then
        [[ "$JSON_MODE" != "true" ]] && echo ""
        [[ "$JSON_MODE" != "true" ]] && echo -e "  ${CYAN}Tip:${NC} Non-coders can't discover undocumented code."
        [[ "$JSON_MODE" != "true" ]] && echo "       Add to CONTEXT_PACK.md or create specs for these."

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
            [[ "$JSON_MODE" != "true" ]] && echo "      - $path"
            add_json_issue "undocumented_endpoint" "API endpoint not documented in specs" "" "" "endpoint" "$path"
            ((undoc_count++))
        fi
    done

    if [[ $undoc_count -eq 0 ]]; then
        log_ok "All API endpoints documented"
    else
        [[ "$JSON_MODE" != "true" ]] && echo ""
        [[ "$JSON_MODE" != "true" ]] && echo -e "  ${CYAN}Tip:${NC} API endpoints should be in CONTEXT_PACK.md or spec/API.md"
    fi
}

#=============================================================================
# Drift Detection: Untracked Implementation Files
#=============================================================================

check_untracked_files() {
    log_check "Untracked implementation files"

    # Skip if not a git repo
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        log_ok "Not a git repository, skipping"
        return 0
    fi

    # Find untracked files in implementation directories
    local untracked=""
    for dir in src lib app pkg cmd internal tests test spec; do
        if [[ -d "$ROOT_DIR/$dir" ]]; then
            local dir_untracked=$(git status --porcelain "$ROOT_DIR/$dir" 2>/dev/null | grep '^??' | sed 's/^?? //' || true)
            if [[ -n "$dir_untracked" ]]; then
                untracked="$untracked$dir_untracked"$'\n'
            fi
        fi
    done

    untracked=$(echo "$untracked" | grep -v '^$' | head -10)

    if [[ -n "$untracked" ]]; then
        log_drift "Untracked implementation files found:"
        echo "$untracked" | while read -r file; do
            if [[ -n "$file" ]]; then
                # Get file size/line count for context
                local info=""
                local lines=""
                if [[ -f "$ROOT_DIR/$file" ]]; then
                    lines=$(wc -l < "$ROOT_DIR/$file" 2>/dev/null | tr -d ' ')
                    info=" ($lines lines)"
                fi
                [[ "$JSON_MODE" != "true" ]] && echo "      - $file$info"
                add_json_issue "untracked_file" "Implementation file not tracked by git" "$file" "" "lines" "${lines:-0}"
            fi
        done
        [[ "$JSON_MODE" != "true" ]] && echo ""
        [[ "$JSON_MODE" != "true" ]] && echo -e "  ${CYAN}Tip:${NC} Consider: git add + commit, or add to .gitignore"

        if [[ "$MODE" == "interactive" ]]; then
            local choice=$(prompt_fix \
                "Untracked files found. What to do?" \
                "  1. Stage all for commit (git add)
  2. Skip (handle manually later)
  3. Show git status")

            case "$choice" in
                1)
                    echo "$untracked" | while read -r file; do
                        [[ -n "$file" ]] && git add "$ROOT_DIR/$file" 2>/dev/null
                    done
                    log_ok "Staged untracked files"
                    ((FIXED_COUNT++))
                    ;;
                3)
                    git status --short
                    ;;
            esac
        fi
    else
        log_ok "No untracked implementation files"
    fi
}

#=============================================================================
# Drift Detection: Template Markers
#=============================================================================

check_template_markers() {
    log_check "Template markers in project files"

    local markers_found=0
    local files_to_check=(
        "STACK.md"
        "CONTEXT_PACK.md"
        "STATUS.md"
        "OVERVIEW.md"
        "spec/FEATURES.md"
        "spec/PRD.md"
        "spec/TECH_SPEC.md"
    )

    for file in "${files_to_check[@]}"; do
        local filepath="$ROOT_DIR/$file"
        if [[ -f "$filepath" ]]; then
            # Check for "(Template)" in title (first line)
            if head -1 "$filepath" | grep -qi "(Template)"; then
                if [[ $markers_found -eq 0 ]]; then
                    log_drift "Template markers found in project files:"
                fi
                [[ "$JSON_MODE" != "true" ]] && echo "      - $file:1 - \"(Template)\" in title"
                add_json_issue "template_marker" "File has (Template) marker in title" "$file" "" "line" "1"
                ((markers_found++))
            fi

            # Check for common template placeholders
            local placeholders=$(grep -nE "^.*TBD[^a-zA-Z]|TODO:.*fill|<!-- .*-->$|\[Your |<describe " "$filepath" 2>/dev/null | head -3 || true)
            if [[ -n "$placeholders" ]]; then
                if [[ $markers_found -eq 0 ]]; then
                    log_drift "Template markers found in project files:"
                fi
                echo "$placeholders" | while read -r line; do
                    local linenum=$(echo "$line" | cut -d: -f1)
                    [[ "$JSON_MODE" != "true" ]] && echo "      - $file:$linenum - template placeholder"
                    add_json_issue "template_placeholder" "File has unfilled template placeholder" "$file" "" "line" "$linenum"
                done
                ((markers_found++))
            fi
        fi
    done

    if [[ $markers_found -eq 0 ]]; then
        log_ok "No template markers found"
    else
        [[ "$JSON_MODE" != "true" ]] && echo ""
        [[ "$JSON_MODE" != "true" ]] && echo -e "  ${CYAN}Tip:${NC} Remove template markers after filling in content"

        if [[ "$MODE" == "interactive" ]]; then
            local choice=$(prompt_fix \
                "Template markers found. What to do?" \
                "  1. Fix STACK.md title (remove Template suffix)
  2. Skip (handle manually later)")

            case "$choice" in
                1)
                    if [[ -f "$ROOT_DIR/STACK.md" ]]; then
                        sed -i.bak 's/ (Template)//g; s/(Template)//g' "$ROOT_DIR/STACK.md"
                        rm -f "$ROOT_DIR/STACK.md.bak"
                        log_ok "Removed (Template) from STACK.md"
                        ((FIXED_COUNT++))
                    fi
                    ;;
            esac
        fi
    fi
}

#=============================================================================
# Drift Detection: Documentation ↔ Code (--docs mode)
#=============================================================================

check_documentation_drift() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║         Documentation Drift Detection                          ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo ""

    local changed_files=()
    local manifest_dir="$ROOT_DIR/.agentic-journal/manifests"

    # Get changed files from manifest or git
    if [[ -n "$MANIFEST_FEATURE" && -d "$manifest_dir" ]]; then
        echo -e "${BLUE}Using manifest:${NC} $MANIFEST_FEATURE"
        local manifest_file="$manifest_dir/${MANIFEST_FEATURE}.json"
        if [[ -f "$manifest_file" ]]; then
            # Extract changed files from manifest JSON (portable for macOS/Linux)
            while IFS= read -r file; do
                [[ -n "$file" ]] && changed_files+=("$file")
            done < <(grep -o '"file": "[^"]*"' "$manifest_file" | sed 's/"file": "//;s/"$//' || true)
        else
            echo -e "${YELLOW}Warning:${NC} Manifest $manifest_file not found"
            echo "  Falling back to recent git changes..."
        fi
    fi

    # Fallback: get recently changed files from git
    if [[ ${#changed_files[@]} -eq 0 ]]; then
        echo -e "${BLUE}Checking:${NC} Recent code changes (last 7 days)"
        while IFS= read -r file; do
            [[ -n "$file" ]] && changed_files+=("$file")
        done < <(git log --name-only --since="7 days ago" --pretty=format: 2>/dev/null | grep -E '\.(ts|tsx|js|jsx|py|go|rs|java|rb|sh)$' | sort -u | head -50 || true)
    fi

    if [[ ${#changed_files[@]} -eq 0 ]]; then
        echo -e "${GREEN}✓${NC} No recent code changes to check"
        return 0
    fi

    echo ""
    echo -e "${BLUE}Files changed (${#changed_files[@]}):${NC}"
    for f in "${changed_files[@]:0:10}"; do
        echo "  - $f"
    done
    if [[ ${#changed_files[@]} -gt 10 ]]; then
        echo "  ... and $((${#changed_files[@]} - 10)) more"
    fi
    echo ""

    # Find documentation files
    local doc_files=()
    for pattern in "*.md" "docs/**/*.md" "README.md" "CONTEXT_PACK.md"; do
        while IFS= read -r f; do
            [[ -f "$ROOT_DIR/$f" ]] && doc_files+=("$f")
        done < <(cd "$ROOT_DIR" && find . -name "*.md" -type f 2>/dev/null | grep -vE '(node_modules|\.git|vendor|spec/migrations)' | sed 's|^\./||' | head -100 || true)
    done

    # Remove duplicates
    doc_files=($(printf '%s\n' "${doc_files[@]}" | sort -u))

    echo -e "${BLUE}Checking against ${#doc_files[@]} documentation files${NC}"
    echo ""

    # Extract keywords from changed code files
    local code_keywords=()
    for code_file in "${changed_files[@]}"; do
        [[ ! -f "$ROOT_DIR/$code_file" ]] && continue

        # Extract meaningful identifiers from filename
        local basename
        basename=$(basename "$code_file" | sed 's/\.[^.]*$//')
        [[ -n "$basename" && ${#basename} -gt 2 ]] && code_keywords+=("$basename")

        # Extract function/class names (simplified)
        while IFS= read -r name; do
            [[ -n "$name" && ${#name} -gt 3 ]] && code_keywords+=("$name")
        done < <(grep -ohE '(function|class|def|const|export)\s+[A-Za-z_][A-Za-z0-9_]*' "$ROOT_DIR/$code_file" 2>/dev/null | awk '{print $2}' | head -20 || true)
    done

    # Remove duplicates and common words
    code_keywords=($(printf '%s\n' "${code_keywords[@]}" | sort -u | grep -vE '^(test|spec|index|main|app|config|utils|helper|const|function|class|export|default)$' | head -30))

    if [[ ${#code_keywords[@]} -eq 0 ]]; then
        echo -e "${GREEN}✓${NC} No significant code identifiers to check"
        return 0
    fi

    # Check documentation for mentions of changed code
    local stale_docs=()
    local updated_docs=()
    local doc_drift_count=0

    for doc_file in "${doc_files[@]}"; do
        [[ ! -f "$ROOT_DIR/$doc_file" ]] && continue

        local doc_content
        doc_content=$(cat "$ROOT_DIR/$doc_file" 2>/dev/null || true)
        local doc_mentions=false

        # Check if doc mentions any of our code keywords
        for keyword in "${code_keywords[@]}"; do
            if echo "$doc_content" | grep -qi "$keyword"; then
                doc_mentions=true
                break
            fi
        done

        if [[ "$doc_mentions" == true ]]; then
            # Doc mentions changed code - check if it was updated recently
            local doc_modified=false
            if [[ -n "$MANIFEST_FEATURE" ]]; then
                # Check if doc was in the same manifest
                if echo "${changed_files[*]}" | grep -q "$doc_file"; then
                    doc_modified=true
                fi
            else
                # Check git log
                local doc_changes
                doc_changes=$(git log --since="7 days ago" --oneline -- "$ROOT_DIR/$doc_file" 2>/dev/null | wc -l | tr -d ' ')
                [[ "$doc_changes" -gt 0 ]] && doc_modified=true
            fi

            if [[ "$doc_modified" == true ]]; then
                updated_docs+=("$doc_file")
            else
                stale_docs+=("$doc_file")
                ((doc_drift_count++))
            fi
        fi
    done

    # Report results
    echo "═══════════════════════════════════════════════════════════════"
    echo -e "${BLUE}📄 Documentation Drift Report${NC}"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""

    if [[ ${#updated_docs[@]} -gt 0 ]]; then
        echo -e "${GREEN}✓ Updated docs (likely in sync):${NC}"
        for doc in "${updated_docs[@]}"; do
            echo "    ✓ $doc"
        done
        echo ""
    fi

    if [[ ${#stale_docs[@]} -gt 0 ]]; then
        echo -e "${YELLOW}⚠ Potentially stale docs (mention changed code but weren't updated):${NC}"
        for doc in "${stale_docs[@]}"; do
            echo "    ⚠ $doc"
            add_json_issue "doc_drift" "Documentation may be stale - mentions changed code" "$doc" "" "reason" "not_updated"
            ((DRIFT_COUNT++))
        done
        echo ""
        echo -e "${CYAN}Recommendation:${NC} Review flagged docs for accuracy."
        echo "  These docs reference code that changed but weren't updated themselves."
        echo ""
    else
        echo -e "${GREEN}✓ No documentation drift detected${NC}"
        echo "  All docs that mention changed code were also updated."
    fi

    echo "═══════════════════════════════════════════════════════════════"
    echo ""

    # STACK.md tracking hint
    if [[ ${#stale_docs[@]} -gt 3 ]]; then
        echo -e "${CYAN}Tip:${NC} Configure doc tracking in STACK.md to reduce false positives:"
        echo ""
        echo "  doc_tracking:"
        echo "    - docs: docs/api.md"
        echo "      tracks: src/api/**"
        echo "    - docs: README.md"
        echo "      tracks: src/index.ts, package.json"
        echo ""
    fi
}

#=============================================================================
# JSON Output
#=============================================================================

output_json() {
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Count issues by type
    local type_counts="{}"
    for issue in "${JSON_ISSUES[@]}"; do
        local issue_type
        issue_type=$(echo "$issue" | grep -oE '"type":"[^"]+"' | cut -d'"' -f4)
        # Simple counting - for more complex needs, use jq
    done

    # Build issues array
    local issues_json="["
    local first=true
    for issue in "${JSON_ISSUES[@]}"; do
        if [[ "$first" == "true" ]]; then
            first=false
        else
            issues_json="$issues_json,"
        fi
        issues_json="$issues_json$issue"
    done
    issues_json="$issues_json]"

    # Output final JSON
    cat <<EOF
{
  "tool": "drift",
  "timestamp": "$timestamp",
  "root": "$ROOT_DIR",
  "issues": $issues_json,
  "summary": {
    "total_issues": $DRIFT_COUNT,
    "fixed_issues": $FIXED_COUNT
  }
}
EOF
}

#=============================================================================
# Main
#=============================================================================

main() {
    # Handle --docs mode separately
    if [[ "$DOCS_MODE" == "true" ]]; then
        check_documentation_drift
        if [[ $DRIFT_COUNT -gt 0 ]]; then
            echo -e "${YELLOW}Found $DRIFT_COUNT potential documentation drift issue(s).${NC}"
            echo "  (Advisory only - review recommended)"
        fi
        return 0
    fi

    if [[ "$JSON_MODE" != "true" ]]; then
        echo ""
        echo "╔═══════════════════════════════════════════════════════════════╗"
        echo "║         Spec ↔ Code Drift Detection                          ║"
        echo "╚═══════════════════════════════════════════════════════════════╝"
        echo ""
        echo "Mode: $MODE"
        echo "Root: $ROOT_DIR"
        echo ""
    fi

    check_untracked_files
    [[ "$JSON_MODE" != "true" ]] && echo ""
    check_template_markers
    [[ "$JSON_MODE" != "true" ]] && echo ""
    check_features_drift
    [[ "$JSON_MODE" != "true" ]] && echo ""
    check_context_pack_drift
    [[ "$JSON_MODE" != "true" ]] && echo ""
    check_status_drift
    [[ "$JSON_MODE" != "true" ]] && echo ""
    check_tests_drift
    [[ "$JSON_MODE" != "true" ]] && echo ""
    check_undocumented_code
    [[ "$JSON_MODE" != "true" ]] && echo ""
    check_undocumented_endpoints

    # Output JSON or human-readable summary
    if [[ "$JSON_MODE" == "true" ]]; then
        output_json
    else
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
    fi
}

main "$@"
