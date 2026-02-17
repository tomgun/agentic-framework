#!/usr/bin/env bash
# enable-formal.sh: Upgrade a Discovery project to Formal profile
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║         ENABLING FORMAL PROFILE                   ║"
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

# Check current profile via settings library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CURRENT_PROFILE="unknown"
if [[ -f "$SCRIPT_DIR/../lib/settings.sh" ]]; then
  source "$SCRIPT_DIR/../lib/settings.sh"
  CURRENT_PROFILE="$(get_setting "profile" "discovery")"
else
  # Fallback for pre-settings framework
  CURRENT_PROFILE=$(
    grep -iE '^[[:space:]]*-[[:space:]]*[Pp]rofile:' STACK.md 2>/dev/null \
      | head -1 \
      | sed -E 's/.*[Pp]rofile:[[:space:]]*([^[:space:]]+).*/\1/' \
      || echo "unknown"
  )
fi

if [[ "$CURRENT_PROFILE" == "formal" ]]; then
  echo -e "${YELLOW}⚠ Formal profile is already enabled!${NC}"
  echo ""
  echo "Current profile: formal"
  exit 0
fi

echo -e "${BLUE}Current profile: $CURRENT_PROFILE${NC}"
echo ""

# Ensure Core artifacts exist (some projects may have been initialized before Core profile was defined)
PRODUCT_EXISTS="no"

if [[ ! -f "CONTEXT_PACK.md" && -f ".agentic/init/CONTEXT_PACK.template.md" ]]; then
  cp ".agentic/init/CONTEXT_PACK.template.md" "CONTEXT_PACK.md"
  echo -e "${GREEN}✓ Created CONTEXT_PACK.md (Core)${NC}"
fi

if [[ ! -f "OVERVIEW.md" && -f ".agentic/init/PRODUCT.template.md" ]]; then
  cp ".agentic/init/PRODUCT.template.md" "OVERVIEW.md"
  echo -e "${GREEN}✓ Created OVERVIEW.md (Discovery)${NC}"
fi

if [[ ! -f ".agentic-journal/JOURNAL.md" ]] && [[ ! -f "JOURNAL.md" ]] && [[ -f ".agentic/spec/JOURNAL.template.md" ]]; then
  mkdir -p ".agentic-journal"
  cp ".agentic/spec/JOURNAL.template.md" ".agentic-journal/JOURNAL.md"
  echo -e "${GREEN}✓ Created .agentic-journal/JOURNAL.md (Discovery)${NC}"
fi

if [[ ! -f "HUMAN_NEEDED.md" && -f ".agentic/spec/HUMAN_NEEDED.template.md" ]]; then
  cp ".agentic/spec/HUMAN_NEEDED.template.md" "HUMAN_NEEDED.md"
  echo -e "${GREEN}✓ Created HUMAN_NEEDED.md (Discovery)${NC}"
fi

echo "What changes:"
echo "  ✓ spec/ directory with templates (PRD, TECH_SPEC, FEATURES, NFR)"
echo "  ✓ STATUS.md (project status and roadmap)"
echo "  ✓ Update STACK.md profile to 'formal'"
echo ""
echo "Note: CONTEXT_PACK.md, OVERVIEW.md, and HUMAN_NEEDED.md are already part of Core."
echo ""

# Check if OVERVIEW.md exists and has content
if [[ -f "OVERVIEW.md" ]]; then
  PRODUCT_LINE_COUNT=$(wc -l < OVERVIEW.md | tr -d ' ')
  if [[ "$PRODUCT_LINE_COUNT" -gt 10 ]]; then
    PRODUCT_EXISTS="yes"
    echo -e "${BLUE}📝 Detected OVERVIEW.md with content.${NC}"
    echo "After enabling Formal profile, you can ask your agent to:"
    echo "  - Seed spec/FEATURES.md from OVERVIEW.md capabilities"
    echo "  - Seed spec/PRD.md from OVERVIEW.md vision"
    echo ""
  fi
fi

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

# Update profile via ag set (creates ## Settings section if needed)
bash "$SCRIPT_DIR/ag.sh" set profile formal 2>/dev/null || {
  # Fallback: direct STACK.md edit
  if grep -qE '^[[:space:]]*-[[:space:]]*[Pp]rofile:' STACK.md; then
    sed -i.bak -E "s/^([[:space:]]*-[[:space:]]*[Pp]rofile:[[:space:]]*).*/\\1formal/" STACK.md
    rm STACK.md.bak 2>/dev/null || true
  fi
}
echo -e "${GREEN}✓ Updated STACK.md (profile: formal)${NC}"

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                    COMPLETE                                    ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo -e "${GREEN}Formal profile enabled!${NC}"
echo ""
echo "Next steps:"
echo "  1. Review the new spec templates in spec/"
echo "  2. Fill in STATUS.md with your current project state"
echo "  3. Update CONTEXT_PACK.md with your architecture"
if [[ "$PRODUCT_EXISTS" == "yes" ]]; then
  echo "  4. Tell your agent:"
  echo "     \"I've enabled the Formal profile. Please convert OVERVIEW.md into formal specs:"
  echo "      - Seed spec/FEATURES.md from OVERVIEW.md capabilities (with F-#### IDs)"
  echo "      - Seed spec/PRD.md from OVERVIEW.md vision and scope\""
else
  echo "  4. Tell your agent:"
  echo "     \"I've enabled the Formal profile. Please review"
  echo "      spec/FEATURES.md and help me document our existing features.\""
fi
echo ""
echo "New files:"
echo "  - spec/PRD.md          (Product requirements)"
echo "  - spec/TECH_SPEC.md    (Technical specification)"
echo "  - spec/FEATURES.md     (Feature tracking with IDs)"
echo "  - spec/NFR.md          (Non-functional requirements)"
echo "  - STATUS.md            (Project status & roadmap)"
echo ""
echo "Already part of Core (no changes):"
echo "  - CONTEXT_PACK.md                (Architecture overview)"
echo "  - HUMAN_NEEDED.md                (Escalation protocol)"
echo "  - .agentic-journal/JOURNAL.md    (Session continuity)"
echo ""

