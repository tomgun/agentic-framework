# Plan: Make Framework Verification Test Real-World Agent Behavior

## Context

The Autonomous Framework Verification Loop (F-0215) spawns **real** Claude agents and creates **real** projects. But the build prompt (`verify_build.md`) is a **prescriptive recipe** telling agents exactly what commands to run:

```
1. Run `ag kickoff "{vision}"`
2. Run `ag kickoff --approve`
3. Run `ag implement F-XXXX`
...
```

This tests plumbing (commands execute correctly) — but **plumbing is already tested by `validate_framework.sh` (367+ static tests) and `tests/*.py` (unit tests)**. You don't need to spend agent-spawning budget on that.

What **requires** agent spawning is testing the instruction layer: does an agent, given only a user request and the project's instruction files (CLAUDE.md, skills), **discover and follow** the correct workflow? That's the verification loop's unique value — and it's not testing it today.

### What real-world usage looks like (vs what verification tests)

| Step | Real-world | Current verification |
|------|-----------|---------------------|
| 1 | User says "build me a todo app" | Agent given step-by-step recipe |
| 2 | Agent reads CLAUDE.md → finds session-start protocol | Skipped — prompt says what to run |
| 3 | Agent recognizes "build" trigger → runs `ag kickoff` | Prompt says "Run `ag kickoff`" |
| 4 | Agent reads implementing-features skill → follows steps | Prompt says "Follow the framework workflow" |
| 5 | Agent hits plan review gate → spawns Critic + Advocate | `review_plan: skip` bypasses entirely |
| 6 | Agent navigates pre-commit gates → fixes issues | Same (this part works) |

---

## Approach: Discovery-Only for Agent Spawning

Replace the recipe prompt with a discovery prompt. Keep recipe as opt-in fallback for complex scenarios and debugging. When `plan_review_enabled: yes` (formal profiles), exercise the full dialectical review flow.

### Dialectical Review Findings (addressed in this plan)

**Critic raised two "showstoppers":**

1. ~~"`--print` mode can't use Agent tool"~~ — **WRONG.** `--print` mode is non-interactive (no user input) but has full tool access (Bash, Read, Write, Agent). Agents CAN spawn subagents in `--print` mode. This is how all autonomous workflows already work.

2. **"`review_merge: human` blocks autonomous execution"** — **VALID.** `autonomous_formal.review_merge = human` in profiles.conf. Fix: keep `review_merge: skip` in scenario YAML, only remove `review_plan` and `review_commit` overrides from `_write_stack_md()` so profile defaults (`critical_agent`) take effect.

**Advocate suggestions adopted:**
- Behavioral expectations start as `severity: warning` (non-blocking) for initial deployment
- Add `--discovery`/`--recipe` CLI flag for debugging
- `spec_before_code` treats same-commit as passing
- Log prompt tier in run output

---

## Changes Overview

| # | File | Change |
|---|------|--------|
| 1 | `.agentic/lib/auto/prompts/verify_build_discovery.md` | **New** — minimal-guidance prompt |
| 2 | `.agentic/lib/auto/framework_verify.py` | `build_prompt()` → use discovery template by default |
| 3 | `.agentic/lib/auto/framework_verify.py` | `_write_stack_md()` — selective override removal for formal profiles |
| 4 | `.agentic/lib/auto/framework_verify.py` | Add behavioral expectation checkers to `ExpectationChecker` |
| 5 | `.agentic/lib/auto/framework_verify.py` | Add `derive_behavioral_expectations()` |
| 6 | `.agentic/lib/auto/framework_verify.py` | Wire behavioral expectations into `run_scenario()` + pass log |
| 7 | `.agentic/lib/auto/framework_verify.py` | Add `--discovery`/`--recipe` CLI flag |
| 8 | `.agentic/lib/auto/framework_verify.py` | Log `prompt_tier` in `ScenarioRun` / `VerifyResult.to_dict()` |
| 9 | `.agentic/lib/auto/scenarios/todo_app.yaml` | Add `prompt_tier` explicit setting, increase formal timeout |
| 10 | `.agentic/lib/auto/scenarios/cli_tool.yaml` | Same |
| 11 | `.agentic/lib/auto/scenarios/fullstack_monorepo.yaml` | Add `prompt_tier: recipe` (explicit opt-in to old behavior) |
| 12 | `.agentic/lib/auto/scenarios/fullstack_multirepo.yaml` | Same |
| 13 | `tests/test_framework_verify.py` | Unit tests for new checkers |

