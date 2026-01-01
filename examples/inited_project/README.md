# Task Manager CLI Example

This is a fully initialized example project demonstrating the Agentic Framework v0.1.0.

## What it demonstrates

- ✅ Complete STACK.md (how to build/test, framework version tracking)
- ✅ Filled specs (PRD, Tech Spec, Features with F-#### IDs)
- ✅ TDD workflow (tests written first, see test_task_manager.py)
- ✅ Feature tracking (F-0001, F-0002, F-0003 all shipped)
- ✅ Code annotations (`@feature F-####` in code)
- ✅ Acceptance criteria (spec/acceptance/F-*.md)
- ✅ Session tracking (JOURNAL.md shows TDD session)

## Quick start

```bash
# Install dependencies
pip install -r requirements.txt

# Run tests
pytest

# Use the app
python task_cli.py add "Buy milk"
python task_cli.py list
python task_cli.py complete 1
python task_cli.py list
```

## 📊 Generated Reports

The [`reports/`](reports/) directory contains auto-generated snapshots demonstrating the framework's visibility tools:

- **[dashboard.txt](reports/dashboard.txt)**: Quick project status overview
- **[feature-report.txt](reports/feature-report.txt)**: Feature status summary (3 shipped)
- **[feature-graph.md](reports/feature-graph.md)**: Mermaid diagram of feature dependencies
- **[health-check.txt](reports/health-check.txt)**: Project health validation
- **[spec-verification.txt](reports/spec-verification.txt)**: Cross-reference validation
- **[test-coverage.txt](reports/test-coverage.txt)**: Feature → code annotation coverage (100%)

See [`reports/README.md`](reports/README.md) for how to regenerate and when to use each tool.

## Project structure

```
inited_project/
├── task_manager.py       # Core logic (@feature F-0001, F-0002, F-0003)
├── task_cli.py           # CLI interface
├── test_task_manager.py  # Unit tests (TDD)
├── tasks.json            # Data (created on first run)
├── spec/                 # Requirements & features
│   ├── PRD.md
│   ├── TECH_SPEC.md
│   ├── FEATURES.md
│   └── acceptance/
│       ├── F-0001.md     # Add tasks
│       ├── F-0002.md     # List tasks
│       └── F-0003.md     # Complete tasks
├── STACK.md              # Tech stack (Python, pytest, TDD mode)
├── STATUS.md             # All features shipped
├── CONTEXT_PACK.md       # Quick reference
├── JOURNAL.md            # Session log
└── agentic/              # Framework (v0.1.0)
```

## Framework version

This example uses **Agentic Framework v0.1.0**.

See `STACK.md` for framework version tracking.

## Learning points

**TDD workflow:**
- Tests written first (see `test_task_manager.py`)
- Implementation follows tests
- JOURNAL.md documents the TDD session

**Feature tracking:**
- Each feature has F-#### ID
- Acceptance criteria in `spec/acceptance/`
- Code annotated with `@feature` comments
- Test coverage tracked per feature

**Documentation:**
- CONTEXT_PACK.md: Quick reference (10 min to understand)
- STACK.md: How to build/test
- FEATURES.md: What's implemented
- STATUS.md: Current state

**This is a reference example - don't copy it!**  
Download the framework and let the agent initialize YOUR project.

