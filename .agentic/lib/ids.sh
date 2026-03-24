#!/usr/bin/env bash
# ids.sh — Centralized ID patterns for shell scripts
#
# Sourced automatically via paths.sh. Provides:
#   - ERE patterns for grep -E
#   - Shell function for validation
#
# Supported prefixes: F- (features), DEV- (dev infrastructure), E- (epics).
#
# @feature F-0004 (consolidated from F-0193)

# Guard against double-sourcing
[[ -n "${_AGENTIC_IDS_LOADED:-}" ]] && return 0
_AGENTIC_IDS_LOADED=1

# ---------------------------------------------------------------------------
# Feature ID patterns (ERE — for grep -E / awk)
# Matches F-XXXX, DEV-XXXX, E-XXXX (4+ digits)
# ---------------------------------------------------------------------------

# Unanchored: matches F-0001, DEV-0001, E-0001 anywhere in text
FEATURE_ID_ERE='(F|DEV|E)-[0-9]{4,}'

# Anchored: entire string must be a feature/dev/epic ID
FEATURE_ID_ERE_ANCHORED='^(F|DEV|E)-[0-9]{4,}$'

# Markdown header: ## F-XXXX: Title  or  ## DEV-XXXX: Title
FEATURE_HEADER_ERE='^## (F|DEV|E)-[0-9]{4,}:'

# ---------------------------------------------------------------------------
# Epic ID patterns (ERE — for grep -E / awk)
# ---------------------------------------------------------------------------

# Unanchored: matches E-0001 or E-10000 anywhere in text
EPIC_ID_ERE='E-[0-9]{4,}'

# Anchored: entire string must be an epic ID
EPIC_ID_ERE_ANCHORED='^E-[0-9]{4,}$'

is_epic_id() {
    [[ "$1" =~ ^E-[0-9]{4,}$ ]]
}

# ---------------------------------------------------------------------------
# Shell function — works in all contexts (if, case, etc.)
# Accepts F-XXXX, DEV-XXXX, E-XXXX
# ---------------------------------------------------------------------------

is_feature_id() {
    [[ "$1" =~ ^(F|DEV|E)-[0-9]{4,}$ ]]
}

# Format an integer as a feature ID (zero-padded up to 9999)
format_feature_id() {
    local n="$1"
    local prefix="${2:-F}"
    if [[ "$n" -lt 10000 ]]; then
        printf "%s-%04d" "$prefix" "$n"
    else
        printf "%s-%d" "$prefix" "$n"
    fi
}
