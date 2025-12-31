# CONTEXT_PACK.md

Quick intent: a compact starting point for **agents + humans**. Read this first to avoid re-scanning the repo.

Purpose: a compact, durable starting point so you don’t need to reread the whole repo.

## One-minute overview
- What this repo is: an example initialized project demonstrating the `agentic/` framework with a Next.js Todo app.
- Main user workflow:
  - add a todo
  - toggle it done/undone
  - (next) filter + persistence
- Current top priorities:
  - implement F-0004 persistence (localStorage)
  - implement F-0005 filters

## Where to look first (map)
- Entry points:
  - `app/page.tsx` (UI)
  - `lib/todo.ts` (domain logic)
- Core modules:
  - `lib/todo.ts` for pure logic (unit-tested)
- Specs: `/spec/`
- Features: `spec/FEATURES.md`
- Overview: `spec/OVERVIEW.md`
- Non-functional requirements: `spec/NFR.md`
- Lessons: `spec/LESSONS.md`
- Decisions: `spec/adr/`
- Status: `STATUS.md`

## How to run
- Setup: `npm install`
- Run: `npm run dev`
- Test: `npm test`

## Architecture snapshot
- Components:
  - Next.js app (UI)
  - Domain logic (`lib/todo.ts`)
- Data flow:
  - UI holds state in React for now
  - actions call pure domain functions
- External dependencies: none (local-only)

## Quality gates (current)
- Unit tests required: yes
- Definition of Done: see `agentic/workflows/definition_of_done.md`
- Review checklist: see `agentic/quality/review_checklist.md`

## Known risks / sharp edges
- `addTodo` uses `Date.now()` for ids; good enough for demo, but not stable across devices.


