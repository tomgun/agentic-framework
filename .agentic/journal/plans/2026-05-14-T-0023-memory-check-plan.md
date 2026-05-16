---
task: T-0023
feature: F-022
date: 2026-05-14
status: APPROVED
profile: autonomous_formal
review:
  critic: ab5d2543a3c91632e
  advocate: ae166ceb9b3540695
  convergence: manual
  iterations: 1
---

# T-0023 — Smarter memory-seed sync (worktree fix + structured diff)

**Status**: APPROVED (with revisions from review round 1)

## Revisions applied after review

1. `git log -S | tail -1` is wrong (picks oldest, not introducing). Use `git log -1 -S "memory-seed v${CURRENT_VERSION}" -- <seed>` → newest introducing commit; `${COMMIT}^` for prior state.
2. After `${COMMON_DIR%/.git}` strip, require `[ -d "$MAIN_GIT/.agentic" ]`; fall back to `--show-toplevel` if not. Protects against bare repos and `repo.git`-named dirs.
3. Section parser keys on `<!-- section: anchor-slug -->` HTML comments under each `^## ` (added to seed file). Rename → MODIFY, not REMOVE+ADD.
4. Contract assertion IDs are auto-assigned by `ag contract migrate --add-assertion`. Use stable text prefixes (`memory-check.sh: ...`) instead of named ACs.
5. Add trigger entry in `.agentic/lib/init/memory-seed.md` (and `.agentic/lib/agents/claude/CLAUDE.md` template) explaining `PATCH N/N` output. Without this the new output is invisible to agents.
6. LLM test oracle: agent emits `Edit` calls against `MEMORY.md` with `old_string` verbatim from `-` lines and `new_string` from `+` lines of the PATCH blocks.
7. Auto-bump version marker into `ag done` → out of scope; tracked as follow-up TODO.
**Owning feature**: F-022 (Framework Architecture & Paths, shipped) — hardening + new sub-capability. No new F-XXXX (no-feature-inflation rule). New behavior is added via `ag contract migrate F-022`.

## Problem

`.agentic/lib/tools/memory-check.sh` is the framework's advisory check that an agent's auto-memory matches `memory-seed.md`. Three latent bugs make it currently a no-op, and the stale-handling behavior (when fixed) is too coarse:

1. **SEED_FILE path is wrong** (`memory-check.sh:64`):
   ```bash
   SEED_FILE="$ROOT_DIR/.agentic/init/memory-seed.md"
   ```
   Actual file lives at `.agentic/lib/init/memory-seed.md` (note `lib/`). The `[ ! -f "$SEED_FILE" ]` guard at line 65 silently short-circuits to `Memory check: skipped (no memory-seed.md found)`. **The script never reaches any real check.**

2. **Worktree path bug** (`memory-check.sh:53`):
   ```bash
   REPO_ROOT="$(git -C "$ROOT_DIR" rev-parse --show-toplevel ...)"
   ```
   Inside a worktree, `--show-toplevel` returns the worktree path. Claude Code's `MEMORY.md` is keyed off the **main** repo path (`~/.claude/projects/<main-repo-as-hash>/memory/MEMORY.md`). Worktree sessions report a phantom "not seeded" because they look at the wrong directory.

3. **No version marker in seed file**: `memory-seed.md` has no `memory-seed vX.Y.Z` line, so `EXPECTED_VERSION` is always empty and the stale check (line 82) is unreachable.

Beyond those, T-0023 itself asks for:

4. **Structured diff on stale**: today the advisory is `To update: Re-read .agentic/init/memory-seed.md and update memory` — the agent has to re-read ~115 lines and reconcile by hand.
5. **Structured patch output**: emit the changes as per-section ADD/REMOVE/MODIFY blocks so the agent applies targeted edits, not a wholesale rewrite.

## Plan

### Phase 1 — Fixes (Tier 0; preconditions for everything else)

1. **Fix SEED_FILE path** → `$ROOT_DIR/.agentic/lib/init/memory-seed.md`.
2. **Worktree-safe REPO_ROOT**:
   ```bash
   COMMON_DIR="$(git -C "$ROOT_DIR" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || skip
   # Strip trailing /.git if present (it always is for non-bare repos)
   MAIN_GIT="${COMMON_DIR%/.git}"
   REPO_ROOT="$MAIN_GIT"
   ```
   For a worktree, `--git-common-dir` points at `/path/to/main/.git`; strip `/.git` → main repo root. For the canonical repo, same answer. Bare repo edge case: the script already gates on `$HOME/.claude` existing and `paths.sh` being sourced, so a bare repo wouldn't be running this anyway, but we'll fall back to `--show-toplevel` if the dirname trick produces something unusable (no `.agentic/` under it).
