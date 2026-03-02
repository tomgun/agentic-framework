# Acceptance criteria & acceptance tests

Purpose: keep acceptance criteria for each feature in a consistent location, and document how to validate it.

## Convention
- One file per feature: `spec/acceptance/F-0001.md`
- Link from `spec/FEATURES.md` to the acceptance file.

## What belongs here
- Acceptance criteria written in plain language
- Example scenarios / edge cases
- **A Tests section specifying what tests verify each criterion** (required — see template)

## Template format (v0.38.0+)

The current template (`.agentic/spec/acceptance.template.md`) uses this structure:

```markdown
# F-####: [Feature Name] - Acceptance Criteria

**Feature**: [One-sentence description]

## Behavior (what the user needs — technology-agnostic)
[Why this feature matters. User-facing, no implementation details.]

## Acceptance Criteria

### [Core Behavior] (P1 — MVP)
**Verify independently**: [how to test this group alone]
- [ ] **AC-001**: [Criterion]

### [Enhanced Experience] (P2 — better but optional)
**Verify independently**: [how to test this group alone]
- [ ] **AC-002**: [Criterion]

### [Edge Cases]
- [ ] **AC-003**: [Criterion]

## Verification

### Tests
#### Unit Tests
- [ ] `tests/test_auth.py` — verifies login rejects bad passwords

#### Integration Tests (if applicable)
- [ ] `tests/integration/test_login_flow.py` — verifies full login → session flow

#### Behavioral / LLM Tests (if feature changes agent decision-making)
- [ ] **LLM-0NN**: agent asked to implement auth → creates acceptance criteria first

## NFR Compliance
- [ ] NFR-XXXX: Description

## Out of Scope
- [Not included]
```

**Key sections:**
- **Behavior**: Technology-agnostic user goal (the "WHAT", not "HOW")
- **Priority tags** (P1/P2): Enables incremental delivery — P1 is MVP, P2 is enhancement
- **Verify independently**: How to test each AC group in isolation
- **Verification > Tests**: Planned before coding (required)

## Backward compatibility

Older acceptance files using `## Tests` as a top-level section are still accepted.
The framework checks for both `## Tests` and `## Verification > ### Tests`.
New features should use the current template format.

**Template**: `.agentic/spec/acceptance.template.md`
