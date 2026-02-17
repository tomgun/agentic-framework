#!/usr/bin/env bash
# settings.sh — Shared settings resolution for the Agentic Framework
#
# Provides get_setting() with three-level resolution:
#   1. Explicit override in STACK.md ## Settings section
#   2. Profile preset from .agentic/presets/profiles.conf
#   3. Fallback default passed by caller
#
# Usage:
#   source .agentic/lib/settings.sh
#   val=$(get_setting "feature_tracking" "no")
#
# Also provides:
#   validate_constraints [--block]  — check constraint rules
#   show_all_settings               — display resolved settings with sources

# Guard against double-sourcing
[[ -n "${_AGENTIC_SETTINGS_LOADED:-}" ]] && return 0
_AGENTIC_SETTINGS_LOADED=1

# Resolve paths relative to the script sourcing us (allow env overrides for testing)
_SETTINGS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_SETTINGS_AGENTIC_DIR="$(cd "$_SETTINGS_LIB_DIR/.." && pwd)"
_SETTINGS_ROOT_DIR="${_SETTINGS_ROOT_DIR:-$(cd "$_SETTINGS_AGENTIC_DIR/.." && pwd)}"
_SETTINGS_PROFILES_CONF="${_SETTINGS_PROFILES_CONF:-$_SETTINGS_AGENTIC_DIR/presets/profiles.conf}"
_SETTINGS_CONSTRAINTS_CONF="${_SETTINGS_CONSTRAINTS_CONF:-$_SETTINGS_AGENTIC_DIR/presets/constraints.conf}"
_SETTINGS_STACK_FILE="${_SETTINGS_STACK_FILE:-$_SETTINGS_ROOT_DIR/STACK.md}"

# Cache for the ## Settings section (extracted once per invocation)
_SETTINGS_SECTION_CACHE=""
_SETTINGS_SECTION_EXTRACTED=0

# Cache for profile value
_SETTINGS_PROFILE_CACHE=""
_SETTINGS_PROFILE_RESOLVED=0

