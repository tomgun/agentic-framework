#!/usr/bin/env bash
# validate_skills.sh: Validate Claude Skills against Anthropic spec requirements
#
# Usage: bash tests/validate_skills.sh [--verbose]
#
# Checks:
#   1. name field present and matches folder name (kebab-case)
#   2. name doesn't contain "claude" or "anthropic"
#   3. description <1024 characters
#   4. No model field (non-standard)
#   5. No XML tags in frontmatter
#   6. No README.md in skill folder
#   7. SKILL.md body <5000 words
#   8. No {PLACEHOLDER} syntax (except ${VERSION} in sources)
#   9. compatibility field present
#  10. metadata with author and version
#  11. scripts/ files are executable
#  12. references/ files exist and have YAML frontmatter
#  13. Skill source exists for each generated skill

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

VERBOSE=false
[[ "${1:-}" == "--verbose" ]] && VERBOSE=true

SKILLS_DIR="$PROJECT_ROOT/.claude/skills"
SKILLS_SRC="$PROJECT_ROOT/.agentic/agents/claude/skills"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ERRORS=0
WARNINGS=0
SKILLS_CHECKED=0

echo -e "${BLUE}=== Claude Skills Validation ===${NC}"
echo ""

# Check generated skills exist
if [[ ! -d "$SKILLS_DIR" ]]; then
    echo -e "${RED}FAIL: No generated skills found at .claude/skills/${NC}"
    echo "  Run: bash .agentic/tools/generate-skills.sh"
    exit 1
fi

# Check skill sources exist
if [[ ! -d "$SKILLS_SRC" ]]; then
    echo -e "${RED}FAIL: No skill sources found at .agentic/agents/claude/skills/${NC}"
    exit 1
fi

# Count skills
SKILL_COUNT=$(ls -1d "$SKILLS_DIR"/*/ 2>/dev/null | wc -l | tr -d ' ')
SRC_COUNT=$(ls -1d "$SKILLS_SRC"/*/ 2>/dev/null | wc -l | tr -d ' ')

echo "Generated skills: $SKILL_COUNT"
echo "Source skills: $SRC_COUNT"
echo ""

if [[ "$SKILL_COUNT" -ne "$SRC_COUNT" ]]; then
    echo -e "${YELLOW}WARNING: Generated ($SKILL_COUNT) != Source ($SRC_COUNT) — regenerate with: bash .agentic/tools/generate-skills.sh${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

# Expected skills list
EXPECTED_SKILLS="committing-changes completing-work exploring-codebase fixing-bugs implementing-features managing-specs planning-features researching-topics reviewing-code session-start updating-documentation writing-tests"

for expected in $EXPECTED_SKILLS; do
    if [[ ! -d "$SKILLS_DIR/$expected" ]]; then
        echo -e "${RED}FAIL: Expected skill missing: $expected${NC}"
        ERRORS=$((ERRORS + 1))
    fi
done

