# `.agentic/`: Agentic AI Framework (Portable)

*Shortname: Agentic AF*

This folder is a **portable framework** you can copy into any repository to bootstrap **high-quality, test-driven, token-efficient** agentic development in **Cursor 2.2+** (and optionally alongside GitHub Copilot / Claude).

**New to this framework?** → Start at [`DEVELOPER_GUIDE.md`](DEVELOPER_GUIDE.md) ⭐⭐⭐ or [`START_HERE.md`](START_HERE.md)

**For AI Agents** → Read [`agents/shared/AGENT_QUICK_START.md`](agents/shared/AGENT_QUICK_START.md) (~70 lines) - gates enforce quality automatically

## Two Profiles: Choose What Fits Your Project

### Core Profile (Default - Simple Setup)
**Purpose**: Make agents work better on ANY project - quality, workflows, multi-agent

**What you get**:
- Agent quality standards (security, performance, testing, mutation testing)
- Development workflows (TDD, dev loop, debugging)
- Multi-agent coordination (multiple agents working in parallel)
- Research mode (deep investigation)
- Git workflow (PR mode or direct commits)
- Lightweight planning (PRODUCT.md - what you're building, what's done)
- Architecture docs (CONTEXT_PACK.md)
- Escalation protocol (HUMAN_NEEDED.md)
- Session continuity (JOURNAL.md)
- Basic tools (doctor.sh with --full/--phase/--pre-commit modes, phase_detect)

**Good for**: 
- Small/simple projects or prototypes
- Projects with external PM tools (Jira, Linear, etc.)
- Solo developers who don't need formal tracking
- Quick experiments and MVPs

### Core + Product Management (For Complex Projects)
**Purpose**: Add formal project tracking for long-term development

**Adds to Core**:
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

**Enable later**: `bash .agentic/tools/enable-product-management.sh`

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
- **Architecture evolution**: Track changes over time with arch_diff.sh
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
curl -L https://github.com/tomgun/agentic-framework/archive/refs/tags/v0.2.1.tar.gz | tar xz
cd agentic-framework-0.2.1

# Install into your project
bash install.sh /path/to/your-project
```

**Or manual installation:**

```bash
# Download and extract
curl -L https://github.com/tomgun/agentic-framework/archive/refs/tags/v0.2.1.tar.gz | tar xz

# Copy .agentic/ into your project
cp -r agentic-framework-0.2.1/.agentic /path/to/your-project/
```

**Initialize:**

Tell your agent:

> "Read `.agentic/init/init_playbook.md` and help me initialize this project."

**That's it!** The agent will:
- Ask what you're building
- Ask which profile you want (Core or Core+PM) and explain the differences
- Interview you about your tech stack and requirements
- Fill in `STACK.md`, `PRODUCT.md`, `CONTEXT_PACK.md` (and `spec/` if Core+PM)
- Set up quality validation for your stack

The agent follows `.agentic/init/init_playbook.md` which guides it through the entire initialization process.

### What the agent does (you don't need to do this):

If you used `install.sh`, templates are already created. Otherwise, the agent will:
1. **Run scaffold**: `bash .agentic/init/scaffold.sh` (creates all template files)
2. **Ask about profile**: Explain Core vs Core+PM and help you choose
3. **Ask questions**: What are you building? What tech stack? Performance constraints? etc.
4. **Fill in docs**: `STACK.md`, `PRODUCT.md`, `CONTEXT_PACK.md` (and `spec/` if Core+PM)
5. **Set up quality checks**: Create stack-specific `quality_checks.sh` if applicable
6. **Ready to develop**: You're ready to start building

If you're using multiple assistants (Cursor + Copilot + Claude), refer to `.agentic/AGENTS.md` for the agent entry point.

## Upgrading the Framework

**To upgrade to a newer version:**

```bash
# Download new version
curl -L https://github.com/tomgun/agentic-framework/archive/refs/tags/v0.2.1.tar.gz | tar xz
cd agentic-framework-0.2.1

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

