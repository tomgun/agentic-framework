# Changelog

All notable changes to the Agentic AI Framework will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.48.0] - 2026-03-08

### Added
- **Component Registry (F-0179, ADR-001 Phase 2)** — Optional `## Components` table in STACK.md for multi-component/monorepo projects. `components.py` with Component dataclass, ComponentRegistry (get, list, reverse path lookup, validation), markdown table parsing, and monorepo auto-detection. Scoped context via `context-for-role.sh --component`. `query_features.py --component` filter. Component-aware gate advisory in `implementing → verified` transition. 25 new tests.

## [0.47.0] - 2026-03-08

### Added
- **Formal Feature State Machine (F-0177)** — 9-state feature lifecycle per ADR-001 Section 5: `planned → specced → criteria_set → tests_written → implementing → verified → documented → committed → shipped` (+ `deprecated` terminal). `state_machine.py` with FeatureState enum, transition tables (forward/regression/skip), advisory/enforce modes, cascade invalidations, CLI interface. `gates.py` with 8 filesystem-based gate functions for transition preconditions.
- **State Machine Blast Radius Update (F-0178)** — All 22 downstream tools updated for 9-state lifecycle: validate_formats, doctor, feature.sh, query_features, feature_stats, feature_graph, consistency, crunch, ag.sh, pre-commit-check, checklists, templates, spec schemas. `ag transition` CLI command.
- **ADR-001** — Multi-component architecture decision record (7 sections) covering state machine design, component model, epic decomposition, and autonomous workflow vision.
- 42 state machine tests, 23 gate tests, 12 crunch tests updated. Framework validation: 507/507 pass.

### Fixed
- `validate_framework.sh`: remove `set -e` that silently crashed script mid-run, fix `((count++))` under `set -e`, fix settings test `_reset_settings_cache`
- `nfr.sh`: awk regex using unsupported `{4}` quantifier
- `STACK.template.md`: stale commented `retrospective_enabled` config
- `validate_specs.py`: graceful exit when pyyaml is not installed

## [0.45.0] - 2026-03-07

### Added
- **Visual Verification (F-0168)** — Screenshot collection from E2E test tiers and AI-powered visual review. `TestTier.screenshot_dir` and `TierResult.screenshots` fields. Parses `E2E screenshots:` from STACK.md. `--visual` flag on verify.py, task.py, engine.py triggers Anthropic API multimodal review. Graceful degradation (no SDK/key = warning + skip). Visual concerns are advisory only (never block). New `VisualReviewResult` dataclass with full serialization.
- **E2E Scaffolding** — `_detect_e2e_framework()` in discover.py detects Playwright, Cypress, Detox, WebdriverIO from config files and package.json. E2E testing contract doc, setup guide, and `webapp_with_e2e.sh` quality profile. STACK.template.md gains `E2E screenshots:` config line.
- 42 new tests in `test_auto_visual.py` (screenshot collection, parsing, visual review, E2E detection).

## [0.44.2] - 2026-03-06

### Changed
- **Advisory batch-size limits on feature branches** — `max_files_per_commit` and `max_added_lines` downgraded to warnings (not blocking) when on feature branches with PR workflow. Keeps blocking on main/master.

## [0.44.0] - 2026-03-06

### Added
- **Tiered Verify Loop (F-0164)** — Multi-tier test execution (unit → integration → e2e) with per-tier fix loops, timeouts, and continue-on-failure settings. Parsed from STACK.md `Test commands:` section.
- **Autonomous Workflow Engine (F-0160–F-0163)** — `ag auto verify`, `ag auto task F-XXXX`, `ag auto crunch` modes with control socket, tiered permissions, and complexity estimation.

## [0.43.0] - 2026-03-06

### Added
- **Autonomous Engine Foundation (F-0160)** — Control plane with Unix domain socket for bidirectional commands (pause/resume/stop/feedback/status), thread-safe engine state with `threading.Lock`, settings.json generation from STACK.md (three-tier trust model: Docker sandbox, scoped permissions, interactive), AC loading/decomposition with complexity estimation, atomic JSON state persistence, signal handling (SIGTERM/SIGINT) and atexit cleanup.
- **Autonomous Verify Mode (F-0161)** — Test-fix loop (`ag auto verify`). Detects test runner from STACK.md or project files (pytest, Jest, Go, Cargo), spawns fresh Claude instances to fix failures, re-runs until green or max iterations. Configurable `--max-iterations`, `--test-command`, `--json` output.
- **Autonomous Task Mode (F-0162)** — Single-feature implementation (`ag auto task F-XXXX`). Reads acceptance criteria, creates feature branch, spawns Claude per AC, runs tests, commits passing work, runs full verify loop, creates PR for human review. User feedback via `ag auto feedback` incorporated into next Claude instance.
- **Autonomous Crunch Mode (F-0163)** — Multi-feature batch (`ag auto crunch`). Reads planned/in-progress features from FEATURES.md, processes each via task mode, stops on max errors threshold or human `ag auto stop`, saves progress to dashboard state file.
- **`ag auto` CLI** — New subcommands: `init`, `verify`, `task`, `crunch`, `status`, `pause`, `resume`, `stop`, `feedback`.
- 75 Python unit tests across 4 test files, 60+ validation checks, 5 LLM behavioral tests (070–074).

## [0.42.0] - 2026-03-06

### Added
- **`.agentic/` directory restructure (v0.41.0)** — `lib/` separation, tarball distribution, path resolution.

## [0.40.0] - 2026-03-03

### Added
- **SKIP_COMPLEXITY Per-File Warnings (F-0154)** — When `SKIP_COMPLEXITY` is set, pre-commit now shows per-file details (filename, line count, limit) instead of silent skip. Agents see exactly which files are over-limit and by how much.
- **Unregistered Shipped Code Detection (F-0155)** — New sync.sh phase 3b detects commits without `F-####` references that touch 3+ source files with 1+ new file. Flags possible unregistered features. Active when `feature_tracking=yes`. Runs in both quiet (ag start) and full sync modes.
- **Session Start Spec Drift Surfacing (F-0156)** — Unregistered code detection feeds into `ag start` sync probe via quiet mode. Falls out of F-0155 architecture.
- 8 new unit tests (`test_unregistered_features.sh`), 5 validation checks (372 total).

## [0.39.0] - 2026-03-02

### Added
- **Spec Format Evolution (F-0148)** — Acceptance template gains `## Behavior` section, priority tags (`<!-- P1 -->` / `<!-- P2 -->`), `## Verification` heading. `verify-independently` marker for reviewable ACs.
- **Spec Clarification Taxonomy (F-0149)** — Writing-specs skill includes 6-category structured clarification (functional scope, data model, edge cases, NFRs, integrations, completion signals). Max 5 targeted questions per spec.
- **Execution Order & Checkpoints (F-0150)** — Plan template includes `## Execution Order` with `[P]` parallel markers. Implementing-features skill gains scope-check + checkpoint validation at P1/P2 boundaries.
- **User-Extension Directory (F-0151)** — `.agentic-local/extensions/` for custom skills, gates, hooks, and rules that survive framework upgrades. Integrated with `scaffold.sh`, `generate-skills.sh`, `pre-commit-check.sh`, and `upgrade.sh`.
- **Semantic Consistency Analysis (F-0152)** — `spec-analyze.sh` runs 3 deterministic checks: ambiguity detection (vague adjectives without metrics), AC↔test coverage gaps (via coverage.py), NFR measurability audit. Advisory only (exit 0 always). New `spec_analysis` setting (on for formal, off for discovery).
- **AC-Level Coverage Tracking (F-0153)** — `coverage.py --ac-coverage F-XXXX` maps individual ACs to tests via naming conventions with proximity-based matching. Human-readable + JSON output. Standalone or integrated with spec-analyze.sh.
- **LLM-069** — New behavioral test: spec analysis advisory before implementation.

## [0.36.0] - 2026-03-01

### Added
- **Spec-Writing Workflow (F-0147)** — Canonical workflow with five protection levels (draft → planned → in-progress → shipped → retired), NFR integration, delta tracking via migrations, and shipped-spec enforcement. `ag spec` command, `check-spec-health.sh`, and `writing-specs` Claude Skill with spec_writing, spec_evolution, and spec_protection references.
- **Pre-commit checks 14-16** — Block modifications to shipped acceptance criteria without migration, block deletion of shipped test files, block status downgrades. No escape hatch.
- **Plan-review gate** — Gate 4 in `check-gates.sh` requires approved plan when `plan_review_enabled=yes`.

## [0.35.0] - 2026-03-01

### Added
- **Periodic Check System (F-0145)** — `periodic-checks.sh` with frequency-gated checks (every_session, every_N_sessions, off), session counter, state persistence in `.agentic-state/sync-state.conf`. Includes orphaned plan detection and retro-due migration from session_start.md.
- **Project-Specific Agent Generation (F-0146)** — `generate-project-agents.sh` detects project stack from STACK.md + file presence + package deps, applies specialization rules (`.agentic/agents/specialization/*.conf`) to generate project-specific agents. Skills integration via `<!-- PROJECT-RULES -->` markers. CLI: `ag agents generate|list|clean`.
- **Post-F-0143 documentation sync** — Updated DEVELOPER_GUIDE, README, INSTRUCTION_ARCHITECTURE, and other docs for skills-primary architecture.

## [0.34.0] - 2026-02-28

### Added
- **Skills-Primary Architecture (F-0143)** — 12 hand-crafted Claude Skills replace 10 auto-generated stubs. Skills are now the primary workflow delivery mechanism for Claude Code, with SKILL.md instructions, scripts/ gates, and references/ playbook copies.
- **YAML frontmatter on 79 files** — All playbook, checklist, workflow, guideline, quality, and subagent files now have machine-parseable frontmatter (summary, trigger, tokens). Enables ~50x discovery savings (scan ~50-token summaries vs load ~2500-token full files).
- **`validate_skills.sh`** — Validates Anthropic spec compliance (name length, description, no XML, word count) for all 12 skills.
- **`generate-skills.sh` rewrite** — Copies hand-crafted skill sources from `.agentic/agents/claude/skills/`, injects VERSION, assembles references. Replaces old auto-generation from subagent definitions.

### Changed
- **CLAUDE.md thinned** — Template reduced from ~79 to ~40 lines; trigger table moved to Skills for Claude Code. Other tools retain trigger tables in their instruction files.
- **Skills source directory** — Moved from auto-generated (from `.agentic/agents/claude/subagents/`) to hand-crafted sources in `.agentic/agents/claude/skills/`.

## [0.33.0] - 2026-02-24

### Added
- **Explicit Settings in STACK.md (F-0141)** — Settings section with typed key-value pairs, `ag set` command for validated changes.
- **Self-Healing Hooks + Plan Auto-Save (F-0142)** — Plan-mode-exit auto-saves to `.agentic-journal/plans/`, test co-presence check for acceptance criteria.
- **DRY State-File Config** — `upgrade.sh` instruction regeneration + state file creation from STACK.md settings.

### Fixed
- **upgrade.sh BSD sed settings bug** — Legacy migrations for BSD compatibility.
- **Concatenated settings** — Template-format Settings section repair.
- **TODO audit cleanup** — blocker.sh, HUMAN_NEEDED, stale prompts.
- **Doc enforcement gaps** — Retired stale.sh, added staleness check to sync.sh.

## [0.31.0] - 2026-02-20

### Added
- **Proactive WIP Creation (F-0140)** — Plan-mode-exit trigger now chains to `ag implement` (creates WIP) across all 5 instruction files. Fixes real-world issue where agents lost work after token limit crash because WIP was never created.
- **S10 structural test** — Verifies all instruction files reference both WIP check (session start) and WIP creation (work start). 15 checks.
- **L07 LLM behavioral test** — Verifies agent mentions `ag implement`/WIP after plan-mode-exit, doesn't jump to code.
- **14 acceptance checks** in `validate_framework.sh` for F-0140.

### Fixed
- **doctor.py WIP path bug** — Was checking `.agentic/WIP.md` instead of `.agentic-state/WIP.md` in implement phase.

### Changed
- **Build trigger** annotated with `(creates WIP)` in all instruction files.
- **Memory seed** updated with WIP creation steps in both "build" and "plan-mode-exit" sections.
- **Checklists** — `feature_start.md` and `feature_implementation.md` reference WIP tracking.

## [0.30.0] - 2026-02-19

### Added
- **Doc Lifecycle System (F-0139)** — Systematic doc drafting wired into `ag done` and `ag docs`. Two-layer architecture: project doc registry in `STACK.md ## Docs` (survives `.agentic/` upgrades), framework machinery in `.agentic/tools/docs.sh` (context assembler + trigger dispatcher).
- **8 built-in doc types** — changelog, readme, lessons, architecture, adr, runbook, tech-spec, custom. Each with write strategy (prepend/append/append-section/new-file) and type guidance in `.agentic/agents/shared/doc_types.md`.
- **4 trigger types** — `feature_done` (fires at `ag done`), `pr` (formal profile only), `session` (staleness check in `ag sync`), `manual`.
- **`ag docs` command** — `ag docs F-####`, `ag docs --list`, `ag docs --check`, `ag docs --pr`.
- **Doc staleness check** — `ag sync` now checks registered docs for staleness (configurable via `docs_stale_days` in STACK.md, default: 30 days).
- **Documentation agent dual-mode** — Structured registry mode (when `docs.sh` context provided) + existing autonomous discovery mode (standalone invocation).
- **2 new LLM behavioral tests** (LLM-064, LLM-065) — doc registry awareness and doc lifecycle at feature completion.

### Changed
- **`auto_orchestration.md`** — Added step 8 "DOC LIFECYCLE" to feature pipeline (between UPDATE DOCS and BEFORE COMMIT).
- **`STACK.template.md`** — Added `## Docs` section with commented-out entries for new projects.

## [0.29.0] - 2026-02-19

### Added
- **Documentation Impact Tracking (F-0138)** — `drift.sh --docs --manifest F-####` wired into `ag done` with `docs_gate` setting (`off` | `warning` | `blocking`). Machine-detects which existing docs reference changed code. Formal profile defaults to `blocking`; Discovery defaults to `off`.
- **`## Documentation` section in CONTEXT_PACK.md template** — agents know what docs exist in a project at session start. Framework's own CONTEXT_PACK.md populated with 8 entries.
- **`acceptance.template.md`** — the template `ag implement` referenced but didn't exist. Has `## Tests` section as a first-class section before acceptance criteria, forcing test planning before coding.
- **2 new LLM behavioral tests** (LLM-062, LLM-063) — doc update process and `docs_gate` awareness.

### Changed
- **Documentation agent** — replaced generic guidance with concrete process: read CONTEXT_PACK.md `## Documentation` → run `drift.sh` → update flagged docs + add new sections for user-facing changes.
- **`auto_orchestration.md` TEST step** — now points to `## Tests` in acceptance criteria rather than giving generic advice. Applies to all projects.
- **`feature_start.md` Gate 1** — now checks for a `## Tests` section in acceptance criteria. An acceptance file without tests is explicitly incomplete.
- **`spec/acceptance/README.template.md`** — documents `## Tests` as a required section for all acceptance files.
- **`docs_gate`** added to `profiles.conf` (discovery=off, formal=blocking), `STACK.template.md`, `auto_orchestration.md` gates table, and `ag set` enum validation.
- **`FRAMEWORK_DEVELOPMENT.md`** — "Adding a new framework feature" now lists structural tests (`validate_framework.sh`) and LLM behavioral tests (`test_definitions.json`) as explicit required steps.

### Fixed
- **VERSION / STACK.md** — corrected stale `0.27.2` to `0.29.0` (two releases behind).

## [0.28.1] - 2026-02-19

### Changed
- **Documentation deduplication** — Established document ownership model: each piece of content lives in ONE canonical file, others cross-reference. Removed ~687 lines of duplication across 5 docs.
- **USER_WORKFLOWS.md retired** — Replaced 547-line file with redirect stub to DEVELOPER_GUIDE.md. Unique content (Accepting a Feature, Common Questions FAQ) migrated first.
- **DEVELOPER_GUIDE.md** — Added "Accepting a Feature" section (§Daily Workflows) and "Common Questions" FAQ (§Troubleshooting). Removed Quick Information Retrieval and Finding Information subsections (duplicated MANUAL_OPERATIONS.md).
- **START_HERE.md** — Common Issues condensed to table + link. Quick Command Reference replaced with cross-refs only. USER_WORKFLOWS ref updated.
- **README.md** — Tools section compressed to categories + link. Troubleshooting replaced with pointer. USER_WORKFLOWS ref updated.
- **MANUAL_OPERATIONS.md** — Script list slimmed to top 3 + cross-ref to DEVELOPER_GUIDE.

### Fixed
- **Stale version numbers** — Replaced hardcoded `v0.19.0` (README.md, MANUAL_OPERATIONS.md) and `v0.13.0`/`v0.12.0` (START_HERE.md) with `<VERSION>` placeholder.

## [0.28.0] - 2026-02-18

