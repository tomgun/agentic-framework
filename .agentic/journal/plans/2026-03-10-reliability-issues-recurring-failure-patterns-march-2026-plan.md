# Reliability Issues & Recurring Failure Patterns — March 2026

## Analysis of the Agentic Framework

This document catalogs reliability issues, bugs, and recurring failure patterns discovered during March 2026 development, drawn from the journal, session transcripts, TODO, CONTRIBUTIONS, and FRAMEWORK_DEVELOPMENT.md.

---

## TIER 1: RECURRING SYSTEMIC PATTERNS (keep breaking repeatedly)

### 1. "Infrastructure Without Wiring" — Features Built But Never Connected

**Pattern**: Code gets written, tests pass, but the feature is never actually reachable from the entry point users/agents invoke. This is the single most damaging recurring pattern.

**Instances in March 2026**:
- **F-0177 State Machine Gates (Mar 8)**: 65 unit tests passed, but `register_default_gates()` was never called in `main()`. Feature was completely non-functional in production. Only discovered when user asked "how do we know it works?" and a CLI smoke test was run. Also uncovered a Python `__main__` dual-import bug (running as script created a *different* `FeatureState` enum than the one gates registered against).
- **Git Hooks (multiple incidents, Feb-Mar)**: Pre-commit hooks existed since v0.20 but git never called them. `scaffold.sh` copied hook files to `.git/hooks/` which got overwritten. `core.hooksPath` was never set. Every quality gate (WIP locks, staleness checks, branch policy) was **theater**. Fixed with F-0129 but then broke AGAIN when hooks weren't verified after init in real projects (fixed again Mar 3).
- **AGENTS_ACTIVE.md (T-0017)**: Referenced in 30+ files but no script or hook ever creates/updates it. Pure behavioral instruction with zero structural backing. A "dead feature."
- **Backlog Advancement (Mar 9, latest fix)**: `ag done` auto-advances BACKLOG.json locally, but completing-work and committing-changes skills never staged BACKLOG.json for commit. Result: shipped features stayed on top of the backlog across sessions because the advancement was never committed. Fixed Mar 9 but represents the SAME pattern.

**Status**: Smoke test gate was added to checklists after F-0177, but there is no automated enforcement. The pattern continues to produce new instances (backlog was the most recent one, discovered Mar 9).

**Root cause**: Unit tests verify internal logic but not CLI wiring. The framework has no mandatory end-to-end integration test that exercises the actual user-facing entry point.

---

### 2. "Instruction Files Are Always Stale" — Doc/Instruction Drift After Feature Shipping

**Pattern**: A feature ships in code but instruction files, skills, checklists, and agent-facing docs don't get updated in the same commit. Agents in user projects can't use the feature because they never learn about it.

**Instances in March 2026**:
- **F-0190 Backlog (Mar 8)**: Code-complete but agents had no awareness. Required 4 follow-up sessions to update 18 files across quick commands, trigger tables, routing rules, session start, feature gates, and completion flow.
- **F-0143 Skills Architecture (Feb 28 - Mar 1)**: After shipping, stale docs still referenced the old auto-generated skills approach. Required separate "Post-F-0143 Doc Sync" session to update 12 files.
- **Spec Protection (Mar 7)**: Was invisible in agent entry points. Agents only discovered it when pre-commit Check 14 blocked them. Required adding bullets to all 5 instruction files.
- **v0.36 dogfooding sync (Mar 1)**: F-0136/0139/0140/0141/0145/0146/0147 were all shipped but instruction files were stale. Required a separate sync session.
- **F-0180 Review Checkpoints (Mar 8)**: Separate session needed after code was done just for instruction file updates (13 files, 21 validation tests).

**Status**: The framework rule "instruction files are part of the feature" exists but is not structurally enforced. F-0189 (Doc Enforcement) was shipped Mar 8 to add drift detection to feature acceptance gates, but the pattern predates it and continued after.

**Root cause**: The number of files that need updating per feature is extremely high (often 10-18 files). No single tool checks all locations. Agents treat code completion as feature completion.

---

### 3. "Silent Bypass / Silent Skip" — Enforcement That Doesn't Actually Enforce

**Pattern**: Quality gates exist but are silently bypassed or skipped due to missing wiring, wrong paths, or unchecked conditions.

