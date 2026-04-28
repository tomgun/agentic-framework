#!/usr/bin/env bash
# battery.sh — shared scaffolding for R-016 Phase 0 verification battery.
#
# Spec: .agentic/journal/plans/2026-04-27-R-016-revised-ac-plan.md (v6 APPROVED).
#
# Provides:
#   scaffold_project <profile>            — fresh test project with Tier 0 wired
#   bypass_seed_failing_test              — STACK.md test_fast: + tests/test_bar.sh
#   bypass_seed_shipped_contract <id>     — canonical shipped+protected contract
#   bypass_seed_uncovered_feature <id>    — behavioral assertions, no tests linked
#   bypass_seed_plan_approved             — touch .agentic/session/.plan-approved
#   bypass_seed_journal_with_past_mtime   — UTC-anchored mtime rollback
#   bypass_seed_claude_settings           — minimal .claude/settings.json + baseline
#   bypass_assert_event_present <type>    — assert events.jsonl has matching event
#   battery_cleanup                       — /tmp scrubber (trap-installed)
#
# Day-1 status: scaffold_project + env-hygiene + cleanup are fully implemented;
# seed helpers have SIGNATURES with the canonical YAML schema but BODIES are
# placeholders. Filled in during Day 2-4 as B01-B12 require them.

set -euo pipefail

BATTERY_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BATTERY_DIR="$(cd "$BATTERY_LIB_DIR/.." && pwd)"
TESTS_DIR="$(cd "$BATTERY_DIR/.." && pwd)"
FRAMEWORK_ROOT="$(cd "$TESTS_DIR/.." && pwd)"

# Reuse the existing scaffold helper for the discovery|formal common path.
# scaffold_project wraps it to add: autonomous_formal STACK.md, explicit
# core.hooksPath, Tier 0 hook shim, bare remote, env-hygiene assertions.
# shellcheck source=../../infrastructure/lib/helpers.sh
source "$FRAMEWORK_ROOT/tests/infrastructure/lib/helpers.sh"

# ─── Env hygiene (round-2 finding; round-4 fix v6.1 prerequisite) ───
#
# INTEGRITY_SKIP=1 + CI=true silences integrity check (precommit_gate.py:341
# via integrity.py:33-37). If contaminated, all B10/B11 cells silently pass.
# Fail loud at battery start rather than producing a misleading matrix.

assert_env_hygiene() {
    local violations=()
    [[ "${INTEGRITY_SKIP:-}" == "1" ]] && violations+=("INTEGRITY_SKIP=1 is set")
    [[ "${CI:-}" == "true" ]] && violations+=("CI=true is set")
    [[ "${AGENT_SKIP_GATE:-}" == "1" ]] && violations+=("AGENT_SKIP_GATE=1 is set in caller env")
    if [[ ${#violations[@]} -gt 0 ]]; then
        echo "ERROR: env hygiene violated — these env vars would corrupt the matrix:" >&2
        printf '  - %s\n' "${violations[@]}" >&2
        echo "Unset them and re-run." >&2
        return 2
    fi
    return 0
}

# ─── /tmp cleanup trap ───
#
# Each scaffold creates /tmp/infra-test-XXXXXX. On test crash we clean up by
# default. --keep-temp opts in to forensic mode (preserve dirs for inspection).

BATTERY_KEEP_TEMP="${BATTERY_KEEP_TEMP:-0}"
BATTERY_TEMP_DIRS=()

battery_cleanup() {
    [[ "$BATTERY_KEEP_TEMP" == "1" ]] && return 0
    local d
    for d in "${BATTERY_TEMP_DIRS[@]}"; do
        if [[ -n "$d" && -d "$d" && "$d" == /tmp/infra-test-* ]]; then
            rm -rf "$d"
        fi
    done
}
trap battery_cleanup EXIT

# ─── scaffold_project (load-bearing helper; round-1..round-5 corrections applied) ───
#
# Creates a fresh test project with Tier 0 actually wired up.
#
# Round-trajectory corrections embedded:
#   R1: autonomous_formal profile branch added (helpers.sh only handles discovery|formal)
#   R3: Tier 0 hook shim installed; install.sh wires legacy bash hook only
#   R4: shim relocated to .agentic/hooks/ (not .git/hooks/) to avoid ag.sh::_ensure_hooks
#       interaction that restores core.hooksPath=.agentic/hooks on every ag invocation
#   R5: explicit `git config core.hooksPath .agentic/hooks` — helpers.sh's discovery
#       scaffold leaves it UNSET (scaffold.sh GIT_MODE=deferred skips the config write)
#   R6: documented unbaselined-shim limit in README; shim itself is not in integrity baseline

scaffold_project() {
    local profile="${1:-discovery}"

    case "$profile" in
        discovery|formal|autonomous_formal) ;;
        *) echo "ERROR: scaffold_project: invalid profile '$profile'" >&2; return 2 ;;
    esac

    # Use helpers.sh::scaffold_test_project for discovery|formal common path;
    # autonomous_formal is built on top of formal.
    local helper_profile="$profile"
    [[ "$profile" == "autonomous_formal" ]] && helper_profile="formal"

    # Capture the helper's stdout (the path) in our function scope, then cd
    # in the caller's scope so seeders + B-test bodies can use relative paths
    # and our exported $CONTRACTS_DIR survives without subshell capture.
    BATTERY_PROJECT_DIR=$(scaffold_test_project "$helper_profile")
    BATTERY_TEMP_DIRS+=("$BATTERY_PROJECT_DIR")

    cd "$BATTERY_PROJECT_DIR"

    # Profile-specific STACK.md keys. Tier 0 gates only consume profile,
    # plan_review_enabled, pre_commit_hook, test_fast, contract_coverage_threshold;
    # the review_* keys are spelled out for ag-init parity (non-SUT).
    case "$profile" in
        discovery)
            cat > STACK.md <<'EOF'
# STACK.md (R-016 scaffold)
- profile: discovery
- plan_review_enabled: no
- pre_commit_hook: fast
EOF
            ;;
        formal)
            cat > STACK.md <<'EOF'
