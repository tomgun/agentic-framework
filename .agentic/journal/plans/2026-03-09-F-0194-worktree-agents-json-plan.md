# F-0194: Worktree-by-Default for Feature Branches

## Context

When agents work on feature branches, they modify files in the main worktree. This causes:
- Pull/rebase blocked by uncommitted changes (happened during F-0192)
- Collision risk when multiple agents work in parallel
- No isolation between the main branch and feature work

The infrastructure exists (`worktree.sh` with create/list/remove/status) but nothing triggers it automatically. Additionally, the coordination files (`AGENTS_ACTIVE.md` and `WIP.md`) use markdown — neither machine-parseable nor LLM-friendly.

**Goal**: Wire `worktree.sh` into `ag implement` and `ag done` with auto-cleanup. Replace `AGENTS_ACTIVE.md` + `WIP.md` with a single `AGENTS.json` registry.

## Key Design Decisions

### 1. Single JSON Registry (AGENTS.json)

Replace both `AGENTS_ACTIVE.md` and `WIP.md` with `AGENTS.json` in the main repo's `.agentic/session/`.

**Schema** (array of entries):
```json
[
  {
    "feature_id": "F-0194",
    "description": "Worktree-by-default",
    "worktree": "/abs/path/to/repo-f-0194",
    "branch": "feature/F-0194",
    "agent": "claude-desktop",
    "started": "2026-03-09T14:30:00Z",
    "last_checkpoint": "2026-03-09T15:00:00Z",
    "status": "active",
    "progress": ["Created settings", "Wired ag implement"],
    "files": ["ag.sh", "worktree.sh"]
  }
]
```

**Entry lifecycle**:
- `worktree.sh create` → adds entry, status `"created"`
- `wip.sh start` → updates to `"active"`, adds WIP details
- `wip.sh checkpoint` → updates `last_checkpoint`, appends to `progress`
- `wip.sh complete` → removes entry
- `worktree.sh auto-remove` → removes entry + worktree directory

**Without worktrees** (`worktree_mode: off`): Same lifecycle, `worktree` field = current PROJECT_ROOT.

### 2. Main-Repo Resolution

AGENTS.json always lives in the main repo. New `MAIN_PROJECT_ROOT` variable in both `paths.sh` and `paths.py`:

```bash
# paths.sh — after PROJECT_ROOT (line 38)
MAIN_PROJECT_ROOT="$PROJECT_ROOT"
if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
    _git_common=$(git rev-parse --git-common-dir 2>/dev/null)
    _git_dir=$(git rev-parse --git-dir 2>/dev/null)
    if [[ "$_git_common" != "$_git_dir" ]]; then
        MAIN_PROJECT_ROOT=$(cd "$(dirname "$_git_common")" && pwd)
    fi
fi
AGENTS_JSON="$MAIN_PROJECT_ROOT/.agentic/session/AGENTS.json"
```

### 3. Python Helper (agents_helpers.py)

