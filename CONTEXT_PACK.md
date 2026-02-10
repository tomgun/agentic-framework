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
- Agent guidelines:
  - Quick start: `.agentic/agents/shared/AGENT_QUICK_START.md` (~70 lines)
  - Full reference: `.agentic/agents/shared/agent_operating_guidelines.md`
  - **Modular guidelines** (lazy-loaded): `.agentic/agents/shared/guidelines/`
    - `anti-hallucination.md` - Core rule, always relevant
    - `token-efficiency.md` - When updating docs
    - `small-batch.md` - Implementation tasks
    - `multi-agent.md` - Parallel agent work
    - `wip-tracking.md` - Interrupted sessions
- Claude-specific: `.agentic/agents/claude/CLAUDE.md` (consolidated quick reference)
- Framework specs: `spec/FEATURES.md` (70 features)
- Acceptance criteria: `spec/acceptance/F-####.md`
- Validation tests: `tests/validate_framework.sh` (104+ tests)
- Templates: `.agentic/init/*.template.md`, `.agentic/spec/*.template.md`
- Workflows: `.agentic/workflows/`
- Quality guides: `.agentic/quality/`
- Checklists: `.agentic/checklists/`
- Principles: `.agentic/PRINCIPLES.md`
- Full dev guide: `FRAMEWORK_DEVELOPMENT.md`
- **Framework ADRs**: `docs/adr/` - why framework decisions were made (read before changing!)

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
  - Agent guidelines (tool-specific + shared)
  - Modular guidelines (lazy-loaded for token efficiency)
  - Workflows (TDD, git, session management)
  - Quality gates (checklists, validation scripts, doctor.sh)
  - Templates (specs, docs, features)
  - Token-efficient tools:
    - `journal.sh` - Append-only JOURNAL.md updates
    - `status.sh` - Direct STATUS.md section updates (focus, progress, next, blocker)
    - `feature.sh` - Field updates to FEATURES.md
    - `blocker.sh` - Append-only HUMAN_NEEDED.md updates
    - `wip.sh` - Work-in-progress tracking
    - `migration.sh` - Spec migration management (create/list/show/search/apply)
    - `drift.sh --docs` - Documentation drift detection
    - `manifest.sh` - Feature change manifest generation from git history
- Data flow: Framework installed → Project initialized → Agents follow guidelines → Quality gates enforced
- External dependencies: None (pure bash/Python, no npm/pip packages)

## Quality gates (current)
- Validation tests required: `tests/validate_framework.sh` must pass (104+ tests)
- Acceptance criteria: Every feature needs `spec/acceptance/F-####.md`
- Definition of Done: See `.agentic/workflows/definition_of_done.md`

## State files
- `.agentic-state/WIP.md` - Work-in-progress tracking (recovery)
- `.agentic-state/AGENTS_ACTIVE.md` - Multi-agent coordination
- `.agentic-journal/manifests/` - Feature change manifests (git history snapshots)
- `.agentic-journal/lessons/` - Operational learnings (L-#### files)

## Known risks / sharp edges
- Multiple agents can work simultaneously - must coordinate via `.agentic-state/AGENTS_ACTIVE.md`
- Template changes affect ALL future projects - test in scratch first
- Version references scattered across files - update ALL on release
- Upgrade path must preserve user customizations
