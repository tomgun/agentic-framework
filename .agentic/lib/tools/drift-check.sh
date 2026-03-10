#!/usr/bin/env bash
# drift-check.sh — Detect FEATURES.md status vs AC completion drift (F-0197)
# Agent-agnostic: no tool-specific dependencies.
# Usage: bash drift-check.sh [--quiet]
#   --quiet: Only output if issues found (for ag sync integration)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/paths.sh" 2>/dev/null || true

ROOT_DIR="${ROOT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
FEATURES_FILE="$ROOT_DIR/.agentic/spec/FEATURES.md"
ACCEPTANCE_DIR="$ROOT_DIR/.agentic/spec/acceptance"

QUIET=false
[ "${1:-}" = "--quiet" ] && QUIET=true

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

issues=0

# ── Helper: count ACs in an acceptance file ──
count_acs() {
    local file="$1"
    local total=0 checked=0

    while IFS= read -r line; do
        if echo "$line" | grep -qE '^[[:space:]]*- \[[ x]\][[:space:]]*\*?\*?AC-'; then
            total=$((total + 1))
            if echo "$line" | grep -qE '^[[:space:]]*- \[x\]'; then
                checked=$((checked + 1))
            fi
        elif echo "$line" | grep -qE '^### AC-'; then
            total=$((total + 1))
        fi
    done < "$file"

    echo "$checked $total"
}

# ── Check 1: Shipped features with low AC completion ──
check_shipped_ac_drift() {
    [ ! -f "$FEATURES_FILE" ] && return 0

    local shipped_features
    shipped_features=$(grep -B2 -iE '\*\*Status\*\*:[[:space:]]*shipped' "$FEATURES_FILE" 2>/dev/null \
        | grep -oE 'F-[0-9]+' || true)

    for fid in $shipped_features; do
        local acc_file="$ACCEPTANCE_DIR/${fid}.md"
        [ ! -f "$acc_file" ] && continue

        local counts
        counts=$(count_acs "$acc_file")
        local checked=${counts%% *}
        local total=${counts##* }

        [ "$total" -eq 0 ] && continue

        local pct=$((checked * 100 / total))
        if [ "$pct" -lt 50 ]; then
            issues=$((issues + 1))
            if [ "$QUIET" = false ] || [ "$issues" -eq 1 ]; then
                echo -e "${YELLOW}Drift:${NC} $fid shipped but only ${checked}/${total} ACs checked (${pct}%)"
            fi
        fi
    done
}

# ── Check 2: BACKLOG.json vs FEATURES.md status divergence ──
check_backlog_drift() {
    local backlog_file="$ROOT_DIR/.agentic/BACKLOG.json"
    [ ! -f "$backlog_file" ] && return 0
    [ ! -f "$FEATURES_FILE" ] && return 0

    # Extract feature IDs from backlog
    local backlog_features
    backlog_features=$(grep -oE 'F-[0-9]+' "$backlog_file" 2>/dev/null || true)

    for fid in $backlog_features; do
        # Features in backlog should not be shipped/deprecated
        local status
        status=$(grep -A1 "^## ${fid}:" "$FEATURES_FILE" 2>/dev/null \
            | grep -oiE 'shipped|deprecated' || true)

        if [ -n "$status" ]; then
            issues=$((issues + 1))
            if [ "$QUIET" = false ] || [ "$issues" -eq 1 ]; then
                echo -e "${YELLOW}Drift:${NC} $fid is in BACKLOG.json but FEATURES.md says '${status}'"
            fi
        fi
    done
}

# ── Main ──
if [ "$QUIET" = false ]; then
    echo "Drift check: FEATURES.md vs acceptance criteria"
    echo "---"
fi

check_shipped_ac_drift
check_backlog_drift

if [ "$issues" -eq 0 ]; then
    if [ "$QUIET" = false ]; then
        echo -e "${GREEN}No drift detected${NC}"
    fi
    exit 0
else
    if [ "$QUIET" = false ]; then
        echo "---"
        echo -e "${YELLOW}${issues} drift issue(s) found${NC}"
    fi
    exit 0  # Advisory — don't fail ag sync
fi
