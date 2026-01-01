#!/usr/bin/env bash
set -euo pipefail

# Architecture diff tool
# Shows what changed in TECH_SPEC architecture sections since a given point

TECH_SPEC="spec/TECH_SPEC.md"

if [ ! -f "$TECH_SPEC" ]; then
  echo "Error: $TECH_SPEC not found"
  exit 1
fi

# Default: show changes since last tag
REF="${1:-$(git describe --tags --abbrev=0 2>/dev/null || echo 'HEAD~10')}"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Not a git repository. Cannot show architectural diff."
  exit 1
fi

echo "=== Architecture changes since $REF ==="
echo ""

# Show diff of specific sections
echo "Changes to TECH_SPEC.md:"
git diff "$REF" HEAD -- "$TECH_SPEC" || echo "No changes or ref not found"

echo ""
echo "---"
echo ""
echo "Changes to architecture diagrams:"
if [ -d "docs/architecture/diagrams" ]; then
  git diff "$REF" HEAD -- docs/architecture/diagrams/ || echo "No changes or ref not found"
else
  echo "No docs/architecture/diagrams/ directory found"
fi

echo ""
echo "Tip: Use 'git diff <commit> HEAD -- spec/TECH_SPEC.md' for specific comparisons"

