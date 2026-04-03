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

## What's Enforced Automatically
- **TDD nudge** → on-code-edit warns if source files edited before test files this session
- **Test existence gate** → PreToolUse warns/blocks source edits without tests (formal, after first edit)
- **Spec-first** → PreToolUse blocks code edits without spec (formal)
- **Contract protection** → Warns if fix affects shipped contract assertions

Steps:
1. **Write a failing test FIRST** — reproduce the bug before touching code (the framework nudges you if you skip this)
2. **Localize** — trace the code path with Grep/Read, observe actual behavior
3. **Fix the root cause** — minimal, scoped change (not the symptom)
4. **Verify** — failing test now passes, full suite has no regressions
5. **Hand off** to `committing-changes` workflow (do not commit directly)

Key rules:
- Do NOT jump to fixing code before reproducing the bug.
- When the user corrects your approach: `ag intel remember "what they said" --context "what you were doing"`
- After fixing, grep `spec/contracts/` for assertions related to the changed behavior. If any are affected, **STOP** — present them to the user and wait for approval before modifying any contract or test. Contracts protect shipped behavior; silently updating them to match new code defeats that protection.
