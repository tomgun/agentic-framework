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

### T-0021: Clarify subagents vs skills distinction in framework docs. Subagents (.agentic/agents/claude/subagents/) = role context for Task tool spawning, tool-agnostic. Skills (.agentic/agents/claude/skills/) = Claude Code workflow delivery bundles. Naming overlap (review, test, etc.) causes confusion. Need clear explanation in DEVELOPER_GUIDE, INSTRUCTION_ARCHITECTURE, and possibly a dedicated ADR.
- **Added**: 2026-03-01

### T-0022: Review all shipped specialization .conf content and other "project stack specific examples" — determine which details are time-proof (detection patterns, conventional dirs) which save tokens in the whole (no need for everybody to do the same research) vs temporal advice that should be LLM-synthesized JIT. Goal: ship stable knowledge that saves tokens, remove anything that risks going stale. Covers react/fastapi/django/go/godot confs.
- **Added**: 2026-03-01

### T-0023: F-idea: Smarter memory-seed sync — memory-check.sh should: (1) fix worktree bug (resolve to main repo memory path, not worktree path), (2) when stale, generate a precise diff showing what changed between memory version and current seed (not just 'go re-read the file'), (3) output structured instructions the LLM can apply as targeted patches. Script prepares the changes, LLM merges them (preserving project-specific memory). Reduces behavioral burden from 'read 115 lines and figure it out' to 'apply these 3 specific changes'.
- **Added**: 2026-03-01

### T-0025: F-idea: NFRs as live invariants — NFR.md should be the source of truth that propagates to features, not a dead reference. Key changes: (1) Acceptance criteria should have a separate 'Invariants (from NFR.md)' section auto-derived from NFR scoping, distinct from feature-specific criteria. (2) Test-writing workflow should check applicable NFRs before writing feature tests. (3) check-spec-health.sh should cross-reference NFR modification dates vs feature spec dates — if NFR changed after spec was written and feature references it, flag for review. (4) NFR capture trigger: when a developer or agent expresses an invariant quality for the system ("it must always...", "never do X", performance/security/reliability constraints), recognize it and write it to spec/NFR.md — don't let invariants stay informal. (5) Important distinction: framework NFR.md has 2 structural NFRs; projects using the framework may have dozens (performance, security, accessibility, compliance, etc.) — the workflow/tooling must scale to a longer list with mixed types (structural, behavioral, design invariants).
- **Added**: 2026-03-01

### T-0029: F-idea: Spec clarification taxonomy — resurface + enhance structured clarification in writing-specs skill. 6-category ambiguity taxonomy (functional, data model, edge cases, NFRs, integrations, completion signals), max 5 multiple-choice questions per spec, records [Clarified] markers. ~2K tokens/spec. Pre-existing framework idea resurfaced via SDD toolkit analysis (R1). Contributor: Tomas
- **Added**: 2026-03-02
- **Background**: `.agentic-journal/plans/2026-03-02-sdd-toolkit-analysis-plan.md` §3.1, §3.3, R1

### T-0032: F-0152 P2: Cross-feature semantic checks — three deferred checks for spec-analyze.sh: (AC-009) cross-feature terminology consistency (detects naming drift across spec files), (AC-010) AC contradiction detection (finds conflicting ACs within or across features), (AC-011) constitution alignment (checks ACs against PRINCIPLES.md). Requires LLM analysis — not deterministic. New insight from SDD toolkit analysis (their /analyze command's 6-pass approach). Contributor: Tomas
- **Added**: 2026-03-02
- **Background**: `.agentic-journal/plans/2026-03-02-sdd-toolkit-analysis-plan.md` §3.2, R2

### T-0038: PR2: Visual verification for tiered verify loop — screenshot collection, AI review in autonomous mode (F-0168, see plan in session transcript)
- **Added**: 2026-03-06

### T-0039: PR3: E2E scaffolding — discover.py detection, setup guide, testing contract, quality profiles (see plan in session transcript)
- **Added**: 2026-03-06

### T-0040: F-idea: Post-PR auto-review loop in autonomous mode — after creating a PR automatically, run a one-time review (code quality + conformance against plan and acceptance criteria). If the review causes changes, re-run the verification loop, then do one final review. Report the situation to the user after (at most 2 review passes to avoid infinite review→fix→review cycles). Fits into the autonomous workflow engine (F-030–F-0163) as a PR-quality gate.
- **Added**: 2026-03-06

