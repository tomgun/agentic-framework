<!-- migration-id: 012 -->
<!-- date: 2026-03-10 -->
<!-- author: Claude -->
<!-- type: feature -->

# Migration 012: F-0196 AC-024: VERSION moves to ag flush allowlist — multi-PR VERSION conflicts make in-PR bumping unworkable; post-merge bump via ag done is conflict-free

## Context & Why

When multiple PRs are open simultaneously, each bumps VERSION in the PR branch. On merge, the second PR always conflicts on VERSION. This creates unnecessary friction for a mechanical operation (patch bump). Moving VERSION bumps to post-merge (`ag done`) eliminates the conflict entirely — only one branch (main) ever writes VERSION.

## Changes

### Features Added

None.

### Features Modified

- F-0196: AC-024 reversed from "VERSION is NOT in the allowlist" to "VERSION IS in the allowlist"
  - `state-commit.sh` allowlist now includes `VERSION`
  - `ag done` (`cmd_done` in `ag.sh`) auto-bumps VERSION (patch) when on main/master
  - All instruction files changed from "Every PR: bump VERSION" to "Every merge: bump VERSION via `ag done`"
  - Committing-changes skill no longer mentions VERSION bump; completing-work skill documents the auto-bump

### Features Deprecated

None.

## Dependencies

- **Requires**: F-0196 (ag flush) already shipped
- **Blocks**: None
- **Related**: None

## Acceptance Criteria

- [x] VERSION is in the `state-commit.sh` allowlist
- [x] `ag done` bumps VERSION (patch) on main and flushes
- [x] `ag done` skips VERSION bump on feature branches/worktrees
- [x] T-0098 validates VERSION IS in the allowlist
- [x] All instruction files reference post-merge workflow

## Implementation Notes

- VERSION bump logic is inlined in `cmd_done` (5 lines, no separate script needed)
- Semver format is validated before writing — unexpected formats produce a warning, no write
- Discovery profile returns early in `cmd_done` and never reaches the bump code — intentional
- For minor/major bumps, users edit VERSION manually before running `ag done`

## Rollback Plan

1. Remove `"VERSION"` from `ALLOWLIST` in `state-commit.sh`
2. Remove the VERSION bump + flush block from `cmd_done` in `ag.sh`
3. Revert T-0098 in `validate_framework.sh` to check VERSION is NOT in allowlist
4. Restore "Every PR: bump VERSION" in all instruction files
5. Revert AC-024 text in `F-0196.md`

## Related Files

- `.agentic/lib/tools/ag.sh` — Added VERSION bump + flush in `cmd_done`
- `.agentic/lib/tools/state-commit.sh` — Added VERSION to allowlist
- `tests/validate_framework.sh` — Inverted T-0098
- `.agentic/spec/acceptance/F-0196.md` — Updated AC-024, verification, out-of-scope
- `CLAUDE.md`, `.cursorrules`, `.github/copilot-instructions.md`, `.codex/instructions.md` — Updated VERSION rule
- `.agentic/lib/init/memory-seed.md` — Added post-merge note to pre-commit sequence
- `.agentic/lib/agents/claude/skills/committing-changes/SKILL.md` — Removed VERSION bump
- `.agentic/lib/agents/claude/skills/completing-work/SKILL.md` — Added Step 3b
- `.claude/skills/committing-changes/SKILL.md` — Removed VERSION bump
- `.claude/skills/completing-work/SKILL.md` — Updated Step 4c

## Notes

The `state-commit.sh` comment mentions "VERSION semver validation" but the validation happens in `ag done` (the writer), not in `ag flush` (the committer). The flush layer trusts that VERSION content is valid since only `ag done` writes it programmatically.
