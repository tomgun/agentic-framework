# Agentic Framework Performance Review: jump-game

## Context

Review of how the Agentic Framework performs in a real greenfield project — a Phaser 3 + TypeScript jumping game at `.../jump-game`. Project active 4 days (2026-02-19 to 2026-02-23), 10 commits, ~14,700 LOC, 12 features shipped. Discovery profile, single agent, direct git workflow, framework v0.28.1.

Cross-referenced against `docs/INSTRUCTION_ARCHITECTURE.md` (three-layer architecture) and `.agentic/PRINCIPLES.md` (13 framework principles) to grade how well the architecture held up.

---

## THE ROOT CAUSE: Pre-commit hooks were never installed

**This single failure explains most issues found.** The framework's pre-commit-check.sh (786 lines, 12 structural checks) exists in `.agentic/hooks/` but `git config core.hooksPath` was **never set**. Verification:

```
$ git config core.hooksPath   → (not set)
$ ls .git/hooks/pre-commit    → No such file
```

The hook already enforces:
| Check | Default limit | Would have caught |
|-------|--------------|-------------------|
| Max files per commit | 10 | C1 — oversized commits |
| Max added lines | 500 | C1 — 2,320 line commit |
| Max code file length | 500 | C4 — Game.ts at 1,350 lines |
| Test execution | Blocking | C3 — would run tests if they existed |
| JOURNAL.md freshness | Blocking | Already maintained (would reinforce) |
| STATUS.md freshness | Blocking | Already maintained (would reinforce) |
| WIP.md presence | Blocking | C2 — would block commit if WIP existed |
| Batch size warning | >7 files | Most commits |

**scaffold.sh** (line 387-399) is supposed to set `core.hooksPath` during init. **ag sync** (line 458-468) checks and fixes it. **upgrade.sh** (line 449-456) also sets it. But none of these ran successfully for this project — the config was never set, and no runtime check warned about it.

**This is the framework's biggest reliability gap**: Principle D2 (Deterministic Enforcement) was correctly implemented in pre-commit-check.sh, but the enforcement **of the enforcement setup** is behavioral — it depends on scaffold.sh succeeding and the git config persisting. The framework has no "defense in depth" for its own installation.

---

## Architecture Grade: How Each Layer Performed

### Layer 1: Constitution (Instruction Files) — Grade: B+

CLAUDE.md, .cursorrules, .codex/instructions.md, .github/copilot-instructions.md are all present, consistent, and appropriately sized. The trigger table format works: agents correctly recognized "build/implement" triggers and "commit/push" triggers based on journal evidence.

**What worked**: Multi-tool parity (D7), token-efficient script references (agents used journal.sh/status.sh consistently), trigger table compliance.

**What didn't work**: Behavioral rules that compete with momentum — "IMMEDIATELY create WIP.md", "Add/update tests", "Code + docs = done" — were systematically ignored. This validates the architecture doc's core thesis: *"Documentation can be ignored. Guidelines can be misunderstood. Critical workflows must be reliable, not 'usually' reliable."* (PRINCIPLES.md D2)

**Evidence**:
- Token-efficient scripts: Used in all 12 journal entries ✓
- Trigger table: Features went through planning flow ✓
- "Never auto-commit": No evidence of auto-commits ✓
- "IMMEDIATELY create WIP.md": 0/12 features used WIP ✗
- "Add/update tests": 1/12 features tested ✗
- "Code + docs = done": README stale since day 1 ✗

**Conclusion**: Constitutional rules that align with agent momentum (journal, status, trigger responses) have high compliance. Constitutional rules that require agents to slow down or add ceremony (WIP, tests, docs) have near-zero compliance without structural enforcement backing them. The architecture doc calls this exactly right.

### Layer 2: Playbooks (Just-in-Time Guidance) — Grade: C

**What worked**: auto_orchestration.md exists with comprehensive workflows. `ag` commands exist and print relevant playbook references (Gap 3 was resolved).

**What didn't work**: Unclear if playbooks were ever loaded. The JOURNAL.md shows agents jumping straight to implementation without evidence of running `ag plan`, `ag implement`, or other commands that would trigger playbook loading. The one saved plan (AUDIO-002) shows planning happened at least once, but 11/12 features show no evidence of playbook engagement.

**Architecture doc assumption A7**: "ag command stdout has high salience to agents" — marked UNTESTED. This project suggests the assumption may be false, or that `ag` commands were never run. Either way, the playbook layer didn't demonstrably influence behavior.

### Layer 3: Project State — Grade: A-

