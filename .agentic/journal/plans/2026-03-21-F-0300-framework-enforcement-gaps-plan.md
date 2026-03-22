# Framework Enforcement Gaps — Street Fury Evaluation Fixes

**Feature**: F-0300
**Status**: APPROVED
**Date**: 2026-03-21
**Profile**: autonomous_formal
**Scope**: 7 structural recommendations from Street Fury test project evaluation
**Review**: Dialectical review completed (Critic + Advocate). Revisions applied.

---

## Context

The Street Fury test project (GTA 1/2-style driving game, autonomous_formal profile, git deferred) exposed that the framework's enforcement collapses when git is deferred. The agent set up backlog correctly, then bypassed the entire implementation workflow — writing 1,925 LOC directly via Write/Edit tools with zero plans, zero state transitions, zero verification, and 10 of 15 features lacking acceptance criteria.

**Root cause (revised after review)**: Two compounding failures:
1. **Claude Code hooks were never installed.** The `.agentic/hooks/claude/` scripts exist but nothing registers them in `.claude/settings.json`. The init/scaffold process only sets up git hooks (`core.hooksPath`), not Claude hooks. This means `gate_pretool` (which already has Write/Edit blocking for formal modes at `gate.py:484-523`) never fires.
2. **`ag auto` commands hard-gate on `git_mode=active`** (`auto.sh:14-25`), so the agent couldn't use them even if it wanted to. The agent believed (incorrectly) that `ag auto crunch` doesn't work without git — and it was right, because the gate rejects it.

With hooks installed AND `ag auto` unlocked for deferred git, the existing enforcement (`check_any_feature_implementing`, spec/AC gates, state machine) would have caught the bypass.

---

## R0: Hook Installation During Init (NEW — enables R1, R3-hook, R6-hook)

### Problem
Claude Code hooks in `.agentic/hooks/claude/` (PreToolUse, UserPromptSubmit, PostToolUse, Stop, etc.) are shipped as scripts but **never registered** in `.claude/settings.json`. The scaffold and init playbook only configure git hooks (`core.hooksPath`). This means the entire Claude-agent-level enforcement layer is inert in new projects.

### Evidence
- `/workspace/.claude/settings.json` does not exist (verified)
- `ag auto init` generates settings.json with permissions only, no hooks (`auto/init.py:127-174`)
- `scaffold.sh` sets `git config core.hooksPath .agentic/hooks` (line 313) but doesn't touch `.claude/`
- `init_playbook.md` mentions verifying git hooks (line 795) but not Claude hooks

### Implementation

**A. Add hook registration to `scaffold.sh`**

After creating the `.agentic/` directory structure, scaffold should also create `.claude/settings.json` (or `.claude/settings.local.json` for gitignored variant) with hook entries:

```json
{
  "hooks": {
    "PreToolUse": [{
      "matcher": "",
      "hooks": [".agentic/hooks/claude/PreToolUse.sh"]
    }],
    "PostToolUse": [{
      "matcher": "",
      "hooks": [".agentic/hooks/claude/PostToolUse.sh"]
    }],
    "UserPromptSubmit": [{
      "matcher": "",
      "hooks": [".agentic/hooks/claude/UserPromptSubmit.sh"]
    }],
    "Stop": [{
      "matcher": "",
      "hooks": [".agentic/hooks/claude/Stop.sh"]
    }]
  }
}
```

**B. Add hook registration to `ag auto init`**

`auto/init.py`'s `generate_settings()` should include hook entries alongside permissions. This ensures auto-mode projects also get enforcement.

**C. Add `ag hooks status` command**

A diagnostic command that checks whether Claude hooks are registered in settings.json and reports status. This helps debug enforcement issues.

**Files to modify**:
- `.agentic/lib/init/scaffold.sh` — add `.claude/settings.json` creation with hooks
- `.agentic/lib/auto/init.py` — add hooks to generated settings.json
- `.agentic/lib/auto/settings-template.json` — add hooks section
- `.agentic/lib/init/init_playbook.md` — add Claude hook verification step

