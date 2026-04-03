# Plan: QA Observatory — Central Registry, Simulation Testing, and Complexity Tier Experiments

## Context

The framework has ~50K lines of code across 85 shell scripts, 56 Python modules, 14 skills, 10 checklists, and 22 pre-commit gates. Quality assurance is extensive but fragmented across 12+ categories (367 static tests, 1,442+ pytest tests, 70 LLM behavioral tests, 50 shell tests, 5 scenario tests, session analysis). There is no single place to understand what's tested, what gaps exist, or whether the framework's complexity actually helps. The user has three concerns:

1. **No central QA map** — hard to know what's covered and what's missing
2. **No simulation/snapshot testing** — we check final outcomes but not intermediate workflow states or agent behavior patterns
3. **No empirical evidence that complexity helps** — the framework might be over-engineered; simpler configurations might work just as well

This plan addresses all three as a unified "QA Observatory" initiative, worked **in parallel** as three independent features. Claude Code is the primary test tool; multi-tool testing comes later.

---

## Part 0: Framework Execution Log (Cross-Cutting Foundation)

### What
Add a structured append-only log at `.agentic/session/framework.log` that every script writes to when called. This provides a **tool-agnostic execution trace** — works with Claude, Cursor, Copilot, and Codex without relying on any tool's proprietary logs.

### Why
- JSONL logs are Claude Code-specific; this works everywhere
- Scripts already have entry points (`ag.sh` routes to commands, hooks fire on events) — adding a log line is trivial
- Gives the simulation testing (Part 2) and tier experiments (Part 3) a clean data source for "what actually happened"
- Complements JSONL: JSONL shows what the *agent* did (tool calls), framework.log shows what the *framework* did (script executions, gate results)

### Format
```
2026-03-20T10:45:23Z | ag.sh        | implement F-0042         | start
2026-03-20T10:45:24Z | wip.sh       | check                    | ok (no WIP)
2026-03-20T10:45:25Z | feature.sh   | F-0042 status in_progress| ok
2026-03-20T10:46:01Z | pre-commit   | check 6 (tests)          | pass
2026-03-20T10:46:02Z | pre-commit   | check 21 (plan approved) | fail (DRAFT)
2026-03-20T10:46:03Z | ag.sh        | implement F-0042         | exit 1
```

### Implementation
Add a shared logging function to a new `.agentic/lib/tools/fwlog.sh`:
```bash
fwlog() {
  local script="$1" action="$2" result="${3:-ok}"
  local ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  local log="${AGENTIC_ROOT:-.agentic}/session/framework.log"
  echo "$ts | $script | $action | $result" >> "$log" 2>/dev/null
}
```

Source it from `ag.sh` and key scripts. **Phased instrumentation:**

**Phase 1 (day 1)** — 80% coverage via choke points:
- `ag.sh` — the command router; catches ALL `ag` commands with entry/exit + exit code
- `pre-commit-check.sh` — log each of the 22 check results (pass/fail/skip)
- Hook scripts (3 files) — log hook fire events

**Phase 2 (as needed)** — individual state scripts:
- `wip.sh`, `status.sh`, `journal.sh`, `feature.sh`, `blocker.sh`, `todo.sh` — log state mutations

**Not instrumented**: Pure-read scripts, helper libraries, Python modules (these are called by instrumented scripts so the outer call is already logged).

**Housekeeping**: Add `framework.log` to `.gitignore` template. Truncate at session start (keep previous session as `framework.log.prev`).

### For Tier Experiments
- Tier A (minimal): No framework.log — no scripts installed
- Tier B (medium): framework.log captures advisory workflow
- Tier C (full): framework.log captures every gate check, every block
- **Comparison**: framework.log line count and patterns reveal how much the framework "does" at each tier

### Files
- Create: `.agentic/lib/tools/fwlog.sh`
- Modify: `ag.sh` (source fwlog.sh, add log calls), `pre-commit-check.sh` (log check results), hook scripts, state scripts

---

## Part 1: Central QA Registry

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

