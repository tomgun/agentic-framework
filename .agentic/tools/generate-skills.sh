#!/usr/bin/env bash
# generate-skills.sh: Generate Claude Skills from subagent definitions
#
# Usage:
#   bash .agentic/tools/generate-skills.sh           # Generate all skills
#   bash .agentic/tools/generate-skills.sh --clean   # Remove generated skills first
#
# This creates .claude/skills/ from .agentic/agents/claude/subagents/
# Skills are auto-discovered by Claude Code based on task description.
#
# Source of truth: .agentic/agents/claude/subagents/*.md
# Generated output: .claude/skills/*/SKILL.md

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTIC_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$AGENTIC_DIR/.." && pwd)"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

SUBAGENTS_DIR="$AGENTIC_DIR/agents/claude/subagents"
SKILLS_DIR="$PROJECT_ROOT/.claude/skills"

# Clean existing generated skills if requested
if [[ "${1:-}" == "--clean" ]]; then
    if [[ -d "$SKILLS_DIR" ]]; then
        echo -e "${YELLOW}Removing existing skills...${NC}"
        rm -rf "$SKILLS_DIR"
    fi
    shift
fi

# Check for subagents
if [[ ! -d "$SUBAGENTS_DIR" ]]; then
    echo "No subagents found at $SUBAGENTS_DIR"
    exit 0
fi

echo -e "${BLUE}Generating Claude Skills from subagent definitions...${NC}"
echo ""

# Create skills directory
mkdir -p "$SKILLS_DIR"

# Track what we generate
GENERATED=0

# Process each subagent
for subagent_file in "$SUBAGENTS_DIR"/*.md; do
    [[ -f "$subagent_file" ]] || continue

    filename=$(basename "$subagent_file")

    # Skip README or non-agent files
    [[ "$filename" == "README.md" ]] && continue

    # Extract agent name (remove -agent.md suffix)
    agent_name=$(echo "$filename" | sed 's/-agent\.md$//' | sed 's/\.md$//')

    # Create skill directory
    skill_dir="$SKILLS_DIR/$agent_name"
    mkdir -p "$skill_dir"

    # Extract key info from subagent file
    purpose=$(grep -A1 "^\*\*Purpose\*\*:" "$subagent_file" | head -1 | sed 's/\*\*Purpose\*\*: //')

    # Extract "When to Use" section for triggers
    when_to_use=$(sed -n '/^## When to Use/,/^## /p' "$subagent_file" | grep "^- " | head -6)

    # Extract model recommendation (handles different formats)
    model_line=$(grep -i "model" "$subagent_file" | grep -i "tier\|selection\|recommended" | head -1)
    if echo "$model_line" | grep -qi "cheap\|fast\|haiku\|mini"; then
        model="haiku"
    elif echo "$model_line" | grep -qi "opus\|expensive"; then
        model="opus"
    else
        model="sonnet"
    fi

    # Determine allowed tools based on agent type
    case "$agent_name" in
        explore)
            allowed_tools="Glob, Grep, Read, Bash"
            ;;
        research)
            allowed_tools="WebSearch, WebFetch, Read, Write"
            ;;
        review)
            allowed_tools="Read, Grep, Glob"
            ;;
        implementation)
            allowed_tools="Read, Write, Edit, Bash, Glob, Grep"
            ;;
        test)
            allowed_tools="Read, Write, Edit, Bash, Glob, Grep"
            ;;
        git)
            allowed_tools="Bash, Read"
            ;;
        documentation)
            allowed_tools="Read, Write, Edit, Glob"
            ;;
        planning)
            allowed_tools="Read, Glob, Grep"
            ;;
        *)
            allowed_tools=""
            ;;
    esac

    # Capitalize first letter (portable approach)
    first_char=$(echo "${agent_name:0:1}" | tr '[:lower:]' '[:upper:]')
    agent_title="${first_char}${agent_name:1}"

    # Generate SKILL.md
    cat > "$skill_dir/SKILL.md" << SKILLEOF
---
description: ${purpose}
model: ${model}
SKILLEOF

    if [[ -n "$allowed_tools" ]]; then
        echo "allowed-tools: [$allowed_tools]" >> "$skill_dir/SKILL.md"
    fi

    cat >> "$skill_dir/SKILL.md" << SKILLEOF
---

# ${agent_title} Skill

${purpose}

## When This Skill Activates

This skill is auto-discovered when your task involves:
${when_to_use}

## Instructions

SKILLEOF

    # Extract prompt template content (between ``` markers)
    # Portable: extract section, then use sed to get content between first ``` and last ```
    prompt_content=$(sed -n '/^## Prompt Template/,/^## /p' "$subagent_file" | \
        sed -n '/^```/,/^```/p' | sed '1d;$d' 2>/dev/null || echo "")
    if [[ -n "$prompt_content" ]]; then
        echo "$prompt_content" >> "$skill_dir/SKILL.md"
    fi

    # Add expected deliverables if prompt doesn't include output format
    deliverables=$(sed -n '/^## Expected Deliverables/,/^## /p' "$subagent_file" | grep "^- " || true)
    if [[ -n "$deliverables" ]] && ! echo "$prompt_content" | grep -qi "output format"; then
        cat >> "$skill_dir/SKILL.md" << SKILLEOF

## Expected Output

SKILLEOF
        echo "$deliverables" >> "$skill_dir/SKILL.md"
    fi

    cat >> "$skill_dir/SKILL.md" << SKILLEOF

---
*Generated from: .agentic/agents/claude/subagents/${filename}*
*To modify, edit the source file and run: bash .agentic/tools/generate-skills.sh*
SKILLEOF

    echo -e "  ${GREEN}✓${NC} $agent_name → .claude/skills/$agent_name/SKILL.md"
    ((GENERATED++))
done

echo ""
echo -e "${GREEN}Generated $GENERATED skills in .claude/skills/${NC}"
echo ""
echo "Skills are auto-discovered by Claude Code based on task description."
echo "Source of truth: .agentic/agents/claude/subagents/*.md"
echo ""
echo "To regenerate after changes: bash .agentic/tools/generate-skills.sh"