---

## Step 1: Create Discovery Prompt Template

**New file**: `.agentic/lib/auto/prompts/verify_build_discovery.md`

```markdown
# Build Project

I want you to build the following project. Follow this project's development
workflow as described in the project's instruction files.

## Project Vision

{vision}

## Stack

{stack_description}

## Rules

- Use the project's development workflow — read the project's instruction files to learn it
- Do NOT modify `.agentic/lib/` files — those are the framework source
- Do NOT create files outside the project directory
- If a command fails, read the error output carefully and adjust your approach
```

What the agent should discover from the bootstrapped CLAUDE.md (`.agentic/lib/agents/claude/CLAUDE.md`):
- Session-start protocol (line 7): "Run `bash .agentic/lib/tools/dashboard.sh`"
- Quick commands (lines 11-14): `ag kickoff`, `ag implement`, `ag commit`, `ag done`
- Core rules (lines 16-27): spec-first, tests required, small commits
- Plan review gate (lines 29-45): DRAFT → review → APPROVED flow
- Skills reference (lines 55-57): implementing-features, committing-changes, etc.

## Step 2: Modify `build_prompt()` — Discovery by Default

**File**: `.agentic/lib/auto/framework_verify.py`, function `build_prompt()` (line 949)

- Default `prompt_tier` to `"discovery"` when not specified
- Select template based on tier
- Discovery template uses `{vision}` and `{stack_description}` only (agent discovers profile/workflow from STACK.md)
- Recipe template still uses `{profile}` and `{git_workflow}` as before
- Use `try/except KeyError` for format vars the discovery template doesn't use

## Step 3: Selective Override Removal in `_write_stack_md()`

**File**: `.agentic/lib/auto/framework_verify.py`, function `_write_stack_md()` (line 839)

Current code (lines 862-865):
```python
if profile in ("formal", "autonomous_formal"):
    lines.append("- acceptance_criteria: blocking")
    lines.append("- review_plan: skip")       # ← REMOVE THIS
    lines.append("- review_commit: skip")     # ← REMOVE THIS
```

Change to:
```python
if profile in ("formal", "autonomous_formal"):
    lines.append("- acceptance_criteria: blocking")
    # Let profile defaults take effect for review_plan and review_commit:
    # - autonomous_formal: review_plan=critical_agent, review_commit=critical_agent
    # - formal: review_plan=critical_agent, review_commit=human
    # review_merge stays as specified in scenario YAML (must be "skip" for autonomous)
```

**Why this is safe**: `review_plan: critical_agent` spawns subagents (works in `--print` mode). `review_commit: critical_agent` spawns a review agent (works in `--print` mode). `review_merge` stays `skip` via scenario YAML (line 858 writes it from settings dict).

**Important**: Scenario YAMLs MUST keep `review_merge: skip` for autonomous execution.

## Step 4: Add Behavioral Expectation Checkers

**File**: `.agentic/lib/auto/framework_verify.py`, class `ExpectationChecker` (line 266)

All checkers use **durable artifacts** (git history, framework state files). Each returns a `MilestoneResult`. New checkers are dispatched from `_check_workflow()` via the existing `_wf_{type}()` pattern.

### 4a. `spec_before_code` — ordering check

```python
def _wf_spec_before_code(self, check: dict) -> MilestoneResult:
    """Verify spec artifacts were committed before or with implementation code.

    Uses `git log --reverse --format='%H' --diff-filter=A -- <path>` to find
    when files were first added. Compares commit position of first AC file vs
    first source code file. Same-commit counts as passing.
    """
```

Evidence: `git log --reverse --diff-filter=A` on `.agentic/spec/acceptance/*` vs `app/**/*.py` (or scenario-appropriate globs). Same commit = pass (agent may batch spec+code in discovery profile).

### 4b. `workflow_commands_used` — command discovery evidence

```python
def _wf_workflow_commands_used(self, check: dict) -> MilestoneResult:
    """Check artifacts for evidence a framework command was discovered and used."""
```

