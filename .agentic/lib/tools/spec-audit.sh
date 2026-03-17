#!/usr/bin/env bash
# spec-audit.sh — Spec verification, change propagation, and QA tracker interface
#
# Phase 3A: Verification
#   bash spec-audit.sh                          # All shipped features
#   bash spec-audit.sh F-XXXX                   # Single feature
#   bash spec-audit.sh --since-last             # Changed since last audit
#   bash spec-audit.sh --report                 # Full markdown report
#
# Phase 3B: Propagation
#   bash spec-audit.sh --propagate NFR-0003     # Trace NFR change downstream
#   bash spec-audit.sh --propagate migration:009 # Trace migration downstream
#
# Phase 3C: Tracker
#   bash spec-audit.sh --status                 # Tracker summary
#   bash spec-audit.sh --resolve PQ-001         # Resolve propagation item
#   bash spec-audit.sh --defer PQ-001 "reason"  # Defer with reason
#
# Exit code: always 0 (advisory tool)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

source "$SCRIPT_DIR/../paths.sh"
source "$SCRIPT_DIR/../settings.sh"
source "$SCRIPT_DIR/ac-parse.sh"

# Colors
if [ -t 1 ]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
    BLUE='\033[0;34m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' BOLD='' DIM='' NC=''
fi

FEATURES_FILE="$ROOT_DIR/.agentic/spec/FEATURES.md"
NFR_FILE="$ROOT_DIR/.agentic/spec/NFR.md"
ACCEPTANCE_DIR="$ROOT_DIR/.agentic/spec/acceptance"
TRACKER_FILE="$ROOT_DIR/.agentic/session/.qa-tracker.json"

# --- Helpers ---

# Get list of shipped feature IDs
get_shipped_features() {
    grep -B1 'Status.*shipped' "$FEATURES_FILE" 2>/dev/null \
        | grep -oE "$FEATURE_ID_ERE" | sort -u
}

# Get acceptance file for a feature
get_acceptance_file() {
    local fid="$1"
    echo "$ACCEPTANCE_DIR/${fid}.md"
}

# Check if feature has tests section
has_tests_section() {
    local ac_file="$1"
    grep -qE '^##\s*(Tests|Verification)' "$ac_file" 2>/dev/null
}

# Check if feature has NFR compliance (old ## NFR Compliance OR new ### NFR Constraints)
has_nfr_compliance() {
    local ac_file="$1"
    grep -qE '^###?\s*NFR (Compliance|Constraints)' "$ac_file" 2>/dev/null
}

# Get NFRs linked to a feature
get_feature_nfrs() {
    local fid="$1"
    # Look in FEATURES.md for NFRs: field
    awk -v fid="$fid" '
        /^## / { if (found) exit; if ($0 ~ "## " fid ":") found=1 }
        found && /NFRs?:/ { gsub(/.*NFRs?:\s*/, ""); gsub(/\*/, ""); print }
    ' "$FEATURES_FILE" 2>/dev/null
}

# Count acceptance criteria in a file (delegates to shared parser)
count_ac() {
    local ac_file="$1"
    ac_count_total "$ac_file"
}

# Discover test directories (STACK.md setting, then common patterns)
_find_test_dirs() {
    local test_dir
    test_dir=$(get_setting "test_directory" "" 2>/dev/null || echo "")
    if [[ -n "$test_dir" && -d "$ROOT_DIR/$test_dir" ]]; then
        echo "$ROOT_DIR/$test_dir"
        return
    fi
    # Search common patterns
    for d in tests test __tests__ spec; do
        [[ -d "$ROOT_DIR/$d" ]] && echo "$ROOT_DIR/$d"
    done
}