**What worked**:
- STATUS.md accurately reflects current project state
- JOURNAL.md has 12 consistent, useful entries that enable session continuity
- FEATURES.md is detailed with file paths, technical descriptions, presets
- HUMAN_NEEDED.md correctly used for human decisions only
- TODO.md properly used as capture inbox
- One plan durably saved to `.agentic-journal/plans/`

**What didn't work**:
- CONTEXT_PACK.md still has template placeholders (never customized after scaffold)
- OVERVIEW.md capability checklist never updated (all `[ ]`)
- README.md never updated after features shipped
- 11/12 plans lost (made in `.claude/plans/` session scope, not saved durably)

**Conclusion**: State files that are written by token-efficient scripts (JOURNAL, STATUS) stay current. State files that require manual editing (CONTEXT_PACK, README, OVERVIEW) drift immediately and never recover.

### Memory Seed Layer — Grade: Untestable

Cannot determine if memory-seed was loaded or influenced behavior. The architecture doc correctly notes this is "redundant reinforcement, not primary enforcement." Given that primary enforcement (hooks) failed, memory reinforcement alone was insufficient.

### Distributed Enforcement — Grade: F (Not Active)

**Designed enforcement surface**:
- `ag implement` → checks acceptance criteria + approved plan
- `pre-commit-check.sh` → 12 structural checks
- `ag done` → runs doctor.sh

**Actual enforcement surface**: None. core.hooksPath not set, so pre-commit-check.sh never ran. No evidence of `ag implement` or `ag done` being used (no WIP files, no doctor.sh output in journal).

---

## Principle-by-Principle Scorecard

| Principle | Score | Evidence |
|-----------|-------|----------|
| **F1**: Developer-Friendly Experience | **A-** | Session dashboard, state files, readable artifacts all work. Missing: WIP recovery (never used) |
| **F2**: Sustainable Quality | **D** | Tests nearly absent, docs stale, no acceptance criteria. Quality infrastructure exists but isn't activated |
| **F3**: Token & Context Optimization | **A** | Token-efficient scripts used consistently, structured JOURNAL entries, compact state files |
| **D1**: Human-Agent Partnership | **B+** | Human decisions properly surfaced in HUMAN_NEEDED.md. Agent presents changes. No auto-commits |
| **D2**: Deterministic Enforcement | **F** | **The framework's core differentiator failed.** Hooks not installed. No structural check caught any violation |
| **D3**: Durable Artifacts | **B** | Core artifacts (JOURNAL, STATUS, FEATURES) excellent. CONTEXT_PACK, README, OVERVIEW stale |
| **D4**: Small Batch + Acceptance-Driven | **D** | No acceptance criteria. Commit sizes routinely exceed limits. One feature at a time: mostly followed |
| **D5**: Living Documentation | **D** | "Same commit rule" violated on nearly every feature. README never updated |
| **D6**: Green Coding | **B** | Token-efficient scripts used. No evidence of wasteful patterns |
| **D7**: Multi-Env Portability | **A** | 4 instruction files, consistent, all functional |
| **R1**: Anti-Hallucination | **A** | No evidence of fabricated APIs or incorrect claims |
| **R2**: No Auto-Commits | **A** | No auto-commits detected |
| **R3**: Check Before Creating | **B** | No duplicate files. Some empty placeholder dirs remain |

---

## What's Working Well (Details)

### 1. State file continuity is excellent
12 journal entries, up-to-date STATUS.md, detailed FEATURES.md. This is the framework's strongest real-world validation. Cross-session context is genuinely maintained.

### 2. Multi-tool instruction parity works
4 instruction files (CLAUDE.md, .cursorrules, .codex/instructions.md, copilot-instructions.md) are consistent and appropriately sized. D7 is validated.

### 3. HUMAN_NEEDED.md is used correctly
3 entries, all genuine human decisions. No dev tasks leaked in. Properly resolved with outcomes and actions. D1 is validated for escalation patterns.

### 4. Discovery profile enables velocity
12 features in 4 days is significant output. The reduced ceremony of discovery profile (no formal specs, direct commits) is appropriate for prototyping.

### 5. Token-efficient scripts work
JOURNAL.md and STATUS.md are always current because the scripts make updating them frictionless. F3 is validated.

---

## Issues Found (Details)

### Critical

**C1. Pre-commit hooks not installed** (see root cause above)
- Impact: ALL structural enforcement was silently disabled
- Framework principle violated: D2 (Deterministic Enforcement)

**C2. WIP tracking never used**
- .agentic-state/ directory is empty across all 12 features
- CLAUDE.md says "IMMEDIATELY create WIP.md" — purely behavioral instruction
- Impact: No work-in-progress recovery capability
- Framework principle validated: D2 — behavioral rules don't work without structural backing

