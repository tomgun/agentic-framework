# Plan: Lifecycle Triggers + Auto-Generated Project Agents

## CRITICAL DESIGN PRINCIPLE: LLM-Optimized Format

**All generated output — instructions, skills, subagents, project patterns — MUST be in LLM-optimized format.** This means:

- **Dense, scannable structure** — bullet points, tables, and structured sections over prose paragraphs
- **Action-oriented** — "Do X" not "You should consider doing X"
- **Token-efficient** — every token must earn its place; no filler, no hedging, no repetition
- **Concrete over abstract** — real file paths, real commands, real code patterns from THIS project
- **Front-loaded** — most important information first (LLMs lose attention in the middle of long contexts)
- **Declarative rules over explanations** — "Use functional components" not "React best practices recommend using functional components because..."
- **Scripts over language for critical steps** — language is ambiguous, code isn't. If something MUST happen correctly, encode it as a runnable command, not a prose instruction. "Validate the data before proceeding" is bad. "`run python scripts/validate.py --input {file}`, if it fails: missing fields → add to csv, bad dates → use yyyy-mm-dd" is good. The more critical the step, the more it should look like executable code with explicit error handling, not a suggestion.

This applies to:
- Generated `subagents-project/*.md` files
- Generated `.claude/skills/*/SKILL.md` content
- Project patterns sections injected into instruction files (Cursor, Copilot, etc.)
- The specialization rules themselves (`.conf` files are for machines; the output they produce is for LLMs)
- Layer B (LLM synthesis) output — the skill that generates agents must itself produce LLM-optimized content

The framework already follows this principle in hand-authored content (CLAUDE.md is ~40 lines of dense trigger tables, not explanatory prose). Generated content must match or exceed this standard.

---

## Context

Two related gaps surfaced from the orphaned-plans incident (T-0015, T-0016):

**A) No unified lifecycle trigger mechanism.** The framework has ~5 ad-hoc trigger patterns (sync.sh phases, retro_check.sh intervals, docs.sh events, session_start checklist, CLAUDE.md keyword matching) — each with different config formats, state tracking, and invocation patterns. Some checks should run every session, others less often (every N commits, every N days). Currently there's no way to express "run X periodically" without hardcoding it into a specific script.

**B) No auto-generated project-specific agents/skills.** The framework ships 29 generic subagents that work for any project but aren't optimized for any. A React project gets the same agents as a FastAPI project. `suggest-agents.sh` detects tech stacks and suggests agents, but doesn't generate them. The user wants the framework to automatically create specialized agents — at init with basic detection, and later when architecture stabilizes with deeper LLM-synthesized content.

These connect: "regenerate project agents" is itself a lifecycle trigger (run after N features ship, or when STACK.md changes).

---

## Feature A: Periodic Check System in sync.sh

### Approach: Extend sync.sh with frequency-gated phases

Rather than building a separate trigger engine, extend the existing sync.sh with:
1. A **state file** tracking when each check last ran
2. A **frequency evaluator** that gates checks by sessions/commits/days
3. New phases that only fire when their frequency condition is met

This is minimal — sync.sh already runs at every `ag start`, already has phases, already has --quiet mode. We just add frequency gating.

### State file: `.agentic-state/sync-state.conf`

Flat key=value format matching the existing `profiles.conf` convention — no `jq` dependency, parseable with the same grep/sed patterns the framework uses everywhere.

```
# Sync state (auto-maintained by sync.sh)
last_sync=2026-03-01
session_count=42
orphaned_plans.last_run=2026-02-28
orphaned_plans.last_session=41
retro_check.last_run=2026-02-20
retro_check.last_session=35
agent_freshness.last_run=2026-02-15
agent_freshness.last_session=30
```

### Frequency config: STACK.md `## Settings`

```
- periodic_orphaned_plans: every_session     # default: every_session
- periodic_retro_check: every_5_sessions     # default: every_5_sessions
- periodic_agent_refresh: every_20_sessions  # default: every_20_sessions (Feature B)
```

Profiles set sensible defaults in `profiles.conf`:
- Discovery: retro off, orphaned plans every session, agent refresh off
- Formal: all enabled at default intervals

### Implementation

**File: `.agentic/tools/periodic-checks.sh`** — New file, called by sync.sh as one phase. Keeps sync.sh from growing past 700 lines. Contains:
- `load_sync_state()` / `save_sync_state()` — read/write `.agentic-state/sync-state.conf` (flat key=value, grep/sed parsing)
- `should_run_check(check_name)` — evaluates frequency from STACK.md setting vs state
- `increment_session_count()` — bumps counter on each run
- `check_orphaned_plans()` — scans `~/.claude/plans/` for project-relevant files not in `.agentic-journal/plans/`
- `check_retro_due()` — wraps existing `retro_check.sh` logic with frequency gating

