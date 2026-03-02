#!/usr/bin/env bash
# spec-analyze.sh: Semantic consistency analysis for spec artifacts
#
# Deterministic checks (no LLM calls) that catch common spec problems:
#   1. Ambiguity detection — flags vague adjectives without metrics
#   2. AC↔test coverage gaps — identifies ACs with no corresponding test
#   3. NFR measurability audit — flags NFRs without quantifiable success criteria
#
# Usage:
#   bash .agentic/tools/spec-analyze.sh F-XXXX    # Analyze one feature
#   bash .agentic/tools/spec-analyze.sh --help     # Usage info
#
# Results are severity-rated and advisory (exit 0 always).
# @feature F-0152

# Note: -e intentionally omitted — script always exits 0 (advisory mode).
# Individual command failures are handled per-check via || true guards.
set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_ROOT"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Severity counters
CRITICAL=0
HIGH=0
MEDIUM=0
LOW=0

# Findings array (for structured output)
FINDINGS=()

# Vague words that need metrics to be meaningful
VAGUE_WORDS="fast|slow|scalable|easy|simple|intuitive|secure|robust|efficient|flexible|responsive|user-friendly|seamless|modern|clean|good|nice|better|improved|optimal|quickly|easily|performant|lightweight|minimal|adequate|sufficient|reasonable|appropriate"

# Measurement units that indicate a metric is present nearby
METRIC_INDICATORS='[0-9]+\s*(ms|s|sec|min|%|percent|MB|GB|KB|bytes|req/s|rps|tps|ops|lines|files|items|times|x)\b|[0-9]+\.[0-9]|<\s*[0-9]|>\s*[0-9]|≤|≥|within\s+[0-9]|under\s+[0-9]|below\s+[0-9]|at least\s+[0-9]|at most\s+[0-9]|max\s+[0-9]|min\s+[0-9]'

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
SEP=$'\x1f'  # ASCII Unit Separator — safe delimiter for finding fields

add_finding() {
    local severity="$1"
    local id="$2"
    local message="$3"
    local suggestion="${4:-}"

    FINDINGS+=("${severity}${SEP}${id}${SEP}${message}${SEP}${suggestion}")

    case "$severity" in
        CRITICAL) CRITICAL=$((CRITICAL + 1)) ;;
        HIGH)     HIGH=$((HIGH + 1)) ;;
        MEDIUM)   MEDIUM=$((MEDIUM + 1)) ;;
        LOW)      LOW=$((LOW + 1)) ;;
    esac
}

print_findings() {
    for finding in "${FINDINGS[@]}"; do
        IFS="$SEP" read -r severity id message suggestion <<< "$finding"
        case "$severity" in
            CRITICAL) color="$RED" ;;
            HIGH)     color="$RED" ;;
            MEDIUM)   color="$YELLOW" ;;
            LOW)      color="$BLUE" ;;
            *)        color="$NC" ;;
        esac
        echo -e "  ${color}[${severity}]${NC} ${id}: ${message}"
        if [[ -n "$suggestion" ]]; then
            echo -e "    → $suggestion"
        fi
    done
}

usage() {
    cat <<'EOF'
Usage: bash .agentic/tools/spec-analyze.sh <F-XXXX|--help>

Semantic consistency analysis for spec artifacts.

Arguments:
  F-XXXX    Analyze a single feature's spec quality
  --help    Show this help message

Checks performed:
  1. Ambiguity detection — flags vague adjectives without metrics
  2. AC↔test coverage gaps — identifies ACs with no corresponding test
  3. NFR measurability audit — flags NFRs without quantifiable success criteria

Results are severity-rated (CRITICAL/HIGH/MEDIUM/LOW) and advisory.
The script always exits 0 — findings are warnings, not blockers.

Examples:
  bash .agentic/tools/spec-analyze.sh F-0148
  bash .agentic/tools/spec-analyze.sh --help
EOF
    exit 0
}

