# CONTEXT_PACK.md

**Quick intent**: A mature Next.js task management web app demonstrating the agentic framework v0.1.0 with retrospectives, research, and production-grade quality automation.

## Where to look first (map)

**Entry points:**
- Web app: `app/page.tsx` (home/task list)
- State management: `lib/store.ts` (Zustand store, @feature F-0004)
- Components: `components/TaskForm.tsx`, `components/TaskList.tsx`
- Tests: `__tests__/`, `e2e/`

**Project structure:**
```
nextjs_evolved/
├── app/                      # Next.js App Router pages
│   ├── page.tsx              # Home/task list (@feature F-0001, F-0002)
│   └── layout.tsx            # Root layout
├── components/               # React components
│   ├── TaskForm.tsx          # Add task form (@feature F-0001)
│   ├── TaskList.tsx          # Task list (@feature F-0002)
│   ├── TaskRow.tsx           # Individual task (@feature F-0003, F-0005)
│   └── TaskFilter.tsx        # Filter controls (@feature F-0004)
├── lib/
│   └── store.ts              # Zustand state (@feature F-0004, ADR-0001)
├── __tests__/                # Unit tests (Vitest)
├── e2e/                      # E2E tests (Playwright)
├── spec/                     # Requirements & features
│   ├── adr/                  # Architectural Decision Records
│   │   ├── ADR-0001-zustand-state-management.md
│   │   ├── ADR-0002-tailwind-css.md
│   │   └── ADR-0003-playwright-e2e-testing.md
│   └── retrospectives/       # Project retrospectives
│       ├── RETRO-2025-12-30.md
│       └── RETRO-2026-01-13.md
└── agentic/                  # Framework (v0.1.0)
```

## How to run / test

**Development:**
```bash
npm install
npm run dev  # http://localhost:3000
```

**Testing:**
```bash
npm test              # Unit tests (Vitest)
npm run test:e2e      # E2E tests (Playwright)
npm run test:all      # All tests
```

**Quality checks:**
```bash
bash quality_checks.sh --pre-commit  # Quick checks
bash quality_checks.sh --full        # Full suite (Lighthouse, bundle analysis)
```

## Current top priorities

### Shipped (v1.0.0 - v1.2.0)
1. F-0001: Add tasks ✅
2. F-0002: List tasks ✅
3. F-0003: Complete tasks ✅
4. F-0004: Filter tasks ✅
5. F-0005: Delete tasks ✅

### In Progress (v1.3.0)
6. F-0007: Server Component optimization 🔄
7. F-0008: Per-page metadata 🔄

### Planned (Future)
8. F-0009: Virtualization for large lists 📋
9. F-0010: Multi-tab synchronization 📋
10. F-0011: Dark mode 📋

## Architecture snapshot

**Style:** Next.js App Router with React Server Components

**Key modules:**
- `lib/store.ts`: Zustand store with persistence (ADR-0001)
- `components/*`: Mix of Server and Client Components
- `app/*`: App Router pages

**Data flow:**
```
UI Component → Zustand Store → localStorage
                    ↓
            Automatic persistence
            Storage event sync (multi-tab)
```

**Quality automation:**
- Pre-commit: TypeScript, ESLint, tests, bundle size
- Full suite: Lighthouse (performance, a11y), bundle breakdown
- E2E: Playwright tests for critical paths

## Technology choices

- **Next.js 15.1**: App Router, Server Components, React 19
- **Zustand**: State management (ADR-0001)
- **Tailwind CSS**: Styling (ADR-0002)
- **Playwright**: E2E testing (ADR-0003)
- **Vitest**: Unit testing (TDD approach)
- **Context7**: Documentation verification (version-specific API validation)

## Project maturity indicators

- **2 retrospectives completed**: Quality improvements, action items tracked
- **3 ADRs documented**: Major architectural decisions with rationale
- **2 research sessions**: Testing strategies, React 19 patterns
- **PR workflow**: Feature branches, CI checks, human review
- **Quality automation**: Lighthouse, bundle monitoring, a11y linting
- **Test coverage**: 92% (unit + integration + E2E)
- **3 releases**: v1.0.0, v1.1.0, v1.2.0

## Known risks / sharp edges

- **Bundle size growth**: 445kb (acceptable, but monitor)
- **Performance on >100 tasks**: Needs virtualization (F-0009)
- **localStorage limitations**: No server-side persistence (demo only)

## Recent quality improvements

From retrospectives:
1. ✅ Accessibility: 88 → 96 (added ARIA labels, contrast fixes)
2. ✅ E2E tests: 0 → 5 critical path tests (Playwright)
3. ✅ Bundle monitoring: Added size breakdown reports
4. ✅ a11y linting: Prevents regressions

## Onboarding cost

**Time to understand:** 30-45 minutes

**Quickstart:**
1. Read: STACK.md (tech stack + quality automation)
2. Read: spec/FEATURES.md (what's implemented)
3. Read: spec/adr/* (architectural decisions)
4. Run: `npm test && npm run dev`
5. Review: `docs/retrospectives/` (project evolution)
6. Review: `docs/research/` (technology decisions)

**This is an evolved project showing 2 months of development with retrospectives, research, and continuous quality improvements.**
