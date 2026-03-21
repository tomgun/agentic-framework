#!/usr/bin/env bash
# commands/git-init.sh — Activate git version control (F-0250)
# Sourced by ag.sh — do NOT execute directly.
# Depends on: SCRIPT_DIR, ROOT_DIR, PROFILE, color codes, paths.sh, settings.sh

cmd_git_init() {
    echo -e "${BOLD}=== Git Init ===${NC}"
    echo ""

    # Check if already active
    local git_mode
    git_mode=$(get_setting "git_mode" "deferred")
    if [[ "$git_mode" == "active" ]]; then
        echo -e "${GREEN}Git already active.${NC}"
        echo "  git_mode: active in STACK.md"
        if git rev-parse --git-dir >/dev/null 2>&1; then
            local commit_count
            commit_count=$(git rev-list --count HEAD 2>/dev/null || echo "0")
            echo "  Commits: $commit_count"
        fi
        return 0
    fi

    # Check git binary
    if ! command -v git >/dev/null 2>&1; then
        echo -e "${RED}ERROR: git is not installed.${NC}"
        echo "  Install git to enable version control."
        echo "  macOS: brew install git"
        echo "  Ubuntu: sudo apt install git"
        return 1
    fi

    # Step 1: git init (if needed)
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        git init
        echo -e "${GREEN}✓${NC} Git repository initialized"
    else
        echo -e "${GREEN}✓${NC} Git repository already exists"
    fi

    # Step 2: Generate stack-aware .gitignore (BEFORE any git add)
    echo ""
    echo "Generating .gitignore..."
    if [[ -f "$SCRIPT_DIR/gitignore.sh" ]]; then
        bash "$SCRIPT_DIR/gitignore.sh"
    else
        # Minimal fallback if gitignore.sh is missing
        if [[ ! -f "$ROOT_DIR/.gitignore" ]]; then
            cat > "$ROOT_DIR/.gitignore" <<'GITIGNORE'
# Agentic framework (session state)
.agentic/session/
.agentic/pipeline/
.agentic/local/

# General
.DS_Store
*.log
GITIGNORE
            echo -e "${GREEN}✓${NC} Created .gitignore (minimal)"
        fi
    fi

    # Step 3: Set core.hooksPath
    local git_ver git_major git_minor
    git_ver=$(git --version | grep -oE '[0-9]+\.[0-9]+' | head -1)
    git_major=$(echo "$git_ver" | cut -d. -f1)
    git_minor=$(echo "$git_ver" | cut -d. -f2)
    if [[ "$git_major" -gt 2 ]] || [[ "$git_major" -eq 2 && "$git_minor" -ge 9 ]]; then
        git config core.hooksPath .agentic/hooks
        echo -e "${GREEN}✓${NC} Git hooks configured (core.hooksPath = .agentic/hooks)"
    else
        if [[ -f "$ROOT_DIR/.agentic/hooks/pre-commit" ]]; then
            mkdir -p "$ROOT_DIR/.git/hooks"
            cp "$ROOT_DIR/.agentic/hooks/pre-commit" "$ROOT_DIR/.git/hooks/pre-commit"
            chmod +x "$ROOT_DIR/.git/hooks/pre-commit"
            echo -e "${GREEN}✓${NC} Git hooks installed (.git/hooks/ fallback for git < 2.9)"
        fi
    fi

    # Step 4: Stage and commit framework scaffold files only
    echo ""
    echo "Creating initial commit (framework scaffold files only)..."

    local scaffold_files=(
        ".gitignore"
        "STACK.md"
        "CONTEXT_PACK.md"
        "CLAUDE.md"
        "AGENTS.md"
        ".cursorrules"
    )

    local scaffold_dirs=(
        ".agentic/STATUS.md"
        ".agentic/OVERVIEW.md"
        ".agentic/HUMAN_NEEDED.md"
        ".agentic/TODO.md"
        ".agentic/spec"
        ".agentic/journal"
        ".agentic/hooks"
        ".claude"
    )

    local staged=0
    local f d
    for f in "${scaffold_files[@]}"; do
        if [[ -f "$ROOT_DIR/$f" ]]; then
            git add "$f" 2>/dev/null && staged=$((staged + 1))
        fi
    done

    for d in "${scaffold_dirs[@]}"; do
        if [[ -e "$ROOT_DIR/$d" ]]; then
            git add "$d" 2>/dev/null && staged=$((staged + 1))
        fi
    done

    if [[ $staged -gt 0 ]]; then
        git commit -m "$(cat <<'EOF'
chore: initialize agentic framework

Framework scaffold files committed. User source code not included —
run `git add src/` (or relevant directories) to start tracking your code.
EOF
        )" 2>/dev/null
        echo -e "${GREEN}✓${NC} Initial commit created ($staged scaffold items)"
    else
        echo -e "${YELLOW}No scaffold files to commit${NC}"
    fi

    # Step 5: Update STACK.md git_mode to active
    if [[ -f "$ROOT_DIR/STACK.md" ]]; then
        if grep -q "^- git_mode:" "$ROOT_DIR/STACK.md"; then
            sed -i.bak 's/^- git_mode:.*/- git_mode: active/' "$ROOT_DIR/STACK.md"
            rm -f "$ROOT_DIR/STACK.md.bak" 2>/dev/null
        else
            # Add git_mode after profile line
            sed -i.bak '/^- profile:/a\- git_mode: active' "$ROOT_DIR/STACK.md"
            rm -f "$ROOT_DIR/STACK.md.bak" 2>/dev/null
        fi
        # Amend commit with updated STACK.md
        git add STACK.md 2>/dev/null
        git commit --amend --no-edit 2>/dev/null
        echo -e "${GREEN}✓${NC} STACK.md updated: git_mode: active"
    fi

    # Step 6: Show summary
    echo ""
    echo -e "${BOLD}Git initialized successfully.${NC}"
    echo ""

    # Show what's NOT tracked
    local untracked
    untracked=$(git status --porcelain 2>/dev/null | grep '^??' | sed 's/^?? //' | head -15)
    if [[ -n "$untracked" ]]; then
        echo "Untracked files (your code — add when ready):"
        echo "$untracked" | while read -r f; do
            echo "  $f"
        done
        echo ""
        echo "Next: git add <files> to start tracking your code"
    fi

    echo ""
    echo "You can now use: ag commit, ag merge, ag auto task/epic"
}
