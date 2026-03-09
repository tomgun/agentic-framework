# F-0182: Critical Review Agent — Implementation Plan

**Status**: APPROVED
**ADR**: ADR-001 Phase 4
**Dependencies**: F-0180 (shipped), F-0181 (shipped)
**Review**: Revision 2 — addresses dialectical review findings

## Context

Review checkpoints (F-0180) support three modes: `human`, `critical_agent`, `skip`. Currently `critical_agent` falls back to `human` with a placeholder message (review.py lines 185-191). This feature makes `critical_agent` functional by spawning a separate Claude instance that performs adversarial review.

This unblocks: F-0183 (Taste/Style), F-0186 (Autonomous Scheduler), and the full autonomous flow.

## Approach

Use the existing `spawn_claude()` infrastructure (`.agentic/lib/auto/__init__.py`) to spawn a fresh Claude CLI instance with an adversarial review prompt. The critical agent reads context (diff, specs, ACs, NFRs), produces a structured JSON verdict, and the framework acts on it (approve → proceed, request_changes → block, escalate → human).

### Key Design Decisions

1. **CLI-based spawning** (not API): Consistent with how `verify.py`, `task.py`, and `engine.py` already spawn Claude. Uses `spawn_claude()` with `--print` mode. Respects tier-based permission settings.

2. **Model selection** (fallback chain):
   - First: parse `## Model customization` section in STACK.md for `review:` value under `- models:`. This section uses nested YAML-like format (indented sub-keys), NOT the flat `- key: value` format that `settings.py` handles. Requires custom parsing: scan for `## Model customization` heading, then regex `^\s+review:\s*(\S+)` within that section. Handle commented-out state (lines wrapped in `<!-- -->`) by checking if the matched line is inside HTML comments.
   - Second: if no explicit model, check `agent_mode` from `## Settings` (via `get_setting()`). Map mode → review model: `premium` → no flag (use default/best), `balanced` → `sonnet`, `economy` → `haiku`.
   - Third: if no agent_mode or unknown value, fall back to default `claude` command (no `--model` flag).
   - Helper: `_resolve_model()` in `critical_agent.py` implements this chain.

3. **Verdict format**: JSON block fenced in ```json markers within the Claude output. Parsed via regex `r"```json\s*\n(.*?)\n\s*```"` with `re.DOTALL`. **Fallback**: if no fenced block found, try to find bare JSON by scanning for `{` ... `}` and attempting `json.loads()`. If all parsing fails → treat as escalation (never auto-approve). Three possible verdicts: `approved`, `request_changes`, `escalate`.

4. **Integration point**: `check_review()` in `review.py` — when mode is `CRITICAL_AGENT`, call `CriticalAgent.review()` synchronously. Print "Running critical agent review..." before spawn. If verdict is `approved`, store verdict artifact and return `(True, [msgs])`. If `request_changes`, return `(False, [issues])`. If `escalate`, create HUMAN_NEEDED and return `(False, [escalation])`.

5. **Prompt assembly**: Per-transition prompt templates. The review type (spec, code, plan, regression, etc.) determines what context is loaded and what review focus areas apply.

6. **Verdict artifact storage**: Extract the verdict-writing logic from `resolve_review()` (lines 342-367) into a shared helper `_write_verdict_artifact(paths, feature_id, from_state, to_state, setting_key, verdict, reasoning, reviewer, review_mode)`. Both `resolve_review()` (human reviews) and `check_review()` (critical_agent approvals) call this helper. The `reviewer` parameter accepts `"human"` or `"critical_agent"`. For critical_agent, format as `critical_agent` (model info stored in raw_output, not in reviewer field — keeps it simple).

7. **Error handling & retry (AC-007)**: Error classification based on `spawn_claude()` return value prefix:
   - `"error: Claude timed out"` → timeout → fall back to human immediately
   - `"error: claude command not found"` → unavailable → fall back to human immediately (no retry — binary failure)
   - `"error: "` (other errors) → possibly transient → retry once after 5s delay, then fall back to human
   - Rate limiting: Claude CLI handles rate limiting internally. If it surfaces as a timeout, the timeout path applies. If it surfaces as an error string, the retry-once path applies.
   - On any fallback to human: create pending review + HUMAN_NEEDED entry (reuse existing `create_pending_review()`)

8. **Git diff for context assembly**:
   - `review_code`: `git diff HEAD~1 -- .` (last commit's changes). If on a feature branch, `git diff main...HEAD` instead (detect via `git rev-parse --abbrev-ref HEAD` != `main`). Truncate to first 3000 lines with `[diff truncated, {total} lines total]` note.
   - `review_spec`: no diff — read the spec file content + ACs directly
   - `review_plan`: no diff — read plan file + ACs
   - `review_regression`: `git diff HEAD~1` + read regression-affected test files
   - All types: append NFRs from `paths.nfr_file` if it exists

9. **Only `approved` verdicts produce verdict artifacts.** `request_changes` and `escalate` do not — this means a re-triggered transition after fixes will re-invoke the critical agent (correct behavior for iterative review).

## Files to Create

### `.agentic/lib/auto/critical_agent.py` (NEW, ~280 lines)

```python
@dataclass
class ReviewVerdict:
    verdict: str          # approved | request_changes | escalate
    confidence: str       # high | medium | low
    summary: str          # One-line summary
    issues: list[dict]    # [{severity, category, description, location}]
    recommendation: str   # What should happen next
    raw_output: str       # Full agent output for debugging


