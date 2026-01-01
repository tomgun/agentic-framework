# STATUS.md

## Current focus
- v1.3.0 development
- Optimizing Server Components (F-0007)
- Adding per-page metadata (F-0008)

## In progress
- F-0007: Server Component optimization (reduce bundle by ~50kb)
- F-0008: Per-page metadata for SEO

## Next up
- F-0009: Virtualization for large task lists (>100 tasks)
- Action item A-006: Research virtualization libraries (react-window)

## Roadmap (lightweight)

### v1.3.0 (current sprint)
- F-0007: Server Component optimization ✅ In progress
- F-0008: Per-page metadata ✅ In progress

### v1.4.0 (planned)
- F-0009: Virtualization for large lists
- F-0010: Multi-tab synchronization

### v2.0.0 (future)
- F-0011: Dark mode
- F-0012: Keyboard shortcuts
- F-0013: Task categories/tags

## Known issues / risks
- **Performance degradation >100 tasks**: Needs virtualization (F-0009)
- **Bundle size**: 445kb (under threshold, but monitor closely)
- **Field update due**: Next.js 15.2 released, need research session

## Decisions needed
- **Virtualization library**: react-window vs react-virtual? (see A-006)
- **Multi-tab sync**: Should we upgrade to BroadcastChannel API? (F-0010)

## Quality metrics (latest)
- **Tests**: 92% coverage (unit + integration + E2E)
- **Bundle size**: 445kb (threshold: 500kb) ✅
- **Lighthouse**:
  - Performance: 91 ✅
  - Accessibility: 96 ✅
  - SEO: 88 (⚠️ will improve with F-0008)
- **Known bugs**: 0 critical, 1 minor (large list performance)

## Recent retrospectives
- **2025-12-30**: First retro (v1.0.0) - improved accessibility, added E2E tests
- **2026-01-13**: Second retro (v1.1.0, v1.2.0) - bundle monitoring, PR workflow

**Next retrospective**: 2026-01-27 OR after F-0007→F-0011 (5 features)

## Action items from last retro (2026-01-13)
- A-005: Research bundle optimization ⏳ In progress (F-0007)
- A-006: Research virtualization 📋 Planned
- A-007: Next.js 15.2 field update 📋 Planned (overdue)
- A-008: Bundle size breakdown to quality checks ✅ Complete

## Release notes

### v1.2.0 (2026-01-12)
- F-0006: E2E test infrastructure (Playwright)
- ADR-0003: Playwright for E2E testing
- Quality: Added Lighthouse CI, a11y linting

### v1.1.0 (2026-01-08)
- F-0004: Filter tasks (all/active/completed)
- F-0005: Delete tasks
- ADR-0001: Zustand for state management
- ADR-0002: Tailwind CSS for styling
- Quality: Accessibility improvements (88→96)

### v1.0.0 (2025-12-20)
- F-0001: Add tasks
- F-0002: List tasks
- F-0003: Complete tasks
- Initial release

## Team notes
- PR workflow adopted (2026-01-06): All features now go through pull requests
- Context7 enabled (2026-01-10): Prevents API version mismatches
- TDD mode default: All new features start with tests
