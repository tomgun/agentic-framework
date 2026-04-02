#!/usr/bin/env bash
# fastlane.sh — Fastlane provider for ag publish
# Implements the provider interface: capabilities, preflight, build, screenshots, metadata, submit, status
# Sourced by the orchestrator — functions, not a standalone script.

provider_capabilities() {
    # Note: 'status' omitted — fastlane has no programmatic review-status API.
    # Users check App Store Connect / Play Console directly.
    echo "build screenshots metadata submit"
}

provider_preflight() {
    local platform="${1:-ios}"

    if ! command -v fastlane >/dev/null 2>&1; then
        echo "ERROR: fastlane not installed"
        return 1
    fi

    case "$platform" in
        ios)
            if ! command -v xcodebuild >/dev/null 2>&1; then
                echo "ERROR: xcodebuild not found (install Xcode)"
                return 1
            fi
            ;;
        android)
            if [[ ! -f "build.gradle" && ! -f "build.gradle.kts" && ! -f "app/build.gradle" && ! -f "app/build.gradle.kts" ]]; then
                echo "ERROR: No Gradle build file found"
                return 1
            fi
            ;;
    esac
    echo "OK"
    return 0
}

provider_build() {
    local platform="${1:-ios}"
    local dry_run="${2:-false}"

    echo "Building $platform via fastlane..."
    case "$platform" in
        ios)
            if [[ "$dry_run" == "true" ]]; then
                echo "[dry-run] Would run: fastlane ios build"
                return 0
            fi
            fastlane ios build
            ;;
        android)
            if [[ "$dry_run" == "true" ]]; then
                echo "[dry-run] Would run: fastlane android build"
                return 0
            fi
            fastlane android build
            ;;
        *)
            echo "ERROR: Unsupported platform for fastlane build: $platform"
            return 1
            ;;
    esac
}

provider_screenshots() {
    local platform="${1:-ios}"
    local dry_run="${2:-false}"

    echo "Generating $platform screenshots via fastlane..."
    case "$platform" in
        ios)
            if [[ "$dry_run" == "true" ]]; then
                echo "[dry-run] Would run: fastlane ios snapshot"
                return 0
            fi
            fastlane ios snapshot
            ;;
        android)
            if [[ "$dry_run" == "true" ]]; then
                echo "[dry-run] Would run: fastlane android screengrab"
                return 0
            fi
            fastlane android screengrab
            ;;
    esac
}

provider_metadata() {
    local platform="${1:-ios}"
    local dry_run="${2:-false}"

    echo "Validating $platform metadata via fastlane..."
    case "$platform" in
        ios)
            if [[ "$dry_run" == "true" ]]; then
                echo "[dry-run] Would run: fastlane deliver validate_only"
                return 0
            fi
            fastlane deliver validate_only
            ;;
        android)
            if [[ "$dry_run" == "true" ]]; then
                echo "[dry-run] Would run: fastlane supply validate"
                return 0
            fi
            fastlane supply validate
            ;;
    esac
}

provider_submit() {
    local platform="${1:-ios}"
    local dry_run="${2:-false}"

    if [[ "$dry_run" == "true" ]]; then
        echo "[dry-run] Would submit $platform to store via fastlane"
        return 0
    fi

    echo "Submitting $platform to store via fastlane..."
    case "$platform" in
        ios)
            fastlane deliver --submit_for_review
            ;;
        android)
            fastlane supply
            ;;
    esac
}

provider_status() {
    local platform="${1:-ios}"

    echo "Checking $platform submission status..."
    case "$platform" in
        ios)
            if command -v spaceship >/dev/null 2>&1; then
                echo "Use App Store Connect to check review status"
            else
                echo "Install spaceship for programmatic status checks"
            fi
            ;;
        android)
            echo "Check Google Play Console for review status"
            ;;
    esac
}