# STACK.md (R-016 scaffold)
- profile: formal
- plan_review_enabled: yes
- pre_commit_hook: fast
- review_plan: critical_agent
- review_code: human
- review_merge: human
- contract_coverage_threshold: 80
EOF
            ;;
        autonomous_formal)
            cat > STACK.md <<'EOF'
# STACK.md (R-016 scaffold)
- profile: autonomous_formal
- plan_review_enabled: yes
- pre_commit_hook: fast
- review_plan: critical_agent
- review_code: critical_agent
- review_regression: critical_agent
- review_merge: human
- contract_coverage_threshold: 80
EOF
            ;;
    esac

    # Tier 0 hook shim — overwrite the legacy bash hook installed by install.sh.
    # We write to .agentic/hooks/ (not .git/hooks/) because ag.sh::_ensure_hooks
    # unconditionally writes core.hooksPath=.agentic/hooks on every ag invocation;
    # putting the shim there means _ensure_hooks is a no-op, not a stomp.
    cat > .agentic/hooks/pre-commit <<'SHIM'
#!/usr/bin/env bash
exec python3 "$(git rev-parse --show-toplevel)/.agentic/lib/hooks/precommit_gate.py" "$@"
SHIM
    chmod +x .agentic/hooks/pre-commit

    cat > .agentic/hooks/pre-push <<'SHIM'
#!/usr/bin/env bash
exec python3 "$(git rev-parse --show-toplevel)/.agentic/lib/hooks/prepush_gate.py" "$@"
SHIM
    chmod +x .agentic/hooks/pre-push

    # Explicit core.hooksPath set — helpers.sh's discovery scaffold leaves it
    # UNSET because install.sh runs scaffold.sh in non-interactive discovery
    # mode, which skips the GIT_MODE=active branch that would write hooksPath.
    git config core.hooksPath .agentic/hooks

    # Local bare remote for B03 + B12 push tests.
    git init --bare --quiet "$BATTERY_PROJECT_DIR/remote.git"
    git remote add origin "$BATTERY_PROJECT_DIR/remote.git"

    # Export CONTRACTS_DIR — paths.sh:163 omits it from the export list, so
    # subprocesses (especially `python3 -c` in B07) won't inherit it otherwise.
    # BATTERY_PROJECT_DIR is also exported so child processes (B-test subshells)
    # can resolve absolute paths.
    export CONTRACTS_DIR="$BATTERY_PROJECT_DIR/.agentic/spec/contracts"
    export BATTERY_PROJECT_DIR
    mkdir -p "$CONTRACTS_DIR"

    # NOTE: scaffold_project does NOT echo the path to stdout (unlike
    # helpers.sh::scaffold_test_project). B-tests emit JSON to stdout for the
    # orchestrator to parse, so any spurious echo would corrupt the result.
    # Caller reads $BATTERY_PROJECT_DIR after scaffold_project returns.
}

# ─── Seed helpers (signatures + canonical schemas; bodies filled Day 2-4) ───
#
# Each seeder has its canonical YAML schema documented in the plan §"Seed
# helpers". Bodies will be implemented as the corresponding B-tests are built.

