# Deep Optimization: Claude Hooks & Skills Enforcement Architecture

## Context

The Agentic Framework (42 shipped features, F-001 through F-042 + DEV-001 through DEV-004) uses Claude Code hooks, skills, and CLI commands to enforce a structured development workflow. After a deep audit of **every** hook script, skill file, gate.py policy engine, settings system, 70+ ag commands, auto-orchestration pipeline (scheduler, engine, parallel, intents, verify loop, pipeline, kickoff, epic), intelligence engine, contract system, drift/sync framework, and documentation layer, this plan identifies the gap between what the framework promises and what it structurally guarantees — then proposes concrete changes to make it work **brilliantly** in Claude Code.

**Key design principle**: Intelligence (quality checklists, domain patterns, cerebrum, decision support) is a CORE VALUE for ALL profiles — not ceremony restricted to formal. Only enforcement gates scale by profile. Intelligence is on by default for everyone.

---

## Part A: Complete Audit — 42 Features Mapped to Enforcement

### Tier 1: Structurally Guaranteed (hooks block/deny)
| Feature | ID | Mechanism | Reliability |
|---------|-----|-----------|-------------|
| Destructive git ops blocked | F-023 | PreToolUse → gate.py regex → deny | 100% |
| Spec-first (no code without spec) | F-002 | PreToolUse → gate.py F-0251 → deny | 100% (formal) |
| DRAFT plan blocks session stop | F-004 | Stop.sh → gate.py → exit 2 | 100% |
| Unshipped merge blocks stop | F-024 | Stop.sh → gate.py → exit 2 | 100% |
| Feature branch without PR blocks stop | F-024 | Stop.sh → gate.py → exit 2 | 100% |
| Fail-closed on gate crash | F-023 | PreToolUse + state_enforcement | 100% |
| Shipped spec migration required | F-031 | pre-commit check 14/23 | 100% (at commit) |
| State machine transitions | F-003 | gates.py preconditions | 100% (via CLI) |
| Backlog position 0 lock | F-006 | implement.sh + backlog_helpers.py | 100% (via CLI) |
| Completion gate (stale features) | F-006 | backlog_helpers.py check-completion-gate | 100% (via CLI) |
| Pre-commit quality gates (23 checks) | F-009 | pre-commit-check.sh | 100% (at commit) |
| Contract assertion verification | F-031 | gate.py check_verification_passes | 100% (at verify) |

### Tier 2: Advisory (hooks warn, agent sees but may ignore)
| Feature | ID | Mechanism | Reliability |
|---------|-----|-----------|-------------|
| Stale journal/status reminder | F-015 | UserPromptSubmit | ~70% |
| Batch work detection | F-030 | UserPromptSubmit regex | ~80% |
| DRAFT plan warning on code edit | F-004 | on-code-edit.sh (PostToolUse, AFTER edit) | ~50% |
| Pattern warnings at write-time | F-041 | PreToolUse stderr | ~60% |
| Capability catalog nudge | F-042 | UserPromptSubmit one-time | ~40% |
| Missing artifact status | F-002 | PostToolUse + UserPromptSubmit | ~50% |
| Multi-session collision warning | F-017 | UserPromptSubmit | ~80% |
| Merge detection (gh pr merge bypass) | F-024 | on-bash-merge-detect.sh | ~70% |
| Context compaction state preservation | F-015 | PreCompact.sh | ~90% |