### Added
- **Centralized TODO tracking (F-0136)** — `TODO.md` as a durable, git-tracked inbox for ideas, tasks, and reminders. `todo.sh` provides CRUD operations (add/done/drop/triage/list) following the `blocker.sh` pattern with single-write insertion (no double-write bug). `ag todo` command for quick capture.
- **Routing rules** — All instruction files and memory-seed now include a decision table: task/idea → `ag todo`, human blocker → `blocker.sh`, bug → `quick_issue.sh`, capability → `feature.sh`. Prevents agents from dumping development tasks into HUMAN_NEEDED.md.
- **Session lifecycle integration** — `ag start` shows TODO inbox count; session-end checklist includes TaskList→TODO.md flush step.
- **S07 structural test** — 7th trigger check (todo/idea → ag todo) and 5th script reference (todo.sh) in memory-seed ↔ CLAUDE.md consistency test.

### Changed
- **STATUS.md** — Backlog section removed (replaced by TODO.md inbox). "Next up" remains as curated session priorities.
- **scaffold.sh** — TODO.md created for both Discovery and Formal profiles during project initialization.
- **ag.sh** — Fixed HUMAN_NEEDED blocker count bug in `cmd_start()` (`^## HN-` → `^### HN-`).
- **memory-seed** — Bumped to v0.28.0, added `ag todo` sentinel, routing rules section, todo.sh script reference.

## [0.27.2] - 2026-02-18

### Added
- **NFR content validation** — `validate_nfr_content()` in `nfr_validator.py` validates NFR.md fields: categories against schema enum, status enum values, test file path existence, placeholder detection. State-machine parser handles nested "Where enforced" structure.
- **nfr.sh** — Token-efficient script for NFR status updates (`list`, `show`, `status` commands).
- **Framework dogfooding NFRs** — `spec/NFR.md` with 2 real NFRs (instruction file size limit, token budget compliance).
- **16 pytest tests** — NFR validation coverage including parser, validators, edge cases, and framework dogfooding.

### Changed
- **doctor.py** — Now calls `validate_nfr_content()` alongside existing `validate_nfr_refs()` in feature-tracking validation block.
- **nfr.schema.json** — Added `$comment` noting markdown/schema format mismatch (tech debt).
- **DEVELOPER_GUIDE.md** — Added nfr.sh to scripts listing, NFR content validation to doctor.sh --full description.

## [0.27.1] - 2026-02-18

### Changed
- **DEVELOPER_GUIDE.md rewrite (F-0134)** — Chat-first framing: users talk to the agent, scripts work behind the scenes. Removed "you're the quality gate" framing, rewrote all user-instruction examples as natural language prompts, added "Why Scripts Exist" section explaining the 3 reasons (agent uses them, transparency, escape hatch). Stale install URLs replaced with `v<VERSION>` placeholders. Pre-commit hook docs updated to `ag hooks install`. Version footer updated.
- **FEATURES.md** — F-0132 and F-0133 marked shipped (v0.27.0). Summary table corrected (97 shipped, 3 in-progress, 2 planned, 103 total).

## [0.27.0] - 2026-02-16

### Added
- **Settings-over-profiles architecture (F-0131)** — Profiles become presets; all framework logic uses `get_setting()` with three-level resolution (explicit > profile preset > fallback default). New `ag set` command for individual overrides. Shared libraries: `.agentic/lib/settings.sh` + `.agentic/lib/settings.py`.
- **Programmatic spec-first gate (F-0132)** — `ag plan F-XXXX` blocks if F-XXXX not in FEATURES.md. `ag implement F-XXXX` blocks if no FEATURES.md entry or no `spec/acceptance/F-XXXX.md`. `SKIP_SPEC_CHECK=1` escape hatch.
- **Durable plan artifacts (F-0133)** — `ag plan --save <source-file> F-XXXX` saves plans to `.agentic-journal/plans/`. CLAUDE.md instructs agents to save plans after approval.
- **Skill routing hints** — CLAUDE.md template documents that framework roles (`/review`, `/test`, etc.) use Skill tool, NOT Task tool's subagent_type.
- **Review-after-PR suggestion** — PR creation rule in CLAUDE.md now includes: "then offer: Want me to run `/review` on this PR?"
- **Profile presets file** — `.agentic/presets/profiles.conf` and `.agentic/presets/constraints.conf` define profile defaults and inter-setting constraints.

### Changed
- **All 18 files with profile logic** — Converted from `if profile == "formal"` to `get_setting` calls. 5 duplicate `get_profile()`/`read_profile()` implementations replaced by shared library imports.
- **STACK.md** — Settings consolidated under `## Settings` section with section-scoped parsing.
- **Pre-commit-check.sh** — Check 5/7 thresholds now derived from settings, not hardcoded.
- **enable-formal.sh** → now calls `ag set profile formal` + creates spec directory.

### Removed
- **Duplicate `get_profile()` / `read_profile()` functions** — Removed from ag.sh, sync.sh, phase_detect.py, doctor.py, verify.py. All use shared `get_setting()`.

## [0.26.0] - 2026-02-15

### Changed
- **Profile rename** — `core` → `discovery`, `core+product` → `formal` across all files. Backward compatibility normalization removed — clean break.
- **enable-pm.sh** → **enable-formal.sh** — Script renamed to match new profile name.
- **All profile references updated** — 18+ files: scripts, templates, documentation, tests, agent instructions.

## [0.25.8] - 2026-02-14

### Added
- **Rough specs & structural nudging (F-0130)** — Core profile gets non-blocking reminders for success criteria: pre-commit checklist, improved `ag work` tip, Success Criteria section in WIP.md templates.
- **Spec evolution surfacing (F-0130)** — `ag done` shows `[Discovered]` marker count and prompts spec review. `ag sync` nudges when in_progress features lack acceptance files.
- **"Starting rough is OK" guidance** — Added to PRINCIPLES.md D4 and spec_evolution.md.

### Removed
- **`## Project Phase` from STATUS.template.md** — Dead code; Profile (Core vs Core+PM) handles spec rigor. All references cleaned from Stop.sh, upgrade.sh, session-start.sh, ag.sh.

## [0.25.6] - 2026-02-12

### Added
- **Git hook enforcement (F-0129)** — Pre-commit dispatcher with CI detection, STACK.md config routing (`pre_commit_hook: fast|full|no`), and `core.hooksPath` wiring. Hooks now fire on every `git commit`.
- **`ag hooks` command** — `install`, `status`, `disable --confirm` for manual hook management.
- **sync.sh Phase 6** — Git hook configuration check with auto-fix in full mode.
- **`ag start` hook warning** — Dashboard warns when hooks are not configured.

### Changed
- **`ag plan` gate** — Loosened from hard block to advisory when acceptance criteria missing. `ag implement` retains independent hard block.
- **pre-commit-check.sh** — Added `--mode fast|full` flag. Fast mode keeps structural blocking checks (1,2,3,3b,3c,7,11), skips slow/advisory checks (4,5,6,8,9,10,12).
- **scaffold.sh** — Uses `git config core.hooksPath .agentic/hooks` instead of file-copy installation. Both profiles get hooks.
- **STACK.template.md** — Uncommented `pre_commit_hook: fast` (was `<!-- yes -->`).
- **upgrade.sh** — Configures `core.hooksPath`, cleans stale `.git/hooks/pre-commit`, migrates `yes` → `fast`.
- **status.sh** — Timestamps now include timezone (e.g., `2026-02-12 13:30 EET`).

## [0.25.5] - 2026-02-12

### Added
- **Specs-before-code structural enforcement (F-0128)** — `ag implement` and `ag plan` block if acceptance criteria don't exist. Enforcement gap audit identified 20 gaps.

## [0.25.4] - 2026-02-11

### Added
- **`ag sync` command** — Unified drift detection across 5 phases (memory, state freshness, features, spec/doc drift, tool parity) with `--check` (dry run) and `--quiet` (probe) modes.
- **Discoverability reminders** — `ag start` shows "Available workflows" line and sync probe when issues detected.
- **Tip of the day** — Random framework tip in session dashboard (10 tips).

## [0.25.3] - 2026-02-11

### Changed
- **memory-seed.md** — Rewritten from documentation style to imperative trigger→action format. Rules framed as "when condition → execute command", not reference material.
- **All 7 trigger tables** (CLAUDE.md, copilot, codex, cursor × template + root) — "Trigger" column → "User intent" with broader synonym matching. Header: "match on intent, not just exact words."
- **CLAUDE.md** (template + root) — Added explicit "check your memory at session start" instruction with re-read directive if stale.

## [0.25.2] - 2026-02-11

### Added
- **Memory integrity check** — `memory-check.sh` validates Claude Code auto-memory contains expected framework patterns at session start. Advisory only (never blocking). Checks: never seeded, stale version, partially overwritten (sentinel-based heuristic).
- **Defense-in-Depth section in INSTRUCTION_ARCHITECTURE.md** — Documents the memory-seed layer, compression problem, tool memory landscape table (Claude Code, Cursor, Windsurf, Copilot, Codex), and why memory is reinforcement not enforcement.
- **Instruction architecture section in CONTEXT_PACK.md** — Three-layer model, distributed enforcement, defense-in-depth summary for session-start context.
- **Memory Seed Maintenance section in FRAMEWORK_DEVELOPMENT.md** — When/how to update memory-seed.md, sentinel alignment, version bump discipline.
- **Memory integrity step in session_start.md** — Checklist step with manual remediation instructions.
- **Sentinels documentation comment in memory-seed.md** — `<!-- sentinels: ... -->` for maintainer reference.

### Changed
- **ag.sh** — `cmd_start()` now runs `memory-check.sh --quiet` after WIP check.
- **CONTEXT_PACK.md** — Fixed stale counters (features 70→100+, tests 104+→180+).
- **INSTRUCTION_ARCHITECTURE.md** — Fixed stale LLM test count (23→48+).

## [0.25.0] - 2026-02-10

### Added
- **Domain categories for features** — `detect_domains()` groups sub-projects by framework type (frontend, backend, mobile, infrastructure, shared). `detect_infra_patterns()` scans for CI/CD, IaC, containers, and deployment configs. Both always run during discovery.
- **Domain-tagged FEATURES.md output** — `render_proposals.py` adds `- Domain:` metadata to each feature, with cluster-to-domain mapping from discovery report.
- **`ag specs` command** — Systematic brownfield spec generation with plan-review loop, per-domain progress tracking via checkbox plan artifacts, multi-session resume support.
- **Size-aware routing in init** — Small projects (1 domain, ≤8 clusters) get inline spec generation; larger projects are routed to `ag specs`.
- **Greenfield domain question** — Init interview asks Core+PM projects about distinct domains from day 1.
- **Brownfield Spec Pipeline** — Documented in `auto_orchestration.md`: 7-step process from discovery through cross-domain review.
- **Session start brownfield plan detection** — Detects active `*-specs-plan.md` and suggests resuming.
- **3 new LLM behavioral tests** (044-046) — `ag specs` awareness, domain-tagged features, brownfield plan resume.
- **16 new pytest tests** — Infrastructure pattern detection (7), domain detection (8), integration test update (1). Total: 75 discover tests.

### Changed
- **discover.py** — Report now always includes `infra_patterns` and `domains` fields (additive, no version bump needed).
- **init_playbook.md** — Step 0.5c for size-aware routing, greenfield domain question in Step 1.

## [0.24.0] - 2026-02-10

### Added
- **Intelligent Onboarding for Existing Projects (F-0123)** — `discover.py` analyzes brownfield codebases (package files, entry points, architecture), `render_proposals.py` generates STACK/CONTEXT_PACK/OVERVIEW proposals with confidence annotations and `<!-- PROPOSAL -->` markers. `scaffold.sh` auto-runs discovery for existing projects. `ag approve-onboarding` strips proposal markers from confirmed files.
- **Agent Memory Seeding** — `.agentic/init/memory-seed.md` with tool-agnostic behavioral patterns (pre-commit sequence, session start, feature workflow, common pitfalls). Seeded to persistent memory during init for Claude Code, Codex CLI, and Windsurf.
- **Windsurf support in init** — Added as option (e) in tool selection, with `.windsurfrules` setup and optional global memory seeding
- **Codex CLI section in init** — Dedicated setup section with optional `~/.codex/AGENTS.md` seeding (asks user first)
- **Memory seed pointer in CLAUDE.md template** — Existing projects auto-seed memory on next session start

### Changed
- **init_playbook.md** — Step 0.5 for brownfield discovery review, Windsurf/Codex sections, Claude memory seeding instruction
- **doctor.py** — Validates discovery artifacts (discover.sh, discover.py, render_proposals.py)
- **ag.sh** — `approve-onboarding` command for stripping proposal markers

## [0.23.0] - 2026-02-08

### Added
- **"How It Works" section in README.md** — Three-layer architecture (Constitution → Playbooks → State) explained for prospective users
- **Architecture table in FRAMEWORK_QUICK_START.md** — Quick reference for framework-dev agents
- **Template vs Root table in FRAMEWORK_DEVELOPMENT.md** — Explicit dogfooding comparison with sync rules
- **Architecture cross-references** — Pointers added to PRINCIPLES.md, auto_orchestration.md, and root CLAUDE.md
- **`core-rules.md`** — Constitutional minimum (~300 tokens) auto-injected for ALL subagent roles via `context-for-role.sh` ALWAYS_INJECT
- **Plans directory** (`.agentic-journal/plans/`) — Reviewed & approved plans now git-tracked alongside manifests and lessons
- **Archived tools README** (`.agentic/tools/archived/README.md`) — Documents why 6 tools were archived

### Changed
- **JOURNAL.md moved** to `.agentic-journal/JOURNAL.md` — all scripts use fallback to root for backward compat
- **Plans consolidated** — from `docs/plans/` and `.agentic-state/plans/` (gitignored) to `.agentic-journal/plans/` (git-tracked)
- **Instruction architecture doc promoted** — `docs/research/INSTRUCTION_ARCHITECTURE.md` → `docs/INSTRUCTION_ARCHITECTURE.md`
- **Instruction files slimmed** — Template CLAUDE.md 79→40 lines, root 92→52 lines, codex 286→50 lines. Gates, delegation, session protocols moved to `auto_orchestration.md`
- **agent_operating_guidelines.md** — 434→~120 lines. Detailed rules extracted to `guidelines/` modules
- **`ag.sh`** — `implement`, `commit`, `done` commands now print playbook references. `done` (Core) runs `doctor.sh --quick`
- **4 design gaps from INSTRUCTION_ARCHITECTURE.md** — all resolved (instruction slimming, always-inject, playbook refs, done blocking)

### Removed
- 6 legacy tools archived: `arch_diff.sh`, `build-stamper.sh`, `bulk_update.py`, `consistency.sh`, `pipeline_list.sh`, `search.sh`
- `docs/plans/` directory (plans consolidated to `.agentic-journal/plans/`)

## [0.22.1] - 2026-02-07

### Added
- **Instruction Architecture Design Document** (`docs/INSTRUCTION_ARCHITECTURE.md`) — Single authoritative design basis synthesizing ChatGPT 5.2 and Claude Opus 4.6 research into unified three-layer architecture (Constitution → Playbooks → State), with 4 gaps, 10 testable assumptions, and maintenance model
- **L-0004 lesson** — Plan-review process preserved (3 rounds, 15 issues narrowed to acceptance)
- **ChatGPT 5.2 research** committed (`docs/research/context_and_subagents_research_2026_02_06.md`)

### Fixed
- **FRAMEWORK_DEVELOPMENT.md line 94** — False claim "CLAUDE.md is auto-loaded for ALL agents including subagents" corrected to tool-specific facts (subagents do NOT inherit it)

### Changed
- **FRAMEWORK_QUICK_START.md** — Step 10 now references instruction architecture design
- **PRINCIPLES.md** — Principle #4 (Deterministic Enforcement) now cites cross-tool research basis
- **L-0003** — Added resolution section pointing to design document

## [0.22.0] - 2026-02-06

### Changed
- **Instruction file slimdown** - All templates reduced ~70% to fix LLM compliance failures (L-0002)
  - Claude template: 277 → 79 lines
  - Copilot template: 268 → 69 lines
  - Codex template: 268 → 71 lines
  - Modeled after cursorrules.txt (69 lines) which already achieved full compliance
  - Root CLAUDE.md: 303 → 92 lines, copilot: 118 → 77 lines, CODEX.md: 134 → 76 lines

### Fixed
- **LLM test 002** (`wip_blocks_commit`) - Wrong mkdir path (`.agentic` → `.agentic-state`)
- **LLM test 003** (`acceptance_first`) - Overly broad pattern `impl.*auth` matched natural language; tightened to code-only patterns

### Added
- **L-0002 lesson update** - Documented subagent context multiplier effect
- **FRAMEWORK_DEVELOPMENT.md** - Added 100-line budget guidance for CLAUDE.md edits

## [0.21.0] - 2026-02-06

### Added
- **`status.sh infer` command** - Auto-infer project state from history data
  - Reconstructs STATUS.md from git log, JOURNAL.md, FEATURES.md, VERSION, CHANGELOG.md
  - `--apply` flag to auto-update STATUS.md
  - Catches staleness AND recovers in one step

- **Session-start auto-inference** - Active recovery instead of passive warnings
  - When STATUS.md is stale (>7 days), auto-runs `status.sh infer`
  - Displays inferred state for agent to review or apply
  - Replaces "it's stale" warning with actionable recovery

