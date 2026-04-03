# Critic Assessment: Parallel Epic Execution with Worktrees

## High-Confidence Concerns

### 1. `.claude/settings.json` is not copied to worktrees — spawned agents will run in interactive mode

`build_claude_cmd()` in `.agentic/lib/auto/__init__.py` (line 37) resolves `settings_path = project_root / ".claude" / "settings.json"`. When `project_root` is a worktree path (e.g., `../repo-f-0101`), `.claude/settings.json` does NOT exist there — `git worktree add` only creates a working tree of tracked files, and `.claude/` is typically gitignored. The spawned Claude processes will fall through to interactive mode (no `--dangerously-skip-permissions`, no `--settings`), which means they will hang waiting for user input rather than running autonomously.

The plan does not mention copying `.claude/settings.json` into worktrees, nor modifying `build_claude_cmd()` to resolve back to the main repo. This is a **blocking issue** — parallel execution will silently fail.

### 2. `TaskRunner` creates branches inside worktrees, conflicting with worktree branch

`worktree.sh create` (line 88) creates a branch `feature/F-XXXX` and checks it out in the worktree. Then the plan says each spawned Claude runs `ag auto task F-XXXX`, which invokes `TaskRunner.run()`. `TaskRunner._create_branch()` (task.py line 214-234) tries to create and checkout `feat/auto-{feature_id}` — a *different* branch name. Inside a worktree that's already on `feature/F-XXXX`, this will either:
- Create a new branch off the worktree's HEAD (diverging from intent), or
- Fail if `feat/auto-f-XXXX` already exists

The plan says "This reuses ALL existing TaskRunner logic" but doesn't address this branch naming conflict. The worktree already IS on a feature branch; `TaskRunner` shouldn't create another one.

### 3. Shared `.agentic/session/` directory — concurrent file access from N agents

Multiple agents will simultaneously read/write to `.agentic/session/` in the **main repo** (resolved via `_resolve_main_root()`). Specifically:
- `AGENTS.json` — has fcntl locking, so this is safe
- `scheduler-state.json` — written by `_save_progress()` in scheduler.py (line 594-601) via atomic rename, but each parallel agent's `TaskRunner` also creates its own `AutoEngine` (task.py line 105) which starts its own `ControlServer` (engine.py line 300) binding to `auto.sock`. **N agents will compete for a single Unix socket path** (`session_dir / "auto.sock"`), and the second agent will hit `RuntimeError("Another auto engine is already running")` at engine.py line 242.

This is a critical collision: `AutoEngine.__init__()` registers `atexit` + signal handlers and binds a Unix socket. Multiple `TaskRunner` instances in different worktrees will all resolve `session_dir` to the same directory via `_resolve_main_root()`.

### 4. Signal handler registration in subprocess children creates cleanup race

The plan registers `SIGTERM`/`SIGINT` handlers + `atexit` in the parent `ParallelDispatcher`. But each spawned Claude (which internally runs `ag auto task`) will create its own `AutoEngine` with its own signal handlers (engine.py line 278-279). When the parent sends `SIGTERM` to child processes (plan line 162: `Popen.terminate()`), the child's cleanup handler may race with the parent's `_cleanup_all()`, both trying to remove worktrees simultaneously. The `worktree.sh auto-remove` may fail because the child process hasn't finished cleanup yet.

### 5. `ag auto task` invoked via prompt does NOT use `TaskRunner` directly — it goes through `ag.sh`

The plan says Claude runs `ag auto task F-XXXX`. Looking at `ag.sh` line 2339-2341, this invokes `python3 "$auto_dir/task.py" --project-root "$ROOT_DIR" "$@"`. But `ROOT_DIR` in ag.sh is derived from the worktree's own root, not from the dispatcher. The `--project-root` will be the worktree path, which is correct for execution but means all the `_resolve_main_root()` pathways need to work from there. This should work via `paths.py` line 174-194, **but the plan doesn't verify this assumption**. If any tool (journal.sh, status.sh, blocker.sh) inside the spawned agent uses `ROOT_DIR` instead of `MAIN_PROJECT_ROOT`, it will write state files to the worktree (which has no `.agentic/session/` or `.agentic/STATUS.md`).

Actually, the plan says the prompt is `"ag auto task {F-XXXX}"` — this is a text prompt sent to `claude --print`. Claude-the-agent will then interpret this and decide what to do. It's not guaranteed to run the exact command `ag auto task F-XXXX` — it might read the codebase, explore, take tangents. The entire TaskRunner flow is mediated through an LLM, introducing nondeterminism the plan doesn't account for.

---

## Possible Concerns

### 1. Resource exhaustion with N concurrent Claude processes

Each Claude process consumes significant memory and potentially API rate limits. The plan sets `max_parallel_agents: 3` (default) with a max of 10. Three concurrent Claude processes is reasonable, but the plan does not mention:
- API rate limiting (Anthropic imposes per-org rate limits)
- Memory constraints (each Claude Code process uses substantial memory)
- Disk space for N worktrees (full repo copies)

For large repos, 5-10 concurrent worktrees could exhaust disk space. No pre-flight check is planned.

### 2. Worktree cleanup on partial failure may leave orphaned branches

The plan's edge case section (line 163) says dirty worktrees are preserved with a warning. But the corresponding `feature/F-XXXX` branch in the main repo will remain checked out in the orphaned worktree. This means:
- `git branch -d feature/F-XXXX` will fail ("checked out in another worktree")
- The branch can't be reused until the worktree is manually cleaned
- Repeated failed runs will accumulate orphaned worktrees and locked branches

No automated cleanup sweep is planned.

### 3. `open(log_path, 'w')` file handle leak in `spawn_claude_async()`

