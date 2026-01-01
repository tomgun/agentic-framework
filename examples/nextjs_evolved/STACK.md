# STACK.md

Purpose: a single source of truth for "how we build and run software here".

## Agentic framework
- Version: 0.1.0
- Installed: 2025-12-15
- Source: https://github.com/tomgun/agentic-framework

## Summary
- What are we building: A task management web app (evolved example with retrospectives & research)
- Primary platform: webapp

## Languages & runtimes
- Language(s): TypeScript
- Runtime(s): Node 22
- Specific versions: TypeScript 5.7.2, Node 22.0.0

## Frameworks & libraries
- App framework: Next.js 15.1.0
- UI framework (if any): React 19.0.0
- Specific versions: Next.js 15.1.0, React 19.0.0

## Documentation verification (recommended)
- doc_verification: context7
- context7_enabled: yes
- context7_config: .context7.yml
- strict_version_matching: yes

## Tooling
- Package manager: npm
- Formatting/linting: ESLint, Prettier

## Testing (required)
- Unit test framework: Vitest
- Integration/E2E (optional): Playwright (planned)
- Test commands:
  - Unit: `npm test`
  - Integration: `npx playwright test` (when added)
  - E2E: `N/A`

## Development approach (optional)
- development_mode: tdd  <!-- RECOMMENDED for most projects -->

## Git workflow (required)
- git_workflow: pull_request  <!-- direct | pull_request -->

## PR settings (if git_workflow: pull_request):
- pr_draft_by_default: true
- pr_auto_request_review: true
- pr_require_ci_pass: true
- pr_reviewers: []

## Multi-agent coordination (optional)
- multi_agent_enabled: no

## Data & integrations
- Primary datastore: Browser localStorage (for demo)
- Messaging/queues (if any): N/A
- External integrations: None

## Deployment
- Target environment: Vercel
- CI: GitHub Actions
- Release strategy: Continuous deployment from main

## Constraints & non-negotiables
- Security/compliance: None (demo app)
- Performance: Lighthouse score >90
- Reliability: High availability on Vercel

## Retrospectives (optional)
- retrospective_enabled: yes
- retrospective_trigger: both  # time | features | both
- retrospective_interval_days: 14
- retrospective_interval_features: 5
- retrospective_depth: full  # full (with research) | quick (no research)

## Research mode (optional)
- research_enabled: yes
- research_cadence: 90  # days between field updates
- research_depth: standard  # quick | standard | deep
- research_budget: 60  # minutes per session

## Quality validation (recommended)
- quality_checks: enabled
- profile: webapp_fullstack
- pre_commit_hook: yes
- run_command: bash quality_checks.sh --pre-commit
- full_suite_command: bash quality_checks.sh --full

## Quality thresholds (stack-specific, optional)
- max_bundle_size_kb: 500
- min_lighthouse_performance: 90
- min_lighthouse_accessibility: 95
