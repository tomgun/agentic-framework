# Examples

This directory contains example projects demonstrating the Agentic Framework in use.

## Examples

### 1. example_structure/
**What it shows:** Empty project structure created by `scaffold.sh`

This is what you get after running the scaffold script but before filling in any content. Shows:
- All required files (STACK.md, STATUS.md, CONTEXT_PACK.md, etc.)
- Directory structure (spec/, docs/, etc.)
- Empty templates ready to be filled

**When to reference:** To understand what files the framework creates and where they live.

---

### 2. inited_project/ (Python CLI - Simple)
**What it shows:** Newly initialized project using TDD

A simple Python task manager CLI demonstrating:
- **TDD workflow**: Tests written first (red-green-refactor)
- **Complete specs**: PRD, Tech Spec, Features (F-0001, F-0002, F-0003)
- **Code annotations**: `@feature F-####` in code
- **Acceptance criteria**: Per-feature files
- **Framework v0.1.0**: Version tracking in STACK.md

**Complexity level:** ⭐ Beginner/Simple
- 3 features (all shipped)
- ~200 lines of code
- Pure unit tests
- Single-user CLI tool

**Tech stack:** Python 3.12, pytest

**When to reference:** Learning the framework basics, understanding TDD workflow.

---

### 3. nextjs_evolved/ (Next.js - Evolved)
**What it shows:** Mature project with retrospectives, research, and quality validation

A Next.js task management web app showing an **evolved, production-ready project**:
- **Retrospectives**: 2 completed retrospectives in `docs/retrospectives/`
- **Research**: Field research on React 19 and Next.js 15 in `docs/research/`
- **Quality validation**: Lighthouse scores, bundle size monitoring, a11y checks
- **PR workflow**: Feature branches, pull requests, CI checks
- **Documentation verification**: Context7 enabled, version-specific API validation
- **Advanced features**: 8 features across 3 releases
- **Architecture evolution**: Tracked ADRs showing design decisions over time

**Complexity level:** ⭐⭐⭐ Advanced/Mature
- 8 features (5 shipped, 2 in progress, 1 planned)
- 3 releases documented
- Integration tests, E2E tests (Playwright)
- Multiple retrospectives with action items
- Research trails informing decisions
- Quality gates enforced

**Tech stack:** Next.js 15.1, React 19, TypeScript, Vitest, Playwright

**When to reference:** Understanding long-term framework usage, seeing how projects evolve over time, learning advanced features.

---

## Comparison

| Aspect | inited_project (Python) | nextjs_evolved (Next.js) |
|--------|------------------------|--------------------------|
| **Maturity** | Just initialized | Evolved over 2 months |
| **Features** | 3 (all shipped) | 8 (5 shipped, ongoing) |
| **Releases** | v1.0.0 | v1.0.0, v1.1.0, v1.2.0 |
| **Tests** | Unit only | Unit + Integration + E2E |
| **Quality** | Basic | Full automation (Lighthouse, bundle, a11y) |
| **Retrospectives** | None yet | 2 completed |
| **Research** | None yet | React 19, Next.js 15, Testing strategies |
| **ADRs** | None yet | 3 (state management, styling, testing) |
| **Git workflow** | Direct commits | Pull requests + CI |
| **Docs verification** | Manual | Context7 enabled |

---

## 📊 Auto-Generated Reports

Each example includes a `reports/` directory with auto-generated tool outputs:
- **Dashboard**: Quick project status
- **Feature report**: Status summary (shipped/in_progress/planned)
- **Feature graph**: Mermaid dependency diagram
- **Health check**: Project validation
- **Spec verification**: Cross-reference validation
- **Test coverage**: Feature → code annotation mapping

These demonstrate the framework's **visibility tools** that help both humans and AI agents quickly understand project state. See each example's `reports/README.md` for details.

## Using These Examples

**Don't copy these into your project!**

These are for reference/learning only. To start your own project:

```bash
# Download framework release
curl -L https://github.com/tomgun/agentic-framework/archive/refs/tags/v0.1.0.tar.gz | tar xz
cp -r agentic-framework-0.1.0/agentic ./

# Tell your agent to initialize
# Agent will create appropriate structure for YOUR project
```

## Framework Version

These examples are compatible with:
- **Agentic Framework v0.1.0**

If you're using a different version, some files/features may differ.

## Learning Path

1. **Start with `example_structure/`**: Understand the framework structure
2. **Study `inited_project/`**: Learn TDD workflow and basic usage
3. **Explore `nextjs_evolved/`**: See how projects mature and use advanced features

Each example builds on the previous concepts!
