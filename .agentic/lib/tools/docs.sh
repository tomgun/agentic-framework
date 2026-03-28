#!/usr/bin/env bash
# docs.sh - Doc lifecycle system: registry reader + trigger dispatcher + context assembler
#
# Reads doc registry from STACK.md ## Docs, filters by trigger, and outputs
# structured context blocks for the Claude agent to act on.
#
# This script is a CONTEXT ASSEMBLER — it does NOT write doc content.
# The Claude agent reads this output and performs the actual drafting.
#
# Usage:
#   bash .agentic/tools/docs.sh --list                              # Show registry
#   bash .agentic/tools/docs.sh --trigger feature_done --manifest F-####  # Feature docs
#   bash .agentic/tools/docs.sh --trigger pr --manifest F-####     # PR docs
#   bash .agentic/tools/docs.sh --trigger session                  # Staleness check
#   bash .agentic/tools/docs.sh --check --manifest F-####          # Dry run
#   bash .agentic/tools/docs.sh --draft <path> --type <type> [--manifest F-####]  # Single doc
#   bash .agentic/tools/docs.sh --validate                         # Registry health check
#   bash .agentic/tools/docs.sh --coverage                         # Area coverage report
#   bash .agentic/tools/docs.sh --create <path> --type <type> --trigger <trigger>  # Scaffold + register
#
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${ROOT_DIR:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
STACK_FILE="$ROOT_DIR/STACK.md"
DOC_TYPES_FILE="$SCRIPT_DIR/../agents/shared/doc_types.md"

# Source settings if available
source "$SCRIPT_DIR/../paths.sh" 2>/dev/null || true

if [[ -f "$SCRIPT_DIR/../settings.sh" ]]; then
    source "$SCRIPT_DIR/../settings.sh"
fi

# Colors
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    BOLD='\033[1m'
    DIM='\033[2m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' BOLD='' DIM='' NC=''
fi

# Default staleness threshold (days)
STALE_DAYS=30
if type get_setting &>/dev/null; then
    STALE_DAYS_SETTING=$(get_setting "docs_stale_days" "30" 2>/dev/null || echo "30")
    STALE_DAYS="${STALE_DAYS_SETTING}"
fi

# ─── Parse arguments ───────────────────────────────────────────────

MODE=""
TRIGGER=""
MANIFEST=""
DRAFT_PATH=""
DRAFT_TYPE=""
CREATE_PATH=""
CREATE_TYPE=""
CREATE_TRIGGER=""
CREATE_FORCE=false
CHECK_ONLY=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --list)
            MODE="list"
            shift
            ;;
        --validate)
            MODE="validate"
            shift
            ;;
        --coverage)
            MODE="coverage"
            shift
            ;;
        --create)
            MODE="create"
            shift
            CREATE_PATH="${1:-}"
            shift
            ;;
        --trigger)
            if [[ "$MODE" == "create" ]]; then
                shift
                CREATE_TRIGGER="${1:-}"
                shift
            elif [[ "$MODE" == "check-freshness" ]]; then
                # --trigger as filter for --check-freshness (don't change MODE)
                shift
                TRIGGER="${1:-}"
                shift
            else
                MODE="trigger"
                shift
                TRIGGER="${1:-}"
                shift
            fi
            ;;
        --check)
            CHECK_ONLY=true
            shift
            ;;
        --check-freshness)
            MODE="check-freshness"
            shift
            ;;
        --manifest)
            shift
            MANIFEST="${1:-}"
            shift
            ;;
        --draft)
            MODE="draft"
            shift
            DRAFT_PATH="${1:-}"
            shift
            ;;
        --type)
            shift
            if [[ "$MODE" == "create" ]]; then
                CREATE_TYPE="${1:-}"
            else
                DRAFT_TYPE="${1:-}"
            fi
            shift
            ;;
        --force)
            CREATE_FORCE=true
            shift
            ;;
        -h|--help)
            echo "Usage: docs.sh [--list | --trigger <trigger> | --check | --draft <path> | --validate | --coverage | --create <path> | --check-freshness]"
            echo "               [--manifest F-####] [--type <type>] [--trigger <trigger>] [--force]"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown argument: $1${NC}" >&2
            exit 1
            ;;
    esac
done

# ─── Parse registry from STACK.md ## Docs ──────────────────────────