- **Pre-commit STATUS.md staleness check** - Safety net during work
  - Advisory warning if STATUS.md not updated in >48h
  - Suggests `status.sh infer --apply` for quick recovery
  - Alongside existing JOURNAL.md staleness check

- **6 artifact-maintenance LLM tests (036-041)** - Verify agents maintain durable artifacts
  - 036: Session end actually updates JOURNAL + STATUS (not just verbal summary)
  - 037: Detects stale STATUS.md (version mismatch)
  - 038: Mentions WIP tracking when starting significant work
  - 039: Updates full chain on feature complete (FEATURES → CHANGELOG → JOURNAL)
  - 040: Documents blockers in HUMAN_NEEDED.md
  - 041: Notices stale JOURNAL.md (date gap vs active development)

### Fixed
- Stale `tests/LLM_TEST_RESULTS.md` reference in pre-commit-check.sh (file was deleted in v0.20.0)

## [0.20.0] - 2026-02-05

### Added
- **"Why This Framework?" section in README.md** - Honest comparison vs custom rules files
  - Comparison table: `.cursorrules`/`CLAUDE.md` vs this framework
  - Evidence tiers: battle-tested, LLM-verified, structurally verified, designed for
  - Links to traceability matrix for proof

- **Principle-organized test reporting** - All test results in single file
  - VERIFICATION_REPORT.md is now the single source of truth for ALL tests
  - Results organized by the 11 core principles
  - Deleted `LLM_TEST_RESULTS.md` (consolidated)
  - Updated all 9 files referencing old location

- **TRACEABILITY_MATRIX.md rewritten** - Maps principles → features → tests
  - Aligned with 11 simplified principles
  - Shows principle coverage at 100% (32 LLM + 13 structural)
  - v0.19.0 results: 33/33 tests mapped

- **Context7 MCP server documentation** - Updated from legacy CLI to MCP approach
  - `documentation_verification.md` rewritten for MCP server setup
  - Cursor and Claude Desktop MCP config examples
  - `anti-hallucination.md` sources of truth updated
  - `agent_operating_guidelines.md` verification protocol updated
  - `STACK.template.md` config updated to `context7-mcp` option

### Changed
- `.agentic/README.md` - Fixed stale version refs (v0.2.1 → v0.19.0), updated principles list
- `STACK.md` - Test results path updated to VERIFICATION_REPORT.md

### Removed
- `tests/LLM_TEST_RESULTS.md` - Consolidated into VERIFICATION_REPORT.md

## [0.19.0] - 2026-02-05

### Added
- **Principles Consolidation** - Expanded PRINCIPLES.md from 34 to 48 principles
  - Development & Quality: TDD as Default, Explicit Over Implicit, Automated Validation, Retrospectives, Research Mode, Programming Standards, Comprehensive Testing
  - Collaboration: Multi-Agent Coordination, PR Mode, Build/Deploy Specialization
  - Documentation: Spec Schema Enforces Consistency, Examples First-Class, Framework Self-Documentation
  - Archived historical analysis files to `docs/reviews/`

- **Framework Value Proposition** - New documentation of framework value
  - `docs/FRAMEWORK_VALUE_PROPOSITION.md` - Problems solved & key features
  - 6 problem areas documented with specific solutions
  - Features organized by use case (Solo, Teams, Quality-Critical, Long-Term)

- **Value Proposition Audit** - Verification that claims match reality
  - `docs/reviews/2026-02-value-proposition-audit.md`
  - Systematic audit of all 30 value claims
  - Results: 29/30 IMPLEMENTED, 1/30 PARTIAL (progressive disclosure)

- **"Check Before Creating" Principle (NON-NEGOTIABLE)** - Prevent duplicates
  - Agents must search for existing implementations before creating new ones
  - Applies to tests, docs, components, utilities
  - Discovered via plan-review loop catching duplicate test
  - Enforcement added to `agent_operating_guidelines.md`

- **Anti-Hallucination Formalized** - Elevated to formal principle
  - Added to PRINCIPLES.md as NON-NEGOTIABLE
  - Comprehensive examples and enforcement mechanisms
  - Previously scattered, now first-class principle

### Fixed
- **Stale Version Numbers** - Updated 8 files from 0.12.0-0.15.1 to 0.18.0
  - PRINCIPLES.md, DEVELOPER_GUIDE.md, FRAMEWORK_DEVELOPMENT.md
  - ROI.md, claude-hooks/README.md, MANUAL_OPERATIONS.md
  - environment_research.md, green_coding.md

- **Green Coding Reference** - Added to agent_operating_guidelines.md

---

## [0.18.0] - 2026-02-05

### Added
- **Plan-Review Loop (F-0120)** - Iterative planning with critical review
  - `ag plan F-XXXX` - Create plan with iterative review loop
  - `ag plan F-XXXX --no-review` - Skip review for simple cases
  - Planner creates plan, reviewer critiques, loop until approved
  - Configurable via STACK.md: `plan_review_enabled`, `plan_review_max_iterations`
  - Plan artifacts stored in `.agentic-journal/plans/`
  - New agents: `plan-creator-agent.md`, `plan-reviewer-agent.md`
  - Catches issues before code is written (better quality first time)