### Risk
- Existing projects missing `.claude/settings.json` need migration path → `ag hooks install` command
- Hook entries must use correct Claude Code settings format (verify against docs)

---

## R1: Strengthen Pre-Write Gate for Deferred Git

### Problem
`gate_pretool` (`gate.py:484-523`) already has Write/Edit enforcement in formal modes, but it has gaps:
1. The F-0251 check (`check_any_feature_implementing`) only blocks when ALL features are "planned". Once ANY feature reaches "implementing", all subsequent features can have code written without their own ACs.
2. The feature-specific check (`gate.py:516-523`) only fires if `resolve_active_feature()` returns a feature ID. If AGENTS.json is empty and STATUS.md doesn't resolve a feature, `feature_id` is None and the check is skipped entirely.

### Implementation (revised — extend existing gate.py, not parallel system)

**File**: `.agentic/lib/gate.py`

**A. Fix the per-feature AC gap** (line 516-523):
When `feature_id` is None but we're in formal mode and features exist in FEATURES.md, try to infer which feature is being worked on from the file path being edited. If ambiguous, block with a message: "Cannot determine which feature this edit belongs to. Run `ag implement F-XXXX` to track your work."

**B. Add AGENTS.json active-work-item check**:
Before the F-0251 check, add: if `git_mode=deferred` and no agent has an active work item in AGENTS.json, emit a deny (not advisory) when `state_enforcement=blocking`:
```python
if not feature_id and git_mode == "deferred":
    msg = ("Code edit blocked — no active work item. "
           "With git_mode=deferred, pre-commit gates are disabled. "
           "Use `ag start F-XXXX` or `ag auto task F-XXXX` to begin tracked work.")
    if enforcement == "blocking":
        return GateResult.deny([msg])
    else:
        return GateResult.allow([msg])
```

**C. Reuse existing `safe_patterns` allowlist** (line 488-495) — don't invent new source dir detection.

**Files to modify**:
- `.agentic/lib/gate.py` — extend `gate_pretool` Write/Edit section

### Risk
- Low. Extends existing, tested enforcement logic. No new architectural patterns.

---

## R2: Autonomous Work Enforcement (revised — hooks-based, not skill injection)

### Problem
Skills only fire on user-originated prompts. When the agent self-directs implementation work, no skill loads.

### Revised approach
The original plan proposed injecting skill content into spawned Claude `--print` mode prompts. **This is infeasible** — `--print` mode treats the entire argument as a user prompt and doesn't support skill loading. However, with R0 (hooks installed), the existing `gate_pretool` enforcement DOES fire for spawned agents because they run in the same project directory with the same hooks.

**The actual fix is two-fold:**
1. **R0 + R1** ensure hooks fire and gate_pretool blocks unauthorized writes
2. **Embed gate-equivalent rules in spawned agent prompts** — not skill content, but explicit constraints:

**File**: `.agentic/lib/auto/task.py`
In `_spawn_claude_implement()` prompt construction, add:
```
IMPORTANT: Before writing any source code, verify:
1. The feature has acceptance criteria at .agentic/spec/acceptance/F-XXXX.md
2. A plan exists at .agentic/work/F-XXXX/plan.md or .agentic/journal/plans/*F-XXXX-plan.md
3. You are implementing ONE specific acceptance criterion, not the whole feature.
```

**File**: `.agentic/lib/auto/crunch.py`
Same pattern for the crunch orchestrator.

**Additionally**: The `UserPromptSubmit.sh` hook (now installed via R0) should detect autonomous work patterns — multiple Write/Edit calls to source files without intervening `ag` commands — and emit a reminder.

**Files to modify**:
- `.agentic/lib/auto/task.py` — add enforcement rules to spawned prompts
- `.agentic/lib/auto/crunch.py` — same
- `.agentic/lib/claude-hooks/UserPromptSubmit.sh` — add autonomous-work-pattern detection

### Risk
- Prompt-embedded rules are softer than hook denials — but combined with R0+R1, the hooks provide the hard enforcement
- Pattern detection in UserPromptSubmit may have false positives → tune thresholds

---

