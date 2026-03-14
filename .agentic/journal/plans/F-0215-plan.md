**Status**: APPROVED

# F-0215: Autonomous Framework Verification Loop

## Context

The framework has extensive unit tests (30+ files), LLM behavioral tests (60+), and structural validation (`validate_framework.sh`, 4889 lines). But none of these test the framework *as a user experiences it* — building a real project end-to-end using `ag kickoff`, `ag implement`, `ag commit`, etc. Behavioral gaps that unit/LLM tests miss only surface when a human uses the framework on a real project.

This feature makes the framework test itself by spawning agents that build example projects from scratch. When the agent hits a framework bug, the system auto-fixes the framework, restarts from scratch, and repeats until the full lifecycle completes clean. All accumulated fixes are delivered as a single PR.

The framework also has shipped multi-component infrastructure (F-0179 component registry, F-0187 multi-repo umbrella, F-0186 component-scoped scheduling, F-0204 integration verification) that has never been exercised end-to-end by an agent. This feature must include multi-component scenarios to verify that monorepo and multi-repo workflows actually work.

Entry point: `ag auto verify-framework --project todo-app` (single scenario) or `ag auto verify-framework --all` (full matrix)

## Approach

### Two-Context Architecture

The verification needs two separate git contexts:

1. **Verification Worktree (VW)**: A worktree of the framework repo on an ephemeral branch (`verify/run-{timestamp}`). Framework fixes are committed here. This IS the framework source code.

2. **Example Project Directory**: A fresh temp directory (`/tmp/ag-verify-{scenario}-{timestamp}/`). Framework installed by copying `.agentic/` from the VW. Wiped entirely on restart. Has its own `git init` — completely independent from the framework repo.

This cleanly separates concerns:
- Framework code accumulates fixes in VW (proper git history)
- Example project is ephemeral (rebuilt from scratch each cycle)
- No risk of polluting framework repo with example project files

### Initialization Sequence

Strict ordering to avoid race conditions:

1. **Pre-flight checks** (see below) — BEFORE any resource creation
2. **VW creation** (`git worktree add -b verify/run-{timestamp}`)
3. **Scenario loop** — creates example projects per iteration

This ensures the concurrent-run detection (`git branch --list 'verify/run-*'`) runs before the current VW branch exists.

### Pre-Flight Checks

Before any scenario runs, `framework_verify.py` performs upfront validation:

1. **Claude availability**: `subprocess.run(["claude", "--version"])` — fail fast if not installed.
2. **Not on main**: Refuse if `git branch --show-current` returns `main` or `master`.
3. **No concurrent verify runs**: Check for existing `verify/run-*` branches via `git branch --list 'verify/run-*'`. If found, refuse with message showing the existing branch.
4. **Clean AGENTS.json**: Check for active WIP entries via `agents_helpers.py list`. Warn (not block) if entries exist.

### Environment Propagation

The `AG_TRUNK_BRANCH` env var must reach all spawned subprocesses. The propagation chain:

1. `framework_verify.py` sets `os.environ["AG_TRUNK_BRANCH"] = branch_name` **before** calling `spawn_claude()`.
2. `spawn_claude()` uses `subprocess.run()` without explicit `env=` argument → inherits parent's `os.environ`.
3. The spawned Claude process runs `ag` bash commands → bash inherits the process environment.
4. `ag.sh` and other bash scripts read `${AG_TRUNK_BRANCH:-}` for trunk detection.

This chain is verified in Phase 1 integration test: set env var, call `spawn_claude()` with a script that runs `echo $AG_TRUNK_BRANCH` via a bash tool call, assert the value arrives through the full chain.

### `spawn_claude()` API Change

The current `spawn_claude()` returns `str` (stdout+stderr concatenated), discarding the exit code. This feature needs the exit code for milestone detection.

**Change**: `spawn_claude()` returns a `SpawnResult` that subclasses `str`:

```python
class SpawnResult(str):
    """Result from spawn_claude() — behaves as str for backward compat, adds metadata."""
    returncode: int
    timed_out: bool

    def __new__(cls, output: str, returncode: int = 0, timed_out: bool = False):
        instance = super().__new__(cls, output)
        instance.returncode = returncode
        instance.timed_out = timed_out
        return instance
```

By subclassing `str`, all existing callers work without changes — `output.upper()`, `output[:200]`, `output.startswith()`, `"word" in output` all work directly on the string value. New code accesses `.returncode` and `.timed_out` as attributes.

