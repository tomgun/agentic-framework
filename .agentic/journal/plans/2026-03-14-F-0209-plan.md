# F-0209: TDD Mode — Structural Test-First Enforcement

**Status: APPROVED**

## Context

`development_mode: tdd` in STACK.md is currently a dead label. The implementing-features skill says "check development_mode" but gives identical instructions regardless. A 563-line `tdd_mode.md` workflow doc exists but isn't wired into any skills or gates. This feature makes TDD a real behavioral mode with three enforcement layers:

1. **Skill-level**: implementing-features SKILL.md branches on `development_mode`, giving per-AC red-green-refactor instructions when TDD
2. **Checkpoint-level**: `wip.sh checkpoint --phase RED|GREEN|REFACTOR` records machine-readable TDD transitions in AGENTS.json
3. **Completion gate (blocking)**: `wip.sh complete` validates TDD phase ordering before removing the entry — blocks completion if `development_mode: tdd` and no RED checkpoints recorded, or GREEN appears before RED. Pre-commit Check #20 is a safety net for entries still active at commit time.

## Design Decisions

- **`--phase` flag (not text parsing)**: Machine-parseable, validated input. Backward compatible — omitting `--phase` works exactly as before.
- **Phase validation in `agents_helpers.py`** (`cmd_check_tdd_phases`): Keeps AGENTS.json logic in the canonical Python module. Testable, reusable, consistent with all other AGENTS.json operations.
- **Dual-point validation (completion + pre-commit)**: The commit workflow calls `wip.sh complete` BEFORE `git commit`. Since `cmd_complete()` removes the AGENTS.json entry (and its progress array), the pre-commit hook would find no data. Therefore: (a) `wip.sh complete` calls `check-tdd-phases` before deleting the entry — this is the PRIMARY enforcement point; (b) Check #20 in pre-commit is a SAFETY NET for entries still active at commit time (e.g., if someone commits without completing WIP first).
- **Blocking, not advisory**: Both gates block when `development_mode: tdd` and phase ordering is violated OR zero phase checkpoints exist. `SKIP_TDD=1` escape hatch available (blocked on main/master).
- **No new `ag tdd` command**: `ag implement` reads `development_mode` setting; the skill handles behavioral branching.
- **No profiles.conf change**: TDD is a user choice, not a profile default.
- **`hybrid` mode out of scope**: `tdd_mode.md` documents `development_mode: hybrid` but it is not wired anywhere today. This plan targets `tdd` only. `hybrid` enforcement can be added later.

## Multi-AC State Machine

For progress array validation, `cmd_check_tdd_phases` uses this rule:
- Every `GREEN:` entry must be preceded by at least one `RED:` entry at an earlier index
- `REFACTOR:` entries are optional (no ordering constraint)
- When `development_mode: tdd` and an active WIP exists, at least one `RED:` entry must be present (catches "agent ignored --phase entirely")

Valid patterns: `RED-GREEN`, `RED-GREEN-REFACTOR`, `RED-GREEN-RED-GREEN`, `RED-RED-GREEN-GREEN` (batch test-first)
Invalid: `GREEN` (no RED), `GREEN-RED` (wrong order), empty (zero phase entries with TDD active)

## Implementation Plan

### Batch 1: Core Structural Changes (6 files)

**1. `.agentic/lib/tools/wip.sh` — Add `--phase` flag to checkpoint + TDD gate on complete**

New checkpoint usage: `wip.sh checkpoint [--phase RED|GREEN|REFACTOR] "<note>"`

- Parse `$2`: if `--phase`, validate `$3` is `RED|GREEN|REFACTOR` (case-insensitive, stored uppercase), note is `$4`
- Prefix note: `"RED: <note>"`, `"GREEN: <note>"`, `"REFACTOR: <note>"`
- Pass prefixed note to `_agents_py checkpoint` (and WIP.md fallback path — same prefix logic)
- Reject invalid phase names with error + usage message
- Both AGENTS.json and WIP.md paths handle the flag identically (prefix is applied in bash before either path)

