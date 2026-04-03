# Fix Hook Automation Gaps + Instruction File Drift

## Context

Two related problems:

**A. Three automations aren't firing reliably.** The root cause is the same for all three: hooks always exit 0 (advisory only) and rely purely on the agent reading text and choosing to comply. When the agent misses the cue — or bypasses the canonical path (`ag merge` → `gh pr merge`) — the chain breaks silently.

**B. Instruction file drift.** Post-merge dogfood sync didn't happen after F-0193, and a drift audit found significant gaps: templates have rules that root files are missing, and root files have rules that templates are missing. This is the drift we should have caught at merge time.

---

## Part A: Automation Enforcement Fixes

### A1 — Plan review loop (all work, not just feature implementation)

**Root cause**: Two separate gaps:
1. `ag implement` Step 0.5 already hard-blocks for DRAFT feature plans, but agents bypass it by coding directly without calling the CLI.
2. More broadly: no mechanical enforcement exists for non-feature work (bug fixes, drift fixes, refactoring). CLAUDE.md says "auto-continue with dialectical review after any ExitPlanMode", but that's purely behavioral — the agent can ignore it.

**Why checking for `**Status**: DRAFT` requires a fix first**: `on-plan-mode-exit.sh` (the PostToolUse:ExitPlanMode hook) does NOT write the DRAFT status — it calls `plan-scan.sh` to copy the plan but leaves status injection to the agent. So DRAFT must be injected mechanically by the hook, not left to the agent.

**Why use the plan file (not a session flag)**: A session flag in `.agentic/session/` is gitignored. Plans saved to `.agentic/journal/plans/` are git-tracked — the APPROVED status persists across machines. If a review loop runs on another machine and sets APPROVED, pulling that commit shows APPROVED on all machines.

**Fix — plan file status approach (mechanical, git-tracked, cross-machine)**:
1. **`on-plan-mode-exit.sh`**: After `plan-scan.sh` copies the plan to `.agentic/journal/plans/`, inject `**Status**: DRAFT` at the top of the saved plan file if no status line exists yet. This fires mechanically on every ExitPlanMode — no agent cooperation needed.
2. **`gate_stop()` in `gate.py`**: Add `check_pending_plan_review()` — check if any plan file in `.agentic/journal/plans/` has `**Status**: DRAFT` (or no status at all). If so, block with: `"REQUIRED: plan review pending — run Critic + Advocate review, set Status: APPROVED before stopping"`. DRAFT always means "pending review" regardless of age — if a plan is genuinely abandoned, mark it REJECTED, don't leave it DRAFT.
3. **Review completes → APPROVED in git**: The dialectical review process sets `**Status**: APPROVED` in the git-tracked plan file. This clears the block on any machine that pulls the change.
4. **Implementing-features skill**: Add callout that agents MUST call `ag implement F-XXXX` as CLI command — not start coding directly.

This way: DRAFT is injected by the hook (mechanical), APPROVED is set by review (gated), the signal is in git (cross-machine), and gate_stop() checks absence of APPROVED in recent plans.

Files:
- `.agentic/lib/hooks/shared/on-plan-mode-exit.sh` — inject `**Status**: DRAFT` after plan-scan.sh saves the plan
- `.agentic/lib/gate.py` — add `check_pending_plan_review()` to `gate_stop()`
- `.claude/skills/implementing-features/SKILL.md` — add "MUST call `ag implement`" callout
- (`.agentic/lib/tools/commands/implement.sh` — no change needed; Step 0.5 APPROVED check already exists)

### A2 — Post-merge dogfood sync

**Root cause**: `on-bash-merge-detect.sh` warns but exits 0. Agent bypassed `ag merge` (used `gh pr merge` directly), saw the warning, but didn't invoke completing-work.

**Fix — two-part**:
1. **Stronger PostToolUse output**: Update `on-bash-merge-detect.sh` to include a structured `REQUIRED NEXT ACTION:` block (agents parse action-prefixed lines more reliably than general advisory text).
2. **Stop hook check**: Add `check_merge_without_done()` to `gate_stop()` in `gate.py` — if git log shows a recent merge commit from a feature branch (matching `F-\d{4,}` pattern in branch name or commit message) AND that feature is NOT in `shipped` status in `FEATURES.md`, block stop with `REQUIRED: run ag done F-XXXX — feature merged but not marked shipped`.

Files:
- `.agentic/lib/hooks/shared/on-bash-merge-detect.sh` — structured REQUIRED block
- `.agentic/lib/gate.py` — add `check_merge_without_done()` to `gate_stop()`

### A3 — Automatic PR creation

**Root cause**: No hook enforces PR creation after a feature branch push. The committing-changes skill instructs it, but agents skip it for "small" changes.

**Fix**: Add `check_feature_branch_without_pr()` to `gate_stop()` in `gate.py` — if HEAD is on a non-main branch with commits ahead of origin and no open PR (`gh pr list --head <branch>` returns empty), block stop with `REQUIRED: create PR before stopping`.

Files:
- `.agentic/lib/gate.py` — add `check_feature_branch_without_pr()` to `gate_stop()` (already included above)

