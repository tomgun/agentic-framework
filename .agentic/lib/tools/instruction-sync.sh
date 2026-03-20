#!/usr/bin/env bash
# instruction-sync.sh — Detect when ag.sh commands are missing from instruction files
#
# Parses ag.sh's main dispatch case statement to discover subcommands,
# then checks each command appears in the instruction file templates
# and shared reference files.
#
# Framework-dev only: detects divergence between ag.sh and the files
# that tell agents about available commands.
#
# Usage:
#   bash .agentic/lib/tools/instruction-sync.sh              # Full report
#   bash .agentic/lib/tools/instruction-sync.sh --quiet       # Exit code only (0=ok, 1=drift)
#   bash .agentic/lib/tools/instruction-sync.sh --json        # JSON output
#
# Exit codes:
#   0 - All commands found in all instruction files
#   1 - One or more commands missing from one or more files
#
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# --- Parse flags ---
MODE="full"
for arg in "$@"; do
    case "$arg" in
        --quiet) MODE="quiet" ;;
        --json)  MODE="json" ;;
        -h|--help)
            echo "Usage: bash .agentic/lib/tools/instruction-sync.sh [--quiet|--json]"
            echo ""
            echo "Detects ag.sh commands missing from instruction files."
            echo ""
            echo "  (no flags)  Full report with per-file details"
            echo "  --quiet     Exit code only (0=in sync, 1=drift detected)"
            echo "  --json      JSON output for programmatic use"
            exit 0
            ;;
    esac
done

# Colors (disabled if not TTY or quiet/json mode)
if [ -t 1 ] && [ "$MODE" = "full" ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' NC=''
fi

# --- Discover ag.sh subcommands from main dispatch ---
AG_SH="$ROOT_DIR/.agentic/lib/tools/ag.sh"
if [ ! -f "$AG_SH" ]; then
    echo "ERROR: ag.sh not found at $AG_SH" >&2
    exit 1
fi

# Extract commands from the main case statement at the end of ag.sh.
# Pattern: top-level case arms like "    start)" or "    implement)"
# We look for the main dispatch block (after "# Main command dispatch")
# and extract the simple command names (excluding help/--help/-h and *).
parse_ag_commands() {
    local in_dispatch=0
    local commands=()
    while IFS= read -r line; do
        # Detect start of main dispatch
        if [[ "$line" =~ "Main command dispatch" ]]; then
            in_dispatch=1
            continue
        fi
        if [ "$in_dispatch" -eq 1 ]; then
            # Match top-level case arms: exactly 4 spaces + word + )
            if [[ "$line" =~ ^[[:space:]]{4}([a-z][-a-z]*)\)$ ]]; then
                local cmd="${BASH_REMATCH[1]}"
                # Skip help aliases and catch-all
                case "$cmd" in
                    help|--help|-h) continue ;;
                    *) commands+=("$cmd") ;;
                esac
            fi
        fi
    done < "$AG_SH"
    printf '%s\n' "${commands[@]}"
}

AG_COMMANDS=$(parse_ag_commands)
COMMAND_COUNT=$(echo "$AG_COMMANDS" | wc -l | tr -d ' ')

# --- Define instruction files to check ---
# Each entry: path|label
# These are the template files that users receive (not root files).
INSTRUCTION_FILES=(
    "$ROOT_DIR/.agentic/lib/agents/claude/CLAUDE.md|CLAUDE.md template"
    "$ROOT_DIR/.agentic/lib/agents/cursor/cursorrules.txt|cursorrules.txt template"
    "$ROOT_DIR/.agentic/lib/agents/copilot/copilot-instructions.md|copilot-instructions.md template"
    "$ROOT_DIR/.agentic/lib/agents/codex/codex-instructions.md|codex-instructions.md template"
    "$ROOT_DIR/.agentic/lib/init/memory-seed.md|memory-seed.md"
)

# Commands that are internal/rare and not expected in all instruction files.
# These are legitimate commands but don't need to appear in user-facing docs.
SKIP_COMMANDS="help init hooks trace tools approve-onboarding status set agents verify specs"

