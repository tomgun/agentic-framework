# Strategic Direction: Hooks-First Agentic Framework

**Status**: APPROVED
**Date**: 2026-03-21
**Scope**: Major architectural refactor — strip v2 engine, simplify to hooks-based enforcement

## Context

The v2 refactor (Phases 1-4) built a custom Python state machine engine to enforce workflows. Meanwhile, hooks have become a cross-tool standard — Claude Code, Cursor, Copilot, Gemini CLI, and OpenCode all support PreToolUse/PostToolUse with deterministic blocking (exit code 2). The state machine engine duplicates what platforms now provide natively.

~90% of the framework's historical complexity compensated for LLM unreliability. Hooks solve this at the platform level.

Research inputs: Our own analysis + ChatGPT 5.3/5.4 feasibility study (`docs/research/2026-03-21-hooks-only-feasibility.md`). Plan reviewed by fresh critic agent — key corrections integrated below.

## Decision: Option 3 — Strip the engine, simplify the product

**Reject Option 1** (keep engine as extra): Two systems = double maintenance, user confusion.
**Reject Option 2** (start over): Loses autonomous execution system (~15K lines of proven orchestration), edge cases baked into scripts.
**Accept Option 3**: Same product, same `ag` commands, same UX. Dramatically simpler internals.

---

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│  Tool Hooks (per tool: Claude/Cursor/Copilot/Gemini)     │
│                                                          │
│  Enforcement adapters:  thin wrappers → ag gate          │
│  Context hooks:         richer scripts (session, prompt)  │
├──────────────────────────────────────────────────────────┤
│  ag gate / ag verify    (bash entry → Python gate checks) │
│  Single policy engine — reads state files, returns JSON   │
├──────────────────────────────────────────────────────────┤
│  State Files            (FEATURES.md, STATUS.md, etc.)   │
│  Human-readable, cross-tool, no engine needed            │
├──────────────────────────────────────────────────────────┤
│  CI also calls ag verify (same checks, merge-level gate) │
└──────────────────────────────────────────────────────────┘
```

### Three Concerns, Cleanly Separated

```
ENFORCEMENT  → ag gate (Python gate checks) + hook adapters (per-tool bash)
GUIDANCE     → skills (Claude) / instruction files (other tools) — kept separate from hooks
STATE        → human-readable markdown/yaml/json files (cross-tool)
```

---

### Two Categories of Hooks

The review correctly identified that not all hooks are "thin adapters." There are two distinct types:

**Enforcement hooks** — thin adapters that call `ag gate` and return allow/deny:
- `PreToolUse` (block git commit, destructive ops, code without spec)
- `Stop` (block stopping until `ag verify` passes)
- `TaskCompleted` (block task completion until ACs verified)

**Context hooks** — richer scripts that inject state and do advisory checks:
- `SessionStart` (inject project state, detect interrupted work, show dashboard)
- `UserPromptSubmit` (detect intent, inject workflow prompts, collision checks, stale artifact detection)
- `PreCompact` (preserve critical state before context compression)
- `PostToolUse` (track batch size, advisory warnings)

Enforcement hooks are ~20-30 lines (parse input, call `ag gate`, format response).
Context hooks are 50-150 lines (read multiple state files, compose context). This matches the existing hook complexity (UserPromptSubmit.sh is 178 lines, Stop.sh is 115 lines).

---

### Policy Engine: `ag gate` (bash → Python, NOT pure bash)

**Critical correction from review:** The existing gate logic (`gates.py` 469 lines, `preconditions.py` 185 lines) is well-structured Python with proper data structures and tests. Rewriting it in bash would produce 500-1000 lines of tangled if/then/else — worse, not better.

`ag gate` is a **bash entry point** that dispatches to a **simplified Python module**:

```bash
# ag gate pretool --tool Write --feature F-0001
# → calls: python3 -m agentic.gates pretool --tool Write --feature F-0001
# → returns: {"decision": "deny", "reason": "No acceptance criteria for F-0001"}
```

What stays from Python:
- `gates.py` — 8 gate check functions (spec exists, tests exist, docs current, etc.)
- `settings.py` — profile/config reading from STACK.md

What's removed:
- `v2/` — TransitionOrchestrator, work items, YAML state config
- `gate_dispatch.py` — routing to human/ai/skip (hooks do this now)
- `features_sync.py` — no dual truth = no sync needed
- `state_machine.py` — v1 state machine class (gate checks don't need it)
- `preconditions.py` — replaced by simplified checks in gates.py

`ag verify` calls the same gate checks but runs ALL of them and returns pass/fail. CI calls `ag verify`. Hooks call `ag gate <specific-check>`.

### Active Feature Resolution

Gate checks need to know which feature is being worked on. Hooks don't receive feature IDs. Resolution order:

1. Read AGENTS.json → find WIP entry for current session/agent
2. Fall back to STATUS.md → parse current focus line
3. Fall back to BACKLOG.json → position 0 (current item)
4. If none found → skip feature-specific checks (discovery mode behavior)

This logic lives in `gates.py` as `resolve_active_feature()`, called by `ag gate` before dispatching to specific checks.

---

### Hooks Configuration: Separate from Skills

**Correction from review:** Hooks and skills serve different concerns. Skills tell the LLM what to do (guidance). Hooks tell the runtime what to enforce (policy). Conflating them creates confusion.

- **`hooks.json`** (per tool) — enforcement configuration, source of truth for hooks
- **Skills** (Claude) / instruction files (other tools) — guidance, no enforcement logic
- **`ag export <tool>`** — generates BOTH from their respective sources

```
.agentic/
  hooks/
    gates.py              ← policy logic (simplified from existing gates.py)
    settings.py           ← reads STACK.md config
    claude/
      enforcement.sh      ← PreToolUse, Stop, TaskCompleted adapters
      context.sh          ← SessionStart, UserPromptSubmit, PreCompact
    cursor/
      enforcement.sh      ← same gate calls, Cursor JSON format
      context.sh          ← Cursor context injection
    copilot/
      ...
    gemini/
      ...
