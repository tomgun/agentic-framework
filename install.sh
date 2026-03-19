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
echo -e "${BLUE}[1/7] Reading framework version${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ -f "$SCRIPT_DIR/VERSION" ]]; then
  FRAMEWORK_VERSION=$(cat "$SCRIPT_DIR/VERSION" | tr -d '[:space:]')
  echo -e "  ${GREEN}✓${NC} Framework version: $FRAMEWORK_VERSION"
elif [[ -f "$SCRIPT_DIR/.agentic/lib/VERSION" ]]; then
  FRAMEWORK_VERSION=$(cat "$SCRIPT_DIR/.agentic/lib/VERSION" | tr -d '[:space:]')
  echo -e "  ${GREEN}✓${NC} Framework version: $FRAMEWORK_VERSION"
else
  echo -e "  ${RED}✗ Error: VERSION file not found in framework directory${NC}"
  exit 1
fi
echo ""

# Step 2: Verify target directory
echo -e "${BLUE}[2/7] Verifying target project${NC}"
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
  # In non-interactive mode, abort (safer default)
  if [[ -t 0 ]]; then
    read -p "  Continue and overwrite? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo -e "${YELLOW}Installation cancelled${NC}"
      exit 0
    fi
  else
    echo -e "${RED}Non-interactive mode: refusing to overwrite existing .agentic/${NC}"
    echo "  Use upgrade.sh for upgrades, or remove .agentic/ first"
    exit 1
  fi
fi
echo ""

# Step 3: Install framework files
echo -e "${BLUE}[3/7] Installing framework files${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ -d ".agentic" ]]; then
  BACKUP_DIR="agentic-backup-$(date +%Y%m%d-%H%M%S)"
  echo "  Backing up existing .agentic/ to $BACKUP_DIR/"
  mv .agentic "$BACKUP_DIR"
fi

# Create .agentic/ structure
mkdir -p .agentic

# Copy thin wrappers (committed to user's repo)
cp "$SCRIPT_DIR/.agentic/bootstrap.sh" .agentic/
cp "$SCRIPT_DIR/.agentic/ag" .agentic/
chmod +x .agentic/bootstrap.sh .agentic/ag
echo -e "  ${GREEN}✓${NC} Thin wrappers installed (bootstrap.sh, ag)"

