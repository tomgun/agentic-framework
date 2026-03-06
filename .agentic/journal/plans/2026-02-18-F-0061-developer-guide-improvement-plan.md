# Plan: F-0134 DEVELOPER_GUIDE.md Improvement

**Status**: APPROVED
**Iteration**: 2
**Created**: 2026-02-18
**Last Updated**: 2026-02-18

---

## Context

The DEVELOPER_GUIDE.md (2172 lines, version footer says v0.19.0) has drifted from the current framework (v0.27.0). The core problem: **it speaks to users as if they're agent operators**, telling them to "run `ag implement F-XXXX`" when they don't know feature numbers. Scripts should work behind the scenes; the guide should use natural workflow language.

This work is tracked under **F-0134** (DEVELOPER_GUIDE Rewrite — User-First Framing). F-0061 covers the guide's existence; F-0134 covers the audience reframing specifically.

## Approach

Targeted edits across all 10 sections. The guide's **structure is sound** (10 sections, logical flow). The problem is content, not organization.

Two commits:
1. **Commit 1 — Mechanical fixes**: Stale URLs, version footer, deprecated notices, NFR references, missing commands in table
2. **Commit 2 — Audience reframing**: F-XXXX rewrites, natural language prompts, command table restructuring, quality_checks.sh clarification, pre-commit hook update

### Guiding Principle for F-XXXX References

There are 88 occurrences of `F-\d{4}` in DEVELOPER_GUIDE.md. Not all are wrong. The distinction:
- **User-instruction context** (REWRITE): "Run `ag implement F-0005`" — user doesn't know the ID -> rewrite as natural language prompt
- **Reference/example context** (KEEP): "The agent will run `ag implement F-0005` behind the scenes" or "In Formal profile, features are tracked with IDs like F-0005"
- **Formal workflow examples** (KEEP): Showing what the Formal profile looks like is legitimate — just frame it as "if you use feature tracking" not as a universal instruction
- **Manual spec editing** (KEEP): Section 5 shows users directly editing FEATURES.md — F-IDs are correct here because users are working with specs directly

## Problems to Fix

1. **Wrong audience framing** — 88 occurrences of `F-\d{4}`; many in user-instruction context where users don't have feature IDs
2. **Stale install URLs** — `v0.13.0` / `agentic-framework-0.12.0` at lines 106-107, 1268-1271, 1725-1726 (3 locations). Use `v<VERSION>` placeholder with note to check GitHub releases, to prevent recurring drift.
3. **Missing v0.25+ commands** — `ag sync`, `ag plan`, `ag set`, `ag specs` not in the main command table (lines 30-38)
4. **Deprecated tool documented** — `continue_here.py` notice (line 632). Reduce to one-liner "superseded by STATUS.md" rather than full removal.
5. **Version footer** — says 0.19.0, should be 0.27.0
6. **Pre-commit hook outdated** — shows manual `.git/hooks/pre-commit` (line 2029-2032), framework uses `core.hooksPath` + `ag hooks install` since v0.25.6
7. **`quality_checks.sh` confusion** — Two different things conflated: (a) user-created project-specific quality scripts (documented correctly in Customization, lines 1450-1501), (b) references to `quality_checks.sh` as if it exists out of the box (lines 202, 2024, 2031, 2086 — these should note user must create it or reference `pre-commit-check.sh`)
8. **Stale NFR references** — lines 642 and 1676 reference NFR.md which was removed. Line 680 uses "NFRs" as a concept (what doctor.sh checks) — leave as-is.
9. **"Essential Agent Prompts"** (lines 2119-2142) — every example uses F-XXXX

## Implementation Steps

### Commit 1: Mechanical Fixes

**2. "Getting Started" (lines 98-137)**
- [ ] Fix install URLs: `v0.13.0` -> `v<VERSION>` with note "replace with current version from [GitHub releases](https://github.com/user/agentic-framework/releases)", folder name `0.12.0` -> `<VERSION>`

**5a. "Automation & Scripts" (lines 619-1298)**
- [ ] Line 632: reduce `continue_here.py` notice to one-liner: "Superseded by STATUS.md — delete if found in your project"
- [ ] Line 642: update NFR reference (NFR.md was removed)
- [ ] Fix stale install URL at lines 1268-1271 (same pattern as above)

