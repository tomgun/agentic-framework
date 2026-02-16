#!/usr/bin/env bash
# S01: core.hooksPath configured after scaffold
# Verifies that install.sh sets git to use .agentic/hooks
set -euo pipefail
source "$(dirname "$0")/../lib/helpers.sh"

section_header "S01: core.hooksPath configured after scaffold"

PROJECT=$(scaffold_test_project "discovery")
cd "$PROJECT"

# Assert core.hooksPath is set
HOOKS_PATH=$(git config core.hooksPath 2>/dev/null || echo "")
if [[ "$HOOKS_PATH" == ".agentic/hooks" ]]; then
    pass_test "core.hooksPath == .agentic/hooks"
else
    fail_test "core.hooksPath == .agentic/hooks" "got '$HOOKS_PATH'"
fi

# Assert pre-commit hook file exists
assert_file_exists ".agentic/hooks/pre-commit" "pre-commit hook file exists"

# Assert it's executable
assert_file_executable ".agentic/hooks/pre-commit" "pre-commit hook is executable"

# Assert pre-commit-check.sh exists
assert_file_exists ".agentic/hooks/pre-commit-check.sh" "pre-commit-check.sh exists"

cleanup_test_project "$PROJECT"
print_summary
