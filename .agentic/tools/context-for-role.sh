#!/bin/bash
# Context Assembly Tool for Role-Based Context Loading
# Usage: context-for-role.sh <role> [feature_id] [--dry-run]
#
# Assembles minimal context for a specialized agent based on its manifest.
# Supports section extraction, token budgets, and variable substitution.

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_DIR="$SCRIPT_DIR/../agents/context-manifests"

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# Approximate token count (1 token ≈ 4 characters)
count_tokens() {
    local text="$1"
    local chars=${#text}
    echo $(( chars / 4 ))
}

# Extract section from file
# Usage: extract_section "file.md" "## Section Name"
extract_section() {
    local file="$1"
    local section_marker="$2"

    if [[ ! -f "$file" ]]; then
        return 1
    fi

    # Extract from section marker to next ## or end of file
    awk -v marker="$section_marker" '
        BEGIN { found=0; printing=0 }
        $0 ~ marker { found=1; printing=1; print; next }
        /^## / && found && printing { printing=0 }
        printing { print }
    ' "$file"
}

# Parse YAML-like manifest (simple parser, no external deps)
parse_manifest() {
    local manifest="$1"
    local key="$2"

    # Extract values under a key (handles simple lists)
    awk -v key="$key:" '
        BEGIN { found=0 }
        $0 ~ "^"key { found=1; next }
        found && /^[a-z_]+:/ { found=0 }
        found && /^  - / { gsub(/^  - /, ""); print }
    ' "$manifest"
}

# Get single value from manifest
get_value() {
    local manifest="$1"
    local key="$2"

    grep "^${key}:" "$manifest" | sed "s/^${key}: *//" | tr -d '"'
}

# Main function
main() {
    local role=""
    local feature_id=""
    local dry_run=false
    local verbose=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)
                dry_run=true
                shift
                ;;
            --verbose|-v)
                verbose=true
                shift
                ;;
            --help|-h)
                echo "Usage: context-for-role.sh <role> [feature_id] [--dry-run] [--verbose]"
                echo ""
                echo "Roles: implementation-agent, research-agent, test-agent, review-agent,"
                echo "       spec-update-agent, orchestrator-agent, documentation-agent,"
                echo "       git-agent, planning-agent"
                echo ""
                echo "Options:"
                echo "  --dry-run   Show what would be loaded without outputting content"
                echo "  --verbose   Show token counts and loading progress"
                echo ""
                echo "Examples:"
                echo "  context-for-role.sh implementation-agent F-0042"
                echo "  context-for-role.sh research-agent --dry-run"
                exit 0
                ;;
            -*)
                echo -e "${RED}Unknown option: $1${NC}" >&2
                exit 1
                ;;
            *)
                if [[ -z "$role" ]]; then
                    role="$1"
                elif [[ -z "$feature_id" ]]; then
                    feature_id="$1"
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$role" ]]; then
        echo -e "${RED}Error: Role is required${NC}" >&2
        echo "Usage: context-for-role.sh <role> [feature_id] [--dry-run]" >&2
        exit 1
    fi

    # Find manifest
    local manifest="$MANIFEST_DIR/${role}.yaml"
    if [[ ! -f "$manifest" ]]; then
        echo -e "${RED}Error: No manifest found for role '$role'${NC}" >&2
        echo "Available roles:" >&2
        ls "$MANIFEST_DIR"/*.yaml 2>/dev/null | xargs -n1 basename | sed 's/.yaml$//' >&2
        exit 1
    fi

    # Get token budget
    local token_budget
    token_budget=$(get_value "$manifest" "token_budget")
    token_budget=${token_budget:-10000}  # Default 10K

    local total_tokens=0
    local context=""
    local loaded_files=()
    local skipped_files=()

    # Process required files
    while IFS= read -r file_spec; do
        [[ -z "$file_spec" ]] && continue

        # Substitute variables
        local file_path="${file_spec/\{feature_id\}/$feature_id}"

        # Check for section extraction: file.md[section_name]
        local section=""
        if [[ "$file_path" =~ \[([^\]]+)\]$ ]]; then
            section="${BASH_REMATCH[1]}"
            file_path="${file_path%\[*\]}"
        fi

        # Remove comments
        file_path="${file_path%%#*}"
        file_path="${file_path%% }"

        if [[ ! -f "$file_path" ]]; then
            if $verbose; then
                echo -e "${YELLOW}Skip (not found): $file_path${NC}" >&2
            fi
            skipped_files+=("$file_path (not found)")
            continue
        fi

        local content
        if [[ -n "$section" ]]; then
            # Get section marker from manifest
            local section_marker
            section_marker=$(awk -v file="$file_path" -v sec="$section" '
                BEGIN { in_sections=0; in_file=0 }
                /^sections:/ { in_sections=1; next }
                in_sections && /^  [^ ]/ {
                    gsub(/:$/, "")
                    if ($0 ~ file) { in_file=1 } else { in_file=0 }
                    next
                }
                in_sections && in_file && /^    [^ ]+:/ {
                    key=$1; gsub(/:$/, "", key)
                    if (key == sec) { gsub(/^    [^ ]+: */, ""); gsub(/"/, ""); print }
                }
            ' "$manifest")

            section_marker=${section_marker:-"## ${section^}"}  # Default to ## Section
            content=$(extract_section "$file_path" "$section_marker")

            if [[ -z "$content" ]]; then
                # Fallback to full file if section not found
                content=$(cat "$file_path")
                if $verbose; then
                    echo -e "${YELLOW}Section '$section' not found in $file_path, using full file${NC}" >&2
                fi
            fi
        else
            content=$(cat "$file_path")
        fi

        local tokens
        tokens=$(count_tokens "$content")

        # Check budget
        if (( total_tokens + tokens > token_budget )); then
            if $verbose; then
                echo -e "${YELLOW}Budget exceeded, skipping: $file_path ($tokens tokens)${NC}" >&2
            fi
            skipped_files+=("$file_path (budget)")
            continue
        fi

        total_tokens=$((total_tokens + tokens))
        loaded_files+=("$file_path${section:+ [$section]}")

        if ! $dry_run; then
            context+="
