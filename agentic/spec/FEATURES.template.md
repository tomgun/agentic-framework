# FEATURES (Template)

Purpose: a **human + machine** readable registry of features with stable IDs, status, acceptance criteria, and test coverage notes.

## Terminology (requirement vs feature)
- **Feature (F-####)** is canonical here: a ship-able capability we implement and validate. Each feature links to concrete acceptance criteria and has explicit test coverage notes.
- **Requirements are optional**:
  - If you use requirements, treat them as outcome/contract statements (often in `spec/PRD.md`) and link them from features.
  - If you don’t, leave the “Requirements” field empty and rely on the feature acceptance criteria file instead.

## Status vocabulary
- `planned` | `in_progress` | `shipped` | `deprecated`

## How to reference
- Feature IDs: `F-0001`, `F-0002`, …
- Requirement IDs (optional, from PRD): `R-0001`, …
- NFR IDs (optional): `NFR-0001`, …
- Task IDs (optional): `T-0001`, …

## Feature index (optional)
- F-0001:
- F-0002:

---

## F-0001: ExampleFeatureName
- Parent: none  <!-- or F-0000 for hierarchy -->
- Status: planned
- PRD: spec/PRD.md#requirements
- Requirements: R-0001
- NFRs: none  <!-- optional; list NFR-#### only if the feature has specific constraints -->
- Acceptance: spec/acceptance/F-0001.md
- Verification:
  - Accepted: no       <!-- no | yes -->
  - Accepted at:       <!-- YYYY-MM-DD (optional) -->
- Implementation:
  - State: none  <!-- none | partial | complete -->
  - Code: <!-- paths/modules -->
- Tests:
  - Unit: todo  <!-- todo | partial | complete -->
  - Integration: n/a
  - Acceptance: todo
  - Perf/realtime: n/a
- Lessons/caveats:
  - <!-- link to spec/LESSONS.md anchors or adr -->
- Notes:
  - <!-- anything agents should remember -->


