# FEATURES (Template)
<!-- spec-format: features-v0.3.1 -->

Purpose: a **human + machine** readable registry of features with stable IDs, status, acceptance criteria, and test coverage notes.

## Terminology (requirement vs feature)
- **Feature (F-####)** is canonical here: a ship-able capability we implement and validate. Each feature links to concrete acceptance criteria and has explicit test coverage notes.
- **Requirements are optional**:
  - If you use requirements, treat them as outcome/contract statements (often in `spec/PRD.md`) and link them from features.
  - If you don’t, leave the “Requirements” field empty and rely on the feature acceptance criteria file instead.

## Status vocabulary
- `planned` | `in_progress` | `shipped` | `deprecated`

## How to reference
- Feature IDs: `F-####`, …
- Requirement IDs (optional, from PRD): `R-0001`, …
- NFR IDs (optional): `NFR-####`, …
- Task IDs (optional): `T-0001`, …

## Feature index (optional)
- F-####:

---

## F-####: ExampleFeatureName
- Parent: none  <!-- or another feature ID -->
- Dependencies: none  <!-- Features that must be complete/partial first -->
- Complexity: M  <!-- S | M | L | XL (optional, for prioritization) -->
- Tags: [feature-type, domain-area]  <!-- Optional: lowercase, hyphen-separated for search/filtering -->
- Layer: business-logic  <!-- Optional: presentation | business-logic | data | infrastructure | other -->
- Domain: example  <!-- Optional: business domain (auth, payments, content, etc.) -->
- Priority: medium  <!-- Optional: critical | high | medium | low -->
- Owner:  <!-- Optional: email or username -->
- Status: planned
- PRD: spec/PRD.md#requirements
- Requirements: R-0001
- NFRs: none  <!-- optional; list NFR-#### only if the feature has specific constraints -->
- Acceptance: spec/acceptance/F-####.md
- Verification:
  - Accepted: no       <!-- no | yes -->
  - Accepted at:       <!-- YYYY-MM-DD (optional) -->
- Implementation:
  - State: none  <!-- none | partial | complete -->
  - Code: <!-- paths/modules -->
- Tests:
  - Test strategy: unit  <!-- unit | integration | e2e | manual | hybrid -->
  - Unit: todo  <!-- todo | partial | complete -->
  - Integration: n/a
  - Acceptance: todo
  - Perf/realtime: n/a
- Technical debt:
  - <!-- links to spec/LESSONS.md anchors or specific debt items -->
- Lessons/caveats:
  - <!-- link to spec/LESSONS.md anchors or adr -->
- Notes:
  - <!-- anything agents should remember -->


