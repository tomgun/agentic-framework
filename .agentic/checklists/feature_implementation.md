# Feature Implementation Checklist

**Purpose**: Ensure systematic, complete feature implementation with proper tracking.

**Use when**: Implementing any feature (F-#### in Core+Product, or general feature in Core).

---

## Before Starting Implementation

### 1. Verify Feature Definition

- [ ] **Feature has acceptance criteria**
  - Core+Product: `spec/acceptance/F-####.md` exists
  - Core: Acceptance criteria in `PRODUCT.md` or clear user request
  - If missing: Create it first or escalate to `HUMAN_NEEDED.md`

- [ ] **Read and understand acceptance criteria**
  - What defines "done"?
  - What are the testable success conditions?
  - Are there edge cases explicitly mentioned?

- [ ] **Check dependencies** (Core+Product only)
  - Look at `Dependencies:` field in `spec/FEATURES.md`
  - Are dependent features complete?
  - If not, implement dependencies first

### 2. Check Development Mode

- [ ] **Confirm TDD or standard mode** (`STACK.md` → `development_mode:`)
  - TDD → Write failing test first
  - Standard → Can write code first, but tests are still mandatory

### 3. Understand Scope

- [ ] **Identify minimal files to touch**
  - Check `CONTEXT_PACK.md` → "Where to look first"
  - Don't change more than necessary
  - Small, reviewable increments

- [ ] **Identify tests to add/modify**
  - Unit tests for new logic
  - Integration tests if crossing boundaries
  - Acceptance tests for end-to-end validation

---

## During Implementation

### If TDD Mode (Recommended)

- [ ] **Write failing test first** (RED)
  - Test expresses desired behavior
  - Run test → verify it fails
  - Commit: `test: add failing test for [behavior]`

- [ ] **Write minimal code to pass** (GREEN)
  - Don't over-engineer
  - Just make test pass
  - Run tests → verify they pass

- [ ] **Refactor for clarity** (REFACTOR)
  - Improve names, structure
  - Remove duplication
  - Tests still pass

- [ ] **Repeat cycle** for next behavior
  - Small increments (one test at a time)
  - Clear progress checkpoints

### If Standard Mode

- [ ] **Implement code and tests together**
  - Write code for one unit of behavior
  - Write tests for that behavior
  - Run tests → verify they pass

### Code Quality Checks (Both Modes)

- [ ] **Follow programming standards** (`.agentic/quality/programming_standards.md`)
  - Clear, descriptive names
  - Small functions (<50 lines ideal)
  - Explicit error handling
  - No magic numbers
  - Max nesting depth <4

- [ ] **Follow testing standards** (`.agentic/quality/testing_standards.md`)
  - Test happy path
  - Test edge cases
  - Test invalid input
  - Test error conditions
  - Test time-based behavior (if applicable)

- [ ] **Add code annotations**
  - `@feature F-####` on relevant functions (Core+Product)
  - `@acceptance A-####` on acceptance test functions
  - `@nfr NFR-####` on NFR-related code

### Documentation Updates

- [ ] **Update code comments**
  - Explain "why" not "what"
  - Document non-obvious decisions
  - Keep comments current

---

## After Implementation

### Update Tracking (Core+Product)

- [ ] **Update `spec/FEATURES.md`**
  - Status: `planned` → `in_progress` → `shipped`
  - Implementation State: `none` → `partial` → `complete`
  - Implementation Code: Add actual file paths
  - Tests: `todo` → `partial` → `complete`
  - **CRITICAL**: Never `State: none` if code exists
  - **CRITICAL**: Never `Status: shipped` without acceptance file

### Update Tracking (Core)

- [ ] **Update `PRODUCT.md`**
  - Mark implemented capabilities with [x]
  - Update "What works now" section
  - Keep "Known limitations" current

### Update Session Tracking

- [ ] **Update `JOURNAL.md`**
  - Session date and feature
  - What was accomplished
  - Any decisions made
  - Blockers encountered (if any)
  - What's next

- [ ] **Update `STATUS.md`** (Core+Product)
  - Current session state
  - Completed this session
  - Next immediate step

- [ ] **Update `CONTEXT_PACK.md`** (if architecture changed)
  - New modules added?
  - New entry points?
  - Architecture diagram needs update?

### Verify Quality

- [ ] **All tests pass**
  - Run full test suite
  - No skipped or ignored tests
  - Check test output carefully

- [ ] **Run quality checks** (if enabled)
  - `bash quality_checks.sh` (if exists)
  - Fix any issues found
  - Don't commit with failing quality checks

- [ ] **No stale placeholders**
  - Search for "(Not yet created)"
  - Search for "TODO" (unless intentional future work)
  - Replace placeholders with actual content

---

## Before Committing

- [ ] **Use Before Commit Checklist** (`.agentic/checklists/before_commit.md`)
  - Don't commit without running that checklist
  - Every commit must pass all checks

---

## Error Recovery

**When things go wrong during feature implementation:**

### Problem: Tests keep failing after implementation

**Quick fixes**:
1. Re-read acceptance criteria - are you testing the right behavior?
2. Check test setup/teardown - is test environment clean?
3. Run test in isolation - does it pass alone but fail in suite?
4. Check for timing issues - add delays if testing async code
5. Verify test framework is configured correctly

**If still stuck after 15 min**: Add to HUMAN_NEEDED.md with test code, implementation code, and error message

---

### Problem: Feature scope is too large (can't complete in session)

**Solutions**:
1. **Split it**: Break into smaller sub-features, implement incrementally
2. **MVP first**: Implement minimal working version, enhance later
3. **Commit partial work**: Mark feature `State: partial`, commit what works
4. **Add task**: Create follow-up task in STATUS.md for remaining work

**Example split**:
- Original: F-0010 "User authentication"
- Split into:
  - F-0010a: Login form UI (1 hour)
  - F-0010b: API integration (1 hour)
  - F-0010c: Error handling (30 min)
  - F-0010d: "Remember me" feature (30 min)

---

### Problem: Unclear acceptance criteria or conflicting requirements

**Immediate actions**:
1. **Don't guess**: Stop coding immediately
2. **Document confusion**: What specifically is unclear?
3. **Add to HUMAN_NEEDED.md**: With specific questions and options
4. **Work on something else**: Switch to feature with clear requirements

**Example escalation**:
```
H-0047: F-0010 Acceptance Unclear

Acceptance criterion says "secure password storage" but doesn't specify:
- Hash algorithm (bcrypt? argon2? scrypt?)
- Salt rounds/iterations?
- Pepper key needed?

Options:
a) bcrypt with 12 rounds (industry standard)
b) argon2id (newer, more secure)
c) Other?

Blocking: F-0010 implementation
```

---

### Problem: Dependencies not ready

**Check**:
1. In FEATURES.md, what does `Dependencies:` say?
2. Are those features actually `Status: shipped`?
3. Can you work on non-dependent parts first?

**Solutions**:
- Implement dependencies first (if small)
- Use mocks/stubs for now, integrate later
- Switch to feature without dependencies
- Add to HUMAN_NEEDED.md if dependency priority unclear

---

### Problem: Code getting messy/complex

**Signs**:
- Functions >100 lines
- Deep nesting (>4 levels)
- Lots of duplication
- Hard to write tests

**Solutions**:
1. **Stop adding features**: Don't make it worse
2. **Refactor first**: Clean up while tests are passing
3. **Extract functions**: Break large functions into smaller ones
4. **Add tests**: Makes refactoring safe
5. **Commit clean code**: Then add new feature on clean foundation

**Don't**: Continue adding features to messy code (compound problem)
**Do**: Clean up first, then extend

---

### Problem: Forgot to update FEATURES.md/PRODUCT.md

**Discovered later (before commit)**:
1. Update it now before committing
2. Check `Implementation: State` matches reality
3. Check `Implementation: Code` lists actual files
4. Check `Tests:` fields are accurate

**Discovered after commit**:
1. Create immediate follow-up commit: `docs: update FEATURES.md for F-0010`
2. No big deal, just fix it
3. Add JOURNAL.md note about forgetting (learn from it)

**Prevention**: Use this checklist every time!

---

### Problem: Quality checks failing

**Linter errors**:
- Fix immediately (don't commit broken code)
- If unsure how to fix, check programming_standards.md
- Most linters can auto-fix (`eslint --fix`, `black .`, `cargo fmt`)

**Test failures** (unrelated to your code):
- **Don't ignore**: These are regressions
- **Revert your changes**: Verify tests pass without your code
- **Find what broke**: Bisect your changes to find culprit
- **Fix it**: Don't proceed until green

**Test coverage too low**:
- Add more tests (missed edge cases?)
- Check testing_standards.md for what to test
- Don't skip tests to pass coverage threshold

---

## Anti-Patterns

❌ **Don't** mark `Status: shipped` without acceptance file  
❌ **Don't** leave `State: none` if code exists  
❌ **Don't** implement without tests  
❌ **Don't** skip documentation updates  
❌ **Don't** change 10 files when 2 would do  

✅ **Do** small increments (easier to review)  
✅ **Do** update tracking in same commit as code  
✅ **Do** write tests (TDD: first; Standard: alongside)  
✅ **Do** keep FEATURES.md/PRODUCT.md accurate  
✅ **Do** add code annotations

