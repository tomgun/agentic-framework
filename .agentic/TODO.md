# TODO

<!-- format: todo-v0.1.0 -->

Purpose: quick-capture inbox for ideas, tasks, and reminders. Triage to FEATURES.md or ISSUES.md when ready, or resolve directly.

## Inbox

<!-- Use: bash .agentic/tools/todo.sh add "description" -->

### T-0001: Progressive disclosure of complexity
- **Added**: 2026-02-18
- **Context**: Migrated from STATUS.md Backlog

### T-0002: Context7 MCP integration — test in real project
- **Added**: 2026-02-18
- **Context**: Migrated from STATUS.md Backlog

### T-0003: Automated CI for LLM tests via Claude CLI
- **Added**: 2026-02-18
- **Context**: Migrated from STATUS.md Backlog

### ~~T-0007: Batch-verify ~50 shipped features with unchecked ACs~~ **OBSOLETE**: Legacy v0.1–v0.12 era features. T-0051 now warns on in_progress features going forward. Retroactive verification has diminishing returns.
- **Added**: 2026-02-24 · **Closed**: 2026-03-11

### ~~T-0010: Implement multi-agent helper scripts (F-0108)~~ **OBSOLETE**: Fully superseded by AGENTS.json (F-0194) and agents_helpers.py. F-0108 marked deprecated in FEATURES.md.
- **Added**: 2026-02-24 · **Closed**: 2026-03-10

### ~~T-0013: Close or formally assess F-0103 (Agent Mode Selection)~~ **DONE**: F-0103 marked shipped. Heading-format ACs (pre-checkbox convention) verified manually.
- **Added**: 2026-02-28 · **Closed**: 2026-03-11

### T-0014: Verify shipped acceptance criteria for F-0131, F-0132, F-0133, F-0134, F-0135 — check boxes that are actually done, identify genuinely incomplete items
- **Added**: 2026-02-28

### ~~T-0015: Structural enforcement for durable plan saving~~ **DONE**: Core covered by F-0198 (plan-scan.sh in ag sync auto-copies plans) + ag implement already checks plan file existence. The `plan_persistence` setting is a nice-to-have, not urgent.
- **Added**: 2026-02-28 · **Closed**: 2026-03-11

### ~~T-0016: Worktree auto-detection~~ **OBSOLETE**: Duplicate of T-0046; core shipped in F-0194 (ag implement auto-creates worktree, worktree_mode setting).
- **Added**: 2026-02-28 · **Closed**: 2026-03-10

### ~~T-0017: AGENTS_ACTIVE.md is never written~~ **CLOSED** (F-0197): Superseded by AGENTS.json (F-0194). F-0033 deprecated.
- **Added**: 2026-02-28 · **Closed**: 2026-03-10

### ~~T-0018: Remove legacy .agentic-journal/manifests/~~ **DONE**: Moved F-0185.json and F-0186.json to canonical .agentic/journal/manifests/. Removed legacy .agentic/.agentic-journal/ directory.
- **Added**: 2026-02-28 · **Closed**: 2026-03-11

### T-0021: Clarify subagents vs skills distinction in framework docs. Subagents (.agentic/agents/claude/subagents/) = role context for Task tool spawning, tool-agnostic. Skills (.agentic/agents/claude/skills/) = Claude Code workflow delivery bundles. Naming overlap (review, test, etc.) causes confusion. Need clear explanation in DEVELOPER_GUIDE, INSTRUCTION_ARCHITECTURE, and possibly a dedicated ADR.
- **Added**: 2026-03-01

### T-0022: Review all shipped specialization .conf content and other "project stack specific examples" — determine which details are time-proof (detection patterns, conventional dirs) which save tokens in the whole (no need for everybody to do the same research) vs temporal advice that should be LLM-synthesized JIT. Goal: ship stable knowledge that saves tokens, remove anything that risks going stale. Covers react/fastapi/django/go/godot confs.
- **Added**: 2026-03-01

