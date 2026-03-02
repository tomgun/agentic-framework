#!/usr/bin/env bash
# generate-skills.sh: Generate Claude Skills from hand-crafted skill sources
#
# Usage:
#   bash .agentic/tools/generate-skills.sh           # Generate all skills
#   bash .agentic/tools/generate-skills.sh --clean   # Remove generated skills first
#   bash .agentic/tools/generate-skills.sh --validate # Validate only, don't generate
#
# Source of truth: .agentic/agents/claude/skills/*/SKILL.md (hand-crafted)
# Generated output: .claude/skills/*/ (SKILL.md + scripts/ + references/)
#
# What the generator does:
#   1. Copies SKILL.md from source, injects VERSION into metadata
#   2. Copies scripts/, makes them executable
#   3. Copies references from .agentic/ sources (mapping table below)
#   4. Validates all spec requirements
#
# Reference copy mapping (source → skill/references/):
#   implementing-features: feature_start.md, feature_implementation.md, programming_standards.md
#   committing-changes: before_commit.md
#   reviewing-code: review_checklist.md, programming_standards.md
#   session-start: session_start.md
#   fixing-bugs: debugging_playbook.md
#   completing-work: feature_complete.md
#   writing-tests: test_strategy.md
#   planning-features: plan_review_loop.md
#   writing-specs: spec_writing.md, spec_evolution.md, spec_protection.md (custom)
#   exploring-codebase: (none)
#   researching-topics: (none)
#   updating-documentation: (none)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTIC_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$AGENTIC_DIR/.." && pwd)"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

SKILLS_SRC="$AGENTIC_DIR/agents/claude/skills"
SKILLS_OUT="$PROJECT_ROOT/.claude/skills"
VERSION=$(cat "$PROJECT_ROOT/VERSION" 2>/dev/null || echo "0.0.0")

VALIDATE_ONLY=false
ERRORS=0
WARNINGS=0

# Parse flags
while [[ $# -gt 0 ]]; do
    case "$1" in
        --clean)
            if [[ -d "$SKILLS_OUT" ]]; then
                echo -e "${YELLOW}Removing existing skills...${NC}"
                rm -rf "$SKILLS_OUT"
            fi
            shift
            ;;
        --validate)
            VALIDATE_ONLY=true
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# Check for skill sources
if [[ ! -d "$SKILLS_SRC" ]]; then
    echo -e "${RED}No skill sources found at $SKILLS_SRC${NC}"
    exit 1
fi

# ── Reference mapping ──────────────────────────────────────
# Maps skill-name → space-separated source files (relative to .agentic/)
# Uses a function instead of associative arrays for bash 3 compatibility (macOS)
get_refs() {
    case "$1" in
        implementing-features) echo "checklists/feature_start.md checklists/feature_implementation.md quality/programming_standards.md" ;;
        committing-changes)    echo "checklists/before_commit.md" ;;
        reviewing-code)        echo "quality/review_checklist.md quality/programming_standards.md" ;;
        session-start)         echo "checklists/session_start.md" ;;
        fixing-bugs)           echo "workflows/debugging_playbook.md" ;;
        completing-work)       echo "checklists/feature_complete.md" ;;
        writing-tests)         echo "quality/test_strategy.md" ;;
        planning-features)     echo "workflows/plan_review_loop.md" ;;
        writing-specs)         echo "workflows/spec_writing.md workflows/spec_evolution.md" ;;
        *)                     echo "" ;;  # no references
    esac
}

