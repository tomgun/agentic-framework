# FEATURES

Purpose: a **human + machine** readable registry of features with stable IDs, status, acceptance criteria, and test coverage notes.

## Status vocabulary
- `planned` | `in_progress` | `shipped` | `deprecated`

## Feature index
- F-0001: Task CRUD operations
- F-0002: localStorage persistence
- F-0003: Task filtering
- F-0004: Drag-and-drop reordering
- F-0005: Dark mode
- F-0006: Keyboard shortcuts
- F-0007: Task search

---

## F-0001: Task CRUD operations
- Parent: none
- Dependencies: none
- Complexity: M
- Status: in_progress
- PRD: spec/PRD.md#requirements
- Requirements: R-0001, R-0003
- NFRs: NFR-0001 (performance)
- Acceptance: spec/acceptance/F-0001.md
- Verification:
  - Accepted: no
  - Accepted at:
- Implementation:
  - State: partial
  - Code: app/components/TaskCard.tsx, app/hooks/useTasks.ts
- Tests:
  - Test strategy: unit + integration
  - Unit: partial (60%)
  - Integration: todo
  - Acceptance: todo
  - Perf/realtime: n/a
- Technical debt:
  - none yet
- Lessons/caveats:
  - none yet
- Notes:
  - Using Zustand for state management
  - Task IDs are UUIDs for uniqueness

---

## F-0002: localStorage persistence
- Parent: none
- Dependencies: F-0001 (partial) - needs task model defined
- Complexity: S
- Status: in_progress
- PRD: spec/PRD.md#requirements
- Requirements: R-0004
- NFRs: NFR-0002 (reliability)
- Acceptance: spec/acceptance/F-0002.md
- Verification:
  - Accepted: no
  - Accepted at:
- Implementation:
  - State: partial
  - Code: app/lib/storage.ts
- Tests:
  - Test strategy: unit + integration
  - Unit: partial (50%)
  - Integration: todo
  - Acceptance: todo
  - Perf/realtime: n/a
- Technical debt:
  - none yet
- Lessons/caveats:
  - Using JSON.stringify/parse with error handling
- Notes:
  - Atomic writes to prevent corruption

---

## F-0003: Task filtering
- Parent: none
- Dependencies: F-0001 (complete) - needs task list to exist
- Complexity: S
- Status: planned
- PRD: spec/PRD.md#requirements
- Requirements: R-0005
- NFRs: NFR-0001 (performance)
- Acceptance: spec/acceptance/F-0003.md
- Verification:
  - Accepted: no
  - Accepted at:
- Implementation:
  - State: none
  - Code:
- Tests:
  - Test strategy: unit
  - Unit: todo
  - Integration: n/a
  - Acceptance: todo
  - Perf/realtime: n/a
- Technical debt:
  - none yet
- Lessons/caveats:
  - none yet
- Notes:
  - Filter by: To Do, In Progress, Done, All

---

## F-0004: Drag-and-drop reordering
- Parent: none
- Dependencies: F-0001 (complete) - needs task list UI
- Complexity: M
- Status: planned
- PRD: spec/PRD.md#requirements
- Requirements: R-0002
- NFRs: NFR-0001 (performance - smooth animations)
- Acceptance: spec/acceptance/F-0004.md
- Verification:
  - Accepted: no
  - Accepted at:
- Implementation:
  - State: none
  - Code:
- Tests:
  - Test strategy: integration + manual
  - Unit: n/a
  - Integration: todo
  - Acceptance: todo
  - Perf/realtime: n/a
- Technical debt:
  - none yet
- Lessons/caveats:
  - Consider @dnd-kit or react-beautiful-dnd
- Notes:
  - Need smooth animations (no jank)
  - Touch support for mobile

---

## F-0005: Dark mode
- Parent: none
- Dependencies: none (can be added anytime)
- Complexity: S
- Status: planned
- PRD: spec/PRD.md (Phase 2)
- Requirements: none (nice-to-have)
- NFRs: none
- Acceptance: spec/acceptance/F-0005.md
- Verification:
  - Accepted: no
  - Accepted at:
- Implementation:
  - State: none
  - Code:
- Tests:
  - Test strategy: manual + visual
  - Unit: n/a
  - Integration: n/a
  - Acceptance: todo
  - Perf/realtime: n/a
- Technical debt:
  - none yet
- Lessons/caveats:
  - Use Tailwind dark: variant
- Notes:
  - Respect system preference, allow toggle

---

## F-0006: Keyboard shortcuts
- Parent: none
- Dependencies: F-0001 (complete) - needs actions to trigger
- Complexity: S
- Status: planned
- PRD: spec/PRD.md (Phase 2)
- Requirements: none (nice-to-have)
- NFRs: NFR-0001 (instant response)
- Acceptance: spec/acceptance/F-0006.md
- Verification:
  - Accepted: no
  - Accepted at:
- Implementation:
  - State: none
  - Code:
- Tests:
  - Test strategy: integration
  - Unit: todo
  - Integration: todo
  - Acceptance: todo
  - Perf/realtime: n/a
- Technical debt:
  - none yet
- Lessons/caveats:
  - Document shortcuts in UI (help dialog?)
- Notes:
  - n: new task, d: delete, e: edit, /: search

---

## F-0007: Task search
- Parent: none
- Dependencies: F-0001 (complete) - needs task data
- Complexity: S
- Status: planned
- PRD: spec/PRD.md (Phase 2)
- Requirements: R-0005
- NFRs: NFR-0001 (fast search)
- Acceptance: spec/acceptance/F-0007.md
- Verification:
  - Accepted: no
  - Accepted at:
- Implementation:
  - State: none
  - Code:
- Tests:
  - Test strategy: unit + integration
  - Unit: todo
  - Integration: todo
  - Acceptance: todo
  - Perf/realtime: n/a
- Technical debt:
  - none yet
- Lessons/caveats:
  - Simple string match for MVP (no fuzzy search)
- Notes:
  - Search by title and description