class CriticalAgent:
    def __init__(self, project_root: Path, claude_command: str = "claude"):
        ...

    def review(self, feature_id, from_state, to_state, review_setting) -> ReviewVerdict:
        """Run adversarial review. Returns structured verdict."""
        # 1. Assemble context (diff, specs, ACs, NFRs)
        # 2. Build prompt from template + context
        # 3. Resolve model (from STACK.md Model customization)
        # 4. Print "Running critical agent review..." to stderr
        # 5. Spawn Claude via spawn_claude() with timeout=600
        # 6. Check for error prefix → retry once or fall back
        # 7. Parse structured verdict from output
        # 8. Return ReviewVerdict

    def _assemble_context(self, feature_id, from_state, to_state, review_setting) -> str:
        """Gather relevant context based on review type.

        review_code → git diff (main...HEAD or HEAD~1, truncated to 3000 lines),
                      feature spec from FEATURES.md, ACs from acceptance dir
        review_spec → spec content from acceptance dir, FEATURES.md entry
        review_plan → plan file from plans dir, ACs
        review_regression → git diff + affected test files
        All types → NFRs from nfr_file (if exists)
        """

    def _get_git_diff(self) -> str:
        """Get git diff, choosing ref range based on branch.

        Feature branch: git diff main...HEAD
        Main branch: git diff HEAD~1
        Truncate to 3000 lines.
        """

    def _resolve_model(self) -> Optional[str]:
        """Resolve model with fallback chain:

        1. Parse ## Model customization section for 'review:' value
           (custom parsing for nested YAML-like format, skip commented lines)
        2. Map agent_mode from settings: premium→None, balanced→sonnet, economy→haiku
        3. Fall back to None (no --model flag)
        """

    def _build_prompt(self, context, review_setting) -> str:
        """Load critical_review.md template and substitute context + review type."""

    def _parse_verdict(self, output: str) -> ReviewVerdict:
        """Extract JSON verdict from Claude output.

        Strategy:
        1. Regex: r"```json\s*\n(.*?)\n\s*```" (re.DOTALL) — last match wins
        2. Fallback: scan for outermost { ... } and try json.loads()
        3. If all parsing fails: return escalation verdict
        """

    def _is_error(self, output: str) -> bool:
        """Check if spawn_claude output indicates an error."""

    def _classify_error(self, output: str) -> str:
        """Classify error: 'timeout' | 'unavailable' | 'transient'."""
