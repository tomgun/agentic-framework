---
name: fixing-bugs
description: >
  Bug fix workflow with failing-test-first approach. Use when user says "fix",
  "debug", "repair", "troubleshoot", "there's a bug", "this is broken",
  "not working", or describes unexpected behavior.
  Do NOT use for: new features (use implementing-features), refactoring
  without a bug (use implementing-features), writing tests for existing
  features (use writing-tests).
compatibility: "Requires Cursor Agent mode with shell access."
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep, Agent]
metadata:
  author: agentic-framework
  version: "${VERSION}"
---
# Fixing Bugs

Run `ag start` with a debug workflow — write a failing test first, then fix.

Steps:
1. **Write a failing test FIRST** — reproduce the bug before touching code
   If `development_mode: tdd`: `bash .agentic/lib/tools/wip.sh checkpoint --phase RED "test reproducing [bug] fails"`
2. **Localize** — trace the code path with Grep/Read, observe actual behavior
3. **Fix the root cause** — minimal, scoped change (not the symptom)
   If `development_mode: tdd`: `bash .agentic/lib/tools/wip.sh checkpoint --phase GREEN "[bug] test now passes"`
4. **Verify** — failing test now passes, full suite has no regressions
5. **Hand off** to `committing-changes` workflow (do not commit directly)

Key rules:
- Do NOT jump to fixing code before reproducing the bug.
- In TDD mode, the PreToolUse hook blocks source edits until a RED checkpoint exists.
- After fixing, grep `spec/contracts/` for assertions related to the changed behavior. If any are affected, **STOP** — present them to the user and wait for approval before modifying any contract or test. Contracts protect shipped behavior; silently updating them to match new code defeats that protection.
