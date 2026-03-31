# QA Dashboard

**Framework Version**: 0.77.0 | **Last verified**: 2026-03-31

## Current Status

| Suite | Command | Tests | Status |
|-------|---------|-------|--------|
| **Acceptance criteria** | `bash tests/validate_framework.sh` | 723 | 723 pass, 0 fail |
| **Workflow gate breaker** | `bash tests/test_workflow_breaker.sh` | 23 | 22 pass, 1 known gap |
| **Unit tests** | `bash tests/run_tests.sh` | 21 | 21 pass |
| **LLM behavioral** | `bash tests/llm/harness.sh` | 81 defined | 42/42 last run (Sonnet) |
| **Total** | | **848** | |

## Quick Start

```bash
# Run everything deterministic (< 3 min)
bash tests/validate_framework.sh && bash tests/test_workflow_breaker.sh && bash tests/run_tests.sh

# Run LLM behavioral tests (requires Claude CLI, costs API calls)
bash tests/llm/harness.sh              # all 81 tests
bash tests/llm/harness.sh --critical   # critical only (fast)
```

---

## What Each Suite Tests

### validate_framework.sh — Acceptance Criteria (723 tests)

Verifies every shipped feature's acceptance criteria structurally. Runs in ~60s, no API calls.

| Category | Tests | What it catches |
|----------|-------|----------------|
| Feature ACs (F-001 through F-036) | ~550 | Feature contracts not met |
| Enforcement chains (E-PLAN, E-DOC, E-SPEC) | 21 | Rule missing from any instruction layer |
| Profile presets + settings | ~30 | Setting defaults, enum validation |
| Pre-commit gates | ~20 | Shipped spec protection, staleness |
| V2 state machine + roles | ~40 | Role prompts, transitions, conventions |
| Structural (file/dir existence) | ~60 | Missing scripts, templates, configs |

**Key insight**: Enforcement-chain tests (E-PLAN-001–009, E-DOC-001–008, E-SPEC-001–003) verify that each behavioral rule exists across ALL instruction layers simultaneously — CLAUDE.md template, skills, memory-seed, hooks, gates, violations.yaml. A rule missing from one layer means agents can skip it.

### test_workflow_breaker.sh — Integration (23 tests)

Systematically tries to **break the autonomous workflow** at every stage. Sets up real project structures and attempts to bypass gates.

| Stage | Tests | What it tries to break |
|-------|-------|----------------------|
| Planning | 2 | Can you plan an unregistered feature? |
| Implementation | 4 | Skip contract? Skip plan review? Use DRAFT plan? |
| Backlog | 2 | Implement out of order? |
| WIP conflict | 1 | Start second feature while one is active? |
| Completion (ag done) | 3 | Ship without plan? Without docs? |
| Bypass escapes | 2 | Does SKIP_SPEC_CHECK actually bypass? |
| State machine + gates | 7 | Skip states? Gates block without artifacts? |
| Settings control | 2 | Does toggling settings enable/disable gates? |

**Known gap**: WIP detection fails when `PROJECT_ROOT` differs from script path (agents_helpers.py resolution issue).

### run_tests.sh — Unit Tests (21 tests)

Fast Python unit tests. No external dependencies needed.

| Module | Tests | What it validates |
|--------|-------|-------------------|
| query_features.py | 15 | Feature filtering, hierarchy, status queries |
| validate_specs.py | 6 | Circular deps, invalid refs, self-deps |

### LLM Behavioral Tests — Agent Compliance (81 tests)

Sends prompts to a real LLM and verifies agent behavior. Requires Claude CLI.

| Section | Tests | What it validates |
|---------|-------|-------------------|
| Session management | 8 | Greeting, WIP recovery, session end, staleness |
| Trigger word routing | 23 | "build", "fix", "commit" route to correct workflow |
| Workflow compliance | 13 | Plan-before-code, spec-first, auto-continue, docs-before-PR |
| Artifact maintenance | 8 | Journal, status, features updated at checkpoints |
| Token efficiency | 3 | Uses scripts, avoids full file reads |
| Anti-hallucination | 3 | No fabricated methods, config, schema |
| Commit gates | 5 | WIP blocks, no auto-commit, untracked files |
| Other (NFR, multi-agent, profiles, brownfield) | 18 | Specialized scenarios |

---

## Test Files

```
tests/
  validate_framework.sh          # Acceptance criteria (723 tests)
  test_workflow_breaker.sh        # Workflow gate breaker (23 tests)
  run_tests.sh                    # Unit test runner
  test_*.py                       # Python unit tests (~70 files)
  test_*.sh                       # Shell tests (~15 files)
  llm/
    harness.sh                    # LLM test runner
    test_definitions.json         # Test registry (81 tests)
    tests/                        # Test scripts (84 files)
    results/                      # Historical run results
    QA_GUIDE.md                   # How to run + interpret LLM tests
    README.md                     # LLM harness documentation
  VERIFICATION_REPORT.md          # Single source of truth for results
  TRACEABILITY_MATRIX.md          # Principles -> features -> tests map
  LLM_TEST_PLAN.md                # Full LLM test scenarios
```

---

## Adding Tests

**New feature?** Add acceptance criteria to `validate_framework.sh`:
```bash
if grep -q "expected_pattern" "$FILE"; then
  pass "F-XXX AC-N: description"
else
  fail "F-XXX AC-N: description"
fi
```

**New enforcement rule?** Add chain test verifying it exists in ALL layers:
```bash
# E-XXX-001: Rule must exist in CLAUDE.md template
if grep -q "rule text" .agentic/lib/agents/claude/CLAUDE.md; then
  pass "E-XXX-001: CLAUDE.md template has rule"
else
  fail "E-XXX-001: CLAUDE.md template missing rule"
fi
# Repeat for: skill file, memory-seed, hooks, gates
```

**New workflow gate?** Add to `test_workflow_breaker.sh`:
```bash
TEST_DIR=$(create_test_project formal)
# Set up scenario that should be blocked
OUTPUT=$(run_ag "$TEST_DIR" <command>)
if echo "$OUTPUT" | grep -qi "BLOCKED"; then
  pass "GATE-XX: description"
else
  fail "GATE-XX: description"
fi
cleanup
```

**New agent behavior?** Add LLM test in `tests/llm/tests/NNN_name.sh`:
```bash
setup_test_project "formal"
send_prompt "your prompt"
FAILURES=0
check_output_contains "expected" "description" || ((FAILURES++))
cleanup_test_project
[[ $FAILURES -eq 0 ]]
```

---

## Known Gaps

| Gap | Priority | Notes |
|-----|----------|-------|
| LLM tests 098-101 not yet run | High | Defined but need Claude CLI execution |
| WIP detection in isolated contexts | Medium | agents_helpers.py PROJECT_ROOT |
| tests/README.md not in doc registry | Medium | QA docs not covered by docs_gate |