**File: `.agentic/tools/sync.sh`** — Add:
- Phase 7: calls `periodic-checks.sh` (replaces ad-hoc retro check in session_start.md)

**File: `.agentic/presets/profiles.conf`** — Add periodic check defaults per profile.

**File: `STACK.template.md`** — Add periodic settings to `## Settings` section with comments.

**Orphaned plan detection logic** (in periodic-checks.sh):

Two-pronged approach — prevention + catch-up:

*Prevention* (structural, in `ag implement`): Before starting implementation, check that a plan exists in `.agentic-journal/plans/`. If missing, prompt: "No saved plan found — save the current plan to .agentic-journal/plans/?" This is T-0015.

*Catch-up detection* (in periodic-checks.sh, this feature):
1. Compute a project fingerprint: `git remote get-url origin 2>/dev/null || basename $(pwd)` — stored in sync-state.conf on first run
2. Extract feature IDs from `spec/FEATURES.md` if it exists (grep `F-[0-9]+`)
3. Scan `~/.claude/plans/*.md` modified since last `ag start` (use sync-state.conf `last_sync` date)
4. For each file, grep for the project fingerprint OR project feature IDs
5. Compare matches against `.agentic-journal/plans/` filenames
6. Report orphans: "Found 2 unsaved plans in ~/.claude/plans/ — run `ag sync` to review"

Edge cases:
- If `~/.claude/plans/` doesn't exist → skip silently
- If `spec/FEATURES.md` doesn't exist (Discovery profile) → match on fingerprint only
- False positives are low-risk: sync only reports, doesn't auto-copy

### Files changed (Feature A)

| File | Change |
|------|--------|
| `.agentic/tools/periodic-checks.sh` | **New** — frequency-gated checks (orphaned plans, retro, etc.) |
| `.agentic/tools/sync.sh` | Add Phase 7 calling periodic-checks.sh |
| `.agentic/presets/profiles.conf` | Add periodic_* defaults |
| `.agentic/init/STACK.template.md` | Add periodic settings to ## Settings |
| `.agentic/checklists/session_start.md` | Remove ad-hoc retro check (now in sync) |
| `tests/test_periodic_checks.sh` | **New** — automated tests for state/frequency/detection |

---

## Feature B: Auto-Generated Project Agents & Skills

### Approach: Two layers, shipped in phases

**Layer A (template-based, no LLM):** Extend `suggest-agents.sh` → `generate-project-agents.sh` that uses tech stack detection + specialization rules to produce project-specific agent definitions. Deterministic, fast, free.

**Layer B (LLM-synthesized, later phase):** Agent reads actual code samples and generates deeply specialized agents. Expensive, high-value, runs on-demand after architecture stabilizes.

### Where generated agents live

```
.agentic/agents/claude/subagents/              # Framework generic (read-only)
.agentic/agents/claude/subagents-project/      # Project-specific (git-tracked, generated)
.claude/skills/                                # Merged output (generic + project)
```

- Framework agents stay untouched — upgrades never conflict
- Project agents in `subagents-project/` are git-tracked (team gets them)
- `generate-skills.sh` processes both dirs, project takes precedence
- Generated files get `<!-- AUTO-GENERATED -->` header; human-edited files get `<!-- CUSTOMIZED -->` to block regeneration

### Specialization rules: `.agentic/agents/specialization/` (one file per stack)

Flat per-stack config files (not nested YAML) — parseable with the same grep/sed the framework uses everywhere. One file per detected tech stack:

**`.agentic/agents/specialization/react.conf`**:
```
# React specialization rules
detect=next.config.js,next.config.mjs,package.json:react

# implementation-agent overrides
implementation.purpose_suffix=for React/TypeScript applications
implementation.instructions=Use functional components with hooks (not class components);Follow project component patterns from src/components/
implementation.key_dirs=src/components/,src/hooks/

# test-agent overrides
test.instructions=Use React Testing Library (not Enzyme);Test behavior, not implementation
```

**`.agentic/agents/specialization/fastapi.conf`**:
```
detect=requirements.txt:fastapi,pyproject.toml:fastapi

implementation.purpose_suffix=for FastAPI/Python applications
implementation.instructions=Use Pydantic models for validation;Use dependency injection for DB sessions
implementation.key_dirs=app/routers/,app/models/

test.instructions=Use httpx AsyncClient for API tests;Use conftest.py for shared fixtures
```

