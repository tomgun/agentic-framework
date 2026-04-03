# Plan Critique: Workflow Fix — State Files in PRs + Post-Merge VERSION Bump

## 1. Correctness

### Problem 1: Dirty state files after PR
**Verdict: The plan does NOT fully solve this.**

The plan says "In the PR: code + JOURNAL.md + STATUS.md (documents the work being done)." This means JOURNAL.md and STATUS.md would be committed in the feature PR. That does solve the dirty-after-merge problem for those two files. Good.

But what about BACKLOG.json and CONTRIBUTIONS.md? The plan says BACKLOG.json is updated "post-merge via `ag done`", and CONTRIBUTIONS.md is in the state-commit.sh allowlist but isn't mentioned in the PR-vs-post-merge split. If CONTRIBUTIONS.md is updated during feature work (and the memory rules say "Every PR: update CONTRIBUTIONS.md"), it will also be dirty after merge. The plan changes "Every PR: bump VERSION" to "Every merge: bump VERSION via `ag done`" but doesn't address CONTRIBUTIONS.md's timing. It could be left dirty.

### Problem 2: VERSION conflicts
**Verdict: Correctly solved.** Moving VERSION bump to `ag done` (run on main post-merge) eliminates the multi-PR conflict problem. The version is bumped once, on main, after the PR is merged. This is the right approach.

### VERSION in `ag flush` allowlist — logical contradiction
The plan adds VERSION to the `state-commit.sh` allowlist. But VERSION is only bumped by `ag done` (also on main), and `ag done` immediately calls `ag flush`. So the VERSION file will be dirty for approximately zero seconds before it's flushed. This is fine mechanically, but the real question is: why does VERSION need to be in the allowlist at all? The `ag done` code bumps VERSION and then calls `state-commit.sh --features`. The flush will commit it. **This is correct** — the flush needs to include VERSION in its commit. The allowlist addition is necessary.

## 2. Completeness

### Missing files/changes

1. **copilot-instructions.md**: The plan's table (Section 6) says "Same" for `.github/copilot-instructions.md` at line 36. But the actual content at that line says "Every PR: Bump VERSION (at least patch) and update .agentic/CONTRIBUTIONS.md...". The plan targets this correctly.

2. **memory-seed.md**: The plan says to add a "post-merge VERSION rule" at ~line 119. But grepping memory-seed.md for VERSION returns no matches — there is no existing VERSION rule to modify. The plan needs to ADD a rule, not modify one. The plan says "Add post-merge VERSION rule" which is correct, but the line number is wrong since there's no existing anchor.

3. **Template CLAUDE.md** (`.agentic/lib/agents/claude/CLAUDE.md`): Not listed in Section 6. This file does NOT contain a "bump VERSION" rule currently, so this is fine — no change needed. But the plan should have audited this.

4. **codex-instructions**: Not mentioned at all. The plan's Section 6 table lists `.cursorrules` and copilot-instructions but not codex. Should verify whether codex-instructions also has a VERSION rule.

5. **`agent_operating_guidelines.md`**: Not mentioned. Should check if it has VERSION rules.

6. **`auto_orchestration.md`**: Not mentioned. Should check.

7. **Discovery profile path**: `cmd_done` has an early return at line 1098 when `feature_tracking` is "no" (Discovery profile). The plan's VERSION bump code goes AFTER the backlog auto-advance block (line 1337-1351), which is in the Formal path. **Discovery profile users will never get the VERSION bump.** This might be intentional (Discovery mode is lightweight), but the plan doesn't discuss it.

8. **FEATURES.md in the flush call**: The plan calls `state-commit.sh --features` from `ag done`. This is correct — `ag done` already runs `feature.sh F-XXXX status shipped` earlier in the flow, making FEATURES.md dirty, and `--features` picks it up. Good.

### Edge cases missed

- **`ag done` without a feature ID**: The plan's VERSION bump code is placed after the backlog auto-advance block which is inside a `if [ -n "$feature_id" ]` guard. Wait — re-reading the code: the backlog block at line 1337 is guarded by `if [ -n "$feature_id" ]`. The plan says to add the VERSION bump "After the backlog auto-advance block, before the closing `}`." The closing `}` of `cmd_done` is at line 1351. So the VERSION bump would be OUTSIDE the feature_id guard. That means `ag done` (no feature ID) would also bump VERSION. Is that desired? Probably yes for Discovery mode, but Discovery mode returns early at line 1098. For Formal mode without a feature ID... that's a weird edge case (Formal mode with feature_tracking=yes but no feature ID passed) — probably fine.

- **Double-bump risk**: If someone runs `ag done F-XXXX` twice (e.g., forgot they already ran it), VERSION gets bumped twice. The plan doesn't guard against this. A minor issue — the user would see the bump output and could revert.

## 3. Risks

### Risk 1: `ag done` requires being on main
The plan's auto-flush is gated on `current_branch == "main"`. But `ag done` is commonly run from a worktree (feature branch). The worktree cleanup happens BEFORE the VERSION bump in the plan's placement (worktree cleanup is at lines 1313-1329, backlog advance at 1337-1351, and the new code comes after). If the user is in a worktree, they run `ag done F-XXXX`, the worktree gets cleaned up, but then the flush is skipped because they're not on main. **The VERSION file gets bumped in the worktree but never committed.** When the worktree is removed, the bump is lost.

