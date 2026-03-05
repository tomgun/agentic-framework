# Plan: Slim Down Tool Instruction Files + Fix Test Bugs

## Context

LLM behavioral tests confirm bloated instruction files cause compliance failures. Session start protocol (buried at line 120+ in 277-line CLAUDE.md) is skipped. Acceptance criteria checks also skipped. Cursor `.cursorrules` at 69 lines proves all behaviors fit concisely.

**Root cause**: CLAUDE.md grew 6x over several commits. When everything is "MANDATORY" and "STOP", nothing stands out. (L-0002)

**Two-layer context model**: CLAUDE.md is auto-loaded for ALL agents - both top-level and every subagent via Task tool. Subagents also get focused context from parent via `context-for-role.sh`. The slimdown benefits both: top-level agents see critical instructions first, subagents waste less context on irrelevant sections (delegation tables, session start).

---

## Revised Structure (after plan-review)

**Key review finding**: Session start should NOT be line 1. Identity + "consult these files" should come first (what subagents need most). Session start goes in a clearly-marked section but NOT buried at line 120+.

**Proposed order** (following cursorrules.txt pattern which already works):

```
1-2:   Identity + consult list (include agent_operating_guidelines.md explicitly)
3-14:  Enforced gates table (compact)
15-16: Escape hatches + quick commands
17-25: Trigger words table
26-28: Acceptance criteria gate
29-32: Small batch (compact, preserve "5-10 files" for F-0121 test)
33-37: Rules (compact list, preserve "PR by default" for AC-004 test)
38-44: Agent boundaries table
45-50: Agent mode (compact, like cursorrules lines 51-56)
51-55: Token-efficient scripts (4 lines, like cursorrules)
56-60: Session protocols (START/END/DONE - 5 lines, with greeting instruction)
61-62: Checklists reference (1 line)
```

**Claude-specific additions** (~10 extra lines):
- Task tool delegation table (subagent_type mapping) - lines 63-70
- Standards references (programming, testing, dev mode) - lines 71-73

**Target**: CLAUDE.md template ~75 lines, copilot/codex ~65 lines

### Behaviors explicitly preserved (reviewer flagged these)

| Behavior | Current | Slimmed |
|----------|---------|---------|
| Docs = part of done | 8 lines with anti-pattern example | 1 line: "Code + docs = done (update docs with code, not later)" |
| Feature complete checklist | 10 lines inline | 1 line ref to checklist file |
| Auto journaling | 7 lines | 1 line in token-scripts: "Log at natural checkpoints, not just session end" |
| Multi-agent awareness | 3 lines | 1 line: "Multi-agent: check .agentic-state/AGENTS_ACTIVE.md" |
| `|| true` (codex only) | 6 lines with examples | 1 line note in codex version |

### Tool-specific differences table

| Section | Claude | Cursor | Copilot | Codex |
|---------|--------|--------|---------|-------|
| Task tool delegation | YES (10 lines) | NO | NO | NO |
| `|| true` bash note | NO | NO | NO | YES (1 line) |
| Git workflow detail | YES (PR by default) | YES | YES | YES |

---

## Files to Modify

### Templates (installed to user projects)

| File | Current | Target | Action |
|------|---------|--------|--------|
| `.agentic/agents/claude/CLAUDE.md` | 277 lines | ~75 | Rewrite |
| `.agentic/agents/copilot/copilot-instructions.md` | 268 lines | ~65 | Rewrite |
| `.agentic/agents/codex/codex-instructions.md` | 268 lines | ~65 | Rewrite |

Reference (no changes): `.agentic/agents/cursor/cursorrules.txt` (69 lines, the model)

### Root framework-dev files

| File | Current | Target | Action |
|------|---------|--------|--------|
| `CLAUDE.md` | 303 lines | ~90 | Template + framework section at top |
| `.github/copilot-instructions.md` | 118 lines | ~80 | Trim to match slimmed template + framework header |
| `CODEX.md` | 134 lines | ~80 | Trim to match slimmed template + framework header |
| `.cursorrules` | 27 lines | 27 | No change (already optimal) |

**Root CLAUDE.md structure** (reviewer finding: framework warnings at TOP):
```
1-3:   Framework identity + "extra care" warning
4:     Read first: FRAMEWORK_QUICK_START.md
5-75:  Template content (from above)
76-90: Framework-specific: validation, dogfooding, spec-first rules, worktree guidance
```

### Test fixes

| File | Bug | Fix |
|------|-----|-----|
| `tests/llm/tests/002_wip_blocks_commit.sh` | Line 11: `mkdir -p .agentic` should be `.agentic-state` | Change mkdir path |
| `tests/llm/tests/003_acceptance_first.sh` | Line 17: `class Auth` and `impl.*auth` match natural language | Tighten to code-only patterns: `function authenticate(\|class Auth[({]\|def authenticate\|import.*authenticate` |

### Validation file updates

| File | What to check |
|------|---------------|
| `tests/validate_framework.sh` | F-0121 greps must still match slimmed content. Phrases to preserve exactly: "Acceptance criteria", "WIP", "Test execution", "Complexity limits", "Pre-commit", "Feature status", "SKIP_TESTS", "SKIP_COMPLEXITY", "small batch" or "TOO BIG" or "5-10 files", "PR by default". Root CODEX.md must preserve `Full template.*codex-instructions` (validated at line 1047). |

---

## Documentation Updates

### Update L-0002 lesson (`/.agentic-journal/lessons/L-0002-instruction-bloat-breaks-compliance.md`)

Add section: "CLAUDE.md is auto-loaded for EVERY subagent spawned via Task tool, not just the top-level agent. A 277-line CLAUDE.md means every implementation agent, test agent, and explore agent burns context on 200+ lines of irrelevant instructions (delegation tables, session start protocol). At balanced mode with haiku subagents, this context waste is proportionally even more expensive since haiku has a smaller effective context budget."

### Update FRAMEWORK_DEVELOPMENT.md (lines 90-95, "When adding new features to CLAUDE.md")

Add to the existing guidance: "CLAUDE.md is auto-loaded for ALL agents including subagents. Every line added to CLAUDE.md is multiplied across every Task tool invocation. Keep under 100 lines. Run LLM behavioral tests after changes."

---

## Implementation Order

1. Fix test bugs (002, 003) - independent, quick
2. Rewrite Claude template (`.agentic/agents/claude/CLAUDE.md`)
3. Rewrite copilot template (model after cursorrules + copilot specifics)
4. Rewrite codex template (model after cursorrules + `|| true` note)
5. Update root `CLAUDE.md` (template + framework section)
6. Update root `.github/copilot-instructions.md` and `CODEX.md`
7. Run `bash tests/validate_framework.sh` - verify F-0121 passes
8. Run `bash tests/llm/harness.sh --critical` - verify LLM behavioral tests pass

Steps 2-4 can be parallelized. Step 5-6 depend on 2-4.

---

## Verification

1. `bash tests/validate_framework.sh` passes (F-0121 template parity intact)
2. `bash tests/llm/harness.sh --critical` passes (001 session start, 002 WIP, 003 acceptance, 005 no-auto-commit, 010 feature-needs-spec)
3. `wc -l` on each file confirms under target line count
4. Grep for preserved phrases: "5-10 files", "PR by default", all 6 gate names, "SKIP_TESTS"
