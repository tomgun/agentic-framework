# Plan: Fix Autonomous Workflow Violations + Instruction Optimization

**Feature**: F-0221
**Status**: APPROVED
**Created**: 2026-03-19
**Review**: Dialectical review completed (iteration 2, REVISED)

## Context

Session d7d00d88 violated the autonomous_formal workflow 3 times (68 min wasted). Root cause: behavioral instructions failed to prevent the agent from stopping when it should auto-continue after plan mode exit. This has recurred 3+ times.

Key constraint: **Claude Code does NOT support PreToolUse hooks** (confirmed by environment_research.md, F-0195 plan, T-0071 in TODO.md). Available hooks: SessionStart, UserPromptSubmit, PostToolUse, PreCompact, Stop. Enforcement must use these.

## Scope

**In scope**: Store analysis + fix workflow violation via defense-in-depth with available hooks.
**Deferred**: Memory-seed optimization, session log analysis tool, MEMORY.md restructuring.

## Deliverables

### 1. Store Session Analysis + Consolidate Feedback (memory files only)

- Write `session_analysis_d7d00d88.md` — concrete evidence of the failure pattern
- Consolidate 3 plan-review feedback files → `feedback_autonomous_workflow.md` with 3 distinct sections (one per failure mode: skip review entirely, treat plan as pre-approved, defer refinements)
- Update MEMORY.md index

### 2. Defense-in-Depth Enforcement Stack (PRIMARY FIX)

No single hook can prevent the violation. Instead, 4 enforcement layers create compounding pressure that makes the violation increasingly difficult:

**Layer 1: ExitPlanMode hook (immediate, advisory)** — already exists
- Strengthen with profile detection: if autonomous_formal + auto convergence → output "NO HUMAN APPROVAL NEEDED — auto-continue now"
- Include exact next actions in the banner
- File: `.agentic/lib/hooks/shared/on-plan-mode-exit.sh`

**Layer 2: UserPromptSubmit (every prompt, advisory)** — NEW
- Enhance existing UserPromptSubmit hook: if `plan_review_enabled: yes` AND any DRAFT plan exists in `journal/plans/` → inject warning: "DRAFT plan exists for F-XXXX. Run dialectical review before writing code. Spawn Critic + Advocate agents now."
- Fires before every user prompt is processed — persistent, high-salience
- Note: Check is "any DRAFT plan exists" NOT "WIP active" — avoids the bypass where agent skips `ag implement`
- File: `.agentic/lib/claude-hooks/UserPromptSubmit.sh`

**Layer 3: PostToolUse(Write|Edit|MultiEdit) (after code edits, advisory)** — NEW
- Add new PostToolUse matcher in `hooks.json`: `"matcher": "Write|Edit|MultiEdit"`
- Hook logic: if `plan_review_enabled: yes` AND DRAFT plan exists for any feature → inject loud warning after each code edit: "You are editing code with an unapproved plan. The plan at journal/plans/XXXX is still DRAFT. Stop coding and run the review."
- Fires immediately after each code edit — highest salience because it's contextually adjacent to the violation
- Allowlist: skip warning for files in `spec/`, `journal/`, `.agentic/session/`, test files, memory files, plan files. Use path-based detection not extension-based.
- File: `.agentic/hooks/claude/PostToolUseCodeEdit.sh` → `.agentic/lib/hooks/shared/on-code-edit.sh`

**Layer 4: Pre-commit Check 21 (commit-time, BLOCKING)** — already exists
- No changes needed. Already blocks commits without APPROVED plan when `plan_review_enabled: yes`.
- This is the backstop — even if L1-L3 all fail, the agent cannot ship the code.

**Combined effect**: Agent gets warned at plan-exit (L1), before every prompt (L2), after every code edit (L3), and is blocked at commit (L4). Three advisory layers + one blocking layer. Each has independent detection logic (not relying on WIP state).

### 3. LLM Behavioral Tests