New complete behavior (TDD gate):
- Before calling `_agents_py complete`, read `development_mode` from STACK.md
- If `tdd`: call `_agents_py check-tdd-phases` first
- If exit 2 (ordering violation) or exit 3 (zero phases): print error, exit 1 (BLOCK completion)
- `SKIP_TDD=1` bypasses (blocked on main/master via branch check)
- If exit 0 or mode is not `tdd`: proceed with normal completion

**2. `.agentic/lib/tools/agents_helpers.py` — Add `cmd_check_tdd_phases`**

New function + CLI command `check-tdd-phases`:
- Reads active (non-session) entries from AGENTS.json
- Extracts progress entries starting with `RED:`, `GREEN:`, `REFACTOR:`
- Validates: every GREEN index has a preceding RED index
- Returns exit code 0 (valid), 1 (error), 2 (violation — print details to stdout)
- Also returns exit code 3 when zero phase entries exist (agent ignored --phase)

**3. `.agentic/lib/agents/claude/skills/implementing-features/SKILL.md` — Conditional TDD Step 4**

Replace current Step 4 (lines 60-72) with conditional branch:
- **If `tdd`**: Per-AC red-green-refactor cycle with checkpoint `--phase` commands
  - RED: write failing test, run to confirm failure, `wip.sh checkpoint --phase RED "AC1: test for [behavior] fails"`
  - GREEN: minimal code to pass, run all tests, `wip.sh checkpoint --phase GREEN "AC1: [behavior] passes"`
  - REFACTOR: improve code, run tests, `wip.sh checkpoint --phase REFACTOR "AC1: cleaned up [aspect]"`
  - "Do NOT write implementation code before its test exists. One AC at a time."
  - Reference `tdd_mode.md` for error recovery/examples
- **If `standard` (default)**: Current behavior unchanged (implement, add tests, checkpoint)

Note: template has Steps 1-6. Only Step 4 changes.

**4. `.claude/skills/implementing-features/SKILL.md` — Same TDD branch (framework-dev copy)**

Apply same conditional branch to Step 4 in framework-dev copy. This file has Steps 0-7. Only Step 4 changes — Steps 0, 0.5, 1-3, 5-7 untouched.

**5. `.agentic/lib/checklists/feature_implementation.md` — Strengthen TDD section**

Current (line 62): "If TDD Mode (Optional)" with soft checkboxes.
New: "If TDD Mode (`development_mode: tdd`)" with:
- Mandatory RED→GREEN→REFACTOR per AC
- `wip.sh checkpoint --phase` commands shown
- Note: "`wip.sh complete` blocks without RED checkpoints when TDD mode active"

**6. `.agentic/lib/hooks/pre-commit-check.sh` — Add Check #20 (safety net)**

After Check 19, add TDD phase ordering check:
- Only runs when `development_mode: tdd` and not fast mode
- Calls `agents_helpers.py check-tdd-phases` (not inline Python)
- Exit 2 → BLOCK: "TDD phase ordering violated: GREEN before RED"
- Exit 3 → BLOCK: "TDD mode active but no phase checkpoints recorded. Use: wip.sh checkpoint --phase RED|GREEN|REFACTOR"
- Exit 0 → pass: "TDD phase ordering OK"
- Exit 1 (no active entries) → pass silently (entries already completed via `wip.sh complete` which has its own gate)
- Escape hatch: `SKIP_TDD=1` (add to existing main/master guard on lines 76-82)
- Increments `FAILURES` on violation (actually blocks the commit)
- Note in check output: "Safety net — primary enforcement is at `wip.sh complete`"

### Batch 2: Instruction File Updates (5 files)

**7. `.agentic/lib/agents/shared/auto_orchestration.md` — Expand step 3 (line 166)**

