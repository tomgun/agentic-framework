#!/usr/bin/env bash
# install.sh: Install the Agentic AI Framework into a new or existing project
# Usage: bash install.sh /path/to/your-project
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
TARGET_PROJECT_DIR="${1:-.}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_VERSION=""

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║       AGENTIC AI FRAMEWORK INSTALLATION TOOL                   ║"
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
  echo -e "${YELLOW}⚠ Warning: .agentic/ folder already exists in target project${NC}"
  echo "  Target: $TARGET_PROJECT_DIR"
  echo ""
  echo "  If this is a new installation, you may have a previous failed attempt."
  echo "  If you want to upgrade an existing installation, use upgrade.sh instead."
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

# Make scripts executable
chmod +x .agentic/init/scaffold.sh
chmod +x .agentic/tools/*.sh .agentic/tools/*.py 2>/dev/null || true
echo -e "  ${GREEN}✓${NC} Scripts made executable"
echo ""

# Step 4: Run scaffold.sh
echo -e "${BLUE}[4/5] Running scaffold script${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "  Creating template files..."
SCAFFOLD_CMD=".agentic/init/scaffold.sh"

if [[ -x "$SCAFFOLD_CMD" ]]; then
  # Run scaffold in non-interactive mode (agent will fill in details later)
  bash $SCAFFOLD_CMD --non-interactive
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
echo "  1. Open your AI agent (Cursor/Claude/Copilot) and say:"
echo ""
echo "     \"Read .agentic/init/init_playbook.md and help me initialize"
echo "     this project by filling in STACK.md, PRODUCT.md, and"
echo "     CONTEXT_PACK.md based on what we're building.\""
echo ""
echo "  2. The agent will:"
echo "     - Ask what you're building and which profile to use (Core or Core+PM)"
echo "     - Fill in project-specific details"
echo "     - Set up quality checks"
echo ""
echo "  3. Then you're ready to start building!"
echo ""
echo "Framework version: $FRAMEWORK_VERSION"
echo "Installation date: $(date +%Y-%m-%d)"
echo ""

