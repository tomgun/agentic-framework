# E2E Testing Contract

The framework's verify loop treats E2E tests as just another tier. This document defines the tool-agnostic contract between the framework and any E2E test setup.

## Contract

1. **A shell command** that returns exit 0 (pass) or non-zero (fail). Configured in STACK.md under `Test commands:`.
2. **Parseable output** (optional). The verify loop can parse Playwright, Cypress, pytest, Jest, Go, and Cargo output formats. Falls back to exit code if format is unrecognized.
3. **Screenshots in a known directory** (optional). Configure `E2E screenshots:` in STACK.md. The verify loop collects images after each tier run.
4. **Server management** is the test's responsibility. Use the framework's built-in mechanisms (Playwright's `webServer`, Cypress's `startDevServer`, or a `beforeAll` hook).

## Known Framework Patterns

| Framework | Command | Config | Screenshots Dir |
|-----------|---------|--------|-----------------|
| Playwright | `npx playwright test` | `playwright.config.ts` | `test-results/` |
| Cypress | `npx cypress run` | `cypress.config.ts` | `cypress/screenshots/` |
| Detox | `detox test` | `.detoxrc.js` | `artifacts/` |
| pytest+playwright | `pytest tests/e2e/` | `conftest.py` | `test-results/` |
| WebdriverIO | `npx wdio run` | `wdio.conf.js` | `screenshots/` |

## Visual Verification

When `--visual` is passed to the verify loop, collected screenshots are sent to the Anthropic API for AI-powered visual review. Requirements:

- `pip install anthropic` (or already in environment)
- `ANTHROPIC_API_KEY` environment variable set
- Visual concerns are **advisory only** and never block the build

If either requirement is missing, the visual review is skipped with a warning.
