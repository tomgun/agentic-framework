#!/usr/bin/env bash
# _common.sh — Shared helpers for ag publish scripts
# Source this file; do not execute directly.

# Resolve project root (callers may override via PROJECT_ROOT)
_PUBLISH_COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PUBLISH_ROOT_DIR="${PROJECT_ROOT:-$(cd "$_PUBLISH_COMMON_DIR/../../.." && pwd)}"
PUBLISH_STACK_FILE="$PUBLISH_ROOT_DIR/STACK.md"

get_provider() {
    local provider="${PUBLISH_PROVIDER:-}"
    if [[ -z "$provider" && -f "$PUBLISH_STACK_FILE" ]]; then
        provider=$(grep -E '^\s*-\s*publish_provider:' "$PUBLISH_STACK_FILE" | head -1 | sed 's/.*publish_provider:\s*//' | sed 's/#.*//' | tr -d '[:space:]')
    fi
    echo "${provider:-fastlane}"
}
