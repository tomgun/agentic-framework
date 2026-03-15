#!/usr/bin/env bash
# ac-parse.sh — Shared AC parsing functions for the agentic framework
#
# Source this file from any tool that needs to count or list acceptance criteria.
# All tools MUST use these functions instead of inline regexes.
#
# Supported AC formats:
#   Primary (checkbox):  - [ ] **AC-001**: description     (unchecked)
#                        - [x] **AC-001**: description     (checked)
#                        - [ ] AC-001: description          (unchecked, no bold)
#                        - [x] AC-001: description          (checked, no bold)
#                        - [ ] AC1: description             (unchecked, no hyphen)
#                        - [x] AC1: description             (checked, no hyphen)
#   Legacy (bare):       - AC-001: description              (counted as unchecked)
#                        - AC1: description                  (counted as unchecked)
#   Heading:             ### AC-001                          (counted as unchecked)
#
# Priority group detection:
#   ### Group Name (P1 — MVP)        → P1 group
#   ### Group Name (P2 — optional)   → P2 group
#   ### Group Name (P1a — ...)       → P1 group (sub-priority)
#   ### NFR Constraints (P1 — ...)   → P1 group (NFR)
#
# Usage:
#   source "$(dirname "${BASH_SOURCE[0]}")/ac-parse.sh"
#   ac_count_checked "path/to/acceptance.md"
#   ac_count_unchecked "path/to/acceptance.md"
#   ac_count_total "path/to/acceptance.md"
#   ac_has_priority_groups "path/to/acceptance.md"
#   ac_count_checked_in_group "path/to/acceptance.md" "P1"
#   ac_count_total_in_group "path/to/acceptance.md" "P1"
#   ac_list "path/to/acceptance.md"

# AC ID pattern: matches AC-001, AC-1, AC001, AC1 (with or without hyphen)
_AC_ID_PATTERN='AC-?[0-9]+'

# --- Internal helpers ---

# Match a line as a checked checkbox AC
_ac_is_checked() {
    echo "$1" | grep -qE "^[[:space:]]*- \[x\][[:space:]]+(\*\*)?${_AC_ID_PATTERN}(\*\*)?:" 2>/dev/null
}

# Match a line as an unchecked checkbox AC
_ac_is_unchecked_checkbox() {
    echo "$1" | grep -qE "^[[:space:]]*- \[ \][[:space:]]+(\*\*)?${_AC_ID_PATTERN}(\*\*)?:" 2>/dev/null
}

# Match a line as a bare (legacy) AC: "- AC-NNN:" without checkbox
# Must exclude checkbox lines to avoid double-counting
_ac_is_bare() {
    echo "$1" | grep -qE "^[[:space:]]*- ${_AC_ID_PATTERN}:" 2>/dev/null && \
    ! echo "$1" | grep -qE "^[[:space:]]*- \[[ x]\]" 2>/dev/null
}

# Match a line as a heading AC: "### AC-NNN"
_ac_is_heading() {
    echo "$1" | grep -qE "^###[[:space:]]+${_AC_ID_PATTERN}" 2>/dev/null
}

# Match any AC format (checked or unchecked)
_ac_is_any() {
    _ac_is_checked "$1" || _ac_is_unchecked_checkbox "$1" || _ac_is_bare "$1" || _ac_is_heading "$1"
}

# Extract AC ID from a line
_ac_extract_id() {
    echo "$1" | grep -oE 'AC-?[0-9]+' | head -1
}

# --- Core counting functions ---

# Count checked ACs (checkbox format with [x])
ac_count_checked() {
    local file="$1"
    [[ -f "$file" ]] || { echo "0"; return; }
    local count
    count=$(grep -cE "^[[:space:]]*- \[x\][[:space:]]+(\*\*)?${_AC_ID_PATTERN}(\*\*)?:" "$file" 2>/dev/null) || count=0
    echo "${count//[[:space:]]/}"
}

# Count unchecked ACs (checkbox with [ ], bare format, heading format)
ac_count_unchecked() {
    local file="$1"
    [[ -f "$file" ]] || { echo "0"; return; }
    local checkbox_unchecked bare heading
    checkbox_unchecked=$(grep -cE "^[[:space:]]*- \[ \][[:space:]]+(\*\*)?${_AC_ID_PATTERN}(\*\*)?:" "$file" 2>/dev/null) || checkbox_unchecked=0
    # Bare format: "- AC-NNN:" WITHOUT checkbox prefix (exclude [x] and [ ] lines)
    bare=$(grep -E "^[[:space:]]*- ${_AC_ID_PATTERN}:" "$file" 2>/dev/null | grep -cvE "^[[:space:]]*- \[[ x]\]" 2>/dev/null) || bare=0
    heading=$(grep -cE "^###[[:space:]]+${_AC_ID_PATTERN}" "$file" 2>/dev/null) || heading=0
    # Trim whitespace
    checkbox_unchecked="${checkbox_unchecked//[[:space:]]/}"
    bare="${bare//[[:space:]]/}"
    heading="${heading//[[:space:]]/}"
    echo $(( checkbox_unchecked + bare + heading ))
}

# Count total ACs (checked + unchecked)
ac_count_total() {
    local file="$1"
    local checked unchecked
    checked=$(ac_count_checked "$file")
    unchecked=$(ac_count_unchecked "$file")
    echo $(( checked + unchecked ))
}

# --- Priority group functions ---

# Check if file has priority group headings (P1, P2, P3 etc)
# Returns 0 (true) if groups exist, 1 (false) otherwise
ac_has_priority_groups() {
    local file="$1"
    [[ -f "$file" ]] || return 1
    grep -qE '^###[[:space:]]+.+\(P[0-9]' "$file" 2>/dev/null
}

