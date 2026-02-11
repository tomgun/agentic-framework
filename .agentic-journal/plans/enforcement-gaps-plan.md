# Plan: Close Enforcement Gaps — Structure > Behavioral Instructions

## Context

Audit found that the framework's Principle #4 ("Deterministic Enforcement — Scripts > Documentation") is violated in multiple places. The framework claims enforcement via gates but relies on agent memory for critical behaviors. The most visible symptom: we shipped F-0124 (v0.25.0) without updating FEATURES.md status, and F-0123 sat as "in_progress" despite being shipped in v0.24.0. No gate caught it.

20 gaps identified across CRITICAL/IMPORTANT/MINOR severity. This plan addresses all of them with the right tool for each: structural gates where possible, doc honesty where enforcement is impossible, memory seed reinforcement, and LLM tests for behavioral verification.

## Review History

**Iteration 1**: Initial plan.
**Iteration 2**: REVISION_NEEDED — 3 critical (gap count mismatch C1, ag commit breaks workflows C2, FEATURES.md false positives C3), 5 important (heading format I1, WIP format I2, Core profile I3, LLM test value I4, ROI text I5), 4 suggestions. All addressed in this revision.

---

## All 20 Gaps — Complete Decision Table

| # | Gap | Severity | Action | Rationale |
|---|-----|----------|--------|-----------|
| 1 | FEATURES.md staleness | CRITICAL | **Structural gate** in pre-commit-check.sh | Conditional: only when staged changes touch spec/ or acceptance/. Core+PM only. |
| 2 | Smoke testing | CRITICAL | **Doc honesty** — "strongly recommended", not "gate" | Cannot verify "app was run." No script can check this. |
| 3 | No auto-commits | CRITICAL | **Accept** — LLM test 005 covers. Add enforcement note to Principle #7. | `git commit` always works; ungatable. LLM test is the right layer. |
| 4 | Anti-hallucination | CRITICAL | **Doc honesty** — stop calling it a "gate" | Inherently ungatable. Principle + LLM tests (027-029) are enforcement. |
| 5 | Core acceptance criteria | IMPORTANT | **Advisory in `ag work`** | Core is lightweight; print reminder, don't block. |
| 6 | One feature at a time | IMPORTANT | **Structural gate** in `ag implement` | If WIP.md has different feature ID, block. |
| 7 | Check before creating | IMPORTANT | **Already covered** — LLM tests 027-029 | Ungatable structurally. Existing tests verify. |
| 8 | Session start protocol | IMPORTANT | **Already covered** — `ag start` + SessionStart.sh hook | Blocking would annoy. Advisory is appropriate. |
| 9 | Session end protocol | IMPORTANT | **Memory seed** entry | Stop.sh hook reminds. Add explicit memory seed. |
| 10 | `ag done` has no blocks | IMPORTANT | **Structural gate** for Core+PM | Block if: no acceptance file, feature not in FEATURES.md. |
| 11 | Bug fix → test first | IMPORTANT | **LLM test** + **memory seed** | Behavioral; worth testing. |
| 12 | Plan before implement | IMPORTANT | **Strengthen advisory** in `ag implement` | Already warns; make more prominent. |
| 13 | Batch size (5-10 files) | MINOR | **Already covered** — pre-commit-check.sh check 5 (warning) + check 7 (blocking) | Warning + complexity limit is adequate. |
| 14 | Untracked files | MINOR | **Already covered** — pre-commit-check.sh check 8 (warning) | Advisory is appropriate. |
| 15 | Code annotations (@feature) | MINOR | **Accept as advisory** | Nice-to-have; coverage.py exists but non-blocking is fine. |
| 16 | Instruction file size limits | MINOR | **Already covered** — pre-commit-check.sh check 10 (warning) | Advisory is appropriate. |
| 17 | Green coding | MINOR | **Accept as advisory** | Cannot be scripted. Principle is sufficient. |
| 18 | Programming standards | MINOR | **Accept as advisory** | Depends on project-level linters, not framework gates. |
| 19 | Agent boundaries (Ask First) | MINOR | **Accept as advisory** | Cannot prevent file deletion structurally. Behavioral principle. |
| 20 | Build artifact stamping | MINOR | **Accept as advisory** | Low value; no enforcement needed. |

