# Plan: Workflow Fix — State Files in PRs + Post-Merge VERSION Bump

## Context

During F-0196 shipping, two workflow problems surfaced:

1. **State files left dirty after PR**: The committing-changes skill says "state files can be committed separately via `ag flush`", but JOURNAL.md and STATUS.md are updated during feature work (and required fresh by the pre-commit hook). Leaving them out of the PR means they're dirty locally, blocking `git checkout main` after merge.

2. **VERSION bumped in the PR**: When multiple PRs are open, each tries to bump VERSION → merge conflicts. VERSION should be bumped post-merge on main.

**Design principle**: Separate *work-time state* from *completion-time state*.
- **In the PR**: code + JOURNAL.md + STATUS.md + CONTRIBUTIONS.md (documents the work)
- **Post-merge via `ag done`**: VERSION bump + FEATURES.md status + BACKLOG.json advance + `ag flush`

## Changes

### 1. `ag.sh` `cmd_done` — add VERSION bump + flush (lines 1337-1351)

After the backlog auto-advance block, before the closing `}`. **Both VERSION bump and flush are gated on being on main** — in a worktree, neither runs (prevents data loss when worktree is cleaned up).

```bash
# VERSION bump + flush (only on main — worktrees skip this)
local current_branch
current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
if [[ "$current_branch" == "main" || "$current_branch" == "master" ]]; then
    # VERSION bump (patch by default)
    if [ -f "$ROOT_DIR/VERSION" ]; then
        local current_ver new_ver major minor patch_num
        current_ver=$(cat "$ROOT_DIR/VERSION" | tr -d '[:space:]')
        if [[ "$current_ver" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            IFS='.' read -r major minor patch_num <<< "$current_ver"
            new_ver="${major}.${minor}.$((patch_num + 1))"
            echo ""
            echo -e "${BOLD}=== VERSION Bump ===${NC}"
            echo "  $current_ver → $new_ver"
            echo "$new_ver" > "$ROOT_DIR/VERSION"
            echo -e "${GREEN}✓ VERSION bumped to $new_ver${NC}"
        else
            echo -e "${YELLOW}⚠ VERSION file format unexpected: $current_ver (skipping auto-bump)${NC}"
        fi
    fi

    # Flush state files to main
    echo ""
    echo -e "${BOLD}=== Flushing State ===${NC}"
    bash "$SCRIPT_DIR/state-commit.sh" --features || true
else
    echo ""
    echo -e "${BLUE}On branch '$current_branch' — run 'ag flush --features' after returning to main.${NC}"
fi
```

Key fixes from review:
- VERSION bump and flush gated on same branch check (no worktree data loss)
- Semver format validation before writing (`^[0-9]+\.[0-9]+\.[0-9]+$`)
- No tag suggestion (drops noise — `ag done` already has a lot of output)

Note: `cmd_done` already does destructive operations (clears WIP, cleans up worktrees, advances backlog), so adding flush is consistent with its existing contract. Discovery profile returns early at line 1098 and never reaches this code — that's fine since Discovery doesn't use FEATURES.md or structured completion.

### 2. `state-commit.sh` — add VERSION to allowlist (line 33)

```bash
ALLOWLIST=(
    ".agentic/STATUS.md"
    ".agentic/TODO.md"
    ".agentic/HUMAN_NEEDED.md"
    ".agentic/BACKLOG.json"
    ".agentic/journal/JOURNAL.md"
    ".agentic/CONTRIBUTIONS.md"
    "VERSION"
)
```

Update the `--no-verify` justification comment (lines 1-11) to mention VERSION.

### 3. `tests/validate_framework.sh` — invert T-0098 (lines 4223-4229)

Change from "VERSION is NOT in allowlist" to "VERSION IS in allowlist".

### 4. Skills — committing-changes (template + generated)

Files: `.agentic/lib/agents/claude/skills/committing-changes/SKILL.md` + `.claude/skills/committing-changes/SKILL.md`

