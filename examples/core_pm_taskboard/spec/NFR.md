# NFR (Non-Functional Requirements)

Purpose: capture cross-cutting constraints that apply across many features (performance, security, realtime safety, reliability, etc.) in a stable, referenceable way.

---

## NFR-0001: Performance budget
- Category: performance
- Statement: All user interactions complete in <100ms, page load <1s
- Applies to: All features (F-0001 through F-0007)
- How to measure:
  - Chrome DevTools Lighthouse score >90
  - Manual testing with network throttling
  - Core Web Vitals: LCP <1s, FID <100ms, CLS <0.1
- Where enforced:
  - Tests: Playwright performance tests
  - CI: Lighthouse CI (future)
- Current status: unknown (not yet measured)
- Notes:
  - Most critical for F-0004 (drag-and-drop must be smooth)
  - localStorage operations are synchronous (fast enough for MVP)

---

## NFR-0002: Data reliability
- Category: reliability
- Statement: Zero data loss on normal browser close, graceful degradation on storage errors
- Applies to: F-0002 (localStorage persistence)
- How to measure:
  - Integration tests with forced storage errors
  - Manual testing: close browser, refresh, clear storage
- Where enforced:
  - Tests: Integration tests with mocked localStorage failures
  - Code: Try/catch blocks around all storage operations
- Current status: partial (basic error handling in place, needs comprehensive tests)
- Notes:
  - localStorage can fail if quota exceeded or private mode
  - Show user-friendly error message if storage unavailable
  - Graceful degradation: app works but doesn't persist

---

## NFR-0003: Browser compatibility
- Category: compatibility
- Statement: Works in Chrome, Firefox, Safari (latest 2 versions)
- Applies to: All features
- How to measure:
  - Manual testing in each browser
  - Playwright cross-browser tests
- Where enforced:
  - Tests: Playwright with webkit, chromium, firefox
  - CI: Test matrix (future)
- Current status: unknown (not yet tested)
- Notes:
  - Using modern features (ES2022, CSS Grid)
  - No IE11 support needed
  - Mobile browsers: iOS Safari, Chrome Android

---

## NFR-0004: Accessibility (WCAG 2.1 AA)
- Category: accessibility
- Statement: Keyboard navigable, screen reader compatible, sufficient color contrast
- Applies to: All features with UI
- How to measure:
  - Lighthouse accessibility score >90
  - Manual keyboard navigation testing
  - axe-core automated testing
- Where enforced:
  - Tests: Playwright with axe-core
  - Code reviews: Check ARIA labels, semantic HTML
- Current status: unknown (not yet tested)
- Notes:
  - Critical for F-0006 (keyboard shortcuts)
  - Use semantic HTML (button, form, etc.)
  - Provide skip links, focus indicators
