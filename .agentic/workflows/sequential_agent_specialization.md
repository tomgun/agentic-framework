# Sequential Agent Specialization (Agent Pipeline)

**Purpose**: Enable specialized agents to work sequentially on tasks, each focusing on their expertise while maintaining context through durable artifacts.

**Key benefit**: **Context optimization** - each agent loads only what they need for their role, dramatically reducing token usage while improving output quality.

**Status**: Recommended pattern for complex features. Simple features can use single general-purpose agent.

---

## Why Sequential Specialization?

### The Problem with General-Purpose Agents

A single agent doing everything must load:
- Research context + planning context + implementation context + testing context + documentation context
- **Result**: 150-200K+ tokens, agent tries to do everything at once, quality suffers from cognitive overload

### The Sequential Specialization Solution

Each specialist agent loads only their context:
- Research Agent: ~30K tokens (research docs, references)
- Planning Agent: ~40K tokens (specs, architecture)
- Test Agent: ~35K tokens (acceptance criteria, test patterns)
- Implementation Agent: ~50K tokens (tests, related code)
- Review Agent: ~45K tokens (implementation, quality checklists)
- Spec Update Agent: ~25K tokens (specs only)
- Documentation Agent: ~35K tokens (docs, implementation summary)
- Git Agent: ~20K tokens (changed files, commit protocol)

**Result**: 
- Each agent <50K tokens (vs 150-200K for general agent)
- Total ~280K tokens but **sequential** (not all at once)
- **Higher quality** (specialist focus, no cognitive overload)
- **Better context efficiency** (each agent loads exactly what they need)

---

## When to Use Sequential Specialization

**✅ Good for:**
- Complex features (>3 acceptance criteria)
- Features requiring research
- Features with significant documentation needs
- Security-sensitive features (benefit from review agent)
- Performance-critical features (benefit from performance agent)

**❌ Overkill for:**
- Simple bug fixes (<10 lines changed)
- Trivial features (1-2 acceptance criteria)
- Documentation-only changes
- Refactoring without new behavior

**💡 Rule of thumb**: If feature spans >5 files or needs research, use sequential specialization.

---

## Core Agent Pipeline

### Standard Feature Development Flow

```
Feature Request
   ↓
Research Agent (if new tech/unclear)
   ↓
Planning Agent (define feature, acceptance criteria)
   ↓
Test Agent (write failing tests - TDD)
   ↓
Implementation Agent (make tests pass)
   ↓
Build Agent (verify build, bundle, compile)
   ↓
Review Agent (verify quality, code review)
   ↓
Spec Update Agent (update FEATURES.md, STATUS.md, JOURNAL.md)
   ↓
Documentation Agent (update docs)
   ↓
Git Agent (commit with human approval, create PR)
   ↓
Deploy Agent (deploy to staging/production - optional, triggered by merge)
   ↓
Done ✅
```

---

## Agent Roles & Responsibilities

### 1. Research Agent 🔬

**When to invoke**: New technologies, unclear requirements, field updates

**Context budget**: ~30K tokens

**Loads**:
- ✅ `STACK.md` (current tech stack)
- ✅ `spec/PRD.md` (user needs)
- ✅ `spec/REFERENCES.md` (existing research)
- ✅ `docs/research/` (past research sessions)
- ❌ Implementation code
- ❌ Tests
- ❌ JOURNAL.md

**Responsibilities**:
1. Investigate technologies, best practices, alternatives
2. Compare options (pros/cons)
3. Create `docs/research/[TOPIC]-YYYY-MM-DD.md`
4. Update `spec/REFERENCES.md` with findings
5. Recommend approach OR escalate to `HUMAN_NEEDED.md` if decision required

**Outputs**:
- Research document: `docs/research/[TOPIC]-YYYY-MM-DD.md`
- Updated `REFERENCES.md`
- Recommendation summary for Planning Agent

**Handoff format**:
```markdown
## Handoff: Research → Planning

**Feature**: F-0042 (User authentication)
**Research complete**: Auth strategies

**Recommendation**: Use Auth.js (NextAuth) for OAuth 2.0

**Context for Planning Agent**:
- Read: docs/research/auth-strategies-2026-01-02.md (Recommendation section)
- Requirements: spec/PRD.md (R-0042, R-0043)
- Constraints: spec/NFR.md (NFR-0002 security)

**Key decisions made**:
- Auth strategy: OAuth 2.0
- Library: Auth.js (Next.js optimized)
- Session: Secure HTTP-only cookies

**Open questions for Planning**:
- Social providers: Google, GitHub, both?
- Email/password: Also support, or OAuth only?
- MFA: v1.0 or defer?

**Next steps**:
1. Define F-0042 in FEATURES.md
2. Write acceptance criteria
3. Create ADR-0005 documenting decision
```

