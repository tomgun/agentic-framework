**Status**: APPROVED

# Fix Documentation Enforcement Gap (F-012)

## Context

Documentation updates are supposed to happen as part of implementation — "spec + code + tests + docs = done" means docs ship in the same PR as the code. But agents consistently skip docs. The user has flagged this twice. The user's explicit feedback: **docs should be updated before committing code, not after merge.**

## Root Cause (revised after dialectical review)

### Structural: `docs_updated` artifact check always passes
`state_machine_af.yaml:155` has `|| true` on the `docs_updated` artifact check. The `docs → ready_to_ship` transition requires `docs_updated` (line 37), but the check always succeeds. The structural gate is a rubber stamp.

### Behavioral: implementing-features and committing-changes skills have no doc step
The skills that guide building features and creating PRs never mention docs. `implementer.md:11,24` already instructs agents to update docs, but role prompt instructions are subject to context decay. Skills reinforce at the right moment (before commit).

### Configuration: 2 docs lack `tracks` — always flagged stale
`LESSONS.md` and `ISSUES.md` have no tracks, so they're checked for every feature. Creates alarm fatigue.

## Plan

### Part A: Fix structural enforcement (primary)

**A1. Remove `|| true` from `docs_updated` check in `state_machine_af.yaml`**
File: `/workspace/.agentic/state_machine_af.yaml` line 155

Change:
```yaml
check: "bash .agentic/lib/tools/drift.sh --docs --quiet 2>/dev/null || true"
```
To:
```yaml
check: "bash .agentic/lib/tools/drift.sh --docs --quiet 2>/dev/null"
```

This makes the `docs → ready_to_ship` transition actually enforce doc freshness. In lean mode (line 72), this transition is skipped anyway (`implementation → ready_to_ship`), so tiny fixes aren't affected.

### Part B: Add doc steps to skills (behavioral reinforcement)

**B1. Add doc section to implementing-features/SKILL.md**
File: `/workspace/.claude/skills/implementing-features/SKILL.md`

Add section after "Contract & test impact check":
```
## Documentation (before creating PR)
Docs are part of the deliverable — update them alongside code, not after merge.
1. Check freshness: `bash .agentic/lib/tools/docs.sh --check-freshness --trigger feature_done --manifest F-XXXX`
2. Update each stale doc relevant to your feature
3. Include doc changes in the same PR as code
4. For complex doc work, use the `updating-documentation` skill

For framework development: also update instruction files (CLAUDE.md template, memory-seed,
DEVELOPER_GUIDE, HOW_IT_WORKS, etc.) — see DEV-003.
```

Also fix dead reference: `ag ship F-XXXX` → `ag done F-XXXX` (no ship command exists).

**B2. Add doc check to committing-changes/SKILL.md**
File: `/workspace/.claude/skills/committing-changes/SKILL.md`

Add step 4 to "Before committing":
```
4. Check doc freshness: `bash .agentic/lib/tools/docs.sh --check-freshness --trigger feature_done --manifest F-XXXX`
   Docs ship with code — update stale docs before creating the PR.
```

**B3. Rewrite completing-work/SKILL.md**
File: `/workspace/.claude/skills/completing-work/SKILL.md`

- Make `ag done F-XXXX` the single required post-merge action (not "step 5")
- Gate 4 = safety net. If docs were updated in the PR, this passes automatically.
- Add to "Before running `ag done`": verify doc freshness as third precondition
- Add rule: "NEVER skip `ag done`."

### Part C: Reduce false positives

**C1. Add `tracks` to trackless docs in STACK.md**
File: `/workspace/STACK.md`

- `LESSONS.md`: add `| .agentic/lib/,.agentic/spec/`
- `ISSUES.md`: add `| .agentic/lib/,.agentic/spec/`

### Part D: Catch up stale docs (separate work item)

Update all 8 stale docs. **This is a separate commit** from the enforcement fix so the systemic changes can be shipped and evaluated independently.

## Sequencing

1. **Commit 1**: Parts A + B + C — structural fix + skill reinforcement + config
2. **Commit 2**: Part D — doc catch-up (separate work, can be deferred)

## Verification

1. `bash tests/validate_framework.sh` → passes
2. Read each skill file: implementing-features mentions docs before PR, committing-changes mentions docs before commit
3. Verify `state_machine_af.yaml` no longer has `|| true` on docs_updated
4. `bash .agentic/lib/tools/docs.sh --check-freshness --trigger feature_done` → shows stale docs correctly
5. Trace: agent follows implementing-features → doc step before PR → docs ship with code → Gate 4 passes automatically

## Key files to modify

- `/workspace/.agentic/state_machine_af.yaml` (line 155: remove `|| true`)
- `/workspace/.claude/skills/implementing-features/SKILL.md`
- `/workspace/.claude/skills/committing-changes/SKILL.md`
- `/workspace/.claude/skills/completing-work/SKILL.md`
- `/workspace/STACK.md` (add tracks to 2 entries)
