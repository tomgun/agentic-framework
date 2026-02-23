# STACK.md (Template)

<!-- format: stack-v0.1.0 -->

Purpose: a single source of truth for "how we build and run software here".

## Agentic framework
- Version: 0.19.0  <!-- Update when upgrading framework -->
- Installed: <!-- YYYY-MM-DD -->
- Source: https://github.com/tomgun/agentic-framework

## Settings
<!-- Use `ag set <key> <value>` to change, `ag set --show` to view all. -->
- profile: discovery
<!-- discovery | formal -->

### Workflow
- feature_tracking: no
# F-XXXX tracking, acceptance criteria gates. Profile defaults — Discovery: no | Formal: yes
- acceptance_criteria: recommended
# Require criteria before coding. Profile defaults — Discovery: recommended | Formal: blocking
- wip_before_commit: warning
# WIP.md required before commit. Profile defaults — Discovery: warning | Formal: blocking
- pre_commit_checks: fast
# Pre-commit gate depth. Profile defaults — Discovery: fast | Formal: full
- pre_commit_hook: fast
# Git hook dispatch mode. Profile defaults — Discovery: fast | Formal: fast
- git_workflow: direct
# Commit policy for main branch. Profile defaults — Discovery: direct | Formal: pull_request
- plan_review_enabled: no
# Review plan before implementation. Profile defaults — Discovery: no | Formal: yes
- spec_directory: no
# Create spec/ directory for features. Profile defaults — Discovery: no | Formal: yes
- docs_gate: off
# Doc staleness check at ag done. Profile defaults — Discovery: off | Formal: blocking

### Complexity limits
- max_files_per_commit: 15
# Blocking limit in pre-commit. Profile defaults — Discovery: 15 | Formal: 10
- max_added_lines: 1000
# Blocking limit for added lines. Profile defaults — Discovery: 1000 | Formal: 500
- max_code_file_length: 1000
# Blocking limit for single file length. Profile defaults — Discovery: 1000 | Formal: 500

## Summary
- What are we building: <!-- 1–2 sentences -->
- Primary platform: <!-- web/service/mobile/desktop/cli -->

## Languages & runtimes
- Language(s): <!-- e.g., TypeScript, Python, Go -->
- Runtime(s): <!-- e.g., Node 22, Python 3.12 -->
- Specific versions: <!-- e.g., TypeScript 5.3.3, Python 3.12.1 -->
  <!-- IMPORTANT: Agents use these exact versions to verify documentation -->

## Frameworks & libraries
- App framework: <!-- e.g., Next.js, FastAPI, Gin -->
- UI framework (if any): <!-- e.g., React, Svelte -->
- Specific versions: <!-- e.g., Next.js 15.1.0, React 19.0.0 -->
  <!-- IMPORTANT: List exact versions so agents can verify API docs -->

## Documentation verification (recommended)
<!-- Ensures agents use current, version-correct documentation -->
<!-- See: .agentic/workflows/documentation_verification.md -->
<!-- - doc_verification: context7-mcp  # context7-mcp | web-search | manual | none -->
<!-- - context7_mcp: enabled          # Requires MCP server config in IDE -->
<!-- - strict_version_matching: yes -->
<!-- MCP setup: Add to .cursor/mcp.json or claude_desktop_config.json: -->
<!-- { "mcpServers": { "context7": { "command": "npx", "args": ["-y", "@upstash/context7-mcp@latest"] } } } -->

## Documentation sources (for verification)
<!-- Agents verify these sources match STACK versions -->
<!-- Example: -->
<!-- - Next.js: https://nextjs.org/docs (version selector: v15.1) -->
<!-- - React: https://react.dev (v19) -->

## Tooling
- Package manager: <!-- npm/pnpm/yarn/uv/pip/poetry/go -->
- Formatting/linting: <!-- black/ruff/eslint/prettier/gofmt/etc -->

## License

- **Project License**: [MIT / Apache 2.0 / GPL-3.0 / AGPL-3.0 / Proprietary]
- **License File**: `LICENSE`
- **Copyright**: [Year] [Your Name / Organization]
- **Compatible Dependencies**: [e.g., MIT, Apache 2.0, BSD, LGPL (dynamic linking)]
- **Incompatible Dependencies**: [e.g., GPL, AGPL - agent must avoid these!]
- **Asset Licensing**: See `assets/ATTRIBUTION.md` for all external assets and their licenses

**Note**: Agents MUST check dependency and asset licenses for compatibility before using!

---

## Testing (required)
- Unit test framework: <!-- e.g., pytest, vitest, go test -->
- Integration/E2E (optional): <!-- e.g., playwright, cypress -->
- Test commands:
  - Unit: `<!-- fill -->`
  - Integration: `<!-- fill or N/A -->`
  - E2E: `<!-- fill or N/A -->`

