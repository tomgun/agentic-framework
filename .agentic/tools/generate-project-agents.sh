#!/usr/bin/env bash
# generate-project-agents.sh — Generate project-specific agent definitions
#
# Layer A: Template-based, no LLM. Uses tech stack detection + specialization
# rules to produce project-specific agents in subagents-project/.
#
# Usage:
#   bash .agentic/tools/generate-project-agents.sh              # Generate
#   bash .agentic/tools/generate-project-agents.sh --dry-run     # Show what would be generated
#   bash .agentic/tools/generate-project-agents.sh --clean       # Remove generated (non-CUSTOMIZED) agents
#
# Input:  STACK.md + file detection + .agentic/agents/specialization/*.conf
# Output: .agentic/agents/claude/subagents-project/*.md
#
# Generated files get <!-- AUTO-GENERATED --> header.
# Files with <!-- CUSTOMIZED --> are never overwritten.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTIC_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_DIR="$(cd "$AGENTIC_DIR/.." && pwd)"

# Colors
if [ -t 1 ]; then
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    DIM='\033[2m'
    NC='\033[0m'
else
    GREEN='' YELLOW='' BLUE='' DIM='' NC=''
fi

# Source shared settings
source "$AGENTIC_DIR/lib/settings.sh"

SPECIALIZATION_DIR="$AGENTIC_DIR/agents/specialization"
GENERIC_AGENTS_DIR="$AGENTIC_DIR/agents/claude/subagents"
PROJECT_AGENTS_DIR="$AGENTIC_DIR/agents/claude/subagents-project"

# Parse flags
DRY_RUN=false
CLEAN=false
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        --clean) CLEAN=true ;;
        -h|--help)
            echo "Usage: bash .agentic/tools/generate-project-agents.sh [--dry-run|--clean]"
            echo ""
            echo "  (no flags)  Generate project-specific agents from specialization rules"
            echo "  --dry-run   Show what would be generated without writing files"
            echo "  --clean     Remove auto-generated agents (preserves CUSTOMIZED)"
            exit 0
            ;;
    esac
done

