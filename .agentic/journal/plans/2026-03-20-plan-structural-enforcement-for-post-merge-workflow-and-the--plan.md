# Plan: Structural Enforcement for Post-Merge Workflow (and the broader reliability problem)

**Status**: DRAFT

## Context: The Pattern That Keeps Repeating

In this session, I merged 3 PRs and forgot to run `ag dogfood` after any of them — despite the rule existing in completing-work Step 6, memory-seed, auto-memory, and the CLAUDE.md I'm reading right now. This happened in the same session where we built the doc decision tree to fix the exact same class of problem (agents skipping behavioral steps).

The pattern across the framework's history:
1. Agent skips step X → We add X to more instruction files → Agent still skips X → We add structural enforcement → X never gets skipped again

Evidence from this framework:
- **Pre-commit checks (13 blocking gates)**: ZERO bypasses. Ever. They're scripts.
- **`ag merge` → `ag done` chain**: When used, dogfood runs automatically. 100% reliable.
- **Behavioral rules in instruction files**: Periodic failures. 20+ doc update skips. 3+ instruction file skips. Now a dogfood skip.

The framework already has principle D2: *"Critical behavior is enforced by scripts and gates, not by documentation and hope."* We keep violating our own principle by adding behavioral rules for things that need structural enforcement.

## Root Cause: The LLM Bypassed the Entry Point

The specific failure chain:
1. User said "merge the prs systematically"
2. I used `gh pr merge 170` — the raw GitHub CLI command
3. Because I bypassed `ag merge`, the `ag done` chain never fired
4. Because `ag done` never fired, dogfood/VERSION/flush never ran

If I had used `ag merge 170 F-0221`, everything would have been automatic. The structural chain already exists — the LLM bypassed it.

## The Reliability Hierarchy

| Level | Mechanism | Reliability | Example |
|-------|-----------|------------|---------|
| **Automated chaining** | Script A triggers Script B | ~100% | `ag merge` → `ag done` → dogfood |
| **Blocking gates** | Script exits non-zero | ~100% | Pre-commit Check 14 (shipped spec) |
| **State-based detection** | Hook detects bad state, warns | ~95% | UserPromptSubmit DRAFT plan check |
| **Concrete behavioral** | Instructions with exact file paths | ~85% | 3-concern doc decision tree |
| **Vague behavioral** | "Remember to do X" | ~60% | The old Step 6 one-liner |

**The solution isn't more behavioral rules. It's promoting critical steps up the hierarchy.**

## Deliverables

### 1. UserPromptSubmit detection: "merged but not done"

Add detection #5 to `.agentic/lib/claude-hooks/UserPromptSubmit.sh`:

- On main/master branch
- Extract F-XXXX IDs from last 5 commit messages (catches recent squash merges)
- For each F-ID: check if shipped in FEATURES.md
- If not shipped → warn: `"⚠️ F-XXXX was merged but ag done was not run. Run: ag done F-XXXX"`

This fires on every user prompt (cheap — a few greps), catches the gap within the same session. Same pattern as the DRAFT plan detection that already works.

### 2. PostToolUse detection: "gh pr merge" without "ag merge"

New hook script `.agentic/lib/hooks/shared/on-bash-merge-detect.sh`:

- Matcher: `Bash` tool in hooks.json
- Fast exit: if tool input doesn't contain `gh pr merge` → exit 0 immediately (<1ms)
- If `gh pr merge` detected → output: `"⚠️ Use ag merge instead — it chains ag done automatically (dogfood, VERSION, backlog). Run ag done F-XXXX now."`

Wire into both `.claude/hooks.json` and `.agentic/lib/claude-hooks/hooks.json`.

### 3. Codify enforcement hierarchy in PRINCIPLES.md

Add subsection to D2 (Deterministic Enforcement):

> **Enforcement Hierarchy** (most to least reliable):
> 1. **Automated chaining**: Action A structurally triggers Action B. Use for: multi-step sequences.
> 2. **Blocking gates**: Script exits non-zero. Use for: invariants before transitions.
> 3. **State-based detection**: Hook warns on bad state. Use for: catching bypassed entry points.
> 4. **Behavioral guidance**: Concrete instructions. Use for: judgment-dependent decisions.
>
> **Promotion rule**: If a behavioral rule has been skipped 3+ times across sessions, promote it to a higher level. Repeated failures are evidence of misclassification, not insufficient documentation.

### 4. Audit & promote known repeat offenders

| Rule | Failures | Current | Promote To |
|------|----------|---------|-----------|
| Dogfood after merge | This session | Behavioral (skill) | State detection (#1 above) |
| `gh pr merge` vs `ag merge` | This session | Behavioral (memory) | PostToolUse detection (#2 above) |
| Update CHANGELOG for shipped features | 13+ features | Behavioral | Done (T-0082 validate_framework.sh) |
| Instruction file sync | 3+ times | Behavioral + advisory `instruction-sync.sh` | Consider: blocking in validate_framework.sh |

## Critical Files

- `.agentic/lib/claude-hooks/UserPromptSubmit.sh` — add detection #5
- `.agentic/lib/hooks/shared/on-bash-merge-detect.sh` — new hook
- `.agentic/lib/claude-hooks/hooks.json` + `.claude/hooks.json` — wire Bash matcher
- `.agentic/lib/PRINCIPLES.md` — enforcement hierarchy subsection in D2

## Verification

1. On main after a merge: send a user prompt → UserPromptSubmit warns about unshipped features
2. Run `gh pr merge` in Bash → PostToolUse reminds to run `ag done`
3. `validate_framework.sh` passes
4. PRINCIPLES.md D2 has the enforcement hierarchy with the "3+ failures = promote" rule