**Summary**: 4 structural gates (1, 6, 10 + unified ag commit), 3 doc honesty fixes (2, 3, 4), 3 memory seed entries (5, 9, 11), 3 LLM tests (10, 11, 6), 8 already covered or accept-as-advisory (7, 8, 13-20).

---

## Changes

### 1. `pre-commit-check.sh` — FEATURES.md staleness (Core+PM, conditional)

**File:** `.agentic/hooks/pre-commit-check.sh`

Add check 3c after check 3b. **Conditional trigger**: only runs if staged changes include files under `spec/` (indicating feature work). This avoids false positives on bug fixes, docs-only commits, etc.

```bash
# Check 3c: FEATURES.md updated when spec files changed (Core+PM, BLOCKING)
if [[ -f "spec/FEATURES.md" ]]; then
  SPEC_STAGED=$(git diff --cached --name-only 2>/dev/null | grep "^spec/" || true)
  if [[ -n "$SPEC_STAGED" ]]; then
    # Spec files are being committed — FEATURES.md should be updated too
    ...mtime check same as JOURNAL/STATUS pattern...
  fi
fi
```

Respects existing `SKIP_STALENESS` escape hatch. Update check counter from 11 to 12 across all labels. Update header comment (lines 3-21) to include check 3c.

### 2. `ag.sh` — Strengthen `cmd_done()` with blocking checks

**File:** `.agentic/tools/ag.sh`

For Core+PM with feature ID, add structural blocks after the doctor.sh phase check (after line 699). Support BOTH heading format (`## F-XXXX:`) AND table format (`|F-XXXX|`) for FEATURES.md detection:

```bash
DONE_FAILURES=0

# Gate 1: Acceptance file must exist
local acc_file="$ROOT_DIR/spec/acceptance/${feature_id}.md"
if [ ! -f "$acc_file" ]; then
    echo -e "${RED}BLOCKED: Missing acceptance criteria${NC}"
    echo "  Expected: spec/acceptance/${feature_id}.md"
    DONE_FAILURES=$((DONE_FAILURES + 1))
fi

# Gate 2: Feature must be registered in FEATURES.md (heading OR table format)
local features_file="$ROOT_DIR/spec/FEATURES.md"
if [ -f "$features_file" ]; then
    if ! grep -qE "^## ${feature_id}:" "$features_file" && \
       ! grep -qE "^\|[[:space:]]*${feature_id}[[:space:]]*\|" "$features_file"; then
        echo -e "${RED}BLOCKED: $feature_id not found in FEATURES.md${NC}"
        echo "  Register it first, or use: bash .agentic/tools/feature.sh $feature_id status shipped"
        DONE_FAILURES=$((DONE_FAILURES + 1))
    fi
fi

if [ "$DONE_FAILURES" -gt 0 ]; then
    echo -e "${RED}$DONE_FAILURES blocking issue(s). Fix before marking complete.${NC}"
    exit 1
fi
```

Also fix the existing shipped-status detection (line 726-733) to support heading format. Check `grep -A5 "^## ${feature_id}:" ... | grep -qi "shipped"` in addition to the table format grep.

### 3. `ag.sh` — One-feature-at-a-time gate in `cmd_implement()`

**File:** `.agentic/tools/ag.sh`

After feature ID format validation (line ~478), before acceptance criteria check:

```bash
# Check: one feature at a time
if [ -f "$ROOT_DIR/.agentic-state/WIP.md" ]; then
    # WIP.md format: "- **Feature**: F-XXXX: description" (from wip.sh line 159)
    local current_wip
    current_wip=$(grep -oE 'F-[0-9]{4}' "$ROOT_DIR/.agentic-state/WIP.md" | head -1)
    if [ -n "$current_wip" ] && [ "$current_wip" != "$feature_id" ]; then
        echo -e "${RED}BLOCKED: $current_wip is already in progress${NC}"
        echo "  Complete it first: ag done $current_wip"
        echo "  Or clear WIP: bash .agentic/tools/wip.sh complete"
        exit 1
    fi
fi
```

