#!/usr/bin/env bash
# ids.sh — Centralized ID patterns for shell scripts
#
# Sourced automatically via paths.sh. Provides:
#   - ERE patterns for grep -E
#   - Shell functions for validation and hierarchy
#
# Supported prefixes: F- (features), DEV- (dev infrastructure), E- (epics).
# Supports dotted hierarchical IDs: F-003.1, F-003.1.2 (children start at .1).
# During transition: both 3-digit (F-003) and 4-digit (F-0003) accepted.
#
# @feature F-0004 (consolidated from F-0193)
# @feature F-0184

# Guard against double-sourcing
[[ -n "${_AGENTIC_IDS_LOADED:-}" ]] && return 0
_AGENTIC_IDS_LOADED=1

# ---------------------------------------------------------------------------
# Feature ID patterns (ERE — for grep -E / awk)
# Matches F-XXXX, DEV-XXXX, E-XXXX (3+ digits, optional dotted children)
# Children start at .1 (never .0)
# ---------------------------------------------------------------------------

# Unanchored: matches F-0001, DEV-0001, E-0001, F-003.1.2 anywhere in text
FEATURE_ID_ERE='(F|DEV|E)-[0-9]{3,}(\.[1-9][0-9]*)*'

# Anchored: entire string must be a feature/dev/epic ID
FEATURE_ID_ERE_ANCHORED='^(F|DEV|E)-[0-9]{3,}(\.[1-9][0-9]*)*$'

# Markdown header: ## F-XXXX: Title  or  ## F-003.1: Title
FEATURE_HEADER_ERE='^## (F|DEV|E)-[0-9]{3,}(\.[1-9][0-9]*)*:'

# ---------------------------------------------------------------------------
# Epic ID patterns (ERE — for grep -E / awk)
# ---------------------------------------------------------------------------

# Unanchored: matches E-0001 or E-10000 anywhere in text
EPIC_ID_ERE='E-[0-9]{3,}'

# Anchored: entire string must be an epic ID
EPIC_ID_ERE_ANCHORED='^E-[0-9]{3,}$'

is_epic_id() {
    [[ "$1" =~ ^E-[0-9]{3,}$ ]]
}

# ---------------------------------------------------------------------------
# Shell functions — works in all contexts (if, case, etc.)
# ---------------------------------------------------------------------------

# Validate a feature ID (F-XXXX, DEV-XXXX, E-XXXX, including dotted)
is_feature_id() {
    [[ "$1" =~ ^(F|DEV|E)-[0-9]{3,}(\.[1-9][0-9]*)*$ ]]
}

# Get parent ID of a dotted feature ID
# F-003.1.2 → F-003.1, F-003.1 → F-003, F-003 → "" (empty)
get_parent_id() {
    local id="$1"
    if [[ "$id" == *.* ]]; then
        echo "${id%.*}"
    fi
}

# Get nesting depth: F-003 → 0, F-003.1 → 1, F-003.1.2 → 2
get_depth() {
    local id="$1"
    local suffix="${id#*-}"
    suffix="${suffix#[0-9]*}"
    if [[ -z "$suffix" ]]; then
        echo 0
    else
        local dots="${suffix//[^.]/}"
        echo "${#dots}"
    fi
}

# Get root ID: F-003.1.2 → F-003
get_root_id() {
    local id="$1"
    echo "${id%%.*}"
}

# Format an integer as a feature ID (zero-padded, default width 4)
format_feature_id() {
    local n="$1"
    local prefix="${2:-F}"
    local width="${3:-4}"
    local limit=$((10 ** width))
    if [[ "$n" -lt "$limit" ]]; then
        printf "%s-%0${width}d" "$prefix" "$n"
    else
        printf "%s-%d" "$prefix" "$n"
    fi
}
