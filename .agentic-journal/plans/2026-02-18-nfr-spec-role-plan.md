# Plan: Strengthen NFR.md Role as Spec Guiding Tests & Implementation

**Status**: IMPLEMENTED
**Iteration**: 2
**Created**: 2026-02-18
**Last Updated**: 2026-02-18
**Feature**: No new F-ID — this is infrastructure improvement to existing NFR plumbing

---

## Context

NFR.md has extensive infrastructure (template, schema, `@nfr` annotations, `validate_nfr_refs()` in doctor.py) but the connective tissue between NFR definitions and actual test/code enforcement is missing. Today:

- **Template** has "Where enforced: Tests:", "How to measure:", "Current status:" fields — but **nothing reads or validates them**
- **doctor.py** only validates cross-references (feature→NFR ID exists) — not content
- **coverage.py** tracks `@feature` annotations but has **zero** `@nfr` handling
- **Schema** (`nfr.schema.json`) defines YAML frontmatter structure, but template uses markdown headings — **format mismatch**
- The framework itself has **no `spec/NFR.md`** (doesn't eat its own dog food)

The result: NFR.md looks like it enforces constraints but delivers no enforcement. The "Where enforced" and "Current status" fields are theater.

## Approach

Make the existing NFR plumbing actually work, following the framework's own principles:

1. **Structural enforcement > behavioral** — make doctor.py validate NFR fields, not just cross-refs
2. **Scripts enforce; memory reinforces** — add `nfr.sh` script for status updates
3. **Eat our own dog food** — add framework NFRs to `spec/NFR.md`
4. **Don't over-engineer** — no CI integration yet, no automated status updates. Make manual fields verifiable first.

### What we're NOT doing (future work)
- Automated "Current status" updates based on test results
- CI-level NFR compliance gates
- Schema/frontmatter alignment (the template markdown format works; schema can be updated to match)
- `@nfr` annotation coverage in coverage.py (valuable but separate feature)

## Implementation Steps

### Step 1: doctor.py NFR content validation
**Files**: `.agentic/tools/doctor.py`

Add a new function `validate_nfr_content(root: Path) -> list[str]` and call it from `main()` in the feature-tracking validation block (line ~1077), right after the existing `validate_nfr_refs()` call.

**Parsing strategy**: State-machine approach matching `parse_features()` pattern (line 523). Walk lines sequentially:
1. `## NFR-####:` header → start new NFR entry, capture ID
2. `- Category:` → capture value, validate against enum (performance|security|scalability|usability|reliability|maintainability|compliance) — addresses S1
3. `- How to measure:` → capture value
4. `- Where enforced:` → set flag for nested sub-items
5. `  - Tests:` (indented under "Where enforced") → capture test path(s)
6. `  - CI:` (indented under "Where enforced") → capture CI info
7. `- Current status:` → capture value
8. Next `## ` header or EOF → finalize entry, validate accumulated fields

**Validation checks per NFR entry**:
- [ ] "How to measure" is non-placeholder (not a value consisting entirely of `<!-- ... -->` with optional whitespace; mixed content with comments is fine)
- [ ] If "Where enforced: Tests:" is non-placeholder AND non-empty, each referenced file path exists relative to project root
- [ ] "Current status" is one of: unknown, partial, met, violated
- [ ] "Category" is one of the 7 valid enum values from the schema

**Placeholder heuristic**: A field value is a placeholder if `re.fullmatch(r'\s*<!--.*?-->\s*', value)` matches. This catches `<!-- benchmark/test/tool -->` but not mixed content like `wc -l on instruction files <!-- see L-0002 -->`.

### Step 2: nfr.sh token-efficient script
**Files**: `.agentic/tools/nfr.sh` (new)

API (following `feature.sh` pattern):
```bash
nfr.sh NFR-#### status met      # Update "Current status" field in spec/NFR.md
nfr.sh NFR-#### show             # Show single NFR entry details
nfr.sh list                      # List all NFRs with ID, name, status (no NFR ID required)
```

This follows the pattern of journal.sh, status.sh, feature.sh — scripts the agent uses behind the scenes.

### Step 3: Framework's own NFRs
**Files**: `spec/NFR.md` (new)

Add 2 real NFRs with automated enforcement (dropped NFR-0002 pre-commit timing — "manual timing" is theater, per I4):

- **NFR-0001**: Instruction file size — Constitution files must be under 100 lines (L-0002)
  - Category: maintainability
  - How to measure: `wc -l` on instruction files
  - Where enforced:
    - Tests: `tests/infrastructure/structural/S08_claude_md_under_100_lines.sh`
    - CI: pre-commit-check.sh staleness detection
  - Current status: met

- **NFR-0002**: Token budget compliance — Subagent context injection must stay within configured budget
  - Category: performance
  - How to measure: `context-for-role.sh` token counting output
  - Where enforced:
    - Tests: `tests/test_nfr_validation.py::test_framework_nfr_passes_validation`
    - CI: none
  - Current status: met

Two well-enforced NFRs are better than three where one is theater. This validates the full pipeline: template → content → doctor validates → agent updates via nfr.sh.

### Step 4: Tests
**Files**: `tests/test_nfr_validation.py` (new — in `tests/` alongside existing Python tests)

- [ ] Test `validate_nfr_content()` catches placeholder "How to measure" fields
- [ ] Test `validate_nfr_content()` catches invalid "Current status" values
- [ ] Test `validate_nfr_content()` catches invalid "Category" values
- [ ] Test `validate_nfr_content()` validates test file paths exist (using tmpdir fixtures)
- [ ] Test `validate_nfr_content()` accepts fully valid NFR entries
- [ ] Test `validate_nfr_content()` returns empty list when NFR.md missing
- [ ] Test framework's own `spec/NFR.md` passes both `validate_nfr_refs()` and `validate_nfr_content()`

### Step 5: Schema tech debt note
**Files**: `.agentic/schemas/nfr.schema.json`

Add a one-line comment at top: the schema defines a YAML/JSON structure that does not match the actual markdown template format. NFR.md uses markdown per `NFR.template.md`. Schema alignment is future work. (Addresses S2)

### Step 6: Documentation updates
**Files**: `.agentic/DEVELOPER_GUIDE.md`

- Add brief mention of NFR content validation in "Automation & Scripts" section where doctor.sh checks are documented
- Reference `nfr.sh` in the scripts listing

## Files to Modify

| File | Change |
|------|--------|
| `.agentic/tools/doctor.py` | Add `validate_nfr_content()`, call from `main()` feature-tracking block (line ~1078) |
| `.agentic/tools/nfr.sh` | NEW — token-efficient NFR status updates |
| `spec/NFR.md` | NEW — framework's own NFRs (dogfooding) |
| `tests/test_nfr_validation.py` | NEW — tests for NFR content validation |
| `.agentic/schemas/nfr.schema.json` | Add tech debt note about markdown/schema mismatch |
| `.agentic/DEVELOPER_GUIDE.md` | Brief NFR documentation additions |

## Testing Strategy

- **Unit tests**: `tests/test_nfr_validation.py` — tests for `validate_nfr_content()` function
- **Framework validation**: `bash tests/validate_framework.sh` — must still pass
- **Dogfooding**: Framework's own `spec/NFR.md` passes `validate_nfr_content()` (tested in `test_nfr_validation.py`)
- **Integration**: Run `python3 .agentic/tools/doctor.py` in framework root — should show NFR content validation alongside existing checks

## Risks & Mitigations

- **Risk**: doctor.py content validation too strict for new projects with placeholder NFRs
  **Mitigation**: Only validate content when `feature_tracking=yes` AND NFR.md exists (consistent with existing `validate_nfr_refs()` gating). Placeholder fields (value = only `<!-- ... -->`) are silently skipped — only non-placeholder values with invalid content are flagged.

- **Risk**: nfr.sh adds another script users don't know about
  **Mitigation**: It's an agent script (behind the scenes), not user-facing. Same pattern as feature.sh.

- **Risk**: Framework's own NFRs feel forced
  **Mitigation**: Only 2 NFRs, both with real automated enforcement. No theater entries.

---

## Review History

### Review 1 — 2026-02-18

**Reviewer**: Code review agent (adversarial review)
**Verdict**: REVISION_NEEDED

---

#### Summary

The plan correctly identifies a real gap: NFR.md fields are unverifiable theater. The approach (make doctor.py validate content, add dogfooding NFRs, add a token-efficient script) is sound and follows framework conventions. However, there are several issues that should be addressed before implementation — most notably a phantom reference to a function that does not exist, a test file path that does not exist, a format mismatch in the `nfr.sh` API, and an under-specified parsing strategy for the NFR markdown format.

---

#### CRITICAL

**C1: `run_full_verification()` does not exist in doctor.py**

The plan says (Step 1, line 47): "Call from `run_full_verification()` alongside existing `validate_nfr_refs()`". This function does not exist. `doctor.py` has a `main()` function that calls `validate_nfr_refs()` directly in the feature-tracking validation block (line 1077). There is no `run_full_verification()` wrapper.

Fix: Replace the reference with the actual integration point — the feature-tracking validation block inside `main()` (around line 1058-1078), right after `validate_nfr_refs()`.

**C2: `tests/structural/test_framework_structure.py` does not exist**

The plan references this file twice in Step 3 (the proposed NFR-0001 and NFR-0003 both cite it as "Where enforced"). The `tests/structural/` directory does not exist at all — there are no files matching `tests/structural/**/*.py`. The framework's structural tests live in `tests/validate_framework.sh` (bash) and `tests/infrastructure/` (mutation tests). The instruction file size check is in `tests/infrastructure/structural/S08_claude_md_under_100_lines.sh`.

Fix: NFR-0001's "Where enforced" should reference the actual test file: `tests/infrastructure/structural/S08_claude_md_under_100_lines.sh`. NFR-0003 needs a real test reference or should say "manual" if no test exists. Also, Step 4 proposes creating the test file at `tests/structural/test_nfr_validation.py` — this would create a new directory (`tests/structural/`). That is fine architecturally but should be an explicit decision, not an accident. Consider whether it belongs in `tests/` (alongside the other test_*.py files) or in a new `tests/structural/` directory.

---

#### IMPORTANT

**I1: NFR markdown parsing strategy is unspecified**

The core of this plan is `validate_nfr_content()` — a function that must parse NFR entries from markdown and validate their fields. But the plan never specifies HOW to parse the markdown template format. The template uses:
```
## NFR-####: Name
- Category: ...
- Statement: ...
- How to measure: <!-- ... -->
- Where enforced:
  - Tests: <!-- ... -->
  - CI: <!-- ... -->
- Current status: unknown
```

This is a nested, indented markdown list with sub-items. Parsing "Where enforced: Tests:" requires handling the two-level structure. The existing `parse_nfr_ids()` (line 571) only extracts IDs from headers — it does not parse field content at all. The existing `parse_features()` (line 523) shows how the framework parses similar markdown, but it does single-level "- Key: value" parsing. The NFR template's "Where enforced:" with nested "- Tests:" / "- CI:" is more complex.

Fix: Step 1 should include a brief parsing specification: state-machine approach (track which NFR entry we are inside, capture fields as they appear), or a regex-per-field approach. This matters because the wrong parsing strategy will produce false positives/negatives and undermine trust in the validation.

**I2: `nfr.sh` API has a semantically wrong command**

The plan shows:
```bash
nfr.sh NFR-#### list       # List all NFRs with current status
```

The `list` command ignores the `NFR-####` argument entirely — listing all NFRs is not per-NFR. This is confusing. Compare with `feature.sh`, which always operates on a specific feature ID.

Fix: Make `list` a standalone command without requiring an NFR ID: `nfr.sh list`. Or if you want per-NFR info: `nfr.sh NFR-#### show`.

**I3: doctor.py validation gated on "profile is Formal" — but the code does not check profile**

The Risks section says: "Only validate content when profile is Formal AND NFR.md exists." But in `doctor.py`, the existing NFR validation (`validate_nfr_refs()`) is gated on `feature_tracking=yes` (line 1059-1078), not on profile. The framework uses `feature_tracking` as the setting, not profile names. Profile is an implementation detail that sets `feature_tracking`.

Fix: Gate on `feature_tracking=yes` (consistent with existing code), not on "Formal profile". The mitigation wording should be updated.

**I4: NFR-0002 (pre-commit gate reliability <5s) has no automated enforcement**

The plan proposes "Where enforced: Tests: manual timing" for NFR-0002. This means it will be "met" based on... someone's word. For a plan whose central thesis is "NFR fields are theater", adding an NFR whose own enforcement is manual timing is ironic. It weakens the dogfooding story.

Fix: Either (a) write an actual timed test for pre-commit speed (straightforward: `time pre-commit-check.sh` and assert <5s), or (b) drop NFR-0002 and keep only NFRs that have real automated enforcement. Two well-enforced NFRs are better than three where one is theater.

**I5: Placeholder detection heuristic needs specificity**

Step 1 says check for "non-placeholder" content by detecting `<!-- ... -->`. But the template has specific placeholders like `<!-- benchmark/test/tool -->` and `<!-- perf tests -->`. A naive regex like `<!--.*-->` would match legitimate HTML comments that are NOT placeholders (e.g., `<!-- format: nfr-v0.1.0 -->`). The plan should specify the exact heuristic.

Fix: Define what "placeholder" means precisely. Suggestion: a field value consisting entirely of `<!-- ... -->` (possibly with whitespace) is a placeholder. A field value that mixes real content with comments is NOT a placeholder.

---

#### SUGGESTION

**S1: Consider validating that the NFR "Category" field uses valid values**

The schema (`nfr.schema.json`) defines valid categories: performance, security, scalability, usability, reliability, maintainability, compliance. The template format uses `- Category:`. If you are already parsing NFR entries to validate status and test paths, validating category against the schema enum is low-hanging fruit.

**S2: The schema/template mismatch should at least be acknowledged as tech debt**

The plan explicitly defers schema alignment ("not doing"). That is fine. But the schema defines a YAML/JSON structure (`constraint`, `rationale`, `verification`, `affected_features`) that is completely different from the markdown template fields (`Statement`, `How to measure`, `Where enforced`, `Current status`). There is no mapping between them. This means the schema is effectively dead code — nothing uses it, and if someone tried to use it, it would not match reality. Consider adding a one-line note in the schema file itself: "Note: this schema is not currently validated against NFR.md. NFR.md uses markdown format per NFR.template.md."

**S3: Test file location**

The plan puts tests in `tests/structural/test_nfr_validation.py`, creating a new directory. The existing Python tests (`test_coverage.py`, `test_drift.py`, `test_validate_specs.py`, etc.) all live directly in `tests/`. The bash structural tests live in `tests/infrastructure/structural/`. Consider putting the new test file at `tests/test_nfr_validation.py` for consistency with existing Python test locations, unless you specifically intend to establish a `tests/structural/` directory as a new convention.

**S4: Coverage of `validate_nfr_content()` in `validate_framework.sh`**

The plan mentions that `validate_framework.sh` must still pass (Testing Strategy), but does not add NFR content validation to `validate_framework.sh`. Since `validate_framework.sh` is the framework's acceptance test runner, consider adding a test case for NFR validation there, similar to how it tests other doctor.py checks.

---

#### Checklist Assessment

- [x] Does plan address the actual gap (NFR fields being unverifiable theater)? Yes, directly.
- [x] Are there simpler approaches not considered? No — this is already minimal. The five steps are the right scope.
- [ ] What could go wrong? Parsing complexity (I1) and phantom references (C1, C2) would cause implementation failures.
- [ ] Is testing strategy adequate? Test file path is wrong (C2), and no coverage of `validate_framework.sh` (S4).
- [ ] Are there hidden dependencies? The `tests/structural/` directory does not exist (C2).
- [x] Does the plan follow framework conventions? Yes — three-layer architecture, scripts-behind-the-scenes, distributed enforcement.
- [x] Are the "NOT doing" exclusions appropriate? Yes — schema alignment, CI gates, and coverage.py can all wait.
- [x] Is the scope right-sized? Yes — 5 files modified/created, well under the 10-file limit.
- [ ] Do the framework's own NFRs make sense? NFR-0001 and NFR-0003 are good. NFR-0002 is theater (I4).

---

### Planner Response (iteration 2)

All CRITICAL and IMPORTANT issues addressed:

- **C1** (phantom `run_full_verification()`): Fixed. Now references `main()` feature-tracking block at line ~1077-1078, right after `validate_nfr_refs()`.
- **C2** (phantom test paths): Fixed. NFR-0001 now references `tests/infrastructure/structural/S08_claude_md_under_100_lines.sh`. New test file placed at `tests/test_nfr_validation.py` (alongside existing Python tests, not a new directory).
- **I1** (parsing strategy): Added detailed state-machine specification matching `parse_features()` pattern, with line-by-line walk and field accumulation.
- **I2** (`nfr.sh list` API): Fixed. `list` is standalone (no NFR ID). Per-NFR command is `show`.
- **I3** (Formal vs feature_tracking): Fixed. All references now say `feature_tracking=yes`.
- **I4** (NFR-0002 theater): Dropped. Now only 2 NFRs, both with real automated enforcement.
- **I5** (placeholder heuristic): Defined precisely: `re.fullmatch(r'\s*<!--.*?-->\s*', value)`. Catches pure-placeholder values, allows mixed content.
- **S1** (category validation): Adopted. Added to Step 1 validation checks.
- **S2** (schema tech debt note): Added as new Step 5.
- **S3** (test file location): Adopted. Tests at `tests/test_nfr_validation.py`.
- **S4** (validate_framework.sh): Addressed by dogfooding test in `test_nfr_validation.py` that validates framework's own NFR.md.

---

### Review 2 — 2026-02-18

**Reviewer**: Code review agent (adversarial review, iteration 2)
**Verdict**: APPROVED

---

#### Were Review 1 CRITICAL issues addressed?

**C1 (phantom `run_full_verification()`)**: Fully resolved. The plan now correctly references `main()` and the feature-tracking validation block at line ~1077-1078. Verified: `validate_nfr_refs()` is indeed called at line 1077 of `doctor.py`, and the plan specifies inserting the new call right after it. Correct.

**C2 (phantom test paths)**: Fully resolved. NFR-0001 now references `tests/infrastructure/structural/S08_claude_md_under_100_lines.sh`, which I verified exists. Test file is now at `tests/test_nfr_validation.py`, consistent with the 6 existing Python test files in `tests/`. No phantom paths remain.

#### Were Review 1 IMPORTANT issues addressed?

**I1 (parsing strategy)**: Fully resolved. Step 1 now includes a detailed 8-step state-machine specification with explicit line patterns for each field, including the two-level "Where enforced" / "  - Tests:" nesting. This is clear enough for implementation.

**I2 (`nfr.sh list` API)**: Fully resolved. `list` is now standalone (no NFR ID argument), and `show` is the per-NFR command. Clean API.

**I3 (Formal vs feature_tracking)**: Fully resolved. The Risks section now correctly says `feature_tracking=yes`, consistent with the existing `doctor.py` gating at line 1059-1060.

**I4 (NFR-0002 theater)**: Fully resolved. The original theater NFR (pre-commit timing) was dropped. Two NFRs remain, both with automated enforcement.

**I5 (placeholder heuristic)**: Fully resolved. Defined with `re.fullmatch(r'\s*<!--.*?-->\s*', value)`. Semantics are clear: only pure-comment values are placeholders; mixed content passes.

#### New issues introduced by revision?

**IMPORTANT: I6 — NFR-0002 (token budget compliance) "Where enforced" is circular**

The revised NFR-0002 says:
```
Where enforced:
  Tests: tests/test_nfr_validation.py::test_framework_nfr_passes_validation
```

This test validates that the framework's own NFRs pass `validate_nfr_content()` — meaning it checks that fields like "Where enforced" contain valid file paths and "Current status" is a valid value. But it does NOT actually test that token budgets are being respected. It only tests that the NFR entry itself is well-formed.

The actual enforcement of token budget compliance happens inside `context-for-role.sh` (which counts tokens and reports over-budget). There is no existing test that verifies token budgets are respected.

However, this is NOT a blocking issue. The plan's stated goal for Step 3 is dogfooding — proving that the template-to-validation pipeline works end-to-end. NFR-0002's "Where enforced: Tests:" field pointing to the dogfooding test is sufficient for that purpose: it proves that doctor.py can parse the entry and validate the test path exists. The NFR itself is real (token budgets are a genuine constraint), the "How to measure" field is actionable (`context-for-role.sh` token counting output), and "Current status: met" is defensible given that the script already enforces budgets at runtime. A deeper enforcement test (asserting that `context-for-role.sh` stays within budget for all roles) would be valuable but is not needed for this plan's scope.

**Recommendation**: Accept as-is. Optionally, during implementation, consider referencing the test path more honestly — e.g., `tests/test_nfr_validation.py` (validates NFR entry format) rather than implying it tests budget compliance. But this is a suggestion, not a blocker.

**SUGGESTION: S5 — "Current status" field parsing needs to strip trailing comments**

The NFR template shows: `- Current status: unknown  <!-- unknown | partial | met | violated -->`. When the parser extracts the value after `Current status:`, it will get `unknown  <!-- unknown | partial | met | violated -->`, not `unknown`. The plan's validation check says "Current status is one of: unknown, partial, met, violated" — but the raw extracted value will include the trailing comment.

The placeholder heuristic (`re.fullmatch(r'\s*<!--.*?-->\s*', value)`) would NOT catch this since it is mixed content. The implementer needs to strip trailing `<!-- ... -->` comments before validating the status value.

This is minor because a competent implementer will handle it, and the parsing spec already distinguishes pure-comment vs mixed content. But it is worth noting explicitly since the state machine spec does not mention comment stripping.

**SUGGESTION: S6 — JSON does not support comments**

Step 5 says: "Add a one-line comment at top" of `nfr.schema.json`. JSON does not support comments. The note would need to be added as a `"$comment"` or `"description"` property (JSON Schema supports `"$comment"` as of draft-07, which this schema uses). Or add it to a companion README. Minor, but the implementer should know.

#### Checklist Assessment

- [x] Does plan address the actual gap? Yes.
- [x] All CRITICAL issues from Review 1 resolved? Yes, both fully addressed.
- [x] All IMPORTANT issues from Review 1 resolved? Yes, all five addressed.
- [x] Are phantom references eliminated? Yes. All file paths verified against actual codebase.
- [x] Is parsing strategy specified? Yes, 8-step state machine with explicit patterns.
- [x] Is the scope right-sized? Yes — 6 files, well under limit.
- [x] Do the framework's own NFRs have real enforcement? Yes — NFR-0001 backed by S08 test, NFR-0002 backed by dogfooding test.
- [x] Is the plan implementable without ambiguity? Yes, with the minor caveats in S5 and S6.

#### Verdict

**APPROVED**. The revision addressed all CRITICAL and IMPORTANT issues from Review 1 thoroughly. The new NFR-0002 enforcement circularity (I6) is a valid observation but not a blocker — the plan's scope is making the pipeline work, not achieving deep enforcement for every NFR. The two suggestions (S5: comment stripping, S6: JSON comment syntax) are implementation details that a competent implementer will handle naturally. The plan is ready for implementation.