**C3. Test coverage: 1/12 features**
- Only `AnatomicalMapper.test.ts` (163 lines, 17 tests)
- ArtSynthesizer.ts (1,323 lines), Game.ts (1,350 lines), AudioManager.ts (354 lines) — all untested
- Framework principle violated: F2, D4 (tests verify acceptance criteria)

**C4. Game.ts is 1,350 lines (God class)**
- Handles: game loop, 3 input types, 5 UI panels, modifier system, audio integration, particles
- Default `max_code_file_length` is 500 — would have been caught if hooks were active
- Framework principle violated: D4 (small batches)

### Moderate

**M1. CONTEXT_PACK.md never customized**
Still has template placeholder code examples (`calculateTotal`), blank "Known risks", placeholder documentation list. Violates D5 (Living Documentation) and D3 (Durable Artifacts).

**M2. README.md never updated after features shipped**
- Says "Physically Simulated Audio (coming soon)" — shipped day 1
- Roadmap checklist all unchecked despite 12 features shipped
- Violates D5 ("same commit rule") on every single commit

**M3. 11/12 plans lost**
Only AUDIO-002 saved to `.agentic-journal/plans/`. All others presumably made in `.claude/plans/` (session-scoped) and lost. Violates D3 (plans are durable artifacts).

**M4. VERSION mismatch** (.agentic/VERSION=0.28.1, STACK.md=0.30.0)

**M5. FEATURES.md duplicate ID** (AUDIO-003 used twice)

**M6. OVERVIEW.md capabilities all unchecked** despite many being shipped

---

## Framework Improvement Recommendations

*Reviewed by a fresh Plan agent against the actual codebase. Fixes validated against ag.sh, pre-commit-check.sh, scaffold.sh, sync.sh, settings.sh, and presets/profiles.conf.*

### Fix 1 (HIGH): Self-healing hook installation in ag preamble

**Status**: RECOMMENDED — addresses root cause, highest impact, smallest change.

The framework already warns about missing hooks in `cmd_start()` (ag.sh:316-323) and fixes them in `ag sync --full` (sync.sh:452-476). But neither runs automatically. The fix: add a preamble function to ag.sh that auto-fixes on every `ag` command invocation.

**Important caveat found in review**: Must respect `pre_commit_hook: no` in STACK.md to avoid overriding deliberate disablement.

**File**: `.agentic/tools/ag.sh` — add before command dispatch (~line 2270):
```bash
_ensure_hooks() {
    local hook_mode
    hook_mode=$(get_setting "pre_commit_hook" "fast")
    [[ "$hook_mode" == "no" ]] && return 0
    [[ ! -d "$ROOT_DIR/.agentic/hooks" ]] && return 0
    command -v git >/dev/null 2>&1 || return 0
    git rev-parse --git-dir >/dev/null 2>&1 || return 0
    local hooks_path
    hooks_path=$(git config core.hooksPath 2>/dev/null || echo "")
    if [[ "$hooks_path" != ".agentic/hooks" ]]; then
        git config core.hooksPath .agentic/hooks
        echo -e "${YELLOW}Auto-fixed: pre-commit hooks installed (core.hooksPath)${NC}" >&2
    fi
}
_ensure_hooks
```

### Fix 2 (SKIP): Loud warning at session start

**Status**: ALREADY EXISTS — `cmd_start()` at ag.sh:316-323 already warns. Mooted by Fix 1 (auto-fix runs before warning code).

### Fix 3 (SKIP): Discovery profile defaults

**Status**: ALREADY IMPLEMENTED — Discovery preset in `profiles.conf` already has:
- `discovery.max_files_per_commit=15`
- `discovery.max_added_lines=1000`
- `discovery.max_code_file_length=1000`

These are already more permissive than proposed values. No change needed.

### Fix 4 (MEDIUM): Test co-presence check in pre-commit

**Status**: RECOMMENDED — advisory only, full-mode only.

The pre-commit hook runs existing tests (check 6) but never checks if tests *exist* for changed files. Add as Check 13 (advisory, non-blocking).

**File**: `.agentic/hooks/pre-commit-check.sh` — add before Summary section (~line 767):
- Check common test patterns: `.test.ts`, `.spec.ts`, `test_*.py`, `*_test.go`
- Also check `tests/` mirror directories
- Skip non-source files, configs, docs, type definitions
- Only run in full mode (not fast)
- Advisory only — never blocks

### Fix 5 (LOW): CONTEXT_PACK.md placeholder detection in ag sync

**Status**: RECOMMENDED — small, advisory.

Note: `check_initialization()` in ag.sh already checks for placeholders, but only triggers when 4+ issues found. `ag sync` doesn't check at all.