# Returns lines of: path|type|trigger|tracks (whitespace-trimmed)
# tracks is an optional 4th field: comma-separated path prefixes the doc covers.
# When present, freshness checks scope to features whose manifest overlaps these paths.
parse_registry() {
    if [[ ! -f "$STACK_FILE" ]]; then
        return
    fi

    local in_docs_section=false
    while IFS= read -r line; do
        # Detect ## Docs section start
        if [[ "$line" =~ ^##[[:space:]]+Docs ]]; then
            in_docs_section=true
            continue
        fi
        # Detect next section (any ## heading)
        if $in_docs_section && [[ "$line" =~ ^##[[:space:]] ]]; then
            break
        fi
        # Parse doc entries: - doc: <path> | <type> | <trigger> [| <tracks>]
        if $in_docs_section && [[ "$line" =~ ^-[[:space:]]*doc:[[:space:]]* ]]; then
            # Strip "- doc: " prefix, then split on |
            local entry="${line#*doc:}"
            local path type trigger tracks
            path=$(echo "$entry" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$1); print $1}')
            type=$(echo "$entry" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$2); print $2}')
            trigger=$(echo "$entry" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$3); print $3}')
            tracks=$(echo "$entry" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$4); print $4}')
            if [[ -n "$path" && -n "$type" && -n "$trigger" ]]; then
                echo "${path}|${type}|${trigger}|${tracks}"
            fi
        fi
    done < "$STACK_FILE"
}

# ─── Check registered files exist ─────────────────────────────────

# Prints one "registered-but-missing" line per issue to stdout.
# Returns 0 if clean, 1 if issues found.
check_registered_exist() {
    local entries
    entries=$(parse_registry)
    [[ -z "$entries" ]] && return 0

    local issues=0
    while IFS='|' read -r path type trigger _tracks; do
        local full_path="$ROOT_DIR/$path"
        if [[ -d "$full_path" ]]; then
            # Directory entry (e.g., docs/adr/) — exists, fine
            continue
        elif [[ ! -f "$full_path" ]]; then
            echo -e "${RED}✗ registered-but-missing: ${path}${NC}"
            issues=$((issues + 1))
        fi
    done <<< "$entries"
    [[ $issues -eq 0 ]] && return 0 || return 1
}

# ─── Find unregistered .md files ─────────────────────────────────

# Scans project for .md files not in the registry.
# Prints one "unregistered" line per issue to stdout.
# Returns 0 if clean, 1 if issues found.
find_unregistered() {
    local entries
    entries=$(parse_registry)

    # Build set of registered paths (normalized, no leading ./)
    local -A registered_paths
    if [[ -n "$entries" ]]; then
        while IFS='|' read -r path type trigger _tracks; do
            registered_paths["$path"]=1
            # If directory entry, mark it so we skip files inside
            if [[ "$path" == */ ]]; then
                registered_paths["__dir__${path}"]=1
            fi
        done <<< "$entries"
    fi

    local issues=0

    # Find all .md files with exclusions
    while IFS= read -r file; do
        # Strip leading ./ for comparison
        local rel="${file#./}"

        # Skip if registered
        [[ -n "${registered_paths[$rel]:-}" ]] && continue

        # Skip if inside a registered directory
        local skip_dir=false
        for key in "${!registered_paths[@]}"; do
            if [[ "$key" == __dir__* ]]; then
                local dir_path="${key#__dir__}"
                if [[ "$rel" == ${dir_path}* ]]; then
                    skip_dir=true
                    break
                fi
            fi
        done
        $skip_dir && continue

        echo -e "${YELLOW}? unregistered: ${rel}${NC}"
        issues=$((issues + 1))
    done < <(
        cd "$ROOT_DIR" && find . -name '*.md' \
            -not -path './.git/*' \
            -not -path './node_modules/*' -not -path './vendor/*' \
            -not -path './dist/*' -not -path './build/*' \
            -not -path './examples/*' \
            -not -path './.agentic/lib/*' \
            -not -path './.agentic/session/*' \
            -not -path './.agentic/journal/*' \
            -not -path './.agentic/spec/acceptance/*' \
            -not -path './.agentic/spec/contracts/*' \
            -not -path './.agentic/spec/migrations/*' \
            -not -path './.claude/*' -not -path './.cursor/*' \
            -not -path './.codex/*' -not -path './.github/*' \
            -not -path './tests/*' -not -path './.pytest_cache/*' \
            -not -name 'STACK.md' -not -name 'CLAUDE.md' \
            -not -name 'CONTEXT_PACK.md' -not -name 'AGENTS.md' \
            -not -name 'SESSION_LOG.md' -not -name 'CODEX.md' \
            -not -name 'STATUS.md' -not -name 'JOURNAL.md' \
            -not -name 'HUMAN_NEEDED.md' -not -name 'TODO.md' \
            -not -name 'FEATURES.md' \
            -not -name '*.template.md' -not -name '*.template-*.md' \
            2>/dev/null | sort
    )

    [[ $issues -eq 0 ]] && return 0 || return 1
}

