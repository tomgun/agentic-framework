# Plan: Framework Instruction Architecture Cleanup (v3 — post-review)

## Review History
- v1: Initial plan (6 batches)
- v2: Revised after Round 1 review (5 CRITICAL, 10 IMPORTANT, 5 SUGGESTION fixes applied)
- v3: Revised after Round 2 review (0 CRITICAL, 3 IMPORTANT, 3 SUGGESTION fixes applied)

## Summary

Implements the three-layer architecture (Constitution / Playbooks / State) from `docs/INSTRUCTION_ARCHITECTURE.md`. Addresses 4 design gaps and 4 cleanup opportunities across 7 batches (Batch 5 split per review). Each batch stays within 5-10 file limit.

Total estimated scope: 7 batches, ~40-50 files touched across all batches.

---

## Batches

### Batch 1: Create core-rules.md and add always-inject to context-for-role.sh (Gap 2)

**Goal**: Establish universal subagent rules module + mechanism to always inject it.

**Files (4)**:

1. **`.agentic/agents/shared/guidelines/core-rules.md`** (NEW, ~20-25 lines, ~300 tokens)
   - Content: Condensed constitutional extract:
     - Never fabricate APIs, endpoints, or function signatures
     - Never auto-commit without human approval
     - Use token-efficient scripts (status.sh, journal.sh, blocker.sh, feature.sh) — do NOT read/edit STATUS.md, JOURNAL.md, HUMAN_NEEDED.md, FEATURES.md directly
     - If uncertain, state uncertainty and ask — never guess
   - NOT a replacement for anti-hallucination.md. Minimal constitutional rules for ALL subagents.
   - **Deduplication note**: For the 7 manifests that already include anti-hallucination.md, ~100 tokens of overlap is acceptable (anti-hallucination is comprehensive; core-rules is the constitutional minimum).

2. **`.agentic/tools/context-for-role.sh`** (MODIFY)
   - Add always-inject mechanism: `ALWAYS_INJECT` array processed BEFORE manifest required files, counted against token budget.
   - Existing manifest-based injection mechanism remains completely intact (additive layer on top).
   - **Token budget safety**: Smallest manifest budget is 2000 tokens (orchestrator-agent.yaml, git-agent.yaml). core-rules.md at ~300 tokens fits. Verify implementation-agent budget (5000) doesn't overflow with core-rules + existing required files.

3. **`.agentic/agents/shared/guidelines/README.md`** (MODIFY)
   - Add core-rules.md to Available Modules table
   - Note: "core-rules.md is always-injected by context-for-role.sh for ALL agent roles"

4. **`docs/INSTRUCTION_ARCHITECTURE.md`** (MODIFY)
   - Update Gap 2 status: "RESOLVED — Option (b) implemented"

**Validation**:
- `context-for-role.sh orchestrator-agent F-0001 --dry-run` — core-rules.md appears, verify total stays under 2000 budget
- `context-for-role.sh git-agent F-0001 --dry-run` — core-rules.md appears, verify total stays under 2000 budget
- `context-for-role.sh implementation-agent F-0001 --dry-run` — core-rules.md appears (5000 budget, ample room)
- `context-for-role.sh api-design-agent F-0001 --dry-run` — core-rules.md appears for previously uncovered manifest
- `bash tests/validate_framework.sh`

**Risk**: LOW

---

### Batch 2: Slim instruction file templates (Gap 1, part 1)

**Goal**: Reduce templates from ~69-79 lines to ~40-50 lines.

**Files (6)**:

