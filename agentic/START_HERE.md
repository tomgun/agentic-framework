# START HERE: Agentic Framework Quick Guide

**New to this framework?** This guide helps you find what you need based on your situation.

## Quick questions

### 1. Are you setting up a new project?

**Yes** → Go to [New Project Setup](#new-project-setup)  
**No, working on existing project** → Go to [Resume Work](#resume-work)

### 2. What do you need?

**a) Understand how the framework works** → See [Framework Overview](#framework-overview)  
**b) Find a specific document** → See [Document Index](#document-index)  
**c) Understand project structure** → See [What Files Mean](#what-files-mean)  
**d) Troubleshoot an issue** → See [Common Issues](#common-issues)

---

## New Project Setup

### Step 1: Copy framework into your repo
```bash
# Copy the agentic/ folder into your project root
cp -r /path/to/agentic-framework/agentic ./
```

### Step 2: Run scaffold script
```bash
# Creates all required files and folders
bash agentic/init/scaffold.sh
```

### Step 3: Agent-guided initialization
Open your AI agent (Cursor/Copilot/Claude) and say:

> "Initialize this project using the agentic framework. Follow `agentic/init/init_playbook.md`."

The agent will ask you questions and fill in:
- `STACK.md` (how to build/test)
- `CONTEXT_PACK.md` (where things are)
- `STATUS.md` (what's happening)
- `spec/PRD.md` and `spec/TECH_SPEC.md` (what/how to build)

**Done!** You're ready to develop. See [Development Workflow](#development-workflow).

---

## Resume Work

### Starting a session (human)
```bash
# Get quick context
bash agentic/tools/brief.sh

# Check status
cat STATUS.md

# See recent progress
tail -50 JOURNAL.md
```

### Starting a session (agent)
Agents should read in this order:
1. `CONTEXT_PACK.md` (where things are, how to run)
2. `STATUS.md` (current focus, next steps)
3. `JOURNAL.md` last 2-3 entries (recent progress)
4. Relevant feature acceptance criteria

See [`agentic/token_efficiency/reading_protocols.md`](token_efficiency/reading_protocols.md) for details.

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
- Test strategy: [`agentic/quality/test_strategy.md`](quality/test_strategy.md)
- Code review: [`agentic/quality/review_checklist.md`](quality/review_checklist.md)
- Definition of done: [`agentic/workflows/definition_of_done.md`](workflows/definition_of_done.md)

### Development workflow

**Small increments loop:**
1. Pick work from `STATUS.md`
2. Check acceptance criteria (spec/acceptance/F-####.md)
3. Implement + test
4. Update `STATUS.md`, `JOURNAL.md`, `spec/FEATURES.md`

Details: [`agentic/workflows/dev_loop.md`](workflows/dev_loop.md)

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

### In `agentic/` (framework itself)
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
- Dev workflow: `agentic/workflows/dev_loop.md`
- Code annotations: `agentic/workflows/code_annotations.md`

**Write tests:**
- Test strategy: `agentic/quality/test_strategy.md`
- Integration testing: `agentic/quality/integration_testing.md`
- Design for testability: `agentic/quality/design_for_testability.md`

**Make an architectural decision:**
- ADR template: `agentic/spec/ADR.template.md`
- Existing ADRs: `spec/adr/`

**Work token-efficiently:**
- Context budgeting: `agentic/token_efficiency/context_budgeting.md`
- Reading protocols: `agentic/token_efficiency/reading_protocols.md`
- Small changes: `agentic/token_efficiency/change_small.md`

**Check quality:**
- Review checklist: `agentic/quality/review_checklist.md`
- Definition of done: `agentic/workflows/definition_of_done.md`
- Run verification: `bash agentic/tools/verify.sh`

**Get project health:**
- `bash agentic/tools/doctor.sh` - Check structure
- `bash agentic/tools/report.sh` - Feature status
- `bash agentic/tools/verify.sh` - Comprehensive checks
- `bash agentic/tools/coverage.sh` - Code annotation coverage

---

## Common Issues

### "Agent keeps re-reading the entire codebase"
→ Update `CONTEXT_PACK.md` with structure summaries  
→ Agent should follow `agentic/token_efficiency/reading_protocols.md`  
→ Use `@feature` annotations to help agents find code

### "Lost track of what we're building"
→ Update `STATUS.md` with current focus  
→ Read `spec/FEATURES.md` for feature list  
→ Read `spec/OVERVIEW.md` for vision

### "Tests are missing or broken"
→ Check `spec/FEATURES.md` for test status  
→ Run `bash agentic/tools/verify.sh`  
→ Review `agentic/quality/test_strategy.md`

### "Don't know what to work on next"
→ Check `STATUS.md` "Next up" section  
→ Check `spec/FEATURES.md` for planned features  
→ Check `HUMAN_NEEDED.md` for blocked items

### "Agent context reset mid-task"
→ Check `STATUS.md` "Current session state"  
→ Check recent `JOURNAL.md` entries for exact next step  
→ Agents should update these before context resets

### "Project is getting complex and hard to navigate"
→ See `agentic/workflows/scaling_guidance.md` for reorganization suggestions  
→ Consider splitting large files (FEATURES.md, NFR.md, CONTEXT_PACK.md)

---

## Framework Map

See [`FRAMEWORK_MAP.md`](FRAMEWORK_MAP.md) for a visual diagram of how everything connects.

---

## Quick command reference

```bash
# Project health
bash agentic/tools/doctor.sh       # Check structure
bash agentic/tools/report.sh       # Feature status summary
bash agentic/tools/verify.sh       # Comprehensive verification

# Context and briefing
bash agentic/tools/brief.sh        # Quick project brief

# Analysis
bash agentic/tools/feature_graph.sh    # Feature dependency graph
bash agentic/tools/coverage.sh         # Code annotation coverage
bash agentic/tools/arch_diff.sh        # Architecture changes over time

# Documentation
bash agentic/tools/sync_docs.sh    # Generate doc scaffolding
```

---

## Next steps

1. **New project?** Run `bash agentic/init/scaffold.sh` then agent init
2. **Existing project?** Read `CONTEXT_PACK.md` → `STATUS.md` → `JOURNAL.md`
3. **Need deep understanding?** See [`FRAMEWORK_MAP.md`](FRAMEWORK_MAP.md)
4. **Ready to code?** Follow [`agentic/workflows/dev_loop.md`](workflows/dev_loop.md)

