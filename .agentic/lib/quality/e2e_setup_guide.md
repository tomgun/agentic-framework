# E2E Setup Guide

Agent playbook for setting up E2E tests based on project type. After setup, update STACK.md with the test command and screenshot directory.

## Web Apps (recommended: Playwright)

```bash
npm init playwright@latest
```

Example `playwright.config.ts`:
```ts
export default defineConfig({
  testDir: './tests/e2e',
  use: { screenshot: 'on' },
  webServer: { command: 'npm run dev', port: 3000 },
});
```

STACK.md fields:
```markdown
- E2E: `npx playwright test`
- E2E screenshots: test-results/
```

## Backend / API

Use supertest (Node) or pytest+httpx (Python). No visual review needed.

```bash
# Node
npm install --save-dev supertest

# Python
pip install httpx pytest
```

STACK.md fields:
```markdown
- E2E API: `pytest tests/e2e/api/`
```

## CLI Tools

Use bash scripts or bats-core. No visual review.

```bash
# Install bats
npm install --save-dev bats
```

STACK.md fields:
```markdown
- E2E CLI: `npx bats tests/e2e/`
```

## Mobile (React Native: Detox)

```bash
npm install --save-dev detox
npx detox init
```

STACK.md fields:
```markdown
- E2E Mobile: `detox test --configuration ios.sim.release`
- E2E screenshots: artifacts/
```

## Games (Web)

Use Playwright for browser-based games. Visual review is particularly useful here.

```bash
npm init playwright@latest
```

STACK.md fields:
```markdown
- E2E Game: `npx playwright test`
- E2E screenshots: test-results/
```

## Audio / VST Plugins

DSP validation is typically a separate tier. Visual review only for UI tier.

STACK.md fields:
```markdown
- DSP: `python3 tests/dsp_validation.py`
- E2E UI: `npx playwright test tests/ui/`
- E2E screenshots: test-results/
```
