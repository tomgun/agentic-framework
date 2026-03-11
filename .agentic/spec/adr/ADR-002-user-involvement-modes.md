# ADR-002: User Involvement Modes

**Status**: Proposed
**Date**: 2026-03-11
**Deciders**: Tomas Gunther
**Context**: Gap analysis of idea-to-working-software pipeline across autonomy levels
**Source**: `.agentic/journal/plans/autonomy-pipeline-gap-analysis-plan.md` (3 rounds dialectical review, approved)

---

## Summary

Defines three user-involvement modes (Tech Lead, Product Visionary, Fully Autonomous) as composable configurations over the existing profile + review checkpoint system. Modes are init shortcuts that set sensible defaults — not persisted meta-configuration.

---

## 1. The Three Modes (ordered by autonomy: least → most)

### 1.1 Mode 1: Tech Lead

- **Autonomy**: LOW — human in the loop at every significant transition
- **Characteristic**: user controls pace and quality at feature level
- Reviews plans, PRs, code. Controls backlog. May write specs and code.
- This is the current framework sweet spot (`formal` profile)
- Profile: `formal` with `review_code: human`, `review_merge: human`

### 1.2 Mode 2: Product Visionary

- **Autonomy**: MEDIUM — human drives direction, framework handles execution
- **Characteristic**: user drives WHAT, framework handles HOW
- Interview-driven kickoff, taste/aesthetic control, preview-based feedback
- Delegates: code review, testing, implementation, commits
- Controls: vision, taste, NFRs, architecture decisions (in expertise areas), final acceptance
- Profile: `autonomous_formal` with taste settings + preview capability

### 1.3 Mode 3: Fully Autonomous

- **Autonomy**: HIGH — human only for final acceptance and escalations
- **Characteristic**: framework does everything from prompt to working software
- Single-prompt kickoff, all reviews via critical agent, auto-commit/merge
- User provides: initial prompt + style refs + constraints
- User receives: working software + report
- Profile: `autonomous_formal` with `review_merge: critical_agent`

---

## 2. Configuration Architecture

### 2.1 Modes as Init Shorthand, Not Meta-Configuration

The three modes are points on a **continuous spectrum**, not discrete categories.

- During `ag init`, offer mode selection as a convenient way to set initial defaults
- After init, only **individual settings** matter — no `user_role` setting persisted
- Users freely override any setting. A user who picks "visionary" but sets `review_merge: critical_agent` is in their own valid configuration
- This is the **same pattern** as `profile:` — it sets defaults, individual settings override
- Hybrid configurations compose naturally via setting overrides (e.g., `check_in_frequency: per_epic` gives autonomous per-feature with human review at epic boundaries)

### 2.2 Mode → Default Settings Mapping

These are **initial defaults**, not locked bundles:

| Setting | Mode 1 (Tech Lead) | Mode 2 (Visionary) | Mode 3 (Autonomous) |
|---------|-----------|-----------|------------|
| profile | formal | autonomous_formal | autonomous_formal |
| review_commit | human | critical_agent | critical_agent |
| review_merge | human | human | critical_agent |
| review_taste | skip | human | critical_agent |
| kickoff_mode | manual | interview | prompt |
| feedback_mode | pr_review | working_software | automated |
| check_in_frequency | per_feature | per_epic | on_escalation |

### 2.3 User Expertise (DEFERRED)

- Mapping user expertise to feature transitions is undefined
- DEFERRED: revisit after real usage patterns emerge from Mode 2 users
- If needed later: simple per-feature annotation ("I want to review this") rather than expertise taxonomy

---

## 3. Vision-to-Backlog Pipeline (ag kickoff)

### 3.1 Two Distinct Implementations

**Script mode** (`ag kickoff "prompt"`):
- Non-interactive. Takes prompt + optional --style/--research refs
- Generates artifacts in staging area: `.agentic/session/kickoff-draft/`
- Produces: OVERVIEW.md draft, FEATURES.md entries, acceptance criteria stubs, BACKLOG.json
- Validates: no ID conflicts, no circular deps, criteria are testable
- Routes through `review_decomposition` checkpoint
- On approval: copies from staging to real spec files
- Reuses: `ag decompose` (for epic → children), `backlog_helpers.py` (for ordering)

**Playbook mode** (`ag kickoff --interview` or selected during `ag init`):
- Interactive multi-turn conversation (like init_playbook.md pattern)
- Implemented as a PLAYBOOK/SKILL, not a script
- Phase 1: Vision interview (what, why, who, success criteria)
- Phase 2: Taste interview (aesthetics, design system, API style)
- Phase 3: Architecture interview (constraints, NFRs from nfr-catalog.md)
- Phase 4: Generate to staging area (same output as script mode)
- Phase 5: User reviews/edits staging artifacts → approve
- NOTE: Web research NOT included in MVP

### 3.2 Token Budget (F3 compliance)

- Script mode target: ~5–10K tokens (prompt parsing + feature generation)
- Playbook mode target: ~15–25K tokens across all interview phases
- Each interview phase as a focused subagent with role-specific context
- Generated artifacts use structured formats (frontmatter, consistent field patterns)
- Kickoff loads CONTEXT_PACK.md + STACK.md + NFR.md only — NOT full codebase

