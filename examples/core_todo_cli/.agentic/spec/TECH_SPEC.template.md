# TECH_SPEC (Template)

Purpose: define *how* we will build it with enough clarity to implement incrementally and testably.

## Scope
- In scope:
- Out of scope:

## Features in scope (IDs)
- Feature registry: `spec/FEATURES.md`
- Implemented by this spec:
  - F-####
  - F-####

## NFRs in scope (IDs) (optional but recommended)
- NFR registry: `spec/NFR.md`
- Addressed by this spec:
  - NFR-####

## Architecture overview
- Style: <!-- monolith/modular monolith/services/plugin/etc -->
- Key constraints from `STACK.md`:
- Diagrams: <!-- link to docs/architecture/diagrams/ -->

## Architecture changelog
Track major architectural changes over time:

### YYYY-MM-DD: [Change description]
- Reason: <!-- why the change was made, link to ADR if applicable -->
- Affected features: <!-- F-#### IDs -->
- Migration status: <!-- planned | in-progress | complete -->
- Breaking changes: <!-- yes/no, describe if yes -->

## Components (responsibilities + boundaries)
- ComponentA:
  - Responsibilities:
  - Inputs/outputs:
  - Test seam:
- ComponentB:

## Data model / state
- Entities/state:
- Persistence:

## Interfaces
- External APIs:
- Internal module interfaces:

## Error handling & failure modes
- Failure mode:
  - Detection:
  - Handling:
  - Test:

## Testing strategy (required)
- Unit tests: what is unit-tested and where
- Integration tests (if any):
- Acceptance/E2E tests (if any):
- Non-functional testing (if relevant):
  - Performance:
  - Security:
  - Reliability:

## Observability (if relevant)
- Logs/metrics/traces:

## Rollout & migration (if relevant)
- Steps:
- Backwards compatibility:

## Risks & open questions
- Risk:
- Question:


