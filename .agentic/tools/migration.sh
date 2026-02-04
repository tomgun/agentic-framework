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
CYAN='\033[0;36m'
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
  apply             Regenerate FEATURES.md from migrations
  init              Initialize migrations directory
  help              Show this help

Examples:
  bash .agentic/tools/migration.sh create "Add real-time notifications"
  bash .agentic/tools/migration.sh list
  bash .agentic/tools/migration.sh show 42
  bash .agentic/tools/migration.sh search "payment"
  bash .agentic/tools/migration.sh apply

Credit: Migration-based specs concept by Arto Jalkanen
        Hybrid approach by Tomas Günther & Arto Jalkanen
EOF
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

  LAST_ID=$(grep -o '"last_migration": *[0-9]*' "$INDEX_FILE" | grep -o '[0-9]*$' || echo "0")
  echo "$((LAST_ID + 1))"
}

# Update index file with new migration
# Uses a simple approach that works with macOS sed
update_index() {
  local id="$1"
  local filename="$2"
  local date="$3"
  local title="$4"

  if [[ ! -f "$INDEX_FILE" ]]; then
    init_migrations
  fi

  # Read current index and rebuild it with the new entry
  local current_content
  current_content=$(cat "$INDEX_FILE")

  # Check if migrations array is empty
  if echo "$current_content" | grep -q '"migrations": \[\]'; then
    # Empty array - create new structure
    cat > "$INDEX_FILE" << EOF
{
  "version": "1.0",
  "last_migration": $id,
  "migrations": [
    {
      "id": $id,
      "file": "$filename",
      "date": "$date",
      "description": "$title"
    }
  ]
}
EOF
  else
    # Has existing migrations - append to array
    # Use awk to insert before the closing ]
    awk -v id="$id" -v file="$filename" -v date="$date" -v desc="$title" '
    BEGIN { found_migrations = 0; last_brace = 0 }
    /"last_migration":/ {
      sub(/"last_migration": *[0-9]+/, "\"last_migration\": " id)
    }
    /"migrations":/ { found_migrations = 1 }
    found_migrations && /}/ { last_brace = NR }
    found_migrations && /\]/ {
      # Print the new entry before ]
      print "    },"
      print "    {"
      print "      \"id\": " id ","
      print "      \"file\": \"" file "\","
      print "      \"date\": \"" date "\","
      print "      \"description\": \"" desc "\""
      print "    }"
      print "  ]"
      found_migrations = 0
      next
    }
    # Skip the original closing } before ] (we printed a new one with comma)
    NR == last_brace && /}[[:space:]]*$/ { next }
    { print }
    ' "$INDEX_FILE" > "$INDEX_FILE.tmp"
    mv "$INDEX_FILE.tmp" "$INDEX_FILE"
  fi
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

  local date
  date=$(date +%Y-%m-%d)

  # Get author from git config
  local author
  author=$(git config user.name 2>/dev/null || echo "Unknown")

  # Create migration from template
  cat > "$filepath" << MIGEOF
<!-- migration-id: $padded_id -->
<!-- date: $date -->
<!-- author: $author -->
<!-- type: feature -->

# Migration $padded_id: $title

## Context & Why

<!-- Describe the problem or need that led to this change -->
<!-- Include business need and technical driver -->

## Changes

### Features Added

<!-- List new features with F-XXXX IDs -->
<!-- - F-XXXX: Feature name -->
<!--   - Detail 1 -->
<!--   - Detail 2 -->

### Features Modified

<!-- List modified features -->
<!-- - F-XXXX: What changed -->

### Features Deprecated

<!-- List deprecated features -->
<!-- - F-XXXX: Why deprecated, migration path -->

## Dependencies

- **Requires**: None
- **Blocks**: None
- **Related**: None

## Acceptance Criteria

- [ ] Criterion 1
- [ ] Criterion 2

## Implementation Notes

<!-- Technical details, patterns used, gotchas -->

## Rollback Plan

<!-- Step-by-step instructions to undo this migration -->
1. Step 1
2. Step 2

## Related Files

