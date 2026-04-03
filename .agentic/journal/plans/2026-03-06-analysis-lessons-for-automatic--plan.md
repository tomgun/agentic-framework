# Analysis: Lessons for Automatic Workflow Mode

## Context

We analyzed three open-source projects that enable autonomous Claude operation to understand:
1. What makes them work reliably
2. What we can learn for our framework
3. How to design an automatic workflow mode

Ref: Auto-Claude, Claude Loop, Ralph
---

## Deep Analysis of Each Project

### Ralph (simplest — ~110 lines of bash)

**Core mechanism**: A bash `for` loop that spawns fresh `claude --dangerously-skip-permissions --print` instances, piping in a prompt template. Each iteration picks the next incomplete story from `prd.json`, implements it, runs quality checks, commits if they pass, and marks it done.

**Why it works without scripts/hooks**:
- **`--dangerously-skip-permissions`** bypasses all approval prompts — the agent can edit/write/bash freely
- **Prompt engineering does the heavy lifting** — the prompt.md file IS the quality gate (tells Claude to run typecheck/lint/tests before committing)
- **Fresh context each iteration** — each loop spawns a NEW Claude instance, avoiding context degradation
- **Small task granularity** — each PRD story is sized to fit in one context window
- **Memory via artifacts** — `progress.txt` (append-only learnings), `prd.json` (task state), `AGENTS.md` (patterns), git history

**Limitations**:
- No real security — `--dangerously-skip-permissions` is all-or-nothing
- Quality depends entirely on Claude following the prompt instructions (no enforcement)
- No verification by a separate agent — trusts the same agent that wrote the code
- No recovery from stuck states beyond max iterations
- No parallel execution

### Claude Loop (medium complexity — POSIX shell, ~2000 lines)

**Core mechanism**: Parses a `PLAN.md` into phases with dependencies, spawns fresh Claude CLI per phase, tracks progress in `PROGRESS.md`. Much more robust than Ralph.

**Key innovations**:
- **Verification loop (`--verify`)**: After each phase, spawns a SEPARATE read-only Claude instance that reviews the work, runs tests, checks git diff. Requires explicit `VERIFICATION_PASSED` keyword — if missing or `VERIFICATION_FAILED`, the phase is retried. This is the "two-agent" pattern (doer + verifier).
- **Anti-skip detection**: Verifier must actually make tool calls (checked via JSON stream); if no `tool_use` events found, verification fails. Prevents Claude from just saying "looks good" without checking.
- **Exponential backoff with jitter** for retries
- **Quota/rate-limit detection** with configurable wait intervals
- **Phase dependencies** allowing complex DAG-like execution
- **AI plan decomposition** (`--ai-parse`) — can turn any free-text plan into structured phases
- **Idle timeout detection** — catches hung Claude instances
- **Empty log / no-write-action detection** — catches phases where Claude didn't actually do anything

**Why it works without hooks**:
- Same `--dangerously-skip-permissions` approach
- But adds the **verification loop** as a programmatic safety net
- Fresh context per phase prevents accumulating confusion
- Rich retry logic handles transient failures

**Limitations**:
- Sequential phases only (no parallel execution within phases)
- No security model — trusts Claude completely
- Verification is optional and doubles API costs

### Auto-Claude (most complex — Python backend + Electron desktop app)

**Core mechanism**: Full multi-agent pipeline using **Claude Agent SDK** (not just CLI). Spec → Planner → Coder (with parallel subagents) → QA Reviewer → QA Fixer → Human review.

**Key architectural decisions**:

1. **SDK-level security hooks** (not git pre-commit hooks):
   - `bash_security_hook()` in `security/hooks.py` is a pre-tool-use hook on the SDK client
   - Validates EVERY bash command against a dynamic allowlist before execution
   - Project-specific security profiles based on detected stack
   - This is why it doesn't need our-style pre-commit hooks — enforcement happens BEFORE commands run

2. **Git worktree isolation**: Every task runs in its own worktree — main branch is never touched. Includes an AI-powered semantic merge system for integrating parallel agent work.

3. **QA validation loop** (`qa/loop.py`):
   - Up to 50 iterations of: QA Reviewer reviews → if rejected → QA Fixer fixes → re-review
   - **Recurring issue detection**: If same issue appears 3+ times, escalates to human
   - **Consecutive error detection**: 3 errors in a row → stop and escalate
   - **Self-correction**: Error context from previous iteration is passed to next iteration

4. **Recovery system**: Rollback to last good commit, retry with different approach, skip stuck subtask, or escalate to human.

5. **Memory system**: Graphiti knowledge graph for cross-session insights + file-based fallback.

6. **Multi-account swapping**: When one Claude account hits rate limits, auto-switches to another.

7. **Post-session processing** runs in Python (not Claude) — "100% reliable" updates to state, as noted in the code comment. This is a key insight: don't rely on the agent to update its own state files.

**Why it works reliably**:
- Programmatic enforcement (SDK hooks) not prompt-based enforcement
- Separation of concerns (planner ≠ coder ≠ reviewer ≠ fixer)
- Worktree isolation eliminates risk to main branch
- Recovery system handles all failure modes
- State management is done by Python, not by the AI agent

---

## Key Lessons for Our Framework

### 1. "Why do they work without pre-commit hooks?"

**Answer: They don't need git-level hooks because enforcement happens at a different layer.**

| Project | Enforcement Layer | Mechanism |
|---------|------------------|-----------|
| Ralph | Prompt engineering | Trust the agent to follow instructions |
| Claude Loop | Process-level | Fresh instances + optional verification agent |
| Auto-Claude | SDK-level | Pre-tool-use hooks intercept every command |
| Our framework | Git-level | Pre-commit hooks check after the fact |

