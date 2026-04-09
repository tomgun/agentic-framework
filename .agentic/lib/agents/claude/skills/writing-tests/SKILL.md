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

Run `ag verify F-XXXX` to check test coverage and run the test suite.

Steps:
1. Read contract assertions from `.agentic/spec/contracts/F-XXXX.yaml`
2. Check `STACK.md` for test framework and conventions
3. Design test cases: happy path, edge cases, error cases
4. Write tests matching project patterns
5. Run tests — in TDD mode, confirm they **fail** (RED phase)
   If `development_mode: tdd`: `bash .agentic/lib/tools/wip.sh checkpoint --phase RED "tests for [AC] fail as expected"`
6. After implementation makes tests pass:
   If `development_mode: tdd`: `bash .agentic/lib/tools/wip.sh checkpoint --phase GREEN "[AC] tests pass"`

Key command:
- `ag verify F-XXXX` — run tests and check AC coverage
