#!/usr/bin/env bash
# I02: Memory mutation — delete memory, behavior degrades
# HUMAN-GUIDED: continues from I01
set -euo pipefail
source "$(dirname "$0")/../lib/helpers.sh"

section_header "I02: Memory Mutation (human-guided)"

# Get project from I01
if [[ -f /tmp/infra-test-i01-project ]]; then
    PROJECT=$(cat /tmp/infra-test-i01-project)
else
    echo -e "${RED}ERROR: Run I01 first (no project path found)${NC}"
    exit 1
fi

if [[ ! -d "$PROJECT" ]]; then
    echo -e "${RED}ERROR: I01 project no longer exists: $PROJECT${NC}"
    exit 1
fi

echo ""
echo "Searching for project memory to delete..."

# Find and delete the project memory
MEMORY_DELETED=false
if [[ -d "$HOME/.claude" ]]; then
    while IFS= read -r f; do
        if grep -qi "spec\|acceptance\|trigger\|build.*plan\|fix.*test" "$f" 2>/dev/null; then
            echo "Found memory: $f"
            echo "Deleting..."
            rm "$f"
            MEMORY_DELETED=true
            pass_test "Project memory deleted"
            break
        fi
    done < <(find "$HOME/.claude" -path "*/memory*" -name "*.md" 2>/dev/null)
fi

if [[ "$MEMORY_DELETED" != true ]]; then
    echo -e "${YELLOW}Could not find project memory to delete.${NC}"
    echo "You may need to manually delete it from ~/.claude/projects/"
    echo ""
    read -r -p "Press ENTER after manually deleting the memory file..."
fi

echo ""
echo -e "${YELLOW}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║  MUTATION: Memory deleted                                     ║${NC}"
echo -e "${YELLOW}║                                                               ║${NC}"
echo -e "${YELLOW}║  Step 1: Open same project again:                             ║${NC}"
echo -e "${YELLOW}║    cd $PROJECT${NC}"
echo -e "${YELLOW}║    claude                                                     ║${NC}"
echo -e "${YELLOW}║                                                               ║${NC}"
echo -e "${YELLOW}║  Step 2: Say EXACT same prompt:                               ║${NC}"
echo -e "${YELLOW}║    \"Build a user notification system\"                         ║${NC}"
echo -e "${YELLOW}║                                                               ║${NC}"
echo -e "${YELLOW}║  Step 3: Copy the agent's response and paste below:           ║${NC}"
echo -e "${YELLOW}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -n "Paste response (end with Ctrl+D on empty line, or type 'skip'): "

RESPONSE=""
while IFS= read -r line; do
    if [[ "$line" == "skip" ]]; then
        RESPONSE="[SKIPPED]"
        break
    fi
    RESPONSE="${RESPONSE}${line}\n"
done

if [[ "$RESPONSE" == "[SKIPPED]" ]]; then
    skip_test "Mutation response (skipped by user)"
else
    echo ""
    echo -e "${BLUE}Analyzing mutation result...${NC}"
    echo ""

    STILL_MENTIONS_SPECS=false
    if echo -e "$RESPONSE" | grep -qi "spec\|acceptance\|criteria\|F-[0-9]"; then
        STILL_MENTIONS_SPECS=true
    fi

    if [[ "$STILL_MENTIONS_SPECS" == true ]]; then
        echo -e "  ${YELLOW}RESULT:${NC} Agent STILL mentions specs after memory deletion"
        echo ""
        echo "  Interpretation: Memory deletion had no effect."
        echo "  CLAUDE.md triggers are the primary enforcement mechanism."
        echo "  Memory seed is redundant reinforcement (defense-in-depth)."
        echo ""
        pass_test "CLAUDE.md alone is sufficient for spec-first behavior"
    else
        echo -e "  ${YELLOW}RESULT:${NC} Agent codes directly after memory deletion"
        echo ""
        echo "  Interpretation: Memory was the critical enforcement factor."
        echo "  CLAUDE.md alone is insufficient — memory seed is necessary."
        echo ""
        pass_test "Memory seed is a necessary enforcement component"
    fi
fi

# Cleanup
cleanup_test_project "$PROJECT"
rm -f /tmp/infra-test-i01-project

print_summary