Current: one-liner "CHECK DEVELOPMENT MODE → Read STACK.md"
New: Add TDD sub-tree:
```
3. CHECK DEVELOPMENT MODE
   └─ Read STACK.md → development_mode (default: standard)
   ├─ standard: implement first, test to verify
   └─ tdd: Per-AC red-green-refactor cycle:
      RED → GREEN → REFACTOR, checkpoint --phase at each step
      `wip.sh complete` blocks without phase checkpoints
```

**8. `.agentic/lib/init/memory-seed.md` — Add TDD enforcement sentinel**

Add paragraph under "When the user wants to build something" section: when `development_mode: tdd`, the implementing-features skill enforces per-AC RED→GREEN→REFACTOR with `wip.sh checkpoint --phase`. `wip.sh complete` blocks if no phase checkpoints or ordering violated. Pre-commit Check #20 is a safety net.

**9-11. Agent instruction files (brief 2-3 line additions each)**
- `.agentic/lib/agents/cursor/cursorrules.txt` — add row to trigger table for TDD mode
- `.agentic/lib/agents/copilot/copilot-instructions.md` — same
- `.agentic/lib/agents/codex/codex-instructions.md` — same

### Batch 3: Tests (2 files)

**12. `tests/validate_framework.sh` — Add F-0209 structural checks**

- wip.sh contains `--phase` flag handling
- implementing-features SKILL.md has TDD conditional branch (`development_mode.*tdd`)
- pre-commit-check.sh has Check #20 reference
- agents_helpers.py has `check-tdd-phases` command

**13. `tests/test_wip_tdd_phases.sh` (new) — Integration test**

Test cases:
- **Happy path**: start WIP, checkpoint --phase RED, checkpoint --phase GREEN → AGENTS.json has "RED: ..." and "GREEN: ..." prefixes
- **Multi-cycle**: RED-GREEN-RED-GREEN → valid (exit 0)
- **Invalid phase**: `--phase INVALID` → error exit
- **Case insensitivity**: `--phase red` → stored as "RED: ..."
- **Backward compat**: `checkpoint "plain note"` → works, no prefix
- **Negative: GREEN-before-RED**: → check-tdd-phases exits 2
- **Negative: zero phases**: TDD mode active, no --phase calls → check-tdd-phases exits 3
- **Completion gate**: `wip.sh complete` with `development_mode: tdd` and no phases → blocked
- **Completion gate pass**: `wip.sh complete` after RED+GREEN → succeeds
- **No-op for standard mode**: development_mode: standard → completion proceeds without phase check

## File Count Summary

- Batch 1: 6 files (core changes)
- Batch 2: 5 files (instruction updates)
- Batch 3: 2 files (tests)
- Total: 13 files across 2-3 commits

## Verification

1. `bash tests/validate_framework.sh` passes (including new F-0209 checks)
2. `bash tests/test_wip_tdd_phases.sh` passes all test cases
3. Manual test: `wip.sh checkpoint --phase RED "test fails"` → AGENTS.json has `"RED: test fails"`
4. Manual test: `wip.sh checkpoint --phase INVALID "x"` → error
5. Manual test: `python3 .agentic/lib/tools/agents_helpers.py --project-root . check-tdd-phases` → exit 0/2/3
6. Read both SKILL.md files — TDD branch present, standard branch unchanged
7. `bash .agentic/lib/hooks/pre-commit-check.sh --mode full` — Check #20 runs correctly
8. Manual test: `wip.sh complete` with tdd mode and no phases → blocked

## Revision History

- v1: Initial plan (advisory Check #20, inline Python, no agents_helpers.py changes)
- v2: Post-review revision addressing Critic feedback (blocking, zero-phase detection, agents_helpers.py)
- v3: Post-dialectical-review revision addressing lifecycle timing bug:
  - **PRIMARY enforcement moved to `wip.sh complete`** (before entry deletion)
  - Check #20 demoted to **safety net** (for entries still active at commit time)
  - `SKIP_TDD=1` added to main/master escape hatch guard
  - `hybrid` mode explicitly scoped out
  - WIP.md fallback clarified (prefix applied in bash before either path)
  - Completion gate test cases added to integration test
