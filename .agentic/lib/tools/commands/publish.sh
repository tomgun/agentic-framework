#!/usr/bin/env bash
# commands/publish.sh — Command dispatch for ag publish
# Usage: ag publish <subcommand> [options]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PUBLISH_DIR="$SCRIPT_DIR/../publish"
ROOT_DIR="${PROJECT_ROOT:-$(cd "$SCRIPT_DIR/../../../.." && pwd)}"
STACK_FILE="$ROOT_DIR/STACK.md"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

get_provider() {
    local provider=""
    if [[ -f "$STACK_FILE" ]]; then
        provider=$(grep -E '^\s*-\s*publish_provider:' "$STACK_FILE" | head -1 | sed 's/.*publish_provider:\s*//' | sed 's/#.*//' | tr -d '[:space:]')
    fi
    echo "${provider:-fastlane}"
}

show_help() {
    cat << 'EOF'
ag publish — App Store Publishing

USAGE:
    ag publish <command> [options]

COMMANDS:
    init                        Scaffold publishing config (STACK.md + publish.yaml)
    preflight                   Validate prerequisites (provider, signing, credentials, OS)
    ios [--skip-screenshots] [--dry-run]     Full iOS pipeline
    android [--skip-screenshots] [--dry-run] Full Android pipeline
    screenshots [--ios|--android]             Generate screenshots only
    metadata [--validate]                    Validate store metadata completeness
    status                      Show publishing progress + review status

EXAMPLES:
    ag publish init             # Set up publishing config
    ag publish preflight        # Check all prerequisites
    ag publish ios --dry-run    # Full iOS pipeline without submitting
    ag publish android          # Full Android pipeline
    ag publish status           # Show current progress
EOF
}

cmd_init() {
    bash "$PUBLISH_DIR/init-publish.sh" "$@"
}

cmd_preflight() {
    local platform
    platform=$(bash "$PUBLISH_DIR/detect.sh" --quiet 2>/dev/null || true)
    if [[ -z "$platform" ]]; then
        echo -e "${RED}No platform detected. Run 'ag publish init' first.${NC}"
        exit 1
    fi
    # If multiple platforms (e.g., react_native = ios + android), run preflight for first
    local first_platform="${platform%% *}"
    bash "$PUBLISH_DIR/preflight.sh" "$first_platform" --provider "$(get_provider)" "$@"
}

cmd_publish_platform() {
    local platform="$1"
    shift
    local dry_run=false
    local skip_screenshots=false
    local remaining_args=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run) dry_run=true; shift ;;
            --skip-screenshots) skip_screenshots=true; shift ;;
            *) remaining_args+=("$1"); shift ;;
        esac
    done

    local provider
    provider=$(get_provider)

    echo "=== Publishing: $platform (provider: $provider) ==="
    [[ "$dry_run" == "true" ]] && echo -e "${YELLOW}DRY RUN — no submissions will be made${NC}"

    # Run preflight first
    echo ""
    echo "Running preflight..."
    if ! bash "$PUBLISH_DIR/preflight.sh" "$platform" --provider "$provider"; then
        echo -e "${RED}Preflight failed — fix issues above before publishing.${NC}"
        exit 1
    fi

    # Delegate to Python orchestrator
    local orchestrator="$SCRIPT_DIR/../../auto/publish.py"
    if [[ -f "$orchestrator" ]]; then
        local args=("--platform" "$platform" "--provider" "$provider")
        [[ "$dry_run" == "true" ]] && args+=("--dry-run")
        [[ "$skip_screenshots" == "true" ]] && args+=("--skip-screenshots")
        python3 "$orchestrator" "${args[@]}" "${remaining_args[@]}"
    else
        echo -e "${YELLOW}Python orchestrator not found. Running provider directly...${NC}"
        local provider_script="$PUBLISH_DIR/providers/${provider}.sh"
        if [[ ! -f "$provider_script" ]]; then
            echo -e "${RED}Provider not found: $provider_script${NC}"
            exit 1
        fi
        source "$provider_script"
        provider_build "$platform" "$dry_run"
    fi
}

cmd_screenshots() {
    local platform_filter=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --ios) platform_filter="ios"; shift ;;
            --android) platform_filter="android"; shift ;;
            *) shift ;;
        esac
    done

    if [[ -f "$PUBLISH_DIR/screenshots.sh" ]]; then
        bash "$PUBLISH_DIR/screenshots.sh" ${platform_filter:+--platform "$platform_filter"}
    else
        echo -e "${YELLOW}Screenshot orchestration not yet available.${NC}"
        exit 1
    fi
}

cmd_metadata() {
    if [[ -f "$PUBLISH_DIR/metadata.sh" ]]; then
        bash "$PUBLISH_DIR/metadata.sh" "$@"
    else
        echo -e "${YELLOW}Metadata validation not yet available.${NC}"
        exit 1
    fi
}

cmd_status() {
    if [[ -f "$PUBLISH_DIR/status.sh" ]]; then
        bash "$PUBLISH_DIR/status.sh" "$@"
    else
        echo -e "${YELLOW}No publish status available.${NC}"
        exit 1
    fi
}

# Main dispatch
subcmd="${1:-help}"
shift 2>/dev/null || true

case "$subcmd" in
    init)           cmd_init "$@" ;;
    preflight)      cmd_preflight "$@" ;;
    ios)            cmd_publish_platform "ios" "$@" ;;
    android)        cmd_publish_platform "android" "$@" ;;
    screenshots)    cmd_screenshots "$@" ;;
    metadata)       cmd_metadata "$@" ;;
    status)         cmd_status "$@" ;;
    help|--help|-h) show_help ;;
    *)
        echo -e "${RED}Unknown publish command: $subcmd${NC}"
        echo ""
        show_help
        exit 1
        ;;
esac
