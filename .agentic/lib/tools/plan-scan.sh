#!/usr/bin/env bash
# plan-scan.sh — Scan ephemeral plan directories for unsaved plans
#
# Scans known tool-specific plan directories for files that reference F-XXXX
# feature IDs and copies unsaved plans to the durable .agentic/journal/plans/
# directory. Agent-agnostic: supports Claude, Cursor, and is extensible via
# STACK.md plan_scan_dirs setting.
#
# Usage:
#   bash .agentic/lib/tools/plan-scan.sh              # Verbose output
#   bash .agentic/lib/tools/plan-scan.sh --quiet       # One-line summary only
#   bash .agentic/lib/tools/plan-scan.sh --check       # Dry run: report only, no copy
#
# ID detection strategy (priority order):
#   1. Epic ID (E-XXXX) from "Epic ID:" metadata or "# Epic Plan:" heading
#   2. Feature ID (F-XXXX) from heading, title, or "Feature:" metadata
#   - Verify the ID belongs to this project (FEATURES.md for F-*, feature refs for E-*)
#   - Plans without a clear primary ID are saved with a title-based slug
#
# Dedup strategy:
#   1. Filename match: checks for *{ID}*plan* in durable plans directory
#   2. Content hash: catches duplicates saved under different names (e.g., E-0001 vs F-0219)
#
# Naming convention:
#   - Feature plans: YYYY-MM-DD-F-XXXX-<slug>-plan.md
#   - Epic plans: YYYY-MM-DD-E-XXXX-<slug>-plan.md
#   - Generic plans: YYYY-MM-DD-<slug>-plan.md (no ID, title-derived slug)
#
# Exit code: always 0 (advisory tool).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source paths (provides PLANS_DIR, PROJECT_ROOT, FEATURES_FILE, etc.)
source "$SCRIPT_DIR/../paths.sh"
source "$SCRIPT_DIR/../settings.sh"

# --- Parse flags ---
QUIET=false
CHECK_ONLY=false
for arg in "$@"; do
    case "$arg" in
        --quiet) QUIET=true ;;
        --check) CHECK_ONLY=true ;;
        -h|--help)
            echo "Usage: bash .agentic/lib/tools/plan-scan.sh [--quiet|--check]"
            echo ""
            echo "  (no flags)  Scan and copy unsaved plans (verbose)"
            echo "  --quiet     One-line summary only"
            echo "  --check     Dry run: report only, no copy"
            exit 0
            ;;
    esac
done

# --- Build list of directories to scan ---
# Default ephemeral plan locations (agent-agnostic)
SCAN_DIRS=()

# Claude Code: ~/.claude/plans/
if [[ -d "${HOME}/.claude/plans" ]]; then
    SCAN_DIRS+=("${HOME}/.claude/plans")
fi

# Cursor: .cursor/plans/ (project-local)
if [[ -d "${PROJECT_ROOT}/.cursor/plans" ]]; then
    SCAN_DIRS+=("${PROJECT_ROOT}/.cursor/plans")
fi

# Extensible: additional dirs from STACK.md setting (comma-separated)
EXTRA_DIRS="$(get_setting "plan_scan_dirs" "")"
if [[ -n "$EXTRA_DIRS" ]]; then
    IFS=',' read -ra EXTRA_ARRAY <<< "$EXTRA_DIRS"
    for dir in "${EXTRA_ARRAY[@]}"; do
        # Trim whitespace and expand ~
        dir="$(echo "$dir" | xargs)"
        dir="${dir/#\~/$HOME}"
        if [[ -d "$dir" ]]; then
            SCAN_DIRS+=("$dir")
        fi
    done
fi

# --- Ensure durable plans directory exists ---
mkdir -p "$PLANS_DIR"

# --- Build set of known feature IDs from this project ---
# This prevents copying plans that belong to OTHER projects
_known_features=""
if [[ -f "$FEATURES_FILE" ]]; then
    _known_features=$(grep -oE "$FEATURE_ID_ERE" "$FEATURES_FILE" 2>/dev/null | sort -u || true)
fi

# --- Helper: extract primary ID from a plan file ---
# Looks at the first 10 lines for a clear feature or epic reference.
# Priority: Epic ID (E-XXXX) > Feature ID in heading > Feature ID in metadata.
# Returns empty string if no primary ID found.
# EPIC_ID_ERE sourced from ids.sh (via paths.sh)