### Tier 3: Behavioral Only (agent must read and comply)
| Feature | ID | Where Instructed | Reliability |
|---------|-----|-----------------|-------------|
| Plan review loop (Critic+Advocate) | F-004 | on-plan-mode-exit.sh + CLAUDE.md + skill | ~60% |
| TDD (test before code) | F-007 | fixing-bugs skill | ~30% |
| Journal/overview updates during impl | F-015 | committing-changes skill | ~40% |
| Doc updates during implementation | F-012 | implementing-features skill | ~35% |
| `ag auto crunch` for batch work | F-030 | CLAUDE.md + warning | ~50% |
| Intelligence surfacing at decisions | F-041 | Skill says "run ag intel implement" | ~20% |
| Spec migration creation | F-031 | gate.py allows with warning | ~40% |
| Correction capture (ag intel remember) | F-041 | Skill prose | ~15% |
| Idea → backlog flow | F-006 | CLAUDE.md trigger words | ~30% |
| NFR discovery & enforcement | F-013 | ag nfr discover (must be called) | ~15% |
| Question patterns for decisions | — | Not implemented | 0% |
| Specs↔tests↔code↔docs live sync | F-002/F-012 | Only at commit/done gates | ~40% |
| Domain intelligence creation | F-041 | ag intel bootstrap (manual) | ~10% |
| Kickoff/vision to backlog | F-004 | ag kickoff (must know to call) | ~25% |
| Epic decomposition workflow | F-005 | ag decompose (must know to call) | ~20% |
| Review checkpoint system | F-014 | review.py (works in auto, not in interactive) | ~50% |
| Drift detection & auto-fix | F-012 | ag sync (must be called periodically) | ~20% |
| Intent recovery after crash | F-016 | ag intent list (must know to call) | ~15% |
| Context-for-role (subagent context) | F-019 | context-for-role.sh | ~30% |
| Publishing workflow | F-040 | ag publish (domain-specific) | ~40% |
| Phase tracking (multi-session) | F-032 | ag phase (must know to call) | ~20% |
| Session logging checkpoints | F-015 | PostToolUse auto-checkpoint every 10 | ~80% |

---

## Part B: Optimization Plan — 18 Changes, 5 Phases

### Phase 1: Core Structural Upgrades (behavioral → blocking)

#### Change 1: DRAFT-plan check in PreToolUse (deny BEFORE edit)
**Problem**: on-code-edit.sh fires AFTER edit. "STOP CODING" banner is theater.
**Fix**: Add `check_pending_plan_review()` to `gate_pretool()` for non-safe files.
**Files**: `.agentic/lib/gate.py`
**Profile**: discovery=skip, formal/autonomous_formal=deny

#### Change 2: Shipped-spec editing escalated to blocking
**Problem**: gate.py allows shipped spec edits with advisory warning.
**Fix**: Respect `state_enforcement` — deny when blocking.
**Files**: `.agentic/lib/gate.py` lines 733-748

#### Change 3: Consolidate Python calls in UserPromptSubmit
**Problem**: 2-3 Python subprocesses per prompt (~300-500ms each), 3s timeout.
**Fix**: Single `gate prompt-context` combining resolve + artifacts + cerebrum + intel.
**Files**: `.agentic/lib/gate.py`, `UserPromptSubmit.sh`
**Savings**: ~600-800ms per prompt

#### Change 4: Plan review evidence check (prevent fake-approval)
**Problem**: Agent can edit DRAFT→APPROVED without spawning reviewers.
**Fix**: Review evidence file must exist with structural markers before APPROVED accepted.
**Files**: `gate.py`, `on-plan-mode-exit.sh`, `Stop.sh`

---

### Phase 2: Intelligence Push Model (ON for all profiles)

#### Change 5: Pre-compute intelligence at `ag implement` time
Generate `.impl-brief.md`, `.contract-surface.txt`, `.phase_implementing` sentinel.
**Files**: `commands/implement.sh`

#### Change 6: Push intelligence via hooks at decision points
**a)** First code edit → push impl-brief (conventions, patterns, quality checks)
**b)** Token budget → warn on 3+ repeated reads or >500K tokens
**c)** Correction hint → one-time after pattern warnings: "capture via ag intel remember"
**d)** Spec drift → if edited file matches contract surface, push contract check
**e)** TDD nudge → if no test writes before source writes
**f)** NFR awareness → if active feature has relevant NFRs, push at first code edit

**Files**: on-code-edit.sh, PostToolUse.sh, PreToolUse.sh
**Profile**: ALL profiles get intelligence (discovery=3 lines, formal=8 lines, autonomous=full+checklist)

#### Change 7: Domain intelligence auto-bootstrap
**Problem**: ag intel bootstrap must be manually triggered. ~10% of projects use it.
**Fix**:
1. SessionStart.sh nudge if quality-checklist.yaml missing and features exist
2. `ag start` (first feature) auto-runs bootstrap from STACK.md stack info
3. After every 5th `ag done`, suggest `ag intel retro` to learn from shipped features
4. `ag kickoff --approve` auto-runs bootstrap if not yet done (intelligence for new projects)

**Files**: SessionStart.sh, start.sh, done.sh, kickoff.py
**Profile**: ALL profiles

