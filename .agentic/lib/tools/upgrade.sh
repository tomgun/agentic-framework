#!/usr/bin/env bash
# upgrade.sh: Upgrades the Agentic Framework in an existing project
# Usage: bash path/to/new-framework/.agentic/lib/tools/upgrade.sh /path/to/your-project
# Debug: DEBUG=yes bash upgrade.sh /path/to/project
set -euo pipefail

# Debug mode
DEBUG="${DEBUG:-no}"
debug() {
  if [[ "$DEBUG" == "yes" ]]; then
    echo -e "\033[0;35m[DEBUG] $1\033[0m"
  fi
}

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
debug "Looking for VERSION at: $NEW_FRAMEWORK_DIR/VERSION"
if [[ -f "$NEW_FRAMEWORK_DIR/VERSION" ]]; then
  FRAMEWORK_VERSION=$(cat "$NEW_FRAMEWORK_DIR/VERSION" | tr -d '[:space:]')
  echo "New framework version: $FRAMEWORK_VERSION"
  echo ""
else
  echo -e "${YELLOW}⚠ Warning: VERSION file not found at $NEW_FRAMEWORK_DIR/VERSION${NC}"
  echo "  The upgrade will continue but version tracking may not work correctly."
  echo ""
fi
debug "FRAMEWORK_VERSION=$FRAMEWORK_VERSION"

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
  echo "  Usage: bash /path/to/new-framework/.agentic/lib/tools/upgrade.sh /path/to/your-project"
  exit 1
fi

echo -e "${GREEN}✓ Pre-flight checks passed${NC}"
echo ""

# Step 2: Detect versions
echo -e "${BLUE}[2/7] Detecting versions${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Current version (from target project - prefer .agentic/VERSION, fallback to STACK.md)
CURRENT_VERSION=""
if [[ -f "$TARGET_PROJECT_DIR/.agentic/VERSION" ]]; then
  CURRENT_VERSION=$(cat "$TARGET_PROJECT_DIR/.agentic/VERSION" | tr -d '[:space:]')
elif [[ -f "$TARGET_PROJECT_DIR/STACK.md" ]]; then
  # Extract version number from line like "- Version: 0.11.2  <!-- comment -->"
  CURRENT_VERSION=$(grep -E "^\s*-?\s*Version:" "$TARGET_PROJECT_DIR/STACK.md" | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
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
  "lib"
  "presets"
)

FILES_TO_REPLACE=(
  "README.md"
  "START_HERE.md"
  "FRAMEWORK_MAP.md"
  "MANUAL_OPERATIONS.md"
  "DIRECT_EDITING.md"
  "DEVELOPER_GUIDE.md"
  "PRINCIPLES.md"
)

echo "  Directories to replace:"
for dir in "${DIRS_TO_REPLACE[@]}"; do
  echo "    - .agentic/$dir/"
done

echo "  Preserved (not touched):"
echo "    - .agentic/local/  (user extensions)"
echo "    - .agentic/journal/ (session history)"
echo "    - .agentic/session/  (session state)"

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

  # Restore state files from backup (these are project-specific, not framework)
  echo ""
  echo "  Restoring project state files from backup..."
  STATE_FILES=(
    "WIP.md"              # Work in progress tracking (legacy, migrated to AGENTS.json)
    "AGENTS_ACTIVE.md"    # Multi-agent coordination (legacy, replaced by AGENTS.json)
    "AGENTS.json"         # Agent/WIP registry (F-0194)
    ".verification-state" # Verification state
  )
  for state_file in "${STATE_FILES[@]}"; do
    if [[ -f "$TARGET_PROJECT_DIR/$BACKUP_DIR/$state_file" ]]; then
      cp "$TARGET_PROJECT_DIR/$BACKUP_DIR/$state_file" "$TARGET_PROJECT_DIR/.agentic/session/"
      echo -e "${GREEN}  ✓ Restored: .agentic/session/$state_file${NC}"
    fi
  done

  # Step 4b: Migrate WIP.md → AGENTS.json (F-0194)
  if [[ -f "$TARGET_PROJECT_DIR/.agentic/session/WIP.md" ]]; then
    echo ""
    echo "  Migrating WIP.md → AGENTS.json..."
    if command -v python3 >/dev/null 2>&1; then
      local _script_dir
      _script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
      python3 "$_script_dir/agents_helpers.py" --project-root "$TARGET_PROJECT_DIR" \
          migrate-wip "$TARGET_PROJECT_DIR/.agentic/session/WIP.md" 2>/dev/null && \
          echo -e "${GREEN}  ✓ WIP.md migrated to AGENTS.json${NC}" || \
          echo -e "${YELLOW}  WIP.md migration skipped (parse error)${NC}"
    else
      echo -e "${YELLOW}  WIP.md migration skipped (python3 not available)${NC}"
    fi
  fi
  # Clean up old AGENTS_ACTIVE.md (replaced by AGENTS.json)
  if [[ -f "$TARGET_PROJECT_DIR/.agentic/session/AGENTS_ACTIVE.md" ]]; then
    echo "  Removing deprecated AGENTS_ACTIVE.md..."
    rm "$TARGET_PROJECT_DIR/.agentic/session/AGENTS_ACTIVE.md"
    echo -e "${GREEN}  ✓ Removed AGENTS_ACTIVE.md${NC}"
  fi
fi

echo ""

# Step 5a: Sync local customization files with updated templates
echo -e "${BLUE}[5a/11] Syncing local customizations${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ "$DRY_RUN" == "yes" ]]; then
  echo "  [DRY RUN] Would sync local customization files"