```

### `.agentic/lib/auto/prompts/critical_review.md` (NEW, ~100 lines)

Adversarial review prompt template with:
- Clear mandate: "You are a CRITICAL REVIEWER. Your job is to find problems."
- "If in doubt, escalate" instruction
- Review-type-specific focus areas (injected dynamically)
- Required JSON output format with exact schema
- Checklist: correctness, security, testing coverage, AC alignment, NFR compliance, breaking changes

### `tests/test_critical_agent.py` (NEW, ~350 lines)

- Test `_parse_verdict()` with valid fenced JSON, bare JSON, malformed JSON, missing JSON, multiple code blocks (last wins)
- Test `_assemble_context()` for each review type (review_code, review_spec, review_plan, review_regression)
- Test `_get_git_diff()` branch detection and truncation
- Test `_resolve_model()` full fallback chain: explicit model → agent_mode mapping → None
- Test `_resolve_model()` with commented-out Model customization section
- Test `review()` end-to-end with mocked `spawn_claude` returning valid verdict
- Test error handling: timeout → human fallback, transient error → retry once then human, unavailable → immediate human
- Test escalation → creates HUMAN_NEEDED entry
- Test read-only: verify `spawn_claude` called with `print_mode=True`
- Test only `approved` verdicts produce artifacts (not request_changes/escalate)

## Files to Modify

### `.agentic/lib/auto/review.py` (~50 lines changed)

**New helper `_write_verdict_artifact()`**: Extract verdict-writing logic from `resolve_review()` lines 342-367 into a shared function:
```python
def _write_verdict_artifact(
    paths, feature_id, from_state, to_state,
    setting_key, verdict, reasoning, reviewer, review_mode
) -> Path:
    """Write verdict artifact atomically. Returns the verdict file path."""
```

**`check_review()`** (lines 185-211): Replace fallback logic with CriticalAgent dispatch:
```python
if mode == ReviewMode.CRITICAL_AGENT:
    from auto.critical_agent import CriticalAgent
    agent = CriticalAgent(project_root)
    print(f"Running critical agent review for {feature_id} "
          f"({from_state} → {to_state})...", file=sys.stderr)
    try:
        verdict = agent.review(feature_id, from_state, to_state, setting_key)
    except Exception as e:
        # Fall back to human review on any unexpected error
        return _fallback_to_human(
            project_root, paths, feature_id, from_state, to_state,
            setting_key, f"Critical agent error: {e}"
        )

    if verdict.verdict == "approved":
        _write_verdict_artifact(
            paths, feature_id, from_state, to_state, setting_key,
            "approved", verdict.summary, "critical_agent", mode.value,
        )
        return True, [f"Critical agent approved: {verdict.summary}"]
    elif verdict.verdict == "escalate":
        return _fallback_to_human(
            project_root, paths, feature_id, from_state, to_state,
            setting_key, f"Critical agent escalated: {verdict.summary}"
        )
    else:  # request_changes
        return False, [
            f"Critical agent requests changes: {verdict.summary}"
        ] + [f"  - [{i.get('severity','?')}] {i['description']}" for i in verdict.issues]
```

**New helper `_fallback_to_human()`**: Creates pending review + HUMAN_NEEDED entry (reuses `create_pending_review()`), returns `(False, [messages])`.

**`resolve_review()`** (lines 342-367): Replace inline verdict-writing with call to `_write_verdict_artifact()`.

### `.agentic/lib/auto/__init__.py` (~10 lines)

Add optional `model` parameter to `build_claude_cmd()` and `spawn_claude()`:
```python
def build_claude_cmd(..., model: Optional[str] = None) -> list[str]:
    cmd = [claude_command]
    if model:
        cmd.extend(["--model", model])
    # ... rest unchanged

def spawn_claude(..., model: Optional[str] = None, ...) -> str:
    cmd = build_claude_cmd(..., model=model, ...)
    # ... rest unchanged
