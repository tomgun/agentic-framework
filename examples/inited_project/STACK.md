# STACK.md

Purpose: a single source of truth for "how we build and run software here".

## Agentic framework
- Version: 0.1.0
- Installed: 2026-01-02
- Source: https://github.com/tomgun/agentic-framework

## Summary
- What are we building: A simple task management CLI tool (example project)
- Primary platform: cli

## Languages & runtimes
- Language(s): Python
- Runtime(s): Python 3.12
- Specific versions: Python 3.12.1

## Frameworks & libraries
- App framework: None (pure Python CLI)
- UI framework (if any): N/A

## Documentation verification (recommended)
- doc_verification: manual
- strict_version_matching: yes

## Tooling
- Package manager: pip
- Formatting/linting: ruff

## Testing (required)
- Unit test framework: pytest
- Integration/E2E (optional): N/A
- Test commands:
  - Unit: `pytest`
  - Integration: `N/A`
  - E2E: `N/A`

## Development approach (optional)
- development_mode: tdd  <!-- RECOMMENDED for most projects -->

## Git workflow (required)
- git_workflow: direct  <!-- direct | pull_request -->

## Multi-agent coordination (optional)
- multi_agent_enabled: no

## Data & integrations
- Primary datastore: JSON file (tasks.json)
- Messaging/queues (if any): N/A
- External integrations: None

## Deployment
- Target environment: local
- CI: GitHub Actions (optional)
- Release strategy: manual

## Constraints & non-negotiables
- Security/compliance: None (local tool)
- Performance: Fast for small task lists (<1000 tasks)
- Reliability: Data persisted to disk

## Quality validation (recommended)
- quality_checks: enabled
- profile: generic_default
- pre_commit_hook: no
- run_command: bash quality_checks.sh --pre-commit
- full_suite_command: bash quality_checks.sh --full
