# `.agentic/`: Agentic AI Framework (Portable)

*Shortname: Agentic AF*

This folder is a **portable framework** you can copy into any repository to bootstrap **high-quality, test-driven, token-efficient** agentic development in **Cursor 2.2+** (and optionally alongside GitHub Copilot / Claude).

**New to this framework?** → Start at [`DEVELOPER_GUIDE.md`](DEVELOPER_GUIDE.md) ⭐⭐⭐ or [`START_HERE.md`](START_HERE.md)

**For AI Agents** → Read [`agents/shared/AGENT_QUICK_START.md`](agents/shared/AGENT_QUICK_START.md) (~70 lines) - gates enforce quality automatically

## Two Profiles: Choose What Fits Your Project

Profiles are **presets** that set bundles of defaults. You can override any individual setting: `ag set feature_tracking yes`. See `ag set --show` for all settings and their sources.

### Discovery Profile (Default - Simple Setup)
**Purpose**: Make agents work better on ANY project - quality, workflows, multi-agent

**What you get**:
- Agent quality standards (security, performance, testing, mutation testing)
- Development workflows (TDD, dev loop, debugging)
- Multi-agent coordination (multiple agents working in parallel)
- Research mode (deep investigation)
- Git workflow (PR mode or direct commits)
- Lightweight planning (OVERVIEW.md - what you're building, what's done)
- Architecture docs (CONTEXT_PACK.md)
- Escalation protocol (HUMAN_NEEDED.md)
- Session continuity (JOURNAL.md)
- Basic tools (doctor.sh with --full/--phase/--pre-commit modes, phase_detect)

**Good for**: 
- Small/simple projects or prototypes
- Projects with external PM tools (Jira, Linear, etc.)
- Solo developers who don't need formal tracking
- Quick experiments and MVPs

### Formal Profile (For Complex Projects)
**Purpose**: Add formal project tracking for long-term development