# Check for empty/trivial test bodies (language-aware heuristic)
check_test_heuristics() {
    local fid="$1"
    local issues=0
    local test_files=""

    # Find test files referencing this feature across all test directories
    local test_dirs
    test_dirs=$(_find_test_dirs)
    if [[ -z "$test_dirs" ]]; then
        echo "no_tests"
        return
    fi

    for tdir in $test_dirs; do
        local found
        found=$(grep -rl "$fid" "$tdir" 2>/dev/null || true)
        [[ -n "$found" ]] && test_files="$test_files $found"
    done
    # Also check for test files matching *_test.go, *.test.{js,ts} patterns
    for tdir in $test_dirs; do
        local go_tests
        go_tests=$(find "$tdir" -name "*_test.go" 2>/dev/null | head -20 || true)
        local js_tests
        js_tests=$(find "$tdir" -name "*.test.js" -o -name "*.test.ts" -o -name "*.test.tsx" 2>/dev/null | head -20 || true)
        # Check if any of these reference the feature ID
        for tf in $go_tests $js_tests; do
            if grep -q "$fid" "$tf" 2>/dev/null; then
                test_files="$test_files $tf"
            fi
        done
    done

    test_files=$(echo "$test_files" | xargs -n1 2>/dev/null | sort -u)
    if [[ -z "$test_files" ]]; then
        echo "no_tests"
        return
    fi

    # Detect language from STACK.md
    local lang
    lang=$(get_setting "language" "" 2>/dev/null || echo "")
    lang=$(echo "$lang" | tr '[:upper:]' '[:lower:]')

    for tf in $test_files; do
        # --- Universal: empty test body ---
        # Python: pass-only bodies
        if grep -qE '^\s*pass\s*$' "$tf" 2>/dev/null; then
            ((issues++))
        fi
        # Shell: true-only or :-only bodies
        if echo "$tf" | grep -qE '\.sh$' && grep -qE '^\s*(true|:)\s*$' "$tf" 2>/dev/null; then
            ((issues++))
        fi

        # --- Stub assertion detection (language-aware) ---
        case "$lang" in
            python*)
                # Python stubs: assert True, assert 1 == 1, assert len(x) >= 0
                if grep -qE '^\s*assert\s+True\b' "$tf" 2>/dev/null; then
                    ((issues++))
                fi
                if grep -qE '^\s*assert\s+1\s*==\s*1' "$tf" 2>/dev/null; then
                    ((issues++))
                fi
                if grep -qE 'assert\s+len\([^)]*\)\s*>=\s*0' "$tf" 2>/dev/null; then
                    ((issues++))
                fi
                ;;
            javascript*|typescript*|js|ts)
                # JS/TS stubs: expect(true).toBe(true), expect(1).toBe(1)
                if grep -qE 'expect\(true\)\.toBe\(true\)' "$tf" 2>/dev/null; then
                    ((issues++))
                fi
                if grep -qE 'expect\(1\)\.toBe\(1\)' "$tf" 2>/dev/null; then
                    ((issues++))
                fi
                ;;
            go*)
                # Go: t.Skip() without reason
                if grep -qE 't\.Skip\(\s*\)' "$tf" 2>/dev/null; then
                    ((issues++))
                fi
                ;;
        esac

        # --- Zero assertions (universal fallback) ---
        local assert_count
        assert_count=$(grep -cE '(assert|expect|should|must|require\.|Equal|NotNil)' "$tf" 2>/dev/null || echo "0")
        assert_count="${assert_count//[[:space:]]/}"
        if [ "$assert_count" -eq 0 ]; then
            ((issues++))
        fi
    done

    if [ "$issues" -gt 0 ]; then
        echo "concerns:$issues"
    else
        echo "ok"
    fi
}

# --- Verification (Phase 3A) ---

