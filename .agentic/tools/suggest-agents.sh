#!/bin/bash
# Analyze project and suggest useful custom agents
# Usage: bash .agentic/tools/suggest-agents.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${BLUE}Analyzing Project for Agent Suggestions${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

cd "$PROJECT_ROOT"

SUGGESTIONS=()

# Detect stack from STACK.md
STACK=""
if [[ -f "STACK.md" ]]; then
  STACK=$(cat STACK.md)
fi

# Detect by file extensions and patterns
detect_tech() {
  # Godot
  if [[ -f "project.godot" ]] || ls *.gd 2>/dev/null | head -1 > /dev/null; then
    echo -e "${CYAN}Detected: Godot Engine${NC}"
    SUGGESTIONS+=("godot-ui-agent|Godot UI/scene work - knows Control nodes, signals, scenes|sonnet")
    SUGGESTIONS+=("gdscript-agent|GDScript patterns, node lifecycle, autoloads|sonnet")
    
    # Check for GUT
    if [[ -d "addons/gut" ]] || grep -r "extends GutTest" . --include="*.gd" -q 2>/dev/null; then
      SUGGESTIONS+=("gut-test-agent|GUT testing framework patterns|haiku")
    fi
  fi
  
  # Game-related patterns
  if grep -ri "chess\|board\|piece\|move" . --include="*.gd" --include="*.ts" --include="*.py" -q 2>/dev/null; then
    SUGGESTIONS+=("game-rules-agent|Game rules, move validation, board state|sonnet")
  fi
  
  if grep -ri "minimax\|alpha.beta\|game.tree\|ai.*move" . --include="*.gd" --include="*.ts" --include="*.py" -q 2>/dev/null; then
    SUGGESTIONS+=("game-ai-agent|Game AI, search algorithms, heuristics|opus")
  fi
  
  # React/Next.js
  if [[ -f "next.config.js" ]] || [[ -f "next.config.mjs" ]]; then
    echo -e "${CYAN}Detected: Next.js${NC}"
    SUGGESTIONS+=("nextjs-agent|Next.js patterns, SSR, API routes, app router|sonnet")
    SUGGESTIONS+=("react-ui-agent|React components, hooks, state management|sonnet")
  elif [[ -f "package.json" ]] && grep -q '"react"' package.json 2>/dev/null; then
    echo -e "${CYAN}Detected: React${NC}"
    SUGGESTIONS+=("react-ui-agent|React components, hooks, state management|sonnet")
  fi
  
  # TypeScript
  if [[ -f "tsconfig.json" ]]; then
    echo -e "${CYAN}Detected: TypeScript${NC}"
    SUGGESTIONS+=("typescript-agent|TypeScript types, generics, strict patterns|sonnet")
  fi
  
  # Python
  if [[ -f "requirements.txt" ]] || [[ -f "pyproject.toml" ]] || [[ -f "setup.py" ]]; then
    echo -e "${CYAN}Detected: Python${NC}"
    SUGGESTIONS+=("python-agent|Python patterns, typing, async|sonnet")
    
    # Django
    if grep -q "django" requirements.txt 2>/dev/null || grep -q "django" pyproject.toml 2>/dev/null; then
      SUGGESTIONS+=("django-agent|Django models, views, migrations, ORM|sonnet")
    fi
    
    # FastAPI
    if grep -q "fastapi" requirements.txt 2>/dev/null || grep -q "fastapi" pyproject.toml 2>/dev/null; then
      SUGGESTIONS+=("fastapi-agent|FastAPI routes, Pydantic, async|sonnet")
    fi
  fi
  
  # Rust
  if [[ -f "Cargo.toml" ]]; then
    echo -e "${CYAN}Detected: Rust${NC}"
    SUGGESTIONS+=("rust-agent|Rust ownership, lifetimes, async, error handling|opus")
  fi
  
  # Go
  if [[ -f "go.mod" ]]; then
    echo -e "${CYAN}Detected: Go${NC}"
    SUGGESTIONS+=("go-agent|Go idioms, concurrency, error handling|sonnet")
  fi
  
  # Database patterns
  if grep -ri "prisma\|sequelize\|typeorm\|mongoose" . --include="*.ts" --include="*.js" -q 2>/dev/null; then
    SUGGESTIONS+=("database-agent|Database schemas, migrations, queries, ORM|sonnet")
  fi
  
  # API patterns
  if ls **/openapi*.yaml **/swagger*.yaml 2>/dev/null | head -1 > /dev/null || \
     grep -ri "fastapi\|express\|flask\|gin" . --include="*.py" --include="*.ts" --include="*.go" -q 2>/dev/null; then
    SUGGESTIONS+=("api-agent|REST/GraphQL API design, endpoints, validation|sonnet")
  fi
  
  # Audio/Music
  if grep -ri "audio\|sound\|music\|wav\|mp3\|ogg" . --include="*.gd" --include="*.cs" --include="*.ts" -q 2>/dev/null; then
    SUGGESTIONS+=("audio-agent|Audio playback, sound effects, music systems|haiku")
  fi
}

detect_tech

echo ""

if [[ ${#SUGGESTIONS[@]} -eq 0 ]]; then
  echo -e "${YELLOW}No specific patterns detected.${NC}"
  echo ""
  echo "Generic suggestions based on common needs:"
  SUGGESTIONS+=("domain-expert|Your project's domain logic and rules|sonnet")
  SUGGESTIONS+=("ui-agent|User interface patterns for your stack|sonnet")
  SUGGESTIONS+=("data-agent|Data models, validation, persistence|sonnet")
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}Suggested Project-Specific Agents:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

for suggestion in "${SUGGESTIONS[@]}"; do
  IFS='|' read -r name desc model <<< "$suggestion"
  echo -e "  ${CYAN}$name${NC}"
  echo "    Purpose: $desc"
  echo "    Model: $model"
  echo ""
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "To create an agent:"
echo ""
for suggestion in "${SUGGESTIONS[@]}"; do
  IFS='|' read -r name desc model <<< "$suggestion"
  echo "  bash .agentic/tools/create-agent.sh $name"
done
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