# ---------------------------------------------------------------------------
# Check 1: Ambiguity Detection
# ---------------------------------------------------------------------------
check_ambiguity() {
    local accept_file="$1"
    local in_ac_section=0

    while IFS= read -r line; do
        # Track whether we're in the Acceptance Criteria section
        if [[ "$line" =~ ^'## Acceptance Criteria' ]]; then
            in_ac_section=1
            continue
        fi
        if [[ $in_ac_section -eq 1 ]] && [[ "$line" =~ ^'## '[^#] ]]; then
            in_ac_section=0
            continue
        fi

        # Only scan AC lines (lines with AC-XXX identifiers)
        if [[ $in_ac_section -eq 1 ]] && [[ "$line" =~ \*\*AC-[0-9]+\*\* ]]; then
            # Extract the AC ID
            local ac_id
            [[ "$line" =~ (AC-[0-9]+) ]] && ac_id="${BASH_REMATCH[1]}"

            # Check each vague word (case-insensitive via grep fallback for portability)
            while IFS='|' read -r word; do
                if echo "$line" | grep -qiw "$word"; then
                    # Check if there's a metric nearby on the same line
                    if ! echo "$line" | grep -qEi "$METRIC_INDICATORS"; then
                        add_finding "MEDIUM" "$ac_id" \
                            "Contains vague term \"$word\" without metric" \
                            "Consider adding a measurable threshold"
                    fi
                fi
            done <<< "$(echo "$VAGUE_WORDS" | tr '|' '\n')"
        fi
    done < "$accept_file"
}

# ---------------------------------------------------------------------------
# Check 2: AC↔Test Coverage Gaps (delegates to coverage.py)
# ---------------------------------------------------------------------------
check_ac_coverage() {
    local feature_id="$1"

    if ! command -v python3 >/dev/null 2>&1; then
        add_finding "LOW" "$feature_id" \
            "python3 not available — skipping AC coverage check" ""
        return
    fi

    local coverage_script="${PROJECT_ROOT}/.agentic/tools/coverage.py"
    if [[ ! -f "$coverage_script" ]]; then
        add_finding "LOW" "$feature_id" \
            "coverage.py not found — skipping AC coverage check" ""
        return
    fi

    local json_output
    json_output=$(python3 "$coverage_script" --ac-coverage "$feature_id" --json 2>/dev/null) || true

    if [[ -z "$json_output" ]]; then
        return
    fi

    # Parse JSON for uncovered ACs
    # Look for entries with "status": "not_covered"
    local uncovered_acs
    uncovered_acs=$(echo "$json_output" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    for ac in data.get('acs', []):
        if ac.get('status') == 'not_covered':
            text = ac.get('text', '')
            print(f\"{ac['id']}|{text}\")
except Exception:
    pass
" 2>/dev/null) || true

    if [[ -n "$uncovered_acs" ]]; then
        while IFS='|' read -r ac_id ac_text; do
            [[ -z "$ac_id" ]] && continue
            local msg="No test found for this acceptance criterion"
            if [[ -n "$ac_text" ]]; then
                msg="No test found — \"$ac_text\""
            fi
            add_finding "MEDIUM" "$ac_id" "$msg" \
                "Add a test referencing $ac_id"
        done <<< "$uncovered_acs"
    fi
}

# ---------------------------------------------------------------------------
# Check 3: NFR Measurability
# ---------------------------------------------------------------------------
check_nfr_measurability() {
    local accept_file="$1"
    local nfr_file="${PROJECT_ROOT}/spec/NFR.md"

    # First: extract NFR references from the acceptance file
    local referenced_nfrs
    referenced_nfrs=$(grep -oE 'NFR-[0-9]+' "$accept_file" 2>/dev/null | sort -u || true)

    if [[ -z "$referenced_nfrs" ]]; then
        return
    fi

    # If NFR.md doesn't exist, flag it
    if [[ ! -f "$nfr_file" ]]; then
        add_finding "HIGH" "NFR" \
            "Acceptance file references NFRs but spec/NFR.md not found" \
            "Create spec/NFR.md or remove NFR references"
        return
    fi

    # Check each referenced NFR exists and has valid measurement
    while IFS= read -r nfr_id; do
        [[ -z "$nfr_id" ]] && continue

        # Check NFR exists in NFR.md
        if ! grep -q "^## ${nfr_id}:" "$nfr_file" 2>/dev/null; then
            add_finding "HIGH" "$nfr_id" \
                "Referenced in acceptance file but not found in spec/NFR.md" \
                "Add $nfr_id to spec/NFR.md or remove the reference"
            continue
        fi

        # Extract the "How to measure" line for this NFR
        local measure_line
        measure_line=$(sed -n "/^## ${nfr_id}:/,/^## /p" "$nfr_file" | grep -i "How to measure" | head -1 || true)

        if [[ -z "$measure_line" ]]; then
            add_finding "HIGH" "$nfr_id" \
                "Missing 'How to measure' field" \
                "Add a measurable criterion to $nfr_id in spec/NFR.md"
            continue
        fi

        # Check for placeholder content
        local measure_value
        measure_value=$(echo "$measure_line" | sed 's/.*How to measure[: ]*//' | xargs)

        if [[ -z "$measure_value" ]] || echo "$measure_value" | grep -qiE '^(TBD|TODO|placeholder|fill|N/A|none|-)$'; then
            add_finding "HIGH" "$nfr_id" \
                "'How to measure' is a placeholder: \"$measure_value\"" \
                "Replace with a concrete measurement approach"
            continue
        fi

        # Check for vague measurement without numbers/units
        if echo "$measure_value" | grep -qiE "\b($VAGUE_WORDS)\b"; then
            if ! echo "$measure_value" | grep -qEi "$METRIC_INDICATORS"; then
                add_finding "MEDIUM" "$nfr_id" \
                    "'How to measure' uses vague terms without numbers: \"$measure_value\"" \
                    "Add specific thresholds or measurement commands"
            fi
        fi
    done <<< "$referenced_nfrs"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    usage
fi

if [[ -z "${1:-}" ]]; then
    echo "Usage: bash .agentic/tools/spec-analyze.sh <F-XXXX|--help>"
    exit 0
fi

FEATURE_ID="$1"

# Validate feature ID format
if ! echo "$FEATURE_ID" | grep -qE '^F-[0-9]{4}$'; then
    echo "Error: Invalid feature ID format: $FEATURE_ID (expected F-XXXX)"
    exit 0  # Advisory — don't fail
fi

ACCEPT_FILE="spec/acceptance/${FEATURE_ID}.md"

echo ""
echo -e "${BLUE}=== Spec Analysis: ${FEATURE_ID} ===${NC}"
echo ""

# Edge case: missing or empty acceptance file (AC-012)
if [[ ! -f "$ACCEPT_FILE" ]]; then
    echo -e "  ${RED}[ERROR]${NC} Acceptance file not found: $ACCEPT_FILE"
    echo -e "  → Create acceptance criteria before running analysis"
    echo ""
    echo "Summary: No analysis possible — acceptance file missing"
    exit 0
fi

if [[ ! -s "$ACCEPT_FILE" ]]; then
    echo -e "  ${RED}[ERROR]${NC} Acceptance file is empty: $ACCEPT_FILE"
    echo -e "  → Add acceptance criteria content"
    echo ""
    echo "Summary: No analysis possible — acceptance file empty"
    exit 0
fi

# Run checks
echo -e "${BLUE}Check 1: Ambiguity detection${NC}"
check_ambiguity "$ACCEPT_FILE"

echo -e "${BLUE}Check 2: AC↔test coverage gaps${NC}"
check_ac_coverage "$FEATURE_ID"

echo -e "${BLUE}Check 3: NFR measurability${NC}"
check_nfr_measurability "$ACCEPT_FILE"

# Print findings
echo ""
if [[ ${#FINDINGS[@]} -gt 0 ]]; then
    print_findings
else
    echo -e "  ${GREEN}No issues found${NC}"
fi

# Summary
echo ""
echo -e "Summary: ${RED}${CRITICAL} CRITICAL${NC}, ${RED}${HIGH} HIGH${NC}, ${YELLOW}${MEDIUM} MEDIUM${NC}, ${BLUE}${LOW} LOW${NC}"

# Always exit 0 — advisory only (AC-007)
exit 0
