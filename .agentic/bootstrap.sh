#!/usr/bin/env bash
# bootstrap.sh — Ensure framework lib is available
#
# In the framework repo: lib/ is committed directly, so this is a no-op.
# In user projects: extracts lib/ from the committed tarball.
#
# Always executed, never sourced.

set -euo pipefail
AGENTIC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$AGENTIC_DIR/lib"

# Already available? (committed source in framework repo, or previously extracted)
[[ -d "$LIB_DIR/tools" ]] && exit 0

# Extract from committed package
tarball="$(ls "$AGENTIC_DIR"/agentic-lib-v*.tar.gz 2>/dev/null | sort -V | tail -1)"
if [[ -n "$tarball" ]]; then
    tmp_dir="$AGENTIC_DIR/.lib-extracting-$$"
    mkdir -p "$tmp_dir"
    tar xzf "$tarball" -C "$tmp_dir"
    mv "$tmp_dir" "$LIB_DIR"  # Atomic on same filesystem
    echo "Framework extracted from $(basename "$tarball")" >&2
    exit 0
fi

# Fallback: download from GitHub releases
PROJECT_ROOT="$(cd "$AGENTIC_DIR/.." && pwd)"
version=$(grep -oP 'Version:\s*\K[\d.]+' "$PROJECT_ROOT/STACK.md" 2>/dev/null || true)
if [[ -n "$version" ]]; then
    echo "Downloading agentic-lib-v${version}.tar.gz..." >&2
    tmp_dir="$AGENTIC_DIR/.lib-extracting-$$"
    mkdir -p "$tmp_dir"
    url="https://github.com/tomgun/agentic-framework/releases/download/v${version}/agentic-lib-v${version}.tar.gz"
    if curl -fsSL "$url" | tar xz -C "$tmp_dir"; then
        mv "$tmp_dir" "$LIB_DIR"
        exit 0
    fi
    rm -rf "$tmp_dir"
fi

echo "ERROR: Framework lib not found. Run install or place agentic-lib-v*.tar.gz in .agentic/" >&2
exit 1
