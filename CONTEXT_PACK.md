# CONTEXT_PACK.md

Purpose: A compact, durable starting point for agents/humans working on the Agentic Framework itself.

## One-minute overview
- What this repo is: The Agentic AI Framework - a spec-driven development framework for AI-assisted coding with quality gates, session continuity, and multi-agent coordination.
- Main user workflow:
  1. Install framework into project (`install.sh`)
  2. Initialize with profile selection (Discovery, Formal, or Autonomous Formal)
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
- **Claude Skills** (primary workflow delivery for Claude Code): `.claude/skills/`
  - Source: `.agentic/agents/claude/skills/` (hand-crafted, 12 skills + project-specific extensions)
  - Generator: `.agentic/tools/generate-skills.sh` (assembles references, injects VERSION, merges extensions)
  - Key skills: `implementing-features`, `committing-changes`, `fixing-bugs`, `writing-specs`, `session-start`, `completing-work`, `planning-features`, `writing-tests`, `reviewing-code`, `exploring-codebase`, `researching-topics`, `updating-documentation`
- Claude-specific: `.agentic/agents/claude/CLAUDE.md` (consolidated quick reference)
- Framework specs: `spec/FEATURES.md` (100+ features)
- Acceptance criteria: `spec/acceptance/F-####.md`
- Validation tests: `tests/validate_framework.sh` (367 tests)
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
    - `todo.sh` - TODO.md CRUD (add/done/drop/triage/list)
    - `wip.sh` - Work-in-progress tracking
    - `migration.sh` - Spec migration management (create/list/show/search/apply)
    - `drift.sh --docs` - Documentation drift detection
    - `docs.sh` - Doc lifecycle context assembler (wired into `ag done` and `ag docs`)
    - `manifest.sh` - Feature change manifest generation from git history
    - `memory-check.sh` - Advisory memory-seed integrity check (session start)
    - `periodic-checks.sh` - Frequency-gated checks (orphan plans, retro, agent freshness)
    - `check-spec-health.sh` - Spec validation (missing criteria, unchecked items)
    - `generate-project-agents.sh` - Stack detection → project-specific agent generation
    - `generate-skills.sh` - Assemble Claude Skills from hand-crafted sources
    - `spec-analyze.sh` - Semantic spec analysis: ambiguity detection, AC↔test gaps, NFR measurability (advisory)
    - `coverage.py --ac-coverage` - Per-AC test coverage mapping via naming conventions
  - User customization: `.agentic/local/extensions/` (custom skills, gates, hooks, rules — survives upgrades)
- Data flow: Framework installed → Project initialized → Agents follow guidelines → Quality gates enforced
- External dependencies: None (pure bash/Python, no npm/pip packages)

## Instruction architecture (core design)
- **Design doc**: `docs/INSTRUCTION_ARCHITECTURE.md` — authoritative, read before changing instruction files
- **Three-layer model**:
  - **Layer 1 — Constitution** (instruction files: CLAUDE.md, .cursorrules, etc.): Only rules that cannot be structurally enforced. Keep under 100 lines (L-0002 empirical ceiling).
  - **Layer 2 — Playbooks** (auto_orchestration.md, checklists, workflows): Loaded just-in-time by `ag` commands, not pinned in context.
  - **Layer 3 — Project State** (STACK.md, STATUS.md): Machine-readable config parsed by scripts. Git-tracked state vs gitignored session-local state.
- **Skills-primary architecture** (F-0143): Claude Code uses 12 hand-crafted Skills (`.claude/skills/`) as primary workflow delivery. Cursor/Copilot/Codex use `auto_orchestration.md` trigger tables. Skills contain instructions + scripts/ + references/ (playbook copies).
- **STACK.md `## Settings`** (F-0141): Typed key-value settings with `ag set` command. Profiles (discovery/formal) set defaults; individual settings override. Settings drive gates, workflows, and tool behavior.
- **Enforcement model**: Distributed — `ag implement` (planning gates), `spec-analyze.sh` (advisory pre-implementation analysis), `pre-commit-check.sh` (17 structural checks), `ag done` (completion validation), `ag docs` (doc lifecycle). No single orchestrator process; each script enforces its phase.
- **Defense-in-depth**: `memory-seed.md` seeds behavioral patterns into tool persistent memory. Memory reinforces; scripts enforce. Memory fades during long sessions (context compression); structural gates are the only reliable late-session enforcement.
- **Multi-tool support**: Claude Code, Cursor, Windsurf, Copilot, Codex — each has different instruction file formats and memory mechanisms. Templates in `.agentic/agents/<tool>/`.
- **Key principle**: Structural enforcement > behavioral instruction > memory reinforcement. If a rule can be checked by a script, don't rely on the agent remembering it.

## Quality gates (current)
- Validation tests required: `tests/validate_framework.sh` must pass (200+ tests)
- Acceptance criteria: Every feature needs `spec/acceptance/F-####.md`
- Definition of Done: See `.agentic/workflows/definition_of_done.md`

## State files
- `AGENTS.json` - Work-in-progress tracking and multi-agent coordination
- `.agentic/journal/manifests/` - Feature change manifests (git history snapshots)
- `.agentic/journal/lessons/` - Operational learnings (L-#### files)

## Documentation

- `README.md` — Framework overview and install guide
- `.agentic/DEVELOPER_GUIDE.md` — Commands, scripts, daily workflows reference
- `.agentic/MANUAL_OPERATIONS.md` — Token-free CLI reference for humans
- `.agentic/PRINCIPLES.md` — Why the framework does what it does
- `docs/INSTRUCTION_ARCHITECTURE.md` — Three-layer design (read before changing instruction files)
- `docs/HOW_IT_WORKS.md` — Principle → feature → implementation map
- `CONTEXT_PACK.md` — Architecture snapshot (update when architecture changes)
- `spec/TECH_SPEC.md` — Technical architecture details

## Known risks / sharp edges
- Multiple agents can work simultaneously - must coordinate via AGENTS.json (`agents_helpers.py list`)
- Template changes affect ALL future projects - test in scratch first
- Version references scattered across files - update ALL on release
- Upgrade path must preserve user customizations
