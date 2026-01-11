#!/bin/bash
# Create a project-specific agent definition
# Usage: bash .agentic/tools/create-agent.sh <agent-name>

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [[ -z "$1" ]]; then
  echo "Usage: bash .agentic/tools/create-agent.sh <agent-name>"
  echo ""
  echo "Examples:"
  echo "  bash .agentic/tools/create-agent.sh godot-expert"
  echo "  bash .agentic/tools/create-agent.sh chess-rules"
  echo "  bash .agentic/tools/create-agent.sh ui-specialist"
  echo ""
  echo "This creates .agentic/agents/claude/subagents/<agent-name>.md"
  exit 1
fi

AGENT_NAME="$1"
AGENT_FILE="$PROJECT_ROOT/.agentic/agents/claude/subagents/${AGENT_NAME}.md"

# Check if already exists
if [[ -f "$AGENT_FILE" ]]; then
  echo -e "${YELLOW}Agent '$AGENT_NAME' already exists at:${NC}"
  echo "  $AGENT_FILE"
  echo ""
  read -p "Overwrite? (y/N): " CONFIRM
  if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo "Aborted."
    exit 0
  fi
fi

# Ensure directory exists
mkdir -p "$(dirname "$AGENT_FILE")"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${BLUE}Creating Agent: $AGENT_NAME${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Gather info interactively
read -p "Purpose (one line): " PURPOSE
echo ""
read -p "When to use (describe scenarios): " WHEN_TO_USE
echo ""
read -p "Recommended model (haiku/sonnet/opus) [sonnet]: " MODEL
MODEL=${MODEL:-sonnet}
echo ""
read -p "Key files/patterns this agent should know (comma-separated): " KEY_FILES
echo ""
read -p "Special instructions (or press Enter to skip): " SPECIAL

# Auto-detect stack
STACK_INFO=""
if [[ -f "$PROJECT_ROOT/STACK.md" ]]; then
  STACK_INFO=$(grep -E "^- (Language|Framework|Engine):" "$PROJECT_ROOT/STACK.md" 2>/dev/null | head -3 || echo "")
fi

# Generate the agent file
cat > "$AGENT_FILE" << EOF
# ${AGENT_NAME} Agent

**Purpose**: ${PURPOSE}

**Recommended Model**: \`${MODEL}\`

## When to Use

${WHEN_TO_USE}

## Project Context

EOF

if [[ -n "$STACK_INFO" ]]; then
  echo "From STACK.md:" >> "$AGENT_FILE"
  echo "$STACK_INFO" >> "$AGENT_FILE"
  echo "" >> "$AGENT_FILE"
fi

if [[ -n "$KEY_FILES" ]]; then
  echo "Key files:" >> "$AGENT_FILE"
  IFS=',' read -ra FILES <<< "$KEY_FILES"
  for file in "${FILES[@]}"; do
    echo "- $(echo "$file" | xargs)" >> "$AGENT_FILE"
  done
  echo "" >> "$AGENT_FILE"
fi

cat >> "$AGENT_FILE" << EOF
## Prompt Template

\`\`\`
You are a ${AGENT_NAME} agent specialized in: ${PURPOSE}

Task: {TASK_DESCRIPTION}

Instructions:
1. Focus on your area of expertise
2. Reference project-specific patterns and conventions
3. Provide clear, actionable output
EOF

if [[ -n "$SPECIAL" ]]; then
  echo "4. ${SPECIAL}" >> "$AGENT_FILE"
fi

cat >> "$AGENT_FILE" << EOF

Constraints:
- Stay within your domain expertise
- Ask for clarification if task is outside your specialty
- Follow project conventions from STACK.md
\`\`\`

## Expected Deliverables

- Clear response focused on ${PURPOSE}
- References to specific files/code when applicable
- Actionable next steps if any

## Example Invocation

\`\`\`
Task tool:
  subagent_type: ${AGENT_NAME}
  model: ${MODEL}
  prompt: "[Your task for this agent]"
\`\`\`
EOF

echo ""
echo -e "${GREEN}✓ Created: $AGENT_FILE${NC}"
echo ""
echo "Next steps:"
echo "  1. Review and customize the generated file"
echo "  2. Add more specific instructions as needed"
echo "  3. Agent is now available for use"
echo ""
echo "To use:"
echo "  Task tool → subagent_type: $AGENT_NAME"

