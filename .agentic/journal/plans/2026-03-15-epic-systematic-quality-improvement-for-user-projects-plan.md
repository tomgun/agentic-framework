# Epic: Systematic Quality Improvement for User Projects

## Context

**Problem**: When teams use the framework to build software, three quality gaps hurt them:
1. **NFR constraints don't reach implementation** — NFRs live in a separate `## NFR Compliance` section that agents treat as paperwork, not as criteria to build against
2. **ACs are vague or incomplete** — `spec-analyze.sh` detects ambiguity but is advisory-only; agents can implement against untestable criteria
3. **Tests don't prove ACs are met** — tests must pass, but no mechanism verifies they actually exercise the acceptance criteria

**For user projects**: A team using this framework on their Rails app / Go service should get agents that write clear ACs with NFR constraints baked in, implement against those ACs, and write tests that actually prove the ACs are met.

---

## Phase 0: Shared AC Parsing (prerequisite)

**Problem**: Four tools parse ACs four different ways — `cmd_done()` in ag.sh, `count_ac()` in spec-audit.sh, spec-analyze.sh, and check-spec-health.sh each use different regexes. Any format improvement is undermined if parsing is inconsistent.

**Deliverable**: A shared shell function (sourced from a common file) that all tools use to count checked/unchecked ACs across all formats: `- [ ] **AC-XXX**:`, `- [x] **AC-XXX**:`, `### AC-XXX`, `- AC-XXX:`.

**Files:**
- `.agentic/lib/tools/ac-parse.sh` — NEW: shared AC parsing functions (`count_checked`, `count_unchecked`, `list_acs`, `get_priority_group`)
- `.agentic/lib/ag.sh` — source ac-parse.sh in `cmd_done()`
- `.agentic/lib/tools/spec-audit.sh` — source ac-parse.sh
- `.agentic/lib/tools/spec-analyze.sh` — source ac-parse.sh
- `.agentic/lib/tools/check-spec-health.sh` — source ac-parse.sh

---

## Phase 1: AC Completeness Enforcement

**Why first**: Highest impact, lowest risk. Fixes the "41 shipped features with <50% ACs checked" problem. Uses Phase 0's shared parser.