Evidence per command:
- `kickoff`: FEATURES.md has `## F-` entries with ID format that `ag kickoff` produces (not just any F-XXXX — check for the structured format with Status/Description fields)
- `implement`: JOURNAL.md has session entries, or `.agentic/journal/plans/` has plan files
- `commit`: git log has conventional commit messages `^(feat|fix|test|chore|docs)\(`
- `done`: FEATURES.md has entries with `shipped` status

### 4c. `session_start_ran` — session protocol evidence

```python
def _wf_session_start_ran(self, check: dict) -> MilestoneResult:
    """Check if agent ran the session-start protocol."""
```

Evidence: JOURNAL.md has a `### Session:` entry (dashboard.sh/session-start adds one), OR STATUS.md has content beyond the default template. Note: `dashboard.sh` is read-only (displays info), but the session-start skill triggers `status.sh focus` which writes to STATUS.md.

### 4d. `plans_reviewed` — dialectical review evidence

```python
def _wf_plans_reviewed(self, check: dict) -> MilestoneResult:
    """Check that plan files show evidence of review (DRAFT → APPROVED transition)."""
```

Evidence: `.agentic/journal/plans/F-*-plan.md` files exist AND contain `**Status**: APPROVED`. For stronger signal: check git log for the plan file showing multiple commits (DRAFT creation, then APPROVED update).

### 4e. `instruction_files_consulted` — log-based supplementary check

```python
def _wf_instruction_files_consulted(self, check: dict) -> MilestoneResult:
    """Grep agent log for evidence of reading instruction files. Supplementary only."""
```

Grep `self.agent_log` for file paths like `CLAUDE.md`, `skills/`, `auto_orchestration.md`. This is fragile (log format varies) — used only as supplementary signal, never as sole evidence.

## Step 5: Add `derive_behavioral_expectations()`

**File**: `.agentic/lib/auto/framework_verify.py`, after `derive_workflow_expectations()` (line 597)

```python
def derive_behavioral_expectations(project_root: Path, prompt_tier: str) -> list[dict]:
    """Derive behavioral expectations for discovery-mode verification.

    Returns empty list for recipe mode — behavioral compliance is meaningless
    when the agent is told what to do.
    """
    if prompt_tier == "recipe":
        return []

    import settings as _settings
    _settings._cache.clear()

    checks = [
        {"type": "spec_before_code", "severity": "warning"},
        {"type": "session_start_ran", "severity": "warning"},
        {"type": "workflow_commands_used", "command": "kickoff",
         "evidence": "features_md_format", "severity": "warning"},
        {"type": "workflow_commands_used", "command": "commit",
         "evidence": "conventional_commits", "severity": "warning"},
    ]

    if _settings.get_setting(project_root, "plan_review_enabled", "no") == "yes":
        checks.append({"type": "plans_reviewed", "severity": "warning"})

    return checks
```

**Severity model**: All behavioral checks start as `severity: warning`. They are reported in results but do NOT trigger the self-heal loop or count as scenario failures. This prevents the `SelfHealEngine` from misclassifying "agent didn't discover workflow" as a framework bug. Once confidence builds, individual checks can be promoted to `severity: blocking`.

## Step 6: Wire Into `run_scenario()` and Pass Agent Log

In `run_scenario()`, after the build agent finishes and before running expectation checks:

1. Read `prompt_tier` from settings (default: `"discovery"`)
2. Call `derive_behavioral_expectations(project_root, prompt_tier)`
3. Add results as a separate `behavioral_results` list in `ScenarioRun`
4. Pass agent log path to `ExpectationChecker`

```python
# Extend ExpectationChecker constructor
class ExpectationChecker:
    def __init__(self, project_root: Path, agent_log: Path | None = None):
        self.root = project_root
        self.agent_log = agent_log
```

Add `check_behavioral()` method (separate from `check_all()`) so behavioral checks don't pollute the main pass/fail determination:

```python
def check_behavioral(self, expectations: list[dict]) -> list[MilestoneResult]:
    """Run behavioral expectations. Results are advisory (severity: warning)."""
    results = []
    for check in expectations:
        method = getattr(self, f"_wf_{check['type']}", None)
        if method:
            results.append(method(check))
    return results
```

## Step 7: Add CLI Flag

**File**: `.agentic/lib/auto/framework_verify.py`, in `main()` argparse section

Add `--prompt-tier` flag:
```python
parser.add_argument("--prompt-tier", choices=["discovery", "recipe"], default=None,
                    help="Override prompt tier for all scenarios (default: per-scenario)")
```

