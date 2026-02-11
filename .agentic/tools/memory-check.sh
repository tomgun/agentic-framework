#!/usr/bin/env bash
# memory-check.sh — Advisory memory-seed integrity check
#
# Validates that Claude Code's auto-memory contains expected framework
# behavioral patterns from memory-seed.md. Advisory only (always exits 0).
#
# Usage: bash .agentic/tools/memory-check.sh [--quiet]
#   --quiet: Only print warnings; skip OK messages (for ag start)
#
# Detection: Claude Code stores auto-memory at:
#   ~/.claude/projects/<project-hash>/memory/MEMORY.md
# where <project-hash> is the git repo root with '/' replaced by '-'.
# FRAGILE: This path convention is reverse-engineered from observed
# Claude Code behavior, not a stable/documented API.

set -euo pipefail

QUIET=false
for arg in "$@"; do
    case "$arg" in
        --quiet) QUIET=true ;;
        -h|--help)
            echo "Usage: bash .agentic/tools/memory-check.sh [--quiet]"
            echo "Advisory memory-seed integrity check (always exits 0)."
            exit 0
            ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

YELLOW='\033[0;33m'
GREEN='\033[0;32m'
DIM='\033[2m'
NC='\033[0m'

# --- Tool detection ---
# Only Claude Code is supported for now.
# Don't use detect_agent() from wip.sh — it checks env vars that
# Claude Code CLI doesn't set. Check for ~/.claude/ directory instead.
if [ ! -d "$HOME/.claude" ]; then
    if [ "$QUIET" = false ]; then
        echo -e "${DIM}Memory check: skipped (not yet supported for non-Claude tools)${NC}"
        echo -e "${DIM}  Tools with file-based memory (Cursor, Windsurf, Copilot) may be supported in future.${NC}"
    fi
    exit 0
fi

# --- Derive memory path ---
# Convention: git repo root → replace '/' with '-' (including leading /)
REPO_ROOT="$(git -C "$ROOT_DIR" rev-parse --show-toplevel 2>/dev/null)" || {
    if [ "$QUIET" = false ]; then
        echo -e "${DIM}Memory check: skipped (not a git repo)${NC}"
    fi
    exit 0
}

PROJECT_HASH="$(echo "$REPO_ROOT" | tr '/' '-')"
MEMORY_FILE="$HOME/.claude/projects/${PROJECT_HASH}/memory/MEMORY.md"

# --- Get expected version from memory-seed.md ---
SEED_FILE="$ROOT_DIR/.agentic/init/memory-seed.md"
if [ ! -f "$SEED_FILE" ]; then
    if [ "$QUIET" = false ]; then
        echo -e "${DIM}Memory check: skipped (no memory-seed.md found)${NC}"
    fi
    exit 0
fi
EXPECTED_VERSION="$(grep -o 'memory-seed v[0-9]*\.[0-9]*\.[0-9]*' "$SEED_FILE" 2>/dev/null | head -1 | sed 's/memory-seed v//' || echo "")"

# --- Check (a): Never seeded ---
if [ ! -f "$MEMORY_FILE" ]; then
    echo -e "${YELLOW}Memory: not seeded — framework patterns not in Claude auto-memory${NC}"
    echo -e "${YELLOW}  To seed: Read .agentic/init/memory-seed.md and write patterns to memory${NC}"
    exit 0
fi

# --- Check (b): Stale version ---
CURRENT_VERSION="$(grep -o 'memory-seed v[0-9]*\.[0-9]*\.[0-9]*' "$MEMORY_FILE" 2>/dev/null | head -1 | sed 's/memory-seed v//' || echo "")"
if [ -n "$EXPECTED_VERSION" ] && [ "$CURRENT_VERSION" != "$EXPECTED_VERSION" ]; then
    echo -e "${YELLOW}Memory: stale (v${CURRENT_VERSION:-unknown} vs seed v${EXPECTED_VERSION})${NC}"
    echo -e "${YELLOW}  To update: Re-read .agentic/init/memory-seed.md and update memory${NC}"
    echo -e "${YELLOW}  (Preserve other project-specific memory content)${NC}"
    exit 0
fi

# --- Check (c): Partially overwritten ---
# Coarse heuristic: check 4 sentinel strings that are stable framework
# command names unlikely to be paraphrased. Require >= 3 present.
SENTINELS=("pre-commit sequence" "token-efficient scripts" "ag commit" "ag done")
FOUND=0
for sentinel in "${SENTINELS[@]}"; do
    if grep -v '^\s*<!--' "$MEMORY_FILE" 2>/dev/null | grep -qi "$sentinel"; then
        FOUND=$((FOUND + 1))
    fi
done

if [ "$FOUND" -lt 3 ]; then
    echo -e "${YELLOW}Memory: partially overwritten (${FOUND}/4 sentinel patterns found)${NC}"
    echo -e "${YELLOW}  To repair: Re-read .agentic/init/memory-seed.md and write patterns to memory${NC}"
    echo -e "${YELLOW}  (Preserve other project-specific memory content)${NC}"
    exit 0
fi

# --- All OK ---
if [ "$QUIET" = false ]; then
    echo -e "${GREEN}Memory: OK (v${CURRENT_VERSION}, ${FOUND}/4 sentinels)${NC}"
fi
exit 0
