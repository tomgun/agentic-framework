#!/usr/bin/env bash
# commands/settings.sh — Settings management (ag set)
# Sourced by ag.sh — do NOT execute directly.
# Depends on: SCRIPT_DIR, ROOT_DIR, PROFILE, color codes, paths.sh, settings.sh

# Set command — manage settings
cmd_set() {
    local arg1="${1:-}"
    local arg2="${2:-}"

    case "$arg1" in
        --show|"")
            echo -e "${BOLD}=== Resolved Settings ===${NC}"
            echo ""
            show_all_settings
            echo ""
            # Constraint check
            local violations
            violations=$(validate_constraints 2>&1)
            if [ -n "$violations" ]; then
                echo -e "${YELLOW}Constraint warnings:${NC}"
                echo "$violations"
            else
                echo -e "${GREEN}All constraint rules satisfied.${NC}"
            fi
            ;;
        --validate)
            echo -e "${BOLD}=== Constraint Validation ===${NC}"
            local violations
            violations=$(validate_constraints 2>&1)
            if [ -n "$violations" ]; then
                echo -e "${RED}Violations:${NC}"
                echo "$violations"
                exit 1
            else
                echo -e "${GREEN}All constraints satisfied.${NC}"
            fi
            ;;
        --migrate)
            echo -e "${BOLD}=== Migrate Settings ===${NC}"
            _settings_migrate
            ;;
        *)
            # ag set <key> <value>
            if [ -z "$arg2" ]; then
                echo -e "${RED}Error: Value required${NC}"
                echo "Usage: ag set <key> <value>"
                echo "       ag set --show"
                echo "       ag set --validate"
                echo "       ag set --migrate"
                exit 1
            fi
            _settings_set_value "$arg1" "$arg2"
            ;;
    esac
}