This is a real sequencing problem. The plan's "Auto-flush if on main" guard protects against flushing on branches, but the VERSION bump happens unconditionally before that guard. The plan needs to either: (a) skip the VERSION bump when not on main, or (b) defer the entire VERSION+flush to be run manually on main after worktree cleanup.

### Risk 2: Spec migration for shipped F-0196
The plan correctly identifies that AC-024 is a shipped spec and needs a migration. This is the right procedure. But the migration changes the *meaning* of a shipped acceptance criterion from "VERSION is NOT in the allowlist" to "VERSION IS in the allowlist." That's a direct inversion. The plan should create a new feature ID for this workflow change rather than retroactively modifying F-0196's contract. A migration is technically allowed, but inverting a shipped AC is unusual and should be justified more explicitly.

### Risk 3: `--no-verify` in `state-commit.sh`
Adding VERSION to the allowlist means `state-commit.sh` will commit VERSION changes with `--no-verify`. The script's header comment explains why `--no-verify` is safe (hardcoded allowlist, self-contained validation). Adding VERSION doesn't break this contract since it's still hardcoded. But VERSION is a more "meaningful" file than STATUS.md — a bad VERSION value could break downstream tooling (tag creation, package publishing). There's no validation of the VERSION format before committing. The script validates BACKLOG.json as valid JSON but doesn't validate VERSION as valid semver. **Consider adding a basic format check** (e.g., matches `^[0-9]+\.[0-9]+\.[0-9]+$`).

### Risk 4: Race condition — no auto-commit rule
The plan adds VERSION bump and flush to `ag done`, but `ag done` is currently a *reporting/checking* function — it doesn't commit anything on its own (it calls external scripts and prints checklists). Adding an auto-flush to `ag done` means `ag done` now makes commits. This is a behavioral change. The completing-work skill says this is "a sub-step of the human-approved `ag done` flow, not an auto-commit" — but that framing is somewhat strained. The user typed `ag done` expecting a checklist, and now it also commits. The plan should consider adding a confirmation prompt or at least clearly documenting this behavioral change.

## 4. Simplicity

### The plan is appropriately scoped
Seven changes for a workflow improvement that touches commit flow, completion flow, and instruction files is proportional. The "What NOT to change" section is good — it prevents scope creep (no new `version.sh` tool, no auto-tagging).

### One simplification possible
The tag suggestion (Section 1, last code block) adds noise. `ag done` already prints a lot of output. A tag suggestion that the user has to manually run is low-value. Consider dropping it or making it conditional on `git_workflow: pull_request`.

### The FEATURES.md status update timing is confusing
The plan says FEATURES.md status is updated "post-merge via `ag done`", but `feature.sh F-XXXX status shipped` is already called in `cmd_done` (via the completing-work skill's Step 3). So FEATURES.md status IS updated during `ag done`. The plan's description is consistent but the narrative in the Context section could be clearer about what happens when.

## 5. Contradictions

### Contradiction with "Never auto-commit" rule
The core rules in CLAUDE.md say "Never auto-commit. Show changes to human first." The plan adds auto-committing (via `ag flush`) to `ag done`. The completing-work skill already addresses this by calling it "a sub-step of the human-approved `ag done` flow." But `cmd_done` currently doesn't commit anything — it only checks and reports. Making it commit is a change in kind, not degree. This should be explicitly acknowledged and the `ag done` help text should warn that it modifies the repo.

### Partial contradiction with memory-seed
The user's auto-memory says: "CONTRIBUTIONS.md on every framework PR: User design insights go here during implementation, not as afterthought. Bump VERSION too." Changing this to post-merge bumping means the memory rule is stale. The plan updates CLAUDE.md and .cursorrules but doesn't mention updating the auto-memory (MEMORY.md). This will cause the agent to receive conflicting instructions until memory is updated.

### F-0196 Out-of-Scope section
Line 86 of the acceptance criteria file explicitly says "VERSION in the allowlist (it's a release artifact)" is OUT OF SCOPE. The plan acknowledges this needs a migration, which is correct. But it's worth noting that this was a deliberate design decision in F-0196, not an oversight. The plan should justify why that decision should be reversed (the justification exists — multi-PR VERSION conflicts — but should be stated in the migration).

## Summary

**The plan is mostly sound** with one significant bug (Risk 1: VERSION bump in worktrees gets lost), one process issue (auto-commit contradiction), and several minor gaps (no semver validation, Discovery profile excluded without discussion, stale auto-memory). The core design — moving VERSION bump to post-merge `ag done` — is the right call. The changes to skills and instruction files are complete enough (modulo codex-instructions audit).

**Must fix before implementing:**
1. Guard VERSION bump against non-main branches (or defer to flush-on-main only)
2. Add semver format validation before writing VERSION
3. Address the "auto-commit" behavioral change explicitly

**Should fix:**
4. Audit codex-instructions and agent_operating_guidelines for VERSION rules
5. Note that auto-memory (MEMORY.md) will need updating
6. Justify the F-0196 AC-024 inversion in the migration description
7. Clarify Discovery profile behavior (intentional exclusion or gap?)
