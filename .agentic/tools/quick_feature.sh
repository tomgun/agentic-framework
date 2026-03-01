#!/usr/bin/env bash
# quick_feature.sh: Quickly add a new feature to FEATURES.md
# Usage: bash .agentic/tools/quick_feature.sh [--category CAT] "Feature name" [priority] [complexity]
#
# Examples:
#   bash .agentic/tools/quick_feature.sh "User login"
#   bash .agentic/tools/quick_feature.sh --category core "Dark mode" high medium
#   bash .agentic/tools/quick_feature.sh "Export to PDF" low easy

set -euo pipefail

# Parse --category flag
CATEGORY=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --category)
            CATEGORY="$2"
            shift 2
            ;;
        --category=*)
            CATEGORY="${1#--category=}"
            shift
            ;;
        *)
            break
            ;;
    esac
done

FEATURE_NAME="${1:-}"
PRIORITY="${2:-medium}"
COMPLEXITY="${3:-medium}"
FEATURES_FILE="spec/FEATURES.md"

# Valid categories
VALID_CATEGORIES="core quality session multi-agent tooling recovery developer-experience design-principles agent-system verification-enforcement"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Normalize category to title case
normalize_category() {
    local cat="$1"
    local lower
    lower=$(echo "$cat" | tr '[:upper:]' '[:lower:]')
    case "$lower" in
        core)                       echo "Core" ;;
        quality)                    echo "Quality" ;;
        session)                    echo "Session" ;;
        multi-agent|multiagent)     echo "Multi-Agent" ;;
        tooling)                    echo "Tooling" ;;
        recovery)                   echo "Recovery" ;;
        developer-experience|devex|dx) echo "Developer Experience" ;;
        design-principles|design)   echo "Design Principles" ;;
        agent-system|agent|agents)  echo "Agent System" ;;
        verification-enforcement|verification|enforcement) echo "Verification & Enforcement" ;;
        *)
            echo ""
            ;;
    esac
}

if [[ -z "$FEATURE_NAME" ]]; then
    echo "Usage: bash .agentic/tools/quick_feature.sh [--category CAT] \"Feature name\" [priority] [complexity]"
    echo ""
    echo "Examples:"
    echo "  bash .agentic/tools/quick_feature.sh \"User authentication\""
    echo "  bash .agentic/tools/quick_feature.sh --category core \"Dark mode\" high medium"
    echo ""
    echo "Priority: low, medium (default), high, critical"
    echo "Complexity: easy, medium (default), hard, complex"
    echo "Categories: core, quality, session, multi-agent, tooling, recovery,"
    echo "            developer-experience (devex), design-principles (design),"
    echo "            agent-system (agent), verification-enforcement (verification)"
    exit 1
fi

# Validate category if provided
if [[ -n "$CATEGORY" ]]; then
    NORMALIZED_CATEGORY=$(normalize_category "$CATEGORY")
    if [[ -z "$NORMALIZED_CATEGORY" ]]; then
        echo -e "${RED}Error: Unknown category '$CATEGORY'${NC}"
        echo "Valid categories: core, quality, session, multi-agent, tooling, recovery,"
        echo "  developer-experience, design-principles, agent-system, verification-enforcement"
        exit 1
    fi
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

# Find next available feature ID (use 10# prefix to force decimal interpretation)
LAST_ID=$(grep -oE "^## F-[0-9]+" "$FEATURES_FILE" | grep -oE "[0-9]+" | sort -n | tail -1 || echo "0")
NEXT_ID=$((10#$LAST_ID + 1))
FEATURE_ID=$(printf "F-%04d" $NEXT_ID)

# Build category line
CATEGORY_LINE=""
if [[ -n "$CATEGORY" ]]; then
    CATEGORY_LINE="**Category**: $NORMALIZED_CATEGORY
"
fi

# Generate feature entry
FEATURE_ENTRY="
---

## $FEATURE_ID: $FEATURE_NAME

**Status**: planned
${CATEGORY_LINE}**Priority**: $PRIORITY
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
if [[ -n "$CATEGORY" ]]; then
    echo "Category: $NORMALIZED_CATEGORY"
fi
echo "Priority: $PRIORITY"
echo "Complexity: $COMPLEXITY"
echo ""
echo "Next steps:"
echo "  1. Edit spec/FEATURES.md to add description"
echo "  2. Create spec/acceptance/$FEATURE_ID.md with acceptance criteria"
echo "  3. Tell your agent: \"Implement $FEATURE_ID\""

