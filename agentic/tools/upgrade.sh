#!/usr/bin/env bash
# upgrade.sh: Upgrades the Agentic Framework in an existing project
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NEW_FRAMEWORK_DIR="${1:-agentic-framework}"
BACKUP_DIR="agentic-backup-$(date +%Y%m%d-%H%M%S)"
DRY_RUN="${DRY_RUN:-no}"

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║            AGENTIC FRAMEWORK UPGRADE TOOL                      ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Step 1: Pre-flight checks
echo -e "${BLUE}[1/7] Pre-flight checks${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ ! -d "agentic" ]]; then
  echo -e "${RED}✗ Error: No 'agentic/' folder found in current directory${NC}"
  echo "  Are you in your project root?"
  exit 1
fi

if [[ ! -f "STACK.md" ]]; then
  echo -e "${YELLOW}⚠ Warning: No STACK.md found. This might not be an initialized project.${NC}"
  read -p "Continue anyway? (y/n): " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi
fi

if [[ ! -d "$NEW_FRAMEWORK_DIR/agentic" ]]; then
  echo -e "${RED}✗ Error: New framework not found at '$NEW_FRAMEWORK_DIR/agentic'${NC}"
  echo "  Usage: bash upgrade.sh [path-to-extracted-framework]"
  echo "  Example: bash upgrade.sh agentic-framework-0.2.0"
  exit 1
fi

echo -e "${GREEN}✓ Pre-flight checks passed${NC}"
echo ""

# Step 2: Detect versions
echo -e "${BLUE}[2/7] Detecting versions${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Current version
CURRENT_VERSION=""
if [[ -f "STACK.md" ]]; then
  CURRENT_VERSION=$(grep -E "^\s*-?\s*Version:" STACK.md | head -1 | sed -E 's/.*Version:\s*([0-9.]+).*/\1/' || echo "unknown")
fi

# New version
NEW_VERSION=""
if [[ -f "$NEW_FRAMEWORK_DIR/VERSION" ]]; then
  NEW_VERSION=$(cat "$NEW_FRAMEWORK_DIR/VERSION" | tr -d '[:space:]')
else
  echo -e "${YELLOW}⚠ Warning: No VERSION file found in new framework${NC}"
  NEW_VERSION="unknown"
fi

echo "  Current version: ${CURRENT_VERSION:-not found}"
echo "  New version: $NEW_VERSION"

if [[ "$CURRENT_VERSION" == "$NEW_VERSION" ]]; then
  echo -e "${YELLOW}⚠ Warning: Same version detected. Proceeding anyway.${NC}"
fi

echo ""

# Step 3: Create backup
echo -e "${BLUE}[3/7] Creating backup${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ "$DRY_RUN" == "yes" ]]; then
  echo "  [DRY RUN] Would create backup: $BACKUP_DIR"
else
  cp -r agentic "$BACKUP_DIR"
  echo -e "${GREEN}✓ Backup created: $BACKUP_DIR${NC}"
fi

echo ""

# Step 4: Identify files to replace
echo -e "${BLUE}[4/7] Planning replacement${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

DIRS_TO_REPLACE=(
  "workflows"
  "quality"
  "agents"
  "tools"
  "init"
  "spec"
  "support"
)

FILES_TO_REPLACE=(
  "README.md"
  "START_HERE.md"
  "FRAMEWORK_MAP.md"
  "MANUAL_OPERATIONS.md"
  "DIRECT_EDITING.md"
)

echo "  Directories to replace:"
for dir in "${DIRS_TO_REPLACE[@]}"; do
  echo "    - agentic/$dir/"
done

echo "  Files to replace:"
for file in "${FILES_TO_REPLACE[@]}"; do
  if [[ -f "$NEW_FRAMEWORK_DIR/agentic/$file" ]]; then
    echo "    - agentic/$file"
  fi
done

echo ""

# Step 5: Replace framework files
echo -e "${BLUE}[5/7] Replacing framework files${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ "$DRY_RUN" == "yes" ]]; then
  echo "  [DRY RUN] Would replace framework files"
