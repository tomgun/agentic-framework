# Before Commit Checklist

**Purpose**: Ensure every commit is clean, tested, and properly documented.

**Use**: BEFORE every `git commit`. No exceptions.

**🚨 CRITICAL**: Never commit without human approval. This checklist is for preparing the commit, not executing it.

---

## Work-In-Progress Check (FIRST!)

- [ ] **WIP.md must be completed**
  ```bash
  # Check if WIP lock exists
  ls WIP.md 2>/dev/null
  ```
  
  - **If WIP.md exists**: Work is not yet complete!
    - Complete work first: `bash .agentic/tools/wip.sh complete`
    - This removes the WIP lock file
    - **NEVER commit while WIP.md exists** (indicates incomplete work)
  
  - **If WIP.md does not exist**: ✓ OK to proceed with commit checks

**Why**: WIP.md is a lock file that tracks in-progress work. If it exists, the work is not ready for commit.

---

## Code Quality

- [ ] **All tests pass**
  - Run full test suite
  - Check output carefully (no ignored/skipped tests that shouldn't be)
  - No test failures or errors

- [ ] **Smoke test passed** (CRITICAL for user-facing changes)
  - **If this commit adds/changes user-facing functionality, you MUST run the application and verify it works**
  - See `.agentic/checklists/smoke_testing.md` for full checklist
  - Quick check:
    - [ ] Application starts without errors
    - [ ] Primary user action works (click button, move piece, submit form, etc.)
    - [ ] No console/log errors
    - [ ] Expected behavior happens
  - **If smoke test fails, DO NOT commit - fix it first**

- [ ] **Quality checks pass** (if enabled)
  - If `quality_validation_enabled: yes` in STACK.md
  - Run `bash quality_checks.sh` (at repo root)
  - Fix all issues found
  - Stack-specific checks must pass

- [ ] **Code follows standards**
  - Check `.agentic/quality/programming_standards.md`
  - Clear names, small functions, explicit errors
  - No obvious code smells

- [ ] **No debug code left**
  - Remove console.log, print(), debugger statements
  - Remove commented-out code blocks
  - Remove temporary test files

---

## Documentation Sync (MANDATORY)

### Core Profile

- [ ] **`PRODUCT.md` reflects reality**
  - Implemented capabilities marked with [x]
  - "What works now" is accurate
  - "Known limitations" is current

- [ ] **`JOURNAL.md` updated**
  - Session summary added
  - What was accomplished
  - Any important decisions
  - What's next (if session continuing)

- [ ] **`CONTEXT_PACK.md` current** (if architecture changed)
  - New modules documented?
  - Entry points still accurate?
  - Architecture snapshot current?

### Core+Product Profile (All Core items plus:)

- [ ] **`spec/FEATURES.md` reflects reality**
  - Status accurate (`planned` / `in_progress` / `shipped`)
  - Implementation State accurate (`none` / `partial` / `complete`)
  - **CRITICAL**: Never `State: none` if code exists
  - Implementation Code: Actual file paths listed
  - Tests: Accurate state (`todo` / `partial` / `complete`)
  - Verification: `Accepted: no` (human will accept later)

- [ ] **`STATUS.md` updated**
  - Current session state reflects work done
  - Completed this session lists accomplishments
  - Next immediate step is clear
  - Blockers documented (if any)

- [ ] **`spec/acceptance/F-####.md` exists** (if feature work)
  - Acceptance criteria defined
  - Not a placeholder
  - Testable conditions listed

---

## No Stale Placeholders

- [ ] **No "(Not yet created)" text**
  - Search codebase for this phrase
  - Replace with actual content or remove reference

- [ ] **No empty templates**
  - FEATURES.md entries are filled
  - Acceptance files have content
  - No TODO without plan

- [ ] **File paths in docs exist**
  - FEATURES.md Code: paths point to real files
  - CONTEXT_PACK.md references are valid
  - No broken references

---

## Code Annotations (Core+Product)

- [ ] **@feature annotations added**
  - Functions implementing F-#### have `@feature F-####` comment
  - At function/class level
  - Enables traceability

- [ ] **@acceptance annotations added** (if acceptance tests)
  - Test functions have `@acceptance A-####`
  - Links tests to acceptance criteria

- [ ] **@nfr annotations added** (if NFR-related)
  - Code addressing NFR-#### has `@nfr NFR-####`
  - Security, performance, reliability code

---

## Human Approval (MANDATORY)

- [ ] **Show summary of changes to user**
  - What files changed
  - What was added/modified/deleted
  - Why these changes were made

- [ ] **Wait for explicit approval**
  - User must say "commit", "looks good", "go ahead", or similar
  - Exception: User gave blanket approval earlier in session
  - Never commit without permission

- [ ] **Confirm commit message**
  - Show proposed commit message
  - Get approval or modify based on feedback

---

## Commit Message Quality

- [ ] **Commit message follows convention**
  - Format: `type(scope): description`
  - Types: feat, fix, test, docs, refactor, chore
  - Clear, concise description

- [ ] **Commit message is accurate**
  - Describes what changed
  - Describes why (if not obvious)
  - References feature ID if applicable (F-####)

**Example good messages:**
```
feat(auth): implement user login with JWT tokens (F-0003)
fix(api): handle network timeout gracefully (F-0002)
test(export): add edge cases for CSV export (F-0005)
docs(readme): update installation instructions
```

---

## Final Checks

- [ ] **Check for untracked files** (CRITICAL - prevents deployment issues!)
  ```bash
  git status --short | grep '??'
  # Or: bash .agentic/tools/check-untracked.sh
  ```
  - Check: assets/, src/, tests/, spec/, docs/ for untracked files
  - **If you created new files, they MUST be git added!**
  - Either: `git add <file>` to track
  - Or: Add to `.gitignore` if intentionally untracked
  - **WARNING**: Untracked files = missing from deployment!

- [ ] **Git status clean** (no unexpected files)
  - `git status` shows only intended changes
  - No untracked files that should be ignored
  - .gitignore is correct

- [ ] **Diff review**
  - `git diff` shows only intentional changes
  - No accidental formatting changes
  - No sensitive data (API keys, passwords)

- [ ] **Files staged correctly**
  - `git add` only files that should be committed
  - Not committing temp files, logs, etc.

---

## After Human Approves

- [ ] **Execute commit**
  - `git commit -m "message"` or interactive commit
  - Verify commit was created

- [ ] **Push if requested**
  - Only push if human explicitly said to push
  - "commit and push" → push immediately
  - "commit" → wait, don't push yet

---

## Anti-Patterns

❌ **Don't** commit without human approval  
❌ **Don't** commit with failing tests  
❌ **Don't** commit without updating JOURNAL.md  
❌ **Don't** commit with stale FEATURES.md/PRODUCT.md  
❌ **Don't** commit with "(Not yet created)" placeholders  
❌ **Don't** commit debug code (console.log, etc.)  

✅ **Do** show changes before committing  
✅ **Do** wait for explicit approval  
✅ **Do** update docs in same commit as code  
✅ **Do** run quality checks  
✅ **Do** write clear commit messages  

---

## Checklist Complete

**After all items checked:**
1. Show this checklist with all ✅ to user
2. Show summary of changes
3. Propose commit message
4. Ask: "Ready to commit?" or "Anything to change before committing?"
5. Wait for approval
6. Commit only after approval

**Remember**: This checklist prevents bugs, maintains quality, and keeps documentation current. Never skip it.