# Validate each generated skill
for skill_dir in "$SKILLS_DIR"/*/; do
    [[ -d "$skill_dir" ]] || continue
    skill_name=$(basename "$skill_dir")
    skill_md="$skill_dir/SKILL.md"
    SKILLS_CHECKED=$((SKILLS_CHECKED + 1))

    if [[ ! -f "$skill_md" ]]; then
        echo -e "${RED}FAIL: $skill_name — missing SKILL.md${NC}"
        ERRORS=$((ERRORS + 1))
        continue
    fi

    # Extract frontmatter
    frontmatter=$(sed -n '2,/^---$/p' "$skill_md" | sed '$d')
    local_errors=0

    # 1. name field matches folder
    name_field=$(echo "$frontmatter" | grep "^name:" | sed 's/^name: *//' | tr -d '"' | tr -d "'" || true)
    if [[ -z "$name_field" ]]; then
        echo -e "${RED}FAIL: $skill_name — missing 'name' field${NC}"
        local_errors=$((local_errors + 1))
    elif [[ "$name_field" != "$skill_name" ]]; then
        echo -e "${RED}FAIL: $skill_name — name '$name_field' != folder '$skill_name'${NC}"
        local_errors=$((local_errors + 1))
    fi

    # 2. No claude/anthropic in name
    if echo "$name_field" | grep -qi "claude\|anthropic"; then
        echo -e "${RED}FAIL: $skill_name — name contains 'claude' or 'anthropic'${NC}"
        local_errors=$((local_errors + 1))
    fi

    # 3. description <1024 chars
    desc_text=$(echo "$frontmatter" | sed -n '/^description:/,/^[a-z]/p' | sed '$d' || true)
    desc_len=$(echo "$desc_text" | wc -c | tr -d ' ')
    if [[ "$desc_len" -gt 1024 ]]; then
        echo -e "${RED}FAIL: $skill_name — description too long (${desc_len} > 1024)${NC}"
        local_errors=$((local_errors + 1))
    fi

    # 4. No model field
    if echo "$frontmatter" | grep -q "^model:"; then
        echo -e "${RED}FAIL: $skill_name — has non-standard 'model' field${NC}"
        local_errors=$((local_errors + 1))
    fi

    # 5. No XML tags in frontmatter
    if echo "$frontmatter" | grep -qE '<[a-zA-Z]'; then
        echo -e "${RED}FAIL: $skill_name — XML tags in frontmatter${NC}"
        local_errors=$((local_errors + 1))
    fi

    # 6. No README.md
    if [[ -f "$skill_dir/README.md" ]]; then
        echo -e "${RED}FAIL: $skill_name — README.md not allowed in skill folder${NC}"
        local_errors=$((local_errors + 1))
    fi

    # 7. Body <5000 words
    body=$(sed -n '/^---$/,$ p' "$skill_md" | tail -n +2)
    word_count=$(echo "$body" | wc -w | tr -d ' ')
    if [[ "$word_count" -gt 5000 ]]; then
        echo -e "${RED}FAIL: $skill_name — body ${word_count} words > 5000${NC}"
        local_errors=$((local_errors + 1))
    fi

    # 8. No unresolved placeholders (in generated output, VERSION should be resolved)
    if grep -qE '\$\{[A-Z_]+\}' "$skill_md" 2>/dev/null; then
        placeholders=$(grep -oE '\$\{[A-Z_]+\}' "$skill_md" | sort -u || true)
        echo -e "${RED}FAIL: $skill_name — unresolved placeholders: $placeholders${NC}"
        local_errors=$((local_errors + 1))
    fi

    # 9. compatibility field
    if ! echo "$frontmatter" | grep -q "^compatibility:"; then
        echo -e "${RED}FAIL: $skill_name — missing 'compatibility' field${NC}"
        local_errors=$((local_errors + 1))
    fi

    # 10. metadata
    if ! echo "$frontmatter" | grep -q "author:"; then
        echo -e "${RED}FAIL: $skill_name — missing metadata.author${NC}"
        local_errors=$((local_errors + 1))
    fi
    if ! echo "$frontmatter" | grep -q "version:"; then
        echo -e "${RED}FAIL: $skill_name — missing metadata.version${NC}"
        local_errors=$((local_errors + 1))
    fi

    # 11. scripts executable
    if [[ -d "$skill_dir/scripts" ]]; then
        for script in "$skill_dir/scripts"/*.sh; do
            [[ -f "$script" ]] || continue
            if [[ ! -x "$script" ]]; then
                echo -e "${YELLOW}WARN: $skill_name — $(basename "$script") not executable${NC}"
                WARNINGS=$((WARNINGS + 1))
            fi
        done
    fi

    # 12. references have frontmatter
    if [[ -d "$skill_dir/references" ]]; then
        for ref in "$skill_dir/references"/*.md; do
            [[ -f "$ref" ]] || continue
            if ! head -1 "$ref" | grep -q "^---"; then
                echo -e "${YELLOW}WARN: $skill_name — reference $(basename "$ref") missing YAML frontmatter${NC}"
                WARNINGS=$((WARNINGS + 1))
            fi
        done
    fi

    # 13. Source skill exists
    if [[ ! -d "$SKILLS_SRC/$skill_name" ]]; then
        echo -e "${YELLOW}WARN: $skill_name — no source found (custom skill?)${NC}"
        WARNINGS=$((WARNINGS + 1))
    fi

    ERRORS=$((ERRORS + local_errors))

    if [[ $local_errors -eq 0 ]]; then
        $VERBOSE && echo -e "${GREEN}PASS: $skill_name (${word_count}w, ${desc_len}c desc)${NC}"
    fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ $ERRORS -gt 0 ]]; then
    echo -e "${RED}FAILED: $SKILLS_CHECKED skills checked, $ERRORS error(s), $WARNINGS warning(s)${NC}"
    exit 1
else
    echo -e "${GREEN}PASSED: $SKILLS_CHECKED skills checked, 0 errors, $WARNINGS warning(s)${NC}"
fi