# Copy hook wrappers
if [[ -d "$SCRIPT_DIR/.agentic/hooks" ]]; then
  cp -r "$SCRIPT_DIR/.agentic/hooks" .agentic/
  chmod +x .agentic/hooks/pre-commit .agentic/hooks/claude/*.sh 2>/dev/null || true
  echo -e "  ${GREEN}✓${NC} Hook wrappers installed"
fi

# Build and save lib tarball (or use pre-built one)
TARBALL_NAME="agentic-lib-v${FRAMEWORK_VERSION}.tar.gz"
if [[ -f "$SCRIPT_DIR/.agentic/$TARBALL_NAME" ]]; then
  # Pre-built tarball (from GitHub release)
  cp "$SCRIPT_DIR/.agentic/$TARBALL_NAME" .agentic/
  echo -e "  ${GREEN}✓${NC} Lib tarball copied ($TARBALL_NAME)"
elif [[ -d "$SCRIPT_DIR/.agentic/lib" ]]; then
  # Build tarball from source (installing from cloned repo)
  (cd "$SCRIPT_DIR/.agentic/lib" && tar czf "$TARGET_PROJECT_DIR/.agentic/$TARBALL_NAME" .)
  echo -e "  ${GREEN}✓${NC} Lib tarball built from source ($TARBALL_NAME)"
else
  echo -e "  ${RED}✗ Error: No lib/ directory or tarball found${NC}"
  exit 1
fi

# Extract lib/ from tarball
mkdir -p .agentic/lib
tar xzf ".agentic/$TARBALL_NAME" -C .agentic/lib/
echo -e "  ${GREEN}✓${NC} Framework lib extracted"

# Make scripts executable
chmod +x .agentic/lib/init/scaffold.sh
chmod +x .agentic/lib/tools/*.sh .agentic/lib/tools/*.py 2>/dev/null || true
echo -e "  ${GREEN}✓${NC} Scripts made executable"

# Add .agentic/lib/ and .agentic/session/ to .gitignore
if [[ -f ".gitignore" ]]; then
  if ! grep -q '.agentic/lib/' .gitignore 2>/dev/null; then
    echo "" >> .gitignore
    echo "# Agentic Framework (extracted at runtime from tarball)" >> .gitignore
    echo ".agentic/lib/" >> .gitignore
    echo ".agentic/session/" >> .gitignore
    echo -e "  ${GREEN}✓${NC} Added .agentic/lib/ and .agentic/session/ to .gitignore"
  fi
else
  cat > .gitignore <<'GITIGNORE'
# Agentic Framework (extracted at runtime from tarball)
.agentic/lib/
.agentic/session/
GITIGNORE
  echo -e "  ${GREEN}✓${NC} Created .gitignore with framework entries"
fi
echo ""

# Step 4: Run scaffold.sh
echo -e "${BLUE}[4/7] Running scaffold script${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "  Creating template files..."
SCAFFOLD_CMD=".agentic/lib/init/scaffold.sh"

if [[ -x "$SCAFFOLD_CMD" ]]; then
  # Run scaffold in non-interactive mode (agent will fill in details later)
  bash $SCAFFOLD_CMD --non-interactive
else
  echo -e "${RED}✗ Error: scaffold.sh not found or not executable${NC}"
  exit 1
fi
echo ""

# Step 5: Update STACK.md with framework version
echo -e "${BLUE}[5/7] Setting framework version in STACK.md${NC}"
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

# Step 6: Generate Claude Skills (if skill sources exist)
echo -e "${BLUE}[6/7] Generating Claude Skills${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ -f ".agentic/lib/tools/generate-skills.sh" ]] && [[ -d ".agentic/lib/agents/claude/skills" ]]; then
  bash .agentic/lib/tools/generate-skills.sh 2>/dev/null || true
  if [[ -d ".claude/skills" ]]; then
    SKILL_COUNT=$(ls -1 .claude/skills/ 2>/dev/null | wc -l | tr -d ' ')
    echo -e "  ${GREEN}✓${NC} Generated $SKILL_COUNT Claude Skills in .claude/skills/"
    echo "    Skills are auto-discovered by Claude Code based on task description."
  fi
else
  echo -e "  ${YELLOW}⚠${NC} Skipping (no skill sources found)"
fi

# Copy Claude Code hooks.json if template exists
if [[ -f ".agentic/lib/claude-hooks/hooks.json" ]]; then
  mkdir -p .claude
  cp .agentic/lib/claude-hooks/hooks.json .claude/hooks.json
  echo -e "  ${GREEN}✓${NC} Installed Claude Code hooks (.claude/hooks.json)"
fi
echo ""

# Step 7: Offer to suggest project-specific agents
echo -e "${BLUE}[7/7] Project-specific agents${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ -f ".agentic/lib/tools/suggest-agents.sh" ]]; then
  echo "  The framework can suggest specialized agents based on your tech stack."
  echo ""
  # Skip prompt if not running interactively (e.g., in tests)
  if [[ -t 0 ]]; then
    read -p "  Run agent suggestions now? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      echo ""
      bash .agentic/lib/tools/suggest-agents.sh
    else
      echo -e "  ${YELLOW}⚠${NC} Skipped. Run later with: bash .agentic/ag suggest-agents"
    fi
  else
    echo -e "  ${YELLOW}⚠${NC} Non-interactive mode. Run later: bash .agentic/ag suggest-agents"
  fi
else
  echo -e "  ${YELLOW}⚠${NC} suggest-agents.sh not found"
fi
echo ""

# Done
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                  ✓  INSTALLATION COMPLETE                      ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo -e "${GREEN}Framework installed successfully!${NC}"
echo ""
echo "What's committed to your repo:"
echo "  .agentic/bootstrap.sh          # Extracts lib from tarball"
echo "  .agentic/ag                    # CLI entry point"
echo "  .agentic/$TARBALL_NAME  # Framework package"
echo "  .agentic/hooks/               # Git + Claude hook wrappers"
echo ""
echo "What's next:"
echo "  1. Open your AI agent (Claude/Cursor/Copilot/Codex) and say:"
echo ""
echo "     \"Read .agentic/lib/init/init_playbook.md and help me initialize this project\""
echo ""
echo "  2. The agent will:"
echo "     - Ask what you're building and which profile to use (Discovery or Formal)"
echo "     - Fill in project-specific details"
echo "     - Set up quality checks"
echo ""
echo "  3. Then you're ready to start building!"
echo ""
echo "Framework version: $FRAMEWORK_VERSION"
echo "Installation date: $(date +%Y-%m-%d)"
echo ""