**7. "Troubleshooting" (lines 1593-1727)**
- [ ] Fix stale install URL at lines 1725-1726
- [ ] Line 1676: fix NFR.md reference ("Consider splitting large files (FEATURES.md)" — remove NFR.md)

**10. "Quick Reference" (lines 2075-2142)**
- [ ] Update version footer: 0.19.0 -> 0.27.0, date -> 2026-02-18

### Commit 2: Audience Reframing

**1. "How You Help the Framework" (lines 22-96)**
- [ ] Expand `ag` command table: add `ag sync`, `ag plan`, `ag set`, `ag specs`
- [ ] Split into: "Commands you use" (`ag start`, `ag status`, `ag verify`, `ag set`, `ag sync`) vs "Commands the agent uses" (`ag implement`, `ag commit`, `ag done`, `ag plan`)
- [ ] Rewrite "Prompts That Help" — natural language (e.g. "Let's work on the CSV export feature" instead of "Run ag implement F-XXXX")
- [ ] Rewrite "Profile-Aware Commands" — user says what they want, agent picks the right command

**3. "Daily Workflows" (lines 139-227)**
- [ ] Rewrite "During: Development Work" — all 3 options as natural prompts
- [ ] Line 202: clarify that `quality_checks.sh` is user-created, not a framework built-in
- [ ] Lines 222-226 "Evening: Wrap Up": this is the "Working Manually" subsection — manual git workflow IS valid here. Fix only the F-0005 reference in the commit message example (use a descriptive example without feature ID). Keep raw git commands since this section is for users working without the agent.

**4. "Working with Agents" (lines 230-441)**
- [ ] Lines 354-362 ("Effective Agent Prompts"): rewrite all 4 "good prompt" examples to natural language
- [ ] Lines 372-394 (Sequential pipeline example): keep F-IDs in context of explaining Formal workflow, but add framing "If you use feature tracking..."
- [ ] Lines 419-435 (Multi-agent worktree): F-IDs OK here — explaining technical mechanism

**5b. "Manual Operations" (lines 444-616)**
- [ ] Lines 547-549: rewrite "Tell agent" prompt — user already created the spec manually, so the F-ID is known and correct here. BUT reframe from imperative "I've added F-0010..." to natural "I've added a CSV export feature to the spec. Please implement it using TDD." The agent will find the F-ID from FEATURES.md.
- [ ] Lines 591-592: same treatment — "I updated the acceptance criteria for CSV export" instead of referencing F-0005
- [ ] Lines 599-611 (grep examples): these are legitimate reference/power-user context — user is grepping spec files. F-IDs are correct. Leave as-is but add brief framing: "These examples use feature IDs from your spec files:"

**6. "Customization" (lines 1300-1590)**
- [ ] No changes needed — already aligned with v0.27.0 settings architecture (`ag set`, profiles-as-presets, resolution order, constraint rules)
- [ ] Lines 1450-1501: `quality_checks.sh` is CORRECTLY documented as user-created here

**7b. "Troubleshooting"**
- [ ] Lines 1698-1706: clarify `quality_checks.sh` is user-created, not a framework built-in script

**8. "Best Practices" (lines 1731-1876)**
- [ ] "4. Use Feature IDs Consistently" — add framing: "If you use Formal profile with feature tracking..."
- [ ] "7. Use Brief Context Loads" — use natural description instead of F-0005
- [ ] Line 1856: clarify `quality_checks.sh` context

**9. "Advanced Topics" (lines 1879-2072)**
- [ ] Lines 2027-2032: replace manual `.git/hooks/pre-commit` with `ag hooks install` and `core.hooksPath` explanation
- [ ] Lines 2024, 2031: clarify `quality_checks.sh` vs framework hooks

**10b. "Quick Reference"**
- [ ] Rewrite "Essential Agent Prompts" (lines 2119-2142): natural language, no F-XXXX in user prompts
- [ ] Line 2086: fix `quality_checks.sh` reference

### Housekeeping (with Commit 2)

- [ ] Update FEATURES.md summary table — currently shows 0 Planned but F-0132, F-0133, F-0134 are all `planned`. Fix counts.
- [ ] Update STATUS.md to track F-0134 correctly (not "created in error")

## Files to Modify

