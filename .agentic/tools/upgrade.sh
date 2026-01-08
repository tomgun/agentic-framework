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
  "quality_profiles"
  "agents"
  "tools"
  "init"
  "spec"
  "support"
  "checklists"
  "claude-hooks"
  "hooks"
  "prompts"
  "schemas"
  "token_efficiency"
)

FILES_TO_REPLACE=(
  "README.md"
  "START_HERE.md"
  "FRAMEWORK_MAP.md"
  "MANUAL_OPERATIONS.md"
  "DIRECT_EDITING.md"
  "DEVELOPER_GUIDE.md"
  "FRAMEWORK_DEVELOPMENT.md"
  "PRINCIPLES.md"
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

  # Run spec format upgrade if available
  if [[ -f "$TARGET_PROJECT_DIR/.agentic/tools/upgrade_spec_format.py" ]] && command -v python3 >/dev/null 2>&1; then
    echo "  Running spec format upgrade..."
    UPGRADE_OUTPUT=$(python3 "$TARGET_PROJECT_DIR/.agentic/tools/upgrade_spec_format.py" 2>&1)
    UPGRADE_EXIT=$?
    
    if [[ $UPGRADE_EXIT -eq 0 ]]; then
      if echo "$UPGRADE_OUTPUT" | grep -q "upgraded\|Updated\|Added"; then
        echo -e "${GREEN}  ✓ Spec formats upgraded${NC}"
        echo "$UPGRADE_OUTPUT" | grep -E "✅|upgraded|Updated" | head -5
      else
        echo -e "${GREEN}  ✓ Spec formats already current${NC}"
      fi
    else
      echo -e "${YELLOW}  ⚠ Spec format upgrade had issues (may need manual review)${NC}"
    fi
  fi
fi

echo ""

# Step 7: Update STACK.md with new version (robust pattern matching)
echo -e "${BLUE}[7/7] Updating STACK.md with new framework version${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

STACK_UPDATED="no"
if [[ -n "$FRAMEWORK_VERSION" && -f "$TARGET_PROJECT_DIR/STACK.md" ]]; then
  # Try multiple patterns to catch all STACK.md formats
  # Pattern 1: "- Version: X.Y.Z" (standard format)
  # Pattern 2: "Version: X.Y.Z" (no dash)
  # Pattern 3: "  - Version: X.Y.Z" (indented)
  
  if grep -qE "^[[:space:]]*-?[[:space:]]*Version:" "$TARGET_PROJECT_DIR/STACK.md"; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
      # macOS sed
      sed -i '' -E "s/^([[:space:]]*-?[[:space:]]*Version:[[:space:]]*)[0-9]+\.[0-9]+\.[0-9]+.*/\1$FRAMEWORK_VERSION/" "$TARGET_PROJECT_DIR/STACK.md"
    else
      # Linux sed
      sed -i -E "s/^([[:space:]]*-?[[:space:]]*Version:[[:space:]]*)[0-9]+\.[0-9]+\.[0-9]+.*/\1$FRAMEWORK_VERSION/" "$TARGET_PROJECT_DIR/STACK.md"
    fi
    STACK_UPDATED="yes"
    echo -e "  ${GREEN}✓${NC} Updated STACK.md version to $FRAMEWORK_VERSION"
  else
    echo -e "  ${YELLOW}⚠ Version field not found in STACK.md${NC}"
    echo "  Add manually: - Version: $FRAMEWORK_VERSION"
  fi
  
  # Verify the update worked
  if [[ "$STACK_UPDATED" == "yes" ]]; then
    UPDATED_VERSION=$(grep -oE "Version:[[:space:]]*[0-9]+\.[0-9]+\.[0-9]+" "$TARGET_PROJECT_DIR/STACK.md" | head -1 | grep -oE "[0-9]+\.[0-9]+\.[0-9]+")
    if [[ "$UPDATED_VERSION" != "$FRAMEWORK_VERSION" ]]; then
      echo -e "  ${RED}✗ STACK.md version mismatch: expected $FRAMEWORK_VERSION, got $UPDATED_VERSION${NC}"
      echo "  Please update manually!"
      STACK_UPDATED="no"
    fi
  fi
else
  echo -e "  ${YELLOW}⚠ Could not update version (STACK.md not found or version unknown)${NC}"
fi

# Also update .agentic/VERSION file
if [[ -n "$FRAMEWORK_VERSION" ]]; then
  echo "$FRAMEWORK_VERSION" > "$TARGET_PROJECT_DIR/.agentic/VERSION"
  echo -e "  ${GREEN}✓${NC} Updated .agentic/VERSION to $FRAMEWORK_VERSION"
fi

# Create upgrade marker for agent to pick up at next session
UPGRADE_MARKER="$TARGET_PROJECT_DIR/.agentic/.upgrade_pending"
cat > "$UPGRADE_MARKER" << EOF
# 🚨 FRAMEWORK UPGRADE PENDING - READ THIS FIRST!

**DO NOT search through .agentic/ randomly. This file tells you everything.**

## Upgrade Summary

- **From**: ${CURRENT_VERSION:-unknown}
- **To**: $FRAMEWORK_VERSION
- **Date**: $(date +%Y-%m-%d)
- **STACK.md updated**: ${STACK_UPDATED}

## Your TODO List (complete all, then delete this file):

1. ✅ Read this file (you're doing it now)
2. [ ] If "STACK.md updated: no" above → manually update: \`- Version: $FRAMEWORK_VERSION\`
3. [ ] Check spec files for format markers (add if missing):
       - spec/FEATURES.md → \`<!-- format: features-v0.2.0 -->\`
       - spec/NFR.md → \`<!-- format: nfr-v0.1.0 -->\`
       - spec/ISSUES.md → \`<!-- format: issues-v0.1.0 -->\`
4. [ ] Read .agentic/START_HERE.md (5 min) for new workflows
5. [ ] Validate specs: \`python3 .agentic/tools/validate_specs.py\`
6. [ ] Review CHANGELOG: $FRAMEWORK_VERSION changes
7. [ ] Delete this file: \`rm .agentic/.upgrade_pending\`

## Changelog

See: https://github.com/tomgun/agentic-framework/blob/v$FRAMEWORK_VERSION/CHANGELOG.md

## Don't Waste Tokens!

- This file IS the upgrade notification
- Don't search .agentic/ for upgrade info - it's all here
- After completing TODO, delete this file
EOF
echo -e "  ${GREEN}✓${NC} Created .upgrade_pending marker for agent"

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
  echo ""
  echo -e "${YELLOW}If agent is already running and doesn't notice the upgrade:${NC}"
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo -e "${GREEN}COPY THIS PROMPT TO YOUR AGENT:${NC}"
  echo ""
  echo "  Read .agentic/.upgrade_pending and follow the TODO list in it."
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "The file .agentic/.upgrade_pending contains everything the agent needs:"
  echo "  - From/to versions"
  echo "  - Whether STACK.md was updated"
  echo "  - Complete TODO checklist"
  echo "  - Changelog link"
  echo ""
  echo "If issues occur:"
  echo "  Rollback: rm -rf .agentic && mv $BACKUP_DIR .agentic"
  echo "  Docs: See UPGRADING.md for troubleshooting"
  echo ""
  echo "Backup location: $TARGET_PROJECT_DIR/$BACKUP_DIR"
fi

echo ""
