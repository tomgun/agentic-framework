#!/usr/bin/env bash
# quick_feature.sh: Quickly add a new feature to FEATURES.md
# Usage: bash .agentic/tools/quick_feature.sh "Feature name" [priority] [complexity]
#
# Examples:
#   bash .agentic/tools/quick_feature.sh "User login"
#   bash .agentic/tools/quick_feature.sh "Dark mode" high medium
#   bash .agentic/tools/quick_feature.sh "Export to PDF" low easy

set -euo pipefail

FEATURE_NAME="${1:-}"
PRIORITY="${2:-medium}"
COMPLEXITY="${3:-medium}"
FEATURES_FILE="spec/FEATURES.md"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

if [[ -z "$FEATURE_NAME" ]]; then
    echo "Usage: bash .agentic/tools/quick_feature.sh \"Feature name\" [priority] [complexity]"
    echo ""
    echo "Examples:"
    echo "  bash .agentic/tools/quick_feature.sh \"User authentication\""
    echo "  bash .agentic/tools/quick_feature.sh \"Dark mode\" high medium"
    echo ""
    echo "Priority: low, medium (default), high, critical"
    echo "Complexity: easy, medium (default), hard, complex"
    exit 1
fi

# Check if FEATURES.md exists
if [[ ! -f "$FEATURES_FILE" ]]; then
    echo -e "${YELLOW}Warning: $FEATURES_FILE not found. Creating it...${NC}"
    mkdir -p spec
    cat > "$FEATURES_FILE" << 'EOF'
# Features

<!-- format: features-v0.2.0 -->

## Summary

| Category | Total |
|----------|-------|
| All | 0 |

---

EOF
fi

# Find next available feature ID
LAST_ID=$(grep -oE "^## F-[0-9]+" "$FEATURES_FILE" | grep -oE "[0-9]+" | sort -n | tail -1 || echo "0")
NEXT_ID=$((LAST_ID + 1))
FEATURE_ID=$(printf "F-%04d" $NEXT_ID)

# Generate feature entry
FEATURE_ENTRY="
---

## $FEATURE_ID: $FEATURE_NAME

**Status**: planned  
**Priority**: $PRIORITY  
**Complexity**: $COMPLEXITY  
**Since**: v$(cat VERSION 2>/dev/null || cat .agentic/VERSION 2>/dev/null || echo "0.0.0")

**Description**: [TODO: Add description]

**Dependencies**: none

**Implementation**:
- State: none
- Code: 
- Tests: 

**Acceptance**: See \`spec/acceptance/$FEATURE_ID.md\`
"

# Append to FEATURES.md
echo "$FEATURE_ENTRY" >> "$FEATURES_FILE"

echo -e "${GREEN}✓ Created $FEATURE_ID: $FEATURE_NAME${NC}"
echo ""
echo "Added to: $FEATURES_FILE"
echo "Priority: $PRIORITY"
echo "Complexity: $COMPLEXITY"
echo ""
echo "Next steps:"
echo "  1. Edit spec/FEATURES.md to add description"
echo "  2. Create spec/acceptance/$FEATURE_ID.md with acceptance criteria"
echo "  3. Tell your agent: \"Implement $FEATURE_ID\""

