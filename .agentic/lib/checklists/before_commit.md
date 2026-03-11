---
summary: "Pre-commit quality gates and human approval"
trigger: "commit, push, ship, finalize, ag commit"
tokens: ~2700
requires: [feature_implementation.md]
phase: commit
---

# Before Commit Checklist

**Purpose**: Ensure every commit is clean, tested, and properly documented.

**Use**: BEFORE every `git commit`. No exceptions.

**🚨 CRITICAL**: Never commit without human approval. This checklist is for preparing the commit, not executing it.

---

## Git Hooks Check (BEFORE ANYTHING ELSE!)

- [ ] **Are git hooks installed?**
  ```bash
  actual=$(git config core.hooksPath 2>/dev/null || echo "")
  if [ "$actual" != ".agentic/hooks" ]; then
    echo "WARNING: hooks not installed — run: git config core.hooksPath .agentic/hooks"
  fi
  ```
  - If not installed: **fix immediately** before proceeding
  - Without hooks, pre-commit quality gates are silently skipped
  - This is the #1 cause of unvalidated commits slipping through

---

## Branch Check

- [ ] **Am I on a feature branch?**
  ```bash
  git branch --show-current
  ```

  - **If on `main` or `master`**: ⚠️ **STOP! Do NOT commit directly.**
    - Create a feature branch: `git checkout -b feature/description`
    - Or ask user: "I'm on main. Should I create a PR or push directly?"
    - **Only push to main if user explicitly says "push to main directly"**

  - **If on feature branch**: ✓ OK to proceed with commit checks

**Why**: Direct commits to main skip code review and can introduce bugs. PRs are safer.

---

## Work-In-Progress Check (FIRST!)

- [ ] **.agentic/session/WIP.md must be completed**
  ```bash
  # Check if WIP lock exists (no output = doesn't exist = OK)
  ls .agentic/session/WIP.md 2>/dev/null || true
  ```
  
  - **If .agentic/session/WIP.md exists**: Work is not yet complete!
    - Complete work first: `bash .agentic/lib/tools/wip.sh complete`
    - This removes the WIP lock file
    - **NEVER commit while .agentic/session/WIP.md exists** (indicates incomplete work)
  
  - **If .agentic/session/WIP.md does not exist**: ✓ OK to proceed with commit checks

**Why**: .agentic/session/WIP.md is a lock file that tracks in-progress work. If it exists, the work is not ready for commit.

---

## Code Quality

- [ ] **All tests pass**
  - Run full test suite
  - Check output carefully (no ignored/skipped tests that shouldn't be)
  - No test failures or errors

- [ ] **Smoke test passed** (CRITICAL for user-facing changes)
  - See `.agentic/lib/checklists/smoke_testing.md` for full checklist
  - Quick: app starts, primary action works, no errors
  - **If smoke test fails, DO NOT commit - fix it first**

- [ ] **Quality checks pass** (if enabled)
  - If `quality_validation_enabled: yes` in STACK.md
  - Run `bash quality_checks.sh` (at repo root)
  - Fix all issues found
  - Stack-specific checks must pass

- [ ] **Code follows standards**
  - Check `.agentic/lib/quality/programming_standards.md`
  - Clear names, small functions, explicit errors
  - No obvious code smells

- [ ] **No debug code left**
  - Remove console.log, print(), debugger statements
  - Remove commented-out code blocks
  - Remove temporary test files

---

## Documentation Sync (MANDATORY)

### Core Profile

- [ ] **`.agentic/OVERVIEW.md` reflects reality**
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

### Project Documentation

- [ ] **Project docs updated with code changes**
  - Spec + code + tests + docs = done — don't defer artifact updates to a follow-up
  - Run `bash .agentic/lib/tools/docs.sh --validate` to check registry health (missing files, unregistered docs)
  - Run `bash .agentic/lib/tools/docs.sh --list` to see the doc registry and which components they cover
  - Run `bash .agentic/lib/tools/drift.sh --docs` to detect stale docs
  - If you changed user-facing behavior, update the relevant docs
  - If your change touches a component with no registered doc, decide whether it needs one — use `docs.sh --create <path> --type <type> --trigger <trigger>` to scaffold and auto-register
  - If you created or changed a doc, ensure its `## Docs` entry in STACK.md has correct component/area tags

### Formal Profile (All Core items plus:)

- [ ] **`.agentic/spec/FEATURES.md` reflects reality**
  - Status accurate (9-state lifecycle: planned → specced → criteria_set → tests_written → implementing → verified → documented → committed → shipped)
  - Implementation State accurate (`none` / `partial` / `complete`)
  - **CRITICAL**: Never `State: none` if code exists
  - Implementation Code: Actual file paths listed
  - Tests: Accurate state (`todo` / `partial` / `complete`)
  - Verification: `Accepted: no` (human will accept later)

- [ ] **`.agentic/STATUS.md` updated**
  - Current session state reflects work done
  - Completed this session lists accomplishments
  - Next immediate step is clear
  - Blockers documented (if any)

- [ ] **`.agentic/spec/acceptance/F-####.md` exists** (if feature work)
  - Acceptance criteria defined
  - Not a placeholder
  - Testable conditions listed

---

## Framework Development Only

These checks apply only when working on the agentic framework repo itself:

- [ ] **Instruction files updated** (if `ag` commands/gates/workflows changed)
  - CLAUDE.md templates, cursorrules.txt, copilot-instructions.md, codex-instructions.md
  - agent_operating_guidelines.md, auto_orchestration.md
  - memory-seed.md, DEVELOPER_GUIDE.md, HOW_IT_WORKS.md
  - Skills/checklists that reference the changed behavior
  - Run `bash .agentic/lib/tools/instruction-sync.sh 2>/dev/null` to detect drift

- [ ] **LLM test coverage considered** (if behavioral changes)
  - If this commit adds/changes `ag` commands, trigger words, or agent workflows
  - Check `tests/llm/test_definitions.json` for existing coverage
  - LLM tests verify agents actually follow instructions — unit tests can't catch behavioral gaps

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

## Code Annotations (Formal)

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
  # Or: bash .agentic/lib/tools/check-untracked.sh
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

❌ **Don't** commit directly to main (create PR instead)
❌ **Don't** commit without human approval
❌ **Don't** commit with failing tests
❌ **Don't** commit without updating JOURNAL.md
❌ **Don't** commit with stale FEATURES.md/OVERVIEW.md
❌ **Don't** commit with "(Not yet created)" placeholders
❌ **Don't** commit debug code (console.log, etc.)

✅ **Do** check branch first (`git branch --show-current`)
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