1. **`.agentic/agents/claude/CLAUDE.md`** (MODIFY — 79 lines -> target ~45)
   - **KEEP**: Opening line + "Always consult" (lines 1-5)
   - **KEEP**: Quick Commands one-liner (line 19)
   - **KEEP**: Trigger table (lines 21-28, tested by 003/010)
   - **KEEP**: "DO NOT PROCEED" + "Small batch" (lines 30-32)
   - **KEEP**: Core behavioral rules from "Rules:" section: PR by default, never auto-commit, code + docs = done, keep changes small (lines 34-41)
   - **KEEP**: Token-efficient scripts (lines 56-60, tested by 004/019)
   - **KEEP**: Checklists reference line (line 67, keep until Batch 4 adds `ag` playbook references — avoid temporal gap)
   - **REMOVE**: Gates table + escape hatches (lines 7-17) — structurally enforced by pre-commit-check.sh
   - **REMOVE**: Agent Boundaries table (lines 43-48) — move to auto_orchestration.md
   - **REMOVE**: Agent Mode / Delegation table (lines 50-54, Claude-specific) — move to auto_orchestration.md
   - **REMOVE**: Session Protocols detail (lines 62-65) — `ag start` handles structurally
   - **REMOVE**: Task Tool Delegation table (lines 69-75) — move to auto_orchestration.md
   - **REMOVE**: Subagent context + Standards references (lines 77-79) — playbook layer, not constitution
   - **ADD**: One-line playbook pointer: "Workflows, delegation, checklists: run `ag` commands or see `.agentic/agents/shared/auto_orchestration.md`"

2. **`.agentic/agents/copilot/copilot-instructions.md`** (MODIFY — 69 lines -> target ~45)
   - **Per-file differences from CLAUDE.md**: No Task Tool Delegation table exists (Claude-only). No "Subagent context" line. Has its own model tier names.
   - **KEEP**: Same core content as CLAUDE.md (trigger table, token scripts, behavioral rules)
   - **REMOVE**: Gates table, Session Protocols detail, Agent Mode table
   - **ADD**: Same playbook pointer

3. **`.agentic/agents/codex/codex-instructions.md`** (MODIFY — 71 lines -> target ~45)
   - **Per-file differences**: No Task Tool Delegation table. Has "Codex runs commands in a sandbox" note (line 7, KEEP). No subagent context line.
   - **KEEP**: Same core + sandbox note
   - **REMOVE**: Same items as copilot (Gates, Session Protocols, Agent Mode)
   - **ADD**: Same playbook pointer

4. **`.agentic/agents/cursor/agentic-framework.mdc`** (VERIFY ONLY — 35 lines)
   - Already within target at 35 lines (delegates to `agent_operating_guidelines.md` instead of inlining rules).
   - Currently has NO trigger table and NO token-efficient scripts inline — delegates to guidelines instead.
   - Decision: Accept current delegation pattern (Cursor .mdc format differs from other templates). Document gap if LLM tests are later extended to Cursor.

5. **`.agentic/agents/shared/auto_orchestration.md`** (MODIFY — receive moved content, 334 -> ~355 lines)
   - Add "## Reference: Gates and Delegation" section with:
     - Gates table (from instruction files)
     - Delegation/Agent Mode table (from CLAUDE.md template)
     - Session protocol details (from instruction files)
   - **Growth note**: ~20-25 lines added. Acceptable — playbooks have no strict size ceiling (only instruction files do). auto_orchestration.md is loaded just-in-time via `ag` commands, not pinned in context.

6. **`docs/INSTRUCTION_ARCHITECTURE.md`** (MODIFY)
   - Update Gap 1 status for templates
   - **Fix design doc error**: `.cursorrules` baseline is 27 lines (root), not 71. The 71-line figure was the codex template.
   - Record actual achieved line counts

**Validation (CRITICAL)**:
- **LLM tests 003, 004, 010, 019 MUST pass** after this batch
- `bash tests/validate_framework.sh`
- **A8 check**: Count actual lines. If >50, document why.

**Risk**: MEDIUM-HIGH (instruction file changes are the riskiest)

---

### Batch 3: Slim root/framework-dev instruction files (Gap 1, part 2)

**Goal**: Reduce root CLAUDE.md (92 -> ~55), slim .codex/instructions.md (286 -> ~55), slim .github/copilot-instructions.md (77 -> ~50), verify .cursorrules (27 lines).

**Files (5)**:

1. **`CLAUDE.md`** (MODIFY — root, 92 -> target ~55)
   - **KEEP**: "THIS IS FRAMEWORK DEVELOPMENT" header
   - **KEEP**: "Read first" references
   - **KEEP**: Trigger table + token-efficient scripts (tested)
   - **KEEP**: "Framework Development" footer (8 lines, unique to root)
   - **KEEP**: Checklists reference (until Batch 4)
   - **REMOVE**: Gates table, Agent Mode/Delegation, Session Protocols, Agent Boundaries table
   - **ADD**: Playbook pointer + core behavioral rules

