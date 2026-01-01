# Agentic Framework

A portable framework for building complex, maintainable software with AI agents as development partners.

## What is this?

The Agentic Framework enables **sustainable long-term software development with AI agents**. It provides structure, conventions, and tooling that keep both humans and AI agents aligned as projects evolve from prototypes to production systems.

This repository is a **template**. Copy the `agentic/` folder into your project to adopt the framework.

## Design Principles

### 1. Token Economics (Efficiency)
**Durable artifacts prevent repeated context waste.**
- Maintain `CONTEXT_PACK.md` so agents don't re-read entire codebases
- Use `JOURNAL.md` to preserve progress across context resets
- Follow structured reading protocols with explicit token budgets
- Summarize instead of repeatedly reading

### 2. Developer-Friendly UX
**Humans focus on decisions and direction. Agents handle implementation mechanics.**
- Humans define what to build, agents handle how
- Humans can read/edit specs directly (markdown files)
- Agents run scaffold scripts, update docs, maintain consistency
- Clear status at all times (`STATUS.md` + `JOURNAL.md`)
- Tools provide immediate project health checks (no agent needed)

### 3. Quality by Design
**Tests and incremental changes reduce risk.**
- **TDD recommended**: Write tests first for better token economics and testable code
- Tests are mandatory for all new/changed logic
- Small, reviewable increments over large changes
- Design for testability (seams, boundaries, pure functions)
- Definition of Done includes quality gates

### 4. Living Documentation
**Documentation stays current through collaboration and automation.**
- Humans add requirements, features, priorities to specs
- Agents update specs when implementing (same commit as code)
- No stale placeholders (`(Not yet created)` gets replaced)
- `FEATURES.md` status matches implementation reality
- Architecture decisions are recorded (ADRs) by whoever makes them

### 5. Traceability
**Clear path from requirements to code to tests.**
- Features have stable IDs (`F-0001`) with acceptance criteria
- Code annotated with `@feature F-####` for bidirectional linking
- Test coverage explicitly tracked per feature
- Dependency visualization shows relationships

### 6. Iterative & Incremental
**Ship in small, validated steps.**
- Pick one small task from `STATUS.md`
- Implement with tests
- Verify acceptance criteria
- Update docs and move to next task

### 7. Human-Agent Collaboration
**Both humans and agents work together on project truth.**
- **Humans**: Read specs, add features/tasks, make decisions, set priorities
- **Agents**: Implement features, update docs with code changes, maintain sync
- Specs are readable and editable by both (markdown files, not complex formats)
- Agents know when to escalate to humans (`HUMAN_NEEDED.md`)
- Tools enable humans to check status without asking agents (token-free queries)

## Quick Start

### For new projects

**Step 1:** Copy framework into your repo
```bash
# From your project root
cp -r /path/to/agentic-framework/agentic ./
```

**Step 2:** Tell your agent to initialize
Open your AI agent (Cursor/Copilot/Claude) and say:

> "Initialize this project using the agentic framework. Run the scaffold script first, then follow the init playbook."

The agent will:
1. Run `bash agentic/init/scaffold.sh` to create all files
2. Ask you questions about your project
3. Fill in `STACK.md`, `CONTEXT_PACK.md`, `STATUS.md`, and `spec/`
4. You're ready to develop!

**New to the framework?** → Read [`agentic/START_HERE.md`](agentic/START_HERE.md)

### For evaluating the framework

- **Full documentation**: [`agentic/README.md`](agentic/README.md)
- **Quick tour**: [`agentic/START_HERE.md`](agentic/START_HERE.md)
- **Visual guide**: [`agentic/FRAMEWORK_MAP.md`](agentic/FRAMEWORK_MAP.md)
- **Working example**: [`examples/inited_project/`](examples/inited_project/) (Next.js Todo app)

## What You Get

### Core Framework
- **Agent operating guidelines**: Consistent behavior across AI tools
- **Specification templates**: PRD, Tech Spec, Features, NFR, ADR, Tasks
- **Quality playbooks**: Test strategy, review checklist, definition of done
- **Token efficiency guides**: Reading protocols, context budgeting
- **Development workflows**: Dev loop, debugging, code annotations

