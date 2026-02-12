#!/usr/bin/env bash
# S08: Template CLAUDE.md under 100 lines
# Validates L-0002 (empirical ceiling for instruction salience)
set -euo pipefail
source "$(dirname "$0")/../lib/helpers.sh"

section_header "S08: Template CLAUDE.md under 100 lines (L-0002)"

CLAUDE_MD="$FRAMEWORK_ROOT/.agentic/agents/claude/CLAUDE.md"

assert_file_exists "$CLAUDE_MD" "CLAUDE.md template exists"

LINE_COUNT=$(wc -l < "$CLAUDE_MD" | tr -d ' ')

if [[ $LINE_COUNT -le 100 ]]; then
    pass_test "CLAUDE.md is $LINE_COUNT lines (limit: 100)"
else
    fail_test "CLAUDE.md is $LINE_COUNT lines (limit: 100)" \
        "L-0002: Instructions over 100 lines lose salience with LLMs"
fi

echo ""
echo -e "  ${DIM}L-0002: Empirical ceiling — LLM compliance drops sharply${NC}"
echo -e "  ${DIM}when instruction files exceed ~100 lines.${NC}"

print_summary