## R3: Trigger Table — "churn/batch/all tasks/build everything"

### Problem
User said "churn all tasks" which didn't match any trigger word. The agent should have routed to `ag auto crunch` but instead wrote code directly.

### Implementation (unchanged from draft — low risk, high impact)

**Memory-seed update** (`.agentic/lib/init/memory-seed.md`):
Add trigger mapping:
```
"churn/batch/all tasks/build everything/implement everything/do all features"
  → STOP. Run `ag auto crunch`. This executes the FULL pipeline for each feature:
    spec → plan → review → implement → test → verify → ship.
    NEVER write code for multiple features outside of `ag auto` commands.
```

**CLAUDE.md template update** (`.agentic/lib/agents/claude/CLAUDE.md`):
Add rule:
```
- NEVER write code for multiple features outside of `ag auto` commands.
  The `ag auto` pipeline ensures each feature gets specs, plans, tests,
  and docs — not just code. If a user says "build everything" or
  "churn all tasks", use `ag auto crunch`, not direct Write/Edit calls.
```

**UserPromptSubmit.sh update**:
Add pattern detection for batch-work triggers:
```bash
if echo "$prompt" | grep -qiE '(churn|batch|all (tasks|features)|build everything|implement (all|everything))'; then
  echo "⚠️ Batch work detected. Use \`ag auto crunch\` to process the backlog with full enforcement."
fi
```

**Note**: Advisory warnings were ignored in the Street Fury session — but that's because hooks weren't installed (R0). With R0 in place, the warning will actually appear in the agent's context. Combined with the CLAUDE.md rule (a hard instruction, not advisory), this creates two layers.

**Files to modify**:
- `.agentic/lib/init/memory-seed.md` — add trigger word entry
- `.agentic/lib/agents/claude/CLAUDE.md` — add batch-work rule
- Root CLAUDE.md — same rule (keep in sync with template)
- `.agentic/lib/claude-hooks/UserPromptSubmit.sh` — add batch-work detection
- `.cursorrules` — add batch-work rule (instruction file checklist)
- `.github/copilot-instructions.md` — add batch-work rule (instruction file checklist)

### Risk
- Low risk. Instructional + advisory. Paired with structural enforcement in R0+R1+R5.

---

## R4: Init Playbook Should Produce Consistent FEATURES.md Format

### Problem
Init created a table-format FEATURES.md that `ag backlog add` couldn't parse. Agent had to rewrite it to `## F-XXXX:` heading format.

### Implementation (revised — use explicit template, not non-existent `feature.sh add`)

**Root cause**: The init playbook tells the agent to "create FEATURES.md" but doesn't specify the exact format. `feature.sh` only updates existing features — it has no `add` subcommand. The state machine (`state_machine.py:186`) and crunch (`crunch.py:240`) only parse heading format (`## F-XXXX:`).

**Fix**: Two changes:

**A. Add format template and explicit instructions to init_playbook.md**:
In the "Create FEATURES.md" step, provide the exact format:
```markdown
Create FEATURES.md with this EXACT format (heading-based, NOT table):

# FEATURES.md
<!-- format: features-v2.0.0 -->
<!-- REQUIRED: heading format. Tables break backlog, state machine, and crunch. -->

## F-0001: Feature Name
- Status: planned
- Domain: infrastructure|gameplay|ui|...

## F-0002: Next Feature
- Status: planned
- Domain: ...
```

**B. Add `feature.sh add` subcommand** for programmatic feature creation:
```bash
# Usage: feature.sh F-XXXX add "Feature Name" domain
# Appends a new feature in the correct heading format
```
This ensures any future code that creates features (kickoff, init, scripts) always produces parseable format.

**Files to modify**:
- `.agentic/lib/init/init_playbook.md` — explicit format template with warning
- `.agentic/lib/tools/feature.sh` — add `add` subcommand
- `.agentic/lib/tools/commands/kickoff.sh` — use `feature.sh add` during kickoff promotion

### Risk
- Low. Format template is purely instructional. `feature.sh add` is small, self-contained.

---

## R5: Unlock `ag auto` for Deferred Git

