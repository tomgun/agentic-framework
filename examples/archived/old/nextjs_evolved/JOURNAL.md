# JOURNAL.md

## 2026-01-15 10:30 - Server Component Optimization (Session 12)

**Feature**: F-0007 (Server Component optimization)

**What was done:**
- Started refactoring TaskList to Server Component
- Identified client/server boundary (TaskRow still needs interactivity)
- Researched React 19 Server Component patterns

**Tests added:**
- None yet (in progress)

**What's next:**
- Complete TaskList refactor
- Run bundle analysis
- Measure performance improvement

**Blockers:**
- None

**Lessons:**
- Server Component boundary placement critical for performance
- Bundle analyzer invaluable for tracking progress

---

## 2026-01-13 14:00 - Second Retrospective (Session 11)

**Feature**: N/A (Retrospective)

**What was done:**
- Completed RETRO-2026-01-13
- Reviewed progress since v1.0.0
- Identified bundle size growth issue
- Set action items for next sprint

**Tests added:**
- N/A

**What's next:**
- F-0007: Server Component optimization (A-005)
- Research virtualization (A-006)
- Field update for Next.js 15.2 (A-007)

**Blockers:**
- None

**Lessons:**
- Retrospectives catching issues early (bundle size growth)
- Action item completion rate excellent (4/4 from first retro)
- PR workflow overhead minimal, worth quality improvement

---

## 2026-01-11 11:00 - E2E Test Infrastructure Complete (Session 10)

**Feature**: F-0006 (E2E test infrastructure)

**What was done:**
- Configured Playwright
- Created 5 E2E tests (add, list, complete, filter, delete)
- Integrated into CI
- Updated quality_checks.sh

**Tests added:**
- `e2e/add-task.spec.ts`
- `e2e/complete-task.spec.ts`
- `e2e/filter-tasks.spec.ts`
- `e2e/delete-task.spec.ts`
- `e2e/task-flow.spec.ts` (full user journey)

**What's next:**
- Ship v1.2.0
- Second retrospective

**Blockers:**
- None

**Lessons:**
- Playwright codegen saved ~2 hours
- Found 1 bug immediately (Enter key submission)
- E2E tests give great confidence for refactoring

---

## 2026-01-10 15:30 - Research: Testing Strategies (Session 9)

**Feature**: Research (action item A-002)

**What was done:**
- Compared Playwright vs Cypress vs Testing Library
- Created docs/research/testing-strategies.md
- Decided on Playwright
- Created ADR-0003

**Tests added:**
- N/A (research session)

**What's next:**
- F-0006: Set up Playwright infrastructure

**Blockers:**
- None

**Lessons:**
- Research sessions critical for informed decisions
- 60 minutes well spent (prevented wrong choice)
- Documentation trail valuable for future reference

---

## 2026-01-09 16:00 - Delete Tasks Complete (Session 8)

**Feature**: F-0005 (Delete tasks)

**What was done:**
- Added delete button to TaskRow
- Confirmation dialog (prevent accidents)
- Fade-out animation
- Tests passing (unit + integration)

**Tests added:**
- `__tests__/TaskRow.test.tsx::delete task`
- `__tests__/integration/delete-flow.test.tsx`

**What's next:**
- Ship v1.1.0
- Action item A-002: Research E2E testing

**Blockers:**
- None

**Lessons:**
- Confirmation dialog UX critical (prevent accidental deletes)
- Animation polish matters

---

## 2026-01-07 10:00 - Filter Tasks Complete (Session 7)

**Feature**: F-0004 (Filter tasks)

**What was done:**
- Created TaskFilter component (all/active/completed)
- Extended Zustand store with filter state
- Persisted filter choice to localStorage
- Tests passing

**Tests added:**
- `__tests__/TaskFilter.test.tsx`
- `__tests__/integration/filter-flow.test.tsx`

**What's next:**
- F-0005: Delete tasks

**Blockers:**
- None

**Lessons:**
- Zustand (ADR-0001) made filtering trivial
- TDD catching edge cases early

---

## 2026-01-06 14:00 - ADR-0002: Tailwind CSS (Session 6)

**Feature**: ADR-0002 (Architectural decision)

**What was done:**
- Decided to adopt Tailwind CSS
- Created ADR-0002 with rationale
- Installed Tailwind, configured
- Migrated TaskForm to Tailwind (pilot)