### T-0041: F-idea: Auto-versioning and tagging — structural enforcement for VERSION bump + git tag after PR merge. Currently behavioral-only (instruction in committing-changes skill). Needs a hook or GitHub Action to make it impossible to forget. Options: post-merge git hook, GitHub Action on PR close, or pre-commit check that VERSION was bumped when on a feature branch.
- **Added**: 2026-03-06

### T-0043: F-idea: AC scheduling phase in auto engine — before executing ACs, analyze dependencies and priorities to build an execution graph. Independent ACs run in parallel (git worktree per stream), dependent ACs chain sequentially. Connects plan-level [P] markers (F-0148) to runtime execution. Resource-aware: premium mode enables parallelism, economy forces sequential. Supersedes T-0033 (which was investigation-only). See CONTRIBUTIONS.md 'Task Scheduling & Parallel Execution' and SDD analysis §9.
- **Added**: 2026-03-07

### T-0045: F-0193: Collision-proof feature IDs — current sequential F-XXXX IDs collide when multiple agents/branches assign independently. Research slug-based IDs, atomic allocation, or other approaches. See conversation notes on options.
- **Added**: 2026-03-08

### T-0050: Spec/backlog status drift: FEATURES.md status (planned/shipped) and BACKLOG.json can diverge. When discrepancy found, don't assume either is truth — check JOURNAL.md, CHANGELOG.md, and git history to determine actual state. Consider adding a drift-check tool.
- **Added**: 2026-03-09

### T-0052: F-idea: Systematic LLM-optimized format pass — convert remaining unstructured files to LLM-friendly formats (YAML frontmatter, structured markdown, consistent field patterns). Priority targets: acceptance criteria files (free-form → structured AC blocks), STATUS.md/JOURNAL.md (markdown → more parseable), STACK.md settings (grep-parsed → schema-validated YAML/TOML). Constraint: must remain human-readable — optimized for both audiences. See PRINCIPLES.md F3, KEY_INSIGHTS.md §12
- **Added**: 2026-03-11

### T-0053: F-idea: Migrate STACK.md to structured config format (YAML/TOML) with schema validation. Current grep/sed parsing is fragile and settings lack discoverability. New format should: (1) support inline comments documenting valid options for each setting (e.g. git_workflow: pull_request # options: pull_request | direct), (2) enable tab-completion or validation of setting values, (3) remain human-editable in any text editor, (4) preserve the single-file simplicity (no splitting into multiple configs). Related: T-0052 (LLM-optimized format pass), PRINCIPLES.md F3.
- **Added**: 2026-03-11

### T-0058: Investigation: F-0209 TDD Mode — can red-green-refactor loop be reliably enforced through skills/workflows, or is it too behavioral? Current tdd_mode.md exists but isn't wired. Need to test if agents actually follow test-first ordering when instructed.
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

### T-0086: Phase 3 spec protection audit: ~9 shipped features have ACs referencing deleted files, 0 spec migrations created for ~100 affected features. Context-for-role.sh silently drops constitutional rules. 4 ag commands degrade. 13 context manifests reference deleted files. See PR #182 (a22475e). Background: Phase 3 deleted ~130 files / 34K lines but validate_framework.sh v2 mode skips v1 checks, hiding the gaps. Affected features: F-0069 (all 7 checklists), F-008 (programming_standards), F-0012 (test_strategy), F-0013 (smoke_testing), F-0014 (library_selection), F-0074 (green_coding), F-0102 (modular guidelines), F-0055 (anti-hallucination), F-0093 (AGENT_QUICK_START). Functional issues: context-for-role.sh ALWAYS_INJECT references guidelines/core-rules.md (deleted), commit.sh/done.sh/implement.sh/specs.sh degrade to generic guidance when checklists missing. Either evolve shipped specs with migrations mapping old ACs to v2 equivalents, or deprecate features superseded by v2 engine.
- **Added**: 2026-03-21

### T-0087: AC check-off should happen with the code changes, not post-merge. Options: (1) In PR workflow: check off ACs in the PR itself (pre-merge), so reviewers see which ACs are satisfied. (2) In direct-commit mode: check off at commit time. Problem: feature numbering conflicts when multiple features develop simultaneously in PR mode — numbers could clash. But if work is planned well (backlog), numbers are assigned beforehand. Consider: assign F-XXXX at plan time (current behavior), check off ACs in the feature branch (not post-merge), and only bump VERSION post-merge. The post-merge AC check-off we do today is backwards — the evidence should travel with the code.
- **Added**: 2026-03-22