# ─── Validate registry ───────────────────────────────────────────

validate_registry() {
    echo -e "${BOLD}=== Doc Registry Validation ===${NC}"
    echo ""

    local total_issues=0

    # Part 1: registered-but-missing
    echo -e "${BOLD}Registered-but-missing:${NC}"
    local missing_output
    missing_output=$(check_registered_exist 2>&1) || true
    local missing_count
    missing_count=$(echo "$missing_output" | grep -c "registered-but-missing" || true)
    if [[ $missing_count -gt 0 ]]; then
        echo "$missing_output"
        total_issues=$((total_issues + missing_count))
    else
        echo -e "  ${GREEN}All registered docs exist${NC}"
    fi

    echo ""

    # Part 2: existing-but-unregistered
    echo -e "${BOLD}Existing-but-unregistered:${NC}"
    local unreg_output
    unreg_output=$(find_unregistered 2>&1) || true
    local unreg_count
    unreg_count=$(echo "$unreg_output" | grep -c "unregistered:" || true)
    if [[ $unreg_count -gt 0 ]]; then
        echo "$unreg_output"
        total_issues=$((total_issues + unreg_count))
    else
        echo -e "  ${GREEN}No unregistered docs found${NC}"
    fi

    echo ""
    if [[ $total_issues -gt 0 ]]; then
        echo -e "${YELLOW}${total_issues} issue(s) found${NC}"
        return 1
    else
        echo -e "${GREEN}Registry is healthy${NC}"
        return 0
    fi
}

# ─── Get valid doc types from doc_types.md ────────────────────────

