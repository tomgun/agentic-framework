#!/usr/bin/env bash
# preflight.sh — Validate prerequisites for app store publishing
# Checks: provider availability, host OS, signing credentials, key file existence
# Usage: preflight.sh <platform> [--provider <fastlane|custom>]
# Exit 0 if all checks pass, 1 otherwise.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${PROJECT_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
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

check_env() {
    local var="$1"
    local label="${2:-$var}"
    if [[ -n "${!var:-}" ]]; then
        pass "$label set"
    else
        fail "$label not set (export $var)"
    fi
}

check_env_file() {
    local var="$1"
    local label="${2:-$var}"
    if [[ -n "${!var:-}" ]]; then
        if [[ -f "${!var}" ]]; then
            pass "$label exists: ${!var}"
        else
            fail "$label file not found: ${!var}"
        fi
    else
        fail "$label not set (export $var)"
    fi
}

get_provider() {
    local provider="${PUBLISH_PROVIDER:-}"
    if [[ -z "$provider" && -f "$STACK_FILE" ]]; then
        provider=$(grep -E '^\s*-\s*publish_provider:' "$STACK_FILE" | head -1 | sed 's/.*publish_provider:\s*//' | sed 's/#.*//' | tr -d '[:space:]')
    fi
    echo "${provider:-fastlane}"
}

check_os() {
    local platform="$1"
    local os
    os="$(uname -s)"

    echo ""
    echo "Host OS check:"
    if [[ "$platform" == "ios" || "$platform" == "react_native" || "$platform" == "flutter" ]]; then
        if [[ "$os" == "Darwin" ]]; then
            pass "macOS detected — iOS builds supported"
        else
            fail "iOS builds require macOS (detected: $os)"
        fi
    fi

    if [[ "$platform" == "android" || "$platform" == "react_native" || "$platform" == "flutter" ]]; then
        if [[ "$os" == "Darwin" || "$os" == "Linux" ]]; then
            pass "Android builds supported on $os"
        else
            warn "Android builds: untested on $os (macOS/Linux recommended)"
        fi
    fi
}

check_provider() {
    local provider="$1"
    echo ""
    echo "Provider check ($provider):"

    case "$provider" in
        fastlane)
            if command -v fastlane >/dev/null 2>&1; then
                pass "fastlane installed: $(fastlane --version 2>/dev/null | head -1)"
            else
                fail "fastlane not installed (gem install fastlane)"
            fi
            ;;
        custom)
            local config="$ROOT_DIR/.agentic/publish.yaml"
            if [[ -f "$config" ]]; then
                pass "publish.yaml found"
            else
                fail "publish.yaml not found — run: ag publish init"
            fi
            ;;
        *)
            fail "Unknown provider: $provider (expected: fastlane | custom)"
            ;;
    esac
}

check_ios_credentials() {
    echo ""
    echo "iOS credentials:"
    check_env "APP_STORE_CONNECT_API_KEY_ID" "App Store Connect API Key ID"
    check_env "APP_STORE_CONNECT_API_ISSUER_ID" "App Store Connect API Issuer ID"
    check_env_file "APP_STORE_CONNECT_API_KEY_PATH" "App Store Connect API Key file"

    echo ""
    echo "iOS signing (match):"
    if [[ -n "${MATCH_PASSWORD:-}" ]]; then
        check_env "MATCH_PASSWORD" "Match password"
        check_env "MATCH_GIT_URL" "Match git URL"
    else
        warn "Match not configured (MATCH_PASSWORD not set) — manual signing assumed"
    fi
}

check_android_credentials() {
    echo ""
    echo "Android credentials:"
    check_env_file "GOOGLE_PLAY_JSON_KEY_PATH" "Google Play JSON key file"

    echo ""
    echo "Android signing:"
    check_env_file "ANDROID_KEYSTORE_PATH" "Keystore file"
    check_env "ANDROID_KEYSTORE_PASSWORD" "Keystore password"
    check_env "ANDROID_KEY_ALIAS" "Key alias"
    check_env "ANDROID_KEY_PASSWORD" "Key password"
}

# Main
main() {
    local platform="${1:-}"
    local provider=""

    # Parse args
    shift || true
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --provider) provider="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    if [[ -z "$platform" ]]; then
        echo -e "${RED}Usage: preflight.sh <platform> [--provider <fastlane|custom>]${NC}"
        echo "  platform: ios | android | react_native | flutter"
        exit 1
    fi

    [[ -z "$provider" ]] && provider=$(get_provider)

    echo "=== Publish Preflight: $platform (provider: $provider) ==="

    check_os "$platform"
    check_provider "$provider"

    case "$platform" in
        ios)
            check_ios_credentials
            ;;
        android)
            check_android_credentials
            ;;
        react_native|flutter)
            check_ios_credentials
            check_android_credentials
            ;;
        *)
            fail "Unknown platform: $platform"
            ;;
    esac

    echo ""
    echo "─────────────────────────────────"
    if [[ $ERRORS -gt 0 ]]; then
        echo -e "${RED}Preflight FAILED: $ERRORS error(s), $WARNINGS warning(s)${NC}"
        exit 1
    elif [[ $WARNINGS -gt 0 ]]; then
        echo -e "${YELLOW}Preflight PASSED with $WARNINGS warning(s)${NC}"
        exit 0
    else
        echo -e "${GREEN}Preflight PASSED — all checks OK${NC}"
        exit 0
    fi
}

main "$@"