### T-0088: Scaffold should copy all Claude tool files (.claude/hooks.json, skills/, subagents/, CLAUDE.md) during scaffolding — BEFORE the agent session starts. Currently setup-agent.sh runs mid-session (called by scaffold.sh), but hooks only take effect on next session start. Fix: scaffold.sh should create .claude/ with hooks.json as part of the directory structure creation (alongside .agentic/), not as a separate setup-agent step. Then when the user starts their first Claude session, hooks are already in place. Remove the 'restart Claude' advisory. The init playbook phase can then remove/customize tool dirs the user doesn't need (e.g. if they only use Cursor, remove .claude/). This inverts the current flow: install everything → prune, instead of install nothing → add on request.
- **Added**: 2026-03-22

### T-0089: Investigate: custom feature prefixes and subproduct grouping. Can users define own prefixes (e.g., AUTH-001, PAY-002) or group features by subproduct within the same repo? Currently F-XXXX is hardcoded in ids.sh regex. Consider: prefix registry in STACK.md, multi-prefix support in is_feature_id(), FEATURES.md sections per subproduct, backlog filtering by prefix. Related: monorepo/multi-component support (F-0179 components).
- **Added**: 2026-03-23

### T-0090: Remove deadweight artifacts from work/ instructions — plan.md (and possibly spec.md, review.md, journal.md) in work/ are never read by CLI, state machine, or gate system; only tasks.yaml is functional. Remove from 'Write artifacts to .agentic/work/F-XXXX/' line in all instruction files (CLAUDE.md template+root, cursorrules, copilot, codex, memory-seed). Verify which work/ artifacts CLI actually reads vs which are purely behavioral. Background: investigated during F-0193 drift fix session. (Merged with T-0091)
- **Added**: 2026-03-23

### T-0092: Investigate autogenerated project-specific subagent roles for plan creation and review. Idea: based on STACK.md / project type, scaffold role personas (e.g. game project → game designer, graphics programmer, engine programmer; web app → UX expert, accessibility lead, backend architect). These roles would participate in plan dialectical review (alongside generic Critic/Advocate) and potentially review implementation PRs. Key questions: (1) how to derive roles from project context automatically, (2) whether roles are defined in STACK.md or inferred, (3) integration with existing Critic+Advocate review loop vs. replacing/extending it, (4) role-specific context loading via context-for-role.sh. Related: F-0246 (plan review), ag auto epic, coord start.
- **Added**: 2026-03-23

### T-0094: Investigate whether Claude Code emits PostToolUse events for built-in tools (ExitPlanMode, EnterPlanMode)
JSONL analysis of session `f85780c3` (2026-03-26) showed zero `PostToolUse:ExitPlanMode` progress entries after an ExitPlanMode tool call, while other PostToolUse hooks (Write, Grep, Read, Bash) fired normally in the same session. This means `on-plan-mode-exit.sh` — the hook designed to auto-save plans and inject review instructions — may have **never fired in production**. All correct plan-save + review behavior observed in sessions came from CLAUDE.md + memory textual instructions alone.
- **Background**: The hook is registered in `.claude/hooks.json` with `"matcher": "ExitPlanMode"` (line 44). The script at `.agentic/lib/hooks/shared/on-plan-mode-exit.sh` runs plan-scan, injects DRAFT status, and outputs a profile-aware banner with auto-continue instructions. All unit tests pass (`test_plan_review_hooks.sh`) but they test the script directly, not through Claude Code's hook dispatch.
- **Related**: INSTRUCTION_ARCHITECTURE.md assumption A11 (now INVALIDATED), FRAMEWORK_DEVELOPMENT.md "Push mechanisms need pull safety nets" section, F-004 (Plan & Design Review), F-0234 (plan review hooks)
- **Impact**: If confirmed, the entire "push" enforcement layer for plan review is inert. Only "pull" mechanisms work: `ag implement` gate 0d, SessionStart orphan detection, pre-commit Check 21.
- **Added**: 2026-03-26

