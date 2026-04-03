## Advocate Assessment

### Core Strengths

1. **Composition over reimplementation**: The plan's most important design decision is that each parallel agent runs `ag auto task {F-XXXX}` inside its own worktree. This reuses the entire `TaskRunner` pipeline (AC iteration, test execution, commit gating, PR creation, doc drift checking, critical agent review) without duplicating a single line of that logic. Every improvement to `TaskRunner` (in `/Users/tomas/code/agentic-framework/.agentic/lib/auto/task.py`) automatically benefits parallel execution. This is a textbook application of the framework's KISS meta-principle.

2. **Surgical insertion point**: The plan identifies the exact seam where parallelism should be introduced: inside `AutonomousScheduler.run()` at `/Users/tomas/code/agentic-framework/.agentic/lib/auto/scheduler.py`, line 132-279. The existing sequential `for fw in actionable` loop (line 213) becomes a delegation point to `ParallelDispatcher` when `--parallel` is set. The existing `run_epic()` method (line 281-322) is completely untouched -- it calls `run()` which delegates. Integration verification (line 313-321) runs after the dispatcher returns. This means the existing sequential path has zero risk of regression.

3. **Rolling window, not batch**: The plan specifies slot-based dispatch with a rolling window (plan line 56: "When a process completes and more children are pending, spawn the next one in the freed slot"). This is materially better than batch-of-N execution because it keeps all slots occupied. With 5 children and 3 slots, batch mode would do [3, 2] = 2 rounds. Rolling window can do [3, fill-as-freed] = near-optimal wall-clock time regardless of individual feature duration variance.

4. **`spawn_claude_async()` as a clean abstraction**: The plan adds a non-blocking counterpart to the existing `spawn_claude()` at `/Users/tomas/code/agentic-framework/.agentic/lib/auto/__init__.py`. The existing function (line 54-87) uses `subprocess.run()` (blocking). The new function returns a `subprocess.Popen` object with log file redirection. Critically, both share `build_claude_cmd()` (line 9-51), which handles the tier-based permission logic. This means parallel agents get the same permission model (tier 1/2/3) as sequential ones -- no security regression.

5. **AGENTS.json as the single coordination point**: The plan uses `cmd_claim()` / `cmd_checkpoint()` / `cmd_release()` from `/Users/tomas/code/agentic-framework/.agentic/lib/tools/agents_helpers.py` (lines 287-363). These already implement atomic read-modify-write with `fcntl.flock` (lines 97-129) and stale-claim cleanup via PID detection (lines 269-284). The plan doesn't invent a new coordination mechanism -- it uses the one that already exists and has been tested in production with multi-agent worktree scenarios.

6. **Per-feature log isolation**: Each agent writes to `.agentic/session/parallel-logs/{F-XXXX}.log`. This provides post-mortem debugging for each parallel agent independently. In a sequential run, stdout/stderr is interleaved; here it's cleanly separated.

7. **File count discipline**: The plan modifies 11 files total (plan table, lines 107-119), with 2 new files (`parallel.py` and `test_auto_parallel.py`). The remaining 9 are surgical modifications to existing files. This is well within the framework's 5-10 file guideline and shows appropriate scope control.

### Trade-offs Acknowledged

1. **`subprocess.Popen` over asyncio**: The plan explicitly chooses Popen with a 2-second poll loop instead of asyncio. This trades some latency (up to 2s detection delay on completion) for consistency with the existing codebase. The entire auto/ module uses `subprocess.run()` patterns (see `spawn_claude()` at `__init__.py:74`, `TaskRunner._create_branch()` at `task.py:216`, etc.). Introducing asyncio would require rewriting the call chain or mixing paradigms. The 2s poll overhead is negligible compared to 5-10 minute feature execution times. This is the right trade-off.

2. **New file (`parallel.py`) vs. expanding `scheduler.py`**: Creating a new file adds a module to maintain. The alternative -- putting all parallel logic in `scheduler.py` -- would bloat what is currently a clean 699-line file focused on sequential orchestration. The new file isolates the new concern (process lifecycle management, worktree lifecycle, signal handling) from the existing concern (feature scheduling, review resolution, state machine queries). This follows separation of concerns.

3. **Default max_parallel=3**: This is conservative. Modern machines could handle 5-10 Claude processes. But 3 is safe because: (a) each Claude process consumes ~500MB-1GB RAM, (b) each worktree duplicates the working directory, (c) the default is user-configurable via `--max-parallel N` or `max_parallel_agents` in STACK.md. Starting low and letting users scale up is safer than starting high and causing OOM.

### Risk Management

1. **Worktree creation failure** (plan "Edge Cases" section): If disk space or git state prevents worktree creation, the plan skips that feature and defers to serial. This is graceful degradation -- partial parallelism is better than total failure.

