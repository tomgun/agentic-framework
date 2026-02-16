# Feature Complete Checklist

**Purpose**: Ensure feature is truly complete before marking as "shipped".

**Use**: When you believe a feature (F-#### or general feature) is ready to be called "done".

**Important**: "Shipped" ≠ "Accepted". This checklist is for SHIPPED status. Human validation comes after.

---

## Acceptance Criteria Met

- [ ] **All acceptance criteria satisfied**
  - Formal: Every item in `spec/acceptance/F-####.md`
  - Core: Every item in `OVERVIEW.md` or user requirements
  - No partial completion
  - No "mostly works" items

- [ ] **Smoke test passed** (CRITICAL - RUN THE APPLICATION!)
  - **See `.agentic/checklists/smoke_testing.md` for full checklist**
  - [ ] Run application in target environment (browser, simulator, etc.)
  - [ ] Application starts without errors (no console errors, no crashes)
  - [ ] Feature works end-to-end (perform the user action)
  - [ ] Verified output matches expectations (visual, functional, data)
  - [ ] Tried different inputs/scenarios
  - **NOT just "tests pass" - ACTUALLY RUN IT and VERIFY IT WORKS**

---

## Code Complete

- [ ] **All code written**
  - No TODOs left for core functionality
  - No placeholder implementations
  - All branches/cases handled

- [ ] **Code quality high**
  - Follows programming standards
  - Clear, maintainable code
  - No obvious code smells
  - Properly documented

- [ ] **Error handling complete**
  - All error cases handled
  - User-friendly error messages
  - No silent failures
  - Graceful degradation where appropriate

---

## Tests Complete

### Unit Tests

- [ ] **Unit tests exist for all logic**
  - Every function/method tested
  - Happy path covered
  - Edge cases covered
  - Error cases covered

- [ ] **Unit tests pass**
  - All green
  - No flaky tests
  - No skipped tests (unless explicitly acceptable)

### Integration Tests

- [ ] **Integration tests complete** (if feature crosses boundaries)
  - Component interactions tested
  - External dependencies mocked/stubbed
  - Error scenarios tested

- [ ] **Integration tests pass**
  - All green
  - Covers realistic scenarios

### Acceptance Tests

- [ ] **Acceptance tests exist**
  - End-to-end validation
  - Tests actual user workflows
  - Matches acceptance criteria

- [ ] **Acceptance tests pass**
  - All green
  - Actually validate feature works

### Test Quality

- [ ] **Tests follow testing standards** — see `.agentic/quality/testing_standards.md`
- [ ] **Mutation testing considered** (for critical code — auth, payments, data integrity)

---

## Documentation Complete

### Core Profile

- [ ] **`OVERVIEW.md` updated**
  - Feature marked as implemented [x]
  - "What works now" includes this feature
  - Usage examples if complex
  - Known limitations documented

### Formal Profile

- [ ] **`spec/FEATURES.md` updated**
  - Status: `shipped` (not `planned` or `in_progress`)
  - Implementation State: `complete` (not `none` or `partial`)
  - Implementation Code: All file paths listed
  - Tests: Unit/Integration/Acceptance all marked `complete`
  - Verification Accepted: `no` (human will accept)
  - **CRITICAL**: Never mark as shipped without setting these correctly

- [ ] **Acceptance file complete**
  - `spec/acceptance/F-####.md` exists
  - Has actual criteria (not placeholder)
  - Criteria are testable
  - Criteria match what was implemented

- [ ] **Tech spec updated** (if changed)
  - `spec/TECH_SPEC.md` reflects implementation
  - No outdated information
  - New components documented

### Code Documentation

- [ ] **Code comments added**
  - @feature annotations on implementation
  - @acceptance annotations on acceptance tests
  - @nfr annotations if relevant
  - Explain "why" not "what"

- [ ] **README/docs updated** (if user-facing)
  - Usage examples
  - API documentation
  - Configuration options
  - Any breaking changes noted

---

## Drift Check (Recommended)

Before marking feature as complete:

- [ ] **Run `bash .agentic/tools/ag.sh trace`** (or `drift.sh`) to verify:
  - No untracked implementation files related to this feature
  - Feature status in FEATURES.md matches acceptance criteria completion
  - No template markers left in project files (e.g., "(Template)" in title)
  - Code has `@feature` annotations for traceability

---

## Quality Checks

- [ ] **Spec ↔ Code alignment verified**
  - Run `bash .agentic/tools/drift.sh --check`
  - No undocumented code (non-coders can read specs)
  - Acceptance criteria match implementation
  - Fix any drift before marking complete

- [ ] **Quality checks pass** (if enabled)
  - `bash quality_checks.sh` succeeds
  - All stack-specific validations pass
  - No quality gate failures

- [ ] **Code review ready**
  - Code is clean, readable
  - Ready for human review
  - You would be proud to show this code

- [ ] **Performance acceptable**
  - No obvious performance issues
  - Response times reasonable
  - Resource usage acceptable
  - If NFRs exist, they're met

---

## Context & Tracking Updated

- [ ] **Change manifest generated** (for documentation patching)
  - Run: `bash .agentic/tools/manifest.sh F-####`
  - Or: `ag done F-####` (auto-generates manifest)
  - Creates `.agentic-journal/manifests/F-####.manifest.md` with:
    - All commits related to feature
    - Files changed (code, tests, docs, config)
    - Lines added/removed
  - Use for: Auditing what actually changed, patching docs later

- [ ] **`JOURNAL.md` updated**
  - Feature completion documented
  - Important decisions recorded
  - Any challenges/learnings noted
  - Consider: `--feature F-#### --files N` flags for metadata

- [ ] **`STATUS.md` updated** (Formal)
  - Moved feature from "Current focus" to "Recently completed"
  - Or updated "Next up" if more work queued

- [ ] **`CONTEXT_PACK.md` updated** (if architecture changed)
  - New modules documented
  - Entry points updated
  - Architecture diagram current

---

## Human Review Preparation

- [ ] **Summary prepared for human**
  - What was implemented
  - How to test/verify it
  - Any known limitations
  - What acceptance criteria were met

- [ ] **Demo/test instructions ready**
  - Clear steps to validate feature
  - Example inputs/outputs
  - Expected behavior described

- [ ] **Request human validation**
  - Tell user feature is ready for acceptance
  - Provide test instructions
  - Ask them to validate and mark as accepted
  - Explain: Shipped ≠ Accepted (you're at "shipped" now)

---

## Pre-Shipped Validation

Before marking status as "shipped", answer these questions:

- [ ] **Would I be confident showing this to a user?** (Yes required)
- [ ] **Does this actually solve the problem?** (Yes required)
- [ ] **Would this survive production use?** (Yes required)
- [ ] **Is the code maintainable?** (Yes required)
- [ ] **Are the tests comprehensive?** (Yes required)
- [ ] **Is documentation accurate and complete?** (Yes required)

If ANY answer is "No" or "Not sure" → Feature is NOT ready to be marked shipped.

---

## Mark as Shipped

**Only after ALL items above are checked:**

### Version Update (Framework Development)

**CRITICAL ORDER**: Update version BEFORE running final tests, so test results are logged with correct version.

- [ ] **Update VERSION file first** (`echo "X.Y.Z" > VERSION`)
- [ ] **Update STACK.md version** to match
- [ ] **Update spec/FEATURES.md version** to match
- [ ] **THEN run tests** (`bash tests/validate_framework.sh`)
- [ ] **Update test result files** with new version:
  - `tests/VERIFICATION_REPORT.md`
  - `tests/LLM_TEST_RESULTS.md`

**Anti-pattern**: Running tests first, then updating version = test results logged against wrong version.

### Core Profile

- [ ] **Update `OVERVIEW.md`**
  - Mark capability as [x] implemented
  - Update "What works now"

### Formal Profile

- [ ] **Update `spec/FEATURES.md`**
  ```markdown
  Status: shipped
  Implementation:
    State: complete
    Code: [actual file paths]
  Tests:
    Unit: complete
    Integration: complete
    Acceptance: complete
  Verification:
    Accepted: no  # Human will accept
    Accepted at: 
  ```

- [ ] **Commit all changes**
  - Use Before Commit Checklist
  - Get human approval
  - Commit with message like: `feat: complete feature F-#### [description]`

---

## After Shipping

- [ ] **Request human acceptance**
  - "Feature F-#### is now shipped and ready for your validation"
  - Provide test instructions
  - Wait for human to test and accept
  - Human will update `Verification: Accepted: yes` when satisfied

- [ ] **Move to next work**
  - Check STATUS.md for next focus
  - Don't start immediately - ask human what's next
  - Update STATUS.md with new focus

---

## Anti-Patterns

❌ **Don't** mark shipped without acceptance file  
❌ **Don't** mark shipped with incomplete tests  
❌ **Don't** mark shipped if you haven't manually tested it  
❌ **Don't** mark shipped with known bugs/issues  
❌ **Don't** auto-accept (Accepted: yes) - human does that  
❌ **Don't** skip documentation updates  

✅ **Do** ensure every acceptance criterion is met  
✅ **Do** test manually end-to-end  
✅ **Do** leave Verification: Accepted: no for human  
✅ **Do** provide clear test instructions to human  
✅ **Do** be thorough before claiming "done"  

---

## Remember: Shipped ≠ Accepted

**Shipped** = You believe it's done, tests pass, code committed  
**Accepted** = Human validated it actually works and solves the problem

This checklist is for getting to "shipped". Human acceptance is the final gate.

**Quality bar**: If you wouldn't be confident demonstrating this to the user, it's not ready to ship.

