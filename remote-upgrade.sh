#!/usr/bin/env bash
# Remote upgrader for Agentic Framework
# Usage: curl -fsSL https://raw.githubusercontent.com/tomgun/agentic-framework/main/remote-upgrade.sh | bash
#
# Options (via environment variables):
#   VERSION=v0.13.0  - Upgrade to specific version (default: latest)
#   TARGET=/path     - Upgrade specific directory (default: current directory)

set -euo pipefail

# Configuration
REPO="tomgun/agentic-framework"
VERSION="${VERSION:-latest}"
TARGET="${TARGET:-.}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}Agentic Framework - Remote Upgrader${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Resolve target directory
TARGET="$(cd "$TARGET" && pwd)"
echo "Target: $TARGET"

# Check if framework is installed
if [ ! -d "$TARGET/.agentic" ]; then
  echo -e "${RED}Error: No .agentic/ directory found in $TARGET${NC}"
  echo "Use remote-install.sh for new installations."
  exit 1
fi

# Get current version
CURRENT_VERSION=""
if [ -f "$TARGET/STACK.md" ]; then
  CURRENT_VERSION=$(grep "^- Version:" "$TARGET/STACK.md" 2>/dev/null | cut -d':' -f2 | tr -d ' ' || echo "unknown")
fi
echo "Current version: ${CURRENT_VERSION:-unknown}"

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
  echo "Target version: $VERSION"
fi

# Check if already up to date
if [ "$CURRENT_VERSION" = "$VERSION" ] || [ "$CURRENT_VERSION" = "${VERSION#v}" ]; then
  echo -e "${GREEN}Already up to date ($VERSION)${NC}"
  exit 0
fi

# Create temp directory
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Download and extract
echo -n "Downloading $VERSION... "
TARBALL_URL="https://github.com/$REPO/archive/refs/tags/$VERSION.tar.gz"
curl -fsSL "$TARBALL_URL" | tar xz -C "$TEMP_DIR"
echo "done"

# Find extracted directory
FRAMEWORK_DIR=$(ls -d "$TEMP_DIR"/agentic-framework-* 2>/dev/null | head -n1)
if [ -z "$FRAMEWORK_DIR" ]; then
  echo -e "${RED}Failed to extract framework${NC}"
  exit 1
fi

# Run upgrade.sh
echo ""
bash "$FRAMEWORK_DIR/.agentic/tools/upgrade.sh" "$TARGET"

echo ""
echo -e "${GREEN}Upgrade complete! ${CURRENT_VERSION:-unknown} → $VERSION${NC}"
