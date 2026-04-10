# Code Review Checklist

Structured checklist for implementation self-review and PR review. Use this for every code change.

## 1. Correctness

- [ ] Does the change meet the acceptance criteria / contract assertions?
- [ ] Are edge cases handled (empty inputs, boundaries, null, zero)?
- [ ] Are error conditions handled (network failure, timeout, permission denied)?
- [ ] Does the logic handle concurrent access correctly (if applicable)?
- [ ] Are all code paths reachable and tested?

### Quick Correctness Check
> Run the code mentally with: empty input, single item, typical input, maximum input, invalid input. Does it handle all five?

## 2. Security

- [ ] Is all external input validated before use?
- [ ] Are database queries parameterized (no string interpolation in SQL)?
- [ ] Is user-generated content sanitized before rendering?
- [ ] Are authentication and authorization checked before actions?
- [ ] Are secrets read from environment, not hardcoded?
- [ ] Are new dependencies free of known CVEs?
- [ ] If file upload: is content type, size, and content validated?

### Quick Security Check
> Trace every external input from entry to use. Is it validated, typed, and bounded at the boundary?

See: `security.knowledge.md` for detailed OWASP patterns.

## 3. Tests

- [ ] Are unit tests present for new/changed logic?
- [ ] Do tests assert behavior, not implementation? (Would they survive a refactor?)
- [ ] Are tests meaningful — do they fail before the fix and pass after?
- [ ] Are edge cases and error paths tested (not just happy path)?
- [ ] If domain-specific tests are needed (plugin validation, performance, E2E), are they covered or tracked?

### The Litmus Test
> "Could this test pass with a broken implementation?" If yes, the test is too weak.

See: `testing.knowledge.md` for London vs Classical, test doubles, coverage strategy.

## 4. Design

- [ ] Are responsibilities clear? Does each module/class have a single purpose?
- [ ] Is the change as small as it can reasonably be?
- [ ] Is there unnecessary coupling between modules?
- [ ] Are abstractions at the right level (not too early, not too late)?
- [ ] Could a new team member understand this without asking the author?

### Quick Design Check
> If you removed this module, how many other files would break? If >5, the coupling is too high.

## 5. Performance & Reliability

- [ ] Are there obvious hot paths impacted (O(n²), DB queries in loops)?
- [ ] Are new resources (connections, files, listeners) properly cleaned up?
- [ ] Are there new concurrency hazards (race conditions, deadlocks)?
- [ ] If caching is added: is invalidation handled correctly?
- [ ] Are timeouts set for external calls (HTTP, database, third-party)?

### Quick Performance Check
> What happens if this runs with 10x the expected data? Does it degrade gracefully or explode?

See: `green_coding.knowledge.md` for algorithm efficiency, caching, and resource management.

## 6. Plan Alignment

- [ ] Does the implementation match the approved plan (`.agentic/journal/plans/`)?
- [ ] Are all planned deliverables present?
- [ ] Are there unplanned additions? If so, are they justified?
- [ ] If deviations exist, are they documented (in the PR or journal)?

## 7. Documentation & Project Truth

- [ ] Is `STATUS.md` updated with current focus?
- [ ] Are specs/contracts updated if behavior changed?
- [ ] Are ADRs updated if architectural decisions changed?
- [ ] Is `JOURNAL.md` updated with what was done and why?
- [ ] If new public API: is it documented (function docs, README section)?

## Review Process

### Self-Review (Before PR)
1. Read the full diff as if you're seeing it for the first time
2. Run through this checklist
3. Check: would a new team member understand every change?

### PR Review (Reviewer)
1. Understand the WHY before reading the code (read PR description, plan, spec)
2. Read the diff top-to-bottom, checking this list
3. Focus on: correctness, security, design — not style (that's for linters)
4. If unsure about a pattern: ask, don't assume it's wrong

### Review Anti-Patterns
- **Rubber-stamping**: Approving without reading ("LGTM" in 30 seconds)
- **Bikeshedding**: Debating naming for 20 minutes, missing a SQL injection
- **Style nitpicking**: Arguing about brace placement instead of checking logic
- **Delayed reviews**: Reviewing 2 days later when context is lost
