#!/usr/bin/env bash
# enable-product-management.sh: Add Product Management features to a Core-only project
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║         ENABLING PRODUCT MANAGEMENT FEATURES                   ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Check we're in a project root
if [[ ! -f "STACK.md" ]]; then
  echo -e "${RED}✗ Error: No STACK.md found. Are you in your project root?${NC}"
  exit 1
fi

# Check framework is installed
if [[ ! -d ".agentic" ]]; then
  echo -e "${RED}✗ Error: No .agentic/ folder found. Is the framework installed?${NC}"
  exit 1
fi

# Check current profile (no PCRE, portable)
CURRENT_PROFILE=$(
  grep -E '^[[:space:]]*-[[:space:]]*Profile:' STACK.md 2>/dev/null \
    | head -1 \
    | sed -E 's/.*Profile:[[:space:]]*([^[:space:]]+).*/\1/' \
    || echo "unknown"
)

if [[ "$CURRENT_PROFILE" == "core+product" ]]; then
  echo -e "${YELLOW}⚠ Product Management features are already enabled!${NC}"
  echo ""
  echo "Current profile: core+product"
  exit 0
fi

echo -e "${BLUE}Current profile: $CURRENT_PROFILE${NC}"
echo ""

# Ensure Core artifacts exist (some projects may have been initialized before Core profile was defined)
if [[ ! -f "CONTEXT_PACK.md" && -f ".agentic/init/CONTEXT_PACK.template.md" ]]; then
  cp ".agentic/init/CONTEXT_PACK.template.md" "CONTEXT_PACK.md"
  echo -e "${GREEN}✓ Created CONTEXT_PACK.md (Core)${NC}"
fi

if [[ ! -f "JOURNAL.md" && -f ".agentic/spec/JOURNAL.template.md" ]]; then
  cp ".agentic/spec/JOURNAL.template.md" "JOURNAL.md"
  echo -e "${GREEN}✓ Created JOURNAL.md (Core)${NC}"
fi

if [[ ! -f "HUMAN_NEEDED.md" && -f ".agentic/spec/HUMAN_NEEDED.template.md" ]]; then
  cp ".agentic/spec/HUMAN_NEEDED.template.md" "HUMAN_NEEDED.md"
  echo -e "${GREEN}✓ Created HUMAN_NEEDED.md (Core)${NC}"
fi
echo "What I'll create:"
echo "  ✓ spec/ directory with templates (PRD, TECH_SPEC, FEATURES, NFR)"
echo "  ✓ STATUS.md (project status and roadmap)"
echo "  ✓ Update STACK.md profile to 'core+product'"
echo ""
echo "Note: CONTEXT_PACK.md and HUMAN_NEEDED.md are already part of Core."
echo ""

read -p "Proceed? [y/N]: " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Cancelled."
  exit 0
fi

echo ""
echo -e "${BLUE}Creating files...${NC}"

# Create spec directory structure
if [[ ! -d "spec" ]]; then
  mkdir -p spec/acceptance
  mkdir -p spec/adr
  echo -e "${GREEN}✓ Created spec/ directory structure${NC}"
else
  echo -e "${YELLOW}⚠ spec/ already exists, skipping${NC}"
fi

# Copy spec templates
TEMPLATES=(
  "PRD.md"
  "TECH_SPEC.md"
  "FEATURES.md"
  "NFR.md"
  "OVERVIEW.md"
  "LESSONS.md"
)

for template in "${TEMPLATES[@]}"; do
  if [[ ! -f "spec/$template" && -f ".agentic/spec/${template%.md}.template.md" ]]; then
    cp ".agentic/spec/${template%.md}.template.md" "spec/$template"
    echo -e "${GREEN}✓ Created spec/$template${NC}"
  elif [[ -f "spec/$template" ]]; then
    echo -e "${YELLOW}⚠ spec/$template already exists, skipping${NC}"
  fi
done

# Create STATUS.md (PM-specific: project roadmap and status)
if [[ ! -f "STATUS.md" && -f ".agentic/init/STATUS.template.md" ]]; then
  cp ".agentic/init/STATUS.template.md" "STATUS.md"
  echo -e "${GREEN}✓ Created STATUS.md${NC}"
elif [[ -f "STATUS.md" ]]; then
  echo -e "${YELLOW}⚠ STATUS.md already exists, skipping${NC}"
fi

# Note: CONTEXT_PACK.md and HUMAN_NEEDED.md should already exist from Core profile

# Update STACK.md profile (portable; tolerate comments)
if grep -qE '^[[:space:]]*-[[:space:]]*Profile:' STACK.md; then
  sed -i.bak -E "s/^([[:space:]]*-[[:space:]]*Profile:[[:space:]]*).*/\\1core+product  # Updated: $(date +%Y-%m-%d)/" STACK.md
  rm STACK.md.bak 2>/dev/null || true
  echo -e "${GREEN}✓ Updated STACK.md (Profile: core+product)${NC}"
else
  # Insert Profile line after Version line in "## Agentic framework"
  perl -0777 -i -pe "s/(## Agentic framework\\n- Version:[^\\n]*\\n)/\\1- Profile: core+product  \\# Updated: $(date +%Y-%m-%d)\\n/" STACK.md || true
  echo -e "${GREEN}✓ Updated STACK.md (added Profile: core+product)${NC}"
fi

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                    COMPLETE                                    ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo -e "${GREEN}Product Management features enabled!${NC}"
echo ""
echo "Next steps:"
echo "  1. Review the new spec templates in spec/"
echo "  2. Fill in STATUS.md with your current project state"
echo "  3. Update CONTEXT_PACK.md with your architecture"
echo "  4. Tell your agent:"
echo "     \"I've enabled Product Management features. Please review"
echo "      spec/FEATURES.md and help me document our existing features.\""
echo ""
echo "New files:"
echo "  - spec/PRD.md          (Product requirements)"
echo "  - spec/TECH_SPEC.md    (Technical specification)"
echo "  - spec/FEATURES.md     (Feature tracking with IDs)"
echo "  - spec/NFR.md          (Non-functional requirements)"
echo "  - STATUS.md            (Project status & roadmap)"
echo ""
echo "Already part of Core (no changes):"
echo "  - CONTEXT_PACK.md      (Architecture overview)"
echo "  - HUMAN_NEEDED.md      (Escalation protocol)"
echo "  - JOURNAL.md           (Session continuity)"
echo ""

