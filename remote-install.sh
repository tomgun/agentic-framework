#!/usr/bin/env bash
# Remote installer for Agentic Framework
# Usage: curl -fsSL https://raw.githubusercontent.com/tomgun/agentic-framework/main/remote-install.sh | bash
#
# Options (via environment variables):
#   VERSION=v0.41.0  - Install specific version (default: latest)
#   TARGET=/path     - Install to specific directory (default: current directory)

set -euo pipefail

# Configuration
REPO="tomgun/agentic-framework"
VERSION="${VERSION:-latest}"
TARGET="${TARGET:-.}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Agentic Framework - Remote Installer${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Resolve target directory
TARGET="$(cd "$TARGET" && pwd)"
echo "Target: $TARGET"

# Get latest version if not specified
if [ "$VERSION" = "latest" ]; then
  echo -n "Fetching latest version... "
  VERSION=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" | grep '"tag_name"' | cut -d'"' -f4)
  if [ -z "$VERSION" ]; then
    echo -e "${RED}Failed to fetch latest version${NC}"
    exit 1
  fi
  echo "$VERSION"
else
  echo "Version: $VERSION"
fi

VERSION_NUM="${VERSION#v}"  # Strip 'v' prefix

# Create temp directory
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Download source tarball (for install.sh, thin wrappers, and templates)
echo -n "Downloading source... "
SOURCE_URL="https://github.com/$REPO/archive/refs/tags/$VERSION.tar.gz"
curl -fsSL "$SOURCE_URL" | tar xz -C "$TEMP_DIR"
echo "done"

# Find extracted directory
FRAMEWORK_DIR=$(ls -d "$TEMP_DIR"/agentic-framework-* 2>/dev/null | head -n1)
if [ -z "$FRAMEWORK_DIR" ]; then
  echo -e "${RED}Failed to extract framework${NC}"
  exit 1
fi

# Try to download pre-built lib tarball from release assets
LIB_TARBALL="agentic-lib-v${VERSION_NUM}.tar.gz"
LIB_URL="https://github.com/$REPO/releases/download/$VERSION/$LIB_TARBALL"
echo -n "Downloading lib tarball... "
if curl -fsSL -o "$FRAMEWORK_DIR/.agentic/$LIB_TARBALL" "$LIB_URL" 2>/dev/null; then
  echo "done"
else
  echo "not available (will build from source)"
fi

# Run install.sh
echo ""
cd "$TARGET"
bash "$FRAMEWORK_DIR/install.sh" .

echo ""
echo -e "${GREEN}Installation complete!${NC}"
echo ""
echo "Next: Open your AI agent and say:"
echo "  \"Read .agentic/lib/init/init_playbook.md and help me initialize this project\""