**Instances in March 2026**:
- **HUMAN_NEEDED path broken since directory restructure (Mar 9)**: `sync.sh` and `ag.sh` used a hardcoded root path instead of `$HUMAN_NEEDED_FILE` from `paths.sh`. PR auto-resolve was silently skipping the file after the v0.41.0 directory restructure. Nobody noticed until explicitly checked.
- **Git hooks not verified after init (Mar 3)**: Dogfooding in a real project revealed hooks were never verified after scaffolding. Three defense-in-depth layers had to be added (init verification, session-start check, pre-commit agent-side check).
- **Pre-commit checks were theater (Feb-Mar 12)**: 786 lines of pre-commit checks, 12 structural gates — but `core.hooksPath` was never set, so none ever ran.
- **Spec staleness gate false trigger (Feb 18)**: NFR spec changes incorrectly triggered the FEATURES.md staleness gate.
- **`((count++))` under `set -e` (Mar 5)**: Silently crashed scripts mid-run. Arithmetic expressions returning 0 cause `set -e` to abort.

**Status**: The path issue was fixed Mar 9. But the pattern of paths breaking after restructuring is concerning — other hardcoded paths may exist.

**Root cause**: No integration test verifies that all quality gates actually execute. Testing individual scripts in isolation doesn't catch wiring failures.

---

### 4. "Plans and State Lost Between Sessions" — Session-Scoped Data Treated as Durable

**Pattern**: Data created during a session is assumed to persist but actually doesn't survive session boundaries.

**Instances in March 2026**:
- **Plans lost in ~/.claude/plans/ (recurring)**: Plans created through Claude Code plan mode are session-scoped with random filenames. The "copy plan after approval" rule exists but is behavioral-only. T-0047 and T-0048 capture the need for a structural gate.
- **BACKLOG.json advancement lost (Mar 9)**: As described above — changes made locally never committed.
- **F-0140 real-world crash (Feb 20)**: A token-limit crash lost 466 lines because WIP was never created. Plan-mode-exit never chained to `ag implement`.
- **Journal format: agents write duplicated smoke-test entries (Mar 5)**: The journal has 11 nearly identical entries reading "smoke-test / paths.sh migration / verify" from March 5, suggesting repeated failed/restarted sessions that each wrote a journal entry.

**Status**: F-0140 (Proactive WIP Creation) fixed the WIP case. T-0047 for plan gate is still open. BACKLOG fix just shipped Mar 9.

**Root cause**: Skills decompose CLI commands into manual steps but don't ensure all side effects (file staging, plan saving) happen. The gap between what `ag done` does (in bash) and what the completing-work skill instructs (in markdown) consistently produces data loss.

---

### 5. "git stash Destroys Work" / Multi-Agent Collision

**Pattern**: Destructive git operations (stash, checkout ., restore ., reset --hard, clean -f) silently destroy work from other sessions or agents.

**Instances in March 2026**:
- **F-0195 Multi-Session Collision Prevention (Mar 9)**: Entire feature built to address this. The problem: `git stash pop` does a silent merge — when another agent modified the same files, it quietly picks one version with no error. CONTRIBUTIONS.md and TODO.md were lost in the F-0177 session this way.
- **`git reset --hard` lesson (Mar 9)**: In the v0.52.2 session, `git reset --hard origin/main` to "fix" divergence destroyed a TZ config fix that had no corresponding PR. Now documented as a lesson.
- **`git clean -fd` destroying untracked files**: Untracked files (plans, specs, new scripts) belonging to another agent's WIP get deleted.

**Status**: F-0195 shipped Mar 9 with three layers: session auto-registration, advisory UserPromptSubmit warning, instruction hardening. But the PID identity flaw (`$$` vs `$PPID`) was caught during review and would have made the entire feature non-functional — another instance of Pattern #1.

**Root cause**: Git has no pre-checkout or pre-stash hooks. Claude Code has no PreToolUse hook. Prevention is purely behavioral (instruction files) + advisory (warnings). No hard block is possible.

---

## TIER 2: SIGNIFICANT ONE-TIME ISSUES (fixed but illuminating)

### 6. Dashboard Reformatting