### T-0095: Add review-evidence check to `ag implement` gate 0d
Currently `implement.sh` gate 0d checks only `**Status**: APPROVED` in the plan file. An agent can flip DRAFT→APPROVED without actually running the Critic/Advocate dialectical review. Approved plans that went through proper review contain structural evidence: `## Dialectical Review Findings`, `## Revision N Changes (from dialectical review)`, reviewer names, convergence signals. The gate should verify presence of at least one review-evidence section, not just the status line.
- **Background**: The three documented failure modes for plan review (FRAMEWORK_DEVELOPMENT.md:665-681) include "treat plan as pre-approved" — agent rationalizes "user approved in plan mode" and skips review. Named rationalizations in CLAUDE.md help but are textual. A structural check in the gate would make this bypass mechanically impossible.
- **Related**: F-004 (Plan & Design Review), `implement.sh` gate 0d (lines 143-175), `plan_convergence.py` (sets status + writes review sections), FRAMEWORK_DEVELOPMENT.md remaining gap #3
- **Files**: `.agentic/lib/tools/commands/implement.sh`, possibly `.agentic/lib/auto/plan_convergence.py` (to verify what sections it writes)
- **Added**: 2026-03-26

### T-0096: Add approved-plan-required check to PreToolUse gate for code edits
The PreToolUse gate (`gate.py` `gate_pretool`) blocks code edits without spec (F-0251) but does NOT check for plan approval. An agent can bypass `ag implement` entirely and start writing code directly — whether there's a DRAFT plan, or no plan at all. The PostToolUse `on-code-edit.sh` warns about DRAFT plans but is advisory (exit 0). Pre-commit Check 21 blocks commits with DRAFT plans but fires too late (code already written). Adding an approved-plan check to PreToolUse would create a hard block at the Write/Edit level — the agent literally cannot edit source files unless an APPROVED plan exists.
- **Background**: Discovered during 2026-03-26 analysis of plan-review enforcement chain. The ExitPlanMode hook may never fire (T-0094), `ag implement` gate 0d is the only hard block, but nothing forces agents to call `ag implement`. The enforcement chain has a gap between "plan mode exit" and "code written" that only advisory warnings cover. The check must be "APPROVED plan exists" not "DRAFT plan exists" — because no plan at all is equally invalid.
- **Related**: F-004 (Plan & Design Review), F-0251 (spec-first gate), `gate.py` `gate_pretool()` lines 666-720, `on-code-edit.sh` (advisory counterpart), FRAMEWORK_DEVELOPMENT.md remaining gap #4
- **Implementation**: In `gate_pretool()`, after the F-0251 check (line 697), add: if `plan_review_enabled=yes` AND `state_enforcement=blocking` AND NO plan has `**Status**: APPROVED` → deny with message directing agent to save plan + run review. Invert the logic of `check_pending_plan_review()` (gate.py:354): instead of "block if DRAFT exists", check "block unless APPROVED exists".
- **Added**: 2026-03-26

### T-0097: Spec auto-update enforcement gap — no gate checks that new code has corresponding contract updates. When code changes ship, nothing verifies that affected YAML contracts were updated. Background: commit 7e39ddb5 noted the gap during PR #232 (planned assertions surfacing). Related: ag contract check validates existing assertions but doesn't detect missing updates for changed code.
- **Added**: 2026-04-10

### T-0098: Test final round-trip
- **Added**: 2026-04-10

## Closed

### ~~T-0007: Batch-verify ~50 shipped features with unchecked ACs~~ **OBSOLETE**: Legacy v0.1–v0.12 era features. T-0051 now warns on in_progress features going forward. Retroactive verification has diminishing returns.
- **Added**: 2026-02-24 · **Closed**: 2026-03-11

### ~~T-0010: Implement multi-agent helper scripts (F-0108)~~ **OBSOLETE**: Fully superseded by AGENTS.json (F-0194) and agents_helpers.py. F-0108 marked deprecated in FEATURES.md.
- **Added**: 2026-02-24 · **Closed**: 2026-03-10

### ~~T-0013: Close or formally assess F-0103 (Agent Mode Selection)~~ **DONE**: F-0103 marked shipped. Heading-format ACs (pre-checkbox convention) verified manually.
- **Added**: 2026-02-28 · **Closed**: 2026-03-11

### ~~T-0014: Verify shipped acceptance criteria for F-0131, F-0132, F-0133, F-0134, F-0135~~ **OBSOLETE**: Legacy IDs consolidated into F-001/F-002/F-004/F-025/F-026 during F-005 renumber. ACs now YAML contracts.
- **Added**: 2026-02-28 · **Closed**: 2026-03-26

