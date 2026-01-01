# `agentic/`: Agentic Development Framework (Portable)

This folder is a **portable framework** you can copy into any repository to bootstrap **high-quality, test-driven, token-efficient** agentic development in **Cursor 2.2+** (and optionally alongside GitHub Copilot / Claude).

**New to this framework?** → Start at [`START_HERE.md`](START_HERE.md)

## What you get
- **A repo init protocol** (agent-guided) that creates stable context artifacts: `STACK.md`, `CONTEXT_PACK.md`, `STATUS.md`, `JOURNAL.md`, `spec/`, `spec/adr/`.
- **Technology-agnostic spec templates**: PRD, Tech Spec, Task, ADR, Features, NFR, Status.
- **Quality playbooks**: Definition of Done, test strategy, design-for-testability, integration testing, review checklist.
- **Token-efficiency playbooks**: context budgeting, reading protocols, change slicing, durable context packs.
- **Code-spec traceability**: `@feature` annotations and coverage tooling.
- **Verification tooling**: doctor.sh, verify.sh, report.sh, coverage.sh, feature_graph.sh.
- **Multi-agent compatibility**: a shared "agent operating contract" + thin entrypoints for Cursor/Copilot/Claude.
- **Optional lightweight enforcement**: PR checklist + a minimal GitHub Actions template to validate docs/spec conventions.

## Schema and Structure

**The spec system has a defined schema**: [`agentic/spec/SPEC_SCHEMA.md`](spec/SPEC_SCHEMA.md)
- Defines valid field values, status vocabularies, cross-reference formats
- Ensures consistency across human and agent edits
- Tools validate against this schema

## For complex projects

This framework now includes advanced features for long-term, complex software:
- **Session continuity**: JOURNAL.md tracks progress across context resets
- **Dependency tracking**: Feature dependencies with visualization
- **Human escalation**: HUMAN_NEEDED.md for decisions requiring human input
- **Architecture evolution**: Track changes over time with arch_diff.sh
- **Research trails**: Structured research documentation
- **Scaling guidance**: Suggestions when project complexity crosses thresholds

See [`START_HERE.md`](START_HERE.md) for complete guide.

## Development Modes

This framework supports two development workflows:

### TDD Mode (✅ RECOMMENDED)
- Tests are written **first** (red-green-refactor cycle)
- Implementation follows tests
- **Token economics**: Smaller increments, less context, clearer progress
- **Quality**: Forces testability, cleaner code, less rework
- Workflow: `agentic/workflows/tdd_mode.md`
- **Enable by**: Set `development_mode: tdd` in `STACK.md` (default in template)

### Standard Mode (for exploration)
- Tests are **required** but can come during/after implementation
- Suitable for prototyping, UI exploration, unclear requirements
- Workflow: `agentic/workflows/dev_loop.md`
- **Enable by**: Set `development_mode: standard` in `STACK.md`

**Recommendation**: Start with TDD mode. Switch to standard mode only for exploratory/prototyping work.

See [`agentic/workflows/tdd_mode.md`](workflows/tdd_mode.md) for complete TDD guide and benefits.