# --- Clean mode ---
if [ "$CLEAN" = true ]; then
    if [ ! -d "$PROJECT_AGENTS_DIR" ]; then
        echo "No project agents to clean."
        exit 0
    fi
    clean_count=0
    for f in "$PROJECT_AGENTS_DIR"/*.md; do
        [ -f "$f" ] || continue
        if head -5 "$f" | grep -q '<!-- AUTO-GENERATED -->'; then
            if [ "$DRY_RUN" = true ]; then
                echo "Would remove: $(basename "$f")"
            else
                rm "$f"
            fi
            ((clean_count++))
        else
            echo -e "${DIM}Skipping (CUSTOMIZED): $(basename "$f")${NC}"
        fi
    done
    if [ "$DRY_RUN" = true ]; then
        echo "Would remove $clean_count auto-generated agent(s)."
    else
        echo "Removed $clean_count auto-generated agent(s)."
    fi
    exit 0
fi

# --- Detect matching stacks ---
detect_stacks() {
    local matched_confs=()

    for conf_file in "$SPECIALIZATION_DIR"/*.conf; do
        [ -f "$conf_file" ] || continue
        local matched=false

        # Check detect_files (comma-separated file names)
        local detect_files
        detect_files=$(grep '^detect_files=' "$conf_file" 2>/dev/null | sed 's/^detect_files=//' || echo "")
        if [ -n "$detect_files" ]; then
            IFS=',' read -ra files_arr <<< "$detect_files"
            for f in "${files_arr[@]}"; do
                f=$(echo "$f" | tr -d ' ')
                [ -z "$f" ] && continue
                if [ -f "$ROOT_DIR/$f" ]; then
                    matched=true
                    break
                fi
            done
        fi

        # Check detect_package (look in package.json)
        if [ "$matched" = false ] && [ -f "$ROOT_DIR/package.json" ]; then
            local detect_pkg
            detect_pkg=$(grep '^detect_package=' "$conf_file" 2>/dev/null | sed 's/^detect_package=//' || echo "")
            if [ -n "$detect_pkg" ] && grep -q "\"$detect_pkg\"" "$ROOT_DIR/package.json" 2>/dev/null; then
                matched=true
            fi
        fi

        # Check detect_pyproject (look in pyproject.toml or requirements.txt)
        if [ "$matched" = false ]; then
            local detect_py
            detect_py=$(grep '^detect_pyproject=' "$conf_file" 2>/dev/null | sed 's/^detect_pyproject=//' || echo "")
            if [ -n "$detect_py" ]; then
                if grep -qi "$detect_py" "$ROOT_DIR/pyproject.toml" 2>/dev/null || \
                   grep -qi "$detect_py" "$ROOT_DIR/requirements.txt" 2>/dev/null; then
                    matched=true
                fi
            fi
        fi

        # Check STACK.md Languages/Frameworks sections for label
        # Word-boundary matching to avoid "Go" matching "Good"
        if [ "$matched" = false ] && [ -f "$ROOT_DIR/STACK.md" ]; then
            local detect_label
            detect_label=$(grep '^detect_label=' "$conf_file" 2>/dev/null | sed 's/^detect_label=//' || echo "")
            if [ -n "$detect_label" ]; then
                local stack_section
                stack_section=$(sed -n '/^## Languages/,/^## [^F]/p' "$ROOT_DIR/STACK.md" 2>/dev/null || echo "")
                stack_section="$stack_section$(sed -n '/^## Frameworks/,/^## [^D]/p' "$ROOT_DIR/STACK.md" 2>/dev/null || echo "")"
                if echo "$stack_section" | grep -qiE "(^|[^a-zA-Z])${detect_label}([^a-zA-Z]|$)" 2>/dev/null; then
                    matched=true
                fi
            fi
        fi

        if [ "$matched" = true ]; then
            matched_confs+=("$conf_file")
        fi
    done

    if [ ${#matched_confs[@]} -gt 0 ]; then
        echo "${matched_confs[@]}"
    fi
}

# --- Parse specialization overrides from a .conf file for a given agent ---
get_agent_overrides() {
    local conf_file="$1"
    local agent_name="$2"

    local purpose_suffix
    purpose_suffix=$(grep "^${agent_name}.purpose_suffix=" "$conf_file" 2>/dev/null | sed "s/^${agent_name}.purpose_suffix=//" || echo "")

    local instructions
    instructions=$(grep "^${agent_name}.instructions=" "$conf_file" 2>/dev/null | sed "s/^${agent_name}.instructions=//" || echo "")

    local key_dirs
    key_dirs=$(grep "^${agent_name}.key_dirs=" "$conf_file" 2>/dev/null | sed "s/^${agent_name}.key_dirs=//" || echo "")

    echo "${purpose_suffix}|${instructions}|${key_dirs}"
}

# --- Generate a project-specific agent file ---
generate_agent() {
    local agent_name="$1"
    local conf_files="$2"
    local output_file="$PROJECT_AGENTS_DIR/${agent_name}-agent.md"

    # Skip if CUSTOMIZED
    if [ -f "$output_file" ] && head -5 "$output_file" | grep -q '<!-- CUSTOMIZED -->'; then
        echo -e "  ${DIM}skip${NC} ${agent_name}-agent.md (CUSTOMIZED)"
        return
    fi

    local generic_file="$GENERIC_AGENTS_DIR/${agent_name}-agent.md"
    if [ ! -f "$generic_file" ]; then
        return
    fi

    # Collect all overrides from matched confs
    local all_purpose_suffix=""
    local all_instructions=""
    local all_key_dirs=""
    local all_labels=""

    for conf_file in $conf_files; do
        local overrides
        overrides=$(get_agent_overrides "$conf_file" "$agent_name")

        local psuffix iinstr kdirs
        psuffix=$(echo "$overrides" | cut -d'|' -f1)
        iinstr=$(echo "$overrides" | cut -d'|' -f2)
        kdirs=$(echo "$overrides" | cut -d'|' -f3)

        local label
        label=$(grep '^detect_label=' "$conf_file" 2>/dev/null | sed 's/^detect_label=//' || echo "")

        [ -n "$psuffix" ] && all_purpose_suffix="$psuffix"
        [ -n "$iinstr" ] && all_instructions="${all_instructions:+$all_instructions|}$iinstr"
        [ -n "$kdirs" ] && all_key_dirs="${all_key_dirs:+$all_key_dirs,}$kdirs"
        [ -n "$label" ] && all_labels="${all_labels:+$all_labels + }$label"
    done

    # Skip if no overrides found for this agent
    if [ -z "$all_instructions" ] && [ -z "$all_purpose_suffix" ] && [ -z "$all_key_dirs" ]; then
        return
    fi

    # Extract generic purpose
    local generic_purpose
    generic_purpose=$(grep '^\*\*Purpose\*\*:' "$generic_file" 2>/dev/null | head -1 | sed 's/\*\*Purpose\*\*: //')

    local full_purpose="$generic_purpose"
    if [ -n "$all_purpose_suffix" ]; then
        full_purpose="${generic_purpose} ${all_purpose_suffix}"
    fi

    # Capitalize first letter
    local first_char
    first_char=$(echo "${agent_name:0:1}" | tr '[:lower:]' '[:upper:]')
    local agent_title="${first_char}${agent_name:1}"

    # Build instructions list
    local instructions_md=""
    if [ -n "$all_instructions" ]; then
        IFS='|' read -ra instr_arr <<< "$all_instructions"
        for instr in "${instr_arr[@]}"; do
            instr=$(echo "$instr" | sed 's/^[[:space:]]*//')
            [ -z "$instr" ] && continue
            instructions_md="${instructions_md}- ${instr}\n"
        done
    fi

    # Build key dirs list
    local key_dirs_md=""
    if [ -n "$all_key_dirs" ]; then
        IFS=',' read -ra dirs_arr <<< "$all_key_dirs"
        for d in "${dirs_arr[@]}"; do
            d=$(echo "$d" | sed 's/^[[:space:]]*//')
            [ -z "$d" ] && continue
            key_dirs_md="${key_dirs_md}- \`${d}\`\n"
        done
    fi

    if [ "$DRY_RUN" = true ]; then
        echo -e "  ${BLUE}would generate${NC} ${agent_name}-agent.md (${all_labels})"
        return
    fi

    # Write the project-specific agent file
    cat > "$output_file" << EOF