# Set a single setting value in STACK.md ## Settings section
_settings_set_value() {
    local key="$1"
    local value="$2"
    local stack_file="$ROOT_DIR/STACK.md"

    # Validate key format (prevent regex injection)
    if [[ ! "$key" =~ ^[a-z_][a-z0-9_]*$ ]]; then
        echo -e "${RED}Error: Invalid setting key '$key' (must be lowercase letters, digits, underscores)${NC}"
        exit 1
    fi

    # Validate values for enum settings
    case "$key" in
        profile)
            if [[ ! "$value" =~ ^(discovery|formal|autonomous_formal)$ ]]; then
                echo -e "${RED}Error: profile must be 'discovery', 'formal', or 'autonomous_formal', got '$value'${NC}"
                exit 1
            fi
            ;;
        feature_tracking|plan_review_enabled|spec_directory)
            if [[ ! "$value" =~ ^(yes|no)$ ]]; then
                echo -e "${RED}Error: $key must be 'yes' or 'no', got '$value'${NC}"
                exit 1
            fi
            ;;
        acceptance_criteria)
            if [[ ! "$value" =~ ^(blocking|recommended|off)$ ]]; then
                echo -e "${RED}Error: acceptance_criteria must be 'blocking', 'recommended', or 'off', got '$value'${NC}"
                exit 1
            fi
            ;;
        wip_before_commit)
            if [[ ! "$value" =~ ^(blocking|warning)$ ]]; then
                echo -e "${RED}Error: wip_before_commit must be 'blocking' or 'warning', got '$value'${NC}"
                exit 1
            fi
            ;;
        docs_gate)
            if [[ ! "$value" =~ ^(off|warning|blocking)$ ]]; then
                echo -e "${RED}Error: docs_gate must be 'off', 'warning', or 'blocking', got '$value'${NC}"
                exit 1
            fi
            ;;
        smoke_test_evidence)
            if [[ ! "$value" =~ ^(off|recommended|required)$ ]]; then
                echo -e "${RED}Error: smoke_test_evidence must be 'off', 'recommended', or 'required', got '$value'${NC}"
                exit 1
            fi
            ;;
        docs_mode)
            if [[ ! "$value" =~ ^(inline|deferred)$ ]]; then
                echo -e "${RED}Error: docs_mode must be 'inline' or 'deferred', got '$value'${NC}"
                exit 1
            fi
            ;;
        pre_commit_checks)
            if [[ ! "$value" =~ ^(full|fast|off)$ ]]; then
                echo -e "${RED}Error: pre_commit_checks must be 'full', 'fast', or 'off', got '$value'${NC}"
                exit 1
            fi
            ;;
        pre_commit_hook)
            if [[ ! "$value" =~ ^(fast|full|no)$ ]]; then
                echo -e "${RED}Error: pre_commit_hook must be 'fast', 'full', or 'no', got '$value'${NC}"
                exit 1
            fi
            ;;
        git_workflow)
            if [[ ! "$value" =~ ^(pull_request|direct)$ ]]; then
                echo -e "${RED}Error: git_workflow must be 'pull_request' or 'direct', got '$value'${NC}"
                exit 1
            fi
            ;;
        max_files_per_commit|max_added_lines|max_code_file_length)
            if [[ ! "$value" =~ ^[0-9]+$ ]]; then
                echo -e "${RED}Error: $key must be a positive integer, got '$value'${NC}"
                exit 1
            fi
            ;;
        review_spec|review_criteria|review_plan|review_code|review_merge|review_decomposition|review_regression|review_taste)
            if [[ ! "$value" =~ ^(human|critical_agent|skip|auto)$ ]]; then
                echo -e "${RED}Error: $key must be 'human', 'critical_agent', or 'skip', got '$value'${NC}"
                exit 1
            fi
            ;;
    esac

    if [ ! -f "$stack_file" ]; then
        echo -e "${RED}Error: STACK.md not found${NC}"
        exit 1
    fi

    # Capture old profile before writing (used by profile cascade below)
    if [[ "$key" == "profile" ]]; then
        _PREV_PROFILE=$(get_setting "profile" "discovery")
    fi

    # Ensure ## Settings section exists
    if ! grep -q "^## Settings" "$stack_file" 2>/dev/null; then
        _settings_create_section
    fi

    # Check if key already exists in ## Settings section
    # We need to be careful to only match within the section
    local in_section=0
    local found=0
    local tmpfile
    tmpfile=$(mktemp)

    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$in_section" -eq 0 ]]; then
            echo "$line" >> "$tmpfile"
            if [[ "$line" =~ ^##[[:space:]]+Settings ]]; then
                in_section=1
            fi
        elif [[ "$line" =~ ^##[[:space:]]+[^#] ]]; then
            # Exiting settings section
            if [[ "$found" -eq 0 ]]; then
                # Key not found in section, add it before next H2
                echo "- ${key}: ${value}" >> "$tmpfile"
                found=1
            fi
            in_section=0
            echo "$line" >> "$tmpfile"
        else
            # Inside settings section
            if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*${key}: ]]; then
                echo "- ${key}: ${value}" >> "$tmpfile"
                found=1
            else
                echo "$line" >> "$tmpfile"
            fi
        fi
    done < "$stack_file"

    # If still in section at EOF and not found, append
    if [[ "$found" -eq 0 ]]; then
        echo "- ${key}: ${value}" >> "$tmpfile"
    fi

    mv "$tmpfile" "$stack_file"

    # Invalidate caches
    _SETTINGS_SECTION_EXTRACTED=0
    _SETTINGS_SECTION_CACHE=""
    _SETTINGS_PROFILE_RESOLVED=0
    _SETTINGS_PROFILE_CACHE=""

    echo -e "${GREEN}Set ${key} = ${value}${NC}"

    # Smart profile cascade: update all settings to new profile defaults,
    # but preserve any settings the user has customized away from the old profile
    if [[ "$key" == "profile" ]]; then
        local old_profile presets_file
        old_profile="${_PREV_PROFILE:-discovery}"
        presets_file="$ROOT_DIR/.agentic/lib/presets/profiles.conf"
        if [[ -f "$presets_file" ]]; then
            local changed=0
            while IFS='=' read -r preset_key preset_value; do
                [[ "$preset_key" =~ ^#|^$ ]] && continue
                [[ -z "$preset_key" ]] && continue
                if [[ "$preset_key" =~ ^${value}\.(.*) ]]; then
                    local setting_name="${BASH_REMATCH[1]}"
                    local new_value="$preset_value"
                    # Get old profile default for this setting
                    local old_default
                    old_default=$(grep "^${old_profile}.${setting_name}=" "$presets_file" | cut -d= -f2)
                    # Re-read current value from file (cache was invalidated)
                    _SETTINGS_SECTION_EXTRACTED=0; _SETTINGS_SECTION_CACHE=""
                    local current_value
                    current_value=$(get_setting "$setting_name" "")
                    # Only overwrite if current value matches old profile default (user didn't customize)
                    if [[ "$current_value" == "$old_default" || -z "$current_value" ]]; then
                        sed -i.bak -E "s/^(- ${setting_name}:[[:space:]]*).*/\\1${new_value}/" "$stack_file"
                        rm -f "$stack_file.bak" 2>/dev/null || true
                        changed=$((changed + 1))
                    fi
                fi
            done < "$presets_file"
            # Clear caches and validate constraints once at end
            _SETTINGS_SECTION_EXTRACTED=0; _SETTINGS_SECTION_CACHE=""
            _SETTINGS_PROFILE_RESOLVED=0; _SETTINGS_PROFILE_CACHE=""
            local violations
            violations=$(validate_constraints 2>&1)
            if [ -n "$violations" ]; then
                echo ""
                echo -e "${YELLOW}Warning — constraint issues:${NC}"
                echo "$violations"
            fi
            echo "Switched to ${value} profile ($changed settings updated, customized settings preserved)"
            return
        fi
    fi

    # Validate constraints after change
    local violations
    violations=$(validate_constraints 2>&1)
    if [ -n "$violations" ]; then
        echo ""
        echo -e "${YELLOW}Warning — constraint issues:${NC}"
        echo "$violations"
    fi
}

# Create ## Settings section in STACK.md if missing
_settings_create_section() {
    local stack_file="$ROOT_DIR/STACK.md"
    local profile
    profile=$(_get_profile)

    # Find a good insertion point — after ## Agentic framework section
    local tmpfile
    tmpfile=$(mktemp)
    local inserted=0

    while IFS= read -r line; do
        echo "$line" >> "$tmpfile"
        # Insert after the "- Source:" line in ## Agentic framework section
        if [[ "$inserted" -eq 0 ]] && [[ "$line" =~ ^-[[:space:]]*Source: ]]; then
            echo "" >> "$tmpfile"
            echo "## Settings" >> "$tmpfile"
            echo "<!-- Profile sets defaults. Override individual settings below. -->" >> "$tmpfile"
            echo "- profile: ${profile}" >> "$tmpfile"
            echo "" >> "$tmpfile"
            inserted=1
        fi
    done < "$stack_file"

    # Fallback: append at end
    if [[ "$inserted" -eq 0 ]]; then
        echo "" >> "$tmpfile"
        echo "## Settings" >> "$tmpfile"
        echo "<!-- Profile sets defaults. Override individual settings below. -->" >> "$tmpfile"
        echo "- profile: ${profile}" >> "$tmpfile"
        echo "" >> "$tmpfile"
    fi

    mv "$tmpfile" "$stack_file"
}

# Migrate: add ## Settings section with current values
_settings_migrate() {
    local stack_file="$ROOT_DIR/STACK.md"

    if [ ! -f "$stack_file" ]; then
        echo -e "${RED}Error: STACK.md not found${NC}"
        exit 1
    fi

    if grep -q "^## Settings" "$stack_file" 2>/dev/null; then
        echo -e "${YELLOW}## Settings section already exists in STACK.md${NC}"
        echo "Run 'ag set --show' to see resolved settings."
        return 0
    fi

    _settings_create_section
    echo -e "${GREEN}Created ## Settings section in STACK.md${NC}"
    echo ""
    echo "Current resolved settings:"
    show_all_settings
}
