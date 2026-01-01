# ADR-0003: Use Playwright for E2E Testing

**Status**: Accepted  
**Date**: 2026-01-10  
**Deciders**: AI Agent, Human Developer  
**Technical Story**: Add E2E testing to catch user flow issues

## Context

v1.0.0 had only unit tests (Vitest). This missed bugs:
- Form submission on Enter key didn't work
- Task list scrolling broke on mobile
- Browser back button cleared form state

Research (see `docs/research/testing-strategies.md`) compared options.

## Decision Drivers

- Must test real user flows (not mocked)
- Must work with Next.js 15 + React Server Components
- Should be fast enough for CI (<2 min)
- Must support parallel test execution
- TypeScript support required

## Options Considered

### Option 1: Cypress
**Pros:**
- Mature ecosystem
- Great visual runner

**Cons:**
- Slower (single-threaded)
- Complex setup with Server Components
- Some Next.js 15 features not supported yet

### Option 2: Playwright
**Pros:**
- ✅ Fast (parallel execution)
- ✅ Great Next.js integration
- ✅ Works with Server Components (no config)
- ✅ Built-in codegen tool
- ✅ Video/screenshot on failure
- ✅ Industry standard (used by Vercel, GitHub)

**Cons:**
- Larger learning curve
- Requires browser install (~200MB)

## Decision

**Adopt Playwright**

## Implementation

```typescript
// playwright.config.ts
import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  use: {
    baseURL: 'http://localhost:3000',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure'
  },
  webServer: {
    command: 'npm run dev',
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI
  }
});
```

```typescript
// e2e/tasks.spec.ts
import { test, expect } from '@playwright/test';

test('add task flow', async ({ page }) => {
  await page.goto('/');
  
  // @feature F-0001
  await page.fill('input[name="title"]', 'Buy milk');
  await page.click('button[type="submit"]');
  
  // @acceptance spec/acceptance/F-0001.md#AC1
  await expect(page.locator('text=Buy milk')).toBeVisible();
});
```

## Consequences

### Positive
- ✅ Caught 1 bug immediately (Enter key submission)
- ✅ Fast tests (~30 seconds for 5 tests)
- ✅ Great DX (codegen, trace viewer)
- ✅ CI integration straightforward

### Negative
- ❌ Browser install adds ~200MB to CI cache
- ❌ Team must learn Playwright API
- ❌ Slightly slower CI builds (+1 min)

## Compliance

- Follows Vercel/Next.js testing recommendations
- Compatible with GitHub Actions, GitLab CI
- No conflicts with existing Vitest tests

## Test Strategy

- **Unit tests (Vitest)**: Business logic, utilities
- **Integration tests (Vitest + Testing Library)**: Component behavior
- **E2E tests (Playwright)**: Critical user flows

Playwright tests only for **critical paths**:
- Add task (F-0001)
- Complete task (F-0003)
- Filter tasks (F-0004)
- Delete task (F-0005)

## Related

- Action item A-002 from RETRO-2025-12-30
- Research: `docs/research/testing-strategies.md`
- Feature: F-0006 (E2E test infrastructure)
- Affects all features (now have E2E coverage)

