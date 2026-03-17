#!/usr/bin/env bash
# spec-metrics.sh — Spec evolution metrics: discovery markers + churn analysis
#
# Usage:
#   bash spec-metrics.sh                  # All shipped features (discovery + churn)
#   bash spec-metrics.sh F-XXXX           # Single feature metrics
#   bash spec-metrics.sh --discovery      # Discovery markers only
#   bash spec-metrics.sh --churn          # Churn analysis only
#   bash spec-metrics.sh --json           # Machine-readable JSON output
#   bash spec-metrics.sh --summary-line   # One-liner for dashboard
#
# Exit code: always 0 (advisory tool)
#
# Note on churn: counts ALL git commits touching the AC file, including
# checkbox toggles and formatting changes — not just requirement edits.
# Treat churn as an approximate signal, not a precise measure.
#
# @feature F-0225

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

# FEATURES_FILE and ACCEPTANCE_DIR provided by paths.sh

# --- Helpers ---

# Get list of shipped feature IDs
get_shipped_features() {
    grep -B2 -iE '\*\*Status\*\*:[[:space:]]*shipped' "$FEATURES_FILE" 2>/dev/null \
        | grep -oE "$FEATURE_ID_ERE" | sort -u
}

# Count [Discovered] markers in an AC file
count_discovered_markers() {
    local file="$1"
    [[ -f "$file" ]] || { echo "0"; return; }
    local count
    count=$(grep -c '\[Discovered\]' "$file" 2>/dev/null) || count=0
    echo "${count//[[:space:]]/}"
}

# Count git commits touching an AC file (churn indicator)
count_churn_commits() {
    local fid="$1"
    local ac_file="$ACCEPTANCE_DIR/${fid}.md"
    # Gracefully return 0 if git unavailable or file not tracked
    if ! command -v git >/dev/null 2>&1; then
        echo "0"
        return
    fi
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        echo "0"
        return
    fi
    local rel_path
    rel_path=$(git -C "$ROOT_DIR" ls-files --full-name "$ac_file" 2>/dev/null)
    if [[ -z "$rel_path" ]]; then
        echo "0"
        return
    fi
    local count
    count=$(git -C "$ROOT_DIR" log --oneline -- "$rel_path" 2>/dev/null | wc -l | tr -d ' ')
    echo "${count:-0}"
}

# Classify churn level
classify_churn() {
    local commits="$1"
    if [[ "$commits" -gt 10 ]]; then
        echo "high"
    elif [[ "$commits" -ge 4 ]]; then
        echo "medium"
    else
        echo "low"
    fi
}

# --- Commands ---

# Show discovery metrics for features
cmd_discovery() {
    local target="${1:-}"
    local features=""

    if [[ -n "$target" ]] && is_feature_id "$target"; then
        features="$target"
    else
        features=$(get_shipped_features)
    fi

    if [[ -z "$features" ]]; then
        echo -e "${YELLOW}No shipped features found.${NC}"
        return
    fi

    local total_features=0
    local total_discoveries=0
    local features_with_discoveries=0

    echo -e "${BOLD}=== Discovery Markers ===${NC}"
    echo ""

    while IFS= read -r fid; do
        [[ -z "$fid" ]] && continue
        local ac_file="$ACCEPTANCE_DIR/${fid}.md"
        total_features=$((total_features + 1))

        local disc_count
        disc_count=$(count_discovered_markers "$ac_file")

        if [[ "$disc_count" -gt 0 ]]; then
            echo -e "  ${YELLOW}⚡${NC} ${BOLD}$fid${NC}: $disc_count discovered requirement(s)"
            total_discoveries=$((total_discoveries + disc_count))
            features_with_discoveries=$((features_with_discoveries + 1))
        fi
    done <<< "$features"

    echo ""
    echo -e "${BOLD}Summary:${NC} $features_with_discoveries/$total_features features have discoveries ($total_discoveries total markers)"
}