```

### `tests/test_review.py` (~30 lines changed)

- Update `test_critical_agent_falls_back_to_human` → `test_critical_agent_delegates_to_critical_agent`: mock `CriticalAgent.review()` to return an approved verdict, verify `check_review()` returns `(True, [...])`.
- Add test: `test_critical_agent_error_falls_back_to_human`: mock `CriticalAgent.review()` to raise, verify pending review created.
- Add test: `test_critical_agent_request_changes`: mock verdict with issues, verify `(False, [issues])` returned.

## Files to Update (instruction files — framework dev rule)

- `.agentic/lib/agents/shared/agent_operating_guidelines.md` — remove "falls back to human" note
- `.agentic/lib/agents/shared/auto_orchestration.md` — add critical agent section
- `.agentic/lib/init/memory-seed.md` — update review modes description
- `.agentic/lib/DEVELOPER_GUIDE.md` — add critical agent to review checkpoints section
- `.agentic/lib/HOW_IT_WORKS.md` — update review checkpoint description
- `CHANGELOG.md` — new entry
- `VERSION` — bump

## Execution Order

### Phase 1: Foundation (blocks everything)
- AC-001 (CriticalAgent class), AC-002 (read-only), AC-005 (adversarial prompt)
- Create `critical_agent.py` with class skeleton + `ReviewVerdict` dataclass
- Create `critical_review.md` prompt template
- Add `--model` parameter to `spawn_claude()` in `__init__.py`
- Extract `_write_verdict_artifact()` from `resolve_review()` in `review.py`

### Phase 2: Core Logic
- AC-003 (structured verdicts), AC-004 (model selection), AC-009 (context assembly)
- Implement `_parse_verdict()` with fenced + bare JSON fallback
- Implement `_resolve_model()` with full 3-level fallback chain
- Implement `_assemble_context()` with per-review-type context + `_get_git_diff()`
- CHECKPOINT: Unit tests for parsing, model resolution, and context assembly pass

### Phase 3: Wiring
- AC-008 (review.py delegation), AC-006 (escalation → HUMAN_NEEDED), AC-007 (error handling)
- Replace `check_review()` placeholder with CriticalAgent dispatch
- Implement `_fallback_to_human()` helper
- Wire error classification → retry/fallback logic in `CriticalAgent.review()`
- CHECKPOINT: Integration test — `check_review()` with mocked spawn returns correct results for all 3 verdicts + error paths

### Phase 4: Testing + Docs
- AC-010 (full test suite)
- Complete `test_critical_agent.py` with all test cases listed above
- Update `test_review.py` delegation tests
- Update instruction files
- CHECKPOINT: `validate_framework.sh` + `pytest tests/ -x --ignore=tests/llm` pass

## Verification

1. **Unit tests**: `python3 -m pytest tests/test_critical_agent.py -v`
2. **Integration**: `python3 -m pytest tests/test_review.py -v` (verify delegation works)
3. **Framework validation**: `bash tests/validate_framework.sh`
4. **Smoke test**: Mock `spawn_claude` to return a known valid JSON verdict, trigger `check_review()` with `critical_agent` mode, verify full pipeline: context assembled → prompt built → spawn called → verdict parsed → artifact written
5. **Error path**: Mock `spawn_claude` to return each error type, verify retry/fallback behavior

## Risks

- **Rubber-stamping**: Mitigated by adversarial prompt design + "if in doubt, escalate" instruction
- **Parsing failures**: Mitigated by dual-strategy parsing (fenced → bare → escalation) — never auto-approve on parse failure
- **Cost**: Each critical_agent review spawns a Claude instance. Mitigated by only triggering on configured transitions (most default to `skip`)
- **Timeout**: 600s timeout for reviews. Large diffs truncated to 3000 lines to keep context manageable
- **Synchronous blocking**: CLI will block during review (~30-120s typical). Progress message printed to stderr. Acceptable — same pattern as all existing `spawn_claude` callers. Async is future optimization.
