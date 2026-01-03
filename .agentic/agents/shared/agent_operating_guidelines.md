# Agent operating guidelines (shared)

**📖 For framework principles and values, see [../../PRINCIPLES.md](../../PRINCIPLES.md)**

These rules are intended to be used by **any** assistant (Cursor, Copilot, Claude, etc.) working in this repo.

## Developer UX contract (keep the user "by the hand")
- Always make the next step obvious. End each work session with:
  - what changed (1–5 bullets)
  - what to do next (1–5 bullets)
  - what you need from the user (questions/decisions)
- Don't rely on user memory. When appropriate, suggest running:
  - `bash .agentic/tools/brief.sh` (quick context)
  - `bash .agentic/tools/report.sh` (what's missing / what needs acceptance)
  - `bash .agentic/tools/sync_docs.sh` (system docs scaffolding)
  - `bash .agentic/tools/retro_check.sh` (check if retrospective is due)
- When the user asks to start/init the project, prefer to run the scripts yourself (with the user's consent) rather than asking them to run commands.
- **Profile selection**: If initializing a new project, ask user to choose profile (Core or Core+Product). See `.agentic/init/scaffold.sh` for details.
- If the user returns after a break, proactively propose a resume protocol:
  - **If core profile**: Read `CONTEXT_PACK.md`, then `JOURNAL.md` (recent entries)
  - **If core+product profile**: Read `CONTEXT_PACK.md`, then `STATUS.md`, then `JOURNAL.md` (recent entries), then relevant feature acceptance docs
- **At session start, check for retrospective trigger**: If `STACK.md` has `retrospective_enabled: yes`, check if it's time for a project retrospective (see `.agentic/workflows/retrospective.md`). Suggest running one if threshold is met, but wait for human approval.
- **Check quality validation setup**: If `STACK.md` has `quality_validation_enabled: yes`, ensure `quality_checks.sh` exists at repo root. If missing, offer to create it based on the tech stack (see `.agentic/workflows/continuous_quality_validation.md`).
- **Check for active pipeline**: If `STACK.md` has `pipeline_enabled: yes`, check for active pipeline in `..agentic/pipeline/` (see `.agentic/workflows/automatic_sequential_pipeline.md`).

## Non-negotiables
- **No auto-commits without explicit human approval**: 
  - **NEVER commit changes without showing them to the user first and getting explicit approval**
  - **ONLY commit when the user explicitly says "commit" or "commit and push"**
  - Always present a summary of changes and ask for review before committing
  - Exception: If the user says "commit everything" or "auto-commit", you may proceed
  - See `.agentic/workflows/git_workflow.md` for commit protocols
- **Tests are required** for new/changed logic.
  - If a feature needs acceptance/integration/perf tests (domain-specific), add them or record a concrete follow-up task.
- **Keep the repo truthful**:
  - Update `CONTEXT_PACK.md` when architecture changes (Core and Core+Product)
  - Add to `HUMAN_NEEDED.md` when stuck (Core and Core+Product)
  - Update `JOURNAL.md` with session summary (Core and Core+Product)
  - **If core+product profile**: Also update `STATUS.md` after progress, update specs when behavior changes, write ADRs for tradeoffs
  - **If core+product profile**: Keep `spec/FEATURES.md` current if you change a feature's behavior/status/tests
  - **If core+product profile**: Keep `spec/NFR.md` current if change affects constraints

## Sequential Pipeline Mode (if enabled)

**At session start, if `pipeline_enabled: yes` in STACK.md**:

1. **Check for active pipeline**: Look for `..agentic/pipeline/F-####-pipeline.md`
2. **If pipeline exists**:
   - Read pipeline file to determine your role (Current agent: [Role])
   - Read handoff notes from previous agent
   - Load ONLY role-specific context (see token budgets in `sequential_agent_specialization.md`)
   - Follow role-specific responsibilities (Research/Planning/Test/Implementation/Review/Spec Update/Documentation/Git)
3. **If no pipeline exists but feature assigned**:
   - Check if you should start pipeline (usually Planning Agent, or Research if unclear)
   - Create `..agentic/pipeline/F-####-pipeline.md` from template (see `automatic_sequential_pipeline.md`)
4. **Context optimization** (CRITICAL):
   - Load ONLY what your role needs (Research: ~30K, Planning: ~40K, Test: ~35K, etc.)
   - Do NOT load entire codebase
   - Trust handoff notes from previous agent
   - See `.agentic/workflows/sequential_agent_specialization.md` for role-specific context budgets

**During work**:
- Update pipeline file with progress periodically
- Create handoff note for next agent when complete
- Mark your role as complete in pipeline file

**At completion**:
- Update pipeline file: mark role complete, set next agent, add handoff notes
- If `pipeline_mode: auto` AND `pipeline_handoff_approval: no`:
  - Save all work, signal for next agent
- If `pipeline_handoff_approval: yes` OR `pipeline_mode: manual`:
  - Present summary to human
  - Ask "Ready for [Next Agent]? (yes/no/show changes)"
  - Wait for approval

**If blocked**:
- Update pipeline status to "blocked"
- Add blocker description to pipeline file
- Escalate to `HUMAN_NEEDED.md` or ask human directly
- Do NOT proceed to next agent until resolved

## Before you edit code

**First, check the profile** (from `STACK.md`):
- Look for `Profile: core` or `Profile: core+product`
- This determines what files exist and how you work

### If Profile: core (minimal project tracking)

**What exists**:
- ✅ `STACK.md` - How to build/run
- ✅ `CONTEXT_PACK.md` - Architecture overview
- ✅ `PRODUCT.md` - What we're building, what's done, what's next
- ✅ `JOURNAL.md` - Session history
- ✅ `HUMAN_NEEDED.md` - Escalation protocol

**What does NOT exist**:
- ❌ `STATUS.md` - No project status/roadmap
- ❌ `spec/` - No formal specs or feature tracking
- ❌ Feature IDs (F-####) - No feature tracking system

**How to work in Core mode**:
1. **Read the product**: `PRODUCT.md` tells you what's being built, what's done, and what's in scope
2. **Ask user for direction**: "Which capability from PRODUCT.md should I work on?" or "What's the priority?"
3. **Read context**: `CONTEXT_PACK.md` (understand architecture), `JOURNAL.md` (recent work)
4. **Document as you go**: 
   - Update `CONTEXT_PACK.md` when architecture changes
   - Update `PRODUCT.md` when you complete capabilities or make technical decisions
   - Check off items in `PRODUCT.md` "Core capabilities" when done
5. **Escalate when stuck**: Add to `HUMAN_NEEDED.md` with clear description
6. **Session continuity**: Always update `JOURNAL.md` with progress summary
7. **No feature tracking**: Work on what user asks, no F-#### IDs
8. **Definition of done**: User approval (no formal acceptance criteria)

**Core mode is good for**:
- Small projects
- Solo developers with clear vision
- Exploratory work
- Prototyping

### If Profile: core+product (formal project tracking)

**What exists** (everything from Core, plus):
- ✅ `STATUS.md` - Project status, roadmap, "next up"
- ✅ `spec/FEATURES.md` - Feature registry with IDs (F-####)
- ✅ `spec/PRD.md`, `spec/TECH_SPEC.md`, `spec/NFR.md`
- ✅ `spec/acceptance/F-####.md` - Acceptance criteria per feature

**How to work in Core+Product mode**:
1. **Read STATUS.md first**: Know what to work on, current focus
2. **Load minimum context**: `CONTEXT_PACK.md`, `STATUS.md`, `spec/OVERVIEW.md`, `spec/FEATURES.md`
3. **Feature-based work**: Pick feature from STATUS.md, read acceptance criteria
4. **Track everything**: Update `spec/FEATURES.md` status, link code to features
5. **Formal definition of done**: Acceptance criteria in `spec/acceptance/F-####.md`
6. **Keep docs synced**: Update specs when behavior changes

**🚨 CRITICAL: Feature Creation Rule**:
- **When adding a new feature to `spec/FEATURES.md`, you MUST immediately create `spec/acceptance/F-####.md`**
- Never leave a feature without acceptance criteria - agents and humans need it to know what "done" means
- If acceptance criteria are unclear, add to `HUMAN_NEEDED.md` and wait for clarification
- Template: Use `.agentic/spec/FEATURES.template.md` as reference for acceptance file structure

**🚨 CRITICAL: Feature Status Workflow**:
- `planned` → Feature defined, acceptance criteria exist, not started
- `in_progress` → Actively being worked on (tests + implementation)
- `shipped` → Code complete, tests pass, deployed/merged
- `shipped` + `Accepted: no` → Waiting for human validation
- `shipped` + `Accepted: yes` → Human tested and approved
- **NEVER mark as `shipped` until**:
  1. All tests pass
  2. Code is committed
  3. Acceptance criteria file exists and is complete
- **After marking `shipped`**, tell human: "F-#### is complete. Please test and mark as accepted if it meets criteria"

---

- **If pipeline mode enabled and in pipeline**: Read `..agentic/pipeline/F-####-pipeline.md`, follow role-specific work (requires core+product profile)
- **Check for human edits**: Human may have added features, updated priorities, or changed specs directly. Honor those changes.
- **Follow the spec schema** (if core+product): All spec edits must conform to `.agentic/spec/SPEC_SCHEMA.md`
- **Check development mode**: Read `STACK.md` for `development_mode` field:
  - If `development_mode: tdd` (RECOMMENDED) → Follow `.agentic/workflows/tdd_mode.md` (write tests FIRST)
  - If `development_mode: standard` → Follow `.agentic/workflows/dev_loop.md` (tests required but not necessarily first)
  - If unset → Default to `tdd` mode
- **Verify documentation versions** (CRITICAL):
  - Read exact versions from `STACK.md` (e.g., "Next.js 15.1.0", "React 19.0.0")
  - If `context7_enabled: yes` → Use Context7 for version-specific docs
  - If manual verification → Go to official docs, ensure version selector matches
  - **NEVER assume an API exists without checking current docs**
  - See `.agentic/workflows/documentation_verification.md` for full protocol
- If the change touches a specific feature: read its acceptance file `spec/acceptance/F-####.md`.
- If constraints matter: read `spec/NFR.md`.
- Identify the relevant spec section(s) and acceptance criteria.
- Propose a small plan and the tests you will add/adjust.
- If requirements are ambiguous, ask before coding.

## While implementing
- Keep diffs small and incremental.
- Prefer seams and boundaries that enable unit tests.
- **Follow programming standards** (`.agentic/quality/programming_standards.md`):
  - Clear, descriptive names (no cryptic abbreviations)
  - Small, focused functions (<50 lines ideal)
  - Explicit error handling (fail fast, specific error types)
  - Avoid magic numbers (use named constants)
  - Avoid deep nesting (<4 levels)
  - Organize imports properly
- Avoid speculative changes outside the task scope.
- **Before using any library/framework API**:
  1. Verify version in `STACK.md`
  2. Check documentation for that specific version (Context7 or official docs)
  3. Look for deprecation warnings
  4. Add version comment in code (e.g., `// Next.js 15.1 API`)
  5. If docs seem outdated → STOP and add to `HUMAN_NEEDED.md`
- Annotate key code with feature IDs (see `.agentic/workflows/code_annotations.md`):
  - Add `@feature F-####` comments to functions/classes implementing features
  - Add `@nfr NFR-####` comments for code with non-functional constraints

## After implementing
- Run the relevant tests (or describe what would be run and why you couldn't).
- **Run formatter/linter** (if configured in STACK.md): ESLint, Prettier, black, ruff, gofmt, etc.
- **Run quality checks** (if configured): `bash quality_checks.sh --pre-commit` (see `.agentic/workflows/continuous_quality_validation.md`)
- **Self-review using**:
  - `.agentic/quality/review_checklist.md` (general review)
  - `.agentic/quality/programming_standards.md` checklist (code quality)
- **MANDATORY: Sync documentation** (see Documentation Sync Rule below).
- Append a session summary to `JOURNAL.md` (especially for long sessions or before context might reset).
- If mid-session and context is about to reset, update `STATUS.md` "Current session state" section with precise next steps.
- For the affected feature(s), update `spec/FEATURES.md`:
  - mark implementation/test status truthfully
  - update "Code:" field with paths to annotated modules
  - set `Accepted: yes` only when the change meets acceptance criteria and you verified it works in practice
- Optionally run `bash .agentic/tools/coverage.sh` to verify code annotations

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
- `Implementation: State`: Update from 'none' → 'partial' → 'complete' (ALWAYS update when you add code!)
- `Implementation: Code`: Add actual file paths as you create them
- `Tests: Unit/Integration/Acceptance`: Update from 'todo' → 'partial' → 'complete'
- `Verification: Accepted`: Leave as 'no' until human validates, then set to 'yes' with date

**🚨 CRITICAL: Keep Implementation State Accurate**:
- **If you write ANY code for a feature, change `State: none` to `State: partial` or `State: complete`**
- **NEVER leave `State: none` if code files exist**
- Check this EVERY time you update FEATURES.md
- If marking feature as `shipped`, verify:
  1. `Implementation: State: complete`
  2. `Implementation: Code:` field lists all relevant files
  3. `Tests: Unit:` is `complete` (not `todo`)
  4. Acceptance criteria file exists at `spec/acceptance/F-####.md`

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
Periodically check complexity thresholds (see `.agentic/workflows/scaling_guidance.md`):
- Feature count >30: suggest domain-based splitting
- NFR count >15: suggest category-based organization
- ADR count >20: suggest creating index
- Large context files: suggest module-specific docs

**Always suggest, never force.** Present options and let user decide.


