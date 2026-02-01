#!/usr/bin/env bash
# setup-agent.sh: Create auto-loaded files for specific AI coding tools
# 
# Usage:
#   bash .agentic/tools/setup-agent.sh <tool>
#   bash .agentic/tools/setup-agent.sh all
#
# Supported tools:
#   claude       - Creates CLAUDE.md (auto-loaded by Claude Code)
#   cursor       - Creates .cursorrules (auto-loaded by Cursor)
#   copilot      - Creates .github/copilot-instructions.md (auto-loaded by GitHub Copilot)
#   codex        - Creates .codex/instructions.md (auto-loaded by OpenAI Codex CLI)
#   all          - Creates files for all tools
#   
# Multi-agent setup:
#   cursor-agents  - Creates .cursor/agents/ with role definitions
#   pipeline       - Creates .agentic/pipeline/ and AGENTS_ACTIVE.md
#
# Why this matters:
#   AGENTS.md is NOT auto-loaded by any tool. Each tool has its own file:
#   - Claude Code: CLAUDE.md
#   - Cursor: .cursorrules or .cursor/rules/*.mdc
#   - Copilot: .github/copilot-instructions.md
#   - Codex: .codex/instructions.md
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
  echo "Auto-Loaded Files:"
  echo "  claude         Create CLAUDE.md for Claude Code"
  echo "  cursor         Create .cursorrules for Cursor"
  echo "  copilot        Create .github/copilot-instructions.md for GitHub Copilot"
  echo "  codex          Create .codex/instructions.md for OpenAI Codex CLI"
  echo "  all            Create files for all tools"
  echo ""
  echo "Multi-Agent Setup:"
  echo "  cursor-agents  Create .cursor/agents/ with specialized role definitions"
  echo "  pipeline       Create pipeline infrastructure (AGENTS_ACTIVE.md, etc.)"
  echo ""
  echo "Examples:"
  echo "  bash .agentic/tools/setup-agent.sh claude"
  echo "  bash .agentic/tools/setup-agent.sh all"
  echo "  bash .agentic/tools/setup-agent.sh cursor-agents  # For multi-agent in Cursor"
  echo "  bash .agentic/tools/setup-agent.sh pipeline       # For sequential agent pipeline"
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

setup_codex() {
  echo -e "${BLUE}Setting up OpenAI Codex CLI...${NC}"

  mkdir -p "$PROJECT_ROOT/.codex"
  TARGET="$PROJECT_ROOT/.codex/instructions.md"
  SOURCE="$AGENTIC_DIR/agents/codex/codex-instructions.md"

  if [[ -f "$TARGET" ]]; then
    echo -e "${YELLOW}⚠ .codex/instructions.md already exists. Backing up to instructions.md.bak${NC}"
    cp "$TARGET" "$TARGET.bak"
  fi

  if [[ -f "$SOURCE" ]]; then
    cp "$SOURCE" "$TARGET"
    echo -e "${GREEN}✓ Created .codex/instructions.md${NC}"
    echo "  OpenAI Codex CLI will now auto-load framework instructions."
  else
    # Create minimal instructions
    cat > "$TARGET" << 'EOF'
# Codex Instructions - Agentic Framework

This project uses the Agentic Framework for AI-assisted development.

## MANDATORY: Before doing any work

1. Read `.agentic/checklists/session_start.md`
2. Follow the session start protocol
3. Check `HUMAN_NEEDED.md` for blockers

## Full Guidelines

See `.agentic/agents/shared/agent_operating_guidelines.md` for complete instructions.

## Non-Negotiables

- Acceptance criteria before code
- Add/update tests for new or changed logic
- Keep documentation current
- Add blockers to HUMAN_NEEDED.md
- Update JOURNAL.md at session end

See `AGENTS.md` for full list.
EOF
    echo -e "${GREEN}✓ Created .codex/instructions.md (minimal)${NC}"
    echo "  OpenAI Codex CLI will now auto-load framework instructions."
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
- Keep documentation current (CONTEXT_PACK.md, OVERVIEW.md)
- Add blockers to HUMAN_NEEDED.md
- Update JOURNAL.md at session end

See `AGENTS.md` for full list.
EOF
    echo -e "${GREEN}✓ Created .github/copilot-instructions.md (minimal)${NC}"
    echo "  GitHub Copilot will now auto-load framework instructions."
  fi
}