**Step 6** (line 86-93): Remove VERSION bump. Include work-time state files explicitly:
```
After human approves:
1. Stage files: `git add <specific-files>` (not `git add .`)
   Include JOURNAL.md, STATUS.md, and CONTRIBUTIONS.md — they document the work.
   Do NOT include VERSION, BACKLOG.json, FEATURES.md status — these are
   updated post-merge by `ag done`.
2. Commit with descriptive message
3. Create PR if on feature branch: `gh pr create --title "..." --body "..."`
4. Log PR in HUMAN_NEEDED.md for review tracking
```

**Step 7** (line 95-100): Replace post-merge tagging with pointer to `ag done`:
```
### Step 7: Post-Merge

After merge, run `ag done F-XXXX` on main. This bumps VERSION, updates
FEATURES.md status, advances the backlog, and flushes state to main.
```

### 5. Skills — completing-work (template + generated)

Files: `.agentic/lib/agents/claude/skills/completing-work/SKILL.md` + `.claude/skills/completing-work/SKILL.md`

The template is simpler (no Step 4b/4c). The generated version has Step 4b (backlog) and 4c (flush) from F-0196.

**Template**: After Step 3 (Update Feature Status), add note:
```
### Step 3b: Bump VERSION and Flush

`ag done` auto-bumps VERSION (patch) and flushes state to main when on main.
For minor/major bumps, edit VERSION manually before running `ag done`.
```

**Generated version**: Update Step 4c (Flush State) to mention VERSION is included in the flush.

### 6. Instruction files — change "Every PR: bump VERSION" to post-merge

| File | Line | Change |
|------|------|--------|
| `CLAUDE.md` (root) | 27 | "Every merge: bump VERSION via `ag done` (not in the PR)." |
| `.cursorrules` | 32 | "Every merge: bump VERSION via `ag done`. Update CONTRIBUTIONS.md during the PR." |
| `.github/copilot-instructions.md` | 36 | Same pattern |
| `.codex/instructions.md` | 35 | Same pattern |
| `.agentic/lib/init/memory-seed.md` | pre-commit section | Add: "VERSION is bumped post-merge by `ag done`, not in PRs." |

Files confirmed NOT needing changes (no VERSION bump rules):
- `.agentic/lib/agents/claude/CLAUDE.md` (template) — no VERSION rule
- `.agentic/lib/agents/shared/agent_operating_guidelines.md` — no VERSION rule
- `.agentic/lib/agents/shared/auto_orchestration.md` — no VERSION rule

### 7. Spec migration for F-0196 AC-024

F-0196 is shipped. AC-024 says "VERSION is NOT in the allowlist — version bumps go through PRs." This was a deliberate design decision that we're now reversing because multi-PR conflicts make it unworkable. Migration:

```bash
bash .agentic/lib/tools/migration.sh create "F-0196 AC-024: VERSION moves to ag flush allowlist — multi-PR VERSION conflicts make in-PR bumping unworkable; post-merge bump via ag done is conflict-free"
```

Then update AC-024 in `.agentic/spec/acceptance/F-0196.md`.

## What NOT to change

- No new `version.sh` tool — 5-line bump logic inlines in `cmd_done`
- No auto-tagging — tags are push operations, left to user
- Don't change the pre-commit hook — already correctly requires fresh JOURNAL.md/STATUS.md
- Don't touch `ag flush` core logic — just the allowlist
- Discovery profile: `cmd_done` returns early (line 1098), never hits the new code — intentional

## Post-implementation

- Update auto-memory (`MEMORY.md`): change "Bump VERSION too" to reference `ag done`

## Verification

1. `bash tests/validate_framework.sh` passes (T-0098 inverted)
2. `ag done F-TEST` on main bumps VERSION and flushes
3. `ag done F-TEST` from worktree/feature branch skips bump and flush (no side effects)
4. `ag flush --dry-run` with dirty VERSION shows it would be included
5. VERSION with bad format → warning, no write
6. Committing-changes skill no longer mentions VERSION bump