# Get the priority level (P1, P2, P3) for a group heading line
# Input: a heading line like "### Core Behavior (P1 — MVP)"
# Output: "P1", "P2", etc. or empty if not a priority heading
_ac_extract_priority() {
    echo "$1" | grep -oE '\(P[0-9]' | head -1 | tr -d '('
}

# Detect if a line is a priority group heading
_ac_is_priority_heading() {
    echo "$1" | grep -qE '^###[[:space:]]+.+\(P[0-9]' 2>/dev/null
}

# Detect if a line is a section heading (## level)
_ac_is_section_heading() {
    echo "$1" | grep -qE '^##[[:space:]]' 2>/dev/null
}

# Count checked ACs within a priority level (e.g., "P1")
# If priority is "ungrouped", counts ACs not in any priority group
ac_count_checked_in_group() {
    local file="$1"
    local priority="$2"
    [[ -f "$file" ]] || { echo "0"; return; }

    local count=0
    local in_target=0

    [[ "$priority" == "ungrouped" ]] && in_target=1

    while IFS= read -r line; do
        if _ac_is_priority_heading "$line"; then
            local grp=""
            grp="$(_ac_extract_priority "$line")"
            if [[ "$priority" == "ungrouped" ]]; then
                in_target=0
            elif [[ "$grp" == "$priority" || "$grp" == "${priority}"[a-z] ]]; then
                in_target=1
            else
                in_target=0
            fi
            continue
        fi
        if _ac_is_section_heading "$line"; then
            [[ "$priority" != "ungrouped" ]] && in_target=0
            continue
        fi
        if [[ "$in_target" -eq 1 ]] && _ac_is_checked "$line"; then
            count=$((count + 1))
        fi
    done < "$file"

    echo "$count"
}

# Count total ACs within a priority level (e.g., "P1")
# If priority is "ungrouped", counts ACs not in any priority group
ac_count_total_in_group() {
    local file="$1"
    local priority="$2"
    [[ -f "$file" ]] || { echo "0"; return; }

    local count=0
    local in_target=0

    [[ "$priority" == "ungrouped" ]] && in_target=1

    while IFS= read -r line; do
        if _ac_is_priority_heading "$line"; then
            local grp=""
            grp="$(_ac_extract_priority "$line")"
            if [[ "$priority" == "ungrouped" ]]; then
                in_target=0
            elif [[ "$grp" == "$priority" || "$grp" == "${priority}"[a-z] ]]; then
                in_target=1
            else
                in_target=0
            fi
            continue
        fi
        if _ac_is_section_heading "$line"; then
            [[ "$priority" != "ungrouped" ]] && in_target=0
            continue
        fi
        if [[ "$in_target" -eq 1 ]] && _ac_is_any "$line"; then
            count=$((count + 1))
        fi
    done < "$file"

    echo "$count"
}

# --- Legacy format detection ---

# Check if file has bare (legacy) AC format without checkboxes
# Returns 0 (true) if legacy format found, 1 otherwise
ac_has_legacy_format() {
    local file="$1"
    [[ -f "$file" ]] || return 1
    grep -qE "^[[:space:]]*- ${_AC_ID_PATTERN}:" "$file" 2>/dev/null
}

# --- NFR tag detection ---

# Count ACs that reference NFRs via (NFR-XXXX) suffix
ac_count_nfr_tagged() {
    local file="$1"
    [[ -f "$file" ]] || { echo "0"; return; }
    local count
    count=$(grep -cE '\(NFR-[0-9]+\)' "$file" 2>/dev/null) || count=0
    echo "${count//[[:space:]]/}"
}

# List NFR IDs referenced in ACs
ac_list_nfr_refs() {
    local file="$1"
    [[ -f "$file" ]] || return
    grep -oE 'NFR-[0-9]+' "$file" 2>/dev/null | sort -u
}

# --- Listing ---

# List all ACs with their status (checked/unchecked) and group
# Output format: STATUS|GROUP|AC_ID|TEXT
ac_list() {
    local file="$1"
    [[ -f "$file" ]] || return

    local current_group="ungrouped"

    while IFS= read -r line; do
        if _ac_is_priority_heading "$line"; then
            current_group=$(_ac_extract_priority "$line")
            continue
        fi
        if _ac_is_section_heading "$line"; then
            current_group="ungrouped"
            continue
        fi
        if _ac_is_checked "$line"; then
            echo "checked|${current_group}|$(_ac_extract_id "$line")|${line}"
        elif _ac_is_unchecked_checkbox "$line"; then
            echo "unchecked|${current_group}|$(_ac_extract_id "$line")|${line}"
        elif _ac_is_bare "$line"; then
            echo "unchecked|${current_group}|$(_ac_extract_id "$line")|${line}"
        elif _ac_is_heading "$line"; then
            echo "unchecked|${current_group}|$(_ac_extract_id "$line")|${line}"
        fi
    done < "$file"
}

# --- Completion percentage ---

# Calculate completion percentage for a file
# Returns integer percentage (0-100)
ac_completion_pct() {
    local file="$1"
    local total checked
    total=$(ac_count_total "$file")
    checked=$(ac_count_checked "$file")
    [[ "$total" -eq 0 ]] && { echo "100"; return; }
    echo $(( checked * 100 / total ))
}

# Calculate completion percentage for a priority group
ac_completion_pct_in_group() {
    local file="$1"
    local priority="$2"
    local total checked
    total=$(ac_count_total_in_group "$file" "$priority")
    checked=$(ac_count_checked_in_group "$file" "$priority")
    [[ "$total" -eq 0 ]] && { echo "100"; return; }
    echo $(( checked * 100 / total ))
}