### Problem
`auto.sh` lines 14-25 hard-gate `ag auto task|epic|crunch|pipeline` on `git_mode=active`. This forces agents into untracked direct-write mode when git is deferred. The core pipeline (plan → spec → implement → test → verify) doesn't need git — only branches, commits, and PRs do.

**Correction from review**: There is NO constraint in `constraints.conf` blocking state_enforcement with deferred git. The constraint was fabricated in the draft. The real blockers are:
1. `auto.sh` hard gate (lines 14-25)
2. `task.py` calls to `_create_branch()`, `_commit_ac()`, `_create_pr()` that assume git

### Implementation

**A. Modify `auto.sh` gate to be conditional, not blocking**:
```bash
case "$subcmd" in
    task|epic|crunch|pipeline)
        local git_mode
        git_mode=$(get_setting "git_mode" "active")
        if [[ "$git_mode" != "active" ]]; then
            echo -e "${YELLOW}Git not active (git_mode: ${git_mode}).${NC}"
            echo "  Running in deferred-git mode: branches, commits, and PRs will be skipped."
            echo "  Work items, plans, specs, and tests will still be enforced."
            echo ""
            # Continue — don't return
        fi
        ;;
esac
```

**B. Add conditional git paths in `task.py`**:
- `_create_branch()` → skip if `git_mode != active`, log warning
- `_commit_ac()` → skip git add/commit, still record completion in work item
- `_create_pr()` → skip entirely, log that PR creation deferred
- `_cleanup()` → skip branch deletion

**C. Same treatment in `crunch.py` and `scheduler.py`**:
- Wrap git-dependent operations in `if git_mode == "active":` guards
- The core loop (iterate backlog → process feature → verify → next) works without git

**D. Make `ag implement` deferred-git path more robust**:
`implement.sh` lines 259-278 already handle non-active git somewhat, but should:
- Always create `.agentic/work/F-XXXX/` directory
- Always require plan (Gate 0) and ACs (Gate 0.5)
- Always register in AGENTS.json
- Always transition state to `implementing`
- Skip only: branch creation, worktree creation

**Files to modify**:
- `.agentic/lib/tools/commands/auto.sh` — change hard gate to conditional warning
- `.agentic/lib/auto/task.py` — add deferred-git conditional paths
- `.agentic/lib/auto/crunch.py` — same
- `.agentic/lib/auto/scheduler.py` — same
- `.agentic/lib/tools/commands/implement.sh` — ensure all non-git gates still fire

### Risk
- **Medium-high.** This is the largest change. No branch isolation means features share the working directory. Mitigated by `.agentic/work/F-XXXX/` directories providing artifact isolation.
- Need to ensure `ag done` cleanup works without git (no branch to delete).
- Task.py's `_commit_ac` writes directly — without git, there's no rollback on failure. Accept this trade-off for deferred-git mode.

### Scope estimate (from review)
This touches 4+ Python files and 2 shell scripts with pervasive conditional logic. Estimate 200-300 lines of changes across files. Not a one-bullet-point change — plan accordingly.

---

## R6: Test Quality Gate Independent of Git

### Problem
Test coverage is only checked at commit time (pre-commit hook). With deferred git, it's never checked.

### Implementation (revised — use existing `check_verification_passes`, don't duplicate)

**A. Wire existing verification into state transitions**

`gate.py:271-327` already has `check_verification_passes(feature_id, project_root)` that reads AC files, extracts `## Verification → **Automated**` commands, and runs them. Don't create a duplicate in `gates.py`.

**File**: `.agentic/lib/auto/gates.py`
Add a new gate function that delegates to the existing `gate.py` function:
```python
def gate_implementing_to_verified_tests_pass(feature_id, project_root):
    """Gate: tests must actually pass before transitioning to verified."""
    from gate import check_verification_passes
    return check_verification_passes(feature_id, project_root)
```

**File**: `.agentic/lib/auto/state_machine.py`
Wire this gate into the `implementing → verified` transition.

**B. Verification reminder in hooks** (enabled by R0)