## Development approach (optional)
<!-- Choose development workflow mode -->
<!-- Standard mode (Acceptance-Driven, DEFAULT): -->
<!--   - AI implements feature, then tests verify acceptance criteria -->
<!--   - Specs evolve during implementation (discoveries are documented) -->
<!--   - Best for AI-generated code where large chunks work quickly -->
<!--   - See .agentic/workflows/spec_evolution.md -->
<!-- TDD mode (OPTIONAL): Tests written FIRST (red-green-refactor) -->
<!--   - Better for critical logic, refactoring, or if you prefer tests-first -->
<!--   - See .agentic/workflows/tdd_mode.md -->
- development_mode: standard  <!-- DEFAULT: Acceptance-Driven -->
<!-- - development_mode: tdd  # OPTIONAL: Tests-first approach -->

## Agent mode (quality vs cost tradeoff)
<!-- Controls model selection across all agent tasks -->
<!-- See: .agentic/workflows/agent_mode.md for full documentation -->
- agent_mode: balanced  <!-- premium | balanced | economy -->
  <!-- premium: Best quality. opus for planning/implementation/review, sonnet for search -->
  <!-- balanced: Good balance (DEFAULT). opus for planning, sonnet for implementation/review -->
  <!-- economy: Cost saving. sonnet for planning, haiku for everything else -->

## Model customization (optional)
<!-- Override default models for any task type. Uncomment and edit to customize. -->
<!-- Useful when: new models released, fine-tuning for your workflow, cost optimization -->
<!-- - models: -->
<!--     planning: opus        # Architecture, specs, critical decisions -->
<!--     implementation: sonnet # Writing production code -->
<!--     review: sonnet        # Code review, testing, refactoring -->
<!--     search: haiku         # Codebase exploration, finding files -->

## Plan-Review Loop
<!-- Iterative planning with critical review before implementation -->
<!-- See: .agentic/workflows/plan_review_loop.md -->
<!-- Note: plan_review_enabled is now in ## Settings (profile-aware) -->
- plan_review_max_iterations: 3  <!-- Max revisions before human escalation -->
- plan_review_auto_for: [planning]  <!-- planning | implement | both -->
  <!-- planning: Runs for ag plan commands -->
  <!-- implement: Also runs before ag implement if no approved plan exists -->
  <!-- both: Always runs for both commands -->
<!-- - plan_review_reviewer_model: same  # same | opus | sonnet (use same model as planner) -->

## Sequential agent pipeline (optional but RECOMMENDED)
<!-- Enables specialized agents to work sequentially on features for optimal context efficiency -->
<!-- See: .agentic/workflows/sequential_agent_specialization.md -->
<!-- See: .agentic/workflows/automatic_sequential_pipeline.md -->
- pipeline_enabled: no  <!-- yes | no (default: no) - Start with 'no', enable after reviewing workflow -->
- pipeline_mode: manual  <!-- manual | auto (default: manual) -->
  <!-- manual: Human explicitly invokes each agent ("Research Agent: investigate X") -->
  <!-- auto: Agents hand off automatically after completing their work -->
- pipeline_agents: standard  <!-- minimal | standard | full -->
  <!-- minimal: Planning → Implementation → Review → Git (skip research, tests, docs) -->
  <!-- standard: Research → Planning → Test → Impl → Review → Spec Update → Docs → Git -->
  <!-- full: + Debugging, Refactoring, Security, Performance agents as needed -->
- pipeline_handoff_approval: yes  <!-- yes | no (require human approval between agents) -->
  <!-- yes: Agent asks "Ready for [Next Agent]? (yes/no)" -->
  <!-- no: Agent automatically hands off (still requires approval for commits) -->
- pipeline_coordination_file: ..agentic/pipeline  <!-- Directory for pipeline state files -->

## Git workflow
<!-- How changes get into main branch. See .agentic/workflows/git_workflow.md -->
<!-- git_workflow setting is in ## Settings (profile-aware: Discovery→direct, Formal→pull_request) -->
<!-- Override: `ag set git_workflow direct` or `ag set git_workflow pull_request`                  -->
<!--                                                                           -->
<!-- pull_request: Feature branches + PRs (review before merge)                -->
<!--   - Pre-commit BLOCKS commits to main/master (use --no-verify for hotfix) -->
<!--   - Best for: teams, long-term projects, audit trails                     -->
<!--                                                                           -->
<!-- direct: Commit straight to main (faster, less ceremony)                   -->
<!--   - Best for: solo prototypes, fast iteration                             -->

