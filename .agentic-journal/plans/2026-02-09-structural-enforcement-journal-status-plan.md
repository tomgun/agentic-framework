# Structural Enforcement: JOURNAL.md & STATUS.md Updates Before Commits

**Status**: REVIEWED

## Context

Previous plan (REVISION 2) added constitution-layer rules and `ag commit` reminders — already implemented. But the user's core frustration remains: **LLMs don't reliably follow instructions under cognitive load.** Text rules help marginally, but the agent that bypassed `ag commit` had the trigger word table right there.

This plan adds **structural enforcement** — mechanisms that physically prevent the wrong action rather than advising against it. Two layers:

1. **Git pre-commit hook** (cross-agent): Blocks commits when JOURNAL/STATUS are stale. Works for Claude, Cursor, Copilot, Codex — anything using git.
2. **Claude Code UserPromptSubmit hook** (Claude-specific): Injects reminder before each response when uncommitted changes exist but artifacts are stale. Agent reads this and updates proactively.

## Why JOURNAL & STATUS (and not other artifacts)

Audited all 20+ state files in the framework. Most are either:
- **Already enforced** at their chokepoint (FEATURES.md/acceptance criteria → pre-commit blocks shipped features without acceptance)
- **Event-driven** (HUMAN_NEEDED.md → add when blocker found, not time-based)
- **Periodic** (CONTEXT_PACK.md, OVERVIEW.md → architecture changes, not per-commit)

Only JOURNAL.md and STATUS.md need **per-session/per-commit** updates — they track "what happened" and "current state." These are exactly the ones agents forget.

## Changes

### 1. Make staleness checks BLOCKING in pre-commit-check.sh

**File**: `.agentic/hooks/pre-commit-check.sh`

**Check 3** (JOURNAL staleness, lines 157-205):
- Remove requirement for `spec/FEATURES.md` + in-progress features — apply to ANY project with JOURNAL.md
- Reduce threshold from 24h to **2h** (session-appropriate)
- Change from WARNING to **BLOCKING** (increment FAILURES counter)
- Clear message with copy-paste fix command
- Respect `SKIP_STALENESS` escape hatch

**Check 3b** (STATUS staleness, lines 207-235):
- Reduce threshold from 48h to **4h**
- Change from WARNING to **BLOCKING** (increment FAILURES counter)
- Clear message with copy-paste fix command
- Respect `SKIP_STALENESS` escape hatch

**Blocking message format** (gives agent exact command to run):
```
❌ BLOCKED: JOURNAL.md not updated recently (last modified: Xh ago)
   Update before committing:
   bash .agentic/tools/journal.sh "Topic" "Done" "Next" "Blockers"

   To skip (feature branches only): SKIP_STALENESS=1 git commit ...
```

### 2. Add SKIP_STALENESS escape hatch

**File**: `.agentic/hooks/pre-commit-check.sh` (lines 36-65, escape hatch section)

Follow existing pattern (SKIP_TESTS, SKIP_COMPLEXITY):
- Add `SKIP_STALENESS=1` env var
- Block on main/master (line 47: add to the `if` condition)
- Show warning when active
- Update header comments (lines 23-25)

### 3. Add artifact reminder to Claude UserPromptSubmit hook

**File**: `.agentic/claude-hooks/UserPromptSubmit.sh`

Add section BEFORE the existing acceptance-criteria check. Logic:
1. Check: are there uncommitted changes? (`git status --porcelain`)
2. If yes: check JOURNAL.md mtime (>1h = stale) and STATUS.md mtime (>1h = stale)
3. If either stale: output reminder with exact commands to run

Only triggers when uncommitted changes exist AND artifacts are >1h stale. Silent otherwise. All commands (git status, stat) complete well within the 3s timeout.

### 4. Do NOT change

- **scaffold.sh** — hook installation scope (see "Known gaps" below)
- **Stop.sh** — already has end-of-session reminders
- **PostToolUse.sh** — can't detect git commits (no tool name/input access per API), adding here would be noise on every tool use
- **pre-commit wrapper** (`.agentic/hooks/pre-commit`) — no changes needed

## Review Notes

**Threshold reasoning:**
- 2h JOURNAL: session-start READS JOURNAL but doesn't WRITE. So mtime reflects last `journal.sh` run. Agent runs journal.sh → mtime resets → commit passes. If agent forgets → mtime stays old → commit blocked. Correct behavior.
- 4h STATUS: STATUS changes less frequently. 4h avoids blocking on short follow-up sessions where STATUS was set at start.
- 1h Claude hook: More aggressive than pre-commit (proactive reminder before agent even starts working toward a commit).

**Edge cases checked:**
- JOURNAL.md doesn't exist → check SKIPPED (graceful, same as current)
- Agent runs journal.sh then immediately commits → mtime is now → PASSES
- Multiple quick commits → second commit at +5min still within 2h → PASSES (limitation: doesn't guarantee JOURNAL reflects second commit's work; accepted trade-off vs. staged-file check noise)
- UserPromptSubmit fires on "hello" with no uncommitted changes → SILENT (no git changes detected)
- 3s timeout budget: git status ~50ms + stat ~1ms = well under limit

**Known gaps (out of scope for this plan):**
- Core profile: pre-commit hook installed only for Core+PM (scaffold.sh). Core users get Claude hook but no git-level enforcement for Cursor/Copilot/Codex. Recommend installing for Core too in a follow-up.

## Verification

1. `bash tests/validate_framework.sh` passes
2. Manual: set JOURNAL mtime to 3h ago → `git commit` → BLOCKED with clear message
3. Manual: `bash .agentic/tools/journal.sh ...` → `git commit` → passes
4. Manual: `SKIP_STALENESS=1 git commit` on feature branch → passes with warning
5. Manual: `SKIP_STALENESS=1 git commit` on main → BLOCKED
6. LLM tests 004, 005 still pass
7. Claude hook: start session with uncommitted changes + stale JOURNAL → see reminder

## Files Modified (2 files)

1. `.agentic/hooks/pre-commit-check.sh` — checks 3/3b → blocking, escape hatch, header comments
2. `.agentic/claude-hooks/UserPromptSubmit.sh` — add stale artifact reminder
