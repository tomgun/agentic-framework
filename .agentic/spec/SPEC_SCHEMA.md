# Specification Schema Reference

**Purpose**: Define the canonical structure, fields, and valid values for all specification documents.

This is the **schema** for the spec system. Do not deviate from this without updating this document first.

---

## Cross-Reference Conventions

### ID Formats (MUST follow exactly)

| Type | Format | Example | Used In |
|------|--------|---------|---------|
| **Feature** | `F-####` | `F-0001` | FEATURES.md, acceptance files |
| **Requirement** | `R-####` | `R-0015` | PRD.md |
| **Non-Functional Req** | `NFR-####` | `NFR-0003` | NFR.md |
| **Architecture Decision** | `ADR-####` | `ADR-0007` | adr/*.md filenames |
| **Task** | `TASK-YYYYMMDD-slug` | `TASK-20260101-auth` | tasks/*.md filenames |
| **Acceptance Criterion** | `AC#` | `AC1`, `AC2` | Within acceptance files |
| **Human Needed** | `H-####` | `H-0002` | HUMAN_NEEDED.md |
| **Reference** | `R-####` | `R-0005` | REFERENCES.md |

### Cross-Reference Syntax

```markdown
<!-- Link to feature -->
F-0001

<!-- Link to feature with status in dependencies -->
F-0001 (complete), F-0002 (in_progress)

<!-- Link to requirement -->
R-0015, R-0020

<!-- Link to NFR -->
NFR-0003

<!-- Link to ADR -->
ADR-0007

<!-- File path reference -->
spec/acceptance/F-0001.md
```

---

## FEATURES.md Schema

### Feature Entry Structure

```markdown
## F-####: Feature Name
- Parent: [none | F-####]
- Dependencies: [none | F-#### (status), ...]
- Complexity: [S | M | L | XL]
- Tags: [[tag1, tag2, ...] | empty]  <!-- NEW in v0.3.0 -->
- Layer: [presentation | business-logic | data | infrastructure | other | none]  <!-- NEW in v0.3.0 -->
- Domain: [domain-name | none]  <!-- NEW in v0.3.0 -->
- Priority: [critical | high | medium | low | none]  <!-- NEW in v0.3.0 -->
- Owner: [email | username | none]  <!-- NEW in v0.3.0 -->
- Status: [planned | in_progress | shipped | deprecated]
- PRD: [spec/PRD.md#anchor | none]
- Requirements: [R-####, ... | none]
- NFRs: [NFR-####, ... | none]
- Acceptance: [spec/acceptance/F-####.md | todo | tbd]
- Verification:
  - Accepted: [yes | no]
  - Accepted at: [YYYY-MM-DD | empty]
- Implementation:
  - State: [none | partial | complete]
  - Code: [file paths or "none"]
- Tests:
  - Test strategy: [unit | integration | e2e | manual | mixed]
  - Unit: [todo | partial | complete | n/a]
  - Integration: [todo | partial | complete | n/a]
  - Acceptance: [todo | partial | complete | n/a]
  - Perf/realtime: [todo | partial | complete | n/a]
- Technical debt: [free text or "none"]
- Lessons/caveats: [bullet list or "none"]
- Notes: [free text]
```

### Field Definitions

| Field | Type | Valid Values | Required | Description |
|-------|------|--------------|----------|-------------|
| **F-####** | ID | `F-` + 4 digits | ✅ | Unique, stable feature identifier |
| **Feature Name** | string | any | ✅ | Human-readable name |
| **Parent** | ID | `none` or `F-####` | ✅ | Parent feature for hierarchy |
| **Dependencies** | ID list | `none` or `F-#### (status), ...` | ✅ | Features that must be complete first |
| **Complexity** | enum | `S`, `M`, `L`, `XL` | ⚠️ Optional | Size estimate |
| **Tags** | list | `[tag1, tag2, ...]` | ⚠️ Optional | Lowercase, hyphen-separated tags for search/filtering (v0.3.0+) |
| **Layer** | enum | `presentation`, `business-logic`, `data`, `infrastructure`, `other` | ⚠️ Optional | Architectural layer (v0.3.0+) |
| **Domain** | string | domain name | ⚠️ Optional | Business domain (auth, payments, content, etc.) (v0.3.0+) |
| **Priority** | enum | `critical`, `high`, `medium`, `low` | ⚠️ Optional | Business priority level (v0.3.0+) |
| **Owner** | string | email or username | ⚠️ Optional | Person responsible for this feature (v0.3.0+) |
| **Status** | enum | `planned`, `in_progress`, `shipped`, `deprecated` | ✅ | Current development status |
| **PRD** | reference | `spec/PRD.md#anchor` or `none` | ✅ | Link to product requirement |
| **Requirements** | ID list | `R-####, ...` or `none` | ✅ | Requirements this feature satisfies |
| **NFRs** | ID list | `NFR-####, ...` or `none` | ✅ | NFRs this feature must satisfy |
| **Acceptance** | reference | `spec/acceptance/F-####.md`, `todo`, `tbd` | ✅ | Link to acceptance criteria |
| **Accepted** | boolean | `yes`, `no` | ✅ | Whether acceptance criteria are met |
| **Accepted at** | date | `YYYY-MM-DD` or empty | ⚠️ Optional | Date acceptance was verified |
| **Implementation: State** | enum | `none`, `partial`, `complete` | ✅ | How much is implemented |
| **Implementation: Code** | paths | File paths or `none` | ✅ | Where code lives (filled as implemented) |
| **Test strategy** | enum | `unit`, `integration`, `e2e`, `manual`, `mixed` | ✅ | Primary test approach |
| **Tests: Unit** | enum | `todo`, `partial`, `complete`, `n/a` | ✅ | Unit test coverage |
| **Tests: Integration** | enum | `todo`, `partial`, `complete`, `n/a` | ✅ | Integration test coverage |
| **Tests: Acceptance** | enum | `todo`, `partial`, `complete`, `n/a` | ✅ | Acceptance test coverage |
| **Tests: Perf/realtime** | enum | `todo`, `partial`, `complete`, `n/a` | ✅ | Performance test coverage |
| **Technical debt** | text | Free text or `none` | ⚠️ Optional | Known shortcuts/issues |
| **Lessons/caveats** | bullets | Bullet list or `none` | ⚠️ Optional | Links to LESSONS.md |
| **Notes** | text | Free text | ⚠️ Optional | Additional context |

### Status Transitions

```
planned → in_progress → shipped
   ↓                        ↓
deprecated ← ← ← ← ← ← ← ← ┘
```

**Rules**:
- Only move to `shipped` when `Implementation: State = complete` AND `Accepted = yes`
- Only move to `in_progress` when actively being worked on
- Use `deprecated` for features no longer needed

---

## PRD.md Schema

### Structure

```markdown
# Product Requirements Document

## Summary
[Brief overview]

## Goals
- [Goal 1]
- [Goal 2]

## Non-goals
- [What we're NOT doing]

## Requirements

### R-0001: Requirement Name
- Priority: [P0 | P1 | P2 | P3]
- User story: [As a X, I want Y, so that Z]
- Acceptance: [When/then statements]
- Related features: [F-####, ...]
```

### Field Definitions

| Field | Type | Valid Values | Required | Description |
|-------|------|--------------|----------|-------------|
| **R-####** | ID | `R-` + 4 digits | ✅ | Unique requirement ID |
| **Requirement Name** | string | any | ✅ | Short name |
| **Priority** | enum | `P0`, `P1`, `P2`, `P3` | ✅ | P0 = critical, P3 = nice-to-have |
| **User story** | text | `As a X, I want Y, so that Z` | ✅ | User-facing need |
| **Acceptance** | text | When/then statements | ✅ | How to verify |
| **Related features** | ID list | `F-####, ...` | ⚠️ Optional | Features implementing this |

---

## NFR.md Schema

### Structure

```markdown
## NFR-0001: NFR Name
- Category: [performance | security | scalability | usability | reliability | maintainability | compliance]
- Constraint: [Specific measurable constraint]
- Rationale: [Why this matters]
- How to verify: [How to test/measure]
- Affected features: [F-####, ... | all]
```

### Field Definitions

| Field | Type | Valid Values | Required | Description |
|-------|------|--------------|----------|-------------|
| **NFR-####** | ID | `NFR-` + 4 digits | ✅ | Unique NFR ID |
| **NFR Name** | string | any | ✅ | Short name |
| **Category** | enum | `performance`, `security`, `scalability`, `usability`, `reliability`, `maintainability`, `compliance` | ✅ | Type of constraint |
| **Constraint** | text | Measurable constraint | ✅ | Specific requirement |
| **Rationale** | text | Free text | ✅ | Why it's needed |
| **How to verify** | text | Test/measurement approach | ✅ | Verification method |
| **Affected features** | ID list | `F-####, ...` or `all` | ✅ | Which features must comply |

---

## ADR (Architecture Decision Record) Schema

### Filename Convention

```
spec/adr/ADR-####-short-slug.md
```

### Structure

```markdown
# ADR-####: Decision Title

## Status
[Proposed | Accepted | Superseded]

## Context
[Problem and constraints]

## Decision
[What we decided]

## Options considered
[Alternatives with pros/cons]

## Research trail
[Links to research notes]

## Alternatives attempted
[What was tried and failed]

## External references
[Papers, docs, examples]

## Consequences
- Positive: [...]
- Negative / risks: [...]

## Follow-ups
[Tasks, migration steps]
```

### Field Definitions

| Field | Type | Valid Values | Required | Description |
|-------|------|--------------|----------|-------------|
| **ADR-####** | ID | `ADR-` + 4 digits | ✅ | Unique ADR ID |
| **Decision Title** | string | any | ✅ | Short title |
| **Status** | enum | `Proposed`, `Accepted`, `Superseded` | ✅ | Current status |
| **Context** | text | Free text | ✅ | Why decision was needed |
| **Decision** | text | Free text | ✅ | What was decided |
| **Options considered** | list | Bullet list with pros/cons | ✅ | Alternatives evaluated |
| **Research trail** | links | Links to docs/research/*.md | ⚠️ Optional | Supporting research |
| **Alternatives attempted** | text | Free text | ⚠️ Optional | What was tried |
| **External references** | links | URLs | ⚠️ Optional | Papers, docs |
| **Consequences** | list | Positive/Negative bullets | ✅ | Impact of decision |
| **Follow-ups** | list | Task bullets | ⚠️ Optional | Next steps |

---

## Acceptance Criteria Schema

### Filename Convention

```
spec/acceptance/F-####.md
```

### Structure

```markdown
# F-####: Feature Name

## Acceptance Criteria

### AC1: Criterion name
[Description of what must be true]

### AC2: Another criterion
[Description]

## Test Notes
[How to test, special considerations]
```

### Field Definitions

| Field | Type | Valid Values | Required | Description |
|-------|------|--------------|----------|-------------|
| **F-####** | ID | Must match feature ID | ✅ | Feature this applies to |
| **Feature Name** | string | Must match feature name | ✅ | For readability |
| **AC#** | ID | `AC` + number (1, 2, 3...) | ✅ | Unique within file |
| **Criterion name** | string | any | ✅ | Short name |
| **Description** | text | Free text | ✅ | What must be true |
| **Test Notes** | text | Free text | ⚠️ Optional | Testing guidance |

---

## STATUS.md Schema

### Structure

```markdown
# STATUS.md

## Current focus
[What we're doing right now]

## Current session state (auto-tracked by agent)
- Session: [YYYY-MM-DD-HHMM]
- Feature: [F-####]
- Phase: [planning | researching | implementing | testing | reviewing]
- Completed this session: [bullets]
- Next immediate step: [what to do next]
- Blocker encountered: [if any]

## In progress
- [F-#### or task bullets]

## Next up
- [F-#### or task bullets]

## Roadmap (lightweight)
- Near-term: [1-5 bullets]
- Later: [1-5 bullets]

## Known issues / risks
- [bullets]

## Decisions needed
- [bullets]

## Release notes (optional)
- [bullets]
```

### Field Definitions

| Section | Type | Valid Values | Required | Description |
|---------|------|--------------|----------|-------------|
| **Current focus** | text | Free text | ✅ | Current work |
| **Session** | timestamp | `YYYY-MM-DD-HHMM` | ⚠️ Agent-managed | Current session ID |
| **Feature** | ID | `F-####` | ⚠️ Optional | Current feature |
| **Phase** | enum | `planning`, `researching`, `implementing`, `testing`, `reviewing` | ⚠️ Optional | Current phase |
| **In progress** | list | Feature/task bullets | ✅ | Active work |
| **Next up** | list | Feature/task bullets | ✅ | Prioritized backlog |
| **Roadmap: Near-term** | list | 1-5 bullets | ⚠️ Optional | Next few items |
| **Roadmap: Later** | list | 1-5 bullets | ⚠️ Optional | Future items |
| **Known issues / risks** | list | Bullets | ⚠️ Optional | Problems to track |
| **Decisions needed** | list | Bullets | ⚠️ Optional | Pending decisions |

---

## JOURNAL.md Schema

### Structure

```markdown
## Session: YYYY-MM-DD-HHMM
- Feature: [F-#### or "none"]
- Task: [TASK-#### or "none"]
- Goal for session: [text]
- Accomplished:
  - [Bullet 1]
  - [Bullet 2]
- Next steps:
  - [Bullet 1]
- Blockers/Issues encountered:
  - [Bullet 1 or "none"]
- Decisions made:
  - [Bullet 1 or "none"]
- Context learned:
  - [Bullet 1 or "none"]
```

### Field Definitions

| Field | Type | Valid Values | Required | Description |
|-------|------|--------------|----------|-------------|
| **Session** | timestamp | `YYYY-MM-DD-HHMM` | ✅ | Unique session ID |
| **Feature** | ID | `F-####` or `none` | ⚠️ Optional | Feature worked on |
| **Task** | ID | `TASK-####` or `none` | ⚠️ Optional | Task worked on |
| **Goal for session** | text | Free text | ✅ | What was intended |
| **Accomplished** | list | Bullets | ✅ | What was done |
| **Next steps** | list | Bullets | ✅ | What to do next |
| **Blockers/Issues** | list | Bullets or `none` | ⚠️ Optional | Problems hit |
| **Decisions made** | list | Bullets or `none` | ⚠️ Optional | Decisions (link ADRs) |
| **Context learned** | list | Bullets or `none` | ⚠️ Optional | New understanding |

---

## HUMAN_NEEDED.md Schema

### Structure

```markdown
## H-####: Item Title
- Category: [business | security | architecture | debugging | refactoring | compliance]
- Context: [What is the problem/question?]
- Agent's attempt/analysis: [What agent tried]
- Why human is needed: [Reason]
- Options (if any):
  - Option A: [Pros/Cons]
  - Option B: [Pros/Cons]
- Next steps for human: [What action required]
- Related: [F-####, ADR-####]
- Date added: [YYYY-MM-DD]
- Status: [active | resolved]
```

### Field Definitions

| Field | Type | Valid Values | Required | Description |
|-------|------|--------------|----------|-------------|
| **H-####** | ID | `H-` + 4 digits | ✅ | Unique ID |
| **Item Title** | string | any | ✅ | Short name |
| **Category** | enum | `business`, `security`, `architecture`, `debugging`, `refactoring`, `compliance` | ✅ | Type of issue |
| **Context** | text | Free text | ✅ | What's the problem |
| **Agent's attempt/analysis** | text | Free text | ✅ | What agent did |
| **Why human is needed** | text | Free text | ✅ | Reason for escalation |
| **Options** | list | Options with pros/cons | ⚠️ Optional | Alternatives |
| **Next steps for human** | text | Free text | ✅ | Action needed |
| **Related** | ID list | `F-####`, `ADR-####` | ⚠️ Optional | Related items |
| **Date added** | date | `YYYY-MM-DD` | ✅ | When added |
| **Status** | enum | `active`, `resolved` | ✅ | Current state |

---

## TECH_SPEC.md Schema

### Structure (High-Level)

```markdown
## Architecture overview
- Style: [monolith | modular monolith | services | plugin | ...]
- Key constraints from STACK.md: [list]

## Architecture diagrams
- [Link to docs/architecture/diagrams/]

## Components
[List major components and responsibilities]

## Data model / state
[Core entities and relationships]

## Interfaces
[Public APIs, contracts]

## Testing strategy
[How components are tested]

## Architecture changelog
[Major changes with dates, reasons, affected features]
```

**Note**: TECH_SPEC.md is semi-structured. Sections can be expanded as needed, but these are the required top-level sections.

---

## Validation Rules

### Cross-Reference Integrity

✅ **MUST be valid**:
- `F-####` in FEATURES.md → must have `spec/acceptance/F-####.md` (unless `todo` or `tbd`)
- `F-####` referenced in STATUS.md → must exist in FEATURES.md
- `NFR-####` referenced in FEATURES.md → must exist in NFR.md
- `R-####` referenced in FEATURES.md → must exist in PRD.md
- `ADR-####` mentioned → must have file `spec/adr/ADR-####-*.md`

### Status Consistency

✅ **MUST be true**:
- If `Status = shipped` → `Implementation: State = complete` AND `Accepted = yes`
- If `Implementation: State = complete` → `Tests: Unit != todo` (unless `n/a`)
- If `Status = shipped` → `Tests: Acceptance = complete` (or `n/a` with justification)

### Field Presence

✅ **MUST exist**:
- Every feature MUST have: `F-####`, `Status`, `Acceptance`, `Implementation: State`, `Tests: Unit`
- Every requirement MUST have: `R-####`, `Priority`, `User story`, `Acceptance`
- Every NFR MUST have: `NFR-####`, `Category`, `Constraint`, `How to verify`
- Every ADR MUST have: `ADR-####`, `Status`, `Context`, `Decision`, `Consequences`

---

## Tools That Enforce This Schema

| Tool | What it checks |
|------|----------------|
| `doctor.py` | File presence, template content, basic parsing, feature status consistency |
| `verify.py` | Cross-reference integrity (F-####, NFR-####, R-####), acceptance file existence |
| `consistency.py` | Documentation drift between FEATURES.md, CONTEXT_PACK.md, STATUS.md |
| `report.py` | Feature dependency validation, circular dependencies |
| `coverage.py` | Code annotations match FEATURES.md |

**Run these regularly**:
```bash
bash .agentic/tools/verify.sh  # Full check
python3 .agentic/tools/doctor.py  # Quick health check
```

---

## Schema Evolution

### To Change the Schema

1. **Update this document first** (`SPEC_SCHEMA.md`)
2. Update affected `.template.md` files
3. Update validation tools (`doctor.py`, `verify.py`, etc.)
4. Update agent guidelines (`agent_operating_guidelines.md`)
5. Document change in LESSONS.md or ADR
6. Migrate existing specs if needed

### Backward Compatibility

When adding fields:
- Mark as "optional" initially
- Update templates
- Gradually fill in existing specs

When removing fields:
- Deprecate first (mark as optional)
- Remove from templates
- Update docs
- Then remove from validation

---

## Quick Reference Card

### Status Values
- **Features**: `planned`, `in_progress`, `shipped`, `deprecated`
- **Implementation**: `none`, `partial`, `complete`
- **Tests**: `todo`, `partial`, `complete`, `n/a`
- **ADRs**: `Proposed`, `Accepted`, `Superseded`
- **Verification**: `yes`, `no`

### Complexity Values
- `S` = Small (hours)
- `M` = Medium (days)
- `L` = Large (weeks)
- `XL` = Extra Large (months)

### Priority Values (PRD)
- `P0` = Critical (must have)
- `P1` = High (should have)
- `P2` = Medium (nice to have)
- `P3` = Low (if time permits)

### Test Strategies
- `unit` = Unit tests primary
- `integration` = Integration tests primary
- `e2e` = End-to-end tests primary
- `manual` = Manual testing only
- `mixed` = Combination approach

---

## Example Valid Feature Entry

```markdown
## F-0042: User authentication
- Parent: none
- Dependencies: none
- Complexity: M
- Status: in_progress
- PRD: spec/PRD.md#authentication
- Requirements: R-0010, R-0011
- NFRs: NFR-0001, NFR-0005
- Acceptance: spec/acceptance/F-0042.md
- Verification:
  - Accepted: no
  - Accepted at:
- Implementation:
  - State: partial
  - Code: lib/auth.ts, app/api/auth/route.ts
- Tests:
  - Test strategy: unit
  - Unit: partial
  - Integration: todo
  - Acceptance: todo
  - Perf/realtime: n/a
- Technical debt: Password hashing uses deprecated library, needs upgrade
- Lessons/caveats:
  - See spec/LESSONS.md#auth-timing-attacks
- Notes:
  - Consider adding 2FA in next iteration
```

This satisfies all schema requirements and can be validated by tools.