### T-0023: F-idea: Smarter memory-seed sync — memory-check.sh should: (1) fix worktree bug (resolve to main repo memory path, not worktree path), (2) when stale, generate a precise diff showing what changed between memory version and current seed (not just 'go re-read the file'), (3) output structured instructions the LLM can apply as targeted patches. Script prepares the changes, LLM merges them (preserving project-specific memory). Reduces behavioral burden from 'read 115 lines and figure it out' to 'apply these 3 specific changes'.
- **Added**: 2026-03-01

### T-0025: F-idea: NFRs as live invariants — NFR.md should be the source of truth that propagates to features, not a dead reference. Key changes: (1) Acceptance criteria should have a separate 'Invariants (from NFR.md)' section auto-derived from NFR scoping, distinct from feature-specific criteria. (2) Test-writing workflow should check applicable NFRs before writing feature tests. (3) check-spec-health.sh should cross-reference NFR modification dates vs feature spec dates — if NFR changed after spec was written and feature references it, flag for review. (4) NFR capture trigger: when a developer or agent expresses an invariant quality for the system ("it must always...", "never do X", performance/security/reliability constraints), recognize it and write it to spec/NFR.md — don't let invariants stay informal. (5) Important distinction: framework NFR.md has 2 structural NFRs; projects using the framework may have dozens (performance, security, accessibility, compliance, etc.) — the workflow/tooling must scale to a longer list with mixed types (structural, behavioral, design invariants).
- **Added**: 2026-03-01

### ~~T-0028: Migrate .agentic-journal/ and .agentic-state/ into .agentic-local/ umbrella~~ **OBSOLETE**: Both directories already migrated — .agentic-journal/ → .agentic/journal/ (T-0018), .agentic-state/ → .agentic/session/ (F-0194). Backward-compat fallbacks in paths.sh. No .agentic-local/ umbrella needed.
- **Added**: 2026-03-02 · **Closed**: 2026-03-11

### T-0029: F-idea: Spec clarification taxonomy — resurface + enhance structured clarification in writing-specs skill. 6-category ambiguity taxonomy (functional, data model, edge cases, NFRs, integrations, completion signals), max 5 multiple-choice questions per spec, records [Clarified] markers. ~2K tokens/spec. Pre-existing framework idea resurfaced via SDD toolkit analysis (R1). Contributor: Tomas
- **Added**: 2026-03-02
- **Background**: `.agentic-journal/plans/2026-03-02-sdd-toolkit-analysis-plan.md` §3.1, §3.3, R1

### ~~T-0030: Verification loop~~ **DONE**: Shipped as F-0161 (Tiered Test Execution) + F-0164 (Verify Loop). Bounded test→fix→retest with tiered execution, escalation on exhaustion, diagnostic context. 100% complete.
- **Added**: 2026-03-02 · **Closed**: 2026-03-10

### ~~T-0031: Auto-dev loop~~ **DONE**: Shipped as F-0160–F-0163 (Autonomous Workflow Engine) + F-0186 (Autonomous Scheduler). Full spec→feature chain exists (TaskRunner reads spec → loops ACs → verify → PR). Deliberately not self-activated in framework dev (by design). ~90% complete, closed.
- **Added**: 2026-03-02 · **Closed**: 2026-03-10

### T-0032: F-0152 P2: Cross-feature semantic checks — three deferred checks for spec-analyze.sh: (AC-009) cross-feature terminology consistency (detects naming drift across spec files), (AC-010) AC contradiction detection (finds conflicting ACs within or across features), (AC-011) constitution alignment (checks ACs against PRINCIPLES.md). Requires LLM analysis — not deterministic. New insight from SDD toolkit analysis (their /analyze command's 6-pass approach). Contributor: Tomas
- **Added**: 2026-03-02
- **Background**: `.agentic-journal/plans/2026-03-02-sdd-toolkit-analysis-plan.md` §3.2, R2

### ~~T-0033: Task IDs and execution prioritization~~ **OBSOLETE**: Superseded by T-0043 (AC scheduling phase) which covers the same ground more concretely with AC-level dependency graphs and parallel execution.
- **Added**: 2026-03-02 · **Closed**: 2026-03-10

