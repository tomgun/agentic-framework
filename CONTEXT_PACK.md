# CONTEXT_PACK.md

Purpose: A compact, durable starting point for agents/humans working on the Agentic Framework itself.

## One-minute overview
- What this repo is: The Agentic AI Framework - a spec-driven development framework for AI-assisted coding with quality gates, session continuity, and multi-agent coordination.
- Main user workflow:
  1. Install framework into project (`install.sh`)
  2. Initialize with profile selection (Core or Core+PM)
  3. Work with AI agents following framework protocols
- Current top priorities:
  - Maintain spec ↔ acceptance ↔ tests ↔ code chain
  - Ensure backward compatibility on all changes
  - Test changes in scratch projects before committing

## Where to look first (map)
- Entry points: `install.sh` (installation), `.agentic/init/scaffold.sh` (initialization)
- Core agent guidelines: `.agentic/agents/shared/agent_operating_guidelines.md`
- Quick start for agents: `.agentic/agents/shared/AGENT_QUICK_START.md`
- Framework specs: `spec/FEATURES.md`
- Acceptance criteria: `spec/acceptance/F-####.md`
- Validation tests: `tests/validate_framework.sh`
- Templates: `.agentic/init/*.template.md`, `.agentic/spec/*.template.md`
- Workflows: `.agentic/workflows/`
- Quality guides: `.agentic/quality/`
- Checklists: `.agentic/checklists/`
- Principles: `.agentic/PRINCIPLES.md`
- Full dev guide: `.agentic/FRAMEWORK_DEVELOPMENT.md`

## How to run
- Setup: Clone repo, no dependencies required (bash/Python 3)
- Test framework: `bash tests/validate_framework.sh`
- Test in scratch project:
  ```bash
  mkdir /tmp/test-project && cd /tmp/test-project && git init
  bash /path/to/agentic-framework/install.sh .
  ```

## Architecture snapshot
- Components:
  - Installation system (`install.sh`, `upgrade.sh`)
  - Init scaffolding (profile selection, file generation)
  - Agent guidelines (tool-specific instructions)
  - Workflows (TDD, git, session management)
  - Quality gates (checklists, validation scripts)
  - Templates (specs, docs, features)
  - Tools (doctor.py, wip.sh, session_log.sh, etc.)
- Data flow: Framework installed → Project initialized → Agents follow guidelines → Quality gates enforced
- External dependencies: None (pure bash/Python, no npm/pip packages)

## Quality gates (current)
- Validation tests required: `tests/validate_framework.sh` must pass (104+ tests)
- Acceptance criteria: Every feature needs `spec/acceptance/F-####.md`
- Definition of Done: See `.agentic/workflows/definition_of_done.md`

## Known risks / sharp edges
- Multiple agents can work simultaneously - must coordinate via `.agentic/AGENTS_ACTIVE.md`
- Template changes affect ALL future projects - test in scratch first
- Version references scattered across files - update ALL on release
- Upgrade path must preserve user customizations
