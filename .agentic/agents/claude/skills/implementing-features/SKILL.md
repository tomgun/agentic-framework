---
name: implementing-features
description: >
  Implements features using acceptance-driven workflow with structural gates.
  Use when user says "build", "implement", "add feature", "create [thing]",
  "implement F-XXXX", "ag implement", or describes new functionality to build.
  Do NOT use for: one-line fixes (use fixing-bugs), writing tests only
  (use writing-tests), code review (use reviewing-code), documentation-only
  changes (use updating-documentation).
compatibility: "Requires Claude Code with shell access and ag commands."
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep, Agent]
metadata:
  author: agentic-framework
  version: "${VERSION}"
---

# Implementing Features

Acceptance-driven feature implementation with structural enforcement gates.

## Instructions

### Step 1: Verify Acceptance Criteria Exist

```bash
bash .agentic/tools/wip.sh check
```

Check for `spec/acceptance/F-XXXX.md`. If it does not exist:

1. Draft acceptance criteria using `.agentic/spec/acceptance.template.md`
2. Include a `## Tests` section — tests are part of the feature definition
3. Show to user for approval before proceeding
4. Create the file at `spec/acceptance/F-XXXX.md`

If no feature ID exists yet, create one in `spec/FEATURES.md` first.

**Do NOT write any code until acceptance criteria exist.**

### Step 1b: Spec Analysis (advisory)

Check if spec analysis is enabled:
1. Read `spec_analysis` setting from STACK.md (default: on for formal, off for discovery)
2. If enabled, run: `bash .agentic/tools/spec-analyze.sh F-XXXX`
3. Review findings but proceed regardless (advisory, not blocking)
4. If any HIGH/CRITICAL findings, mention them to the user before coding

### Step 2: Scope Check

Verify the feature is small batch (max 5-10 files). If larger, break into smaller features first and confirm with user.

### Step 3: Start WIP Tracking

```bash
bash .agentic/tools/wip.sh start F-XXXX "Description" "file1 file2"
```

This creates `.agentic-state/WIP.md` — a lock that prevents premature commits.

### Step 4: Implement

1. Read and understand acceptance criteria fully
2. Check `CONTEXT_PACK.md` for "Where to look first"
3. Check `STACK.md` for `development_mode` (standard or tdd)
4. Implement in small increments:
   - Write code following `references/programming_standards.md`
   - Add tests that verify acceptance criteria
   - Run tests after each significant change
5. Checkpoint progress periodically:
   ```bash
   bash .agentic/tools/wip.sh checkpoint "Completed step X"
   ```

### Step 5: Checkpoint Validation (priority-grouped ACs)

When acceptance criteria have priority groups (P1/P2):
1. Complete all P1 ACs first
2. Run tests for P1 group
3. Report to user: "P1 complete — core feature works. Proceed to P2?"
4. Only proceed to P2 after user confirmation

This ensures MVP is solid before adding enhancements.

### Step 6: Verify Before Declaring Done

- All acceptance criteria met (P1 at minimum, P2 if confirmed)
- Tests pass
- No unrelated files changed
- Code follows project conventions

Then hand off to the `committing-changes` workflow (do NOT commit directly).

## Examples

**Example 1: Implementing a new CLI command**
User says: "Add an `ag sync` command"
Steps taken:
1. Check `spec/acceptance/F-0125.md` exists — it does, read criteria
2. Start WIP: `wip.sh start F-0125 "ag sync command" "ag .agentic/tools/sync.sh"`
3. Read CONTEXT_PACK.md, find existing ag commands in `ag` script
4. Implement sync.sh following existing tool patterns
5. Add test in tests/
6. Checkpoint: `wip.sh checkpoint "sync.sh working, tests pass"`
Result: Feature implemented, tests passing, ready for commit workflow.

**Example 2: User describes functionality without a feature ID**
User says: "Build a dark mode toggle"
Steps taken:
1. No F-XXXX exists — create F-0150 in spec/FEATURES.md
2. Draft acceptance criteria, show to user for approval
3. Create spec/acceptance/F-0150.md
4. Start WIP, implement, test
Result: Feature tracked from spec through implementation.

## Troubleshooting

**Error: wip.sh exits "WIP already active"**
Cause: Previous work was interrupted or not completed.
Solution: Run `bash .agentic/tools/wip.sh check` to see what's in progress. Either complete it (`wip.sh complete`) or abandon it (`wip.sh abandon`) before starting new work.

**Error: No acceptance criteria found**
Cause: Feature work attempted without spec.
Solution: Create `spec/acceptance/F-XXXX.md` first. Use the template at `.agentic/spec/acceptance.template.md`.

**Error: Scope too large (>10 files)**
Cause: Feature is too big for one batch.
Solution: Break into 3-5 smaller features, each touching max 5-10 files. Confirm decomposition with user.

## References

- For implementation checklist: see `references/feature_implementation.md`
- For pre-implementation gates: see `references/feature_start.md`
- For code standards: see `references/programming_standards.md`