New file following `backlog_helpers.py` pattern. File locking via `fcntl.flock()` (new — backlog_helpers.py doesn't have locking; add cross-platform fallback for Windows using `msvcrt` or no-op).

```python
def register(feature_id, worktree, branch, description="")  # status: created
def activate(feature_id, description, files, agent)          # status: active
def checkpoint(feature_id, note)                             # update checkpoint
def complete(feature_id)                                     # remove entry
def unregister(feature_id)                                   # alias for complete
def check_worktree(worktree_path)                            # find entry by worktree
def get_active(feature_id=None)                              # get entry by feature
def get_current_feature()                                    # first active entry's feature_id
def list_all()                                               # print all entries
```

CLI: `python3 agents_helpers.py --project-root <root> <command> [args]`

### 4. Full WIP.md Migration in ag.sh

`ag.sh` checks `WIP.md` directly (file existence) in 9 places. ALL must migrate to `agents_helpers.py` calls:

| Line | Function | Current check | New check |
|------|----------|---------------|-----------|
| 311 | `cmd_start()` | `if [ -f WIP.md ]` → interrupted work | `python3 agents_helpers.py check-worktree "$PROJECT_ROOT"` |
| 547 | `cmd_work()` | `wip.sh start "task"` | Same but writes to AGENTS.json |
| 780 | `cmd_implement()` | `if [ -f WIP.md ]` → one-feature guard | `python3 agents_helpers.py get-active` → check feature_id |
| 925 | `cmd_implement()` | `wip.sh start` | Conditional: skip if worktree_mode=always (agent starts WIP in worktree) |
| 945 | `cmd_commit()` | `if [ -f WIP.md ]` → WIP-before-commit | `python3 agents_helpers.py check-worktree "$PROJECT_ROOT"` |
| 1050 | `cmd_done()` | `if [ -f WIP.md ]` → reminder | `python3 agents_helpers.py check-worktree "$PROJECT_ROOT"` |
| 1263 | `cmd_done()` | `if [ -f WIP.md ]` → reminder | Same |
| 1357 | `cmd_docs()` | `grep F-XXXX WIP.md` → feature ID | `python3 agents_helpers.py get-current-feature` |
| 1727 | `cmd_status()` | `head WIP.md` → show status | `python3 agents_helpers.py list` |

**Helper bash function** (add to ag.sh to avoid repeating Python invocations):
```bash
_agents_py() {
    python3 "$SCRIPT_DIR/agents_helpers.py" --project-root "$ROOT_DIR" "$@" 2>/dev/null
}
_has_active_wip() {
    _agents_py check-worktree "$PROJECT_ROOT" >/dev/null 2>&1
}
_get_wip_feature() {
    _agents_py get-current-feature 2>/dev/null || echo ""
}
```

### 5. Profile Design

Both default to `worktree_mode: off`. Discovery allows main-branch multi-agent work. Users opt in to worktrees via STACK.md.

### 6. Future: MCP Integration (F-0185)

F-0194's AGENTS.json becomes the file-based foundation. F-0185's MCP wraps it with real-time coordination. Graceful degradation per ADR-001.

### 7. Upgrade Path

**`upgrade.sh`** — Add migration step (between step 4 and 5):
```bash
# Step 4b: Migrate WIP.md → AGENTS.json
if [[ -f "$TARGET_PROJECT_DIR/.agentic/session/WIP.md" ]]; then
    echo "  Migrating WIP.md → AGENTS.json..."
    python3 "$SCRIPT_DIR/agents_helpers.py" --project-root "$TARGET_PROJECT_DIR" \
        migrate-wip "$TARGET_PROJECT_DIR/.agentic/session/WIP.md"
    echo -e "${GREEN}✓ WIP.md migrated to AGENTS.json${NC}"
fi
# Clean up old AGENTS_ACTIVE.md (replaced by AGENTS.json)
if [[ -f "$TARGET_PROJECT_DIR/.agentic/session/AGENTS_ACTIVE.md" ]]; then
    echo "  Removing deprecated AGENTS_ACTIVE.md..."
    rm "$TARGET_PROJECT_DIR/.agentic/session/AGENTS_ACTIVE.md"
fi
```

**`agents_helpers.py migrate-wip`** — Parses WIP.md format, extracts feature_id/description/files/started/checkpoint, creates AGENTS.json entry.

**`.gitignore`** — Add `AGENTS.json` alongside existing WIP.md/AGENTS_ACTIVE.md entries.

## Critic Findings Addressed

| ID | Severity | Issue | Resolution |
|----|----------|-------|------------|
| C-01 | Critical | worktree.sh resolves AGENTS file to worktree, not main repo | `MAIN_PROJECT_ROOT` via `--git-common-dir` |
| C-02 | Critical | Double WIP.md (main repo + worktree) | Single AGENTS.json in main repo |
| C-03 | Critical | ag.sh checks WIP.md directly in 9 places | Full migration: all 9 checks → `agents_helpers.py` calls (see table above) |
| C-04 | Critical | Backward-compat fallback prevents AGENTS.json bootstrap | Fallback only on reads (`check`), not writes (`start` always creates AGENTS.json) |
| H-01 | High | `--auto-cleanup` flag never parsed | `auto-remove` as separate dispatch command |
| H-04 | High | Partial worktree creation | Validate with `git rev-parse --is-inside-work-tree` |
| H-05 | High | backlog_helpers.py has no file locking | New work: `fcntl.flock` with cross-platform fallback |
| H-07 | High | worktree.sh exits 1 if worktree exists | Fix: return 0 with message when worktree exists (not an error) |
| H-08 | High | auto-remove behavior with dirty worktree | Explicit: exit 1 with warning. ag.sh catches it gracefully. |
| M-02 | Medium | Python 3 dependency in wip.sh | Fallback: if python3 unavailable, wip.sh writes WIP.md directly (graceful degradation) |
| M-03 | Medium | AGENTS.json not in .gitignore | Add to .gitignore template and framework .gitignore |
| M-04 | Medium | "created" status stuck if agent crashes | Stale entry detection: `wip.sh check` warns if entry is "created" for >30 min |

## Changes by File

### Batch 1: Path infrastructure + settings (6 files)

**`.agentic/lib/paths.sh`** (line ~38) — Add `MAIN_PROJECT_ROOT`, `AGENTS_JSON`. Keep `AGENTS_ACTIVE_FILE` deprecated.

**`.agentic/lib/paths.py`** (line ~103) — Add `main_project_root`, `agents_json`, `_resolve_main_root()`.

**`.agentic/lib/presets/profiles.conf`** — Add `discovery.worktree_mode=off`, `formal.worktree_mode=off`

**`.agentic/lib/init/STACK.template.md`** — Add `- worktree_mode: off` under `### Workflow`

**`STACK.md`** — Same setting (off)

**`.agentic/lib/settings.sh`** — Add `"worktree_mode"` to `show_all_settings()`

### Batch 2: Agent registry (2 files — foundation, no ag.sh changes yet)

**`.agentic/lib/tools/agents_helpers.py`** — NEW. Core AGENTS.json manipulation:
- `_load()` / `_save()` with `fcntl.flock` (fallback: no-op on Windows/if unavailable)
- All commands from section 3 above + `migrate-wip` for upgrade path
- CLI dispatch like `backlog_helpers.py`

**`.agentic/lib/tools/wip.sh`** — Modify all operations to use `agents_helpers.py`:
- `start` → `agents_helpers.py activate`
- `checkpoint` → `agents_helpers.py checkpoint`
- `complete` → `agents_helpers.py complete`
- `check` → `agents_helpers.py check-worktree` (output stays human-readable: crash recovery instructions)
- **Python fallback**: if `python3` unavailable, write WIP.md directly (old behavior). Keeps wip.sh functional in minimal environments.

### Batch 3: ag.sh full migration + worktree wiring (2 files)

**`.agentic/lib/tools/worktree.sh`** — Five changes:
1. Fix `REPO_ROOT` → use `MAIN_PROJECT_ROOT` pattern for AGENTS.json path
2. Replace `register_agent()` markdown with `agents_helpers.py register`
3. Add `auto-remove` command (no prompts, exit 1 if dirty)
4. Add `path` subcommand (centralized path derivation)
5. Fix: `cmd_create()` returns 0 (not exit 1) when worktree already exists (H-07)

**`.agentic/lib/tools/ag.sh`** — Full migration:
1. Add `_agents_py()`, `_has_active_wip()`, `_get_wip_feature()` helper functions
2. Migrate all 9 WIP.md checks (see table in section 4)
3. `cmd_implement()`: worktree creation when `worktree_mode == always`, skip WIP in main repo
4. `cmd_done()`: worktree cleanup with inside-worktree detection
5. Command dispatch: add `worktree)` passthrough + `show_help()` entry

### Batch 4: Upgrade path + gitignore (2 files)

**`.agentic/lib/tools/upgrade.sh`** — Add step 4b: WIP.md → AGENTS.json migration, AGENTS_ACTIVE.md removal

**`.agentic/lib/init/gitignore-seed`** (or wherever .gitignore template lives) — Add `AGENTS.json`
Also update framework's own `.gitignore` if needed.

### Batch 5: Instruction files (7 files)

**Root `CLAUDE.md`** + **`.agentic/lib/agents/claude/CLAUDE.md`**:
- Worktree line: "When `worktree_mode: always`, `ag implement` auto-creates worktrees. `ag done` auto-cleans."
- Add `ag worktree` to Quick Commands

**`.claude/skills/implementing-features/SKILL.md`** — After Step 3:
- "If `ag implement` created a worktree, `cd <path>`. Run `wip.sh start` from the worktree."

**`.claude/skills/completing-work/SKILL.md`** — Worktree completion:
- "In worktree: commit + push, `wip.sh complete`, `cd` to main, `ag done F-XXXX`."

**`.claude/skills/committing-changes/SKILL.md`** — "In a worktree, already on feature branch."

**`.agentic/lib/init/memory-seed.md`** — Add `worktree_mode`, `ag worktree`, AGENTS.json

**`.agentic/lib/agents/shared/auto_orchestration.md`** — Worktree auto-creation in implement trigger

### Batch 6: Tests & docs (3 files)

**`tests/validate_framework.sh`** — F-0194 tests:
- `worktree_mode` in STACK.template.md
- `agents_helpers.py` exists with all commands
- `auto-remove` and `path` in worktree.sh
- `ag worktree` in ag.sh dispatch
- `MAIN_PROJECT_ROOT` in paths.sh
- `agents_json` in paths.py
- No direct `WIP.md` file checks in ag.sh (regression guard)

**`docs/HOW_IT_WORKS.md`** — Add F-0194 row, update coordination section

**`.agentic/lib/agents/shared/guidelines/multi-agent.md`** — Mention `worktree_mode: always`

## Edge Cases

| Case | Behavior |
|------|----------|
| Worktree already exists | Print path, return 0, skip creation |
| `worktree_mode: off` (default) | Zero worktree behavior. AGENTS.json still used for WIP. |
| Uncommitted changes at cleanup | Worktree preserved, warning printed |
| `ag done` from inside worktree | Error with step-by-step instructions |
| `worktree.sh create` fails | Warning, continue in main repo |
| Partial worktree creation | Validated with `git rev-parse` |
| Two agents, same feature ID | Second create returns 0 (exists). AGENTS.json shows entry. |
| Concurrent AGENTS.json writes | `fcntl.flock` prevents corruption |
| Old project, WIP.md exists | `upgrade.sh` migrates; `wip.sh check` fallback reads WIP.md |
| Python 3 unavailable | `wip.sh` falls back to WIP.md directly |
| "created" entry stuck (agent crash) | `wip.sh check` warns if >30 min old |
| Not a git repo | `MAIN_PROJECT_ROOT = PROJECT_ROOT` |

## Verification

1. `ag implement F-TEST` with `worktree_mode: always` → worktree created, AGENTS.json entry added
2. `cd` to worktree, `wip.sh start` → entry updated to "active" in AGENTS.json
3. `wip.sh checkpoint "test"` → checkpoint in AGENTS.json
4. `ag done F-TEST` from worktree → error with instructions
5. `wip.sh complete`, `cd` back, `ag done F-TEST` → worktree removed, entry gone
6. With uncommitted changes → worktree preserved
7. `worktree_mode: off` → zero worktree behavior, AGENTS.json used for WIP
8. `ag start` → detects interrupted work from AGENTS.json (not WIP.md)
9. `ag commit` → WIP gate reads AGENTS.json
10. `ag status` → shows active WIP from AGENTS.json
11. No file named `WIP.md` created anywhere during normal flow
12. `bash tests/validate_framework.sh` → all pass
13. `ag worktree list` / `ag worktree path F-TEST` → work
14. Verify AGENTS.json is in main repo, not worktree
15. Test `upgrade.sh` with existing WIP.md → migrated to AGENTS.json
16. Test `wip.sh start` without python3 → falls back to WIP.md