setup_cursor_agents() {
  echo -e "${BLUE}Setting up Cursor specialized agents...${NC}"
  
  mkdir -p "$PROJECT_ROOT/.cursor/agents"
  
  ROLES_DIR="$AGENTIC_DIR/agents/roles"
  
  if [[ ! -d "$ROLES_DIR" ]]; then
    echo -e "${RED}✗ Role definitions not found at $ROLES_DIR${NC}"
    return 1
  fi
  
  # Copy each role as a Cursor agent file
  for role_file in "$ROLES_DIR"/*.md; do
    if [[ -f "$role_file" ]]; then
      filename=$(basename "$role_file")
      # Convert snake_case to kebab-case for Cursor
      agent_name=$(echo "$filename" | sed 's/_/-/g')
      cp "$role_file" "$PROJECT_ROOT/.cursor/agents/$agent_name"
      echo -e "${GREEN}  ✓${NC} Created .cursor/agents/$agent_name"
    fi
  done
  
  echo -e "${GREEN}✓ Created Cursor agents in .cursor/agents/${NC}"
  echo "  Reference these agents in Cursor with @agent-name"
  echo "  See: .agentic/agents/cursor/agents-setup.md for usage"
}

setup_pipeline() {
  echo -e "${BLUE}Setting up multi-agent pipeline infrastructure...${NC}"
  
  # Create pipeline directory
  mkdir -p "$PROJECT_ROOT/.agentic/pipeline"
  mkdir -p "$PROJECT_ROOT/.agentic/pipeline/archive"
  
  echo -e "${GREEN}  ✓${NC} Created .agentic/pipeline/"
  
  # Create AGENTS_ACTIVE.md if not exists
  if [[ ! -f "$PROJECT_ROOT/AGENTS_ACTIVE.md" ]]; then
    if [[ -f "$AGENTIC_DIR/spec/AGENTS_ACTIVE.template.md" ]]; then
      cp "$AGENTIC_DIR/spec/AGENTS_ACTIVE.template.md" "$PROJECT_ROOT/AGENTS_ACTIVE.md"
    else
      cat > "$PROJECT_ROOT/AGENTS_ACTIVE.md" << 'EOF'
# Active Agents

Track which agents are working on which features.

## Currently Active

| Agent | Feature | Status | Started | Last Update |
|-------|---------|--------|---------|-------------|
| - | - | - | - | - |

## Feature Locks

To prevent conflicts, agents should "lock" features they're working on:

| Feature | Locked By | Since | Worktree |
|---------|-----------|-------|----------|
| - | - | - | - |

## Coordination Rules

1. Check this file before starting work on a feature
2. Add yourself when starting
3. Remove yourself when done
4. Don't work on locked features
EOF
    fi
    echo -e "${GREEN}  ✓${NC} Created AGENTS_ACTIVE.md"
  else
    echo -e "${YELLOW}  ⚠${NC} AGENTS_ACTIVE.md already exists"
  fi
  
  # Create pipeline template
  if [[ ! -f "$PROJECT_ROOT/.agentic/pipeline/TEMPLATE.md" ]]; then
    cat > "$PROJECT_ROOT/.agentic/pipeline/TEMPLATE.md" << 'EOF'
<!-- format: pipeline-v0.1.0 -->
# Pipeline: F-#### ([Feature Name])

## Status
- Current agent: [None/Research/Planning/Test/Implementation/Review/Spec/Docs/Git]
- Phase: [not_started/in_progress/blocked/complete]
- Started: YYYY-MM-DD HH:MM

## Completed Agents
<!-- Mark with [x] when done -->
- [ ] Research Agent
- [ ] Planning Agent
- [ ] Test Agent
- [ ] Implementation Agent
- [ ] Review Agent
- [ ] Spec Update Agent
- [ ] Documentation Agent
- [ ] Git Agent

## Handoff Notes
<!-- Each agent adds notes for the next -->

### Research → Planning
- Findings: 
- Recommendation:
- Research doc:

### Planning → Test
- Acceptance criteria:
- Test strategy:

### Test → Implementation
- Test count:
- All failing:
- Command:

### Implementation → Review
- Files changed:
- Tests passing:
- Notes:

### Review → Spec Update
- Approved: yes/no
- Issues:

### Spec Update → Documentation
- FEATURES.md updated:
- Status:

### Documentation → Git
- Docs updated:
- Ready for commit:
EOF
    echo -e "${GREEN}  ✓${NC} Created .agentic/pipeline/TEMPLATE.md"
  fi
  
  echo -e "${GREEN}✓ Pipeline infrastructure ready${NC}"
  echo ""
  echo "To start a feature pipeline:"
  echo "  1. Copy TEMPLATE.md to F-####-pipeline.md"
  echo "  2. Update feature ID and name"
  echo "  3. Register in AGENTS_ACTIVE.md"
  echo "  4. Start with Research Agent"
  echo ""
  echo "See: .agentic/workflows/multi_agent_coordination.md"
}

setup_all() {
  echo "Setting up all supported tools..."
  echo ""
  setup_claude
  echo ""
  setup_cursor
  echo ""
  setup_copilot
  echo ""
  setup_codex
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
  codex)
    setup_codex
    ;;
  cursor-agents)
    setup_cursor_agents
    ;;
  pipeline)
    setup_pipeline
    ;;
  all)
    setup_all
    ;;
  all-agents)
    setup_all
    echo ""
    setup_cursor_agents
    echo ""
    setup_pipeline
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

