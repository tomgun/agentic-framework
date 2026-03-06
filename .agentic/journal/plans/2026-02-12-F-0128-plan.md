# F-0128: Specs-Before-Code Structural Enforcement — Implementation Plan

**Status**: APPROVED
**Created**: 2026-02-12
**Feature**: F-0128
**Revision**: 3

---

## Root Cause Analysis

The core question: why did an agent implement 3 features (ag sync, discoverability reminders, tip of the day) without writing acceptance criteria first, despite multiple instructions saying to do so?

**Finding 1: The trigger table sends the agent to `ag plan`, which checks for specs — but the agent can skip `ag plan` entirely.**

The CLAUDE.md trigger table says:
```
Build / implement / add / create ... | STOP -> Run `ag plan F-XXXX` first, then `ag implement`
```

The problem: `ag plan` does check for acceptance criteria (line 412 in ag.sh — hard gate, exits on failure). But the trigger table assumes the agent will (a) have a feature ID, and (b) actually run `ag plan`. When a user says "add a tip of the day", the agent has no F-XXXX ID yet, so it cannot run `ag plan F-XXXX`. The trigger becomes inapplicable, and the agent falls through to just coding.

**Finding 2: `ag work` has NO spec gate — it is intentionally spec-free.**

`cmd_work()` only starts WIP tracking and prints a blue reminder: `"Reminder: Define acceptance criteria (in any form) before implementing."` This is purely behavioral — a polite suggestion that is trivially ignored. The `ag work` command was designed for "Core" profile where specs are optional. But in a Core+PM project, an agent can use `ag work "desc"` instead of `ag implement F-XXXX` and bypass all spec gates entirely.

**Finding 3: There is no structural check that blocks coding without specs — the only gates are at command entry points.**

If the agent never runs `ag plan` or `ag implement` (e.g., it just starts editing files), there is zero enforcement. The gates are opt-in: they only fire if the agent remembers to invoke them.

**Finding 4: The pre-commit hook checks if SHIPPED features have acceptance files — but NOT if the agent bypassed the workflow.**

If new code is committed for a feature that hasn't been registered in FEATURES.md yet, nothing catches it. The commit gate only checks "are shipped features missing acceptance files?" — not "did you use the workflow at all?"

**Finding 5: Memory-seed doesn't mention acceptance criteria explicitly.**

The memory-seed "When the user wants to build something" section says `STOP. Run ag plan F-XXXX first` — which implies specs exist (because `ag plan` checks). But it never says "write acceptance criteria FIRST" as a standalone imperative. If the agent can't run `ag plan` (no feature ID), the memory-seed provides no fallback instruction about creating specs.

**Finding 6: The "happy path" assumes a feature ID is known upfront.**

The entire framework workflow assumes: user says "implement F-0042" → agent runs `ag plan F-0042` → gate checks for `spec/acceptance/F-0042.md` → agent proceeds. But the common real-world path is: user says "add a dark mode toggle" → agent has no feature ID → agent skips the entire pipeline and just codes.

**What already works (acknowledged):**
- `cmd_plan()` has a hard gate at line 412 — exits with error if acceptance criteria don't exist
- `cmd_implement()` calls `doctor.sh --phase planning` which checks for acceptance criteria and FEATURES.md registration (via `doctor.py` line 728+)
- The gap is NOT in `ag plan` or `ag implement` — those work. The gap is in the `ag work` path and the "no ag command at all" path.

## Gap Classification

| Gap | Type | Severity |
|-----|------|----------|
| `ag work` has no spec gate in Core+PM | Structural | High |
| Agent can code without running any `ag` command | Structural | High |
| Pre-commit doesn't detect workflow bypass | Structural | Medium |
| Trigger table assumes feature ID exists | Behavioral | High |
| Memory-seed doesn't mention acceptance criteria explicitly | Behavioral | Medium |
| `cmd_implement()` calls `doctor.sh --phase planning` with `|| true` (advisory, not blocking) | Structural | Medium |

## Proposed Fixes

### Fix 1: Make `ag work` a hard block in Core+PM (STRUCTURAL)

**File**: `.agentic/tools/ag.sh` — `cmd_work()` function

