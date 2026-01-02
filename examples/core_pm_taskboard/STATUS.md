# STATUS.md

Purpose: current focus, roadmap, known issues. Machine + human readable.

## Current focus

**Sprint**: Foundation (Week 1-2)
**Goal**: Get basic task CRUD working with persistent storage

**Active work**:
- F-0001: Task CRUD operations (in progress, 70% complete)
- F-0002: Local storage persistence (in progress, 50% complete)

**Next up** (this week):
- F-0003: Task filtering by status
- F-0004: Drag-and-drop task reordering

## Roadmap

### Phase 1: MVP (Weeks 1-3) 🏗️
- F-0001: Task CRUD operations
- F-0002: Local storage persistence
- F-0003: Task filtering by status
- F-0004: Drag-and-drop reordering

### Phase 2: Polish (Weeks 4-5)
- F-0005: Dark mode support
- F-0006: Keyboard shortcuts
- F-0007: Task search

### Phase 3: Future
- Export/import tasks (future consideration)
- Cloud sync (if needed)

## Known issues

- None yet (MVP phase)

## Recent decisions

- Using localStorage for MVP (simpler than IndexedDB)
- Next.js 15 with App Router (latest stable)
- Tailwind for styling (fast iteration)
- No backend for MVP (client-side only)

## Metrics

- Features planned: 7
- Features shipped: 0
- In progress: 2
- Test coverage: 85% (target: 80%+)

---

**Last updated**: 2026-01-02