**Description**: Agents kept reformatting or narrating the session dashboard despite instruction hardening. Multiple rounds of fixes failed because the design asked agents to parse structured `===SECTION===` markers and render a formatted dashboard — inherently fragile.

**Fix (Mar 9, v0.52.2)**: Moved rendering INTO `dashboard.sh` itself. Agents now just output verbatim. Architectural fix, not behavioral.

**Lesson**: When agents keep getting something wrong despite instructions, the fix is to remove the decision from the agent entirely.

### 7. Directory Restructure Broke Paths (v0.41.0, Mar 5-6)

**Description**: The v0.41.0 directory restructure (from scattered `.agentic/` layout to `lib/` separation) broke multiple path references. Required 11+ "smoke-test / paths.sh migration" sessions on March 5 alone, and continued fixes into March 6.

**Specific breakages**:
- `settings.sh` profile resolution
- `ag.sh` stale paths
- `drift.sh`/`coverage.py` bugs
- `periodic-checks.sh` state dir
- `HUMAN_NEEDED_FILE` path (not discovered until Mar 9)

**Lesson**: Large structural refactors need comprehensive path-reference tests, not just unit tests of individual scripts.

### 8. Octal Bug in Feature IDs (Mar 2)

**Description**: `quick_feature.sh` used `$(( ))` arithmetic on feature IDs, which interprets `08` and `09` as invalid octal numbers. Fixed with `$((10#$id))`.

### 9. BSD sed Incompatibility (Feb 25)

**Description**: Settings manipulation in `upgrade.sh` broke on macOS because it used GNU sed syntax. Required explicit BSD-compatible patterns.

---

## TIER 3: OPEN/UNRESOLVED ISSUES (still at risk)

### T-0050: Spec/Backlog Status Drift
FEATURES.md status (planned/shipped) and BACKLOG.json can diverge. No drift-check tool exists. When discrepancy found, neither is authoritative — must cross-reference JOURNAL.md, CHANGELOG.md, and git history.

### T-0047: Plans Keep Getting Lost
`ag implement` has no gate for durable plan file. Plans keep getting lost in `~/.claude/plans/`. Needs a setting: `plan_save_gate (discovery: advisory, formal: blocking, off to disable)`.

### T-0017: AGENTS_ACTIVE.md Never Written
Referenced in 30+ files. No script or hook creates/updates it. Dead feature with zero structural backing.

### T-0023: Memory-Seed Worktree Bug
`memory-check.sh` resolves to worktree path instead of main repo memory path. Stale seed generates imprecise "go re-read the file" instructions instead of specific diffs.

### T-0045: Collision-Proof Feature IDs (F-0193)
Sequential F-XXXX IDs collide when multiple agents/branches assign independently. No solution implemented.

### ag.sh / validate_framework.sh Length
Both exceed `max_code_file_length=1200` (ag.sh ~2100, validate_framework.sh ~1890). Every commit touching these requires temporarily raising the limit. Needs splitting/refactoring.

---

## PATTERN SUMMARY

| # | Pattern | Frequency | Status |
|---|---------|-----------|--------|
| 1 | Infrastructure without wiring | 4+ incidents in March | Smoke test gate added but not automated |
| 2 | Instruction files always stale | 5+ incidents in March | F-0189 doc enforcement shipped but pattern continues |
| 3 | Silent bypass / enforcement theater | 3+ incidents in March | Individual fixes, no systemic prevention |
| 4 | Session state treated as durable | 3+ incidents in March | Partial fixes (F-0140, backlog); plans still vulnerable |
| 5 | git ops destroy other agents' work | Persistent | F-0195 shipped, advisory-only (hard block impossible) |
| 6 | Dashboard reformatting | Recurring until architectural fix | Fixed v0.52.2 |
| 7 | Path breaks after restructure | 11+ sessions on Mar 5 alone | Mostly fixed; HUMAN_NEEDED found Mar 9 |

**The meta-pattern**: The framework's enforcement mechanisms are themselves enforced only behaviorally. When a quality gate depends on an instruction file that the agent may not follow, the gate is theater. The framework keeps adding new gates and then discovering they're not wired. The fix for each gate is a new instruction — which itself may not be followed. This is a self-referential reliability problem that architectural solutions (like the dashboard rendering fix) address better than behavioral ones.