### ~~T-0034: Cursor agent leaves work uncommitted~~ **DONE**: Added commit nudge in ag.sh cmd_done(), completing-work skill Step 0, and cursorrules.txt "done" trigger.
- **Added**: 2026-03-03 · **Closed**: 2026-03-11

### T-0038: PR2: Visual verification for tiered verify loop — screenshot collection, AI review in autonomous mode (F-0168, see plan in session transcript)
- **Added**: 2026-03-06

### T-0039: PR3: E2E scaffolding — discover.py detection, setup guide, testing contract, quality profiles (see plan in session transcript)
- **Added**: 2026-03-06

### T-0040: F-idea: Post-PR auto-review loop in autonomous mode — after creating a PR automatically, run a one-time review (code quality + conformance against plan and acceptance criteria). If the review causes changes, re-run the verification loop, then do one final review. Report the situation to the user after (at most 2 review passes to avoid infinite review→fix→review cycles). Fits into the autonomous workflow engine (F-0160–F-0163) as a PR-quality gate.
- **Added**: 2026-03-06

### T-0041: F-idea: Auto-versioning and tagging — structural enforcement for VERSION bump + git tag after PR merge. Currently behavioral-only (instruction in committing-changes skill). Needs a hook or GitHub Action to make it impossible to forget. Options: post-merge git hook, GitHub Action on PR close, or pre-commit check that VERSION was bumped when on a feature branch.
- **Added**: 2026-03-06

### ~~T-0042: Multi-tool auto modes~~ **OBSOLETE**: Overly broad. Per-tool support should be scoped individually when needed, not as a single abstraction task.
- **Added**: 2026-03-06 · **Closed**: 2026-03-11

### T-0043: F-idea: AC scheduling phase in auto engine — before executing ACs, analyze dependencies and priorities to build an execution graph. Independent ACs run in parallel (git worktree per stream), dependent ACs chain sequentially. Connects plan-level [P] markers (F-0148) to runtime execution. Resource-aware: premium mode enables parallelism, economy forces sequential. Supersedes T-0033 (which was investigation-only). See CONTRIBUTIONS.md 'Task Scheduling & Parallel Execution' and SDD analysis §9.
- **Added**: 2026-03-07

### T-0044: F-NEW: Post-merge dogfooding workflow — after framework PR merge, systematically verify: (1) ag commands work with new code, (2) root entry points sync with template changes, (3) state files valid, (4) session-start loads correctly. Currently dogfooding is a principle but has no enforcement after merge. User insight from F-0177 PR session.
- **Added**: 2026-03-08

### T-0045: F-0193: Collision-proof feature IDs — current sequential F-XXXX IDs collide when multiple agents/branches assign independently. Research slug-based IDs, atomic allocation, or other approaches. See conversation notes on options.
- **Added**: 2026-03-08

### ~~T-0046: Worktree-by-default for feature branches~~ **DONE**: Shipped as F-0194. `worktree_mode: always` in STACK.md, `ag implement` auto-creates worktrees, `ag done` auto-cleans.
- **Added**: 2026-03-08 · **Closed**: 2026-03-11

### ~~T-0048: Plan file advisory in ag review~~ **DONE**: Added _check_plan_file() in review.py resolve path. Advisory prints when no durable plan found. Complements T-0047 (ag implement gate).
- **Added**: 2026-03-09 · **Closed**: 2026-03-11

### ~~T-0049: Dashboard after ag done~~ **DONE**: Added dashboard.sh call at end of cmd_done(), conditional on interactive terminal ([ -t 1 ]), non-blocking.
- **Added**: 2026-03-09 · **Closed**: 2026-03-11

### T-0050: Spec/backlog status drift: FEATURES.md status (planned/shipped) and BACKLOG.json can diverge. When discrepancy found, don't assume either is truth — check JOURNAL.md, CHANGELOG.md, and git history to determine actual state. Consider adding a drift-check tool.
- **Added**: 2026-03-09

