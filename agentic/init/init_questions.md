# Init questions (canonical)

The agent should ask only what’s necessary to produce durable context artifacts.

## Product + scope
- What type of product is this: webapp / game / vstplugin / mobileapp / app+backend?
- What are we building (1–2 sentences)?
- Who is the user and what is the primary workflow?
- Success criteria (measurable if possible)?
- Non-goals (what we explicitly won’t do now)?
- Is this trivial/standard, or do we need a research phase first?
  - If research is needed: list what to research and what “good” sources look like (papers, official docs, reference implementations).

## Constraints
- Platforms: web/mobile/desktop/CLI/service?
- Deployment environment: local only, cloud, on-prem?
- Compliance/security requirements (PII, SOC2, HIPAA, GDPR, etc.)?
- Performance/latency constraints?

## Tech stack
- Primary language(s)?
- Primary framework(s) / runtime(s)?
- Package/dependency manager choice?
- Data storage: DB type + hosting?
- Authn/authz approach (if needed)?
- External integrations (APIs, queues, payments, etc.)?

## Architecture + boundaries
- High-level architecture style (monolith, modular monolith, services)?
- Key modules/components and their responsibilities?
- Where are the seams for testing/mocking?

## Testing (must be explicit)
- Unit test framework choice?
- Integration/E2E test approach (if any)?
- How tests are run locally and in CI (commands)?
- Test data strategy (fixtures, factories, containers)?
- Domain-specific testing/perf (if relevant):
  - VST/JUCE: audio I/O golden tests, host automation tests, realtime/perf budget tests
  - Games: determinism/replay tests, perf budgets, input recording
  - Mobile: device/simulator strategy, UI tests, crash/perf checks

## Developer experience
- Lint/format standards (if any)?
- CI provider (GitHub Actions by default)?
- Branching/review process expectations?

## Repo conventions
- Where specs live: `/spec/`?
- Where ADRs live: `/adr/`?
- Where status lives: `STATUS.md`?
- Any naming conventions that matter?