- **Persistent Journal & Lessons (F-0121)** - Cross-session learning
  - Created `.agentic-journal/` directory for persistent history artifacts
  - Separates transient state (`.agentic-state/`) from persistent history
  - `lessons/` subdirectory for capturing project learnings (L-#### format)
  - `manifests/` moved from `.agentic-state/` to persist across sessions
  - L-0001: Plan-review model selection lesson (first example)
  - Survives framework upgrades and context resets

- **Tool-Specific Instructions Parity (F-0121)** - Consistent enforcement
  - Updated Codex, Copilot, Cursor templates with full 6-gate table
  - All tools now enforce: Acceptance, WIP, Tests, Complexity, Pre-commit, Status
  - Added escape hatches (`SKIP_TESTS=1`, `SKIP_COMPLEXITY=1`) to all templates
  - Added "implement entire" / "full system" trigger detection
  - Validation tests ensure gate parity across all 4 tools
  - `/CODEX.md` now extends template properly (not a stub)

- **Multi-Tool LLM Testing Infrastructure (F-0122)** - Cross-tool behavioral testing
  - `ag test llm` - Environment-aware test command
  - `ag test llm --list` - List available tests
  - `ag test llm --critical` - Run/show critical tests only
  - `ag test llm --setup 001` - Set up test project for a specific test
  - `ag test llm --verify 001` - Verify test outcomes
  - `ag test llm --detect` - Show detected environment
  - **Interactive mode** for IDE-based tools (Cursor, Copilot)
  - Machine-readable test definitions in `tests/llm/test_definitions.json`
  - Python interactive runner `tests/llm/interactive_runner.py`
  - Cursor CLI (`cursor-cli`) support added to harness.sh
  - Environment detection: Claude CLI, Codex CLI, Cursor IDE, Copilot IDE
  - All 4 critical behavioral tests validated in Cursor

---

## [0.17.1] - 2026-02-04

### Fixed
- **CLAUDE.md Dogfooding (I-0001)** - Template is now canonical source
  - `.agentic/agents/claude/CLAUDE.md` is the canonical template (what users get)
  - Root `/CLAUDE.md` extends template with framework-dev-specific notes only
  - Template now includes: ENFORCED GATES, `ag` CLI commands, escape hatches
  - **50% token reduction** for users (558 → 277 lines)
  - Added dogfooding rule to `FRAMEWORK_DEVELOPMENT.md`

### Added
- **Issue Tracking** - `spec/ISSUES.md` for bug/issue tracking (I-#### format)
  - Created via `quick_issue.sh` script
  - Parallel to feature tracking (F-####)

---

## [0.17.0] - 2026-02-04

### Added
- **Spec Migration System (F-0117)** - Complete migration management for spec evolution
  - `migration.sh create "title"` - Creates numbered migration files with template
  - `migration.sh list` - Lists all migrations with dates
  - `migration.sh show N` - Displays specific migration
  - `migration.sh search "term"` - Searches migrations by keyword
  - `migration.sh apply` - Regenerates FEATURES.md from migrations
  - Auto-updates `_index.json` registry
  - Parses Features Added/Modified/Deprecated sections
  - Detects shipped status from acceptance criteria

- **Documentation Drift Detection (F-0118)** - Manifest-based doc staleness detection
  - `drift.sh --docs` - Detects when docs may be out of sync with code changes
  - `drift.sh --docs --manifest F-XXXX` - Checks against specific feature manifest
  - Advisory only (never blocks)
  - Shows "potentially stale" vs "updated" documentation
  - Configurable via `doc_tracking:` in STACK.md

- **Feature Change Manifest Generation (F-0119)** - Git-based change tracking
  - `manifest.sh F-XXXX` - Generate manifest from feature ID (JSON output)
  - `manifest.sh --branch feature/foo` - Generate from branch
  - `manifest.sh --since 2026-02-01` - Generate from date range
  - `manifest.sh --markdown` - Human-readable Markdown output
  - Integrates with `drift.sh --manifest` for targeted doc drift detection

- **State Directory Migration** - Moved state files to `.agentic-state/`
  - `WIP.md`, `AGENTS_ACTIVE.md`, manifests now in `.agentic-state/`
  - Survives framework upgrades (not inside `.agentic/`)
  - Updated all tools and tests for new paths

---

## [0.16.0] - 2026-02-04

### Added
- **Maintainability Enforcement Gates (F-0116)** - Automated quality enforcement
  - **Test Execution Gate** (BLOCKING) - Pre-commit runs tests from STACK.md
    - Reads `test_fast:` (preferred) or `test:` commands
    - Whitelist-based execution for security (pytest, npm test, cargo test, etc.)
    - Timeout protection with macOS/Linux compatibility
  - **Complexity Limits Gate** (BLOCKING) - Enforces small batch development
    - `max_files_per_commit` (default: 10)
    - `max_added_lines` (default: 500) - counts additions only, not deletions
    - `max_code_file_length` (default: 500)
    - File-type aware (only checks code extensions)
  - **Escape Hatches** for legitimate bypasses
    - `SKIP_TESTS=1` and `SKIP_COMPLEXITY=1` environment variables
    - BLOCKED on main/master branches (only allowed on feature branches)

- **WIP Auto-Creation** - `wip.sh start F-XXXX --auto` creates minimal WIP tracking

- **Acceptance Frontmatter Parsing** - doctor.py parses YAML frontmatter from acceptance files
  - Graceful fallback to regex if PyYAML not installed
  - `validate_acceptance_tests()` function for validation commands

- **Migration Support** - upgrade.sh now adds:
  - Complexity limits section to STACK.md
  - Frontmatter to acceptance files missing it

### Changed
- Pre-commit check now has 11 checks (was 9)
- Core profile now enforces tests and complexity (previously lighter)
- Updated CLAUDE.md enforcement table with new gates
- Updated agent_operating_guidelines.md with Core profile clarification

### Fixed
- `grep '^??'` failing with pipefail when no untracked files (added `|| true`)

---

## [0.15.0] - 2026-02-01

### Added
- **Spec-Code Traceability Enhancements (F-0109)** - Answer key questions about code-spec alignment
  - `drift.sh --json` - Machine-readable drift detection output
  - `coverage.py --json` - Machine-readable annotation coverage
  - `coverage.py --reverse FILE` - Find what features a file implements
  - `coverage.py --test-mapping` - Infer test→feature relationships via conventions
  - `ag trace` - Unified CLI combining drift + coverage
    - `ag trace` - Full traceability report
    - `ag trace F-XXXX` - Files implementing a feature
    - `ag trace FILE` - Features implemented by a file
    - `ag trace --gaps` - Missing implementations only
    - `ag trace --orphans` - Orphaned code/annotations
    - `ag trace --json` - Combined JSON output for CI/tooling

- **Test→Feature Inference Conventions** - No annotations required
  - Explicit naming: `test_F0001_*.py` → F-0001 (high confidence)
  - Import tracing: test imports file with `@feature` → inferred (medium confidence)
  - Documented in `.agentic/workflows/code_annotations.md`

- **New Example Project: traced_notes_app** - Demonstrates traceability features
  - Source code with `@feature` annotations
  - Tests using naming conventions
  - Spec files with acceptance criteria

- **New Tests** - 18 tests for traceability tools
  - `tests/test_coverage.py` - Tests for coverage.py enhancements
  - `tests/test_drift.py` - Tests for drift.sh JSON output

### Changed
- Archived old examples to `examples/archived/`
- Updated documentation to include new traceability commands:
  - `.agentic/README.md`
  - `.agentic/DEVELOPER_GUIDE.md`
  - `.agentic/MANUAL_OPERATIONS.md`
  - `.agentic/START_HERE.md`
  - `.agentic/checklists/feature_complete.md`

---

## [0.14.0] - 2026-02-01

### Added
- **OVERVIEW.md as High-Level Context Document** - New unified vision document for projects
  - Clean structure: What We're Building, Why It Matters, Core Capabilities, In/Out of Scope, Success Looks Like, Guiding Principles
  - Agents read during planning to keep project vision front and center
  - Created at project root for both Core and Core+PM profiles

### Changed
- **Document separation clarified**:
  - `OVERVIEW.md` - What & why we're building (stable, read during planning)
  - `CONTEXT_PACK.md` - How to work here (operational, read at session start)
  - `STATUS.md` - What's happening now (dynamic, read at session start)
- **Planning agent** now reads OVERVIEW.md first before planning
- **Session start checklist** includes OVERVIEW.md in essential reads
- **scaffold.sh** creates OVERVIEW.md instead of PRODUCT.md

### Removed
- **PRODUCT.template.md** - Replaced by OVERVIEW.template.md
- **VISION.template.md** - Merged into OVERVIEW.md
- **PRD.template.md** - Corporate jargon, redundant with OVERVIEW.md
- **spec/OVERVIEW.template.md** - Consolidated to init/OVERVIEW.template.md

### Migration
- Existing PRODUCT.md files should be renamed to OVERVIEW.md
- Update content to match new structure (add "Why It Matters", "Success Looks Like", "Guiding Principles")
- All PRODUCT.md references in your project should be updated to OVERVIEW.md

---

## [0.13.0] - 2026-01-30

### Added
- **ag.sh Gateway Command** - Unified entry point for all framework commands
  - `ag start` - Session initialization (checks WIP, upgrades, shows status)
  - `ag implement F-XXXX` - Start feature implementation (Core+PM with acceptance criteria check)
  - `ag work "description"` - Start work session (Core profile, lighter workflow)
  - `ag commit` - Pre-commit validation and guided commit
  - `ag done F-XXXX` - Feature completion checklist
  - `ag verify` - Run doctor.sh with appropriate flags
  - `ag status` - Show current project status
  - `ag tools` - List available tools
- **list-tools.sh** - New tool to list and describe all framework tools

### Changed
- **CLAUDE.md reduced from ~570 to ~285 lines** - Trimmed redundancy, delegated to ag commands
- **agent_operating_guidelines.md reduced from ~1300 to ~340 lines** - Major token efficiency improvement
- **Docs cleanup** - Updated version references to v0.13.0 across 14+ documentation files

### Fixed
- **install.sh non-interactive mode** - Script now properly exits with code 0 when run without tty
  - Added `[[ -t 0 ]]` checks for interactive prompts
  - Fixes test failures in `validate_framework.sh`

---

## [0.12.2] - 2026-01-28

### Added
- **F-0103: Agent Mode Selection (Quality vs Cost)** - Configurable model selection for agent tasks
  - Three modes: `premium`, `balanced` (default), `economy`
  - Four task types: planning, implementation, review, search
  - Premium: opus for planning/impl/review, sonnet for search
  - Balanced: opus for planning, sonnet for impl/review, haiku for search
  - Economy: sonnet for planning, haiku for everything else
  - `agent_mode` setting in STACK.md controls selection
  - **Model customization**: `models:` section allows per-task overrides
  - **Documentation**: `.agentic/workflows/agent_mode.md`
  - **Init questions**: Agent asks about preferred mode during setup
- **Codex CLI Support** - OpenAI Codex CLI now supported
  - Created `.agentic/agents/codex/codex-instructions.md` template
  - Added `setup_codex()` function to setup-agent.sh
  - `bash .agentic/tools/setup-agent.sh codex` generates `.codex/instructions.md`

### Changed
- CLAUDE.md delegation tables now mode-aware (show different models per agent_mode)
- agent_operating_guidelines.md delegation tables updated with mode-based recommendations
- STACK.template.md includes agent_mode setting and commented models section for customization

---

## [0.12.1] - 2026-01-27

### Fixed
- **Session start exit code error** - `ls .agentic/WIP.md` now uses `|| true` to prevent "Exit code 1" error on fresh projects where WIP.md doesn't exist
- Same fix applied to AGENTS_ACTIVE.md checks

---

## [0.12.0] - 2026-01-20

### Added
- **F-0101: Framework Architecture Decision Records (ADRs)** - Document WHY decisions were made
  - `docs/adr/` directory for framework-level decision documentation
  - ADR-001: CLAUDE.md must be self-contained (bootstrap reliability)
  - Prevents future contributors from undoing intentional decisions
- **F-0102: Modular Guidelines for Token Efficiency** - Lazy-loaded guideline modules
  - `.agentic/agents/shared/guidelines/` with 5 modules
  - anti-hallucination, token-efficiency, small-batch, wip-tracking, multi-agent
  - ~84% token reduction (12,800 → 2,000 tokens) for typical tasks
- **.gitignore** for framework repository
- **JSON backend for status.sh** - True append-only updates via `.agentic/state/status.json`

### Changed
- **STATUS.md now required for both Core and Core+PM profiles**
  - Simplifies framework - one file for project state tracking
  - OVERVIEW.md becomes optional "vision document"
  - Removes 30+ conditional code paths (`STATUS.md || OVERVIEW.md`)
  - Migration: `upgrade.sh` auto-creates STATUS.md for existing Core projects
- **Project Phase concept** - STATUS.md tracks phase: `discovery` or `building`
  - Discovery: Research, references, requirements gathering, initial designs
  - Building: Iterative loop (specs, code, tests evolve together)
- **F-0028 (continue_here.py) deprecated** - Superseded by Project Phase in STATUS.md

### Added
- **PR Tracking via HUMAN_NEEDED.md** - Universal PR notification at session start
  - Primary: PRs tracked in HUMAN_NEEDED.md with "review" category (any git host)
  - Backup: `gh pr list` check for GitHub users
  - `blocker.sh` now supports "review" type for PR tracking
  - `git_workflow.md` step 7: Track PR in HUMAN_NEEDED.md when creating
- **F-0099: Branch Policy Safeguard** - Pre-push hook blocks direct pushes to main/master
  - `--i-know-what-im-doing` flag for intentional direct pushes
  - Integrated into `before_commit.md` checklist

### Updated
- 33 files updated for STATUS.md consolidation
- Templates: STATUS.md required, OVERVIEW.md optional with clear header
- `scaffold.sh`: Creates STATUS.md for both profiles
- `doctor.py`, `verify.py`: Profile detection and required files updated
- `upgrade.sh`: Step 6 migrates Core projects to use STATUS.md
- All hooks, checklists, agent guidelines simplified

---

## [0.11.5] - 2026-01-20

### Added
- **F-0098: Generate Claude Skills from Subagents** - Auto-discovered capabilities
  - `generate-skills.sh` creates `.claude/skills/` from subagent definitions
  - 10 skills: research, review, test, implementation, explore, planning, etc.
  - Skills auto-discovered by Claude Code based on task description
  - Single source of truth: `.agentic/agents/claude/subagents/*.md`
- **LLM Behavioral Tests Expanded** - From 5 to 11 tests, all passing
  - Section-based organization: session, trigger, scripts, commit, context
  - Compartmentalized testing: `--section`, `--critical` options
  - Multi-model comparison: `--compare-models` (Opus vs Sonnet)
  - Cost controls: `REGRESSION_GUIDE.md` with budget limits
- **Iterative Requirements Gathering** - New guideline
  - Agents offer options: finalize, ask more questions, get more context
  - Prevents premature assumption that enough info was gathered

### Changed
- `install.sh` now generates Claude Skills (Step 6) and offers agent suggestions (Step 7)
- `upgrade.sh` regenerates Skills (Step 5b), preserves custom skills
- Pre-commit hook now checks agent instruction file sizes (advisory)

---

## [0.11.3] - 2026-01-15

### Added
- **F-0096: PR-Based Workflow Default** - PR workflow is now default for Core+PM profile
  - Profile-aware defaults: Core+PM → `pull_request`, Core → `direct`
  - Updated agent guidelines, CLAUDE.md, STACK.template.md
- **F-0097: Worktree Management Tool** - `worktree.sh` for parallel agent development
  - Commands: `create`, `list`, `remove`, `status`
  - Auto-registers agents in `.agentic/AGENTS_ACTIVE.md`
  - Enables multiple Claude/Cursor windows without conflicts
- Multi-agent coordination via `.agentic/AGENTS_ACTIVE.md`
- Session start protocol now checks for other active agents
- Framework development itself now uses PR workflow (dogfooding)

### Changed
- `STACK.template.md` default `git_workflow` changed from `direct` to `pull_request`
- Agent guidelines updated to prioritize PR-based workflow
- DEVELOPER_GUIDE.md updated with `worktree.sh` documentation

---

## [0.11.2] - 2025-01-15

### Fixed
- Upgrade script no longer shows same "new features" on every upgrade
- Features now tracked by version introduced - only shown when actually new to user

---

## [0.11.1] - 2025-01-15

### Fixed
- `status.sh` macOS compatibility - replaced sed with awk for cross-platform support

### Added
- Issue tracking to `AGENT_QUICK_START.md` - agents now log bugs to ISSUES.md before fixing

---

## [0.11.0] - 2025-01-14

### NEW: Gate-Based Verification

Shift from instruction-based to **gate-based architecture**. Agents don't need to memorize 1000+ lines of guidelines - gates enforce quality automatically.

**`doctor.sh` is now THE verification command:**

```bash
doctor.sh              # Quick health check
doctor.sh --full       # Comprehensive verification (replaces verify.sh)
doctor.sh --phase X    # Phase-specific checks (start/planning/implement/complete/commit)
doctor.sh --pre-commit # Fast checks for git pre-commit hook
```

### NEW: Phase Detection

New `phase_detect.py` detects current development phase:
- `start` - No active work
- `planning` - Feature started, needs acceptance criteria
- `implement` - Has acceptance, coding in progress
- `complete` - Ready for final verification
- `blocked` - Has unresolved blockers

### NEW: Simplified Instructions

**AGENT_QUICK_START.md** (~70 lines) replaces reading 1000+ lines of guidelines.

**CLAUDE.md reduced 71%** (271 → 78 lines) - points to quick start, gates handle enforcement.

**agent_operating_guidelines.md** now marked as **reference material** - detailed rationale for troubleshooting, not required reading.

### NEW: Enforcement Hooks

`UserPromptSubmit.sh` now warns when user says "implement F-####" but acceptance criteria are missing:

```
⚠️  GATE WARNING: No acceptance criteria for F-0042
   Create spec/acceptance/F-0042.md before implementing
```

### DEPRECATED

- `verify.sh` - Use `doctor.sh --full` instead (will be removed in v0.12.0)

### Files Added
- `.agentic/tools/phase_detect.py`
- `.agentic/agents/shared/AGENT_QUICK_START.md`
- `tests/test_phase_detect.py`
- `docs/reviews/2025-01-14-framework-critical-review.md`
- `docs/reviews/2025-01-14-comparison-analysis.md`

### Files Modified
- `.agentic/tools/doctor.py` - Added argparse, --full, --phase, --pre-commit modes
- `.agentic/tools/doctor.sh` - Passes all args to Python
- `.agentic/tools/verify.sh` - Added deprecation warning
- `.agentic/claude-hooks/UserPromptSubmit.sh` - Added gate warnings
- `CLAUDE.md` - Reduced to 78 lines
- `.agentic/agents/shared/agent_operating_guidelines.md` - Marked as reference

---

## [0.10.0] - 2025-01-11

### NEW: Proactive Session Start

Agents now **automatically greet users with context** at session start:

```
👋 Welcome back! Here's where we are:

**Last session**: Implemented game board rendering
**Current focus**: Touch controls for mobile

**Next steps**:
1. Add touch event handlers (F-0019)
2. Test on mobile emulator

What would you like to work on?
```

Features:
- Silently reads STATUS.md, OVERVIEW.md, HUMAN_NEEDED.md, WIP.md
- Presents options for next steps
- Handles special cases:
  - "⚠️ Previous work interrupted!" (if WIP.md exists)
  - "📋 3 items need your input" (if HUMAN_NEEDED has items)
  - "🔄 Framework upgraded" (if upgrade pending)

**User shouldn't ask "where were we?" - agent tells them automatically.**

Added to shared (tool-agnostic) files:
- `agent_operating_guidelines.md`
- `auto_orchestration.md`
- `checklists/session_start.md`

### NEW: Feature Start Checklist

New `checklists/feature_start.md` with BLOCKING gates:
- Gate 1: Acceptance criteria exist?
- Gate 2: Small batch? (max 5-10 files)
- Gate 3: Delegate or do?
- Gate 4: Context handoff rules

### IMPROVED: Deterministic Agent Behavior

Restructured all agent instruction files:
- Trigger pattern matching at TOP
- STOP/BLOCK language for non-negotiable gates
- Primacy + recency (rules at top AND bottom)
- Redundancy across all tool-specific files

### FIXED: Claude Desktop → Claude Code

Renamed all references from "Claude Desktop" to "Claude Code" (terminal).

## [0.9.9] - 2025-01-11

### IMPROVED: Deterministic Agent Behavior

Based on real-world usage feedback where agents skipped documented workflows:

**Problem**: Agents would jump straight to implementation when asked to "build a feature", skipping the acceptance criteria check.

**Solution**: Restructured all agent instruction files for deterministic behavior:

1. **New checklist**: `feature_start.md` - BLOCKING gates before any feature work
   - Gate 1: Acceptance criteria exist?
   - Gate 2: Small batch? (max 5-10 files)
   - Gate 3: Delegate or do?
   - Gate 4: Context handoff (if delegating)

2. **Trigger pattern matching**: Explicit triggers at TOP of all instruction files
   - "build", "implement", "add", "create", "let's do" → Check criteria FIRST
   - "fix", "bug", "issue" → Write failing test FIRST
   - "commit" → All gates must pass

3. **Primacy + Recency**: Critical rules at BOTH top AND bottom of docs

4. **STOP language**: "🛑 STOP", "BLOCK", "DO NOT PROCEED UNTIL"

5. **Redundancy**: Same rules in multiple places (CLAUDE.md, copilot-instructions.md, agent_operating_guidelines.md)

Updated files:
- `.agentic/checklists/feature_start.md` (NEW)
- `.agentic/agents/claude/CLAUDE.md` (restructured)
- `.agentic/agents/copilot/copilot-instructions.md` (restructured)
- `.agentic/agents/shared/agent_operating_guidelines.md` (restructured)

### IMPROVED: Token Efficiency Delegation Guidelines

Clear rules for when to spawn subagents:

| Task | Spawn Agent | Model Tier | Savings |
|------|-------------|------------|---------|
| Codebase exploration | explore-agent | Cheap/fast | 83% |
| Documentation lookup | research-agent | Cheap/fast | 60% |
| Implementation | implementation-agent | Mid-tier | Focus |

Context handoff rules: Pass ONLY feature ID, criteria, 3-5 files, STACK.md.

## [0.9.8] - 2025-01-11

### NEW: Automatic Orchestration

Agents now **auto-detect task type** and follow systematic processes without user prompting:

- New `auto_orchestration.md` - Defines auto-triggers and non-negotiable gates
- Auto-triggers:
  - "implement F-####" → Feature Pipeline (acceptance → implement → test → update specs)
  - "fix I-####" → Issue Pipeline (understand → failing test → fix → update ISSUES.md)
  - "commit" → Before Commit checklist
  - "done" → Feature Complete checklist
- Non-negotiable gates:
  - Acceptance criteria must exist before implementing
  - Smoke test must pass before shipping
  - Specs must be updated before commit
  - Tests must pass
- Updated `agent_operating_guidelines.md`, `CLAUDE.md`, `copilot-instructions.md` with auto-orchestration

**The user should NEVER need to remind agents to update specs, run smoke tests, or follow checklists.**

### NEW: Orchestrator Agent

Manager/puppeteer agent that coordinates specialized agents:
- Delegates work but never implements itself
- Verifies quality gates at each step
- Ensures framework compliance
- Created for Claude Code (`.agentic/agents/claude/subagents/orchestrator-agent.md`)
- Created for Cursor (`.cursor/agents/orchestrator-agent.md`)
- Formal spec F-0081 with acceptance criteria

### NEW: Complete Agent Parity Across Environments

All 10 agents now available in Claude Code subagents:
- orchestrator-agent (NEW)
- planning-agent (NEW)
- spec-update-agent (NEW)
- documentation-agent (NEW)
- git-agent (NEW)
- explore-agent, research-agent, implementation-agent, test-agent, review-agent (existing)

### NEW: ROI Documentation

- `.agentic/ROI.md` - Comprehensive cost savings analysis
- Token savings: 50-60% reduction
- Developer time: 70-85% reduction in wasted time
- Bug prevention: 60-80% fewer production bugs
- Estimated annual savings by team size

### Refactored: Reduced Duplicate Documentation

- `definition_of_done.md` now redirects to `feature_complete.md` (single source of truth)
- Eliminated ~70% overlap between the two documents

### NEW: Formal Specs for Agent System

- F-0081: Orchestrator Agent
- F-0082: Tier-Based Model Selection
- F-0083: Agent Token Savings Documentation
- F-0084: Untracked Files Protection
- All with acceptance criteria and automated tests (87 checks pass)

## [0.9.7] - 2025-01-11

### NEW: Untracked Files Protection

Prevents "files created but not tracked in git" deployment issues:
- `check-untracked.sh` - Detect untracked files in project directories
- Pre-commit hook (check 6/6) warns about untracked files
- Updated `session_end.md` and `before_commit.md` checklists
- Updated `agent_operating_guidelines.md` with "always git add new files" rule

### NEW: Specialized Agent Usage

Claude Code can now actively use specialized subagents:
- Created 5 subagent definitions in `.agentic/agents/claude/subagents/`:
  - `explore-agent` - Quick codebase exploration (cheap/fast tier)
  - `implementation-agent` - Code writing (mid-tier)
  - `test-agent` - Test writing (mid-tier)
  - `review-agent` - Code review (mid-tier)
  - `research-agent` - Documentation lookup (cheap/fast tier)
- `create-agent.sh` - Create project-specific agents interactively
- `suggest-agents.sh` - Analyze project, suggest useful agents
- Updated `CLAUDE.md` with Agent Delegation section
- Updated `session_start.md` with Agent Delegation Check

### NEW: Token Savings Documentation

- `agent_delegation_savings.md` - Quantified savings (60-83% typical)
- `claude_best_practices.md` - Based on official Claude guide
- Documented why delegation saves tokens (model cost, context isolation)
- Added Claude Projects caching tips

### Improved: Tier-Based Model Recommendations

Model names change frequently. Documentation now uses tiers:
- **Cheap/Fast**: Exploration, lookups (haiku, gpt-4o-mini, gemini-flash)
- **Mid-tier**: Implementation, testing, reviews (sonnet, gpt-4o)
- **Powerful**: Complex architecture (opus, o1)

Future-proof: guidance remains valid as new models release.

## [0.9.6] - 2025-01-11

### Improved: Tool-Specific Setup

#### Selective Tool File Creation
- Init now asks which AI tool(s) user will use (can select multiple)
- Only creates files for selected tools (no clutter)
- User types 'ab' for Claude + Cursor, 'b' for Cursor only, etc.

#### Technology-Agnostic Agent Roles
- Role definitions now work with any language/framework
- Replaced `.ts` extensions with `.*` placeholders
- Agents read `STACK.md` for project-specific conventions

#### Environment Detection
- New: `check-environment.sh` detects which tools might be in use
- New: `check-environment.sh --list` shows existing tool files
- Upgrade process (step 8/8) now shows tool file status

#### Upgrade Asks About New Features
- `.upgrade_pending` now includes TODO for new features (sub-agents, pipeline)
- Helps users discover features added since their last version

#### Framework Dogfooding
- Framework repo now uses its own tool files (CLAUDE.md, .cursorrules)
- These are excluded from release packages via .gitattributes

## [0.9.5] - 2025-01-11

### NEW: Native Sub-Agent Integration

Claude Code and Cursor support **specialized sub-agents** for task-specific work. This release adds full support for leveraging these native capabilities.

#### 8 Agent Role Definitions

Created `.agentic/agents/roles/` with specialized roles:

| Role | Purpose | Output |
|------|---------|--------|
| Research Agent | Investigate tech choices | docs/research/*.md |
| Planning Agent | Define features, acceptance criteria | spec/acceptance/*.md |
| Test Agent | Write failing tests (TDD red) | tests/*.test.ts |
| Implementation Agent | Make tests pass (TDD green) | src/*.ts |
| Review Agent | Code review, quality checks | Approval/feedback |
| Spec Update Agent | Update FEATURES.md status | spec/FEATURES.md |
| Documentation Agent | Update docs | docs/, README |
| Git Agent | Commits, PRs | Git operations |

#### Tool-Specific Integration

- **Claude Code**: `.agentic/agents/claude/sub-agents.md` - How to spawn sub-agents
- **Cursor**: `.agentic/agents/cursor/agents-setup.md` - Custom agent setup

#### Pipeline Coordination

All agents update `.agentic/pipeline/F-####-pipeline.md` with:
- Current phase and agent
- Completed steps with timestamps
- Handoff notes for next agent

#### New: setup-agent.sh Options

```bash
# Multi-agent setup
bash .agentic/tools/setup-agent.sh cursor-agents  # Copy roles to .cursor/agents/
bash .agentic/tools/setup-agent.sh pipeline       # Create pipeline infrastructure
```

#### New: project-health.sh

Manager oversight script for monitoring:
- Pipeline status and stalled agents
- Feature completion tracking
- Documentation currency
- HUMAN_NEEDED items
- Active agent registry

```bash
bash .agentic/tools/project-health.sh --verbose
```

#### Updated: init_questions.md

New question for development style:
- (a) Single agent (default)
- (b) Specialized agents (sequential pipeline)
- (c) Parallel features (git worktrees)
- (d) Not sure (start simple)

#### Updated: multi_agent_coordination.md

Clarified two approaches:
1. **Native Sub-Agents**: Sequential pipeline for complex features
2. **Git Worktrees**: Parallel work on independent features

---

## [0.9.4] - 2025-01-08

### NEW: Tool-Specific Initialization (Critical Fix!)

**Problem**: `AGENTS.md` is NOT auto-loaded by any AI tool!
- Claude Code auto-loads `CLAUDE.md`
- Cursor auto-loads `.cursorrules`
- Copilot auto-loads `.github/copilot-instructions.md`

Agents weren't seeing framework instructions unless manually told to read AGENTS.md.

#### New: setup-agent.sh

```bash
# Set up for your specific tool
bash .agentic/tools/setup-agent.sh claude   # Creates CLAUDE.md
bash .agentic/tools/setup-agent.sh cursor   # Creates .cursorrules
bash .agentic/tools/setup-agent.sh copilot  # Creates copilot-instructions.md
bash .agentic/tools/setup-agent.sh all      # All of the above
```

#### Updated: scaffold.sh

Now automatically runs `setup-agent.sh all` during initialization, so all tool-specific files are created.

#### Updated: AGENTS.md

Now clarifies it's a REFERENCE file (not auto-loaded) and lists the tool-specific files.

#### Updated: Documentation

- `START_HERE.md`: Explains AGENTS.md vs auto-loaded files
- `init_playbook.md`: Uses setup-agent.sh instead of manual cp
- `.agentic/agents/installation.md`: Comprehensive tool setup guide

#### Supported Tools

| Tool | Auto-Loaded File |
|------|------------------|
| Claude Code | CLAUDE.md |
| Cursor | .cursorrules |
| GitHub Copilot | .github/copilot-instructions.md |
| Codex (OpenAI) | .codex/instructions.md (documented) |
| Gemini CLI | .gemini/instructions.md (documented) |

---

## [0.9.3] - 2025-01-08

### FIXED: Upgrade Script Bug (STACK.md & .upgrade_pending not created)

**Root Cause Found**: The upgrade script had **duplicate STACK.md update logic** in Step 6 and Step 7, using different variables (`NEW_VERSION` vs `FRAMEWORK_VERSION`). This caused confusion and silent failures.

#### Bug Fix

1. **Removed duplicate Step 6** - Consolidated into Step 7
2. **Unified version variable** - Now uses `VERSION_TO_USE` consistently
3. **Added explicit error messages** - Script now tells you exactly what failed
4. **Added debug mode** - Run `DEBUG=yes bash upgrade.sh ...` to diagnose issues
5. **Verification after update** - Confirms STACK.md was actually updated
6. **Better .upgrade_pending creation** - Checks .agentic/ exists before writing

#### How to Use Debug Mode

```bash
DEBUG=yes bash /path/to/upgrade.sh /your/project
```

Shows:
- VERSION file location being checked
- Whether STACK.md exists and its content
- Pattern matching results
- Verification results

### Added: Integration Test Plan

**Problem**: Framework features not validated end-to-end. Upgrade script may silently fail.

#### New: Integration Test Plan

Created `tests/INTEGRATION_TEST_PLAN.md` documenting:
- **Installation tests** (INST-01 to INST-03)
- **Upgrade tests** (UPG-01 to UPG-05) - covers the bugs reported
- **Tool tests** (TOOL-01 to TOOL-07)
- **Agent simulation tests** (AGT-01 to AGT-03)
- **Cross-environment tests** (ENV-01 to ENV-03)
- Manual test scenarios for agent behavior
- Future CI/CD integration plan

#### New: Upgrade Script Debug Mode

Run with `DEBUG=yes` to diagnose issues:
```bash
DEBUG=yes bash upgrade.sh /path/to/project
```

Shows:
- Where VERSION file is being read from
- Whether STACK.md exists and its path
- Whether .agentic/ directory exists before creating marker
- All conditions being checked

#### Quality Assurance Philosophy

- Static checks (`validate_framework.sh`) ≠ working software
- Integration tests validate actual behavior
- Manual scenarios test agent interaction
- Debug mode helps diagnose real-world issues

---

## [0.9.2] - 2025-01-08

### Fixed: Additional Upgrade Issues

**Reported issues fixed:**

#### 1. version_check.sh expects missing VERSION file

- Now falls back to STACK.md if `.agentic/VERSION` doesn't exist
- Clear error message with fix instructions
- Works with older projects that lack the VERSION file

#### 2. NFR.md missing format marker

- Added `<!-- format: nfr-v0.1.0 -->` to NFR.template.md
- Updated example project NFR.md
- Upgrade TODO now reminds to check format markers on all spec files

#### 3. Upgrade script now shows agent prompt

When upgrade completes, shows:
```
If agent is already running and doesn't notice the upgrade:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
COPY THIS PROMPT TO YOUR AGENT:

  Read .agentic/.upgrade_pending and follow the TODO list in it.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## [0.9.1] - 2025-01-08

### Fixed: Upgrade Script & Agent Upgrade Detection

**Problem Reported**: After upgrade, agent didn't know WHERE to look for upgrade info and was "reading all over .agentic", wasting tokens. STACK.md version wasn't updated.

#### Fixed: STACK.md Version Update

- **More robust pattern matching** - Now handles all STACK.md formats:
  - `- Version: X.Y.Z` (standard)
  - `Version: X.Y.Z` (no dash)
  - `  - Version: X.Y.Z` (indented)
- **Verification step** - Checks that version was actually updated
- **Reports if manual update needed**

#### Fixed: Agent Upgrade Detection

**New `.upgrade_pending` marker format**:
```markdown
🚨 FRAMEWORK UPGRADE PENDING - READ THIS FIRST!

**DO NOT search through .agentic/ randomly. This file tells you everything.**

## Upgrade Summary
- From: 0.4.3
- To: 0.9.1
- STACK.md updated: yes/no

## Your TODO List (complete all, then delete this file):
1. ✅ Read this file (you're doing it now)
2. [ ] If STACK.md not updated → update manually
3. [ ] Read START_HERE.md
4. [ ] Validate specs
5. [ ] Review CHANGELOG
6. [ ] Delete this file
```

**Updated session_start.md**:
- Emphasizes: "The marker file IS the upgrade notification"
- Explicitly says: "Don't search through .agentic/ randomly"
- Clear instructions to read the ONE file

**Updated agent_operating_guidelines.md**:
- Same emphasis on single-file detection
- Token waste prevention instructions

---

## [0.9.0] - 2025-01-08

### Major: Developer Hand-Holding & Issue Tracking

**Philosophy**: Developers should never need to remember processes. The framework guides them.

#### New: Emergency Quick Reference (EMERGENCY.md)

**Problem Solved**: When tokens run out, developers need immediate guidance.

**New file**: `.agentic/EMERGENCY.md` - Printable quick reference card

**Sections**:
- 🚨 "Tokens Running Out NOW?" - Save work in 3 commands
- "Add a New Feature Without Agent" - `quick_feature.sh` one-liner
- "Log a Bug/Issue" - `quick_issue.sh` one-liner  
- "Check What Agent Was Doing" - STATUS, JOURNAL, WIP commands
- "Resume Next Session" - Exact prompt to use
- Key files cheat sheet

**Linked from**: START_HERE.md for easy discovery.

#### New: Quick Scripts for Manual Work

**`quick_feature.sh`**:
```bash
bash .agentic/tools/quick_feature.sh "Dark mode support"
# Creates F-0001: Dark mode support in spec/FEATURES.md
```

**`quick_issue.sh`**:
```bash
bash .agentic/tools/quick_issue.sh "Login button broken" high major
# Creates I-0001: Login button broken in spec/ISSUES.md
```

Both scripts:
- Auto-generate next ID (F-#### or I-####)
- Create proper markdown format
- Show help when called without arguments

#### New: Issue/Bug Tracking (I-#### IDs)

**Problem Solved**: Features tracked (F-####), but bugs weren't formally tracked.

**New template**: `spec/ISSUES.template.md`

**Issue format**:
- ID: I-0001, I-0002, ...
- Status: open, in_progress, fixed, wont_fix
- Priority: critical, high, medium, low
- Severity: blocker, major, minor, cosmetic
- Found/Fixed dates
- Steps to reproduce
- Related features

**Scaffold updated**: Creates `spec/ISSUES.md` for Core+PM projects.

#### Framework Self-Dogfooding Enforced

**Critical insight**: Framework wasn't using its own methodology for new features!

**Fixed**:
- Added F-0077 to F-0080 to `spec/FEATURES.md` (now 59 features)
- Created acceptance criteria files for all new features
- Updated `tests/validate_framework.sh` (59 checks, all passing)
- Updated `FRAMEWORK_DEVELOPMENT.md` release checklist

**New rule**: "New framework features MUST be specced just like product features!"

---

## [0.8.1] - 2025-01-08

### Improved - Upgrade Experience

#### Upgrade Script Enhancements
- **All directories replaced**: Now replaces 14 directories (was 7), including `checklists/`, `claude-hooks/`, `hooks/`, `prompts/`, `quality_profiles/`, `schemas/`, `token_efficiency/`
- **All files replaced**: Now replaces 8 root files (was 5), including `DEVELOPER_GUIDE.md`, `FRAMEWORK_DEVELOPMENT.md`, `PRINCIPLES.md`
- **Auto-migrates spec formats**: Runs `upgrade_spec_format.py` automatically
- **Updates .agentic/VERSION**: Both `STACK.md` and `.agentic/VERSION` are updated

#### Efficient Upgrade Detection (Marker File)
- **New**: `upgrade.sh` creates `.agentic/.upgrade_pending` marker file
- Agent checks for marker at session start (instant file existence check)
- No more version comparison every session
- Marker contains: from_version, to_version, changelog URL, TODO list
- Agent handles upgrade tasks → deletes marker → done

#### Post-Upgrade Agent Guidance
- **New section** in `agent_operating_guidelines.md`: "After Framework Upgrade"
- **New check** in `session_start.md`: Check for `.upgrade_pending` marker
- Clear instructions for agents on what to review after upgrade

#### New Tool
- `version_check.sh`: Manual version comparison (backup method)

---

## [0.8.0] - 2025-01-08

### Added - Framework Self-Specification ("Dogfooding")

**Major milestone: The framework now has formal specs and acceptance criteria for itself.**

#### What This Means

At each version, you can now know exactly what the framework reliably does:
- **55 features** defined with clear acceptance criteria
- **49 automated validation checks** (all passing)
- **8 feature categories**: Core, Quality, Session, Multi-Agent, Tooling, Recovery, Developer Experience, Design Principles

#### New: spec/ Directory

**`spec/FEATURES.md`** - Complete feature catalog:
- F-0001 to F-0010: Core (initialization, profiles, spec-driven dev)
- F-0011 to F-0020: Quality (standards, gates, smoke testing)
- F-0021 to F-0030: Session (session management, journaling, context)
- F-0031 to F-0040: Multi-Agent (worktrees, coordination)
- F-0041 to F-0050: Tooling (scripts, automation, token efficiency)
- F-0051 to F-0060: Recovery (WIP tracking, error recovery)
- F-0061 to F-0070: Developer Experience (docs, onboarding, usability)
- F-0071 to F-0080: Design Principles (token economics, green coding, etc.)

**`spec/acceptance/`** - Acceptance criteria for 17 features:
- F-0001: Project Initialization
- F-0006: Acceptance-Driven Development
- F-0007: Small Batch Development
- F-0013: Smoke Testing
- F-0016: Pre-Commit Quality Gates
- F-0021: Session Start Protocol
- F-0031: Multi-Agent Coordination
- F-0041: Token-Efficient Scripts
- F-0051: WIP Tracking
- F-0055: Anti-Hallucination Rules
- F-0061: DEVELOPER_GUIDE.md
- F-0064: Script Help Messages
- F-0066: Template Quality
- F-0069: Checklist-Driven Workflows
- F-0071: Token Economics
- F-0073: Human-Agent Collaboration
- F-0074: Green Coding

**`tests/validate_framework.sh`** - Automated validation:
```bash
bash tests/validate_framework.sh
# ✅ ALL ACCEPTANCE CRITERIA VALIDATED
# Passed: 49, Failed: 0, Warnings: 0
```

#### Updated Design Principles in README

**Quality by Design:**
- Changed from "TDD recommended" to "Acceptance-Driven Development" primary
- TDD remains available as optional alternative

**Small Batch Development (Critical for Agents!):**
- Added as separate principle (#6) - critical for keeping agents focused
- One feature at a time per agent (multi-agent uses worktrees)
- MAX 5-10 files per commit

**Iterative & Incremental Development:**
- Restored as separate principle (#7) - complements Small Batch
- Small Batch = HOW to work (mechanics)
- Iterative = PHILOSOPHY (ship, learn, adapt)
- Both principles work together

#### Benefits

1. **Version Verification**: Know exactly what v0.8.0 can do
2. **Regression Testing**: Ensure upgrades don't break features
3. **Clear Communication**: Unambiguous feature definitions
4. **Self-Dogfooding**: Framework uses its own methodology

## [0.7.0] - 2025-01-08

### Changed - Acceptance-Driven Development (Primary Methodology)

**Major shift: From TDD-recommended to Acceptance-Driven Development as default.**

#### Philosophy Change

**Before (TDD-first):**
- Write test → Implement 5 lines → Repeat (micro-level)
- Good discipline, but can be slower with AI

**After (Acceptance-Driven):**
1. Define feature + acceptance criteria (rough is OK)
2. AI implements feature (can be large chunk - AI is fast!)
3. Write acceptance tests to verify criteria
4. Update specs with discoveries (edge cases, issues, ideas)
5. Commit when tests pass
6. Move to next feature

**Why this change:**
- AI can generate large working chunks quickly
- Micro-TDD may be slower than needed with AI
- Specs are discovered during implementation, not fully known upfront
- Acceptance tests are the critical gate, not unit test coverage
- Discovery is expected and encouraged - update specs as you learn

**TDD remains available:** Set `development_mode: tdd` in STACK.md for those who prefer tests-first.

### Added - Small Batch Development (NON-NEGOTIABLE Principle)

**New top-level principle in PRINCIPLES.md and agent_operating_guidelines.md.**

**Rules:**
- ONE feature at a time (never work on multiple simultaneously)
- Acceptance criteria MUST exist before implementation (rough is OK)
- MAX 5-10 files per commit (stop and re-plan if more)
- Commit when feature's acceptance tests pass
- Update specs with discoveries

**STOP and re-plan if:**
- >10 files touched for "one feature"
- Can't define any acceptance criteria
- >1 hour without a commit
- Multiple features "in progress"

### Added - Spec Evolution Workflow

**New: `spec_evolution.md` - How specs evolve during implementation**

Specs are discovered, not fully designed upfront. This is expected!

**During implementation, update specs when you discover:**
- New edge cases
- Security requirements
- Performance constraints
- Future enhancement ideas
- Dependencies on other features

**Mark discoveries:** `[Discovered] Rate limit: Max 5 failed attempts per 10 min`

### Added - Workflows README

**New: `workflows/README.md` - Guide to workflow documents**

Clarifies which documents to use when:
- Primary checklists for day-to-day work
- Development modes (Standard vs TDD)
- Quality documents
- Recovery documents
- Optional/advanced documents

### Changed - Batch Size Enforcement

**Updated: `pre-commit-check.sh` now warns about large commits**

- >10 files: Note (moderate batch size)
- >15 files: Warning (too large, should re-plan)

### Changed - Feature Implementation Checklist

**Updated: `feature_implementation.md` now has Gate 1: Acceptance Criteria**

- Cannot proceed without acceptance criteria (rough is OK)
- Specs evolve during implementation (expected)
- Links to `spec_evolution.md`

### Changed - STACK.template.md Default

**Updated: `development_mode: standard` is now default (was `tdd`)**

- Standard (Acceptance-Driven): AI implements, tests verify
- TDD (Optional): Tests first, for those who prefer it

## [0.6.0] - 2025-01-08

### Added - Enforcement Layer: From Guidelines to Gates

(Previous release notes...)

## [0.5.0] - 2025-01-08

### Added - Work-In-Progress (WIP) Tracking: Never Lose Work Again

**Critical new feature: Automatic detection and recovery of interrupted work.**

#### The Problem

Work was being lost when:
- ❌ Token limits reached mid-edit (agent stops abruptly)
- ❌ Tools crashed or closed unexpectedly
- ❌ Context compaction happened (Claude)
- ❌ Environment switched mid-task (forgot to log)
- ❌ Computer crashed or froze

**User request**: *"Lock file system that tracks 'starting to work on X, if not updated = interrupted, check diff against git'"*

#### The Solution: WIP.md Lock File + Recovery Protocol

**NEW: `.agentic/tools/wip.sh` - Work-in-progress tracking**

**Commands:**
```bash
bash .agentic/tools/wip.sh start F-#### "description" "files"    # Start tracking
bash .agentic/tools/wip.sh checkpoint "progress note"             # Update (~15 min)
bash .agentic/tools/wip.sh complete                               # Finish & remove
bash .agentic/tools/wip.sh check                                  # Detect interrupted work
```

**Creates `WIP.md` lock file containing:**
- Feature being worked on
- Agent/environment (claude-code, cursor, copilot)
- Started timestamp
- Last checkpoint timestamp
- Files being edited
- Progress checklist
- Recovery instructions

**Staleness detection:**
- <5 min: Recent (active handoff or recent interruption)
- 5-60 min: Normal working (no concern)
- >60 min: STALE (agent likely crashed, needs review)

**Exit codes:**
- 0: No interrupted work (clean state)
- 1: Interrupted work detected (triggers recovery protocol)

#### Session Start: Automatic Interruption Detection

**UPDATED: `.agentic/checklists/session_start.md`**

**NEW FIRST STEP (before anything else):**
```bash
bash .agentic/tools/wip.sh check
```

**If interrupted work detected:**
- ⚠️ Shows what was in progress (feature, agent, time ago)
- Shows git diff (what changed since WIP started)
- Shows last checkpoint from SESSION_LOG.md
- **Offers recovery options:**
  1. **Continue** - Resume from checkpoint (if progress looks good)
  2. **Review** - `git diff` to see changes, then decide
  3. **Rollback** - `git reset --hard` if changes incomplete/broken

**Example user message:**
> "⚠️ Previous work on F-0005: User Authentication was interrupted 45 minutes ago.
> I can see 3 uncommitted changes (src/auth/login.ts, src/auth/types.ts, tests/auth/login.test.ts).
> Last checkpoint: 'Login endpoint done, starting JWT validation'
> 
> Would you like to:
> 1. Continue from where we left off
> 2. Review changes first (git diff)
> 3. Roll back to last commit"

**Why first?** Prevents building on top of incomplete/broken changes.

#### Claude Hooks: Automatic WIP Protection

**UPDATED: `.agentic/claude-hooks/PreCompact.sh`**

**NEW Step 0 (before context compaction):**
- If WIP.md exists: `bash .agentic/tools/wip.sh checkpoint "Context compaction triggered"`
- Preserves WIP state automatically before context reset
- User doesn't need to do anything!

**Result:** After compaction, WIP.md still tracks work → SessionStart can resume seamlessly.

**UPDATED: `.agentic/claude-hooks/Stop.sh`**

**NEW Step 0 (session ending check):**
- If WIP.md exists: "🚨 WIP.md exists - work may be incomplete!"
- Shows options: complete work, leave for next session, review
- Prevents forgetting in-progress work

#### Commit Safety: Never Commit Incomplete Work

**UPDATED: `.agentic/checklists/before_commit.md`**

**NEW FIRST CHECK:**
- Check if WIP.md exists
- If exists: `bash .agentic/tools/wip.sh complete` FIRST (removes lock)
- Then commit
- **Why**: WIP.md presence = work incomplete → never commit incomplete work

#### Agent Workflow Integration

**UPDATED: `.agentic/agents/shared/agent_operating_guidelines.md`**

**NEW Section: Work-In-Progress (WIP) Tracking**
- When to start WIP (beginning significant work)
- How to checkpoint frequently (~15 min, not just at end)
- Session start WIP check (ALWAYS first, mandatory)
- Context compaction handling (automatic via hooks)
- Environment switching protocol (WIP as handoff mechanism)
- Multi-agent coordination (WIP as lock file)
- Never commit with WIP present (enforcement)
- Benefits and token cost (~50 tokens/operation)

#### Complete Documentation

**NEW: `.agentic/workflows/work_in_progress.md`**

**Comprehensive guide covering:**
- Problem statement (work loss scenarios)
- Solution overview (WIP.md lock file)
- Usage guide (start, checkpoint, complete, check)
- Integration points (session start, hooks, commit)
- Recovery scenarios with examples:
  - Token limit reached mid-edit
  - Tool crash
  - Context compaction
  - Environment switching
  - Computer crash
- Git integration (diff, status, rollback)
- Best practices (checkpoint frequency, never commit with WIP)
- Multi-agent coordination (WIP as lock)
- State machine diagram

### Benefits

**Prevents work loss from:**
- ✅ Token limit reached mid-edit (checkpoint preserved in WIP.md)
- ✅ Tool crashes or abrupt close (WIP + git diff show exact state)
- ✅ Context compaction (PreCompact hook auto-updates WIP)
- ✅ Computer crashes (WIP.md survives reboot)
- ✅ Environment switching mid-task (WIP tracks handoff)
- ✅ Forgot to log progress (WIP is automatic reminder)

**Provides recovery via:**
- ✅ Shows what was in progress (feature, files being edited, progress checklist)
- ✅ Shows git diff (what actually changed since WIP started)
- ✅ Shows last checkpoint (what was last accomplished)
- ✅ Calculates time ago (staleness detection, >60 min = crashed)
- ✅ Offers clear options (continue seamlessly, review first, or rollback)

**Multi-environment support:**
- ✅ WIP tracks which agent/environment has context (claude-code, cursor, copilot)
- ✅ Seamless handoff between tools (Claude → Cursor → Copilot)
- ✅ Each tool checks WIP at session start (shared state)
- ✅ No work lost when switching tools mid-task

**Multi-agent coordination:**
- ✅ WIP.md acts as lock file (prevents concurrent work)
- ✅ Fresh WIP (<5 min): Another agent working, coordinate
- ✅ Stale WIP (>60 min): Agent crashed, safe to take over
- ✅ Prevents conflicts in parallel agent scenarios

**Token efficiency:**
- Create WIP: ~50 tokens
- Checkpoint WIP: ~50 tokens  
- Check WIP: ~200 tokens (includes git diff, recovery options)
- **Total cost: Minimal vs. losing hours of work!**

### Example Scenarios

**1. Token Limit Reached (Most Common)**
```
11:00 AM - Agent working on F-0005: User Authentication
11:30 AM - bash wip.sh checkpoint "Login endpoint done, starting JWT validation"
11:45 AM - Token limit reached, agent stops abruptly
           (WIP.md preserved with checkpoint at 11:30)

12:00 PM - User opens Cursor (switching environments)
           bash wip.sh check
           "⚠️ Interrupted work detected (15 minutes ago)"
           git diff shows 3 uncommitted files
           User: "Continue"
           Cursor resumes from exact checkpoint, continues work
```

**2. Tool Crash**
```
2:00 PM - Agent editing src/auth/login.ts
2:15 PM - bash wip.sh checkpoint "Implementing token validation logic"
2:20 PM - Computer freezes, force restart required
          (WIP.md survives reboot)

2:30 PM - User reopens project in Claude
          bash wip.sh check
          "⚠️ WIP detected from 15 minutes ago (STALE)"
          git diff shows partial implementation in login.ts
          User: "Review changes first"
          git diff src/auth/login.ts  # Shows partial validation code
          User: "Looks incomplete, rollback"
          git reset --hard
          bash wip.sh complete  # Clean WIP lock
```

**3. Context Compaction (Claude, Automatic)**
```
10:00 AM - Agent working on F-0005
10:30 AM - PreCompact hook triggers (context 90% full)
           bash wip.sh checkpoint "Context compaction triggered" (AUTOMATIC!)
           Context window resets
10:31 AM - Agent resumes with fresh context
           SessionStart automatically reads WIP.md
           Continues seamlessly from checkpoint
           User never notices interruption!
```

**4. Environment Switch (Multi-tool workflow)**
```
Morning  - Claude working on F-0005: User Authentication
11:00 AM - Claude tokens at 80%
           bash wip.sh checkpoint "Login endpoint complete, switching to Cursor"
11:05 AM - User opens project in Cursor
           bash wip.sh check
           "✓ Recent checkpoint (5 minutes ago) - active handoff"
           Cursor continues from exact checkpoint
           No context loss, perfect continuity!
```

### Files Changed

**New files:**
- `.agentic/tools/wip.sh` - WIP tracking script (executable)
- `.agentic/workflows/work_in_progress.md` - Complete documentation

**Updated files:**
- `.agentic/checklists/session_start.md` - WIP check as FIRST step
- `.agentic/claude-hooks/PreCompact.sh` - Auto-checkpoint WIP before compaction
- `.agentic/claude-hooks/Stop.sh` - Warn about uncommitted WIP
- `.agentic/checklists/before_commit.md` - Never commit with WIP present
- `.agentic/agents/shared/agent_operating_guidelines.md` - WIP workflow integrated

### Impact

**This feature fundamentally changes the reliability of AI-assisted development.**

**Before v0.5.0:**
- Work lost when tokens ran out mid-edit
- No detection of incomplete work at session start
- Risky to switch environments mid-task
- Tool crashes = lost work
- Building on top of incomplete changes = bugs

**After v0.5.0:**
- ✅ Work automatically tracked and recoverable
- ✅ Interrupted work detected immediately at session start
- ✅ Safe environment switching with WIP handoff
- ✅ Tool crashes recoverable via WIP + git diff
- ✅ Never build on incomplete work (WIP check first!)

**Users can now work confidently**, knowing their progress is protected and recoverable even when tools fail or tokens run out.

## [0.4.4] - 2025-01-08

### Added - Multi-Environment Support & Environment Optimization

**Work seamlessly across Claude Code, Cursor, and GitHub Copilot in the same project. Switch between tools as tokens run out.**

#### 1. Multi-Environment as Default Setup

**NEW: Multi-environment is now RECOMMENDED during initialization**

**Problem it solves:**
- Token limits force work stoppage (Claude 200K → Cursor 50K → Copilot 8K)
- User wants: Claude tokens run out → switch to Cursor → continue work → switch to Copilot → keep going
- Each tool should pick up EXACTLY where previous left off
- Need seamless handoff without losing context

**Solution:**
- Init playbook now asks: "a) Multiple (RECOMMENDED)" as first option
- All adapter files installed by default (CLAUDE.md, .cursor/rules/, .github/)
- Shared state files ensure continuity (JOURNAL.md, FEATURES.md, STATUS.md)
- Token-efficient scripts work in ALL environments (40x cheaper than file reads)

**Example chain:**
1. Morning: Claude Code (complex feature, full codebase context)
2. Claude tokens 80%: Switch to Cursor (@ mentions, composer mode)
3. Need quick fix: Copilot inline suggestion
4. Next morning: Back to Claude (SessionStart hook loads full context)

Each tool reads same files → Perfect continuity!

#### 2. Environment-Specific Optimizations

**NEW: `.agentic/support/environment_research.md` - Capabilities matrix & best practices**

**Documented differences:**
- **Context windows**: Claude (200K) >> Cursor (~50K) >> Copilot (8K)
- **File operations**: Claude/Cursor (direct edits) vs. Copilot (suggestions only)
- **Hooks**: Claude ONLY (SessionStart, PreCompact, PostToolUse, Stop)
- **Multi-file**: Claude/Cursor (yes) vs. Copilot (no, one file at a time)
- **Terminal**: Claude/Cursor (yes) vs. Copilot (no)

**Environment-specific instructions:**
- **Claude**: Leverage hooks for auto-logging, use artifacts, read all specs at once
- **Cursor**: Use @ mentions (@FEATURES.md), composer mode, token-efficient scripts
- **Copilot**: ULTRA-CONCISE instructions (8K limit!), scripts CRITICAL, work file-by-file

**Benefits:**
- Claude users get hooks (automatic checkpoint logging before context reset!)
- Cursor users get @ mention tips (precise context without reading whole files)
- Copilot users get minimal instructions (fits in 8K limit)
- Each tool optimized for its strengths

#### 3. Seamless Environment Switching Workflow

**NEW: `.agentic/workflows/environment_switching.md` - Complete handoff protocol**

**Switching protocols:**

**Claude → Cursor:**
```bash
# In Claude (before tokens run out)
bash .agentic/tools/journal.sh "Checkpoint" "What done" "What next" "Blockers"
# PreCompact hook does this automatically!

# In Cursor
@JOURNAL.md  # Reads recent entries
@FEATURES.md # Current feature state
# Continues seamlessly
```

**Cursor → Copilot:**
```bash
# In Cursor
bash .agentic/tools/session_log.sh "Checkpoint" "Details" "feature=F-####"

# In Copilot (TINY context!)
# Give minimal context, use scripts only
bash .agentic/tools/feature.sh F-#### status shipped
```

**Copilot → Claude:**
```
# Next session in Claude
# SessionStart hook automatically loads .continue-here.md
# Full context restored!
```

**Best practices:**
- Log before switching (journal.sh, session_log.sh)
- Match tool to task (complex→Claude, multi-file→Cursor, quick→Copilot)
- Checkpoint frequently (every ~30 min, not just at session end)
- Use shared state files (all tools read/write same markdown)

**Token management:**
- Claude: 200K tokens/session (~2-4 hours complex work)
- Cursor: 50K tokens/conversation (~30-60 min complex work)
- Copilot: 8K tokens (~quick edits only)
- Scripts: 40x more efficient than reading files!

#### 4. Framework Staleness Detection

**NEW: `.agentic/tools/framework_age.sh` - Check if framework is outdated**

**Problem:** AI tools evolve rapidly (new hooks, larger context, new features). Framework instructions may become outdated.

**Solution:** Automatic staleness detection during init:
```bash
bash .agentic/tools/framework_age.sh
# Outputs:
# - Framework version and age
# - Status: Current (<30 days) / Aging (30-90 days) / Outdated (>90 days)
# - Research recommendations if old
# - Links to official docs (Claude, Cursor, Copilot)
```

**Exit codes:**
- 0: Current (<30 days) - No action needed
- 1: Aging (30-90 days) - Consider research
- 2: Outdated (>90 days) - Strongly recommend research

**If framework old (>30 days), agent offers:**
> "Framework is 120 days old. Would you like to research latest [Claude/Cursor/Copilot] features?
> I'll check official docs and update environment_research.md with new capabilities."

**Benefits:**
- Framework stays current with tool updates
- Users get latest optimizations
- Clear prompts for agents to research and update
- Prevents obsolescence

#### 5. Updated Init Playbook

**UPDATED: `.agentic/init/init_playbook.md`**

**New steps:**
- **Step 1a: Detect AI environment**
  - Ask: Multiple (a) | Claude (b) | Cursor (c) | Copilot (d)
  - Install appropriate adapters
  - Provide environment-specific tips
  - Update STACK.md with "AI Environments: multi"

- **Step 1b: Check framework age**
  - Calculate days since last update
  - Warn if >30 days old
  - Offer research prompt if >90 days
  - Link to official docs for each environment

**Why this matters:**
- Users explicitly choose multi-environment (or know they can)
- Framework adapts to tool capabilities
- Staleness detected before it's a problem
- Research workflow prevents obsolete instructions

### Benefits

**Token resilience:**
- Never blocked by token limits
- Work continuously throughout day (Claude → Cursor → Copilot chain)
- Each tool picks up where previous left off

**Tool flexibility:**
- Use best tool for each task
- Claude: Complex features, architecture, research
- Cursor: Multi-file refactors, IDE work, @ mentions
- Copilot: Quick edits, inline suggestions, when others unavailable

**Seamless handoff:**
- All tools share state (JOURNAL, FEATURES, STATUS)
- Token-efficient scripts work everywhere
- Common checklists and standards
- AGENTS.md as unified behavioral contract

**Cost optimization:**
- Start with Claude (large context, can read all specs)
- Switch to Cursor before tokens run out
- Use Copilot for quick fixes
- Extend work session across tools
- Minimize token waste

**Future-proof:**
- Framework age check prevents obsolescence
- Research workflow keeps optimizations current
- Environment-specific instructions evolve with tools
- Maintenance reminders every 3-6 months

### Example: Full Day Multi-Environment Workflow

```
8:00 AM - Claude Code (tokens fresh)
├─ Read all specs, understand architecture
├─ Plan F-0005 implementation
├─ Write tests (TDD)
├─ Implement core logic
└─ Hooks auto-log checkpoints

11:00 AM - Claude tokens at 80%
├─ bash .agentic/tools/journal.sh "F-0005 progress" "..." "..." "..."
└─ Switch to Cursor

11:15 AM - Cursor
├─ @JOURNAL.md (loads recent context)
├─ @src/feature.ts (current code)
├─ Composer mode (multi-file error handling)
├─ bash .agentic/tools/feature.sh F-0005 impl-state complete
└─ Integration tests

12:30 PM - Quick README typo
├─ Open in VS Code
├─ Copilot inline suggestion
└─ Fixed in 30 seconds

2:00 PM - Back to Cursor
├─ Complete F-0005
├─ bash .agentic/tools/feature.sh F-0005 status shipped
└─ bash .agentic/tools/journal.sh "F-0005 complete" "..." "Start F-0006" "..."

Next day 8:00 AM - Claude Code
├─ SessionStart hook loads .continue-here.md
├─ Sees full progress from all tools
├─ ✓ F-0005 shipped yesterday
└─ Continues with F-0006 seamlessly
```

**Total work**: ~6 hours uninterrupted across 3 tools!

### Files Changed

**New files:**
- `.agentic/support/environment_research.md` - Capabilities matrix & optimizations
- `.agentic/workflows/environment_switching.md` - Complete handoff guide
- `.agentic/tools/framework_age.sh` - Staleness detection script

**Updated files:**
- `.agentic/init/init_playbook.md` - Multi-environment setup, staleness check
- `README.md` - Multi-environment section, token resilience benefits
- `CHANGELOG.md` - This entry

## [0.4.3] - 2025-01-05

### Added - Library Selection Guidelines & Architectural Decision Framework

**Prevents costly wrong library choices based on real-world failure (chess.js for chess variant).**

#### 1. Library Selection Decision Framework

**NEW: `quality/library_selection.md` - Comprehensive guide for choosing libraries vs. custom code**

**Critical lesson from real project:**
- Project: Chess/Tetris hybrid game
- AI chose: chess.js (enforces standard FIDE chess rules)
- Problem: Game has custom rules, Tetris mechanics, pieces added one at a time
- Result: FAILED - had to rip out library and rebuild
- Should have: Implemented custom engine from the start

**Decision framework includes:**
- **Standard vs. Custom identification**
  - Standard implementation → Use library
  - Custom/variant → Custom code or low-level library
  - Decision tree: 0% custom = library, 20-50% = low-level, 50%+ = custom

- **Required user consultation**
  - Template: "Does this follow standard [X] rules exactly, or does it have custom mechanics?"
  - Add to HUMAN_NEEDED.md and WAIT for response
  - Document choice in ADR

- **Red flags (wrong library)**
  - Library enforces rules you don't need
  - Bypassing/disabling library features
  - User says "like X but with custom Y"
  - Documentation says "enforces standard X"

- **Examples by domain**
  - Games: Standard chess (use chess.js) vs. Chess variant (custom engine)
  - Card games: Standard poker (use library) vs. Custom game (custom code)
  - Protocols: Standard HTTP (use fetch) vs. Custom protocol (custom client)

**Benefits:**
- Prevents wasted time on wrong library choices
- Forces architectural discussion early
- Documents decision rationale in ADR
- Real-world failure example for learning

#### 2. Enhanced Research Mode

**Updated `workflows/research_mode.md` with library research requirements:**

- Added CRITICAL section on library selection research
- Must identify if library enforces standards/rules
- Must determine if project needs standard or custom implementation
- Required user consultation when unclear
- Document constraints and alternatives in ADR

**Prevents:**
- Choosing chess.js for chess variants
- Using poker libraries for custom card games
- Selecting protocol libraries for custom protocols
- Any standard library for non-standard implementations

#### 3. Agent Guidelines Updated

**Added to `agent_operating_guidelines.md`:**
- Link to `library_selection.md` as critical guideline
- Placed alongside smoke testing checklist
- Mandatory review before selecting libraries

### Changed

**CONTRIBUTIONS.md Updated:**
- Added "Real-World Usage & Critical Feedback" section
- Documented chess/Tetris hybrid game learnings
- Library selection gap analysis
- Smoke testing gap (from v0.4.2-v0.4.3)
- Template noise issues
- Updated version to v0.4.3

**Key Lessons Documented:**
1. "Works on my machine" ≠ Works (smoke testing)
2. Testability is architecture (Model-View separation)
3. Standard library ≠ Custom variant (chess.js failure)
4. Ask when unclear (user consultation required)
5. Clean templates matter (90% reduction in noise)

---

## [0.4.2] - 2025-01-05

### Added - Automatic Attribution & Clean Templates

**Improved developer experience with automatic attribution stamping and cleaner project initialization.**

#### 1. Automatic Attribution Stamping

**Agents now automatically inject subtle attribution stamps when creating production code:**
- Format: `Engineered with Agentic AF v{VERSION} by TSG, {YEAR}`
- Location: ONE file per project (main HTML/JS/Python entry point)
- Placement: Half-visible (HTML source comments, bundle comments)
- Timing: During initial file creation (silent, no user intervention)
- No build scripts required - just naturally part of the code agents write

**Examples:**
- Web apps: `<!-- Engineered with Agentic AF v0.4.2 by TSG, 2025 -->` in `index.html`
- Python CLI: `# Engineered with Agentic AF v0.4.2 by TSG, 2025` in `main.py`
- JS apps: `/* Engineered with Agentic AF v0.4.2 by TSG, 2025 */` in bundle

**Benefits:**
- Automatic, silent attribution (no developer action needed)
- Minimal and professional (one stamp per project)
- Framework visibility without cluttering code
- Token-efficient (no separate build process)

#### 2. Clean Root Templates

**Root project files now start clean, with examples moved to `.agentic/` for reference:**

**Before vs After:**
- `HUMAN_NEEDED.md`: 194 lines → 20 lines (90% reduction!)
- `JOURNAL.md`: 81 lines → 14 lines
- `FEATURES.md`: 59 lines → 25 lines

**Examples and guidelines now in `.agentic/spec/*.reference.md`:**
- `HUMAN_NEEDED.reference.md` - 4 example entries + agent/human guidelines
- `JOURNAL.reference.md` - format options + examples
- `FEATURES.reference.md` - complete format spec + examples

**Benefits:**
- New projects start clean (reflect actual state, not templates)
- No confusing example content in production files
- Examples available for reference when needed
- Better developer experience (less noise, clearer intent)

### Changed

**Agent Guidelines Updated:**
- Added "Build Artifact Stamping" section with automatic injection rules
- Root template references now link to `.agentic/spec/*.reference.md` for examples

**Template Structure:**
- Templates are now minimal with structure + reference links
- All examples, guidelines, and format docs in `.agentic/` for reference

---

## [0.4.1] - 2025-01-05

### Added - Enhanced Workflows, Design Systems, Validation Cache, Claude Commands

**Comprehensive framework enhancements for improved agent autonomy and developer experience.**

#### 1. Enhanced Workflows with Error Recovery

**TDD Mode (tdd_mode.md)**:
- 7 detailed error recovery scenarios
- Tests won't run, tests pass immediately, stuck in RED phase
- Refactoring breaks tests, too many tests failing, tests are slow
- Unclear requirements handling

**Proactive Agent Loop (proactive_agent_loop.md)**:
- Added preconditions, progress tracking, state contracts
- 9 error recovery scenarios for agent collaboration
- Can't find planned work, stale HUMAN_NEEDED items
- Unclear feature states, interrupted sessions
- Decision escalation guidelines, context window management
- Lost track handling, non-responsive human handling

**Feature Implementation Checklist (feature_implementation.md)**:
- 7 practical error recovery scenarios
- Tests failing, scope too large, unclear acceptance criteria
- Dependencies not ready, code getting messy
- Forgot to update tracking, quality checks failing

**Benefits**:
- More systematic agent behavior
- Self-checking prevents skipped steps
- Error recovery reduces escalations to humans
- Clear guidance for common problems

#### 2. Design System Templates

**New Directory**: `.agentic/support/design_systems/`

Three comprehensive design systems:
- **Modern Minimal**: Clean, Tailwind-inspired (web apps, dashboards, SaaS)
- **Material Design**: Google's Material Design 3 (Android apps, Google-style web)
- **iOS Human Interface**: Apple's HIG (iOS/macOS apps, elegant consumer products)

**Each includes**:
- Color palettes (with dark mode)
- Typography scales
- Spacing systems
- Component patterns
- Motion & animation guidelines
- Accessibility guidelines
- Code examples (React, SwiftUI, React Native)

**Benefits**:
- Consistent UI implementation
- Faster development (less design decisions)
- Professional, polished results
- Platform-appropriate designs

#### 3. Validation Cache

**New Tool**: `.agentic/tools/validation-cache.sh`

Cache validation results to avoid redundant checks:
- Time-based expiry (5 minutes)
- File-based invalidation (via hash)
- Speeds up `doctor.sh`, `verify.sh`, `validate_specs.py`
- Simple JSON-based storage

**Usage**:
```bash
# Check cache
bash .agentic/tools/validation-cache.sh check doctor

# Get cached results
bash .agentic/tools/validation-cache.sh get doctor

# Store results
bash .agentic/tools/validation-cache.sh set doctor "OK"
```

**Benefits**:
- Faster feedback loops
- Reduces redundant work
- Still catches real issues (smart invalidation)

#### 4. Claude Custom Commands (Optional)

**New Directory**: `.agentic/prompts/claude-commands/`

Optional slash commands for Claude Code users:
- `/start` - Start session with context loading
- `/continue` - Resume from .continue-here.md
- `/implement` - Implement feature with TDD
- `/end` - End session with documentation

**Benefits**:
- Better UX for Claude Code users
- User-friendly alternative to copy-paste prompts
- Falls back to regular prompts if not supported
- Easy to customize

### Changed - Documentation Updates

- Updated workflow files with error recovery sections
- Added design systems README and usage guide
- Documented validation cache in tool comments

---

## [0.4.0] - 2025-01-05

### Added - Session Continuity & Claude Hooks

**Major UX improvements for session management and Claude Code integration.**

#### 1. Session Continuity Tool (`continue_here.py`)

**New Tool**: `.agentic/tools/continue_here.py`

Generates `.continue-here.md` - a single-file snapshot for instant context recovery:
- Synthesizes: JOURNAL.md, STATUS.md/OVERVIEW.md, HUMAN_NEEDED.md, FEATURES.md, pipeline files
- Output: Quick summary, active work, blockers, recent progress, next steps
- Works in both Core and Core+PM modes
- Auto-detects project profile

**Benefits**:
- Instant context recovery after breaks or context resets
- Read 1 file instead of 5+ files
- Lower cognitive load for humans and AI agents
- Perfect handoff between sessions

**Usage**:
```bash
python3 .agentic/tools/continue_here.py
# Then read .continue-here.md at start of next session
```

#### 2. Ready-to-Use AI Prompts

**New Directories**: `.agentic/prompts/cursor/` and `.agentic/prompts/claude/`

13 copy-paste workflow prompts for common tasks:
- **Session Management**: `session_start.md`, `session_end.md`
- **Feature Development**: `feature_start.md`, `feature_test.md`, `feature_complete.md` (TDD workflow)
- **Spec Management**: `migration_create.md`, `spec_update.md` (Core+PM mode)
- **Core Mode**: `product_update.md`, `quick_feature.md`
- **Quality & Maintenance**: `run_quality.md`, `fix_issues.md`, `retrospective.md`
- **Research & Planning**: `research.md`, `plan_feature.md`

**Claude-Specific Features Documented**:
- Artifacts (interactive previews)
- Projects (persistent context)
- Extended Thinking mode
- Hooks integration

**Benefits**:
- Eliminate prompt engineering - just copy and paste
- Consistent agent behavior across sessions
- Lower barrier to entry for new users
- Claude users get platform-specific guidance

#### 3. Claude Code Lifecycle Hooks

**New Directory**: `.agentic/claude-hooks/`

Automated scripts that run at key lifecycle points in Claude Code:

**Hooks**:
1. **`SessionStart.sh`**: Environment validation, project status, detect `.continue-here.md`
2. **`UserPromptSubmit.sh`**: Auto-inject `.continue-here.md` (ZERO-TOUCH context recovery!)
3. **`PostToolUse.sh`**: Real-time linter checks after code edits
4. **`PreCompact.sh`**: State preservation before context window compaction
5. **`Stop.sh`**: Session end reminders (commits, docs, context generation)

**Configuration**: `hooks.json` for Claude Code

**Benefits**:
- **Automatic context injection**: No manual "read .continue-here.md" needed
- **Real-time quality gates**: Catch syntax errors immediately after writing code
- **Never lose progress**: State automatically saved before context compaction
- **Better workflow discipline**: Reminders about commits and documentation
- **Seamless session continuity**: Perfect pairing with `continue_here.py`

**Requirements**: Claude Code with hooks enabled (check version compatibility)

**Documentation**: Complete setup, usage, and troubleshooting guide in `.agentic/claude-hooks/README.md`

#### 4. Pre-Project Ideation Template

**New Template**: `.agentic/init/VISION.template.md`

For capturing project vision before initialization:
- Problem & opportunity
- Vision & success criteria
- User scenarios
- Core principles
- Constraints & non-goals
- Technical direction
- Open questions

**Benefits**:
- Better alignment before implementation
- Clear "why" documented upfront
- Informs PRD and feature specs
- Reduces scope creep

### Changed - Documentation Updates

**Updated Files**:
- `README.md`: Reference new prompts and tools
- `START_HERE.md`: Mention `.continue-here.md` and prompts in session start
- `DEVELOPER_GUIDE.md`: Document `continue_here.py`, prompt library, Claude hooks
- `.agentic/README.md`: Add continue_here.py and migration.sh to tools list
- `prompts/claude/README.md`: Add hooks documentation and setup guide

---

## [0.3.4] - 2026-01-04

### Fixed - Upgrade Script Path Bug

**Problem**: `upgrade.sh` checked for old `agentic/` folder instead of new `.agentic/` folder (hidden directory with dot prefix)

**Impact**: Upgrade tool failed on all projects with error:
```
✗ Error: No '.agentic/' folder found in target project
  Target: /path/to/project/agentic
```

**Root Cause**: Three hardcoded references to old `agentic` path:
- Line 50: Check for target project `.agentic/` folder
- Line 66: Check for new framework `.agentic/` folder  
- Line 112: Backup command

**Fixed**:
- Changed all `agentic` references to `.agentic` (with dot)
- Upgrade tool now correctly detects hidden `.agentic/` directory
- Backup, rollback, and all operations now work correctly

**Credit**: Discovered by Tomas during upgrade of `passive-income-solution1` project

**Testing**:
```bash
# Should now work
./upgrade.sh /Users/tomas/code/passive-income-solution1
```

---

## [0.3.3] - 2026-01-04

### Added - Minimal Test Suite (Cobbler's Children Now Have Shoes!)

**Problem**: Framework had no tests validating core claims - "the cobbler's children have no shoes"

**Solution**: Added minimal test suite appropriate for POC/discovery phase (no overengineering)

**New Tests**:
- `tests/test_query_features.py` (6 tests, no dependencies)
  - Parse features from markdown
  - Filter by status, tags, layer, owner
  - Combine multiple filters
  - **Validates**: Query tool works for 200+ feature projects
  
- `tests/test_validate_specs.py` (7 tests, optional dependencies)
  - Detect circular dependencies (F-0001 → F-0002 → F-0001)
  - Detect self-dependencies
  - Detect invalid parent references
  - Detect invalid dependency references
  - **Validates**: Pre-commit validation catches errors
  - Graceful skip if dependencies not installed

**Test Infrastructure**:
- `tests/fixtures/sample_features.md` - 5 sample features for testing
- `tests/run_tests.sh` - Simple runner (no pytest needed)
- `tests/README.md` - Philosophy and guide

**Philosophy** (POC-appropriate):
- ✅ Minimal: No pytest, no coverage, no CI (yet)
- ✅ Focused: Test core claims only
- ✅ Fast: <5 seconds to run
- ✅ Simple: Pure Python, easy to understand
- ✅ Graceful: Skips tests if dependencies missing
- ✅ Easy: `bash tests/run_tests.sh`

**What We DON'T Test** (intentionally):
- Full pytest suite (overkill for POC)
- Coverage metrics (premature)
- Integration tests (not needed yet)
- Performance benchmarks (later)
- All edge cases (test what matters)

### Documentation
- `docs/SELF_APPLICATION_PLAN.md` - Analysis of "cobbler's children" problem
- `tests/README.md` - Test philosophy and guide

### Impact
✅ Core claims validated by tests
✅ Tests catch regressions in tools
✅ Dogfooding: Using framework principles on framework itself
✅ Confidence: Tools actually work as claimed

**The cobbler's children now have shoes (at least sandals)!** 👞

## [0.3.2] - 2026-01-04

### Added - Agent Tool Awareness

**Critical Update**: Agents now know HOW and WHEN to use scalability tools efficiently.

Added comprehensive guidance to `agent_operating_guidelines.md`:

**Efficient Tool Usage (Core+Product Mode)**:
1. **Finding Features Quickly**: Use `query_features.py` instead of grep (50+ features)
   - Filter by status, tags, owner, layer
   - Get counts and distributions
2. **Updating Multiple Features**: Use `bulk_update.py` for mass operations
   - Assign owners across features
   - Set priorities by domain/layer
   - Add/remove tags in bulk
3. **Understanding Dependencies**: Use `feature_graph.py` with filters
   - Focus mode for single feature + neighbors
   - Filtered views by layer/status
   - Hierarchy-only mode
4. **Project Health Metrics**: Use `feature_stats.py` periodically
   - Before retrospectives
   - When summarizing progress
5. **Validation**: Always run `validate_specs.py` before commits
   - Pre-commit hook does this automatically
6. **Hierarchical Migration**: Suggest when beneficial
   - 200-500 features: Consider
   - 500+ features: Recommend
   - Show preview with `--dry-run` first

**Agent Behavioral Changes**:
- ✅ Use tools, not grep for feature searches
- ✅ Bulk operations instead of manual edits
- ✅ Generate focused dependency graphs
- ✅ Monitor health metrics periodically
- ✅ Suggest hierarchical layout when project grows
- ✅ Validate before every commit

### Impact
Agents now work **efficiently** with 200-1000+ feature projects instead of inefficiently reading/editing large files manually.

## [0.3.1] - 2026-01-04

### Added - Phase 2 & 3 Spec Scalability Complete (500+ and 1000+ Features)

**Phase 2: Hierarchical Organization (500+ features)**

New Tools:
- `organize_features.py`: Migrate from flat to hierarchical layout
  - Organize by domain or layer
  - Auto-generates `_index.md` master index
  - Preview with `--dry-run`
  - Creates `spec/features/domain/*.md` structure
- `bulk_update.py`: Mass feature updates
  - Update multiple features at once
  - Filter by status, tags, layer, domain, owner
  - Add/remove tags in bulk
  - Set fields across many features
  - Safety: preview changes, confirmation prompt

**Phase 3: Advanced Analytics (1000+ features)**

New Tools:
- `feature_stats.py`: Comprehensive statistics dashboard
  - Distribution by status, layer, domain, priority, complexity
  - Top tags analysis
  - Owner distribution
  - Health metrics (shipped vs accepted, velocity)
  - Features per week calculation
- `upgrade_spec_format.py`: Spec format version management
  - Detects format version markers
  - Upgrades specs to latest format
  - Safe migrations with `--dry-run`
  - Enables reliable framework upgrades

**Enhanced Existing Tools**:
- `query_features.py`: Now supports hierarchical layout (auto-detects)
- `feature_graph.py`: Now supports hierarchical layout (auto-detects)
- `validate_specs.py`: Validates both flat and hierarchical layouts

**Spec Format Versioning**:
- Added `<!-- spec-format: features-v0.3.1 -->` markers to all spec templates
- Enables reliable upgrades when framework evolves
- `upgrade_spec_format.py` tool manages migrations

**Documentation**:
- Updated `SPEC_SCALABILITY_PLAN.md`: All 3 phases complete
- Added migration recommendations (when to use flat vs hierarchical)
- Added tool ecosystem guide
- Added maintenance & best practices

### Changed
- All feature tools now support both flat (`spec/FEATURES.md`) and hierarchical (`spec/features/*/*.md`) layouts
- Tools auto-detect layout, no configuration needed

### Impact
- ✅ Handle 1000+ features smoothly (all phases complete)
- ✅ Query time <3s even with 1000+ features  
- ✅ Hierarchical organization for 500+ features
- ✅ Bulk updates save massive manual work
- ✅ Statistics dashboard for project insights
- ✅ Format versioning for safe framework upgrades
- ✅ Graceful migration path (opt-in hierarchical)
- ✅ Backward compatible (flat layout still works perfectly)

### Migration Guide

**For existing v0.3.0 projects**:
- All tools continue to work with flat `FEATURES.md`
- No changes required
- Optionally migrate to hierarchical: `python .agentic/tools/organize_features.py`
- Optionally add format markers: `python .agentic/tools/upgrade_spec_format.py`

**When to migrate to hierarchical**:
- 0-200 features: Stay flat (simpler)
- 200-500 features: Optional (team preference)
- 500+ features: Recommended (better organization)

## [0.3.0] - 2026-01-04

### Added - Phase 1 Spec Scalability (Critical for 200+ Features)

**New Tools:**
- `query_features.py`: Fast feature filtering by status, tags, layer, domain, priority, owner
  - Essential for finding features in large projects
  - Count features by category
  - Sub-second performance even with 500+ features
- Enhanced `feature_graph.py`: Filterable dependency graphs
  - `--focus` mode: show single feature + neighbors
  - `--layer`, `--tags`, `--status` filters
  - `--hierarchy-only` mode for parent-child relationships
  - Prevents massive unreadable diagrams
- Enhanced `validate_specs.py`: Circular dependency detection
  - DFS-based cycle detection (catches F-0001 → F-0002 → F-0001)
  - Cross-reference validation (parent/dependencies exist)
- `hooks/pre-commit`: Pre-commit hook for spec validation
  - Auto-installed by `scaffold.sh` (Core+PM mode)
  - Catches errors before commit

**New Feature Metadata Fields (v0.3.0+):**
- `Tags`: `[auth, ui, critical]` for categorization/search
- `Layer`: `presentation | business-logic | data | infrastructure | other`
- `Domain`: `auth`, `payments`, `content`, etc.
- `Priority`: `critical | high | medium | low`
- `Owner`: email or username
- All fields optional, backward compatible

**Documentation:**
- `docs/SPEC_SCALABILITY_PLAN.md`: Comprehensive 3-phase plan (200/500/1000+ features)
- Updated `DEVELOPER_GUIDE.md`: New tools with examples
- Updated `SPEC_SCHEMA.md`: Documented new fields
- Updated `FEATURES.template.md`: Added new optional fields

### Fixed
- `scaffold.sh`: Now installs pre-commit hook for Core+PM mode

### Impact
- ✅ Handle 200+ features smoothly (Phase 1 complete)
- ✅ Fast queries (<1 second with 500 features)
- ✅ Focused graphs (no unreadable massive diagrams)
- ✅ Catch circular dependencies automatically
- ✅ Better organization (tags, layers, domains)
- 📋 Phase 2 planned: Hierarchical file organization for 500+ features
- 📋 Phase 3 planned: Statistics dashboard for 1000+ features

## [0.2.5] - 2026-01-03

### Added

**Documentation:**
- **PRINCIPLES.md** - Comprehensive framework constitution documenting all 60+ principles
  - Core philosophy (sustainable development, human-agent partnership, context efficiency)
  - Token economics principles (4 detailed principles)
  - Quality & testing principles (6 principles including "Shipped ≠ Accepted")
  - Human-agent collaboration principles (4 principles)
  - Documentation & maintenance principles (5 principles)
  - Modularity & flexibility principles (4 principles)
  - 10 anti-patterns with explanations
  - Each principle has: What, Why, How Enforced, Example, Anti-pattern
  - Linked from README, START_HERE, agent_operating_guidelines

- **FRAMEWORK_DEVELOPMENT.md** - Complete guide for contributors working on the framework itself
  - 12 comprehensive sections covering framework-specific responsibilities
  - Maintain internal consistency (templates, examples, docs)
  - Example projects as first-class citizens
  - Documentation single source of truth enforcement
  - Test framework changes in scratch projects
  - Version management (SemVer, CHANGELOG, releases)
  - Template changes and backward compatibility
  - Quality standards apply to framework itself
  - Git workflow and commit conventions
  - Complete release checklist
  - Common development patterns and quick reference
  - 8 framework development anti-patterns
  - Comparison table: project dev vs. framework dev

### Changed

**Clarifications:**
- `agent_operating_guidelines.md` now explicitly states it's for "projects using framework"
- Clear distinction between project guidelines vs. framework development guidelines
- Added cross-references between the two guideline documents
- Removed ambiguity about "working in this repo"

### Impact

- Framework values and principles are now explicitly documented and won't be lost
- Contributors have clear guidelines for framework development
- Agents know which rules apply in which context (project vs. framework work)
- All implicit principles from development discussions are now captured

## [0.1.0] - 2026-01-02

### Added (Initial Release)

**Core Framework:**
- Agent operating guidelines for consistent AI behavior
- Durable artifacts for token efficiency (CONTEXT_PACK, STATUS, JOURNAL)
- Specification system (PRD, Tech Spec, Features, NFR, ADR, Tasks)
- Feature tracking with stable IDs (F-####) and acceptance criteria
- Test-Driven Development (TDD) as recommended default mode
- Definition of done and quality review checklists

**Advanced Features:**
- Session continuity across context resets (JOURNAL.md)
- Feature dependency tracking with visualization
- Human escalation protocol (HUMAN_NEEDED.md)
- Architecture evolution tracking
- Research trails and structured research mode
- Automated retrospectives for project health checks
- Documentation verification to ensure up-to-date API usage
- Spec format validation with YAML frontmatter (optional)
- Continuous quality validation with stack-specific profiles
- Multi-agent coordination with Git worktrees
- PR workflow mode for team collaboration

**Tools (27 scripts):**
- Project health: `doctor.py`, `report.py`, `verify.sh`, `validate_specs.py`
- Context & analysis: `brief.sh`, `dashboard.sh`, `coverage.sh`, `feature_graph.sh`
- Manual operations: `search.sh`, `whatchanged.sh`, `deps.sh`, `accept.sh`
- Quality: `consistency.sh`, `stale.sh`, `retro_check.sh`, `version_check.sh`
- Development: `task.sh`, `sync_docs.sh`, `arch_diff.sh`

**Quality Profiles:**
- Web applications (bundle size, Lighthouse, accessibility)
- Mobile apps (iOS, Android - battery, memory, UI performance)
- Backend services (load testing, connection pools, queries)
- Desktop applications (Qt, Electron, native - UI responsiveness, cross-platform)
- CLI/Server tools (long-running, signal handling, resource cleanup)
- Games (2D, Unity, Unreal - FPS, physics, assets)
- Audio plugins (JUCE - pluginval, DSP validation, realtime CPU/glitch detection)
- Specialized (security, network, embedded/IoT, ML)

**Documentation:**
- Comprehensive README with design principles
- START_HERE guide for quick navigation
- FRAMEWORK_MAP with visual diagram
- MANUAL_OPERATIONS for token-free queries
- DIRECT_EDITING workflow for human spec editing
- 40+ workflow and guideline documents

**Stack Profiles:**
- Generic/default, Webapp fullstack, Native iOS
- Go backend, Python ML, Rust systems, React Native

### Features by Category

**Token Economics:**
- Structured reading protocols with explicit budgets
- Context budgeting strategies
- Durable artifacts prevent repeated repo scanning

**Developer UX:**
- Agent does all initialization (no manual script running)
- Clear status at all times
- Human review required before commits (no auto-commit)
- Direct spec editing by humans (agents pick up changes)

**Quality by Design:**
- TDD recommended (tests first)
- Stack-specific quality gates
- Mandatory tests for new/changed logic
- Design for testability guidelines

**Traceability:**
- Code annotations link code to features (`@feature F-####`)
- Bidirectional linking (specs → code → tests)
- Test coverage tracking per feature

**Team Collaboration:**
- Git workflow modes (direct commits or pull requests)
- Multi-agent coordination with worktrees
- AGENTS_ACTIVE.md for coordination
- File lock protocol to prevent conflicts

## [0.2.4] - 2026-01-03

### Added
- **DEVELOPER_GUIDE.md**: Comprehensive 1,500+ line guide for developers
  - Daily workflows (morning, during, evening routines)
  - Manual operations vs. agent operations
  - All 30+ automation scripts explained with examples and "when to run"
  - Customization guide (profiles, STACK.md, quality checks, custom scripts)
  - Troubleshooting section with 10 common problems and fixes
  - Best practices for sustainable development
  - Advanced topics (sequential pipeline, multi-agent, mutation testing)
  - Quick reference tables and commands

### Improved
- **agent_operating_guidelines.md**: Critical improvements to prevent documentation gaps
  - Added CRITICAL rule: Acceptance file mandatory when creating features
  - Added CRITICAL workflow: Clear "shipped" vs "accepted" status distinction
  - Added CRITICAL rule: Never leave `Implementation: State: none` if code exists
  - Improved FEATURES.md sync instructions with explicit checks
  - Better guidance on when to mark features as shipped/accepted

### Changed
- **Documentation structure**: DEVELOPER_GUIDE now primary entry point for new users
  - Updated START_HERE.md to link DEVELOPER_GUIDE first (⭐⭐⭐)
  - Updated .agentic/README.md to prominently link DEVELOPER_GUIDE
  - Updated main README.md with quick links section
- **Profile selection UX**: Added a/b choice format in init_playbook.md for easier selection

### Context
This release addresses issues found in real-world usage:
- Missing acceptance criteria files (now mandatory via agent guidelines)
- Features marked "shipped" but never formally accepted (now clear workflow)
- Implementation state "none" despite code existing (now explicitly checked)
- Documentation completeness (comprehensive DEVELOPER_GUIDE created)

## [0.2.3] - 2026-01-02

### Fixed
- **install.sh now makes scripts executable**: After copying `.agentic/` folder, the install script now runs `chmod +x` on all scripts to ensure they work immediately
- Fixed `scaffold.sh not found or not executable` error during installation

## [0.2.2] - 2026-01-02

### Changed
- **Branding update**: Framework now officially named "Agentic AI Framework" (shortname: Agentic AF)
- **Documentation overhaul**: All references updated to reflect current version (v0.2.2) and GitHub org (tomgun)
- Replaced all `YOUR_USERNAME` placeholders with `tomgun`
- Updated all installation and upgrade instructions
- Fixed `.agentic/` folder references throughout documentation

### Fixed
- README.md installation section now uses `install.sh`
- `.agentic/README.md` now has accurate v0.2.2 installation instructions
- UPGRADING.md completely updated with correct paths and version
- RELEASING.md examples now reference v0.2.2
- Example projects updated with correct framework version

## [0.2.1] - 2026-01-02

### Added
- **Installation script** (`install.sh`) for automated framework setup
  - Reads VERSION from framework repo
  - Copies `.agentic/` to target project
  - Updates `STACK.md` with framework version and install date
  - Shows clear next steps for agent initialization

### Changed
- **Profile selection moved to agent interview** (UX improvement)
  - Profile choice now part of `init_playbook.md` workflow
  - Agent explains Core vs Core+PM differences
  - Users make informed choice during initialization
  - Removed `--profile` argument from `install.sh` (simpler)
- **Upgrade script improvements**
  - Now reads VERSION from new framework and updates `STACK.md`
  - Fixed references from `agentic/` to `.agentic/`
- **Documentation improvements**
  - README.md updated with clearer installation instructions
  - Explicit reference to `init_playbook.md` for agent guidance
  - Removed confusion about when initialization is complete

### Fixed
- `STACK.template.md` version updated to 0.2.0 (was 0.1.0)
- Framework version now properly tracked in production projects

## [0.2.0] - 2026-01-02

### Added

**Modular Framework Profiles:**
- Two profiles: "Core" (minimal) and "Core + Product Management" (full specs)
- Core includes: quality standards, workflows, multi-agent, research, OVERVIEW.md
- Core+PM adds: formal specs, feature tracking (F-####), STATUS.md, project metrics
- Profile-aware agents adapt behavior based on STACK.md profile field
- Easy upgrade path: `enable-product-management.sh` converts Core → Core+PM

**Hidden Framework Internals:**
- Moved `agentic/` → `.agentic/` for cleaner project root
- Framework files hidden, product files (STACK.md, STATUS.md, spec/, docs/) visible
- Optimized for agent efficiency and developer clarity

**OVERVIEW.md (New Core File):**
- Lightweight planning document for Core mode
- Captures: what we're building, capabilities (checkboxes), technical approach, scope
- Serves as basis for formal specs when upgrading to Core+PM
- Agents update it as work progresses

**Programming & Testing Standards:**
- Comprehensive programming guidelines (naming, functions, error handling, security, performance, green coding)
- Detailed testing standards (happy path, edge cases, invalid input, time-based, concurrency, resource exhaustion, network failures)
- TDD remains recommended default approach
- Standards linked prominently in README files

**Mutation Testing (Optional):**
- Added mutation testing as advanced quality check
- Documentation in `test_strategy.md`
- Helper script: `mutation_test.sh` (auto-detects stack)
- Guidance on when to use (critical logic, suspicious coverage, post-bug-fix)
- Integration with quality profiles

**Framework Upgrade Mechanism:**
- `UPGRADING.md` guide with step-by-step instructions
- `upgrade.sh` tool runs from new framework download (ensures latest logic)
- Safe upgrade path: backup → update internals → preserve customizations
- Validates before/after with doctor.py

**Examples (Complete Rewrite):**
- `core_todo_cli/` - Python CLI demonstrating Core profile
- `core_pm_taskboard/` - Next.js app demonstrating Core+PM profile
- Realistic mid-development state (not empty templates)
- Full validation: all tools pass (doctor, verify, report)
- Comprehensive README with profile comparison table

**Documentation Improvements:**
- Updated all READMEs to reflect Core vs Core+PM modes
- Added programming/testing standards to prominent locations
- Clear upgrade instructions
- Examples show both profiles in action

### Changed
- `agentic/` directory renamed to `.agentic/` (breaking change, but simple rename)
- Agents now profile-aware (check `Profile:` in STACK.md)
- `scaffold.sh` accepts `--profile` argument
- `doctor.py` and `verify.py` are profile-aware (skip PM checks in Core mode)
- `report.py` and `accept.py` degrade gracefully if PM features disabled

### Fixed
- PM templates no longer contain concrete example IDs (F-0001, NFR-0001) that caused verify failures
- Core mode agents now work efficiently (don't try to read non-existent STATUS.md/spec/)
- `enable-product-management.sh` detects OVERVIEW.md and provides conversion guidance

## [Unreleased]

### Planned
- npm package (optional install method)
- Homebrew formula (optional install method)
- More stack-specific quality profiles
- Enhanced dependency analysis
- Automated architecture documentation
- Framework version compatibility checks

---

## Version Numbering

This project follows [Semantic Versioning](https://semver.org/):
- **MAJOR** version: Breaking changes (requires migration)
- **MINOR** version: New features (backward compatible)
- **PATCH** version: Bug fixes (backward compatible)

## Download

Get the latest release: https://github.com/tomgun/agentic-framework/releases

```bash
# Download and extract
curl -L https://github.com/tomgun/agentic-framework/archive/refs/tags/v0.2.1.tar.gz | tar xz

# Install (recommended)
cd agentic-framework-0.2.1
bash install.sh /path/to/your-project

# Or copy manually
cp -r agentic-framework-0.2.1/.agentic /path/to/your-project/
```

