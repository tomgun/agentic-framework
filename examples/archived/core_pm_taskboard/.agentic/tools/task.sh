#!/usr/bin/env bash
# Quick task creator - creates task file from template
set -euo pipefail

if [[ $# -eq 0 ]]; then
  cat <<'EOF'
Usage: bash .agentic/tools/task.sh "Task title"

Creates a new task file in spec/tasks/ with auto-generated ID.

Example:
  bash .agentic/tools/task.sh "Add user profile validation"
  
Creates: spec/tasks/TASK-YYYYMMDD-add-user-profile-validation.md
EOF
  exit 1
fi

TITLE="$1"

# Generate task ID from date and slugified title
DATE=$(date +%Y%m%d)
SLUG=$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//')
TASK_ID="TASK-${DATE}-${SLUG}"
FILENAME="spec/tasks/${TASK_ID}.md"

# Ensure directory exists
mkdir -p spec/tasks

# Check if file already exists
if [[ -f "$FILENAME" ]]; then
  echo "Error: $FILENAME already exists"
  exit 1
fi

# Create task file from template
cat > "$FILENAME" <<EOF
# $TASK_ID: $TITLE

## Context
- Spec link(s): <!-- /spec/PRD.md section, /spec/TECH_SPEC.md section -->
- Feature ID(s): <!-- F-#### -->
- Requirement ID(s) (optional): <!-- R-#### -->
- Why now:

## Scope
- In scope:
- Out of scope:

## Acceptance criteria (must be testable)
- AC1:
- AC2:

## Test plan (required)
- Unit tests:
  - What to test:
  - Where:
- Integration/acceptance tests (if applicable):
- Non-functional checks (if applicable):

## Implementation notes (optional)
- Suggested approach:
- Files/modules likely touched:

## Definition of Done (checklist)
- [ ] Code implemented
- [ ] Unit tests added/updated
- [ ] Docs updated (\`STATUS.md\`, relevant spec sections)
- [ ] Review checklist considered (see \`.agentic/quality/review_checklist.md\`)
EOF

echo "Created: $FILENAME"
echo ""
echo "Next steps:"
echo "1. Edit $FILENAME to fill in details"
echo "2. Reference in STATUS.md or JOURNAL.md"
echo "3. Tell agent: 'Work on task $TASK_ID'"