1. `.agentic/DEVELOPER_GUIDE.md` — targeted edits across all 10 sections (~200 lines changed, split across 2 commits)
2. `spec/FEATURES.md` — fix summary table counts only (keep F-0134)
3. `STATUS.md` — update current session state

## Testing Strategy

1. `bash tests/validate_framework.sh` passes
2. `grep "v0.13.0\|agentic-framework-0.12" .agentic/DEVELOPER_GUIDE.md` -> 0 matches
3. `grep "continue_here.py" .agentic/DEVELOPER_GUIDE.md` returns at most 1 match (the one-liner migration note)
4. `grep "NFR.md" .agentic/DEVELOPER_GUIDE.md` -> 0 matches
5. `grep -n "Run ag implement\|Tell.*F-[0-9]" .agentic/DEVELOPER_GUIDE.md` -> 0 matches (no user instructions that reference feature IDs as if users know them)
6. Version footer says 0.27.0
7. `ag sync`, `ag plan`, `ag set` appear in the main command table
8. FEATURES.md summary table counts are accurate

## Risks & Mitigations

- **Risk**: Over-editing breaks useful examples
  Mitigation: Targeted edits only, keep Formal workflow examples that are properly framed
- **Risk**: Removing all F-XXXX references loses documentation of how Formal profile works
  Mitigation: Distinction between user-instruction (rewrite) vs reference/example (keep) contexts
- **Risk**: quality_checks.sh edits confuse things further
  Mitigation: Clear "user-created" framing where appropriate, reference `pre-commit-check.sh` for framework hooks
- **Risk**: Install URLs go stale again
  Mitigation: Use `v<VERSION>` placeholder pattern with note to check releases page

---

## Review History

### Review 1 (2026-02-18) - iteration 1
**Reviewer**: plan-reviewer-agent

**Issues Found**:

- [x] CRITICAL: **F-0134 removal is the wrong call.** F-0061 covers the guide's existence; F-0134 covers the rewrite. Keep F-0134.
- [x] CRITICAL: **F-XXXX count is wrong (88 not 98).** Corrected to 88.
- [x] IMPORTANT: **"Single commit" scope is too large.** Split into 2 commits: mechanical fixes + audience reframing.
- [x] IMPORTANT: **Section 6 already v0.27.0-aligned.** Noted explicitly — no changes needed.
- [x] IMPORTANT: **NFR.md reference at line 680 doesn't exist.** Corrected: only lines 642 and 1676 need edits. Line 680 is concept, not file reference.
- [x] IMPORTANT: **Evening "Wrap Up" section handling is ambiguous.** Decided: manual git is valid in "Working Manually" section. Fix only the F-0005 reference.
- [x] IMPORTANT: **FEATURES.md summary table is already wrong.** Added fix for Planned counts.
- [x] SUGGESTION: **Use dynamic version in install URLs.** Adopted `v<VERSION>` placeholder pattern.
- [x] SUGGESTION: **Keep brief continue_here.py migration note.** Reduced to one-liner instead of full removal.
- [x] SUGGESTION: **Add negative grep test for F-XXXX in user-instruction context.** Added to testing strategy.
- [x] SUGGESTION: **Plan misses Section 5 "Manual Operations".** Added as Section 5b with analysis of which F-IDs to keep vs rewrite.

**Verdict**: REVISION_NEEDED

**Planner Response** (iteration 2):
- All 11 issues addressed. F-0134 kept as the tracking feature. Count corrected to 88. Plan split into 2 commits. Section 5 "Manual Operations" added. Evening section kept as manual workflow with F-0005 fix only. FEATURES.md table fix added. Dynamic version URLs adopted. continue_here.py reduced to one-liner. Negative grep test added. Section 6 explicitly noted as already aligned.

---

### Review 2 (2026-02-18) - iteration 2
**Reviewer**: plan-reviewer-agent

**Issues Found**:

- [ ] IMPORTANT: **FEATURES.md fix is underscoped — individual entries stale, not just summary table.** The plan says "fix summary table counts only" (line 108, 114), but F-0132 and F-0133 individual entries still say `Status: planned` despite being shipped (PRs #32 and #33 merged). The summary table will be wrong even if you fix its numbers but don't update the individual feature statuses to `shipped`. Fix: in the Housekeeping step, also update F-0132 and F-0133 status fields from `planned` to `shipped` (with `Since:` version), or at minimum note this as a prerequisite the implementer must handle.

- [ ] IMPORTANT: **Section 5b line 547-549 treatment is self-contradictory.** The plan says "the F-ID is known and correct here" but then says "reframe from imperative 'I've added F-0010...' to natural 'I've added a CSV export feature to the spec.'" — the current text at line 549 already reads `"I've added F-0010 to FEATURES.md. Please implement it using TDD."` which is mostly natural language and the user DID just create the spec manually (so they DO know the F-ID). The plan's proposed rewrite (`"I've added a CSV export feature to the spec. Please implement it using TDD."`) removes useful specificity without solving a real problem. The user literally just typed `F-0010` into FEATURES.md 20 lines above. Suggestion: keep the F-ID in this prompt (the user knows it — they just created it), or at most make both forms equivalent examples ("I've added F-0010" or "I've added a CSV export feature").

- [ ] SUGGESTION: **F-0134 acceptance criterion "Quick start section that gets a user productive in <2 minutes of reading" has no plan coverage.** The F-0134 "Should have" criteria include this item. The plan's Commit 2 restructures the command table and rewrites prompts, but doesn't explicitly address making a quick-start path. This may already be satisfied by the existing Section 2 ("Getting Started") which is compact, but the plan should note this explicitly rather than leaving it implicit. Low risk since the guide already has a short Getting Started section.

- [ ] SUGGESTION: **F-0134 acceptance criterion "Table of contents / navigation is coherent after restructure" is not in testing strategy.** The plan's testing strategy (lines 119-127) has 8 grep/validation checks but none verify the ToC is still accurate after edits. Since the plan doesn't change section names or order, this is low risk — but worth a manual check step.

- [ ] SUGGESTION: **Line 190 ("Then tell agent: 'I've added F-0010. Please implement it using TDD.'") in Section 3 is the same pattern as line 549 in Section 5b.** The plan handles Section 3 lines 222-226 but doesn't mention line 190. This is the same "user just created spec manually so they know the F-ID" context. Should be treated consistently with Section 5b.

**Verification of Review 1 Issue Resolution**:

All 11 issues from Review 1 were verified as actually addressed:
1. F-0134 kept (confirmed in plan context, lines 14-15) -- VERIFIED
2. F-XXXX count corrected to 88 (confirmed via `grep -c` = 88) -- VERIFIED
3. Split into 2 commits (lines 20-22) -- VERIFIED
4. Section 6 explicitly noted as no-change (line 87-88) -- VERIFIED
5. NFR.md line 680 left as concept reference (line 42) -- VERIFIED (line 680 says "Broken links to features/NFRs/ADRs" — concept, not file ref)
6. Evening section kept as manual workflow with F-0005 fix only (line 74) -- VERIFIED
7. FEATURES.md table fix added (line 108) -- VERIFIED (but underscoped — see IMPORTANT above)
8. Dynamic version URLs adopted (lines 35, 49, 137) -- VERIFIED
9. continue_here.py reduced to one-liner (line 52) -- VERIFIED
10. Negative grep test added (line 123) -- VERIFIED
11. Section 5 Manual Operations added (lines 81-84) -- VERIFIED

**Commit split assessment**: The 2-commit boundary is clean. Commit 1 (mechanical: stale URLs, deprecated notices, NFR refs, version footer) is purely factual corrections. Commit 2 (audience reframing: command table, natural language prompts, quality_checks.sh clarification, pre-commit hook) is all about the voice/framing shift. No overlap.

**Section 5b F-ID keep/rewrite decisions**: Mostly sound. Lines 599-611 (grep examples with F-IDs) correctly kept as power-user reference. Lines 591-592 rewrite is reasonable. Lines 547-549 treatment is the one debatable call (see IMPORTANT above).

**Verdict**: APPROVED

**Notes**: The plan is solid and ready for implementation. The two IMPORTANT issues are real but neither is a blocker: (1) the FEATURES.md individual entry staleness is a pre-existing problem that should be fixed while touching that file anyway — the implementer just needs to know about it; (2) the Section 5b line 549 treatment is a judgment call where either approach works. The plan correctly identifies the core problem (wrong audience framing), has a clear guiding principle for F-XXXX keep/rewrite decisions, and the 2-commit split is well-reasoned. No new issues were introduced by the revision. All 11 Review 1 issues were genuinely addressed.