is_skipped() {
    local cmd="$1"
    for skip in $SKIP_COMMANDS; do
        [ "$cmd" = "$skip" ] && return 0
    done
    return 1
}

# --- Check each command in each file ---
TOTAL_MISSING=0
declare -A FILE_MISSING  # file_label -> missing commands (comma-separated)

for entry in "${INSTRUCTION_FILES[@]}"; do
    filepath="${entry%%|*}"
    label="${entry##*|}"

    if [ ! -f "$filepath" ]; then
        FILE_MISSING["$label"]="FILE_NOT_FOUND"
        TOTAL_MISSING=$((TOTAL_MISSING + 1))
        continue
    fi

    file_content=$(cat "$filepath")
    missing_for_file=""

    while IFS= read -r cmd; do
        [ -z "$cmd" ] && continue
        is_skipped "$cmd" && continue

        # Check if the command appears in the file (as "ag <cmd>" or just the command word)
        # We search for "ag <cmd>" pattern which is how commands appear in instruction files
        if ! echo "$file_content" | grep -q "ag ${cmd}\b\|ag ${cmd}[^a-z]\|ag ${cmd}$" 2>/dev/null; then
            if [ -n "$missing_for_file" ]; then
                missing_for_file="$missing_for_file, $cmd"
            else
                missing_for_file="$cmd"
            fi
            TOTAL_MISSING=$((TOTAL_MISSING + 1))
        fi
    done <<< "$AG_COMMANDS"

    if [ -n "$missing_for_file" ]; then
        FILE_MISSING["$label"]="$missing_for_file"
    fi
done

# --- Output ---
if [ "$MODE" = "quiet" ]; then
    [ "$TOTAL_MISSING" -eq 0 ] && exit 0 || exit 1
fi

if [ "$MODE" = "json" ]; then
    echo "{"
    echo "  \"total_commands\": $COMMAND_COUNT,"
    echo "  \"total_missing\": $TOTAL_MISSING,"
    echo "  \"files\": {"
    first=true
    for entry in "${INSTRUCTION_FILES[@]}"; do
        label="${entry##*|}"
        if [ "$first" = true ]; then first=false; else echo ","; fi
        if [ -n "${FILE_MISSING[$label]+x}" ]; then
            echo -n "    \"$label\": \"${FILE_MISSING[$label]}\""
        else
            echo -n "    \"$label\": null"
        fi
    done
    echo ""
    echo "  }"
    echo "}"
    [ "$TOTAL_MISSING" -eq 0 ] && exit 0 || exit 1
fi

# Full mode
echo ""
echo "Instruction File Sync Check"
echo "════════════════════════════"
echo ""
echo "ag.sh commands discovered: $COMMAND_COUNT"
echo "Skipped (internal): $SKIP_COMMANDS"
echo ""

HAS_ISSUES=0
for entry in "${INSTRUCTION_FILES[@]}"; do
    filepath="${entry%%|*}"
    label="${entry##*|}"

    if [ -n "${FILE_MISSING[$label]+x}" ]; then
        missing="${FILE_MISSING[$label]}"
        if [ "$missing" = "FILE_NOT_FOUND" ]; then
            echo -e "${RED}✗${NC} $label — FILE NOT FOUND"
            echo "  Path: $filepath"
        else
            echo -e "${YELLOW}⚠${NC} $label — missing commands:"
            echo "  $missing"
        fi
        HAS_ISSUES=1
    else
        echo -e "${GREEN}✓${NC} $label — all commands present"
    fi
done

echo ""
if [ "$HAS_ISSUES" -eq 0 ]; then
    echo -e "${GREEN}All ag.sh commands found in all instruction files.${NC}"
    exit 0
else
    echo -e "${YELLOW}$TOTAL_MISSING command reference(s) missing across instruction files.${NC}"
    echo "Update instruction files to include missing commands."
    exit 1
fi
