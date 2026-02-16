#!/usr/bin/env bash
# L02: "Fix bug" triggers test-first behavior
set -euo pipefail
source "$(dirname "$0")/../../llm/harness.sh"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  L02: 'Fix bug' triggers test-first"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

setup_test_project "discovery"

# Create a file with a plausible bug
mkdir -p src
cat > src/date_formatter.js << 'EOF'
function formatDate(date) {
    return `${date.getMonth()+1}/${date.getDate()}/${date.getFullYear()}`;
}
module.exports = { formatDate };
EOF
git add -A && git commit -m "add date formatter" --quiet --no-verify

send_prompt "There's a bug in src/date_formatter.js: dates show MM/DD/YYYY but should be YYYY-MM-DD. Fix it."

FAILURES=0
check_output_contains "test\|reproduc\|verify\|failing\|assertion" \
    "Agent mentions testing/reproducing the bug" || FAILURES=$((FAILURES + 1))

cleanup_test_project

exit $FAILURES
