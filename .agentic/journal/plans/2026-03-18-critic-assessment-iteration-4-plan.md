# Critic Assessment — Iteration 4

## High-Confidence Concerns

### 1. `spawn_claude` `project_root` param IS the cwd — fix agent's `project_root` argument is the claim, not the bug

The plan says: fix agent is spawned with `project_root=self.project_root` (the worktree path), and the Iter 3 fix addressed "cwd ambiguity." On inspection of `spawn_claude` in `__init__.py` (line 177-220): `spawn_claude` takes `project_root: Path` and uses it directly as `cwd=str(project_root)` in the subprocess call. So passing `self.project_root` (the worktree root) correctly sets the cwd.

**However**, there is a subtler version of the bug: `build_claude_cmd` reads `.claude/settings.json` from `project_root` (line 65: `settings_path = project_root / ".claude" / "settings.json"`). In a worktree, `.claude/settings.json` may not exist — worktrees don't get their own `.claude/` directory by default; that directory lives in the main repo. The fix agent would therefore fall through to interactive mode (tier 3), meaning it runs without `--print` and without tool permissions, and would block waiting for interactive input. This is a **runtime failure** that will manifest the first time someone runs the fix loop in a worktree — which is the primary scenario.

**Verdict**: High-confidence. The plan says "runs in existing worktree on PR branch" but doesn't address the missing `.claude/settings.json` in the worktree. The plan claims "Fix agent inherits the worktree context" but doesn't specify how the tier/settings are resolved.

---

### 2. `result.success` is set BEFORE the PR review block — review failure doesn't affect `success`

In `task.py` (lines 208-212), `result.success` is computed BEFORE the plan's proposed hook fires. The plan inserts the PR review call after line 206 (`result.pr_url = pr_url`), but `result.success` is computed at line 208 with no reference to `pr_review_verdict`. The plan does add `pr_review_verdict` to `TaskResult`, but the `success` field — which the scheduler reads to decide if a feature passed — is set at lines 208-211 based only on `acs_passed == acs_total and verification_passed`.

This means: the scheduler's `_run_feature()` returns a `TaskResult` with `success=True` even when `pr_review_verdict == "request_changes"`. The plan's scheduler change (`fw.status = "review_blocked"`) reads `pr_review_verdict` separately, which is correct — but only if the scheduler code is explicitly updated to inspect that field. The plan says "if `pr_review_verdict == "request_changes"` → `fw.status = "review_blocked"`" but the existing `_run_feature()` → scheduler flow just passes the `TaskResult` back; nothing currently routes on that field.

More concretely: the scheduler's main loop (around line 396-403) calls `runner.run()` and returns the `TaskResult`. There's no code today that reads `task_result.pr_review_verdict` and sets `fw.status = "review_blocked"`. The plan assumes this code will be added to scheduler.py, but it's not calling out WHERE — there is no `_run_feature()` post-processing hook that reads `TaskResult`. The plan must specify that after `_run_feature()` returns, the caller (in the main scheduler loop) checks `task_result.pr_review_verdict` and sets `fw.status = "review_blocked"`.

**Verdict**: High-confidence gap. The plan says "In `_run_feature()` after TaskRunner returns" but `_run_feature()` returns `TaskResult` to the main loop — the logic needs to be in the main scheduling loop, not buried in `_run_feature()` itself. As written, the scheduler would mark the feature `completed` (since `result.success` is still True) and proceed.

---

### 3. Phase 1 Step 5 contradiction: `_finalize_feature()` was removed, but Step 5 still references it

Phase 1, Step 5 reads: "Add `_review_and_fix_pr()` call in `ParallelDispatcher._finalize_feature()` for parallel epic mode."

But the Iter 3 fix **explicitly removed** this approach: "Removed non-existent `ParallelDispatcher._finalize_feature()` hook — each worktree runs its own TaskRunner with independent PR creation + review (no coordinator-level PR exists)."

The plan body (F-0235 Hook Point section) correctly says "No changes needed in `ParallelDispatcher` or `parallel.py`." But Phase 1 Step 5 was never updated to remove this contradicted step. This is a direct implementation contradiction between the narrative and the implementation sequence.

**Verdict**: High-confidence. A developer following Phase 1 Step 5 will spend time looking for `_finalize_feature()` or adding it, doing work that the plan's own text says is unnecessary and wrong.

---

## Possible Concerns