#### Change 8: Decision question patterns (interactive sessions)
**Problem**: No structured decision support for agents in non-autonomous flows.
**Fix**:
1. New `.agentic/intel/decision-patterns.yaml` with domain-aware question templates
2. `ag intel questions F-XXXX` surfaces relevant questions based on component/type
3. UserPromptSubmit: when feature in planning/spec phase AND not autonomous, push: "Decision questions available"
4. `ag intel bootstrap` auto-generates domain-specific patterns from STACK.md

**Files**: New decision-patterns.yaml, intel.sh, UserPromptSubmit.sh
**Profile**: discovery+formal (interactive), autonomous_formal=off (decisions are automated)

---

### Phase 3: Workflow Reliability

#### Change 9: Backlog churning reliability
**Problem**: ag auto crunch fails on: review blocking, no retry, intent orphaning.
**Fix**:
1. Retry on failure (once with fresh context) before marking failed
2. Review timeout escalation: >10min critical_agent → retry different approach; human → HUMAN_NEEDED.md + skip
3. SessionStart.sh: check for orphaned intents, output recovery instructions
4. Crunch progress persistence: `crunch-progress.json`, resume skips completed features

**Files**: scheduler.py, crunch.py, SessionStart.sh

#### Change 10: Idea → Backlog → Implementation flow
**Problem**: "idea → ag todo → triage → ag backlog add" is purely behavioral.
**Fix**:
1. UserPromptSubmit: detect idea/todo/note keywords → output actionable `ag todo "desc"` command
2. When TODO.md has >5 untriaged items, backlog list nudges triage
3. When backlog empty but planned features exist, dashboard warns
4. `ag formalize` skill reference added to exploring-codebase skill

**Files**: UserPromptSubmit.sh, backlog_helpers.py, dashboard.sh

#### Change 11: Specs↔Tests↔Code↔Docs live matching
**Problem**: Sync only at commit/done time. No real-time during development.
**Fix**:
1. on-code-edit.sh: If file referenced in contract verify commands, push reminder
2. PostToolUse.sh: Track test/source write ratio; if < 0.3 after 5+ source writes, TDD nudge
3. UserPromptSubmit.sh: When >3 impl writes and 0 doc writes, show WHICH docs are stale (from STACK.md `## Docs` registry)
4. Auto-suggest `ag sync` after 10th tool checkpoint if last sync >1 hour ago
5. on-code-edit.sh: If editing a file that was part of a shipped feature's verify commands, push contract regression warning

**Files**: on-code-edit.sh, PostToolUse.sh, UserPromptSubmit.sh

#### Change 12: Review checkpoint visibility
**Problem**: Review system works in auto mode but is invisible in interactive sessions. Agent doesn't know when to request review.
**Fix**:
1. UserPromptSubmit: When feature state allows transition with review checkpoint, push: "Ready for review? Run `ag transition F-XXXX <next-state>`"
2. on-code-edit.sh: Track file count; after 10+ implementation edits, push: "Consider saving progress: `ag commit`"
3. Stop.sh: If feature in implementing state with uncommitted code, warn (already exists but improve message with specific next step)

**Files**: UserPromptSubmit.sh, on-code-edit.sh

#### Change 13: Kickoff/Vision and Decomposition surfacing
**Problem**: ag kickoff and ag decompose are powerful but invisible. Agents don't know when to use them.
**Fix**:
1. UserPromptSubmit: When prompt contains "build/create entire/whole/full" AND no features exist → suggest `ag kickoff "vision"` instead of direct implementation
2. When a feature has >5 ACs in its contract, suggest `ag decompose F-XXXX` to break into children
3. SessionStart.sh: When kickoff staging exists (`.agentic/staging/`), prompt: "Pending kickoff — run `ag kickoff --review`"
4. Add kickoff awareness to planning-features skill

**Files**: UserPromptSubmit.sh, SessionStart.sh, planning-features skill

#### Change 14: Crash recovery and intent surfacing
**Problem**: Intent orphaning is silent. `ag intent list` must be known and called.
**Fix**:
1. SessionStart.sh: Auto-detect orphaned intents (PID dead, age > 5 min), output recovery commands
2. UserPromptSubmit: If orphaned intents exist, per-prompt warning until resolved
3. Dashboard.sh: Show intent count if > 0

**Files**: SessionStart.sh, UserPromptSubmit.sh, dashboard.sh

---

### Phase 4: Documentation Cleanup (prevent "not working" regression)

#### Change 15: Single-source-of-truth architecture

**Problem**: 11+ overlapping instruction files cause agents to read conflicting guidance and revert to lowest-common-denominator behavior.