3. **Add version marker to seed file**: top-of-file line `<!-- memory-seed v0.85.2 -->` (mirrors framework `VERSION`). Manual sync acceptable initially; T-0023 doesn't require auto-bump. Add a comment in `VERSION` or in the seed file pointing to where the next maintainer should update it.

### Phase 2 — Structured diff when stale

When `CURRENT_VERSION` (from MEMORY.md) and `EXPECTED_VERSION` (from seed file) differ:

1. Resolve the commit that introduced `<!-- memory-seed v${CURRENT_VERSION} -->`:
   ```bash
   PRIOR_REV="$(git -C "$REPO_ROOT" log -S "memory-seed v${CURRENT_VERSION}" \
       --format=%H -- .agentic/lib/init/memory-seed.md | tail -1)"
   ```
2. If `PRIOR_REV` resolves: `git diff "$PRIOR_REV..HEAD" -- .agentic/lib/init/memory-seed.md`.
3. If it doesn't (memory-seed isn't in git, no matching commit, etc.): fall back to today's behavior with a clearer message ("can't reconstruct diff for v${CURRENT_VERSION}, re-read the seed").

### Phase 3 — Section-keyed patch output

1. The seed file has stable `^## ` section headers ("Key Commands", "Trigger Words", "After Plan Mode Exits — Auto-Continue", etc.). Parse both versions into sections keyed by header text.
2. For each section: `ADD` (new section), `REMOVE` (gone), or `MODIFY` (content changed; show unified diff for that section only).
3. Emit a numbered block per section:
   ```
   PATCH 1/3 — MODIFY section "After Plan Mode Exits — Auto-Continue"
   -  Save plan to .agentic/journal/plans/...
   +  Save plan to .agentic/journal/plans/...  (status: DRAFT)
   ```
4. Footer: `Apply these N patches to your MEMORY.md; preserve project-specific entries outside framework sections.`

Implementation: pure bash + `git diff` for content; an `awk` pass for header-based section splitting. No new dependencies. Add a small helper script `.agentic/lib/tools/memory-diff.sh` so the sectioning logic is testable in isolation.

### Phase 4 — Tests

1. **Shell unit tests** in `tests/memory_check_test.sh` (or extend existing test runner — see what `tests/validate_framework.sh` lists):
   - Resolver returns main repo root from inside a fixture worktree.
   - SEED_FILE points to an existing file.
   - Sectioning helper: feed two fixture seeds, assert ADD/REMOVE/MODIFY blocks match snapshot.
   - Stale-with-no-prior-rev path uses fallback message (not a crash).
2. **LLM test** (framework-dev mandatory rule) under `.agentic/test/llm/`: simulate stale state, assert agent produces correctly-targeted memory edits from the patch block.

### Phase 5 — Contract assertions (F-022 is shipped)

Use `ag contract migrate F-022 --reason "T-0023 memory-check worktree + structured diff" --add-assertion "..."` to add:

- `AC-memory-check-worktree`: memory-check.sh resolves to main repo root from inside a worktree. Verify: structural test that uses a fixture worktree.
- `AC-memory-check-structured-diff`: stale output contains at least one `PATCH N/N` block when prior version is reachable. Verify: structural test against fixture.

(Existing F-022 AC-001..003 untouched.)

## Non-goals

- Auto-bumping the seed version marker on every framework release (manual sync for now; can be follow-up).
- Supporting Cursor/Windsurf/Copilot memory paths (`memory-check.sh:43-49` already documents these as out of scope).
- Auto-applying patches to MEMORY.md (the LLM applies them; script only proposes).

## Risk areas

- `git log -S "memory-seed v..."` is `O(history)` on the seed file — fine because seed file has short history; if it grows, swap to a `--first-parent` walk.
- Section parsing relies on stable `^## ` headers; if someone reorganizes the seed with `^# ` or nested `^### `, the diff degrades to "whole file changed". Acceptable; not silently wrong.
- Worktree-safe REPO_ROOT change must not regress the canonical-repo case. Test fixture covers both.

## Touched files (estimate)

- `.agentic/lib/tools/memory-check.sh` — modified
- `.agentic/lib/tools/memory-diff.sh` — new (sectioning helper)
- `.agentic/lib/init/memory-seed.md` — add version marker line
- `tests/memory_check_test.sh` (or equivalent under existing test infra) — new
- `.agentic/test/llm/memory_check_stale.md` — new LLM test
- `.agentic/spec/contracts/F-022.yaml` — new ACs (via `ag contract migrate`)
- `CONTRIBUTIONS.md` — note user insight on diff-instead-of-reread

Within the 10-file budget.
