#!/bin/bash
# worktree.sh - Manage git worktrees for parallel agent development
#
# Usage:
#   bash .agentic/tools/worktree.sh create <feature-id> "<description>"
#   bash .agentic/tools/worktree.sh list
#   bash .agentic/tools/worktree.sh remove <feature-id>
#   bash .agentic/tools/worktree.sh status
#
# Examples:
#   bash .agentic/tools/worktree.sh create F-0001 "User authentication"
#   bash .agentic/tools/worktree.sh create auth "Login system"  # non-feature work
#   bash .agentic/tools/worktree.sh list
#   bash .agentic/tools/worktree.sh remove F-0001

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get repo root
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [[ -z "$REPO_ROOT" ]]; then
    echo -e "${RED}Error: Not in a git repository${NC}"
    exit 1
fi

AGENTS_FILE="$REPO_ROOT/.agentic/AGENTS_ACTIVE.md"
REPO_NAME=$(basename "$REPO_ROOT")
PARENT_DIR=$(dirname "$REPO_ROOT")

# Ensure AGENTS_ACTIVE.md exists
ensure_agents_file() {
    if [[ ! -f "$AGENTS_FILE" ]]; then
        mkdir -p "$(dirname "$AGENTS_FILE")"
        cat > "$AGENTS_FILE" << 'EOF'
# Active Agents

<!-- Auto-managed by worktree.sh -->
<!-- Agents register here when starting work -->

## Currently Active

<!-- No agents currently active -->
EOF
        echo -e "${GREEN}Created .agentic/AGENTS_ACTIVE.md${NC}"
    fi
}

# Create a new worktree
cmd_create() {
    local feature_id="$1"
    local description="$2"

    if [[ -z "$feature_id" ]]; then
        echo -e "${RED}Usage: worktree.sh create <feature-id> \"<description>\"${NC}"
        echo "Example: worktree.sh create F-0001 \"User authentication\""
        exit 1
    fi

    if [[ -z "$description" ]]; then
        description="$feature_id work"
    fi

    # Normalize feature ID for branch/path naming
    local safe_id=$(echo "$feature_id" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g')
    local branch_name="feature/$feature_id"
    local worktree_path="$PARENT_DIR/${REPO_NAME}-${safe_id}"

    # Check if worktree already exists
    if [[ -d "$worktree_path" ]]; then
        echo -e "${YELLOW}Worktree already exists: $worktree_path${NC}"
        echo "Use 'worktree.sh remove $feature_id' first if you want to recreate it."
        exit 1
    fi

    # Check if branch already exists
    if git show-ref --verify --quiet "refs/heads/$branch_name"; then
        echo -e "${YELLOW}Branch $branch_name already exists, using it${NC}"
        git worktree add "$worktree_path" "$branch_name"
    else
        echo -e "${BLUE}Creating new branch: $branch_name${NC}"
        git worktree add "$worktree_path" -b "$branch_name"
    fi

    echo -e "${GREEN}✓ Created worktree: $worktree_path${NC}"
    echo -e "${GREEN}✓ Branch: $branch_name${NC}"

    # Register in AGENTS_ACTIVE.md
    ensure_agents_file
    register_agent "$feature_id" "$description" "$worktree_path" "$branch_name"

    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}Ready for parallel development!${NC}"
    echo ""
    echo "To start working in this worktree:"
    echo -e "  ${YELLOW}cd $worktree_path${NC}"
    echo ""
    echo "Or open a new Claude/Cursor window in that directory."
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Register agent in AGENTS_ACTIVE.md
register_agent() {
    local feature_id="$1"
    local description="$2"
    local worktree_path="$3"
    local branch_name="$4"
    local timestamp=$(date '+%Y-%m-%d %H:%M')

    # Remove the "no agents" placeholder if present
    sed -i.bak '/<!-- No agents currently active -->/d' "$AGENTS_FILE" && rm -f "$AGENTS_FILE.bak"

    # Add agent entry
    cat >> "$AGENTS_FILE" << EOF

### $feature_id
- **Description**: $description
- **Worktree**: $worktree_path
- **Branch**: $branch_name
- **Started**: $timestamp
- **Status**: active
EOF

    echo -e "${GREEN}✓ Registered in .agentic/AGENTS_ACTIVE.md${NC}"
}

# List active worktrees
cmd_list() {
    echo -e "${BLUE}Git Worktrees:${NC}"
    echo ""
    git worktree list
    echo ""

    if [[ -f "$AGENTS_FILE" ]]; then
        echo -e "${BLUE}Registered Agents (.agentic/AGENTS_ACTIVE.md):${NC}"
        echo ""
        grep -A5 "^### " "$AGENTS_FILE" 2>/dev/null || echo "No agents registered"
    else
        echo -e "${YELLOW}No .agentic/AGENTS_ACTIVE.md file${NC}"
    fi
}

# Remove a worktree
cmd_remove() {
    local feature_id="$1"

    if [[ -z "$feature_id" ]]; then
        echo -e "${RED}Usage: worktree.sh remove <feature-id>${NC}"
        echo "Example: worktree.sh remove F-0001"
        exit 1
    fi

    local safe_id=$(echo "$feature_id" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g')
    local worktree_path="$PARENT_DIR/${REPO_NAME}-${safe_id}"
    local branch_name="feature/$feature_id"

    # Check if worktree exists
    if [[ ! -d "$worktree_path" ]]; then
        echo -e "${YELLOW}Worktree not found: $worktree_path${NC}"
        # Still try to clean up AGENTS_ACTIVE.md
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

    # Unregister from AGENTS_ACTIVE.md
    if [[ -f "$AGENTS_FILE" ]]; then
        # Remove the agent section (### feature_id through next ### or end)
        # Using awk for cross-platform compatibility
        awk -v id="$feature_id" '
            /^### / {
                if ($2 == id) { skip=1; next }
                else { skip=0 }
            }
            !skip { print }
        ' "$AGENTS_FILE" > "$AGENTS_FILE.tmp" && mv "$AGENTS_FILE.tmp" "$AGENTS_FILE"

        echo -e "${GREEN}✓ Unregistered from .agentic/AGENTS_ACTIVE.md${NC}"
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
        echo "  Main repo: $git_common"
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
    remove <id>            Remove worktree and unregister
    status                 Show current worktree status
    help                   Show this help

EXAMPLES:
    # Create worktree for feature F-0001
    worktree.sh create F-0001 "User authentication"

    # Creates: ../project-f-0001/ on branch feature/F-0001
    # Registers in .agentic/AGENTS_ACTIVE.md

    # List all worktrees
    worktree.sh list

    # Remove when done (will prompt about uncommitted changes)
    worktree.sh remove F-0001

WORKFLOW:
    1. Main window: worktree.sh create F-0001 "Auth feature"
    2. Open new Claude/Cursor in ../project-f-0001/
    3. Work in parallel - no conflicts!
    4. Create PRs from each branch
    5. Merge PRs
    6. Cleanup: worktree.sh remove F-0001

EOF
}

# Main
case "${1:-}" in
    create)
        cmd_create "$2" "$3"
        ;;
    list)
        cmd_list
        ;;
    remove|delete)
        cmd_remove "$2"
        ;;
    status)
        cmd_status
        ;;
    help|--help|-h)
        cmd_help
        ;;
    *)
        if [[ -n "$1" ]]; then
            echo -e "${RED}Unknown command: $1${NC}"
            echo ""
        fi
        cmd_help
        exit 1
        ;;
esac
