# Agent operating guidelines (shared)

These rules are intended to be used by **any** assistant (Cursor, Copilot, Claude, etc.) working in this repo.

## Developer UX contract (keep the user "by the hand")
- Always make the next step obvious. End each work session with:
  - what changed (1–5 bullets)
  - what to do next (1–5 bullets)
  - what you need from the user (questions/decisions)
- Don't rely on user memory. When appropriate, suggest running:
  - `bash agentic/tools/brief.sh` (quick context)
  - `bash agentic/tools/report.sh` (what's missing / what needs acceptance)
  - `bash agentic/tools/sync_docs.sh` (system docs scaffolding)
  - `bash agentic/tools/retro_check.sh` (check if retrospective is due)
- When the user asks to start/init the project, prefer to run the scripts yourself (with the user's consent) rather than asking them to run commands.
- If the user returns after a break, proactively propose a resume protocol:
  - read `CONTEXT_PACK.md`, then `STATUS.md`, then `JOURNAL.md` (recent entries), then relevant feature acceptance docs.
- **At session start, check for retrospective trigger**: If `STACK.md` has `retrospective_enabled: yes`, check if it's time for a project retrospective (see `agentic/workflows/retrospective.md`). Suggest running one if threshold is met, but wait for human approval.

## Non-negotiables
- **Follow the spec workflow**: treat `/spec/*`, `spec/adr/*`, `STATUS.md`, `STACK.md`, `CONTEXT_PACK.md` as authoritative.
- **Keep feature truth current**: if you change a feature’s behavior/status/tests, update `spec/FEATURES.md` and the relevant acceptance file(s).
- **Keep NFR truth current**: if your change affects cross-cutting constraints (perf/security/realtime/reliability), update `spec/NFR.md` and link relevant NFR IDs from the feature(s).
- **Tests are required** for new/changed logic.
  - If a feature needs acceptance/integration/perf tests (domain-specific), add them or record a concrete follow-up task.
- **Keep the repo truthful**:
  - update `STATUS.md` after meaningful progress
  - update specs when behavior changes
  - write ADRs for real tradeoffs

## Before you edit code
- Read (minimum): `CONTEXT_PACK.md`, `STATUS.md`, `spec/OVERVIEW.md`, `spec/FEATURES.md`.
- **Check for human edits**: Human may have added features, updated priorities, or changed specs directly. Honor those changes.
- **Follow the spec schema**: All spec edits must conform to `agentic/spec/SPEC_SCHEMA.md` (valid status values, field formats, cross-reference conventions).
- **Check development mode**: Read `STACK.md` for `development_mode` field:
  - If `development_mode: tdd` (RECOMMENDED) → Follow `agentic/workflows/tdd_mode.md` (write tests FIRST)
  - If `development_mode: standard` → Follow `agentic/workflows/dev_loop.md` (tests required but not necessarily first)
  - If unset → Default to `tdd` mode
- If the change touches a specific feature: read its acceptance file `spec/acceptance/F-####.md`.
- If constraints matter: read `spec/NFR.md`.
- Identify the relevant spec section(s) and acceptance criteria.
- Propose a small plan and the tests you will add/adjust.
- If requirements are ambiguous, ask before coding.

## While implementing
- Keep diffs small and incremental.
- Prefer seams and boundaries that enable unit tests.
- Avoid speculative changes outside the task scope.
- Annotate key code with feature IDs (see `agentic/workflows/code_annotations.md`):
  - Add `@feature F-####` comments to functions/classes implementing features
  - Add `@nfr NFR-####` comments for code with non-functional constraints

## After implementing
- Run the relevant tests (or describe what would be run and why you couldn't).
- Self-review using `agentic/quality/review_checklist.md`.
- **MANDATORY: Sync documentation** (see Documentation Sync Rule below).
- Append a session summary to `JOURNAL.md` (especially for long sessions or before context might reset).
- If mid-session and context is about to reset, update `STATUS.md` "Current session state" section with precise next steps.
- For the affected feature(s), update `spec/FEATURES.md`:
  - mark implementation/test status truthfully
  - update "Code:" field with paths to annotated modules
  - set `Accepted: yes` only when the change meets acceptance criteria and you verified it works in practice
- Optionally run `bash agentic/tools/coverage.sh` to verify code annotations

## Documentation Sync Rule (MANDATORY)

When implementing features, creating files, or making significant changes, **immediately update these canonical documentation files in the same commit**:

### 1. CONTEXT_PACK.md
Update when:
- Creating new entry points or core modules
- Adding new directories or major components
- Changing how to run/test the project
- Learning important architectural details

**What to update:**
- "Where to look first (map)": Add actual paths when creating entry points
- Replace "(Not yet created)" and "(To be created)" placeholders with real paths
- Update "Current top priorities" to reflect actual next steps from STATUS.md
- Update "Architecture snapshot" when structure changes
- Update "Known risks / sharp edges" when discovering new issues

### 2. STATUS.md
Update when:
- Starting work on a new feature (move from "Next up" to "In progress")
- Completing any work item
- Changing focus between tasks
- Encountering blockers

**What to update:**
- "Current focus": Change when switching work context
- "In progress": Mark items complete, remove them or move to roadmap
- "Next up": Update based on what's actually next (not aspirational)
- "Current session state": Update when changing implementation phase
- "Known issues / risks": Add newly discovered issues

### 3. FEATURES.md (spec/FEATURES.md)
Update when:
- Starting feature implementation
- Creating implementation files
- Writing tests
- Completing any milestone

**What to update:**
- `Status`: Change from 'planned' → 'in_progress' → 'shipped'
- `Implementation: State`: Update from 'none' → 'partial' → 'complete'
- `Implementation: Code`: Add actual file paths as you create them
- `Tests: Unit/Integration/Acceptance`: Update from 'todo' → 'partial' → 'complete'
- `Verification: Accepted`: Set to 'yes' only when fully tested and working

### Enforcement Protocol

**After creating any file:**
1. Check if that file type is mentioned in CONTEXT_PACK.md
2. If yes, update CONTEXT_PACK.md to replace placeholder with actual path
3. If creating entry point, add it to "Where to look first"

**Before marking work complete:**
1. Check STATUS.md reflects what you actually did
2. Check FEATURES.md status matches reality
3. Check CONTEXT_PACK.md has no stale placeholders for your work

**When completing a feature:**
1. Update all three files (CONTEXT_PACK, STATUS, FEATURES) in same commit
2. Verify no "(Not yet created)" remains for completed code
3. Verify "Current top priorities" reflects next actual work

**Red flags (fix immediately):**
- CONTEXT_PACK.md says "Entry point: (Not yet created)" but you created it
- STATUS.md "In progress" lists completed work
- FEATURES.md "Status: shipped" but "State: none" 
- FEATURES.md "Code:" field is empty for implemented feature
- FEATURES.md "Tests: complete" but test files don't exist

## Token efficiency
- Start sessions by reading `CONTEXT_PACK.md` then `STATUS.md` then recent `JOURNAL.md` entries.
- When you learn something important, capture it in `CONTEXT_PACK.md` so the next session is cheaper.
- Before context resets, capture mid-session state in `STATUS.md` and `JOURNAL.md`.

## When to escalate to human
Add entries to `HUMAN_NEEDED.md` for:
- **Business decisions**: pricing, partnerships, user priorities that agents lack context for
- **Security decisions**: encryption strategies, authentication approaches, sensitive data handling
- **Complex debugging**: after 3-5 failed attempts, especially hardware/environment-specific issues
- **Large refactors**: changes touching >50 files require human oversight
- **Compliance/legal**: privacy, data retention, accessibility requirements
- **Production risk**: changes with unclear impact on live systems

**Don't escalate routine implementation, bug fixes with clear solutions, or small refactors.**

## When to suggest reorganization
Periodically check complexity thresholds (see `agentic/workflows/scaling_guidance.md`):
- Feature count >30: suggest domain-based splitting
- NFR count >15: suggest category-based organization
- ADR count >20: suggest creating index
- Large context files: suggest module-specific docs

**Always suggest, never force.** Present options and let user decide.


