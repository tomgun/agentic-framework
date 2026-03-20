**Status**: APPROVED (revision 2 — converged after 2 rounds of dialectical review)

# Plan: QA Observatory — Central Registry, Simulation Testing, and Complexity Tier Experiments

## Revision History
- **v1**: Initial plan from plan mode
- **v2**: Addressed dialectical review findings — decomposed into separate features, fixed tier definitions, resolved SequenceChecker duplication, corrected dependency ordering

## Context

The framework has ~50K lines of code across 85 shell scripts, 56 Python modules, 14 skills, 10 checklists, and 22 pre-commit gates. Quality assurance is extensive but fragmented across 12+ categories (367 static tests, 1,442+ pytest tests, 70 LLM behavioral tests, 50 shell tests, 5 scenario tests, session analysis). There is no single place to understand what's tested, what gaps exist, or whether the framework's complexity actually helps. Three concerns:

1. **No central QA map** — hard to know what's covered and what's missing
2. **No simulation/snapshot testing** — we check final outcomes but not intermediate workflow states or agent behavior patterns
3. **No empirical evidence that complexity helps** — the framework might be over-engineered; simpler configurations might work just as well

This is an **epic** with 4 features (Part 0-3), each with its own spec and ACs. Claude Code is the primary test tool; multi-tool testing comes later.

## Feature Decomposition

| Feature | Part | Title | Independent? |
|---------|------|-------|-------------|
| F-0240 | 0 | Framework Execution Log | Foundation (standalone debugging value) |
| F-0241 | 1 | Central QA Registry | **YES** — fully independent |
| F-0242 | 2 | Simulation Testing (Phase + Sequence) | Depends on F-0240 |
| F-0243 | 3 | Complexity Tier Experiments | Depends on F-0240, benefits from F-0242 |

**Honest ordering**: F-0241 can ship independently at any time. F-0240→F-0242→F-0243 is sequential. Don't claim parallel execution for dependent work.

---

## Part 0: Framework Execution Log (F-0240)

### What
Add a structured append-only log at `.agentic/session/framework.log` that every script writes to when called. Tool-agnostic execution trace — works with Claude, Cursor, Copilot, and Codex.

### Standalone Value
Even without Parts 2-3, framework.log is a **debugging aid** for users. When something goes wrong ("why did my commit fail?"), users can read the log to see exactly which gates fired and what failed. Currently this information is scattered across terminal output that scrolls away.

### Format (structured, not free-form)
Pipe-delimited with **fixed field structure** so PhaseChecker can parse reliably:

```
TIMESTAMP | SCRIPT | COMMAND VERB | ARGS | RESULT
```

Examples:
```
2026-03-20T10:45:23Z | ag.sh        | implement  | F-0042           | start
2026-03-20T10:45:24Z | wip.sh       | check      |                  | ok
2026-03-20T10:45:25Z | feature.sh   | status     | F-0042 in_progress | ok
2026-03-20T10:46:01Z | pre-commit   | check      | 6 (tests)        | pass
2026-03-20T10:46:02Z | pre-commit   | check      | 21 (plan approved)| fail
2026-03-20T10:46:03Z | ag.sh        | implement  | F-0042           | exit 1
```

### Implementation
New `.agentic/lib/tools/fwlog.sh`:
```bash
fwlog() {
  local script="$1" verb="$2" args="${3:-}" result="${4:-ok}"
  local ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  local log="${AGENTIC_ROOT:-.agentic}/session/framework.log"
  printf '%s | %-12s | %-10s | %-20s | %s\n' "$ts" "$script" "$verb" "$args" "$result" >> "$log" 2>/dev/null
}
```

**Phase 1** — 80% coverage via choke points:
- `ag.sh` — command entry/exit with exit code (catches ALL `ag` commands)
- `pre-commit-check.sh` — each of the 22 check results (pass/fail/skip)
- Hook scripts (3 files) — hook fire events

**Phase 2 (deferred to F-0242)** — individual state scripts as needed

**Housekeeping**: Add `framework.log` to `.gitignore` template. Truncate at session start (keep previous as `framework.log.prev`).

### Files
- Create: `.agentic/lib/tools/fwlog.sh`
- Modify: `.agentic/lib/tools/ag.sh` (source fwlog.sh, add log calls at entry/exit)
- Modify: `.agentic/lib/hooks/pre-commit-check.sh` (log each check result)
- Modify: `.agentic/lib/hooks/` hook scripts (log hook fire)
- Modify: `.agentic/.gitignore` template (add framework.log)

---

## Part 1: Central QA Registry (F-0241) — INDEPENDENT

### What
A **generated** document (`docs/QA_REGISTRY.md`) produced by `tests/qa_registry.py` that catalogs every QA method, maps features to tests, and identifies gaps.

### Why generated, not hand-written
156 features × 12 test categories. Manual maintenance would drift instantly.