**Changes:**
- P1 ACs (in `### ... (P1 — MVP)` groups) must be 100% checked to ship via `ag done`
- P2/P3 ACs: 80% threshold (configurable via `acceptance_threshold` setting)
- `ag done` is the enforcement point (not pre-commit — by pre-commit it's too late)
- **Profile-aware**: Formal/autonomous_formal = blocking. Discovery = advisory warning.

**Files:**
- `.agentic/lib/ag.sh` — update `cmd_done()` to use shared parser, enforce P1 100% threshold
- `.agentic/lib/tools/check-spec-health.sh` — report per-priority completion rates

---

## Phase 2: AC Clarity Gate

**Why second**: Catches bad ACs before implementation starts. Works on current format, no NFR dependency.

**Changes to `spec-analyze.sh`:**
- Tighten vague-word list — keep only unambiguous red flags ("fast", "scalable", "easy to use", "appropriate") without quantified metrics. Remove context-dependent words ("clean", "simple", "minimal") that cause false positives
- Return non-zero exit code for CRITICAL findings (currently always exits 0)
- When flagging vague ACs, **suggest a specific rewrite pattern** (e.g., "fast → specify: 'responds within Xms under Y concurrent users'")
- Drop the "testability check" idea — detecting whether an AC has a concrete expected outcome is a semantic property that requires LLM judgment, not regex. Defer to future LLM-assisted analysis.

**New gate in `ag implement` (ag.sh):**
- After Gate 1 (acceptance file exists), run `spec-analyze.sh F-XXXX --gate`
- CRITICAL findings → block with message showing what to fix and suggested rewrites
- HIGH/MEDIUM findings → advisory warning, proceed
- `--force` bypass for legitimate cases (logged to journal)
- **Profile-aware**: Formal = blocking on CRITICAL. Discovery = advisory only (warn, don't block). Reason: Discovery mode users need low friction for rapid iteration.

**Files:**
- `.agentic/lib/tools/spec-analyze.sh` — tighten word list, add rewrite suggestions, non-zero exit for CRITICAL, `--gate` mode
- `.agentic/lib/ag.sh` — add spec-analyze gate in implement flow, profile-aware
- `.agentic/lib/checklists/feature_start.md` — document new gate

---

## Phase 3: NFR→AC Integration (realizes T-0025)

**Why third, not first**: Phases 1-2 work on the current AC format and deliver immediate value. This phase changes the format — better to do it after the foundation (shared parser, enforcement, clarity) is solid.

### Template Change

Replace separate `## NFR Compliance` section with `### NFR Constraints` group INSIDE `## Acceptance Criteria`:

```markdown
## Acceptance Criteria

### Core Behavior (P1 — MVP)
**Verify independently**: [how to test this group alone]
- [ ] **AC-001**: Feature-specific criterion
- [ ] **AC-002**: Feature-specific criterion

### NFR Constraints (P1 — required)
- [ ] **AC-010**: Response time under 200ms for search endpoint (NFR-0001)
- [ ] **AC-011**: All form inputs have ARIA labels (NFR-0007)
- [ ] **AC-012**: Batch size stays under 10 files per commit (NFR-0003)
```

Design decisions:
- **Plain `(NFR-XXXX)` suffix** — no custom tag syntax. grep-scannable, human-readable, zero parser changes
- **NFR Constraints group is P1** — NFR criteria are not optional. Phase 1's completeness enforcement treats them like any P1 AC (100% to ship)
- Old `## NFR Compliance` section accepted for backward compat (info message suggests migration)

### NFR Scope Matching Tool

**New tool: `nfr-applicable.sh`** (honest name — it lists applicable NFRs, NOT auto-generated ACs):
- `nfr-applicable.sh F-XXXX` — reads NFR.md, matches feature category/scope against each NFR's `Applies to:` field, outputs list of applicable NFR IDs with their statements
- The **agent** writes the actual ACs — constraints ("response time < 200ms") need feature context to become testable criteria ("search API returns results within 200ms for queries up to 1000 results")

### Staleness Detection (Just-in-Time, No New Files)

**No NFR_PROPAGATION.md.** Instead, just-in-time git timestamp comparison:
- When `ag implement` runs, compare `git log -1 --format=%ct -- .agentic/spec/NFR.md` against `git log -1 --format=%ct -- .agentic/spec/acceptance/F-XXXX.md`
- If NFR.md changed after the acceptance file AND the acceptance file references any NFR → warn: "NFR.md has changed since this feature's ACs were written. Run `nfr-applicable.sh F-XXXX` to check for updates."
- Zero maintenance, no embedded metadata, no new files to drift
- Dashboard integration: `dashboard.sh` runs the same check across all in-progress features

### Spec-Writing Workflow Integration

`spec_writing.md` Step 2 changes from "manually evaluate each NFR" to:
1. Run `nfr-applicable.sh F-XXXX`
2. For each applicable NFR, write an AC in the `### NFR Constraints` group that makes the constraint testable in this feature's context
3. If no NFRs apply, omit the group (or add `<!-- NFRs: none evaluated YYYY-MM-DD -->`)

### Files

- `.agentic/lib/templates/acceptance.template.md` — new format (NFR Constraints inside AC section)
- `.agentic/lib/tools/nfr-applicable.sh` — NEW: scope matcher
- `.agentic/lib/tools/nfr.sh` — no propagation file changes; keep existing functionality
- `.agentic/lib/tools/spec-audit.sh` — scan for `(NFR-XXXX)` patterns in ACs
- `.agentic/lib/workflows/spec_writing.md` — replace Step 2
- `.agentic/lib/checklists/feature_start.md` — update Gate 1 to accept new format
- `.agentic/lib/ag.sh` — NFR staleness check in implement flow
- `.agentic/lib/tools/dashboard.sh` — NFR staleness line
- `.agentic/lib/tools/ac-parse.sh` — extend parser to recognize `(NFR-XXXX)` tagged ACs

**Migration:** `nfr-migrate.sh` (NEW) converts old `## NFR Compliance` → new inline format. Opt-in.

---

## Phase 4: Test Quality Checks

**Why last**: Depends on Phases 0-1 (shared parser, completeness enforcement) to know which ACs matter.

**Viable checks (ship these):**
- **Stub assertion detection**: flag `assert True`, `assert 1 == 1`, `assert len(x) >= 0` — simple regex, low false positives
- **Unused import detection**: test imports module under test but never calls its functions — deterministic, catches copy-paste test stubs
- **Empty test body detection**: improve existing check in spec-audit.sh (currently regex-based, can miss disguised empties)

**Drop these (from original plan):**
- ~~Assertion-to-lines ratio~~ — integration tests legitimately have long setup. A low ratio doesn't mean bad tests.
- ~~Per-AC coverage reporting~~ — tests reference feature IDs (`F-XXXX`), not individual ACs. Reframe to **feature-level** coverage: "Does F-0042 have at least one non-trivial test file?"

**Feature-level test coverage in `ag audit`:**
- For each shipped feature, show: has tests (yes/no), test quality (clean / has stubs / empty bodies)
- Simple table output, not a per-AC matrix

**Files:**
- `.agentic/lib/tools/spec-audit.sh` — stub detection, unused import detection, feature-level coverage
- `.agentic/lib/ag.sh` — `ag audit` output enhancement

---

## Ordering & Dependencies

```
Phase 0: Shared AC Parser          ← foundation for all phases
    ↓
Phase 1: AC Completeness           ← highest impact, uses shared parser
    ↓
Phase 2: AC Clarity Gate           ← catches bad ACs before implementation
    ↓
Phase 3: NFR→AC Integration       ← template change + scope matching + staleness
    ↓
Phase 4: Test Quality              ← viable heuristics only, feature-level coverage
```

Phases 1 and 2 are independent after Phase 0 — could be done in parallel.
Phase 3 changes the template format — depends on shared parser being stable.
Phase 4 depends on Phase 1 (needs completeness to know which features to audit).

## Estimated Scope

| Phase | New files | Modified files | Complexity |
|-------|-----------|----------------|------------|
| 0: AC Parser | 1 (ac-parse.sh) | 4 | Low (extract + consolidate) |
| 1: Completeness | 0 | 2 | Low (use shared parser + threshold) |
| 2: Clarity Gate | 0 | 3 | Low-medium (tighten tool + add gate) |
| 3: NFR→AC | 2 (nfr-applicable.sh, nfr-migrate.sh) | ~8 | Medium (template + workflow + staleness) |
| 4: Test Quality | 0 | 2 | Low-medium (regex heuristics) |

## Verification

Each phase needs both manual testing AND LLM tests (agents must encounter and respond to gates):

**Phase 0**: Unit tests for ac-parse.sh — feed it all AC formats, verify consistent counts.

**Phase 1**: `ag done` with unchecked P1 AC → blocks (Formal), warns (Discovery). LLM test: agent running `ag done` with incomplete ACs gets blocked.

**Phase 2**: Vague AC → `ag implement` blocks with rewrite suggestion. Clear AC → passes. `--force` → logged. LLM test: agent writing "system should be fast" gets prompted to add metrics.

**Phase 3**: Write feature spec → `nfr-applicable.sh` lists applicable NFRs → agent writes NFR Constraint ACs → verify they appear in AC list. Change NFR → `ag implement` warns about staleness. LLM test: agent writing spec for a feature that has applicable NFRs includes them in AC list.

**Phase 4**: Test with `assert True` → flagged by `spec-audit.sh`. `ag audit` shows feature-level coverage table. LLM test: agent asked "could this test pass with a broken implementation?" on a stub test answers yes.

## Out of Scope

- Cross-feature AC contradiction detection (T-0032 — needs LLM)
- TDD mode enforcement (T-0058 — separate investigation)
- Configurable DoD per task type (F-0210 — separate feature, could absorb Phase 1)
- Framework's own AC backlog cleanup (internal housekeeping)
- Code style/linting integration (too project-specific)
- AC testability heuristic (semantic property, needs LLM — defer)
- Per-AC test coverage mapping (tests reference features, not individual ACs)
