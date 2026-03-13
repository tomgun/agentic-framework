# Plan: F-0204 Epic Integration Verification

**Status**: DRAFT
**Feature**: F-0204 (ADR-001 §6, ADR-002 §8 item 5)
**Parent**: F-0188 (Full Autonomous Pipeline)
**Depends**: F-0186 (Autonomous Scheduler)

## Context

When an epic's children all reach `shipped`, `recompute_epic_status()` auto-derives the epic to `shipped`. But there's no integration verification — no cross-component test suite validates that children work together. An epic could ship with components that individually pass but collectively fail.

**Goal**: Insert an integration verification gate between "all children shipped" and "epic shipped". Only after integration tests pass (or none are defined) does the epic advance.

## Design Decisions

### D1: Integration test command location
**STACK.md `## Integration tests` section** (project-level), with per-epic override in the epic's AC file (`## Integration tests` section). Resolution: epic AC > STACK.md section > skip.

Rationale: Parallels existing `Test commands:` pattern. Integration tests are project infrastructure, not per-epic. But epic-specific cross-component tests are possible via AC file override.

### D2: Trigger mechanism
**Dual trigger**: (1) `scheduler.run_epic()` post-completion hook, (2) standalone `ag auto verify-epic F-XXXX` CLI command.

Rationale: Scheduler is the natural orchestration point. CLI enables manual re-runs and independent testing. `recompute_epic_status()` is NOT the trigger — it's the gate.

### D3: State machine interaction — no new states
`derive_epic_status()` stays pure (no filesystem reads). Instead, `recompute_epic_status()` intercepts: when derived status is `"shipped"`, it checks for an integration verification artifact before writing. If tests are defined but not passed, it holds at `"implementing"`.

### D4: Review checkpoint
New `review_integration` setting (human | critical_agent | skip). Defaults: discovery=skip, formal=critical_agent, autonomous_formal=critical_agent. Uses existing `CriticalAgent.review()` with new focus entry.

### D5: Failure handling
If integration tests fail: children stay shipped, epic stays `"implementing"`. Artifact records failure. Re-run via `ag auto verify-epic F-XXXX` after fixes.

## Files to Change (10 total: 3 new, 7 modified)

### New Files

| File | Purpose |
|------|---------|
| `.agentic/lib/auto/integration_verify.py` | Core module: load commands, run verify, store/read artifacts |
| `.agentic/spec/acceptance/F-0204.md` | Acceptance criteria (8 ACs) |
| `tests/test_integration_verify.py` | Tests (~15 cases) |

### Modified Files

| File | Change |
|------|--------|
| `.agentic/lib/auto/epic.py` | Integration gate in `recompute_epic_status()` (~15 lines at L152) |
| `.agentic/lib/auto/scheduler.py` | Post-completion hook in `run_epic()` (~20 lines at L296), `integration_result` field on `SchedulerResult` |
| `.agentic/lib/auto/critical_agent.py` | Add `review_integration` to `_REVIEW_FOCUS` dict (L50) |
| `.agentic/lib/presets/profiles.conf` | Add `review_integration` to all 3 profiles |
| `.agentic/lib/tools/ag.sh` | Add `verify-epic` case to `cmd_auto()`, update help |
| `.agentic/lib/init/STACK.template.md` | Add commented `## Integration tests` section |
| `CHANGELOG.md` | F-0204 entry |

## Implementation Detail

### 1. `integration_verify.py` — Core Module

```python
@dataclass
class IntegrationResult:
    epic_id: str
    success: bool
    commands_run: int = 0
    verify_result: Optional[VerifyResult] = None
    skipped: bool = False      # True if no integration tests defined
    error: str = ""

def load_integration_commands(project_root, epic_id) -> list[str]:
    """Resolution: epic AC file ## Integration tests > STACK.md ## Integration tests > skip."""

def run_integration_verify(project_root, epic_id, claude_command="claude") -> IntegrationResult:
    """Load commands → VerifyLoop.run() → store artifact → optional review → return."""

def get_integration_result(project_root, epic_id) -> Optional[IntegrationResult]:
    """Read stored artifact from .agentic/session/integration-verify/{epic_id}.json."""

def main() -> int:
    """CLI: ag auto verify-epic F-XXXX [--json]"""
```

Key: reuses `VerifyLoop(project_root, test_command=cmd)` for each integration command. Artifact stored at `paths.session_dir / "integration-verify" / f"{epic_id}.json"`.

### 2. `epic.py` — Gate in `recompute_epic_status()`

Insert between `derived = derive_epic_status(children)` and the status write (L152-159):

```python
if derived == "shipped":
    from .integration_verify import get_integration_result, load_integration_commands
    commands = load_integration_commands(project_root, epic_id)
    if commands:
        result = get_integration_result(project_root, epic_id)
        if result is None or not result.success:
            messages.append(f"Epic {epic_id}: integration verification {'pending' if result is None else 'failed'}")
            derived = "implementing"
```

### 3. `scheduler.py` — Post-Completion Hook

```python
def run_epic(self, epic_id, ...):
    children = self._get_epic_children(epic_id)
    result = self.run(feature_ids=children, ...)

    if result.success:
        iv_result = self._run_integration_verify(epic_id)
        if iv_result and not iv_result.success:
            result.success = False
            result.stopped_reason = f"Integration verification failed for {epic_id}"
            result.integration_result = iv_result.to_dict()
    return result
```

### 4. Review Setting

`critical_agent.py` — new focus entry:
```python
"review_integration": (
    "Focus on: cross-component contract satisfaction, API compatibility, "
    "shared state consistency, integration test coverage of epic acceptance criteria."
),
```

`profiles.conf` — add to all 3 profiles:
- `discovery.review_integration=skip`
- `formal.review_integration=critical_agent`
- `autonomous_formal.review_integration=critical_agent`

### 5. CLI: `ag auto verify-epic`

In `ag.sh` `cmd_auto()`:
```bash
verify-epic) python3 "$auto_dir/integration_verify.py" --project-root "$ROOT_DIR" "$@" ;;
```

## Acceptance Criteria

- **AC-001**: `recompute_epic_status()` holds epic at "implementing" when all children shipped but integration tests defined and no verification artifact exists
- **AC-002**: Epic ships when integration tests pass (artifact success=true) or no tests defined
- **AC-003**: `load_integration_commands()` resolves from epic AC > STACK.md section > skip (priority order)
- **AC-004**: `run_integration_verify()` runs commands via VerifyLoop, stores artifact, returns IntegrationResult
- **AC-005**: `scheduler.run_epic()` auto-runs integration verification after all children complete
- **AC-006**: `ag auto verify-epic F-XXXX` CLI works standalone
- **AC-007**: Graceful degradation — no integration tests defined = epic ships immediately
- **AC-008**: `review_integration` setting controls critical agent review of results

## Verification

1. `python -m pytest tests/test_integration_verify.py -v` — all tests pass
2. `python -m pytest tests/test_epic.py -v` — existing + new integration gate tests pass
3. `python -m pytest tests/test_scheduler.py -v` — existing + integration hook tests pass
4. `bash tests/validate_framework.sh` — framework validation passes
5. Manual: `ag auto verify-epic F-XXXX` with/without integration tests in STACK.md