### ~~T-0015: Structural enforcement for durable plan saving~~ **DONE**: Core covered by F-0198 (plan-scan.sh in ag sync auto-copies plans) + ag implement already checks plan file existence. The `plan_persistence` setting is a nice-to-have, not urgent.
- **Added**: 2026-02-28 · **Closed**: 2026-03-11

### ~~T-0016: Worktree auto-detection~~ **OBSOLETE**: Duplicate of T-0046; core shipped in F-0194 (ag implement auto-creates worktree, worktree_mode setting).
- **Added**: 2026-02-28 · **Closed**: 2026-03-10

### ~~T-0017: AGENTS_ACTIVE.md is never written~~ **CLOSED** (F-0197): Superseded by AGENTS.json (F-0194). F-0033 deprecated.
- **Added**: 2026-02-28 · **Closed**: 2026-03-10

### ~~T-0018: Remove legacy .agentic-journal/manifests/~~ **DONE**: Moved F-018.json and F-0186.json to canonical .agentic/journal/manifests/. Removed legacy .agentic/.agentic-journal/ directory.
- **Added**: 2026-02-28 · **Closed**: 2026-03-11

### ~~T-0028: Migrate .agentic-journal/ and .agentic-state/ into .agentic-local/ umbrella~~ **OBSOLETE**: Both directories already migrated — .agentic-journal/ → .agentic/journal/ (T-0018), .agentic-state/ → .agentic/session/ (F-0194). Backward-compat fallbacks in paths.sh. No .agentic-local/ umbrella needed.
- **Added**: 2026-03-02 · **Closed**: 2026-03-11

### ~~T-0030: Verification loop~~ **DONE**: Shipped as F-0161 (Tiered Test Execution) + F-0164 (Verify Loop). Bounded test→fix→retest with tiered execution, escalation on exhaustion, diagnostic context. 100% complete.
- **Added**: 2026-03-02 · **Closed**: 2026-03-10

### ~~T-0031: Auto-dev loop~~ **DONE**: Shipped as F-030–F-0163 (Autonomous Workflow Engine) + F-0186 (Autonomous Scheduler). Full spec→feature chain exists (TaskRunner reads spec → loops ACs → verify → PR). Deliberately not self-activated in framework dev (by design). ~90% complete, closed.
- **Added**: 2026-03-02 · **Closed**: 2026-03-10

### ~~T-0033: Task IDs and execution prioritization~~ **OBSOLETE**: Superseded by T-0043 (AC scheduling phase) which covers the same ground more concretely with AC-level dependency graphs and parallel execution.
- **Added**: 2026-03-02 · **Closed**: 2026-03-10

### ~~T-0034: Cursor agent leaves work uncommitted~~ **DONE**: Added commit nudge in ag.sh cmd_done(), completing-work skill Step 0, and cursorrules.txt "done" trigger.
- **Added**: 2026-03-03 · **Closed**: 2026-03-11

### ~~T-0042: Multi-tool auto modes~~ **OBSOLETE**: Overly broad. Per-tool support should be scoped individually when needed, not as a single abstraction task.
- **Added**: 2026-03-06 · **Closed**: 2026-03-11

### ~~T-0044: Post-merge dogfooding workflow~~ **DONE**: Shipped as F-0226, consolidated into DEV-003 during F-005 renumber.
- **Added**: 2026-03-08 · **Closed**: 2026-03-26

### ~~T-0046: Worktree-by-default for feature branches~~ **DONE**: Shipped as F-0194. `worktree_mode: always` in STACK.md, `ag implement` auto-creates worktrees, `ag done` auto-cleans.
- **Added**: 2026-03-08 · **Closed**: 2026-03-11

### ~~T-0048: Plan file advisory in ag review~~ **DONE**: Added _check_plan_file() in review.py resolve path. Advisory prints when no durable plan found. Complements T-0047 (ag implement gate).
- **Added**: 2026-03-09 · **Closed**: 2026-03-11

### ~~T-0049: Dashboard after ag done~~ **DONE**: Added dashboard.sh call at end of cmd_done(), conditional on interactive terminal ([ -t 1 ]), non-blocking.
- **Added**: 2026-03-09 · **Closed**: 2026-03-11