**Adds to Discovery**:
- Specs & feature tracking (FEATURES.md with F-#### IDs)
- Requirements & acceptance criteria
- Project status & roadmap (STATUS.md)
- Sequential agent pipeline (specialized agents per feature)
- Advanced tools (feature graphs, consistency checks)
- Quality automation & retrospectives

**Good for**: 
- Long-term projects (3+ months of development)
- Human-machine teams collaborating on product
- Complex products requiring traceability
- Projects needing audit trails and formal specs

**Enable later**: `bash .agentic/tools/enable-formal.sh`

**Customize settings**: See [`DEVELOPER_GUIDE.md` → Settings System](DEVELOPER_GUIDE.md#settings-system) for resolution order, profile defaults, and constraints.

## What you get
- **A repo init protocol** (agent-guided) that creates stable context artifacts: `STACK.md`, `CONTEXT_PACK.md`, `STATUS.md`, `JOURNAL.md`, `spec/`, `spec/adr/`.
- **Technology-agnostic spec templates**: PRD, Tech Spec, Task, ADR, Features, NFR, Status.
- **Quality playbooks**: Definition of Done, test strategy, design-for-testability, integration testing, review checklist.
- **Token-efficiency playbooks**: context budgeting, reading protocols, change slicing, durable context packs.
- **Code-spec traceability**: `@feature` annotations and coverage tooling.
- **Verification tooling**: doctor.sh (--full, --phase, --pre-commit modes), phase_detect.py, report.sh, coverage.sh, feature_graph.sh.
- **Multi-agent compatibility**: a shared "agent operating contract" + thin entrypoints for Cursor/Copilot/Claude.
- **Optional lightweight enforcement**: PR checklist + a minimal GitHub Actions template to validate docs/spec conventions.

## Schema and Structure

**The spec system has a defined schema**: [`.agentic/spec/SPEC_SCHEMA.md`](spec/SPEC_SCHEMA.md)
- Defines valid field values, status vocabularies, cross-reference formats
- Ensures consistency across human and agent edits
- Tools validate against this schema

## For complex projects

This framework now includes advanced features for long-term, complex software:
- **Session continuity**: JOURNAL.md tracks progress across context resets
- **Dependency tracking**: Feature dependencies with visualization
- **Human escalation**: HUMAN_NEEDED.md for decisions requiring human input
- **Architecture evolution**: Track changes with CONTEXT_PACK.md snapshots
- **Research trails**: Structured research documentation
- **Scaling guidance**: Suggestions when project complexity crosses thresholds
- **Automated retrospectives**: Periodic project health checks and improvement suggestions
- **Research mode**: Deep investigation into technologies and field updates
- **Documentation verification**: Ensure agents use up-to-date, version-correct documentation
- **Spec validation**: Enforce structure and valid values in spec files
- **Continuous quality validation**: Stack-specific automated quality gates before commits
- **Multi-agent coordination**: Multiple AI agents working simultaneously with Git worktrees
- **PR workflow**: Optional pull request mode for team collaboration

See [`START_HERE.md`](START_HERE.md) for complete guide.

## Development Modes

This framework supports two development workflows:

### TDD Mode (✅ RECOMMENDED)
- Tests are written **first** (red-green-refactor cycle)
- Implementation follows tests
- **Token economics**: Smaller increments, less context, clearer progress
- **Quality**: Forces testability, cleaner code, less rework
- Workflow: `.agentic/workflows/tdd_mode.md`
- **Enable by**: Set `development_mode: tdd` in `STACK.md` (default in template)

### Standard Mode (for exploration)
- Tests are **required** but can come during/after implementation
- Suitable for prototyping, UI exploration, unclear requirements
- Workflow: `.agentic/workflows/dev_loop.md`
- **Enable by**: Set `development_mode: standard` in `STACK.md`

**Recommendation**: Start with TDD mode. Switch to standard mode only for exploratory/prototyping work.

See [`.agentic/workflows/tdd_mode.md`](workflows/tdd_mode.md) for complete TDD guide and benefits.

## Quick start (new repo)

**Install using automated script (recommended):**

```bash
# Download latest release
curl -L https://github.com/tomgun/agentic-framework/archive/refs/tags/v<VERSION>.tar.gz | tar xz
cd agentic-framework-<VERSION>

# Install into your project
bash install.sh /path/to/your-project
```

**Or manual installation:**

```bash
# Download and extract
curl -L https://github.com/tomgun/agentic-framework/archive/refs/tags/v<VERSION>.tar.gz | tar xz

# Copy .agentic/ into your project
cp -r agentic-framework-<VERSION>/.agentic /path/to/your-project/
```

**Initialize:**

Tell your agent:

> "Read `.agentic/init/init_playbook.md` and help me initialize this project."

**That's it!** The agent will:
- Ask what you're building
- Ask which profile you want (Discovery or Formal) and explain the differences
- Interview you about your tech stack and requirements
- Fill in `STACK.md`, `OVERVIEW.md`, `CONTEXT_PACK.md` (and `spec/` if Formal)
- Set up quality validation for your stack

The agent follows `.agentic/init/init_playbook.md` which guides it through the entire initialization process.

### What the agent does (you don't need to do this):

If you used `install.sh`, templates are already created. Otherwise, the agent will:
1. **Run scaffold**: `bash .agentic/init/scaffold.sh` (creates all template files)
2. **Ask about profile**: Explain Discovery vs Formal and help you choose
3. **Ask questions**: What are you building? What tech stack? Performance constraints? etc.
4. **Fill in docs**: `STACK.md`, `OVERVIEW.md`, `CONTEXT_PACK.md` (and `spec/` if Formal)
5. **Set up quality checks**: Create stack-specific `quality_checks.sh` if applicable
6. **Ready to develop**: You're ready to start building

If you're using multiple assistants (Cursor + Copilot + Claude), refer to `.agentic/AGENTS.md` for the agent entry point.

## Upgrading the Framework

**To upgrade to a newer version:**

```bash
# Download new version
curl -L https://github.com/tomgun/agentic-framework/archive/refs/tags/v<VERSION>.tar.gz | tar xz
cd agentic-framework-<VERSION>

# Run upgrade tool FROM the new framework, pointing to your project
bash .agentic/tools/upgrade.sh /path/to/your-project
```

The upgrade script will:
- Backup your existing `.agentic/` folder
- Copy new framework files
- Preserve your customizations
- Update version in `STACK.md`
- Run validation

See [`UPGRADING.md`](../UPGRADING.md) for detailed instructions.

**Important**: Always run the upgrade script **from the NEW framework** (not your old one), as it contains the latest upgrade logic and bug fixes.

The upgrade tool preserves your project files (specs, docs, STACK.md, STATUS.md) while updating framework internals.

See **[`UPGRADING.md`](../UPGRADING.md)** in the repo root for detailed guide.

## Quick resume (after a break)
From repo root:

```bash
bash .agentic/tools/brief.sh
```

**Want to check status without using AI tokens?** See [`MANUAL_OPERATIONS.md`](MANUAL_OPERATIONS.md) for commands you can run yourself to check project state, feature status, and health.

## Reports (no LLM required)
From repo root:

```bash
bash .agentic/tools/report.sh
```

## System docs scaffolding (no LLM required)
From repo root:

```bash
bash .agentic/tools/sync_docs.sh
```

## User Workflows: How to Work with Agents

**⭐ Complete guide**: [`DEVELOPER_GUIDE.md`](DEVELOPER_GUIDE.md) — covers adding features, updating specs, TDD workflow, agent pipeline, troubleshooting, and common questions.

### Ready-to-Use AI Prompts

**Cursor Users**: See [`prompts/cursor/`](prompts/cursor/) for copy-paste workflow prompts:
- `session_start.md` / `session_end.md` - Session management
- `feature_start.md` / `feature_test.md` / `feature_complete.md` - Feature development (TDD)
- `migration_create.md` - Spec migrations (Formal mode)
- `product_update.md` / `quick_feature.md` - Discovery mode workflows
- `research.md` / `plan_feature.md` - Deep research and planning
- `run_quality.md` / `fix_issues.md` / `retrospective.md` - Quality & maintenance

**Claude Users**: See [`prompts/claude/`](prompts/claude/) for:
- Same workflow prompts as Cursor
- Claude-specific tips (Artifacts, Projects, Extended Thinking)
- Project setup instructions

**GitHub Copilot Users**: Use Cursor prompts - they work in any tool!

## Where to read / edit "project truth"
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

30+ scripts in `.agentic/tools/`. Key categories:
- **Health**: `doctor.sh`, `report.sh`, `verify.sh`
- **Traceability**: `ag trace`, `coverage.sh`, `drift.sh`
- **Analysis**: `feature_graph.sh`, `stale.sh`, `deps.sh`

Run `ag tools` or see [`DEVELOPER_GUIDE.md#automation--scripts`](DEVELOPER_GUIDE.md#automation--scripts) for full documentation.

## Troubleshooting

See [`DEVELOPER_GUIDE.md#troubleshooting`](DEVELOPER_GUIDE.md#troubleshooting) for common issues.
Quick navigation: [`START_HERE.md`](START_HERE.md) | Visual overview: [`FRAMEWORK_MAP.md`](FRAMEWORK_MAP.md)

## Design Principles

**📖 Full guide: [`PRINCIPLES.md`](PRINCIPLES.md)** ⭐

13 principles in a derivation hierarchy (3 FOUNDATION + 7 DESIGN PRINCIPLES + 3 OPERATIONAL RULES, all mandatory):

**FOUNDATION** (WHY — the reasons this framework exists):
- **F1: Developer-Friendly Experience** — Framework remembers so developers don't have to
- **F2: Sustainable Long-Term Development & Quality Software** — Tested, documented, reliable over time
- **F3: Token & Context Optimization** — Token-efficient scripts and reading protocols

**DESIGN PRINCIPLES** (HOW — strategies that serve the foundations):
- **D1: Human-Agent Partnership** — Collaboration, not AI autonomy
- **D2: Deterministic Enforcement** — Scripts with exit codes, not suggestions
- **D3: Durable Artifacts** — CONTEXT_PACK, STATUS, JOURNAL always current
- **D4: Small Batch + Acceptance-Driven** — One feature at a time, criteria first
- **D5: Living Documentation** — Docs updated in same commit as code
- **D6: Green Coding** — Minimize environmental impact
- **D7: Multi-Environment Portability** — Same state and enforcement across all AI tools

**OPERATIONAL RULES** (WHAT — concrete, testable constraints):
- **R1: Anti-Hallucination** — Verify before using, never fabricate
- **R2: No Auto-Commits** — Human approval required
- **R3: Check Before Creating** — Search for existing before adding new

See PRINCIPLES.md for the derivation DAG and reasoning behind every framework decision.

## Adoption notes
- This framework is intentionally **tech-agnostic**. Where stack specifics matter, use:
  - `STACK.md` (repo’s truth)
  - `.agentic/support/stack_profiles/*` (guidance profiles to speed up init)
- The optional CI template is **opt-in**. It validates *presence/format* of the docs artifacts only.
  - To enable it, copy `.agentic/support/ci/github_actions.template.yml` to `.github/workflows/agentic-spec-lint.yml`.


