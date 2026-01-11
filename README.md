# Agentic AI Framework

**Portable, token-efficient, test-driven framework for AI-assisted software development.**

*Shortname: Agentic AF*

**Current version:** [v0.9.6](https://github.com/tomgun/agentic-framework/releases/tag/v0.9.6)

**📖 Quick Links:**
- [**DEVELOPER_GUIDE.md**](.agentic/DEVELOPER_GUIDE.md) ⭐ - Complete usage guide (daily workflows, scripts, customization)
- [**PRINCIPLES.md**](.agentic/PRINCIPLES.md) ⭐ - Framework values & why we do what we do
- [**CREDITS.md**](CREDITS.md) - Contributors and acknowledgments
- [START_HERE.md](.agentic/START_HERE.md) - Quick start in 5 minutes
- [MANUAL_OPERATIONS.md](.agentic/MANUAL_OPERATIONS.md) - Token-free information retrieval
- [USER_WORKFLOWS.md](.agentic/workflows/USER_WORKFLOWS.md) - Working with agents
- [Example Projects](examples/) - See it in action
- 🚨 [**FRAMEWORK_DEVELOPMENT.md**](.agentic/FRAMEWORK_DEVELOPMENT.md) - For contributors working on the framework itself

## What is this?

The Agentic AI Framework enables **sustainable long-term software development with AI agents**. It provides structure, conventions, and tooling that keep both humans and AI agents aligned as projects evolve from prototypes to production systems.

**Two profiles available:**
- **Core**: Quality standards, workflows, multi-agent coordination (minimal ceremony)
- **Core + Product Management**: Adds formal specs, feature tracking, project metrics (for complex projects)

**🔄 Multi-Environment Support:**
Work seamlessly across Claude Desktop, Cursor, and GitHub Copilot in the same project. Switch between tools as tokens run out or use the best tool for each task. All environments share the same project state for perfect continuity. [Learn more](.agentic/workflows/environment_switching.md)

## Installation

### Automated install (Recommended)

```bash
# Download latest release
curl -L https://github.com/tomgun/agentic-framework/archive/refs/tags/v0.9.6.tar.gz | tar xz
cd agentic-framework-0.9.4

# Install into your project
bash install.sh /path/to/your-project
```

The install script will:
1. Copy `.agentic/` folder with correct version number
2. Run scaffold script (creates template files)
3. Update `STACK.md` with framework version and install date

**After installation**, tell your agent:

> "Read `.agentic/init/init_playbook.md` and help me initialize this project by filling in STACK.md, PRODUCT.md, and CONTEXT_PACK.md based on what we're building."

The agent will:
- Ask what you're building
- **Ask which profile to use** (Core or Core+PM)
- Interview you about tech stack, constraints, etc.
- Fill in all project-specific details
- Set up quality checks

### Manual install

```bash
# Download and extract
curl -L https://github.com/tomgun/agentic-framework/archive/refs/tags/v0.9.6.tar.gz | tar xz

# Copy .agentic/ into your project
cp -r agentic-framework-0.9.4/.agentic /path/to/your-project/
```

Then follow the same agent initialization process above. The agent will run `scaffold.sh` for you.

## Design Principles

**📖 For comprehensive principles guide, see [`PRINCIPLES.md`](.agentic/PRINCIPLES.md)** ⭐

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
- **Ready-to-use prompts**: Copy-paste workflows from `.agentic/prompts/` (Cursor/Claude)
- **Session continuity**: Generate `.continue-here.md` for instant context recovery
- **Pre-project planning**: Use `VISION.template.md` for ideation phase

### 3. Quality by Design
**Acceptance criteria and tests control unwanted changes.**
- **Acceptance-Driven Development**: Define acceptance criteria (rough OK), implement, then verify with tests
- **Specs evolve during implementation**: Discovery is expected - update specs as you learn
- Tests are mandatory for all new/changed logic
- Design for testability (seams, boundaries, pure functions)
- Definition of Done includes quality gates
- **TDD available**: Optional for those who prefer tests-first (set `development_mode: tdd`)

### 4. Living Documentation
**Documentation stays current through collaboration and automation.**
- Humans add requirements, features, priorities to specs
- Agents update specs when implementing (same commit as code)
- No stale placeholders (`(Not yet created)` gets replaced)
- `FEATURES.md` status matches implementation reality
- Architecture decisions are recorded (ADRs) by whoever makes them
- **Optional: Spec Migrations** - Track evolution as atomic changes for better context management (Tomas Günther & Arto Jalkanen)

### 5. Traceability
**Clear path from requirements to code to tests.**
- Features have stable IDs (`F-0001`) with acceptance criteria
- Code annotated with `@feature F-####` for bidirectional linking
- Test coverage explicitly tracked per feature
- Dependency visualization shows relationships

### 6. Small Batch Development (Critical for Agents!)
**Work in small, isolated batches - one feature at a time.**
- **ONE feature at a time per agent** (multi-agent uses worktrees)
- **MAX 5-10 files per commit** (stop and re-plan if more)
- Acceptance criteria MUST exist before implementation (rough OK)
- Commit when feature's acceptance tests pass
- Update specs with discoveries (edge cases, issues, ideas)
- **Why**: Small changes = easy rollback, known-good checkpoints, clear ownership
- **Critical**: Keeps AI agents focused and prevents context drift

### 7. Iterative & Incremental Development
**Ship in small, validated steps - learn and adapt.**
- Pick one small task from `STATUS.md` or planned features
- Implement with acceptance tests
- Verify criteria are met
- Update docs and specs based on discoveries
- Ship to production (or mark complete) and move to next task
- **Adapt based on learnings**: Requirements evolve through building
- **Validated progress**: Each iteration produces working software

### 8. Human-Agent Collaboration
**Both humans and agents work together on project truth.**
- **Humans**: Read specs, add features/tasks, make decisions, set priorities
- **Agents**: Implement features, update docs with code changes, maintain sync
- Specs are readable and editable by both (markdown files, not complex formats)
- Agents know when to escalate to humans (`HUMAN_NEEDED.md`)
- Tools enable humans to check status without asking agents (token-free queries)

### 9. Green Coding & Environmental Responsibility
**Efficient software reduces energy consumption and environmental impact.**
- Optimize algorithms for computational efficiency (lower complexity)
- Minimize resource usage (memory, CPU cycles, network calls)
- Lazy loading and on-demand resource allocation
- Event-driven instead of polling (webhooks > setInterval)
- Caching reduces redundant compute
- Choose green hosting (renewable energy data centers)
- See [green_coding.md](.agentic/quality/green_coding.md) for comprehensive guidelines

### 10. Anti-Hallucination by Design ⚠️
**Agents NEVER make things up - explicit verification prevents fabricated code.**
- **"I don't know" is explicitly encouraged** when uncertain
- **Version-specific documentation** requirement (Context7 preferred, official docs, source code)
- **Verify before implementing** - no guessing API signatures, endpoints, or library features
- **Document uncertainty** in HUMAN_NEEDED.md
- **Research mode** for unfamiliar technologies
- **Trust docs over training data** (training data may be outdated)
- **Wrong code that looks right is worse than no code** - accuracy > speed
- See [agent_operating_guidelines.md](.agentic/agents/shared/agent_operating_guidelines.md#-critical-anti-hallucination-rules-non-negotiable) for complete rules

## Quick Start

### Agent-driven initialization

**After installation**, tell your agent:

> "Read `.agentic/init/init_playbook.md` and help me initialize this project."

**Or use a ready-made prompt**: Copy from `.agentic/prompts/cursor/session_start.md` or `.agentic/prompts/claude/session_start.md`

The agent will:
1. Ask what you're building
2. **Ask which profile you want** (a=Core or b=Core+PM) and explain the differences
3. Interview you about your tech stack and requirements
4. Fill in `STACK.md`, `PRODUCT.md`, `CONTEXT_PACK.md` (and `spec/` if Core+PM)
5. Set up quality validation for your stack

**Now you're ready!** The agent understands your project and can start building.

**New to the framework?** → Tell your agent: *"Read `.agentic/START_HERE.md` and explain how to use this framework"*

**Pre-project planning?** → See `.agentic/init/VISION.template.md` for ideation-phase template.

### Upgrading existing projects

```bash
# Download new version
curl -L https://github.com/tomgun/agentic-framework/archive/refs/tags/v0.9.6.tar.gz | tar xz
cd agentic-framework-0.9.4

# Run upgrade script with your project path
bash .agentic/tools/upgrade.sh /path/to/your-project
```

The upgrade script will:
- Backup your existing `.agentic/` folder
- Copy new framework files
- Preserve your customizations
- Update version in `STACK.md`
- Run validation

See `UPGRADING.md` for detailed instructions.

### For evaluating the framework

- **Full documentation**: [`.agentic/README.md`](.agentic/README.md)
- **Quick tour**: [`.agentic/START_HERE.md`](.agentic/START_HERE.md)
- **Visual guide**: [`.agentic/FRAMEWORK_MAP.md`](.agentic/FRAMEWORK_MAP.md)
- **Example projects**: [`examples/`](examples/) (Core and Core+PM modes)

See [CHANGELOG.md](CHANGELOG.md) for version history.

## Multi-Environment Support 🔄

**Work seamlessly across Claude Desktop, Cursor, and GitHub Copilot in the same project.**

### Why Multi-Environment?

**Token limits exist:** Claude Desktop (200K) → Cursor (50K) → GitHub Copilot (8K)

Instead of stopping when tokens run out, **switch to another tool and keep working**. The framework makes handoff seamless because all tools share the same project state.

### How It Works

**All environments read/write the same files:**
- `JOURNAL.md` - Session history and decisions
- `FEATURES.md` - Feature status and acceptance criteria
- `STATUS.md` / `PRODUCT.md` - Current project state
- `HUMAN_NEEDED.md` - Blockers requiring human action
- Token-efficient scripts - Work in all environments (40x cheaper than file reads!)

**Example workflow:**
1. **Morning (Claude Desktop)**: Complex feature with full codebase context
2. **Afternoon (Claude tokens low)**: Switch to Cursor, continue implementation
3. **Quick fix needed**: Use Copilot for inline suggestions
4. **Next morning**: Back to Claude, seamless continuation

### Setting Up Multi-Environment

During `init_playbook.md`, choose **"a) Multiple (RECOMMENDED)"** and the framework will:
- Install Claude instructions (`CLAUDE.md` + hooks)
- Install Cursor rules (`.cursor/rules/*.mdc`)
- Install Copilot instructions (`.github/copilot-instructions.md`)
- Configure shared state files
- Set up token-efficient scripts

**Learn more:**
- [Environment Switching Workflow](.agentic/workflows/environment_switching.md) - Complete handoff guide
- [Environment Research](.agentic/support/environment_research.md) - Capabilities & optimizations

### Best Tool for Each Task

**Claude Desktop** (200K context):
- ✅ Complex features requiring full codebase understanding
- ✅ Architectural decisions and planning
- ✅ Research and documentation (artifacts)
- ✅ Initial project setup

**Cursor** (50K context):
- ✅ Multi-file refactors
- ✅ Feature implementation across modules
- ✅ IDE-integrated work with @ mentions
- ✅ Composer mode for batch edits

**GitHub Copilot** (8K context):
- ✅ Quick inline suggestions
- ✅ Single-file edits
- ✅ Small bug fixes
- ✅ When other tools unavailable

**Switching between tools?** Each tool automatically picks up where the previous left off via shared markdown files!

## What You Get

### Core Framework (Always Included)
- **Agent operating guidelines**: Consistent behavior across AI tools
- **Quality standards**: Programming, testing, review, design-for-testability
- **Development workflows**: TDD mode, dev loop, debugging, git workflow
- **Multi-agent coordination**: Multiple agents working in parallel
- **Research mode**: Deep investigation workflows
- **Token efficiency guides**: Reading protocols, context budgeting
- **Basic tools**: doctor, verify, dashboard, sync_docs

### Optional: Product Management Add-On
- **Specification templates**: PRD, Tech Spec, Features, NFR, ADR, Tasks
- **Feature tracking**: Stable IDs, dependencies, status tracking
- **Sequential pipeline**: Specialized agents per feature (Research → Plan → Test → Implement → Review)
- **Project status**: STATUS.md for roadmap and current focus
- **Advanced tools**: Feature graphs, consistency checks, staleness detection
- **Quality automation**: Stack-specific pre-commit validation
- **Retrospectives**: Periodic project health checks

Enable later: `bash .agentic/tools/enable-product-management.sh`

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
- **Continuous quality validation**: Stack-specific quality gates before commits
- **Multi-agent coordination**: Multiple AI agents working simultaneously with Git worktrees
- **PR workflow**: Optional pull request mode for team collaboration

### Tooling
```bash
# Project health & verification
bash .agentic/tools/doctor.sh      # Check structure
bash .agentic/tools/report.sh      # Feature status summary
bash .agentic/tools/verify.sh      # Comprehensive validation
python3 .agentic/tools/validate_specs.py  # Validate spec frontmatter

# Retrospectives & version checking
bash .agentic/tools/retro_check.sh    # Check if retrospective is due
bash .agentic/tools/version_check.sh  # Check dependency versions

# Context & analysis
bash .agentic/tools/brief.sh       # Quick project brief
bash .agentic/tools/dashboard.sh   # Comprehensive dashboard
bash .agentic/tools/coverage.sh    # Code annotation coverage
bash .agentic/tools/feature_graph.sh   # Dependency visualization
bash .agentic/tools/arch_diff.sh   # Architecture changes over time

# Manual operations (token-free)
bash .agentic/tools/search.sh      # Search specs and code
bash .agentic/tools/whatchanged.sh # Recent changes
bash .agentic/tools/deps.sh        # Feature dependencies
bash .agentic/tools/accept.sh      # Run acceptance tests
bash .agentic/tools/consistency.sh # Check doc drift
bash .agentic/tools/stale.sh       # Find stale docs
bash .agentic/tools/task.sh        # Create task files

# Advanced quality (optional)
bash .agentic/tools/mutation_test.sh [path]  # Mutation testing for critical code
```

### Stack Profiles
Quick-start guidance for common technology stacks:
- Generic/default, Full-stack webapp, Native iOS
- Go backend services, Python ML projects
- Rust systems programming, React Native mobile

## Key Artifacts

### Core Profile Files
**Project State:**
- `STACK.md` - How to build, test, run, and deploy (with profile setting)
- `JOURNAL.md` - Session-by-session progress log
- `CONTEXT_PACK.md` - Durable context (architecture, where things are)
- `HUMAN_NEEDED.md` - Items requiring human decision/intervention

### Product Management Profile Adds
**Specifications:**
- `STATUS.md` - Current focus, roadmap, known issues
- `spec/PRD.md` - Requirements (why, what)
- `spec/TECH_SPEC.md` - Architecture (how)
- `spec/FEATURES.md` - Feature registry with IDs, status, tests
- `spec/NFR.md` - Non-functional requirements
- `spec/acceptance/F-####.md` - Acceptance criteria per feature
- `spec/adr/` - Architecture Decision Records

## Examples

- **Scaffold output**: [`examples/example_structure/`](examples/example_structure/) - Freshly scaffolded project structure
- **Working project**: [`examples/inited_project/`](examples/inited_project/) - Complete Next.js Todo app with full specs, tests, and documentation

## For Existing Projects

Already have a project? The framework integrates non-invasively:

1. Download release and extract `.agentic/` folder into your repo
2. Tell your agent: "Initialize the agentic framework for this existing project"
3. Agent analyzes existing code and fills in specs
4. Adopt practices incrementally (tests first, then specs, then workflows)

## Upgrading

**Already using the framework?** Upgrade to the latest version:

```bash
# Download new version (to temp location)
cd /tmp
curl -L https://github.com/tomgun/agentic-framework/archive/refs/tags/v0.9.6.tar.gz | tar xz

# Run upgrade tool from NEW framework, pointing to your project
bash /tmp/agentic-framework-0.9.4/.agentic/tools/upgrade.sh /path/to/your-project

# Clean up
rm -rf /tmp/agentic-framework-0.9.4
```

**Why from the new framework?** The new upgrade script has the latest bug fixes and knows about new structure changes.

See **[`UPGRADING.md`](UPGRADING.md)** for complete upgrade guide, version compatibility, and troubleshooting.

## License & Contributing

**Agentic AI Framework** is proprietary software by **Tomas Günther / Kipinä Software Oy**.

### Three Licensing Options:

1. **Free Tier (with Attribution)** ⭐
   - Use in any personal, open source, or commercial project
   - Must include visible attribution in your product
   - Example: "Built with Agentic AI Framework"

2. **Commercial Tier (White-Label)**
   - €499 one-time OR €99/year per product
   - Remove all attribution requirements
   - Priority support included

3. **Kipinä Software Oy & Employees**
   - Free use without attribution
   - Any projects (personal, commercial, client work)

**See [LICENSE](LICENSE) for complete terms.**

### Attribution Examples (Free Tier)

**Web app footer:**
```html
Built with <a href="https://github.com/tomgun/agentic-framework">Agentic AI Framework</a>
```

**Desktop/Mobile app "About":**
```
Built with Agentic AI Framework
```

**CLI tool `--version`:**
```
Built with Agentic AI Framework (https://github.com/tomgun/agentic-framework)
```

### Commercial License

To purchase white-label license: **tomas@kipina.fi**

---

### Contributing

[Add your contribution guidelines]

## Getting Help

- **Documentation**: Start at [`.agentic/START_HERE.md`](.agentic/START_HERE.md)
- **Examples**: See [`examples/`](examples/) directory
- **Issues**: [Your issue tracker]

---
