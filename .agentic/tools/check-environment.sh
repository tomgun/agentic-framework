#!/bin/bash
# Environment Detection & Tool Setup Check
# Detects which AI coding tools might be in use and suggests setup
#
# Usage:
#   check-environment.sh         # Check and suggest
#   check-environment.sh --fix   # Auto-create for detected environments
#   check-environment.sh --list  # Just list what files exist

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Parse args
FIX_MODE=false
LIST_MODE=false
if [[ "$1" == "--fix" ]]; then
  FIX_MODE=true
elif [[ "$1" == "--list" ]]; then
  LIST_MODE=true
fi

if [[ "$LIST_MODE" == true ]]; then
  echo "Tool files in project:"
  [[ -f "$PROJECT_ROOT/CLAUDE.md" ]] && echo "  ✓ CLAUDE.md (Claude Code)"
  [[ -f "$PROJECT_ROOT/.cursorrules" ]] && echo "  ✓ .cursorrules (Cursor)"
  [[ -f "$PROJECT_ROOT/.github/copilot-instructions.md" ]] && echo "  ✓ .github/copilot-instructions.md (Copilot)"
  [[ -f "$PROJECT_ROOT/GEMINI.md" ]] && echo "  ✓ GEMINI.md (Gemini)"
  [[ -f "$PROJECT_ROOT/AGENTS.md" ]] && echo "  ✓ AGENTS.md (Codex/general)"
  echo ""
  echo "To add another tool: bash .agentic/tools/setup-agent.sh <tool>"
  echo "Available: claude, cursor, copilot, codex, gemini"
  exit 0
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${BLUE}Environment Detection & Tool Setup${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

MISSING=()
DETECTED=()

# Check for Claude Code
if [[ -n "$CLAUDE_CODE" ]] || [[ -d "$HOME/.claude" ]] || pgrep -f "claude" > /dev/null 2>&1; then
  DETECTED+=("claude")
  if [[ ! -f "$PROJECT_ROOT/CLAUDE.md" ]]; then
    echo -e "${YELLOW}⚠ Claude Code detected but CLAUDE.md missing${NC}"
    MISSING+=("claude")
  else
    echo -e "${GREEN}✓ Claude Code: CLAUDE.md exists${NC}"
  fi
else
  if [[ -f "$PROJECT_ROOT/CLAUDE.md" ]]; then
    echo -e "${GREEN}✓ CLAUDE.md exists (Claude Code ready)${NC}"
  fi
fi

# Check for Cursor
if [[ -n "$CURSOR_SESSION" ]] || [[ -d "$HOME/.cursor" ]] || pgrep -f "Cursor" > /dev/null 2>&1; then
  DETECTED+=("cursor")
  if [[ ! -f "$PROJECT_ROOT/.cursorrules" ]]; then
    echo -e "${YELLOW}⚠ Cursor detected but .cursorrules missing${NC}"
    MISSING+=("cursor")
  else
    echo -e "${GREEN}✓ Cursor: .cursorrules exists${NC}"
  fi
else
  if [[ -f "$PROJECT_ROOT/.cursorrules" ]]; then
    echo -e "${GREEN}✓ .cursorrules exists (Cursor ready)${NC}"
  fi
fi

# Check for GitHub Copilot (via VS Code or GitHub CLI)
if [[ -d "$HOME/.vscode" ]] || command -v gh &> /dev/null; then
  DETECTED+=("copilot")
  if [[ ! -f "$PROJECT_ROOT/.github/copilot-instructions.md" ]]; then
    echo -e "${YELLOW}⚠ VS Code/GitHub detected but copilot-instructions.md missing${NC}"
    MISSING+=("copilot")
  else
    echo -e "${GREEN}✓ GitHub Copilot: .github/copilot-instructions.md exists${NC}"
  fi
fi

# Check for Codex
if [[ -n "$CODEX_CLI" ]] || command -v codex &> /dev/null; then
  DETECTED+=("codex")
  if [[ ! -f "$PROJECT_ROOT/AGENTS.md" ]]; then
    echo -e "${YELLOW}⚠ Codex detected but AGENTS.md missing${NC}"
    MISSING+=("codex")
  else
    echo -e "${GREEN}✓ Codex: AGENTS.md exists${NC}"
  fi
fi

echo ""

# Summary and suggestions
if [[ ${#MISSING[@]} -gt 0 ]]; then
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo -e "${YELLOW}Missing tool-specific files detected!${NC}"
  echo ""
  echo "Run one of these commands to fix:"
  echo ""
  
  for tool in "${MISSING[@]}"; do
    echo -e "  ${BLUE}bash .agentic/tools/setup-agent.sh $tool${NC}"
  done
  
  echo ""
  echo "Or set up all at once:"
  echo -e "  ${BLUE}bash .agentic/tools/setup-agent.sh all${NC}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  
  # If --fix flag provided, auto-fix
  if [[ "$1" == "--fix" ]]; then
    echo ""
    echo -e "${BLUE}Auto-fixing...${NC}"
    for tool in "${MISSING[@]}"; do
      bash "$SCRIPT_DIR/setup-agent.sh" "$tool"
    done
  fi
  
  exit 1
else
  echo -e "${GREEN}All detected environments have proper tool files!${NC}"
  
  if [[ ${#DETECTED[@]} -eq 0 ]]; then
    echo ""
    echo "No specific AI tools detected. You can still set up files for:"
    echo -e "  ${BLUE}bash .agentic/tools/setup-agent.sh all${NC}"
  fi
  
  exit 0
fi