# ---------------------------------------------------------------------------
# _extract_settings_section: Pull text between ## Settings and next ## heading
# ---------------------------------------------------------------------------
_extract_settings_section() {
    if [[ "$_SETTINGS_SECTION_EXTRACTED" -eq 1 ]]; then
        return
    fi
    _SETTINGS_SECTION_EXTRACTED=1

    if [[ ! -f "$_SETTINGS_STACK_FILE" ]]; then
        _SETTINGS_SECTION_CACHE=""
        return
    fi

    # Extract between "## Settings" and the next H2 heading (^## [^#])
    local in_section=0
    _SETTINGS_SECTION_CACHE=""
    while IFS= read -r line; do
        if [[ "$in_section" -eq 0 ]]; then
            if [[ "$line" =~ ^##[[:space:]]+Settings ]]; then
                in_section=1
            fi
        else
            # Stop at next H2 heading (## Something) but NOT ### subsections
            if [[ "$line" =~ ^##[[:space:]]+[^#] ]]; then
                break
            fi
            _SETTINGS_SECTION_CACHE+="$line"$'\n'
        fi
    done < "$_SETTINGS_STACK_FILE"
}

# ---------------------------------------------------------------------------
# _get_from_settings_section: Look up key in ## Settings section
# Returns: value via stdout, exit 0 if found, exit 1 if not
# ---------------------------------------------------------------------------
_get_from_settings_section() {
    local key="$1"
    _extract_settings_section

    if [[ -z "$_SETTINGS_SECTION_CACHE" ]]; then
        return 1
    fi

    # Match "- key: value" (with optional leading spaces, strip comments)
    local val
    val=$(echo "$_SETTINGS_SECTION_CACHE" | grep -E "^[[:space:]]*-[[:space:]]*${key}:" 2>/dev/null | head -1 | sed 's/.*:[[:space:]]*//' | sed 's/[[:space:]]*#.*//' | sed 's/<!--.*-->//' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    if [[ -n "$val" ]]; then
        echo "$val"
        return 0
    fi
    return 1
}

# ---------------------------------------------------------------------------
# _get_from_whole_file: Backward compat — search entire STACK.md
# ---------------------------------------------------------------------------
_get_from_whole_file() {
    local key="$1"
    if [[ ! -f "$_SETTINGS_STACK_FILE" ]]; then
        return 1
    fi

    local val
    val=$(grep -E "^[[:space:]]*-?[[:space:]]*${key}:" "$_SETTINGS_STACK_FILE" 2>/dev/null | head -1 | sed 's/.*:[[:space:]]*//' | sed 's/[[:space:]]*#.*//' | sed 's/<!--.*-->//' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    if [[ -n "$val" ]]; then
        echo "$val"
        return 0
    fi
    return 1
}

# ---------------------------------------------------------------------------
# _get_profile: Resolve the current profile (cached)
# ---------------------------------------------------------------------------
_get_profile() {
    if [[ "$_SETTINGS_PROFILE_RESOLVED" -eq 1 ]]; then
        echo "$_SETTINGS_PROFILE_CACHE"
        return
    fi
    _SETTINGS_PROFILE_RESOLVED=1

    # Try ## Settings section first
    local val
    val=$(_get_from_settings_section "profile") && {
        case "$val" in
            discovery|formal) _SETTINGS_PROFILE_CACHE="$val" ;;
            *) _SETTINGS_PROFILE_CACHE="" ;;
        esac
    }

    # Fall back to whole-file search (backward compat)
    if [[ -z "$_SETTINGS_PROFILE_CACHE" ]]; then
        val=$(_get_from_whole_file "Profile") && {
            val=$(echo "$val" | tr '[:upper:]' '[:lower:]')
            case "$val" in
                discovery|formal) _SETTINGS_PROFILE_CACHE="$val" ;;
            esac
        }
    fi

    # Infer from directory structure
    if [[ -z "$_SETTINGS_PROFILE_CACHE" ]]; then
        if [[ -d "$_SETTINGS_ROOT_DIR/spec" ]]; then
            _SETTINGS_PROFILE_CACHE="formal"
        else
            _SETTINGS_PROFILE_CACHE="discovery"
        fi
    fi

    echo "$_SETTINGS_PROFILE_CACHE"
}

# ---------------------------------------------------------------------------
# _get_from_profile_preset: Look up profile.key in profiles.conf
# ---------------------------------------------------------------------------
_get_from_profile_preset() {
    local key="$1"
    if [[ ! -f "$_SETTINGS_PROFILES_CONF" ]]; then
        return 1
    fi

    local profile
    profile=$(_get_profile)
    local val
    val=$(grep -E "^${profile}\.${key}=" "$_SETTINGS_PROFILES_CONF" 2>/dev/null | head -1 | sed 's/.*=//')
    if [[ -n "$val" ]]; then
        echo "$val"
        return 0
    fi
    return 1
}

# ---------------------------------------------------------------------------
# get_setting: Main entry point — three-level resolution
#   $1 = setting key (e.g., "feature_tracking")
#   $2 = fallback default (optional, used if nothing else matches)
# ---------------------------------------------------------------------------
get_setting() {
    local key="$1"
    local default="${2:-}"
    local val

    # Special case: "profile" key
    if [[ "$key" == "profile" ]]; then
        _get_profile
        return
    fi

    # Ensure section is extracted in parent shell (not subshell)
    _extract_settings_section

    # 1. Check ## Settings section in STACK.md
    val=$(_get_from_settings_section "$key") && { echo "$val"; return; }

    # 2. If no ## Settings section exists, try whole-file (backward compat)
    if [[ -z "$_SETTINGS_SECTION_CACHE" ]]; then
        val=$(_get_from_whole_file "$key") && { echo "$val"; return; }
    fi

    # 3. Check profile preset
    val=$(_get_from_profile_preset "$key") && { echo "$val"; return; }

    # 4. Return fallback default
    echo "$default"
}

# ---------------------------------------------------------------------------
# _get_setting_source: Return where a setting value comes from
#   Returns: "explicit", "preset", "default", or "not-set"
# ---------------------------------------------------------------------------
_get_setting_source() {
    local key="$1"
    local default="${2:-}"

    # Ensure section is extracted in parent shell
    _extract_settings_section

    if [[ "$key" == "profile" ]]; then
        if _get_from_settings_section "profile" >/dev/null 2>&1; then
            echo "explicit"
        elif _get_from_whole_file "Profile" >/dev/null 2>&1; then
            echo "explicit"
        else
            echo "inferred"
        fi
        return
    fi

    if _get_from_settings_section "$key" >/dev/null 2>&1; then
        echo "explicit"
        return
    fi

    if [[ -z "$_SETTINGS_SECTION_CACHE" ]]; then
        if _get_from_whole_file "$key" >/dev/null 2>&1; then
            echo "explicit"
            return
        fi
    fi

    if _get_from_profile_preset "$key" >/dev/null 2>&1; then
        echo "preset"
        return
    fi

    if [[ -n "$default" ]]; then
        echo "default"
        return
    fi

    echo "not-set"
}

# ---------------------------------------------------------------------------
# validate_constraints: Check constraint rules
#   --block: exit 1 on violation (for commit gate)
#   Returns: 0 if OK, 1 if violations found
# ---------------------------------------------------------------------------
validate_constraints() {
    local block=0
    [[ "${1:-}" == "--block" ]] && block=1

    if [[ ! -f "$_SETTINGS_CONSTRAINTS_CONF" ]]; then
        return 0
    fi

    local violations=0

    while IFS= read -r line; do
        # Skip comments and blank lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// /}" ]] && continue

        # Parse: antecedent=value -> consequent=allowed1|allowed2
        local ante_key ante_val cons_key cons_allowed
        ante_key=$(echo "$line" | sed 's/=.*//')
        ante_val=$(echo "$line" | sed 's/[^=]*=//' | sed 's/ *->.*//')
        cons_key=$(echo "$line" | sed 's/.*-> *//' | sed 's/=.*//')
        cons_allowed=$(echo "$line" | sed 's/.*-> *[^=]*=//')

        # Check if antecedent matches
        local current_ante
        current_ante=$(get_setting "$ante_key" "")
        if [[ "$current_ante" != "$ante_val" ]]; then
            continue  # Rule doesn't apply
        fi

        # Check consequent
        local current_cons
        current_cons=$(get_setting "$cons_key" "")
        local match=0
        IFS='|' read -ra allowed_values <<< "$cons_allowed"
        for av in "${allowed_values[@]}"; do
            if [[ "$current_cons" == "$av" ]]; then
                match=1
                break
            fi
        done

        if [[ "$match" -eq 0 ]]; then
            echo "Constraint violation: ${ante_key}=${ante_val} requires ${cons_key}=${cons_allowed}, but got '${current_cons}'"
            violations=$((violations + 1))
        fi
    done < "$_SETTINGS_CONSTRAINTS_CONF"

    if [[ "$violations" -gt 0 ]]; then
        if [[ "$block" -eq 1 ]]; then
            return 1
        fi
    fi
    return 0
}

# ---------------------------------------------------------------------------
# show_all_settings: Display all resolved settings with their sources
# ---------------------------------------------------------------------------
show_all_settings() {
    local settings=(
        "profile"
        "feature_tracking"
        "acceptance_criteria"
        "wip_before_commit"
        "pre_commit_checks"
        "git_workflow"
        "plan_review_enabled"
        "spec_directory"
        "max_files_per_commit"
        "max_added_lines"
        "max_code_file_length"
        "development_mode"
        "agent_mode"
        "pre_commit_hook"
        "plan_review_max_iterations"
        "pipeline_enabled"
    )

    printf "%-28s %-20s %s\n" "SETTING" "VALUE" "SOURCE"
    printf "%-28s %-20s %s\n" "-------" "-----" "------"

    for key in "${settings[@]}"; do
        local val src
        val=$(get_setting "$key" "")
        src=$(_get_setting_source "$key" "")
        printf "%-28s %-20s %s\n" "$key" "${val:-(not set)}" "$src"
    done
}