### 4. The PR review loop runs INSIDE `task.py` — it blocks the TaskRunner for the full fix-loop duration

The plan places the review+fix loop synchronously inside `TaskRunner.run()`. A full fix cycle is: spawn review agent (timeout ~300s) + spawn fix agent (~300s) + re-review (~300s) = up to ~15 minutes PER PR review cycle, with max 2 fix attempts = potentially 45 minutes of blocking. In a parallel epic with N features, each TaskRunner runs in a subprocess — so this is parallelized across features. BUT: for a single feature, this adds up to 45 minutes AFTER all ACs pass and the PR is created.

The plan doesn't specify a timeout for the review+fix block. If the review agent hangs (e.g., `gh pr diff` fails or network issue), the entire TaskRunner blocks indefinitely. The existing VerifyLoop has `max_iterations` and per-iteration timeouts. The PRReviewer loop needs equivalent safeguards: a per-review-spawn timeout and a total-loop timeout.

**Verdict**: Possible concern. The plan says "spawn_claude(prompt, print_mode=True, model=model)" with no timeout argument. `spawn_claude` defaults to `timeout=300` (line 183 of `__init__.py`), so it won't hang forever — but 300s per spawn × 6 spawns (3 review + 2 fix + 1 final review) = 30 minutes worst case. This should be documented and `pr_fix_timeout` should be a configurable setting.

---

### 5. `_check_pr_review_resolved()` polls GitHub but `_wait_for_review_resolution()` wasn't designed for mixed review types

The scheduler's `_wait_for_review_resolution()` (lines 466-510) checks `_is_review_blocked(feature_id)` which calls `get_pending_reviews()` which globs `{feature_id}_*.json`. When the PR review JSON file is created (`{feature_id}_pr_review.json`), this glob WILL match it, correctly blocking. When `_check_pr_review_resolved()` deletes the JSON file, `_is_review_blocked()` returns False, unblocking the feature.

The concern: the plan adds GitHub-state polling to `_wait_for_review_resolution()` by having it "iterate over any `*_pr_review.json` files and check GitHub state." This extends an existing method that was designed for state machine reviews. The extension requires iterating the directory, identifying PR-review files by filename suffix, and calling `PRReviewer._check_pr_review_resolved()`. This creates a coupling between `scheduler.py` and `pr_review.py` (new module) inside an existing method. The plan doesn't detail how `PRReviewer` gets instantiated inside the scheduler (scheduler has no `PRReviewer` today, no `claude_command` reference available at this call site).

**Verdict**: Possible concern. Needs explicit: `PRReviewer` must be instantiated (scheduler has `self.claude_command`? — check scheduler `__init__`), or the GitHub check is extracted to a standalone function in `pr_review.py` that takes only `project_root`.

---

### 6. `ConvergenceLoop` spawns a Planner agent that writes back to the plan file — but which plan file, and where?

The plan says: "Planner receives: current plan file path (to read and edit)." During `ag auto task`, the plan file path is in `.agentic/journal/plans/*F-XXXX-plan.md` in the MAIN REPO. If `ag auto task` runs from a worktree, `self.project_root` is the worktree root. The plan file is in the main repo (not copied to the worktree). The Planner agent spawned with `project_root=worktree_root` would need to find the plan at a path that's OUTSIDE the worktree.

`_find_plan_file()` (mentioned in memory-seed) globs within the project root. If the project root is the worktree, `*F-XXXX-plan.md` won't be found there. The plan is silent on how the Planner locates the plan file when running from a worktree context.

**Verdict**: Possible concern. Either: (a) the plan file path is passed explicitly to the Planner prompt, or (b) `ConvergenceLoop` always runs with the MAIN repo root (not the worktree root). The plan says `ag auto task` calls `ConvergenceLoop.run()` "Python-to-Python, no subprocess" — so the loop inherits `task.py`'s `project_root`, which in a worktree IS the worktree path. Needs explicit resolution.

---

## Assumptions Worth Verifying

### 7. `print_mode=True` for the fix agent matches verify.py pattern — but verify's fix agent uses `print_mode` default (True)

The plan changed fix agent to `print_mode=True` in Iter 4 (matching the VerifyLoop pattern). The verify.py `_spawn_claude_fix()` at line 731 calls `spawn_claude(self.claude_command, self.project_root, prompt, timeout=timeout)` — no explicit `print_mode`, so it defaults to `True`. This matches the plan's claim.