**Insight**: For *human-interactive* sessions, our pre-commit hooks are the right choice (catch mistakes before they're committed). For *automatic* mode, we need enforcement at the SDK/process level — by the time a pre-commit hook runs, the agent has already done the work. We should keep our hooks for interactive mode and add process-level enforcement for automatic mode.

### 2. Fresh Context Per Task (Ralph + Claude Loop pattern)

All three projects spawn **fresh Claude instances** for each unit of work. This is the single most important reliability pattern — it prevents context degradation, accumulated confusion, and token exhaustion.

Our framework currently relies on one long-running session. For automatic mode, we should adopt the fresh-instance pattern.

### 3. Verification by Separate Agent (Claude Loop pattern)

Claude Loop's `--verify` is elegant: after work is done, a SEPARATE read-only Claude instance reviews the changes, runs tests, checks the diff, and must output an explicit verdict. This "doer + verifier" separation is much more reliable than self-review.

### 4. Post-Processing in Code, Not in AI (Auto-Claude pattern)

Auto-Claude's `post_session_processing()` explicitly runs in Python, not Claude, because agent compliance is unreliable. State updates (progress tracking, recovery recording, memory saves) should be done by deterministic code after the agent session ends.

### 5. Structured Task Format (All three)

All three use machine-readable task definitions:
- Ralph: `prd.json` with `passes: true/false`
- Claude Loop: `PLAN.md` with `## Phase N:` format
- Auto-Claude: `implementation_plan.json` with subtask statuses

Our `spec/acceptance/F-XXXX.md` files could serve this role, but we'd need a machine-readable status tracking mechanism.

### 6. Escalation to Human (Auto-Claude pattern)

Auto-Claude has clear escalation rules: recurring issues (3+ times), consecutive errors (3+), max iterations (50). This prevents infinite loops while still allowing substantial autonomous work.

---

## Proposed Automatic Workflow Modes

Based on this analysis, I propose three distinct modes that build on each other:

### Mode 1: Verification Loop (`ag verify`)
**Scope**: Run tests → fix failures → re-run → repeat until green or max iterations

This is the simplest mode. Similar to Claude Loop's `--verify` pattern:
1. Run the project's test suite
2. If failures: spawn fresh Claude instance with failure output + relevant code
3. Claude fixes the failures
4. Re-run tests
5. Repeat until green or N iterations exhausted
6. Report results

**Use case**: "Make all tests pass after a refactor" or "Fix CI"

### Mode 2: Single Task Auto (`ag auto F-XXXX`)
**Scope**: Implement one feature/task autonomously on a feature branch

Combines Ralph's loop pattern with our spec-driven workflow:
1. Read spec + acceptance criteria for F-XXXX
2. Create feature branch + worktree
3. Loop (fresh Claude instance each iteration):
   a. Read acceptance criteria + progress file
   b. Pick next uncompleted criterion
   c. Implement it (write code + tests)
   d. Run tests
   e. If passing: commit, mark criterion done
   f. If failing: fix or mark as stuck
4. After all criteria done: run full verification (Mode 1)
5. Create PR for human review

**Use case**: "Implement this feature while I'm in a meeting"

### Mode 3: Full Pipeline Auto (`ag crunch`)
**Scope**: Process an entire task list autonomously

Orchestrates multiple Mode 2 runs:
1. Read task list (from FEATURES.md or a curated list)
2. For each task in priority order:
   a. Generate/verify spec + acceptance criteria
   b. Generate tests from acceptance criteria
   c. Run Mode 2 (single task auto)
   d. Run Mode 1 (verification loop)
   e. Create PR
3. Track overall progress in a dashboard file
4. Stop on: all done, max errors, or human intervention needed

**Use case**: "Crunch through these 5 features overnight"

### Visual Monitoring (Cross-cutting)

A simple dashboard showing:
- Active agents and their current task
- Progress per task (criteria completed / total)
- Test status (passing/failing/running)
- Commit history
- Errors requiring attention

Could be: terminal UI (like `htop`), a generated HTML page, or a simple markdown status file that auto-refreshes.

---

## Implementation Architecture

### Core Runner (`ag-auto.sh` or Python script)

```
ag-auto [mode] [target] [options]

Modes:
  verify              Run test-fix loop
  task F-XXXX         Implement single task
  crunch [list]       Process task list

Options:
  --max-iterations N  Max loops per task (default: 10)
  --branch-prefix     Git branch prefix (default: auto/)
  --worktree          Use git worktree for isolation (default: yes)
  --verify            Run verification after each task (default: yes)
  --docker            Run in Docker container (future)
  --visual            Enable visual verification via Playwright MCP
  --dashboard         Enable live dashboard output
```

### Key Components to Build

1. **Loop runner** — spawns fresh Claude instances per iteration (like Ralph)
2. **Task state tracker** — machine-readable progress per acceptance criterion
3. **Verification agent** — separate read-only Claude that checks work (like Claude Loop)
4. **Post-iteration processor** — deterministic code that updates state (like Auto-Claude)
5. **Escalation logic** — max iterations, recurring issues, consecutive errors → stop
6. **Dashboard** — live progress output

### Safety Model

| Layer | Interactive Mode | Automatic Mode |
|-------|-----------------|----------------|
| Git isolation | Feature branches | Worktrees (stronger isolation) |
| Command safety | Pre-commit hooks | `settings.json` allowlist OR Docker container |
| Quality gates | Human reviews before commit | Verification agent + test suite |
| Escape hatch | Human says "stop" | Max iterations + escalation rules |
| State management | Agent updates files | Post-iteration code updates files |

### Settings Integration

New settings in STACK.md `## Settings`:
```
- auto_mode: enabled           # Allow automatic workflow
- auto_max_iterations: 10      # Max iterations per task
- auto_worktree: yes           # Use worktree isolation
- auto_verify: yes             # Run verification after each task
- auto_visual_verify: no       # Playwright screenshot comparison
- auto_escalation_threshold: 3 # Consecutive errors before stopping
```

### Visual Verification (Playwright MCP)

For frontend/UI tasks:
1. After implementation, spawn Playwright MCP to take screenshots
2. Compare against baseline screenshots (or just capture for human review)
3. Include screenshot links in verification report
4. This integrates with the verification agent (Mode 1)

---

## PART 2: How to Make the Framework SHINE

### The Realization

Looking at our framework through the lens of these three projects reveals something important:

**None of them have what we have.** Ralph is 110 lines of bash with zero enforcement. Claude Loop is a phase runner with no spec system. Auto-Claude is the closest competitor but it's a monolithic desktop app — not a portable framework.

Our framework already has:
- Spec-driven development with acceptance criteria
- 17 structural quality gates
- Token-optimized context delivery (`context-for-role.sh`)
- Multi-tool portability (Claude, Cursor, Copilot, Codex)
- Durable artifacts that survive context resets
- Settings system with profiles and constraints

**What we're missing is the execution engine.** We tell agents WHAT to do and HOW to verify it, but we don't orchestrate WHEN to run them or manage the loop. That's what Ralph, Claude Loop, and Auto-Claude all provide.

### The Vision: From Instruction Framework to Autonomous Development Platform

```
Current:   Human → starts Claude → Claude reads CLAUDE.md → Claude works → Human reviews
                                                                    ↑
                                              (one long session, context degrades)

Vision:    Human → `ag auto F-XXXX` → Engine orchestrates →  Human reviews PR
                                           ↓
                    ┌─────────────────────────────────────┐
                    │  For each acceptance criterion:      │
                    │  1. Spawn fresh Claude (focused)     │
                    │  2. Claude implements criterion      │
                    │  3. Engine runs tests (deterministic)│
                    │  4. Engine verifies (separate agent) │
                    │  5. Engine commits if passing        │
                    │  6. Engine updates state files       │
                    │  Escalate if stuck                   │
                    └─────────────────────────────────────┘
```

The key shift: **the engine, not Claude, owns the loop and state**. Claude is a powerful tool called at the right moments with the right context. This aligns perfectly with our principles:

| Principle | How Auto Mode Honors It |
|-----------|------------------------|
| F1 (Developer UX) | `ag auto` is dead simple — point it at a spec, walk away, review a PR |
| F2 (Sustainable Quality) | Acceptance criteria ARE the verification contract. Tests are mandatory. |
| F3 (Token Optimization) | Fresh context per criterion = minimal tokens per iteration |
| D1 (Human-Agent Partnership) | Human defines WHAT (specs), agent handles HOW, human reviews RESULT |
| D2 (Deterministic Enforcement) | Engine runs tests and gates — not the agent. 100% reliable. |
| D3 (Durable Artifacts) | Progress tracked in structured files, survives crashes/restarts |
| D4 (Small Batch) | One criterion per iteration = maximally small batches |
| R2 (No Auto-Commits) | Commits happen on an isolated worktree branch — main is never touched. Human merges the PR. |

### What Would Make Us Uniquely Better Than All Three

#### 1. Acceptance Criteria as Executable Verification Contracts

This is our killer feature. Nobody else has this.

Ralph uses `prd.json` — simple `passes: true/false` per story. Claude Loop uses plan phases. Auto-Claude uses `implementation_plan.json`.

We have **Given/When/Then acceptance criteria** that are ALREADY verification contracts. We just need to close the loop:

```markdown
# F-0042: User Authentication

## Acceptance Criteria
- [ ] AC-1: Given a valid email/password, when POST /login, then return JWT token
- [ ] AC-2: Given an invalid password, when POST /login, then return 401
- [ ] AC-3: Given an expired token, when accessing protected route, then return 401

## Tests
- test_login_success → AC-1
- test_login_invalid_password → AC-2
- test_expired_token → AC-3
```

The engine reads the acceptance file, picks the next unchecked criterion, tells Claude to implement it + write the linked test, runs the test, and checks the box if it passes. The **acceptance criteria file IS the task list, the verification spec, AND the progress tracker**.

A companion machine-readable file (e.g., `F-0042-progress.json`) tracks state:
```json
{
  "criteria": [
    {"id": "AC-1", "status": "passed", "test": "test_login_success", "iteration": 2},
    {"id": "AC-2", "status": "in_progress", "iteration": 3},
    {"id": "AC-3", "status": "pending"}
  ],
  "total_iterations": 3,
  "last_error": null
}
```

#### 2. Defense-in-Depth Safety (Not Just "Skip Permissions")

Ralph and Claude Loop use `--dangerously-skip-permissions` and trust Claude completely. That's fine for solo prototyping. For a serious framework, we need layered safety:

**Layer 1: Git Worktree Isolation**
- Every auto task runs in its own worktree
- Main branch physically cannot be modified
- If something goes wrong, `rm -rf` the worktree — zero damage

**Layer 2: Permission Profiles (settings.json)**
- Auto mode generates a Claude `settings.json` with explicit tool permissions
- Based on project stack detection (similar to Auto-Claude's security profiles)
- E.g., allow Edit/Write/Read/Glob/Grep/Bash, but Bash only for test commands
- User can customize: `auto_allowed_commands: ["npm test", "pytest", "cargo test"]`

**Layer 3: Verification Agent**
- After each iteration, a SEPARATE read-only Claude instance checks:
  - Did the tests actually pass? (runs them independently)
  - Does the code match the acceptance criterion?
  - Any obvious regressions? (git diff review)
- Must output explicit `VERIFICATION_PASSED` keyword (Claude Loop pattern)
- Anti-skip: must actually make tool calls (no "looks good" without checking)

**Layer 4: Escalation Rules**
- Max iterations per criterion (default: 5)
- Max consecutive errors (default: 3)
- Max total iterations per feature (default: 20)
- Recurring issue detection (same error 3+ times → stop)
- All configurable via STACK.md settings

**Layer 5: Human Checkpoint**
- Between features in crunch mode: pause for human review
- PR created automatically — human merges (R2 honored at the feature level)
- Dashboard shows progress, human can intervene at any time

#### 3. Token-Optimal Fresh Context (Our Existing Strength, Amplified)

We already have `context-for-role.sh` with 24 role-specific context manifests. For auto mode, each iteration gets EXACTLY what it needs:

```
Iteration context budget: ~5K tokens
├── core-rules.md (300 tokens) — constitutional minimum
├── Acceptance criterion being implemented (200 tokens)
├── Relevant source files (2-3K tokens) — from context manifest
├── Previous iteration's learnings (500 tokens) — append-only progress file
├── Test failure output if retrying (500 tokens)
└── STACK.md stack info (200 tokens)
```

Compare to a long-running session that accumulates 100K+ tokens of drift. Each fresh iteration is focused, cheap, and effective.

#### 4. Progressive Autonomy (Unique to Our Framework)

No other tool offers a trust gradient:

```
Level 0: ag verify          — Only fix failing tests (most constrained)
Level 1: ag auto F-XXXX     — Implement one spec'd feature (medium trust)
Level 2: ag crunch           — Process a task list (high trust)
Level 3: ag crunch --spec    — Also generate specs from a brief (highest trust)
```

Each level builds on the previous. Users start with `ag verify` to build confidence, graduate to `ag auto` when they trust the quality, and eventually use `ag crunch` for overnight batch work.

Settings encode the trust level:
```
- auto_trust_level: verify    # Options: verify | task | pipeline | full
```

#### 5. Multi-Tool Auto Mode (Nobody Else Has This)

Our D7 (Multi-Environment Portability) means auto mode shouldn't be Claude-only:

```bash
ag auto F-XXXX --tool claude    # Uses claude CLI
ag auto F-XXXX --tool cursor    # Uses Cursor terminal API
ag auto F-XXXX --tool codex     # Uses codex CLI
```

The loop runner is tool-agnostic. It spawns the right CLI, passes the prompt, reads the output. The context assembly (`context-for-role.sh`) already works across tools.

This is a MASSIVE differentiator. Auto-Claude only works with Claude. Claude Loop only works with Claude. Ralph supports Amp + Claude but that's it.

#### 6. Visual Verification as First-Class Citizen

For frontend/UI work, integrate Playwright MCP:

```
ag auto F-XXXX --visual
```

After each criterion is implemented:
1. Engine starts dev server
2. Playwright MCP takes screenshots of affected pages
3. Screenshots saved to `.agentic/auto/screenshots/F-XXXX/AC-N/`
4. Verification agent compares to baseline (or just captures for human review)
5. Visual regressions treated like test failures — retry or escalate

This is what the user specifically asked about and it's a natural extension of the verification loop.

### Architecture: What Changes

#### New Components (to build)

```
.agentic/lib/auto/
├── engine.sh              # Main loop runner (POSIX shell for portability)
├── verify.sh              # Verification agent spawner
├── progress.sh            # Machine-readable progress tracking
├── escalation.sh          # Escalation rules engine
├── prompt-builder.sh      # Builds iteration prompts from acceptance criteria
├── worktree.sh            # Git worktree lifecycle management
├── dashboard.sh           # Live progress output
└── permissions.sh         # Generate settings.json for auto mode
```

Why shell, not Python: D7 (portability) — shell scripts work everywhere, no dependencies. The engine is thin orchestration; Claude does the heavy lifting.

#### Existing Components (to extend)

| Component | Current | Auto Mode Extension |
|-----------|---------|-------------------|
| `ag.sh` | Gateway for `ag start/commit/done` | Add `ag auto/verify/crunch` commands |
| `settings.sh` | Resolves settings from STACK.md | Add auto_* settings |
| `context-for-role.sh` | Assembles role context for subagents | Add "auto-implementer" and "auto-verifier" roles |
| `pre-commit-check.sh` | 17 gates for interactive mode | Runs programmatically between iterations |
| `wip.sh` | WIP lock for interactive mode | Auto mode creates/releases WIP per feature |
| Acceptance criteria files | Human-readable specs | Add machine-readable progress companion |
| `feature.sh` | Status transitions | Auto mode transitions: planned → in_progress → auto_verified → needs_review |

#### New State Files (per auto run)

```
.agentic/auto/                        # Gitignored — session-local
├── runs/
│   └── F-XXXX/
│       ├── progress.json             # Machine-readable criterion status
│       ├── learnings.md              # Append-only iteration learnings
│       ├── dashboard.md              # Live-updating progress dashboard
│       └── screenshots/              # Visual verification captures
└── config.json                       # Resolved auto settings for current run
```

#### New Feature Status: `auto_verified`

Add to the feature lifecycle:
```
planned → in_progress → auto_verified → shipped → accepted
                                ↑
                          (new! auto mode sets this)
```

`auto_verified` means: all acceptance criteria pass, all tests pass, verification agent approved. But human hasn't reviewed yet. Human reviews the PR and either ships it or sends it back.

### What About R2 (No Auto-Commits)?

This is the big principle question. R2 says "Agents NEVER commit changes without explicit human approval." But auto mode needs to commit within the worktree.

**Resolution**: R2's spirit is "don't change main without approval." Auto mode commits are:
1. On an isolated worktree branch (not main)
2. Each commit is one acceptance criterion (small, reviewable)
3. Human reviews the PR before merging to main
4. The MERGE is the human approval — individual commits are implementation detail

This is like how a developer commits to a feature branch freely but needs PR approval to merge. R2 is honored at the RIGHT level.

Add an explicit exception in principles:
```
R2 Exception: Auto mode may commit to isolated worktree branches.
Human approval is required to merge the resulting PR to main.
```

### Major Refactoring Opportunities

These are things we should simplify/restructure to make auto mode work cleanly:

#### 1. Acceptance Criteria Files Need Structure
Currently free-form markdown. Need:
- Consistent `- [ ] AC-N:` format for machine parsing
- `## Tests` section linking tests to criteria
- Optional YAML frontmatter for machine-readable metadata

#### 2. Feature Status Machine Needs Formalization
Currently `feature.sh` handles transitions. Need:
- `auto_verified` status
- Transition rules: only auto engine can set `auto_verified`
- Dashboard can query status programmatically

#### 3. Context Manifests Need Auto Roles
Add to `context-manifests/`:
- `auto-implementer.manifest` — what Claude needs to implement a single criterion
- `auto-verifier.manifest` — what the verification agent needs to check work

#### 4. Settings System Needs Auto Section
Extend `profiles.conf` with auto defaults per profile:
```
formal.auto_trust_level=task
formal.auto_max_iterations=10
formal.auto_worktree=yes
formal.auto_verify=yes
discovery.auto_trust_level=verify
discovery.auto_max_iterations=5
```

### Implementation Priority

If we were to build this, the order would be:

1. **Foundation**: Worktree management + progress tracking + basic loop runner
2. **Mode 1 (`ag verify`)**: Test-fix loop — simplest, most immediately useful
3. **Mode 2 (`ag auto F-XXXX`)**: Single-task auto with acceptance criteria
4. **Verification agent**: Doer + verifier separation
5. **Dashboard**: Live progress monitoring
6. **Mode 3 (`ag crunch`)**: Multi-task pipeline
7. **Visual verification**: Playwright MCP integration
8. **Multi-tool support**: Cursor/Codex auto mode

Each builds on the previous. Each is independently useful.

---

## Summary: Why This Would SHINE

| Dimension | Ralph | Claude Loop | Auto-Claude | Our Framework (Vision) |
|-----------|-------|------------|-------------|----------------------|
| Spec-driven | prd.json | Plan phases | impl_plan.json | **Acceptance criteria as verification contracts** |
| Safety | None | Optional verify | SDK hooks | **5-layer defense in depth** |
| Token efficiency | N/A | Fresh per phase | N/A | **context-for-role.sh + fresh per criterion** |
| Multi-tool | Claude+Amp | Claude only | Claude SDK only | **Claude, Cursor, Copilot, Codex** |
| Trust model | All or nothing | All or nothing | Full auto | **Progressive autonomy (4 levels)** |
| Quality gates | Prompt-based | Prompt-based | QA loop | **17 structural gates + verification agent** |
| Recovery | Max iterations | Retry+backoff | Full recovery | **Escalation rules + worktree isolation** |
| Visual testing | No | No | Electron MCP | **Playwright MCP integration** |
| Simplicity | 110 lines | ~2000 lines | ~50K+ lines | **~500-1000 lines engine + existing framework** |

The magic: we're not building Auto-Claude's complexity. We're adding a **thin execution engine** (~500-1000 lines of shell) on top of our existing rich framework. The specs, gates, context system, and artifacts are already built. We just need the loop.

---

---

## PART 3: Architecture Deep-Dive

### What We Already Have (Infrastructure Audit)

Before designing new architecture, let's inventory what EXISTS:

| Component | File | Status | Auto Mode Fit |
|-----------|------|--------|--------------|
| Worktree management | `worktree.sh` (307 lines) | Working | **Direct reuse** — create/list/remove/status |
| Settings resolution | `settings.sh` (346 lines) | Working | **Extend** — add auto_* settings |
| Context assembly | `context-for-role.sh` + 25 manifests | Working | **Add 2 manifests** — auto-implementer, auto-verifier |
| Acceptance criteria | `spec/acceptance/F-XXXX.md` | Working | **Already machine-parseable!** Uses `- [x] **AC-NNN**:` format |
| Feature status | `feature.sh` | Working | **Extend** — add `auto_verified` status |
| Quality gates | `pre-commit-check.sh` (17 checks) | Working | **Call programmatically** between iterations |
| WIP lock | `wip.sh` | Working | **Reuse** — auto mode creates/releases WIP |
| Doctor checks | `doctor.sh` | Working | **Reuse** — run as verification step |
| `ag` gateway | `ag.sh` (2471 lines) | Working | **Extend** — add `ag auto` subcommand |
| `ag verify` | Already exists (calls doctor.sh) | Working | **Repurpose** — verification loop |
| Verify script | `verify.sh` (deprecated) | Deprecated | **Replace** with auto verify |
| Claude hooks | `.agentic/lib/claude-hooks/` | Working | **Leverage** — PostToolUse, Stop hooks |

**Key discovery**: Our acceptance criteria files ALREADY use machine-parseable format:
```
- [x] **AC-001**: Description here
- [ ] **AC-010**: Not yet done
```

This is parseable with simple grep/sed. We don't need a separate `progress.json` — we can read/write the acceptance files directly! (Though a companion JSON for richer state tracking is still useful.)

### The Engine Architecture

```
                        ┌──────────────────┐
                        │   Human triggers  │
                        │   ag auto F-XXXX  │
                        └────────┬─────────┘
                                 │
                        ┌────────▼─────────┐
                        │   auto/engine.sh  │  ← Thin orchestrator (~300 lines)
                        │   (the loop)      │
                        └────────┬─────────┘
                                 │
              ┌──────────────────┼──────────────────┐
              │                  │                   │
     ┌────────▼────────┐ ┌──────▼───────┐ ┌────────▼────────┐
     │  worktree.sh    │ │ progress.sh  │ │  escalation.sh  │
     │  (isolation)    │ │ (state mgmt) │ │  (stop rules)   │
     └────────┬────────┘ └──────┬───────┘ └────────┬────────┘
              │                  │                   │
              │         ┌────────▼─────────┐        │
              │         │  ITERATION LOOP  │        │
              │         │                  │        │
              │         │  1. Read next AC │        │
              │         │  2. Build prompt │        │
              │         │  3. Spawn Claude │←───────┘
              │         │  4. Run tests    │  (check limits)
              │         │  5. Verify       │
              │         │  6. Commit/retry │
              │         │  7. Update state │
              │         │                  │
              │         └──────────────────┘
              │
              │  (All work happens in worktree)
              │
     ┌────────▼────────┐
     │  On completion:  │
     │  - Create PR     │
     │  - Dashboard     │
     │  - Notify human  │
     └─────────────────┘
```

### Key Design Decisions

#### Decision 1: Shell Engine, Not Python

**Choice: POSIX-compatible shell (bash with set -euo pipefail)**

Rationale:
- **D7 (Portability)**: Shell works everywhere — macOS, Linux, CI, Docker. No `pip install` needed.
- **Consistency**: `ag.sh` is already 2471 lines of bash. The auto engine is a natural extension.
- **Simplicity**: The engine is orchestration logic, not data processing. Shell excels at: spawning processes, reading files, checking exit codes, calling other scripts.
- **Our existing tools are shell**: `worktree.sh`, `feature.sh`, `settings.sh`, `pre-commit-check.sh` — the engine composes these.

For JSON/progress tracking, we use simple helper functions (jq for parsing, printf for writing). If jq isn't available, fall back to grep/sed (our acceptance files are already grep-parseable).

#### Decision 2: Acceptance Criteria = Progress Tracker

**Choice: Read/write the existing `spec/acceptance/F-XXXX.md` files directly**

The auto engine:
1. Parses `- [ ] **AC-NNN**: description` → list of pending criteria
2. Picks the next `[ ]` criterion
3. Passes it to Claude as the task
4. After Claude completes: runs tests
5. If tests pass: changes `[ ]` to `[x]` in the file (deterministic sed)
6. When all `[x]`: feature is auto_verified

**No separate progress.json needed for the core flow.** The acceptance file IS the single source of truth. This is beautifully aligned with D3 (Durable Artifacts) and D5 (Living Documentation) — the same file humans read is the file the engine reads/writes.

For richer state (iteration count, timestamps, errors), a lightweight companion:
```
.agentic/auto/F-XXXX.state    # Simple key=value (shell-parseable, no jq needed)
```
```
STARTED=2026-03-06T17:30:00
CURRENT_AC=AC-010
ITERATION=3
TOTAL_ITERATIONS=7
LAST_ERROR=
CONSECUTIVE_ERRORS=0
STATUS=in_progress
```

#### Decision 3: Fresh Claude Instance Per Criterion

**Choice: One `claude --print` invocation per acceptance criterion**

Each criterion gets:
1. Fresh context (no accumulated drift)
2. Focused prompt (~3-5K tokens via `context-for-role.sh`)
3. Clear definition of "done" (one criterion, one test)
4. Bounded scope (one criterion should be <30 min of work)

This maps to our D4 (Small Batch) perfectly. And it's exactly the pattern that makes Ralph and Claude Loop reliable.

The prompt for each iteration:
```markdown
# Task: Implement AC-{N} for {Feature Title}

## Criterion
{criterion description from acceptance file}

## Context
{assembled by context-for-role.sh using auto-implementer manifest}

## Test to write/verify
{linked test name if specified in acceptance file}

## Previous learnings
{from .agentic/auto/F-XXXX-learnings.md — append-only, like Ralph's progress.txt}

## Rules
- Implement ONLY this criterion, nothing else
- Write or update the linked test
- Run tests: {test_command from STACK.md}
- If tests pass, you are done. Output: CRITERION_PASSED
- If tests fail and you can fix it, fix and re-run
- If stuck, output: CRITERION_STUCK with explanation
```

#### Decision 4: Verification Agent = Optional but Recommended

**Choice: Separate read-only verification, enabled by default, skippable**

After each criterion passes:
1. Engine spawns a SECOND Claude instance with `--print`
2. This instance gets: the acceptance criterion, the git diff, test results
3. It runs tests independently, reviews the diff, checks for regressions
4. Must output `VERIFICATION_PASSED` or `VERIFICATION_FAILED`
5. Anti-skip: engine checks that tool_use events occurred in output

Setting: `auto_verify: yes` (default) / `no` (skip verification, faster but less safe)

Cost: ~doubles API usage per criterion. Worth it for important features. Skip for low-risk changes.

#### Decision 5: Worktree Isolation, Not Docker (Initially)

**Choice: Git worktrees first, Docker as optional future layer**

Rationale:
- `worktree.sh` already works
- Worktrees are instant (no image building)
- Main branch is physically protected
- Docker adds value for: network isolation, filesystem sandboxing, reproducible environments
- Docker can be added LATER as an additional layer without changing the engine

The engine calls `worktree.sh create auto-F-XXXX "Auto: feature description"` at start and `worktree.sh remove auto-F-XXXX` on completion (or leaves it for human review).

#### Decision 6: `--dangerously-skip-permissions` Wrapped with Safety

**Choice: Use it, but document clearly and wrap with our own safety layers**

The name is alarming but it's necessary for autonomous operation. Our safety layers:
1. Worktree isolation (can't touch main)
2. Our pre-commit-check.sh runs between iterations (catches bad state)
3. Verification agent reviews every change
4. Escalation rules stop runaway agents
5. Human reviews the final PR

We create a wrapper function:
```bash
spawn_auto_claude() {
    local prompt="$1"
    local worktree_path="$2"

    # Build settings.json with allowed tools if configured
    # ...

    cd "$worktree_path"
    echo "$prompt" | claude --print \
        --dangerously-skip-permissions \
        --output-format stream-json \
        --verbose 2>&1
}
```

For multi-tool support (D7), abstract the tool invocation:
```bash
spawn_auto_agent() {
    local tool=$(get_setting "auto_tool" "claude")
    case "$tool" in
        claude) spawn_auto_claude "$@" ;;
        codex)  spawn_auto_codex "$@" ;;
        *)      echo "Unsupported auto tool: $tool"; exit 1 ;;
    esac
}
```

### Integration Points with Existing Framework

#### `ag.sh` Extension

Add to the command router:
```bash
auto)
    cmd_auto "${@:2}"
    ;;
```

`cmd_auto()` is a thin dispatcher:
```bash
cmd_auto() {
    case "${1:-}" in
        verify)   bash "$SCRIPT_DIR/../auto/engine.sh" verify "${@:2}" ;;
        task)     bash "$SCRIPT_DIR/../auto/engine.sh" task "${@:2}" ;;
        crunch)   bash "$SCRIPT_DIR/../auto/engine.sh" crunch "${@:2}" ;;
        status)   bash "$SCRIPT_DIR/../auto/engine.sh" status ;;
        stop)     bash "$SCRIPT_DIR/../auto/engine.sh" stop ;;
        *)        show_auto_help ;;
    esac
}
```

#### Settings Integration

New settings in `profiles.conf`:
```
formal.auto_enabled=yes
formal.auto_max_iterations=10
formal.auto_worktree=yes
formal.auto_verify=yes
formal.auto_tool=claude
formal.auto_escalation_threshold=3
discovery.auto_enabled=yes
discovery.auto_max_iterations=5
discovery.auto_worktree=yes
discovery.auto_verify=no
discovery.auto_tool=claude
discovery.auto_escalation_threshold=3
```

User overrides in STACK.md:
```markdown
## Settings
- auto_max_iterations: 20
- auto_verify: yes
```

All resolved by existing `settings.sh` — zero new infrastructure needed.

#### Context Manifests

Two new manifests:

**`auto-implementer.yaml`** (for the coding iteration):
```yaml
role: auto-implementer
token_budget: 4000
description: Implement a single acceptance criterion

required:
  - spec/acceptance/{feature_id}.md[current_criterion]
  - STACK.md[build_commands,test_commands]
  - CONTEXT_PACK.md[entry_points,modules]
  - .agentic/auto/{feature_id}-learnings.md  # Previous iteration learnings

optional:
  - .agentic/quality/programming_standards.md

exclude:
  - JOURNAL.md
  - STATUS.md
  - docs/
```

**`auto-verifier.yaml`** (for the verification agent):
```yaml
role: auto-verifier
token_budget: 3000
description: Verify a single acceptance criterion was implemented correctly

required:
  - spec/acceptance/{feature_id}.md[current_criterion]
  - STACK.md[test_commands]

optional:
  - .agentic/quality/programming_standards.md

exclude:
  - JOURNAL.md
  - STATUS.md
  - CONTEXT_PACK.md  # Verifier doesn't need architecture context
```

#### Claude Hooks Integration

Our existing `claude-hooks/` can enhance auto mode:

- **`PostToolUse.sh`**: Could log tool usage for anti-skip detection
- **`Stop.sh`**: Could save learnings when Claude exits
- **`PreCompact.sh`**: Not relevant (auto mode uses fresh instances)

#### Feature Lifecycle Extension

Current: `planned → in_progress → shipped → accepted`

Extended: `planned → in_progress → auto_verified → shipped → accepted`

`auto_verified` means:
- All acceptance criteria checked `[x]`
- All tests passing
- Verification agent approved (if enabled)
- PR created
- Human hasn't reviewed yet

`feature.sh` needs one new valid transition: `in_progress → auto_verified`

### The Engine: Pseudocode

```bash
# engine.sh task F-XXXX

# 1. SETUP
feature_id="$1"
acceptance_file="spec/acceptance/${feature_id}.md"
worktree_path=$(worktree.sh create "auto-${feature_id}" "Auto: ${feature_id}")
max_iterations=$(get_setting "auto_max_iterations" "10")
verify_enabled=$(get_setting "auto_verify" "yes")

# 2. STATE INIT
state_file=".agentic/auto/${feature_id}.state"
learnings_file=".agentic/auto/${feature_id}-learnings.md"
echo "STARTED=$(date -Iseconds)" > "$state_file"
echo "# Learnings for ${feature_id}" > "$learnings_file"

iteration=0
consecutive_errors=0

# 3. MAIN LOOP
while true; do
    # Find next unchecked criterion
    next_ac=$(grep '^\- \[ \] \*\*AC-' "$acceptance_file" | head -1)

    if [ -z "$next_ac" ]; then
        # All criteria checked!
        break
    fi

    iteration=$((iteration + 1))

    # Check escalation
    if [ "$iteration" -gt "$max_iterations" ]; then
        echo "Max iterations reached. Escalating."
        break
    fi
    if [ "$consecutive_errors" -ge 3 ]; then
        echo "3 consecutive errors. Escalating."
        break
    fi

    # Build prompt
    prompt=$(build_iteration_prompt "$feature_id" "$next_ac" "$learnings_file")

    # Spawn fresh Claude
    output=$(spawn_auto_agent "$prompt" "$worktree_path")

    # Check result
    if echo "$output" | grep -q "CRITERION_PASSED"; then
        # Run tests (deterministic, not Claude)
        if run_tests "$worktree_path"; then
            # Mark criterion as done (deterministic sed)
            mark_criterion_done "$acceptance_file" "$next_ac"

            # Commit (auto mode can commit to worktree branch)
            git -C "$worktree_path" add -A
            git -C "$worktree_path" commit -m "auto: ${feature_id} ${next_ac}"

            # Optional: verify with separate agent
            if [ "$verify_enabled" = "yes" ]; then
                verify_output=$(spawn_verifier "$feature_id" "$next_ac" "$worktree_path")
                if ! echo "$verify_output" | grep -q "VERIFICATION_PASSED"; then
                    # Verification failed — roll back, retry
                    git -C "$worktree_path" reset --hard HEAD~1
                    unmark_criterion "$acceptance_file" "$next_ac"
                    consecutive_errors=$((consecutive_errors + 1))
                    continue
                fi
            fi

            consecutive_errors=0
            append_learnings "$learnings_file" "$output"
        else
            consecutive_errors=$((consecutive_errors + 1))
        fi
    elif echo "$output" | grep -q "CRITERION_STUCK"; then
        consecutive_errors=$((consecutive_errors + 1))
        append_learnings "$learnings_file" "$output"
    else
        consecutive_errors=$((consecutive_errors + 1))
    fi

    # Update dashboard
    update_dashboard "$feature_id" "$iteration" "$state_file"
done

# 4. FINALIZE
if all_criteria_done "$acceptance_file"; then
    feature.sh "$feature_id" status auto_verified
    create_pr "$feature_id" "$worktree_path"
    echo "All criteria met. PR created for human review."
else
    echo "Some criteria incomplete. See $state_file for details."
fi
```

### What's Notably ABSENT from This Design

Things I'm deliberately NOT including, aligned with KISS:

1. **No custom settings.json generation** — Use `--dangerously-skip-permissions` + worktree isolation. Simpler than trying to generate per-project permission profiles.
2. **No parallel criterion execution** — Sequential is simpler, more predictable, and avoids merge conflicts within the worktree.
3. **No Graphiti/knowledge graph** — Our append-only learnings file + acceptance criteria are sufficient. No new dependencies.
4. **No Electron UI** — A markdown dashboard file + terminal output is enough. KISS.
5. **No AI plan decomposition** — We already HAVE acceptance criteria. They ARE the plan.
6. **No multi-account swapping** — Handle rate limits with simple backoff + wait. One account is enough.

### File Tree (What Gets Added)

```
.agentic/lib/auto/
├── engine.sh          # Main loop (~300 lines)
├── prompt.sh          # Build prompts from acceptance criteria (~100 lines)
├── verify.sh          # Verification agent spawner (~80 lines)
├── progress.sh        # Read/write acceptance criteria + state files (~100 lines)
├── escalation.sh      # Stop rules + error tracking (~60 lines)
└── dashboard.sh       # Progress output to terminal + file (~80 lines)

.agentic/lib/agents/context-manifests/
├── auto-implementer.yaml   # NEW
└── auto-verifier.yaml      # NEW

.agentic/lib/presets/profiles.conf  # EXTEND with auto_* defaults

.agentic/auto/                      # GITIGNORED — runtime state
├── F-XXXX.state                    # Per-feature state
└── F-XXXX-learnings.md             # Per-feature learnings
```

Total new code: ~720 lines of shell across 6 files. Plus 2 YAML manifests and settings extensions.

That's less than Ralph (110 lines) plus Claude Loop (2000 lines) combined, but with dramatically better safety, verification, and integration with a spec-driven workflow.

### Comparison: Our Architecture vs. The Three Repos

| Concern | Ralph | Claude Loop | Auto-Claude | Our Design |
|---------|-------|------------|-------------|------------|
| Loop mechanism | bash for loop | POSIX shell + lib/ | Python async | bash + existing ag.sh |
| Task definition | prd.json | PLAN.md phases | implementation_plan.json | **Existing acceptance criteria files** |
| Progress tracking | progress.txt + prd.json | PROGRESS.md | JSON + Graphiti | **Acceptance file checkboxes + .state** |
| Safety | None | Optional verify | SDK hooks + worktrees | **Worktrees + verify agent + escalation + pre-commit gates** |
| Context per iteration | Full CLAUDE.md | Phase description | SDK context | **context-for-role.sh (token-optimized)** |
| State management | Agent updates files | Shell updates PROGRESS.md | Python updates JSON | **Shell updates acceptance file (deterministic)** |
| New code needed | 110 lines (standalone) | ~2000 lines (standalone) | ~50K+ lines (standalone) | **~720 lines (integrates with ~3000 lines of existing framework)** |
| Depends on | Nothing | Nothing | Claude Agent SDK, Electron, Python | **Existing framework (already installed)** |

---

## PART 4: Research + Plan + Review Pipeline (Pre-Implementation Phases)

### The Full Autonomous Pipeline

The implementation loop (Part 3) handles "here are the acceptance criteria, go implement them." But for complex features, foundational decisions, or new projects, you need the phases BEFORE implementation:

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│  RESEARCH   │───▶│    SPEC      │───▶│    PLAN      │───▶│  IMPLEMENT  │───▶│   VERIFY    │
│  (optional) │    │  (if needed) │    │  (if needed) │    │   (loop)    │    │  (per AC)   │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
     │                   │                  │                    │                  │
  Gather info       Write specs         Create plan          One AC per       Separate agent
  Analyze options   Write acceptance    Review loop          iteration        checks work
  Compare tech      criteria            Revise until         Fresh Claude     Runs tests
  Understand domain                     approved             each time        Reviews diff
```

Each phase is a separate Claude invocation (or multiple invocations for the review loop). The engine decides which phases to run based on what already exists:

```bash
# Phase auto-detection:
if no acceptance criteria exist for F-XXXX:
    if complex/foundational task:
        run RESEARCH phase
    run SPEC phase (writes acceptance criteria)
    if plan_review_enabled:
        run PLAN phase (with review loop)
run IMPLEMENT phase (the main loop from Part 3)
run VERIFY phase (final check)
```

### Phase 0: Research (Optional)

**When**: Feature involves unfamiliar technology, architectural decisions, or domain exploration.

**Trigger**: `ag auto research "topic"` or auto-detected when feature description is vague.

**What happens**:
1. Engine spawns Claude with `auto-researcher` context manifest
2. Claude searches codebase, reads docs, optionally fetches web resources
3. Output: structured research document saved to `.agentic/auto/research/F-XXXX-research.md`
4. Research document becomes input to the SPEC phase

**Context manifest**: `auto-researcher.yaml` — loads CONTEXT_PACK.md, STACK.md, relevant docs. Excludes implementation details (not needed yet).

**Fresh instance**: Yes. Research agent gets a clean context with the research question + project overview.

**Example prompt**:
```markdown
# Research Task: {topic}

## Context
{from auto-researcher manifest — project overview, tech stack}

## Questions to answer
1. What approaches exist for {topic}?
2. What does our codebase already have that's relevant?
3. What are the trade-offs?
4. Recommended approach and why?

## Output format
Save findings to .agentic/auto/research/F-XXXX-research.md
```

### Phase 1: Spec Writing (If Acceptance Criteria Don't Exist)

**When**: `spec/acceptance/F-XXXX.md` doesn't exist or has no criteria.

**What happens**:
1. Engine spawns Claude with `auto-spec-writer` manifest
2. Input: feature description + research document (if Phase 0 ran) + existing codebase context
3. Claude writes acceptance criteria in our standard format (`- [ ] **AC-NNN**: description`)
4. Output: `spec/acceptance/F-XXXX.md` + optional FEATURES.md entry

**The two-agent pattern applies here too**: After spec is written, spawn a SEPARATE Claude instance as spec reviewer:
- Does the spec cover the feature adequately?
- Are criteria testable and specific?
- Any missing edge cases?
- Are criteria small enough for one iteration each?

If reviewer finds issues, loop back to the writer with feedback. Max 3 review iterations.

**Context manifest**: `auto-spec-writer.yaml` — loads research output, STACK.md, CONTEXT_PACK.md, existing acceptance criteria for style reference, NFR.md for applicable NFRs.

**Why this matters for "setting up project direction"**: For a new project, you might run:
```bash
ag auto spec F-0001 --description "Core authentication system"
ag auto spec F-0002 --description "Database schema and migrations"
ag auto spec F-0003 --description "API endpoint structure"
```

Each creates well-structured acceptance criteria that later feed into `ag auto task F-XXXX`. The specs become the source of truth for the project's direction.

### Phase 2: Planning (With Review Loop)

**When**: Feature is complex (many criteria) or `plan_review_enabled=yes` in STACK.md.

**What happens**:
1. Engine spawns Claude with `auto-planner` manifest
2. Input: acceptance criteria + codebase context + research (if available)
3. Claude creates an implementation plan: which criteria to tackle in what order, what files to touch, what dependencies exist between criteria
4. Plan saved to `.agentic-journal/plans/F-XXXX-plan.md`

**Plan-review loop** (already a concept in our framework!):
1. Planner creates plan
2. Separate Claude instance reviews it:
   - Is the order logical? (dependencies respected?)
   - Are the file lists realistic?
   - Any criteria that should be split or merged?
3. If reviewer has concerns: planner revises
4. Max `plan_review_max_iterations` iterations (from STACK.md settings)

**This is exactly our existing `ag plan` concept, automated.**

The plan output informs the implementation loop — criteria are processed in the planned order rather than file order.

### How Phases Compose into Modes

```
ag auto verify                    → Phase 3 only (test-fix loop)
ag auto task F-XXXX               → Phases 1-4 (spec if needed → plan → implement → verify)
ag auto task F-XXXX --spec-only   → Phase 1 only (just write acceptance criteria)
ag auto task F-XXXX --plan-only   → Phases 1-2 (write spec + create plan, don't implement)
ag auto research "topic"          → Phase 0 only (research, save findings)
ag auto crunch                    → For each feature: Phases 0-4 as needed
```

The `--spec-only` and `--plan-only` flags are powerful for project direction work:

```bash
# Morning: spec out the features (auto writes specs, you review)
ag auto task F-0001 --spec-only
ag auto task F-0002 --spec-only
ag auto task F-0003 --spec-only

# Review and adjust the specs manually

# Afternoon: implement them (auto uses your approved specs)
ag auto crunch F-0001 F-0002 F-0003
```

### For "Core Decisions / Project Direction"

When the task is architectural rather than feature-focused:

```bash
# Research phase: understand the landscape
ag auto research "authentication approaches for our Next.js + Postgres stack"

# This produces .agentic/auto/research/auth-research.md with:
# - Options analyzed (NextAuth, Clerk, custom JWT, etc.)
# - Trade-offs table
# - Recommendation with rationale

# Then spec the chosen approach
ag auto task F-0001 --spec-only --research .agentic/auto/research/auth-research.md

# Review the spec, adjust, then implement
ag auto task F-0001
```

Or for setting up a whole project:

```bash
# Create a project brief
ag auto research "architecture for a SaaS billing dashboard"

# Generate specs for core features
ag auto crunch --spec-only F-0001 F-0002 F-0003 F-0004 F-0005

# Review all specs (human)
# Adjust acceptance criteria as needed

# Then batch implement
ag auto crunch F-0001 F-0002 F-0003 F-0004 F-0005
```

### Updated File Tree

```
.agentic/lib/auto/
├── engine.sh          # Main loop + phase orchestration (~400 lines)
├── phases/
│   ├── research.sh    # Phase 0: research (~80 lines)
│   ├── spec.sh        # Phase 1: spec writing + review (~120 lines)
│   ├── plan.sh        # Phase 2: planning + review loop (~100 lines)
│   ├── implement.sh   # Phase 3: criterion implementation loop (~200 lines)
│   └── verify.sh      # Phase 4: verification agent (~80 lines)
├── prompt.sh          # Prompt templates for all phases (~150 lines)
├── progress.sh        # State management (~100 lines)
├── escalation.sh      # Stop rules (~60 lines)
└── dashboard.sh       # Progress output (~80 lines)

.agentic/lib/agents/context-manifests/
├── auto-implementer.yaml   # NEW
├── auto-verifier.yaml      # NEW
├── auto-researcher.yaml    # NEW
├── auto-spec-writer.yaml   # NEW
├── auto-spec-reviewer.yaml # NEW
└── auto-planner.yaml       # NEW

.agentic/auto/               # GITIGNORED — runtime state
├── research/                 # Research outputs
├── F-XXXX.state              # Per-feature state
└── F-XXXX-learnings.md       # Per-feature learnings
```

Total new code: ~1370 lines of shell across ~11 files. Plus 6 YAML manifests.

Still dramatically simpler than Auto-Claude (~50K+ lines) while providing the full pipeline from research through verification.

### The "Two-Agent Pattern" Throughout

This is the unifying architectural pattern across ALL phases:

| Phase | Doer Agent | Reviewer Agent |
|-------|-----------|---------------|
| Research | Researcher | (none — output reviewed by human or spec phase) |
| Spec | Spec Writer | Spec Reviewer |
| Plan | Planner | Plan Reviewer |
| Implement | Implementer | (none per criterion — but tests are the "reviewer") |
| Verify | (none — deterministic test run) | Verification Agent |

Every non-trivial output gets checked by a second perspective. This is what makes it reliable without human intervention at every step.

---

## PART 5: Development Mode Shapes (TDD / SDD / Standard)

### The Key Insight

In TDD mode, the iteration for each criterion splits into distinct phases:

```
Standard mode:  Claude implements + writes test → engine runs test → done
TDD mode:       Claude writes test → engine verifies FAIL → Claude implements → engine verifies PASS
SDD mode:       (spec already written) → Claude writes test → engine verifies FAIL → Claude implements → engine verifies PASS
```

This is actually MORE reliable in auto mode because:
- The RED → GREEN transition is **machine-verifiable** (deterministic)
- Each iteration is even MORE focused (either test-only or implement-only)
- The test acts as a specification FOR the implementation agent
- The implementation agent has a clear, unambiguous definition of "done": make the test pass

### TDD Iteration Shape

For each acceptance criterion in TDD mode:

```
┌─────────────────────────────────────────────────────┐
│ Step 1: WRITE TEST (fresh Claude instance)           │
│                                                      │
│ Prompt: "Write a failing test for AC-N.              │
│          The test should verify: {criterion}          │
│          Use test framework: {from STACK.md}          │
│          The test MUST fail right now."               │
│                                                      │
│ Engine checks:                                       │
│   ✓ Test file was created/modified                   │
│   ✓ Run test → it FAILS (RED)                        │
│   If test passes: REJECT (criterion already works)   │
│   If no test: RETRY with feedback                    │
│                                                      │
│ Commit: "test(F-XXXX): add failing test for AC-N"   │
├─────────────────────────────────────────────────────┤
│ Step 2: IMPLEMENT (fresh Claude instance)            │
│                                                      │
│ Prompt: "Make this failing test pass for AC-N.       │
│          The test is at: {test_file}:{line}           │
│          Implement the minimum code to pass.          │
│          Do NOT modify the test."                     │
│                                                      │
│ Engine checks:                                       │
│   ✓ Test now PASSES (GREEN)                          │
│   ✓ All OTHER tests still pass (no regressions)      │
│   If test still fails: RETRY with failure output     │
│   If other tests break: RETRY with regression info   │
│                                                      │
│ Commit: "feat(F-XXXX): implement AC-N"              │
├─────────────────────────────────────────────────────┤
│ Step 3: REFACTOR (optional, fresh Claude instance)   │
│                                                      │
│ Prompt: "Refactor the implementation for AC-N.       │
│          All tests MUST continue to pass.             │
│          Focus on: readability, DRY, patterns."       │
│                                                      │
│ Engine checks:                                       │
│   ✓ All tests still pass                             │
│   If any test fails: ROLLBACK refactor               │
│                                                      │
│ Commit: "refactor(F-XXXX): clean up AC-N"           │
└─────────────────────────────────────────────────────┘
```

### Why TDD Is Actually the IDEAL Auto Mode

Think about it: TDD was designed for human developers to have clear feedback loops. For an autonomous agent, these feedback loops are even MORE valuable:

1. **Unambiguous success criteria**: The test IS the spec. "Is the test passing?" is binary — no interpretation needed.

2. **Regression detection is free**: Running the full test suite after each implementation catches regressions immediately. The engine does this deterministically.

3. **The implementation agent is maximally constrained**: It receives a failing test and its ONLY job is to make it pass. This is the smallest, most focused task possible — perfect for one Claude context window.

4. **The test-writing agent is maximally creative**: It reads the acceptance criterion and translates it into executable test code. This is a design task, well-suited for a fresh, unfocused context.

5. **RED → GREEN is machine-verifiable**: The engine doesn't need a verification agent to check if the criterion was met. The test suite does this. In TDD mode, the verification agent becomes less important (or can focus on code quality instead of correctness).

### Development Mode Integration

Our framework already has `development_mode` in STACK.md:

```markdown
## Settings
- development_mode: tdd    # Options: standard, tdd, sdd
```

The engine reads this and adjusts iteration shape:

```bash
dev_mode=$(get_setting "development_mode" "standard")

case "$dev_mode" in
    tdd)
        # For each criterion: write_test → verify_red → implement → verify_green → optional_refactor
        for ac in $(get_pending_criteria "$acceptance_file"); do
            write_failing_test "$ac"
            verify_test_fails "$ac"    # Engine runs tests, checks for RED
            implement_criterion "$ac"
            verify_test_passes "$ac"   # Engine runs tests, checks for GREEN + no regressions
            if get_setting "auto_refactor" "no" = "yes"; then
                refactor_criterion "$ac"
                verify_all_pass          # Regression check
            fi
            mark_criterion_done "$acceptance_file" "$ac"
        done
        ;;
    sdd)
        # Same as TDD but specs are already the starting point
        # (Phase 1: Spec already ran, Phase 2: Plan already ran)
        # From here, identical to TDD
        ;;
    standard)
        # For each criterion: implement_with_test → verify_passes
        for ac in $(get_pending_criteria "$acceptance_file"); do
            implement_and_test "$ac"
            verify_tests_pass "$ac"
            mark_criterion_done "$acceptance_file" "$ac"
        done
        ;;
esac
```

### ADD Mode (Acceptance-Driven Development)

There's actually a fourth mode that combines our framework's strengths uniquely:

```
ADD mode: spec → test → implement → verify
```

This is what the FULL pipeline looks like when all phases run:
1. **Research** produces domain knowledge
2. **Spec** writes acceptance criteria (the "contract")
3. **Test Writing** translates criteria into executable tests (all FAIL initially)
4. **Implementation** makes tests pass one by one
5. **Verification** checks everything

ADD is essentially TDD where the specs drive the test design. The acceptance criteria ARE the test specifications. This is our framework's unique contribution — nobody else has the spec layer feeding into TDD.

Setting: `development_mode: add` (Acceptance-Driven Development)

### How This Changes the Prompt Design

**TDD Test-Writing Prompt** (Step 1):
```markdown
# Write Failing Test for {Feature} - {Criterion}

## Acceptance Criterion
{AC-N description from acceptance file}

## Test Framework
{from STACK.md: pytest, jest, vitest, etc.}

## Existing Tests
{list of test files in the area, from context manifest}

## Instructions
1. Write a test that verifies the acceptance criterion
2. The test MUST FAIL right now (the feature isn't implemented yet)
3. Name the test descriptively: test_{criterion_slug}
4. Use the project's existing test patterns and conventions
5. Output the test file path when done

## Important
- Do NOT implement the feature
- Only write the test
- The test should clearly test the criterion's requirement
- Output: TEST_WRITTEN {file_path}
```

**TDD Implementation Prompt** (Step 2):
```markdown
# Implement {Feature} - {Criterion}

## Failing Test
File: {test_file}
Test: {test_name}

## Test Output (current failure)
{actual test failure output from engine running the test}

## Acceptance Criterion
{AC-N description}

## Codebase Context
{from auto-implementer manifest}

## Instructions
1. Read the failing test carefully
2. Implement the MINIMUM code to make the test pass
3. Do NOT modify the test file
4. Run: {test_command} to verify
5. If all tests pass, output: CRITERION_PASSED
6. If stuck, output: CRITERION_STUCK {reason}

## Important
- Only implement what the test requires
- Keep it simple — refactoring comes later
- Do NOT add features beyond what the test checks
```

### Updated Engine Pseudocode (TDD Mode)

```bash
# engine.sh task F-XXXX (TDD mode)

dev_mode=$(get_setting "development_mode" "standard")

for ac in $(get_pending_criteria "$acceptance_file"); do
    ac_id=$(extract_ac_id "$ac")
    ac_desc=$(extract_ac_description "$ac")

    if [ "$dev_mode" = "tdd" ] || [ "$dev_mode" = "add" ]; then
        # === STEP 1: Write Failing Test ===
        test_prompt=$(build_test_writing_prompt "$feature_id" "$ac_id" "$ac_desc")
        test_output=$(spawn_auto_agent "$test_prompt" "$worktree_path")

        if ! echo "$test_output" | grep -q "TEST_WRITTEN"; then
            # Test wasn't written — retry or escalate
            consecutive_errors=$((consecutive_errors + 1))
            continue
        fi

        # Verify test FAILS (RED)
        if run_tests "$worktree_path" 2>/dev/null; then
            # Test passed — criterion already works or test is wrong
            echo "WARNING: Test passes without implementation. Skipping or reviewing."
            # Could mean: feature already partially implemented, or test is weak
            mark_criterion_done "$acceptance_file" "$ac"
            git -C "$worktree_path" add -A && git -C "$worktree_path" commit -m "test(${feature_id}): ${ac_id} already passes"
            continue
        fi

        # Good — test fails. Commit the failing test.
        git -C "$worktree_path" add -A
        git -C "$worktree_path" commit -m "test(${feature_id}): add failing test for ${ac_id}"

        # Capture test failure output for the implementation agent
        test_failure=$(run_tests "$worktree_path" 2>&1 || true)
    fi

    # === STEP 2: Implement ===
    impl_prompt=$(build_implementation_prompt "$feature_id" "$ac_id" "$ac_desc" "$test_failure")
    impl_output=$(spawn_auto_agent "$impl_prompt" "$worktree_path")

    # Verify test PASSES (GREEN) and no regressions
    if run_tests "$worktree_path"; then
        # Commit implementation
        git -C "$worktree_path" add -A
        git -C "$worktree_path" commit -m "feat(${feature_id}): implement ${ac_id}"

        mark_criterion_done "$acceptance_file" "$ac"
        consecutive_errors=0

        # === STEP 3: Optional Refactor ===
        if [ "$(get_setting "auto_refactor" "no")" = "yes" ]; then
            refactor_prompt=$(build_refactor_prompt "$feature_id" "$ac_id")
            spawn_auto_agent "$refactor_prompt" "$worktree_path"

            if run_tests "$worktree_path"; then
                git -C "$worktree_path" add -A
                git -C "$worktree_path" commit -m "refactor(${feature_id}): clean up ${ac_id}"
            else
                # Refactor broke something — rollback
                git -C "$worktree_path" checkout -- .
            fi
        fi
    else
        # Tests still failing after implementation — retry
        consecutive_errors=$((consecutive_errors + 1))
        append_learnings "$learnings_file" "Failed: ${ac_id} — tests don't pass after implementation"
    fi
done
```

### The Beauty of This Design

The auto engine in TDD mode produces a git history that looks like a skilled developer's work:

```
a1b2c3d test(F-0042): add failing test for AC-001
d4e5f6a feat(F-0042): implement AC-001
7g8h9i0 refactor(F-0042): clean up AC-001
j1k2l3m test(F-0042): add failing test for AC-002
n4o5p6q feat(F-0042): implement AC-002
r7s8t9u test(F-0042): add failing test for AC-003
v1w2x3y feat(F-0042): implement AC-003
z4a5b6c chore(F-0042): final verification passed
```

Each commit is small, focused, and the test/implementation pairs tell a clear story. The PR reviewer can see exactly what each criterion does and how it was tested.

## Final Architecture Summary

```
                    ag auto task F-XXXX
                           │
                    ┌──────▼──────┐
                    │  engine.sh  │
                    └──────┬──────┘
                           │
            ┌──────────────┼──────────────┐
            │              │              │
     ┌──────▼──────┐ ┌────▼────┐ ┌──────▼──────┐
     │ Phase 0-2   │ │ Phase 3 │ │ Phase 4     │
     │ Research/   │ │ Impl    │ │ Verify      │
     │ Spec/Plan   │ │ Loop    │ │             │
     └─────────────┘ └────┬────┘ └─────────────┘
                          │
              ┌───────────┼───────────┐
              │           │           │
         ┌────▼────┐ ┌───▼───┐ ┌────▼────┐
         │ TDD     │ │ SDD   │ │Standard │
         │ RED→    │ │ Spec→ │ │ Impl+   │
         │ GREEN→  │ │ Test→ │ │ Test    │
         │ REFACTOR│ │ Impl  │ │ together│
         └─────────┘ └───────┘ └─────────┘

    dev_mode setting selects iteration shape
```

---

## PART 6: Live Dashboard & Agent Monitoring

### The Problem with Checkboxes

Acceptance criteria checkboxes (`[x]`/`[ ]`) show **completion state** but not:
- What's happening RIGHT NOW
- Which iteration we're on
- What Claude is currently doing (reading files? writing code? running tests?)
- Whether we're stuck or making progress
- How long each phase is taking
- Error details

For autonomous operation, you need two views:
1. **Summary view**: Quick glance — how far along, any problems?
2. **Detail view**: Live output, current agent activity, ability to intervene

### Architecture: State File + Viewer

The engine writes structured state; a separate viewer reads and displays it.

```
┌──────────────┐         ┌─────────────────┐
│  engine.sh   │────────▶│ .agentic/auto/   │
│  (writes)    │         │ live-state.json   │
└──────────────┘         └────────┬──────────┘
                                  │
                    ┌─────────────┼─────────────┐
                    │             │              │
              ┌─────▼─────┐ ┌───▼────┐ ┌──────▼──────┐
              │ Terminal   │ │ Web    │ │ Markdown    │
              │ dashboard  │ │ UI     │ │ file        │
              │ (Phase 1)  │ │(Phase 2)│ │ (always)   │
              └─────┬─────┘ └───┬────┘ └─────────────┘
                    │           │
                    │     ┌─────▼──────┐
                    │     │ Controls:  │
                    └────▶│ pause      │
                          │ resume     │
                          │ cancel     │
                          │ feedback   │
                          └────────────┘
```

### The State File (`live-state.json`)

Engine writes this after every significant event:

```json
{
  "feature": "F-0042",
  "description": "User Authentication",
  "phase": "implement",
  "dev_mode": "tdd",
  "started": "2026-03-06T17:30:00",
  "elapsed_seconds": 342,
  "criteria": {
    "total": 5,
    "completed": 2,
    "in_progress": "AC-003",
    "pending": 2,
    "stuck": 0
  },
  "current": {
    "criterion": "AC-003",
    "step": "implement",
    "iteration": 1,
    "status": "running",
    "agent_pid": 12345,
    "started": "2026-03-06T17:35:42",
    "last_activity": "2026-03-06T17:36:15",
    "last_tool": "Edit src/auth/login.ts"
  },
  "iterations": {
    "total": 7,
    "successful": 5,
    "failed": 2,
    "consecutive_errors": 0
  },
  "tests": {
    "last_run": "2026-03-06T17:36:10",
    "total": 12,
    "passing": 10,
    "failing": 2,
    "command": "npm test"
  },
  "commits": [
    {"hash": "a1b2c3d", "message": "test(F-0042): add failing test for AC-001", "time": "17:31:15"},
    {"hash": "d4e5f6a", "message": "feat(F-0042): implement AC-001", "time": "17:32:30"},
    {"hash": "7g8h9i0", "message": "test(F-0042): add failing test for AC-002", "time": "17:33:45"},
    {"hash": "n4o5p6q", "message": "feat(F-0042): implement AC-002", "time": "17:35:00"}
  ],
  "errors": [],
  "worktree": "/Users/tomas/code/my-project-auto-f-0042",
  "branch": "feature/F-0042"
}
```

Writing this is cheap — it's a single file write after each event. The engine already tracks all this state internally.

### Control File (`.agentic/auto/control`)

Simple text-based control interface:

```
# Write a command to this file, engine reads at next iteration boundary
PAUSE              # Stop after current iteration completes
RESUME             # Continue after pause
CANCEL             # Stop and clean up
FEEDBACK AC-003 "Try using the existing AuthService instead of creating a new one"
SKIP AC-003        # Mark as stuck, move to next criterion
PRIORITY AC-005    # Do AC-005 next instead of the default order
```

The engine checks this file at every iteration boundary (between criteria, between TDD steps):

```bash
check_control() {
    local control_file=".agentic/auto/control"
    [ -f "$control_file" ] || return 0

    local cmd=$(head -1 "$control_file")
    case "$cmd" in
        PAUSE*)
            echo "Paused by user. Write RESUME to continue."
            while true; do
                sleep 5
                cmd=$(head -1 "$control_file" 2>/dev/null)
                [ "$cmd" = "RESUME" ] && break
                [ "$cmd" = "CANCEL" ] && exit 0
            done
            ;;
        CANCEL*)
            echo "Cancelled by user."
            exit 0
            ;;
        FEEDBACK*)
            # Extract feedback and inject into next iteration's learnings
            local feedback="${cmd#FEEDBACK }"
            echo "Human feedback: $feedback" >> "$learnings_file"
            ;;
        SKIP*)
            local skip_ac="${cmd#SKIP }"
            mark_criterion_stuck "$acceptance_file" "$skip_ac"
            ;;
    esac
    # Clear the control file after processing
    > "$control_file"
}
```

### Phase 1: Terminal Dashboard (ship first)

A simple terminal output that updates in-place:

```
╔══════════════════════════════════════════════════════════════╗
║  ag auto: F-0042 User Authentication                       ║
║  Mode: TDD │ Branch: feature/F-0042 │ Elapsed: 5m 42s      ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  Criteria Progress                                           ║
║  ████████████░░░░░░░░░░░░░░ 2/5 (40%)                      ║
║                                                              ║
║  [x] AC-001: POST /login returns JWT ................ DONE   ║
║  [x] AC-002: Invalid password returns 401 ........... DONE   ║
║  [>] AC-003: Expired token returns 401 ........... RUNNING   ║
║      └─ Step: implement (iteration 1/5)                      ║
║      └─ Agent: editing src/middleware/auth.ts                 ║
║  [ ] AC-004: Token refresh endpoint ................. PENDING ║
║  [ ] AC-005: Rate limiting on login ................. PENDING ║
║                                                              ║
║  Tests: 10/12 passing │ Commits: 4 │ Errors: 0              ║
║                                                              ║
║  Last: feat(F-0042): implement AC-002 (2m ago)               ║
║                                                              ║
║  Controls: Write to .agentic/auto/control                    ║
║    PAUSE │ CANCEL │ SKIP AC-NNN │ FEEDBACK AC-NNN "msg"      ║
╚══════════════════════════════════════════════════════════════╝
```

This can be implemented with simple `printf` and ANSI escape codes — no dependencies. The engine outputs this to stderr (so it doesn't interfere with logged output). Or a separate `ag auto status` command that reads `live-state.json` and renders.

For `ag crunch` (multiple features), the dashboard expands:

```
╔══════════════════════════════════════════════════════════════╗
║  ag crunch: 5 features                                      ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  [x] F-0040: Database schema ............ DONE (12m)         ║
║  [x] F-0041: API endpoints .............. DONE (18m)         ║
║  [>] F-0042: User Authentication ........ IN PROGRESS        ║
║      └─ AC-003 implementing (2/5 criteria done)              ║
║  [ ] F-0043: Dashboard UI ............... PENDING             ║
║  [ ] F-0044: Email notifications ........ PENDING             ║
║                                                              ║
║  Overall: 2/5 features │ Time: 35m │ PRs created: 2          ║
╚══════════════════════════════════════════════════════════════╝
```

### Phase 2: Web Dashboard (future enhancement)

A local web server serving a live dashboard:

```bash
ag auto dashboard    # Start dashboard server on localhost:3847
```

Implementation concept:
- Single HTML file with embedded JS (no build step, no dependencies)
- Engine writes `live-state.json` (already done for terminal dashboard)
- HTML page polls the JSON file every 2 seconds (or uses Server-Sent Events)
- Shows: progress, live output, commit graph, test results
- Interactive controls: pause/resume/cancel buttons, feedback input
- Screenshots from visual verification displayed inline

The web dashboard is a separate enhancement — it reads the SAME state file as the terminal dashboard. No changes to the engine needed.

Tech: Could be as simple as Python's `http.server` serving a static HTML + a JSON endpoint. Or even `npx serve` with a custom page. No framework needed.

### Phase 3: Multi-Agent Visual View (ambitious future)

For `ag crunch` with parallel execution (future):
- Multiple worktrees running simultaneously
- Each shows its own progress
- Gantt-like view of phase timelines
- Shared resource view (rate limit status, API usage)

This is the "Kanban board" view from Auto-Claude — but auto-generated from our structured state files.

### How State Propagates

```
engine.sh
    │
    ├──▶ .agentic/auto/live-state.json    ← Real-time state (JSON)
    │
    ├──▶ .agentic/auto/F-XXXX.state       ← Per-feature state (key=value)
    │
    ├──▶ spec/acceptance/F-XXXX.md        ← Criteria checkboxes ([x]/[ ])
    │
    ├──▶ .agentic/auto/dashboard.md       ← Markdown snapshot (for editors)
    │
    └──▶ stderr                            ← Terminal dashboard (live)

