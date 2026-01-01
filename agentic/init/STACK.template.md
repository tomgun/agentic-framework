# STACK.md (Template)

Purpose: a single source of truth for “how we build and run software here”.

## Summary
- What are we building: <!-- 1–2 sentences -->
- Primary platform: <!-- web/service/mobile/desktop/cli -->

## Languages & runtimes
- Language(s): <!-- e.g., TypeScript, Python, Go -->
- Runtime(s): <!-- e.g., Node 22, Python 3.12 -->
- Specific versions: <!-- e.g., TypeScript 5.3.3, Python 3.12.1 -->
  <!-- IMPORTANT: Agents use these exact versions to verify documentation -->

## Frameworks & libraries
- App framework: <!-- e.g., Next.js, FastAPI, Gin -->
- UI framework (if any): <!-- e.g., React, Svelte -->
- Specific versions: <!-- e.g., Next.js 15.1.0, React 19.0.0 -->
  <!-- IMPORTANT: List exact versions so agents can verify API docs -->

## Documentation verification (recommended)
<!-- Ensures agents use current, version-correct documentation -->
<!-- See: agentic/workflows/documentation_verification.md -->
<!-- - doc_verification: context7  # context7 | manual | none -->
<!-- - context7_enabled: yes -->
<!-- - context7_config: .context7.yml -->
<!-- - strict_version_matching: yes -->

## Documentation sources (for manual verification)
<!-- If not using Context7, agents must check these sources match STACK versions -->
<!-- Example: -->
<!-- - Next.js: https://nextjs.org/docs (version selector: v15.1) -->
<!-- - React: https://react.dev (v19) -->

## Tooling
- Package manager: <!-- npm/pnpm/yarn/uv/pip/poetry/go -->
- Formatting/linting: <!-- black/ruff/eslint/prettier/gofmt/etc -->

## Testing (required)
- Unit test framework: <!-- e.g., pytest, vitest, go test -->
- Integration/E2E (optional): <!-- e.g., playwright, cypress -->
- Test commands:
  - Unit: `<!-- fill -->`
  - Integration: `<!-- fill or N/A -->`
  - E2E: `<!-- fill or N/A -->`

## Development approach (optional)
<!-- Choose development workflow mode -->
<!-- TDD mode (RECOMMENDED): Tests written FIRST (red-green-refactor) -->
<!--   - Better token economics (smaller increments, less rework) -->
<!--   - Forces unit testability by design -->
<!--   - See agentic/workflows/tdd_mode.md -->
<!-- Standard mode: Tests required but can come during/after implementation -->
<!--   - Use for exploration, prototyping, unclear requirements -->
- development_mode: tdd  <!-- RECOMMENDED for most projects -->
<!-- - development_mode: standard -->

## Data & integrations
- Primary datastore: <!-- postgres/sqlite/mongo/redis/etc -->
- Messaging/queues (if any): <!-- kafka/sqs/rabbitmq/etc -->
- External integrations: <!-- bullet list -->

## Deployment
- Target environment: <!-- local/cloud/on-prem -->
- CI: <!-- GitHub Actions by default -->
- Release strategy: <!-- manual/semver/tags/etc -->

## Constraints & non-negotiables
- Security/compliance: <!-- PII, GDPR, etc -->
- Performance: <!-- latency, throughput -->
- Reliability: <!-- SLOs if known -->

## Retrospectives (optional)
<!-- Agent-led periodic project health checks. See agentic/workflows/retrospective.md -->
<!-- Uncomment to enable: -->
<!-- - retrospective_enabled: yes -->
<!-- - retrospective_trigger: both  # time | features | both -->
<!-- - retrospective_interval_days: 14 -->
<!-- - retrospective_interval_features: 10 -->
<!-- - retrospective_depth: full  # full (with research) | quick (no research) -->

## Research mode (optional)
<!-- Deep investigation into specific topics. See agentic/workflows/research_mode.md -->
<!-- Uncomment to enable proactive research suggestions: -->
<!-- - research_enabled: yes -->
<!-- - research_cadence: 90  # days between field update research -->
<!-- - research_depth: standard  # quick (30min) | standard (60min) | deep (90min) -->
<!-- - research_budget: 60  # default minutes per research session -->


