---
name: completing-work
description: >
  Feature completion workflow: verify acceptance criteria, mark done, update
  specs, cleanup WIP. Use when the user indicates a feature is finished —
  e.g. "done", "complete", "finished", "merged", "PR merged", "shipped",
  "landed", "wrapped up", "ag done", "mark as done", "it's in", or any
  phrasing that means the work is complete. Match intent, not exact words.
  Do NOT use for: committing code (use committing-changes), starting new
  features (use implementing-features).
compatibility: "Requires Claude Code with shell access and ag commands."
allowed-tools: [Read, Edit, Bash, Glob, Grep]
metadata:
  author: agentic-framework
  version: "0.46.1"
---

# Completing Work

Verify acceptance criteria, mark features done, update specs, and cleanup.

## Instructions

### Step 0: Check Uncommitted Changes

Before completing, ensure all work is committed:

```bash
git status --porcelain
```

If there are uncommitted changes, commit first (`ag commit`) before proceeding. Uncommitted work gets lost in compressed context and is easy to forget.

### Step 1: Verify Acceptance Criteria

Read `.agentic/spec/acceptance/F-XXXX.md` and verify each criterion is met:

1. All criteria have passing tests
2. Documentation is updated
3. No known regressions

If any criteria are not met, list what remains and ask user how to proceed.

### Step 2: Complete WIP Tracking

```bash
bash .agentic/lib/tools/wip.sh complete
```

This clears the active WIP entry from `.agentic/session/AGENTS.json`.

In a worktree: commit and push from the worktree, run `wip.sh complete`, then `cd` back to the main worktree and run `ag done F-XXXX`. When `worktree_mode: always`, `ag done` auto-cleans the worktree.

### Step 2b: Verify Documentation Updated

Before marking shipped, verify documentation is current:

1. Run `bash .agentic/lib/tools/drift.sh --docs` to detect stale docs
2. Check that CONTEXT_PACK.md reflects any architecture changes
3. If `docs_gate: blocking` in STACK.md, `ag done` enforces this automatically
4. For framework development: verify all instruction files updated (see CLAUDE.md § Framework Development)

**Do not mark shipped with stale documentation.** Code + docs = done.

### Step 3: Update Feature Status

```bash
bash .agentic/lib/tools/feature.sh F-XXXX status shipped
```

### Step 4: Update Artifacts

```bash
bash .agentic/lib/tools/journal.sh "F-XXXX Complete" "Project can now [capability]" "Next: [what's next]" "None" --why "Problem solved"
bash .agentic/lib/tools/status.sh focus "F-XXXX shipped, ready for next task"
```

### Step 4b: Advance Backlog

If `.agentic/BACKLOG.json` exists and the completed feature is at position 0:

```bash
bash .agentic/lib/tools/backlog.sh done
```

This removes the completed item and promotes the next item to position 0. The command is a no-op if the completed feature is not at position 0. Include BACKLOG.json in the next commit.

### Step 4c: Flush State (including VERSION)

`ag done` auto-bumps VERSION (patch) and flushes state files (STATUS.md, JOURNAL.md,
BACKLOG.json, FEATURES.md status, VERSION, etc.) directly to main when on main.
For minor/major bumps, edit VERSION manually before running `ag done`.

If in a worktree, this step is skipped — state files will be flushed after returning to main.

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