**Timeout behavior**: When `TimeoutExpired` is caught, `SpawnResult` is created with:
- `output`: the timeout error message string
- `returncode = -1` (process was killed, not a clean exit)
- `timed_out = True`

**Error behavior**: For `FileNotFoundError` and other exceptions:
- `output`: the error message string
- `returncode = -1`
- `timed_out = False`

### Example Project Setup

Each example project needs these beyond `.agentic/`:

1. **`.claude/settings.json`** with `{"_tier": 1}` — enables `--dangerously-skip-permissions` so the build agent runs non-interactively. Without this, `spawn_claude()` runs in interactive mode and hangs (no stdin with `capture_output=True`).

2. **`git init` + initial commit** — the framework's tooling expects a git repo. Multi-repo scenarios need `git init` + initial commit in EACH component directory.

The setup function in `framework_verify.py`:
```python
def setup_project(scenario, vw_path, project_dir):
    shutil.copytree(vw_path / ".agentic", project_dir / ".agentic")
    (project_dir / ".claude").mkdir(exist_ok=True)
    (project_dir / ".claude" / "settings.json").write_text('{"_tier": 1}')
    subprocess.run(["git", "init"], cwd=project_dir, check=True)
    subprocess.run(["git", "add", "."], cwd=project_dir, check=True)
    subprocess.run(["git", "commit", "-m", "init"], cwd=project_dir, check=True)
```

**Multi-repo setup ordering** (critical — `umbrella.py` checks `.git` existence):
1. Create ALL component temp directories
2. `git init` + initial commit in EACH component directory
3. THEN write STACK.md with resolved absolute paths (not `repo: local`)
4. This ensures `umbrella.py:resolve_umbrella()` finds `.git` directories when it validates

The `project_root` passed to `spawn_claude()` is the example project directory (not the VW), so tier detection reads `.claude/settings.json` from the correct location.

**VW also needs `.claude/settings.json`**: The fix agent is spawned with the VW as `project_root`. The VW must also have `{"_tier": 1}` in `.claude/settings.json` for non-interactive execution. The VW setup function creates this after `git worktree add`.

### Core Loop

```
pre_flight_checks()                         # 1. Fail fast (BEFORE VW creation)
create_vw()                                 # 2. Create verification worktree

for each scenario (selected by --project or --all):
  for each settings combo in scenario.settings_matrix:
    retry_count = 0
    while retry_count < max_retries:
      1. Clean up any prior AGENTS.json entries for this scenario
      2. Create fresh example project dir(s) via setup_project()
         - Single-component: one dir
         - Monorepo: one dir with packages/ structure
         - Multi-repo: create ALL component dirs + git init FIRST, then write STACK.md
      3. Write STACK.md with settings combo + Components table (if multi-component)
      4. Spawn Claude to build project using ag commands (timeout from scenario YAML)
      5. Check milestones (see Milestone Detection below)
      6. If ALL milestones met → SUCCESS → next combo
      7. If FAILURE → classify (framework_bug vs agent_error)
         - framework_bug → spawn fix agent in VW → validate_framework.sh in VW → commit fix → restart
         - agent_error → retry from scratch (fresh Claude context)
         - external → skip with warning
      retry_count++
    if exhausted → report, continue to next scenario
  if total_fixes >= max_total_fixes → STOP, create PR with partial results
```

### Milestone Detection

Each `required_milestone` maps to a concrete check. The orchestrator inspects the project state after the build agent completes (or fails):

| Milestone | Detection Method |
|-----------|-----------------|
| `kickoff_complete` | File exists: `.agentic/spec/FEATURES.md` with at least one `F-` entry |
| `features_specced` | At least one file in `.agentic/spec/acceptance/F-*.md` |
| `component_features_scoped` | At least one feature in FEATURES.md contains `**Component**:` field |
| `contracts_defined` | STACK.md contains `## Contracts` section |
| `implementation_done` | At least one non-spec commit on the project's branch (git log check) |
| `contracts_validated` | Orchestrator calls `load_registry(project_root)` then `validate_contracts(project_root, registry)`. Pass = `len(results) > 0 and all(not r.warnings for r in results)`. |
| `integration_verified` | File exists: `.agentic/journal/verify-epic-*.md` |
| `verification_green` | `SpawnResult.timed_out == False` AND `SpawnResult.returncode == 0` |

Implementation: A `MilestoneChecker` class with a method per milestone type. Each method takes the project root path and `SpawnResult`, returns `(passed: bool, detail: str)`.