When running in Core+PM profile, `ag work` should refuse to start, period:
```
BLOCKED: Core+PM profile requires a feature ID with acceptance criteria.

To start:
  1. Add feature to spec/FEATURES.md (next available F-XXXX)
  2. Create spec/acceptance/F-XXXX.md with acceptance criteria
  3. Run: ag implement F-XXXX

Core profile users: ag work is available without feature IDs.
```

No escape hatch. No `--ack-no-spec`. No deviation log. If the user needs exploratory work without specs, the Core profile exists for that. Creating a spec is fast — it's a markdown file.

### Fix 2: Pre-commit "workflow bypass" check (STRUCTURAL)

**File**: `.agentic/hooks/pre-commit-check.sh`

Add a new check: "Did you use the workflow?" Detection logic:
1. Only triggers for Core+PM profile
2. Only triggers when new files are added (`git status A`) in implementation directories
3. Only triggers when there is NO active WIP tracking with a feature ID (`.agentic-state/WIP.md` doesn't exist or doesn't contain an F-XXXX ID)

This checks "did the agent bypass `ag implement`?" rather than trying to map files to features. A warning, not a block — catch-all safety net.

### Fix 3: CLAUDE.md trigger table — one-line specs-first (BEHAVIORAL)

**Files**: `CLAUDE.md` (root) and `.agentic/agents/claude/CLAUDE.md` (template)

Change the "Build" trigger to a single scannable line:
```
Build / implement / add / create ... | STOP -> If no F-XXXX: create spec/acceptance/F-XXXX.md FIRST, then `ag plan` + `ag implement`. Never code before specs.
```

Detailed multi-step instructions go in memory-seed.md and auto_orchestration.md where there's room.

### Fix 4: Memory-seed — add explicit acceptance criteria imperative (BEHAVIORAL)

**File**: `.agentic/init/memory-seed.md`

In the "When the user wants to build something" section, add:

```
If no feature ID exists yet: assign one (next available F-XXXX in spec/FEATURES.md), create spec/acceptance/F-XXXX.md with acceptance criteria, THEN run `ag plan F-XXXX`.

Never write implementation code before acceptance criteria exist. This is a structural rule, not a suggestion.
```

This is where the detailed multi-step instructions live (not in the trigger table).

### Fix 5: Make `cmd_implement()` doctor check blocking (STRUCTURAL)

**File**: `.agentic/tools/ag.sh` — `cmd_implement()` function

Change line 589 from:
```bash
bash "$SCRIPT_DIR/doctor.sh" --phase planning "$feature_id" 2>/dev/null || true
```
To:
```bash
if ! bash "$SCRIPT_DIR/doctor.sh" --phase planning "$feature_id" 2>/dev/null; then
    echo -e "${RED}BLOCKED: Planning phase checks failed. Fix issues above.${NC}"
    exit 1
fi
```

One-line semantic change: `doctor.sh --phase planning` already exists and works (via `doctor.py`). Just make it blocking instead of advisory.

### Fix 5b: Make `ag implement` enforce plan-review when enabled (STRUCTURAL)

**File**: `.agentic/tools/ag.sh` — `cmd_implement()` function, section 0b

Currently the plan-review check in `cmd_implement()` (lines 538-559) only fires when `plan_review_auto_for` includes "implement" or "both". When `plan_review_enabled: yes` but `auto_for: [planning]`, `ag implement` skips the plan check entirely — meaning an agent can skip `ag plan` and go straight to `ag implement` without ever entering the plan-review loop.

Fix: When `plan_review_enabled: yes`, ALWAYS check for an approved plan in `ag implement`. Make it a hard block (not just yellow warnings):
- If no plan file exists → BLOCKED, run `ag plan F-XXXX` first
- If plan exists but not APPROVED → BLOCKED, complete the review loop

This closes the loop: agents can't skip `ag plan` by jumping to `ag implement`.

### Fix 6: Auto-orchestration — reinforce specs-first at pipeline entry (DOCUMENTATION)

**File**: `.agentic/agents/shared/auto_orchestration.md`

Add a bold callout before the Feature Pipeline:

```
**CRITICAL PRE-CONDITION (Core+PM)**: If the user describes a feature without a feature ID:
1. Assign the next available F-XXXX ID in spec/FEATURES.md
2. Create spec/acceptance/F-XXXX.md with acceptance criteria
3. THEN proceed with the pipeline below

Do NOT proceed to IMPLEMENT without completing VERIFY ACCEPTANCE CRITERIA EXIST.
```

