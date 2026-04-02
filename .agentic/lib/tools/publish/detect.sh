#!/usr/bin/env bash
# detect.sh — Platform detection for ag publish
# Reads mobile_platform from STACK.md first, then uses file-system heuristics.
# Output: space-separated list of detected platforms (ios, android, react_native, flutter)
# Exit 0 on success, 1 if no platform detected.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${PROJECT_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
STACK_FILE="$ROOT_DIR/STACK.md"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

detect_from_stack() {
    if [[ -f "$STACK_FILE" ]]; then
        local setting
        setting=$(grep -E '^\s*-\s*mobile_platform:' "$STACK_FILE" | head -1 | sed 's/.*mobile_platform:\s*//' | sed 's/#.*//' | tr -d '[:space:]')
        if [[ -n "$setting" && "$setting" != "auto" ]]; then
            echo "$setting"
            return 0
        fi
    fi
    return 1
}

detect_from_files() {
    local platforms=()

    # React Native (check first — it generates ios/android dirs too)
    if [[ -f "$ROOT_DIR/package.json" ]]; then
        if grep -q '"react-native"' "$ROOT_DIR/package.json" 2>/dev/null; then
            platforms+=("react_native")
            echo "${platforms[*]}"
            return 0
        fi
    fi

    # Flutter (check before native — it generates ios/android dirs too)
    if [[ -f "$ROOT_DIR/pubspec.yaml" ]]; then
        if grep -q 'flutter' "$ROOT_DIR/pubspec.yaml" 2>/dev/null; then
            platforms+=("flutter")
            echo "${platforms[*]}"
            return 0
        fi
    fi

    # Native iOS
    if compgen -G "$ROOT_DIR/*.xcodeproj" >/dev/null 2>&1 || \
       compgen -G "$ROOT_DIR/*.xcworkspace" >/dev/null 2>&1; then
        platforms+=("ios")
    fi

    # Native Android
    if [[ -f "$ROOT_DIR/build.gradle" || -f "$ROOT_DIR/build.gradle.kts" ]] && \
       [[ -f "$ROOT_DIR/app/src/main/AndroidManifest.xml" || -d "$ROOT_DIR/app/src/main" ]]; then
        platforms+=("android")
    fi

    if [[ ${#platforms[@]} -gt 0 ]]; then
        echo "${platforms[*]}"
        return 0
    fi

    return 1
}

# Main
main() {
    local mode="${1:-detect}"

    case "$mode" in
        detect)
            local platforms
            if platforms=$(detect_from_stack); then
                echo -e "${GREEN}Platform (from STACK.md):${NC} $platforms" >&2
                echo "$platforms"
                exit 0
            fi

            if platforms=$(detect_from_files); then
                echo -e "${GREEN}Platform (auto-detected):${NC} $platforms" >&2
                echo "$platforms"
                exit 0
            fi

            echo -e "${RED}No mobile platform detected.${NC}" >&2
            echo "Set mobile_platform in STACK.md or ensure project files are present." >&2
            exit 1
            ;;
        --quiet|-q)
            # Machine-readable: just output platform(s), no color
            if platforms=$(detect_from_stack 2>/dev/null); then
                echo "$platforms"
                exit 0
            fi
            if platforms=$(detect_from_files 2>/dev/null); then
                echo "$platforms"
                exit 0
            fi
            exit 1
            ;;
        *)
            echo "Usage: detect.sh [detect|--quiet]"
            exit 1
            ;;
    esac
}

main "$@"
