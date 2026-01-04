#!/usr/bin/env bash
# upgrade.sh: Upgrades the Agentic Framework in an existing project
# Usage: bash path/to/new-framework/.agentic/tools/upgrade.sh /path/to/your-project
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
NEW_FRAMEWORK_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
BACKUP_DIR="agentic-backup-$(date +%Y%m%d-%H%M%S)"
DRY_RUN="${DRY_RUN:-no}"

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║          AGENTIC AI FRAMEWORK UPGRADE TOOL                     ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Read new framework version
FRAMEWORK_VERSION=""
if [[ -f "$NEW_FRAMEWORK_DIR/VERSION" ]]; then
  FRAMEWORK_VERSION=$(cat "$NEW_FRAMEWORK_DIR/VERSION" | tr -d '[:space:]')
  echo "New framework version: $FRAMEWORK_VERSION"
  echo ""
fi

# Step 1: Pre-flight checks
echo -e "${BLUE}[1/7] Pre-flight checks${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Verify target project directory
if [[ ! -d "$TARGET_PROJECT_DIR" ]]; then
  echo -e "${RED}✗ Error: Target directory not found: $TARGET_PROJECT_DIR${NC}"
  exit 1
fi

cd "$TARGET_PROJECT_DIR"
TARGET_PROJECT_DIR="$(pwd)"  # Get absolute path

echo "  Target project: $TARGET_PROJECT_DIR"
echo "  New framework: $NEW_FRAMEWORK_DIR"
echo ""

if [[ ! -d ".agentic" ]]; then
  echo -e "${RED}✗ Error: No '.agentic/' folder found in target project${NC}"
  echo "  Target: $TARGET_PROJECT_DIR/.agentic"
  echo "  Is this an initialized agentic project?"
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

if [[ ! -d "$NEW_FRAMEWORK_DIR/.agentic" ]]; then
  echo -e "${RED}✗ Error: New framework structure invalid${NC}"
  echo "  Expected: $NEW_FRAMEWORK_DIR/.agentic/"
  echo "  This script must be run FROM the new framework directory"
  echo "  Usage: bash /path/to/new-framework/.agentic/tools/upgrade.sh /path/to/your-project"
  exit 1
fi

echo -e "${GREEN}✓ Pre-flight checks passed${NC}"
echo ""

# Step 2: Detect versions
echo -e "${BLUE}[2/7] Detecting versions${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Current version (from target project)
CURRENT_VERSION=""
if [[ -f "$TARGET_PROJECT_DIR/STACK.md" ]]; then
  CURRENT_VERSION=$(grep -E "^\s*-?\s*Version:" "$TARGET_PROJECT_DIR/STACK.md" | head -1 | sed -E 's/.*Version:\s*([0-9.]+).*/\1/' || echo "unknown")
fi

# New version (from this framework)
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
  echo "  [DRY RUN] Would create backup: $TARGET_PROJECT_DIR/$BACKUP_DIR"
else
  cp -r "$TARGET_PROJECT_DIR/.agentic" "$TARGET_PROJECT_DIR/$BACKUP_DIR"
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
  echo "    - .agentic/$dir/"
done

echo "  Files to replace:"
for file in "${FILES_TO_REPLACE[@]}"; do
  if [[ -f "$NEW_FRAMEWORK_DIR/.agentic/$file" ]]; then
    echo "    - .agentic/$file"
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
    if [[ -d "$TARGET_PROJECT_DIR/.agentic/$dir" ]]; then
      rm -rf "$TARGET_PROJECT_DIR/.agentic/$dir"
      echo "  Removed: .agentic/$dir/"
    fi
  done

  # Copy new directories
  for dir in "${DIRS_TO_REPLACE[@]}"; do
    if [[ -d "$NEW_FRAMEWORK_DIR/.agentic/$dir" ]]; then
      cp -r "$NEW_FRAMEWORK_DIR/.agentic/$dir" "$TARGET_PROJECT_DIR/.agentic/"
      echo -e "${GREEN}  ✓ Updated: .agentic/$dir/${NC}"
    fi
  done

  # Replace files
  for file in "${FILES_TO_REPLACE[@]}"; do
    if [[ -f "$NEW_FRAMEWORK_DIR/.agentic/$file" ]]; then
      cp "$NEW_FRAMEWORK_DIR/.agentic/$file" "$TARGET_PROJECT_DIR/.agentic/"
      echo -e "${GREEN}  ✓ Updated: .agentic/$file${NC}"
    fi
  done
fi

echo ""

