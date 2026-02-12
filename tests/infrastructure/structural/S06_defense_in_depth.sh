#!/usr/bin/env bash
# S06: Defense-in-depth — hooks catch what instructions miss
#
# THE KILLER TEST: Simulates an LLM that ignores CLAUDE.md instruction
# to update JOURNAL.md before committing. The git hook should catch it.
#
# This proves: even when Layer 1 (instructions) fails,
# Layer 2 (hooks) catches it. The framework doesn't depend on LLM compliance alone.
set -euo pipefail
source "$(dirname "$0")/../lib/helpers.sh"

section_header "S06: Defense-in-depth (hooks catch LLM misses)"

PROJECT=$(scaffold_test_project "core")
cd "$PROJECT"

# Simulate: LLM makes code changes but IGNORES the instruction
# to update JOURNAL.md before committing
echo "function newFeature() { return true; }" > feature.js
sleep 2  # Ensure mtime gap from initial commit

# Stage the code change but deliberately do NOT touch JOURNAL.md
# This simulates an LLM that didn't follow CLAUDE.md instructions
git add feature.js

OUTPUT=$(git commit -m "add feature without journal update" 2>&1) && EXIT_CODE=0 || EXIT_CODE=$?

assert_exit_code 1 "$EXIT_CODE" "hook blocks commit when JOURNAL.md not updated"
assert_output_contains "$OUTPUT" "JOURNAL\|not updated\|BLOCKED" \
    "hook catches missing JOURNAL update (defense-in-depth)"

echo ""
echo -e "  ${GREEN}PROVEN:${NC} Even when the LLM ignores CLAUDE.md instructions,"
echo -e "         the git hook catches the violation at commit time."
echo -e "         Git hooks can't be talked out of enforcement."

cleanup_test_project "$PROJECT"
print_summary