# ── Validation functions ───────────────────────────────────
validate_skill() {
    local skill_dir="$1"
    local skill_name
    skill_name=$(basename "$skill_dir")
    local skill_md="$skill_dir/SKILL.md"
    local local_errors=0

    if [[ ! -f "$skill_md" ]]; then
        echo -e "  ${RED}✗${NC} $skill_name: missing SKILL.md"
        ERRORS=$((ERRORS + 1))
        return
    fi

    # Extract frontmatter (between first --- and second ---)
    local frontmatter
    frontmatter=$(sed -n '2,/^---$/p' "$skill_md" | sed '$d')

    # V1: name field present and matches folder
    local name_field
    name_field=$(echo "$frontmatter" | grep "^name:" | sed 's/^name: *//' | tr -d '"' | tr -d "'" || true)
    if [[ -z "$name_field" ]]; then
        echo -e "  ${RED}✗${NC} $skill_name: missing 'name' field"
        local_errors=$((local_errors + 1))
    elif [[ "$name_field" != "$skill_name" ]]; then
        echo -e "  ${RED}✗${NC} $skill_name: name '$name_field' doesn't match folder '$skill_name'"
        local_errors=$((local_errors + 1))
    fi

    # V2: name doesn't contain "claude" or "anthropic"
    if echo "$name_field" | grep -qi "claude\|anthropic"; then
        echo -e "  ${RED}✗${NC} $skill_name: name contains 'claude' or 'anthropic'"
        local_errors=$((local_errors + 1))
    fi

    # V3: description <1024 characters
    local desc_len
    desc_len=$(echo "$frontmatter" | sed -n '/^description:/,/^[a-z]/p' | sed '$d' | wc -c | tr -d ' ')
    if [[ "$desc_len" -gt 1024 ]]; then
        echo -e "  ${RED}✗${NC} $skill_name: description too long (${desc_len} > 1024 chars)"
        local_errors=$((local_errors + 1))
    fi

    # V4: No model field
    if echo "$frontmatter" | grep -q "^model:"; then
        echo -e "  ${RED}✗${NC} $skill_name: non-standard 'model' field present (remove it)"
        local_errors=$((local_errors + 1))
    fi

    # V5: No XML tags in frontmatter
    if echo "$frontmatter" | grep -qE '<[a-zA-Z]'; then
        echo -e "  ${RED}✗${NC} $skill_name: XML tags found in frontmatter"
        local_errors=$((local_errors + 1))
    fi

    # V6: No README.md in skill folder
    if [[ -f "$skill_dir/README.md" ]]; then
        echo -e "  ${RED}✗${NC} $skill_name: README.md not allowed in skill folder"
        local_errors=$((local_errors + 1))
    fi

    # V7: Body <5000 words
    local body
    body=$(sed -n '/^---$/,$ p' "$skill_md" | tail -n +2)  # After second ---
    local word_count
    word_count=$(echo "$body" | wc -w | tr -d ' ')
    if [[ "$word_count" -gt 5000 ]]; then
        echo -e "  ${RED}✗${NC} $skill_name: body too long (${word_count} > 5000 words)"
        local_errors=$((local_errors + 1))
    fi

    # V8: No {PLACEHOLDER} syntax (allow ${VERSION} — replaced during generation)
    local placeholders
    placeholders=$(grep -oE '\{[A-Z_]+\}' "$skill_md" 2>/dev/null | grep -v 'VERSION' | sort -u || true)
    if [[ -n "$placeholders" ]]; then
        echo -e "  ${RED}✗${NC} $skill_name: unresolved placeholders: $placeholders"
        local_errors=$((local_errors + 1))
    fi

    # V9: compatibility field present
    if ! echo "$frontmatter" | grep -q "^compatibility:"; then
        echo -e "  ${RED}✗${NC} $skill_name: missing 'compatibility' field"
        local_errors=$((local_errors + 1))
    fi

    # V10: metadata with author and version
    if ! echo "$frontmatter" | grep -q "author:"; then
        echo -e "  ${RED}✗${NC} $skill_name: missing metadata.author"
        local_errors=$((local_errors + 1))
    fi
    if ! echo "$frontmatter" | grep -q "version:"; then
        echo -e "  ${RED}✗${NC} $skill_name: missing metadata.version"
        local_errors=$((local_errors + 1))
    fi

    # V11: scripts are executable (check source)
    if [[ -d "$skill_dir/scripts" ]]; then
        for script in "$skill_dir/scripts"/*.sh; do
            [[ -f "$script" ]] || continue
            if [[ ! -x "$script" ]]; then
                echo -e "  ${YELLOW}⚠${NC} $skill_name: $(basename "$script") not executable"
                WARNINGS=$((WARNINGS + 1))
            fi
        done
    fi

    if [[ $local_errors -eq 0 ]]; then
        echo -e "  ${GREEN}✓${NC} $skill_name: valid"
    else
        ERRORS=$((ERRORS + local_errors))
    fi
}

# ── Validate-only mode ─────────────────────────────────────
if $VALIDATE_ONLY; then
    echo -e "${BLUE}Validating skill sources...${NC}"
    for skill_src_dir in "$SKILLS_SRC"/*/; do
        [[ -d "$skill_src_dir" ]] || continue
        validate_skill "$skill_src_dir"
    done
    echo ""
    if [[ $ERRORS -gt 0 ]]; then
        echo -e "${RED}Validation failed: $ERRORS error(s), $WARNINGS warning(s)${NC}"
        exit 1
    else
        echo -e "${GREEN}All skills valid ($WARNINGS warning(s))${NC}"
        exit 0
    fi
fi

# ── Generate skills ────────────────────────────────────────
echo -e "${BLUE}Generating Claude Skills from hand-crafted sources...${NC}"
echo -e "  Source: .agentic/agents/claude/skills/"
echo -e "  Output: .claude/skills/"
echo -e "  Version: $VERSION"
echo ""

mkdir -p "$SKILLS_OUT"

GENERATED=0

for skill_src_dir in "$SKILLS_SRC"/*/; do
    [[ -d "$skill_src_dir" ]] || continue
    skill_name=$(basename "$skill_src_dir")

    # Validate source first
    validate_skill "$skill_src_dir"

    dest_dir="$SKILLS_OUT/$skill_name"
    mkdir -p "$dest_dir"

    # 1. Copy SKILL.md with version injection
    sed "s/\${VERSION}/$VERSION/g" "$skill_src_dir/SKILL.md" > "$dest_dir/SKILL.md"

    # 2. Copy scripts/ and make executable
    if [[ -d "$skill_src_dir/scripts" ]]; then
        mkdir -p "$dest_dir/scripts"
        for script in "$skill_src_dir/scripts"/*; do
            [[ -f "$script" ]] || continue
            cp "$script" "$dest_dir/scripts/"
            chmod +x "$dest_dir/scripts/$(basename "$script")"
        done
    fi

    # 3. Copy references from mapping table
    ref_sources=$(get_refs "$skill_name")
    if [[ -n "$ref_sources" ]]; then
        mkdir -p "$dest_dir/references"
        for ref_source in $ref_sources; do
            local_path="$AGENTIC_DIR/$ref_source"
            if [[ -f "$local_path" ]]; then
                cp "$local_path" "$dest_dir/references/$(basename "$ref_source")"
            else
                echo -e "  ${YELLOW}⚠${NC} Reference not found: $ref_source"
                WARNINGS=$((WARNINGS + 1))
            fi
        done
    fi

    # 3b. Copy source skill's own references/ (skill-specific, not in mapping)
    if [[ -d "$skill_src_dir/references" ]]; then
        mkdir -p "$dest_dir/references"
        for src_ref in "$skill_src_dir/references"/*; do
            [[ -f "$src_ref" ]] || continue
            ref_basename=$(basename "$src_ref")
            # Don't overwrite mapping-sourced references
            if [[ ! -f "$dest_dir/references/$ref_basename" ]]; then
                cp "$src_ref" "$dest_dir/references/$ref_basename"
            fi
        done
    fi

    echo -e "  ${GREEN}✓${NC} $skill_name → .claude/skills/$skill_name/"
    GENERATED=$((GENERATED + 1))
done

# ── Generate extension skills from .agentic-local/extensions/skills/ ─
EXT_SKILLS_DIR="$PROJECT_ROOT/.agentic-local/extensions/skills"
EXT_GENERATED=0

if [[ -d "$EXT_SKILLS_DIR" ]] && ! $VALIDATE_ONLY; then
    for ext_skill_dir in "$EXT_SKILLS_DIR"/*/; do
        [[ -d "$ext_skill_dir" ]] || continue
        ext_skill_name=$(basename "$ext_skill_dir")
        ext_skill_md="$ext_skill_dir/SKILL.md"

        [[ -f "$ext_skill_md" ]] || continue

        # Validate extension skill
        validate_skill "$ext_skill_dir"

        dest_dir="$SKILLS_OUT/$ext_skill_name"
        mkdir -p "$dest_dir"

        # Copy SKILL.md (no version injection for user extensions)
        cp "$ext_skill_md" "$dest_dir/SKILL.md"

        # Copy scripts/ and make executable
        if [[ -d "$ext_skill_dir/scripts" ]]; then
            mkdir -p "$dest_dir/scripts"
            for script in "$ext_skill_dir/scripts"/*; do
                [[ -f "$script" ]] || continue
                cp "$script" "$dest_dir/scripts/"
                chmod +x "$dest_dir/scripts/$(basename "$script")"
            done
        fi

        # Copy references/
        if [[ -d "$ext_skill_dir/references" ]]; then
            mkdir -p "$dest_dir/references"
            for ref in "$ext_skill_dir/references"/*; do
                [[ -f "$ref" ]] || continue
                cp "$ref" "$dest_dir/references/"
            done
        fi

        echo -e "  ${GREEN}✓${NC} $ext_skill_name → .claude/skills/$ext_skill_name/ (extension)"
        EXT_GENERATED=$((EXT_GENERATED + 1))
    done
fi

# ── Inject project-specific rules from subagents-project/ ─
# Maps agent type → skill name
agent_to_skill() {
    case "$1" in
        implementation) echo "implementing-features" ;;
        test)           echo "writing-tests" ;;
        review)         echo "reviewing-code" ;;
        *)              echo "" ;;
    esac
}

PROJECT_AGENTS_DIR="$AGENTIC_DIR/agents/claude/subagents-project"
INJECTED=0

if [[ -d "$PROJECT_AGENTS_DIR" ]] && ! $VALIDATE_ONLY; then
    for agent_file in "$PROJECT_AGENTS_DIR"/*-agent.md; do
        [[ -f "$agent_file" ]] || continue

        # Extract agent type from filename (e.g., implementation-agent.md → implementation)
        agent_type=$(basename "$agent_file" | sed 's/-agent\.md$//')
        skill_name=$(agent_to_skill "$agent_type")
        [[ -z "$skill_name" ]] && continue

        skill_md="$SKILLS_OUT/$skill_name/SKILL.md"
        [[ -f "$skill_md" ]] || continue

        # Extract project-specific content (everything from "## Project-Specific Rules" onward,
        # stopping before the footer separator)
        project_content=$(sed -n '/^## Project-Specific Rules/,/^---$/p' "$agent_file" | sed '$d')
        [[ -z "$project_content" ]] && continue

        # Strip any existing PROJECT-RULES block before appending (idempotent re-runs)
        if grep -q '<!-- PROJECT-RULES-START' "$skill_md" 2>/dev/null; then
            local tmp_skill="${skill_md}.tmp"
            sed '/<!-- PROJECT-RULES-START/,/<!-- PROJECT-RULES-END/d' "$skill_md" > "$tmp_skill" && mv "$tmp_skill" "$skill_md"
        fi

        # Append project-specific rules to the skill
        printf '\n<!-- PROJECT-RULES-START (auto-injected from subagents-project/) -->\n%s\n<!-- PROJECT-RULES-END -->\n' "$project_content" >> "$skill_md"

        echo -e "  ${GREEN}+${NC} injected project rules → $skill_name"
        INJECTED=$((INJECTED + 1))
    done
fi

# ── Inject rules from .agentic-local/extensions/rules/ ──
EXT_RULES_DIR="$PROJECT_ROOT/.agentic-local/extensions/rules"
if [[ -d "$EXT_RULES_DIR" ]] && ! $VALIDATE_ONLY; then
    declare -A _seen_rules=()
    for rule_file in "$EXT_RULES_DIR"/*-agent.md "$EXT_RULES_DIR"/*.md; do
        [[ -f "$rule_file" ]] || continue
        [[ -n "${_seen_rules[$rule_file]:-}" ]] && continue
        _seen_rules["$rule_file"]=1

        # Determine target skill from filename or content
        rule_basename=$(basename "$rule_file" .md)
        # Try mapping agent-style names (e.g., implementation-agent.md)
        agent_type=$(echo "$rule_basename" | sed 's/-agent$//')
        skill_name=$(agent_to_skill "$agent_type")

        # If no mapping, try using filename directly as skill name
        if [[ -z "$skill_name" ]]; then
            [[ -d "$SKILLS_OUT/$rule_basename" ]] && skill_name="$rule_basename"
        fi
        [[ -z "$skill_name" ]] && continue

        skill_md="$SKILLS_OUT/$skill_name/SKILL.md"
        [[ -f "$skill_md" ]] || continue

        project_content=$(sed -n '/^## Project-Specific Rules/,/^---$/p' "$rule_file" | sed '$d')
        [[ -z "$project_content" ]] && project_content=$(cat "$rule_file")
        [[ -z "$project_content" ]] && continue

        # Strip existing EXT-RULES block (idempotent)
        if grep -q '<!-- EXT-RULES-START' "$skill_md" 2>/dev/null; then
            sed '/<!-- EXT-RULES-START/,/<!-- EXT-RULES-END/d' "$skill_md" > "${skill_md}.tmp" && mv "${skill_md}.tmp" "$skill_md"
        fi

        printf '\n<!-- EXT-RULES-START (auto-injected from .agentic-local/extensions/rules/) -->\n%s\n<!-- EXT-RULES-END -->\n' "$project_content" >> "$skill_md"

        echo -e "  ${GREEN}+${NC} injected extension rules → $skill_name"
        INJECTED=$((INJECTED + 1))
    done
fi

echo ""
if [[ $ERRORS -gt 0 ]]; then
    echo -e "${RED}Generated $GENERATED skills with $ERRORS error(s) and $WARNINGS warning(s)${NC}"
    echo "Fix validation errors in source files before deploying."
    exit 1
else
    local_msg="${GREEN}Generated $GENERATED skills"
    if [[ $EXT_GENERATED -gt 0 ]]; then
        local_msg="$local_msg + $EXT_GENERATED extension skills"
    fi
    if [[ $INJECTED -gt 0 ]]; then
        local_msg="$local_msg + $INJECTED project-specific injections"
    fi
    echo -e "$local_msg ($WARNINGS warning(s))${NC}"
fi

echo ""
echo "Skills are auto-discovered by Claude Code based on task description."
echo "Source of truth: .agentic/agents/claude/skills/"
if [[ $INJECTED -gt 0 ]]; then
    echo "Project rules from: .agentic/agents/claude/subagents-project/"
fi
echo ""
echo "To regenerate: bash .agentic/tools/generate-skills.sh"
echo "To validate only: bash .agentic/tools/generate-skills.sh --validate"
