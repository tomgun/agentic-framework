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

### T-0058: Investigation: F-0209 TDD Mode — can red-green-refactor loop be reliably enforced through skills/workflows, or is it too behavioral? Current tdd_mode.md exists but isn't wired. Need to test if agents actually follow test-first ordering when instructed.
- **Added**: 2026-03-11

### T-0059: Investigation: F-0210 Configurable DoD per task type — feasibility study. Can agents reliably switch between different 'done' checklists based on task type (implementation vs design vs spike vs bugfix)? Risk: behavioral branching is hard to enforce structurally.
- **Added**: 2026-03-11

### T-0060: F-0207 enhancement: --validate should read file content to determine if .md file is a project doc needing upkeep vs internal/config. LLM-assisted classification.
- **Added**: 2026-03-11

### T-0061: F-0207 enhancement: cache scan results for files already classified as non-doc, skip re-scanning unless changed
- **Added**: 2026-03-11

### T-0062: F-IDEA: Autonomous Framework Verification Loop — agent builds example projects (todo app, API service, CLI tool) using the framework end-to-end, acting as developer/architect. Uses git worktrees or temp branches (HARD GUARD: never touch main/real branches). Agent handles its own review requests, commit approvals, kickoff flows. Self-healing loop: when a framework issue is found, (1) auto-fix the framework code, (2) restart the example project from scratch, (3) repeat until the full lifecycle completes without errors. Build project → hit framework bug → fix framework → rebuild → verify fix. Catches behavioral gaps that unit/LLM tests miss. Think: ag auto verify-framework --project todo-app. Could reuse ag auto task/crunch infrastructure. Key constraints: isolated worktrees, ephemeral branches only, auto-cleanup, abort on any main-branch mutation attempt. **Prerequisite**: state-commit.sh and other scripts that hardcode "main"/"master" must accept a configurable trunk branch (env var or setting) so verification runs don't pollute real main. **Coverage**: must exercise all three operation modes (tech lead/formal, visioneer/interview, full autonomous) and key settings matrix (discovery vs formal profiles, review modes human/critical_agent/skip, docs_mode inline/deferred, worktree_mode, kickoff_confirm ask/skip, git_workflow direct/pull_request). **Delivery**: all framework fixes discovered during verification must be collected into a single PR at the end. The verification loop runs on an ephemeral trunk branch where agents auto-merge their fix PRs as they go; once the full loop passes clean, the accumulated fixes are delivered as one PR against real main for human review.
- **Added**: 2026-03-12

### T-0063: HTTP dashboard endpoint on coord server — GET /dashboard route returning dashboard.sh output as text/JSON for lightweight remote status checking (phone browser, curl, future web UI)
- **Added**: 2026-03-13

### T-0064: ag preview command — stack-specific hook triggering preview deployment (Vercel/Netlify/etc), returns URL. Quality profile extension, not core.
- **Added**: 2026-03-13

### T-0065: Discovery profile documentation — ensure discovery profile is clearly documented as the rapid Idea-to-Ship pipeline for users wanting lighter workflow ceremony
- **Added**: 2026-03-13

### T-0066: Support for protected main branch: ag done/flush currently commit state files (BACKLOG.json, STATUS.md, FEATURES.md, VERSION) directly to main. With branch protection rules (no direct push, require PR review), this breaks. Design alternatives: (1) long-lived state branch auto-synced via rebase, (2) auto-PR for state flushes with auto-merge label, (3) bot-exempt bypass token for state-only commits, (4) state files live outside git (e.g. GitHub API, external store). Must audit all direct-to-main paths: ag done, ag flush, state-commit.sh. Consider: what if state diverges while PR waits? Merge conflict risk with parallel agents.
- **Added**: 2026-03-13

### T-0067: NFR lifecycle: auto-generate project-appropriate NFRs at init and retrospectives. Categories: testability, performance, security, usability, reportability, scalability, portability, visual impressiveness, immersivity, small deployment size, etc. Pre-filled templates for common project types (web, API, games, music software, mobile, CLI). NFRs may vary per component. Guide user to refine NFRs before they flow into ACs — user may add/change constraints. Trigger points: ag kickoff, ag init, retrospectives, and other natural stops. This ensures NFR→AC→implementation pipeline starts with good NFRs, not afterthoughts.
- **Added**: 2026-03-15