2. **Agent timeout**: `Popen.terminate()` with 10-second grace period before `Popen.kill()`. This is the standard Unix process management pattern (SIGTERM then SIGKILL). The timeout is feature-level, not AC-level, which is correct because `ag auto task` manages its own per-AC timeouts internally.

3. **SIGTERM/SIGINT handling**: The plan specifies signal handlers plus `atexit` for cleanup. This dual approach covers both explicit signals (Ctrl+C) and interpreter shutdown. Importantly, cleanup kills all active Popen processes AND removes worktrees -- preventing orphaned worktrees that consume disk space.

4. **Claim conflicts**: `cmd_claim()` in `agents_helpers.py` (line 287-331) already implements atomic dedup with fcntl locking. If two dispatchers try to claim the same feature, only one wins. The plan correctly handles the rejection case (skip + log warning). Additionally, `_cleanup_stale_claims()` (lines 269-284) handles the case where a claiming process died without releasing -- PID-based liveness check prevents permanent deadlock.

5. **Dirty worktree on cleanup**: `worktree.sh auto-remove` (lines 184-222) already exits 1 if the worktree has uncommitted changes. The plan preserves the worktree and logs a warning rather than force-removing. This prevents data loss from interrupted parallel agents.

6. **Integration verification runs in main repo**: After all parallel worktrees are cleaned up, integration verification runs in the main repo (plan lines 79, 149). This ensures verification sees the merged state, not individual worktree states.

### Honest Weaknesses

1. **No dependency ordering between children**: The plan dispatches all children in parallel without analyzing dependencies between them. If F-0102 depends on F-0101's output (e.g., creates a module that F-0102 imports), they'll run in parallel and F-0102 will fail. The plan doesn't mention this. **Why it's acceptable**: Epic children in this framework are designed to be independently implementable -- each has its own worktree and branch. Dependencies between children would require a DAG scheduler, which is a significantly larger feature. The current design matches the framework's model where children are merge-independent PRs. If there ARE dependencies, the user can set `--max-parallel 1` to fall back to sequential.

2. **No merge conflict detection during parallel execution**: If two parallel features modify the same file, their PRs will conflict. The plan doesn't detect this upfront. **Why it's acceptable**: PR-level merge conflicts are handled at merge time, not implementation time. This is consistent with how any team of developers works -- you don't prevent people from working on overlapping files, you resolve conflicts at merge. Integration verification (post-completion) would catch functional conflicts.

3. **Log file parsing is unspecified**: The plan mentions `_handle_completion()` "reads log, parses result" but doesn't specify the parsing format. `ag auto task` exits with 0/1, which gives success/failure, but extracting per-AC results from the log for aggregation into `FeatureWork` would require parsing stdout. **Why it's acceptable**: The essential information (success/failure) comes from the exit code. Per-AC detail is available in the log file for human review. The `SchedulerResult` can be populated with feature-level status without log parsing. This can be refined iteratively.

4. **No progress streaming during parallel execution**: In sequential mode, `on_feature_done` provides real-time callbacks. During parallel execution, the user sees nothing until features complete. **Why it's acceptable**: The plan stores per-feature logs, and AGENTS.json checkpoints are updated during monitoring. A progress display could be added in a follow-up without changing the core architecture. The V1 goal is correctness, not UX polish.

5. **Missing acceptance criteria file**: The plan references no formal acceptance criteria file at `.agentic/spec/acceptance/F-XXXX.md`. Without AC verification, the plan's completeness is judged solely by the plan document. This is a process gap, not a technical weakness.

### Alignment with Framework Principles

- **D4 (Small Batch)**: Each parallel agent still works on ONE feature at a time -- the parallelism is at the scheduler level, not the agent level. Agents remain single-feature-focused.
- **D2 (Deterministic Enforcement)**: The plan uses existing enforcement gates (claim/release, worktree.sh validation, VerifyLoop) rather than inventing new ones.
- **D7 (Multi-Env Portability)**: `subprocess.Popen` is platform-agnostic. `build_claude_cmd()` handles the tool-specific CLI construction. The parallel dispatcher is agent-agnostic.
- **F3 (Token Optimization)**: Each parallel Claude instance gets fresh, focused context (via `ag auto task`). No context sharing or accumulation between parallel agents.
- **KISS**: One new file, one new function, minimal modifications to existing code. The plan resists the temptation to add DAG scheduling, progress streaming, or other features that could ship later.

### User Value

The problem statement is clear: 5 children x 10 min each = 50 min serial vs. 10 min parallel. This is a 5x wall-clock improvement for the common case of an epic with independent children. The `--parallel` flag is opt-in, so existing users see zero behavior change. The `max_parallel_agents` setting gives users control over resource consumption. This directly addresses the #1 bottleneck in `ag auto epic` -- waiting for serial execution of independent work.
