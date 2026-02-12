#!/usr/bin/env bash
# I01: Memory seeds in session 1, triggers work in session 2
# HUMAN-GUIDED: requires interactive Claude Code sessions
set -euo pipefail
source "$(dirname "$0")/../lib/helpers.sh"

section_header "I01: Memory Persistence (human-guided)"

PROJECT=$(scaffold_test_project "core-pm")
echo ""
echo -e "${YELLOW}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║  INTERACTIVE TEST: Memory Persistence (I01)                   ║${NC}"
echo -e "${YELLOW}╠═══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${YELLOW}║                                                               ║${NC}"
echo -e "${YELLOW}║  Step 1: Open this project in Claude Code:                    ║${NC}"
echo -e "${YELLOW}║    cd $PROJECT${NC}"
echo -e "${YELLOW}║    claude                                                     ║${NC}"
echo -e "${YELLOW}║                                                               ║${NC}"
echo -e "${YELLOW}║  Step 2: Say \"hi\" and wait for session start                  ║${NC}"
echo -e "${YELLOW}║    (agent should read STATUS.md, seed memory)                 ║${NC}"
echo -e "${YELLOW}║                                                               ║${NC}"
echo -e "${YELLOW}║  Step 3: Type /exit to end the session                        ║${NC}"
echo -e "${YELLOW}║                                                               ║${NC}"
echo -e "${YELLOW}║  Step 4: Press ENTER when done                                ║${NC}"
echo -e "${YELLOW}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""
read -r -p "Press ENTER after completing session 1..."

# Try to find project memory
echo ""
echo "Checking for seeded memory..."
MEMORY_FOUND=false

# Claude Code stores project memory in ~/.claude/projects/<hash>/
# The hash is based on the project path
if [[ -d "$HOME/.claude" ]]; then
    MEMORY_FILE=$(find "$HOME/.claude" -path "*/memory*" -name "*.md" 2>/dev/null | while read -r f; do
        # Check if this memory file is for our test project
        if grep -qi "spec\|acceptance\|trigger\|build.*plan\|fix.*test" "$f" 2>/dev/null; then
            echo "$f"
            break
        fi
    done)

    if [[ -n "$MEMORY_FILE" ]]; then
        MEMORY_FOUND=true
        pass_test "Memory file found: $MEMORY_FILE"
        if grep -qi "spec\|acceptance\|trigger\|build.*plan\|fix.*test" "$MEMORY_FILE"; then
            pass_test "Memory contains trigger-related content"
        else
            fail_test "Memory contains trigger-related content"
        fi
    else
        fail_test "Memory file with trigger content not found"
    fi
else
    fail_test "~/.claude directory not found"
fi

echo ""
echo -e "${YELLOW}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║  Step 5: Open same project again:                             ║${NC}"
echo -e "${YELLOW}║    cd $PROJECT${NC}"
echo -e "${YELLOW}║    claude                                                     ║${NC}"
echo -e "${YELLOW}║                                                               ║${NC}"
echo -e "${YELLOW}║  Step 6: Say this EXACT prompt:                               ║${NC}"
echo -e "${YELLOW}║    \"Build a user notification system\"                         ║${NC}"
echo -e "${YELLOW}║                                                               ║${NC}"
echo -e "${YELLOW}║  Step 7: Copy the agent's response and paste below            ║${NC}"
echo -e "${YELLOW}║    (or type 'skip'):                                          ║${NC}"
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
    skip_test "Session 2 response (skipped by user)"
else
    if echo -e "$RESPONSE" | grep -qi "spec\|acceptance\|criteria\|F-[0-9]"; then
        pass_test "Session 2: agent mentions spec/acceptance (memory persisted)"
    else
        fail_test "Session 2: agent mentions spec/acceptance (memory persisted)"
    fi

    if echo -e "$RESPONSE" | grep -qi "function.*notify\|class.*Notif\|def.*notify"; then
        fail_test "Session 2: agent does NOT write notification code"
    else
        pass_test "Session 2: agent does NOT write notification code"
    fi
fi

echo ""
echo "Test project: $PROJECT"
echo "(Not cleaning up — needed for I02)"

# Export for I02
echo "$PROJECT" > /tmp/infra-test-i01-project

print_summary
