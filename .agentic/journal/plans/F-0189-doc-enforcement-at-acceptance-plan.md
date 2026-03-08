# Plan: Documentation Enforcement at Feature Acceptance (F-XXXX)

## Context

The framework principle "Code + docs = done" is stated in CLAUDE.md but agents routinely skip doc updates during implementation. The user has to constantly remind agents. Current enforcement is too late or too weak:

- **Pre-commit** checks JOURNAL/STATUS/FEATURES freshness — but checking doc drift on every commit is too frequent
- **`ag done`** has `docs_gate` — but the underlying state machine gate is purely advisory
- **Skills** mention docs — but as optional checklist items agents skip

The `verified → documented` state machine gate (gates.py:312-333) exists but is purely advisory: it checks CHANGELOG and emits a warning. It never calls drift.sh, never reads `docs_gate`, and never blocks. Autonomode has no doc step at all.

**Goal**: Enforce documentation updates at feature acceptance and merge time — when a feature is being completed, reviewed, or shipped. Not on every commit (too noisy), but at the gates that matter.

## Approach: Wire Existing Enforcement Into Acceptance/Merge Points

No new tooling needed. The pieces exist — `drift.sh --docs`, `docs_gate` setting, state machine gate — they're just not connected to the right moments.

### Step 1: Fix `drift.sh --docs` to support `--check` exit code

**File**: `.agentic/lib/tools/drift.sh` (lines 38-58, 997-1006)

Currently `--docs` always returns 0 (advisory). Need it to return non-zero when drift is found, so gates and scripts can use the exit code.

- Allow `--docs` and `--check` flags simultaneously (currently `--docs` overrides MODE to `"--docs"`)
- Add a `DOCS_CHECK` flag that persists alongside `DOCS_MODE`
- In main(), when `DOCS_MODE && DOCS_CHECK`: return non-zero if `DRIFT_COUNT > 0`

### Step 2: Strengthen `gate_verified_to_documented` in gates.py

**File**: `.agentic/lib/auto/gates.py` (lines 312-333)

The state machine gate becomes real enforcement. Note: `ag done` already has its own `docs_gate` check in `ag.sh` — this gate matters for state machine transitions, autonomode, and any code using the state machine API directly.

- Parse `docs_gate` from STACK.md (follow pattern from components.py/verify.py — read file, regex match)
- When `docs_gate == "off"`: return `GateResult.ok()` (no checks)
- When `docs_gate != "off"`: shell out to `drift.sh --docs --check --manifest {feature_id}` and capture exit code + output
- Keep existing CHANGELOG check
- When `docs_gate == "blocking"` and drift found: return `GateResult.blocked(...)`
- When `docs_gate == "warning"`: return `GateResult.ok(warnings=[...])`

### Step 3: Add doc update step to implementing-features skill

**File**: `.claude/skills/implementing-features/SKILL.md`

Add explicit doc step after implementation, before declaring done. This is the highest-impact change for manual agent workflows — the skill is loaded every time an agent implements a feature.

Key: point agents at the existing doc registry (`## Docs` in STACK.md) so they know *which* docs to update.

> **Documentation**: Before declaring done, check which project docs need updating:
> 1. Run `bash .agentic/lib/tools/docs.sh --list` to see the project's doc registry
> 2. Run `bash .agentic/lib/tools/drift.sh --docs` to detect stale docs
> 3. Update docs in the same change as code — don't defer to a follow-up
> 4. If you created a new user-facing artifact, add it to the `## Docs` section in STACK.md
>
> Doc updates are enforced at feature acceptance (`ag done`) when `docs_gate: blocking`.

### Step 4: Strengthen reviewing-code skill doc dimension

**File**: `.claude/skills/reviewing-code/SKILL.md`

Change the "Documentation" review dimension from generic ("Are comments and docs updated?") to actionable, since review happens at merge time:

> **Documentation**: Run `docs.sh --list` to see registered docs, then `drift.sh --docs` to check for drift. Check CHANGELOG updated for behavior changes. Check if new user-facing artifacts need adding to `## Docs` in STACK.md. Flag missing doc updates as "Must Fix" when `docs_gate: blocking`.

### Step 5: Add doc step to autonomode pipeline (task.py)

**File**: `.agentic/lib/auto/task.py` (between lines 196-199)

After verify loop, before PR creation — this is the autonomode equivalent of "feature acceptance":
1. Read `docs_gate` from STACK.md
2. If not `off`: run `drift.sh --docs --check`
3. If drift detected: spawn Claude with doc-update prompt (update flagged docs, add CHANGELOG entry)
4. Commit doc updates separately before creating PR

### Step 6: Add doc reminder to autonomode AC prompt (engine.py)

**File**: `.agentic/lib/auto/engine.py` (lines 436-446)

Add one line to the AC implementation prompt:
```
- If your changes affect documented behavior (README, CHANGELOG, docs/), update those docs in the same change
```

Lightweight — doesn't block, just makes Claude aware during implementation.

## Files Changed (6 files)

| # | File | Change |
|---|------|--------|
| 1 | `.agentic/lib/tools/drift.sh` | Support `--docs --check` (non-zero exit on drift) |
| 2 | `.agentic/lib/auto/gates.py` | Strengthen verified→documented gate with drift.sh + docs_gate |
| 3 | `.claude/skills/implementing-features/SKILL.md` | Add explicit doc update step |
| 4 | `.claude/skills/reviewing-code/SKILL.md` | Strengthen doc review dimension for merge reviews |
| 5 | `.agentic/lib/auto/task.py` | Add doc check/update step between verify and PR |
| 6 | `.agentic/lib/auto/engine.py` | Add doc instruction to AC prompt |

## Feature Tracking

Register as F-XXXX in FEATURES.md with acceptance criteria before implementation.

## Verification

1. `bash tests/validate_framework.sh` — structural tests pass
2. Smoke test: `drift.sh --docs --check` returns non-zero when docs are stale
3. Gate test: `gate_verified_to_documented` with `docs_gate: blocking` + stale docs returns `GateResult.blocked`
4. Autonomode: task.py spawns doc-update Claude when drift detected before PR
5. Unit tests for the gate (test_gates.py)

## What This Does NOT Do (by design)

- **No pre-commit check** — doc drift on every commit is too noisy. Enforcement belongs at feature acceptance/merge.
- **No Phase 3 dependency** — works now with current state machine. Phase 3 review checkpoints can add `review_documented` later.
- **Backward compatible** — `docs_gate: off` (Discovery default) skips all checks. Only Formal profile gets enforcement.
