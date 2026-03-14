**Status**: APPROVED

# F-0214: Parallel Epic Execution with Worktrees

## Context

`ag auto epic F-XXXX` executes child features sequentially. With parallelism via worktrees: N features execute concurrently.

Infrastructure exists but isn't wired: worktree.sh, AGENTS.json with fcntl locking, spawn_claude() with cwd, TaskRunner --skip-branch flag.

## Approach

- New `parallel.py` with `ParallelDispatcher`
- Modify `scheduler.py` to delegate when `--parallel` flag set
- Add `spawn_claude_async()` to `__init__.py`
- Rolling slot management with configurable max_parallel and timeout
- AGENTS.json claim/release per feature, worktree cleanup on completion

## Files

1. `.agentic/lib/auto/parallel.py` — NEW ParallelDispatcher
2. `.agentic/lib/auto/scheduler.py` — --parallel/--max-parallel/--timeout flags
3. `.agentic/lib/auto/__init__.py` — spawn_claude_async()
4. `.agentic/lib/tools/ag.sh` — help text
5. `.agentic/lib/presets/profiles.conf` — max_parallel_agents setting
6. `tests/test_auto_parallel.py` — NEW unit tests
7. `tests/validate_framework.sh` — structural checks
8. Instruction files: memory-seed, auto_orchestration, agent_operating_guidelines, CLAUDE.md templates

## Acceptance Criteria

AC-001 through AC-010 (see spec/acceptance/F-0214.md)
