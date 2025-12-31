# STACK.md

Quick intent (agent-first): **how to build/run/test** this repo and what constraints matter.

Purpose: a single source of truth for “how we build and run software here”.

## Summary
- What are we building: a small Todo web app used as an example of the agentic framework.
- Primary platform: webapp

## Languages & runtimes
- Language(s): TypeScript
- Runtime(s): Node.js (>= 18 recommended)

## Frameworks & libraries
- App framework: Next.js (App Router)
- UI framework (if any): React

## Tooling
- Package manager: npm (or pnpm)
- Formatting/linting: Next.js lint (optional)

## Testing (required)
- Unit test framework: Vitest
- Integration/E2E (optional): N/A (future)
- Test commands:
  - Unit: `npm test`
  - Integration: `N/A`
  - E2E: `N/A`

## Data & integrations
- Primary datastore: <!-- postgres/sqlite/mongo/redis/etc -->
- Messaging/queues (if any): <!-- kafka/sqs/rabbitmq/etc -->
- External integrations: <!-- bullet list -->

## Deployment
- Target environment: local demo
- CI: optional (see `agentic/support/ci/`)
- Release strategy: N/A

## Constraints & non-negotiables
- Security/compliance: no PII
- Performance: simple local state app
- Reliability: N/A


