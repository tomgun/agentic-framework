#!/usr/bin/env bash
# gitignore.sh — Stack-aware .gitignore generator (F-0250)
# Reads STACK.md to detect language/framework, generates appropriate .gitignore.
# Called by `ag git-init` or standalone `ag gitignore`.
# Merges with existing .gitignore (no duplicate entries).
#
# Usage: bash .agentic/lib/tools/gitignore.sh [--stdout]
#   --stdout: Print to stdout instead of writing to .gitignore

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"

STDOUT_MODE=false
[[ "${1:-}" == "--stdout" ]] && STDOUT_MODE=true

# ---------------------------------------------------------------------------
# Detect stack from STACK.md
# ---------------------------------------------------------------------------
STACK_FILE="$ROOT_DIR/STACK.md"
DETECTED_LANG=""
DETECTED_PKG=""
DETECTED_FRAMEWORK=""

if [[ -f "$STACK_FILE" ]]; then
    # Extract language(s)
    DETECTED_LANG=$(grep -i "^- Language" "$STACK_FILE" 2>/dev/null | head -1 | sed 's/.*: //' | tr '[:upper:]' '[:lower:]' || true)

    # Extract package manager
    DETECTED_PKG=$(grep -i "^- Package manager" "$STACK_FILE" 2>/dev/null | head -1 | sed 's/.*: //' | tr '[:upper:]' '[:lower:]' || true)

    # Extract framework
    DETECTED_FRAMEWORK=$(grep -i "^- App framework" "$STACK_FILE" 2>/dev/null | head -1 | sed 's/.*: //' | tr '[:upper:]' '[:lower:]' || true)
fi

# Fallback: detect from project files
if [[ -z "$DETECTED_LANG" ]]; then
    [[ -f "$ROOT_DIR/package.json" ]] && DETECTED_LANG="typescript"
    [[ -f "$ROOT_DIR/requirements.txt" || -f "$ROOT_DIR/pyproject.toml" ]] && DETECTED_LANG="python"
    [[ -f "$ROOT_DIR/Cargo.toml" ]] && DETECTED_LANG="rust"
    [[ -f "$ROOT_DIR/go.mod" ]] && DETECTED_LANG="go"
fi

if [[ -z "$DETECTED_PKG" ]]; then
    [[ -f "$ROOT_DIR/pnpm-lock.yaml" ]] && DETECTED_PKG="pnpm"
    [[ -f "$ROOT_DIR/yarn.lock" ]] && DETECTED_PKG="yarn"
    [[ -f "$ROOT_DIR/package-lock.json" ]] && DETECTED_PKG="npm"
fi

# ---------------------------------------------------------------------------
# Build gitignore entries
# ---------------------------------------------------------------------------
ENTRIES=()

# Always: framework session state
ENTRIES+=(
    "# Agentic framework (session state)"
    ".agentic/session/"
    ".agentic/debug/"
    ".agentic/pipeline/"
    ".agentic/local/"
    ".agentic/lib/"
    "# Intel engine (derived/session-scoped)"
    ".agentic/intel/anatomy.index"
    ".agentic/intel/token-summary.json"
    ""
)

# Always: general
ENTRIES+=(
    "# General"
    ".DS_Store"
    "*.log"
    "*.tmp"
    "*.cache"
    ""
)

# Always: environment files
ENTRIES+=(
    "# Environment"
    ".env"
    ".env.local"
    ".env.*.local"
    ""
)

# Node / TypeScript
if echo "$DETECTED_LANG" | grep -qi "typescript\|javascript\|node"; then
    ENTRIES+=(
        "# Node / TypeScript"
        "node_modules/"
        "dist/"
        "build/"
        ".next/"
        ".nuxt/"
        "coverage/"
        ""
    )
fi

# pnpm specific
if echo "$DETECTED_PKG" | grep -qi "pnpm"; then
    ENTRIES+=(
        "# pnpm"
        ".pnpm-store/"
        ""
    )
fi

# yarn specific
if echo "$DETECTED_PKG" | grep -qi "yarn"; then
    ENTRIES+=(
        "# Yarn"
        ".yarn/cache/"
        ".yarn/unplugged/"
        ".yarn/install-state.gz"
        ""
    )
fi

# Python
if echo "$DETECTED_LANG" | grep -qi "python"; then
    ENTRIES+=(
        "# Python"
        "__pycache__/"
        "*.pyc"
        "*.pyo"
        ".venv/"
        "venv/"
        "*.egg-info/"
        ".mypy_cache/"
        ".pytest_cache/"
        ""
    )
fi

# Rust
if echo "$DETECTED_LANG" | grep -qi "rust"; then
    ENTRIES+=(
        "# Rust"
        "target/"
        ""
    )
fi

# Go
if echo "$DETECTED_LANG" | grep -qi "go"; then
    ENTRIES+=(
        "# Go"
        "vendor/"
        ""
    )
fi

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------

if $STDOUT_MODE; then
    printf '%s\n' "${ENTRIES[@]}"
    exit 0
fi

GITIGNORE="$ROOT_DIR/.gitignore"

if [[ -f "$GITIGNORE" ]]; then
    # Merge: only add entries that don't already exist
    EXISTING=$(cat "$GITIGNORE")
    ADDED=0
    for entry in "${ENTRIES[@]}"; do
        # Skip comments and empty lines for matching
        if [[ "$entry" == "#"* || -z "$entry" ]]; then
            continue
        fi
        # Check if pattern already in .gitignore
        if ! grep -qF "$entry" "$GITIGNORE" 2>/dev/null; then
            echo "$entry" >> "$GITIGNORE"
            ADDED=$((ADDED + 1))
        fi
    done
    if [[ $ADDED -gt 0 ]]; then
        echo -e "\033[32m✓\033[0m Updated .gitignore ($ADDED new entries added)"
    else
        echo -e "\033[32m✓\033[0m .gitignore already up to date"
    fi
else
    # Create new .gitignore
    printf '%s\n' "${ENTRIES[@]}" > "$GITIGNORE"
    TOTAL=$(printf '%s\n' "${ENTRIES[@]}" | grep -v '^#' | grep -v '^$' | wc -l | tr -d ' ')
    echo -e "\033[32m✓\033[0m Created .gitignore ($TOTAL patterns, stack: ${DETECTED_LANG:-unknown})"
fi
