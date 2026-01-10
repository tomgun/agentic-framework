#!/usr/bin/env bash
# setup-agent.sh: Create auto-loaded files for specific AI coding tools
# 
# Usage:
#   bash .agentic/tools/setup-agent.sh <tool>
#   bash .agentic/tools/setup-agent.sh all
#
# Supported tools:
#   claude  - Creates CLAUDE.md (auto-loaded by Claude Code)
#   cursor  - Creates .cursorrules (auto-loaded by Cursor)
#   copilot - Creates .github/copilot-instructions.md (auto-loaded by GitHub Copilot)
#   all     - Creates files for all tools
#
# Why this matters:
#   AGENTS.md is NOT auto-loaded by any tool. Each tool has its own file:
#   - Claude Code: CLAUDE.md
#   - Cursor: .cursorrules or .cursor/rules/*.mdc
#   - Copilot: .github/copilot-instructions.md
#
set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTIC_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$AGENTIC_DIR/.." && pwd)"

show_help() {
  echo "Usage: bash .agentic/tools/setup-agent.sh <tool>"
  echo ""
  echo "Tools:"
  echo "  claude   Create CLAUDE.md for Claude Code"
  echo "  cursor   Create .cursorrules for Cursor"
  echo "  copilot  Create .github/copilot-instructions.md for GitHub Copilot"
  echo "  all      Create files for all tools"
  echo ""
  echo "Examples:"
  echo "  bash .agentic/tools/setup-agent.sh claude"
  echo "  bash .agentic/tools/setup-agent.sh all"
}

setup_claude() {
  echo -e "${BLUE}Setting up Claude Code...${NC}"
  
  TARGET="$PROJECT_ROOT/CLAUDE.md"
  SOURCE="$AGENTIC_DIR/agents/claude/CLAUDE.md"
  
  if [[ -f "$TARGET" ]]; then
    echo -e "${YELLOW}⚠ CLAUDE.md already exists. Backing up to CLAUDE.md.bak${NC}"
    cp "$TARGET" "$TARGET.bak"
  fi
  
  if [[ -f "$SOURCE" ]]; then
    cp "$SOURCE" "$TARGET"
    echo -e "${GREEN}✓ Created CLAUDE.md${NC}"
    echo "  Claude Code will now auto-load framework instructions."
  else
    echo -e "${RED}✗ Source file not found: $SOURCE${NC}"
    return 1
  fi
}

setup_cursor() {
  echo -e "${BLUE}Setting up Cursor...${NC}"
  
  # Cursor can use .cursorrules (root) or .cursor/rules/*.mdc
  TARGET="$PROJECT_ROOT/.cursorrules"
  SOURCE="$AGENTIC_DIR/agents/cursor/cursorrules.txt"
  
  if [[ -f "$TARGET" ]]; then
    echo -e "${YELLOW}⚠ .cursorrules already exists. Backing up to .cursorrules.bak${NC}"
    cp "$TARGET" "$TARGET.bak"
  fi
  
  if [[ -f "$SOURCE" ]]; then
    cp "$SOURCE" "$TARGET"
    echo -e "${GREEN}✓ Created .cursorrules${NC}"
    echo "  Cursor will now auto-load framework instructions."
  else
    # Create minimal .cursorrules pointing to framework
    cat > "$TARGET" << 'EOF'
# Cursor Rules - Agentic Framework

This project uses the Agentic Framework for AI-assisted development.

## MANDATORY: Before doing any work

1. Read `.agentic/checklists/session_start.md`
2. Follow the session start protocol
3. Check `HUMAN_NEEDED.md` for blockers

## Full Guidelines

See `.agentic/agents/shared/agent_operating_guidelines.md` for complete instructions.

## Non-Negotiables

See `AGENTS.md` for non-negotiable rules:
- Add/update tests for new or changed logic
- Keep documentation current
- Add blockers to HUMAN_NEEDED.md
- Update JOURNAL.md at session end
EOF
    echo -e "${GREEN}✓ Created .cursorrules (minimal)${NC}"
    echo "  Cursor will now auto-load framework instructions."
  fi
  
  # Also create .cursor/rules/agentic.mdc if .cursor exists
  if [[ -d "$PROJECT_ROOT/.cursor" ]] || [[ -d "$PROJECT_ROOT/.cursor/rules" ]]; then
    mkdir -p "$PROJECT_ROOT/.cursor/rules"
    if [[ -f "$AGENTIC_DIR/agents/cursor/agentic-framework.mdc" ]]; then
      cp "$AGENTIC_DIR/agents/cursor/agentic-framework.mdc" "$PROJECT_ROOT/.cursor/rules/"
      echo -e "${GREEN}✓ Also created .cursor/rules/agentic-framework.mdc${NC}"
    fi
  fi
}

setup_copilot() {
  echo -e "${BLUE}Setting up GitHub Copilot...${NC}"
  
  mkdir -p "$PROJECT_ROOT/.github"
  TARGET="$PROJECT_ROOT/.github/copilot-instructions.md"
  SOURCE="$AGENTIC_DIR/agents/copilot/copilot-instructions.md"
  
  if [[ -f "$TARGET" ]]; then
    echo -e "${YELLOW}⚠ copilot-instructions.md already exists. Backing up to copilot-instructions.md.bak${NC}"
    cp "$TARGET" "$TARGET.bak"
  fi
  
  if [[ -f "$SOURCE" ]]; then
    cp "$SOURCE" "$TARGET"
    echo -e "${GREEN}✓ Created .github/copilot-instructions.md${NC}"
    echo "  GitHub Copilot will now auto-load framework instructions."
  else
    # Create minimal copilot-instructions.md
    cat > "$TARGET" << 'EOF'
# GitHub Copilot Instructions - Agentic Framework

This project uses the Agentic Framework for AI-assisted development.

## MANDATORY: Before doing any work

1. Read `.agentic/checklists/session_start.md`
2. Follow the session start protocol
3. Check `HUMAN_NEEDED.md` for blockers

## Full Guidelines

See `.agentic/agents/shared/agent_operating_guidelines.md` for complete instructions.

## Non-Negotiables

- Add/update tests for new or changed logic
- Keep documentation current (CONTEXT_PACK.md, PRODUCT.md)
- Add blockers to HUMAN_NEEDED.md
- Update JOURNAL.md at session end

See `AGENTS.md` for full list.
EOF
    echo -e "${GREEN}✓ Created .github/copilot-instructions.md (minimal)${NC}"
    echo "  GitHub Copilot will now auto-load framework instructions."
  fi
}

setup_all() {
  echo "Setting up all supported tools..."
  echo ""
  setup_claude
  echo ""
  setup_cursor
  echo ""
  setup_copilot
}

# Main
if [[ $# -eq 0 ]]; then
  show_help
  exit 0
fi

TOOL="${1:-}"

case "$TOOL" in
  claude)
    setup_claude
    ;;
  cursor)
    setup_cursor
    ;;
  copilot)
    setup_copilot
    ;;
  all)
    setup_all
    ;;
  -h|--help|help)
    show_help
    ;;
  *)
    echo -e "${RED}Unknown tool: $TOOL${NC}"
    echo ""
    show_help
    exit 1
    ;;
esac

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}Setup complete!${NC}"
echo ""
echo "The auto-loaded file(s) now instruct agents to:"
echo "  1. Read .agentic/checklists/session_start.md first"
echo "  2. Follow agent_operating_guidelines.md"
echo "  3. Respect AGENTS.md non-negotiables"
echo ""
echo "Note: AGENTS.md is a REFERENCE file (not auto-loaded)."
echo "      The tool-specific files point to it."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