### ~~T-0051: AC check-offs must be part of the implementation PR~~ **DONE**: Shipped as advisory pre-commit check. Warns when in_progress features have unchecked ACs. 10 bash tests.
- **Added**: 2026-03-10 · **Closed**: 2026-03-11

### T-0052: F-idea: Systematic LLM-optimized format pass — convert remaining unstructured files to LLM-friendly formats (YAML frontmatter, structured markdown, consistent field patterns). Priority targets: acceptance criteria files (free-form → structured AC blocks), STATUS.md/JOURNAL.md (markdown → more parseable), STACK.md settings (grep-parsed → schema-validated YAML/TOML). Constraint: must remain human-readable — optimized for both audiences. See PRINCIPLES.md F3, KEY_INSIGHTS.md §12
- **Added**: 2026-03-11

### T-0053: F-idea: Migrate STACK.md to structured config format (YAML/TOML) with schema validation. Current grep/sed parsing is fragile and settings lack discoverability. New format should: (1) support inline comments documenting valid options for each setting (e.g. git_workflow: pull_request # options: pull_request | direct), (2) enable tab-completion or validation of setting values, (3) remain human-editable in any text editor, (4) preserve the single-file simplicity (no splitting into multiple configs). Related: T-0052 (LLM-optimized format pass), PRINCIPLES.md F3.
- **Added**: 2026-03-11

### ~~T-0055: manifest.sh hardcodes legacy .agentic-journal path~~ **DONE**: Replaced hardcoded `$PROJECT_ROOT/.agentic-journal` with `$MANIFESTS_DIR` from paths.sh.
- **Added**: 2026-03-11 · **Closed**: 2026-03-11

### T-0056: T-0056: Plan file naming regression — saved plans missing YYYY-MM-DD date prefix (should be YYYY-MM-DD-F-XXXX-...-plan.md)
- **Added**: 2026-03-11

## Done


### T-0057: T-0057: manifest.sh regenerates on every dashboard/status call, creating dirty working tree noise. Also duplicates commits after rebase (dedup by message not just hash). Should either: (1) only regenerate when explicitly asked, or (2) gitignore manifests, or (3) dedup properly.
- **Resolved**: 2026-03-11 — resolved

### T-0054: Agent forgets doc updates and LLM test checks during feature implementation. Root cause: implementing-features and committing-changes skills don't have explicit gates for (1) checking if project docs (HOW_IT_WORKS, DEVELOPER_GUIDE, CHANGELOG, instruction files) need updating, and (2) checking if new LLM tests should be added. The doc check in implementing-features Step 6 only runs drift.sh and checks the doc registry — it doesn't check framework instruction files. Fix: add framework-dev doc gate to implementing-features Step 6 (when in framework repo, check all instruction files per CLAUDE.md § Framework Development), and add LLM test advisory to committing-changes (when new ag commands or behavioral rules are added, suggest LLM test). This is a recurring issue — user has had to remind multiple times.
- **Resolved**: 2026-03-11 — resolved
### T-0047: ag implement: gate on durable plan file (.agentic/journal/plans/F-XXXX-*-plan.md). Plans keep getting lost in ~/.claude/plans/.
- **Resolved**: 2026-03-10 — Implemented as F-0198: plan-scan.sh in ag sync scans ephemeral plan dirs and auto-copies to .agentic/journal/plans/

### T-0024: Consider relaxing max_staged_files for PR workflow — commits get squashed on merge, making per-commit file limits unnecessary friction for multi-phase features
- **Resolved**: 2026-03-06 — Batch-size limits (max_files_per_commit, max_added_lines) downgraded to advisory warnings on feature branches in PR workflow

### T-0027: Revisit D4: phased checkpoints vs file-count limits as small-batch proxy (L493 insight from SDD toolkit analysis)
- **Resolved**: 2026-03-06 — Batch-size limits downgraded to advisory on feature branches; phased checkpoints (F-0150) are the primary small-batch mechanism now

