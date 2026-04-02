#!/usr/bin/env bash
# screenshots.sh — Screenshot generation orchestration for ag publish
# Delegates to the active provider's provider_screenshots function.
# Usage: screenshots.sh [--platform ios|android] [--dry-run]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Shared helpers (get_provider, PUBLISH_ROOT_DIR, PUBLISH_STACK_FILE)
source "$SCRIPT_DIR/_common.sh"
ROOT_DIR="$PUBLISH_ROOT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

main() {
    local platform=""
    local dry_run="false"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --platform) platform="$2"; shift 2 ;;
            --dry-run) dry_run="true"; shift ;;
            *) shift ;;
        esac
    done

    # Auto-detect platform if not specified
    if [[ -z "$platform" ]]; then
        platform=$(bash "$SCRIPT_DIR/detect.sh" --quiet 2>/dev/null || true)
        if [[ -z "$platform" ]]; then
            echo -e "${RED}No platform detected. Use --platform ios|android.${NC}"
            exit 1
        fi
    fi

    local provider
    provider=$(get_provider)
    local provider_script="$SCRIPT_DIR/providers/${provider}.sh"

    if [[ ! -f "$provider_script" ]]; then
        echo -e "${RED}Provider not found: $provider${NC}"
        exit 1
    fi

    # Source provider and check capabilities
    source "$provider_script"
    local caps
    caps=$(provider_capabilities)

    if [[ ! "$caps" == *"screenshots"* ]]; then
        echo -e "${YELLOW}Provider '$provider' does not support screenshots.${NC}"
        echo "Add a screenshots_cmd to .agentic/publish.yaml if using custom provider."
        exit 1
    fi

    echo "=== Screenshot Generation ==="
    echo "Platform: $platform"
    echo "Provider: $provider"
    [[ "$dry_run" == "true" ]] && echo -e "${YELLOW}DRY RUN${NC}"
    echo ""

    # Handle multi-platform (react_native, flutter)
    local platforms_to_run=()
    case "$platform" in
        react_native|flutter)
            platforms_to_run=("ios" "android")
            ;;
        *)
            platforms_to_run=("$platform")
            ;;
    esac

    local any_failed=false
    for p in "${platforms_to_run[@]}"; do
        echo "--- Screenshots: $p ---"
        if provider_screenshots "$p" "$dry_run"; then
            echo -e "${GREEN}✓ $p screenshots complete${NC}"
        else
            echo -e "${RED}✗ $p screenshots failed${NC}"
            any_failed=true
        fi
        echo ""
    done

    if [[ "$any_failed" == "true" ]]; then
        echo -e "${RED}Some screenshot tasks failed.${NC}"
        exit 1
    fi

    echo -e "${GREEN}All screenshots complete.${NC}"
}

main "$@"