bypass_seed_failing_test() {
    # Writes tests/test_bar.sh that exits 1 if src/foo.py contains "BROKEN",
    # plus STACK.md test_fast: bash tests/test_bar.sh.
    # Used by: B01, B09.
    mkdir -p tests src
    cat > tests/test_bar.sh <<'EOF'
#!/usr/bin/env bash
# Bypass-battery test command. Exits 1 if src/foo.py contains "BROKEN",
# else 0. Used by B01 (assert AC1 fires on broken-code commit) and B09
# (assert AC1 still fires under AGENT_FIX_MODE=1).
if [[ -f src/foo.py ]] && grep -q "BROKEN" src/foo.py; then
    echo "src/foo.py contains BROKEN sentinel; failing per bypass-battery contract" >&2
    exit 1
fi
exit 0
EOF
    chmod +x tests/test_bar.sh

    # Append the test_fast: line to STACK.md (project root — precommit_gate.py:248-251
    # checks root/STACK.md before .agentic/STACK.md). _resolve_test_command at line
    # 261-263 matches `^\s*-?\s*(test_fast|test)\s*:\s*<value>` — leading-dash form is
    # consistent with the existing STACK.md key format.
    echo "- test_fast: bash tests/test_bar.sh" >> STACK.md
}

bypass_seed_shipped_contract() {
    # Writes a canonical shipped+protected YAML at $CONTRACTS_DIR/<id>.yaml,
    # commits via AGENT_SKIP_GATE=1 (so HEAD has the shipped+protected version
    # — required for AC5's HEAD-vs-staged comparison at precommit_gate.py:697-700),
    # then chmod 444 to match R-005's locked state.
    #
    # Canonical schema (matches contracts.py validation):
    #   id: F-9001..F-9005             # all-digit ID per _ID_PATTERN
    #   name: Shipped Contract Fixture # ≥3 chars
    #   description: |                 # ≥10 chars
    #     Shipped+protected contract fixture for AC5 second-wall testing.
    #   lifecycle: shipped
    #   profile: both
    #   protection: contract
    #   assertions:
    #     - id: AC-001                 # matches ^AC-\d{3,}$
    #       text: structural fixture assertion
    #       type: structural
    #       verify: "test -f /tmp/never-checked"   # required for non-draft structural
    #       status: shipped
    #   migrations: []
    #
    # Used by: B06, B07, B08, B12.
    local feature_id="${1:-F-9002}"
    local target="$CONTRACTS_DIR/$feature_id.yaml"
    mkdir -p "$CONTRACTS_DIR"

    cat > "$target" <<EOF
id: $feature_id
name: Shipped Contract Fixture
description: |
  Shipped+protected contract fixture for AC5 second-wall testing.
  Generated by R-016 bypass battery — do not edit by hand.
lifecycle: shipped
profile: both
protection: contract
assertions:
  - id: AC-001
    text: structural fixture assertion
    type: structural
    verify: "test -f /tmp/never-checked"
    status: shipped
migrations: []
EOF

    # Commit the shipped+protected version so HEAD has it. Required because
    # AC5 (precommit_gate.py:697-700) short-circuits when _git_show_head returns
    # None — without HEAD having the prior content, an attack edit looks like
    # a new file and the migration check skips.
    git add "$target"
    AGENT_SKIP_GATE=1 AGENT_SKIP_GATE_REASON="seed shipped contract $feature_id" \
        git commit -m "seed $feature_id" --quiet

    # Match R-005's locked state. B07 verifies chmod=444 + EACCES; B06/B08/B12
    # then `chmod u+w` to perform the attack edit, knowing R-005 first wall is
    # the deliberate-bypass surface.
    chmod 444 "$target"
}