extract_primary_id() {
    local file="$1"
    local header
    header=$(head -30 "$file" 2>/dev/null || true)

    # Pattern 0: Epic ID — "Epic ID: E-XXXX" or "**Epic ID**: E-XXXX"
    local eid
    eid=$(echo "$header" | grep -iE "(epic.id|epic)[:\*]*\s*$EPIC_ID_ERE" | grep -oE "$EPIC_ID_ERE" | head -1 || true)
    if [[ -n "$eid" ]]; then
        echo "$eid"
        return
    fi

    # Pattern 0b: "# Epic Plan:" with E-XXXX anywhere in header
    if echo "$header" | grep -qiE "^#.*epic"; then
        eid=$(echo "$header" | grep -oE "$EPIC_ID_ERE" | head -1 || true)
        if [[ -n "$eid" ]]; then
            echo "$eid"
            return
        fi
    fi

    # Pattern 1: "# F-XXXX:" or "## F-XXXX:" (feature ID in heading)
    local fid
    fid=$(echo "$header" | grep -oE "^#+ $FEATURE_ID_ERE" | head -1 | grep -oE "$FEATURE_ID_ERE" || true)
    if [[ -n "$fid" ]]; then
        echo "$fid"
        return
    fi

    # Pattern 2: "F-XXXX" in the first heading line (e.g., "# Plan: Implement F-0198")
    fid=$(echo "$header" | grep -E '^#' | head -1 | grep -oE "$FEATURE_ID_ERE" | head -1 || true)
    if [[ -n "$fid" ]]; then
        echo "$fid"
        return
    fi

    # Pattern 3: "**Feature**: F-XXXX" or "Feature: F-XXXX" in metadata
    fid=$(echo "$header" | grep -iE "(feature|feature.id)[:\*]*\s*$FEATURE_ID_ERE" | grep -oE "$FEATURE_ID_ERE" | head -1 || true)
    if [[ -n "$fid" ]]; then
        echo "$fid"
        return
    fi

    # Pattern 4: most-referenced F-XXXX in full content (3+ mentions = likely primary)
    fid=$(grep -oE "$FEATURE_ID_ERE" "$file" 2>/dev/null | sort | uniq -c | sort -rn | head -1 | awk '$1 >= 3 { print $2 }' || true)
    if [[ -n "$fid" ]]; then
        echo "$fid"
        return
    fi

    # No primary ID found — plan may not have a feature assigned yet
    echo ""
}

# --- Helper: generate a slug from the plan's first heading ---
# Extracts first markdown heading, lowercases, strips non-alnum, truncates.
# Returns empty string if no heading found.
extract_slug() {
    local file="$1"
    local heading
    heading=$(head -5 "$file" 2>/dev/null | grep -E '^#' | head -1 | sed 's/^#\+ *//' || true)
    [[ -z "$heading" ]] && return

    # Lowercase, replace non-alphanumeric with hyphens, collapse, trim
    echo "$heading" \
        | tr '[:upper:]' '[:lower:]' \
        | sed 's/[^a-z0-9]/-/g' \
        | sed 's/--*/-/g' \
        | sed 's/^-//;s/-$//' \
        | cut -c1-60
}

# --- Scan for unsaved plans ---
FOUND_COUNT=0
COPIED_COUNT=0
SKIPPED_COUNT=0
COPIED_PLANS=()

