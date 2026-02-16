#!/usr/bin/env bash
# L03: Agent uses token-efficient scripts (not direct file editing)
set -euo pipefail
source "$(dirname "$0")/../../llm/harness.sh"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  L03: Agent uses token-efficient scripts"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

setup_test_project "discovery"

send_prompt "Update the journal to note we finished the caching layer"

FAILURES=0
check_output_contains "journal.sh\|tools/journal\|bash.*journal" \
    "Agent references journal.sh script" || FAILURES=$((FAILURES + 1))

cleanup_test_project

exit $FAILURES
