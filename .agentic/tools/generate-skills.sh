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
#   exploring-codebase: (none)
#   researching-topics: (none)
#   updating-documentation: (none)
#   managing-specs: (none)

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

    echo -e "  ${GREEN}✓${NC} $skill_name → .claude/skills/$skill_name/"
    GENERATED=$((GENERATED + 1))
done

echo ""
if [[ $ERRORS -gt 0 ]]; then
    echo -e "${RED}Generated $GENERATED skills with $ERRORS error(s) and $WARNINGS warning(s)${NC}"
    echo "Fix validation errors in source files before deploying."
    exit 1
else
    echo -e "${GREEN}Generated $GENERATED skills ($WARNINGS warning(s))${NC}"
fi

echo ""
echo "Skills are auto-discovered by Claude Code based on task description."
echo "Source of truth: .agentic/agents/claude/skills/"
echo ""
echo "To regenerate: bash .agentic/tools/generate-skills.sh"
echo "To validate only: bash .agentic/tools/generate-skills.sh --validate"
