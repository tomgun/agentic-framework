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