for scan_dir in "${SCAN_DIRS[@]}"; do
    for plan_file in "$scan_dir"/*; do
        [[ -f "$plan_file" ]] || continue

        # Extract primary ID (E-XXXX for epics, F-XXXX for features)
        primary_id=$(extract_primary_id "$plan_file")

        # Determine how to name/dedup this plan
        slug=""
        if [[ -n "$primary_id" ]]; then
            # Verify this ID belongs to THIS project
            # For feature IDs: check FEATURES.md. For epic IDs: accept if any feature ref matches.
            if [[ "$primary_id" == F-* && -n "$_known_features" ]]; then
                if ! echo "$_known_features" | grep -qF "$primary_id"; then
                    continue
                fi
            elif [[ "$primary_id" == E-* && -n "$_known_features" ]]; then
                # Epic: check if the plan references any known feature
                plan_fids=$(grep -oE "$FEATURE_ID_ERE" "$plan_file" 2>/dev/null | sort -u || true)
                has_match=false
                for pfid in $plan_fids; do
                    if echo "$_known_features" | grep -qF "$pfid"; then
                        has_match=true
                        break
                    fi
                done
                [[ "$has_match" == false ]] && continue
            fi
        else
            # No feature/epic ID — check if plan references ANY known feature
            # (belongs to this project even without a primary ID)
            if [[ -n "$_known_features" ]]; then
                plan_fids=$(grep -oE "$FEATURE_ID_ERE" "$plan_file" 2>/dev/null | sort -u || true)
                has_match=false
                for pfid in $plan_fids; do
                    if echo "$_known_features" | grep -qF "$pfid"; then
                        has_match=true
                        break
                    fi
                done
                [[ "$has_match" == false ]] && continue
            else
                # No known features at all — can't verify ownership, skip
                continue
            fi

            # Generate slug from title for naming
            slug=$(extract_slug "$plan_file")
            [[ -z "$slug" ]] && continue
        fi

        ((FOUND_COUNT++))

        # Check 1: filename match — any file with the primary ID or slug in PLANS_DIR
        local_plan_exists=false
        match_pattern="${primary_id:-$slug}"
        for existing in "$PLANS_DIR"/*"${match_pattern}"*plan*; do
            if [[ -f "$existing" ]]; then
                local_plan_exists=true
                break
            fi
        done

        # Check 2: content hash — catch duplicates saved under different names
        # Normalizes content before hashing: strips Status markers, blank lines,
        # and leading whitespace so minor edits (status changes, reformatting)
        # don't defeat the hash match.
        if [[ "$local_plan_exists" == false ]]; then
            plan_hash=""
            for existing in "$PLANS_DIR"/*plan*; do
                [[ -f "$existing" ]] || continue
                # Lazy-compute: normalize orphan on first comparison
                if [[ -z "$plan_hash" ]]; then
                    plan_hash=$(grep -vE '^\*\*Status\*\*:|^[[:space:]]*$' "$plan_file" 2>/dev/null | sed 's/^[[:space:]]*//' | md5sum | cut -d' ' -f1 || true)
                fi
                existing_hash=$(grep -vE '^\*\*Status\*\*:|^[[:space:]]*$' "$existing" 2>/dev/null | sed 's/^[[:space:]]*//' | md5sum | cut -d' ' -f1 || true)
                if [[ "$plan_hash" == "$existing_hash" ]]; then
                    local_plan_exists=true
                    break
                fi
            done
        fi

        if [[ "$local_plan_exists" == true ]]; then
            ((SKIPPED_COUNT++))
            continue
        fi

        # No durable plan exists — copy with naming:
        #   With ID:    YYYY-MM-DD-F-XXXX-<slug>-plan.md
        #   Without ID: YYYY-MM-DD-<slug>-plan.md
        [[ -z "$slug" ]] && slug=$(extract_slug "$plan_file")
        label=""
        if [[ -n "$primary_id" && -n "$slug" ]]; then
            label="${primary_id}-${slug}"
        elif [[ -n "$primary_id" ]]; then
            label="${primary_id}"
        else
            label="${slug}"
        fi
        file_date=$(date -r "$plan_file" +%Y-%m-%d 2>/dev/null || date +%Y-%m-%d)
        dest_name="${file_date}-${label}-plan.md"
        if [[ "$CHECK_ONLY" == true ]]; then
            COPIED_PLANS+=("$label (from $(basename "$scan_dir")/$(basename "$plan_file"))")
            ((COPIED_COUNT++))
        else
            cp "$plan_file" "$PLANS_DIR/$dest_name"
            COPIED_PLANS+=("$label (from $(basename "$scan_dir")/$(basename "$plan_file"))")
            ((COPIED_COUNT++))
        fi
    done
done

# --- Output results ---
if [[ "$QUIET" == true ]]; then
    if [[ "$COPIED_COUNT" -gt 0 ]]; then
        if [[ "$CHECK_ONLY" == true ]]; then
            echo "Plan scan: $COPIED_COUNT unsaved plan(s) found"
        else
            echo "Plan scan: $COPIED_COUNT plan(s) saved to .agentic/journal/plans/"
        fi
    fi
    # Quiet mode: no output if nothing to report
    exit 0
fi

# Verbose output
if [[ ${#SCAN_DIRS[@]} -eq 0 ]]; then
    echo "Plan scan: no ephemeral plan directories found"
    exit 0
fi

if [[ "$COPIED_COUNT" -gt 0 ]]; then
    if [[ "$CHECK_ONLY" == true ]]; then
        echo "Plan scan: $COPIED_COUNT unsaved plan(s) detected (dry run)"
    else
        echo "Plan scan: $COPIED_COUNT plan(s) saved to .agentic/journal/plans/"
    fi
    for entry in "${COPIED_PLANS[@]}"; do
        echo "  -> $entry"
    done
elif [[ "$FOUND_COUNT" -gt 0 ]]; then
    echo "Plan scan: OK ($FOUND_COUNT ephemeral plan(s) already saved)"
else
    echo "Plan scan: OK (no ephemeral plans found)"
fi

exit 0
