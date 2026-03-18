#!/usr/bin/env bash
# dogfood-sync.sh — Post-merge dogfood sync: detect drift between root and template instruction files
#
# Framework-dev only. Compares root instruction files against their canonical
# templates in .agentic/lib/agents/ using sentinel-based checking. Reuses
# instruction-sync.sh (ag command parity) and memory-check.sh (seed freshness).
#
# Usage:
#   bash .agentic/lib/tools/dogfood-sync.sh           # Full report with fix suggestions
#   bash .agentic/lib/tools/dogfood-sync.sh --brief    # One-line summary per phase
#
# Exit codes:
#   0 - No drift detected
#   1 - Drift detected (advisory — does not block ag done)
#
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# --- Parse flags ---
MODE="full"
for arg in "$@"; do
    case "$arg" in
        --brief) MODE="brief" ;;
        -h|--help)
            echo "Usage: bash .agentic/lib/tools/dogfood-sync.sh [--brief]"
            echo ""
            echo "Post-merge dogfood sync: detect root vs template instruction file drift."
            echo ""
            echo "  (no flags)  Full report with fix suggestions per drift item"
            echo "  --brief     One-line summary per phase (for ag done integration)"
            exit 0
            ;;
    esac
done

# --- Colors ---
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BOLD='\033[1m'
    DIM='\033[2m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BOLD='' DIM='' NC=''
fi

# --- Framework-dev guard ---
if [ ! -f "$ROOT_DIR/FRAMEWORK_DEVELOPMENT.md" ]; then
    [ "$MODE" = "full" ] && echo -e "${DIM}Dogfood sync: skipped (not a framework-dev repo)${NC}"
    exit 0
fi

TOTAL_DRIFT=0

# ═══════════════════════════════════════════════════════════════════
# Phase 1: AG Command Parity (delegates to instruction-sync.sh)
# ═══════════════════════════════════════════════════════════════════
phase1_drift=0
if [ -f "$SCRIPT_DIR/instruction-sync.sh" ]; then
    if ! bash "$SCRIPT_DIR/instruction-sync.sh" --quiet 2>/dev/null; then
        phase1_drift=1
        TOTAL_DRIFT=$((TOTAL_DRIFT + 1))
    fi
else
    phase1_drift=-1  # script not found
fi

if [ "$MODE" = "brief" ]; then
    if [ "$phase1_drift" -eq 0 ]; then
        echo -e "  ${GREEN}✓${NC} Phase 1: AG command parity — in sync"
    elif [ "$phase1_drift" -eq -1 ]; then
        echo -e "  ${YELLOW}?${NC} Phase 1: AG command parity — instruction-sync.sh not found"
    else
        echo -e "  ${YELLOW}⚠${NC} Phase 1: AG command parity — drift detected (run: bash .agentic/lib/tools/instruction-sync.sh)"
    fi
elif [ "$MODE" = "full" ]; then
    echo ""
    echo -e "${BOLD}Phase 1: AG Command Parity${NC}"
    if [ "$phase1_drift" -eq 0 ]; then
        echo -e "  ${GREEN}✓ All ag commands found in all instruction files${NC}"
    elif [ "$phase1_drift" -eq -1 ]; then
        echo -e "  ${YELLOW}? instruction-sync.sh not found — skipping${NC}"
    else
        echo -e "  ${YELLOW}⚠ Drift detected. Full report:${NC}"
        bash "$SCRIPT_DIR/instruction-sync.sh" 2>/dev/null | sed 's/^/    /'
    fi
fi

# ═══════════════════════════════════════════════════════════════════
# Phase 2: Sentinel-Based Content Drift
# ═══════════════════════════════════════════════════════════════════

# --- Sentinel definitions ---
# Quick Commands: must appear in all root files that have a Quick Commands line
SENTINELS_QUICK_COMMANDS=(
    "ag start"
    "ag sync"
    "ag implement"
    "ag commit"
    "ag done"
    "ag plan"
    "ag merge"
    "ag flush"
    "ag backlog"
    "ag review"
    "ag decompose"
    "ag worktree"
    "ag intent"
    "ag formalize"
    "ag kickoff"
    "ag run"
    "ag feedback"
)