2. **`.codex/instructions.md`** (MODIFY — 286 lines -> target ~55)
   - **THIS IS THE LARGEST INSTRUCTION FILE IN THE REPO** (2.8x the L-0002 ceiling)
   - Same KEEP/REMOVE pattern as root CLAUDE.md
   - Must include framework-dev specifics equivalent to root CLAUDE.md footer

3. **`.github/copilot-instructions.md`** (MODIFY — root, 77 -> target ~50)
   - Same KEEP/REMOVE as root CLAUDE.md for Copilot
   - Remove session start details, overlapping "Adding Framework Features" table

4. **`.cursorrules`** (VERIFY — root, 27 lines)
   - Already lean. Check: does it have trigger table? If not, evaluate adding for Cursor-based framework dev.

5. **`docs/INSTRUCTION_ARCHITECTURE.md`** (MODIFY)
   - Update Gap 1 status: "FULLY RESOLVED"
   - Record final line counts for ALL instruction files

**Validation (CRITICAL)**:
- LLM tests 003, 004, 010, 019 MUST pass
- `bash tests/validate_framework.sh`

**Risk**: MEDIUM
- Root CLAUDE.md affects agent behavior in this very repo
- `.codex/instructions.md` at 286 lines is the biggest win but also biggest change

**Dependencies**: Batch 2

---

### Batch 4: `ag.sh` fixes — playbook references and `cmd_done` blocking (Gaps 3 + 4)

**Goal**: `ag` commands print playbook references; `ag done` blocks on validation failures.

**Files (9)** (1 script + 1 design doc + 1 new test + 6 instruction files for one-line removal):

1. **`.agentic/tools/ag.sh`** (MODIFY)

   **Gap 3 — Playbook references**:
   - `cmd_implement()`: After "Ready to implement", add:
     ```
     Playbook: .agentic/agents/shared/auto_orchestration.md (Feature Pipeline)
     Checklist: .agentic/checklists/feature_implementation.md
     ```
   - `cmd_commit()`: At end of success path, add:
     ```
     Checklist: .agentic/checklists/before_commit.md
     ```
   - `cmd_done()`: Already has feature_complete.md reference — verify prominence

   **Gap 4 — cmd_done blocking (Core+PM)**:
   - Line 666: Replace `|| true`:
     ```bash
     if ! bash "$SCRIPT_DIR/doctor.sh" --phase complete "$feature_id" 2>/dev/null; then
         echo -e "${RED}Structural checks FAILED - fix issues above${NC}"
     fi
     ```
   - Core profile (lines 615-630): Add basic `doctor.sh --quick` check with WARNING (not blocking — Core is discovery mode)

   **Also evaluate**: `cmd_implement()` line 528 has same `|| true` pattern on `doctor.sh --phase planning`. Decision: KEEP as non-blocking for planning phase — planning is early-stage, blocking would be overly strict. Document this as intentional divergence from cmd_done behavior.

   **After Batch 4**: Remove the "Checklists reference" line kept in instruction files during Batches 2-3 (now redundant since `ag` commands print references). This is a follow-up edit to templates + root files — include in this batch.

2. **`docs/INSTRUCTION_ARCHITECTURE.md`** (MODIFY)
   - Update Gap 3 + Gap 4 status

3. **`tests/llm/tests/` + `test_definitions.json`** (NEW test)
   - New LLM test validating A7 (agents follow stdout references)
   - Determine test number from test_definitions.json at implementation time (next available after existing tests)

4. **Instruction files** (MODIFY — remove checklists reference line now that ag commands print them)
   - `.agentic/agents/claude/CLAUDE.md`, copilot, codex templates + root CLAUDE.md, .codex/instructions.md, .github/copilot-instructions.md
   - This is a one-line removal from each — counts as one logical change

**Validation**:
- `bash tests/validate_framework.sh`
- Manual: `ag implement F-0001` → playbook reference visible
- Manual: `ag done F-0001` with failures → blocks/warns

**Risk**: LOW-MEDIUM

