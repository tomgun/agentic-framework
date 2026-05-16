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
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
source "$SCRIPT_DIR/../paths.sh"

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
# Convention: MAIN git repo root → replace '/' with '-' (including leading /).
# Worktree fix: --show-toplevel returns the WORKTREE path. Claude Code's
# MEMORY.md is keyed off the MAIN repo path, so we resolve via
# --git-common-dir (which points at <main>/.git from any worktree).
COMMON_DIR="$(git -C "$ROOT_DIR" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || {
    if [ "$QUIET" = false ]; then
        echo -e "${DIM}Memory check: skipped (not a git repo)${NC}"
    fi
    exit 0
}
MAIN_REPO_ROOT="${COMMON_DIR%/.git}"
# Sanity gate: a usable main repo has .agentic/ at its root. If not (bare
# repo, repo literally named foo.git, or other oddity), fall back to
# --show-toplevel — better the old behavior than a wrong path.
if [ ! -d "$MAIN_REPO_ROOT/.agentic" ]; then
    MAIN_REPO_ROOT="$(git -C "$ROOT_DIR" rev-parse --show-toplevel 2>/dev/null)" || MAIN_REPO_ROOT=""
fi
if [ -z "$MAIN_REPO_ROOT" ]; then
    if [ "$QUIET" = false ]; then
        echo -e "${DIM}Memory check: skipped (couldn't resolve main repo root)${NC}"
    fi
    exit 0
fi

PROJECT_HASH="$(echo "$MAIN_REPO_ROOT" | tr '/' '-')"
MEMORY_FILE="$HOME/.claude/projects/${PROJECT_HASH}/memory/MEMORY.md"

# --- Get expected version from memory-seed.md ---
SEED_FILE="$MAIN_REPO_ROOT/.agentic/lib/init/memory-seed.md"
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

    # Try to emit structured PATCH blocks the agent can apply directly.
    # If anything in the resolver fails, fall back to the "re-read it"
    # advisory — the check stays advisory either way.
    SEED_REPO_PATH=".agentic/lib/init/memory-seed.md"
    PRIOR_REV=""
    if [ -n "$CURRENT_VERSION" ]; then
        # Most recent commit whose diff touched the v${CURRENT_VERSION} line.
        # (-1 returns newest match, which is the introducing commit unless
        # someone wrote about that version in an unrelated commit later.)
        PRIOR_REV="$(git -C "$MAIN_REPO_ROOT" log -1 --format=%H \
            -S "memory-seed v${CURRENT_VERSION}" -- "$SEED_REPO_PATH" 2>/dev/null || echo "")"
    fi

    if [ -n "$PRIOR_REV" ] && [ -x "$SCRIPT_DIR/memory-diff.sh" ]; then
        echo -e "${DIM}  Computing structured diff from $PRIOR_REV (v${CURRENT_VERSION} era) → HEAD ...${NC}"
        # Run from the main repo so git context is correct
        (cd "$MAIN_REPO_ROOT" && bash "$SCRIPT_DIR/memory-diff.sh" \
            --rev "$PRIOR_REV" "$SEED_REPO_PATH" "$SEED_FILE") \
            2> >(grep -v '^$' >&2 || true)
        echo
        echo -e "${YELLOW}  Apply each PATCH block above to your MEMORY.md:${NC}"
        echo -e "${YELLOW}    MODIFY → Edit calls with old_string from '-' lines, new_string from '+' lines${NC}"
        echo -e "${YELLOW}    ADD    → insert the new section${NC}"
        echo -e "${YELLOW}    REMOVE → delete the section${NC}"
        echo -e "${YELLOW}  Preserve project-specific entries outside framework sections.${NC}"
    else
        echo -e "${YELLOW}  Couldn't reconstruct diff (no commit for v${CURRENT_VERSION:-unknown}).${NC}"
        echo -e "${YELLOW}  To update: Re-read $SEED_REPO_PATH and update memory${NC}"
        echo -e "${YELLOW}  (Preserve other project-specific memory content)${NC}"
    fi
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
