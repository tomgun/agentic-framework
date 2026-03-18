---
name: completing-work
description: >
  Feature completion workflow: verify acceptance criteria, mark done, update
  specs, cleanup WIP. Use when user says "done", "complete", "finished",
  "merged", "PR merged", "shipped", "landed", "wrapped up", "ag done",
  "mark as done", "it's in", or indicates work is finished. Also triggered
  automatically after merging a PR. Do NOT use for: committing code (use
  committing-changes), starting new features (use implementing-features).
compatibility: "Requires Claude Code with shell access and ag commands."
allowed-tools: [Read, Edit, Bash, Glob, Grep]
metadata:
  author: agentic-framework
  version: "0.62.0"
---

# Completing Work

Verify acceptance criteria, mark features done, update specs, and cleanup.

## Instructions

### Step 1: Verify and Check Off Acceptance Criteria

Read `.agentic/spec/acceptance/F-XXXX.md` and verify each criterion is met:

1. All criteria have passing tests
2. Documentation is updated
3. No known regressions

As you verify each criterion, check it off in the file (`- [ ]` → `- [x]`).
If any criteria are not met, list what remains and ask user how to proceed.

### Step 2: Complete WIP Tracking

```bash
bash .agentic/lib/tools/wip.sh complete
```

This clears the active WIP entry from `.agentic/session/AGENTS.json`.

### Step 3: Update Feature Status

```bash
bash .agentic/lib/tools/feature.sh F-XXXX status shipped
```

### Step 3b: Bump VERSION and Flush

`ag done` auto-bumps VERSION (patch) and flushes state to main when on main.
For minor/major bumps, edit VERSION manually before running `ag done`.

### Step 4: Update Artifacts

```bash
bash .agentic/lib/tools/journal.sh "F-XXXX Complete" "Project can now [capability]" "Next: [what's next]" "None" --why "Problem solved"
bash .agentic/lib/tools/status.sh focus "F-XXXX shipped, ready for next task"
```

### Step 5: Flush Pending Items

Check for any pending tasks captured during implementation:

```bash
bash .agentic/lib/tools/todo.sh list
```

Surface any items that should be addressed before moving on.

### Step 6: Retrospective Check

After shipping, check if a retrospective is due:

```bash
bash .agentic/lib/tools/retro_check.sh 2>/dev/null
```

If exit code is 1 (due): inform user "Retrospective is due! Run `ag retro` when ready."

## Examples

**Example 1: Completing a feature**
User says: "I think we're done with F-0125"
Steps taken:
1. Read .agentic/spec/acceptance/F-0125.md — 4 criteria, all verified
2. Run `wip.sh complete` — WIP cleared
3. Run `feature.sh F-0125 status shipped`
4. Update journal and status
5. Check TODO list — 2 follow-up items captured
Result: "F-0125 marked as shipped. 2 TODO items to address: [list]"

**Example 2: Criteria not fully met**
User says: "done"
Steps taken:
1. Read acceptance criteria — 3 of 4 met, missing: edge case test
2. Report: "3 of 4 acceptance criteria met. Missing: edge case test for empty input. Should I write that test, or mark as shipped anyway?"
Result: User decides to add the test first.

## Troubleshooting

**Error: No active WIP found**
Cause: Work was never formally started or already completed.
Solution: Proceed with status updates. WIP tracking is a guard, not a blocker for completion.

**Error: Feature ID not found in FEATURES.md**
Cause: Feature was implemented without a spec entry.
Solution: Add the feature to .agentic/spec/FEATURES.md retroactively before marking shipped.

## References

- For completion checklist: see `references/feature_complete.md`