**Dependencies**: After Batches 2-3 (to remove the checklist reference line)

---

### Batch 5a: Refactor agent_operating_guidelines.md — core file (Cleanup A, part 1)

**Goal**: Replace 434-line monolith with ~80-100 line reference document using existing modules.

**Files (5)**:

1. **`.agentic/agents/shared/agent_operating_guidelines.md`** (MODIFY — 434 -> ~80-100)

   **Section-by-section handling**:
   | Section | Lines | Action |
   |---------|-------|--------|
   | Header + reference note | 1-9 | KEEP |
   | ENFORCED GATES table | 15-22 | KEEP (brief) |
   | Quick Commands | 25 | KEEP |
   | Agent Boundaries | 29-60 | KEEP (condensed to ~15 lines) |
   | Token-Efficient Scripts | 75-89 | REPLACE → `guidelines/token-efficiency.md` |
   | Small Batch | 92-98 | REPLACE → `guidelines/small-batch.md` |
   | Green Coding | 101-109 | KEEP as 2-line summary + ref to `.agentic/quality/green_coding.md` |
   | Anti-Hallucination | 113-175 | REPLACE → `guidelines/anti-hallucination.md` |
   | Check Before Creating | 177-211 | MOVE into `guidelines/anti-hallucination.md` |
   | WIP Tracking | 215-248 | REPLACE → `guidelines/wip-tracking.md` |
   | Profile-Specific Workflows | 252-292 | KEEP 5-line summary + ref to `auto_orchestration.md` |
   | Documentation Sync Rule | 295-314 | KEEP as 3-line rule (behavioral, can't be structurally enforced) |
   | Agent Delegation | 317-329 | REPLACE → `workflows/agent_mode.md` |
   | Sequential Pipeline | 332-343 | REMOVE (covered by auto_orchestration.md) |
   | When to Escalate | 346-358 | KEEP as 3-line summary (behavioral) |
   | Checklists reference | 360-370 | KEEP as compact list |
   | Developer UX Contract | 381-393 | KEEP as 3-line summary (behavioral) |
   | Build Artifact Stamping | 395-404 | REMOVE (move to build-stamper.sh header or archive) |
   | After Framework Upgrade | 406-413 | REPLACE → ref to `session_start.md` |
   | Git File Tracking | 416-424 | KEEP as 2-line rule |

2. **`.agentic/agents/shared/guidelines/anti-hallucination.md`** (MODIFY)
   - Add "Check Before Creating" section (from lines 177-211)

3. **`.agentic/agents/shared/guidelines/README.md`** (MODIFY)
   - Mark migration as COMPLETE

4. **`docs/INSTRUCTION_ARCHITECTURE.md`** (MODIFY)
   - Note: agent_operating_guidelines.md refactored

5. One additional file if Build Artifact Stamping content needs a new home

**Validation**:
- `wc -l` on agent_operating_guidelines.md — target 80-100
- All module files exist with expected content
- `context-for-role.sh` still works
- `bash tests/validate_framework.sh`

**Risk**: MEDIUM

**Dependencies**: After Batch 3 (instruction files stable)

---

### Batch 5b: Update cross-references to agent_operating_guidelines.md (Cleanup A, part 2)

**Goal**: Fix all broken section-header anchor links after Batch 5a restructuring.

**Files (estimated 3 anchor fixes + ~12 filename-only references to verify)**:

**Pre-work**: Run grep for `agent_operating_guidelines.md#` and `agent_operating_guidelines` across all non-archived files. Current counts: 65 occurrences across 30 files total (including journals, manifests, archived examples). Active files: ~15. Of those, only 3 use section-header anchors that will break:

**Anchor-linked files (WILL break — must fix)**:
- `.codex/instructions.md` — `#agent-boundaries--authority` anchor
- `.agentic/agents/cursor/agents-setup.md` — `#agent-boundaries--authority` anchor
- `.agentic-journal/plans/2026-02-03-article-insights-implementation.md` — `#agent-boundaries--authority` anchor

**Filename-only references (~12 files — verify no breakage)**:
- Root CLAUDE.md, FRAMEWORK_DEVELOPMENT.md, CONTEXT_PACK.md, UPGRADING.md
- Various spec/acceptance/ files (F-0055, F-0069, F-0082, F-0084, F-0093, etc.)
- `.agentic/DEVELOPER_GUIDE.md`, `.agentic/tools/setup-agent.sh`, `tests/validate_framework.sh`
- These reference the filename only, not section anchors — no update needed unless sections are renamed

**Approach**: For each broken anchor, either:
- Update to new section header in restructured guidelines, OR
- Redirect to the appropriate guideline module file

**Validation**:
- Grep for `agent_operating_guidelines.md#` — zero broken anchors
- `bash tests/validate_framework.sh`

**Risk**: LOW (reference updates only, no behavioral changes)
**Recommendation**: Single commit so `git revert` works atomically

**Dependencies**: Batch 5a

---

### Batch 6: Checklist consolidation + legacy tool cleanup (Cleanups B + C)

**Goal**: Reduce checklist overlap; document/archive legacy tools.

**Files (8-10)**:

**Checklists** (consolidate by cross-reference, not deletion):
1. **`feature_start.md`** — Keep as pre-flight, add cross-ref to feature_implementation.md
2. **`feature_implementation.md`** — Replace Gate 1 with prerequisite ref, cross-ref before_commit.md
3. **`feature_complete.md`** — Mark test sections: "Verify: see before_commit.md"
4. **`before_commit.md`** — Replace smoke test section with brief ref to smoke_testing.md

**Excluded from consolidation** (standalone, no significant overlap):
- `session_start.md`, `session_end.md` — session lifecycle, distinct scope
- `smoke_testing.md` — standalone reference doc
- `retrospective.md` — standalone, different purpose
- `agent_behavior_verification.md` — specialized verification, no overlap

**Legacy tools** (evaluate: document use case or move to `.agentic/tools/archived/`):
5-10. arch_diff.sh, build-stamper.sh, bulk_update.py, consistency.sh, pipeline_list.sh, search.sh

**NOT archived** (have acceptance specs or active references):
- `quick_feature.sh` (F-0077), `quick_issue.sh` (F-0078), `retro_check.sh` (referenced by session_start.md), `create-agent.sh` (active utility)

**Validation**:
- `bash tests/validate_framework.sh`
- Grep for archived tool names in active (non-archived) files
- No checklist content completely lost

**Risk**: LOW

**Dependencies**: None (fully independent)

---

## Dependencies

```
Batch 1 (core-rules + always-inject)
    |
    v
Batch 2 (slim templates)
    |
    v
Batch 3 (slim root files)
    |
    v
Batch 4 (ag.sh fixes + remove checklists ref from instruction files)
    |
    v
Batch 5a (guidelines refactor)
    |
    v
Batch 5b (cross-reference fixes)

Batch 6 (checklists + legacy) -- fully independent, can run anytime
```

Recommended order: 1 → 2 → 3 → 4 → 5a → 5b → 6

Batch 6 can run in parallel with any batch.

---

## Risks & Rollback

| Risk | Severity | Mitigation | Rollback |
|------|----------|------------|----------|
| LLM tests fail after slimming (Batches 2-3) | HIGH | Run tests after each batch; keep trigger table + token scripts verbatim | `git revert`; add back content |
| ~40-50 line target not achievable (A8) | MEDIUM | Accept ~55 for root, ~50 for templates | Adjust target in design doc |
| `ag done` blocking surfaces doctor.sh bugs (Batch 4) | MEDIUM | Test doctor.sh independently first | Restore `|| true` |
| `.codex/instructions.md` at 286 lines resists slimming | MEDIUM | May need intermediate target (~80) then iterate | Document actual vs target |
| Guidelines refactor breaks cross-references (Batch 5b): 3 anchor-linked + ~12 filename-only | MEDIUM | Grep ALL refs before modifying; single commit | Revert atomically |
| Token budget overflow from core-rules.md injection | LOW | Smallest budget is 2000; core-rules is ~300 | Remove from always-inject |
| Agents don't follow stdout references (A7) | LOW | Create LLM test; echo lines are harmless | Remove echo lines |

---

## Corrections from Review

### Round 1 (v1 → v2): 5 CRITICAL, 10 IMPORTANT

| Issue | Fix Applied |
|-------|-------------|
| CRITICAL-1: Missing `.codex/instructions.md` (286 lines) | Added to Batch 3 as primary target |
| CRITICAL-2: Missing `.agentic/agents/cursor/agentic-framework.mdc` | Added to Batch 2 for verification |
| CRITICAL-3: Design doc `.cursorrules` line count wrong (27, not 71) | Batch 2 now corrects design doc |
| CRITICAL-4: Smallest token budget is 2000, not 4000 | Corrected in Batch 1 |
| CRITICAL-5: Templates are not structurally identical | Per-file KEEP/REMOVE lists in Batch 2 |
| IMPORTANT-5: Cross-reference surface area 5-10x larger | Batch 5 split into 5a (refactor) + 5b (references) |
| IMPORTANT-6: Missing section handling in guidelines | Full section-by-section table in Batch 5a |
| IMPORTANT-7: Checklists ref removal creates temporal gap | Keep ref until Batch 4 adds `ag` playbook refs |
| IMPORTANT-8: cmd_implement() also has `|| true` | Added evaluation to Batch 4 (keep, document why) |
| IMPORTANT-9: Placeholder test number | Noted: determine at implementation time |
| IMPORTANT-10: Missing checklist exclusion rationale | Added explicit in/out scope for all 9 checklists |

### Round 2 (v2 → v3): 0 CRITICAL, 3 IMPORTANT, 3 SUGGESTION

| Issue | Fix Applied |
|-------|-------------|
| IMPORTANT-1: Batch 4 file count understated (4 vs actual 9) | Corrected header to "Files (9)" with breakdown |
| IMPORTANT-2: 2000-token manifest overflow not validated | Added orchestrator-agent + git-agent dry-run checks to Batch 1 validation |
| IMPORTANT-3: auto_orchestration.md growth undocumented | Added growth note (334→~355) with rationale in Batch 2 |
| SUGGESTION-1: Batch 5b cross-ref count knowable | Replaced "8-10" with anchor vs filename breakdown (3 anchors + ~12 filename-only) |
| SUGGESTION-2: Section line ranges may shift | Noted: verify at implementation time (no files modify guidelines before 5a) |
| SUGGESTION-3: `.cursorrules` trigger table evaluation | Already handled as open question — no change needed |

### Round 3 (v3 refinement): 0 CRITICAL, 0 IMPORTANT, 4 SUGGESTION

| Issue | Fix Applied |
|-------|-------------|
| SUGGESTION-1: Risk table still said "10-15+" for Batch 5b | Updated to match batch description: "3 anchor-linked + ~12 filename-only" |
| SUGGESTION-2: Cursor .mdc says "verify it has trigger table" but it doesn't | Corrected: notes delegation pattern, no trigger table/token scripts inline |
| SUGGESTION-3: CLAUDE.md KEEP/REMOVE missing Quick Commands + Escape hatches | Added explicit line references for ALL 79 lines — every line accounted for |
| SUGGESTION-4: KEEP line arithmetic not verified | Verified: 32 content + ~10 blank = ~42-44 lines. Target ~45 confirmed achievable |

---

## Open Questions

1. **Agent Boundaries table in instruction files?** Behavioral but 5 lines. Recommendation: condense to 3 bullets.
2. **Root `.cursorrules` expansion?** Currently 27 lines. Evaluate trigger table addition in Batch 3.
3. **"Check Before Creating" destination?** Recommendation: anti-hallucination.md (related concern).
4. **Should A7 LLM test block ag.sh changes?** No — references are harmless regardless.
5. **`.codex/instructions.md` intermediate target?** If 286 → 55 is too aggressive, accept ~80 as Phase 1.

---

## What This Plan Does NOT Do

1. Does NOT change pre-commit-check.sh (DO NOT CHANGE list)
2. Does NOT change manifest-based injection mechanism (always-inject is additive)
3. Does NOT restructure auto_orchestration.md beyond receiving moved content
4. Does NOT add Gemini support
5. Does NOT create config.json aggregation
6. Does NOT change git-tracked vs gitignored state split
7. Does NOT reduce smoke_testing.md, retrospective.md, session_start/end.md, agent_behavior_verification.md
