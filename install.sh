#!/usr/bin/env bash
# install.sh: Install the Agentic Framework into a new or existing project
# Usage: bash install.sh /path/to/your-project [--profile core|core+product]
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
TARGET_PROJECT_DIR="${1:-.}"
PROFILE="${2:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_VERSION=""

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║         AGENTIC FRAMEWORK INSTALLATION TOOL                    ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Step 1: Read framework version
echo -e "${BLUE}[1/5] Reading framework version${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ -f "$SCRIPT_DIR/VERSION" ]]; then
  FRAMEWORK_VERSION=$(cat "$SCRIPT_DIR/VERSION" | tr -d '[:space:]')
  echo -e "  ${GREEN}✓${NC} Framework version: $FRAMEWORK_VERSION"
else
  echo -e "  ${RED}✗ Error: VERSION file not found in framework directory${NC}"
  echo "    Expected: $SCRIPT_DIR/VERSION"
  exit 1
fi
echo ""

# Step 2: Verify target directory
echo -e "${BLUE}[2/5] Verifying target project${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ ! -d "$TARGET_PROJECT_DIR" ]]; then
  echo -e "${RED}✗ Error: Target directory not found: $TARGET_PROJECT_DIR${NC}"
  exit 1
fi

cd "$TARGET_PROJECT_DIR"
TARGET_PROJECT_DIR="$(pwd)"  # Get absolute path
echo "  Target project: $TARGET_PROJECT_DIR"

if [[ -d ".agentic" ]]; then
  echo -e "${YELLOW}⚠ Warning: .agentic/ folder already exists${NC}"
  echo "  If you want to upgrade, use upgrade.sh instead"
  echo ""
  read -p "  Continue and overwrite? [y/N] " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Installation cancelled${NC}"
    exit 0
  fi
fi
echo ""

# Step 3: Copy .agentic/ folder
echo -e "${BLUE}[3/5] Copying framework files${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ -d ".agentic" ]]; then
  BACKUP_DIR="agentic-backup-$(date +%Y%m%d-%H%M%S)"
  echo "  Backing up existing .agentic/ to $BACKUP_DIR/"
  mv .agentic "$BACKUP_DIR"
fi

echo "  Copying .agentic/ from framework..."
cp -r "$SCRIPT_DIR/.agentic" .
echo -e "  ${GREEN}✓${NC} Framework files copied"
echo ""

# Step 4: Run scaffold.sh
echo -e "${BLUE}[4/5] Running scaffold script${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

SCAFFOLD_CMD=".agentic/init/scaffold.sh"

# Add profile flag if provided
if [[ -n "$PROFILE" ]]; then
  if [[ "$PROFILE" == "core" || "$PROFILE" == "core+product" ]]; then
    SCAFFOLD_CMD="$SCAFFOLD_CMD --profile $PROFILE"
    echo "  Using profile: $PROFILE"
  else
    echo -e "${YELLOW}⚠ Warning: Invalid profile '$PROFILE'. Scaffold will prompt.${NC}"
  fi
fi

if [[ -x "$SCAFFOLD_CMD" ]]; then
  bash $SCAFFOLD_CMD
else
  echo -e "${RED}✗ Error: scaffold.sh not found or not executable${NC}"
  exit 1
fi
echo ""

# Step 5: Update STACK.md with framework version
echo -e "${BLUE}[5/5] Setting framework version in STACK.md${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ -f "STACK.md" ]]; then
  # Update the version line in STACK.md
  if grep -q "^- Version:" STACK.md; then
    # macOS and Linux compatible sed
    if [[ "$OSTYPE" == "darwin"* ]]; then
      sed -i '' "s/^- Version: .*$/- Version: $FRAMEWORK_VERSION/" STACK.md
    else
      sed -i "s/^- Version: .*$/- Version: $FRAMEWORK_VERSION/" STACK.md
    fi
    echo -e "  ${GREEN}✓${NC} Updated STACK.md with version $FRAMEWORK_VERSION"
  else
    echo -e "  ${YELLOW}⚠ Warning: Version field not found in STACK.md${NC}"
    echo "    You may need to add it manually"
  fi
  
  # Update installed date
  INSTALL_DATE=$(date +%Y-%m-%d)
  if grep -q "^- Installed:" STACK.md; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
      sed -i '' "s/^- Installed: .*$/- Installed: $INSTALL_DATE/" STACK.md
    else
      sed -i "s/^- Installed: .*$/- Installed: $INSTALL_DATE/" STACK.md
    fi
    echo -e "  ${GREEN}✓${NC} Set installation date to $INSTALL_DATE"
  fi
else
  echo -e "  ${YELLOW}⚠ Warning: STACK.md not found${NC}"
  echo "    Scaffold may have failed"
fi
echo ""

# Done
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                  ✓  INSTALLATION COMPLETE                      ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo -e "${GREEN}Framework installed successfully!${NC}"
echo ""
echo "What's next:"
echo "  1. Review STACK.md and fill in your project details"
echo "  2. Review PRODUCT.md (Core) or spec/ (Core+PM) for planning"
echo "  3. Tell your AI agent to start working:"
echo "     \"Read AGENTS.md and help me build this project\""
echo ""
echo "Useful commands:"
echo "  python3 .agentic/tools/doctor.py     # Check project health"
if [[ -n "$PROFILE" && "$PROFILE" == "core+product" ]] || grep -q "Profile: core+product" STACK.md 2>/dev/null; then
  echo "  python3 .agentic/tools/report.py     # View feature status"
  echo "  python3 .agentic/tools/verify.py     # Validate cross-references"
fi
echo ""
echo "Framework version: $FRAMEWORK_VERSION"
echo "Installation date: $(date +%Y-%m-%d)"
echo ""

