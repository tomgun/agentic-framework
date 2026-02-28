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
  version: "${VERSION}"
---

# Committing Changes

Pre-commit quality gates and branch management with human approval.

## Instructions

### Step 1: Check WIP Status

```bash
bash .agentic/tools/wip.sh check
```

If `.agentic-state/WIP.md` exists, work is still in progress. Complete it first:
```bash
bash .agentic/tools/wip.sh complete
```

**Never commit while WIP.md exists** — it indicates incomplete work.

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
bash .agentic/tools/journal.sh "Topic" "What was done" "Next steps" "Blockers"
bash .agentic/tools/status.sh focus "Current state"
```

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

Present a summary of changes. **Never auto-commit.** Wait for human approval.

### Step 6: Commit and PR

After human approves:
1. Stage files: `git add <specific-files>` (not `git add .`)
2. Commit with descriptive message
3. Create PR if on feature branch: `gh pr create --title "..." --body "..."`
4. Bump VERSION (at least patch)
5. Log PR in HUMAN_NEEDED.md for review tracking:
   ```bash
   bash .agentic/tools/blocker.sh add "PR #N: Description" "review" "Details"
   ```

### Step 7: Post-Merge Tagging

After a PR is merged, tag the release:
```bash
git tag v$(cat VERSION) && git push origin v$(cat VERSION)
```

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
1. Check WIP — `.agentic-state/WIP.md` exists for F-0125
2. **BLOCK**: "Work is still in progress for F-0125. Complete it first with `wip.sh complete`, or should I mark it complete now?"
Result: User confirms completion, then proceed with commit flow.

## Troubleshooting

**Error: On main branch**
Cause: No feature branch was created before coding.
Solution: Create branch now: `git checkout -b feature/description`. Changes are preserved.

**Error: Tests fail**
Cause: Code has regressions or incomplete implementation.
Solution: Fix failing tests before committing. Do not skip tests.

**Error: WIP.md still exists**
Cause: Feature work not formally completed.
Solution: Run `bash .agentic/tools/wip.sh complete` after verifying all acceptance criteria are met.

## References

- For pre-commit checklist: see `references/before_commit.md`
