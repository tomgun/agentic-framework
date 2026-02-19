# Acceptance criteria & acceptance tests

Purpose: keep acceptance criteria for each feature in a consistent location, and document how to validate it.

## Convention
- One file per feature: `spec/acceptance/F-0001.md`
- Link from `spec/FEATURES.md` to the acceptance file.

## What belongs here
- Acceptance criteria written in plain language
- Example scenarios / edge cases
- **A `## Tests` section specifying what tests verify each criterion** (required — see template)

## Tests must be planned before implementation

Every acceptance criteria file should have a `## Tests` section written **before coding starts**:

```markdown
## Tests

### Unit Tests
- [ ] `tests/test_auth.py` — verifies login rejects bad passwords
- [ ] `tests/test_auth.py` — verifies login accepts valid credentials

### Integration Tests (if applicable)
- [ ] `tests/integration/test_login_flow.py` — verifies full login → session flow

### Behavioral / LLM Tests (if feature changes agent decision-making)
- [ ] **LLM-0NN**: agent asked to implement auth → creates acceptance criteria first
```

Remove sections that don't apply. At minimum, unit tests are required.

**Template**: `.agentic/spec/acceptance.template.md`


