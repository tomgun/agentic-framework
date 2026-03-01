#!/usr/bin/env bash
# S12: Check 2 correctly detects shipped features (grep pattern fix)
#
# Regression test: Before fix, Check 2 used "Status: shipped" which
# didn't match "**Status**: shipped" format in FEATURES.md, causing
# all shipped features to be silently skipped.
set -euo pipefail
source "$(dirname "$0")/../lib/helpers.sh"

section_header "S12: Check 2 shipped feature detection (grep pattern)"

# ── Test: Shipped feature WITHOUT acceptance file should be caught ──

PROJECT=$(scaffold_test_project "formal")
cd "$PROJECT"

# Create shipped feature in FEATURES.md with markdown bold format
cat >> spec/FEATURES.md << 'EOF'

---

## F-0088: Shipped Without Acceptance

**Status**: shipped
**Priority**: high
**Complexity**: low

**Description**: A shipped feature deliberately missing acceptance file.
EOF

# Do NOT create spec/acceptance/F-0088.md — this should trigger Check 2

git add -A
git commit -m "add shipped feature without acceptance" --quiet --no-verify

# Attempt a normal commit — Check 2 should catch the missing acceptance file
OUTPUT=$(attempt_commit "$PROJECT" 2>&1) && EXIT_CODE=0 || EXIT_CODE=$?

assert_exit_code 1 "$EXIT_CODE" "commit blocked when shipped feature lacks acceptance"
assert_output_contains "$OUTPUT" "F-0088\|acceptance\|BLOCKED\|Shipped features missing" \
    "Check 2 detects F-0088 missing acceptance file"
assert_output_not_contains "$OUTPUT" "No shipped features to check" \
    "Check 2 does NOT silently skip shipped features"

cleanup_test_project "$PROJECT"

# ── Test: Shipped feature WITH acceptance file should pass ──

PROJECT=$(scaffold_test_project "formal")
cd "$PROJECT"

cat >> spec/FEATURES.md << 'EOF'

---

## F-0077: Shipped With Acceptance

**Status**: shipped
**Priority**: high
**Complexity**: low

**Description**: A shipped feature with proper acceptance file.

**Acceptance**: See `spec/acceptance/F-0077.md`
EOF

cat > spec/acceptance/F-0077.md << 'EOF'
# F-0077

## Acceptance Criteria
- [x] Feature works
EOF

git add -A
git commit -m "add shipped feature with acceptance" --quiet --no-verify

OUTPUT=$(attempt_commit "$PROJECT" 2>&1) && EXIT_CODE=0 || EXIT_CODE=$?

# Check 2 specifically should pass — output should say "All shipped features have acceptance"
assert_output_contains "$OUTPUT" "All shipped features have acceptance\|shipped features" \
    "Check 2 passes when acceptance file exists"

cleanup_test_project "$PROJECT"
print_summary