**Tests added:**
- None (styling change, no behavior change)

**What's next:**
- Gradually migrate all components
- Remove CSS Modules once complete

**Blockers:**
- None

**Lessons:**
- Gradual migration strategy reduces risk
- Tailwind autocomplete saves time

---

## 2026-01-05 09:00 - ADR-0001: Zustand State Management (Session 5)

**Feature**: ADR-0001 (Tech debt resolution)

**What was done:**
- Researched state management options
- Decided on Zustand
- Created ADR-0001 with rationale
- Refactored all components to use Zustand store
- Resolved localStorage race conditions

**Tests added:**
- `__tests__/store.test.ts` (Zustand store tests)
- Updated all component tests

**What's next:**
- ADR-0002: Styling (Tailwind CSS)

**Blockers:**
- None

**Lessons:**
- ADRs document "why" not just "what"
- Zustand migration smooth (~2 hours)
- Tech debt tackled early pays off

---

## 2025-12-30 16:00 - First Retrospective (Session 4)

**Feature**: N/A (Retrospective)

**What was done:**
- Completed RETRO-2025-12-30
- Identified 3 improvement areas
- Created 4 action items
- Documented lessons learned

**Tests added:**
- N/A

**What's next:**
- A-001: Fix accessibility issues
- A-002: Research E2E testing (Playwright)
- A-003: Create ADR-0001 (state management)
- A-004: Add a11y linting

**Blockers:**
- None

**Lessons:**
- Retrospectives after first release valuable
- Metrics (Lighthouse, bundle) guide improvements
- TDD workflow effective, continue using

---

## 2025-12-20 14:00 - v1.0.0 Release (Session 3)

**Feature**: F-0001, F-0002, F-0003 (all shipped!)

**What was done:**
- Completed all 3 core features
- All acceptance criteria met
- Tests passing (85% coverage)
- Deployed to Vercel

**Tests added:**
- All unit tests complete
- Integration tests for user flows

**What's next:**
- First retrospective (scheduled 2025-12-30)
- F-0004: Filter tasks

**Blockers:**
- None

**Lessons:**
- TDD workflow: green from day 1
- localStorage simple but has limitations (tech debt noted)
- Next.js App Router learning curve steep but worthwhile

---

## 2025-12-18 10:00 - Complete Tasks (Session 2)

**Feature**: F-0003 (Complete tasks)

**What was done:**
- Added checkbox to TaskRow
- Toggle completion state
- Visual feedback (strikethrough, opacity)
- Tests passing (TDD)

**Tests added:**
- `__tests__/TaskRow.test.tsx::complete task`
- `__tests__/TaskRow.test.tsx::toggle twice`

**What's next:**
- Ship v1.0.0 (all 3 features complete!)

**Blockers:**
- None

**Lessons:**
- Keyboard accessibility (Space/Enter) critical
- Test interactions, not implementation

---

## 2025-12-16 14:00 - List Tasks (Session 1 continued)

**Feature**: F-0002 (List tasks)

**What was done:**
- Created TaskList component
- Created TaskRow component
- Loaded tasks from localStorage
- Empty state handling
- Tests passing (TDD)

**Tests added:**
- `__tests__/TaskList.test.tsx::renders tasks`
- `__tests__/TaskList.test.tsx::empty state`

**What's next:**
- F-0003: Complete tasks

**Blockers:**
- None

**Lessons:**
- Component composition (List → Row) working well
- Empty states important for UX

---

## 2025-12-15 09:00 - Project Initialization + Add Tasks (Session 1)

**Feature**: F-0001 (Add tasks)

**What was done:**
- Initialized project with Next.js 15.1, React 19
- Created TaskForm component
- Implemented add task with localStorage
- TDD: Tests written first
- All tests passing

**Tests added:**
- `__tests__/TaskForm.test.tsx::add task`
- `__tests__/TaskForm.test.tsx::clear form`
- `__tests__/TaskForm.test.tsx::validation`

**What's next:**
- F-0002: List tasks

**Blockers:**
- None

**Lessons:**
- TDD workflow effective (tests guide design)
- localStorage simple for demo (may need upgrade later)
- Next.js App Router: "use client" required for interactivity
