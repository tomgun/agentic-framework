# Plan: Systematic Quality Improvement for User Projects (Epic)

**Status**: APPROVED
**Iteration**: 4
**Created**: 2026-03-15
**Last Updated**: 2026-03-15

---

## Context

**Problem**: When teams use the framework to build software, three quality gaps hurt them:
1. **NFR constraints don't reach implementation** — NFRs live in a separate `## NFR Compliance` section that agents treat as paperwork, not as criteria to build against
2. **ACs are vague or incomplete** — `spec-analyze.sh` detects ambiguity but is advisory-only; agents can implement against untestable criteria
3. **Tests don't prove ACs are met** — tests must pass, but no mechanism verifies they actually exercise the acceptance criteria

**For user projects**: A team using this framework on their Rails app / Go service should get agents that write clear ACs with NFR constraints baked in, implement against those ACs, and write tests that actually prove the ACs are met.

---

## Approach

Five-phase implementation with strict dependency ordering. Each phase delivers independent value.

### Phase 0: Shared AC Parsing (prerequisite)

**Problem**: Four tools parse ACs four different ways — `cmd_done()` in ag.sh, `count_ac()` in spec-audit.sh, spec-analyze.sh, and check-spec-health.sh each use different regexes. Any format improvement is undermined if parsing is inconsistent.

**Deliverable**: A shared shell function (sourced from a common file) that all tools use to count checked/unchecked ACs across all formats: `- [ ] **AC-XXX**:`, `- [x] **AC-XXX**:`, `### AC-XXX`, `- AC-XXX:`.

**⚠️ Behavior change, not just refactoring**: The four tools currently count different things (e.g., spec-audit.sh counts `^- AC-[0-9]+:` while cmd_done() counts `^[[:space:]]*- \[[ x]\]`). The shared parser will recognize **both** formats:
- **Primary format (checkbox)**: `- [ ] **AC-NNN**:` and `- [x] **AC-NNN**:` — the canonical format going forward
- **Legacy format (bare)**: `- AC-NNN:` — recognized for backward compat. Only 5 files (33 lines) use this today. Counted as unchecked (no checkbox = not checked off). Info message: "Legacy AC format detected — consider migrating to checkbox format: `- [ ] **AC-NNN**:`"
- `check-spec-health.sh` will gain AC-ID awareness (currently counts raw checkboxes without AC-ID)
- Expected count changes should be documented in the PR and verified against 5-10 representative spec files

**Profile check helper**: Add `_is_formal_like()` function to ag.sh (returns true for `formal` and `autonomous_formal`). Used by Phases 1-2 for profile-aware enforcement. Prevents the existing pattern of checking `== "formal"` and missing `autonomous_formal`.

**Files:**
- `.agentic/lib/tools/ac-parse.sh` — NEW: shared AC parsing functions (`count_checked`, `count_unchecked`, `list_acs`, `get_priority_group`)
- `.agentic/lib/ag.sh` — source ac-parse.sh in `cmd_done()`
- `.agentic/lib/tools/spec-audit.sh` — source ac-parse.sh
- `.agentic/lib/tools/spec-analyze.sh` — source ac-parse.sh
- `.agentic/lib/tools/check-spec-health.sh` — source ac-parse.sh

### Phase 1: AC Completeness Enforcement

**Why first**: Highest impact, lowest risk. Fixes the "41 shipped features with <50% ACs checked" problem. Uses Phase 0's shared parser.

