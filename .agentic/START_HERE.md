# START HERE: Agentic AI Framework Quick Guide

*Shortname: Agentic AF*

**New to this framework?** This guide helps you find what you need based on your situation.

## Quick questions

### 1. Are you setting up a new project?

**Yes** → Go to [New Project Setup](#new-project-setup)  
**No, working on existing project** → Go to [Resume Work](#resume-work)  
**Upgrading framework version** → See [`UPGRADING.md`](../UPGRADING.md)

### 2. What do you need?

**a) Understand how the framework works** → See [Framework Overview](#framework-overview)  
**b) Find a specific document** → See [Document Index](#document-index)  
**c) Understand project structure** → See [What Files Mean](#what-files-mean)  
**d) Troubleshoot an issue** → See [Common Issues](#common-issues)

---

## New Project Setup

### Step 1: Download the framework

```bash
# Download latest release
curl -L https://github.com/tomgun/agentic-framework/archive/refs/tags/v0.1.0.tar.gz | tar xz

# Extract just the agentic folder
cp -r agentic-framework-0.1.0/agentic ./

# Clean up
rm -rf agentic-framework-0.1.0
```

### Step 2: Tell your agent to initialize
Open your AI agent (Cursor/Copilot/Claude) and say:

> "Initialize this project using the agentic framework."

**That's it!** The agent will:
1. Run the scaffold script (creates all files and folders)
2. Ask you questions (what are you building, tech stack, etc.)
3. Fill in `STACK.md`, `CONTEXT_PACK.MD`, `STATUS.md`, and specs
4. Set up quality checks (if applicable)
5. Configure Git workflow
6. Get you ready to develop

**You don't need to run any scripts manually.** The agent follows `.agentic/init/init_playbook.md` automatically.

### What gets created (by the agent)

Files at your repo root:
- `AGENTS.md` - Entry point for AI agents
- `STACK.md` - Tech stack, how to build/test
- `STATUS.md` - Current state and roadmap
- `CONTEXT_PACK.md` - Architecture snapshot
- `JOURNAL.md` - Progress log
- `HUMAN_NEEDED.md` - Items needing human input
- `spec/` directory with templates (PRD, TECH_SPEC, FEATURES, etc.)

**Done!** You're ready to develop. See [Development Workflow](#development-workflow).

---

## Resume Work

### Starting a session (human)
```bash
# Get quick context
bash .agentic/tools/brief.sh

# Or generate a comprehensive continue-here document
python3 .agentic/tools/continue_here.py

# Check status
cat STATUS.md  # or cat PRODUCT.md (in Core mode)

# See recent progress
tail -50 JOURNAL.md
```

**💡 Pro tip**: You can check project state yourself without asking the agent. See [`MANUAL_OPERATIONS.md`](MANUAL_OPERATIONS.md) for a complete guide to token-free information retrieval.

**✏️ Direct editing**: You can also edit spec files directly (add features, update priorities, write acceptance criteria) without talking to the agent. The agent will pick up your changes. See [`DIRECT_EDITING.md`](DIRECT_EDITING.md) for the workflow.

**🤖 Ready-to-use AI prompts**: See [`prompts/cursor/`](prompts/cursor/) or [`prompts/claude/`](prompts/claude/) for copy-paste prompts for common tasks (starting sessions, implementing features, running quality checks, etc.).

### Starting a session (agent)
Agents should read in this order:
1. `.continue-here.md` (if exists - quick recovery document)
2. `CONTEXT_PACK.md` (where things are, how to run)
3. `STATUS.md` or `PRODUCT.md` (current focus, next steps)
4. `JOURNAL.md` last 2-3 entries (recent progress)
5. Relevant feature acceptance criteria (if Core+PM mode)

See [`.agentic/token_efficiency/reading_protocols.md`](token_efficiency/reading_protocols.md) for details.

---

## What to Read

**For humans starting out**:
1. This file (you're reading it!)
2. **[`DEVELOPER_GUIDE.md`](DEVELOPER_GUIDE.md) - Complete developer guide** ⭐⭐⭐
   - How to use the framework daily
   - Manual operations vs. agent operations
   - All automation scripts explained
   - Customization options
   - Best practices
   - **START HERE if you're new!**
3. **[`PRINCIPLES.md`](PRINCIPLES.md) - Framework principles & values** ⭐
   - Why we do what we do
   - Core philosophy
   - Anti-patterns to avoid
   - **Read this to understand the "why"**
4. **[`workflows/USER_WORKFLOWS.md`](workflows/USER_WORKFLOWS.md) - Working with agents** ⭐
   - How to add features, update specs, work with agents
   - Step-by-step workflows and examples
   - Common questions answered
5. [`README.md`](README.md) - Full framework documentation
6. [`MANUAL_OPERATIONS.md`](MANUAL_OPERATIONS.md) - Token-free information retrieval

**For AI agents** (humans can read too):
1. [`agents/shared/agent_operating_guidelines.md`](agents/shared/agent_operating_guidelines.md) - Core rules
2. [`workflows/tdd_mode.md`](workflows/tdd_mode.md) or [`workflows/dev_loop.md`](workflows/dev_loop.md) - Development workflow
3. [`token_efficiency/reading_protocols.md`](token_efficiency/reading_protocols.md) - How to read efficiently
4. **🚨 Working ON the framework itself?** [`FRAMEWORK_DEVELOPMENT.md`](FRAMEWORK_DEVELOPMENT.md) - Additional guidelines for framework development

---

## Framework Overview

### Core principle
**Durable artifacts prevent repeated token waste.**

Instead of agents re-reading the entire codebase every session, maintain:
- **CONTEXT_PACK.md**: "Where is X? How do I Y?"
- **STATUS.md**: "What's happening now?"
- **JOURNAL.md**: "What happened recently?"
- **spec/**: "What should the software do and how?"

### Key artifacts (the "truth" files)

**Project state:**
- [`STACK.md`](../../../STACK.md): How to build, test, run
- [`STATUS.md`](../../../STATUS.md): Current focus, next steps, roadmap
- [`CONTEXT_PACK.md`](../../../CONTEXT_PACK.md): Durable context (where things are)
- [`JOURNAL.md`](../../../JOURNAL.md): Session-by-session progress log

**Specifications:**
- [`spec/PRD.md`](../../../spec/PRD.md): Why and what (requirements)
- [`spec/TECH_SPEC.md`](../../../spec/TECH_SPEC.md): How (architecture, components)
- [`spec/FEATURES.md`](../../../spec/FEATURES.md): Feature registry with acceptance
- [`spec/NFR.md`](../../../spec/NFR.md): Non-functional requirements (performance, security)
- [`spec/acceptance/F-####.md`](../../../spec/acceptance/): Per-feature acceptance criteria
- [`spec/adr/`](../../../spec/adr/): Architecture decision records

**Quality:**
- Test strategy: [`.agentic/quality/test_strategy.md`](quality/test_strategy.md)
- Code review: [`.agentic/quality/review_checklist.md`](quality/review_checklist.md)
- Definition of done: [`.agentic/workflows/definition_of_done.md`](workflows/definition_of_done.md)

### Development workflow

**Sequential Agent Pipeline** (✅ RECOMMENDED for complex features):

Specialized agents work sequentially for optimal context efficiency:

**Pipeline**: Research → Planning → Test → Implementation → Review → Spec Update → Documentation → Git

**Why?** Each agent loads only ~30-50K tokens (vs 150-200K for general agent), focusing on their expertise.

**Enable in STACK.md**:
```yaml
- pipeline_enabled: yes
- pipeline_mode: manual  # Start with manual, graduate to auto
- pipeline_agents: standard  # Research → Planning → Test → Impl → Review → Spec → Docs → Git
```

**Usage**:
- **Manual mode**: `Human: "Research Agent: investigate auth options for F-0042"`
- **Auto mode**: Agents hand off automatically (you approve at key points)

**Details**:
- Agent roles & responsibilities: [`workflows/sequential_agent_specialization.md`](workflows/sequential_agent_specialization.md)
- Automatic coordination: [`workflows/automatic_sequential_pipeline.md`](workflows/automatic_sequential_pipeline.md)
- Monitor: `bash .agentic/tools/pipeline_status.sh F-####`

---

**Single Agent Mode** (for simple features or when learning):

**TDD mode** (✅ RECOMMENDED):
1. Pick work from `STATUS.md`
2. Write failing test FIRST
3. Implement minimal code to pass
4. Refactor if needed
5. Update docs

**Why TDD?** Better token economics (smaller increments, clearer progress, less rework) + forces testable code.

Enable: Set `development_mode: tdd` in `STACK.md` (default in template)  
Details: [`.agentic/workflows/tdd_mode.md`](workflows/tdd_mode.md)

**Standard mode** (for exploration/prototyping):
1. Pick work from `STATUS.md`
2. Check acceptance criteria
3. Implement + test (tests required but can come during/after)
4. Update docs

Enable: Set `development_mode: standard` in `STACK.md`  
Details: [`.agentic/workflows/dev_loop.md`](workflows/dev_loop.md)

---

## What Files Mean

### At repo root (created by scaffold)
- **AGENTS.md**: Entry point for AI agents (points to framework rules)
- **STACK.md**: Tech stack, how to build/test, constraints
- **STATUS.md**: Current state, what's in progress, roadmap
- **CONTEXT_PACK.md**: Durable context (architecture snapshot, where to look)
- **JOURNAL.md**: Session-by-session progress (what was done, what's next, blockers)
- **HUMAN_NEEDED.md**: Items requiring human decision/intervention

### In `spec/` (specifications)
- **PRD.md**: Product requirements (why, what)
- **TECH_SPEC.md**: Technical spec (how, architecture)
- **FEATURES.md**: Feature registry (IDs, status, acceptance, tests)
- **NFR.md**: Non-functional requirements (performance, security, etc.)
- **LESSONS.md**: Lessons learned, caveats
- **REFERENCES.md**: External resources (papers, docs)
- **acceptance/F-####.md**: Detailed acceptance criteria per feature
- **adr/ADR-####.md**: Architecture decision records
- **tasks/**: Task tracking (optional, for complex work)

### In `docs/` (long-lived documentation)
- **README.md**: Project documentation index
- **architecture/**: Architecture diagrams and design docs
- **debugging/**: Troubleshooting guides
- **operations/**: Runbooks, deployment guides
- **research/**: Research findings that informed decisions

### In `.agentic/` (framework itself)
You shouldn't need to edit these - they're the framework:
- **agents/**: Agent-specific rules (Cursor, Copilot, Claude)
- **init/**: Initialization templates and playbook
- **quality/**: Quality guidelines (testing, review, design)
- **spec/**: Specification templates
- **support/**: Stack profiles, doc templates, CI templates
- **token_efficiency/**: Token budgeting and context management
- **tools/**: Automation scripts (brief.sh, report.sh, verify.sh, etc.)
- **workflows/**: Development workflows (dev loop, debugging, etc.)

---

## Document Index

### I need to...

**Understand the project:**
- Overview: `spec/OVERVIEW.md`
- Current state: `STATUS.md`
- Architecture: `spec/TECH_SPEC.md`, `docs/architecture/`
- Recent work: `JOURNAL.md`

**Implement a feature:**
- Feature list: `spec/FEATURES.md`
- Acceptance criteria: `spec/acceptance/F-####.md`
- Dev workflow: `.agentic/workflows/dev_loop.md`
- TDD mode (recommended): `.agentic/workflows/tdd_mode.md`
- Git workflow: `.agentic/workflows/git_workflow.md`
- Code annotations: `.agentic/workflows/code_annotations.md`

**Work with a team / multiple agents:**
- Multi-agent coordination: `.agentic/workflows/multi_agent_coordination.md`
- Git worktrees: `.agentic/workflows/multi_agent_coordination.md#git-worktrees`
- Agent coordination file: `AGENTS_ACTIVE.md`
- PR workflow: `.agentic/workflows/git_workflow.md#pull-request-workflow`

**Write tests:**
- Test strategy: `.agentic/quality/test_strategy.md`
- Integration testing: `.agentic/quality/integration_testing.md`
- Design for testability: `.agentic/quality/design_for_testability.md`
- TDD mode (optional): `.agentic/workflows/tdd_mode.md`

**Understand specifications:**
- Spec templates: `.agentic/spec/*.template.md`
- Spec schema (field definitions, valid values): `.agentic/spec/SPEC_SCHEMA.md`
- Spec validation: `.agentic/workflows/spec_format_validation.md`

**Do research & retrospectives:**
- Project retrospectives: `.agentic/workflows/retrospective.md`
- Research mode: `.agentic/workflows/research_mode.md`
- Documentation verification: `.agentic/workflows/documentation_verification.md`

**Make an architectural decision:**
- ADR template: `.agentic/spec/ADR.template.md`
- Existing ADRs: `spec/adr/`

**Work token-efficiently:**
- Context budgeting: `.agentic/token_efficiency/context_budgeting.md`
- Reading protocols: `.agentic/token_efficiency/reading_protocols.md`
- Small changes: `.agentic/token_efficiency/change_small.md`

**Check quality:**
- Review checklist: `.agentic/quality/review_checklist.md`
- Definition of done: `.agentic/workflows/definition_of_done.md`
- Continuous quality validation: `.agentic/workflows/continuous_quality_validation.md`
- Run verification: `bash .agentic/tools/verify.sh`

**Get project health:**
- `bash .agentic/tools/doctor.sh` - Check structure
- `bash .agentic/tools/report.sh` - Feature status
- `bash .agentic/tools/verify.sh` - Comprehensive checks
- `bash .agentic/tools/coverage.sh` - Code annotation coverage
- `bash .agentic/tools/retro_check.sh` - Check if retrospective is due
- `python3 .agentic/tools/validate_specs.py` - Validate spec frontmatter

---

## Common Issues

### "Agent keeps re-reading the entire codebase"
→ Update `CONTEXT_PACK.md` with structure summaries  
→ Agent should follow `.agentic/token_efficiency/reading_protocols.md`  
→ Use `@feature` annotations to help agents find code

### "Lost track of what we're building"
→ Update `STATUS.md` with current focus  
→ Read `spec/FEATURES.md` for feature list  
→ Read `spec/OVERVIEW.md` for vision

### "Tests are missing or broken"
→ Check `spec/FEATURES.md` for test status  
→ Run `bash .agentic/tools/verify.sh`  
→ Review `.agentic/quality/test_strategy.md`

### "Don't know what to work on next"
→ Check `STATUS.md` "Next up" section  
→ Check `spec/FEATURES.md` for planned features  
→ Check `HUMAN_NEEDED.md` for blocked items

### "Agent context reset mid-task"
→ Check `STATUS.md` "Current session state"  
→ Check recent `JOURNAL.md` entries for exact next step  
→ Agents should update these before context resets

### "Project is getting complex and hard to navigate"
→ See `.agentic/workflows/scaling_guidance.md` for reorganization suggestions  
→ Consider splitting large files (FEATURES.md, NFR.md, CONTEXT_PACK.md)

---

## Framework Map

See [`FRAMEWORK_MAP.md`](FRAMEWORK_MAP.md) for a visual diagram of how everything connects.

---

## Quick Command Reference

**📖 For comprehensive commands and examples, see:**
- [`DEVELOPER_GUIDE.md#quick-reference`](DEVELOPER_GUIDE.md#quick-reference) - Full command table with explanations
- [`MANUAL_OPERATIONS.md`](MANUAL_OPERATIONS.md) - Token-free quick operations

**Essential commands:**
```bash
# Project health
bash .agentic/tools/doctor.sh       # Check structure
bash .agentic/tools/verify.sh       # Comprehensive verification

# Project status
cat STATUS.md                        # Current focus
tail -30 JOURNAL.md                  # Recent work
cat HUMAN_NEEDED.md                  # Blockers

# Feature info
bash .agentic/tools/report.sh       # Feature summary
bash .agentic/tools/feature_graph.sh # Dependencies
```

See the guides above for 30+ available commands with detailed explanations.

---

## Next steps

1. **New project?** Run `bash .agentic/init/scaffold.sh` then agent init
2. **Existing project?** Read `CONTEXT_PACK.md` → `STATUS.md` → `JOURNAL.md`
3. **Need deep understanding?** See [`FRAMEWORK_MAP.md`](FRAMEWORK_MAP.md)
4. **Ready to code?** Follow [`.agentic/workflows/dev_loop.md`](workflows/dev_loop.md)

