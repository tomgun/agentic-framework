#!/bin/bash
# Check for untracked files in project directories
# Prevents "created but not tracked" deployment issues

set -e

# Colors
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

# Directories to check (common project directories)
CHECK_DIRS=("src" "lib" "app" "assets" "public" "tests" "test" "spec" "docs" "scripts")

# Find untracked files
UNTRACKED=$(git status --porcelain 2>/dev/null | grep '^??' | cut -c4-)

if [[ -z "$UNTRACKED" ]]; then
  echo -e "${GREEN}✓ No untracked files${NC}"
  exit 0
fi

# Filter to relevant directories
RELEVANT=""
for file in $UNTRACKED; do
  for dir in "${CHECK_DIRS[@]}"; do
    if [[ "$file" == "$dir/"* ]] || [[ "$file" == "$dir" ]]; then
      RELEVANT="$RELEVANT$file\n"
      break
    fi
  done
done

if [[ -z "$RELEVANT" ]]; then
  echo -e "${GREEN}✓ No untracked files in project directories${NC}"
  exit 0
fi

echo -e "${YELLOW}⚠ Untracked files in project directories:${NC}"
echo ""
echo -e "$RELEVANT" | sort | uniq | while read -r file; do
  [[ -n "$file" ]] && echo "  ?? $file"
done
echo ""
echo "Consider:"
echo "  git add <files>           # to track them"
echo "  echo '<pattern>' >> .gitignore  # to ignore them"
echo ""

# Exit with warning code (not error - don't block)
exit 2