**Note on `contracts_validated`**: The orchestrator imports `umbrella.load_registry()` and `umbrella.validate_contracts()` and calls them directly on the example project's root. This reuses the framework's own validation code — no log file parsing. The two-call sequence is: `registry = load_registry(project_root)` then `results = validate_contracts(project_root, registry)`.

**Note on `verification_green`**: Simplified to exit code + timeout check only. No stdout string matching (too many false negatives from normal Claude output containing "error:").

### Multi-Component Scenarios

The framework has shipped multi-component support that needs end-to-end verification:

**Monorepo scenario** (`fullstack-monorepo`): Frontend + backend + shared lib in one repo.
- STACK.md `## Components` table with 3 entries (path-based, no Repo column)
- Uses `components.py:load_registry()` + `auto_detect_components()`
- Features scoped to components via `**Component**:` field
- Epic with children spanning components → exercises `integration_verify.py`
- Verifies: component-scoped test commands, `context-for-role.sh --component`, scheduler scoping

**Multi-repo scenario** (`fullstack-multirepo`): Umbrella repo + separate component repos.
- STACK.md `## Components` table with Repo column for external repos
- Uses `umbrella.py:resolve_umbrella()` for cross-repo path resolution
- `## Contracts` section declaring interface between components (OpenAPI)
- Verifies: `validate_contracts()`, cross-repo scheduling, umbrella resolution
- Creates separate git repos in `/tmp/` for each component + umbrella — **each must have `git init` + initial commit** for `umbrella.py`'s `.git` directory checks to pass
- Multi-repo YAML uses `repo: local` as sentinel. Setup code translates this to the actual temp directory absolute path before writing STACK.md Components table (so `umbrella.py` sees real paths, not the literal string "local").

**What these scenarios exercise that unit tests don't:**
- Real `ag kickoff` with multi-component vision → does it generate per-component features?
- Real `ag auto epic` with component-scoped children → does scheduler route correctly?
- Real integration verification across components → do cross-component tests actually run?
- Real contract validation → does `ag` warn when contracts break between components?

### Trunk Branch Configurability (Prerequisite)

5 scripts hardcode `main`/`master`. Each gets a change to check the env var first:

**For bash scripts using string comparison** (state-commit.sh, wip.sh, ag.sh):
```bash
TRUNK="${AG_TRUNK_BRANCH:-}"
if [[ -z "$TRUNK" ]]; then
    # Auto-detect (existing logic unchanged)
fi
```

**For bash scripts using `show-ref --verify`** (manifest.sh):
```bash
TRUNK="${AG_TRUNK_BRANCH:-}"
if [[ -n "$TRUNK" ]]; then
    BASE_BRANCH="$TRUNK"
elif git show-ref --verify --quiet refs/heads/main 2>/dev/null; then
    BASE_BRANCH="main"
elif git show-ref --verify --quiet refs/heads/master 2>/dev/null; then
    BASE_BRANCH="master"
fi
```

**For Python** (critical_agent.py): Lines 325 AND 326 both hardcode `main`/`master`. The fix:
```python
trunk = os.environ.get("AG_TRUNK_BRANCH", "")
trunk_branches = {"main", "master"}
if trunk:
    trunk_branches.add(trunk)
# Line 325: use `branch not in trunk_branches` instead of hardcoded check
# Line 326: iterate `for base in trunk_branches:` instead of hardcoded tuple
```

The VW sets `AG_TRUNK_BRANCH=verify/run-{timestamp}` in the environment of all spawned subprocesses (see Environment Propagation above). Without the env var, behavior is identical to today.

### Verification Worktree Creation

The VW is created using **direct `git worktree add`**, not `worktree.sh`. Reason: `worktree.sh::cmd_create()` hardcodes the `feature/` branch prefix and integrates with AGENTS.json in ways specific to feature work. The VW needs a `verify/` prefix and different lifecycle semantics.

```python
# In framework_verify.py
branch = f"verify/run-{timestamp}"
vw_path = f"/tmp/ag-vw-{timestamp}"
subprocess.run(["git", "worktree", "add", "-b", branch, vw_path], check=True)
```

Cleanup uses `git worktree remove --force` (handles dirty worktree state) + `git branch -D` in the atexit handler. **Exception**: if PR was created (push succeeded), skip local branch deletion — the remote ref is needed for the PR.

### Failure Classification