```

Claude hooks.json (generated by `ag export claude` or maintained directly):
```json
{
  "hooks": {
    "PreToolUse": [{ "matcher": "Bash", "hooks": [{ "type": "command", "command": ".agentic/hooks/claude/enforcement.sh" }] }],
    "Stop": [{ "hooks": [{ "type": "command", "command": ".agentic/hooks/claude/enforcement.sh" }] }],
    "SessionStart": [{ "hooks": [{ "type": "command", "command": ".agentic/hooks/claude/context.sh" }] }],
    "UserPromptSubmit": [{ "hooks": [{ "type": "command", "command": ".agentic/hooks/claude/context.sh" }] }]
  }
}
```

---

### Cross-Tool Adapter Reality

The review correctly noted that "same bash scripts across tools" has a structural problem: different JSON schemas, different tool names (Claude "Bash" vs Cursor "Shell"), different blocking mechanisms.

**Realistic adapter sizing:**
- Enforcement adapters: ~30-50 lines each (parse tool-specific JSON, normalize tool names, call `ag gate`, format tool-specific response)
- Context adapters: ~80-150 lines each (tool-specific context injection format)
- Total per tool: ~2 adapter files, ~100-200 lines

**Tool name normalization** lives in `ag gate` itself:
```python
TOOL_ALIASES = {"Shell": "Bash", "shell": "Bash", "Read": "Read", ...}
```

4 tools × 2 files × ~150 lines = ~1,200 lines of adapters. Not trivial, but manageable and each adapter is simple.

---

### Cursor Reliability Mitigations (from ChatGPT research)

- **All scripts use `jq` for JSON** — no manual string interpolation
- **Treat `ask` as `deny` operationally** — approvals via `ag approve`, not Cursor's ask flow
- **Fail-closed in scripts** — any error → deny + exit 2
- **Never rely on hook messages as only feedback** — write failures to a known file
- **CI backstop** — `ag verify` in CI regardless of whether hooks fired
- **Do NOT build core flows around Cursor's `followup_message` loops** — unreliable across versions

---

### State: Same Files, No Engine

| File | Purpose | Updated By |
|------|---------|------------|
| `STACK.md` | Config: profile, stack, commands, review settings | Human |
| `STATUS.md` | Current focus, next steps, blockers | `status.sh` |
| `JOURNAL.md` | Session history (outcomes, not files) | `journal.sh` |
| `FEATURES.md` | Feature catalog + state (THE source of truth) | `feature.sh` |
| `BACKLOG.json` | Ordered work queue | `backlog.sh` |
| `CONTEXT_PACK.md` | Architecture map | Human/agent |
| `HUMAN_NEEDED.md` | Items requiring human decision | `blocker.sh` |
| `spec/acceptance/F-XXXX.md` | Acceptance criteria per feature | Agent/human |

No work item directories. No item.yaml. No sync shim. FEATURES.md IS the state.

---

### ag CLI

**Keep (simplified):**
- `ag start` → dashboard
- `ag gate <check> [args]` → policy engine (called by hooks AND by CI)
- `ag verify [F-XXXX]` → full verification (all gate checks, for CI/manual)
- `ag todo` / `ag backlog` → state file operations
- `ag commit` → pre-commit checks + git
- `ag done` → verify ACs, update state, cleanup
- `ag export <tool>` → generate hook configs + instruction files
- `ag auto task/epic/verify/crunch/pipeline` → autonomous execution
- `ag init` → scaffold state files + hooks for new project

**Remove:**
- `ag transition/ship/info/next` (v2 engine commands)
- `ag check` (redundant with `ag verify`)
- TransitionOrchestrator, work items, gate dispatch, features sync
- All of `.agentic/lib/auto/v2/`

---

### Autonomous Execution: Keep, with explicit v2 unwinding

The auto system is orthogonal to enforcement but has v2 dependencies that need clean removal.

**5 files with `is_v2_engine()` calls:**
1. `scheduler.py:644-688` — `_ensure_v2_work_item()`, `_advance_v2_state()` → remove, use `feature.sh` for state advancement
2. `epic.py:340-374` — `_create_v2_work_items()` → remove, keep FEATURES.md-based child creation
3. `kickoff.py:1102-1104` — work item creation during kickoff → remove
4. `verify.py:180-201` — artifact writes to v2 work dirs → remove, verification results stay in test output
5. `state_machine.py` — v2 adapter → remove entire v2 adapter path

All 5 call sites are behind `try/except` or `if is_v2_engine()` guards, so removal is safe — fallback paths already exist and use FEATURES.md + `feature.sh`.

**Migration for existing v2 users:**
- `upgrade.sh` detects `engine: v2` in `state_machine_af.yaml`
- Reads any in-progress items from `.agentic/work/*/item.yaml`
- Ensures their state is reflected in FEATURES.md via `feature.sh`
- Archives `.agentic/work/` → `.agentic/work.archived/`
- Removes `engine: v2` from config

---

## What This Removes

- `.agentic/lib/auto/v2/` — Python state machine engine (~3.2K lines, 14 files)
- `state_machine_af.yaml` — YAML state config
- `.agentic/work/` — work item directories
- `features_sync.py`, `gate_dispatch.py`, `preconditions.py`
- `state_machine.py` v2 adapter path
- v2-specific ag commands and tests
- v2 dependencies in 5 auto system files (behind existing fallbacks)

## What This Adds

- `ag gate` — bash entry point dispatching to simplified Python gate checks
- `.agentic/hooks/{claude,cursor,copilot,gemini}/` — enforcement + context adapters
- `hooks.json` configs per tool (generated by `ag export`)
- `upgrade.sh` v2 → hooks migration support
- Tool name normalization in gate checks

## What This Keeps

- `gates.py` — gate check functions (simplified, v2 deps removed)
- `settings.py` — profile/config reading
- All state files and token-efficient scripts
- All ag commands except v2-specific
- All skills (pure guidance, no hooks in frontmatter)
- Full autonomous execution system (v2 calls removed, fallback paths used)
- Profiles and review settings
- Spec-driven workflow, backlog, journal
- `validate_framework.sh` (updated for hooks)

---

## Implementation Phases

### Phase 1: Stop Gate — Highest Value (~2-3 days)
Agent can't stop until `ag verify` passes. Directly attacks problem #2 (no definition of done).
- Simplify `gates.py`: extract gate checks, remove v2 imports
- Write `ag gate stop` entry point in ag.sh
- Write Claude enforcement adapter for Stop hook
- Wire in `.claude/settings.json`
- Test: implement feature, try to stop before tests pass → blocked
- Test: `ag verify` from command line produces same result

### Phase 2: PreToolUse Enforcement (~3-4 days)
- `ag gate pretool` — block git commit/push without checks, block destructive git, block code without spec
- Active feature resolution (`resolve_active_feature()`)
- Claude enforcement adapter for PreToolUse
- Cursor enforcement adapter for PreToolUse (fail-closed, jq, exit 2)
- Tool name normalization
- Test across Claude + Cursor

### Phase 3: Context Hooks (~2-3 days)
- SessionStart context hook (inject state, detect interrupted work)
- UserPromptSubmit context hook (intent routing, collision checks)
- PreCompact context hook (preserve state)
- Claude + Cursor context adapters
- These are richer scripts, not thin adapters — budget accordingly

### Phase 4: Strip v2 Engine (~3-5 days)
- Remove `.agentic/lib/auto/v2/` entirely
- Remove `is_v2_engine()` calls from 5 auto system files (use existing fallbacks)
- Remove v2 ag commands from ag.sh
- Write migration in `upgrade.sh` for existing v2 users
- Simplify `state_machine.py` (remove v2 adapter, keep v1 feature state queries if still needed by auto system)
- Update `validate_framework.sh`
- Run full auto system smoke test (`ag auto task` with a test feature)

### Phase 5: Cross-Tool Export + CI (~3-4 days)
- `ag export cursor` → .cursor/hooks.json + rules
- `ag export copilot` → .github/hooks/*.json + copilot-instructions.md
- `ag export gemini` → .gemini/settings.json + instruction file
- `ag export codex` → AGENTS.md (degraded, guidance only)
- CI integration: document `ag verify` as merge gate
- Update framework docs (HOW_IT_WORKS, DEVELOPER_GUIDE, MIGRATION_v2)

**Total: ~3-4 weeks** (not 8-12 days — review was right about realistic timeline)

---

## Verification

- Stop gate blocks agent from claiming done without passing checks
- PreToolUse blocks git commit without tests, blocks code without spec (formal mode)
- `ag verify` works identically from hooks, from CLI, and from CI
- `ag auto task` still works end-to-end after v2 removal
- `ag export cursor` generates working Cursor hooks with fail-closed + jq
- Cursor adapters treat `ask` as `deny`, use exit 2
- Context hooks inject state at SessionStart, route intents at UserPromptSubmit
- Migration: project with `engine: v2` upgrades cleanly via `upgrade.sh`
- No Python import errors from removed v2 modules

---

## Key Insights

1. **Two types of hooks**: enforcement (thin adapters → `ag gate`) and context (richer scripts). Don't force both into one model.
2. **`ag gate` = bash entry → Python gate checks**: Don't rewrite structured Python as tangled bash. Keep `gates.py`, strip the orchestration layer around it.
3. **Hooks and skills are separate concerns**: hooks.json for enforcement, skills for guidance. `ag export` generates both.
4. **CI is the backstop**: `ag verify` runs the same checks as hooks. Hooks are guardrails, CI is the hard gate.
5. **Fail-closed everywhere**: if anything errors, deny. Critical for Cursor.
6. **Stop gate is the #1 win**: "can't claim done until verified" directly solves the biggest problem.
7. **Active feature must be resolved**: hooks don't receive feature IDs — `gates.py` reads AGENTS.json/STATUS.md/BACKLOG.json.
8. **Adapters are ~30-150 lines, not 10**: different JSON schemas per tool, different blocking mechanisms. Budget accordingly.
9. **MCP is NOT suitable for enforcement**: LLM must choose to call it. Use only for guidance/optional tooling.
10. **Don't build core flows around Cursor's followup_message**: unreliable across versions.
