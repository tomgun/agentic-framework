#!/usr/bin/env bash
# run.sh — Infrastructure validation test runner
#
# Usage:
#   bash tests/infrastructure/run.sh                  # Structural only ($0, ~90s)
#   bash tests/infrastructure/run.sh --with-llm       # + LLM tests (~$5-8, ~18min)
#   bash tests/infrastructure/run.sh --interactive     # + human-guided memory tests
#   bash tests/infrastructure/run.sh --full            # Everything
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/results"
mkdir -p "$RESULTS_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Parse flags
WITH_LLM=false
WITH_INTERACTIVE=false
WITH_LLM_MUTATIONS=false

for arg in "$@"; do
    case "$arg" in
        --with-llm)       WITH_LLM=true ;;
        --interactive)    WITH_INTERACTIVE=true ;;
        --full)           WITH_LLM=true; WITH_INTERACTIVE=true; WITH_LLM_MUTATIONS=true ;;
        --help|-h)
            echo "Usage: bash tests/infrastructure/run.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  (none)          Structural tests only (\$0, ~90s)"
            echo "  --with-llm      + LLM behavioral tests (~\$5-8, ~18min)"
            echo "  --interactive   + Human-guided memory tests (~\$1-2, ~10min)"
            echo "  --full          All tests (~\$15-20, ~45min)"
            exit 0
            ;;
    esac
done

# Counters
PHASE_RESULTS=()
TOTAL_PASSED=0
TOTAL_FAILED=0

run_test() {
    local test_file="$1"
    local test_name
    test_name=$(basename "$test_file" .sh)

    echo ""
    local output exit_code
    output=$(bash "$test_file" 2>&1) && exit_code=0 || exit_code=$?
    echo "$output"

    # Extract pass/fail counts from output
    local passed failed
    passed=$(echo "$output" | grep -c "PASS" || true)
    failed=$(echo "$output" | grep -c "FAIL" || true)

    TOTAL_PASSED=$((TOTAL_PASSED + passed))
    TOTAL_FAILED=$((TOTAL_FAILED + failed))

    if [[ $exit_code -eq 0 ]] && [[ $failed -eq 0 ]]; then
        PHASE_RESULTS+=("${GREEN}PASS${NC} $test_name ($passed assertions)")
    else
        PHASE_RESULTS+=("${RED}FAIL${NC} $test_name ($failed failures)")
    fi
}

run_llm_test() {
    local test_file="$1"
    local test_name
    test_name=$(basename "$test_file" .sh)

    echo ""
    local exit_code
    bash "$test_file" && exit_code=0 || exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        TOTAL_PASSED=$((TOTAL_PASSED + 1))
        PHASE_RESULTS+=("${GREEN}PASS${NC} $test_name")
    elif [[ $exit_code -eq 2 ]]; then
        PHASE_RESULTS+=("${YELLOW}RATE${NC} $test_name (rate limited)")
    else
        TOTAL_FAILED=$((TOTAL_FAILED + 1))
        PHASE_RESULTS+=("${RED}FAIL${NC} $test_name")
    fi
}

# ═══════════════════════════════════════════════════════════════
echo ""
echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     INFRASTRUCTURE VALIDATION — MUTATION TESTING              ║${NC}"
echo -e "${BLUE}║     Proving our solutions work (and break without them)       ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

START_TIME=$(date +%s)

# ─── Phase 1A: Structural Positive Tests ───
echo -e "${BLUE}Phase 1A: Structural Positive Tests (bash-only, \$0)${NC}"
echo "───────────────────────────────────────────────────────────"

for test_file in "$SCRIPT_DIR"/structural/S*.sh; do
    [[ -f "$test_file" ]] && run_test "$test_file"
done

# ─── Phase 1B: Structural Mutation Tests ───
echo ""
echo -e "${BLUE}Phase 1B: Structural Mutation Tests (bash-only, \$0)${NC}"
echo "───────────────────────────────────────────────────────────"

for test_file in "$SCRIPT_DIR"/mutations/M*.sh; do
    [[ -f "$test_file" ]] && run_test "$test_file"
done

# ─── Phase 2A: LLM Positive Tests ───
if [[ "$WITH_LLM" == true ]]; then
    echo ""
    echo -e "${BLUE}Phase 2A: LLM Behavioral Tests (~\$5-8, ~18min)${NC}"
    echo "───────────────────────────────────────────────────────────"

    for test_file in "$SCRIPT_DIR"/llm/L*.sh; do
        [[ -f "$test_file" ]] && run_llm_test "$test_file"
    done