else
  LOCAL_DIR="$TARGET_PROJECT_DIR/.agentic/local"

  # Helper: check if file still looks like an unedited template
  _file_looks_like_template() {
    local file="$1"
    [[ ! -f "$file" ]] && return 1
    local first_lines
    first_lines=$(head -3 "$file" | tr '[:upper:]' '[:lower:]')
    if echo "$first_lines" | grep -qi "(template)"; then
      return 0
    fi
    local total_lines filled_lines
    total_lines=$(wc -l < "$file" | tr -d ' ')
    filled_lines=$(grep -cvE '^\s*$|^\s*<!--.*-->$|^#' "$file" 2>/dev/null || echo "0")
    if [[ "$total_lines" -gt 5 && "$filled_lines" -lt 3 ]]; then
      return 0
    fi
    return 1
  }

  # Template-derived files to sync: local_path|template_path
  declare -a LOCAL_SYNC_MAP=(
    "conventions.md|lib/init/conventions-local.template.md"
    "workflow-directions.md|lib/init/workflow-directions.template.md"
    "extensions/README.md|lib/init/extensions-readme.md"
  )

  SYNC_UPDATED=0
  SYNC_KEPT=0
  SYNC_NEW_FILES=()

  for entry in "${LOCAL_SYNC_MAP[@]}"; do
    local_rel="${entry%%|*}"
    template_rel="${entry##*|}"
    local_file="$LOCAL_DIR/$local_rel"
    new_template="$TARGET_PROJECT_DIR/.agentic/$template_rel"

    # Skip if new template doesn't exist
    [[ ! -f "$new_template" ]] && continue

    if [[ ! -f "$local_file" ]]; then
      # Local file missing — create from template
      mkdir -p "$(dirname "$local_file")"
      cp "$new_template" "$local_file"
      echo -e "  ${GREEN}✓${NC} Created $local_rel (from template)"
      SYNC_UPDATED=$((SYNC_UPDATED + 1))
    elif _file_looks_like_template "$local_file"; then
      # Unmodified template — safe to replace
      cp "$new_template" "$local_file"
      echo -e "  ${GREEN}✓${NC} Updated $local_rel (was unmodified template)"
      SYNC_UPDATED=$((SYNC_UPDATED + 1))
    else
      # Customized by user — don't touch, write .new for review
      if ! diff -q "$local_file" "$new_template" >/dev/null 2>&1; then
        cp "$new_template" "${local_file}.new"
        SYNC_NEW_FILES+=("$local_rel")
        SYNC_KEPT=$((SYNC_KEPT + 1))
      fi
    fi
  done

  # Ensure all expected extension subdirectories exist
  for subdir in skills gates hooks rules done-checks policies; do
    mkdir -p "$LOCAL_DIR/extensions/$subdir"
  done

  if [[ $SYNC_UPDATED -gt 0 ]]; then
    echo -e "  ${GREEN}✓${NC} Synced $SYNC_UPDATED local file(s)"
  fi
  if [[ $SYNC_KEPT -gt 0 ]]; then
    echo -e "  ${YELLOW}⚠${NC} $SYNC_KEPT customized file(s) preserved — review .new versions:"
    for f in "${SYNC_NEW_FILES[@]}"; do
      echo "    .agentic/local/${f}.new"
    done
  fi
  if [[ $SYNC_UPDATED -eq 0 && $SYNC_KEPT -eq 0 ]]; then
    echo -e "  ${GREEN}✓${NC} Local customizations up to date"
  fi
  echo -e "  ${GREEN}✓${NC} Extension subdirectories verified"
fi

echo ""

# Step 5b: Regenerate Claude Code artifacts (skills, hooks, subagents)
echo -e "${BLUE}[5b/8] Regenerating Claude Code artifacts${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ "$DRY_RUN" == "yes" ]]; then
  echo "  [DRY RUN] Would regenerate Claude artifacts"
elif [[ -d "$TARGET_PROJECT_DIR/.claude" ]] || [[ -f "$TARGET_PROJECT_DIR/CLAUDE.md" ]]; then
  # User has Claude set up — regenerate all Claude artifacts via setup_claude()
  # This handles: CLAUDE.md, hooks.json, skills, subagents
  if [[ -x "$TARGET_PROJECT_DIR/.agentic/lib/tools/setup-agent.sh" ]]; then
    bash "$TARGET_PROJECT_DIR/.agentic/lib/tools/setup-agent.sh" claude 2>/dev/null || true
  fi
else
  echo -e "  ${YELLOW}⚠${NC} No .claude/ directory — Claude not configured. Skipping."
  echo "  Run 'bash .agentic/tools/setup-agent.sh claude' to set up Claude Code."
fi

echo ""

# Step 5c: Regenerate instruction files from updated templates
echo -e "${BLUE}[5c/11] Regenerating instruction files${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ "$DRY_RUN" == "yes" ]]; then
  echo "  [DRY RUN] Would regenerate instruction files (CLAUDE.md, .cursorrules, copilot, codex)"
elif [[ -x "$TARGET_PROJECT_DIR/.agentic/lib/tools/setup-agent.sh" ]]; then
  bash "$TARGET_PROJECT_DIR/.agentic/lib/tools/setup-agent.sh" all 2>/dev/null || true
  echo -e "  ${GREEN}✓${NC} Instruction files regenerated (CLAUDE.md, .cursorrules, copilot, codex)"
else
  echo -e "  ${YELLOW}⚠ setup-agent.sh not found, skipping${NC}"
fi

echo ""

# Step 5d: v2 migration removed (v2 engine deleted in F-031 Phase 4)
echo ""

# Step 6: Migrate STATUS.md for Core profile
echo -e "${BLUE}[6/7] Checking STATUS.md migration${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Detect profile: try settings library first, fall back to STACK.md Profile: line
PROFILE="discovery"
source "$SCRIPT_DIR/../paths.sh" 2>/dev/null || true

if [[ -f "$TARGET_PROJECT_DIR/.agentic/lib/settings.sh" ]]; then
  source "$TARGET_PROJECT_DIR/.agentic/lib/settings.sh"
  PROFILE="$(get_setting "profile" "")"
fi
# If settings library couldn't determine profile, check legacy Profile: line in STACK.md
# (get_setting returns "discovery" as fallback even for old profile names like core+product)
if [[ -f "$TARGET_PROJECT_DIR/STACK.md" ]]; then
  PROFILE_LINE=$(grep -Ei "^[[:space:]]*-[[:space:]]*Profile:" "$TARGET_PROJECT_DIR/STACK.md" 2>/dev/null | head -1 || echo "")
  case "$PROFILE_LINE" in
    *core+product*|*core+pm*) PROFILE="formal" ;;
    *formal*) PROFILE="formal" ;;
  esac