**File**: `.agentic/tools/sync.sh` — add to `phase_state_freshness()`:
- Grep for template markers: `<!-- 1`, `<!-- fill`, `<!-- bullets`, `<!-- e.g.`, `<!-- path -->`
- Warn when 3+ placeholders found (prevents false positives)

### Fix 6 (SKIP): "Coming soon" drift in README

**Status**: SKIP — wrong enforcement layer. Framework should enforce structural invariants (tests exist, specs match code, hooks fire), not lint prose content. Also fragile (would need to match "planned for v2", "future work", "roadmap", etc.).

### Fix 7 (MEDIUM): Auto-save plans on ag implement

**Status**: RECOMMENDED — prevents plan loss, isolated change.

`cmd_implement()` checks for plans in `.agentic-journal/plans/` but never looks in `.claude/plans/`. Plans made via Claude Code's plan mode are session-scoped and lost.

**File**: `.agentic/tools/ag.sh` — add to `cmd_implement()` after plan-review block (~line 636):
```bash
local durable_plan="$ROOT_DIR/.agentic-journal/plans/${feature_id}-plan.md"
if [ ! -f "$durable_plan" ] && [ -d "$ROOT_DIR/.claude/plans" ]; then
    for f in "$ROOT_DIR/.claude/plans/"*; do
        if [ -f "$f" ] && grep -q "$feature_id" "$f" 2>/dev/null; then
            mkdir -p "$ROOT_DIR/.agentic-journal/plans"
            cp "$f" "$durable_plan"
            echo -e "${GREEN}Plan auto-saved: .claude/plans/ -> .agentic-journal/plans/${feature_id}-plan.md${NC}"
            break
        fi
    done
fi
```

### Implementation sequence

1. **Fix 1** — self-healing hooks (root cause, 1 file)
2. **Fix 7** — plan auto-save (prevents plan loss, 1 file)
3. **Fix 4** — test co-presence check (new pre-commit check, 1 file)
4. **Fix 5** — CONTEXT_PACK placeholder detection (1 file)

**Total**: 3 files modified (ag.sh, pre-commit-check.sh, sync.sh). All changes additive. No breaking changes.

---

## Meta-Insight: The Enforcement Paradox

The framework's own design document states its most important principle:

> **"Never rely on memory — if a rule must always apply, enforce it structurally"** (INSTRUCTION_ARCHITECTURE.md §5.1)

> **"Scripts enforce; memory reinforces... Only structural enforcement (scripts with exit codes) survives the entire session reliably"** (INSTRUCTION_ARCHITECTURE.md §2, Memory Seed Layer)

> **"Documentation can be ignored. Guidelines can be misunderstood. Critical workflows must be reliable, not 'usually' reliable"** (PRINCIPLES.md D2)

The framework applied this principle to agent behavior (pre-commit hooks, WIP checks, complexity limits) but **not to its own installation**. The enforcement mechanism is itself enforced behaviorally — scaffold.sh runs once, ag sync is optional, and nothing verifies the hooks are active.

**The fix is to apply D2 to itself**: every `ag` command should verify hooks are installed (self-healing), and session start should warn loudly if they're not. Make the framework's enforcement infrastructure as deterministic as the enforcement it provides.

This is the single highest-impact improvement: it doesn't require new features — it activates the extensive enforcement that already exists.

---

## Summary Scorecard

| Category | Score | Key Finding |
|----------|-------|-------------|
| Session continuity (JOURNAL/STATUS) | **A** | Consistently maintained, token-efficient scripts work |
| Feature tracking (FEATURES.md) | **A-** | Detailed, minor ID duplicate |
| Human blocker tracking | **A** | Correct usage, proper escalation |
| Velocity | **A+** | 12 features in 4 days, deployed |
| Multi-tool support | **A** | 4 AI tools properly configured |
| Anti-hallucination | **A** | No fabricated APIs or claims |
| Token efficiency | **A** | Scripts used consistently |
| Deterministic enforcement (D2) | **F** | Hooks not installed — root cause of all D/F grades below |
| Test coverage | **D** | 1/12 features tested |
| Commit discipline | **D** | Oversized commits, no enforcement active |
| WIP tracking | **F** | Never used |
| Doc freshness | **D** | README, CONTEXT_PACK, OVERVIEW all stale |
| Plan durability | **D+** | 1/12 plans saved |
| Code organization | **C-** | 1,350 line God class |

**Overall**: The framework's **information architecture** (state files, journal, multi-tool instructions) is excellent and provides genuine value. The framework's **enforcement architecture** (pre-commit hooks, complexity limits, test gates) is well-designed but was **silently disabled** because hook installation failed and nothing detected it. Fixing the self-healing hook installation would likely raise 5-6 grades from D/F to B+ or better with zero new features needed.