**However**: in `print_mode=True` (`--print` flag), Claude outputs text but does NOT have access to file-writing tools unless the tier grants them. Tier 1 (`--dangerously-skip-permissions`) gives all tools. Tier 2 (`--settings`) gives tools per the settings file. Tier 3 (interactive) — no tools. The VerifyLoop fix agent works because the same tier settings apply. The PR fix agent in a WORKTREE has the missing-settings-json problem identified in concern #1 above.

**Verdict**: Worth verifying. The plan's claim that "print_mode=True (like CriticalAgent) — the spawned Claude subprocess has file write + git access via the tier-based permission system" is only true if the worktree has `.claude/settings.json`. It doesn't.

---

### 8. `plan_review_convergence: auto` in `ag implement` Step 0.5 calls `plan_convergence.py` as a subprocess — but the plan also says `ag auto task` calls it Python-to-Python

The plan: "`ag implement` Step 0.5 (skill-level → Python): calls `python3 .agentic/lib/auto/plan_convergence.py --feature "$feature_id"`" as a subprocess. But "`ag auto task` (Python): calls `ConvergenceLoop.run()` directly (Python-to-Python, no subprocess)."

These are two entry points into the same logic, which is fine — but the `plan_convergence.py` CLI entry point (`if __name__ == "__main__"`) needs to correctly handle the `plan_review_convergence: manual` case. If `manual`, the CLI should print instructions and exit non-zero (or exit 0 with instructions). The plan says "Exit 1: plan is DRAFT/REVIEWING → runs convergence loop (auto mode) or prints review instructions (manual mode), then exits 0 on approval or 2 on escalation." So exit 0 on approval is clear, but exit 1 is overloaded: it means BOTH "runs convergence" AND "prints instructions." The exit codes need to be unambiguous for the bash caller in `ag implement`.

**Verdict**: Worth verifying. Exit code 1 means two different things depending on mode — this creates fragile bash logic in the `ag implement` skill. Consider: exit 0 = approved, exit 1 = needs action (either running loop or printing instructions), exit 2 = escalated/error. The skill logic must handle all three modes cleanly.

---

## Missing Coverage

### Scenario: PR review runs but `gh pr diff` returns empty or fails (PR branch not yet pushed)

The fix agent flow assumes `gh pr diff {number}` works when called. But `_create_pr()` in `task.py` creates the PR — if there's a race condition or the PR hasn't propagated to GitHub yet (common with GitHub's eventual consistency on new PRs), `gh pr diff` may return an empty diff or an error. The review prompt built from an empty diff will produce a garbage review. No retry or validation of the diff is specified.

### Scenario: Auto-fix agent commits but push fails (e.g., branch protection, no-force push rule)

The plan says "Fix agent ... commit, pushes to PR branch." If the push fails (remote has diverged, branch protection rules, etc.), the fix agent may report success but the PR branch isn't updated. The outer re-review loop then reviews the ORIGINAL diff again (not the fixed version). The plan has no error handling for push failure in the fix agent.

### Scenario: `plan_review_convergence: auto` with multiple features in an epic — convergence loop runs per-feature

If an epic has 10 features and each runs `_run_plan_convergence()` before starting, each feature independently runs the full convergence loop. For features sharing an epic, the plan convergence context (the plan file) may be the SAME file (epic-level plan) or per-feature plans. The plan doesn't clarify whether convergence runs per-feature-AC-file or per-plan-file, and whether running it 10 times for the same plan wastes cost.

### AC file for F-0235/F-0236

The plan adds Phase 0 (write ACs before code). Good. But the ACs themselves are not drafted in the plan — the Critic cannot verify AC completeness. The plan lists verification steps (F-0235 items 1-8, F-0236 items 1-10) which read like ACs but are in the "Verification" section, not in formal AC files. Per the framework's own rule, formal AC files must exist at `spec/acceptance/F-0235.md` and `spec/acceptance/F-0236.md`. The plan correctly defers creation to Phase 0 but gives no AC content to validate against.

---

## Convergence Signal

- [ ] Plan is fundamentally sound (no high-severity concerns remaining)

**NOT checking** — three high-confidence concerns remain:
1. Missing `.claude/settings.json` in worktrees breaks fix agent and review agent tool access (#1)
2. `result.success` computed before PR review verdict; scheduler routing gap for `review_blocked` (#2)
3. Phase 1 Step 5 directly contradicts the Iter 3 fix (still references removed `_finalize_feature()`) (#3)
