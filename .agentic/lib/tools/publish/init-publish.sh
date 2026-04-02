#!/usr/bin/env bash
# init-publish.sh — Scaffold publishing configuration
# Creates publish.yaml from template and adds STACK.md publishing section.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${PROJECT_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
TEMPLATE="$SCRIPT_DIR/../../init/publish.template.yaml"
TARGET="$ROOT_DIR/.agentic/publish.yaml"
STACK_FILE="$ROOT_DIR/STACK.md"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

main() {
    echo "=== Publish Init ==="

    # 1. Copy publish.yaml template
    if [[ -f "$TARGET" ]]; then
        echo -e "${YELLOW}publish.yaml already exists — skipping.${NC}"
    else
        if [[ ! -f "$TEMPLATE" ]]; then
            echo -e "${RED}Template not found: $TEMPLATE${NC}"
            exit 1
        fi
        cp "$TEMPLATE" "$TARGET"
        echo -e "${GREEN}Created:${NC} .agentic/publish.yaml"
    fi

    # 2. Add publishing section to STACK.md if missing
    if [[ -f "$STACK_FILE" ]]; then
        if grep -q "publish_provider" "$STACK_FILE"; then
            echo -e "${YELLOW}STACK.md already has publishing settings — skipping.${NC}"
        else
            # Insert before ## Data & integrations (or append)
            if grep -q "## Data & integrations" "$STACK_FILE"; then
                sed -i '/## Data & integrations/i \
## Publishing (optional, for mobile apps)\
- publish_provider: fastlane  # fastlane | custom\
- mobile_platform: auto       # auto | ios | android | react_native | flutter\
- publish_config: .agentic/publish.yaml\
' "$STACK_FILE"
                echo -e "${GREEN}Added publishing section to STACK.md${NC}"
            else
                cat >> "$STACK_FILE" << 'SECTION'

## Publishing (optional, for mobile apps)
- publish_provider: fastlane  # fastlane | custom
- mobile_platform: auto       # auto | ios | android | react_native | flutter
- publish_config: .agentic/publish.yaml
SECTION
                echo -e "${GREEN}Appended publishing section to STACK.md${NC}"
            fi
        fi
    else
        echo -e "${YELLOW}No STACK.md found — publishing settings will need to be added manually.${NC}"
    fi

    # 3. Detect platform
    echo ""
    echo "Detecting platform..."
    bash "$SCRIPT_DIR/detect.sh" detect || true

    echo ""
    echo -e "${GREEN}Publishing initialized.${NC} Next steps:"
    echo "  1. Edit .agentic/publish.yaml with your app details"
    echo "  2. Set environment variables for credentials"
    echo "  3. Run: ag publish preflight"
}

main "$@"
