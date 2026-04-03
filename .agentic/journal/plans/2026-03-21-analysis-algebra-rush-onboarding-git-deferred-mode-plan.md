# Analysis: Algebra Rush Onboarding + Git-Deferred Mode

## Context

User initialized the agentic framework in an empty folder, chose `autonomous_formal`, asked Claude to create "algebra rush" (a geometry dash clone), told it to work autonomously. Got a playable game in 5-10 minutes (~1593 lines of TypeScript). Observations and proposed improvements follow.

---

## Part 1: What Actually Happened (from examining the project)

### The Good
- **Init worked well**: autonomous_formal profile, all state files created (STACK.md, STATUS.md, CONTEXT_PACK.md, OVERVIEW.md)
- **Claude hooks fully set up**: All 7 hook types configured in `.claude/hooks.json` with shell scripts present in `.agentic/hooks/claude/`
- **Specs created**: 6 features defined in FEATURES.md with descriptions
- **Detailed ACs for 3/6 features**: F-0001 (platformer), F-0002 (algebra puzzles), F-0003 (level system) have Given/When/Then ACs with 6 criteria each
- **NFRs defined**: 8 non-functional requirements (performance, visual style, audio, mobile)
- **HUMAN_NEEDED used properly**: 2 items raised (music assets, art direction), both resolved with procedural generation decisions
- **Working game code**: 1593 lines across 8 TypeScript files, one test file (PuzzleGenerator.test.ts)
- **.gitignore created** with node_modules, dist, .agentic/lib/, .agentic/session/ (note: user thought it wasn't there — it IS, but `.pnpm-store/` is missing)

### What Wasn't Used (the engine/state machine was bypassed)
- **All 6 features still "planned"** — no state transitions happened despite 1593 lines of code
- **No BACKLOG.json** — backlog was never populated
- **No work items** — `.agentic/work/` directory is empty
- **No plans** — `.agentic/journal/plans/` is empty (despite `plan_review_enabled: yes`)
- **`ag implement` never ran** — no worktrees, no WIP tracking in AGENTS.json
- **`ag transition` never ran** — state machine completely bypassed
- **3/6 features have no AC files** (F-0004 Audio, F-0005 UI, F-0006 Persistence)
- **Git initialized but zero commits** — everything untracked
- **Only 1 journal entry** — the init session

### Why the State Machine Was Bypassed
The agent was told "work autonomously, tell me when playable." It took the fastest path:
1. Created specs and feature list (good foundation)
2. Jumped straight to writing code without `ag plan` → `ag implement` → `ag transition`
3. Claude hooks were set up but are **advisory not blocking** for code creation
4. The `PreToolUse` hook enforces "spec-first" but having features in FEATURES.md was apparently sufficient — it didn't enforce that features must be transitioned to `implementing` before code is written

### The Two Enforcement Layers

```
Layer 1: Claude hooks (.claude/hooks.json)     ← SET UP, PARTIALLY ACTIVE
  - PreToolUse: Fires on Bash/Write/Edit — spec-first check
  - PostToolUse: ExitPlanMode enforcement, quality checks
  - UserPromptSubmit: Phase-aware verification
  - Stop: Blocks stop until ag verify passes
  → These fire on Claude tool-use events, NO GIT NEEDED

Layer 2: Git hooks (.agentic/hooks/pre-commit)  ← SET UP, NEVER FIRED
  - Pre-commit quality checks
  - Branch protection
  → Never fired because no commits were made
```

---

## Part 2: Identified Gaps (prioritized)

### Gap 1: State Machine Bypass — Agent coded while all features stayed "planned"
- **Severity**: Medium — bypassed formal lifecycle, BUT user liked the fast results ("turbo mode")
- **Root cause**: `PreToolUse` checks that specs EXIST but not that features are in `implementing` state
- **Decision**: **Don't enforce for now.** Turbo mode is valuable for autonomous prototyping. The agent DID create specs (hooks nudged it via `acceptance_criteria: blocking`) — it created ACs for 3/6 features (the core ones it was implementing) but skipped the rest. This is a reasonable MVP behavior.
- **Future**: Consider a `prototype_phase: yes` setting that formally acknowledges "spec then code fast" without requiring state transitions. Formalization happens later via `ag formalize`.

### Gap 2: Missing AC Files for 3/6 Features
- **F-0004 (Audio), F-0005 (UI), F-0006 (Progress)** have FEATURES.md entries but no `spec/acceptance/F-XXXX.md` files
- **Root cause**: Features were hand-created (no kickoff), agent created ACs for first 3 but stopped
- **Proposed fix**: `ag kickoff` should be the primary path for feature creation. Direct feature creation should still work but `ag check` should flag features without AC files.

### Gap 3: No BACKLOG.json — No Work Queue
- **Root cause**: Kickoff populates BACKLOG.json; hand-creating features doesn't
- **Impact**: `ag backlog list` shows nothing, dashboard shows no queue
- **Proposed fix**: When features exist in FEATURES.md but BACKLOG.json is empty/missing, `ag status` and dashboard should note this and suggest `ag backlog add F-XXXX`

### Gap 4: .gitignore Incomplete
- `.pnpm-store/` not ignored (shows in git status)
- **Proposed fix**: Stack-aware .gitignore generation (see Part 4)

### Gap 5: WIP/Active Work Invisible
- No `ag wip` command, AGENTS.json is empty `[]`
- STATUS.md says "Project initialization" but code is already written
- **Proposed fix**: Dashboard should cross-reference FEATURES.md status with actual source files — if code exists but features are all "planned", flag the inconsistency

---

## Part 3: Git-Deferred Mode (user's choices: all profiles default deferred, three modes)

### `git_mode` Setting in STACK.md

```
git_mode: deferred   # Options: none | deferred | active
```

| Mode | Behavior |
|------|----------|
| `none` | No git, ever. All git-dependent features disabled. For teams using external VCS or non-git workflows. |
| `deferred` | **New default for all profiles.** Framework fully functional via Claude hooks + engine. Git can be activated anytime via `ag git-init`. |
| `active` | Current behavior. Git initialized, hooks set up, branching/PRs available. |

### What Works Without Git (deferred/none modes)
- State machine lifecycle (all 9 states)
- All Claude hooks (PreToolUse, PostToolUse, UserPromptSubmit, ExitPlanMode, PreCompact, Stop)
- Kickoff pipeline (vision → features → backlog)
- Spec/AC creation and tracking
- Test running and verification (`ag verify`)
- BACKLOG.json ordering
- STATUS.md, JOURNAL.md updates
- Dashboard (minus git-specific sections)
- `ag plan`, `ag implement` (in-place, no worktree), `ag verify`, `ag done`

### What's Gated Behind `git_mode: active`
- `ag commit` → prints "Git not active. Run `ag git-init` to enable version control."
- `ag merge` → same
- Worktree creation (`ag implement` falls back to in-place branch)
- Git pre-commit hooks
- Branch protection
- PR workflow (`git_workflow: pull_request` effectively becomes `direct` until git activated)

### `ag git-init` Command
When user is ready for version control:
1. Run `git init` (if not already)
2. Generate stack-aware `.gitignore` (from STACK.md) — see Part 4
3. Set `core.hooksPath = .agentic/hooks`
4. Stage all non-ignored files, create initial commit: `"Initial commit"`
5. Update STACK.md: `git_mode: active`
6. Print summary: "Git initialized with N files. You can now use `ag commit`, branches, and PRs."

### Init Flow Changes

**scaffold.sh** (`.agentic/lib/init/scaffold.sh`):
- Remove lines 12-18 (`git init` auto-run)
- Add `git_mode` to STACK.md during init based on profile (all default to `deferred`)
- Skip `core.hooksPath` setup when deferred
- Still create `.gitignore` template (useful reference even without git)

**init_playbook.md** (`.agentic/lib/init/init_playbook.md`):
- Update Step 0 to explain git-deferred default
- Add note: "Git is deferred by default. Activate anytime with `ag git-init`."
- Remove "framework requires git" statement

**profiles.conf** (`.agentic/lib/presets/profiles.conf`):
- Add `discovery.git_mode=deferred`, `formal.git_mode=deferred`, `autonomous_formal.git_mode=deferred`

---

## Part 4: Stack-Aware .gitignore Generation

### New Script: `.agentic/lib/tools/gitignore.sh`

Called by `ag git-init` and also available standalone as `ag gitignore`.

**Logic:**
1. Read STACK.md for language/framework/tooling
2. Generate appropriate entries based on detected stack
3. Merge with existing .gitignore if one exists (don't duplicate)

**Always included (framework):**
```gitignore
# Agentic framework (session state)
.agentic/session/
.agentic/pipeline/
.agentic/local/
```

**Node/TypeScript detected:**
```gitignore
node_modules/
dist/
build/
.next/
.nuxt/
.pnpm-store/
.env
.env.local
.env.*.local
```

**Python detected:**
```gitignore
__pycache__/
*.pyc
.venv/
venv/
*.egg-info/
.mypy_cache/
```

**General (always):**
```gitignore
.DS_Store
*.log
```

**Stack detection**: Reuse the same logic scaffold.sh already has (lines 143-175 scan for package.json, requirements.txt, Cargo.toml, go.mod, etc.)

---

## Part 5: Implementation Plan

### Feature Breakdown

**F-NEW-1: Git-Deferred Mode** (`git_mode: none | deferred | active`)

Files to modify:
1. `.agentic/lib/init/scaffold.sh` — Remove auto `git init`, add `git_mode` to STACK.md
2. `.agentic/lib/init/init_playbook.md` — Update git docs, remove "requires git"
3. `.agentic/lib/init/STACK.template.md` — Add `git_mode: deferred` setting
4. `.agentic/lib/presets/profiles.conf` — Add `git_mode` per profile
5. `.agentic/lib/tools/settings.py` — Support `git_mode` setting in `get_setting()`
6. `.agentic/lib/tools/commands/commit.sh` — Gate on `git_mode: active`
7. `.agentic/lib/tools/commands/implement.sh` — Skip worktree when no git, fall back to in-place
8. `.agentic/lib/tools/dashboard.sh` — Show git_mode, suppress git checks when not active
9. `.agentic/lib/tools/wip.sh` — Handle no-git gracefully (no `git status` calls)
10. `.agentic/lib/tools/ag.sh` — Add `git-init` command, skip hook self-heal when not active
11. `.agentic/lib/hooks/pre-commit-check.sh` — Graceful no-op when `git_mode != active`

New files:
12. `.agentic/lib/tools/commands/git-init.sh` — The `ag git-init` command
13. `.agentic/lib/tools/gitignore.sh` — Stack-aware .gitignore generator

**F-NEW-2: WIP Visibility / Status Consistency**

Files to modify:
1. `.agentic/lib/tools/dashboard.sh` — Cross-reference feature states with source existence
2. `.agentic/lib/tools/status.sh` — Show active feature state positions

**Instruction file updates (framework-dev requirement):**
- `.agentic/lib/agents/claude/CLAUDE.md` — Add git-deferred info
- `.claude/skills/session-start.md` — Mention git-deferred in dashboard notes
- `.claude/skills/committing-changes.md` — Handle no-git case
- `.claude/skills/implementing-features.md` — No-worktree fallback
- `.agentic/lib/init/memory-seed.md` — Add git-deferred trigger words
- DEVELOPER_GUIDE.md, HOW_IT_WORKS.md

---

## Part 6: Verification

1. **New scratch project**: `ag init` → verify no `.git/`, STACK.md has `git_mode: deferred`
2. **Claude hooks still work**: PreToolUse, PostToolUse should fire without git
3. **`ag commit` gates properly**: Should print helpful message about `ag git-init`
4. **`ag implement` works without git**: Falls back to in-place (no worktree)
5. **`ag git-init`**: Creates `.git/`, `.gitignore` (stack-aware), initial commit, updates STACK.md
6. **`.gitignore` correct for stack**: Node project → `node_modules/`, `.pnpm-store/`, etc.
7. **Full lifecycle**: deferred → kickoff → implement → verify → git-init → commit
8. **`validate_framework.sh`** passes
9. **Existing projects unaffected**: Projects with `git_mode: active` (or no setting, defaults to active for backwards compat) work as before

---

## Part 7: Correction on .gitignore

The user mentioned "it did not add node_modules to .gitignore" but examining the project shows:
- `.gitignore` **does exist** with `node_modules/`, `dist/`, `.agentic/lib/`, `.agentic/session/`
- `node_modules/` correctly doesn't show in `git status` (it's being ignored)
- **BUT** `.pnpm-store/` is NOT in .gitignore and IS showing in git status
- The .gitignore was created but is incomplete for the pnpm stack

This validates the need for stack-aware .gitignore that detects pnpm and adds `.pnpm-store/`.

---

## Summary of Key Insights

1. **The "turbo mode" the user loved was the agent bypassing the formal workflow** — all features stayed "planned" while 1593 lines got written. This is a VALID and VALUABLE prototyping pattern. Don't enforce state machine here — instead, formally support "prototype then formalize" as a workflow.

2. **Claude hooks are the primary enforcement layer** and work without git. Git hooks are secondary. This makes git-deferred mode natural.

3. **Claude hooks DID nudge spec creation** — the agent created FEATURES.md, 3/6 AC files, and 8 NFRs because `acceptance_criteria: blocking` and PreToolUse spec-first checks were active. Hooks worked as advisory guidance even without blocking.

4. **NFRs are separate from ACs** — the 8 NFRs in NFR.md (60fps, neon style, etc.) should be embedded as testable criteria within relevant feature ACs. This is a known gap (feedback_nfr_in_ac.md) and separate from this work.

5. **BACKLOG.json not created** because kickoff wasn't used. Features were hand-created. Dashboard should handle this gracefully.

6. **Git was initialized but zero commits made** — the init creates git infrastructure that goes completely unused. Deferring it is the right call.

## Scope of This Work

**In scope:**
- Git-deferred mode (`git_mode: none | deferred | active`)
- `ag git-init` command
- Stack-aware .gitignore generation
- Dashboard/status improvements for deferred mode
- Instruction file updates

**Out of scope (separate features):**
- State machine enforcement for turbo mode (keep as-is)
- NFR embedding in ACs (existing feedback item)
- `ag formalize` command (future — reconcile code with feature states after prototyping)