ag auto status    ← reads live-state.json, renders terminal view
ag auto dashboard ← starts web server reading live-state.json
```

Multiple viewers can read the state simultaneously. The engine doesn't know or care about viewers — it just writes state.

### Updated File Tree

```
.agentic/lib/auto/
├── engine.sh          # Main loop + phase orchestration
├── phases/
│   ├── research.sh
│   ├── spec.sh
│   ├── plan.sh
│   ├── implement.sh
│   └── verify.sh
├── prompt.sh          # Prompt templates
├── progress.sh        # State management + live-state.json writer
├── escalation.sh      # Stop rules
├── dashboard.sh       # Terminal dashboard renderer
├── control.sh         # Control file reader
└── web/               # Web dashboard (Phase 2)
    └── dashboard.html # Single-file web UI

.agentic/auto/                      # GITIGNORED
├── live-state.json                  # Real-time state
├── control                          # Control commands
├── dashboard.md                     # Markdown snapshot
├── research/                        # Research outputs
├── F-XXXX.state                     # Per-feature state
└── F-XXXX-learnings.md              # Per-feature learnings
```

## Summary: The Complete Vision

```
Human says: ag auto crunch F-0040 F-0041 F-0042 F-0043 F-0044
Human opens: ag auto dashboard (in another terminal/browser)

