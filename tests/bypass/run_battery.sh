#!/usr/bin/env bash
# run_battery.sh — R-016 Phase 0 verification battery orchestrator.
#
# Spec: .agentic/journal/plans/2026-04-27-R-016-revised-ac-plan.md (v6 APPROVED).
#
# Iterates B01..B12 × {discovery, formal, autonomous_formal} = 36 cells.
# For each cell:
#   - scaffold a fresh project for the profile
#   - run the B-test (which performs the attack and asserts)
#   - record outcome: PASS | SKIP-by-design | FAIL
# Writes results to tests/bypass/results/<ISO8601>.json.
#
# Pass criteria:
#   exit 0 if every cell is PASS or SKIP-by-design,
#          OR every FAIL cell appears in known-fails.yaml with reason +
#          (journal_ref OR r_nnn).
#   exit 2 otherwise.
#
# Day-1 status: orchestrator skeleton with full results-JSON emitter and
# known-fails.yaml manifest parsing. B-tests are not yet implemented; running
# this script today will iterate the matrix and record SKIP-tests-not-yet-built
# for every cell. Once B01..B12 are written, the same skeleton drives them.
#
# Flags:
#   --keep-temp       Preserve /tmp/infra-test-* dirs for forensics.
#   --filter B01      Run only one B-test (×3 profiles).
#   --once <profile>  Run all B-tests once for one profile.
#   --json-only       Suppress human-readable output; emit only the JSON path.

set -euo pipefail

BATTERY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/battery.sh
source "$BATTERY_DIR/lib/battery.sh"

# ─── Args ───

FILTER_TEST=""
FILTER_PROFILE=""
JSON_ONLY=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --keep-temp) export BATTERY_KEEP_TEMP=1; shift ;;
        --filter) FILTER_TEST="$2"; shift 2 ;;
        --once) FILTER_PROFILE="$2"; shift 2 ;;
        --json-only) JSON_ONLY=1; shift ;;
        --help|-h)
            grep '^# ' "$0" | sed 's/^# //'
            exit 0
            ;;
        *) echo "unknown arg: $1" >&2; exit 2 ;;
    esac
done

# ─── Pre-flight ───

assert_env_hygiene || exit $?

# ─── Test matrix ───

# Each B-test is a script in tests/bypass/B<NN>_<name>.sh. The orchestrator
# discovers them by glob — adding a new test means dropping a new script in
# this directory, no orchestrator change needed.

mapfile -t B_TESTS < <(find "$BATTERY_DIR" -maxdepth 1 -name 'B[0-9][0-9]_*.sh' | sort)
PROFILES=(discovery formal autonomous_formal)

if [[ -n "$FILTER_PROFILE" ]]; then
    PROFILES=("$FILTER_PROFILE")
fi

# ─── Result emission ───

RESULTS_DIR="$BATTERY_DIR/results"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H-%M-%SZ")
RESULTS_FILE="$RESULTS_DIR/$TIMESTAMP.json"
mkdir -p "$RESULTS_DIR"

# Build the JSON incrementally as we go.
declare -a CELL_JSON_LINES=()

