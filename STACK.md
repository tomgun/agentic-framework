# STACK.md - Agentic Framework

<!-- format: stack-v0.1.0 -->

Purpose: Configuration for developing the Agentic Framework itself.

## Agentic framework
- Version: 0.12.0
- Profile: core+pm
- This IS the framework (dogfooding)
- Source: https://github.com/tomgun/agentic-framework

## Summary
- What are we building: AI-assisted development framework with spec-driven methodology
- Primary platform: CLI tools / documentation

## Languages & runtimes
- Language(s): Bash, Python
- Runtime(s): Bash 5+, Python 3.9+

## Tooling
- Package manager: N/A (shell scripts)
- Formatting/linting: shellcheck (bash), ruff (python)

## Testing
- Unit test framework: bash tests/validate_framework.sh
- Test commands:
  - Unit: `bash tests/validate_framework.sh`
  - Integration: N/A
  - E2E: Manual testing in scratch projects

## Development approach
- development_mode: standard

## Git workflow
- git_workflow: pull_request
- pr_draft_by_default: false
- pr_auto_request_review: false

## Constraints
- Backward compatibility: Must support existing projects upgrading
- Cross-platform: Scripts must work on macOS and Linux