<!-- List files created, modified, or deleted -->
<!-- - \`path/to/file.md\` - Action taken -->

## Notes

<!-- Any additional context, future considerations -->
MIGEOF

  # Update index.json
  update_index "$next_id" "$filename" "$date" "$title"

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

  echo ""
  echo -e "${BLUE}Spec Migrations${NC}"
  echo "───────────────────────────────────────────────────────"

  local count=0
  for file in "$MIGRATIONS_DIR"/[0-9]*.md; do
    [[ ! -f "$file" ]] && continue

    local id=$(grep -o 'migration-id: *[0-9]*' "$file" | head -1 | grep -o '[0-9]*' || echo "?")
    local padded_id=$(printf "%03d" "$id" 2>/dev/null || echo "$id")
    local date=$(grep -o 'date: *[0-9-]*' "$file" | head -1 | sed 's/date: *//' || echo "?")
    local title=$(grep '^# Migration' "$file" | head -1 | sed 's/^# Migration [0-9]*: *//' || basename "$file")

    echo -e "  ${CYAN}$padded_id${NC} - $title ${YELLOW}($date)${NC}"
    ((count++))
  done

  echo "───────────────────────────────────────────────────────"

  if [[ $count -eq 0 ]]; then
    echo -e "${YELLOW}No migrations found. Run 'migration.sh create \"Title\"' to create one.${NC}"
  else
    echo -e "Total: ${GREEN}$count${NC} migration(s)"
  fi
  echo ""
}

# Show a specific migration
show_migration() {
  local id="$1"
  # Remove leading zeros for comparison
  id=$(echo "$id" | sed 's/^0*//')
  [[ -z "$id" ]] && id=0
  local padded_id=$(printf "%03d" "$id")

  local file
  file=$(find "$MIGRATIONS_DIR" -name "${padded_id}_*.md" 2>/dev/null | head -1)

  if [[ -z "$file" || ! -f "$file" ]]; then
    echo -e "${RED}Migration $padded_id not found${NC}"
    exit 1
  fi

  # Use pager if interactive
  if [[ -t 1 ]]; then
    ${PAGER:-less} "$file"
  else
    cat "$file"
  fi
}

# Search migrations
search_migrations() {
  local term="$1"

  if [[ ! -d "$MIGRATIONS_DIR" ]]; then
    echo -e "${YELLOW}No migrations directory found.${NC}"
    exit 1
  fi

  echo ""
  echo -e "${BLUE}Search Results for:${NC} \"$term\""
  echo "───────────────────────────────────────────────────────"

  local found=0
  for file in "$MIGRATIONS_DIR"/[0-9]*.md; do
    [[ ! -f "$file" ]] && continue

    local matches
    matches=$(grep -in "$term" "$file" 2>/dev/null || true)

    if [[ -n "$matches" ]]; then
      local id=$(grep -o 'migration-id: *[0-9]*' "$file" | head -1 | grep -o '[0-9]*' || echo "?")
      local padded_id=$(printf "%03d" "$id" 2>/dev/null || echo "$id")
      local title=$(grep '^# Migration' "$file" | head -1 | sed 's/^# Migration [0-9]*: *//' || basename "$file")

      echo ""
      echo -e "${CYAN}$padded_id${NC} - $title"

      # Show matching lines with context (limit to 5)
      echo "$matches" | head -5 | while IFS= read -r line; do
        local linenum
        linenum=$(echo "$line" | cut -d: -f1)
        local content
        content=$(echo "$line" | cut -d: -f2- | sed 's/^[[:space:]]*//' | cut -c1-70)
        echo -e "  ${YELLOW}Line $linenum:${NC} $content"
      done

      local match_count
      match_count=$(echo "$matches" | wc -l | tr -d ' ')
      if [[ "$match_count" -gt 5 ]]; then
        echo -e "  ... and $((match_count - 5)) more matches"
      fi

      ((found++))
    fi
  done

  echo ""
  echo "───────────────────────────────────────────────────────"
  echo -e "Found matches in ${GREEN}$found${NC} migration(s)"
  echo ""
}

# Apply migrations (regenerate FEATURES.md from migrations)
# Note: Uses temp files instead of associative arrays for bash 3.x compatibility
apply_migrations() {
  echo ""
  echo -e "${BLUE}Applying Migrations to Generate FEATURES.md${NC}"
  echo "───────────────────────────────────────────────────────"

  if [[ ! -d "$MIGRATIONS_DIR" ]]; then
    echo -e "${RED}Error:${NC} No migrations directory found"
    exit 1
  fi

  local features_file="$REPO_ROOT/spec/FEATURES.md"
  local output_file="$REPO_ROOT/spec/FEATURES.generated.md"

  # Use temp files for bash 3.x compatibility (no associative arrays)
  local tmp_dir
  tmp_dir=$(mktemp -d)
  trap "rm -rf $tmp_dir" EXIT

  local migration_count=0
  local feature_count=0

  # Process migrations in order
  for file in "$MIGRATIONS_DIR"/[0-9]*.md; do
    [[ -f "$file" ]] || continue

    local bname
    bname=$(basename "$file" .md)
    local mid
    mid=$(echo "$bname" | grep -oE '^[0-9]+')

    echo -e "  Processing migration ${CYAN}$mid${NC}..."
    ((migration_count++))

    # Extract date from migration
    local mdate
    mdate=$(grep -oE '<!-- date: [0-9-]+ -->' "$file" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' || echo "unknown")

    # Parse Features Added section using sed/grep
    local in_section=""

    while IFS= read -r line; do
      # Detect section headers
      case "$line" in
        "### Features Added"*)
          in_section="added"
          continue
          ;;
        "### Features Modified"*)
          in_section="modified"
          continue
          ;;
        "### Features Deprecated"*)
          in_section="deprecated"
          continue
          ;;
        "## "*)
          in_section=""
          continue
          ;;
      esac

      # Parse feature lines: - F-XXXX: Name
      if [[ "$line" =~ ^-\ F-([0-9]+):\ (.+)$ ]] || echo "$line" | grep -qE '^- F-[0-9]+: '; then
        local fid
        fid=$(echo "$line" | grep -oE 'F-[0-9]+' | head -1)
        local fname
        fname=$(echo "$line" | sed 's/^- F-[0-9]*: //')

        if [[ "$in_section" == "added" && -n "$fid" ]]; then
          # Store feature data in temp files
          echo "$fname" > "$tmp_dir/${fid}_name"
          echo "planned" > "$tmp_dir/${fid}_status"
          echo "$mdate" > "$tmp_dir/${fid}_added"
          echo "pending" > "$tmp_dir/${fid}_tests"
          ((feature_count++))
        elif [[ "$in_section" == "modified" && -n "$fid" ]]; then
          if [[ -f "$tmp_dir/${fid}_name" ]]; then
            echo "in_progress" > "$tmp_dir/${fid}_status"
          fi
        elif [[ "$in_section" == "deprecated" && -n "$fid" ]]; then
          echo "deprecated" > "$tmp_dir/${fid}_status"
        fi
      fi
    done < "$file"

    # Check acceptance criteria to determine if shipped
    local total_criteria=0
    local checked_criteria=0
    local in_criteria=false

    while IFS= read -r line; do
      case "$line" in
        "## Acceptance Criteria"*)
          in_criteria=true
          continue
          ;;
        "## "*)
          [[ "$in_criteria" == true ]] && break
          continue
          ;;
      esac

      if [[ "$in_criteria" == true ]]; then
        if echo "$line" | grep -qE '^\- \[.\]'; then
          ((total_criteria++))
          if echo "$line" | grep -qiE '^\- \[x\]'; then
            ((checked_criteria++))
          fi
        fi
      fi
    done < "$file"

    # If all criteria are checked, mark features from this migration as shipped
    if [[ $total_criteria -gt 0 && $total_criteria -eq $checked_criteria ]]; then
      for added_file in "$tmp_dir"/*_added; do
        [[ -f "$added_file" ]] || continue
        local add_date
        add_date=$(cat "$added_file")
        if [[ "$add_date" == "$mdate" ]]; then
          local fid
          fid=$(basename "$added_file" _added)
          echo "shipped" > "$tmp_dir/${fid}_status"
          echo "$mdate" > "$tmp_dir/${fid}_shipped"
          echo "pass" > "$tmp_dir/${fid}_tests"
        fi
      done
    fi

  done

  # Generate FEATURES.md
  echo ""
  echo -e "  Generating ${GREEN}$output_file${NC}..."

  cat > "$output_file" << 'EOF'
# Features (Auto-Generated)

> **Note**: This file was generated by `migration.sh apply` from spec migrations.
> To make changes, create a new migration instead of editing this file directly.

## Feature Registry

| ID | Feature | Status | Tests | Added | Shipped |
|----|---------|--------|-------|-------|---------|
EOF

  # Collect and sort feature IDs
  local feature_ids=""
  for name_file in "$tmp_dir"/*_name; do
    [[ -f "$name_file" ]] || continue
    local fid
    fid=$(basename "$name_file" _name)
    feature_ids="$feature_ids $fid"
  done

  # Sort and output
  for fid in $(echo "$feature_ids" | tr ' ' '\n' | sort -u | grep -v '^$'); do
    local fname=""
    local fstatus="planned"
    local ftests="pending"
    local fadded=""
    local fshipped=""

    [[ -f "$tmp_dir/${fid}_name" ]] && fname=$(cat "$tmp_dir/${fid}_name")
    [[ -f "$tmp_dir/${fid}_status" ]] && fstatus=$(cat "$tmp_dir/${fid}_status")
    [[ -f "$tmp_dir/${fid}_tests" ]] && ftests=$(cat "$tmp_dir/${fid}_tests")
    [[ -f "$tmp_dir/${fid}_added" ]] && fadded=$(cat "$tmp_dir/${fid}_added")
    [[ -f "$tmp_dir/${fid}_shipped" ]] && fshipped=$(cat "$tmp_dir/${fid}_shipped")

    echo "| $fid | $fname | $fstatus | $ftests | $fadded | $fshipped |" >> "$output_file"
  done

  cat >> "$output_file" << 'EOF'

---

*Generated from spec migrations. Run `migration.sh list` to see all migrations.*
EOF

  echo ""
  echo "───────────────────────────────────────────────────────"
  echo -e "Applied ${GREEN}$migration_count${NC} migration(s)"
  echo -e "Total features: ${GREEN}$feature_count${NC}"
  echo ""
  echo -e "Output: ${CYAN}$output_file${NC}"
  echo ""
  echo "To replace FEATURES.md:"
  echo "  mv spec/FEATURES.generated.md spec/FEATURES.md"
  echo ""
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
    help|--help|-h)
      usage
      ;;
    *)
      echo "Unknown command: $command"
      usage
      ;;
  esac
}

main "$@"