--- FILE: $file_path${section:+ (section: $section)} ---
$content
"
        fi

        if $verbose; then
            echo -e "${GREEN}Loaded: $file_path${section:+ [$section]} ($tokens tokens)${NC}" >&2
        fi

    done < <(parse_manifest "$manifest" "required")

    # Process optional files if budget permits
    while IFS= read -r file_spec; do
        [[ -z "$file_spec" ]] && continue

        # Check remaining budget
        if (( total_tokens >= token_budget * 90 / 100 )); then
            if $verbose; then
                echo -e "${YELLOW}90% budget used, skipping optional files${NC}" >&2
            fi
            break
        fi

        local file_path="${file_spec/\{feature_id\}/$feature_id}"
        file_path="${file_path%%#*}"
        file_path="${file_path%% }"

        # Handle directory specs (scan, don't read all)
        if [[ "$file_path" == */ ]]; then
            if [[ -d "$file_path" ]]; then
                local dir_listing
                dir_listing=$(ls -la "$file_path" 2>/dev/null | head -20)
                local tokens
                tokens=$(count_tokens "$dir_listing")

                if (( total_tokens + tokens <= token_budget )); then
                    total_tokens=$((total_tokens + tokens))
                    loaded_files+=("$file_path (listing)")

                    if ! $dry_run; then
                        context+="
--- DIRECTORY: $file_path ---
$dir_listing
"
                    fi
                fi
            fi
            continue
        fi

        if [[ ! -f "$file_path" ]]; then
            continue
        fi

        local content
        content=$(cat "$file_path")
        local tokens
        tokens=$(count_tokens "$content")

        if (( total_tokens + tokens <= token_budget )); then
            total_tokens=$((total_tokens + tokens))
            loaded_files+=("$file_path")

            if ! $dry_run; then
                context+="
--- FILE: $file_path ---
$content
"
            fi

            if $verbose; then
                echo -e "${GREEN}Loaded (optional): $file_path ($tokens tokens)${NC}" >&2
            fi
        fi

    done < <(parse_manifest "$manifest" "optional")

    # Output results
    if $dry_run; then
        echo -e "${BLUE}=== Context Assembly: $role ===${NC}"
        echo -e "Token budget: ${GREEN}$token_budget${NC}"
        echo -e "Tokens used:  ${GREEN}$total_tokens${NC} ($(( total_tokens * 100 / token_budget ))%)"
        echo ""
        echo -e "${GREEN}Files loaded:${NC}"
        for f in "${loaded_files[@]}"; do
            echo "  - $f"
        done
        if [[ ${#skipped_files[@]} -gt 0 ]]; then
            echo ""
            echo -e "${YELLOW}Files skipped:${NC}"
            for f in "${skipped_files[@]}"; do
                echo "  - $f"
            done
        fi
    else
        echo "# Context for: $role"
        echo "# Feature: ${feature_id:-N/A}"
        echo "# Token budget: $token_budget"
        echo "# Tokens used: $total_tokens"
        echo ""
        echo "$context"
    fi
}

main "$@"
