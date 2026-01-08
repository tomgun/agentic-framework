#!/usr/bin/env bash
# quick_issue.sh: Quickly log a bug/issue to ISSUES.md
# Usage: bash .agentic/tools/quick_issue.sh "Issue title" [priority] [severity]
#
# Examples:
#   bash .agentic/tools/quick_issue.sh "Login button not working"
#   bash .agentic/tools/quick_issue.sh "Memory leak in parser" high major
#   bash .agentic/tools/quick_issue.sh "Typo in header" low cosmetic

set -euo pipefail

ISSUE_TITLE="${1:-}"
PRIORITY="${2:-medium}"
SEVERITY="${3:-minor}"
ISSUES_FILE="spec/ISSUES.md"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

if [[ -z "$ISSUE_TITLE" ]]; then
    echo "Usage: bash .agentic/tools/quick_issue.sh \"Issue title\" [priority] [severity]"
    echo ""
    echo "Examples:"
    echo "  bash .agentic/tools/quick_issue.sh \"Login fails on Safari\""
    echo "  bash .agentic/tools/quick_issue.sh \"Memory leak\" high major"
    echo ""
    echo "Priority: critical, high, medium (default), low"
    echo "Severity: blocker, major, minor (default), cosmetic"
    exit 1
fi

# Check if ISSUES.md exists, create from template if not
if [[ ! -f "$ISSUES_FILE" ]]; then
    echo -e "${YELLOW}Creating $ISSUES_FILE from template...${NC}"
    mkdir -p spec
    if [[ -f ".agentic/spec/ISSUES.template.md" ]]; then
        cp .agentic/spec/ISSUES.template.md "$ISSUES_FILE"
    else
        cat > "$ISSUES_FILE" << 'EOF'
# Issues & Bugs

<!-- format: issues-v0.1.0 -->

## Summary

| Status | Count |
|--------|-------|
| Open | 0 |
| In Progress | 0 |
| Fixed | 0 |

---

## Open Issues

EOF
    fi
fi

# Find next available issue ID
LAST_ID=$(grep -oE "^## I-[0-9]+" "$ISSUES_FILE" | grep -oE "[0-9]+" | sort -n | tail -1 || echo "0")
NEXT_ID=$((LAST_ID + 1))
ISSUE_ID=$(printf "I-%04d" $NEXT_ID)
TODAY=$(date +%Y-%m-%d)

# Generate issue entry
ISSUE_ENTRY="
## $ISSUE_ID: $ISSUE_TITLE

**Status**: open  
**Priority**: $PRIORITY  
**Severity**: $SEVERITY  
**Found**: $TODAY  
**Fixed**: 

**Description**:
[TODO: Describe the issue - expected vs actual behavior]

**Steps to Reproduce**:
1. [Step 1]
2. [Step 2]
3. [Observe issue]

**Related**:
- Feature: 
- Blocks: 

---
"

# Find the "## Open Issues" section and insert after it
if grep -q "^## Open Issues" "$ISSUES_FILE"; then
    # Insert after "## Open Issues" line
    awk -v entry="$ISSUE_ENTRY" '
        /^## Open Issues/ { print; print entry; next }
        { print }
    ' "$ISSUES_FILE" > "${ISSUES_FILE}.tmp" && mv "${ISSUES_FILE}.tmp" "$ISSUES_FILE"
else
    # Just append at end
    echo "$ISSUE_ENTRY" >> "$ISSUES_FILE"
fi

# Update summary counts
OPEN_COUNT=$(grep -c "^\*\*Status\*\*: open" "$ISSUES_FILE" || echo "0")
# Update the Open count in summary table (basic update)
if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s/| Open | [0-9]* |/| Open | $OPEN_COUNT |/" "$ISSUES_FILE"
else
    sed -i "s/| Open | [0-9]* |/| Open | $OPEN_COUNT |/" "$ISSUES_FILE"
fi

echo -e "${GREEN}✓ Created $ISSUE_ID: $ISSUE_TITLE${NC}"
echo ""
echo "Added to: $ISSUES_FILE"
echo "Priority: $PRIORITY"
echo "Severity: $SEVERITY"
echo ""
echo "Next steps:"
echo "  1. Edit spec/ISSUES.md to add description and steps to reproduce"
echo "  2. Tell your agent: \"Fix $ISSUE_ID\" or \"Investigate $ISSUE_ID\""

