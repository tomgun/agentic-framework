# Next.js Evolved Task App Example

A **mature, production-ready** Next.js task management app demonstrating the Agentic Framework v0.1.0 with retrospectives, research, and advanced quality automation.

## What This Demonstrates

This is an **evolved project** showing ~2 months of development:

### 🎯 Core Features
- ✅ **8 features** (5 shipped, 2 in progress, 1 planned)
- ✅ **3 releases** (v1.0.0, v1.1.0, v1.2.0)
- ✅ **3 ADRs** (Architectural Decision Records with rationale)

### 🔄 Process Maturity
- ✅ **2 retrospectives** with action items tracked
- ✅ **2 research sessions** (testing strategies, React 19 patterns)
- ✅ **PR workflow** (feature branches, CI checks)
- ✅ **TDD throughout** (tests written first)

### 🔍 Quality Automation
- ✅ **Lighthouse CI** (performance 91, accessibility 96)
- ✅ **Bundle monitoring** (445kb, threshold 500kb)
- ✅ **a11y linting** (catches issues early)
- ✅ **E2E tests** (Playwright, 5 critical paths)
- ✅ **92% test coverage** (unit + integration + E2E)

### 📚 Documentation
- ✅ **Context7 enabled** (version-specific API validation)
- ✅ **Research trails** documenting technology decisions
- ✅ **Retrospective history** showing project evolution
- ✅ **ADRs** explaining architectural choices

## Quick Start

```bash
npm install
npm run dev        # http://localhost:3000
npm test           # Unit tests
npm run test:e2e   # E2E tests
bash quality_checks.sh --pre-commit  # Fast quality checks
bash quality_checks.sh --full        # Full suite (Lighthouse, etc.)
```

## 📊 Generated Reports

The [`reports/`](reports/) directory contains auto-generated snapshots demonstrating the framework's visibility tools for a mature project:

- **[dashboard.txt](reports/dashboard.txt)**: Project status overview
- **[feature-report.txt](reports/feature-report.txt)**: Feature summary (6 shipped, 2 in progress, 3 planned)
- **[feature-graph.md](reports/feature-graph.md)**: Mermaid diagram showing 11 features + dependencies
- **[health-check.txt](reports/health-check.txt)**: Project health check
- **[spec-verification.txt](reports/spec-verification.txt)**: Validates ADRs, retrospectives, research links
- **[retro-check.txt](reports/retro-check.txt)**: Checks if retrospective is due

See [`reports/README.md`](reports/README.md) for how to regenerate these and explore additional tools (`whatchanged.sh`, `deps.py`, `search.sh`, etc.).

## Project Structure

```
nextjs_evolved/
├── app/                      # Next.js App Router
├── components/               # React components (Server + Client)
├── lib/store.ts              # Zustand state (ADR-0001)
├── __tests__/                # Unit tests (Vitest)
├── e2e/                      # E2E tests (Playwright)
├── spec/                     # Requirements & features
│   ├── FEATURES.md           # 8 features with full tracking
│   ├── adr/                  # 3 ADRs with rationale
│   ├── acceptance/           # Acceptance criteria per feature
│   └── retrospectives/       # 2 retrospectives
├── docs/
│   └── research/             # 2 research sessions
├── quality_checks.sh         # Automated quality gates
├── playwright.config.ts      # E2E test config
└── agentic/                  # Framework (v0.1.0)
```

## Features

### Shipped (v1.0.0 - v1.2.0)
- F-0001: Add tasks ✅
- F-0002: List tasks ✅
- F-0003: Complete tasks ✅
- F-0004: Filter tasks ✅
- F-0005: Delete tasks ✅
- F-0006: E2E test infrastructure (Playwright) ✅

### In Progress (v1.3.0)
- F-0007: Server Component optimization 🔄
- F-0008: Per-page metadata (SEO) 🔄

### Planned
- F-0009: Virtualization (large lists)
- F-0010: Multi-tab sync
- F-0011: Dark mode

## Architectural Decisions (ADRs)

1. **ADR-0001: Zustand for State Management**
   - Replaced direct localStorage (tech debt from v1.0.0)
   - Enables reactive updates, simpler testing
   - Bundle: +3.5kb

