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
  version: "0.62.0"
---
# Writing Tests

Run `ag verify F-XXXX` to check test coverage and run the test suite.

Steps:
1. Read contract assertions from `.agentic/spec/contracts/F-XXXX.yaml`
2. Check `STACK.md` for test framework and conventions
3. Design test cases: happy path, edge cases, error cases
4. Write tests matching project patterns
5. Run tests and verify all pass with no regressions

Key rules:
- `ag verify F-XXXX` — run tests and check AC coverage
- When the user corrects your approach: `ag intel remember "what they said" --context "what you were doing"`
