# Plan: F-0196 — Fluent State File Commits (`ag flush`)

**Status**: APPROVED
**Revision**: 3 (approved after dialectical review iteration 3)

## Context

State files (BACKLOG.json, STATUS.md, TODO.md, JOURNAL.md, FEATURES.md status, HUMAN_NEEDED.md, CONTRIBUTIONS.md) are updated frequently via token-efficient tools but require a full PR to commit when `git_workflow: pull_request`. This creates friction: state changes accumulate dirty, get lost across sessions, or require `--no-verify` hacks. We just experienced this firsthand — F-0184 was shipped but backlog/FEATURES.md weren't updated because the previous session didn't commit state changes.

**Goal**: One command (`ag flush`) commits + pushes state-only changes directly to main without a PR. Code changes still require PRs.

**Naming**: `flush` (not `save`) to avoid collision with the committing-changes skill trigger word "save". `flush` reads naturally: "flush pending state to main."

## Design: Self-Contained Script with `--no-verify`

The simplest correct approach: `state-commit.sh` does ALL validation itself and commits with `--no-verify`, leaving the pre-commit hook untouched. The script IS the safety layer.

> **Why `--no-verify` is safe here (and NOT a precedent):** This script enforces its own
> validation that is *stricter* than the pre-commit hook (hardcoded allowlist, branch check,
> diff-level FEATURES.md validation). The hook is redundant, not bypassed. Future tool
> authors should NOT cite this as justification for `--no-verify` — the conditions are:
> (1) hardcoded file allowlist, (2) no user-editable configuration, (3) self-contained
> validation that rejects on any violation. If your script doesn't meet all three, use the hook.

### New Files

1. **`.agentic/lib/tools/state-commit.sh`** — the engine (~120 lines):

   **Hardcoded allowlist** (security boundary, not user-editable):
   ```
   .agentic/STATUS.md
   .agentic/TODO.md
   .agentic/HUMAN_NEEDED.md
   .agentic/BACKLOG.json
   .agentic/journal/JOURNAL.md
   .agentic/CONTRIBUTIONS.md
   ```

   **Removed from allowlist (revision 2):** `VERSION` — it's a release artifact with
   downstream implications (upgrade.sh, CHANGELOG), not a state file. VERSION changes
   go through PRs.

   Note: **FEATURES.md excluded from base allowlist.** `feature.sh` status changes go
   through `ag flush` only via a dedicated `--features` flag that validates the diff is
   status-line-only (every added/removed line must match the pattern `**Status**:`).
   This prevents prose changes from bypassing PR review.

   **Algorithm**:
   ```
   ag flush [--dry-run | --check | --features]

   1. Branch + worktree check:
      a. Get branch via git rev-parse --abbrev-ref HEAD — exact match "main" or "master"
      b. Detect worktree: compare git rev-parse --show-toplevel with
         git worktree list --porcelain (primary worktree path). If cwd is not
         the primary worktree, reject even if branch is main.
      c. Reject with clear message if either check fails.

   2. Check remote exists: git remote get-url origin 2>/dev/null
      If no remote: set NO_REMOTE=1 (skip pull and push later, warn at end)

   3. Detect dirty files matching hardcoded allowlist (git status --porcelain)

   4. If --features: also include .agentic/spec/FEATURES.md, but validate
      diff is status-only (every +/- content line must match `**Status**:`)
      Reject if any non-Status content line changed.

   5. REJECT if any non-allowlist files are staged (mixed commit protection)

   6. If no dirty state files: exit 0 "Nothing to flush"

   7. If --dry-run: show what would be committed and exit

   8. If --check: exit 0 (dirty exists) or exit 1 (clean) — used by dashboard

   9. Content validation: if BACKLOG.json is dirty, validate it's valid JSON
      (python3 -m json.tool .agentic/BACKLOG.json > /dev/null)

   10. Multi-agent advisory: check agents_helpers.py count-others (warn, don't block)

   11. If remote exists: git pull --rebase origin main
       On conflict: abort with "State conflict on <file>. Resolve manually, then re-run ag flush"

   12. git add <each dirty allowlist file>

   13. git commit --no-verify -m "chore(state): update <file1>, <file2>"

   14. If remote exists: git push origin main
       On push failure: git reset --soft HEAD~1 (preserves working tree changes)
       Abort with: "Another agent pushed first. Re-run: ag flush"

   15. Print summary. If NO_REMOTE: warn "committed locally but not pushed (no remote)"
   ```

   **Key: `--no-verify` is safe here because the script enforces its own gates:**
   - Allowlist containment (stricter than file-level — FEATURES.md gets diff-level validation)
   - Branch + worktree check (primary main checkout only)
   - No code files can sneak in
   - Content validation for structured files (JSON)
   - Collision detection + graceful push-failure recovery (`git reset --soft HEAD~1`)

