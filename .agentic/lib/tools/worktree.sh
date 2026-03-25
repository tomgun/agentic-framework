#!/usr/bin/env bash
# worktree.sh - Manage git worktrees for parallel agent development
#
# Usage:
#   bash .agentic/lib/tools/worktree.sh create <feature-id> "<description>"
#   bash .agentic/lib/tools/worktree.sh list
#   bash .agentic/lib/tools/worktree.sh remove <feature-id>
#   bash .agentic/lib/tools/worktree.sh auto-remove <feature-id>
#   bash .agentic/lib/tools/worktree.sh path <feature-id>
#   bash .agentic/lib/tools/worktree.sh status

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../paths.sh" 2>/dev/null || true

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Use MAIN_PROJECT_ROOT for repo root (always main repo, not worktree)
REPO_ROOT="${MAIN_PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null)}"
if [[ -z "$REPO_ROOT" ]]; then
    echo -e "${RED}Error: Not in a git repository${NC}"
    exit 1
fi

REPO_NAME=$(basename "$REPO_ROOT")
PARENT_DIR=$(dirname "$REPO_ROOT")

# Python helper for AGENTS.json
_agents_py() {
    python3 "$SCRIPT_DIR/agents_helpers.py" --project-root "$REPO_ROOT" "$@" 2>/dev/null
}

_has_python() {
    command -v python3 >/dev/null 2>&1
}

# Derive worktree path for a feature ID
_worktree_path() {
    local feature_id="$1"
    local safe_id=$(echo "$feature_id" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g')
    echo "$PARENT_DIR/${REPO_NAME}-${safe_id}"
}

# Create a new worktree
cmd_create() {
    local feature_id="$1"
    local description="$2"

    if [[ -z "$feature_id" ]]; then
        echo -e "${RED}Usage: worktree.sh create <feature-id> \"<description>\"${NC}"
        echo "Example: worktree.sh create F-001 \"User authentication\""
        exit 1
    fi

    if [[ -z "$description" ]]; then
        description="$feature_id work"
    fi

    local branch_name="feature/$feature_id"
    local worktree_path=$(_worktree_path "$feature_id")

    # Check if worktree already exists — return 0, not error (H-07)
    if [[ -d "$worktree_path" ]]; then
        # Validate it's a working tree
        if git -C "$worktree_path" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
            echo -e "${GREEN}Worktree already exists: $worktree_path${NC}"
            echo "$worktree_path"
            return 0
        else
            echo -e "${YELLOW}Directory exists but is not a valid worktree: $worktree_path${NC}"
            echo "Remove it manually or use a different feature ID."
            exit 1
        fi
    fi

    # Check if branch already exists
    if git show-ref --verify --quiet "refs/heads/$branch_name"; then
        echo -e "${YELLOW}Branch $branch_name already exists, using it${NC}"
        git worktree add "$worktree_path" "$branch_name"
    else
        echo -e "${BLUE}Creating new branch: $branch_name${NC}"
        git worktree add "$worktree_path" -b "$branch_name"
    fi

    # Validate creation (H-04)
    if ! git -C "$worktree_path" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo -e "${RED}Error: Worktree creation failed validation${NC}"
        exit 1
    fi

    echo -e "${GREEN}✓ Created worktree: $worktree_path${NC}"
    echo -e "${GREEN}✓ Branch: $branch_name${NC}"

    # Register in AGENTS.json
    if _has_python; then
        _agents_py register "$feature_id" "$worktree_path" "$branch_name" "$description" || true
    fi

    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}Ready for parallel development!${NC}"
    echo ""
    echo "To start working in this worktree:"
    echo -e "  ${YELLOW}cd $worktree_path${NC}"
    echo ""
    echo "Or open a new Claude/Cursor window in that directory."
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "$worktree_path"
}

# List active worktrees
cmd_list() {
    echo -e "${BLUE}Git Worktrees:${NC}"
    echo ""
    git worktree list
    echo ""

    if _has_python; then
        echo -e "${BLUE}Registered Agents (AGENTS.json):${NC}"
        echo ""
        _agents_py list || echo "No agents registered"
    fi
}

# Remove a worktree (interactive — prompts for confirmation)
cmd_remove() {
    local feature_id="$1"

    if [[ -z "$feature_id" ]]; then
        echo -e "${RED}Usage: worktree.sh remove <feature-id>${NC}"
        echo "Example: worktree.sh remove F-001"
        exit 1
    fi

    local worktree_path=$(_worktree_path "$feature_id")
    local branch_name="feature/$feature_id"

    # Check if worktree exists
    if [[ ! -d "$worktree_path" ]]; then
        echo -e "${YELLOW}Worktree not found: $worktree_path${NC}"
    else
        # Check for uncommitted changes
        if [[ -n $(git -C "$worktree_path" status --porcelain 2>/dev/null) ]]; then
            echo -e "${RED}Warning: Worktree has uncommitted changes!${NC}"
            echo ""
            git -C "$worktree_path" status --short
            echo ""
            read -p "Remove anyway? (y/N): " confirm
            if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
                echo "Aborted."
                exit 1
            fi
        fi

        # Remove worktree
        git worktree remove "$worktree_path" --force 2>/dev/null || rm -rf "$worktree_path"
        echo -e "${GREEN}✓ Removed worktree: $worktree_path${NC}"
    fi

    # Unregister from AGENTS.json
    if _has_python; then
        _agents_py unregister "$feature_id" || true
    fi

    # Optionally delete branch
    echo ""
    read -p "Delete branch $branch_name? (y/N): " delete_branch
    if [[ "$delete_branch" == "y" || "$delete_branch" == "Y" ]]; then
        if git branch -d "$branch_name" 2>/dev/null; then
            echo -e "${GREEN}✓ Deleted branch: $branch_name${NC}"
        else
            echo -e "${YELLOW}Branch not deleted (may have unmerged changes)${NC}"
            echo "Use 'git branch -D $branch_name' to force delete"
        fi
    fi
}