Engine:
  For each feature:
    Phase 0: Research (if needed)
    Phase 1: Write specs + acceptance criteria (if needed)
    Phase 2: Plan (with review loop)
    Phase 3: Implement (TDD: test → RED → implement → GREEN per criterion)
    Phase 4: Final verification
    → Create PR
    → Update dashboard
    → Move to next feature

Human watches progress, can:
  - PAUSE/RESUME at any time
  - Give FEEDBACK on specific criteria
  - SKIP stuck criteria
  - CANCEL the whole run

Result: 5 PRs ready for review, each with clean TDD commit history
```

## Open Questions

1. **State file format**: JSON (structured, easy for web) vs key=value (shell-native, no jq needed). Could do both — engine writes key=value `.state` for internal use + JSON for dashboards.
2. **Web dashboard scope**: MVP could be literally a single HTML page that auto-refreshes. Keep it dead simple.
3. **Should `ag auto status` be a one-shot view or a live-updating TUI?** One-shot is simpler; live-updating needs a loop. Leaning: one-shot by default, `--watch` for continuous.
4. **Parallel features in crunch mode**: Sequential first (KISS). Parallel later using multiple worktrees. Dashboard design should account for parallel from the start even if engine is sequential.
5. **How to handle "give details/feedback"**: The FEEDBACK control command injects human knowledge into the learnings file. The next iteration reads it. Simple but effective — no complex IPC needed.

---

---

## PART 7: Concrete Implementation Plan

### Feature Breakdown

This work spans multiple features. Each is independently shippable:

| Feature ID | Name | Priority | Depends On |
|-----------|------|----------|------------|
| F-0160 | Auto Mode Foundation (engine, progress, escalation) | P0 | — |
| F-0161 | `ag auto verify` — Test-Fix Loop | P0 | F-0160 |
| F-0162 | `ag auto task F-XXXX` — Single Task Auto | P1 | F-0160, F-0161 |
| F-0163 | TDD/SDD Iteration Shapes | P1 | F-0162 |
| F-0164 | Verification Agent (doer+verifier) | P1 | F-0162 |
| F-0165 | Pre-Implementation Phases (research, spec, plan) | P2 | F-0162 |
| F-0166 | `ag auto crunch` — Multi-Task Pipeline | P2 | F-0162, F-0165 |
| F-0167 | Live Dashboard (terminal + web) | P2 | F-0160 |
| F-0168 | Visual Verification (Playwright MCP) | P3 | F-0164 |
| F-0169 | Multi-Tool Support (Cursor, Codex) | P3 | F-0162 |

### Implementation Order (What to Build First)

#### Step 1: Spec & Register Features

Create feature entries in `.agentic/spec/FEATURES.md` for F-0160 through F-0167 (P0-P2).
Write acceptance criteria for F-0160 and F-0161 in `spec/acceptance/`.

#### Step 2: F-0160 — Auto Mode Foundation (~300 lines)

**Files to create:**
- `.agentic/lib/auto/engine.sh` — Main loop orchestrator
- `.agentic/lib/auto/progress.sh` — Parse/update acceptance criteria checkboxes + state files
- `.agentic/lib/auto/escalation.sh` — Stop rules (max iterations, consecutive errors)
- `.agentic/lib/auto/prompt.sh` — Build iteration prompts from acceptance criteria + learnings

**Files to modify:**
- `.agentic/lib/tools/ag.sh` — Add `cmd_auto()` dispatcher (`ag auto verify|task|crunch|status|stop`)
- `.agentic/lib/settings.sh` — Add `auto_*` setting defaults
- `.agentic/lib/presets/profiles.conf` — Add auto settings per profile
- `.gitignore` — Add `.agentic/auto/` (runtime state directory)

**Existing code to reuse:**
- `worktree.sh` (307 lines) — `create`, `list`, `remove`, `status` — direct reuse
- `settings.sh` (346 lines) — `get_setting()` for all auto_* settings
- `context-for-role.sh` — spawn with focused context per iteration
- `pre-commit-check.sh` — run programmatically between iterations

**Key functions in engine.sh:**
```
spawn_auto_agent()     — invoke claude --print with prompt
run_tests()            — execute test_command from STACK.md
check_control()        — read .agentic/auto/control for pause/cancel
update_state()         — write live-state.json + .state file
main_loop()            — iterate over pending acceptance criteria
```

#### Step 3: F-0161 — `ag auto verify` (~100 lines)

The simplest mode: run tests → if fail → spawn Claude to fix → re-run → repeat.

**Files to create:**
- `.agentic/lib/auto/phases/verify.sh` — Test-fix loop

**This is the "Hello World" of auto mode** — proves the loop works, the agent spawning works, test detection works, escalation works. All subsequent modes build on this.

#### Step 4: F-0162 — `ag auto task F-XXXX` (~200 lines)

Full single-task auto: read acceptance criteria → pick next `[ ]` → build prompt → spawn Claude → run tests → mark `[x]` → commit → repeat.

**Files to create:**
- `.agentic/lib/auto/phases/implement.sh` — Per-criterion implementation loop
- `.agentic/lib/agents/context-manifests/auto-implementer.yaml`
- `.agentic/lib/agents/context-manifests/auto-verifier.yaml`

**Files to modify:**
- `.agentic/lib/tools/feature.sh` — Add `auto_verified` status transition

#### Step 5: F-0163, F-0164 — TDD Shapes + Verification Agent

Extend implement.sh with TDD iteration shape (RED→GREEN→REFACTOR).
Add verification agent spawning after each criterion.

#### Step 6: F-0165, F-0166, F-0167 — Later phases

Research/spec/plan phases, crunch mode, dashboard. Each builds on the foundation.

### Settings to Add

```
# In profiles.conf (defaults per profile)
formal.auto_max_iterations=10
formal.auto_verify=yes
formal.auto_worktree=yes
formal.auto_tool=claude
formal.auto_escalation_threshold=3
formal.auto_refactor=no
discovery.auto_max_iterations=5
discovery.auto_verify=no
discovery.auto_worktree=yes
discovery.auto_tool=claude
discovery.auto_escalation_threshold=3
discovery.auto_refactor=no
```

### Verification Plan

1. **Unit tests**: Add `tests/test_auto_progress.sh` — test acceptance criteria parsing, checkbox toggle, state file read/write
2. **Integration test**: Create a toy project in `/tmp`, write a simple spec with 2 criteria, run `ag auto task F-TEST`, verify both criteria get checked and tests pass
3. **Escalation test**: Create a spec with an impossible criterion, verify engine stops after max iterations
4. **Manual smoke test**: Run `ag auto verify` on a project with a known failing test, watch it fix and re-run

### R2 Exception (Formal)

Add to `.agentic/lib/PRINCIPLES.md` under R2:
> **Exception**: Auto mode (`ag auto`) may commit to isolated worktree branches. Human approval is required to merge the resulting PR to the main branch.

### What We're NOT Building (KISS)

- No Docker containerization (worktrees are sufficient isolation for now)
- No parallel criterion execution (sequential avoids merge conflicts)
- No knowledge graph (append-only learnings file is sufficient)
- No Electron/desktop UI (terminal + optional web dashboard)
- No multi-account API key rotation (simple backoff handles rate limits)
- No AI-generated plans from free text (we already have acceptance criteria)

---

## Files Analyzed

- `/tmp/auto-claude/` — Full repo, key files: `CLAUDE.md`, `apps/backend/qa/loop.py`, `apps/backend/agents/session.py`, `apps/backend/agents/coder.py`, `apps/backend/security/hooks.py`
- `/tmp/Claude Loop/` — Full repo, key files: `Claude Loop` (main script), `lib/verify.sh`, `lib/retry.sh`, `lib/prompt.sh`
- `/tmp/ralph/` — Full repo, key files: `ralph.sh`, `prompt.md`, `AGENTS.md`, `README.md`
