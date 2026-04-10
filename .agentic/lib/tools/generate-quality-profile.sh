#!/usr/bin/env bash
# generate-quality-profile.sh — Shell wrapper for quality_profile_generator.py
# Called by: scaffold.sh (during init), upgrade.sh, ag quality setup
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR=""
DRY_RUN=""
FORCE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --root)
            ROOT_DIR="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN="--dry-run"
            shift
            ;;
        --force)
            FORCE="--force"
            shift
            ;;
        *)
            echo "Usage: generate-quality-profile.sh --root <project-root> [--dry-run] [--force]"
            exit 1
            ;;
    esac
done

if [[ -z "$ROOT_DIR" ]]; then
    ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
fi

# Ensure local directories exist
mkdir -p "${ROOT_DIR}/.agentic/local/extensions/gates" 2>/dev/null || true

echo "Generating quality profile..."

# Run Python generator
if command -v python3 &>/dev/null; then
    python3 "${SCRIPT_DIR}/quality_profile_generator.py" \
        --root "$ROOT_DIR" \
        $DRY_RUN \
        $FORCE
else
    echo "  ⚠️  python3 not found — cannot generate quality profile"
    echo "     Install Python 3 and run: ag quality setup"
    exit 0  # Non-fatal: don't break init
fi