# Auto-remove worktree (non-interactive, for ag done)
cmd_auto_remove() {
    local feature_id="$1"

    if [[ -z "$feature_id" ]]; then
        echo -e "${RED}Usage: worktree.sh auto-remove <feature-id>${NC}"
        exit 1
    fi

    local worktree_path=$(_worktree_path "$feature_id")

    if [[ ! -d "$worktree_path" ]]; then
        # Not found — clean up AGENTS.json entry if exists
        if _has_python; then
            _agents_py unregister "$feature_id" 2>/dev/null || true
        fi
        return 0
    fi

    # Check for uncommitted changes (H-08: exit 1 if dirty)
    if [[ -n $(git -C "$worktree_path" status --porcelain 2>/dev/null) ]]; then
        echo -e "${YELLOW}Worktree has uncommitted changes — preserving: $worktree_path${NC}"
        echo "  Clean up manually: git worktree remove $worktree_path --force"
        exit 1
    fi

    # Remove worktree (no --force: dirty check above already confirmed clean)
    if ! git worktree remove "$worktree_path" 2>/dev/null; then
        echo -e "${RED}Failed to remove worktree: $worktree_path${NC}"
        echo "  Remove manually: git worktree remove $worktree_path"
        exit 1
    fi
    echo -e "${GREEN}✓ Auto-removed worktree: $worktree_path${NC}"

    # Unregister from AGENTS.json
    if _has_python; then
        _agents_py unregister "$feature_id" 2>/dev/null || true
    fi
}

# Print worktree path for a feature ID
cmd_path() {
    local feature_id="$1"
    if [[ -z "$feature_id" ]]; then
        echo -e "${RED}Usage: worktree.sh path <feature-id>${NC}"
        exit 1
    fi
    _worktree_path "$feature_id"
}

# Show current worktree status
cmd_status() {
    local current_worktree=$(git rev-parse --show-toplevel 2>/dev/null)
    local current_branch=$(git branch --show-current 2>/dev/null)

    echo -e "${BLUE}Current Worktree Status:${NC}"
    echo ""
    echo "  Path:   $current_worktree"
    echo "  Branch: $current_branch"
    echo ""

    # Check if this is a worktree (not main repo)
    local git_common=$(git rev-parse --git-common-dir 2>/dev/null)
    local git_dir=$(git rev-parse --git-dir 2>/dev/null)

    if [[ "$git_common" != "$git_dir" ]]; then
        echo -e "${YELLOW}This is a worktree (not the main repository)${NC}"
        echo "  Main repo: $(dirname "$git_common")"
    else
        echo "This is the main repository"
    fi

    echo ""
    cmd_list
}

# Help
cmd_help() {
    cat << 'EOF'
worktree.sh - Manage git worktrees for parallel agent development

USAGE:
    worktree.sh <command> [arguments]

COMMANDS:
    create <id> "<desc>"   Create new worktree for feature/task
    list                   List all worktrees and registered agents
    remove <id>            Remove worktree (interactive, prompts)
    auto-remove <id>       Remove worktree (non-interactive, for ag done)
    path <id>              Print worktree path for feature ID
    status                 Show current worktree status
    help                   Show this help

EXAMPLES:
    # Create worktree for feature F-001
    worktree.sh create F-001 "User authentication"

    # Creates: ../project-f-0001/ on branch feature/F-001
    # Registers in AGENTS.json

    # List all worktrees
    worktree.sh list

    # Get path for a feature
    worktree.sh path F-001

    # Remove when done (will prompt about uncommitted changes)
    worktree.sh remove F-001

    # Auto-remove (non-interactive, used by ag done)
    worktree.sh auto-remove F-001

EOF
}

# Main
case "${1:-}" in
    create)
        cmd_create "${2:-}" "${3:-}"
        ;;
    list)
        cmd_list
        ;;
    remove|delete)
        cmd_remove "${2:-}"
        ;;
    auto-remove)
        cmd_auto_remove "${2:-}"
        ;;
    path)
        cmd_path "${2:-}"
        ;;
    status)
        cmd_status
        ;;
    help|--help|-h)
        cmd_help
        ;;
    *)
        if [[ -n "${1:-}" ]]; then
            echo -e "${RED}Unknown command: $1${NC}"
            echo ""
        fi
        cmd_help
        exit 1
        ;;
esac
