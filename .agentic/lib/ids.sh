#!/usr/bin/env bash
# ids.sh — Centralized ID patterns for shell scripts
#
# Sourced automatically via paths.sh. Provides:
#   - ERE patterns for grep -E
#   - Shell function for validation
#
# @feature F-0004 (consolidated from F-0193)

# Guard against double-sourcing
[[ -n "${_AGENTIC_IDS_LOADED:-}" ]] && return 0
_AGENTIC_IDS_LOADED=1

# ---------------------------------------------------------------------------
# Feature ID patterns (ERE — for grep -E / awk)
# ---------------------------------------------------------------------------

# Unanchored: matches F-0001 or F-10000 anywhere in text
FEATURE_ID_ERE='F-[0-9]{4,}'

# Anchored: entire string must be a feature ID
FEATURE_ID_ERE_ANCHORED='^F-[0-9]{4,}$'

# Markdown header: ## F-XXXX: Title
FEATURE_HEADER_ERE='^## F-[0-9]{4,}:'

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
# ---------------------------------------------------------------------------

is_feature_id() {
    [[ "$1" =~ ^F-[0-9]{4,}$ ]]
}

# Format an integer as a feature ID (zero-padded up to 9999)
format_feature_id() {
    local n="$1"
    if [[ "$n" -lt 10000 ]]; then
        printf "F-%04d" "$n"
    else
        printf "F-%d" "$n"
    fi
}