## Quick start (new repo)
1. Copy the **folder** `agentic/` into your repo root (don't copy its contents into the root; keep the folder so links stay consistent).
2. Init is two-phase: **agent-runs scaffold** (create everything) + **agent-guided planning** (fill it in). The developer should only need to talk to the agent.

### Step 0: scaffold (agent runs script)

```bash
bash agentic/init/scaffold.sh
```

### Step 1: init planning (agent)
3. Start your agent and point it to `agentic/init/init_playbook.md`.
4. If the topic is non-trivial, do a short research pass first, then write/upgrade `/spec/PRD.md` and `/spec/TECH_SPEC.md`.
5. Start development using `agentic/workflows/dev_loop.md` (small tasks, tests, updates to `STATUS.md`).
6. If you’re using multiple assistants (Cursor + Copilot + Claude), install entrypoints from `agentic/agents/installation.md`.

## Quick resume (after a break)
From repo root:

```bash
bash agentic/tools/brief.sh
```

**Want to check status without using AI tokens?** See [`MANUAL_OPERATIONS.md`](MANUAL_OPERATIONS.md) for commands you can run yourself to check project state, feature status, and health.

## Reports (no LLM required)
From repo root:

```bash
bash agentic/tools/report.sh
```

## System docs scaffolding (no LLM required)
From repo root:

```bash
bash agentic/tools/sync_docs.sh
```

## Where to read / edit “project truth”
- Vision + current state + architecture pointers: `spec/OVERVIEW.md`
- Current execution state: `STATUS.md`
- Requirements: `spec/PRD.md`
- Architecture + testing strategy: `spec/TECH_SPEC.md`
- Feature/requirement registry (IDs + status + acceptance + test notes): `spec/FEATURES.md`
- Acceptance criteria per feature: `spec/acceptance/F-####.md`
- Lessons learned / caveats: `spec/LESSONS.md` and `spec/adr/*`

## Minimal repo files this framework expects (created during init)
- `STACK.md`: tech stack + constraints (source of truth for "how to build here").  
- `CONTEXT_PACK.md`: short durable context for agents (what matters, where to look).  
- `STATUS.md`: current progress, next steps, known issues, roadmap.  
- `JOURNAL.md`: session-by-session progress log (new sessions, blockers, next steps).
- `HUMAN_NEEDED.md`: items requiring human decision or intervention.
- `/spec/`: PRD + Tech Spec(s) + tasks (living docs).  
- `spec/adr/`: Architecture Decision Records (only for real decisions).

## Tools and automation

From repo root:

```bash
# Project health and verification
bash agentic/tools/doctor.sh      # Check structure
bash agentic/tools/report.sh      # Feature status
bash agentic/tools/verify.sh      # Comprehensive checks

# Context and analysis
bash agentic/tools/brief.sh       # Quick project brief
bash agentic/tools/coverage.sh    # Code annotation coverage
bash agentic/tools/feature_graph.sh   # Feature dependency graph
bash agentic/tools/arch_diff.sh   # Architecture changes

# Documentation
bash agentic/tools/sync_docs.sh   # Generate doc scaffolding

# Retrospective
bash agentic/tools/retro_check.sh  # Check if retrospective is due

# Version verification
bash agentic/tools/version_check.sh # Check dependency versions match STACK.md

# Spec validation
python3 agentic/tools/validate_specs.py  # Validate spec frontmatter
```

## Troubleshooting

**Can't find what you need?**
- Read [`START_HERE.md`](START_HERE.md) for guided navigation
- See [`FRAMEWORK_MAP.md`](FRAMEWORK_MAP.md) for visual overview
- Check tools with `bash agentic/tools/doctor.sh`

**Agent keeps re-reading everything?**
- Ensure `CONTEXT_PACK.md` is comprehensive
- Use `@feature` annotations in code
- Follow `agentic/token_efficiency/reading_protocols.md`

**Project getting complex?**
- See `agentic/workflows/scaling_guidance.md` for reorganization suggestions
- Run `bash agentic/tools/feature_graph.sh` to visualize dependencies  

## Design principles (first principles)
See `agentic/principles/first_principles.md` for the “why”. The short version:
- **Feedback loops** beat cleverness: tests and small diffs reduce risk.
- **Entropy is real**: decisions must be recorded, status must be current.
- **Context is expensive**: durable artifacts reduce repeated token spend.
- **Agents need a contract**: consistent behavior across tools avoids thrash.

## Adoption notes
- This framework is intentionally **tech-agnostic**. Where stack specifics matter, use:
  - `STACK.md` (repo’s truth)
  - `agentic/support/stack_profiles/*` (guidance profiles to speed up init)
- The optional CI template is **opt-in**. It validates *presence/format* of the docs artifacts only.
  - To enable it, copy `agentic/support/ci/github_actions.template.yml` to `.github/workflows/agentic-spec-lint.yml`.


