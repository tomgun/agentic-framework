#!/usr/bin/env bash
# Staleness detector - finds documentation files not updated recently
set -euo pipefail

DAYS="${1:-30}"

echo "=== Staleness Check (files not updated in $DAYS days) ==="
echo ""

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Not a git repository. Cannot check staleness."
  exit 1
fi

# Key documentation files to check
FILES=(
  "CONTEXT_PACK.md"
  "STATUS.md"
  "JOURNAL.md"
  "spec/FEATURES.md"
  "spec/TECH_SPEC.md"
  "spec/NFR.md"
  "spec/OVERVIEW.md"
)

stale_count=0

for file in "${FILES[@]}"; do
  if [[ ! -f "$file" ]]; then
    continue
  fi
  
  # Get last modification date
  last_modified=$(git log -1 --format="%ar" -- "$file" 2>/dev/null || echo "never")
  last_commit_days=$(git log -1 --format="%cr" -- "$file" 2>/dev/null | grep -oE '[0-9]+' | head -1 || echo "999")
  
  if [[ "$last_commit_days" -gt "$DAYS" ]]; then
    echo "⚠ $file - last updated $last_modified"
    stale_count=$((stale_count + 1))
  fi
done

echo ""

if [[ $stale_count -eq 0 ]]; then
  echo "✓ All key documentation files updated recently"
else
  echo "Found $stale_count stale file(s)"
  echo ""
  echo "Stale documentation may indicate:"
  echo "  - No recent development activity (OK if intentional)"
  echo "  - Agents not updating docs (check Documentation Sync Rule)"
  echo "  - Files need manual review and update"
fi