# Step 6: Update version in STACK.md
echo -e "${BLUE}[6/7] Updating STACK.md${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ -f "$TARGET_PROJECT_DIR/STACK.md" && "$NEW_VERSION" != "unknown" ]]; then
  if [[ "$DRY_RUN" == "yes" ]]; then
    echo "  [DRY RUN] Would update version in STACK.md to $NEW_VERSION"
  else
    # Update version field (handles both "- Version:" and "Version:" formats)
    if grep -qE "^\s*-?\s*Version:" "$TARGET_PROJECT_DIR/STACK.md"; then
      sed -i.bak -E "s/(^\s*-?\s*Version:\s*)[0-9.]+.*/\1$NEW_VERSION  <!-- Updated: $(date +%Y-%m-%d) -->/" "$TARGET_PROJECT_DIR/STACK.md"
      rm "$TARGET_PROJECT_DIR/STACK.md.bak" 2>/dev/null || true
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
  if [[ -x "$TARGET_PROJECT_DIR/.agentic/tools/doctor.sh" ]]; then
    echo "  Running doctor.sh..."
    if bash "$TARGET_PROJECT_DIR/.agentic/tools/doctor.sh" > /dev/null 2>&1; then
      echo -e "${GREEN}  ✓ Structure verification passed${NC}"
    else
      echo -e "${YELLOW}  ⚠ Some checks failed (see below)${NC}"
      bash "$TARGET_PROJECT_DIR/.agentic/tools/doctor.sh" 2>&1 | grep -E "^(Missing|NEW)" || true
    fi
  fi

  # Check for spec validation
  if [[ -f "$TARGET_PROJECT_DIR/.agentic/tools/validate_specs.py" ]] && command -v python3 >/dev/null 2>&1; then
    echo "  Running spec validation..."
    VALIDATION_OUTPUT=$(python3 "$TARGET_PROJECT_DIR/.agentic/tools/validate_specs.py" 2>&1)
    VALIDATION_EXIT=$?
    
    if [[ $VALIDATION_EXIT -eq 0 ]]; then
      echo -e "${GREEN}  ✓ Spec validation passed${NC}"
    elif echo "$VALIDATION_OUTPUT" | grep -q "ModuleNotFoundError\|No module named"; then
      echo -e "${BLUE}  ℹ Spec validation skipped (Python dependencies not installed)${NC}"
      echo "    Optional: pip install pyyaml python-frontmatter jsonschema"
    else
      echo -e "${YELLOW}  ⚠ Spec validation found issues:${NC}"
      echo "$VALIDATION_OUTPUT" | head -10
      echo "    Run manually: python3 .agentic/tools/validate_specs.py"
    fi
  fi
fi

echo ""

# Step 7: Update STACK.md with new version
echo -e "${BLUE}[7/7] Updating STACK.md with new framework version${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ -n "$FRAMEWORK_VERSION" && -f "$TARGET_PROJECT_DIR/STACK.md" ]]; then
  if grep -q "^- Version:" "$TARGET_PROJECT_DIR/STACK.md"; then
    # macOS and Linux compatible sed
    if [[ "$OSTYPE" == "darwin"* ]]; then
      sed -i '' "s/^- Version: .*$/- Version: $FRAMEWORK_VERSION/" "$TARGET_PROJECT_DIR/STACK.md"
    else
      sed -i "s/^- Version: .*$/- Version: $FRAMEWORK_VERSION/" "$TARGET_PROJECT_DIR/STACK.md"
    fi
    echo -e "  ${GREEN}✓${NC} Updated STACK.md version to $FRAMEWORK_VERSION"
  else
    echo -e "  ${YELLOW}⚠ Version field not found in STACK.md${NC}"
  fi
else
  echo -e "  ${YELLOW}⚠ Could not update version (STACK.md not found or version unknown)${NC}"
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
  if [[ -n "$FRAMEWORK_VERSION" ]]; then
    echo -e "${GREEN}✓ Framework upgraded to version $FRAMEWORK_VERSION${NC}"
  else
    echo -e "${GREEN}✓ Framework upgraded${NC}"
  fi
  echo ""
  echo "Project: $TARGET_PROJECT_DIR"
  echo ""
  echo "Next steps:"
  echo "  1. Review CHANGELOG: https://github.com/tomgun/agentic-framework/blob/v$FRAMEWORK_VERSION/CHANGELOG.md"
  echo "  2. Test your workflow: bash .agentic/tools/dashboard.sh"
  echo "  3. Run quality checks: bash quality_checks.sh --pre-commit (if configured)"
  echo "  4. Tell your agent: 'The framework was upgraded to v$FRAMEWORK_VERSION. Review any new features or changes.'"
  echo ""
  echo "If issues occur:"
  echo "  Rollback: rm -rf .agentic && mv $BACKUP_DIR .agentic"
  echo "  Docs: See UPGRADING.md for troubleshooting"
  echo ""
  echo "Backup location: $TARGET_PROJECT_DIR/$BACKUP_DIR"
fi

echo ""