**⭐ New user? Start here**: [`workflows/USER_WORKFLOWS.md`](workflows/USER_WORKFLOWS.md)

Complete guide covering:
- How to add new features (edit specs yourself or ask agent)
- How to update specs and acceptance criteria
- How agents pick up your changes (YES, they do!)
- TDD workflow
- Sequential agent pipeline
- Common questions and troubleshooting

### Ready-to-Use AI Prompts

**Cursor Users**: See [`prompts/cursor/`](prompts/cursor/) for copy-paste workflow prompts:
- `session_start.md` / `session_end.md` - Session management
- `feature_start.md` / `feature_test.md` / `feature_complete.md` - Feature development (TDD)
- `migration_create.md` - Spec migrations (Core+PM mode)
- `product_update.md` / `quick_feature.md` - Core mode workflows
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

From repo root:

```bash
# Project health and verification
bash .agentic/tools/doctor.sh      # Check structure
bash .agentic/tools/report.sh      # Feature status
bash .agentic/tools/verify.sh      # Comprehensive checks

# Context and analysis
bash .agentic/tools/brief.sh       # Quick project brief
python3 .agentic/tools/continue_here.py  # Generate .continue-here.md for next session
bash .agentic/tools/coverage.sh    # Code annotation coverage
bash .agentic/tools/feature_graph.sh   # Feature dependency graph
bash .agentic/tools/arch_diff.sh   # Architecture changes

# Documentation
bash .agentic/tools/sync_docs.sh   # Generate doc scaffolding

# Retrospective
bash .agentic/tools/retro_check.sh  # Check if retrospective is due

# Version verification
bash .agentic/tools/version_check.sh # Check dependency versions match STACK.md

# Spec validation
python3 .agentic/tools/validate_specs.py  # Validate spec frontmatter

# Spec migrations (Core+PM mode, optional)
bash .agentic/tools/migration.sh create "Add Feature X"  # Create new migration
bash .agentic/tools/migration.sh list                    # List all migrations
bash .agentic/tools/migration.sh show 001                # Show specific migration
bash .agentic/tools/migration.sh search "keyword"        # Search migrations
```

## Troubleshooting

**Can't find what you need?**
- Read [`START_HERE.md`](START_HERE.md) for guided navigation
- See [`FRAMEWORK_MAP.md`](FRAMEWORK_MAP.md) for visual overview
- Check tools with `bash .agentic/tools/doctor.sh`

**Agent keeps re-reading everything?**
- Ensure `CONTEXT_PACK.md` is comprehensive
- Use `@feature` annotations in code
- Follow `.agentic/token_efficiency/reading_protocols.md`

**Project getting complex?**
- See `.agentic/workflows/scaling_guidance.md` for reorganization suggestions
- Run `bash .agentic/tools/feature_graph.sh` to visualize dependencies  

## Design principles (first principles)

**📖 For comprehensive principles guide, see [`PRINCIPLES.md`](PRINCIPLES.md)** ⭐

The short version:
- **Feedback loops** beat cleverness: tests and small diffs reduce risk.
- **Entropy is real**: decisions must be recorded, status must be current.
- **Context is expensive**: durable artifacts reduce repeated token spend.
- **Agents need a contract**: consistent behavior across tools avoids thrash.
- **Human-agent partnership**: Collaboration, not replacement.
- **Quality by design**: TDD, stack-specific checks, acceptance validation.

See PRINCIPLES.md for the "why" behind every framework decision.

## Adoption notes
- This framework is intentionally **tech-agnostic**. Where stack specifics matter, use:
  - `STACK.md` (repo’s truth)
  - `.agentic/support/stack_profiles/*` (guidance profiles to speed up init)
- The optional CI template is **opt-in**. It validates *presence/format* of the docs artifacts only.
  - To enable it, copy `.agentic/support/ci/github_actions.template.yml` to `.github/workflows/agentic-spec-lint.yml`.