### T-0037: Session start: add 'untracked shipped features?' check — surface spec drift proactively every session, not just when ag sync is manually run (dogfooding: Cursor never ran ag sync, spec drift accumulated silently)
- **Resolved**: 2026-03-03 — Implemented as F-0156 — falls out of F-0155 quiet mode

### T-0036: SKIP_COMPLEXITY expiry/escalation — track bypass count per file in .agentic-state/, escalate after 3+ bypasses on same file: 'Either fix the file or create a refactor feature entry' (dogfooding: Cursor bypassed MainScene.ts complexity gate on every commit instead of fixing it)
- **Resolved**: 2026-03-03 — Implemented as F-0154 — per-file warnings in pre-commit-check.sh

### T-0035: Unregistered shipped code detector — ag sync should heuristically compare recently modified source files against FEATURES.md and flag new capabilities with no F-#### entry (dogfooding: Cursor shipped F-0011–F-0014 without feature entries, hooks had nothing to check)
- **Resolved**: 2026-03-03 — Implemented as F-0155 — phase_unregistered_code in sync.sh

### T-0026: Auto-resolve HUMAN_NEEDED PR entries: ag sync should check if PR entries are still open (gh pr view if available, else prompt human) and auto-clear merged ones. Keeps HUMAN_NEEDED clean without losing the write-on-create signaling pattern.
- **Resolved**: 2026-03-01 — resolved

### T-0012: Update FEATURES.md status: F-0136, F-0139, F-0140, F-0141 are shipped (PRs merged) but still marked in_progress
- **Resolved**: 2026-03-01 — Marked F-0136, F-0139, F-0140, F-0141 as shipped

### T-0020: LLM tests for F-0143 Skills: (1) Skill activation — does 'implement feature X' trigger implementing-features skill instructions (ag implement, acceptance criteria check)? (2) Trigger regression — do tests 003/010 still pass with 40-line CLAUDE.md where triggers are in Skills not instruction file? (3) Skill routing — does 'fix a bug' activate fixing-bugs skill (test-first behavior)? Skills are installed via install.sh in harness and visible to Claude Code via --print.
- **Resolved**: 2026-03-01 — resolved

### T-0019: LLM test gap: verify trigger compliance still holds with 40-line CLAUDE.md template (post-F-0143). Run existing tests 003/010 against thinned template to confirm no regression from moving triggers to Skills.
- **Resolved**: 2026-03-01 — resolved
<!-- Resolved/triaged items move here with outcome -->

### T-0005: Migrate Python tools from read_profile() to get_setting()
- **Added**: 2026-02-24
- **Resolved**: 2026-02-24
- **Outcome**: Removed read_profile() wrappers from doctor.py and verify.py; both now call get_setting() directly. phase_detect.py, discover.py, render_proposals.py, continue_here.py already used get_setting().

### T-0011: Automatic git tag after PR merge
- **Added**: 2026-02-24
- **Resolved**: 2026-02-24
- **Outcome**: Added `git tag v$(cat VERSION) && git push origin v$(cat VERSION)` instruction to all 4 framework-dev instruction files.

### T-0004: Fix blocker.sh double-write bug in add command
- **Added**: 2026-02-18
- **Resolved**: 2026-02-24
- **Outcome**: Removed duplicate `>>` append; kept `sed` insert before `## Resolved`

### T-0006: Clean up HUMAN_NEEDED.md resolved items
- **Added**: 2026-02-24
- **Resolved**: 2026-02-24
- **Outcome**: Added Resolved dates and Outcomes to HN-0002 through HN-0011. All PRs confirmed merged.

### T-0008: Remove Cursor prompt stubs referencing nonexistent upgrade_profile.sh
- **Added**: 2026-02-24
- **Resolved**: 2026-02-24
- **Outcome**: Replaced with `ag set profile formal` (exists since F-0141)

### T-0009: Fix README.md:512 template placeholder
- **Added**: 2026-02-24
- **Resolved**: 2026-02-24
- **Outcome**: Replaced `[Your issue tracker]` with GitHub Issues link
