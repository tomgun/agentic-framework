---
name: committing-changes
description: >
  Pre-commit quality gates, branch management, and PR creation.
  Use when user says "commit", "push", "ship", "finalize", "create PR",
  "ag commit", "ready to commit", or wants to save completed work.
  Do NOT use for: writing code (use implementing-features), running tests
  (use writing-tests), reviewing code (use reviewing-code).
compatibility: "Requires Claude Code with shell access and git."
allowed-tools: [Bash, Read, Edit, Glob, Grep]
metadata:
  author: agentic-framework
  version: "0.61.1"
---

# Committing Changes

Pre-commit quality gates and branch management with human approval.

## Instructions

### Step 1: Check WIP Status

```bash
bash .agentic/lib/tools/wip.sh check
```

If `wip.sh check` reports active work (tracked in `.agentic/session/AGENTS.json`), complete it first:
```bash
bash .agentic/lib/tools/wip.sh complete
```

**Never commit while WIP is active** — it indicates incomplete work.

### Step 2: Branch Check

```bash
git branch --show-current
```

- If on `main` or `master`: **STOP.** Create a feature branch first:
  `git checkout -b feature/description`
- If on feature branch: proceed.
- Only push to main if user explicitly says "push to main directly".

### Step 3: Update Artifacts

Before committing, update the durable artifacts using token-efficient scripts:

```bash
bash .agentic/lib/tools/journal.sh "Topic" "Outcome for the project" "Next steps" "Blockers" --why "Problem solved"
bash .agentic/lib/tools/status.sh focus "Current state"
```

**Journal entries must be outcome-focused** — describe what the project can do now, not what files were edited.
- Good: "Agents can now scope context to a single component via --component flag"
- Bad: "Fixed indentation in query_features.py, removed dead code in components.py"

**Never edit JOURNAL.md or STATUS.md directly** — always use the scripts.

### Step 4: Quality Gates

Run these checks:
1. Tests pass (run the project's test suite)
2. No untracked files that should be committed (`git status`)
3. No secrets or credentials in staged files
4. Changes are scoped — no unrelated modifications

If the project has a validation script:
```bash
bash tests/validate_framework.sh
```

### Step 5: Show Changes to Human

```bash
git diff --stat
git diff
```

Present a summary of changes. **Interactive sessions**: wait for human approval before committing. **Autonomous/non-interactive sessions** (e.g. `--print` mode, `ag auto` workflows): commit directly, using `review_commit` setting to determine review level (F-0203).

### Step 6: Commit and PR

After human approves:
1. Stage files: `git add <specific-files>` (not `git add .`)
   Include JOURNAL.md, STATUS.md, and CONTRIBUTIONS.md — they document the work.
   Do NOT include VERSION, BACKLOG.json, FEATURES.md status — these are
   updated post-merge by `ag done`.
2. Commit with descriptive message
3. Create PR if on feature branch: `gh pr create --title "..." --body "..."`
4. Switch to main, log PR in HUMAN_NEEDED.md, and flush (so it doesn't leave a dirty working tree):
   ```bash
   git checkout main -q
   bash .agentic/lib/tools/blocker.sh add "PR #N: Description" "review" "Details"
   ag flush
   ```
   Stay on main — the feature branch work is done (it's in the PR now).

### Step 7: Post-Merge (run automatically — don't wait for user)

When you merge a PR (via `gh pr merge`) or the user says "merge", IMMEDIATELY
run `ag done F-XXXX` on main as the next step. Do not suggest it — just do it.
This bumps VERSION, updates FEATURES.md status, advances the backlog, and
flushes state to main. The post-merge flow is part of the merge, not a
separate action.

## Examples

**Example 1: Committing a completed feature**
User says: "commit this"
Steps taken:
1. Check WIP — not active, good
2. Branch check — on `feature/dark-mode`, good
3. Update journal and status
4. Run tests — all pass
5. Show `git diff --stat` to user: "3 files changed, 85 insertions"
6. User approves, commit and create PR
Result: PR #42 created, logged in HUMAN_NEEDED.md.

**Example 2: WIP still active**
User says: "let's ship this"
Steps taken:
1. Check WIP — active WIP found in AGENTS.json for F-0125
2. **BLOCK**: "Work is still in progress for F-0125. Complete it first with `wip.sh complete`, or should I mark it complete now?"
Result: User confirms completion, then proceed with commit flow.

## Troubleshooting

**Error: On main branch**
Cause: No feature branch was created before coding.
Solution: Create branch now: `git checkout -b feature/description`. Changes are preserved.

**Error: Tests fail**
Cause: Code has regressions or incomplete implementation.
Solution: Fix failing tests before committing. Do not skip tests.

**Error: WIP still active**
Cause: Feature work not formally completed.
Solution: Run `bash .agentic/lib/tools/wip.sh complete` after verifying all acceptance criteria are met.

## References

- For pre-commit checklist: see `references/before_commit.md`