# Show churn metrics for features
cmd_churn() {
    local target="${1:-}"
    local features=""

    if [[ -n "$target" ]] && is_feature_id "$target"; then
        features="$target"
    else
        features=$(get_shipped_features)
    fi

    if [[ -z "$features" ]]; then
        echo -e "${YELLOW}No shipped features found.${NC}"
        return
    fi

    local total_features=0
    local high_churn=0
    local medium_churn=0
    local low_churn=0

    echo -e "${BOLD}=== Spec Churn Analysis ===${NC}"
    echo ""

    while IFS= read -r fid; do
        [[ -z "$fid" ]] && continue
        local ac_file="$ACCEPTANCE_DIR/${fid}.md"
        [[ ! -f "$ac_file" ]] && continue
        total_features=$((total_features + 1))

        local commits
        commits=$(count_churn_commits "$fid")
        local level
        level=$(classify_churn "$commits")

        case "$level" in
            high)
                echo -e "  ${RED}▲${NC} ${BOLD}$fid${NC}: $commits commits (high churn)"
                high_churn=$((high_churn + 1))
                ;;
            medium)
                echo -e "  ${YELLOW}●${NC} ${BOLD}$fid${NC}: $commits commits (medium)"
                medium_churn=$((medium_churn + 1))
                ;;
            low)
                low_churn=$((low_churn + 1))
                ;;
        esac
    done <<< "$features"

    echo ""
    echo -e "${BOLD}Summary:${NC} $high_churn high, $medium_churn medium, $low_churn low churn ($total_features features)"
}

# Combined metrics for all or single feature
cmd_all() {
    local target="${1:-}"
    cmd_discovery "$target"
    echo ""
    cmd_churn "$target"
}

# JSON output for machine consumption (feeds F-0210)
cmd_json() {
    local target="${1:-}"
    local features=""

    if [[ -n "$target" ]] && is_feature_id "$target"; then
        features="$target"
    else
        features=$(get_shipped_features)
    fi

    local first=true
    echo "{"
    echo '  "features": ['

    while IFS= read -r fid; do
        [[ -z "$fid" ]] && continue
        local ac_file="$ACCEPTANCE_DIR/${fid}.md"

        local disc_count
        disc_count=$(count_discovered_markers "$ac_file")
        local commits
        commits=$(count_churn_commits "$fid")
        local level
        level=$(classify_churn "$commits")
        local ac_total
        ac_total=$(ac_count_total "$ac_file" 2>/dev/null || echo "0")

        if $first; then
            first=false
        else
            echo ","
        fi
        printf '    {"id": "%s", "discoveries": %s, "churn_commits": %s, "churn_level": "%s", "ac_count": %s}' \
            "$fid" "$disc_count" "$commits" "$level" "$ac_total"
    done <<< "$features"

    echo ""
    echo "  ]"
    echo "}"
}

# One-liner for dashboard (discovery-only — skips churn for performance)
cmd_summary_line() {
    local features
    features=$(get_shipped_features)

    if [[ -z "$features" ]]; then
        # Return empty — dashboard will skip the line
        return
    fi

    local total_features=0
    local total_discoveries=0

    while IFS= read -r fid; do
        [[ -z "$fid" ]] && continue
        local ac_file="$ACCEPTANCE_DIR/${fid}.md"
        total_features=$((total_features + 1))

        local disc
        disc=$(count_discovered_markers "$ac_file")
        total_discoveries=$((total_discoveries + disc))
    done <<< "$features"

    if [[ "$total_discoveries" -gt 0 ]]; then
        echo "$total_features specs tracked, ${total_discoveries} discovered"
    else
        echo "$total_features specs tracked, no anomalies"
    fi
}

# --- Main ---

case "${1:-}" in
    --discovery)
        cmd_discovery "${2:-}"
        ;;
    --churn)
        cmd_churn "${2:-}"
        ;;
    --json)
        cmd_json "${2:-}"
        ;;
    --summary-line)
        cmd_summary_line
        ;;
    --help|-h)
        cat <<'USAGE'
Usage:
  bash spec-metrics.sh                  # All shipped features (discovery + churn)
  bash spec-metrics.sh F-XXXX           # Single feature metrics
  bash spec-metrics.sh --discovery      # Discovery markers only
  bash spec-metrics.sh --churn          # Churn analysis only
  bash spec-metrics.sh --json           # Machine-readable JSON output
  bash spec-metrics.sh --summary-line   # One-liner for dashboard
USAGE
        ;;
    "")
        cmd_all ""
        ;;
    *)
        if is_feature_id "$1"; then
            cmd_all "$1"
        else
            echo -e "${RED}Unknown argument: $1${NC}"
            echo "Run: bash spec-metrics.sh --help"
            exit 1
        fi
        ;;
esac

exit 0