### How
`qa_registry.py` scans:
- `tests/validate_framework.sh` for `# F-XXXX:` section headers → static test mapping
- `tests/test_*.py` for `@feature F-XXXX` decorators → pytest mapping
- `tests/llm/tests/*.sh` for feature references → LLM test mapping
- `tests/infrastructure/` for structural/mutation tests
- `.agentic/lib/auto/scenarios/*.yaml` for scenario coverage
- `.agentic/lib/hooks/pre-commit-check.sh` for gate catalog (checks 1-22)
- `.agentic/lib/checklists/*.md` for checklist coverage

**Annotation reality**: Only `validate_framework.sh` (81 features tagged) and 5/39 pytest files have `@feature` annotations. The registry will honestly report this: "81 features mapped via static tests, 5 via pytest, 34 pytest files untagged." **Finding the gap IS the value.**

Output sections:
1. **Test Methods Catalog** — each category, file count, how to run
2. **Feature-to-Test Matrix** — for each F-XXXX: which test types cover it? (sparse initially — that's the point)
3. **Gap Analysis** — features with zero automated tests + test files with no feature tags
4. **Quick Run Guide** — `fast` (static+unit, 2min), `medium` (+LLM, 30min), `full` (+scenarios, 2hr)

Add `ag qa` command. Freshness check runs in CI (not pre-commit — avoids adding latency to every commit).

### Files
- Create: `tests/qa_registry.py`, `docs/QA_REGISTRY.md`
- Modify: `.agentic/lib/tools/ag.sh` (add `qa` command)
- Modify: `tests/validate_framework.sh` (freshness check — advisory, not blocking)

---

## Part 2: Simulation Testing (F-0242) — Depends on F-0240

### What
Extend scenario YAML format with **intermediate state expectations** and **tool-call sequence checks**, verified after real scenario runs.

### Key Insight
Three complementary data sources:
1. **framework.log** (F-0240) — tool-agnostic, primary for phase detection
2. **Git archaeology** — supplementary for state checks
3. **JSONL logs** (Claude Code only) — primary for behavioral sequence checks

### Extended Scenario Format (backward-compatible — all new keys optional)

```yaml
phase_expectations:
  - phase: "kickoff"
    detect_via:
      framework_log: "ag.sh | kickoff"  # structured match against log fields
    state:
      files_exist:
        - ".agentic/spec/FEATURES.md"
      file_contains:
        - path: ".agentic/spec/FEATURES.md"
          pattern: "F-\\d{4}"
      files_not_exist:
        - ".agentic/journal/plans/*-plan.md"

  - phase: "implement"
    detect_via:
      framework_log: "ag.sh | implement"
    state:
      files_exist:
        - "app/**/*.py"
        - "tests/test_*.py"

tool_call_expectations:
  - name: "spec_before_code"
    description: "Spec/AC files created before source code"
    sequence:
      - {tool: "Write|Edit", path_match: "spec/|acceptance/", label: "spec_write"}
      - {tool: "Write|Edit", path_match: "app/|src/", label: "code_write"}
    ordering: "spec_write before code_write"
```

### Implementation — Extending Existing Code (NOT parallel systems)

**PhaseChecker** (new class in `framework_verify.py`):
- Parses `framework.log` with structured field matching (script + verb)
- Uses `git log` as supplementary phase signal
- Returns `MilestoneResult` list (existing type)
- Tolerant matching: "at some point, state X existed"

**SequenceChecker** — extends `detect_violations()` in `session-analyze.py`:
- **NOT a parallel function** — refactor existing `detect_violations()` to load violation patterns from YAML
- Migrate existing hard-coded violations (`stopped_after_plan_exit`, `code_before_review`, `skipped_planning`) to YAML declarations **in the same PR**
- The YAML-driven checker replaces the hard-coded one, not supplements it
- This avoids the "two systems" problem the critic identified

**Integration** in `framework_verify.py` `run_scenario()`:
```python
# After milestone checking, before behavioral expectations
if scenario.get("phase_expectations"):
    phase_results = PhaseChecker(project_root).check_all(phase_expectations)
    milestones.extend(phase_results)

if scenario.get("tool_call_expectations") and log_file:
    events = extract_events(parse_jsonl(log_file))
    tc_results = check_sequence_expectations(events, tool_call_expectations)
    milestones.extend(tc_results)
```

### Files
- Modify: `framework_verify.py` (add PhaseChecker, integrate into run_scenario)
- Modify: `session-analyze.py` (refactor detect_violations to YAML-driven, add check_sequence_expectations)
- Create: `.agentic/lib/auto/violations.yaml` (migrated hard-coded violation patterns)
- Modify: `scenarios/todo_app.yaml`, `scenarios/cli_tool.yaml` (add phase_expectations)
- Create: `tests/test_phase_checker.py`, extend `tests/test_session_analyze.py`

---

## Part 3: Complexity Tier Experiments (F-0243) — Depends on F-0240

### What
Run the **same task** across three **real configuration profiles** and compare outcomes empirically.

### The Three Tiers (REVISED — all are real user configurations)

| Tier | Profile | Enforcement | Analogy |
|------|---------|-------------|---------|
| **A: Discovery** | `profile: discovery`, all defaults | Advisory only — warnings, no blocking | "Smart person with tools and guidelines" |
| **B: Formal** | `profile: formal`, default gates | Structural — pre-commit blocks, plan review required, human review | "Smart person with gates and guardrails" |
| **C: Autonomous Formal** | `profile: autonomous_formal`, `review_merge: skip` | Full structural + agent-driven review | "Smart person with full automation" |

**Why this change**: The original Tier A ("CLAUDE.md only, no scripts") is not a real configuration anyone uses. An agent reading CLAUDE.md that references `ag` commands it can't find would measure "agent confusion from broken instructions," not "outcome without framework tools." All three tiers now represent actual configurations users choose between.

### How "Tier Install" Works

`setup_project_tier()` in `framework_verify.py`:
- **Tier A (discovery)**: Full copy + setup. STACK.md: `profile: discovery` (all defaults: no feature tracking, no blocking gates, advisory only)
- **Tier B (formal)**: Full copy + setup. STACK.md: `profile: formal` (feature tracking, blocking gates, human review)
- **Tier C (autonomous_formal)**: Full copy + setup. STACK.md: `profile: autonomous_formal`, `review_merge: skip` (all gates, agent review)

### Metrics

```python
@dataclass
class TierMetrics:
    # Identity
    tier: str              # "discovery" | "formal" | "autonomous_formal"
    scenario: str
    run_number: int

    # UNIVERSAL metrics (cross-tier comparison)
    app_runs: bool
    tests_pass: bool
    test_count: int
    code_quality_errors: int  # lint error count (concrete, not float)
    wall_time_seconds: float
    total_commits: int
    code_files_count: int

    # FRAMEWORK-SPECIFIC metrics (what the framework adds)
    spec_created: bool
    plan_created: bool
    plan_reviewed: bool
    journal_updated: bool
    conventional_commits_pct: float
    features_shipped: int
    ac_completeness_pct: float
    framework_log_events: int

    # Workflow violations (from JSONL + framework.log)
    violations: list[dict]
```

**Cross-tier comparisons use universal metrics only.** Framework-specific metrics are reported separately as "what the framework adds at each tier."

**Statistical honesty**: n=3 is a starting point for directional signal with high variance. Results should report per-run values AND variance, not just averages. The plan does not claim p-values or statistical significance.

### Experiment Definition

```yaml
# .agentic/lib/auto/experiments/complexity_tiers.yaml
name: "Complexity Tier Comparison"
scenarios: [todo_app]
tiers:
  - name: discovery
    settings: {profile: discovery}
  - name: formal
    settings: {profile: formal, review_merge: skip}
  - name: autonomous_formal
    settings: {profile: autonomous_formal, review_merge: skip}
repetitions: 3
timeout_per_run: 3600
```

### Files
- Create: `.agentic/lib/auto/tier_experiment.py`, `.agentic/lib/auto/experiments/complexity_tiers.yaml`
- Modify: `framework_verify.py` (add `setup_project_tier()`)
- Create: `tests/test_tier_experiment.py`
- Modify: `ag.sh` (add `ag auto tier-experiment` command)

---

## Delivery Order (honest sequencing)

```
F-0241 (QA Registry) ─────────────────────────── independent, ship anytime
F-0240 (Framework Log) ─→ F-0242 (Simulation) ─→ F-0243 (Tier Experiments)
```

**Recommended start**: F-0241 (QA Registry) first — it's independent, immediately useful, and smallest scope. Then F-0240 → F-0242 → F-0243.

## Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| Tier experiments expensive (3 tiers × 3 reps = 9 runs) | HIGH | Start with todo_app only. Manual single-run pilot before full automation. |
| Discovery agents don't commit at phase boundaries | HIGH | framework.log as primary phase detector |
| n=3 insufficient for meaningful comparison | MEDIUM | Report per-run values + variance. Increase n if ambiguous. |
| JSONL format changes across Claude versions | MEDIUM | Existing parser handles variations. Keep tolerant. |
| fwlog.sh I/O on slow disks | LOW | Single append per call. Benchmark if needed. |
| framework.log in worktrees | LOW | Each worktree has own session dir via $AGENTIC_ROOT |

## Verification

- **F-0240**: Run any `ag` command → `.agentic/session/framework.log` has structured entries
- **F-0241**: `python3 tests/qa_registry.py && cat docs/QA_REGISTRY.md` shows registry with feature matrix
- **F-0242**: `pytest tests/test_phase_checker.py tests/test_session_analyze.py -v` passes; scenario YAML extensions work
- **F-0243**: `ag auto tier-experiment --scenario todo_app --json` produces comparison report