### 3.3 Staging Area & Validation

- All kickoff output goes to `.agentic/session/kickoff-draft/` first
- Uses `<!-- PROPOSAL -->` markers (same pattern as discovery in init_playbook.md)
- Validation: feature ID uniqueness, dependency acyclicity, criteria non-empty
- `ag kickoff --approve` moves from staging to real spec files
- Rollback: delete staging directory to discard

### 3.4 Integration with Scheduler

- After kickoff approval → `ag auto epic F-XXXX` (existing scheduler)
- Kickoff is the front-end; scheduler is the execution engine

---

## 4. New Review Boundary: review_commit

### 4.1 Problem

"Never auto-commit" is a constitutional principle (R2) appearing in ~28 files. Mode 3 needs autonomous commit to function.

### 4.2 Proposed Amendment to Principle R2

- R2 currently states: "Agents NEVER commit changes without explicit human approval"
- **This is a PRINCIPLE AMENDMENT PROPOSAL, not a formalization of existing behavior**
- `task.py._commit_ac()` currently auto-commits without human review — this is a **known principle violation** that should be either fixed or legitimized
- Two distinct commit contexts:
  - **Interactive agent sessions**: "never auto-commit" remains absolute
  - **Automated execution** (scheduler, task runner): auto-commit allowed IF explicitly opted-in AND reviewed by critical agent
- **Parent principle engagement**: R2 derives from D1 (Human-Agent Partnership) and D2 (Deterministic Enforcement). The amendment preserves D1 by requiring explicit opt-in (human chose to delegate) and preserves D2 by replacing behavioral hope with structural review (critical agent evaluates every diff)
- **If this amendment is rejected**: `task.py._commit_ac()` must be fixed, which would make `ag auto epic` non-functional without a human watching every commit

### 4.3 Solution

- New setting: `review_commit: human | critical_agent`
- `human` (default): current behavior for interactive sessions
- `critical_agent`: adversarial review of diff, auto-commits if approved
- `review_merge: critical_agent` also now allowed (for Mode 3)
- The rule becomes: "never auto-commit IN INTERACTIVE SESSIONS unless review_commit is explicitly set to critical_agent"

### 4.4 Implementation Scope (~15 files)

- `.agentic/lib/agents/shared/guidelines/core-rules.md`
- All agent templates (CLAUDE.md, cursorrules, copilot, codex, windsurf)
- `.agentic/lib/init/memory-seed.md`
- `.agentic/lib/PRINCIPLES.md`
- `.agentic/lib/workflows/git_workflow.md`
- LLM regression test `005_no_auto_commit.sh` (make conditional)
- NFR catalog entry
- `committing-changes` skill
- `profiles.conf` (add new setting)

### 4.5 Safety

- Formal profile default stays `human`; only autonomous_formal overrides to critical_agent
- Critical agent evaluates: all tests pass, no secrets in diff, no regressions, ACs met
- Any escalation → blocks for human
- Discovery profile: `human` (no auto-commit for lightweight projects)

---

## 5. Preview & Feedback Loop

### 5.1 ag preview

- Detects stack from STACK.md → reports how to run dev server
- MVP: documentation-first (detect stack → tell user how to run). Automated preview is P2+.
- Automated version (P2+): single-process stacks only, health check, URL reporting
- Complexity note: even "simple" dev servers involve port conflicts, env vars, database deps

### 5.2 Feedback Capture (DEFERRED)

- DEFERRED until preview generates real usage patterns
- Current workaround: user gives feedback via chat, agent captures as issues/features
- Future: structured feedback format → auto-conversion to bugs/features/criteria updates

---

## 6. Open Questions

- Should mode selection happen during `ag init` or as a separate `ag setup` step?
- How does `review_commit` interact with pre-commit hooks?
- Should `ag preview` be part of the scheduler loop (auto-preview after each epic)?

---

## 7. Consequences

**Positive**: Framework adapts to user's working style, enables true autonomy from prompt to working software.

**Negative**: More configuration surface, more edge cases in review checkpoint logic.

**Risk**: Auto-commit/merge could produce low-quality output if critical agent review is weak. Mitigated by requiring all tests pass + critical agent approval + escalation on any uncertainty.

---

## 8. Implementation Order

1. **F-0183: Taste & Style System** — already spec'd, low-dependency start (~5–8 files)
2. **Vision-to-Backlog Pipeline (ag kickoff)** — THE linchpin, feeds `ag auto epic`
3. **Preview Capability (ag preview)** — enables Mode 2 feedback loop
4. **Auto-Commit/Merge Mode** — ~15 files, formalizes R2 amendment
5. **Epic Integration Verification** — quality gate for epics with multiple children
6. **Init mode selection** — update init_playbook.md with mode shortcuts after settings exist
7. **Discovery-to-Formal Migration** — new `ag formalize` command
8. **Feedback Capture** — DEFERRED until preview generates real patterns