### Fix 7: New LLM behavioral test (TESTING)

**File**: New test `tests/llm/tests/050_specs_before_code_no_fid.sh`

Test scenario: In a Core+PM project, user says "add a tip of the day feature" (no feature ID). Verify:
1. Agent does NOT immediately write implementation code.
2. Agent either creates or asks about acceptance criteria.
3. Agent assigns/proposes a feature ID.
4. Agent mentions `ag plan` or `ag implement`.

This directly tests the failure mode that occurred.

## Implementation Sequence

1. **Fix 5**: Make `cmd_implement()` doctor check blocking (one-line change, unblocks nothing but quick win)
2. **Fix 1**: `ag work` hard block in Core+PM — biggest structural gap
3. **Fix 2**: Pre-commit workflow bypass check — catch-all safety net
4. **Fix 3**: CLAUDE.md trigger table update — behavioral fix
5. **Fix 4**: memory-seed.md update — behavioral reinforcement
6. **Fix 6**: auto_orchestration.md update — documentation
7. **Fix 7**: LLM behavioral test — verification
8. Run `tests/validate_framework.sh` — ensure 184+ checks still pass

Fixes 3-6 can be done in parallel. Fix 7 should be written to verify fixes 1-2.

**Acceptance criteria amendment**: The "session start greeting reminds about specs-first" criterion has been removed from `spec/acceptance/F-0128.md` with justification: structural gates (Fixes 1, 2, 5) make text reminders redundant, and adding per-session behavioral reminders is the exact failure mode this feature addresses. Enforcement, not reminding.

## Files Changed

| File | Change Type | Size |
|------|-------------|------|
| `.agentic/tools/ag.sh` | Modify `cmd_work()`, `cmd_implement()` | ~25 lines |
| `.agentic/hooks/pre-commit-check.sh` | Add workflow bypass check | ~30 lines |
| `CLAUDE.md` | Update trigger table (one line) | ~2 lines |
| `.agentic/agents/claude/CLAUDE.md` | Update trigger table (one line) | ~2 lines |
| `.agentic/init/memory-seed.md` | Add acceptance criteria imperative | ~10 lines |
| `.agentic/agents/shared/auto_orchestration.md` | Add pre-condition callout | ~10 lines |
| `tests/llm/tests/050_specs_before_code_no_fid.sh` | New test | ~35 lines |
| `tests/llm/test_definitions.json` | Register new test | ~10 lines |

Total: ~8 files, ~125 lines. Simpler than revision 1.

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| `ag work` block too strict for Core+PM exploratory work | Core profile exists for exploratory work; creating a spec is fast (markdown file) |
| Pre-commit check false positives | Only triggers when WIP tracking is missing AND new files added — narrows to workflow bypass |
| Agents ignore updated trigger table | Structural gates (Fix 1, 2, 5) don't depend on agent compliance |

## Key Insight

The fundamental design problem is that all current spec enforcement is **opt-in** — it only works if the agent voluntarily runs the right `ag` command. Two entry points lack gates: `ag work` in Core+PM, and "no ag command at all."

The existing gates work fine: `ag plan` hard-blocks without specs, `ag implement` runs `doctor.sh --phase planning`. The fixes close the remaining gaps:
- **Layer 1 (Behavioral)**: Clearer trigger table + memory-seed + docs (Fixes 3, 4, 6)
- **Layer 2 (Structural entry)**: Hard block on `ag work` in Core+PM + blocking doctor check in `ag implement` (Fixes 1, 5)
- **Layer 3 (Structural exit)**: Pre-commit workflow bypass detection (Fix 2)
- **Layer 4 (Verification)**: LLM behavioral test (Fix 7)

---

## Review History

### Review 1 (2026-02-12) — iteration 1
**Reviewer**: Claude Opus 4.6 (reviewer agent)

**Overall Assessment**: The root cause analysis is strong and the defense-in-depth layering is the right architecture. However, there is one factual error, one design problem that could undermine the entire feature, and several over-engineering concerns that need addressing before implementation.

**Issues Found**:

- [ ] CRITICAL: **Finding 6 is factually wrong — `doctor.sh --phase planning` is NOT phantom.** The plan states that `doctor.sh` has no `--phase` flag and silently no-ops. This is incorrect. `doctor.sh` is a thin wrapper that passes all arguments to `doctor.py`, which fully implements `--phase planning` (see `doctor.py` line 728+). It checks for acceptance criteria existence and FEATURES.md registration. The `2>/dev/null || true` in `ag.sh` line 589 suppresses errors but does NOT make the gate phantom — the code runs and prints issues. Fix 5 proposes implementing something that already exists. **Action**: Remove Finding 6 and Fix 5 entirely. Instead, the real issue is that `cmd_implement()` calls `doctor.sh --phase planning` with `|| true`, making it advisory rather than blocking. If you want this to be a structural gate, change `|| true` to a real exit-on-failure. This is a one-line change, not a 40-line new feature.

- [ ] CRITICAL: **The `--ack-no-spec` escape hatch undermines the entire feature.** The acceptance criteria for F-0128 say: "ag work / ag implement checks for acceptance criteria existence before allowing work to start." The plan proposes that `ag work --ack-no-spec` bypasses this check with only a log entry. This creates a trivially easy path around the gate — an agent that doesn't want to write specs can always pass `--ack-no-spec`. The spec-deviations.log is write-only; nothing reads it to enforce consequences. The pre-commit check merely "emits a prominent warning" when deviations exist, but warnings have already been proven ineffective (that's the whole premise of this feature). **Suggested fix**: Remove `--ack-no-spec` entirely. In Core+PM, `ag work` should simply refuse to start without a feature ID, period. The message should say: "Core+PM requires a feature ID. Create one in spec/FEATURES.md and spec/acceptance/F-XXXX.md, then use `ag implement F-XXXX`." If the user truly needs exploratory work, they can use `ag work` with Core profile, or the agent can create the spec first (which is fast — it's a markdown file). The spec-deviations.log and the entire deviation-tracking machinery (Fix 1 logging + Fix 2 reading the log) can be dropped, simplifying both fixes significantly.

- [ ] IMPORTANT: **Fix 2 (pre-commit check) has a fundamental detection problem.** The plan says: "Look at staged files in implementation directories. If new files are added (git status A), check whether there is a corresponding feature registered in spec/FEATURES.md." But how does the check know WHICH feature a new file belongs to? A new file `src/utils/helper.py` could belong to any feature. Without `@feature` annotations in the code (which are optional and new), there's no mapping from file to feature. The check can only answer "are ANY new impl files staged without ANY spec files staged?" — which produces false positives for every commit that doesn't also modify specs (bug fixes, refactors, config changes, test additions). **Suggested fix**: Narrow the scope. Only trigger the warning when: (a) it's a Core+PM profile, AND (b) new files are added in impl directories, AND (c) there is NO active WIP tracking with a feature ID (meaning the agent bypassed `ag implement`). This makes it a "did you use the workflow?" check rather than a "does this file have a spec?" check.

- [ ] IMPORTANT: **Fix 3 trigger table revision is too verbose for CLAUDE.md.** The proposed replacement is 3 lines long with numbered sub-steps. CLAUDE.md trigger tables work because they're scannable — one line per trigger. A multi-line action breaks the table format and reduces scannability. **Suggested fix**: Keep the trigger table entry to one line: `Build / implement / add / create ... | STOP -> If no F-XXXX: create spec/acceptance/F-XXXX.md FIRST, then `ag plan` + `ag implement`. Never code before specs.` Put the detailed multi-step instructions in memory-seed.md and auto_orchestration.md where there's room for them.

- [ ] SUGGESTION: **Fix 7 (session start reminder) is low-value noise.** Every session already shows "Ready to work. Run 'ag implement F-XXXX' to start a feature." Adding another reminder about specs-first to every session greeting creates reminder fatigue. The structural gates (Fixes 1 and 2) are what actually prevent violations. **Suggested action**: Drop Fix 7, or make it conditional — only show the reminder if spec-deviations.log has recent entries (but if you drop the deviation log per the CRITICAL above, this becomes moot).

- [ ] SUGGESTION: **The plan should note that `ag plan` already has a hard gate for specs.** `cmd_plan()` at line 412 already exits with error if `spec/acceptance/F-XXXX.md` doesn't exist. This is a working structural gate. The real gap is exclusively the `ag work` path and the "no ag command at all" path. Acknowledging this would sharpen the analysis and make it clear that only 2 entry points need fixing, not a broad overhaul.

**Verdict**: REVISION_NEEDED

**Summary of required changes before approval**:
1. Remove Finding 6 and Fix 5 (phantom gate claim is wrong; the gate exists). Instead, make the existing `doctor.sh --phase planning` call in `cmd_implement()` blocking (remove `|| true`).
2. Remove `--ack-no-spec` escape hatch and spec-deviations.log machinery. Make `ag work` in Core+PM a hard block with no bypass.
3. Fix the pre-commit detection logic (Fix 2) to check for workflow bypass rather than file-to-feature mapping.
4. Shorten Fix 3 trigger table entry to one line.
5. Consider dropping Fix 7 (session reminder) to reduce noise.
6. Add a note about running `validate_framework.sh` to ensure the 184+ checks still pass.

---

### Review 2 (2026-02-12) — iteration 2
**Reviewer**: Claude Opus 4.6 (reviewer agent)

**Overall Assessment**: Revision 2 is a substantial improvement. The root cause analysis is now factually accurate, the architecture is clean (three-layer defense-in-depth without over-engineering), and 5 of 6 Review 1 issues are fully addressed. One acceptance criterion has a gap that needs a minor addition. The plan is close to approval.

**Review 1 Issue Resolution**:

1. CRITICAL (Finding 6 factually wrong / phantom gate claim): **RESOLVED.** Finding 6 has been completely rewritten. It no longer claims `doctor.sh --phase planning` is phantom. Instead, it correctly identifies the real gap: "The happy path assumes a feature ID is known upfront." The new Fix 5 correctly makes the existing `doctor.sh --phase planning || true` call blocking by removing the `|| true` — a one-line semantic change, exactly as recommended. The plan also adds a "What already works (acknowledged)" section (lines 43-46) that correctly notes `cmd_plan()` has a hard gate and `cmd_implement()` runs doctor.sh. This fully addresses the factual error.

2. CRITICAL (--ack-no-spec escape hatch): **RESOLVED.** The `--ack-no-spec` flag, spec-deviations.log, and all deviation-tracking machinery have been completely removed. Fix 1 is now a hard block with no bypass: "No escape hatch. No `--ack-no-spec`. No deviation log." The message correctly directs users to create a spec or use Core profile for exploratory work. This is the right design.

3. IMPORTANT (Pre-commit detection problem): **RESOLVED.** Fix 2 now checks for workflow bypass using WIP tracking, not file-to-feature mapping. The three conditions are: (a) Core+PM profile, (b) new files added, (c) no active WIP tracking with a feature ID. This is exactly the narrowed scope recommended. It is described as "a warning, not a block — catch-all safety net," which is appropriate for a last-line defense.

4. IMPORTANT (Trigger table too verbose): **RESOLVED.** Fix 3 is now a single scannable line: "If no F-XXXX: create spec/acceptance/F-XXXX.md FIRST, then `ag plan` + `ag implement`. Never code before specs." Detailed instructions are deferred to memory-seed.md and auto_orchestration.md. This preserves the one-line-per-trigger format.

5. SUGGESTION (Drop session reminder / Fix 7): **RESOLVED.** The old Fix 7 (session start reminder) has been dropped entirely. The new Fix 7 is a different item — an LLM behavioral test, which is appropriate and required by acceptance criteria.

6. SUGGESTION (Acknowledge `ag plan` hard gate): **RESOLVED.** Lines 43-46 explicitly acknowledge: "`cmd_plan()` has a hard gate at line 412 — exits with error if acceptance criteria don't exist" and "`cmd_implement()` calls `doctor.sh --phase planning`." The Key Insight section (lines 198-204) correctly frames the problem as "opt-in enforcement" with only two entry points needing fixes.

**New Issues Found**:

- [ ] IMPORTANT: **Acceptance criterion "Session start greeting reminds about specs-first when Core+PM profile active" is not covered.** The acceptance criteria at `spec/acceptance/F-0128.md` line 22 explicitly requires: "Session start greeting reminds about specs-first when Core+PM profile active." Review 1 suggested dropping the session reminder (old Fix 7) as noise, and the planner correctly dropped it. However, the acceptance criteria still require it. The plan needs to either: (a) add a minimal session-start reminder (e.g., a one-liner in the dashboard output, not a separate Fix), or (b) explicitly note that this criterion will be addressed by updating the acceptance criteria to remove it (with justification that structural gates make it unnecessary). The planner should not silently skip an acceptance criterion. **Suggested fix**: Add a note to Fix 6 (auto_orchestration.md / documentation) or to the Implementation Sequence that the session start checklist (`.agentic/checklists/session_start.md`) will include a one-line Core+PM specs reminder. Alternatively, propose amending the acceptance criteria with a rationale. Either way, acknowledge the gap explicitly.

**Acceptance Criteria Coverage**:

| Criterion | Covered By | Status |
|-----------|-----------|--------|
| Root cause analysis documented | Findings 1-6 | COVERED |
| All enforcement points identified | Gap Classification table | COVERED |
| Gaps categorized structural vs behavioral | Gap Classification table | COVERED |
| `ag work` / `ag implement` checks for acceptance criteria | Fix 1 (ag work hard block) + Fix 5 (ag implement blocking doctor) | COVERED |
| Tools emit warning if no acceptance file | Fix 2 (pre-commit warning) | COVERED |
| Commit gates warn for new code without specs | Fix 2 | COVERED |
| Memory-seed includes "write acceptance criteria FIRST" | Fix 4 | COVERED |
| CLAUDE.md trigger table references acceptance criteria | Fix 3 | COVERED |
| Auto-orchestration reinforces specs-first | Fix 6 | COVERED |
| All `ag` commands checked for specs-first | Fix 1 + Fix 5 + acknowledged `ag plan` works | COVERED |
| Session start greeting reminds (Core+PM) | Not addressed | GAP |
| Pre-commit detects new impl files without specs | Fix 2 | COVERED |
| Framework validation passes (184+) | Implementation Sequence step 8 | COVERED |
| New LLM behavioral test | Fix 7 | COVERED |

**Other Observations**:

- File count (8 files, ~125 lines) is realistic and well-scoped. No over-engineering detected.
- Implementation sequence is logical. The parallel batch (Fixes 3-6) and the note that Fix 7 verifies Fixes 1-2 are good.
- The Key Insight section (lines 196-204) with the four-layer defense model is clear and well-structured.
- The Risks and Mitigations table is reasonable.
- No new over-engineering has been introduced compared to revision 1.

**Verdict**: REVISION_NEEDED

**Summary of required changes before approval**:
1. Address the session-start greeting acceptance criterion — either add a minimal implementation note or propose amending the acceptance criteria with justification. This is the only remaining gap.

Once this single item is addressed, the plan should be ready for APPROVED status.

---

### Review 3 (2026-02-12) — iteration 3
**Reviewer**: Claude Code (final review)

**Overall Assessment**: Revision 3 successfully resolves the single remaining issue from Review 2. The acceptance criterion gap has been properly addressed through explicit amendment of the acceptance criteria file with clear justification. The plan is now complete, internally consistent, and ready for implementation.

**Review 2 Issue Resolution**:

- [x] **Session-start greeting acceptance criterion:** The plan now explicitly documents that the criterion "Session start greeting reminds about specs-first when Core+PM profile active" has been removed from `spec/acceptance/F-0128.md` (line 22, struck through with rationale). The justification is sound: structural gates (ag work hard block in Fix 1, ag implement blocking doctor check in Fix 5, pre-commit workflow bypass detection in Fix 2) make text reminders both redundant and counterproductive. Adding per-session behavioral reminders would create noise without enforcement value — the exact failure mode this feature was designed to address. The amendment is properly documented in both the plan (line 173) and the acceptance criteria file itself.

**Quality Assessment**:

✓ Root cause analysis is factually accurate (acknowledged by Review 1 resolution)
✓ Architecture uses clean defense-in-depth with four layers (behavioral, structural entry, structural exit, verification)
✓ All acceptance criteria are addressed or properly amended with justification
✓ Implementation scope is realistic (~8 files, ~125 lines, no over-engineering)
✓ Implementation sequence is logical and includes validation step
✓ Risks and mitigations are reasonable
✓ New LLM behavioral test (Fix 7) will verify the core failure mode

**Verdict**: APPROVED

The plan is ready for implementation. All Review 1 and Review 2 issues have been resolved, and no new issues have been identified.