---

## Part B: Instruction File Drift (5 files)

### B1 — `CLAUDE.md` root ← add from template

Template has these that root is missing:
- `ag contract check/coverage/pending/list` commands in Workflow section
- `git_mode: deferred/none` rule (skip git ops, suggest `ag git-init`)
- `"pending user input/contract input"` trigger → `ag contract pending`
- `"migrate specs/convert acceptance"` trigger → `ag migrate-specs`
- `"Never fabricate APIs, data, or behavior"` rule in Core Rules

File: `CLAUDE.md`

### B2 — `CLAUDE.md` template ← backport from root

Root has these non-framework-dev rules that template is missing:
- `ag kickoff` and `ag coord` commands in Workflow section
- `"Plans are durable"` rule (save to journal/plans/, dialectical review)
- `"Multi-agent: check AGENTS.json"` rule
- Autonomous session commit rule (`review_commit` setting)
- PR → HUMAN_NEEDED tracking instruction
- Skills & Workflows section (subagent context + memory seed)
- 4th wrong rationalization: "Proceed with refinements during implementation"
- `feature.sh` in token-efficient scripts list

File: `.agentic/lib/agents/claude/CLAUDE.md`

### B3 — `.cursorrules` ← add from template

Missing:
- `"Backlog / what's next / prioritize"` trigger row
- `"Write spec / contract / acceptance criteria"` trigger row
- `"Churn / batch / all tasks / build everything"` trigger row
- `"NEVER write code for multiple features"` rule
- `"No feature inflation"` rule
- Token-efficient scripts section (STATUS.md, JOURNAL.md, HUMAN_NEEDED.md, TODO.md)

File: `.cursorrules`

### B4 — `.github/copilot-instructions.md` ← add from template

Missing:
- `"Backlog / what's next / prioritize"` trigger row
- `"Write spec / contract / acceptance criteria"` trigger row
- `"Phase done / mark phase"` trigger row
- `"Multi-session safety"` rule
- `"NEVER write code for multiple features"` rule
- `"No feature inflation"` rule
- Fix journal placeholders: `"Done"/"Reason"` → `"Outcomes"/"Problem"` (canonical form)

File: `.github/copilot-instructions.md`

### B5 — `.codex/instructions.md` ← add from template

Missing:
- `"Backlog / what's next / prioritize"` trigger row
- `"Write spec / contract / acceptance criteria"` trigger row
- `"Phase done / mark phase / phase progress / which phase"` trigger row
- `"Churn / batch / all tasks / build everything"` trigger row
- `"NEVER write code for multiple features"` rule
- `"No feature inflation"` rule
- Fix journal placeholders: `"Done"/"Reason"` → `"Outcomes"/"Problem"` (canonical form)

File: `.codex/instructions.md`

---

## Verification

### Automation fixes
- Call ExitPlanMode → `.agentic/journal/plans/*.md` has `**Status**: DRAFT` injected mechanically by hook
- Try `/stop` before review completes → gate_stop() finds recent plan with DRAFT status → blocks
- Try `/stop` on a non-implementation plan (drift fix, bug fix, etc.) → same block — applies to all work types
- After review sets APPROVED → `/stop` unblocked (and APPROVED is in git, works across machines)
- `ag implement F-0243` with a DRAFT plan → already exits 1 (pre-existing gate) — verify still works
- `SKILL.md` shows explicit "MUST call `ag implement`" callout before implementation steps
- Run `gh pr merge` on a test PR → hook outputs structured `REQUIRED NEXT ACTION:` block
- Try `/stop` after merge without `ag done` → gate_stop() detects feature in git log but not shipped in FEATURES.md → blocks
- Try `/stop` with unpushed feature branch commits and no PR → gate_stop() blocks with `gh pr create` reminder

### Drift fixes
- `grep -c "ag contract" CLAUDE.md` → > 0
- `grep -c "No feature inflation" .cursorrules` → > 0
- Template and root cursorrules/copilot/codex trigger tables match on backlog/spec/churn rows
- `diff .agentic/lib/agents/claude/CLAUDE.md CLAUDE.md` shows only framework-dev-specific additions in root

---

## Files to modify (9 total)
<!-- 4 automation + 5 drift -->

**Automation (4 files):**
- `.agentic/lib/hooks/shared/on-plan-mode-exit.sh` — A1: inject `**Status**: DRAFT` into saved plan file
- `.agentic/lib/gate.py` — A1+A2+A3: add `check_pending_plan_review()`, `check_merge_without_done()`, `check_feature_branch_without_pr()` to `gate_stop()`
- `.claude/skills/implementing-features/SKILL.md` — A1: "MUST call `ag implement`" callout
- `.agentic/lib/hooks/shared/on-bash-merge-detect.sh` — A2: structured REQUIRED block
- (Stop.sh delegates to gate.py — no changes needed there)

**Drift (5):**
- `CLAUDE.md` (root)
- `.agentic/lib/agents/claude/CLAUDE.md` (template)
- `.cursorrules`
- `.github/copilot-instructions.md`
- `.codex/instructions.md`
