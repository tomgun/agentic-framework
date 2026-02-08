#!/bin/bash
# context-for-role.sh - Assemble minimal context for a specific agent role
#
# Usage:
#   context-for-role.sh <role> [feature_id] [--dry-run]
#
# Example:
#   context-for-role.sh implementation-agent F-0042
#   context-for-role.sh implementation-agent F-0042 --dry-run

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
MANIFESTS_DIR="$PROJECT_ROOT/.agentic/agents/context-manifests"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

show_help() {
    cat << 'EOF'
context-for-role.sh - Assemble minimal context for a specific agent role

Usage:
    context-for-role.sh <role> [feature_id] [options]

Arguments:
    role          Agent role name (e.g., implementation-agent, test-agent)
    feature_id    Feature ID for variable substitution (e.g., F-0042)

Options:
    --dry-run     Show what would be loaded without outputting content
    --help        Show this help message

Examples:
    # Get context for implementation agent
    context-for-role.sh implementation-agent F-0042
    
    # Preview what would be loaded
    context-for-role.sh implementation-agent F-0042 --dry-run
    
    # Get context for research agent (no feature)
    context-for-role.sh research-agent

Available roles:
EOF
    ls -1 "$MANIFESTS_DIR"/*.yaml 2>/dev/null | xargs -n1 basename | sed 's/.yaml$/    /' || echo "    (none found)"
}

# Approximate token count (words / 0.75, since avg token is ~0.75 words)
count_tokens() {
    local content="$1"
    local words=$(echo "$content" | wc -w | tr -d ' ')
    echo $(( words * 4 / 3 ))  # Rough approximation
}

# Extract a section from a file based on header
extract_section() {
    local file="$1"
    local section_header="$2"
    
    if [[ ! -f "$file" ]]; then
        return
    fi
    
    # Extract from section header to next same-level header or EOF
    awk -v header="$section_header" '
        BEGIN { found=0; level=0 }
        $0 ~ header { found=1; match($0, /^#+/); level=RLENGTH; print; next }
        found && /^#+/ { 
            match($0, /^#+/)
            if (RLENGTH <= level) exit
        }
        found { print }
    ' "$file"
}

# Parse simple YAML value
yaml_value() {
    local file="$1"
    local key="$2"
    grep "^${key}:" "$file" 2>/dev/null | sed "s/^${key}:[[:space:]]*//" | tr -d '"'
}

# Parse YAML list
yaml_list() {
    local file="$1"
    local key="$2"
    awk -v key="$key:" '
        $0 ~ "^"key { found=1; next }
        found && /^[a-z_]+:/ { exit }
        found && /^  - / { gsub(/^  - /, ""); print }
    ' "$file"
}