### ~~T-0051: AC check-offs must be part of the implementation PR~~ **DONE**: Shipped as advisory pre-commit check. Warns when in_progress features have unchecked ACs. 10 bash tests.
- **Added**: 2026-03-10 · **Closed**: 2026-03-11

### ~~T-0055: manifest.sh hardcodes legacy .agentic-journal path~~ **DONE**: Replaced hardcoded `$PROJECT_ROOT/.agentic-journal` with `$MANIFESTS_DIR` from paths.sh.
- **Added**: 2026-03-11 · **Closed**: 2026-03-11

### ~~T-0056: Plan file naming regression~~ **DONE**: Fixed. `plan-scan.sh` line 218 now uses `$(date +%Y-%m-%d)-${primary_id}-plan.md`.
- **Added**: 2026-03-11 · **Closed**: 2026-03-26

### ~~T-0059: Configurable DoD per task type~~ **DUPLICATE**: Duplicate of backlog item "Configurable Definition of Done per task type" (task on F-002).
- **Added**: 2026-03-11 · **Closed**: 2026-03-26

### ~~T-0066: Support for protected main branch~~ **PROMOTED**: Design notes moved to backlog F-035.
- **Added**: 2026-03-13 · **Closed**: 2026-03-26

### ~~T-0071: DONE — PreToolUse(Write|Edit) artifact enforcement implemented (Phase 4 completion, 2026-03-21)~~
- **Added**: 2026-03-17 · **Completed**: 2026-03-21
- **Resolution**: Implemented as `.agentic/lib/claude-hooks/PreToolUse.sh` — blocks Write/Edit/MultiEdit when v2 engine is active and required artifacts are missing. Uses `ag check --quick --active` for <500ms checks, returns `permissionDecision: "deny"` to block. Allows edits to framework/config/state files (.agentic/*, tests/*, docs/*, *.md, etc.).

### ~~T-0091: Investigate deadweight artifacts in work/~~ **MERGED**: Merged into T-0090.
- **Added**: 2026-03-23 · **Closed**: 2026-03-26

### T-0082: validate_framework.sh check: shipped features must appear in CHANGELOG and at least one living doc
- **Resolved**: 2026-03-20

### T-0079: Structural gate for project-wide documentation currency at feature completion
- **Resolved**: 2026-03-20

### T-0081: Build session log analysis tool (session-analyze.py)
- **Resolved**: 2026-03-20

### T-0080: Optimize memory-seed.md from 320→~200 lines using LLM-directive format
- **Resolved**: 2026-03-20

### T-0057: manifest.sh regenerates on every dashboard/status call, creating dirty working tree noise
- **Resolved**: 2026-03-11

### T-0054: Agent forgets doc updates and LLM test checks during feature implementation
- **Resolved**: 2026-03-11

### T-0047: ag implement: gate on durable plan file
- **Resolved**: 2026-03-10

### T-0024: Consider relaxing max_staged_files for PR workflow
- **Resolved**: 2026-03-06

### T-0027: Revisit D4: phased checkpoints vs file-count limits as small-batch proxy
- **Resolved**: 2026-03-06

### T-0037: Session start: add 'untracked shipped features?' check
- **Resolved**: 2026-03-03

### T-0036: SKIP_COMPLEXITY expiry/escalation
- **Resolved**: 2026-03-03

### T-0035: Unregistered shipped code detector
- **Resolved**: 2026-03-03

### T-0026: Auto-resolve HUMAN_NEEDED PR entries
- **Resolved**: 2026-03-01

### T-0012: Update FEATURES.md status: F-0136, F-0139, F-0140, F-0141
- **Resolved**: 2026-03-01

### T-0020: LLM tests for F-0143 Skills
- **Resolved**: 2026-03-01

### T-0019: LLM test gap: verify trigger compliance with 40-line CLAUDE.md template
- **Resolved**: 2026-03-01

### T-0005: Migrate Python tools from read_profile() to get_setting()
- **Resolved**: 2026-02-24

### T-0011: Automatic git tag after PR merge
- **Resolved**: 2026-02-24

### T-0004: Fix blocker.sh double-write bug in add command
- **Resolved**: 2026-02-24

### T-0006: Clean up HUMAN_NEEDED.md resolved items
- **Resolved**: 2026-02-24

### T-0008: Remove Cursor prompt stubs referencing nonexistent upgrade_profile.sh
- **Resolved**: 2026-02-24

### T-0009: Fix README.md:512 template placeholder
- **Resolved**: 2026-02-24
