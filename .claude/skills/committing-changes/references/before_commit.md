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

## Documentation Sync (3 concerns — MANDATORY)

This is the backstop for ALL commits. If you followed implementing-features Step 6, verify these are done. If you bypassed `ag implement` (direct coding, doc-only changes, hook fixes), do them now.

### Concern 1: Project docs via registry

- [ ] **`feature_done` docs verified or updated**
  - Run `bash .agentic/lib/tools/docs.sh --list` to see the registry
  - For each doc with trigger `feature_done`: check if your changes made it stale, update if needed
  - Common feature_done docs: `docs/HOW_IT_WORKS.md`, `docs/INSTRUCTION_ARCHITECTURE.md`, `.agentic/lib/DEVELOPER_GUIDE.md`, `.agentic/OVERVIEW.md`, `docs/FRAMEWORK_WORKFLOW.md`

- [ ] **`pr`-triggered docs verified or updated** (at commit time, also check these)
  - `CHANGELOG.md` — entry for this change?
  - `README.md` — still accurate?
  - `CONTRIBUTIONS.md` — user design insights captured?

- [ ] **Drift and registry health**
  - Run `bash .agentic/lib/tools/drift.sh --docs` to detect stale docs
  - Run `bash .agentic/lib/tools/docs.sh --validate` for registry health (missing files, unregistered docs)

### Concern 2: Registry maintenance

- [ ] **New docs registered**
  - If you created a new doc → `docs.sh --create <path> --type <type> --trigger <trigger>`
  - If your change touches a component with no registered doc → decide whether it needs one
  - If a registered doc was deleted or moved → update its `## Docs` entry in STACK.md

### Concern 3: Instruction files (framework dev only — skip if `FRAMEWORK_DEVELOPMENT.md` absent)

- [ ] **Quick Commands updated** (if new/changed `ag` command) — 5 files:
  - `.agentic/lib/agents/claude/CLAUDE.md`, `CLAUDE.md` (root), `.cursorrules`
  - `.agentic/lib/agents/copilot/copilot-instructions.md`, `.agentic/lib/agents/codex/codex-instructions.md`
- [ ] **Trigger tables updated** (if new trigger word) — 4 files:
  - `.cursorrules`, `.agentic/lib/agents/copilot/copilot-instructions.md`
  - `.agentic/lib/agents/codex/codex-instructions.md`, `.agentic/lib/agents/shared/auto_orchestration.md`
- [ ] **`help.sh` updated** (if new `ag` command) — both `feature_tracking` on/off sections
- [ ] **`memory-seed.md` updated** (if changed agent behavior)
- [ ] Run `bash .agentic/lib/tools/instruction-sync.sh 2>/dev/null` to detect drift

### Core Artifacts (always)

- [ ] **`JOURNAL.md` updated** — session summary, decisions, next steps
- [ ] **`.agentic/STATUS.md` updated** — current state, completed items, next step, blockers
- [ ] **`.agentic/OVERVIEW.md` reflects reality** — capabilities, limitations current
- [ ] **`CONTEXT_PACK.md` current** (if architecture changed) — modules, entry points, snapshot

### Formal Profile (all Core items plus:)

- [ ] **`.agentic/spec/FEATURES.md` reflects reality**
  - Status accurate (9-state lifecycle: planned → specced → criteria_set → tests_written → implementing → verified → documented → committed → shipped)
  - Implementation State accurate (`none` / `partial` / `complete`)
  - **CRITICAL**: Never `State: none` if code exists
  - Implementation Code: Actual file paths listed
  - Tests: Accurate state (`todo` / `partial` / `complete`)
  - Verification: `Accepted: no` (human will accept later)

- [ ] **`.agentic/spec/acceptance/F-####.md` exists** (if feature work)
  - Acceptance criteria defined
  - Not a placeholder
  - Testable conditions listed

- [ ] **Affected shipped specs evolved** (if changes overlap with existing features)
  - Do your changes modify behavior covered by shipped acceptance criteria?
  - If yes: create a migration (`migration.sh create "description"`), add new ACs to affected `spec/acceptance/F-XXXX.md` with migration reference
  - Specs are living documents — they evolve as understanding deepens

---

## Framework Development Only — LLM Tests

- [ ] **LLM test required** (if behavioral changes)
  - If this commit adds/changes `ag` commands, trigger words, or agent workflows → MUST add LLM test
  - The LLM layer decides if deterministic code gets called — no LLM test = no proof agents use the feature
  - Add test in `tests/llm/tests/` + entry in `test_definitions.json`

---

## Capture Deferred Items

- [ ] **Any future work mentioned in this PR/plan?**
  - Scan plan, PR description, and code comments for "future", "follow-up", "TODO", "deferred", "later"
  - Run `ag todo "description"` for each deferred item — don't let them stay buried in prose
  - **MANDATORY**: If you have context (source plan, related PR, architecture doc, why it matters), add `- **Background**:` and `- **Related**:` fields to the TODO entry immediately after creating it. A one-liner TODO without available context is unactionable — the context is cheaper to write now than to rediscover later

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

