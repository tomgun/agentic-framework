#!/usr/bin/env bash
# migration.sh: Spec migration management tool
# Purpose: Create, list, search, and apply spec migrations
# Credit: Concept by Arto Jalkanen
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
MIGRATIONS_DIR="$REPO_ROOT/spec/migrations"
INDEX_FILE="$MIGRATIONS_DIR/_index.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Usage
usage() {
  cat << EOF
Usage: bash .agentic/tools/migration.sh <command> [args]

Commands:
  create <title>    Create a new migration
  list              List all migrations
  show <id>         Show a specific migration
  search <term>     Search migrations by term
  apply             Regenerate FEATURES.md from migrations (optional)
  init              Initialize migrations directory

Examples:
  bash .agentic/tools/migration.sh create "Add real-time notifications"
  bash .agentic/tools/migration.sh list
  bash .agentic/tools/migration.sh show 42
  bash .agentic/tools/migration.sh search "payment"

Credit: Migration-based specs concept by Arto Jalkanen
        Hybrid approach by Tomas Günther & Arto Jalkanen
EOF
  exit 1
}

# Initialize migrations directory
init_migrations() {
  echo "Initializing spec migrations..."
  
  mkdir -p "$MIGRATIONS_DIR"
  
  # Create index if it doesn't exist
  if [[ ! -f "$INDEX_FILE" ]]; then
    cat > "$INDEX_FILE" << 'INDEXEOF'
{
  "version": "1.0",
  "last_migration": 0,
  "migrations": []
}
INDEXEOF
    echo -e "${GREEN}✓${NC} Created $INDEX_FILE"
  fi
  
  # Create README
  if [[ ! -f "$MIGRATIONS_DIR/README.md" ]]; then
    cat > "$MIGRATIONS_DIR/README.md" << 'READMEEOF'
# Spec Migrations

This directory contains the evolution history of specs as atomic changes.

**Concept by**: Arto Jalkanen

## Purpose

Track HOW we arrived at current specs, not just WHAT the specs are.

## Benefits

- Smaller context windows for AI (read 3-5 migrations, not entire spec)
- Natural audit trail of decisions
- Can regenerate system from history
- Better for parallel agent work

## Usage

See: `.agentic/workflows/spec_migrations.md`

## Files

- `_index.json` - Auto-generated registry
- `001_*.md` - Individual migrations (atomic changes)
READMEEOF
    echo -e "${GREEN}✓${NC} Created README.md"
  fi
  
  echo -e "${GREEN}✓${NC} Migrations initialized at $MIGRATIONS_DIR"
}

# Get next migration ID
get_next_id() {
  if [[ ! -f "$INDEX_FILE" ]]; then
    echo "1"
    return
  fi
  
  LAST_ID=$(cat "$INDEX_FILE" | grep -o '"last_migration": *[0-9]*' | grep -o '[0-9]*$' || echo "0")
  echo "$((LAST_ID + 1))"
}