**Fix**: Establish clear hierarchy, eliminate duplication:

```
hooks.json + gate.py          → STRUCTURAL (what is enforced — agent can't bypass)
.claude/skills/*.md           → BEHAVIORAL (what to do at each step — agent follows)
CLAUDE.md template            → CONSTITUTION (<100 lines, survives compaction)
memory-seed.md                → REINFORCEMENT (re-seeds rules after compaction)
Everything else               → REFERENCE (for humans, not agent instructions)
```

**Key principle**: Skills must NOT repeat what hooks enforce. Instead of "You must check X", write "The framework automatically checks X (PreToolUse). You need to handle Y."

**Each skill gets an enforcement reference table**:
```markdown
## What's Enforced Automatically
- Spec must exist → PreToolUse blocks code edits (formal)
- DRAFT plan blocks code → PreToolUse denies (formal)
- Shipped specs protected → PreToolUse denies edit without migration
## What You Must Do  
- Run `ag intel implement F-XXXX` for conventions (or wait for auto-push)
- Update docs alongside code (nudged by hooks, gated at ag done)
```

**Files**: All 15 skill files, CLAUDE.md template, memory-seed.md

#### Change 16: Merge auto_orchestration and agent_operating_guidelines

**Problem**: `.agentic/lib/auto/auto_orchestration.md` and `agent_operating_guidelines.md` contain workflow rules that overlap with skills and CLAUDE.md.

**Fix**:
1. Move actionable content into relevant skill files
2. Convert remainders to reference docs for humans
3. agent_operating_guidelines.md → merge into CLAUDE.md template
4. memory-seed.md: audit every rule — if now hook-enforced, change "MUST do X" → "framework enforces X"

**Files**: auto_orchestration.md, agent_operating_guidelines.md, memory-seed.md

#### Change 17: Instruction file drift detection

**Problem**: Features ship without updating instruction files. Agents use outdated workflows.

**Fix**:
1. New pre-commit check: when `.agentic/lib/claude-hooks/` or `gate.py` changes, require skill or CLAUDE.md template change too
2. `ag done` Gate 5: grep instruction files for feature's new commands/gates
3. `drift.sh --instructions`: compare CLAUDE.md template vs root for shared content divergence

**Files**: pre-commit-check.sh, done.sh, drift.sh

#### Change 18: Comprehensive feature-to-enforcement mapping doc

**Problem**: No single document maps all 42 features to their enforcement mechanisms. Agents and developers can't tell what's real vs. behavioral.

**Fix**: Generate `.agentic/ENFORCEMENT_MAP.md` from gate.py + hooks.json + pre-commit-check.sh:
- For each feature: what hooks enforce it, what gates check it, what's behavioral
- Auto-generated by `ag audit --enforcement` so it stays current
- Referenced by skills: "See ENFORCEMENT_MAP.md for what's automatic"

**Files**: New audit command, generated ENFORCEMENT_MAP.md

---

## Session State Files (all in `.agentic/session/`, gitignored)

| File | Created by | Purpose | Cleared by |
|------|-----------|---------|------------|
| `.phase_implementing` | ag implement | Active implementation signal | ag done, Stop.sh |
| `.impl-brief.md` | ag implement | Pre-computed intelligence | ag done, Stop.sh |
| `.impl_intel_pushed` | on-code-edit.sh | Suppress repeated intel push | Stop.sh |
| `.token_budget_warned` | PostToolUse.sh | Suppress budget warning | Stop.sh |
| `.tdd_nudge_fired` | on-code-edit.sh | Suppress TDD nudge | Stop.sh |
| `.correction_hint_shown` | PreToolUse.sh | Suppress remember hint | Stop.sh |
| `.contract-surface.txt` | ag implement | Contract file patterns | ag done, Stop.sh |
| `review-pending-{FID}` | on-plan-mode-exit.sh | Review not performed | review.md creation |
| `crunch-progress.json` | scheduler.py | Crunch resume state | crunch completion |
| `.nfr-brief.txt` | ag implement | Relevant NFRs for feature | ag done, Stop.sh |

---

## New Settings (profiles.conf)

