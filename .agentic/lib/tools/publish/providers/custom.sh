#!/usr/bin/env bash
# custom.sh — Custom scripts provider for ag publish
# Delegates to user-defined scripts from publish.yaml
# Implements the provider interface with dynamic capabilities based on what scripts exist.

CUSTOM_ROOT="${PROJECT_ROOT:-.}"
PUBLISH_CONFIG="${CUSTOM_ROOT}/.agentic/publish.yaml"

_read_custom_cmd() {
    local key="$1"
    if [[ ! -f "$PUBLISH_CONFIG" ]]; then
        return 1
    fi
    # Simple YAML key extraction (custom section)
    local in_custom=false
    while IFS= read -r line; do
        if [[ "$line" =~ ^custom: ]]; then
            in_custom=true
            continue
        fi
        if [[ "$in_custom" == true ]]; then
            # Exit if we hit a new top-level key
            if [[ "$line" =~ ^[a-z] && ! "$line" =~ ^[[:space:]] ]]; then
                break
            fi
            # Match the key
            if [[ "$line" =~ ^[[:space:]]+${key}:[[:space:]]*(.+) ]]; then
                echo "${BASH_REMATCH[1]}" | sed 's/#.*//' | tr -d '[:space:]'
                return 0
            fi
        fi
    done < "$PUBLISH_CONFIG"
    return 1
}

provider_capabilities() {
    local caps=()
    if _read_custom_cmd "build_cmd" >/dev/null 2>&1; then
        caps+=("build")
    fi
    if _read_custom_cmd "screenshots_cmd" >/dev/null 2>&1; then
        caps+=("screenshots")
    fi
    if _read_custom_cmd "metadata_cmd" >/dev/null 2>&1; then
        caps+=("metadata")
    fi
    if _read_custom_cmd "submit_cmd" >/dev/null 2>&1; then
        caps+=("submit")
    fi
    if _read_custom_cmd "status_cmd" >/dev/null 2>&1; then
        caps+=("status")
    fi
    echo "${caps[*]}"
}

provider_preflight() {
    if [[ ! -f "$PUBLISH_CONFIG" ]]; then
        echo "ERROR: $PUBLISH_CONFIG not found — run: ag publish init"
        return 1
    fi

    local caps
    caps=$(provider_capabilities)
    if [[ -z "$caps" ]]; then
        echo "ERROR: No custom commands defined in publish.yaml"
        return 1
    fi

    echo "Custom provider: capabilities = $caps"
    return 0
}

_run_custom() {
    local cmd_key="$1"
    local label="$2"
    local dry_run="${3:-false}"

    local cmd
    if ! cmd=$(_read_custom_cmd "$cmd_key"); then
        echo "SKIP: No $cmd_key defined in publish.yaml"
        return 0
    fi

    if [[ "$dry_run" == "true" ]]; then
        echo "[dry-run] Would run: $cmd"
        return 0
    fi

    echo "Running $label: $cmd"
    (cd "$CUSTOM_ROOT" && bash -c "$cmd")
}

provider_build() {
    local platform="${1:-}"
    local dry_run="${2:-false}"
    _run_custom "build_cmd" "build" "$dry_run"
}

provider_screenshots() {
    local platform="${1:-}"
    local dry_run="${2:-false}"
    _run_custom "screenshots_cmd" "screenshots" "$dry_run"
}

provider_metadata() {
    local platform="${1:-}"
    local dry_run="${2:-false}"
    _run_custom "metadata_cmd" "metadata" "$dry_run"
}

provider_submit() {
    local platform="${1:-}"
    local dry_run="${2:-false}"
    _run_custom "submit_cmd" "submit" "$dry_run"
}

provider_status() {
    local platform="${1:-}"
    _run_custom "status_cmd" "status" "false"
}