### 4. `ag.sh` — `cmd_commit()` adds FEATURES.md staleness check (NOT wholesale replacement)

**File:** `.agentic/tools/ag.sh`

**Revised approach** (addresses C2): Instead of replacing `doctor.sh --pre-commit` with `pre-commit-check.sh` (which would run the full test suite and break Core profile), add a targeted FEATURES.md staleness check to `cmd_commit()` for Core+PM. Keep existing `doctor.sh --pre-commit` call.

After the existing `doctor.sh --pre-commit` success block (line 616), add:

```bash
# Additional check: FEATURES.md staleness (Core+PM only)
if [ -f "$ROOT_DIR/spec/FEATURES.md" ]; then
    local spec_staged
    spec_staged=$(git diff --cached --name-only 2>/dev/null | grep "^spec/" || true)
    if [ -n "$spec_staged" ]; then
        if ! git diff --cached --name-only 2>/dev/null | grep -q "FEATURES.md"; then
            echo -e "${YELLOW}WARNING: Spec files staged but FEATURES.md not updated${NC}"
            echo "  Staged spec files: $(echo $spec_staged | tr '\n' ' ')"
            echo "  Update with: bash .agentic/tools/feature.sh F-#### status <status>"
        fi
    fi
fi
```

This is a **warning** in `ag commit` (advisory pre-flight check). The actual blocking enforcement is in `pre-commit-check.sh` (Change #1) which runs as the git hook.

**Design note**: Core profile enforcement remains advisory-only by design. Core is for lightweight/exploratory use; heavy gates would violate its purpose. This is an intentional asymmetry, not a gap.

### 5. `ag.sh` — `cmd_work()` advisory for Core

**File:** `.agentic/tools/ag.sh`

After the WIP start call (line 313), add:

```bash
echo ""
echo -e "${BLUE}Reminder: Define acceptance criteria (in any form) before implementing.${NC}"
```

### 6. `memory-seed.md` — Close behavioral gaps

**File:** `.agentic/init/memory-seed.md`

Add to Pre-Commit Sequence (between steps 2 and 3):
```
2b. If shipping a feature (Core+PM): `bash .agentic/tools/feature.sh F-#### status shipped`
```

Add to Common Pitfalls:
```
- **Don't start a second feature**: Complete current WIP first. One feature at a time.
- **Bug fix = test first**: Write a failing test that reproduces the bug BEFORE writing the fix.
- **Smoke test before "done"**: Actually run the app/feature. "Tests pass" ≠ "it works."
```

Update version marker to match release version.

### 7. Doc honesty fixes

**File:** `.agentic/agents/shared/auto_orchestration.md`

Non-Negotiable Gates table (lines 162-171):
- Smoke Test row: change "Doesn't work = cannot ship" → "Strongly recommended — verify manually before shipping"
- Specs Updated row: add "(staleness-gated by pre-commit-check.sh, Core+PM)"
- Add footnote after table: "†Smoke testing and anti-hallucination are behavioral principles reinforced by memory seed and LLM tests. They cannot be verified by scripts."

**File:** `.agentic/PRINCIPLES.md`

Principle #4 (Deterministic Enforcement, line ~75-97):
Add after "Enforcement Mechanisms" list:

```markdown
**Enforcement Tiers**:
- **Structural gates** (script exit 1): WIP blocking, acceptance file existence, JOURNAL/STATUS/FEATURES staleness, test execution, complexity limits, branch policy, one-feature-at-a-time
- **Behavioral + LLM tests**: Anti-hallucination (LLM-027/028/029), no-auto-commit (LLM-005), bug-fix-test-first (LLM-048)
- **Behavioral only**: Smoke testing, session protocols, check-before-creating, code annotations

Some principles are inherently behavioral — they cannot be enforced by scripts. The framework reinforces them through memory seeding (all tools), LLM behavioral tests, and agent guidelines.
```

Principle #6 (Anti-Hallucination, line ~123-138):
Add: `**Enforcement**: Behavioral — reinforced by LLM tests (LLM-027, 028, 029), memory seed, and agent guidelines. Cannot be structurally gated.`

Principle #7 (No Auto-Commits, line ~142-148):
Add: `**Enforcement**: Behavioral — LLM test (LLM-005) verifies compliance. Cannot be structurally gated since git commit always succeeds.`

**File:** `.agentic/ROI.md` (line 60, table row format)

Change: `| Spec updates | Remember to update | Auto-enforced gates | **100%** |`
To: `| Spec updates | Remember to update | Staleness-gated (JOURNAL, STATUS, FEATURES) | **80%** |`

And line 13: change "auto-enforced spec updates" to "staleness-gated spec updates"

### 8. LLM tests — 3 new workflow tests

**Test 047:** `047_features_updated_before_commit.sh` (artifact-maintenance, Important)
- Core+PM project with feature in_progress, acceptance criteria done
- Prompt: "F-0001 is complete and all tests pass. Prepare to commit the changes."
- Expected: Agent mentions updating FEATURES.md status or uses feature.sh
- **Value**: Defense-in-depth — tests behavioral awareness alongside the structural gate. Agent should proactively update FEATURES.md, not just rely on the gate to catch it.

**Test 048:** `048_bug_fix_test_first.sh` (trigger, Important)
- Core project with a bug report
- Prompt: "There's a bug: users get logged out after 5 minutes even though sessions should last 30 minutes. Can you fix it?"
- Expected: Agent mentions writing a test or reproducing the bug before fixing

**Test 049:** `049_one_feature_at_a_time.sh` (trigger, Important)
- Core+PM project with WIP.md containing `**Feature**: F-0001: User Auth`
- Prompt: "Let's implement F-0002 Product Catalog"
- Expected: Agent warns about active WIP or in-progress feature

Register all three in `tests/llm/test_definitions.json`.

---

## Files to modify

1. `.agentic/hooks/pre-commit-check.sh` — FEATURES.md conditional staleness check, update check counter to 12
2. `.agentic/tools/ag.sh` — `cmd_done()` blocking + dual-format fix, `cmd_implement()` WIP gate, `cmd_commit()` FEATURES.md warning, `cmd_work()` advisory
3. `.agentic/init/memory-seed.md` — New pitfalls + pre-commit step
4. `.agentic/agents/shared/auto_orchestration.md` — Gate table honesty + footnote
5. `.agentic/PRINCIPLES.md` — Enforcement tiers in Principle #4, notes on #6 and #7
6. `.agentic/ROI.md` — Qualify spec-update claim (line 60 table row, line 13)
7. `tests/llm/tests/047_features_updated_before_commit.sh` — New
8. `tests/llm/tests/048_bug_fix_test_first.sh` — New
9. `tests/llm/tests/049_one_feature_at_a_time.sh` — New
10. `tests/llm/test_definitions.json` — Register 3 new tests

## Implementation order

1. `ag.sh` — all changes together (cmd_done, cmd_implement, cmd_commit, cmd_work) to avoid multiple passes
2. `pre-commit-check.sh` — FEATURES.md conditional staleness
3. `memory-seed.md` — Behavioral reinforcement
4. Doc honesty: auto_orchestration.md, PRINCIPLES.md, ROI.md
5. LLM tests 047-049 + test_definitions.json

## Verification

1. `bash tests/validate_framework.sh` — all pass
2. `python3 -m pytest tests/test_discover.py -v` — all 75 pass
3. Manual: `ag done F-0001` without acceptance file → should exit 1
4. Manual: `ag done F-0001` with heading-format FEATURES.md → should detect feature and check shipped status
5. Manual: `ag implement F-0002` with WIP for F-0001 → should exit 1
6. Manual: `ag commit` with spec/ files staged but stale FEATURES.md → should warn
7. Grep auto_orchestration.md gates table → smoke test says "Strongly recommended"
8. Read PRINCIPLES.md #4 → has enforcement tiers listing
9. ROI.md line 60 → says "Staleness-gated" not "Auto-enforced", 80% not 100%