```conf
# Push intelligence (ALL profiles get it — core value)
discovery.push_intel=standard
formal.push_intel=aggressive
autonomous_formal.push_intel=aggressive

# Token budget
discovery.token_budget_threshold=800000
formal.token_budget_threshold=500000
autonomous_formal.token_budget_threshold=500000

# TDD enforcement
discovery.tdd_enforcement=advisory
formal.tdd_enforcement=advisory
autonomous_formal.tdd_enforcement=blocking

# Decision questions
discovery.decision_questions=on
formal.decision_questions=on
autonomous_formal.decision_questions=off

# Auto-retry in crunch
discovery.crunch_retry=off
formal.crunch_retry=once
autonomous_formal.crunch_retry=once

# Auto-bootstrap intelligence
discovery.auto_bootstrap=on
formal.auto_bootstrap=on
autonomous_formal.auto_bootstrap=on
```

---

## What This Does NOT Change (already working well)

- Destructive git blocking (perfect)
- Spec-first enforcement in formal mode (perfect)
- Multi-session collision detection (works)
- Context preservation on compact (PreCompact.sh works)
- Profile-aware settings cascade (works)
- Fail-closed design (works)
- State machine transition enforcement (works via CLI)
- Backlog position/completion gates (works via CLI)
- Pre-commit 23-check quality gates (works)
- Contract YAML assertion verification (works)
- Token tracking and session metrics (works)
- Publishing workflow (domain-specific, works)
- Coordination server (works)
- Parallel execution with worktrees (works)

---

## Verification Plan

1. **Unit tests**: Each new gate.py function
2. **Hook integration**: PreToolUse denies on DRAFT plan + code edit; denies shipped spec edit
3. **LLM behavioral**: Agent receives pushed intel; cannot fake-approve plans; gets TDD reminder
4. **Timeout**: All hooks under 3s/2s/3s with all new checks
5. **Profile matrix**: Each change verified in all 3 profiles
6. **Intelligence push**: Verify intel pushes fire in discovery mode (core value, not optional)
7. **Crunch reliability**: Test retry, skip, resume with review-blocked features
8. **Doc drift**: drift.sh --instructions catches template/root divergence
9. **End-to-end**: Full lifecycle from `ag kickoff` through `ag done`
10. **Documentation audit**: No duplicated rules across skills, CLAUDE.md, memory-seed
11. **Enforcement map**: ag audit --enforcement generates accurate map

---

## Expected Reliability After All Changes

| Feature | Before | After | Mechanism |
|---------|--------|-------|-----------|
| Plan review loop | ~60% | ~95% | Evidence check blocks fake-approval |
| TDD enforcement | ~30% | ~80% | PreToolUse warns/blocks without tests |
| Doc updates during impl | ~35% | ~75% | Push nudge + Stop advisory + registry |
| Intelligence surfacing | ~20% | ~85% | Push at decision points (ALL profiles) |
| Spec migration | ~40% | ~95% | gate.py deny in formal |
| DRAFT plan blocks code | ~50% | ~98% | PreToolUse denies BEFORE edit |
| Correction capture | ~15% | ~50% | One-time hint after pattern match |
| Token economics | ~10% | ~70% | Budget warnings pushed |
| Backlog churning | ~60% | ~85% | Retry, resume, intent recovery |
| Idea → backlog flow | ~30% | ~65% | UserPromptSubmit + triage nudges |
| Specs↔tests↔code↔docs sync | ~40% | ~75% | Real-time contract + ratio + drift |
| Decision questions | 0% | ~60% | decision-patterns.yaml + prompt push |
| Domain intelligence | ~10% | ~55% | Auto-bootstrap, retro triggers |
| NFR awareness | ~15% | ~60% | Push NFRs at first code edit |
| Kickoff/decomposition | ~25% | ~65% | UserPromptSubmit detection + skills |
| Crash recovery/intents | ~15% | ~70% | SessionStart auto-detect + per-prompt |
| Review visibility | ~50% | ~75% | State-aware prompts + file count |
| Instruction clarity | ~50% | ~90% | Single-source, dedup, enforcement refs |

---

## Implementation Priority

1. **Phase 1** (Changes 1-4): Structural gates. Highest impact, prevents most common failures.
2. **Phase 2** (Changes 5-8): Intelligence push. Transforms from "remember to ask" to "framework tells you." ALL profiles.
3. **Phase 3** (Changes 9-14): Workflow reliability. Backlog, live sync, kickoff, recovery.
4. **Phase 4** (Changes 15-18): Documentation cleanup. Prevents regression to "not working" ways.
5. **Phase 5** (Verification): Full test coverage across all changes.