**Annotation reality**: Only `validate_framework.sh` (81 features tagged) and 5/39 pytest files have `@feature` annotations. The registry will honestly report this: "81 features mapped via static tests, 5 via pytest, 34 pytest files untagged." **Finding the gap IS the value** — the registry doesn't pretend to have complete mapping; it shows exactly where mapping exists and where it doesn't.

Output sections:
1. **Test Methods Catalog** — each category, file count, how to run
2. **Feature-to-Test Matrix** — for each F-XXXX: which test types cover it? (sparse initially — that's the point)
3. **Gap Analysis** — features with zero automated tests + test files with no feature tags
4. **Quick Run Guide** — `fast` (static+unit, 2min), `medium` (+LLM, 30min), `full` (+scenarios, 2hr)

Add `ag qa` command. Add freshness check to `validate_framework.sh`.

### Files
- Create: `tests/qa_registry.py`, `docs/QA_REGISTRY.md`
- Modify: `.agentic/lib/tools/ag.sh` (add `qa` command), `tests/validate_framework.sh` (freshness check)

---

## Part 2: Simulation Testing (Phase Expectations + Tool-Call Snapshots)

### What
Extend scenario YAML format with **intermediate state expectations** and **tool-call sequence checks**, verified after real scenario runs.

### Key Insight
Three complementary data sources, each with different strengths:
1. **framework.log** (Part 0) — tool-agnostic, shows exactly which scripts ran and what gates passed/failed. **Primary source for phase detection.**
2. **Git archaeology** — shows what files existed at each commit. Works retroactively. **Supplementary for state checks**, but unreliable for phase detection since discovery-mode agents often make 2-3 large commits instead of per-phase commits.
3. **JSONL logs** (Claude Code only) — shows agent tool calls. **Primary source for behavioral sequence checks** (spec before code, plan before review).

### Extended Scenario Format

```yaml
# Added to existing scenario YAML (backward-compatible — all new keys optional)
phase_expectations:
  - phase: "kickoff"
    state:
      files_exist:
        - ".agentic/spec/FEATURES.md"
        - ".agentic/OVERVIEW.md"
      file_contains:
        - path: ".agentic/spec/FEATURES.md"
          pattern: "F-\\d{4}"
      files_not_exist:
        - ".agentic/journal/plans/*-plan.md"

  - phase: "implement"
    state:
      files_exist:
        - "app/**/*.py"
        - "tests/test_*.py"
        - ".agentic/spec/acceptance/F-*.md"

tool_call_expectations:
  - name: "spec_before_code"
    description: "Spec/AC files created before source code"
    sequence:
      - {tool: "Write|Edit", path_match: "spec/|acceptance/", label: "spec_write"}
      - {tool: "Write|Edit", path_match: "app/|src/", label: "code_write"}
    ordering: "spec_write before code_write"

  - name: "plan_then_review"
    description: "Plan exits followed by critic/advocate spawn"
    sequence:
      - {tool: "ExitPlanMode", label: "plan_exit"}
      - {tool: "Agent", input_match: "critic|advocate", label: "review_spawn"}
    ordering: "plan_exit before review_spawn"
    max_gap: 3
```

### Implementation

**PhaseChecker** (new class in `framework_verify.py`):
- **Primary**: Parses `framework.log` to identify phase transitions (e.g., `ag.sh | implement F-0042 | start` marks the implement phase)
- **Supplementary**: Uses `git log` to find commits and check state at each phase (`git show <commit>:<path>`)
- Checks `files_exist`, `file_contains`, `files_not_exist` against project state at each phase
- Returns `MilestoneResult` list (same type as existing milestones)
- Tolerant matching: "at some point, state X existed" not "at commit #3"

**SequenceChecker** (extension to `session-analyze.py`):
- Reuses existing `extract_events()` parser
- New `check_sequence_expectations(events, tool_call_expectations)` function
- Matches events to labels via tool name + path/input regex
- Verifies ordering constraints, max_gap
- Returns violations in same format as `detect_violations()`
- **Migration**: Existing hard-coded violations (`stopped_after_plan_exit`, `code_before_review`, `skipped_planning`) should be migrated to YAML declarations over time, avoiding duplication

**Integration point** in `framework_verify.py` `run_scenario()` (~line 1580):
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
- Modify: `framework_verify.py` (add PhaseChecker, integrate), `session-analyze.py` (add SequenceChecker)
- Modify: `scenarios/todo_app.yaml`, `scenarios/cli_tool.yaml` (add phase_expectations)
- Create: `tests/test_phase_checker.py`, extend `tests/test_session_analyze.py`

---

## Part 3: Complexity Tier Experiments (A/B/C Testing)

### What
Run the **same task** (e.g., build a todo app) across three instrumentation levels and compare outcomes empirically. This answers: "does the complexity actually help?"

### The Three Tiers

| Tier | What's Installed | Enforcement | Analogy |
|------|-----------------|-------------|---------|
| **A: Minimal** | CLAUDE.md + STACK.md only. No hooks, no skills, no scripts, no `ag` commands | Zero — agent only sees instruction text | "Smart person with a style guide" |
| **B: Medium** | Full `.agentic/` + skills + `ag` commands, discovery profile | Advisory only — warnings, no blocking gates | "Smart person with tools and guidelines" |
| **C: Full** | Full `.agentic/` + autonomous_formal profile, all gates | Structural — pre-commit blocks, plan review required | "Smart person with tools, gates, and guardrails" |

### How "Partial Install" Works

The existing `setup_project()` in `framework_verify.py` already copies `.agentic/` and configures STACK.md. New `setup_project_tier()`:

- **Tier A**: Copy only the CLAUDE.md template to project root. Write minimal STACK.md (language, framework, test_runner — no framework settings). No `.agentic/lib/`, no hooks, no skills.
- **Tier B**: Full copy + `setup-agent.sh` + `generate-skills.sh`. STACK.md: `profile: discovery`, `pre_commit_hook: off`, `state_enforcement: off`.
- **Tier C**: Full copy + everything. STACK.md: `profile: autonomous_formal`, `pre_commit_checks: full`, `plan_review_enabled: yes`, `review_merge: skip`.

### Metrics Collected Per Run

Two metric categories: **universal** (comparable across all tiers) and **framework-specific** (only meaningful when framework is installed).

```python
@dataclass
class TierMetrics:
    # Identity
    tier: str              # "minimal" | "medium" | "full"
    scenario: str
    run_number: int

    # UNIVERSAL metrics (comparable across all tiers)
    app_runs: bool          # Does the built app actually start?
    tests_pass: bool        # Do tests pass?
    test_count: int         # How many tests written?
    code_quality: float     # Lint score / error count
    wall_time_seconds: float
    total_commits: int
    code_files_count: int

    # FRAMEWORK-SPECIFIC metrics (only meaningful for tiers B/C)
    spec_created: bool
    plan_created: bool
    plan_reviewed: bool
    journal_updated: bool
    conventional_commits_pct: float
    features_shipped: int
    ac_completeness_pct: float
    framework_log_events: int   # from framework.log

    # Workflow violations (from JSONL + framework.log)
    violations: list[dict]
```

**Key design choice**: Tier comparisons use **universal metrics only**. Framework-specific metrics show what the framework *adds* to the process, not whether the outcome is better. The comparison table should clearly separate these.

### Experiment Definition

```yaml
# .agentic/lib/auto/experiments/complexity_tiers.yaml
name: "Complexity Tier Comparison"
scenarios: [todo_app]  # start simple
tiers:
  - name: minimal
    install_mode: minimal
  - name: medium
    install_mode: medium
    settings: {profile: discovery, pre_commit_hook: "off"}
  - name: full
    install_mode: full
    settings: {profile: autonomous_formal, review_merge: skip}
repetitions: 3
timeout_per_run: 3600
```

### Comparison Report

Output: `verify-logs/tier-comparison-{date}.md`

```
| Metric              | Minimal (n=3) | Medium (n=3) | Full (n=3)  |
|---------------------|---------------|--------------|-------------|
| App runs            | 3/3 (100%)    | 3/3 (100%)   | 2/3 (67%)   |
| Tests pass          | 1/3 (33%)     | 3/3 (100%)   | 2/3 (67%)   |
| Specs created       | 0/3 (0%)      | 1/3 (33%)    | 3/3 (100%)  |
| Avg wall time       | 180s          | 420s          | 1200s       |
| Workflow violations | n/a           | 2.3 avg      | 0.3 avg     |
```

### Why This Matters

If Tier A (bare CLAUDE.md) produces working apps 90% of the time and Tier C only marginally improves that at 6x the time cost, we'd know to simplify. If Tier C consistently produces better-tested, better-structured code, the complexity is justified. If Tier B is the sweet spot, we might default to lighter enforcement.

### Files
- Create: `.agentic/lib/auto/tier_experiment.py`, `.agentic/lib/auto/experiments/complexity_tiers.yaml`
- Modify: `framework_verify.py` (add `setup_project_tier()`)
- Create: `tests/test_tier_experiment.py`
- Modify: `ag.sh` (add `ag auto tier-experiment` command)

---

## Delivery Plan (Parallel Execution)

**Foundation first** (shared dependency): Framework execution log (`fwlog.sh`) — 1-2 days. All three parts benefit from this.

Then **three parallel tracks**:

| Track | Part | Steps | Effort |
|-------|------|-------|--------|
| **A** | QA Registry | 1. `qa_registry.py` scanner → 2. `docs/QA_REGISTRY.md` generator → 3. `ag qa` command → 4. freshness check in validate_framework.sh | 3-4 days |
| **B** | Simulation Testing | 1. SequenceChecker in session-analyze.py → 2. PhaseChecker in framework_verify.py → 3. Extend todo_app.yaml + cli_tool.yaml → 4. framework.log-based checks | 1.5 weeks |
| **C** | Tier Experiments | 1. `tier_experiment.py` with `setup_project_tier()` → 2. `TierMetrics` + collector → 3. Experiment YAML + runner → 4. Comparison report generator → 5. `ag auto tier-experiment` | 2 weeks |

**After all tracks complete**: Run experiments on `todo_app`, analyze results, document findings in FRAMEWORK_DEVELOPMENT.md, decide on simplifications.

## Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| Tier experiments expensive (3 tiers × 3 reps = 9+ agent runs) | HIGH | Start with `todo_app` only. Consider running a single manual experiment first (one tier, one run) before building full automation. |
| Discovery-mode agents don't commit at phase boundaries | HIGH | Use framework.log as primary phase detector, git archaeology as supplementary. |
| n=3 may be insufficient for meaningful comparison | MEDIUM | Looking for directional signal, not p-values. Increase n if initial results are ambiguous. Report variance. |
| JSONL log format may change across Claude versions | MEDIUM | Existing parser handles variations. Add version detection. Keep parser tolerant of unknown fields. |
| Tier A milestones are meaningless (agent won't create framework artifacts) | MEDIUM | Use universal metrics only (app runs, tests pass, code quality) for cross-tier comparison. Framework-specific metrics reported separately. |
| SequenceChecker overlaps existing hard-coded violations | LOW | Plan for migration: generalize existing checks to YAML declarations over time. |
| framework.log rotation/size management | LOW | Truncate at session start, keep `.log.prev`. Add to gitignore template. |

## Verification

- **Foundation**: Run any `ag` command → `.agentic/session/framework.log` has timestamped entries
- **Track A**: `python3 tests/qa_registry.py && cat docs/QA_REGISTRY.md` shows complete registry with feature-to-test matrix
- **Track B**: `python3 -m pytest tests/test_session_analyze.py tests/test_phase_checker.py -v` passes; `ag auto verify-framework --project todo_app --json` includes phase_expectations + tool_call_expectations results
- **Track C**: `ag auto tier-experiment --scenario todo_app --json` produces comparison report across minimal/medium/full tiers
- **End-to-end**: Tier experiment results inform concrete simplification decisions documented in FRAMEWORK_DEVELOPMENT.md