**File**: `.agentic/lib/claude-hooks/UserPromptSubmit.sh`
When prompt contains "done" or "finished" with a feature reference, check if verification exists:
```bash
if echo "$prompt" | grep -qiE '(done|finished|complete|ship)' && [[ -n "$FEATURE_ID" ]]; then
  if [[ ! -f ".agentic/work/$FEATURE_ID/verification.json" ]]; then
    echo "⚠️ No verification record for $FEATURE_ID. Run \`ag verify $FEATURE_ID\` first."
  fi
fi
```

**C. Inter-feature verify in crunch pipeline**

**File**: `.agentic/lib/auto/crunch.py`
After each feature's implementation step, call `ag verify F-XXXX`. Block next feature if verification fails.

**Files to modify**:
- `.agentic/lib/auto/gates.py` — add gate delegating to `check_verification_passes`
- `.agentic/lib/auto/state_machine.py` — wire gate into transitions
- `.agentic/lib/claude-hooks/UserPromptSubmit.sh` — add verification reminder
- `.agentic/lib/auto/crunch.py` — add inter-feature verify step

### Risk
- Low for A and B (wiring existing code).
- Medium for C (crunch pipeline changes interact with R5).

---

## Implementation Order (revised)

1. **R0** (hook installation) — **CRITICAL ENABLER**. Without this, R1/R3-hook/R6-hook are inert. Must be first.
2. **R3** (trigger table) — Lowest risk, high behavioral impact. Pure instruction updates.
3. **R4** (FEATURES.md format) — Low risk, prevents init-time breakage.
4. **R5** (unlock ag auto for deferred git) — Keystone. Enables R6 and makes R3's "use ag auto crunch" actionable.
5. **R1** (strengthen pre-write gate) — Extends existing gate.py. More impactful after R5 (remediation is actionable).
6. **R6** (test quality gate) — Wires existing verification into transitions. Depends on R5 for crunch integration.
7. **R2** (autonomous work enforcement) — Depends on R0+R1 for hooks and R5 for ag auto.

---

## Success Criteria (revised)

After implementing all 7 recommendations, re-running the Street Fury scenario should produce:
1. **R0**: `.claude/settings.json` created during init with all hook registrations
2. **R3**: "Churn all tasks" triggers hook warning + CLAUDE.md rule prevents direct-write
3. **R4**: FEATURES.md created in correct heading format, no `ag backlog add` failures
4. **R5**: `ag auto crunch` works with `git_mode=deferred` (skipping only branch/PR ops)
5. **R1**: Writing to source files without active work item is DENIED by `gate_pretool`
6. **R6**: Each feature must pass verification before transitioning to `verified`
7. **R2**: Spawned agents in `ag auto` receive enforcement rules in prompts

**Structural test**: Run `ag auto crunch` in a fresh project with `autonomous_formal` + `git_mode=deferred`. Each feature should: get ACs → get plan → pass review → have code written → pass verification → transition through states.

---

## Appendix: Review Synthesis

### Critic findings addressed
- **C1/C2**: R1 reframed to extend existing `gate_pretool`, not create parallel system ✅
- **C3**: R2 redesigned — hooks-based enforcement instead of infeasible skill injection ✅
- **C4**: Phantom `constraints.conf` entry removed from R5 ✅
- **S1**: R4 simplified with template + `feature.sh add` implementation ✅
- **S2**: R5 scope acknowledged as 200-300 LOC across 4+ files ✅
- **S3**: R3 advisory limitation acknowledged, paired with CLAUDE.md hard rule ✅
- **S4**: R6 reuses existing `check_verification_passes` ✅
- **S5**: R6 separated from R5 dependency (core gate is git-independent) ✅
- **Missing: Why gate_pretool didn't fire**: **R0 answers this — hooks were never installed** ✅
- **Missing: Testing strategy**: LLM tests for trigger words, framework validation for gate changes ✅

### Advocate validations preserved
- Root cause diagnosis strengthened (two compounding failures, not one)
- Multi-layer defense-in-depth maintained
- R3 and R5 confirmed as highest-impact recommendations
- Implementation order refined per advocate suggestion (R5 before R1)