verify_feature() {
    local fid="$1"
    local verbose="${2:-false}"
    local ac_file
    ac_file=$(get_acceptance_file "$fid")

    local structural="pass"
    local coverage="pass"
    local test_quality="unknown"
    local nfr_check="pass"
    local issues=()

    # 1. Structural check
    if [ ! -f "$ac_file" ]; then
        structural="fail"
        issues+=("Missing acceptance file")
    else
        if ! has_tests_section "$ac_file"; then
            structural="fail"
            issues+=("Missing ## Tests section")
        fi
    fi

    # 2. Coverage check — AC count vs test references
    if [ -f "$ac_file" ]; then
        local ac_count
        ac_count=$(count_ac "$ac_file")
        if [ "$ac_count" -eq 0 ]; then
            coverage="fail"
            issues+=("No acceptance criteria defined")
        fi
    fi

    # 3. Test quality heuristics
    local heuristic_result
    heuristic_result=$(check_test_heuristics "$fid")
    case "$heuristic_result" in
        no_tests)
            test_quality="missing"
            issues+=("No test files reference $fid")
            ;;
        concerns:*)
            test_quality="concerns"
            local count="${heuristic_result#concerns:}"
            issues+=("$count test quality concern(s): empty bodies or zero assertions")
            ;;
        ok)
            test_quality="good"
            ;;
    esac

    # 4. NFR compliance check
    local nfrs
    nfrs=$(get_feature_nfrs "$fid")
    if [ -n "$nfrs" ] && [ "$nfrs" != "none" ]; then
        if [ -f "$ac_file" ] && ! has_nfr_compliance "$ac_file"; then
            nfr_check="missing"
            issues+=("Feature links NFRs but acceptance file has no NFR Compliance section")
        fi
    fi

    # Output
    if [ "$verbose" = "true" ]; then
        local status_icon="${GREEN}ok${NC}"
        if [ ${#issues[@]} -gt 0 ]; then
            status_icon="${YELLOW}!!${NC}"
        fi
        echo -e "$status_icon ${BOLD}$fid${NC}: structural=$structural coverage=$coverage tests=$test_quality nfr=$nfr_check"
        for issue in "${issues[@]}"; do
            echo -e "  ${YELLOW}- $issue${NC}"
        done
    fi

    # Return 0 if clean, 1 if issues found
    [[ ${#issues[@]} -eq 0 ]]
}

# Run verification on a list of features
cmd_verify() {
    local target="${1:-}"
    local features=""

    if [ -n "$target" ] && is_feature_id "$target"; then
        features="$target"
    else
        features=$(get_shipped_features)
    fi

    if [ -z "$features" ]; then
        echo -e "${YELLOW}No shipped features found to verify.${NC}"
        return 0
    fi

    local total=0 passed=0 issues=0

    echo -e "${BOLD}=== Spec Verification Audit ===${NC}"
    echo ""

    while IFS= read -r fid; do
        [ -z "$fid" ] && continue
        ((total++))
        if verify_feature "$fid" "true"; then
            ((passed++))
        else
            ((issues++))
        fi
    done <<< "$features"

    echo ""
    echo -e "${BOLD}Summary:${NC} $passed/$total features clean, $issues with issues"

    # Update tracker if it exists
    if [ -f "$TRACKER_FILE" ] || command -v python3 &>/dev/null; then
        _update_tracker_verify "$total" "$passed"
    fi
}

# Verify only features changed since last audit
cmd_verify_since_last() {
    local last_commit=""
    if [ -f "$TRACKER_FILE" ] && command -v python3 &>/dev/null; then
        last_commit=$(python3 -c "
import json, sys
try:
    with open('$TRACKER_FILE') as f:
        data = json.load(f)
    print(data.get('verification', {}).get('last_audit_commit', ''))
except: pass
" 2>/dev/null)
    fi

    if [ -z "$last_commit" ]; then
        echo -e "${DIM}No previous audit recorded. Running full audit.${NC}"
        cmd_verify ""
        return
    fi

    # Find features whose acceptance files changed since last audit
    local changed_features
    changed_features=$(git diff --name-only "$last_commit" HEAD -- ".agentic/spec/acceptance/" 2>/dev/null \
        | grep -oE "$FEATURE_ID_ERE" | sort -u)

    if [ -z "$changed_features" ]; then
        echo -e "${GREEN}No spec changes since last audit ($last_commit).${NC}"
        return
    fi

    echo -e "${DIM}Verifying features changed since $last_commit...${NC}"
    while IFS= read -r fid; do
        [ -z "$fid" ] && continue
        verify_feature "$fid" "true"
    done <<< "$changed_features"
}

# Generate full report
cmd_report() {
    local report_dir="$ROOT_DIR/docs/retrospectives"
    local report_file="$report_dir/SPEC-AUDIT-$(date +%Y-%m-%d).md"
    mkdir -p "$report_dir"

    {
        echo "# Spec Verification Audit — $(date +%Y-%m-%d)"
        echo ""
        echo "**Generated by**: \`spec-audit.sh --report\`"
        echo "**Commit**: $(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')"
        echo ""
        echo "## Feature Verification Results"
        echo ""
        echo "| Feature | Structural | Coverage | Test Quality | NFR | Issues |"
        echo "|---------|-----------|----------|-------------|-----|--------|"

        local features
        features=$(get_shipped_features)
        while IFS= read -r fid; do
            [ -z "$fid" ] && continue
            local ac_file
            ac_file=$(get_acceptance_file "$fid")
            local s="pass" c="pass" t="unknown" n="n/a" issue_list=""

            if [ ! -f "$ac_file" ]; then s="FAIL"; issue_list="missing acceptance"; fi
            if [ -f "$ac_file" ] && ! has_tests_section "$ac_file"; then s="FAIL"; issue_list="${issue_list:+$issue_list, }no tests section"; fi

            local ac_count
            ac_count=$(count_ac "$ac_file" 2>/dev/null || echo "0")
            if [ "$ac_count" -eq 0 ] && [ -f "$ac_file" ]; then c="FAIL"; issue_list="${issue_list:+$issue_list, }no ACs"; fi

            local heur
            heur=$(check_test_heuristics "$fid")
            case "$heur" in
                no_tests) t="MISSING" ;;
                concerns:*) t="CONCERN" ;;
                ok) t="good" ;;
            esac

            local nfrs
            nfrs=$(get_feature_nfrs "$fid")
            if [ -n "$nfrs" ] && [ "$nfrs" != "none" ]; then
                if [ -f "$ac_file" ] && has_nfr_compliance "$ac_file"; then
                    n="pass"
                else
                    n="MISSING"
                fi
            fi

            echo "| $fid | $s | $c | $t | $n | ${issue_list:-none} |"
        done <<< "$features"

        echo ""
        echo "## Legend"
        echo "- **Structural**: acceptance file exists with required sections"
        echo "- **Coverage**: acceptance criteria are defined"
        echo "- **Test Quality**: heuristic check for empty/trivial tests"
        echo "- **NFR**: NFR Compliance section present when NFRs are linked"
    } > "$report_file"

    echo -e "${GREEN}Report saved: $report_file${NC}"
}

# --- Propagation (Phase 3B) ---

cmd_propagate() {
    local target="$1"

    echo -e "${BOLD}=== Change Propagation Analysis ===${NC}"
    echo ""

    if [[ "$target" =~ ^NFR- ]]; then
        _propagate_nfr "$target"
    elif [[ "$target" =~ ^migration: ]]; then
        local migration_id="${target#migration:}"
        _propagate_migration "$migration_id"
    else
        echo -e "${RED}Unknown propagation target: $target${NC}"
        echo "Usage: --propagate NFR-XXXX  or  --propagate migration:NNN"
        return 1
    fi
}

_propagate_nfr() {
    local nfr_id="$1"

    # Find features referencing this NFR
    local affected_features
    affected_features=$(grep -B5 "$nfr_id" "$FEATURES_FILE" 2>/dev/null \
        | grep -oE "$FEATURE_ID_ERE" | sort -u)

    if [ -z "$affected_features" ]; then
        echo -e "${GREEN}No features reference $nfr_id.${NC}"
        return
    fi

    echo -e "NFR $BOLD$nfr_id$NC referenced by:"
    local gap_count=0

    while IFS= read -r fid; do
        [ -z "$fid" ] && continue
        local ac_file
        ac_file=$(get_acceptance_file "$fid")
        local status="ok"

        if [ ! -f "$ac_file" ]; then
            status="MISSING acceptance file"
            ((gap_count++))
        elif ! has_nfr_compliance "$ac_file"; then
            status="MISSING NFR Compliance section"
            ((gap_count++))
        fi

        if [ "$status" = "ok" ]; then
            echo -e "  ${GREEN}✓${NC} $fid"
        else
            echo -e "  ${YELLOW}⚠${NC} $fid — $status"
        fi
    done <<< "$affected_features"

    echo ""
    if [ "$gap_count" -gt 0 ]; then
        echo -e "${YELLOW}$gap_count propagation gap(s) found.${NC}"
        echo -e "${DIM}Consider adding these as propagation items:${NC}"
        echo "  bash qa-tracker.sh add-propagation \"$nfr_id\" \"threshold change\" \"$(echo "$affected_features" | tr '\n' ',' | sed 's/,$//')\""
    else
        echo -e "${GREEN}All referencing features are in sync.${NC}"
    fi
}

_propagate_migration() {
    local migration_id="$1"
    local migration_dir="$ROOT_DIR/.agentic/spec/migrations"

    # Find migration file
    local migration_file
    migration_file=$(find "$migration_dir" -name "*${migration_id}*" -type f 2>/dev/null | head -1)

    if [ -z "$migration_file" ]; then
        echo -e "${RED}Migration $migration_id not found in $migration_dir${NC}"
        return 1
    fi

    echo -e "Migration: ${BOLD}$(basename "$migration_file")${NC}"

    # Extract feature IDs mentioned in migration
    local affected_features
    affected_features=$(grep -oE "$FEATURE_ID_ERE" "$migration_file" 2>/dev/null | sort -u)

    if [ -z "$affected_features" ]; then
        echo -e "${DIM}No feature IDs found in migration content.${NC}"
        return
    fi

    echo "Affected features:"
    while IFS= read -r fid; do
        [ -z "$fid" ] && continue
        verify_feature "$fid" "true"
    done <<< "$affected_features"
}

# --- Tracker (Phase 3C) ---

cmd_status() {
    if [ ! -f "$TRACKER_FILE" ]; then
        echo -e "${DIM}QA tracker not initialized. Run an audit first.${NC}"
        return
    fi

    python3 -c "
import json, sys
from datetime import datetime, timezone
try:
    with open('$TRACKER_FILE') as f:
        data = json.load(f)
    s = data.get('summary', {})
    v = s.get('features_verified', 0)
    t = s.get('features_total', 0)
    p = s.get('pending_propagation_items', 0)
    d = s.get('days_since_full_audit', '?')
    overdue = s.get('audit_overdue', False)
    overdue_str = ' (OVERDUE)' if overdue else ''
    print(f'QA: {v}/{t} verified, {p} pending propagation{overdue_str}')
    if int(d) if isinstance(d, (int, float)) else 0 > 0:
        print(f'  Last full audit: {d} days ago')
except Exception as e:
    print(f'QA tracker error: {e}', file=sys.stderr)
" 2>/dev/null || echo -e "${DIM}QA tracker: unable to read (python3 required)${NC}"
}

cmd_resolve() {
    local pq_id="$1"
    bash "$SCRIPT_DIR/qa-tracker.sh" resolve "$pq_id" 2>/dev/null \
        || echo -e "${RED}Failed to resolve $pq_id. Is qa-tracker.sh available?${NC}"
}

cmd_defer() {
    local pq_id="$1"
    local reason="$2"
    bash "$SCRIPT_DIR/qa-tracker.sh" defer "$pq_id" "$reason" 2>/dev/null \
        || echo -e "${RED}Failed to defer $pq_id. Is qa-tracker.sh available?${NC}"
}

# --- Tracker update helper ---

_update_tracker_verify() {
    local total="$1"
    local verified="$2"

    # Initialize or update tracker
    python3 -c "
import json, os
from datetime import datetime, timezone

tracker_file = '$TRACKER_FILE'
os.makedirs(os.path.dirname(tracker_file), exist_ok=True)

try:
    with open(tracker_file) as f:
        data = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    data = {'verification': {}, 'propagation': {'pending': [], 'resolved': []}, 'summary': {}}

now = datetime.now(timezone.utc).isoformat()
commit = '$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")'

data['verification']['last_full_audit'] = now
data['verification']['last_audit_commit'] = commit
data['summary']['features_total'] = $total
data['summary']['features_verified'] = $verified
data['summary']['pending_propagation_items'] = sum(
    sum(1 for i in p.get('items', []) if i.get('status') == 'open')
    for p in data.get('propagation', {}).get('pending', [])
)

# Calculate days since audit
data['summary']['days_since_full_audit'] = 0
freshness = data['verification'].get('audit_freshness_days', 30)
data['summary']['audit_overdue'] = False

with open(tracker_file, 'w') as f:
    json.dump(data, f, indent=2)
" 2>/dev/null
}

# --- Main ---

case "${1:-}" in
    --status)
        cmd_status
        ;;
    --since-last)
        cmd_verify_since_last
        ;;
    --nfr-test-coverage)
        # NFR test coverage across all shipped features with NFR references
        echo -e "${BOLD}NFR Test Coverage Report${NC}"
        echo ""
        local_total=0
        local_gaps=0
        if [[ -f "$FEATURES_FILE" ]] && [[ -f "$NFR_FILE" ]]; then
            shipped_fids=$(grep -E "^## F-[0-9]+:" "$FEATURES_FILE" -A5 | awk '/^## F-/{fid=$2; sub(/:$/,"",fid)} /[Ss]tatus.*shipped/{print fid}')
            for fid in $shipped_fids; do
                ac_file="$ACCEPTANCE_DIR/${fid}.md"
                [[ -f "$ac_file" ]] || continue
                # Check if this feature has any NFR references
                if grep -qE 'NFR-[0-9]+' "$ac_file" 2>/dev/null; then
                    local_total=$((local_total + 1))
                    result=$(bash "$SCRIPT_DIR/nfr-test-check.sh" "$fid" 2>/dev/null)
                    rc=$?
                    if [[ $rc -ne 0 ]]; then
                        local_gaps=$((local_gaps + 1))
                        echo -e "  ${YELLOW}⚠${NC} ${fid}: NFR test gaps"
                    else
                        echo -e "  ${GREEN}✓${NC} ${fid}: NFR tests covered"
                    fi
                fi
            done
            echo ""
            echo -e "${BOLD}Summary${NC}: ${local_total} features with NFR refs, ${local_gaps} with gaps"
        else
            echo "No FEATURES.md or NFR.md found."
        fi
        ;;
    --report)
        cmd_report
        ;;
    --propagate)
        cmd_propagate "${2:-}"
        ;;
    --resolve)
        cmd_resolve "${2:-}"
        ;;
    --defer)
        cmd_defer "${2:-}" "${3:-}"
        ;;
    --help|-h)
        cat <<'USAGE'
Usage:
  bash spec-audit.sh                          # Verify all shipped features
  bash spec-audit.sh F-XXXX                   # Verify single feature
  bash spec-audit.sh --since-last             # Changed since last audit
  bash spec-audit.sh --report                 # Full markdown report
  bash spec-audit.sh --propagate NFR-XXXX     # Trace NFR change downstream
  bash spec-audit.sh --propagate migration:NNN # Trace migration downstream
  bash spec-audit.sh --nfr-test-coverage       # NFR test coverage across shipped features
  bash spec-audit.sh --status                 # QA tracker summary
  bash spec-audit.sh --resolve PQ-001         # Resolve propagation item
  bash spec-audit.sh --defer PQ-001 "reason"  # Defer with documented reason
USAGE
        ;;
    "")
        cmd_verify ""
        ;;
    *)
        if is_feature_id "$1"; then
            cmd_verify "$1"
        else
            echo -e "${RED}Unknown argument: $1${NC}"
            echo "Run: bash spec-audit.sh --help"
            exit 1
        fi
        ;;
esac

exit 0