### For Complex Projects
- **Session continuity**: JOURNAL.md tracks progress across context resets
- **Dependency tracking**: Feature dependencies with visualization
- **Human escalation**: HUMAN_NEEDED.md for decisions requiring judgment
- **Architecture evolution**: Track changes with arch_diff.sh
- **Research trails**: Structured documentation of research findings
- **Scaling guidance**: Suggestions when complexity crosses thresholds
- **Project retrospectives**: Periodic agent-led health checks
- **Research mode**: Deep investigation into technologies and best practices
- **Documentation verification**: Ensures agents use current, version-correct docs
- **Spec validation**: Automatic validation of spec files against schemas

### Tooling
```bash
# Project health & verification
bash agentic/tools/doctor.sh      # Check structure
bash agentic/tools/report.sh      # Feature status summary
bash agentic/tools/verify.sh      # Comprehensive validation
python3 agentic/tools/validate_specs.py  # Validate spec frontmatter

# Retrospectives & version checking
bash agentic/tools/retro_check.sh    # Check if retrospective is due
bash agentic/tools/version_check.sh  # Check dependency versions

# Context & analysis
bash agentic/tools/brief.sh       # Quick project brief
bash agentic/tools/dashboard.sh   # Comprehensive dashboard
bash agentic/tools/coverage.sh    # Code annotation coverage
bash agentic/tools/feature_graph.sh   # Dependency visualization
bash agentic/tools/arch_diff.sh   # Architecture changes over time

# Manual operations (token-free)
bash agentic/tools/search.sh      # Search specs and code
bash agentic/tools/whatchanged.sh # Recent changes
bash agentic/tools/deps.sh        # Feature dependencies
bash agentic/tools/accept.sh      # Run acceptance tests
bash agentic/tools/consistency.sh # Check doc drift
bash agentic/tools/stale.sh       # Find stale docs
bash agentic/tools/task.sh        # Create task files
```

### Stack Profiles
Quick-start guidance for common technology stacks:
- Generic/default, Full-stack webapp, Native iOS
- Go backend services, Python ML projects
- Rust systems programming, React Native mobile

## Key Artifacts

The framework creates and maintains these "source of truth" files:

**Project State:**
- `STACK.md` - How to build, test, run, and deploy
- `STATUS.md` - Current focus, roadmap, known issues
- `CONTEXT_PACK.md` - Durable context (where things are, how it works)
- `JOURNAL.md` - Session-by-session progress log

**Specifications:**
- `spec/PRD.md` - Requirements (why, what)
- `spec/TECH_SPEC.md` - Architecture (how)
- `spec/FEATURES.md` - Feature registry with IDs, status, tests
- `spec/NFR.md` - Non-functional requirements
- `spec/acceptance/F-####.md` - Acceptance criteria per feature
- `spec/adr/` - Architecture Decision Records

**Escalation:**
- `HUMAN_NEEDED.md` - Items requiring human decision/intervention

## Examples

- **Scaffold output**: [`examples/example_structure/`](examples/example_structure/) - Freshly scaffolded project structure
- **Working project**: [`examples/inited_project/`](examples/inited_project/) - Complete Next.js Todo app with full specs, tests, and documentation

## For Existing Projects

Already have a project? The framework integrates non-invasively:

1. Copy `agentic/` folder into your repo
2. Run scaffold to create documentation structure
3. Agent fills in specs based on existing code
4. Adopt practices incrementally (tests first, then specs, then workflows)

## License & Contributing

[Add your license and contribution guidelines]

## Getting Help

- **Documentation**: Start at [`agentic/START_HERE.md`](agentic/START_HERE.md)
- **Examples**: See [`examples/`](examples/) directory
- **Issues**: [Your issue tracker]

---

**Note for adopted projects**: After copying `agentic/` into your project, replace this root `README.md` with your project's actual README. Keep `agentic/README.md` as-is for framework documentation.