**Changes:**
- P1 ACs (in `### ... (P1 — MVP)` groups) must be 100% checked to ship via `ag done`
- P2/P3 ACs: 80% threshold (configurable via `acceptance_threshold` setting)
- `ag done` is the enforcement point (not pre-commit — by pre-commit it's too late)
- **Profile-aware**: Formal/autonomous_formal = blocking. Discovery = advisory warning.

**⚠️ Fallback for specs without priority group headings (95% of existing files)**: Only 9/178 existing acceptance files use `(P1 — MVP)` style priority headings. The rest use flat AC lists. The parser must handle this:
- **If no priority group headings found**: Flat-list specs use the **existing 80% threshold** (same as today's behavior — no policy cliff). This is a non-breaking default.
- **If priority groups found**: P1 groups = 100%, P2/P3 = 80%.
- **Mixed format** (priority groups AND bare ACs outside any group): ACs outside any priority group are treated as P1 when groups exist in the file. Rationale: if you've started categorizing, uncategorized stragglers should default to "required" not "optional."
- **Migration path**: As teams adopt priority group headings (encouraged by the template), they get stricter P1 enforcement naturally. The benefit of categorization is the incentive. No forced migration.
- **Interaction with existing `acceptance_criteria: blocking/advisory` setting**: The existing setting controls whether AC enforcement is blocking or advisory overall. The new P1/P2/P3 thresholds apply WITHIN blocking mode. `acceptance_criteria: advisory` still makes everything advisory. No new setting needed — the existing one is sufficient.
- **No phantom `acceptance_threshold` setting**: The 80% default is hardcoded (matching today's behavior). If teams want to configure it, that's a future enhancement — not part of this epic. Avoids adding unvalidated settings to profiles.conf.

**Files:**
- `.agentic/lib/ag.sh` — update `cmd_done()` to use shared parser, enforce P1 100% threshold
- `.agentic/lib/tools/check-spec-health.sh` — report per-priority completion rates

### Phase 2: AC Clarity Gate

**Why second**: Catches bad ACs before implementation starts. Works on current format, no NFR dependency.

**Changes to `spec-analyze.sh`:**
- Tighten vague-word list — keep only unambiguous red flags ("fast", "scalable", "easy to use", "appropriate") without quantified metrics. Remove context-dependent words ("clean", "simple", "minimal") that cause false positives
- **Exit code behavior**: Default invocation (`spec-analyze.sh F-XXXX`) continues to exit 0 — advisory only, no breaking change. New `--gate` mode (`spec-analyze.sh F-XXXX --gate`) exits non-zero for CRITICAL findings. Only `ag implement` calls `--gate` mode. Existing CI/Makefile usage is unaffected.
- **`--gate` mode and `pipefail`**: The existing script uses `set -uo pipefail` but NOT `set -e`. In `--gate` mode, compute the CRITICAL finding count into a variable, then `exit` explicitly based on that count at the end of the gate function. Do NOT rely on pipefail propagation for the exit code — internal command failures should not produce false gate failures. Pattern: `local critical_count=0; ... ; if [[ "$critical_count" -gt 0 ]]; then exit 1; fi; exit 0`
- When flagging vague ACs, **suggest a specific rewrite pattern** (e.g., "fast → specify: 'responds within Xms under Y concurrent users'")
- Drop the "testability check" idea — detecting whether an AC has a concrete expected outcome is a semantic property that requires LLM judgment, not regex. Defer to future LLM-assisted analysis.

**New gate in `ag implement` (ag.sh):**
- After Gate 1 (acceptance file exists), run `spec-analyze.sh F-XXXX --gate`
- CRITICAL findings → block with message showing what to fix and suggested rewrites
- HIGH/MEDIUM findings → advisory warning, proceed
- **Profile-aware**: Formal = blocking on CRITICAL. Discovery = advisory only (warn, don't block). Reason: Discovery mode users need low friction for rapid iteration.

**⚠️ `--skip-clarity` bypass specification** (not `--force` — that flag is already used by `ag kickoff --force` for overwriting OVERVIEW.md):
- Usage: `ag implement F-XXXX --skip-clarity` skips the clarity gate
- Also available as env var: `SKIP_CLARITY=1 ag implement F-XXXX` (consistent with existing `SKIP_BACKLOG=1` pattern)
- **What gets logged**: Journal entry via `journal.sh` with topic "AC clarity gate bypassed" and the feature ID + reason. **Journal write is advisory** — if `journal.sh` fails (missing JOURNAL.md, permissions), the bypass still proceeds. Pattern: `journal.sh ... 2>/dev/null || true`
- **Available in all profiles**: Yes — even formal-profile users may have legitimate use (e.g., "fast path" where "fast" is a product concept, not a vague metric)
- **Does NOT create a TODO/blocker**: The journal entry is sufficient — creating a TODO for every bypass adds noise. The bypass is visible in git history.
- **Applies to clarity gate only**: Does NOT bypass other gates (plan review, spec-first, etc.)

**⚠️ Re-implement skip**: The clarity gate only fires on **first implement** (when no WIP entry exists for this feature in AGENTS.json). Detection mechanism: `_get_wip_feature()` already returns the current WIP feature ID (line 42 of ag.sh). If `current_wip == feature_id`, the feature is already in progress — skip the clarity gate. This means:
- First `ag implement F-XXXX`: runs clarity gate (spec-analyze --gate)
- Subsequent `ag implement F-XXXX` (resuming after context switch): skips clarity gate (already committed to these ACs)
- `ag implement F-YYYY` (different feature): runs clarity gate for F-YYYY

**⚠️ Gate placement**: The clarity gate runs **after Gate 1** (acceptance file exists, ~line 900 area of cmd_implement) and **before step 6** (WIP registration via `wip.sh start`, ~line 1012). This sequencing is load-bearing:
- Gate 1 ensures the acceptance file exists (can't analyze ACs without a file)
- Clarity gate runs analysis on that file
- WIP registration happens later — so `_get_wip_feature()` correctly returns empty on first implement (gate fires) and the feature ID on re-implement (gate skips)
- **Implementer note**: Do NOT move the clarity gate after WIP registration — that would break the re-implement skip detection

**⚠️ `--skip-clarity` flag parsing**: `cmd_implement()` uses positional args (`feature_id=$1`), not getopts. The flag must be parsed explicitly before positional arg extraction:
```bash
# At top of cmd_implement(), before feature_id=$1:
local skip_clarity="${SKIP_CLARITY:-0}"
while [[ "${1:-}" == --* ]]; do
    case "$1" in
        --skip-clarity) skip_clarity=1; shift ;;
        *) break ;;
    esac
done
local feature_id="$1"
```
This ensures `ag implement --skip-clarity F-XXXX` and `ag implement F-XXXX --skip-clarity` both work. The `SKIP_CLARITY=1` env var path is the simpler alternative.

**Files:**
- `.agentic/lib/tools/spec-analyze.sh` — tighten word list, add rewrite suggestions, `--gate` mode with non-zero exit (default mode unchanged)
- `.agentic/lib/ag.sh` — add spec-analyze gate in implement flow, profile-aware, `--skip-clarity` handling
- `.agentic/lib/checklists/feature_start.md` — document new gate

### Phase 3: NFR→AC Integration (realizes T-0025)

**Why third, not first**: Phases 1-2 work on the current AC format and deliver immediate value. This phase changes the format — better to do it after the foundation (shared parser, enforcement, clarity) is solid.

#### Template Change

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
- **Both old and new locations recognized as compliant**: `spec-audit.sh` checks both `## NFR Compliance` (old) and `### NFR Constraints` (new). `cmd_done()` gate passes for either location. The info message is just a suggestion, not a degradation.
- **NFR evaluation absence**: When no NFRs apply, use `<!-- NFRs: none applicable — evaluated YYYY-MM-DD -->` (single convention, not optional). Tools distinguish "not evaluated" (no comment, no group) from "evaluated, none apply" (comment present).

#### NFR Scope Matching Tool

**New tool: `nfr-applicable.sh`** (honest name — it lists applicable NFRs, NOT auto-generated ACs):
- `nfr-applicable.sh F-XXXX` — reads NFR.md, matches feature category/scope against each NFR's `Applies to:` field, outputs list of applicable NFR IDs with their statements
- The **agent** writes the actual ACs — constraints ("response time < 200ms") need feature context to become testable criteria ("search API returns results within 200ms for queries up to 1000 results")
- **Matching heuristic**: NFRs with `(global)` or `all work` in `Applies to:` always match. Other NFRs matched by keyword overlap between `Applies to:` field and feature's `Category:` / `Description:` from FEATURES.md. Low-confidence matches are flagged with `(?)` so the agent can decide.
- **When NFR.md is empty/template-only**: Tool outputs "No NFRs defined. Consider running `ag nfr discover` to identify project-specific NFRs." — helpful, not silent.

#### Staleness Detection (Just-in-Time, No New Files)

**No NFR_PROPAGATION.md.** Instead, just-in-time git timestamp comparison:
- When `ag implement` runs, compare `git log -1 --format=%ct -- .agentic/spec/NFR.md` against `git log -1 --format=%ct -- .agentic/spec/acceptance/F-XXXX.md`
- If NFR.md changed after the acceptance file AND the acceptance file references any NFR → warn: "NFR.md has changed since this feature's ACs were written. Run `nfr-applicable.sh F-XXXX` to check for updates."
- **Known limitation: false positives from unrelated NFR changes**. Adding a new NFR-0015 triggers warnings for features referencing only NFR-0003. Accepted trade-off: file-level comparison is zero-maintenance and the warning is non-blocking (advisory only). The alternative (line-level diff to detect which NFR IDs changed) adds parsing complexity for marginal benefit — the agent can quickly check if its referenced NFRs actually changed.
- **Shallow clone / empty timestamp handling**: If `git log` returns empty (shallow clone, uncommitted file), skip the staleness check silently. No arithmetic errors, no false blocks.
- Dashboard integration: `dashboard.sh` runs the same check across all in-progress features

#### Spec-Writing Workflow Integration

`spec_writing.md` Step 2 changes from "manually evaluate each NFR" to:
1. Run `nfr-applicable.sh F-XXXX`
2. For each applicable NFR, write an AC in the `### NFR Constraints` group that makes the constraint testable in this feature's context
3. If no NFRs apply, add `<!-- NFRs: none applicable — evaluated YYYY-MM-DD -->`

#### Files
- `.agentic/lib/templates/acceptance.template.md` — new format
- `.agentic/lib/tools/nfr-applicable.sh` — NEW: scope matcher
- `.agentic/lib/tools/nfr.sh` — no propagation file changes; keep existing
- `.agentic/lib/tools/spec-audit.sh` — scan for `(NFR-XXXX)` patterns, recognize both old and new locations
- `.agentic/lib/workflows/spec_writing.md` — replace Step 2
- `.agentic/lib/checklists/feature_start.md` — update Gate 1
- `.agentic/lib/ag.sh` — NFR staleness check in implement flow
- `.agentic/lib/tools/dashboard.sh` — NFR staleness line
- `.agentic/lib/tools/ac-parse.sh` — extend parser for `(NFR-XXXX)` tagged ACs

**⚠️ `nfr-migrate.sh` and shipped spec contracts**:
- NEW: `.agentic/lib/tools/nfr-migrate.sh` — converts old `## NFR Compliance` → new `### NFR Constraints` inline format
- **Shipped spec protection**: `nfr-migrate.sh` checks feature status in FEATURES.md. For shipped features, it creates a migration entry via `migration.sh create` before modifying the acceptance file. For in-progress/planned features, it modifies directly (no contract to protect).
- **Opt-in only**: Never called automatically by any workflow. Agent or user must invoke explicitly.

### Phase 4: Test Quality Checks

**Why last**: Depends on Phases 0-1 (shared parser, completeness enforcement) to know which ACs matter.

**⚠️ Language-scoped checks**: Test quality heuristics are inherently language-specific. Rather than pretend universality:
- **Language-aware detection**: Read `language:` from STACK.md. Apply patterns per language:
  - Python: `assert True`, `assert 1 == 1`, `assert len(x) >= 0`, unused `import`
  - JavaScript/TypeScript: `expect(true).toBe(true)`, `expect(1).toBe(1)`, unused `require`/`import`
  - Shell: empty test functions (body is just `true` or `:`)
  - Go: compile-time import checking means unused imports are already caught; focus on `t.Skip()` without reason
  - Other languages: empty body detection only (universal), skip stub/import checks with info message "stub detection not available for [language]"
- **Test directory discovery**: Read `test_directory:` from STACK.md if present. Fallback: search common patterns (`tests/`, `test/`, `__tests__/`, `spec/`, `*_test.go`, `*.test.{js,ts}`).

**Viable checks per language:**
- **Stub assertion detection**: language-specific patterns (see above)
- **Unused import detection**: Python and JS/TS only (Go catches at compile time, others vary)
- **Empty test body detection**: universal (any language — function/method with no assertions)

**Drop these (from original plan):**
- ~~Assertion-to-lines ratio~~ — integration tests legitimately have long setup
- ~~Per-AC coverage reporting~~ — reframe to feature-level coverage

**Feature-level test coverage in `ag audit`:**
- For each shipped feature, show: has tests (yes/no), test quality (clean / has stubs / empty bodies)
- Simple table output, not a per-AC matrix
- **Known limitation**: Feature-level coverage requires test files to reference the feature ID (e.g., `F-0042` in a comment or filename). Projects organized by module rather than feature will show "no test files." Documented in output with: "Tip: add `# F-XXXX` comment in test files to enable feature-level coverage tracking."

**Files:**
- `.agentic/lib/tools/spec-audit.sh` — language-aware stub detection, unused import detection, feature-level coverage
- `.agentic/lib/ag.sh` — `ag audit` output enhancement

---

## Instruction File Updates

**Framework-dev rule: instruction files are part of the feature.** Each phase that adds/changes an `ag` command, gate, or workflow must update these files. Grouped by what changes:

### Phase 1 changes (`ag done` behavior) + Phase 2 changes (`ag implement` gate):

| File | Section to update |
|------|-------------------|
| `.agentic/lib/agents/claude/CLAUDE.md` | Core Rules (mention AC completeness enforcement at `ag done`) |
| `.agentic/lib/agents/cursor/cursorrules.txt` | STOP! Trigger Words table (update "done/complete" entry with P1 enforcement note) |
| `.agentic/lib/agents/copilot/copilot-instructions.md` | Mirror cursorrules changes |
| `.agentic/lib/agents/codex/codex-instructions.md` | Mirror cursorrules changes |
| `.agentic/lib/agents/shared/agent_operating_guidelines.md` | GATES table (add clarity gate row) |
| `.agentic/lib/agents/shared/auto_orchestration.md` | Feature Pipeline steps (add clarity gate step) |
| `.agentic/lib/init/memory-seed.md` | "When the user wants to build something" section (mention clarity gate), "When the user says done" section (mention P1 enforcement). Bump sentinel version. |
| `docs/DEVELOPER_GUIDE.md` | "When you say..." table (update implement/done rows) |
| `docs/HOW_IT_WORKS.md` | Feature map (add quality gates to principle implementation) |
| `.agentic/lib/agents/claude/skills/implementing-features/SKILL.md` | Add Step 1.5: AC Clarity Gate (between Step 1 verify ACs and Step 2 implementation). Document `--skip-clarity` bypass. **Template first** (dogfooding rule), then sync to `.claude/skills/`. |

### Phase 3 changes (NFR integration, `nfr-applicable.sh`, template change):

| File | Section to update |
|------|-------------------|
| `.agentic/lib/agents/cursor/cursorrules.txt` | Trigger Words ("NFR" entry → reference `nfr-applicable.sh`) |
| `.agentic/lib/agents/copilot/copilot-instructions.md` | Mirror |
| `.agentic/lib/agents/codex/codex-instructions.md` | Mirror |
| `.agentic/lib/agents/shared/auto_orchestration.md` | Spec-Writing Pipeline (update NFR step) |
| `.agentic/lib/init/memory-seed.md` | Spec-writing section (reference new NFR workflow) |
| `.agentic/lib/agents/claude/skills/writing-specs/SKILL.md` | NFR integration step |

### Phase 4 changes (`ag audit` enhancement):

| File | Section to update |
|------|-------------------|
| `.agentic/lib/agents/shared/agent_operating_guidelines.md` | Autonomous Modes table (add `ag audit` if not present) |
| `.agentic/lib/init/memory-seed.md` | Add "When the user wants to check test quality" section |
| `docs/DEVELOPER_GUIDE.md` | "When you say..." table (add audit row) |

---

## Implementation Steps

1. [ ] Phase 0: Create `ac-parse.sh` with shared parsing functions, document expected count changes
2. [ ] Phase 0: Integrate shared parser into ag.sh, spec-audit.sh, spec-analyze.sh, check-spec-health.sh
3. [ ] Phase 0: Verify count consistency against 5-10 representative spec files
4. [ ] Phase 1: Update `cmd_done()` with flat-list fallback (80% — same as today) and priority-group thresholds (P1=100%, P2/P3=80%)
5. [ ] Phase 1: Update check-spec-health.sh for per-priority rates
6. [ ] Phase 1: Update instruction files (see table above)
7. [ ] Phase 2: Tighten spec-analyze.sh word list, add rewrite suggestions, `--gate` mode (default unchanged)
8. [ ] Phase 2: Add spec-analyze gate in ag.sh implement flow with `--skip-clarity` bypass and re-implement skip
9. [ ] Phase 2: Update feature_start.md checklist + instruction files (see table above)
10. [ ] Phase 3: Update acceptance template with NFR Constraints group
11. [ ] Phase 3: Create nfr-applicable.sh scope matcher with keyword heuristic
12. [ ] Phase 3: Create nfr-migrate.sh with shipped-spec protection (creates migration entry)
13. [ ] Phase 3: Add NFR staleness detection in ag.sh implement (with shallow-clone guard)
14. [ ] Phase 3: Integrate into spec_writing.md and dashboard.sh
15. [ ] Phase 3: Update instruction files (see table above)
16. [ ] Phase 4: Add language-aware stub/empty/unused-import detection to spec-audit.sh
17. [ ] Phase 4: Enhance ag audit output with feature-level coverage
18. [ ] Phase 4: Update instruction files (see table above)

## Files to Modify

**New files (3):**
- `.agentic/lib/tools/ac-parse.sh` — shared AC parsing
- `.agentic/lib/tools/nfr-applicable.sh` — NFR scope matcher
- `.agentic/lib/tools/nfr-migrate.sh` — migration tool (with shipped-spec protection)

**Modified files — code (10):**
- `.agentic/lib/ag.sh` — cmd_done(), implement flow gates, audit, --skip-clarity, _is_formal_like()
- `.agentic/lib/tools/spec-audit.sh` — shared parser, NFR scan (both locations), test quality
- `.agentic/lib/tools/spec-analyze.sh` — tightened word list, --gate mode (default exit 0 unchanged)
- `.agentic/lib/tools/check-spec-health.sh` — per-priority rates
- `.agentic/lib/templates/acceptance.template.md` — NFR Constraints group
- `.agentic/lib/workflows/spec_writing.md` — NFR integration
- `.agentic/lib/checklists/feature_start.md` — new gates documented
- `.agentic/lib/tools/dashboard.sh` — NFR staleness line

**Modified files — instruction files (9):**
- `.agentic/lib/agents/claude/CLAUDE.md`
- `.agentic/lib/agents/cursor/cursorrules.txt`
- `.agentic/lib/agents/copilot/copilot-instructions.md`
- `.agentic/lib/agents/codex/codex-instructions.md`
- `.agentic/lib/agents/shared/agent_operating_guidelines.md`
- `.agentic/lib/agents/shared/auto_orchestration.md`
- `.agentic/lib/init/memory-seed.md`
- `docs/DEVELOPER_GUIDE.md`
- `docs/HOW_IT_WORKS.md`

**Modified files — skills (2 templates + 2 root syncs):**
- `.agentic/lib/agents/claude/skills/writing-specs/SKILL.md` (template) → sync to `.claude/skills/writing-specs/SKILL.md`
- `.agentic/lib/agents/claude/skills/implementing-features/SKILL.md` (template) → sync to `.claude/skills/implementing-features/SKILL.md`

## Testing Strategy

- **Unit tests**: ac-parse.sh with all AC formats (flat list, priority groups, mixed format, bare `- AC-NNN:` legacy), verify count consistency against real spec files
- **Integration**: `ag done` on flat-list spec blocks at <80% in formal (same as today), warns in discovery
- **Integration**: `ag done` on priority-grouped spec enforces P1=100%, P2/P3=80%
- **Integration**: `ag done` on mixed-format spec (groups + ungrouped ACs) treats ungrouped as P1
- **Integration**: `ag implement` with vague ACs blocks with suggestions in formal; warns in discovery
- **Integration**: `ag implement --skip-clarity` bypasses clarity gate, journal entry created
- **Integration**: `ag implement` on already-in-progress feature (WIP exists) skips clarity gate
- **Integration**: `nfr-migrate.sh` on shipped spec creates migration entry; on in-progress spec modifies directly
- **LLM tests**: Agent writing "fast" in AC gets prompted for metrics; agent running `ag done` with incomplete ACs gets blocked; agent writing spec for feature with applicable NFRs includes them

## Risks & Mitigations

- **Risk**: Shared parser changes existing tool counts
  Mitigation: Document expected changes, verify against representative files, unit tests

- **Risk**: Vague-word detection false positives
  Mitigation: Tight word list, `--skip-clarity` bypass (logged), profile-aware (discovery = advisory)

- **Risk**: NFR template change breaks existing specs
  Mitigation: Both locations recognized as compliant, opt-in migration with shipped-spec protection

- **Risk**: NFR staleness false positives from unrelated NFR changes
  Mitigation: Advisory-only warning, agent can quickly verify. Document as known limitation.

- **Risk**: Phase ordering means later phases are never reached
  Mitigation: Each phase delivers independent value; phases 1-2 are low complexity

- **Risk**: `ag implement` gate blocks mid-development resumption
  Mitigation: `--skip-clarity` bypass, profile-aware (discovery = advisory), gate skips when `_get_wip_feature() == feature_id` (already in progress)

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
Phase 4: Test Quality              ← language-aware heuristics, feature-level coverage
```

Phases 1 and 2 are independent after Phase 0 — could be done in parallel.
Phase 3 changes the template format — depends on shared parser being stable.
Phase 4 depends on Phase 1 (needs completeness to know which features to audit).

## Estimated Scope

| Phase | New files | Modified files (code) | Modified files (instructions) | Complexity |
|-------|-----------|----------------------|-------------------------------|------------|
| 0: AC Parser | 1 (ac-parse.sh) | 4 | 0 | Low |
| 1: Completeness | 0 | 2 | 9 | Low-medium |
| 2: Clarity Gate | 0 | 3 | 9 (same files, additional updates) | Low-medium |
| 3: NFR→AC | 2 (nfr-applicable.sh, nfr-migrate.sh) | ~8 | 6 | Medium |
| 4: Test Quality | 0 | 2 | 3 | Low-medium |

## Out of Scope

- Cross-feature AC contradiction detection (T-0032 — needs LLM)
- TDD mode enforcement (T-0058 — separate investigation)
- Configurable DoD per task type (F-0210 — separate feature, could absorb Phase 1)
- Framework's own AC backlog cleanup (internal housekeeping)
- Code style/linting integration (too project-specific)
- AC testability heuristic (semantic property, needs LLM — defer)
- Per-AC test coverage mapping (tests reference features, not individual ACs)

---

## Review History

### Review 1 (2026-03-15) — iteration 1

**Critic**: Key concerns: (1) Shared parser integration is a behavior change not just refactoring — tools count different things today. (2) P1 priority group detection won't work on 95% of existing files that use flat AC lists. (3) NFR staleness detection has systematic false positives from unrelated NFR changes. (4) spec-analyze.sh exit code change could break existing CI users. (5) `--force` bypass is underdocumented. (6) Phase 4 test checks are language-specific but framework claims language-agnostic. (7) Missing instruction file updates — framework-dev rule requires 9+ files updated.

**Advocate**: Core strengths: (1) Shared parser as Phase 0 is architecturally correct prerequisite. (2) Enforcement at `ag done` not pre-commit is the right chokepoint. (3) Profile-aware behavior implements the framework's existing design contract. (4) NFR integration via format change means existing enforcement applies automatically. (5) Test quality drop decisions are disciplined — only zero-false-positive patterns retained. (6) `nfr-applicable.sh` has honest scope.

**Synthesis**: Architecture is sound. Two critical gaps: (1) fallback for 95% of specs without priority headings, (2) missing instruction file updates. Five important clarifications needed: exit code scoping, NFR staleness false positives, --force behavior, language-aware test checks, nfr-migrate.sh and shipped spec contracts.

**User Decision**: Revise — address all 7 items from revision guidance.

**Planner Response** (iteration 2):
1. **[Critical] Fallback for flat ACs**: Added explicit rule — no priority headings = all ACs treated as P1 (strict default). Documented interaction with existing `acceptance_criteria` setting.
2. **[Critical] Instruction files**: Added full "Instruction File Updates" section with per-phase tables covering all 9 instruction files + 1 skill file.
3. **[Important] Exit code behavior**: Clarified — default invocation stays exit 0. Non-zero ONLY in `--gate` mode. Documented explicitly.
4. **[Important] NFR staleness false positives**: Acknowledged as known limitation. Advisory-only. Added shallow-clone guard (skip if empty timestamp). Documented why file-level is acceptable vs line-level complexity.
5. **[Important] --force bypass**: Full specification added — what gets logged (journal entry), availability (all profiles), scope (clarity gate only), no TODO creation.
6. **[Consider] Language-aware test checks**: Phase 4 now reads `language:` from STACK.md and applies per-language patterns. Explicit support for Python, JS/TS, Shell, Go. Other languages get empty-body detection only with info message.
7. **[Consider] nfr-migrate.sh shipped spec contracts**: Specified — checks feature status, creates migration entry for shipped specs, modifies directly for in-progress specs.

### Review 2 (2026-03-15) — iteration 2

**Critic**: Key concerns: (1) `acceptance_threshold` is a phantom setting — doesn't exist in profiles.conf. (2) "Gate only fires on first implement" asserted but has no mechanism. (3) `--force` conflicts with existing `ag kickoff --force`. (4) Bare `- AC-NNN:` format silently dropped after Phase 0. (5) 80%→100% policy cliff for flat-list specs. (6) `is_formal_like()` doesn't exist in ag.sh — profile checks are inline. (7) `implementing-features` skill missing from instruction file tables. (8) LLM test specs not concrete enough.

**Advocate**: Revisions are substantive, not cosmetic. Key strengths maintained: shared parser foundation, enforcement at `ag done`, profile-aware behavior, NFR format change as structural fix. The "all ACs = P1" default is the correct safe direction. Instruction file coverage now comprehensive. Language-aware Phase 4 is more honest. Acknowledges that re-implement skip mechanism needs specification before coding.

**Synthesis**: Revisions from iteration 1 were genuine improvements. New concerns are implementation-level (flag namespace, re-implement detection mechanism, policy threshold) rather than architectural. One policy question: the 80%→100% cliff for 95% of existing specs needs a decision.

**User Decision**: Revise — address remaining 5 items.

**Planner Response** (iteration 3):
1. **[Important] Re-implement skip mechanism**: Specified — `_get_wip_feature() == feature_id` means feature already in progress, skip clarity gate. Documented three cases: first implement (runs gate), re-implement (skips), different feature (runs gate).
2. **[Important] 80%→100% policy cliff**: Resolved — flat-list specs keep existing 80% threshold (no regression). Only explicitly tagged P1 groups get 100%. Migration is natural: adopt priority headings → get stricter enforcement. Removed phantom `acceptance_threshold` setting — 80% is hardcoded default matching today's behavior.
3. **[Minor] Flag namespace**: Changed from `--force` to `--skip-clarity`. Also available as `SKIP_CLARITY=1` env var (consistent with existing `SKIP_BACKLOG=1` pattern).
4. **[Minor] `implementing-features` skill**: Added to Phase 2 instruction file table. New Step 1.5: AC Clarity Gate between "verify ACs exist" and "implement."
5. **[Minor] Bare AC format fate**: Parser recognizes both checkbox and bare formats. Bare format counted as unchecked with info message suggesting migration. No silent drops.

### Review 3 (2026-03-15) — iteration 3

**Critic**: Implementation-level concerns: (1) Phase 1 delivers value only for 5% of specs on day one. (2) Gate placement sequencing needs documentation. (3) `--gate` mode pipefail interaction. (4) `--skip-clarity` flag parsing with positional args. (5) Mixed format behavior undefined. (6) Dogfooding asymmetry in skill files.

**Advocate**: Plan has converged. Concerns moved structural → implementation → edge cases. All remaining items are code-review-level. Architecture sound, policy decisions explicit.

**Synthesis**: Plan architecturally ready. 5 implementation notes — all code-level.

**User Decision**: Revise — incorporate implementation notes into plan body.

**Planner Response** (iteration 4):
1. Gate placement: Explicit sequencing with rationale for why it's load-bearing.
2. Flag parsing: Code snippet for `--skip-clarity` extraction before positional args.
3. Mixed format: ACs outside groups = P1 when groups exist.
4. Pipefail: Explicit critical_count pattern, no reliance on pipefail.
5. Dogfooding: Template skills first, sync to root.
6. Journal advisory: `|| true` pattern for bypass logging.

### Review 4 (2026-03-15) — iteration 4

**Critic**: No structural blockers remain. Low-severity items: `_get_wip_feature()` multi-WIP behavior, `nfr-migrate.sh` partial-migration dedup, missing test cases for env var bypass. All implementation-time decisions.

**Advocate**: Four iterations showed correct convergence (structural → implementation → edge cases → code patterns). Further iteration = diminishing returns. Plan contains code snippets, explicit gate sequencing, file paths for templates and root. Ready.

**Synthesis**: Plan is ready. Remaining items are test cases and edge case behaviors for code review.

**User Decision**: Proceed

**Status**: APPROVED

**Critic**: Concerns shifted to implementation-level: (1) Phase 1 delivers value only for 5% of specs with priority headings on day one (flat-list = 80% = same as today). (2) Gate placement sequencing needs explicit documentation. (3) `--gate` mode and `set -uo pipefail` interaction — false non-zero exits possible. (4) `--skip-clarity` flag parsing — cmd_implement uses positional args, not getopts. (5) Mixed format behavior undefined. (6) Dogfooding asymmetry — root skill updated but not template skill.

**Advocate**: Plan has converged after 3 iterations. Concerns moved from structural (iteration 1) to implementation (iteration 2) to edge cases (iteration 3) — correct convergence pattern. All remaining items are code-review-level decisions. Flat-list 80% default is non-regressive and correct. Architecture sound, policy decisions explicit, known limitations acknowledged.

**Synthesis**: Plan is architecturally ready. 5 implementation notes remain — all code-level, none requiring plan changes. Recommend proceeding.

**User Decision**: Revise — incorporate implementation notes directly into the plan.

**Planner Response** (iteration 4):
1. **Gate placement**: Added explicit sequencing note — clarity gate after Gate 1, before step 6 (WIP registration). Documented why this is load-bearing.
2. **`--skip-clarity` flag parsing**: Added code snippet showing flag extraction before positional arg parsing in `cmd_implement()`.
3. **Mixed format behavior**: Added rule — ACs outside any group treated as P1 when groups exist.
4. **`--gate` mode pipefail**: Added explicit pattern — compute critical_count, exit explicitly. Don't rely on pipefail.
5. **Dogfooding**: Fixed skill file paths — template first (`.agentic/lib/agents/claude/skills/`), then sync to root `.claude/skills/`. Both listed.
6. **Journal write advisory**: `--skip-clarity` journal entry uses `|| true` — journal failure doesn't block bypass.
