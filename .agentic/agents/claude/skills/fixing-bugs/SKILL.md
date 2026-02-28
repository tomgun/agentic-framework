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
  version: "${VERSION}"
---

# Fixing Bugs

Systematic bug fixing with failing-test-first methodology.

## Instructions

### Step 1: Write a Failing Test FIRST

Before any fix, create a test that reproduces the bug:

1. Understand what the expected behavior should be
2. Write a test that demonstrates the current (broken) behavior
3. Run the test to confirm it fails
4. This becomes the regression guard

If a test is not possible (e.g., infrastructure/config issue), write a minimal reproduction script or document exact steps to reproduce.

**Do NOT jump to fixing code before reproducing the bug.**

### Step 2: Localize the Bug

Follow first principles debugging:

1. **Reproduce** — run the failing test, confirm the bug
2. **Localize** — identify the boundary where behavior diverges from expectation
3. **Hypothesize** — state assumptions explicitly
4. **Experiment** — change one variable at a time

Use `Grep` and `Read` to trace the code path. Do NOT guess — observe the actual behavior.

### Step 3: Fix the Root Cause

- Fix the root cause, not the symptom
- Keep the fix minimal and scoped — no unrelated changes
- If the fix requires more than 5-10 files, it might be a feature, not a bug fix

### Step 4: Verify

1. Run the failing test — it should now pass
2. Run the full test suite — no regressions
3. Update `STATUS.md` if the bug was tracked:
   ```bash
   bash .agentic/tools/status.sh focus "Fixed: description"
   ```

### Step 5: Hand Off to Commit Workflow

Do not commit directly. Let the `committing-changes` workflow handle pre-commit gates.

## Examples

**Example 1: Function returns wrong value**
User says: "The calculate_total function is off by one"
Steps taken:
1. Write test: `test_calculate_total_edge_case` that asserts correct value
2. Run test — fails, confirming the bug
3. Read the function, find the off-by-one in a loop boundary
4. Fix: change `< length` to `<= length`
5. Run test — passes. Run full suite — no regressions.
Result: Bug fixed with regression test in place.

**Example 2: Script fails silently**
User says: "ag sync isn't detecting stale files"
Steps taken:
1. Write test that runs sync.sh with a known stale file, asserts detection
2. Test fails — confirms the bug
3. Trace sync.sh code, find missing file extension in glob pattern
4. Fix the pattern, test passes
Result: Bug fixed, edge case covered by new test.

## Troubleshooting

**Cannot write a failing test**
Cause: The bug may be in infrastructure, config, or environment.
Solution: Write a reproduction script instead. Document exact steps. After fix, add a test if possible.

**Fix requires >10 files**
Cause: This is likely a design issue, not a simple bug.
Solution: Treat as a feature (use implementing-features skill). Create an F-XXXX spec with acceptance criteria.

## References

- For debugging methodology: see `references/debugging_playbook.md`
