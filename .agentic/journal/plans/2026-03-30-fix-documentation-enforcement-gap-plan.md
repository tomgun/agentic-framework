# Fix Documentation Enforcement Gap

## Context

Documentation updates are supposed to happen as part of implementation — "spec + code + tests + docs = done" means docs ship in the same PR as the code. But agents consistently skip docs. The user had to explicitly ask for doc updates on the last PR. This is the second time this has been flagged.

**The gate machinery works. But it's the wrong enforcement point.** Docs should be updated before committing code, not caught post-merge.

## Root Cause

### Primary: implementing-features and committing-changes skills have no doc step
The skills that guide building features and creating PRs never tell agents to update documentation. The `updating-documentation` skill exists but is never referenced from the main workflow skills. Agents implement code, write tests, create PR — and docs aren't in the checklist.

### Secondary: completing-work skill misframes `ag done`
Presents `ag done` as "step 5 for VERSION bump" with steps 1-4 as manual alternatives. Agents do manual steps, skip `ag done`, and Gate 4 (doc freshness safety net) never fires.

### Tertiary: 2 docs lack `tracks` — always flagged stale
`LESSONS.md` and `ISSUES.md` have no tracks, so they're stale for every feature. Creates alarm fatigue.

### Current state: 8 stale docs
```
.agentic/spec/LESSONS.md, docs/INSTRUCTION_ARCHITECTURE.md, .agentic/spec/NFR.md,
.agentic/spec/ISSUES.md, .agentic/OVERVIEW.md, .agentic/lib/START_HERE.md,
.agentic/lib/PRINCIPLES.md, .agentic/lib/FRAMEWORK_MAP.md
```

## Plan

### Part A: Make docs part of implementation (primary enforcement)

**A1. Add doc step to implementing-features/SKILL.md**
File: `/workspace/.claude/skills/implementing-features/SKILL.md`

Add a new section after "Contract & test impact check":
```
## Documentation (before creating PR)
Docs are part of the deliverable — update them alongside code, not after merge.
1. Check freshness: `bash .agentic/lib/tools/docs.sh --check-freshness --trigger feature_done --manifest F-XXXX`
2. Update each stale doc that's relevant to your feature
3. Include doc changes in the same PR as the code

For framework development: also update instruction files (CLAUDE.md template, memory-seed,
DEVELOPER_GUIDE, HOW_IT_WORKS, etc.) — see DEV-003.
```

Also fix dead reference: replace `ag ship F-XXXX` (line 26, doesn't exist) with `ag done F-XXXX` noting it runs post-merge.

**A2. Add doc check to committing-changes/SKILL.md**
File: `/workspace/.claude/skills/committing-changes/SKILL.md`

Add step 4 to "Before committing" section:
```
4. Check doc freshness: `bash .agentic/lib/tools/docs.sh --check-freshness --trigger feature_done --manifest F-XXXX`
   Docs ship with code — update stale docs before creating the PR.
```

### Part B: Fix completing-work as safety net (last verification)

**B1. Rewrite completing-work/SKILL.md**
File: `/workspace/.claude/skills/completing-work/SKILL.md`

- Make `ag done F-XXXX` the single required post-merge action (not "step 5")
- Add note: "Gate 4 checks doc freshness as a safety net. If docs were updated in the PR (as they should be), this gate passes automatically. If it blocks, go back and update docs."
- Add rule: "NEVER skip `ag done`."

### Part C: Reduce false positives

**C1. Add `tracks` to trackless docs in STACK.md**
File: `/workspace/STACK.md`

- `LESSONS.md`: add `| .agentic/lib/,.agentic/spec/`
- `ISSUES.md`: add `| .agentic/lib/,.agentic/spec/`

### Part D: Catch up 8 stale docs

Update all 8 against features shipped since last touch (F-0210, F-036, F-033, F-004, F-003):

1. `.agentic/spec/LESSONS.md`
2. `docs/INSTRUCTION_ARCHITECTURE.md`
3. `.agentic/spec/NFR.md`
4. `.agentic/spec/ISSUES.md`
5. `.agentic/OVERVIEW.md`
6. `.agentic/lib/START_HERE.md`
7. `.agentic/lib/PRINCIPLES.md`
8. `.agentic/lib/FRAMEWORK_MAP.md`

### Sequencing

1. **Commit 1**: Parts A + B + C (skill fixes + STACK.md tracks) — the enforcement fix
2. **Commit 2**: Part D (doc catch-up) — the content fix

## Verification

1. `bash .agentic/lib/tools/docs.sh --check-freshness --trigger feature_done` → 0 stale after Part D
2. Read each skill file: implementing-features mentions docs before PR, committing-changes mentions docs before commit
3. `bash tests/validate_framework.sh` → passes
4. Trace: "agent follows implementing-features skill → hits doc step before creating PR → docs ship with code"

## Key files to modify

- `/workspace/.claude/skills/implementing-features/SKILL.md` (primary: add doc step)
- `/workspace/.claude/skills/committing-changes/SKILL.md` (add doc check)
- `/workspace/.claude/skills/completing-work/SKILL.md` (reframe as safety net)
- `/workspace/STACK.md` (add tracks to 2 entries)
- 8 stale doc files (content catch-up)

## Key files for reference (read-only)

- `/workspace/.agentic/lib/tools/commands/done.sh` (Gate 4 at lines 612-623)
- `/workspace/.agentic/lib/tools/docs.sh` (check_freshness at line 706)
