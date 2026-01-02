# STACK.md

<!-- format: stack-v0.1.0 -->

Purpose: a single source of truth for "how we build and run software here".

## Agentic framework
- Version: 0.2.0
- Profile: core  # core | core+product
- Installed: 2026-01-02
- Framework location: .agentic/

## Summary
- What are we building: Command-line todo manager for developers
- Primary platform: CLI tool (cross-platform)

## Languages & runtimes
- Language(s): Python
- Runtime(s): Python 3.12+
- Specific versions: Python 3.12.1

## Frameworks & libraries
- CLI framework: argparse (built-in)
- Terminal colors: colorama (optional dependency)
- Storage: JSON (built-in)

## Tooling
- Package manager: pip
- Formatting/linting: black, ruff
- Type checking: mypy

## Testing (required)
- Unit test framework: pytest
- Integration/E2E (optional): pytest
- Test commands:
  - Unit: `pytest tests/ -v`
  - Integration: `pytest tests/integration/ -v`

## Development approach (optional)
- development_mode: tdd  # RECOMMENDED for most projects

## Git workflow (required)
- git_workflow: direct  # direct | pull_request

## Data & integrations
- Primary datastore: JSON file at ~/.local/share/todo-cli/todos.json
- No external integrations

## Deployment
- Target environment: local CLI installation
- Distribution: pip install (future), or direct Python script
- Entry point: `python -m todo_cli` or `todo` (if installed)

## Constraints & non-negotiables
- No external dependencies for core functionality (colorama is optional)
- Cross-platform (Linux, macOS, Windows)
- Fast startup (<100ms)
- Human-readable storage format (JSON)
