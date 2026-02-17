# Plan: Implement Remaining 13 Missing LLM Test Shell Scripts

**Status**: REVIEWING
**Iteration**: 2
**Created**: 2026-02-08
**Last Updated**: 2026-02-08

---

## Context

28 test definitions exist in `tests/llm/test_definitions.json`. After the v0.23.0 alignment work (which created tests 027-030, 035), 13 definitions still lack shell script implementations. This plan implements all 13.

## Approach

Direct translation from JSON definitions to shell scripts following the established harness pattern. Key design decisions from review:

- **Token-efficiency tests (024-026)**: Soft-check pattern (warnings, not hard failures) for optimization goals.
- **Proactive-behavior tests (036, 038, 040, 041)**: Soft-check pattern — these test aspirational agent behavior that varies across models.
- **All other tests**: Standard hard-check pattern with `|| ((FAILURES++))`.
- **gitignore handling**: `.agentic-state/` files (AGENTS_ACTIVE, WIP) are gitignored — use `git add -f` for those. `.agentic-journal/` is NOT gitignored (committed per project policy).

## Files to Create (13, all in `tests/llm/tests/`)

| # | File | Profile | Check Style | Key Fix from Review |
|---|------|---------|-------------|---------------------|
| 1 | `024_mentions_script_for_journal.sh` | core | soft | Differentiate from 004: focus on larger journal + token waste |
| 2 | `025_targeted_context_reading.sh` | core | soft | Improve output_not_contains (S-2) |
| 3 | `026_avoids_unnecessary_reads.sh` | core | soft | — |
| 4 | `031_references_journal_history.sh` | core | hard | Use explicit git add for .agentic-journal/ |
| 5 | `032_knows_architecture_from_context_pack.sh` | core | hard | — |
| 6 | `033_mentions_agents_active.sh` | core | hard | Populate AGENTS_ACTIVE + git add -f (C-1) |
| 7 | `034_suggests_worktree_for_parallel.sh` | core-pm | hard | — |
| 8 | `036_session_end_updates_artifacts.sh` | core | **soft** | Proactive behavior (I-5) |
| 9 | `037_detects_stale_status.sh` | core | hard | Fix output_not_contains to catch *following* stale advice (C-2) |
| 10 | `038_mentions_wip_on_work_start.sh` | core | **soft** | Proactive behavior (I-2, I-5) |
| 11 | `039_feature_complete_updates_chain.sh` | core-pm | hard | — |
| 12 | `040_blocker_creates_human_needed.sh` | core | **soft** | Proactive behavior (I-5) |
| 13 | `041_notices_stale_journal.sh` | core | **soft** | Proactive behavior (I-5) |

## Review Responses (Iteration 2)

### C-1: Test 033 empty AGENTS_ACTIVE + gitignore — ADDRESSED

Reviewer is correct on both points:
1. `.agentic-state/AGENTS_ACTIVE.md` is gitignored — `git add -A` will skip it.
2. Empty file provides no signal.

**Fix**: Populate AGENTS_ACTIVE.md with an active agent on a different feature (auth) and use `git add -f .agentic-state/AGENTS_ACTIVE.md` to force-track the gitignored file. The prompt asks about parallel work on payment — agent should notice the active agent on auth and mention coordination.

**Note**: This also changes the JSON definition's `setup.files` from empty to populated. However, **the shell script is the source of truth for the harness** — JSON defs are used by the interactive_runner.py (a separate tool). We should update the JSON as well, but the shell script is what runs.

### C-2: Test 037 output_not_contains false-fails — ADDRESSED

Reviewer is correct. An agent that says "STATUS.md mentions login form but this is outdated" would correctly detect staleness but fail the test.

**Fix**: Change the output_not_contains assertion from bare terms to patterns that catch *following* stale advice:
```
"should work on.*login\|let's.*password validation\|next.*email verification\|focus on.*login form"
```
Also update the JSON definition to match.

### C-3: Test 024 near-duplicate — PARTIALLY ADDRESSED

Reviewer identifies overlap with 004 and 021. However:
- 004 tests "uses journal.sh" (scripts section)
- 021 tests "doesn't read entire journal" (scripts section, 50-entry journal)
- 024 tests "token-efficient journal usage" (token-efficiency section, 4-session journal with realistic content)

The overlap is real but the JSON definition exists and needs a shell script. **Decision**: Implement 024 but differentiate by adding a comment that this is the token-efficiency angle of the same behavior. The shell test will focus on the "not reading entire" check as the hard failure, and journal.sh mention as the soft check. This makes it structurally identical to 004 — **acknowledged as low-value but implementing for completeness since the JSON def exists**.

