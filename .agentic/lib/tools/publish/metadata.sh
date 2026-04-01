#!/usr/bin/env bash
# metadata.sh — Validate store metadata completeness for ag publish
# Checks: app name, description, screenshots directory, keywords, categories
# Usage: metadata.sh [--validate] [--platform ios|android]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${PROJECT_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
PUBLISH_CONFIG="$ROOT_DIR/.agentic/publish.yaml"
STACK_FILE="$ROOT_DIR/STACK.md"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ERRORS=0
WARNINGS=0

pass() { echo -e "  ${GREEN}✓${NC} $1"; }
warn() { echo -e "  ${YELLOW}⚠${NC} $1"; WARNINGS=$((WARNINGS + 1)); }
fail() { echo -e "  ${RED}✗${NC} $1"; ERRORS=$((ERRORS + 1)); }

get_provider() {
    local provider=""
    if [[ -f "$STACK_FILE" ]]; then
        provider=$(grep -E '^\s*-\s*publish_provider:' "$STACK_FILE" | head -1 | sed 's/.*publish_provider:\s*//' | sed 's/#.*//' | tr -d '[:space:]')
    fi
    echo "${provider:-fastlane}"
}

validate_ios_metadata() {
    echo "iOS metadata checks:"

    # Fastlane metadata directory
    local metadata_dir="$ROOT_DIR/fastlane/metadata/en-US"
    if [[ -d "$metadata_dir" ]]; then
        pass "Fastlane metadata directory exists"
        for file in name.txt subtitle.txt description.txt keywords.txt; do
            if [[ -f "$metadata_dir/$file" ]]; then
                local content
                content=$(cat "$metadata_dir/$file")
                if [[ -n "$content" ]]; then
                    pass "$file: filled"
                else
                    warn "$file: empty"
                fi
            else
                fail "$file: missing"
            fi
        done
    else
        warn "No fastlane metadata directory at $metadata_dir"
        echo "  Create with: fastlane deliver download_metadata"
    fi

    # Screenshots directory
    local screenshots_dir="$ROOT_DIR/fastlane/screenshots"
    if [[ -d "$screenshots_dir" ]]; then
        local count
        count=$(find "$screenshots_dir" -name "*.png" -o -name "*.jpg" 2>/dev/null | wc -l)
        if [[ "$count" -gt 0 ]]; then
            pass "Screenshots: $count images found"
        else
            warn "Screenshots directory exists but is empty"
        fi
    else
        warn "No screenshots directory at $screenshots_dir"
    fi
}

validate_android_metadata() {
    echo "Android metadata checks:"

    # Fastlane supply metadata
    local metadata_dir="$ROOT_DIR/fastlane/metadata/android/en-US"
    if [[ -d "$metadata_dir" ]]; then
        pass "Fastlane supply metadata directory exists"
        for file in title.txt short_description.txt full_description.txt; do
            if [[ -f "$metadata_dir/$file" ]]; then
                local content
                content=$(cat "$metadata_dir/$file")
                if [[ -n "$content" ]]; then
                    pass "$file: filled"
                else
                    warn "$file: empty"
                fi
            else
                fail "$file: missing"
            fi
        done
    else
        warn "No supply metadata directory at $metadata_dir"
        echo "  Create with: fastlane supply init"
    fi
}

validate_config() {
    echo "Configuration checks:"

    if [[ -f "$PUBLISH_CONFIG" ]]; then
        pass "publish.yaml exists"
    else
        fail "publish.yaml not found — run: ag publish init"
    fi

    local provider
    provider=$(get_provider)
    pass "Provider: $provider"

    # Delegate to provider for deeper validation
    local provider_script="$SCRIPT_DIR/providers/${provider}.sh"
    if [[ -f "$provider_script" ]]; then
        source "$provider_script"
        local caps
        caps=$(provider_capabilities)
        if [[ "$caps" == *"metadata"* ]]; then
            pass "Provider supports metadata validation"
        else
            warn "Provider does not support metadata phase"
        fi
    fi
}

main() {
    local validate_only=false
    local platform=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --validate) validate_only=true; shift ;;
            --platform) platform="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    if [[ -z "$platform" ]]; then
        platform=$(bash "$SCRIPT_DIR/detect.sh" --quiet 2>/dev/null || echo "")
    fi

    echo "=== Metadata Validation ==="
    echo ""

    validate_config
    echo ""

    case "$platform" in
        ios)
            validate_ios_metadata
            ;;
        android)
            validate_android_metadata
            ;;
        react_native|flutter)
            validate_ios_metadata
            echo ""
            validate_android_metadata
            ;;
        *)
            warn "No platform detected — skipping platform-specific checks"
            ;;
    esac

    echo ""
    echo "─────────────────────────────────"
    if [[ $ERRORS -gt 0 ]]; then
        echo -e "${RED}Validation: $ERRORS error(s), $WARNINGS warning(s)${NC}"
        exit 1
    elif [[ $WARNINGS -gt 0 ]]; then
        echo -e "${YELLOW}Validation: PASSED with $WARNINGS warning(s)${NC}"
    else
        echo -e "${GREEN}Validation: All checks passed${NC}"
    fi
}

main "$@"