Ship with 5 stacks initially: `react.conf`, `fastapi.conf`, `django.conf`, `go.conf`, `godot.conf` — extending detection patterns already in `suggest-agents.sh`.

### Generation pipeline

1. **Input**: STACK.md + discover.py output (if available) + specialization `.conf` files
2. **Match**: Find matching stack rules from detection patterns
3. **For each matched agent**: Take generic `subagents/{name}-agent.md`, apply specialization (append instructions, add key_dirs, modify purpose)
4. **Output**: Write to `subagents-project/{name}-agent.md` with AUTO-GENERATED header
5. **Skills**: Run `generate-skills.sh` which now also processes `subagents-project/`

**Output format requirement**: All generated agent/skill content must follow the LLM-optimized format principle (see top of plan). The generation script must produce dense, action-oriented, token-efficient content — not generic boilerplate. Example:

```markdown
## Project-Specific Rules
- Components: functional + hooks, NO class components
- State: Zustand stores in src/stores/ (not Redux, not Context)
- Tests: React Testing Library + vitest, test files colocated as *.test.tsx
- Styling: Tailwind utility classes, NO CSS modules
- API calls: src/api/ with tanstack-query hooks
```

NOT:
```markdown
## Guidelines
This project uses React with functional components. You should prefer hooks over class components.
For state management, the project has chosen Zustand. Tests should be written using React Testing Library.
```

### Layer B: LLM synthesis via dedicated skill

Layer B is inherently an LLM task — reading code, understanding patterns, generating specialized content. This ships as a **Claude Code skill** (e.g., `agent-generator` in `.claude/skills/agent-generator/SKILL.md`) and is also available as `ag agents synthesize`.

The skill:
1. Runs discover.py for current state
2. Samples 3-5 representative source files per architectural layer
3. Reads existing project-specific agent (from Layer A, or generic if none)
4. Generates a deeply specialized agent definition in **LLM-optimized format**: dense project-specific rules, concrete file paths, real code patterns extracted from the codebase — not generic advice
5. Writes output with `<!-- LLM-SYNTHESIZED -->` marker
6. User reviews before committing

The skill's own prompt must emphasize: "Output must be dense, scannable, action-oriented. Every line is a directive. No filler. Use the project's actual file paths, naming conventions, and patterns — not generic advice."

This is a "suggest then approve" flow — `--dry-run` shows what would change, default writes files with PROPOSAL markers, `ag agents approve` strips markers.

The skill is hand-authored (not generated) since it's a framework capability, not project-specific. It lives in `.agentic/agents/claude/subagents/agent-generator-agent.md` and gets converted to a skill by `generate-skills.sh` like all other subagents.

### Multi-tool output: adapters per AI tool

The specialization rules and project analysis are **tool-agnostic**. The output format varies by tool:

| Tool | Has agent/skill system? | Output format |
|------|------------------------|---------------|
| Claude Code | Yes — `.claude/skills/` | Full skills via `generate-skills.sh` (already works) |
| Cursor | Yes — `.cursor/rules/*.mdc` + `.cursor/agents/` | Generate `.mdc` rule files with project-specific patterns |
| Copilot | No — single instruction file | Inject project patterns section into `.github/copilot-instructions.md` |
| Codex | No — single instruction file | Inject project patterns section into `.codex/instructions.md` |
| Gemini | No — single instruction file | Inject project patterns section into instruction file |

**For Claude + Cursor** (tools with agent systems):
- `generate-project-agents.sh` produces tool-agnostic agent definitions in `subagents-project/`
- `generate-skills.sh` converts to Claude skills (already exists, just extend)
- New: `generate-cursor-rules.sh` converts to `.cursor/rules/*.mdc` files (follows existing pattern in `setup-agent.sh cursor-agents`)

**For Copilot/Codex/Gemini** (instruction-file-only tools):
- `generate-project-agents.sh` also emits a **project patterns section** (markdown block with key conventions, file locations, test patterns)
- `setup-agent.sh` already creates instruction files for each tool — extend it to inject this patterns section between existing markers: `<!-- PROJECT-PATTERNS-START -->` / `<!-- PROJECT-PATTERNS-END -->`
- On regeneration, only the content between markers is replaced

This means `ag agents generate` produces output for ALL configured tools in one go.

### Integration points