fi
[[ -z "$PROFILE" ]] && PROFILE="discovery"

# Check if STATUS.md exists
if [[ ! -f "$TARGET_PROJECT_DIR/STATUS.md" ]]; then
  echo "  STATUS.md not found - creating (now required for all profiles)"

  if [[ -f "$NEW_FRAMEWORK_DIR/.agentic/lib/init/STATUS.template.md" ]]; then
    cp "$NEW_FRAMEWORK_DIR/.agentic/lib/init/STATUS.template.md" "$TARGET_PROJECT_DIR/STATUS.md"
    echo -e "  ${GREEN}✓${NC} Created STATUS.md from template"

    # Add to upgrade marker TODO
    STATUS_MD_MIGRATION="yes"
  else
    echo -e "  ${YELLOW}⚠${NC} Template not found - run: bash .agentic/lib/init/scaffold.sh"
  fi
else
  echo -e "  ${GREEN}✓${NC} STATUS.md already exists"
fi

# Cleanup: Remove deprecated status.json backend (removed in v0.25.0)
rm -f "$TARGET_PROJECT_DIR/.agentic/state/status.json" 2>/dev/null
rmdir "$TARGET_PROJECT_DIR/.agentic/state" 2>/dev/null || true

# Migrate legacy profile names (v0.26.0: core→discovery, core+product→formal)
if [[ "$DRY_RUN" != "yes" ]] && [[ -f "$TARGET_PROJECT_DIR/STACK.md" ]]; then
  if grep -qE "^[[:space:]]*-[[:space:]]*Profile:[[:space:]]*(core[+]product|core[+]pm)" "$TARGET_PROJECT_DIR/STACK.md"; then
    sed -i.bak -E 's/(Profile:[[:space:]]*)(core[+]product|core[+]pm)/\1formal/' "$TARGET_PROJECT_DIR/STACK.md"
    rm -f "$TARGET_PROJECT_DIR/STACK.md.bak" 2>/dev/null || true
    echo -e "  ${GREEN}✓${NC} Renamed profile core+product → formal in STACK.md"
  elif grep -qE "^[[:space:]]*-[[:space:]]*Profile:[[:space:]]*core[^a-z]" "$TARGET_PROJECT_DIR/STACK.md"; then
    sed -i.bak -E 's/(Profile:[[:space:]]*)core([^a-z]|$)/\1discovery\2/' "$TARGET_PROJECT_DIR/STACK.md"
    rm -f "$TARGET_PROJECT_DIR/STACK.md.bak" 2>/dev/null || true
    echo -e "  ${GREEN}✓${NC} Renamed profile core → discovery in STACK.md"
  fi
fi

# Migrate legacy JOURNAL.md location (v0.30.0: root → .agentic/journal/)
if [[ "$DRY_RUN" != "yes" ]]; then
  if [[ -f "$TARGET_PROJECT_DIR/JOURNAL.md" ]] && [[ ! -f "$TARGET_PROJECT_DIR/.agentic/journal/JOURNAL.md" ]]; then
    mkdir -p "$TARGET_PROJECT_DIR/.agentic-journal"
    mv "$TARGET_PROJECT_DIR/JOURNAL.md" "$TARGET_PROJECT_DIR/.agentic/journal/JOURNAL.md"
    echo -e "  ${GREEN}✓${NC} Migrated JOURNAL.md → .agentic/journal/JOURNAL.md"
  elif [[ -f "$TARGET_PROJECT_DIR/JOURNAL.md" ]] && [[ -f "$TARGET_PROJECT_DIR/.agentic/journal/JOURNAL.md" ]]; then
    # Both exist — merge legacy content into new if new is template-only
    if head -3 "$TARGET_PROJECT_DIR/.agentic/journal/JOURNAL.md" | grep -qi "template\|<!-- format"; then
      cat "$TARGET_PROJECT_DIR/JOURNAL.md" >> "$TARGET_PROJECT_DIR/.agentic/journal/JOURNAL.md"
      rm "$TARGET_PROJECT_DIR/JOURNAL.md"
      echo -e "  ${GREEN}✓${NC} Merged legacy JOURNAL.md into .agentic/journal/JOURNAL.md"
    else
      echo -e "  ${YELLOW}⚠${NC} Both JOURNAL.md and .agentic/journal/JOURNAL.md exist — review manually"
    fi
  fi
fi

echo ""

# Step 6b: Create missing state files from config
echo -e "${BLUE}[6b/11] Checking state files${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ "$DRY_RUN" == "yes" ]]; then
  echo "  [DRY RUN] Would create any missing state files"
