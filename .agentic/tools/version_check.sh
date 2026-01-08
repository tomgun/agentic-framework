#!/usr/bin/env bash
# version_check.sh: Check if framework was upgraded since last session
# Usage: bash .agentic/tools/version_check.sh
# Exit codes: 0 = versions match, 1 = upgrade detected, 2 = error

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Get framework version from .agentic/VERSION
FRAMEWORK_VERSION=""
if [[ -f ".agentic/VERSION" ]]; then
    FRAMEWORK_VERSION=$(cat .agentic/VERSION | tr -d '[:space:]')
else
    # Fallback: check STACK.md for framework version (older projects)
    if [[ -f "STACK.md" ]]; then
        FRAMEWORK_VERSION=$(grep -E "^\s*-?\s*Version:" STACK.md | head -1 | sed -E 's/.*Version:\s*([0-9.]+).*/\1/' | tr -d '[:space:]')
        if [[ -n "$FRAMEWORK_VERSION" ]]; then
            echo -e "${YELLOW}Note: .agentic/VERSION not found, using STACK.md version${NC}"
        fi
    fi
    
    if [[ -z "$FRAMEWORK_VERSION" ]]; then
        echo -e "${RED}Error: Cannot determine framework version${NC}"
        echo "Missing: .agentic/VERSION file"
        echo "Missing: Version field in STACK.md"
        echo ""
        echo "If recently upgraded, add version manually:"
        echo "  echo '0.9.1' > .agentic/VERSION"
        exit 2
    fi
fi

# Get recorded version from STACK.md
RECORDED_VERSION=""
if [[ -f "STACK.md" ]]; then
    RECORDED_VERSION=$(grep -E "^\s*-?\s*Version:" STACK.md | head -1 | sed -E 's/.*Version:\s*([0-9.]+).*/\1/' | tr -d '[:space:]')
fi

if [[ -z "$RECORDED_VERSION" ]]; then
    echo -e "${YELLOW}Warning: Could not read version from STACK.md${NC}"
    echo "Framework version: $FRAMEWORK_VERSION"
    exit 2
fi

# Compare versions
if [[ "$FRAMEWORK_VERSION" == "$RECORDED_VERSION" ]]; then
    echo -e "${GREEN}✓ Versions match: $FRAMEWORK_VERSION${NC}"
    exit 0
else
    echo -e "${YELLOW}⚠ FRAMEWORK UPGRADE DETECTED${NC}"
    echo ""
    echo "  STACK.md version:  $RECORDED_VERSION (old)"
    echo "  Framework version: $FRAMEWORK_VERSION (new)"
    echo ""
    echo "Post-upgrade actions needed:"
    echo "  1. Read .agentic/START_HERE.md for new workflows"
    echo "  2. Check spec formats: python3 .agentic/tools/validate_specs.py"
    echo "  3. Review CHANGELOG for breaking changes"
    echo "  4. Update STACK.md version to match"
    echo ""
    echo "See: .agentic/agents/shared/agent_operating_guidelines.md → 'After Framework Upgrade'"
    exit 1
fi