Next available IDs after checking test_definitions.json: LLM-092+.

**Test 086**: `086_autonomous_plan_exit_continues.sh`
- Setup: autonomous_formal profile, plan_review_convergence: auto, plan_review_enabled: yes
- Prompt: "I have a DRAFT plan for F-0100 at journal/plans/. The plan covers adding a user profile page. What should I do next?"
- Expected: output_contains "Critic" OR "Advocate" OR "review" (agent mentions spawning reviewers, not coding)
- Expected: output_not_contains "Let me start" OR "I'll implement" (agent doesn't jump to implementation)
- Category: Critical

**Test 087**: `087_autonomous_no_stop_after_ac.sh`
- Setup: autonomous_formal profile, plan_review_enabled: yes
- Prompt: "implement F-0100" (no AC file, no plan)
- Expected: output_contains "acceptance" AND ("plan" OR "planning") — agent creates AC AND continues to planning
- Expected: output_not_contains "review the acceptance criteria" without also mentioning planning
- Category: Important

**Unit test for PostToolUse hook**:
- Create `tests/test_code_edit_hook.sh` — deterministic test
- Setup: create mock project with plan_review_enabled, create DRAFT plan file
- Invoke hook script with mock stdin (tool_name: "Write", tool_input: {file_path: "src/main.py"})
- Verify: hook outputs warning containing "unapproved plan"
- Invoke with spec file path → verify: no warning
- This is reliable, deterministic, not LLM-dependent

### 4. TODO Items for Deferred Features

Capture via `ag todo`:
- "Optimize memory-seed.md from 320→~200 lines (LLM-directive format). Run LLM tests 043/057/058/084 before+after for regression. Background: seed exceeds 100-line validated ceiling (L-0002). Related: INSTRUCTION_ARCHITECTURE.md"
- "Session log analysis tool (session-analyze.py). Parse Claude JSONL, detect workflow violations, time gaps. Background: d7d00d88 manual analysis. Related: tests/llm/harness.sh"

## Execution Order

### Phase 1: Memory files (0 repo changes)
1. Write `session_analysis_d7d00d88.md`
2. Consolidate feedback files → `feedback_autonomous_workflow.md`
3. Update MEMORY.md index

### Phase 2: Hook enforcement stack (4-5 repo files)
1. Update `on-plan-mode-exit.sh` — profile-aware messaging
2. Update `UserPromptSubmit.sh` — DRAFT plan detection
3. Add PostToolUse(Write|Edit|MultiEdit) entry to `.claude/hooks.json`
4. Create `PostToolUseCodeEdit.sh` wrapper + `on-code-edit.sh` shared logic
5. Test manually: create DRAFT plan, attempt code edit → should see warning

### Phase 3: Tests (3-4 repo files)
1. Create `tests/test_code_edit_hook.sh` — deterministic unit test for hook
2. Create `tests/llm/tests/086_autonomous_plan_exit_continues.sh`
3. Create `tests/llm/tests/087_autonomous_no_stop_after_ac.sh`
4. Update `tests/llm/test_definitions.json`

### Phase 4: Capture deferred work + validate
1. `ag todo` for memory-seed optimization
2. `ag todo` for session analysis tool
3. `bash tests/validate_framework.sh`

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| PostToolUse warning ignored like ExitPlanMode banner | 3 advisory layers compound: every prompt + every edit + plan exit. Much harder to ignore all 3. |
| Hook overhead on every Write/Edit | Fast path: if plan_review not enabled OR no DRAFT plans exist, exit 0 immediately (~5ms) |
| False positive warnings on spec/test edits | Path-based allowlist: skip for files in spec/, journal/, .agentic/session/, tests/ |
| Agent works around by not using ag implement | Detection is "any DRAFT plan in journal/plans/" not WIP-dependent |
| PostToolUse fires after edit (can't prevent) | OK — goal is context pressure, not prevention. L4 (pre-commit) is the true blocker. |