### Modified Files

2. **`.agentic/lib/tools/ag.sh`** — add `flush` subcommand:
   ```bash
   flush) bash "$SCRIPT_DIR/state-commit.sh" "${@:2}" ;;
   ```
   Add to both discovery and formal help text.

3. **`.agentic/lib/tools/dashboard.sh`** — show dirty state count in health section:
   ```
   ⚠ 3 state files uncommitted. Run: ag flush
   ```
   Use `state-commit.sh --check` to detect. Lightweight — only checks `git status`
   against the allowlist, no git operations beyond `git status --porcelain`.

4. **`.claude/skills/completing-work/SKILL.md`** — after Step 4b (backlog advance), add Step 4c:
   ```
   ### Step 4c: Flush State
   If on main (not in a worktree), flush state files:
   ```bash
   ag flush --features
   ```
   If in a worktree, state files will be flushed after returning to main.
   ```

   **R2 justification**: State-only commits during `ag done` are considered part of
   the human-approved completion flow. The user explicitly invoked `ag done`, which
   encompasses all completion steps including state persistence. `ag flush` within
   this flow is not auto-commit — it's a sub-step of an explicitly requested workflow.

5. **`.claude/skills/committing-changes/SKILL.md`** — update Step 6 to note:
   ```
   State files (BACKLOG.json, STATUS.md, etc.) can be committed separately
   via `ag flush` — no need to include them in feature PRs.
   ```

6. **Instruction files** — add `ag flush` to quick commands and trigger rules:
   - CLAUDE.md template + root CLAUDE.md: add to Quick Commands
   - memory-seed.md: (a) add trigger "When state files are dirty after a workflow step
     (ag done, backlog changes, feature status updates), run `ag flush` if on main";
     (b) update the `--no-verify` prohibition to carve out the `ag flush` exception:
     "Never bypass gates (`--no-verify`) — except `ag flush` which uses `--no-verify`
     with its own stricter validation (see state-commit.sh header comment)."
   - agent_operating_guidelines.md, auto_orchestration.md: mention `ag flush`
   - .cursorrules, copilot-instructions, codex-instructions: add to command list
   - DEVELOPER_GUIDE.md, HOW_IT_WORKS.md: document the feature

### What We DON'T Do (Simplifications)

- **No pre-commit hook modification** — the hook stays untouched. `--no-verify` means the hook never fires for `ag flush`. Manual `git commit` on main still blocked by Gate 11 (correct behavior — `ag flush` is the blessed path).
- **No separate allowlist conf file** — hardcoded in script. The allowlist is a security boundary; editability weakens it.
- **No profiles.conf setting** — `git_workflow: direct` users don't need it (they can commit directly). No separate toggle.
- **No local extension mechanism** — ship without it, add if users request.
- **No VERSION in allowlist** — VERSION is a release artifact, not state. Goes through PRs.

## Safety Properties

| Property | How enforced |
|----------|-------------|
| No code bypasses PR | Hardcoded allowlist — ANY non-allowlist file → reject entire commit |
| FEATURES.md prose safe | Only allowed via `--features` flag with diff-level validation (status lines only) |
| Structured file integrity | BACKLOG.json validated as valid JSON before commit |
| Auditable | `chore(state):` prefix in git log; `--dry-run` flag |
| Multi-agent safe | Pulls before commit; push failure → `git reset --soft HEAD~1` + abort with clear message |
| No auto-commit | `ag flush` is explicit — tools don't auto-commit. In completing-work skill, it's a sub-step of the human-approved `ag done` flow. |
| Worktree-safe | Rejected from non-primary worktrees via `git worktree list` comparison |
| Hook integrity preserved | Pre-commit hook untouched; `--no-verify` documented as narrow exception, not precedent. memory-seed updated with explicit carve-out. |