### I-1: Test 033 overlap with 014 — ADDRESSED by C-1 fix

With populated AGENTS_ACTIVE and a different prompt scenario (asking about parallel work vs asking to work on a conflicting feature), tests are sufficiently distinct.

### I-2: Test 038 should use soft-check — ADDRESSED

Changed to soft-check pattern. WIP mention on work start is aspirational, not instructed.

### I-3: Test 041 prompt doesn't force JOURNAL read — PARTIALLY ADDRESSED

Reviewer makes a fair point. However, changing the prompt would diverge from the JSON definition. The agent is asked "Where did we leave off?" — a good agent should check both STATUS.md AND JOURNAL.md. The test checks for `"JOURNAL|journal|stale|outdated|hasn't been updated|last entry|January 10|gap|catch.up|update.*journal|no recent"` — this is a broad enough pattern. Additionally, using soft-check for this test (I-5) means a miss is a warning, not a failure.

### I-4: gitignore handling — ADDRESSED

`.agentic-journal/` is NOT gitignored (confirmed at .gitignore line 35). Tests 031, 036, 039, 041 use `.agentic-journal/JOURNAL.md` which is committed normally — just need `mkdir -p` + `git add`.

`.agentic-state/` IS gitignored. Tests 033 (AGENTS_ACTIVE) and 006 (WIP) need `git add -f`. Only 033 is new — it will use `git add -f`.

### I-5: Proactive-behavior tests should use soft-check — ADDRESSED

Tests 036, 038, 040, 041 changed to soft-check pattern. These test aspirational behaviors where hard failures create noise.

### S-1 through S-5 — NOTED

- S-1 (batch groups): Natural grouping in creation order. Accepted.
- S-2 (025 vacuous not_contains): Will improve patterns to catch actual behavior.
- S-3 (Profile header): Will add `# Profile:` header to all new tests.
- S-4 (mkdir bug): Will ensure correct `mkdir -p` patterns.
- S-5 (no live LLM validation): Acknowledged in testing strategy. Structural validation only.

## Updated JSON Changes

Two JSON definition changes needed alongside shell scripts:

1. **Test 033**: Update `setup.files` from empty AGENTS_ACTIVE to populated content
2. **Test 037**: Update `output_not_contains` from bare terms to "following stale advice" patterns

## Execution

1. Update 2 JSON entries in `test_definitions.json` (033, 037)
2. Create all 13 shell scripts
3. `chmod +x` all 13
4. Verify with `bash tests/validate_framework.sh` and `bash tests/llm/harness.sh --list`

## Testing Strategy

1. `bash tests/validate_framework.sh` — passes (new files don't affect validation)
2. `bash tests/llm/harness.sh --list` — all scripts listed without error
3. All new files executable
4. Every JSON test ID has a matching shell script (no gaps remain)
5. No live LLM validation — structural only (acknowledged limitation)

---

## Review History

### Review 1 (2026-02-08) — iteration 1
**Reviewer**: plan-reviewer-agent

**Issues Found**:
- [x] CRITICAL (C-1): Test 033 empty AGENTS_ACTIVE + gitignore = broken test
- [x] CRITICAL (C-2): Test 037 output_not_contains false-fails on quoted stale content
- [x] CRITICAL (C-3): Test 024 near-duplicate of 004+021
- [x] IMPORTANT (I-1): Test 033 vs 014 overlap larger than acknowledged
- [x] IMPORTANT (I-2): Test 038 should use soft-check (aspirational behavior)
- [x] IMPORTANT (I-3): Test 041 prompt doesn't force JOURNAL read
- [x] IMPORTANT (I-4): gitignore handling for .agentic-state/ files
- [x] IMPORTANT (I-5): Tests 036, 038, 040, 041 should use soft-check
- [x] SUGGESTION (S-1-S-5): Grouped creation, improved patterns, Profile header

**Verdict**: REVISION_NEEDED

**Planner Response** (iteration 2):
- C-1: Populate AGENTS_ACTIVE + git add -f
- C-2: Changed output_not_contains to match "following" stale advice
- C-3: Acknowledged overlap, implementing for completeness (JSON def exists)
- I-1: Resolved by C-1 fix
- I-2: Changed to soft-check
- I-3: Kept prompt (matches JSON), soft-check mitigates risk
- I-4: Confirmed .agentic-journal/ is NOT gitignored; only 033 needs git add -f
- I-5: Tests 036, 038, 040, 041 → soft-check pattern
- S-1-S-5: All accepted