else
  # Remove old directories
  for dir in "${DIRS_TO_REPLACE[@]}"; do
    if [[ -d "agentic/$dir" ]]; then
      rm -rf "agentic/$dir"
      echo "  Removed: agentic/$dir/"
    fi
  done

  # Copy new directories
  for dir in "${DIRS_TO_REPLACE[@]}"; do
    if [[ -d "$NEW_FRAMEWORK_DIR/agentic/$dir" ]]; then
      cp -r "$NEW_FRAMEWORK_DIR/agentic/$dir" "agentic/"
      echo -e "${GREEN}  ✓ Updated: agentic/$dir/${NC}"
    fi
  done

  # Replace files
  for file in "${FILES_TO_REPLACE[@]}"; do
    if [[ -f "$NEW_FRAMEWORK_DIR/agentic/$file" ]]; then
      cp "$NEW_FRAMEWORK_DIR/agentic/$file" "agentic/"
      echo -e "${GREEN}  ✓ Updated: agentic/$file${NC}"
    fi
  done
fi

echo ""

# Step 6: Update version in STACK.md
echo -e "${BLUE}[6/7] Updating STACK.md${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ -f "STACK.md" && "$NEW_VERSION" != "unknown" ]]; then
  if [[ "$DRY_RUN" == "yes" ]]; then
    echo "  [DRY RUN] Would update version in STACK.md to $NEW_VERSION"
  else
    # Update version field (handles both "- Version:" and "Version:" formats)
    if grep -qE "^\s*-?\s*Version:" STACK.md; then
      sed -i.bak -E "s/(^\s*-?\s*Version:\s*)[0-9.]+.*/\1$NEW_VERSION  <!-- Updated: $(date +%Y-%m-%d) -->/" STACK.md
      rm STACK.md.bak
      echo -e "${GREEN}✓ Updated version in STACK.md to $NEW_VERSION${NC}"
    else
      echo -e "${YELLOW}⚠ Warning: Could not find 'Version:' field in STACK.md${NC}"
      echo "  Please update manually to: Version: $NEW_VERSION"
    fi
  fi
else
  echo -e "${YELLOW}⚠ Skipping STACK.md update${NC}"
fi

echo ""

# Step 7: Verification
echo -e "${BLUE}[7/7] Running verification${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ "$DRY_RUN" == "yes" ]]; then
  echo "  [DRY RUN] Would run verification checks"
else
  # Run doctor.sh if available
  if [[ -x "agentic/tools/doctor.sh" ]]; then
    echo "  Running doctor.sh..."
    if bash agentic/tools/doctor.sh > /dev/null 2>&1; then
      echo -e "${GREEN}  ✓ Structure verification passed${NC}"
    else
      echo -e "${YELLOW}  ⚠ Some checks failed (see below)${NC}"
      bash agentic/tools/doctor.sh 2>&1 | grep -E "^(Missing|NEW)"
    fi
  fi

  # Check for spec validation
  if [[ -f "agentic/tools/validate_specs.py" ]] && command -v python3 >/dev/null 2>&1; then
    echo "  Running spec validation..."
    if python3 agentic/tools/validate_specs.py > /dev/null 2>&1; then
      echo -e "${GREEN}  ✓ Spec validation passed${NC}"
    else
      echo -e "${YELLOW}  ⚠ Spec validation failed (may need manual fixes)${NC}"
    fi
  fi
fi

echo ""

# Summary
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                    UPGRADE COMPLETE                            ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

if [[ "$DRY_RUN" == "yes" ]]; then
  echo -e "${YELLOW}This was a DRY RUN. No changes were made.${NC}"
  echo "To perform the actual upgrade, run without DRY_RUN=yes"
else
  echo -e "${GREEN}✓ Framework upgraded from $CURRENT_VERSION to $NEW_VERSION${NC}"
  echo ""
  echo "Next steps:"
  echo "  1. Review CHANGELOG: https://github.com/YOUR_USERNAME/agentic-framework/blob/v$NEW_VERSION/CHANGELOG.md"
  echo "  2. Test your workflow: bash agentic/tools/dashboard.sh"
  echo "  3. Run quality checks: bash quality_checks.sh --pre-commit (if configured)"
  echo "  4. Tell your agent: 'The framework was upgraded to v$NEW_VERSION. Review any new features or changes.'"
  echo ""
  echo "If issues occur:"
  echo "  Rollback: rm -rf agentic && mv $BACKUP_DIR agentic"
  echo "  Docs: See UPGRADING.md for troubleshooting"
  echo ""
  echo "Backup location: $BACKUP_DIR"
fi

echo ""