# Create a new migration
create_migration() {
  local title="$1"
  
  # Initialize if needed
  [[ ! -d "$MIGRATIONS_DIR" ]] && init_migrations
  
  # Get next ID
  local next_id
  next_id=$(get_next_id)
  local padded_id=$(printf "%03d" "$next_id")
  
  # Sanitize title for filename
  local filename_title
  filename_title=$(echo "$title" | tr '[:upper:]' '[:lower:]' | tr ' ' '_' | sed 's/[^a-z0-9_]//g')
  
  local filename="${padded_id}_${filename_title}.md"
  local filepath="$MIGRATIONS_DIR/$filename"
  
  # Create migration from template
  local template="$REPO_ROOT/.agentic/spec/MIGRATION.template.md"
  local date
  date=$(date +%Y-%m-%d)
  
  if [[ -f "$template" ]]; then
    sed "s/XXX/$padded_id/g; s/YYYY-MM-DD/$date/g; s/\[Brief Title\]/$title/g" "$template" > "$filepath"
  else
    # Fallback if template doesn't exist
    cat > "$filepath" << MIGEOF
<!-- migration-id: $padded_id -->
<!-- date: $date -->
<!-- author: [your-name] -->
<!-- type: feature -->

# Migration $padded_id: $title

## Context & Why

[Why is this change needed?]

## Changes

### Features Added
- F-XXXX: [Feature name]

### Features Modified
- (none)

### Features Deprecated
- (none)

## Dependencies

- **Requires**: (none)
- **Blocks**: (none)

## Acceptance Criteria

- [ ] [Criterion 1]

## Implementation Notes

[Guidance for developers]

## Rollback Plan

[How to undo this change]

## Related Files

- \`spec/FEATURES.md\` - [What changed]
MIGEOF
  fi
  
  echo -e "${GREEN}✓${NC} Created migration $padded_id: $title"
  echo "   File: $filepath"
  echo ""
  echo "Next steps:"
  echo "  1. Edit the migration file"
  echo "  2. Update spec/FEATURES.md (or run 'migration.sh apply')"
  echo "  3. Commit both files"
}

# List all migrations
list_migrations() {
  if [[ ! -d "$MIGRATIONS_DIR" ]]; then
    echo -e "${YELLOW}No migrations directory found. Run 'migration.sh init' first.${NC}"
    exit 1
  fi
  
  echo "=== Spec Migrations ==="
  echo ""
  
  local count=0
  for file in "$MIGRATIONS_DIR"/*.md; do
    [[ ! -f "$file" ]] && continue
    [[ "$(basename "$file")" == "README.md" ]] && continue
    
    local id=$(grep -o 'migration-id: *[0-9]*' "$file" | head -1 | grep -o '[0-9]*' || echo "?")
    local date=$(grep -o 'date: *[0-9-]*' "$file" | head -1 | sed 's/date: *//' || echo "?")
    local author=$(grep -o 'author: *[^>]*' "$file" | head -1 | sed 's/author: *//' | sed 's/ *-->.*//' || echo "?")
    local type=$(grep -o 'type: *[a-z]*' "$file" | head -1 | sed 's/type: *//' || echo "?")
    local title=$(grep '^# Migration' "$file" | head -1 | sed 's/^# Migration [0-9]*: *//' || basename "$file")
    
    echo -e "${BLUE}$id${NC} - $title"
    echo "     Type: $type | Date: $date | Author: $author"
    echo ""
    ((count++))
  done
  
  if [[ $count -eq 0 ]]; then
    echo -e "${YELLOW}No migrations found. Run 'migration.sh create \"Title\"' to create one.${NC}"
  else
    echo "Total: $count migrations"
  fi
}

# Show a specific migration
show_migration() {
  local id="$1"
  local padded_id=$(printf "%03d" "$id")
  
  local file
  file=$(find "$MIGRATIONS_DIR" -name "${padded_id}_*.md" | head -1)
  
  if [[ -z "$file" || ! -f "$file" ]]; then
    echo -e "${RED}Migration $id not found${NC}"
    exit 1
  fi
  
  cat "$file"
}

# Search migrations
search_migrations() {
  local term="$1"
  
  if [[ ! -d "$MIGRATIONS_DIR" ]]; then
    echo -e "${YELLOW}No migrations directory found.${NC}"
    exit 1
  fi
  
  echo "=== Searching migrations for: '$term' ==="
  echo ""
  
  local found=0
  for file in "$MIGRATIONS_DIR"/*.md; do
    [[ ! -f "$file" ]] && continue
    [[ "$(basename "$file")" == "README.md" ]] && continue
    
    if grep -qi "$term" "$file"; then
      local id=$(grep -o 'migration-id: *[0-9]*' "$file" | head -1 | grep -o '[0-9]*' || echo "?")
      local title=$(grep '^# Migration' "$file" | head -1 | sed 's/^# Migration [0-9]*: *//' || basename "$file")
      
      echo -e "${BLUE}$id${NC} - $title"
      echo "     File: $(basename "$file")"
      
      # Show matching lines
      grep -i --color=always "$term" "$file" | head -3 | sed 's/^/     /'
      echo ""
      ((found++))
    fi
  done
  
  if [[ $found -eq 0 ]]; then
    echo -e "${YELLOW}No migrations found matching '$term'${NC}"
  else
    echo "Found in $found migration(s)"
  fi
}

# Apply migrations (regenerate FEATURES.md - optional feature)
apply_migrations() {
  echo -e "${YELLOW}⚠ This is an advanced feature!${NC}"
  echo ""
  echo "This will regenerate spec/FEATURES.md from migrations."
  echo "Current FEATURES.md will be backed up."
  echo ""
  read -p "Continue? (y/n): " -n 1 -r
  echo
  
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
  fi
  
  echo -e "${BLUE}Applying migrations...${NC}"
  
  # Backup current FEATURES.md
  if [[ -f "$REPO_ROOT/spec/FEATURES.md" ]]; then
    local backup="$REPO_ROOT/spec/FEATURES.md.backup.$(date +%Y%m%d-%H%M%S)"
    cp "$REPO_ROOT/spec/FEATURES.md" "$backup"
    echo -e "${GREEN}✓${NC} Backed up to $(basename "$backup")"
  fi
  
  # TODO: Implement migration replay logic
  # For now, just a placeholder
  echo -e "${YELLOW}⚠ Migration replay not yet implemented${NC}"
  echo "   This feature will read all migrations in order and regenerate FEATURES.md"
  echo "   For now, maintain FEATURES.md manually alongside migrations"
}

# Main
main() {
  if [[ $# -eq 0 ]]; then
    usage
  fi
  
  local command="$1"
  shift
  
  case "$command" in
    create)
      [[ $# -eq 0 ]] && { echo "Error: Title required"; usage; }
      create_migration "$*"
      ;;
    list)
      list_migrations
      ;;
    show)
      [[ $# -eq 0 ]] && { echo "Error: Migration ID required"; usage; }
      show_migration "$1"
      ;;
    search)
      [[ $# -eq 0 ]] && { echo "Error: Search term required"; usage; }
      search_migrations "$*"
      ;;
    apply)
      apply_migrations
      ;;
    init)
      init_migrations
      ;;
    *)
      echo "Unknown command: $command"
      usage
      ;;
  esac
}

main "$@"

