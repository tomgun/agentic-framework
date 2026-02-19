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
#
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${ROOT_DIR:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
STACK_FILE="$ROOT_DIR/STACK.md"
DOC_TYPES_FILE="$SCRIPT_DIR/../agents/shared/doc_types.md"

# Source settings if available
if [[ -f "$SCRIPT_DIR/../lib/settings.sh" ]]; then
    source "$SCRIPT_DIR/../lib/settings.sh"
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
CHECK_ONLY=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --list)
            MODE="list"
            shift
            ;;
        --trigger)
            MODE="trigger"
            shift
            TRIGGER="${1:-}"
            shift
            ;;
        --check)
            CHECK_ONLY=true
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
            DRAFT_TYPE="${1:-}"
            shift
            ;;
        -h|--help)
            echo "Usage: docs.sh [--list | --trigger <trigger> | --check | --draft <path>] [--manifest F-####] [--type <type>]"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown argument: $1${NC}" >&2
            exit 1
            ;;
    esac
done

# ─── Parse registry from STACK.md ## Docs ──────────────────────────

# Returns lines of: path|type|trigger (whitespace-trimmed)
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
        # Parse doc entries: - doc: <path> | <type> | <trigger>
        if $in_docs_section && [[ "$line" =~ ^-[[:space:]]*doc:[[:space:]]* ]]; then
            # Strip "- doc: " prefix, then split on |
            local entry="${line#*doc:}"
            local path type trigger
            path=$(echo "$entry" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$1); print $1}')
            type=$(echo "$entry" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$2); print $2}')
            trigger=$(echo "$entry" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$3); print $3}')
            if [[ -n "$path" && -n "$type" && -n "$trigger" ]]; then
                echo "${path}|${type}|${trigger}"
            fi
        fi
    done < "$STACK_FILE"
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
        local manifest_json="$ROOT_DIR/.agentic-journal/manifests/${feature_id}.json"
        local manifest_md="$ROOT_DIR/.agentic-journal/manifests/${feature_id}.manifest.md"
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

        # Acceptance criteria
        local acc_file="$ROOT_DIR/spec/acceptance/${feature_id}.md"
        if [[ -f "$acc_file" ]]; then
            echo ""
            echo "--- Acceptance criteria ---"
            cat "$acc_file"
            echo ""
            echo "--- End acceptance ---"
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

    while IFS='|' read -r path type trigger; do
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
            # File doesn't exist (and it's not a directory like docs/adr/)
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
        printf "  %-30s %-15s %s\n" "PATH" "TYPE" "TRIGGER"
        printf "  %-30s %-15s %s\n" "----" "----" "-------"
        while IFS='|' read -r path type trigger; do
            printf "  %-30s %-15s %s\n" "$path" "$type" "$trigger"
        done <<< "$entries"
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
        while IFS='|' read -r path type trigger; do
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
            IFS='|' read -r path type trigger <<< "$entry"
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

    "")
        echo "Usage: docs.sh [--list | --trigger <trigger> | --check | --draft <path>] [--manifest F-####] [--type <type>]"
        echo ""
        echo "Commands:"
        echo "  --list                          Show doc registry from STACK.md"
        echo "  --trigger <trigger>             Run docs for trigger (feature_done|pr|session|manual)"
        echo "  --check                         Dry run (combine with --trigger or --draft)"
        echo "  --draft <path> --type <type>    Draft a single doc"
        echo ""
        echo "Options:"
        echo "  --manifest F-####              Feature ID for context"
        exit 0
        ;;

    *)
        echo -e "${RED}Unknown mode: $MODE${NC}" >&2
        exit 1
        ;;
esac