# Core Rules: only checked in full-mode file pairs
SENTINELS_CORE_RULES=(
    "show changes to human before committing"
    "PR by default"
    "Spec + code + tests + docs = done"
    "Shipped specs are contracts"
    "Keep changes small and scoped"
    "Plans are durable"
    "Multi-agent"
    "Multi-session safety"
)

# Token-efficient scripts: only checked in full-mode file pairs
SENTINELS_SCRIPTS=(
    "status.sh focus"
    "journal.sh"
    "blocker.sh"
    "feature.sh"
    "todo.sh"
)

# --- File pairs: root|template|mode ---
# mode: full = all sentinel categories, reduced = Quick Commands only
FILE_PAIRS=(
    "$ROOT_DIR/CLAUDE.md|$ROOT_DIR/.agentic/lib/agents/claude/CLAUDE.md|full"
    "$ROOT_DIR/.github/copilot-instructions.md|$ROOT_DIR/.agentic/lib/agents/copilot/copilot-instructions.md|full"
    "$ROOT_DIR/.codex/instructions.md|$ROOT_DIR/.agentic/lib/agents/codex/codex-instructions.md|full"
    "$ROOT_DIR/.cursorrules|$ROOT_DIR/.agentic/lib/agents/cursor/cursorrules.txt|reduced"
)

# Check if a sentinel is suppressed in a root file
# Suppression: line containing <!-- dogfood:ignore: SENTINEL --> anywhere in the file
is_suppressed() {
    local root_file="$1"
    local sentinel="$2"
    grep -q "<!-- dogfood:ignore: ${sentinel} -->" "$root_file" 2>/dev/null
}

# Find the line number of a sentinel in a file
find_line() {
    local file="$1"
    local sentinel="$2"
    grep -n "$sentinel" "$file" 2>/dev/null | head -1 | cut -d: -f1
}

phase2_drift=0
phase2_details=()

for entry in "${FILE_PAIRS[@]}"; do
    IFS='|' read -r root_file template_file check_mode <<< "$entry"

    root_name="$(basename "$root_file")"
    template_name="$(basename "$template_file")"

    # Skip if either file missing
    if [ ! -f "$root_file" ]; then
        phase2_details+=("${YELLOW}?${NC} $root_name — root file not found")
        continue
    fi
    if [ ! -f "$template_file" ]; then
        phase2_details+=("${YELLOW}?${NC} $root_name — template file not found")
        continue
    fi

    file_drift=0
    file_details=()

    # Always check Quick Commands
    for sentinel in "${SENTINELS_QUICK_COMMANDS[@]}"; do
        # Only check if sentinel is in the template
        if grep -q "$sentinel" "$template_file" 2>/dev/null; then
            if ! grep -q "$sentinel" "$root_file" 2>/dev/null; then
                if ! is_suppressed "$root_file" "$sentinel"; then
                    template_line=$(find_line "$template_file" "$sentinel")
                    file_details+=("    ${YELLOW}⚠${NC} Missing: \"$sentinel\" (template line ${template_line:-?})")
                    file_drift=$((file_drift + 1))
                fi
            fi
        fi
    done

    # Full mode: also check Core Rules and Scripts
    if [ "$check_mode" = "full" ]; then
        for sentinel in "${SENTINELS_CORE_RULES[@]}"; do
            if grep -qi "$sentinel" "$template_file" 2>/dev/null; then
                if ! grep -qi "$sentinel" "$root_file" 2>/dev/null; then
                    if ! is_suppressed "$root_file" "$sentinel"; then
                        template_line=$(find_line "$template_file" "$sentinel")
                        file_details+=("    ${YELLOW}⚠${NC} Missing: \"$sentinel\" (template line ${template_line:-?})")
                        file_drift=$((file_drift + 1))
                    fi
                fi
            fi
        done

        for sentinel in "${SENTINELS_SCRIPTS[@]}"; do
            if grep -q "$sentinel" "$template_file" 2>/dev/null; then
                if ! grep -q "$sentinel" "$root_file" 2>/dev/null; then
                    if ! is_suppressed "$root_file" "$sentinel"; then
                        template_line=$(find_line "$template_file" "$sentinel")
                        file_details+=("    ${YELLOW}⚠${NC} Missing: \"$sentinel\" (template line ${template_line:-?})")
                        file_drift=$((file_drift + 1))
                    fi
                fi
            fi
        done
    fi

    if [ "$file_drift" -gt 0 ]; then
        phase2_drift=$((phase2_drift + file_drift))
        phase2_details+=("  ${YELLOW}⚠${NC} $root_name ← $template_name: $file_drift sentinel(s) missing")
        for detail in "${file_details[@]}"; do
            phase2_details+=("$detail")
        done
    else
        phase2_details+=("  ${GREEN}✓${NC} $root_name ← $template_name: in sync ($check_mode mode)")
    fi
