#!/usr/bin/env bash
# S11: Shipped spec protection gates (Checks 14-16)
#
# Tests:
#   14: Modifying shipped spec acceptance without migration → BLOCKED
#   15: Deleting test file referenced by shipped spec → BLOCKED
#   16: Downgrading shipped feature status → BLOCKED
#   Also: allowed case — modifying shipped spec WITH migration → ALLOWED
set -euo pipefail
source "$(dirname "$0")/../lib/helpers.sh"

section_header "S11: Shipped spec protection (Checks 14-16)"

# ── Setup: formal project with a shipped feature ──

PROJECT=$(scaffold_test_project "formal")
cd "$PROJECT"

# Create a shipped feature with acceptance criteria and test file
cat >> spec/FEATURES.md << 'EOF'

---

## F-0099: Test Feature

**Status**: shipped
**Priority**: high
**Complexity**: low

**Description**: A test feature for validation.

**Acceptance**: See `spec/acceptance/F-0099.md`
EOF

mkdir -p spec/acceptance spec/migrations tests
cat > spec/acceptance/F-0099.md << 'EOF'
# F-0099: Test Feature

## Tests
- [x] `tests/test_feature.sh` — validates core behavior

## Acceptance Criteria
- [x] Feature works correctly

## Out of Scope
- Nothing
EOF

echo "#!/bin/bash" > tests/test_feature.sh
chmod +x tests/test_feature.sh

# Create migration index
cat > spec/migrations/_index.json << 'EOF'
{"version": "1.0", "last_migration": 0, "migrations": []}
EOF

# Commit the shipped feature
git add -A
git commit -m "add shipped feature F-0099" --quiet --no-verify

# ── Test 14: Modify shipped spec WITHOUT migration → BLOCKED ──

echo "# Added criteria" >> spec/acceptance/F-0099.md
touch .agentic/journal/JOURNAL.md STATUS.md
sleep 1
git add spec/acceptance/F-0099.md

OUTPUT=$(git commit -m "modify shipped spec" 2>&1) && EXIT_CODE=0 || EXIT_CODE=$?

assert_exit_code 1 "$EXIT_CODE" "Check 14: modify shipped spec without migration → blocked"
assert_output_contains "$OUTPUT" "F-0099\|migration\|BLOCKED\|FAIL" \
    "Check 14: output mentions F-0099 and migration"

# Reset for next test
git reset HEAD -- spec/acceptance/F-0099.md >/dev/null 2>&1
git checkout -- spec/acceptance/F-0099.md 2>/dev/null

# ── Test 14b: Modify shipped spec WITH migration → ALLOWED ──

echo "# Added criteria" >> spec/acceptance/F-0099.md
cat > spec/migrations/001_update_f0099.md << 'EOF'
<!-- migration-id: 001 -->
# Migration 001: Update F-0099

## Changes
### Features Modified
- F-0099: Added new criteria
EOF

touch .agentic/journal/JOURNAL.md STATUS.md
sleep 1
git add spec/acceptance/F-0099.md spec/migrations/001_update_f0099.md

OUTPUT=$(git commit -m "modify shipped spec with migration" 2>&1) && EXIT_CODE=0 || EXIT_CODE=$?

# Note: may still fail due to other checks (FEATURES.md staleness, etc.)
# but Check 14 specifically should NOT be the blocker
if echo "$OUTPUT" | grep -qi "Shipped feature F-0099.*without migration"; then
    fail_test "Check 14b: should NOT block when migration included"
else
    pass_test "Check 14b: modify shipped spec with migration → not blocked by Check 14"
fi

# Reset for next test
git reset HEAD -- . >/dev/null 2>&1
git checkout -- . 2>/dev/null

# ── Test 15: Delete test file referenced by shipped spec → BLOCKED ──

git rm tests/test_feature.sh --quiet
touch .agentic/journal/JOURNAL.md STATUS.md
sleep 1
git add -A

OUTPUT=$(git commit -m "delete test file" 2>&1) && EXIT_CODE=0 || EXIT_CODE=$?

assert_exit_code 1 "$EXIT_CODE" "Check 15: delete test file for shipped feature → blocked"
assert_output_contains "$OUTPUT" "test_feature\|shipped\|Cannot delete\|FAIL" \
    "Check 15: output mentions test file deletion blocked"

# Reset for next test
git reset HEAD -- . >/dev/null 2>&1
git checkout -- . 2>/dev/null

# ── Test 16: Downgrade shipped feature status → BLOCKED ──

sed -i.bak 's/\*\*Status\*\*: shipped/**Status**: in-progress/' spec/FEATURES.md
rm -f spec/FEATURES.md.bak
touch .agentic/journal/JOURNAL.md STATUS.md
sleep 1
git add spec/FEATURES.md

OUTPUT=$(git commit -m "downgrade status" 2>&1) && EXIT_CODE=0 || EXIT_CODE=$?

assert_exit_code 1 "$EXIT_CODE" "Check 16: downgrade shipped status → blocked"
assert_output_contains "$OUTPUT" "downgrade\|shipped\|BLOCKED\|FAIL" \
    "Check 16: output mentions status downgrade"

cleanup_test_project "$PROJECT"
print_summary