# Main logic
main() {
    local role=""
    local feature_id=""
    local dry_run=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help|-h)
                show_help
                exit 0
                ;;
            --dry-run)
                dry_run=true
                shift
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
        echo -e "${RED}Error: Role name required${NC}" >&2
        show_help
        exit 1
    fi
    
    # Find manifest
    local manifest="$MANIFESTS_DIR/${role}.yaml"
    if [[ ! -f "$manifest" ]]; then
        echo -e "${RED}Error: Manifest not found: $manifest${NC}" >&2
        echo "Available roles:" >&2
        ls -1 "$MANIFESTS_DIR"/*.yaml 2>/dev/null | xargs -n1 basename | sed 's/.yaml$//' >&2
        exit 1
    fi
    
    # Parse manifest
    local token_budget=$(yaml_value "$manifest" "token_budget")
    local description=$(yaml_value "$manifest" "description")
    
    token_budget=${token_budget:-5000}
    
    if $dry_run; then
        echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
        echo -e "${BLUE}Context Assembly: ${role}${NC}"
        echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
        echo -e "Description: ${description}"
        echo -e "Token budget: ${token_budget}"
        echo -e "Feature ID: ${feature_id:-'(none)'}"
        echo ""
    fi
    
    local total_tokens=0
    local assembled_content=""
    local files_loaded=()

    # Always-inject: constitutional rules for ALL agent roles
    local ALWAYS_INJECT=(
        ".agentic/agents/shared/guidelines/core-rules.md"
    )

    if $dry_run; then
        echo -e "${GREEN}Always-inject files:${NC}"
    fi

    for inject_path in "${ALWAYS_INJECT[@]}"; do
        local full_inject_path="$PROJECT_ROOT/$inject_path"
        if [[ -f "$full_inject_path" ]]; then
            local content=$(cat "$full_inject_path")
            local file_tokens=$(count_tokens "$content")
            total_tokens=$((total_tokens + file_tokens))
            files_loaded+=("$inject_path")

            if $dry_run; then
                echo -e "  ${GREEN}✓${NC} $inject_path (~${file_tokens} tokens) [always-inject]"
            else
                assembled_content+="# === $inject_path ==="#$'\n'
                assembled_content+="$content"$'\n\n'
            fi
        else
            if $dry_run; then
                echo -e "  ${YELLOW}⚠${NC} $inject_path (not found) [always-inject]"
            fi
        fi
    done

    if $dry_run; then
        echo ""
    fi

    # Process required files
    if $dry_run; then
        echo -e "${GREEN}Required files:${NC}"
    fi
    
    while IFS= read -r entry; do
        [[ -z "$entry" ]] && continue
        
        # Strip comments
        entry=$(echo "$entry" | sed 's/#.*//' | xargs)
        [[ -z "$entry" ]] && continue
        
        # Substitute variables
        entry="${entry//\{feature_id\}/$feature_id}"
        
        # Check for section extraction: file.md[section]
        local file_path=""
        local sections=""
        if [[ "$entry" =~ ^([^\[]+)\[([^\]]+)\]$ ]]; then
            file_path="${BASH_REMATCH[1]}"
            sections="${BASH_REMATCH[2]}"
        else
            file_path="$entry"
        fi
        
        local full_path="$PROJECT_ROOT/$file_path"
        
        if [[ -f "$full_path" ]]; then
            local content=""
            
            if [[ -n "$sections" ]]; then
                # Extract specific sections
                IFS=',' read -ra section_list <<< "$sections"
                for section in "${section_list[@]}"; do
                    section=$(echo "$section" | xargs)  # trim
                    # Extract section by searching for ## header containing section name
                    local section_content=$(extract_section "$full_path" "## .*${section}")
                    if [[ -n "$section_content" ]]; then
                        content+="$section_content"$'\n'
                    fi
                done
                # Fallback: just read the whole file if section extraction failed
                if [[ -z "$content" ]]; then
                    content=$(cat "$full_path")
                fi
            else
                content=$(cat "$full_path")
            fi
            
            local file_tokens=$(count_tokens "$content")
            total_tokens=$((total_tokens + file_tokens))
            files_loaded+=("$file_path")
            
            if $dry_run; then
                echo -e "  ${GREEN}✓${NC} $file_path (~${file_tokens} tokens)"
            else
                assembled_content+="# === $file_path ==="#$'\n'
                assembled_content+="$content"$'\n\n'
            fi
        else
            if $dry_run; then
                echo -e "  ${YELLOW}⚠${NC} $file_path (not found)"
            fi
        fi
    done < <(yaml_list "$manifest" "required")
    
    # Process optional files (if budget allows)
    if $dry_run; then
        echo ""
        echo -e "${YELLOW}Optional files:${NC}"
    fi
    
    while IFS= read -r entry; do
        [[ -z "$entry" ]] && continue
        
        entry=$(echo "$entry" | sed 's/#.*//' | xargs)
        [[ -z "$entry" ]] && continue
        
        entry="${entry//\{feature_id\}/$feature_id}"
        
        local file_path="$entry"
        local full_path="$PROJECT_ROOT/$file_path"
        
        if [[ -f "$full_path" ]]; then
            local content=$(cat "$full_path")
            local file_tokens=$(count_tokens "$content")
            
            if (( total_tokens + file_tokens <= token_budget )); then
                total_tokens=$((total_tokens + file_tokens))
                files_loaded+=("$file_path")
                
                if $dry_run; then
                    echo -e "  ${GREEN}✓${NC} $file_path (~${file_tokens} tokens) - included"
                else
                    assembled_content+="# === $file_path ==="#$'\n'
                    assembled_content+="$content"$'\n\n'
                fi
            else
                if $dry_run; then
                    echo -e "  ${YELLOW}⊘${NC} $file_path (~${file_tokens} tokens) - skipped (over budget)"
                fi
            fi
        elif [[ -d "$full_path" ]]; then
            if $dry_run; then
                echo -e "  ${BLUE}📁${NC} $file_path (directory - would sample)"
            fi
        else
            if $dry_run; then
                echo -e "  ${YELLOW}⚠${NC} $file_path (not found)"
            fi
        fi
    done < <(yaml_list "$manifest" "optional")
    
    # Summary
    if $dry_run; then
        echo ""
        echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
        local pct=$((total_tokens * 100 / token_budget))
        if (( total_tokens > token_budget )); then
            echo -e "${RED}Token budget: ${token_budget}${NC}"
            echo -e "${RED}Tokens used:  ${total_tokens} (${pct}%) - OVER BUDGET${NC}"
        else
            echo -e "${GREEN}Token budget: ${token_budget}${NC}"
            echo -e "${GREEN}Tokens used:  ${total_tokens} (${pct}%)${NC}"
        fi
        echo -e "Files loaded: ${#files_loaded[@]}"
        echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    else
        # Output assembled context
        echo "$assembled_content"
    fi
}

main "$@"