get_valid_types() {
    if [[ ! -f "$DOC_TYPES_FILE" ]]; then
        echo "changelog readme lessons architecture adr runbook tech-spec custom"
        return
    fi
    # Only extract type headings (## at top level, not inside code blocks)
    awk '
        /^```/ { in_block = !in_block; next }
        !in_block && /^## / {
            sub(/^## /, "")
            if ($0 != "Doc Types Reference" && $0 !~ /^#/) print
        }
    ' "$DOC_TYPES_FILE" | tr '\n' ' '
}

# ─── Extract template for a doc type ─────────────────────────────

extract_template() {
    local doc_type="$1"
    if [[ ! -f "$DOC_TYPES_FILE" ]]; then
        echo "# $(echo "$doc_type" | sed 's/.*/\u&/')"
        return
    fi
    # Extract content between the LAST ``` fences under the matching ## type heading
    # (the "New file template" block is always last in the section)
    local found=false in_block=false
    local template_lines=()
    while IFS= read -r line; do
        if [[ "$line" == "## $doc_type" ]]; then
            found=true
            continue
        fi
        # Only break on next ## heading when NOT inside a code block
        if $found && ! $in_block && [[ "$line" =~ ^##\  ]]; then
            break
        fi
        if $found && [[ "$line" == '```' ]]; then
            if $in_block; then
                # End of code block — save captured lines as template
                in_block=false
            else
                # Start of code block — begin capturing
                in_block=true
                template_lines=()
            fi
            continue
        fi
        if $found && $in_block; then
            template_lines+=("$line")
        fi
    done < "$DOC_TYPES_FILE"

    # Output the last captured template
    for tl in "${template_lines[@]}"; do
        echo "$tl"
    done
}

# ─── Create doc + register ────────────────────────────────────────

create_doc() {
    local doc_path="$1"
    local doc_type="$2"
    local doc_trigger="$3"
    local force="$4"

    # Validate type
    local valid_types
    valid_types=$(get_valid_types)
    local type_valid=false
    for t in $valid_types; do
        if [[ "$t" == "$doc_type" ]]; then
            type_valid=true
            break
        fi
    done
    if ! $type_valid; then
        echo -e "${RED}Error: invalid type '${doc_type}'. Valid types: ${valid_types}${NC}" >&2
        return 1
    fi

    # Validate trigger
    if [[ ! "$doc_trigger" =~ ^(feature_done|pr|session|manual)$ ]]; then
        echo -e "${RED}Error: invalid trigger '${doc_trigger}'. Valid: feature_done, pr, session, manual${NC}" >&2
        return 1
    fi

    local full_path="$ROOT_DIR/$doc_path"

    # Check if already registered (idempotency)
    local entries
    entries=$(parse_registry)
    if [[ -n "$entries" ]]; then
        while IFS='|' read -r path type trigger _tracks; do
            if [[ "$path" == "$doc_path" ]]; then
                echo -e "${YELLOW}Already registered: ${doc_path} (type: ${type}, trigger: ${trigger})${NC}"
                return 0
            fi
        done <<< "$entries"
    fi

    # Check if file exists
    if [[ -f "$full_path" ]] && ! $force; then
        echo -e "${RED}Error: file already exists: ${doc_path}. Use --force to register without overwriting.${NC}" >&2
        return 1
    fi

    # Step 1: Register in STACK.md first (so no orphan on failure)
    if [[ ! -f "$STACK_FILE" ]]; then
        echo -e "${RED}Error: STACK.md not found at ${STACK_FILE}${NC}" >&2
        return 1
    fi

    # Find the line number of the next ## heading after ## Docs
    local insert_line
    insert_line=$(awk '
        /^## Docs/ { in_docs=1; next }
        in_docs && /^## / { print NR; exit }
    ' "$STACK_FILE")

    if [[ -z "$insert_line" ]]; then
        # ## Docs is the last section — append before EOF
        insert_line=$(wc -l < "$STACK_FILE")
        insert_line=$((insert_line + 1))
    fi

    # Format entry to match existing alignment
    local entry="- doc: ${doc_path}"
    # Pad to align pipe columns (aim for ~40 char path column)
    local pad_len=$((40 - ${#doc_path}))
    [[ $pad_len -lt 1 ]] && pad_len=1
    local padding
    padding=$(printf '%*s' "$pad_len" '')
    entry="${entry}${padding}| ${doc_type}"
    # Pad type column to ~15 chars
    local type_pad=$((15 - ${#doc_type}))
    [[ $type_pad -lt 1 ]] && type_pad=1
    local type_padding
    type_padding=$(printf '%*s' "$type_pad" '')
    entry="${entry}${type_padding}| ${doc_trigger}"

    # Insert the entry
    sed -i "${insert_line}i\\${entry}" "$STACK_FILE"

    # Step 2: Create the file (if it doesn't exist or --force)
    if [[ ! -f "$full_path" ]]; then
        # Ensure directory exists
        mkdir -p "$(dirname "$full_path")"
        local template
        template=$(extract_template "$doc_type")
        if [[ -n "$template" ]]; then
            echo "$template" > "$full_path"
        else
            echo "# $(basename "$doc_path" .md)" > "$full_path"
        fi
        echo -e "${GREEN}✓ Created: ${doc_path}${NC}"
    else
        echo -e "${GREEN}✓ File exists, registered only: ${doc_path}${NC}"
    fi

    echo -e "${GREEN}✓ Registered in STACK.md: ${doc_path} | ${doc_type} | ${doc_trigger}${NC}"
    return 0
}

# ─── Coverage report ──────────────────────────────────────────────

show_coverage() {
    local entries
    entries=$(parse_registry)

    if [[ -z "$entries" ]]; then
        echo "No docs registered in STACK.md ## Docs"
        return 0
    fi

    echo -e "${BOLD}Doc Coverage by Type${NC}"
    echo ""

    # Collect types and their docs
    local -A type_docs
    local -A type_counts
    while IFS='|' read -r path type trigger _tracks; do
        type_counts["$type"]=$(( ${type_counts["$type"]:-0} + 1 ))
        if [[ -n "${type_docs[$type]:-}" ]]; then
            type_docs["$type"]="${type_docs[$type]}"$'\n'"    ${path}"
        else
            type_docs["$type"]="    ${path}"
        fi
    done <<< "$entries"

    # Known types from doc_types.md
    local known_types
    known_types=$(get_valid_types)

    # Print coverage for each known type
    for t in $known_types; do
        local count="${type_counts[$t]:-0}"
        if [[ $count -gt 0 ]]; then
            echo -e "  ${GREEN}${t}${NC}: ${count} doc(s)"
            echo "${type_docs[$t]}"
        else
            echo -e "  ${YELLOW}${t}${NC}: 0 docs"
        fi
    done

    # Print any custom types not in the known list
    for t in "${!type_counts[@]}"; do
        local is_known=false
        for kt in $known_types; do
            [[ "$kt" == "$t" ]] && is_known=true && break
        done
        if ! $is_known; then
            echo -e "  ${BLUE}${t}${NC}: ${type_counts[$t]} doc(s)"
            echo "${type_docs[$t]}"
        fi
    done
}

# ─── Check for existing draft markers ──────────────────────────────

has_draft_marker() {
    local file="$1"
    [[ -f "$file" ]] && grep -q '<!-- draft:' "$file" 2>/dev/null
}

# ─── Assemble context for a single doc ─────────────────────────────

assemble_context() {
    local doc_path="$1"
    local doc_type="$2"
    local feature_id="$3"

    echo "=== DOC DRAFT CONTEXT ==="
    echo "Path: $doc_path"
    echo "Type: $doc_type"
    echo "Feature: ${feature_id:-none}"
    echo "Date: $(date +%Y-%m-%d)"

    # File status
    local full_path="$ROOT_DIR/$doc_path"
    if [[ -f "$full_path" ]]; then
        echo "Status: existing"
        echo ""
        echo "--- Current content (first 50 lines) ---"
        head -50 "$full_path" 2>/dev/null
        echo ""
        echo "--- End current content ---"
    else
        echo "Status: [new file]"
    fi

    # Manifest context
    if [[ -n "$feature_id" ]]; then
        local manifest_json="$ROOT_DIR/.agentic/journal/manifests/${feature_id}.json"
        local manifest_md="$ROOT_DIR/.agentic/journal/manifests/${feature_id}.manifest.md"
        if [[ -f "$manifest_json" ]]; then
            echo ""
            echo "--- Feature manifest (JSON) ---"
            cat "$manifest_json"
            echo ""
            echo "--- End manifest ---"
        elif [[ -f "$manifest_md" ]]; then
            echo ""
            echo "--- Feature manifest ---"
            head -40 "$manifest_md"
            echo ""
            echo "--- End manifest ---"
        fi

        # Contract/acceptance criteria (check contracts first, then legacy)
        local acc_file=""
        if [[ -f "$CONTRACTS_DIR/${feature_id}.yaml" ]]; then
            acc_file="$CONTRACTS_DIR/${feature_id}.yaml"
        elif [[ -f "$ACCEPTANCE_DIR/${feature_id}.md" ]]; then
            acc_file="$ACCEPTANCE_DIR/${feature_id}.md"
        fi
        if [[ -n "$acc_file" && -f "$acc_file" ]]; then
            echo ""
            echo "--- Contract/acceptance criteria ---"
            cat "$acc_file"
            echo ""
            echo "--- End contract/acceptance ---"
        fi
    fi

    # Doc type guidance
    if [[ -f "$DOC_TYPES_FILE" ]]; then
        echo ""
        echo "--- Doc type guidance ---"
        # Extract the section for this type
        awk -v type="## $doc_type" '
            $0 == type { found=1; next }
            found && /^## / { exit }
            found { print }
        ' "$DOC_TYPES_FILE"
        echo "--- End guidance ---"
    fi

    echo ""
    echo "=== END DOC DRAFT CONTEXT ==="
}

# ─── Staleness check ───────────────────────────────────────────────

check_staleness() {
    local entries
    entries=$(parse_registry)

    if [[ -z "$entries" ]]; then
        echo "No docs registered in STACK.md ## Docs"
        return
    fi

    local stale_count=0
    local now
    now=$(date +%s)

    while IFS='|' read -r path type trigger _tracks; do
        local full_path="$ROOT_DIR/$path"
        if [[ -f "$full_path" ]]; then
            local mod_time
            if [[ "$(uname)" == "Darwin" ]]; then
                mod_time=$(stat -f '%m' "$full_path" 2>/dev/null || echo "0")
            else
                mod_time=$(stat -c '%Y' "$full_path" 2>/dev/null || echo "0")
            fi
            local days_old=$(( (now - mod_time) / 86400 ))
            if [[ "$days_old" -ge "$STALE_DAYS" ]]; then
                echo -e "${YELLOW}⚠ ${path}: last modified ${days_old} days ago (stale_days: ${STALE_DAYS})${NC}"
                stale_count=$((stale_count + 1))
            fi
        elif [[ ! -d "$full_path" ]]; then
            # Reuse shared check — file doesn't exist
            echo -e "${YELLOW}⚠ ${path}: file does not exist${NC}"
            stale_count=$((stale_count + 1))
        fi
    done <<< "$entries"

    if [[ "$stale_count" -eq 0 ]]; then
        echo -e "${GREEN}All registered docs are fresh (within ${STALE_DAYS} days)${NC}"
    else
        echo ""
        echo -e "${YELLOW}${stale_count} doc(s) may need attention${NC}"
    fi
}

# ─── Freshness check (git-based, deterministic) ──────────────────

# Detect the base branch (not hardcoded)
detect_base_branch() {
    local base=""
    # Try origin/HEAD first (works when remote is configured)
    if git -C "$ROOT_DIR" rev-parse --verify origin/HEAD &>/dev/null; then
        base=$(git -C "$ROOT_DIR" rev-parse --abbrev-ref origin/HEAD 2>/dev/null | sed 's|origin/||')
    fi
    # Validate result — reject empty or literal "HEAD" (no-remote fallback)
    if [[ -z "$base" || "$base" == "HEAD" ]]; then
        # Fallback: check for main or master
        if git -C "$ROOT_DIR" rev-parse --verify main &>/dev/null; then
            base="main"
        elif git -C "$ROOT_DIR" rev-parse --verify master &>/dev/null; then
            base="master"
        else
            base="main"
        fi
    fi
    echo "$base"
}

# Check freshness of registered docs.
# Returns 0 if all fresh, 1 if any stale. Prints stale list to stdout.
# Usage: check_freshness [trigger_filter] [manifest_id]
#   trigger_filter: only check docs with this trigger (default: feature_done)
#   manifest_id: feature ID (e.g. F-035) — when provided with tracks field,
#                only docs whose tracked paths overlap the manifest are checked
check_freshness() {
    local trigger_filter="${1:-feature_done}"
    local manifest_id="${2:-}"
    local entries
    entries=$(parse_registry)
    [[ -z "$entries" ]] && return 0

    # Load manifest files if available (all categories: code, tests, docs, config)
    local manifest_files=""
    if [[ -n "$manifest_id" ]]; then
        local manifest_path="$ROOT_DIR/.agentic/journal/manifests/${manifest_id}.json"
        if [[ -f "$manifest_path" ]]; then
            # Extract "file" values from manifest JSON using grep+sed (no python/jq dependency)
            manifest_files=$(grep -o '"file"[[:space:]]*:[[:space:]]*"[^"]*"' "$manifest_path" \
                | sed 's/"file"[[:space:]]*:[[:space:]]*"//;s/"$//' || true)
        fi
    fi

    local base_branch
    base_branch=$(detect_base_branch)
    local current_branch
    current_branch=$(git -C "$ROOT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

    # Get files changed in branch (empty if on base branch or base not available)
    local branch_files=""
    if [[ -n "$current_branch" && "$current_branch" != "$base_branch" ]]; then
        # Verify merge-base exists (fails in shallow clones without base ref)
        if git -C "$ROOT_DIR" merge-base "$base_branch" HEAD &>/dev/null; then
            branch_files=$(git -C "$ROOT_DIR" diff --name-only "${base_branch}...HEAD" 2>/dev/null || true)
        fi
    fi

    # Get files changed in last 5 commits
    local recent_files=""
    recent_files=$(git -C "$ROOT_DIR" log -5 --diff-filter=AMCR --name-only --pretty=format: HEAD 2>/dev/null | sort -u || true)

    local stale_count=0
    local skipped_count=0

    while IFS='|' read -r path type trigger tracks; do
        # Filter by trigger
        [[ "$trigger" != "$trigger_filter" ]] && continue

        local full_path="$ROOT_DIR/$path"

        # Directory entries — skip freshness (tracked differently)
        if [[ "$path" == */ ]]; then
            continue
        fi

        # Scope filtering: if manifest provided AND doc has tracks, skip docs
        # whose tracked paths don't overlap with the feature's changed files.
        # tracks is a comma-separated list of path prefixes (e.g. ".agentic/lib/,src/api/")
        if [[ -n "$manifest_files" && -n "$tracks" ]]; then
            local has_overlap=false
            # Split tracks on comma
            IFS=',' read -ra track_prefixes <<< "$tracks"
            for prefix in "${track_prefixes[@]}"; do
                # Trim whitespace (parameter expansion, no subprocess)
                prefix="${prefix#"${prefix%%[![:space:]]*}"}"
                prefix="${prefix%"${prefix##*[![:space:]]}"}"
                [[ -z "$prefix" ]] && continue
                # Check if any manifest file starts with this prefix (literal match, not regex)
                if echo "$manifest_files" | grep -qF "$prefix"; then
                    has_overlap=true
                    break
                fi
            done
            if [[ "$has_overlap" == "false" ]]; then
                skipped_count=$((skipped_count + 1))
                continue
            fi
        fi

        # File doesn't exist → STALE
        if [[ ! -f "$full_path" ]]; then
            echo -e "${RED}✗ stale (missing): ${path}${NC}"
            stale_count=$((stale_count + 1))
            continue
        fi

        # File in branch diff → FRESH
        if [[ -n "$branch_files" ]] && echo "$branch_files" | grep -qx "$path"; then
            continue
        fi

        # File in last 5 commits → FRESH
        if [[ -n "$recent_files" ]] && echo "$recent_files" | grep -qx "$path"; then
            continue
        fi

        # Otherwise → STALE
        echo -e "${YELLOW}✗ stale: ${path}${NC}"
        stale_count=$((stale_count + 1))
    done <<< "$entries"

    if [[ "$stale_count" -eq 0 ]]; then
        local msg="All ${trigger_filter} docs are fresh"
        if [[ "$skipped_count" -gt 0 ]]; then
            msg="${msg} (${skipped_count} skipped — not relevant to feature)"
        fi
        echo -e "${GREEN}${msg}${NC}"
        return 0
    else
        echo ""
        echo -e "${RED}${stale_count} doc(s) need updating (trigger: ${trigger_filter})${NC}"
        if [[ "$skipped_count" -gt 0 ]]; then
            echo -e "${DIM}(${skipped_count} doc(s) skipped — tracked paths don't overlap feature manifest)${NC}"
        fi
        return 1
    fi
}

# ─── Main ──────────────────────────────────────────────────────────

case "$MODE" in
    list)
        entries=$(parse_registry)
        if [[ -z "$entries" ]]; then
            echo "No docs registered in STACK.md ## Docs"
            exit 0
        fi
        echo -e "${BOLD}Doc Registry (from STACK.md ## Docs)${NC}"
        echo ""
        # Check if any entry has tracks configured
        local has_any_tracks=false
        if echo "$entries" | grep -q '|[^|]*|[^|]*|[^|]'; then
            has_any_tracks=true
        fi
        if $has_any_tracks; then
            printf "  %-35s %-15s %-14s %s\n" "PATH" "TYPE" "TRIGGER" "TRACKS"
            printf "  %-35s %-15s %-14s %s\n" "----" "----" "-------" "------"
            while IFS='|' read -r path type trigger tracks; do
                printf "  %-35s %-15s %-14s %s\n" "$path" "$type" "$trigger" "$tracks"
            done <<< "$entries"
        else
            printf "  %-30s %-15s %s\n" "PATH" "TYPE" "TRIGGER"
            printf "  %-30s %-15s %s\n" "----" "----" "-------"
            while IFS='|' read -r path type trigger _tracks; do
                printf "  %-30s %-15s %s\n" "$path" "$type" "$trigger"
            done <<< "$entries"
        fi
        ;;

    trigger)
        if [[ -z "$TRIGGER" ]]; then
            echo -e "${RED}Error: --trigger requires a value (feature_done | pr | session | manual)${NC}" >&2
            exit 1
        fi

        if [[ "$TRIGGER" == "session" ]]; then
            check_staleness
            exit 0
        fi

        entries=$(parse_registry)
        if [[ -z "$entries" ]]; then
            echo "No docs registered in STACK.md ## Docs"
            exit 0
        fi

        # Filter by trigger
        matched=()
        while IFS='|' read -r path type trigger _tracks; do
            if [[ "$trigger" == "$TRIGGER" ]]; then
                matched+=("${path}|${type}|${trigger}")
            fi
        done <<< "$entries"

        if [[ ${#matched[@]} -eq 0 ]]; then
            echo "No docs match trigger '$TRIGGER'"
            exit 0
        fi

        echo -e "${BOLD}=== Doc Lifecycle: trigger=$TRIGGER ===${NC}"
        echo ""

        for entry in "${matched[@]}"; do
            IFS='|' read -r path type trigger _tracks <<< "$entry"
            local_path="$ROOT_DIR/$path"

            # Check for existing draft marker
            if has_draft_marker "$local_path"; then
                echo -e "${YELLOW}⚠ ${path}: existing draft marker found (previous draft not reviewed) — skipping${NC}"
                continue
            fi

            if $CHECK_ONLY; then
                echo -e "  Would draft: ${BLUE}${path}${NC} (type: ${type})"
            else
                echo -e "${BOLD}--- Drafting: ${path} (${type}) ---${NC}"
                assemble_context "$path" "$type" "$MANIFEST"
                echo ""
            fi
        done

        if $CHECK_ONLY; then
            echo ""
            echo -e "${DIM}Dry run — no files modified${NC}"
        fi
        ;;

    draft)
        if [[ -z "$DRAFT_PATH" || -z "$DRAFT_TYPE" ]]; then
            echo -e "${RED}Error: --draft requires <path> and --type <type>${NC}" >&2
            exit 1
        fi

        local_path="$ROOT_DIR/$DRAFT_PATH"
        if has_draft_marker "$local_path"; then
            echo -e "${YELLOW}⚠ ${DRAFT_PATH}: existing draft marker found (previous draft not reviewed) — skipping${NC}"
            exit 0
        fi

        if $CHECK_ONLY; then
            echo -e "  Would draft: ${BLUE}${DRAFT_PATH}${NC} (type: ${DRAFT_TYPE})"
            echo -e "${DIM}Dry run — no files modified${NC}"
        else
            echo -e "${BOLD}--- Drafting: ${DRAFT_PATH} (${DRAFT_TYPE}) ---${NC}"
            assemble_context "$DRAFT_PATH" "$DRAFT_TYPE" "$MANIFEST"
        fi
        ;;

    validate)
        validate_registry
        ;;

    coverage)
        show_coverage
        ;;

    check-freshness)
        # Use TRIGGER if provided via --trigger, otherwise default to feature_done
        # Pass MANIFEST to scope freshness check to relevant docs
        check_freshness "${TRIGGER:-feature_done}" "$MANIFEST"
        ;;

    create)
        if [[ -z "$CREATE_PATH" ]]; then
            echo -e "${RED}Error: --create requires <path>${NC}" >&2
            exit 1
        fi
        if [[ -z "$CREATE_TYPE" ]]; then
            echo -e "${RED}Error: --create requires --type <type>${NC}" >&2
            exit 1
        fi
        if [[ -z "$CREATE_TRIGGER" ]]; then
            echo -e "${RED}Error: --create requires --trigger <trigger>${NC}" >&2
            exit 1
        fi
        create_doc "$CREATE_PATH" "$CREATE_TYPE" "$CREATE_TRIGGER" "$CREATE_FORCE"
        ;;

    "")
        echo "Usage: docs.sh [--list | --trigger <trigger> | --check | --draft <path> | --validate | --coverage | --create <path> | --check-freshness]"
        echo "               [--manifest F-####] [--type <type>] [--trigger <trigger>] [--force]"
        echo ""
        echo "Commands:"
        echo "  --list                          Show doc registry from STACK.md"
        echo "  --trigger <trigger>             Run docs for trigger (feature_done|pr|session|manual)"
        echo "  --check                         Dry run (combine with --trigger or --draft)"
        echo "  --check-freshness               Check if registered docs are fresh (git-based)"
        echo "  --draft <path> --type <type>    Draft a single doc"
        echo "  --validate                      Registry health check (registered-but-missing + unregistered)"
        echo "  --coverage                      Show doc coverage by type"
        echo "  --create <path> --type <type> --trigger <trigger>  Scaffold doc + register"
        echo ""
        echo "Options:"
        echo "  --manifest F-####              Feature ID for context (scopes freshness to relevant docs)"
        echo "  --trigger <trigger>             Filter for --check-freshness (default: feature_done)"
        echo ""
        echo "Registry format (STACK.md ## Docs):"
        echo "  - doc: <path> | <type> | <trigger> [| <tracks>]"
        echo "  tracks: comma-separated path prefixes the doc covers (optional)"
        echo "  When --manifest is provided, docs with tracks are only checked if"
        echo "  the feature's changed files overlap their tracked paths."
        echo "  --force                         Allow --create to register existing files"
        exit 0
        ;;

    *)
        echo -e "${RED}Unknown mode: $MODE${NC}" >&2
        exit 1
        ;;
esac