The plan's `spawn_claude_async()` (line 89) opens a file handle: `log_f = open(log_path, 'w')`. This handle is passed to `Popen` but never explicitly closed by the caller. If `Popen` itself doesn't close it (it doesn't — `Popen` holds a reference to the fd but doesn't own the Python file object), this leaks file handles. With a rolling window of agent spawns, this accumulates.

### 4. Integration verification runs in main repo after worktrees are cleaned

The plan says (line 149): "integration_verify runs after parallel dispatch returns (in main repo, worktrees already cleaned up)." But integration tests may need the feature branches to be merged into main first. If each feature created a PR but nothing was merged yet, the integration test runs against main without any of the new code. The plan doesn't specify how parallel feature work gets integrated before verification.

### 5. No dependency ordering between child features

The plan assumes all children of an epic can execute in parallel. But child features may have implicit dependencies (e.g., F-0102 needs a database schema that F-0101 creates). There's no mechanism to express or detect ordering constraints between children. Sequential execution accidentally handled this; parallel execution will surface latent dependency bugs as nondeterministic failures.

---

## Assumptions Worth Verifying

### 1. "worktree.sh create" is idempotent for repeated runs

The plan relies on `worktree.sh create` (line 68-80) returning 0 if the worktree already exists. This is true per the code (line 69-79: returns 0 with existing valid worktrees). But if a previous run crashed after creating the worktree but before registering in AGENTS.json, the claim check will fail (no existing claim) while the worktree already exists. This creates an inconsistency: claim succeeds, worktree "create" returns the existing path, but the branch state inside may be dirty from the crashed run.

### 2. `_resolve_main_root()` works correctly from every tool invoked inside a worktree

The plan's core assumption is that `paths.py:_resolve_main_root()` correctly resolves back to the main repo from any worktree. This uses `git rev-parse --git-common-dir` vs `--git-dir`. This should work for Python code using `get_paths()`, but shell scripts using `MAIN_PROJECT_ROOT` from `paths.sh` may or may not have this set correctly when invoked by a fresh Claude process inside a worktree. Verify that `paths.sh` also resolves worktree roots.

### 3. The `ag auto task` prompt will be executed faithfully by Claude

The spawned Claude receives the text prompt `"ag auto task F-XXXX"` via `--print` mode. In print mode, Claude executes autonomously but there's no guarantee it runs that exact command. It might refuse, ask clarifying questions (even in print mode), or interpret the command differently. The plan treats the LLM as a deterministic subprocess, which it is not.

### 4. fcntl locks work across worktrees accessing the same `AGENTS.json`

`agents_helpers.py` uses `fcntl.flock()` for atomic read-modify-write. When multiple processes in different worktrees all open the same `AGENTS.json` file (in the main repo, resolved via `_resolve_main_root()`), fcntl should work correctly since it's the same underlying file. But if any process opens a different path that happens to resolve to the same inode (symlinks, bind mounts), locking semantics may differ. This is likely fine on macOS/Linux but worth a sanity check.

---

## Missing Coverage

### No acceptance criteria file referenced

The plan has no feature ID and references no acceptance criteria file. Without ACs, there's no way to verify coverage. The plan should specify which feature this implements (e.g., F-0209?) and link to its acceptance criteria.

### No rollback strategy for partial epic completion

If 3 of 5 features complete and 2 fail, the plan marks the epic as not fully successful. But the 3 completed features have already created PRs and possibly merged. There's no guidance on whether to revert the successful PRs, leave them, or re-run only the failed features. The sequential scheduler had the same gap, but parallelism makes it more visible because all 5 start simultaneously.

### `EngineState` sharing is not addressed

Each spawned `ag auto task` creates its own `EngineState` (via `AutoEngine.__init__`). The parent `ParallelDispatcher` has no `EngineState`. If the user sends a `stop` command to the dispatcher (via `ag auto stop`), there's no mechanism to propagate that stop to the N child Claude processes. The plan mentions `SIGTERM`/`SIGINT` propagation but not the `ControlServer` stop command pathway.

### Per-feature log rotation/limits

The plan writes logs to `.agentic/session/parallel-logs/{F-XXXX}.log`. Claude output can be substantial (hundreds of KB per feature). With repeated runs (retries), logs will grow. No rotation, size limit, or cleanup strategy is mentioned.

### Testing strategy is thin

The plan lists unit tests with mocked Popen plus one manual test. For a feature this complex (process management, signal handling, worktree lifecycle, concurrent file access), the testing strategy should include:
- Integration test with real (but minimal) worktrees
- Signal handling test (verify cleanup on SIGTERM)
- Concurrent AGENTS.json access test (race condition detection)
- Log capture test (verify output is actually captured)

Mocked Popen tests will miss all the real-world failure modes (the most likely source of bugs).

---

## Complexity Assessment

The plan is appropriately scoped for the problem. The decision to reuse `TaskRunner` via `ag auto task` (rather than reimplementing its logic) is sound. The rolling-window slot management is the right pattern (vs. batch-and-wait). The 11-file change list is at the upper end of "small" but reasonable for a feature that touches process management + CLI + config + instructions.

However, the plan **underestimates integration complexity**. The pieces it wires together (worktrees, AGENTS.json, spawn_claude, TaskRunner) were designed for single-agent use. Making them work concurrently surfaces issues (socket conflicts, branch naming, settings.json resolution) that aren't visible from the API surface. The plan reads like "just wire the pieces together" but the devil is in the concurrent execution semantics.

**Recommendation to planner (not a fix, just a flag)**: The high-confidence concerns #1 (settings.json), #2 (branch naming), and #3 (socket conflicts) are individually blocking and will each cause failures on the first real test. They need explicit solutions before implementation.
