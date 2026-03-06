# F-0129: Git Hook Enforcement Plan

**Status**: APPROVED
**Created**: 2026-02-12
**Feature**: F-0129 — Prevent Direct `git commit` Bypass

## Context

Two enforcement gaps:
1. **No git hooks installed**: `.git/hooks/` has only `.sample` files, `core.hooksPath` not set
2. **`ag plan` over-gates**: Requires acceptance criteria before planning (backwards)

## Changes

### Prerequisite: Loosen `ag plan` gate
- `.agentic/tools/ag.sh` lines 423-430: Hard block → advisory warning
- `ag implement` retains independent hard gate at lines 574-583

### Fix 1: Replace pre-commit hook with dispatcher
- `.agentic/hooks/pre-commit`: CI detection, STACK.md config read, validate_specs routing, fast/full mode routing

### Fix 2: Add `--mode` flag to pre-commit-check.sh
- `_FAST_MODE` internal variable
- Fast mode keeps: checks 1, 2, 3, 3b, 3c, 7, 11 (structural blocking)
- Fast mode skips: checks 4, 5, 6, 8, 9, 10, 12 (tests, warnings, advisories)

### Fix 3: Wire hooks via `core.hooksPath` in scaffold.sh
- `git config core.hooksPath .agentic/hooks` for both profiles
- Git < 2.9 fallback to file copy

### Fix 4: `ag hooks install|status|disable` command
- Manual hook management for existing projects

### Fix 5: Hook check in `ag sync` (Phase 6)
- Auto-fix in full mode, report in check/quiet modes

### Fix 6: Hook status in `ag start`
- Warning if hooks not configured

### Fix 7: STACK.template.md + upgrade.sh
- Template: `pre_commit_hook: fast` (was commented-out `yes`)
- Upgrade: Configure hooks, clean stale files, migrate `yes` → `fast`

## Files Modified

| File | Change |
|------|--------|
| `.agentic/tools/ag.sh` | Loosened plan gate, added hooks cmd, start warning |
| `.agentic/hooks/pre-commit` | Replaced with dispatcher |
| `.agentic/hooks/pre-commit-check.sh` | Added `--mode` flag |
| `.agentic/init/scaffold.sh` | `core.hooksPath` instead of file copy |
| `.agentic/tools/sync.sh` | Phase 6: git hook check |
| `.agentic/init/STACK.template.md` | Uncommented + updated `pre_commit_hook` |
| `.agentic/tools/upgrade.sh` | Hook config + stale cleanup + value migration |

## Review History

### Review 1-3: See plan transcript
### Final: APPROVED after 3 review iterations
