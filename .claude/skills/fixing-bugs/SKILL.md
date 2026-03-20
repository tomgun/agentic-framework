---
name: fixing-bugs
description: >
  Bug fix workflow with failing-test-first approach. Use when user says "fix",
  "debug", "repair", "troubleshoot", "there's a bug", "this is broken",
  "not working", or describes unexpected behavior.
  Do NOT use for: new features (use implementing-features), refactoring
  without a bug (use implementing-features), writing tests for existing
  features (use writing-tests).
compatibility: "Requires Claude Code with shell access."
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep, Agent]
metadata:
  author: agentic-framework
  version: "0.62.0"
---
# Fixing Bugs

Run `ag start` with a debug workflow — write a failing test first, then fix.

Steps:
1. **Write a failing test FIRST** — reproduce the bug before touching code
2. **Localize** — trace the code path with Grep/Read, observe actual behavior
3. **Fix the root cause** — minimal, scoped change (not the symptom)
4. **Verify** — failing test now passes, full suite has no regressions
5. **Hand off** to `committing-changes` workflow (do not commit directly)

Key rule: Do NOT jump to fixing code before reproducing the bug.
