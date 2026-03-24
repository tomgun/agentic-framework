# Autonomous Workflow Analysis (2026-03-10)

Session: F-0197 through F-0200 reliability fixes — 9 PRs (#98-#106), 4 features, fully autonomous.

## What was accomplished
- 8 feature PRs + 1 fix PR merged autonomously
- Up to 4 implementation agents ran in parallel in isolated worktrees
- Automated PR reviews caught real bugs (POSIX regex, quiet flag, pipefail+SIGPIPE)
- All merge conflicts resolved systematically (8 merges, 5 had conflicts)
- 626 tests pass, 0 failures on final main

## Why it worked — structural factors

### 1. Acceptance criteria as executable contracts
Each feature had `spec/acceptance/F-XXXX.md` with numbered, checkboxable ACs before any code was written. This gave every agent (implementation + review) an unambiguous "done" definition. Without this, parallel agents would have diverged on scope.

### 2. Worktree isolation
`git worktree` gave each parallel agent a full, independent copy of the repo. No shared working directory state, no stash conflicts, no checkout races. AGENTS.json in main repo tracked who was working where.

### 3. Pre-commit quality gates (16 checks)
`pre-commit-check.sh` caught: missing journal updates, direct-to-main commits, shipped spec modifications without migrations, complexity limits. These gates made it safe to work fast — errors were caught mechanically.

### 4. Token-efficient scripts
Scripts like `journal.sh`, `status.sh`, `feature.sh` handle state file updates in one call instead of read-edit-write cycles. Saves context window tokens, reduces error surface, prevents state file corruption from manual edits.

### 5. `validate_framework.sh` as integration test suite
626 acceptance tests running against actual framework files (not mocks) meant every merge could be verified in seconds. This was the final safety net that caught the stray conflict marker.

### 6. Review agents with structured checklists
Automated review caught 3 real issues implementation agents missed:
- `\s` not POSIX-compatible (would break on macOS)
- `--quiet` flag not respected in `check_backlog_drift()`
- Missing `fi` in one test block

### 7. Stacked PR strategy for large features
F-0200 was too large for one PR. Splitting into 4 chained PRs (#102-#105) kept each under complexity limits while maintaining coherent merge order.

## What was different from previous sessions

Previous sessions typically hit these failure modes:
1. **Scope creep**: Agent discovers adjacent issues, expands beyond original task
2. **State file corruption**: Multiple manual edits introduce formatting errors
3. **Merge conflict avalanche**: PRs pile up, each merge creates conflicts in the next
4. **"Tests pass" != "it works"**: Unit tests pass but feature isn't wired into CLI

This session avoided all because:
- Spec-first workflow enforced — every feature had ACs before code
- State scripts used consistently — no manual state file edits
- Merge order planned — independent features first, dependent ones last
- Integration tests verified wiring — validate_framework.sh checks tools exist, are executable, are wired into sync.sh

## Critical files for autonomous workflow

If any of these are lost/broken, autonomous workflow degrades:

| File | Role |
|------|------|
| `.agentic/lib/hooks/pre-commit-check.sh` | 16 quality gates at commit time |
| `tests/validate_framework.sh` | 626 acceptance tests against live framework |
| `.agentic/lib/tools/ag.sh` | CLI orchestrator (`ag implement`, `ag done`, `ag commit`) |
| `.agentic/lib/tools/sync.sh` | 10-phase drift detection on session start |
| `.agentic/lib/tools/journal.sh` | Token-efficient journal updates |
| `.agentic/lib/tools/status.sh` | Token-efficient status updates |
| `.agentic/lib/tools/feature.sh` | Token-efficient FEATURES.md updates |
| `.agentic/lib/init/memory-seed.md` | Trigger word -> action mappings agents internalize |
| `CLAUDE.md` | Constitution layer — session start protocol, core rules |
| `.claude/skills/` | Just-in-time playbooks loaded per workflow |

## Risk areas from these PRs

1. **`sync.sh` now has 10 phases** — if any new phase script is missing or buggy, `ag sync` may fail. Each phase is guarded with `|| true` or file-existence checks, so should be advisory-only.

2. **`ag.sh` has new `intent` subcommand and AC gate in `cmd_done`** — if `intents.py` is missing or python3 unavailable, intent commands gracefully degrade. AC gate respects `acceptance_criteria` STACK.md setting.

3. **`pre-commit-check.sh` pipefail+SIGPIPE fix** — the fix (pre-fetching diff into variable) is strictly more correct. If edge cases with very large diffs, `|| true` fallback handles it.

4. **`validate_framework.sh` F-0197/F-0198/DEV-0199 test sections** — additive (no existing tests modified), so risk is low.

## Merge conflict resolution strategy used

- **State files** (JOURNAL.md, STATUS.md): Accept `--theirs` (latest wins)
- **Shared code files** (sync.sh, validate_framework.sh, HOW_IT_WORKS.md): Manually combine both sides' additions
- **Feature-specific files**: Usually clean (isolated to worktrees)