Three-tier classification:
1. **Pattern matching**: Stack traces in `.agentic/lib/` → framework bug. `ag` command non-zero with traceback → framework bug. **Timeout** (`SpawnResult.timed_out == True`) → classify as `agent_error` (not a framework bug, just ran too long).
2. **LLM classification**: Ambiguous cases get a focused prompt with the error output asking Claude to classify.
3. **Conservative default**: When uncertain, classify as `agent_error` (safe — wastes a retry but doesn't create false fixes).

### Fix Agent Constraints

The fix agent spawned in the VW operates under strict constraints:
- **Prompt scopes it**: "Fix ONLY the specific bug described. Do not refactor, add features, or modify unrelated code."
- **No `ag commit`**: Fix agent uses direct `git add` + `git commit --no-verify` (not the full `ag commit` workflow, which would try to create another worktree/WIP entry). The `--no-verify` bypasses pre-commit hooks; the real validation gate is `validate_framework.sh` run by the orchestrator immediately after.
- **Zero-commit guard**: After the fix agent returns, check `git rev-parse HEAD` against the pre-fix HEAD. If unchanged (fix agent produced no commit), skip validation/revert and classify as `agent_error` directly.
- **Post-fix validation**: After the fix agent commits, the orchestrator runs `bash tests/validate_framework.sh` in the VW. If validation fails, the fix commit is reverted (`git revert --no-edit HEAD`) and the failure is reclassified as `agent_error` (retry from scratch instead).
- **Commit message format**: `fix(verify): {description}` — no feature-ID patterns. Scenario attribution is tracked in the PR body.

### Fix Accumulation & Delivery

- Each framework fix committed to ephemeral branch in VW with message: `fix(verify): {description}`
- After all scenarios complete (or max_total_fixes reached):
  - **If zero fixes**: No PR created. Report "all scenarios passed, no framework bugs found."
  - **If fixes exist**: Push VW branch to origin (`git push -u origin verify/run-{timestamp}`), then `gh pr create --base main --head verify/run-{timestamp}` with structured body listing each fix and which scenario triggered it.
  - **If push fails**: Warn user, preserve local VW branch (skip atexit cleanup for the branch), print branch name so user can push manually.
  - **If push succeeds but `gh pr create` fails**: Warn user with remote branch name (`origin/verify/run-{timestamp}`) so they can create PR manually. Skip local cleanup (remote branch exists for the PR).
- Worktree + ephemeral branch cleaned up via atexit handler (after PR creation). Branch preserved if push or PR creation failed.

### Safety Hard Guards

1. VW created on ephemeral branch — never on main
2. `AG_TRUNK_BRANCH` env var ensures spawned agents treat ephemeral branch as trunk
3. Example projects in `/tmp/` — completely separate git repos
4. atexit handler cleans up worktrees (`--force`) + ephemeral branches (with `finally` block backup)
5. Max retries (3/scenario) + max total fixes (20) prevent infinite loops. When max_total_fixes reached: stop all scenarios, create PR with partial results + report listing which scenarios remain untested.
6. Pre-flight: refuse to run if on main, if concurrent verify run exists, or if Claude unavailable. Pre-flight runs BEFORE VW creation.

### CLI Design

```
ag auto verify-framework --project todo-app    # Single scenario, single settings combo (first in matrix)
ag auto verify-framework --project todo-app --settings-index 1  # Specific settings combo
ag auto verify-framework --all                 # All scenarios × all settings combos
ag auto verify-framework --all --json          # Machine-readable output
```

Default (no flags): error with usage help.

## Files to Modify

### New Files

| File | ~Lines | Purpose |
|------|--------|---------|
| `.agentic/lib/auto/framework_verify.py` | 650 | `FrameworkVerifier` class — orchestrator, worktree setup, project setup, loop control, milestone checking, PR creation |
| `.agentic/lib/auto/self_heal.py` | 300 | `SelfHealEngine` — failure classification, fix spawning, post-fix validation, restart logic |
| `.agentic/lib/auto/scenarios/todo_app.yaml` | 50 | Single-component: Python REST API |
| `.agentic/lib/auto/scenarios/api_service.yaml` | 50 | Single-component: Node.js service |
| `.agentic/lib/auto/scenarios/cli_tool.yaml` | 50 | Single-component: Python CLI |
| `.agentic/lib/auto/scenarios/fullstack_monorepo.yaml` | 80 | Multi-component monorepo: React frontend + FastAPI backend + shared lib |
| `.agentic/lib/auto/scenarios/fullstack_multirepo.yaml` | 90 | Multi-repo umbrella: separate frontend/backend repos with contracts |
| `.agentic/lib/auto/prompts/verify_build.md` | 40 | Prompt: build example project using framework |
| `.agentic/lib/auto/prompts/verify_fix.md` | 40 | Prompt: diagnose and fix framework bug |
| `.agentic/lib/auto/prompts/classify_failure.md` | 30 | Prompt: classify failure type |
| `tests/test_framework_verify.py` | 350 | Unit tests for FrameworkVerifier + MilestoneChecker |
| `tests/test_self_heal.py` | 250 | Unit tests for SelfHealEngine |
| `.agentic/spec/acceptance/F-0215.md` | 60 | Acceptance criteria |

### Modified Files

| File | Change |
|------|--------|
| `.agentic/lib/auto/__init__.py` | `spawn_claude()` returns `SpawnResult(str)` subclass (fully backward-compatible). Add `SpawnResult` class. |
| `.agentic/lib/tools/state-commit.sh:89` | Accept `$AG_TRUNK_BRANCH` env var (string comparison pattern) |
| `.agentic/lib/tools/wip.sh:234-238` | Same pattern (string comparison) |
| `.agentic/lib/tools/ag.sh` | (1) Same pattern for branch check (string comparison), (2) Add `verify-framework` to `cmd_auto()` |
| `.agentic/lib/auto/critical_agent.py:325-326` | Both lines: add trunk from env var to recognized branches set AND diff base loop (Python) |
| `.agentic/lib/tools/manifest.sh:120-123` | Accept `$AG_TRUNK_BRANCH` env var (`show-ref --verify` pattern — different from string comparison scripts) |
| `.agentic/spec/FEATURES.md` | Add F-0215 entry |
| Instruction files (memory-seed, CLAUDE.md template, auto_orchestration, etc.) | Add trigger word + command reference |

## Scenario YAML Format

**Single-component example:**
```yaml
name: "Todo App"
description: "CRUD todo app with REST API and persistence"
type: single          # single | monorepo | multirepo
timeout: 600          # seconds for build agent (default: 600 for single)

stack:
  language: python
  framework: fastapi
  test_runner: pytest

vision: |
  Build a simple todo application with:
  - REST API (CRUD operations for todos)
  - SQLite persistence
  - Input validation
  - Unit and integration tests

settings_matrix:
  - profile: discovery
    git_workflow: direct
    docs_mode: deferred
  - profile: autonomous_formal
    git_workflow: pull_request
    review_merge: skip

required_milestones:
  - kickoff_complete
  - features_specced
  - implementation_done
  - verification_green
```

**Multi-component monorepo example:**
```yaml
name: "Fullstack Monorepo"
description: "React frontend + FastAPI backend + shared types in one repo"
type: monorepo
timeout: 1200         # seconds (multi-component needs more time)

components:
  - name: api
    path: packages/api
    type: python
    framework: fastapi
    test_command: "pytest packages/api/tests/"
  - name: web
    path: packages/web
    type: typescript
    framework: react
    test_command: "npm run test --workspace=web"
  - name: shared
    path: packages/shared
    type: typescript
    test_command: "npm run test --workspace=shared"

vision: |
  Build a fullstack task management app:
  - React frontend with task list and creation form
  - FastAPI backend with REST endpoints
  - Shared TypeScript types between frontend and API client
  - Integration tests verifying frontend→backend flow

settings_matrix:
  - profile: formal
    git_workflow: pull_request
    review_merge: skip

required_milestones:
  - kickoff_complete
  - features_specced
  - component_features_scoped   # Features have Component: field
  - implementation_done
  - integration_verified        # Cross-component integration tests pass
  - verification_green
```

**Multi-repo umbrella example:**
```yaml
name: "Fullstack Multi-Repo"
description: "Umbrella repo coordinating separate frontend and backend repos"
type: multirepo
timeout: 1200

repos:
  umbrella:
    description: "Orchestrator with specs and contracts"
  api-service:
    language: python
    framework: fastapi
  web-app:
    language: typescript
    framework: react

components:
  - name: api
    path: ../api-service
    repo: local          # Setup code translates to actual temp dir absolute path
    type: python
    test_command: "pytest"
  - name: web
    path: ../web-app
    repo: local
    type: typescript
    test_command: "npm test"

contracts:
  - name: task-api
    format: openapi
    path: contracts/task-api.yaml
    producer: api
    consumers: [web]

vision: |
  Build a task management system split across repos:
  - API service repo: FastAPI backend with task CRUD
  - Web app repo: React frontend consuming the API
  - Umbrella: OpenAPI contract defining the interface
  - Contract validation ensures frontend/backend stay in sync

settings_matrix:
  - profile: autonomous_formal
    git_workflow: pull_request
    review_merge: skip

required_milestones:
  - kickoff_complete
  - contracts_defined           # Contracts section in STACK.md
  - features_specced
  - component_features_scoped
  - implementation_done
  - contracts_validated         # Orchestrator calls load_registry() + validate_contracts()
  - integration_verified
  - verification_green
```

## Acceptance Criteria

- **AC-001**: `ag auto verify-framework --project todo-app` spawns Claude to build a todo app from scratch using framework commands in an isolated worktree. HARD GUARD: no mutation of main or real feature branches.
- **AC-002**: Framework bugs (errors in `.agentic/lib/`) trigger self-healing: classify → fix in VW → validate_framework.sh passes → commit to ephemeral branch → restart scenario from scratch.
- **AC-003**: Accumulated fixes delivered as single PR against main at completion. Zero fixes → no PR, just report. Max fixes reached → PR with partial results. Push failure → preserve local branch, warn user.
- **AC-004**: Scenario definitions are declarative YAML in `.agentic/lib/auto/scenarios/` with `type: single | monorepo | multirepo`.
- **AC-005**: Settings matrix covers at least discovery + autonomous_formal profiles.
- **AC-006**: 5 scripts accept `AG_TRUNK_BRANCH` env var (string comparison and show-ref patterns as appropriate; both lines in critical_agent.py). Without it, behavior unchanged.
- **AC-007**: Verification worktree + ephemeral branches cleaned up on exit (success or failure) using `--force` for dirty state. Branch preserved if push failed.
- **AC-008**: Agent errors (bad Claude choices) distinguished from framework bugs. Agent errors → retry, not fix. Timeouts → agent_error (not framework_bug).
- **AC-009**: Max retries (3/scenario) + max total fixes (20) prevent infinite loops. At max_total_fixes: stop, create PR with partial results, report untested scenarios.
- **AC-010**: `--json` flag provides machine-readable results.
- **AC-011**: Monorepo scenario creates a multi-component project with `## Components` table in STACK.md, features scoped to components via `**Component**:` field, and integration verification across components (exercises `components.py`, `context-for-role.sh --component`, scheduler component scoping, `integration_verify.py`).
- **AC-012**: Multi-repo scenario creates an umbrella repo + separate component repos with `## Contracts` section, cross-repo component resolution, and contract validation (exercises `umbrella.py`, `validate_contracts()`, multi-repo scheduling).

## Execution Order

### Phase 1: Prerequisite — Trunk Branch Configurability + spawn_claude API
- AC-006
- Modify 5 scripts: state-commit.sh, wip.sh, ag.sh (string comparison pattern); manifest.sh (show-ref pattern); critical_agent.py lines 325+326 (Python set + loop)
- Modify `spawn_claude()` to return `SpawnResult(str)` subclass (fully backward-compatible, no caller changes needed)
- ~50 lines changed total, fully backward compatible
- Unit test: verify env var overrides default branch detection
- Integration test: verify env var propagates through spawn_claude → claude → bash tool chain

CHECKPOINT: `bash tests/validate_framework.sh` passes, existing behavior unchanged, `SpawnResult` has `.returncode` and `.timed_out`

### Phase 2: Foundation — Scenario Format + Core Orchestrator
- AC-004 (YAML loader)
- AC-001 (core loop — spawn agent, detect success/failure)
- AC-007 (cleanup with `--force`, branch preservation on push failure)
- Initialization sequence: pre-flight → VW creation → scenario loop
- MilestoneChecker class (filesystem + exit-code + direct Python calls)
- Example project setup: copy `.agentic/`, create `.claude/settings.json` with `_tier: 1`, git init + commit
- Multi-repo setup ordering: create component dirs + git init → THEN write STACK.md
- VW creation via direct `git worktree add` (not worktree.sh)
- Write `framework_verify.py` + `scenarios/*.yaml` + `prompts/verify_build.md`
- No self-healing yet — just report pass/fail per scenario

CHECKPOINT: `ag auto verify-framework --project todo-app` runs, spawns agent, reports result

### Phase 3: Self-Healing Engine
- AC-002 (classification + fix + post-fix validation)
- AC-008 (agent_error vs framework_bug distinction; timeout = agent_error)
- AC-009 (bounded retries + max total fixes with partial-PR behavior)
- Fix agent constraints: scoped prompt, direct git commit `--no-verify`, no ag commit
- Post-fix `validate_framework.sh` gate — revert if validation fails
- AGENTS.json cleanup before scenario restart
- Write `self_heal.py` + `prompts/verify_fix.md` + `prompts/classify_failure.md`

CHECKPOINT: When agent hits a framework bug, system classifies, fixes, validates, restarts

### Phase 4: Multi-Component Scenarios
- AC-011 (monorepo scenario)
- AC-012 (multi-repo scenario)
- Scenario setup logic in `framework_verify.py`: create component dirs, write STACK.md with Components/Contracts tables
- Multi-repo setup: create sibling git repos (each with `git init` + initial commit) BEFORE writing STACK.md, umbrella with resolved absolute paths (not literal "local") in Components table
- `contracts_validated` milestone: orchestrator calls `load_registry(project_root)` then `validate_contracts(project_root, registry)` directly
- Reuse: `components.py:load_registry()`, `umbrella.py:resolve_umbrella()`, `integration_verify.py`

CHECKPOINT: `ag auto verify-framework --project fullstack-monorepo` exercises component registry + integration verification

### Phase 5: Delivery + Polish
- AC-003 (push VW branch, PR creation with structured body; skip if zero fixes; partial if max fixes; preserve branch on push failure)
- AC-010 (JSON output)
- AC-005 (settings matrix iteration)
- CLI: `--project`, `--all`, `--settings-index`, `--json`
- All 5 scenario YAML files finalized

CHECKPOINT: Full end-to-end run produces PR with accumulated fixes (or clean report)

### Phase 6: Instruction Files + Tests
- Unit tests for both modules
- LLM behavioral test: agent invokes `ag auto verify-framework` on trigger
- Update: memory-seed, CLAUDE.md template, auto_orchestration.md, ag.sh quick commands
- FEATURES.md entry

## Verification

1. **Unit tests**: `pytest tests/test_framework_verify.py tests/test_self_heal.py`
2. **Structural**: `bash tests/validate_framework.sh` (add F-0215 section)
3. **Manual smoke test**: `ag auto verify-framework --project todo-app` in a sandbox environment with tier-1 permissions
4. **Safety verification**: Confirm main branch has zero new commits after a full run; confirm ephemeral branch exists only during run and is cleaned up after

## Risks

| Risk | Mitigation |
|------|------------|
| Agent mutates real main | Hard guard: AG_TRUNK_BRANCH, branch validation, atexit cleanup, pre-flight check |
| False framework fixes | Conservative classification (default=agent_error). Post-fix validate_framework.sh gate. Fix validated by restart |
| Token/cost explosion | Bounded retries + scenario-level `timeout` field. `--project` for focused single-scenario runs |
| Cleanup fails (leftover branches) | atexit + finally block with `--force`. `verify/` prefix makes stale branches identifiable. Pre-flight detects stale branches |
| Fix agent introduces regressions | Post-fix `validate_framework.sh` gate; revert on failure. Scenario restart IS the behavioral test |
| Cross-scenario fix regressions | Max total fixes bound. Scenarios run against latest VW state (accumulated fixes). Not traced in v1 — enhancement for future |
| Build agent hangs (no permissions) | `.claude/settings.json` with `_tier: 1` copied to each example project |
| Push failure loses fixes | Preserve local branch on push failure, warn user with branch name |

## Key Reuse

| Existing | Reuse | Note |
|----------|-------|------|
| `spawn_claude()` (`auto/__init__.py`) | Spawning build + fix agents | Modified to return `SpawnResult(str)` subclass. Env inherited via os.environ |
| `agents_helpers.py` | AGENTS.json coordination | Pre-flight + cleanup |
| `PipelineResult` pattern (`pipeline.py`) | Result dataclass design | |
| `ParallelDispatcher` (`parallel.py`) | Future: parallel scenarios | |
| `profiles.conf` | Reading settings defaults for matrix generation | |
| `components.py` (`auto/components.py`) | Load/validate component registry for monorepo scenarios | `load_registry()` also needed before `validate_contracts()` |
| `umbrella.py` (`auto/umbrella.py`) | Cross-repo resolution + contract validation for multi-repo scenarios | `repo: local` translated to real absolute path before STACK.md write. `validate_contracts()` called directly by orchestrator (two-call: `load_registry()` then `validate_contracts()`) |
| `integration_verify.py` (`auto/integration_verify.py`) | Epic integration verification for multi-component scenarios | |
| `context-for-role.sh` | Component-scoped subagent context | |

**Not reused** (with reason):
| Tool | Reason |
|------|--------|
| `worktree.sh` | Hardcodes `feature/` prefix. VW uses direct `git worktree add -b verify/...` |

---

## Review History

### Iteration 1 (2026-03-14)

**Revision Guidance received (8 items):**
1. [Critical] Specify milestone detection mechanism → Added "Milestone Detection" section with concrete filesystem checks per milestone + MilestoneChecker class
2. [Critical] Address spawn_claude() env injection → Added "Environment Propagation" section tracing the full subprocess chain + Phase 1 integration test
3. [Important] Handle zero-fix case in AC-003 → Updated AC-003 and "Fix Accumulation & Delivery" to skip PR when no fixes
4. [Important] Add in-loop validate_framework.sh after fix → Added "Fix Agent Constraints" section with post-fix validation gate + revert on failure
5. [Important] Add pre-flight checks → Added "Pre-Flight Checks" section (Claude availability, concurrent run guard, main branch check, AGENTS.json state)
6. [Consider] Clarify CLI design → Added "CLI Design" section with --project, --all, --settings-index, --json flags
7. [Consider] Clarify worktree.sh reuse → Added "Verification Worktree Creation" section explaining direct git worktree add. Moved worktree.sh to "Not reused" table with reason
8. [Consider] AGENTS.json cleanup on restart → Added cleanup step in core loop (step 1) before creating fresh project dir

### Iteration 2 (2026-03-14)

**Revision Guidance received (8 items):**
1. [Critical] spawn_claude() discards exit code → Added "spawn_claude() API Change" section: returns SpawnResult dataclass with .returncode and .timed_out, backward-compatible via __str__().
2. [Critical] Example project needs .claude/settings.json → Added to "Example Project Setup" section.
3. [Critical] contracts_validated milestone checks non-existent logs → Changed to: orchestrator calls validate_contracts() directly.
4. [Important] Push VW branch before PR creation → Added git push step.
5. [Important] Use --force in worktree cleanup → Updated cleanup to use git worktree remove --force.
6. [Important] Specify build agent timeout → Added timeout field to scenario YAML format.
7. [Consider] AC-009 boundary behavior → Updated: at max_total_fixes, create PR with partial results.
8. [Consider] Fix agent --no-verify → Updated "Fix Agent Constraints".

### Iteration 3 (2026-03-14)

**Revision Guidance received (7 items):**
1. [Critical] SpawnResult __str__() insufficient for backward compat → Changed to `SpawnResult(str)` subclass — all string operations (.upper(), [:200], .startswith(), `in`) work natively.
2. [Critical] contracts_validated "empty list = pass" wrong → Fixed to `len(results) > 0 and all(not r.warnings for r in results)`. Spelled out two-call sequence: `load_registry()` then `validate_contracts()`.
3. [Critical] SpawnResult on timeout undefined → Specified: `returncode=-1, timed_out=True`. Added timeout → agent_error in Failure Classification.
4. [Important] manifest.sh uses show-ref pattern → Added separate code template for show-ref style. Distinguished from string comparison scripts in Modified Files table.
5. [Important] Ordering: pre-flight before VW creation → Added "Initialization Sequence" section with strict ordering. Multi-repo: component dirs + git init BEFORE STACK.md write.
6. [Consider] Push failure fallback → Preserve local branch on failure, warn user with branch name.
7. [Consider] Spell out load_registry + validate_contracts sequence → Added to milestone table and Key Reuse notes.

**Additional refinements:**
- `verification_green` simplified to exit code + timeout only (no stdout string matching — too many false negatives)
- Timeout classified as `agent_error` in failure classification (not framework_bug)

### Iteration 4 (2026-03-14) — FINAL

**No critical or important concerns raised.** Three minor [Consider] items applied:
1. [Consider] VW needs `.claude/settings.json` for fix agent → Added note in "Example Project Setup" section.
2. [Consider] Fix agent zero-commit guard → Added to "Fix Agent Constraints": check HEAD before/after, skip revert if unchanged.
3. [Consider] `gh pr create` failure after successful push → Added fallback: warn user with remote branch name.

**Review outcome**: Plan APPROVED after 4 iterations of dialectical review.
