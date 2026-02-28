---
name: writing-tests
description: >
  Write and run tests for features or bug fixes. Use when user says "write
  tests", "add tests", "/test", "test this", "need tests for", "add coverage",
  or asks specifically for test creation.
  Do NOT use for: running existing tests only (just run them), implementing
  features (use implementing-features), fixing bugs (use fixing-bugs).
compatibility: "Requires Claude Code with shell access and test runners."
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep]
metadata:
  author: agentic-framework
  version: "${VERSION}"
---

# Writing Tests

Write tests that verify acceptance criteria and prevent regressions.

## Instructions

### Step 1: Understand What to Test

1. Read acceptance criteria from `spec/acceptance/F-XXXX.md` if available
2. Read the code to understand behavior and edge cases
3. Check `STACK.md` for test framework and conventions

### Step 2: Design Test Cases

For each acceptance criterion, identify:
- **Happy path**: Normal expected behavior
- **Edge cases**: Boundary values, empty inputs, large inputs
- **Error cases**: Invalid input, missing dependencies, failures

### Step 3: Write Tests

Follow the project's test patterns:
- Match existing test file naming conventions
- Use the same test framework
- Keep tests focused — one assertion per test where practical
- Use descriptive test names that read like specifications

### Step 4: Run and Verify

Run the tests:
```bash
# Run specific test file
# (use project's test runner — check STACK.md or package.json/pyproject.toml)
```

Ensure:
- All new tests pass
- No existing tests broken
- Coverage covers the acceptance criteria

## Examples

**Example 1: Tests for a new utility function**
User says: "Add tests for the parseConfig function"
Steps taken:
1. Read parseConfig implementation, understand inputs/outputs
2. Design cases: valid config, missing fields, malformed input, empty object
3. Write test file matching project conventions
4. Run tests — all pass
Result: 6 test cases covering happy path, edge cases, and errors.

**Example 2: Tests for acceptance criteria**
User says: "/test F-0125"
Steps taken:
1. Read spec/acceptance/F-0125.md — 4 criteria listed
2. Write one or more tests per criterion
3. Run tests — 3 pass, 1 fails (reveals incomplete implementation)
Result: "Tests written. 3 pass, 1 fails — AC-3 (empty input handling) not yet implemented."

## Troubleshooting

**Test runner not found**
Cause: Test framework not configured or not in PATH.
Solution: Check `STACK.md` for test configuration. Check package.json, pyproject.toml, or Makefile.

**Tests pass locally but fail in CI**
Cause: Environment differences (paths, versions, dependencies).
Solution: Check CI logs. Ensure test isolation (no shared state between tests).

## References

- For test strategy: see `references/test_strategy.md`