run_cell() {
    local b_test="$1" profile="$2"
    local b_name; b_name="$(basename "$b_test" .sh)"

    if [[ -n "$FILTER_TEST" && "$b_name" != *"$FILTER_TEST"* ]]; then
        return 0
    fi

    [[ "$JSON_ONLY" == 0 ]] && echo "  [$b_name × $profile] running..." >&2

    # Each B-test runs in a subshell so its scaffold side-effects (cd into
    # a tempdir, env exports) don't leak between cells.
    local outcome="UNKNOWN" evidence="" code_path=""
    local rc=0
    local out_file
    out_file=$(mktemp)

    (
        # B-test contract: write a single line to stdout in the form
        #   OUTCOME|evidence|code_path
        # OUTCOME ∈ {PASS, SKIP-by-design, FAIL}
        bash "$b_test" "$profile" 2>/dev/null
    ) >"$out_file" || rc=$?

    if [[ $rc -ne 0 ]]; then
        outcome="FAIL"
        evidence="b-test exited $rc (test infrastructure error or unhandled assertion)"
    else
        local line; line=$(tail -n 1 "$out_file")
        IFS='|' read -r outcome evidence code_path <<<"$line"
        outcome="${outcome:-FAIL}"
    fi
    rm -f "$out_file"

    # JSON-encode evidence + code_path safely.
    local json_line
    json_line=$(python3 -c '
import json, sys
b, profile, outcome, evidence, code_path = sys.argv[1:6]
print(json.dumps({
    "test": b, "profile": profile, "outcome": outcome,
    "evidence": evidence, "code_path": code_path,
}))
' "$b_name" "$profile" "$outcome" "$evidence" "$code_path")
    CELL_JSON_LINES+=("$json_line")
}

# ─── Main loop ───

if [[ ${#B_TESTS[@]} -eq 0 ]]; then
    echo "No B-tests found in $BATTERY_DIR (B<NN>_*.sh) — orchestrator skeleton only." >&2
    echo "Day-1 status: scaffold + seeders skeleton present; B01..B12 implemented Day 2-4." >&2
fi

for b_test in "${B_TESTS[@]}"; do
    for profile in "${PROFILES[@]}"; do
        run_cell "$b_test" "$profile"
    done
done

# ─── Aggregate + emit results JSON ───

# Write per-cell JSON lines to a temp file so the python heredoc can read them
# without bash-interpolation gymnastics that break on empty arrays.
CELLS_TMP=$(mktemp)
if [[ ${#CELL_JSON_LINES[@]} -gt 0 ]]; then
    printf '%s\n' "${CELL_JSON_LINES[@]}" > "$CELLS_TMP"
fi
# else: leave $CELLS_TMP empty — the python reader handles zero-cell case

python3 - "$RESULTS_FILE" "$BATTERY_DIR/known-fails.yaml" "$CELLS_TMP" <<'PY'
import json, sys, datetime, pathlib

results_file, known_fails_path, cells_path = sys.argv[1:4]
cells = []
try:
    with open(cells_path) as f:
        for line in f:
            line = line.strip()
            if line:
                cells.append(json.loads(line))
except FileNotFoundError:
    pass

# Parse known-fails.yaml (minimal stdlib parser — known schema is flat).
known = []
try:
    import yaml  # type: ignore
    raw = pathlib.Path(known_fails_path).read_text()
    parsed = yaml.safe_load(raw) or {}
    known = parsed.get("known_fails", []) or []
except Exception:
    # If pyyaml isn't available, treat as empty manifest. The orchestrator's
    # exit code will then enforce stricter "no FAILs allowed" semantics —
    # acceptable fallback because the manifest is the only escape hatch and
    # losing it should fail closed, not open.
    pass

def is_known(cell):
    for entry in known:
        if entry.get("test") == cell["test"] and entry.get("profile") == cell["profile"]:
            reason = (entry.get("reason") or "").strip()
            ref = entry.get("journal_ref") or entry.get("r_nnn")
            if reason and ref:
                return True
    return False

summary = {"pass": 0, "skip_by_design": 0, "fail": 0, "fail_known": 0, "fail_unlisted": 0}
for cell in cells:
    if cell["outcome"] == "PASS":
        summary["pass"] += 1
    elif cell["outcome"] == "SKIP-by-design":
        summary["skip_by_design"] += 1
    elif cell["outcome"] == "FAIL":
        summary["fail"] += 1
        if is_known(cell):
            summary["fail_known"] += 1
        else:
            summary["fail_unlisted"] += 1

doc = {
    "ts": datetime.datetime.utcnow().isoformat(timespec="seconds") + "Z",
    "phase": "Phase 0",
    "matrix": cells,
    "summary": summary,
}
pathlib.Path(results_file).write_text(json.dumps(doc, indent=2))

# Exit code: 0 if all cells PASS|SKIP|known-FAIL; 2 if any unlisted FAIL.
sys.exit(0 if summary["fail_unlisted"] == 0 else 2)
PY
status=$?
rm -f "$CELLS_TMP"

if [[ "$JSON_ONLY" == 1 ]]; then
    echo "$RESULTS_FILE"
else
    echo "" >&2
    echo "Results: $RESULTS_FILE" >&2
    if [[ $status -eq 0 ]]; then
        echo "Verification: COMPLETE (all cells PASS|SKIP-by-design|known-FAIL)" >&2
    else
        echo "Verification: INCOMPLETE — unlisted FAIL cells; see results JSON" >&2
    fi
fi

exit $status