else
  STATE_FILES_CONF="$TARGET_PROJECT_DIR/.agentic/lib/init/state-files.conf"
  if [[ -f "$STATE_FILES_CONF" ]]; then
    CREATED_COUNT=0
    while IFS=: read -r dst_rel src_rel file_profile; do
      [[ "$dst_rel" =~ ^#|^[[:space:]]*$ ]] && continue
      # Use is_formal_like if available, else inline check
      if type is_formal_like &>/dev/null; then
        [[ "$file_profile" == "formal" ]] && ! is_formal_like "$PROFILE" && continue
      else
        [[ "$file_profile" == "formal" && "$PROFILE" != "formal" && "$PROFILE" != "autonomous_formal" ]] && continue
      fi
      dst="$TARGET_PROJECT_DIR/$dst_rel"
      src="$TARGET_PROJECT_DIR/$src_rel"
      if [[ ! -f "$dst" ]] && [[ -f "$src" ]]; then
        # Skip if an equivalent legacy file exists (avoids blank template over real content)
        skip_reason=""
        case "$dst_rel" in
          OVERVIEW.md)
            for equiv in PRODUCT.md PRD.md; do
              [[ -f "$TARGET_PROJECT_DIR/$equiv" ]] && skip_reason="$equiv exists (rename to OVERVIEW.md manually)" && break
            done ;;
        esac
        if [[ -n "$skip_reason" ]]; then
          echo -e "  ${YELLOW}⚠${NC} Skipped $dst_rel — $skip_reason"
        else
          mkdir -p "$(dirname "$dst")"
          cp "$src" "$dst"
          if head -1 "$dst" | grep -qi "(Template)"; then
            sed -i.bak '1s/ (Template)//g; 1s/(Template)//g' "$dst"
            rm -f "$dst.bak" 2>/dev/null || true
          fi
          echo -e "  ${GREEN}✓${NC} Created $dst_rel"
          CREATED_COUNT=$((CREATED_COUNT + 1))
        fi
      fi
    done < "$STATE_FILES_CONF"
    if [[ $CREATED_COUNT -eq 0 ]]; then
      echo -e "  ${GREEN}✓${NC} All state files present"
    fi
  else
    echo -e "  ${YELLOW}⚠${NC} state-files.conf not found, skipping"
  fi
fi

echo ""

# Step 7: Add new configuration sections (v0.16.0+)
echo -e "${BLUE}[7/11] Adding new configuration sections${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ "$DRY_RUN" == "yes" ]]; then
  echo "  [DRY RUN] Would add new configuration sections"
else
  # Add complexity_limits section to STACK.md if missing
  if [[ -f "$TARGET_PROJECT_DIR/STACK.md" ]]; then
    if ! grep -q "## Complexity limits" "$TARGET_PROJECT_DIR/STACK.md" 2>/dev/null; then
      echo "  Adding complexity limits section to STACK.md..."
      cat >> "$TARGET_PROJECT_DIR/STACK.md" <<'COMPLEXITY_EOF'

## Complexity limits
- max_files_per_commit: 10
- max_added_lines: 500
- max_code_file_length: 500
COMPLEXITY_EOF
      echo -e "${GREEN}  ✓ Added complexity limits section${NC}"
    else
      echo -e "  ${GREEN}✓${NC} Complexity limits section already exists"
    fi

    # Check for test commands
    HAS_TEST=$(grep -iE "^[- ]*test:" "$TARGET_PROJECT_DIR/STACK.md" 2>/dev/null || true)
    HAS_TEST_FAST=$(grep -iE "test_fast:" "$TARGET_PROJECT_DIR/STACK.md" 2>/dev/null || true)

    if [[ -z "$HAS_TEST" ]] && [[ -z "$HAS_TEST_FAST" ]]; then
      echo -e "  ${YELLOW}⚠${NC} No test commands in STACK.md"
      echo "    Consider adding:"
      echo "      - test: <your full test suite command>"
      echo "      - test_fast: <quick tests for pre-commit>"
    elif [[ -n "$HAS_TEST" ]] && [[ -z "$HAS_TEST_FAST" ]]; then
      echo -e "  ${YELLOW}⚠${NC} Found 'test:' but no 'test_fast:'"
      echo "    Consider adding a faster test for pre-commit checks"
    else
      echo -e "  ${GREEN}✓${NC} Test commands configured"
    fi
  fi

  # Add frontmatter to acceptance files missing it (legacy format)
  if [[ -d "$TARGET_PROJECT_DIR/.agentic/spec/acceptance" ]]; then
    UPDATED_ACC=0
    for acc_file in "$TARGET_PROJECT_DIR"/.agentic/spec/acceptance/F-*.md; do
      if [[ -f "$acc_file" ]]; then
        # Check if file already has frontmatter
        if ! head -1 "$acc_file" | grep -q "^---"; then
          FEATURE_ID=$(basename "$acc_file" .md)
          echo "  Adding frontmatter to $FEATURE_ID..."

          # Create temp file with frontmatter prepended
          {
            echo "---"
            echo "feature: $FEATURE_ID"
            echo "status: shipped"
            echo "validation: []  # TODO: Add validation commands"
            echo "---"
            echo ""
            cat "$acc_file"
          } > "${acc_file}.tmp"
          mv "${acc_file}.tmp" "$acc_file"

          UPDATED_ACC=$((UPDATED_ACC + 1))
        fi
      fi
    done

    if [[ $UPDATED_ACC -gt 0 ]]; then
      echo -e "  ${GREEN}✓${NC} Updated $UPDATED_ACC acceptance file(s) with frontmatter"
    else
      echo -e "  ${GREEN}✓${NC} All acceptance files have frontmatter"
    fi
  fi

  # Add or repair ## Settings section in STACK.md (v0.27.0+)
  if [[ -f "$TARGET_PROJECT_DIR/STACK.md" ]]; then
    TEMPLATE_FILE="$NEW_FRAMEWORK_DIR/.agentic/lib/init/STACK.template.md"
    PRESETS_FILE="$NEW_FRAMEWORK_DIR/.agentic/presets/profiles.conf"
    STACK_FILE="$TARGET_PROJECT_DIR/STACK.md"

    # Repair concatenated settings lines from v0.33.0 BSD sed bug
    # Pattern: "- key: value- key2: value2" on a single line
    if grep -qE '^- [a-z_]+: .+- [a-z_]+:' "$STACK_FILE"; then
      python3 -c "
import re, sys
text = open(sys.argv[1]).read()
# Split concatenated settings: '- key: val- key2: val2' on one line
for _ in range(20):
    new = re.sub(r'(\w)(- [a-z_]+:)', r'\1\n\2', text)
    if new == text: break
    text = new
open(sys.argv[1], 'w').write(text)" "$STACK_FILE"
      echo -e "  ${GREEN}✓${NC} Repaired concatenated settings lines (v0.33.0 bug)"
    fi

    # Remove duplicate settings (keep first occurrence of each key)
    python3 -c "
import sys, re
lines = open(sys.argv[1]).readlines()
seen = set()
out = []
for line in lines:
    m = re.match(r'^- ([a-z_]+):', line)
    if m:
        key = m.group(1)
        if key in seen:
            continue
        seen.add(key)
    out.append(line)
open(sys.argv[1], 'w').writelines(out)" "$STACK_FILE"

    if ! grep -q "^## Settings" "$STACK_FILE" 2>/dev/null; then
      # Create Settings from template with full comments and subheadings
      echo "  Adding ## Settings section from template..."
      if [[ -f "$TEMPLATE_FILE" ]] && [[ -f "$PRESETS_FILE" ]]; then
        # Extract ## Settings section from template (up to next ## or blank line after ### block)
        SETTINGS_BLOCK=$(awk '/^## Settings/{found=1} found && /^## [^S#]/{exit} found{print}' "$TEMPLATE_FILE")
        # Substitute profile values
        while IFS='=' read -r preset_key preset_value; do
          [[ "$preset_key" =~ ^#|^$ ]] && continue
          [[ -z "$preset_key" ]] && continue
          if [[ "$preset_key" =~ ^${PROFILE}\.(.*) ]]; then
            sname="${BASH_REMATCH[1]}"
            SETTINGS_BLOCK=$(echo "$SETTINGS_BLOCK" | sed "s/^- ${sname}: .*$/- ${sname}: ${preset_value}/")
          fi
        done < "$PRESETS_FILE"
        # Set profile line
        SETTINGS_BLOCK=$(echo "$SETTINGS_BLOCK" | sed "s/^- profile: .*$/- profile: ${PROFILE}/")
        printf '\n%s\n' "$SETTINGS_BLOCK" >> "$STACK_FILE"
        echo -e "  ${GREEN}✓${NC} Added ## Settings section with descriptions (profile: ${PROFILE})"
      else
        # Fallback: bare section if template unavailable
        cat >> "$STACK_FILE" <<SETTINGS_EOF

## Settings
<!-- Use \`ag set <key> <value>\` to change, \`ag set --show\` to view all. -->
- profile: ${PROFILE}
SETTINGS_EOF
        echo -e "  ${GREEN}✓${NC} Added ## Settings section (profile: ${PROFILE})"
      fi
    else
      echo -e "  ${GREEN}✓${NC} ## Settings section already exists"
    fi

    # Populate any missing settings from profile defaults
    if [[ -f "$PRESETS_FILE" ]]; then
      missing_settings=()
      while IFS='=' read -r preset_key preset_value; do
        [[ "$preset_key" =~ ^#|^$ ]] && continue
        [[ -z "$preset_key" ]] && continue
        if [[ "$preset_key" =~ ^${PROFILE}\.(.*) ]]; then
          sname="${BASH_REMATCH[1]}"
          if ! grep -q "^- ${sname}:" "$STACK_FILE"; then
            missing_settings+=("- ${sname}: ${preset_value}")
          fi
        fi
      done < "$PRESETS_FILE"

      settings_added=${#missing_settings[@]}
      if [[ $settings_added -gt 0 ]]; then
        settings_start=$(grep -n "^## Settings" "$STACK_FILE" | head -1 | cut -d: -f1)
        settings_end=$(awk -v start="$settings_start" 'NR > start && /^## [^#]/ { print NR; exit }' "$STACK_FILE")
        [[ -z "$settings_end" ]] && settings_end=$(wc -l < "$STACK_FILE")
        last_setting_line=$(sed -n "${settings_start},${settings_end}p" "$STACK_FILE" | grep -n "^- " | tail -1 | cut -d: -f1)
        if [[ -n "$last_setting_line" ]]; then
          abs_line=$((settings_start + last_setting_line - 1))
          {
            head -n "$abs_line" "$STACK_FILE"
            for s in "${missing_settings[@]}"; do
              echo "$s"
            done
            tail -n +"$((abs_line + 1))" "$STACK_FILE"
          } > "$STACK_FILE.tmp"
          mv "$STACK_FILE.tmp" "$STACK_FILE"
        fi
        echo -e "  ${GREEN}✓${NC} Added $settings_added missing settings for ${PROFILE} profile"
      fi
    fi
  fi
fi

echo ""

# Step 7b: Git hook configuration
echo -e "${BLUE}[7b/11] Configuring git hooks${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ "$DRY_RUN" == "yes" ]]; then
  echo "  [DRY RUN] Would configure git hooks"
else
  # Configure core.hooksPath
  if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
    CURRENT_HOOKS_PATH=$(git config core.hooksPath 2>/dev/null || echo "")
    if [[ "$CURRENT_HOOKS_PATH" != ".agentic/hooks" ]]; then
      git config core.hooksPath .agentic/hooks
      echo -e "  ${GREEN}✓${NC} Set core.hooksPath to .agentic/hooks"
    else
      echo -e "  ${GREEN}✓${NC} core.hooksPath already configured"
    fi

    # Clean up stale file-copied hook from old scaffold.sh
    if [[ -f "$TARGET_PROJECT_DIR/.git/hooks/pre-commit" ]]; then
      if grep -q "validate_specs" "$TARGET_PROJECT_DIR/.git/hooks/pre-commit" 2>/dev/null; then
        rm -f "$TARGET_PROJECT_DIR/.git/hooks/pre-commit"
        echo -e "  ${GREEN}✓${NC} Removed stale .git/hooks/pre-commit (replaced by core.hooksPath)"
      fi
    fi
  fi

  # Add intent journal entries to .gitignore (v0.53.0, F-0200)
  if [[ -f "$TARGET_PROJECT_DIR/.gitignore" ]]; then
    local gitignore_updated=false
    if ! grep -q "intents.json" "$TARGET_PROJECT_DIR/.gitignore" 2>/dev/null; then
      echo ".agentic/session/intents.json" >> "$TARGET_PROJECT_DIR/.gitignore"
      gitignore_updated=true
    fi
    if ! grep -q ".current-session-id" "$TARGET_PROJECT_DIR/.gitignore" 2>/dev/null; then
      echo ".agentic/session/.current-session-id" >> "$TARGET_PROJECT_DIR/.gitignore"
      gitignore_updated=true
    fi
    if [[ "$gitignore_updated" == "true" ]]; then
      echo -e "  ${GREEN}✓${NC} Added intent journal entries to .gitignore"
    fi
  fi

  # Ensure .agentic/session/ exists for intent journal
  mkdir -p "$TARGET_PROJECT_DIR/.agentic/session" 2>/dev/null

  # Migrate review_*: auto → skip in STACK.md (v0.51.0: "auto" renamed to "skip")
  if [[ -f "$TARGET_PROJECT_DIR/STACK.md" ]]; then
    if grep -qE "^[- ]*review_[a-z_]+:[[:space:]]*auto" "$TARGET_PROJECT_DIR/STACK.md" 2>/dev/null; then
      if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' -E 's/^([- ]*review_[a-z_]+:[[:space:]]*)auto([[:space:]]|$)/\1skip\2/' "$TARGET_PROJECT_DIR/STACK.md"
      else
        sed -i -E 's/^([- ]*review_[a-z_]+:[[:space:]]*)auto([[:space:]]|$)/\1skip\2/' "$TARGET_PROJECT_DIR/STACK.md"
      fi
      echo -e "  ${GREEN}✓${NC} Migrated review_*: auto → skip"
    fi
  fi

  # Add git_mode setting for existing projects (v0.69.0, F-0250)
  # Existing projects with .git/ get git_mode: active (backwards compat)
  if [[ -f "$TARGET_PROJECT_DIR/STACK.md" ]]; then
    if ! grep -q "^- git_mode:" "$TARGET_PROJECT_DIR/STACK.md" 2>/dev/null; then
      if git -C "$TARGET_PROJECT_DIR" rev-parse --git-dir >/dev/null 2>&1; then
        # Has git — set to active
        if [[ "$OSTYPE" == "darwin"* ]]; then
          sed -i '' '/^- profile:/a\
- git_mode: active\
# Git initialization mode. none | deferred | active. Activated via ag git-init (F-0250).' "$TARGET_PROJECT_DIR/STACK.md"
        else
          sed -i '/^- profile:/a\- git_mode: active\n# Git initialization mode. none | deferred | active. Activated via ag git-init (F-0250).' "$TARGET_PROJECT_DIR/STACK.md"
        fi
        echo -e "  ${GREEN}✓${NC} Added git_mode: active (existing git project)"
      else
        # No git — set to deferred
        if [[ "$OSTYPE" == "darwin"* ]]; then
          sed -i '' '/^- profile:/a\
- git_mode: deferred\
# Git initialization mode. none | deferred | active. Activate with: ag git-init (F-0250).' "$TARGET_PROJECT_DIR/STACK.md"
        else
          sed -i '/^- profile:/a\- git_mode: deferred\n# Git initialization mode. none | deferred | active. Activate with: ag git-init (F-0250).' "$TARGET_PROJECT_DIR/STACK.md"
        fi
        echo -e "  ${GREEN}✓${NC} Added git_mode: deferred (no git detected)"
      fi
    fi
  fi

  # Migrate pre_commit_hook: yes → fast in STACK.md
  if [[ -f "$TARGET_PROJECT_DIR/STACK.md" ]]; then
    if grep -qE "^[- ]*pre_commit_hook:[[:space:]]*yes" "$TARGET_PROJECT_DIR/STACK.md" 2>/dev/null; then
      if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' -E 's/^([- ]*pre_commit_hook:[[:space:]]*)yes/\1fast  # fast | full | no/' "$TARGET_PROJECT_DIR/STACK.md"
      else
        sed -i -E 's/^([- ]*pre_commit_hook:[[:space:]]*)yes/\1fast  # fast | full | no/' "$TARGET_PROJECT_DIR/STACK.md"
      fi
      echo -e "  ${GREEN}✓${NC} Migrated pre_commit_hook: yes → fast"
    fi
  fi
fi

echo ""

# Step 8: Verification (was 7/9)
echo -e "${BLUE}[8/11] Running verification${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ "$DRY_RUN" == "yes" ]]; then
  echo "  [DRY RUN] Would run verification checks"
else
  # Run doctor.sh if available
  if [[ -x "$TARGET_PROJECT_DIR/.agentic/lib/tools/doctor.sh" ]]; then
    echo "  Running doctor.sh..."
    if bash "$TARGET_PROJECT_DIR/.agentic/lib/tools/doctor.sh" > /dev/null 2>&1; then
      echo -e "${GREEN}  ✓ Structure verification passed${NC}"
    else
      echo -e "${YELLOW}  ⚠ Some checks failed (see below)${NC}"
      bash "$TARGET_PROJECT_DIR/.agentic/lib/tools/doctor.sh" 2>&1 | grep -E "^(Missing|NEW)" || true
    fi
  fi

  # Check for spec validation
  if [[ -f "$TARGET_PROJECT_DIR/.agentic/lib/tools/validate_specs.py" ]] && command -v python3 >/dev/null 2>&1; then
    echo "  Running spec validation..."
    VALIDATION_OUTPUT=$(python3 "$TARGET_PROJECT_DIR/.agentic/lib/tools/validate_specs.py" 2>&1)
    VALIDATION_EXIT=$?
    
    if [[ $VALIDATION_EXIT -eq 0 ]]; then
      echo -e "${GREEN}  ✓ Spec validation passed${NC}"
    elif echo "$VALIDATION_OUTPUT" | grep -q "ModuleNotFoundError\|No module named"; then
      echo -e "${BLUE}  ℹ Spec validation skipped (Python dependencies not installed)${NC}"
      echo "    Optional: pip install pyyaml python-frontmatter jsonschema"
    else
      echo -e "${YELLOW}  ⚠ Spec validation found issues:${NC}"
      echo "$VALIDATION_OUTPUT" | head -10
      echo "    Run manually: python3 .agentic/lib/tools/validate_specs.py"
    fi
  fi

  # Run spec format upgrade if available
  if [[ -f "$TARGET_PROJECT_DIR/.agentic/lib/tools/upgrade_spec_format.py" ]] && command -v python3 >/dev/null 2>&1; then
    echo "  Running spec format upgrade..."
    UPGRADE_OUTPUT=$(python3 "$TARGET_PROJECT_DIR/.agentic/lib/tools/upgrade_spec_format.py" 2>&1)
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

# Step 8b: Run sync check
echo -e "${BLUE}[8b/11] Running sync check${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ "$DRY_RUN" == "yes" ]]; then
  echo "  [DRY RUN] Would run sync --check"
elif [[ -f "$TARGET_PROJECT_DIR/.agentic/lib/tools/sync.sh" ]]; then
  SYNC_OUTPUT=$(cd "$TARGET_PROJECT_DIR" && bash .agentic/tools/sync.sh --check 2>&1) || true
  if [[ -n "$SYNC_OUTPUT" ]]; then
    echo -e "  ${YELLOW}⚠ Sync check found drift (expected after upgrade):${NC}"
    echo "$SYNC_OUTPUT" | head -15 | sed 's/^/    /'
    echo "    Run \`bash .agentic/tools/sync.sh\` after upgrade to auto-fix"
  else
    echo -e "  ${GREEN}✓${NC} Sync check passed"
  fi
else
  echo -e "  ${YELLOW}⚠${NC} sync.sh not found, skipping"
fi

echo ""

# Step 9: Update STACK.md with new version (consolidated, robust pattern matching)
echo -e "${BLUE}[9/11] Updating STACK.md with new framework version${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Use whichever version variable is set (FRAMEWORK_VERSION or NEW_VERSION as fallback)
VERSION_TO_USE="${FRAMEWORK_VERSION:-$NEW_VERSION}"
debug "VERSION_TO_USE='$VERSION_TO_USE' (FRAMEWORK_VERSION='$FRAMEWORK_VERSION', NEW_VERSION='$NEW_VERSION')"

STACK_UPDATED="no"
debug "Checking STACK.md update conditions:"
debug "  VERSION_TO_USE='$VERSION_TO_USE'"
debug "  STACK.md exists at $TARGET_PROJECT_DIR/STACK.md? $(test -f "$TARGET_PROJECT_DIR/STACK.md" && echo yes || echo no)"

if [[ -z "$VERSION_TO_USE" || "$VERSION_TO_USE" == "unknown" ]]; then
  echo -e "${RED}✗ Cannot update STACK.md: version not determined${NC}"
  echo "  Check that VERSION file exists in the framework being used for upgrade"
elif [[ ! -f "$TARGET_PROJECT_DIR/STACK.md" ]]; then
  echo -e "${YELLOW}⚠ STACK.md not found - skipping version update${NC}"
else
  # Try multiple patterns to catch all STACK.md formats
  # Pattern 1: "- Version: X.Y.Z" (standard format)
  # Pattern 2: "Version: X.Y.Z" (no dash)
  # Pattern 3: "  - Version: X.Y.Z" (indented)
  
  debug "Looking for Version: pattern in STACK.md"
  if grep -qE "^[[:space:]]*-?[[:space:]]*Version:" "$TARGET_PROJECT_DIR/STACK.md"; then
    debug "Found Version: pattern, updating..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
      # macOS sed
      sed -i '' -E "s/^([[:space:]]*-?[[:space:]]*Version:[[:space:]]*)[0-9]+\.[0-9]+\.[0-9]+.*/\1$VERSION_TO_USE/" "$TARGET_PROJECT_DIR/STACK.md"
    else
      # Linux sed
      sed -i -E "s/^([[:space:]]*-?[[:space:]]*Version:[[:space:]]*)[0-9]+\.[0-9]+\.[0-9]+.*/\1$VERSION_TO_USE/" "$TARGET_PROJECT_DIR/STACK.md"
    fi
    STACK_UPDATED="yes"
    echo -e "  ${GREEN}✓${NC} Updated STACK.md version to $VERSION_TO_USE"
  else
    echo -e "  ${YELLOW}⚠ Version field not found in STACK.md${NC}"
    echo "  Add manually: - Version: $VERSION_TO_USE"
    debug "STACK.md content (first 20 lines):"
    debug "$(head -20 "$TARGET_PROJECT_DIR/STACK.md" 2>/dev/null || echo 'Could not read')"
  fi
  
  # Verify the update worked
  if [[ "$STACK_UPDATED" == "yes" ]]; then
    UPDATED_VERSION=$(grep -oE "Version:[[:space:]]*[0-9]+\.[0-9]+\.[0-9]+" "$TARGET_PROJECT_DIR/STACK.md" | head -1 | grep -oE "[0-9]+\.[0-9]+\.[0-9]+" || echo "")
    debug "Verification: UPDATED_VERSION='$UPDATED_VERSION', expected='$VERSION_TO_USE'"
    if [[ "$UPDATED_VERSION" != "$VERSION_TO_USE" ]]; then
      echo -e "  ${RED}✗ STACK.md version mismatch: expected $VERSION_TO_USE, got ${UPDATED_VERSION:-nothing}${NC}"
      echo "  Please update manually!"
      STACK_UPDATED="no"
    else
      debug "Verification passed!"
    fi
  fi
fi

# Also update .agentic/VERSION file
if [[ -n "$VERSION_TO_USE" && "$VERSION_TO_USE" != "unknown" ]]; then
  echo "$VERSION_TO_USE" > "$TARGET_PROJECT_DIR/.agentic/VERSION"
  echo -e "  ${GREEN}✓${NC} Updated .agentic/VERSION to $VERSION_TO_USE"
else
  echo -e "  ${YELLOW}⚠${NC} Could not update .agentic/VERSION (version unknown)"
fi

# Step 10: Create upgrade marker for agent to pick up at next session
echo -e "${BLUE}[10/11] Creating upgrade marker${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

debug "Creating upgrade marker at: $TARGET_PROJECT_DIR/.agentic/.upgrade_pending"
debug "  .agentic dir exists? $(test -d "$TARGET_PROJECT_DIR/.agentic" && echo yes || echo no)"

# Helper function: check if version A < version B
version_lt() {
  # Returns 0 (true) if $1 < $2
  [[ "$1" != "$2" ]] && [[ "$(printf '%s\n%s' "$1" "$2" | sort -V | head -n1)" == "$1" ]]
}

# Build NEW FEATURES section based on version upgrade path
# Features registry: "version_introduced:feature_name:command:description"
# Only features introduced AFTER from_version and AT OR BEFORE to_version are shown
NEW_FEATURES_SECTION=""
FROM_VER="${CURRENT_VERSION:-0.0.0}"
TO_VER="${VERSION_TO_USE:-999.0.0}"

# Feature registry - add new features here with the version they were introduced
declare -a FEATURE_REGISTRY=(
  "0.5.0:Sub-agent setup:bash .agentic/tools/setup-agent.sh cursor-agents:Specialized agents for different tasks"
  "0.5.0:Multi-agent pipeline:bash .agentic/tools/setup-agent.sh pipeline:Parallel work coordination"
  "0.5.0:Tool setup:bash .agentic/tools/setup-agent.sh all:Auto-loaded instructions"
  "0.12.0:STATUS.md consolidation:See STATUS.md:STATUS.md now required for both Discovery and Formal profiles"
  "0.18.0:LLM behavioral tests:ag test llm --help:Run behavioral tests in any AI tool (Claude, Cursor, Codex, Copilot)"
  "0.18.0:Plan-review loop:ag plan F-XXXX:Iterative planning with critical review before implementation"
  "0.26.0:Profile rename:See STACK.md:Profiles renamed: Core→Discovery, Core+PM→Formal"
  "0.33.0:Instruction file auto-refresh:Automatic:CLAUDE.md, .cursorrules, copilot, codex regenerated on upgrade"
  "0.33.0:DRY state file config:See .agentic/init/state-files.conf:Single source of truth for required state files"
  "0.39.0:Spec format evolution:See .agentic/spec/acceptance.template.md:Priority tiers (P1/P2), Behavior section, Verification heading (F-0148)"
  "0.39.0:User extensions:.agentic/local/extensions/:Custom skills, gates, hooks, rules that survive upgrades (F-028)"
  "0.39.0:Semantic spec analysis:bash .agentic/tools/spec-analyze.sh F-XXXX:Advisory checks before implementation — ambiguity, NFR, coverage gaps (F-0152)"
  "0.39.0:AC-level test coverage:python3 .agentic/lib/tools/coverage.py --ac-coverage F-XXXX:Per-acceptance-criterion test mapping (F-0153)"
  "0.53.0:Intent journal + crash recovery:ag intent list:Write-ahead log for ag implement/done with reconciliation via ag sync (F-0200)"
)

# Filter features based on version range
NEW_FEATURES=""
for feature_entry in "${FEATURE_REGISTRY[@]}"; do
  IFS=':' read -r feat_version feat_name feat_cmd feat_desc <<< "$feature_entry"
  # Include if: from_version < feature_version <= to_version
  if version_lt "$FROM_VER" "$feat_version" && ! version_lt "$TO_VER" "$feat_version"; then
    NEW_FEATURES="${NEW_FEATURES}       - ${feat_name}: \`${feat_cmd}\` (${feat_desc})\n"
  fi
done

# Only add NEW FEATURES section if there are actually new features
if [[ -n "$NEW_FEATURES" ]]; then
  NEW_FEATURES_SECTION="8. [ ] **NEW FEATURES CHECK**: Ask user about new features added since ${FROM_VER}:
${NEW_FEATURES}9. [ ] Delete this file: \\\`rm .agentic/.upgrade_pending\\\`"
else
  NEW_FEATURES_SECTION="8. [ ] Delete this file: \\\`rm .agentic/.upgrade_pending\\\`"
fi

if [[ ! -d "$TARGET_PROJECT_DIR/.agentic" ]]; then
  echo -e "${RED}✗ Cannot create marker: .agentic/ directory not found${NC}"
  echo "  This is unexpected after upgrade. Check the upgrade output above."
else
  UPGRADE_MARKER="$TARGET_PROJECT_DIR/.agentic/.upgrade_pending"
  cat > "$UPGRADE_MARKER" << EOF
# 🚨 FRAMEWORK UPGRADE PENDING - READ THIS FIRST!

**DO NOT search through .agentic/ randomly. This file tells you everything.**

## Upgrade Summary

- **From**: ${CURRENT_VERSION:-unknown}
- **To**: ${VERSION_TO_USE:-unknown}
- **Date**: $(date +%Y-%m-%d)
- **STACK.md updated**: ${STACK_UPDATED}

## Your TODO List (complete all, then delete this file):

1. ✅ Read this file (you're doing it now)
2. [ ] If "STACK.md updated: no" above → manually update: \`- Version: ${VERSION_TO_USE:-unknown}\`
3. [ ] Read .agentic/START_HERE.md (5 min) for new workflows
4. [ ] Re-read .agentic/init/memory-seed.md and update persistent memory
5. [ ] Validate specs: \`python3 .agentic/lib/tools/validate_specs.py\`
6. [ ] Review CHANGELOG for ${VERSION_TO_USE:-unknown} changes (see link below)
$(echo -e "$NEW_FEATURES_SECTION")

## Changelog

https://github.com/tomgun/agentic-framework/blob/main/CHANGELOG.md

## Don't Waste Tokens!

- This file IS the upgrade notification
- Don't search .agentic/ for upgrade info - it's all here
- After completing TODO, delete this file
EOF

  if [[ -f "$UPGRADE_MARKER" ]]; then
    echo -e "  ${GREEN}✓${NC} Created .upgrade_pending marker for agent"
  else
    echo -e "  ${RED}✗${NC} Failed to create .upgrade_pending marker"
  fi
fi

echo ""

# Environment check - show what tool files exist, suggest if missing
echo ""
echo "[11/11] Environment check ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [[ -f "$TARGET_PROJECT_DIR/.agentic/lib/tools/check-environment.sh" ]]; then
  cd "$TARGET_PROJECT_DIR"
  bash .agentic/tools/check-environment.sh --list 2>/dev/null || true
  cd - > /dev/null
fi

# Summary
echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                    UPGRADE COMPLETE                            ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

if [[ "$DRY_RUN" == "yes" ]]; then
  echo -e "${YELLOW}This was a DRY RUN. No changes were made.${NC}"
  echo "To perform the actual upgrade, run without DRY_RUN=yes"
else
  if [[ -n "$VERSION_TO_USE" && "$VERSION_TO_USE" != "unknown" ]]; then
    echo -e "${GREEN}✓ Framework upgraded to version $VERSION_TO_USE${NC}"
  else
    echo -e "${GREEN}✓ Framework upgraded${NC}"
  fi
  echo ""
  echo "Project: $TARGET_PROJECT_DIR"
  echo ""
  echo "Next steps:"
  echo "  1. Review CHANGELOG: https://github.com/tomgun/agentic-framework/blob/main/CHANGELOG.md"
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
