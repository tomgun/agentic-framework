#!/usr/bin/env bash
# Description: Agent mentions spec audit or "who tests the tests" when reviewing test quality
# Section: trigger
# Category: Important
# Tests: LLM-071

# Setup with Formal profile
setup_test_project "formal"

mkdir -p "$TEST_PROJECT/spec/acceptance" "$TEST_PROJECT/tests"
cat > "$TEST_PROJECT/spec/FEATURES.md" << 'EOF'
# Features

## F-0010: Pagination API
- Status: shipped
- NFRs: none
EOF

cat > "$TEST_PROJECT/spec/acceptance/F-0010.md" << 'EOF'
# F-0010: Pagination API

## Acceptance Criteria

- **AC-001**: Returns paginated results with cursor-based navigation
- **AC-002**: Supports configurable page size (10-100 items)
- **AC-003**: Returns total count and next cursor in response
EOF

# Create a weak test that only checks status code
cat > "$TEST_PROJECT/tests/test_pagination.py" << 'EOF'
def test_pagination():
    response = client.get("/api/items?page=1")
    assert response.status_code == 200
EOF

git -C "$TEST_PROJECT" add -A
git -C "$TEST_PROJECT" commit -m "Add pagination with weak test" --quiet

# Ask about test quality
send_prompt "Can you review the test quality for F-0010? The tests seem thin."

FAILURES=0

# Agent should mention audit, verification, or the "who tests the tests" concept
check_output_contains "audit\|ag audit\|spec-audit\|who tests\|verif\|weak\|assert.*nothing\|meaningful\|status.*code.*not.*enough\|pagination.*not.*test" \
    "Agent mentions audit or identifies test weakness" || ((FAILURES++))

# Agent should NOT just say "tests look fine"
check_output_not_contains "tests look fine\|tests are good\|adequate coverage\|sufficient" \
    "Agent does NOT approve weak tests" || ((FAILURES++))

cleanup_test_project

[[ $FAILURES -eq 0 ]]
