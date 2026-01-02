# PRD

Purpose: define *why* we're building this and *what* success means.

## Summary
- Problem (1–2 sentences): Developers need a simple, local-first task board for organizing work. Existing tools are too complex or require accounts/servers.
- Target user: Solo developers, small teams who want a quick task board without setup
- Primary workflow: Create tasks, move them between To Do/In Progress/Done columns, drag to reorder

## Goals (measurable)
- G1: Launch MVP in 3 weeks with basic task management
- G2: 100% local (no backend required)
- G3: Fast (<100ms interactions, instant load)
- G4: Works offline (PWA-ready)

## Non-goals (explicit)
- NG1: No team collaboration (single user for MVP)
- NG2: No cloud sync (local storage only)
- NG3: No mobile app (web only, but mobile-responsive)
- NG4: No complex project management features (no sprints, burndown charts, etc.)

## Terminology (requirement vs feature)
In this framework, **Features (F-####)** are the canonical unit we plan/ship/test (`spec/FEATURES.md`).

## Requirements (user-facing)
- R-0001: User can create tasks with title and description
- R-0002: User can move tasks between To Do, In Progress, Done
- R-0003: User can edit and delete tasks
- R-0004: Tasks persist across browser sessions
- R-0005: User can filter by status or search by title

## Acceptance criteria (high-level)
- AC1: All CRUD operations work without page refresh
- AC2: Data persists after closing browser
- AC3: Drag-and-drop is smooth and responsive
- AC4: Works in Chrome, Firefox, Safari

## Feature mapping (IDs)
- Feature registry: `spec/FEATURES.md`
- Map requirements to features:
  - R-0001 -> F-0001
  - R-0002 -> F-0004
  - R-0003 -> F-0001
  - R-0004 -> F-0002
  - R-0005 -> F-0003, F-0007

## Risks & open questions
- Risk: localStorage has 5-10MB limit (unlikely to hit with task data)
- Risk: No conflict resolution if user opens in multiple tabs
- Question: Should we add categories/tags in MVP?

## Release plan (thin)
- Milestone 1 (Week 3): MVP with CRUD, persistence, filtering
- Milestone 2 (Week 5): Polish (dark mode, shortcuts, search)
