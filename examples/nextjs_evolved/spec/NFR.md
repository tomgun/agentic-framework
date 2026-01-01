# Non-Functional Requirements

## NFR-0001: Performance
- **Requirement**: Fast response for task operations
- **Metric**: <100ms for operations on <1000 tasks
- **Affected features**: F-0001, F-0002, F-0003, F-0004, F-0007
- **Verification**: Manual testing + Lighthouse performance score >90
- **Status**: met (Lighthouse: 91)

## NFR-0002: Data integrity
- **Requirement**: Tasks must not be lost or corrupted
- **Metric**: 100% persistence reliability for successful operations
- **Affected features**: F-0001, F-0005, F-0010
- **Verification**: Unit tests for Zustand persistence, E2E tests
- **Status**: met (ADR-0001 resolved localStorage issues)

## NFR-0003: Accessibility
- **Requirement**: WCAG 2.1 AA compliance
- **Metric**: Lighthouse accessibility score >95
- **Affected features**: F-0001, F-0002, F-0003, F-0011
- **Verification**: Lighthouse CI, eslint-plugin-jsx-a11y
- **Status**: met (Lighthouse: 96, improved from 88 in RETRO-2025-12-30)

## NFR-0004: Quality automation
- **Requirement**: Automated quality gates prevent regressions
- **Metric**: All checks passing before commit
- **Affected features**: F-0006 (E2E infrastructure)
- **Verification**: quality_checks.sh execution, CI passing
- **Status**: met (pre-commit + full suite in place)

## NFR-0005: Bundle size
- **Requirement**: Keep bundle small for fast loading
- **Metric**: <500kb production bundle
- **Affected features**: F-0007 (Server Component optimization)
- **Verification**: Bundle size check in quality_checks.sh
- **Status**: met (445kb, under threshold)

## NFR-0006: SEO
- **Requirement**: Good search engine visibility
- **Metric**: Lighthouse SEO score >85
- **Affected features**: F-0008 (per-page metadata)
- **Verification**: Lighthouse CI
- **Status**: acceptable (88, will improve with F-0008)