When set, this overrides `prompt_tier` in all settings matrix entries. Useful for debugging:
```bash
ag auto verify-framework --project todo-app --prompt-tier recipe  # isolate plumbing
ag auto verify-framework --project todo-app --prompt-tier discovery  # test instructions
```

## Step 8: Log Prompt Tier in Output

**File**: `.agentic/lib/auto/framework_verify.py`

Add `prompt_tier: str = "discovery"` to `ScenarioRun` dataclass (line 63). Include in `to_dict()` output so `--json` mode shows which tier each run used.

## Step 9: Update Scenario YAMLs

**`todo_app.yaml`**:
```yaml
settings_matrix:
  - profile: discovery
    git_workflow: direct
    docs_mode: deferred
    # prompt_tier defaults to "discovery"

  - profile: autonomous_formal
    git_workflow: pull_request
    review_merge: skip            # KEEP — no human for merge review in autonomous
    timeout_override: 7200        # 2hrs — plan review + subagents need more time
    # prompt_tier defaults to "discovery"
    # review_plan and review_commit use profile defaults (critical_agent)
```

**`cli_tool.yaml`**: Same pattern.

**`fullstack_monorepo.yaml`** and **`fullstack_multirepo.yaml`**: Add explicit `prompt_tier: recipe` — these test complex plumbing that's already hard enough:
```yaml
settings_matrix:
  - profile: discovery
    git_workflow: direct
    prompt_tier: recipe

  - profile: autonomous_formal
    git_workflow: pull_request
    review_merge: skip
    prompt_tier: recipe
```

**`api_service.yaml`**: Keep recipe for now (TypeScript scenario, can graduate later).

## Step 10: Handle `timeout_override` in `run_scenario()`

**File**: `.agentic/lib/auto/framework_verify.py`, in `run_scenario()` (~line 1134)

Currently reads `scenario.get("timeout", 600)`. Add per-settings-entry override:
```python
timeout = settings.get("timeout_override") or scenario.get("timeout", 600)
timeout = int(timeout)
```

## Step 11: Unit Tests

**File**: `tests/test_framework_verify.py`

Add tests for:
1. `build_prompt()` uses discovery template by default, recipe when `prompt_tier: recipe`
2. `_wf_spec_before_code()` — create temp git repo with:
   - AC before code → pass
   - Code before AC → fail
   - Same commit → pass
3. `_wf_workflow_commands_used()` — with/without matching FEATURES.md format
4. `_wf_session_start_ran()` — with/without STATUS.md content
5. `_wf_plans_reviewed()` — with DRAFT vs APPROVED plan files
6. `derive_behavioral_expectations()` — returns `[]` for recipe, populated for discovery, adds `plans_reviewed` for formal
7. `timeout_override` handling
8. `--prompt-tier` CLI flag overrides per-scenario settings

---

## Verification

1. **Unit tests**: `python3 -m pytest tests/test_framework_verify.py -x -q`
2. **Validate framework**: `bash tests/validate_framework.sh`
3. **Dry-run**: Load scenarios, verify prompt generation uses discovery template by default
4. **Full E2E** (expensive): `ag auto verify-framework --project todo-app`
   - Discovery profile entry: agent should discover `ag kickoff` etc. from CLAUDE.md
   - Formal profile entry: agent should exercise dialectical plan review
   - Check behavioral results in JSON output (advisory warnings)

## Key Design Decisions

1. **Discovery-only for agent spawning** — recipe tests plumbing, which static tests cover. Agent spawns should test instruction discovery.
2. **Artifact-based behavioral checks** — git history and framework state are durable. Agent logs are fragile (supplementary only).
3. **Severity: warning for initial deployment** — behavioral checks don't trigger self-heal or fail scenarios. Promotes to blocking once stable.
4. **Selective override removal** — remove `review_plan: skip` and `review_commit: skip` from `_write_stack_md()`, keep `review_merge: skip` in YAML (no human available).
5. **Complex scenarios stay recipe** — monorepo/multirepo opt into `prompt_tier: recipe` explicitly. Graduate to discovery once simple scenarios stabilize.
6. **Old recipe prompt kept** — not deleted, available via `prompt_tier: recipe` or `--prompt-tier recipe` CLI flag.
