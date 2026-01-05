# FEATURES - Format Reference

**Purpose**: This file contains the complete format specification for `FEATURES.md`. Keep this in `.agentic/` for reference.

---

## Terminology (requirement vs feature)
- **Feature (F-####)** is canonical here: a shippable capability we implement and validate. Each feature links to concrete acceptance criteria and has explicit test coverage notes.
- **Requirements are optional**:
  - If you use requirements, treat them as outcome/contract statements (often in `spec/PRD.md`) and link them from features.
  - If you don't, leave the "Requirements" field empty and rely on the feature acceptance criteria file instead.

## Status vocabulary
- `planned` | `in_progress` | `shipped` | `deprecated`

## How to reference
- Feature IDs: `F-####`, …
- Requirement IDs (optional, from PRD): `R-0001`, …
- NFR IDs (optional): `NFR-####`, …
- Task IDs (optional): `T-0001`, …

## Feature index (optional)
You can add an index at the top for quick navigation:
- F-0001: User Authentication
- F-0002: Data Persistence
- F-0003: Real-time Sync

---

## Complete Feature Template

```markdown
## F-####: FeatureName
- Parent: none  <!-- or another feature ID for hierarchical features -->
- Dependencies: none  <!-- Features that must be complete/partial first -->
- Complexity: M  <!-- S | M | L | XL (optional, for prioritization) -->
- Tags: [feature-type, domain-area]  <!-- Optional: lowercase, hyphen-separated for search/filtering -->
- Layer: business-logic  <!-- Optional: presentation | business-logic | data | infrastructure | other -->
- Domain: example  <!-- Optional: business domain (auth, payments, content, etc.) -->
- Priority: medium  <!-- Optional: critical | high | medium | low -->
- Owner:  <!-- Optional: email or username -->
- Status: planned  <!-- planned | in_progress | shipped | deprecated -->
- PRD: spec/PRD.md#requirements  <!-- Optional: link to requirements doc -->
- Requirements: R-0001  <!-- Optional: requirement IDs this feature satisfies -->
- NFRs: none  <!-- Optional: list NFR-#### only if the feature has specific constraints -->
- Acceptance: spec/acceptance/F-####.md  <!-- Link to acceptance criteria -->
- Verification:
  - Accepted: no       <!-- no | yes -->
  - Accepted at:       <!-- YYYY-MM-DD (optional) -->
- Implementation:
  - State: none  <!-- none | partial | complete -->
  - Code: <!-- paths/modules where this feature is implemented -->
- Tests:
  - Test strategy: unit  <!-- unit | integration | e2e | manual | hybrid -->
  - Unit: todo  <!-- todo | partial | complete -->
  - Integration: n/a  <!-- todo | partial | complete | n/a -->
  - Acceptance: todo  <!-- todo | partial | complete -->
  - Perf/realtime: n/a  <!-- todo | partial | complete | n/a -->
- Technical debt:
  - <!-- links to spec/LESSONS.md anchors or specific debt items -->
- Lessons/caveats:
  - <!-- link to spec/LESSONS.md anchors or adr -->
- Notes:
  - <!-- anything agents should remember -->
```

---

## Minimal Feature Template

For simpler projects, you can use a minimal version:

```markdown
## F-####: FeatureName
- Parent: none
- Dependencies: none
- Status: planned
- Acceptance: spec/acceptance/F-####.md
- Implementation:
  - State: none
- Tests:
  - Unit: todo
- Notes:
  - 
```

---

## Field Descriptions

### Core Fields (Always Include)

**F-####: FeatureName**
- Stable ID (never changes, even if feature is renamed)
- Format: F-0001, F-0002, etc.
- Name should be descriptive and concise

**Parent**
- Use for hierarchical features (e.g., F-0002 is child of F-0001)
- `none` if top-level feature

**Dependencies**
- Other features that must be complete/partial first
- `none` if no dependencies

**Status**
- Current state: `planned` | `in_progress` | `shipped` | `deprecated`

**Acceptance**
- Link to acceptance criteria file (`spec/acceptance/F-####.md`)

**Implementation.State**
- Track implementation progress: `none` | `partial` | `complete`

**Tests**
- Track test coverage for each test type

### Optional Fields

**Complexity**: Estimation for planning
- S (small): <1 day
- M (medium): 1-3 days
- L (large): 1-2 weeks
- XL (extra large): >2 weeks

**Tags**: For filtering/searching
- Examples: `[ui, backend]`, `[auth, security]`

**Layer**: Architecture layer
- `presentation` | `business-logic` | `data` | `infrastructure` | `other`

**Domain**: Business domain
- Examples: `auth`, `payments`, `content`, `analytics`

**Priority**: Business priority
- `critical` | `high` | `medium` | `low`

**Owner**: Who's responsible (optional)

**PRD / Requirements**: Link to requirements docs (optional)

**NFRs**: Non-functional requirements this feature must satisfy

**Verification**: Track acceptance testing
- Accepted: yes/no
- Accepted at: Date when acceptance criteria were met

**Technical debt**: Known issues or shortcuts

**Lessons/caveats**: Learnings and gotchas

**Notes**: Anything agents should remember

---

## Example Feature

```markdown
## F-0001: User Login with Email/Password
- Parent: none
- Dependencies: none
- Complexity: M
- Tags: [auth, security, ui]
- Layer: business-logic
- Domain: auth
- Priority: critical
- Status: shipped
- Acceptance: spec/acceptance/F-0001.md
- Verification:
  - Accepted: yes
  - Accepted at: 2025-01-15
- Implementation:
  - State: complete
  - Code: src/auth/login.ts, src/ui/LoginForm.tsx
- Tests:
  - Test strategy: hybrid
  - Unit: complete
  - Integration: complete
  - Acceptance: complete
- Lessons/caveats:
  - Rate limiting essential (see ADR-0003)
  - Email validation must handle + alias (gmail specific)
- Notes:
  - Uses bcrypt with 12 rounds
  - JWT expiry: 24 hours
```

---

## Guidelines

### When to create features
- Shippable capabilities that add value
- Technical foundations (e.g., F-0001: Database Schema)
- User-facing features (e.g., F-0012: Export to PDF)
- Non-functional improvements (e.g., F-0045: Performance Optimization)

### When NOT to create features
- Bug fixes (use JOURNAL.md or issue tracker)
- Refactors that don't add capability
- Internal code quality improvements (unless significant, like F-#### Performance Optimization)

### Keeping it maintainable
- Use hierarchical organization for large feature sets (100+ features)
- Archive deprecated features to `spec/features_deprecated.md`
- Keep Implementation.State and Tests fields up to date
- Link to acceptance criteria files (don't inline them)