### T-0068: F-0234: Create ExitPlanMode hook wrappers for Cursor, Gemini, Codex, Copilot — shared logic exists at .agentic/lib/hooks/shared/on-plan-mode-exit.sh, needs per-tool wrappers like .agentic/hooks/claude/ExitPlanMode.sh
- **Added**: 2026-03-17
- **Background**: F-0234 (PR #151) shipped the ExitPlanMode hook for Claude Code only. The shared hook logic at `.agentic/lib/hooks/shared/on-plan-mode-exit.sh` was designed to be agent-agnostic — it handles plan-save and review-instruction injection. Each tool needs a thin wrapper: Claude has `.agentic/hooks/claude/ExitPlanMode.sh`, but Cursor, Gemini, Codex, and Copilot don't yet. Gemini is closest to ready (mature AfterTool with regex matchers per `docs/INSTRUCTION_ARCHITECTURE.md` line 32). Cursor/Copilot/Codex hook support is emerging.
- **Related**: F-0234 plan (`.agentic/journal/plans/2026-03-17-F-0234-plan.md`), `docs/INSTRUCTION_ARCHITECTURE.md` §4 Defense-in-Depth: Hooks

### T-0069: F-0234: Field-validate ExitPlanMode hook (A11) — enter/exit plan mode in Claude Code and verify hook fires, PostToolUse banner appears
- **Added**: 2026-03-17
- **Background**: F-0234 PR #151 test plan has two unchecked items requiring manual testing in Claude Code. Assumption A11 in `docs/INSTRUCTION_ARCHITECTURE.md` tracks that the ExitPlanMode matcher behavior (PostToolUse with `tool_name == "ExitPlanMode"`) needs field validation — unit tests pass but the actual Claude Code hook dispatch hasn't been tested interactively. Need to: (1) enter plan mode, (2) exit plan mode, (3) verify the hook banner appears with plan-save confirmation and review instructions.
- **Related**: PR #151 test plan, `docs/INSTRUCTION_ARCHITECTURE.md` Assumption A11, `.agentic/lib/claude-hooks/hooks.json`

### T-0070: F-0234: Field-validate Check 21 — verify pre-commit blocks commit when WIP exists without APPROVED plan
- **Added**: 2026-03-17
- **Background**: F-0234 added pre-commit Check 21 (`.agentic/lib/hooks/pre-commit-check.sh` lines 1157-1189) which blocks commits when `plan_review_enabled: yes` and a WIP entry exists in AGENTS.json but no APPROVED plan is found. Unit tests verify the logic, but the actual blocking behavior during a real `git commit` hasn't been validated. Test: create WIP entry without plan, attempt commit, verify it's blocked with clear error message.
- **Related**: PR #151 test plan, `.agentic/lib/hooks/pre-commit-check.sh` Check 21, `tests/test_plan_review_hooks.sh`

### ~~T-0071: DONE — PreToolUse(Write|Edit) artifact enforcement implemented (Phase 4 completion, 2026-03-21)~~
- **Added**: 2026-03-17 · **Completed**: 2026-03-21
- **Resolution**: Implemented as `.agentic/lib/claude-hooks/PreToolUse.sh` — blocks Write/Edit/MultiEdit when v2 engine is active and required artifacts are missing. Uses `ag check --quick --active` for <500ms checks, returns `permissionDecision: "deny"` to block. Allows edits to framework/config/state files (.agentic/*, tests/*, docs/*, *.md, etc.).

### T-0072: Future hook: PreToolUse(Bash)+parse cmd — prevent stash/reset with active agents (from INSTRUCTION_ARCHITECTURE.md transition table)
- **Added**: 2026-03-17
- **Background**: `docs/INSTRUCTION_ARCHITECTURE.md` §"Tool-Native Hook Transition Points" (line 331) lists this as a future enforcement point. Multi-session safety currently relies on prompt instructions ("run agents_helpers.py count-others before destructive ops"). A PreToolUse hook on Bash could parse the command for `git stash`, `git reset --hard`, `git checkout .`, `git restore .`, `git clean -f` and auto-check for other active agents before allowing. Would make the "never git stash" rule structural instead of behavioral.
- **Related**: `docs/INSTRUCTION_ARCHITECTURE.md` transition table, F-0194 multi-agent safety, CLAUDE.md multi-session safety rule

### T-0073: Future hook: PostToolUse(Bash)+parse cmd — after ag done verify completeness (from INSTRUCTION_ARCHITECTURE.md transition table)
- **Added**: 2026-03-17
- **Background**: `docs/INSTRUCTION_ARCHITECTURE.md` §"Tool-Native Hook Transition Points" (line 332) lists this as a future enforcement point. After `ag done` runs, a PostToolUse hook could verify that all expected artifacts were actually created/updated (ACs checked, docs updated, journal entry written, VERSION bumped). Currently `ag done` runs internal checks, but this would add a tool-native verification layer that catches issues even if the agent bypasses `ag done` and runs completion steps manually.
- **Related**: `docs/INSTRUCTION_ARCHITECTURE.md` transition table, `feature_complete.md` checklist, F-0234 hook architecture

### T-0074: Future hook: PreToolUse(Bash)+parse gh pr — pre-submit check ensuring tests pass before PR creation (from INSTRUCTION_ARCHITECTURE.md transition table)
- **Added**: 2026-03-17
- **Background**: `docs/INSTRUCTION_ARCHITECTURE.md` §"Tool-Native Hook Transition Points" (line 333) lists this as a future enforcement point. When an agent runs `gh pr create`, a PreToolUse hook could verify that tests pass, pre-commit checks are clean, and required artifacts exist before allowing the PR to be created. Would prevent PRs with known-failing tests from being submitted for review.
- **Related**: `docs/INSTRUCTION_ARCHITECTURE.md` transition table, `before_commit.md` checklist, F-0234 hook architecture

### T-0075: F-0193 PR 2: Apply ID centralization to other entity types — NFR-XXXX, T-XXXX, I-XXXX, HN-XXXX, FB-XXXX, R-XXXX (follow-up from F-0193 shipped in v0.57.0)
- **Added**: 2026-03-17
- **Background**: F-0193 (PR #152, shipped v0.57.0) centralized Feature ID patterns (`F-XXXX`) into `.agentic/lib/ids.py` and `.agentic/lib/ids.sh`, widening from `\d{4}` to `\d{4,}`. The plan (`.agentic/journal/plans/2026-03-17-F-0193-plan.md`) explicitly scoped PR 1 to Feature IDs only (~40 files) and deferred other entity types to PR 2. Remaining types: NFR-XXXX (non-functional requirements), T-XXXX (TODOs), I-XXXX (issues), HN-XXXX (human-needed items), FB-XXXX (feedback), R-XXXX (references). Same pattern: add to ids.py/ids.sh, update regex consumers.
- **Related**: F-0193 plan, PR #152, `.agentic/lib/ids.py`, `.agentic/lib/ids.sh`, E-0001 epic plan (`.agentic/journal/plans/2026-03-17-F-0219-plan.md`)

### T-0076: Production project post-merge sync: after merging PRs in production projects, local instruction file extensions (CLAUDE.md, .cursorrules) and project-specific memory may need updating — different from framework dogfood sync which syncs templates↔root
- **Added**: 2026-03-17
- **Background**: PR #153 added a "Post-merge dogfood sync" step to the completing-work workflow, but it's guarded to framework-dev only (`FRAMEWORK_DEVELOPMENT.md` existence check). Production projects have a related but different need: when a PR changes behavior, local CLAUDE.md extensions, .cursorrules project-specific sections, and project-level persistent memory (auto-memory) may need updating to reflect the new reality. Examples: a PR adds a new API endpoint → CLAUDE.md's project-specific section should mention it; a PR changes the build system → memory about build commands is stale. This is NOT about syncing `.agentic/lib/` templates (that's framework-internal) — it's about keeping project-level agent context fresh after code changes land.
- **Related**: PR #153 (dogfood sync), completing-work skill Step 6, `feature_complete.md` "Post-merge dogfood sync" checklist item, F-0226 (Post-Merge Dogfooding planned feature in E-0001 epic)

### T-0077: plan-scan.sh creates duplicates when plan exists under different filename — enforce rigid naming convention: F-XXXX / E-XXXX / slug-based, and match on ID/slug before saving
- **Added**: 2026-03-17
- **Background**: `plan-scan.sh` saved `~/.claude/plans/` content as `2026-03-17-F-0219-plan.md` despite identical content already existing as `2026-03-16-E-0001-opportunity-map-epic-plan.md`. Root cause: scan matches by feature ID in filename only, not by content or epic ID. Three plan types need rigid naming: `YYYY-MM-DD-F-XXXX-plan.md`, `YYYY-MM-DD-E-XXXX-plan.md`, `YYYY-MM-DD-<slug>-plan.md` (generic/research). `_find_plan_file()` and `plan-scan.sh` both need updating.
- **Related**: `plan-scan.sh`, `_find_plan_file()` in ag.sh, `.agentic/journal/plans/`

### T-0078: ag done verification subprocess leaks sourced env (ROOT_DIR, FRAMEWORK_ROOT) into bash -c, causing functional tests to use wrong project root — 5 phantom failures vs direct run
- **Added**: 2026-03-17

### T-0083: LLM test: agent must auto-save plan and run dialectical review loop after exiting plan mode — no stopping, no waiting for user input. Verify full sequence: save DRAFT → spawn Critic+Advocate → synthesize → convergence check → APPROVED → ag implement. Test both auto and manual convergence modes. Background: this session the agent tried to skip plan review entirely until corrected with 'save the plan first, review it'.
- **Added**: 2026-03-20

### T-0084: LLM test: agent must update all project documentation (HOW_IT_WORKS, DEVELOPER_GUIDE, FRAMEWORK_WORKFLOW, FRAMEWORK_MAP, README, CHANGELOG) BEFORE creating a PR — not post-merge. Step 6 of implementing-features skill. Background: F-0241 shipped with zero doc updates; required a separate fix PR #175 after user caught the gap. docs_gate: blocking should catch this if ag done is used properly.
- **Added**: 2026-03-20

### T-0085: LLM test: agent must update specs/acceptance criteria AND write the migration log when implementation changes affect shipped features — Step 7 of implementing-features skill. Both actions required: (1) create migration via migration.sh documenting why the spec evolved, (2) add new ACs to affected spec/acceptance/F-XXXX.md with migration reference. Background: this is a recurring skip — agents treat shipped specs as frozen rather than living documents that evolve with implementation. Related: feedback_doc_updates_must_be_structural.md.
- **Added**: 2026-03-20

### T-0086: Phase 3 spec protection audit: ~9 shipped features have ACs referencing deleted files, 0 spec migrations created for ~100 affected features. Context-for-role.sh silently drops constitutional rules. 4 ag commands degrade. 13 context manifests reference deleted files. See PR #182 (a22475e). Background: Phase 3 deleted ~130 files / 34K lines but validate_framework.sh v2 mode skips v1 checks, hiding the gaps. Affected features: F-0069 (all 7 checklists), F-0011 (programming_standards), F-0012 (test_strategy), F-0013 (smoke_testing), F-0014 (library_selection), F-0074 (green_coding), F-0102 (modular guidelines), F-0055 (anti-hallucination), F-0093 (AGENT_QUICK_START). Functional issues: context-for-role.sh ALWAYS_INJECT references guidelines/core-rules.md (deleted), commit.sh/done.sh/implement.sh/specs.sh degrade to generic guidance when checklists missing. Either evolve shipped specs with migrations mapping old ACs to v2 equivalents, or deprecate features superseded by v2 engine.
- **Added**: 2026-03-21

### T-0087: AC check-off should happen with the code changes, not post-merge. Options: (1) In PR workflow: check off ACs in the PR itself (pre-merge), so reviewers see which ACs are satisfied. (2) In direct-commit mode: check off at commit time. Problem: feature numbering conflicts when multiple features develop simultaneously in PR mode — numbers could clash. But if work is planned well (backlog), numbers are assigned beforehand. Consider: assign F-XXXX at plan time (current behavior), check off ACs in the feature branch (not post-merge), and only bump VERSION post-merge. The post-merge AC check-off we do today is backwards — the evidence should travel with the code.
- **Added**: 2026-03-22

### T-0088: Scaffold should copy all Claude tool files (.claude/hooks.json, skills/, subagents/, CLAUDE.md) during scaffolding — BEFORE the agent session starts. Currently setup-agent.sh runs mid-session (called by scaffold.sh), but hooks only take effect on next session start. Fix: scaffold.sh should create .claude/ with hooks.json as part of the directory structure creation (alongside .agentic/), not as a separate setup-agent step. Then when the user starts their first Claude session, hooks are already in place. Remove the 'restart Claude' advisory. The init playbook phase can then remove/customize tool dirs the user doesn't need (e.g. if they only use Cursor, remove .claude/). This inverts the current flow: install everything → prune, instead of install nothing → add on request.
- **Added**: 2026-03-22

### T-0089: Investigate: custom feature prefixes and subproduct grouping. Can users define own prefixes (e.g., AUTH-001, PAY-002) or group features by subproduct within the same repo? Currently F-XXXX is hardcoded in ids.sh regex. Consider: prefix registry in STACK.md, multi-prefix support in is_feature_id(), FEATURES.md sections per subproduct, backlog filtering by prefix. Related: monorepo/multi-component support (F-0179 components).
- **Added**: 2026-03-23

### T-0090: Remove plan.md from work/ artifact instructions — /work/plan.md is never read by CLI, state machine, or gate system; only tasks.yaml in work/ is functional. Remove plan.md from 'Write artifacts to .agentic/work/F-XXXX/' line in all instruction files (CLAUDE.md template+root, cursorrules, copilot, codex, memory-seed). Background: investigated during F-0193 drift fix session, F-0302 has orphaned work/plan.md. Related: spec.md/review.md/journal.md in work/ may be similarly unused — verify.
- **Added**: 2026-03-23

### T-0091: Investigate deadweight artifacts: work/plan.md (and possibly work/spec.md, work/review.md) are written by agents per instruction but never read by state machine/CLI. Clarify: should these be removed from instructions, or should CLI gain awareness of them? Related: what other work/ artifacts are similarly orphaned?
- **Added**: 2026-03-23

## Done


### T-0082: T-NEW: validate_framework.sh check: shipped features must appear in CHANGELOG and at least one living doc (HOW_IT_WORKS, DEVELOPER_GUIDE, or FRAMEWORK_WORKFLOW). Compares FEATURES.md shipped entries against doc mentions. Behavioral layer (concrete 3-concern decision tree in skills) already shipped in F-0237 — this is the structural backstop. Related: F-0138, F-0207, pre-commit-check.sh Check 19, docs.sh
- **Resolved**: 2026-03-20 — resolved

### T-0079: Structural gate for project-wide documentation currency at feature completion
- **Resolved**: 2026-03-20 — resolved

### T-0081: Build session log analysis tool (session-analyze.py). Background: Manual analysis of session d7d00d88 (3 autonomous_formal violations, 68 min wasted) required hand-parsing Claude JSONL transcripts to build a timeline. This tool should: (1) Parse Claude Code JSONL session logs from ~/.claude/projects/, (2) Detect workflow violations by matching tool calls against expected sequences (e.g., ExitPlanMode should be followed by Agent spawns, not Write/Edit), (3) Calculate time gaps between user prompts to measure wasted wait time, (4) Output structured report with violation type, timestamp, time wasted, and agent rationalization text. Related: tests/llm/harness.sh (similar JSONL parsing), session_analysis_d7d00d88.md (manual analysis as reference), .agentic/lib/auto/ (Python orchestration patterns)
- **Resolved**: 2026-03-20 — resolved

### T-0080: Optimize memory-seed.md from 320→~200 lines using LLM-directive format. Background: memory-seed.md at 320 lines exceeds the 100-line validated ceiling from L-0002 (INSTRUCTION_ARCHITECTURE.md). Dialectical review confirmed this needs empirical validation — run LLM tests 043/057/058/084 before+after to check for behavioral regression. The optimization approach: replace narrative paragraphs with directive bullet points, merge duplicated workflow patterns, remove examples that duplicate CLAUDE.md content. Related: docs/INSTRUCTION_ARCHITECTURE.md, .agentic/lib/init/memory-seed.md, tests/llm/harness.sh
- **Resolved**: 2026-03-20 — resolved

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