**Tools**: Web search, Context7, `research_mode.md`

---

### 2. Planning Agent 📋

**When to invoke**: After research, for new features, complex changes

**Context budget**: ~40K tokens

**Loads**:
- ✅ Research findings (from Research Agent handoff)
- ✅ `spec/PRD.md` (requirements)
- ✅ `spec/TECH_SPEC.md` (architecture)
- ✅ `spec/FEATURES.md` (existing features, dependencies)
- ✅ `spec/NFR.md` (constraints)
- ❌ Implementation code
- ❌ Tests

**Responsibilities**:
1. Define feature in `FEATURES.md` (F-####, status: planned)
2. Write `spec/acceptance/F-####.md` (detailed acceptance criteria)
3. Identify dependencies (`deps.py` to check blockers)
4. Estimate complexity (S/M/L)
5. List affected NFRs
6. Create ADR if architectural decision needed
7. Update `TECH_SPEC.md` if architecture changes
8. Determine test strategy (unit/integration/E2E split)

**Outputs**:
- Feature entry in `FEATURES.md` (complete metadata)
- Acceptance criteria: `spec/acceptance/F-####.md`
- ADR (if needed): `spec/adr/ADR-####-[title].md`
- Updated `TECH_SPEC.md` (if architecture changed)
- Updated `STATUS.md` ("Next up" section)

**Handoff format**:
```markdown
## Handoff: Planning → Test

**Feature**: F-0042 (User authentication)
**Planning complete**: Feature defined, acceptance criteria written

**What was defined**:
- Feature: spec/FEATURES.md (F-0042, status: planned, complexity: M)
- Acceptance criteria: spec/acceptance/F-0042.md (6 ACs: AC1-AC6)
- ADR-0005: Auth.js decision documented
- Architecture: spec/TECH_SPEC.md updated (Auth section added)

**Test strategy**:
- Unit: Auth logic (login, session, validation)
- Integration: API routes (/api/auth/*)
- E2E: Full login flow (UI → API → success)

**Context for Test Agent**:
- Read: spec/acceptance/F-0042.md (ALL 6 acceptance criteria)
- Test framework: Vitest (unit), Playwright (E2E) - see STACK.md
- Test patterns: __tests__/auth/*.test.ts (existing auth tests for reference)

**Next steps**:
1. Write failing unit tests for AC1-AC4 (auth logic)
2. Write failing integration tests for AC5 (API)
3. Write failing E2E test for AC6 (login flow)
4. All tests should FAIL (red phase) ✅
```

**Tools**: `feature_graph.py`, `deps.py`, `doctor.py`, `verify.py`

---

### 3. Test Agent 🧪

**When to invoke**: If `STACK.md` has `development_mode: tdd` (RECOMMENDED)

**Context budget**: ~35K tokens

**Loads**:
- ✅ `spec/acceptance/F-####.md` (acceptance criteria - PRIMARY REFERENCE)
- ✅ `spec/FEATURES.md` (feature definition)
- ✅ `STACK.md` (test frameworks, test commands)
- ✅ Existing test files (for patterns/style)
- ❌ Research docs
- ❌ Most other specs
- ❌ Implementation code (minimal - just to understand interfaces)

**Responsibilities**:
1. Write **failing tests** for EACH acceptance criterion (AC1 → test1, AC2 → test2, etc.)
2. Ensure tests cover all ACs comprehensively
3. Follow test quality standards:
   - Descriptive test names (`should reject passwords shorter than 8 characters`)
   - Clear assertions (one behavior per test)
   - Deterministic (no flaky tests)
   - Use test data factories/fixtures (see `test_strategy.md`)
4. Add `@feature F-####` annotations to test files
5. Add `@acceptance AC#` annotations to specific tests
6. Run tests - verify they FAIL (red phase)
7. Document test coverage in `FEATURES.md`

**Outputs**:
- Test files (unit, integration, E2E)
- All tests **FAILING** (red phase - this is CORRECT in TDD!)
- Updated `FEATURES.md` (Tests: unit/integration/e2e = written)

**Handoff format**:
```markdown
## Handoff: Test → Implementation

**Feature**: F-0042 (User authentication)
**Tests written**: All acceptance criteria covered

**What was created**:
- Unit tests: __tests__/auth/login.test.ts (AC1-AC4, 12 tests total)
  - `@acceptance AC1`: Email validation (3 tests)
  - `@acceptance AC2`: Password validation (3 tests)
  - `@acceptance AC3`: Session creation (3 tests)
  - `@acceptance AC4`: Token generation (3 tests)
- Integration: __tests__/api/auth.test.ts (AC5, 4 tests)
  - `@acceptance AC5`: API endpoint tests
- E2E: e2e/auth/login.spec.ts (AC6, 3 tests)
  - `@acceptance AC6`: Full login flow

**Test status**: All FAILING (red phase) ✅

**Context for Implementation Agent**:
- Read: Test files above (they show EXACTLY what to implement)
- Read: spec/acceptance/F-0042.md (if test expectations unclear)
- Architecture: spec/TECH_SPEC.md (Auth section)
- **Goal**: Make tests pass (green phase)

**Implementation order suggestion**:
1. Auth logic first (unit tests)
2. API routes second (integration tests)
3. UI components last (E2E tests)

**Next steps**:
1. Implement lib/auth/login.ts (make unit tests pass)
2. Implement app/api/auth/[...nextauth]/route.ts (make integration tests pass)
3. Implement components/LoginForm.tsx (make E2E tests pass)
4. Run tests frequently (TDD red-green cycle)
```

**Tools**: Test framework (pytest, vitest, etc.), `coverage.py`, `tdd_mode.md`

---

### 4. Implementation Agent 💻

**When to invoke**: After tests written (TDD) or after planning (non-TDD)

**Context budget**: ~50K tokens

**Loads**:
- ✅ Test files (if TDD - PRIMARY GUIDE for what to implement)
- ✅ `spec/acceptance/F-####.md` (acceptance criteria)
- ✅ `spec/TECH_SPEC.md` (architecture guidance)
- ✅ `STACK.md` (languages, frameworks, conventions)
- ✅ Related code files (for patterns, integration points)
- ❌ Research docs
- ❌ Planning docs

**Responsibilities**:
1. Implement feature to make tests pass (TDD) OR meet acceptance criteria (non-TDD)
2. Follow programming standards (see `.agentic/quality/programming_standards.md`):
   - Clear, descriptive names (no cryptic abbreviations)
   - Small, focused functions (<50 lines ideal)
   - Handle errors explicitly (fail fast, specific error types)
   - No magic numbers (use named constants)
   - Avoid deep nesting (<4 levels)
   - Organize imports properly
3. Add `@feature F-####` annotations to code
4. Add `@acceptance AC#` annotations linking to specific criteria
5. Add `@nfr NFR-####` if implementing NFR requirements
6. Keep changes focused (no scope creep)
7. Run tests **frequently** (TDD: red → green cycle)
8. Refactor if needed (while keeping tests green)
9. Format code using project linter/formatter
10. Review own code against `programming_standards.md` checklist before handoff

**Outputs**:
- Implementation code
- Tests **PASSING** (green phase)
- Code annotations linking to feature/acceptance/NFRs

**Handoff format**:
```markdown
## Handoff: Implementation → Review

**Feature**: F-0042 (User authentication)
**Implementation complete**: All tests passing

**What was implemented**:
- Auth logic:
  - lib/auth/login.ts (@feature F-0042, @acceptance AC1-AC4)
  - lib/auth/session.ts (@feature F-0042, @acceptance AC3)
- API routes:
  - app/api/auth/[...nextauth]/route.ts (@feature F-0042, @acceptance AC5)
- UI components:
  - components/LoginForm.tsx (@feature F-0042, @acceptance AC6)

**Test status**: All PASSING ✅ (19/19 tests green)
- Unit: 12/12 passing
- Integration: 4/4 passing
- E2E: 3/3 passing

**Context for Review Agent**:
- Implementation files: Listed above
- Test files: __tests__/auth/*.test.ts, e2e/auth/*.spec.ts
- Acceptance criteria: spec/acceptance/F-0042.md
- Review checklist: .agentic/quality/review_checklist.md

**What to verify**:
1. All acceptance criteria met (AC1-AC6)
2. Code quality (clean, testable, maintainable)
3. Test coverage adequate (check with coverage.py)
4. Code annotations present and correct
5. Security review (auth is security-sensitive)
6. NFR compliance (NFR-0002 security requirements)

**Potential concerns for review**:
- Session storage: Using cookies (please verify security)
- Error handling: Basic for now (may need improvement)
- Rate limiting: Not implemented yet (future enhancement)
```

**Tools**: Linter, type checker, test runner, `consistency.py`

---

### 5. Build Agent 🏗️

**When to invoke**: After implementation complete, before code review

**Context budget**: ~30K tokens

**Loads**:
- ✅ `STACK.md` (build commands, tooling)
- ✅ Implementation code (to understand what was built)
- ✅ Build configuration files (package.json, Dockerfile, Makefile, etc.)
- ✅ `CONTEXT_PACK.md` (build instructions)
- ❌ Research docs
- ❌ Tests (already verified by Implementation Agent)
- ❌ Most specs

**Responsibilities**:
1. Run build/compile process
2. Verify bundle size (if applicable)
3. Check for build warnings/errors
4. Validate asset generation (images, fonts, etc.)
5. Test build artifacts (can they run?)
6. Check dependencies (no missing/broken deps)
7. Verify environment-specific builds (dev, staging, prod)
8. Validate Docker image builds (if containerized)

**Outputs**:
- Build artifacts (compiled code, bundles, Docker images)
- Build report (size, warnings, time)
- Build verification (smoke test of built artifacts)

**Handoff format**:
```markdown
## Handoff: Build → Review

**Feature**: F-0042 (User authentication)
**Build status**: SUCCESS ✅

**Build results**:
- TypeScript compilation: OK (0 errors)
- ESBuild bundle: 445kb (under 500kb threshold ✅)
- Docker image: built successfully (image: myapp:f-0042)
- Build time: 45 seconds
- Warnings: 0

**Artifacts**:
- dist/: Production build
- dist/client/: Client bundle (445kb)
- dist/server/: Server bundle (890kb)
- Docker image: myapp:f-0042 (185 MB)

**Smoke test**:
- ✅ Server starts (port 3000)
- ✅ Health check responds (200 OK)
- ✅ Auth endpoints registered (/api/auth/*)

**Context for Review Agent**:
- Build artifacts verified
- No build warnings or errors
- Bundle size within limits
- Ready for code review

**Next steps**: Code quality review, acceptance criteria verification
```

**Handoff format (if build fails)**:
```markdown
## Handoff: Build → Implementation (Rework)

**Feature**: F-0042 (User authentication)
**Build status**: FAILED ❌

**Build errors**:
1. TypeScript error: Cannot find module '@auth/core' (lib/auth/login.ts:5)
2. ESBuild error: Unresolved import 'zod' (components/LoginForm.tsx:12)
3. Bundle size: 620kb (exceeds 500kb threshold by 120kb)

**Required fixes**:
1. Add missing dependency: npm install @auth/core
2. Add missing dependency: npm install zod
3. Reduce bundle size (consider code splitting, lazy loading)

**Context for Implementation Agent**:
- Fix build errors above
- Re-run build
- Verify bundle size under threshold

**Next steps**: Fix errors, rebuild, re-submit for build verification
```

**Tools**: Build tools (tsc, webpack, esbuild, Docker), bundle analyzers, linters

---

### 6. Review Agent ✅

**When to invoke**: After build succeeds

**Context budget**: ~45K tokens

**Loads**:
- ✅ `spec/acceptance/F-####.md` (acceptance criteria - PRIMARY CHECKLIST)
- ✅ Implementation code
- ✅ Test files
- ✅ `.agentic/quality/review_checklist.md`
- ✅ `.agentic/workflows/definition_of_done.md`
- ✅ `spec/NFR.md` (if feature has NFR requirements)
- ❌ Research docs
- ❌ Planning docs

**Responsibilities**:
1. Verify **ALL** acceptance criteria met (AC1, AC2, ..., ACN)
2. Check code quality against `programming_standards.md`:
   - **Naming**: Clear, descriptive (not cryptic)
   - **Functions**: Small (<50 lines), focused, single purpose
   - **Error handling**: Explicit, specific error types
   - **No magic numbers**: Constants are named
   - **No deep nesting**: <4 levels
   - **No duplication**: DRY principle followed
   - **Type safety**: TypeScript types, Python hints present
   - **Organization**: Imports organized, no unused imports
3. Verify test coverage (`coverage.py`):
   - Unit tests: >80% ideal
   - Integration tests: Key boundaries covered
   - E2E tests: Critical flows covered
4. Check code annotations (`@feature`, `@acceptance`, `@nfr`)
5. Run quality checks (`quality_checks.sh --pre-commit`)
6. Security review (if applicable):
   - Input validation present
   - No secrets in code
   - Sensitive data handled properly
7. Performance check (if NFRs specify):
   - No obvious hot paths
   - Resource usage reasonable
8. Identify tech debt or refactoring opportunities
9. **Approve** OR **request changes**

**Outputs**:
- Review feedback (if changes needed)
- Approval to proceed (if all criteria met)
- Tech debt items logged (if any)

**Handoff format (if approved)**:
```markdown
## Handoff: Review → Spec Update

**Feature**: F-0042 (User authentication)
**Review status**: APPROVED ✅

**Review summary**:
✅ All acceptance criteria met (AC1-AC6 verified)
✅ Code quality: Good (clean, well-structured)
✅ Test coverage: 95% (excellent)
✅ Code annotations: Present and correct
✅ Security review: No issues found
✅ NFR-0002 (security): Compliant
✅ Quality checks: All passed

**Minor observations** (not blocking):
- Consider adding rate limiting to login endpoint (future NFR)
- Error messages could be more user-friendly (UX improvement for v2)

**Context for Spec Update Agent**:
- Feature: F-0042
- Status change: planned → shipped
- Release: v1.2.0 (next release)
- Tests: 19/19 passing, 95% coverage
- Implementation files: lib/auth/*, app/api/auth/*, components/LoginForm.tsx
- Lessons learned: Auth.js integration straightforward, session management well-documented

**Next steps**:
1. Update FEATURES.md (status, implementation, tests, lessons)
2. Update STATUS.md (move to release notes)
3. Add JOURNAL.md entry (session summary)
```

**Handoff format (if changes needed)**:
```markdown
## Handoff: Review → Implementation (Changes Requested)

**Feature**: F-0042 (User authentication)
**Review status**: Changes requested ❌

**Issues found**:
1. ❌ AC3 not fully met: Password reset flow missing (required by AC3)
2. ❌ Security issue: Passwords logged in error messages (NFR-0002 violation)
3. ⚠️  Test coverage: LoginForm only 60% covered (target: >80%)
4. ⚠️  Code quality: Error handling too generic (user feedback unclear)

**Required changes**:
1. **CRITICAL**: Remove password from error logs immediately (security)
2. **CRITICAL**: Implement password reset flow OR split AC3 into separate feature
3. **Important**: Add tests for LoginForm edge cases (empty input, network error, etc.)
4. **Nice-to-have**: Improve error messages for users

**Context for Implementation Agent**:
- Focus on: Issues 1-3 above (4 is optional)
- Don't change: Other parts are good (session management, API routes)
- Re-run: All tests after each fix
- Security: Priority #1 (issue 1)

**Estimated effort**: 2-3 hours

**Next steps**:
1. Fix security issue (remove password logging)
2. Discuss AC3 with human: split feature or implement now?
3. Add LoginForm tests
4. Re-submit for review
```

**Tools**: `doctor.py`, `verify.py`, `coverage.py`, `quality_checks.sh`

---

### 6. Spec Update Agent 📝

**When to invoke**: After review approval

**Context budget**: ~25K tokens

**Loads**:
- ✅ `spec/FEATURES.md`
- ✅ `STATUS.md`
- ✅ `JOURNAL.md`
- ✅ Implementation summary (from Review Agent handoff)
- ❌ Implementation code (just needs summary)
- ❌ Tests (just needs coverage numbers)
- ❌ Research docs

**Responsibilities**:
1. Update `spec/FEATURES.md`:
   - Status: planned → shipped (or in_progress → shipped)
   - Implementation: State = complete, Code = [files], Release = vX.Y.Z
   - Tests: Mark all test types complete
   - Verification: Accepted = yes, Accepted at = [date]
   - Lessons/caveats: Document any discoveries/gotchas
2. Update `STATUS.md`:
   - Move feature from "In progress" to completion
   - Update "Current focus" if this was current
   - Add to "Release notes" section
3. Add `JOURNAL.md` entry:
   - Session summary
   - Tests added, files changed
   - Blockers resolved, lessons learned

**Outputs**:
- Updated `FEATURES.md` (feature marked shipped)
- Updated `STATUS.md` (reflects current state)
- New `JOURNAL.md` entry (session log)

**Handoff format**:
```markdown
## Handoff: Spec Update → Documentation

**Feature**: F-0042 (User authentication)
**Specs updated**: FEATURES.md, STATUS.md, JOURNAL.md

**Changes made**:
- FEATURES.md:
  - F-0042 status: planned → shipped
  - Implementation state: complete
  - Release: v1.2.0
  - Tests: unit/integration/e2e all complete
  - Lessons: "Auth.js integration straightforward, well-documented"
- STATUS.md:
  - Moved F-0042 to release notes (v1.2.0)
  - Updated "Current focus" to F-0043
- JOURNAL.md:
  - Added session entry documenting completion
  - Noted 19 tests added, 95% coverage achieved

**Context for Documentation Agent**:
- Feature: F-0042 (user authentication)
- User-facing: YES (login UI, public API)
- Documentation needed:
  - API docs: POST /api/auth/login, POST /api/auth/logout, GET /api/auth/session
  - User guide: "How to log in" section
  - Architecture: Auth flow diagram (login → validate → create session → return token)

**Docs to update**:
1. docs/api/auth.md (add new endpoints)
2. docs/user-guide.md (add login instructions)
3. docs/architecture/diagrams/auth-flow.md (create Mermaid diagram)
4. README.md (update "Features" section)

**Next steps**:
1. Document API endpoints (parameters, responses, errors)
2. Write user-facing login guide
3. Create architecture diagram
4. Update README features list
```

**Tools**: `verify.py`, `doctor.py`

---

### 7. Documentation Agent 📚

**When to invoke**: For user-facing features, public APIs, architecture changes

**Context budget**: ~35K tokens

**Loads**:
- ✅ `spec/FEATURES.md` (what was implemented)
- ✅ `spec/TECH_SPEC.md` (architecture)
- ✅ Implementation code (to understand behavior/API)
- ✅ `docs/` directory (existing documentation)
- ❌ Research docs
- ❌ Tests
- ❌ JOURNAL.md

**Responsibilities**:
1. Update user-facing docs (`docs/README.md`, user guides)
2. Update API documentation:
   - Endpoints, parameters, responses
   - Error codes
   - Examples
3. Update architecture docs if design changed
4. Create/update diagrams (Mermaid for flows/architecture)
5. Update troubleshooting guides if error handling added
6. Update runbooks if operational changes
7. Update README.md if major feature
8. Ensure examples are current and working

**Outputs**:
- Updated documentation in `docs/`
- Updated `README.md` (if needed)
- Architecture diagrams (if structure changed)

**Handoff format**:
```markdown
## Handoff: Documentation → Git

**Feature**: F-0042 (User authentication)
**Documentation complete**: All user-facing docs updated

**Changes made**:
1. docs/api/auth.md:
   - Added POST /api/auth/login (params, response, errors)
   - Added POST /api/auth/logout
   - Added GET /api/auth/session
   - Added code examples (curl, JavaScript, TypeScript)

2. docs/user-guide.md:
   - Added "Logging In" section
   - Added screenshots of login form
   - Added troubleshooting (common errors)

3. docs/architecture/diagrams/auth-flow.md:
   - Created Mermaid diagram (user → LoginForm → API → Auth.js → session)

4. README.md:
   - Updated "Features" section (added authentication)
   - Updated quick start (mention login requirement)

**All work complete**: Ready for commit ✅

**Context for Git Agent**:
- Feature: F-0042
- Changed files: 15 total
  - Code: 4 files
  - Tests: 3 files
  - Specs: 5 files
  - Docs: 3 files
- Git workflow: PR mode (from STACK.md)
- Branch: feature/F-0042
- Target: main

**Commit message suggestion**:
```
feat: implement user authentication (F-0042)

- Add OAuth 2.0 login via Auth.js
- Support email/password and social auth (Google, GitHub)
- Implement session management with secure HTTP-only cookies
- Add login UI component with form validation
- Add comprehensive tests (unit, integration, E2E) - 19 tests, 95% coverage

Closes F-0042
```

**Next steps**:
1. Show changes to human
2. Get approval
3. Run pre-commit checks
4. Commit and create PR
5. Push to remote
```

**Tools**: `sync_docs.py`, `arch_diff.sh`

---

### 8. Git Agent 🚀

**When to invoke**: When all work complete and ready to commit

**Context budget**: ~20K tokens

**Loads**:
- ✅ All changed files (for showing human)
- ✅ `STACK.md` (git_workflow setting: direct or pull_request)
- ✅ `.agentic/workflows/git_workflow.md` (protocol)
- ✅ `JOURNAL.md` last entry (for commit message context)
- ❌ Research docs
- ❌ Most other specs

**Responsibilities**:
1. **CRITICAL**: Show all changes to human (NEVER auto-commit!)
2. Wait for **explicit human approval** ("commit", "looks good", "yes")
3. Create conventional commit message (feat/fix/docs/etc)
4. Run pre-commit checks (`quality_checks.sh --pre-commit`)
5. Commit with clear, semantic message
6. Create PR if `git_workflow: pull_request`
7. Push to remote (after human approval)
8. Clean up feature branch (if merged)

**Outputs**:
- Git commit
- PR (if PR workflow)
- Updated remote branch

**Protocol**:
```markdown
## Git Agent: Ready to Commit

**Feature**: F-0042 (User authentication)

### Changed Files (15)

**Code** (4 files):
- lib/auth/login.ts (new, 120 lines)
- lib/auth/session.ts (new, 85 lines)
- app/api/auth/[...nextauth]/route.ts (new, 95 lines)
- components/LoginForm.tsx (new, 150 lines)

**Tests** (3 files):
- __tests__/auth/login.test.ts (new, 180 lines)
- __tests__/auth/session.test.ts (new, 95 lines)
- e2e/auth/login.spec.ts (new, 75 lines)

**Specs** (5 files):
- spec/FEATURES.md (updated, +45 lines)
- spec/acceptance/F-0042.md (new, 120 lines)
- spec/adr/ADR-0005-auth-strategy.md (new, 95 lines)
- STATUS.md (updated, +15 lines)
- JOURNAL.md (updated, +25 lines)

**Docs** (3 files):
- docs/api/auth.md (updated, +180 lines)
- docs/user-guide.md (updated, +75 lines)
- docs/architecture/diagrams/auth-flow.md (new, 50 lines)

**Total**: +1,405 lines, -0 lines

### Pre-commit Checks

✅ TypeScript compilation: OK
✅ ESLint: 0 errors, 0 warnings
✅ Tests: 19/19 passing
✅ Bundle size: 445kb (under 500kb threshold)
✅ Lighthouse (simulated): Performance 91, A11y 96

### Proposed Commit Message

```
feat: implement user authentication (F-0042)

- Add OAuth 2.0 login via Auth.js (NextAuth)
- Support email/password and social auth (Google, GitHub)
- Implement session management with secure HTTP-only cookies
- Add LoginForm component with validation and error handling
- Add comprehensive test coverage (unit, integration, E2E)

Tests: 19 tests added, 95% coverage
ADR-0005: Chose Auth.js for Next.js integration

Closes F-0042
```

### Git Workflow (from STACK.md)

- Mode: `pull_request` (create PR for human review)
- Branch: `feature/F-0042` (create from main)
- Target: `main`
- Draft: Yes (initial PR state)
- Reviewers: [] (none specified in STACK.md)

### Actions Awaiting Human Approval

1. **Commit** changes with message above
2. **Push** feature branch to remote
3. **Create PR** from feature/F-0042 → main
4. **Assign reviewers** (or leave for human)

---

**Waiting for human approval...**

[Human types: "looks good, commit and create PR"]

✅ Committing...
✅ Pushing to remote...
✅ Creating PR #42...
✅ PR created: https://github.com/user/repo/pull/42

**PR Details**:
- Title: "feat: implement user authentication (F-0042)"
- Status: Draft
- Checks: Running (CI will run tests, linting, build)
- Ready for: Human review when checks pass

**Next steps for human**:
1. Wait for CI checks to pass
2. Review PR diffs on GitHub
3. Mark as "Ready for review" when satisfied
4. Merge when approved
```

**Tools**: Git commands, `quality_checks.sh`, `git_workflow.md`

---

## Context Optimization: Token Budget Summary

| Agent | Budget | Load | Skip | Efficiency |
|-------|--------|------|------|------------|
| Research | ~30K | STACK, PRD, REFERENCES, research docs | Code, tests, JOURNAL | High (focused on refs) |
| Planning | ~40K | Research results, PRD, TECH_SPEC, FEATURES, NFR | Code, tests | High (specs only) |
| Test | ~35K | Acceptance, FEATURES, test patterns | Research, most specs | High (test-focused) |
| Implementation | ~50K | Tests (TDD), acceptance, architecture, related code | Research, planning | Medium (needs code context) |
| Review | ~45K | Acceptance, implementation, tests, checklists | Research, planning | Medium (review context) |
| Spec Update | ~25K | FEATURES, STATUS, JOURNAL | Code, tests, research | Very high (docs only) |
| Documentation | ~35K | FEATURES, TECH_SPEC, implementation, docs | Research, tests | High (doc-focused) |
| Git | ~20K | Changed files, workflow, JOURNAL | Most other docs | Very high (minimal context) |

**Total sequential**: ~345K tokens across 10 agents (8 core + Build + Deploy)  
**Per agent**: <50K tokens (67% reduction vs general agent)  
**General-purpose agent**: 150-200K tokens minimum, lower quality

---

## Handoff File Format

For complex handoffs, create `..agentic/handoff/F-####-[from]-to-[to].md`:

```markdown
# Handoff: F-0042 Research → Planning

## Summary
Research on authentication strategies complete. Recommendation: Auth.js.

## Key Findings
1. OAuth 2.0 + JWT industry standard
2. Auth.js best for Next.js (v13+ App Router)
3. Security considerations documented

## Context for Next Agent (Planning)

### Must Read
- docs/research/auth-strategies-2026-01-02.md (Recommendation section)
- spec/PRD.md (R-0042: Secure login, R-0043: Social auth)
- spec/NFR.md (NFR-0002: Security requirements)

### Must Create
- Feature F-0042 in FEATURES.md (status: planned)
- Acceptance criteria: spec/acceptance/F-0042.md
- ADR-0005: Document Auth.js decision

### Dependencies
- None (new feature, no blockers)

### Complexity Estimate
Medium (M) - 3-5 days
- OAuth provider setup required
- Integration with existing user model
- Session management complexity

## Decisions Made
1. Auth strategy: OAuth 2.0 (industry standard)
2. Library: Auth.js v5 (Next.js optimized)
3. Session: Secure HTTP-only cookies (not localStorage)

## Open Questions for Planning Agent
1. Social providers: Which ones? (Google, GitHub, both, more?)
2. Email/password: Also support, or OAuth-only?
3. MFA: In scope for v1.0 or defer to v1.1?
4. Password reset: Part of F-0042 or separate feature?

## Risks / Watch Out For
- Session security: MUST use HTTPS in production
- OAuth callback URLs: Need proper .env configuration
- Rate limiting: Consider for login endpoint (prevent brute force)
- CSRF protection: Auth.js handles this, verify configuration

## Estimated Token Budget for Next Agent
~40K tokens:
- Research doc: ~5K
- PRD (relevant sections): ~3K
- TECH_SPEC (auth section): ~5K
- FEATURES.md: ~8K
- NFR.md: ~4K
- Existing auth code (for reference): ~10K
- Buffer: ~5K
```

---

## Additional Specialist Agents

### 9. Debugging Agent 🐛

**When to invoke**: Bug reports, failing tests, production issues

**Context**: Bug description, failing tests, related code, error logs

**Handoff to**: Review Agent (after fix)

---

### 11. Refactoring Agent ♻️

**When to invoke**: Code quality improvements, tech debt resolution

**Context**: Code to refactor, tests (must pass before/after), FEATURES.md

**Handoff to**: Review Agent

---

### 12. Security Agent 🔒

**When to invoke**: Security-sensitive features (auth, data handling, encryption)

**Context**: Implementation, security best practices, NFR security requirements

**Handoff to**: Human (for decisions) OR Spec Update Agent (if approved)

---

### 13. Performance Agent ⚡

**When to invoke**: Performance-critical features, optimization needs

**Context**: Implementation, profiling results, NFR performance requirements

**Handoff to**: Review Agent

---

## Orchestration Options

### Option 1: Human Orchestration (Recommended)

Human explicitly invokes each agent:

```
Human: "Research Agent: investigate Next.js 15 auth options for F-0042"
[Research Agent completes, creates handoff]
