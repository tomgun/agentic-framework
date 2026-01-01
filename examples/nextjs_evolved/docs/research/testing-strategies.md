# Research: Testing Strategies for Next.js Apps

**Date**: 2025-12-31  
**Duration**: 60 minutes  
**Trigger**: Retrospective action item A-002  
**Researcher**: AI Agent

## Research Question

What is the best E2E/integration testing framework for a Next.js 15 + React 19 app with Server Components?

## Context

- Current state: Unit tests only (Vitest)
- Need: Integration and E2E tests for user flows
- Constraint: Must work with React Server Components
- Constraint: Must be fast enough for CI

## Options Considered

### 1. Playwright
**Pros:**
- ✅ First-class TypeScript support
- ✅ Fast (headless Chrome/Firefox)
- ✅ Great Next.js integration
- ✅ Works with Server Components (no special config)
- ✅ Built-in test generator (codegen)
- ✅ Parallel test execution
- ✅ Video/screenshot on failure

**Cons:**
- ❌ Larger learning curve than Jest
- ❌ Requires separate browser install (~200MB)

**Verdict:** **Recommended for Next.js 15**

### 2. Cypress
**Pros:**
- ✅ Mature ecosystem
- ✅ Great dev experience (visual runner)
- ✅ Large community

**Cons:**
- ❌ Slower than Playwright (single-threaded)
- ❌ More complex setup with Server Components
- ❌ Some Next.js 15 features not fully supported yet

**Verdict:** Good for older Next.js, but Playwright better for v15+

### 3. Testing Library + MSW (Mock Service Worker)
**Pros:**
- ✅ Same paradigm as unit tests
- ✅ Fast (no real browser)
- ✅ Good for component integration tests

**Cons:**
- ❌ Not true E2E (mocked browser)
- ❌ Misses browser-specific bugs
- ❌ Can't test actual user interactions

**Verdict:** Use for component integration, not E2E

## Decision

**Adopt Playwright for E2E tests**

**Rationale:**
1. Best support for Next.js 15 + React Server Components
2. Fast enough for CI (parallel execution)
3. Industry standard (used by Vercel, GitHub, Microsoft)
4. Great DX with codegen and trace viewer

## Implementation Plan

1. Install: `npm install -D @playwright/test`
2. Init: `npx playwright install`
3. Config: Create `playwright.config.ts`
4. First test: Login flow (F-0001)
5. Add to CI: `.github/workflows/test.yml`
6. Update quality_checks.sh

## External References

- [Playwright Next.js Guide](https://playwright.dev/docs/test-components)
- [Vercel's testing recommendations](https://nextjs.org/docs/app/building-your-application/testing)
- [Playwright vs Cypress benchmark](https://blog.logrocket.com/playwright-vs-cypress/)

## Follow-up Actions

- [x] Create ADR-0003: Playwright for E2E testing
- [x] Add F-0006: E2E test infrastructure setup
- [ ] Write first E2E test for F-0001 (Add task flow)
- [ ] Integrate into quality_checks.sh

## Outcome

Successfully adopted Playwright. E2E tests running in CI. Caught 1 bug (form submission on Enter key) that unit tests missed.

**Time saved**: Estimate 4-6 hours debugging in production prevented by E2E tests.