<!-- Pull Request mode (DEFAULT for Formal, recommended): -->
<!--   - Agent creates feature branches for each feature -->
<!--   - Agent creates PRs after human approval -->
<!--   - Human reviews PR before merge -->
<!--   - Aligns with acceptance-driven workflow -->
<!-- PR settings: -->
<!-- - pr_draft_by_default: true  # Create draft PRs until complete -->
<!-- - pr_auto_request_review: true  # Auto-assign reviewers -->
<!-- - pr_require_ci_pass: true  # Wait for CI before suggesting merge -->
<!-- - pr_reviewers: ["github_username"]  # Reviewers to auto-assign -->

<!-- Direct mode (opt-in, better for solo prototyping): -->
<!--   - Agent commits directly to branch after human approval -->
<!--   - No PR creation, fast iteration -->
<!--   - Use: git_workflow: direct -->

## Multi-agent coordination (optional)
<!-- Multiple AI agents working simultaneously. See .agentic/workflows/multi_agent_coordination.md -->
<!-- - multi_agent_enabled: no  # yes | no -->
<!-- - multi_agent_orchestrator: cursor-main  # ID of orchestrator agent (optional) -->
<!-- - multi_agent_workers: -->
<!--     - id: cursor-agent-1 -->
<!--       worktree: /path/to/worktree-1 -->
<!--     - id: cursor-agent-2 -->
<!--       worktree: /path/to/worktree-2 -->
<!-- When enabled, agents use Git worktrees and coordinate via .agentic-state/AGENTS_ACTIVE.md -->

## Data & integrations
- Primary datastore: <!-- postgres/sqlite/mongo/redis/etc -->
- Messaging/queues (if any): <!-- kafka/sqs/rabbitmq/etc -->
- External integrations: <!-- bullet list -->

## Deployment
- Target environment: <!-- local/cloud/on-prem -->
- CI: <!-- GitHub Actions by default -->
- Release strategy: <!-- manual/semver/tags/etc -->

## Docs
<!-- Doc registry — declare what docs this project maintains.
     This section lives in STACK.md (project root) and survives .agentic/ upgrades.
     To add a doc: add a line here. No .agentic/ files need editing.
     Triggers: feature_done | pr | session | manual
     Note: pr-trigger docs only fire in formal profile (formal uses PRs).
     To fire on multiple triggers, add two entries with the same path.
     Types (built-in): changelog | readme | adr | lessons | architecture | runbook | tech-spec | custom -->
<!-- - doc: CHANGELOG.md          | changelog    | pr           -->
<!-- - doc: README.md             | readme       | pr           -->
<!-- - doc: docs/lessons.md       | lessons      | feature_done -->
<!-- - doc: docs/architecture.md  | architecture | feature_done -->
<!-- - doc: docs/adr/             | adr          | manual       -->

## Constraints & non-negotiables
- Security/compliance: <!-- PII, GDPR, etc -->
- Performance: <!-- latency, throughput -->
- Reliability: <!-- SLOs if known -->

## Retrospectives (optional)
<!-- Agent-led periodic project health checks. See .agentic/workflows/retrospective.md -->
<!-- Uncomment to enable: -->
<!-- - retrospective_enabled: yes -->
<!-- - retrospective_trigger: both  # time | features | both -->
<!-- - retrospective_interval_days: 14 -->
<!-- - retrospective_interval_features: 10 -->
<!-- - retrospective_depth: full  # full (with research) | quick (no research) -->

## Research mode (optional)
<!-- Deep investigation into specific topics. See .agentic/workflows/research_mode.md -->
<!-- Uncomment to enable proactive research suggestions: -->
<!-- - research_enabled: yes -->
<!-- - research_cadence: 90  # days between field update research -->
<!-- - research_depth: standard  # quick (30min) | standard (60min) | deep (90min) -->
<!-- - research_budget: 60  # default minutes per research session -->

## Quality validation (recommended)
<!-- Automated, stack-specific quality gates. See .agentic/workflows/continuous_quality_validation.md -->
<!-- Agents create this during init based on tech stack -->
<!-- - quality_checks: enabled -->
<!-- - profile: juce_audio_plugin  # or webapp_fullstack, ios_app, etc -->
<!-- Note: pre_commit_hook is now in ## Settings (use `ag set pre_commit_hook fast|full|no`) -->
<!-- - run_command: bash quality_checks.sh --pre-commit -->
<!-- - full_suite_command: bash quality_checks.sh --full -->

## Quality thresholds (stack-specific, optional)
<!-- Example for JUCE plugins: -->
<!-- - max_cpu_percent: 50 -->
<!-- - allow_nan_inf: no -->
<!-- - max_glitches: 0 -->
<!-- - max_latency_ms: 10 -->

<!-- Example for web apps: -->
<!-- - max_bundle_size_kb: 500 -->
<!-- - min_lighthouse_performance: 90 -->
<!-- - min_lighthouse_accessibility: 95 -->

<!-- Example for mobile apps: -->
<!-- - max_memory_mb: 150 -->
<!-- - max_battery_per_hour_percent: 5 -->
<!-- - max_fps_drops: 5 -->