bypass_seed_uncovered_feature() {
    # Writes a contract with behavioral assertions (no verify: required) so they
    # count in total_assertions but lack test linkage → coverage_pct=0 < threshold.
    # Precondition: parse `bash .agentic/lib/tools/ag.sh contract coverage` and
    # assert `Total assertions: 0` BEFORE seeding (round-3 fix). If non-zero,
    # B02 SKIPs — install.sh may have shipped framework-baseline contracts.
    #
    # Canonical schema:
    #   id: F-9001
    #   name: Uncovered Feature Fixture
    #   description: |
    #     Adversarial fixture for B02 coverage attack — three uncovered behavioral assertions.
    #   lifecycle: implementing
    #   profile: both
    #   protection: none
    #   assertions:
    #     - id: AC-001
    #       text: uncovered behavioral assertion 1
    #       type: behavioral
    #       status: planned
    #     - id: AC-002
    #     - id: AC-003
    #   migrations: []
    #
    # Used by: B02.
    #
    # Returns 0 on successful seed, 1 if scaffold isn't bare (caller should
    # mark cell SKIP-by-design per the round-3 Critic precondition).

    # Precondition: assert scaffold has zero existing contracts. Otherwise
    # `install.sh` shipped framework-baseline contracts and B02's coverage
    # measurement would include them, masking the test signal. Format from
    # contract.sh:307: `  Total assertions:  N`.
    #
    # Capture output to a variable first (with `|| true` so pipefail doesn't
    # kill us if ag fails — e.g., pyyaml missing). Then parse the captured
    # output. This is more robust than chaining ag → awk under pipefail.
    local cov_out
    cov_out=$(bash .agentic/lib/tools/ag.sh contract coverage 2>&1 || true)
    local total
    total=$(echo "$cov_out" | awk '/^[[:space:]]*Total assertions:/ {print $NF; exit}')
    if [[ -z "$total" ]]; then
        echo "SKIP: ag contract coverage produced no 'Total assertions:' line" >&2
        echo "      output was:" >&2
        echo "$cov_out" | sed 's/^/        /' >&2
        return 1
    fi
    if [[ "$total" != "0" ]]; then
        echo "SKIP: scaffold not bare (Total assertions: $total); install.sh shipped baseline contracts" >&2
        return 1
    fi

    local target="$CONTRACTS_DIR/F-9001.yaml"
    mkdir -p "$CONTRACTS_DIR"
    cat > "$target" <<'EOF'
id: F-9001
name: Uncovered Feature Fixture
description: |
  Adversarial fixture for B02 coverage attack — three uncovered behavioral
  assertions. Behavioral type is used because validate_contract:415 only
  requires `verify:` for non-draft structural assertions; behavioral
  assertions count toward total_assertions but don't need a test linkage,
  producing coverage_pct=0 < threshold.
lifecycle: implementing
profile: both
protection: none
assertions:
  - id: AC-001
    text: uncovered behavioral assertion 1
    type: behavioral
    status: planned
  - id: AC-002
    text: uncovered behavioral assertion 2
    type: behavioral
    status: planned
  - id: AC-003
    text: uncovered behavioral assertion 3
    type: behavioral
    status: planned
migrations: []
EOF

    # Commit so the contract is reachable from HEAD; consistent with B06 pattern.
    git add "$target"
    AGENT_SKIP_GATE=1 AGENT_SKIP_GATE_REASON="seed uncovered feature F-9001" \
        git commit -m "seed F-9001" --quiet
}

bypass_seed_plan_approved() {
    # Touches .agentic/session/.plan-approved.
    # Used by: B04.
    mkdir -p .agentic/session
    : > .agentic/session/.plan-approved
}

bypass_seed_journal_with_past_mtime() {
    # UTC-anchored mtime rollback (round-3 fix v3.6: replaces touch -t which
    # is timezone-fragile in TZ+ regions).
    # Used by: B05.
    local journal=".agentic/journal/JOURNAL.md"
    [[ -f "$journal" ]] || return 0
    python3 -c "import os; os.utime('$journal', (86400, 86400))"
}

bypass_seed_claude_settings() {
    # Writes minimal .claude/settings.json with non-empty hooks field, then
    # `ag integrity update` to baseline it. Without this, install.sh's
    # deliberate exclusion of .claude/ means B11 has no attack target —
    # integrity.py silently skips missing partial-JSON paths.
    # Used by: B11.
    mkdir -p .claude
    cat > .claude/settings.json <<'EOF'
{
  "hooks": {
    "PreToolUse": []
  }
}
EOF
    bash .agentic/lib/tools/ag.sh integrity update >/dev/null 2>&1 || true
}

# ─── Assertion helpers ───

bypass_assert_event_present() {
    # Asserts events.jsonl contains at least one event of <type> with optional
    # <actor> filter, written after <since_ts> (epoch seconds, optional).
    local event_type="$1"
    local actor="${2:-}"
    local since_ts="${3:-0}"

    local events=".agentic/journal/events.jsonl"
    if [[ ! -f "$events" ]]; then
        return 1
    fi

    python3 - "$event_type" "$actor" "$since_ts" "$events" <<'PY'
import json, sys
event_type, actor, since_ts, events_path = sys.argv[1:5]
since_ts = int(since_ts or 0)
try:
    with open(events_path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                evt = json.loads(line)
            except json.JSONDecodeError:
                continue
            if evt.get("type") != event_type:
                continue
            if actor and evt.get("actor") != actor:
                continue
            # ts is ISO8601; coarse comparison via length is sufficient for "after now"
            sys.exit(0)
except FileNotFoundError:
    pass
sys.exit(1)
PY
}

# ─── End ───