2. **ADR-0002: Tailwind CSS for Styling**
   - Replaced CSS Modules
   - Consistent design system, faster iteration
   - Bundle: -20kb (purging)

3. **ADR-0003: Playwright for E2E Testing**
   - Research-driven decision (see `docs/research/testing-strategies.md`)
   - Best Next.js 15 + React Server Components support
   - Caught 1 bug immediately

## Retrospectives

### RETRO-2025-12-30 (v1.0.0)
- **Shipped**: F-0001, F-0002, F-0003
- **Issues**: Accessibility 88/100, no E2E tests
- **Actions**: Fix a11y, research Playwright, add linting
- **Outcome**: All 4 action items completed ✅

### RETRO-2026-01-13 (v1.1.0, v1.2.0)
- **Shipped**: F-0004, F-0005, F-0006
- **Improvements**: A11y 96/100, E2E tests added, PR workflow
- **Issues**: Bundle growing (+65kb), perf on large lists
- **Actions**: Research bundle optimization, virtualization
- **Outcome**: 2/4 in progress, 2 planned

## Research Sessions

### Testing Strategies (2025-12-31)
- **Question**: Best E2E framework for Next.js 15 + React 19?
- **Compared**: Playwright vs Cypress vs Testing Library
- **Decision**: Playwright (best Server Components support)
- **Outcome**: ADR-0003, F-0006 implemented

### React 19 Patterns (2026-01-02)
- **Question**: Are we using React 19 best practices?
- **Findings**: 3 optimizations (Server Components, metadata, Suspense)
- **Actions**: F-0007 (Server Components), F-0008 (metadata)
- **Outcome**: ~50kb bundle reduction expected

## Quality Metrics

| Metric | Current | Target | Status |
|--------|---------|--------|--------|
| Test coverage | 92% | 90% | ✅ |
| Bundle size | 445kb | <500kb | ✅ |
| Lighthouse Perf | 91 | >90 | ✅ |
| Lighthouse A11y | 96 | >95 | ✅ |
| Lighthouse SEO | 88 | >85 | ✅ |

## Tech Stack

- **Next.js 15.1** (App Router, Server Components)
- **React 19** (latest patterns)
- **TypeScript 5.7** (strict mode)
- **Zustand** (state management, ADR-0001)
- **Tailwind CSS** (styling, ADR-0002)
- **Vitest** (unit tests, TDD)
- **Playwright** (E2E tests, ADR-0003)
- **Context7** (doc verification)

## Comparison to `inited_project/`

| Aspect | inited_project (Python) | nextjs_evolved (Next.js) |
|--------|------------------------|--------------------------|
| **Maturity** | Just initialized | 2 months evolved |
| **Features** | 3 | 8 (5 shipped, 2 in progress, 1 planned) |
| **Releases** | v1.0.0 | v1.0.0, v1.1.0, v1.2.0 |
| **Tests** | Unit only | Unit + Integration + E2E |
| **Quality** | Basic | Full automation (Lighthouse, bundle, a11y) |
| **Retrospectives** | None | 2 completed |
| **Research** | None | 2 sessions |
| **ADRs** | None | 3 documented |
| **Git workflow** | Direct commits | Pull requests + CI |

## Learning Value

This example shows:
1. **How projects evolve** over time
2. **Retrospective-driven improvements** (accessibility, testing, quality)
3. **Research-informed decisions** (Playwright, React 19 patterns)
4. **Quality automation maturity** (from basic to production-grade)
5. **Technical debt resolution** (localStorage → Zustand)
6. **Architectural evolution** (ADRs documenting major changes)

## Usage Note

**This is a reference example - don't copy it!**

Download the framework and let the agent initialize YOUR project:

```bash
curl -L https://github.com/tomgun/agentic-framework/archive/refs/tags/v0.1.0.tar.gz | tar xz
cp -r agentic-framework-0.1.0/agentic ./
# Then tell your agent to initialize
```

## Framework Version

- **Agentic Framework v0.1.0**
- See `STACK.md` for version tracking

