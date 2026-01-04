# STACK.md (Template)

<!-- format: stack-v0.1.0 -->

Purpose: a single source of truth for "how we build and run software here".

## Agentic framework
- Version: 0.2.4  <!-- Update when upgrading framework -->
- Profile: core  <!-- core | core+product -->
- Installed: <!-- YYYY-MM-DD -->
- Source: https://github.com/tomgun/agentic-framework

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
<!-- - doc_verification: context7  # context7 | manual | none -->
<!-- - context7_enabled: yes -->
<!-- - context7_config: .context7.yml -->
<!-- - strict_version_matching: yes -->

## Documentation sources (for manual verification)
<!-- If not using Context7, agents must check these sources match STACK versions -->
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
<!-- TDD mode (RECOMMENDED): Tests written FIRST (red-green-refactor) -->
<!--   - Better token economics (smaller increments, less rework) -->
<!--   - Forces unit testability by design -->
<!--   - See .agentic/workflows/tdd_mode.md -->
<!-- Standard mode: Tests required but can come during/after implementation -->
<!--   - Use for exploration, prototyping, unclear requirements -->
- development_mode: tdd  <!-- RECOMMENDED for most projects -->
<!-- - development_mode: standard -->

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

## Git workflow (required)
<!-- How agents interact with Git. See .agentic/workflows/git_workflow.md -->
- git_workflow: direct  <!-- direct | pull_request -->

<!-- Direct mode: Commit directly to branch (solo developer, simple projects) -->
<!--   - Agent commits after human approval -->
<!--   - No PR creation -->
<!--   - Fast iteration -->

<!-- Pull Request mode: Create PRs for review (teams, collaborative projects) -->
<!--   - Agent creates feature branches -->
<!--   - Agent creates PRs after human approval -->
<!--   - Human or CI reviews before merge -->
<!-- PR settings (if git_workflow: pull_request): -->
<!-- - pr_draft_by_default: true  # Create draft PRs until complete -->
<!-- - pr_auto_request_review: true  # Auto-assign reviewers -->
<!-- - pr_require_ci_pass: true  # Wait for CI before suggesting merge -->
<!-- - pr_reviewers: ["github_username"]  # Reviewers to auto-assign -->

## Multi-agent coordination (optional)
<!-- Multiple AI agents working simultaneously. See .agentic/workflows/multi_agent_coordination.md -->
<!-- - multi_agent_enabled: no  # yes | no -->
<!-- - multi_agent_orchestrator: cursor-main  # ID of orchestrator agent (optional) -->
<!-- - multi_agent_workers: -->
<!--     - id: cursor-agent-1 -->
<!--       worktree: /path/to/worktree-1 -->
<!--     - id: cursor-agent-2 -->
<!--       worktree: /path/to/worktree-2 -->
<!-- When enabled, agents use Git worktrees and coordinate via AGENTS_ACTIVE.md -->

## Data & integrations
- Primary datastore: <!-- postgres/sqlite/mongo/redis/etc -->
- Messaging/queues (if any): <!-- kafka/sqs/rabbitmq/etc -->
- External integrations: <!-- bullet list -->

## Deployment
- Target environment: <!-- local/cloud/on-prem -->
- CI: <!-- GitHub Actions by default -->
- Release strategy: <!-- manual/semver/tags/etc -->

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
<!-- - pre_commit_hook: yes -->
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


