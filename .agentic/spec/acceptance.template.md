# F-####: [Feature Name] - Acceptance Criteria

**Feature**: [One-sentence description of what this feature does]

---

## Behavior (what the user needs — technology-agnostic)

<!-- Why this feature matters. What user goal it serves.
     Write from the user's perspective: what changes for them?
     Keep technology-neutral — describe the "what", not the "how". -->

[User-facing behavior description]

---

## Acceptance Criteria

### [Core Behavior] (P1 — MVP)
**Verify independently**: [how to test this group alone]

- [ ] **AC-001**: [Criterion — specific, testable, unambiguous]
- [ ] **AC-002**: [Criterion]

### [Enhanced Experience] (P2 — better but optional)
**Verify independently**: [how to test this group alone]

- [ ] **AC-003**: [Criterion]

### [Edge Cases]

- [ ] **AC-004**: [Criterion]

---

## Verification

### Tests

<!-- Plan your tests HERE, before writing code. This is not optional.
     Specify: what type, what file/suite, what scenario each test covers.
     The implementation is not done until these tests exist and pass. -->

#### Unit Tests
- [ ] `[test file]` — [what it verifies]

#### Integration Tests (if crossing module/service boundaries)
- [ ] `[test file]` — [what it verifies]

#### Behavioral / LLM Tests (if feature changes agent decision-making)
- [ ] **[TEST-ID]**: [prompt scenario] → agent should [expected behavior]

<!-- Remove sections that don't apply. At minimum, unit tests are required. -->

---

## NFR Compliance

<!-- List any NFRs that constrain this feature. Remove section if none apply. -->
- [ ] NFR-XXXX: Description

---

## Out of Scope

<!-- Explicitly note what this feature does NOT do, to prevent scope creep. -->
- [Not included]