<!-- AUTO-GENERATED by generate-project-agents.sh — do not edit manually -->
<!-- To customize: replace this line with <!-- CUSTOMIZED --> and edit freely -->
<!-- Stack: ${all_labels} -->

# ${agent_title} Agent (Project-Specific)

**Purpose**: ${full_purpose}

## Project-Specific Rules

$(if [ -n "$instructions_md" ]; then echo -e "$instructions_md"; else echo "<!-- Add project-specific rules here or run \`ag agents synthesize\` to generate from codebase -->"; fi)
EOF

    if [ -n "$key_dirs_md" ]; then
        cat >> "$output_file" << EOF
## Key Directories

$(echo -e "$key_dirs_md")
EOF
    fi

    cat >> "$output_file" << EOF

---
*Generated from: .agentic/agents/specialization/ rules*
*Re-generate: \`ag agents generate\` | Customize: add \`<!-- CUSTOMIZED -->\` to first line*
EOF

    echo -e "  ${GREEN}generated${NC} ${agent_name}-agent.md (${all_labels})"
}

# ============================================================================
# Main
# ============================================================================
main() {
    echo -e "${BLUE}Generating project-specific agents...${NC}"
    echo ""

    # Check specialization rules exist
    if [ ! -d "$SPECIALIZATION_DIR" ] || [ -z "$(ls "$SPECIALIZATION_DIR"/*.conf 2>/dev/null)" ]; then
        echo "No specialization rules found in $SPECIALIZATION_DIR"
        exit 0
    fi

    # Detect matching stacks
    local matched
    matched=$(detect_stacks)

    if [ -z "$matched" ]; then
        echo -e "${YELLOW}No matching tech stacks detected.${NC}"
        echo "Checked: STACK.md, package.json, pyproject.toml, requirements.txt, project files"
        echo ""
        echo "To manually specify, add tech stack info to STACK.md ## Frameworks & libraries"
        exit 0
    fi

    # Show detected stacks
    echo -e "Detected stacks:"
    for conf in $matched; do
        local label
        label=$(grep '^detect_label=' "$conf" 2>/dev/null | sed 's/^detect_label=//' || basename "$conf" .conf)
        echo -e "  ${GREEN}✓${NC} $label ($(basename "$conf"))"
    done
    echo ""

    # Create output directory
    if [ "$DRY_RUN" = false ]; then
        mkdir -p "$PROJECT_AGENTS_DIR"
    fi

    # Generate project agents for each agent type that has overrides
    local agents_to_specialize=("implementation" "test" "review")
    local generated=0

    for agent_name in "${agents_to_specialize[@]}"; do
        generate_agent "$agent_name" "$matched"
        ((generated++)) || true
    done

    echo ""

    if [ "$DRY_RUN" = true ]; then
        echo "Dry run complete. Use without --dry-run to generate files."
    else
        echo -e "${GREEN}Project agents written to .agentic/agents/claude/subagents-project/${NC}"
        echo ""
        echo "Next steps:"
        echo "  1. Review generated agents"
        echo "  2. Run: bash .agentic/tools/generate-skills.sh  (to update Claude skills)"
        echo "  3. Customize: add <!-- CUSTOMIZED --> to any file you want to hand-edit"

        # Update state for freshness tracking (use grep+write to avoid sed escaping issues)
        local state_dir="$ROOT_DIR/.agentic-state"
        mkdir -p "$state_dir"
        local state_file="$state_dir/sync-state.conf"
        local stack_hash
        stack_hash=$(git log -1 --format="%H" -- STACK.md 2>/dev/null || echo "none")
        if [ -f "$state_file" ]; then
            local tmp_file="${state_file}.tmp"
            grep -v "^agent_gen\." "$state_file" > "$tmp_file" 2>/dev/null || true
            echo "agent_gen.stack_hash=${stack_hash}" >> "$tmp_file"
            echo "agent_gen.last_run=$(date +%Y-%m-%d)" >> "$tmp_file"
            mv "$tmp_file" "$state_file"
        else
            echo "# Sync state (auto-maintained)" > "$state_file"
            echo "agent_gen.stack_hash=${stack_hash}" >> "$state_file"
            echo "agent_gen.last_run=$(date +%Y-%m-%d)" >> "$state_file"
        fi
    fi
}

main
