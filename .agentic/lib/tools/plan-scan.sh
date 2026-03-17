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
# Feature detection strategy:
#   - Extract the PRIMARY feature ID from the plan title/header (first 5 lines)
#   - Match patterns: "F-XXXX:" in heading, "Feature: F-XXXX", "F-XXXX" in title
#   - Verify the feature exists in this project's FEATURES.md (avoids cross-project noise)
#   - Plans without a clear primary feature ID are skipped
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

# --- Helper: extract primary feature ID from a plan file ---
# Looks at the first 10 lines for a clear feature reference in the title/header.
# Returns empty string if no primary feature found.
extract_primary_feature() {
    local file="$1"
    local header
    header=$(head -10 "$file" 2>/dev/null || true)

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

    # No primary feature found
    echo ""
}

# --- Scan for unsaved plans ---
FOUND_COUNT=0
COPIED_COUNT=0
SKIPPED_COUNT=0
COPIED_PLANS=()

for scan_dir in "${SCAN_DIRS[@]}"; do
    for plan_file in "$scan_dir"/*; do
        [[ -f "$plan_file" ]] || continue

        # Extract primary feature ID
        primary_fid=$(extract_primary_feature "$plan_file")
        [[ -z "$primary_fid" ]] && continue

        # Verify this feature belongs to THIS project
        if [[ -n "$_known_features" ]]; then
            if ! echo "$_known_features" | grep -qF "$primary_fid"; then
                continue
            fi
        fi

        ((FOUND_COUNT++))

        # Check if a durable plan already exists for this feature
        # Look for any file matching F-XXXX*plan* in PLANS_DIR
        local_plan_exists=false
        for existing in "$PLANS_DIR"/*"${primary_fid}"*plan*; do
            if [[ -f "$existing" ]]; then
                local_plan_exists=true
                break
            fi
        done

        if [[ "$local_plan_exists" == true ]]; then
            ((SKIPPED_COUNT++))
            continue
        fi

        # No durable plan exists — copy it
        dest_name="$(date +%Y-%m-%d)-${primary_fid}-plan.md"
        if [[ "$CHECK_ONLY" == true ]]; then
            COPIED_PLANS+=("$primary_fid (from $(basename "$scan_dir")/$(basename "$plan_file"))")
            ((COPIED_COUNT++))
        else
            cp "$plan_file" "$PLANS_DIR/$dest_name"
            COPIED_PLANS+=("$primary_fid (from $(basename "$scan_dir")/$(basename "$plan_file"))")
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