- **Init**: After discover.py runs → `generate-project-agents.sh` (Layer A only)
- **On demand**: `ag agents generate` (Layer A) / `ag agents synthesize` (Layer B)
- **Lifecycle trigger** (Feature A): `periodic_agent_refresh: every_20_sessions` suggests regeneration when project has evolved
- **Stack change**: When `ag set` modifies STACK.md language/framework settings, suggest re-running `ag agents generate`

### Files changed (Feature B — F-YYYY, Claude Code only)

| File | Change |
|------|--------|
| `.agentic/tools/generate-project-agents.sh` | **New** — Layer A generation script |
| `.agentic/agents/specialization/*.conf` | **New** — per-stack flat config files (5 stacks) |
| `.agentic/tools/generate-skills.sh` | Process `subagents-project/` too |
| `.agentic/tools/ag.sh` | Add `ag agents generate` subcommand |
| `.agentic/init/scaffold.sh` or `init_playbook.md` | Hook Layer A after discovery |
| `.agentic/tools/suggest-agents.sh` | Deprecate → redirect to `ag agents generate` |
| `tests/test_generate_project_agents.sh` | **New** — automated tests |

---

## Implementation Order — Three Features

### F-XXXX: Periodic Check System (lifecycle triggers)

**Batch 1: Orphaned plan detection (T-0016) — 3 files**
Solve the immediate problem. Add Phase 7 to sync.sh.
- sync.sh: add `phase_orphaned_plans()`
- sync.sh: ensure it runs in --quiet mode
- Light state tracking (just for this phase, keep it simple)

**Batch 2: Frequency-gated periodic checks — 4 files**
Generalize: add sync state file, frequency evaluator, migrate retro_check into sync.
- sync.sh: add state file + `should_run_check()`
- profiles.conf + STACK.template.md: periodic settings
- session_start.md: remove ad-hoc retro check

### F-YYYY: Project-Specific Agent Generation (Layer A, Claude Code first)

**Batch 3: Core generation pipeline — 4 files**
- `.agentic/agents/specialization/*.conf` (5 stacks: react, fastapi, django, go, godot)
- `.agentic/tools/generate-project-agents.sh` (detects stack → applies rules → outputs to subagents-project/)
- `.agentic/tools/generate-skills.sh`: also process `subagents-project/` (project skills take precedence)
- `.agentic/tools/ag.sh`: add `ag agents generate` subcommand (just generate — add list/diff later if needed)

**Batch 4: Init integration + lifecycle hook — 3 files**
- Hook generation into init flow (after discover.py runs)
- Add `periodic_agent_refresh` check in periodic-checks.sh (depends on F-XXXX)
- Deprecate suggest-agents.sh → redirect to `ag agents generate`

### F-AAAA: Multi-Tool Project Agent Output (deferred, after F-YYYY validated)

Ships after the Claude-only pipeline is proven. Adds:
- Cursor: `.cursor/rules/*.mdc` generation from project agents
- Copilot/Codex/Gemini: inject project patterns section into instruction files
- `ag agents generate` dispatches to all configured tool adapters

### F-ZZZZ: LLM-Synthesized Agents (Layer B, future feature)

**Batch 6: Skill + synthesis pipeline — 4 files**
- agent-generator-agent.md (subagent definition → becomes Claude skill)
- `ag agents synthesize` command in ag.sh
- Approval flow (PROPOSAL markers, `ag agents approve`)
- Code sampling logic + structured LLM prompts

---

## Verification

**F-XXXX (Periodic checks):**
- `ag start` should surface orphaned plans in sync probe
- Manually create a test plan in `~/.claude/plans/` with a project feature ID → verify sync detects it
- Verify frequency gating: set `periodic_retro_check: every_5_sessions`, run ag start 4 times → retro check should not fire, 5th time it should
- Edge case: `~/.claude/plans/` doesn't exist → no error
- Edge case: Discovery profile (no FEATURES.md) → falls back to fingerprint-only matching
- Automated test: add `test_periodic_checks.sh` covering state file read/write, frequency evaluation, session counter
- `bash tests/validate_framework.sh` passes

**F-YYYY (Project agents):**
- Create a test project with React stack → `ag agents generate` produces project-specific implementation + test agents
- Generated agents are in `subagents-project/`, not in `subagents/`
- `generate-skills.sh` produces skills that include project-specific content
- Edit a generated agent, add `<!-- CUSTOMIZED -->` → re-run generate → that file is skipped
- Edge case: stack matches multiple rules (React + TypeScript) → both apply, no conflict
- Automated test: add `test_generate_project_agents.sh` covering detection, rule application, skill generation, CUSTOMIZED guard
- `bash tests/validate_framework.sh` passes