fi

# ─── Phase 2B: Interactive Memory Tests ───
if [[ "$WITH_INTERACTIVE" == true ]]; then
    echo ""
    echo -e "${BLUE}Phase 2B: Interactive Memory Tests (human-guided)${NC}"
    echo "───────────────────────────────────────────────────────────"

    for test_file in "$SCRIPT_DIR"/interactive/I*.sh; do
        [[ -f "$test_file" ]] && run_test "$test_file"
    done
fi

# ─── Phase 2C: LLM Mutation Tests ───
if [[ "$WITH_LLM_MUTATIONS" == true ]]; then
    echo ""
    echo -e "${BLUE}Phase 2C: LLM Mutation Tests (~\$3-5, ~10min)${NC}"
    echo "───────────────────────────────────────────────────────────"

    for test_file in "$SCRIPT_DIR"/llm-mutations/M*.sh; do
        [[ -f "$test_file" ]] && run_llm_test "$test_file"
    done
fi

# ─── Summary ───
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo ""
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  INFRASTRUCTURE VALIDATION RESULTS${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

for result in "${PHASE_RESULTS[@]}"; do
    echo -e "  $result"
done

echo ""
echo "───────────────────────────────────────────────────────────"

TOTAL=$((TOTAL_PASSED + TOTAL_FAILED))
if [[ $TOTAL_FAILED -eq 0 ]]; then
    echo -e "  ${GREEN}ALL $TOTAL ASSERTIONS PASSED${NC} (${DURATION}s)"
else
    echo -e "  ${RED}$TOTAL_FAILED/$TOTAL ASSERTIONS FAILED${NC} (${DURATION}s)"
fi

echo ""

# ─── Generate Evidence Report ───
REPORT_DATE=$(date +%Y-%m-%d)
REPORT_FILE="$RESULTS_DIR/${REPORT_DATE}_evidence.md"

cat > "$REPORT_FILE" << REPORT_EOF
# Infrastructure Validation Evidence — $REPORT_DATE

## Test Run Summary

- **Date**: $(date '+%Y-%m-%d %H:%M %Z')
- **Duration**: ${DURATION}s
- **Assertions**: $TOTAL_PASSED passed, $TOTAL_FAILED failed (total: $TOTAL)
- **Phases run**: Structural$([ "$WITH_LLM" = true ] && echo ", LLM")$([ "$WITH_INTERACTIVE" = true ] && echo ", Interactive")$([ "$WITH_LLM_MUTATIONS" = true ] && echo ", LLM Mutations")

## Results

| Test | Result |
|------|--------|
REPORT_EOF

for result in "${PHASE_RESULTS[@]}"; do
    # Strip ANSI colors for markdown
    clean=$(echo -e "$result" | sed 's/\x1b\[[0-9;]*m//g')
    status=$(echo "$clean" | awk '{print $1}')
    name=$(echo "$clean" | cut -d' ' -f2-)
    echo "| $name | $status |" >> "$REPORT_FILE"
done

cat >> "$REPORT_FILE" << 'LESSONS_EOF'

## Lessons Learned (with evidence)

### 1. core.hooksPath is THE enforcement point
- Evidence: M01 removes config → all 12 checks silently bypassed
- Evidence: M02 deletes hook file → same result
- Before F-0129: hooks existed but git never called them
- Impact: Without this, WIP locks, staleness checks, branch policy ALL fail silently

### 2. One config line can disable everything
- Evidence: M03 sets `pre_commit_hook: no` → all gates off
- Implication: STACK.md is a trust boundary — treated as human-controlled

### 3. Defense-in-depth: hooks catch what instructions miss
- Evidence: S06 simulates LLM ignoring "update JOURNAL before commit"
- Hook blocks the commit even though the LLM didn't follow instructions
- Git hooks can't be talked out of blocking; CLAUDE.md instructions CAN be diluted

### 4. Memory-seed and CLAUDE.md are consistent
- Evidence: S07 verifies all 5 trigger categories and 4 script references match
- Both enforcement layers agree on what to enforce

### 5. CLAUDE.md stays within salience limits
- Evidence: S08 verifies template is under 100 lines (L-0002)
- Empirical finding: LLM compliance drops sharply beyond ~100 lines
LESSONS_EOF

echo -e "  Evidence report: ${GREEN}$REPORT_FILE${NC}"
echo ""

# Exit with failure count
exit $TOTAL_FAILED