done

TOTAL_DRIFT=$((TOTAL_DRIFT + phase2_drift))

if [ "$MODE" = "brief" ]; then
    if [ "$phase2_drift" -eq 0 ]; then
        echo -e "  ${GREEN}✓${NC} Phase 2: Content sentinels — in sync"
    else
        echo -e "  ${YELLOW}⚠${NC} Phase 2: Content sentinels — $phase2_drift item(s) drifted (run: ag dogfood)"
    fi
elif [ "$MODE" = "full" ]; then
    echo ""
    echo -e "${BOLD}Phase 2: Sentinel-Based Content Drift${NC}"
    for line in "${phase2_details[@]}"; do
        echo -e "$line"
    done
fi

# ═══════════════════════════════════════════════════════════════════
# Phase 3: Memory-Seed Freshness (delegates to memory-check.sh)
# ═══════════════════════════════════════════════════════════════════
phase3_drift=0
phase3_output=""
if [ -f "$SCRIPT_DIR/memory-check.sh" ]; then
    phase3_output=$(bash "$SCRIPT_DIR/memory-check.sh" 2>/dev/null || true)
    # memory-check.sh always exits 0; detect issues from output
    if echo "$phase3_output" | grep -qi "stale\|not seeded\|partially overwritten" 2>/dev/null; then
        phase3_drift=1
        TOTAL_DRIFT=$((TOTAL_DRIFT + 1))
    fi
else
    phase3_drift=-1
fi

if [ "$MODE" = "brief" ]; then
    if [ "$phase3_drift" -eq 0 ]; then
        echo -e "  ${GREEN}✓${NC} Phase 3: Memory-seed freshness — OK"
    elif [ "$phase3_drift" -eq -1 ]; then
        echo -e "  ${YELLOW}?${NC} Phase 3: Memory-seed freshness — memory-check.sh not found"
    else
        echo -e "  ${YELLOW}⚠${NC} Phase 3: Memory-seed freshness — needs update"
    fi
elif [ "$MODE" = "full" ]; then
    echo ""
    echo -e "${BOLD}Phase 3: Memory-Seed Freshness${NC}"
    if [ "$phase3_drift" -eq 0 ]; then
        echo -e "  ${GREEN}✓ Memory-seed is current${NC}"
    elif [ "$phase3_drift" -eq -1 ]; then
        echo -e "  ${YELLOW}? memory-check.sh not found — skipping${NC}"
    else
        echo -e "  $phase3_output" | sed 's/^/  /'
    fi
fi

# ═══════════════════════════════════════════════════════════════════
# Summary
# ═══════════════════════════════════════════════════════════════════
if [ "$MODE" = "full" ]; then
    echo ""
    if [ "$TOTAL_DRIFT" -eq 0 ]; then
        echo -e "${GREEN}No drift detected. Root files are in sync with templates.${NC}"
    else
        echo -e "${YELLOW}$TOTAL_DRIFT drift item(s) detected. Review and fix above issues.${NC}"
        echo -e "${DIM}Drift is advisory — fix inline or defer to next session.${NC}"
    fi
fi

[ "$TOTAL_DRIFT" -eq 0 ] && exit 0 || exit 1