## Edge Cases

| Scenario | Handling |
|----------|---------|
| Mixed stage (state + code) | Rejected — error shows which files are non-allowlist |
| Merge conflict on pull | Abort with: "State conflict on <file>. Resolve manually, then re-run ag flush" |
| Push fails (non-fast-forward) | `git reset --soft HEAD~1`, abort with: "Another agent pushed first. Re-run: ag flush" |
| No remote | Commit locally, skip pull+push, warn: "committed locally but not pushed (no remote)" |
| `git_workflow: direct` | Works but prints "tip: with direct workflow, regular commits work too" |
| No dirty state | Clean exit: "Nothing to flush" |
| FEATURES.md prose edit + `ag flush` (no --features) | FEATURES.md not staged (not in base allowlist). No risk. |
| FEATURES.md prose edit + `ag flush --features` | Diff validation rejects: "FEATURES.md has non-status changes. Use a PR." |
| Concurrent agents both flush | Agent B's pull gets Agent A's commit. If same file changed → rebase conflict → abort. If push fails → reset --soft + retry message. |
| Partial state (only STATUS.md dirty) | Only STATUS.md staged and committed. Other files untouched. |
| Hooks not installed | Irrelevant — `ag flush` uses `--no-verify` and does its own validation |
| From worktree (even if on main) | Rejected via worktree list comparison. Skill says: "state files will be flushed after returning to main" |
| Broken BACKLOG.json | JSON validation catches it before commit: "BACKLOG.json is not valid JSON. Fix before flushing." |
| Detached HEAD | Branch check returns "HEAD", doesn't match main/master → rejected |
| Branch named `main-v2` | Exact match only — rejected correctly |
| No remote + pull step | Remote checked before pull (step 2). If no remote, pull is skipped entirely. |

## Verification

1. `bash tests/validate_framework.sh` passes
2. `ag flush --dry-run` shows correct state files
3. `ag flush` commits + pushes to main with `git_workflow: pull_request` active
4. Stage a .py file, run `ag flush` → rejected
5. Edit FEATURES.md prose, run `ag flush --features` → rejected (non-status change)
6. Edit FEATURES.md status only via `feature.sh`, run `ag flush --features` → accepted
7. Run from worktree → rejected with clear message
8. Dashboard shows dirty state count
9. After `ag done`, state is flushed without separate PR
10. Automated test in validate_framework.sh verifies allowlist boundary
11. Push failure is handled gracefully (`git reset --soft HEAD~1`, clear message)
12. Broken BACKLOG.json is rejected before commit
13. **[NEW]** No remote → commits locally, skips pull+push, warns
14. **[NEW]** Worktree on main → still rejected (worktree list comparison)

## Implementation Order

1. Spec artifacts (FEATURES.md entry, acceptance criteria) — spec-first
2. `state-commit.sh` + `ag.sh` dispatch (core, testable immediately)
3. Dashboard integration (visibility)
4. Skill updates: completing-work, committing-changes
5. Instruction files (behavioral delivery to all agents)
6. Tests (structural in validate_framework.sh + automated allowlist boundary test)

## Revision History

- **Rev 1**: Initial plan
- **Rev 2**: Post-dialectical review (iteration 1):
  - Removed VERSION from allowlist (release artifact, not state)
  - Added push-failure recovery (reset local commit + abort with retry message)
  - Added JSON validation for BACKLOG.json before commit
  - Added explicit `--no-verify` justification comment (not a precedent)
  - Added automated allowlist boundary test to verification
  - Moved spec artifacts to step 1 (spec-first, per framework rules)
  - Added edge cases: detached HEAD, branch name substring, broken JSON
  - Clarified branch check is exact match, not substring
- **Rev 3**: Post-dialectical review (iteration 2):
  - Added worktree detection via `git worktree list` comparison (not just branch check)
  - Added remote existence check before `git pull` (step 2), not just before push
  - Specified `git reset --soft HEAD~1` for push-failure recovery (preserves working tree)
  - Added memory-seed `--no-verify` exception carve-out to instruction file updates
  - Added R2 justification for `ag flush` in completing-work skill (sub-step of human-approved `ag done`)
  - Added edge case: worktree on main still rejected; no remote skips pull entirely
  - Added verification items 13-14
