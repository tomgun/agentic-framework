#!/usr/bin/env bash
# state-commit.sh — Commit state-only files to main (ag flush)
#
# WHY --no-verify IS SAFE HERE (and NOT a precedent):
# This script enforces its own validation that is STRICTER than the pre-commit
# hook: hardcoded file allowlist, branch+worktree check, diff-level FEATURES.md
# validation, JSON validation for structured files. VERSION is in the allowlist
# (bumped post-merge by ag done, which validates semver before writing).
# The hook is redundant, not bypassed. Future tool authors should NOT cite this
# as justification for --no-verify — the conditions are: (1) hardcoded file
# allowlist, (2) no user-editable configuration, (3) self-contained validation
# that rejects on any violation. If your script doesn't meet all three, use
# the hook.
#
# Usage:
#   ag flush                  # Commit + push dirty state files to main
#   ag flush --dry-run        # Show what would be committed
#   ag flush --check          # Exit 0 if dirty state exists, 1 if clean
#   ag flush --features       # Also include FEATURES.md (status-only changes)
#
# When main_branch_mode is 'protected' (F-035):
#   Creates a state/flush-<timestamp>-<pid> branch, commits state files,
#   pushes to origin, and opens a PR via gh CLI. Falls back to manual
#   PR instructions when gh is unavailable.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../paths.sh"
source "$SCRIPT_DIR/../settings.sh"

# ---------------------------------------------------------------------------
# Hardcoded allowlist — security boundary, NOT user-editable
# ---------------------------------------------------------------------------
ALLOWLIST=(
    ".agentic/STATUS.md"
    ".agentic/TODO.md"
    ".agentic/HUMAN_NEEDED.md"
    ".agentic/BACKLOG.json"
    ".agentic/journal/JOURNAL.md"
    ".agentic/CONTRIBUTIONS.md"
    "VERSION"
)
# Prefix patterns — files under these dirs are also allowed
ALLOWLIST_PREFIXES=(
    ".agentic/journal/manifests/"
)

# ---------------------------------------------------------------------------
# Parse flags
# ---------------------------------------------------------------------------
DRY_RUN=false
CHECK_ONLY=false
INCLUDE_FEATURES=false
AUTO_FLUSH=false

for arg in "$@"; do
    case "$arg" in
        --dry-run)     DRY_RUN=true ;;
        --check)       CHECK_ONLY=true ;;
        --features)    INCLUDE_FEATURES=true ;;
        --auto-flush)  AUTO_FLUSH=true ;;
        --help|-h)
            echo "Usage: ag flush [--dry-run] [--check] [--features]"
            echo ""
            echo "Commit state-only files to main."
            echo ""
            echo "Options:"
            echo "  --dry-run    Show what would be committed without committing"
            echo "  --check      Exit 0 if dirty state files exist, 1 if clean"
            echo "  --features   Also include FEATURES.md (status-line changes only)"
            echo ""
            echo "When main_branch_mode is 'protected':"
            echo "  Creates a state/flush-<timestamp> branch and opens a PR."
            echo "  Use: ag set main_branch_mode protected"
            exit 0
            ;;
        *)
            echo "Error: Unknown flag '$arg'. Use --help for usage."
            exit 1
            ;;
    esac
done

# ---------------------------------------------------------------------------
# Resolve branch mode (F-035)
# ---------------------------------------------------------------------------
_get_branch_mode() {
    local mode
    mode=$(get_setting "main_branch_mode" "direct")
    echo "$mode"
}

BRANCH_MODE=$(_get_branch_mode)

# ---------------------------------------------------------------------------
# Step 1: Branch + worktree check
# ---------------------------------------------------------------------------
cd "$PROJECT_ROOT"

# Check for in-progress rebase/merge
if [[ -d ".git/rebase-merge" ]] || [[ -d ".git/rebase-apply" ]]; then
    echo "Error: A rebase is in progress. Resolve it first (git rebase --abort or --continue)."
    exit 1
fi
if [[ -f ".git/MERGE_HEAD" ]]; then
    echo "Error: A merge is in progress. Resolve it first."
    exit 1
fi

BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
TRUNK="${AG_TRUNK_BRANCH:-}"
if [[ -z "$TRUNK" ]]; then
    # Auto-detect: default trunk is main or master
    if [[ "$BRANCH" != "main" && "$BRANCH" != "master" ]]; then
        echo "Error: ag flush only works on main/master (current branch: ${BRANCH:-detached HEAD})."
        echo "State files should be flushed from the primary checkout, not feature branches."
        exit 1
    fi
elif [[ "$BRANCH" != "$TRUNK" ]]; then
    echo "Error: ag flush only works on trunk branch '$TRUNK' (current branch: ${BRANCH:-detached HEAD})."
    exit 1
fi

# Worktree check: reject if not the primary worktree
PRIMARY_WORKTREE=$(git worktree list --porcelain 2>/dev/null | head -1 | sed 's/^worktree //')
CURRENT_TOPLEVEL=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
if [[ -n "$PRIMARY_WORKTREE" && -n "$CURRENT_TOPLEVEL" && "$PRIMARY_WORKTREE" != "$CURRENT_TOPLEVEL" ]]; then
    echo "Error: ag flush must be run from the primary worktree, not a linked worktree."
    echo "State files will be flushed after returning to main."
    exit 1
fi

# ---------------------------------------------------------------------------
# Protected mode + auto-flush: skip (F-035 AC-009)
# Creating PRs from ag todo / ag feedback is surprising — require explicit ag flush.
# ---------------------------------------------------------------------------
if [[ "$BRANCH_MODE" == "protected" ]] && $AUTO_FLUSH; then
    echo "Protected mode: skipping auto-flush (use 'ag flush' explicitly)" >&2
    exit 0
fi

# ---------------------------------------------------------------------------
# Step 2: Check remote existence
# ---------------------------------------------------------------------------
HAS_REMOTE=true
if ! git remote get-url origin >/dev/null 2>&1; then
    HAS_REMOTE=false
fi

# ---------------------------------------------------------------------------
# Step 3: Detect dirty state files
# ---------------------------------------------------------------------------
DIRTY_STATE=()
GIT_STATUS=$(git status --porcelain 2>/dev/null || echo "")

for allowed in "${ALLOWLIST[@]}"; do
    if echo "$GIT_STATUS" | grep -qF "$allowed"; then
        DIRTY_STATE+=("$allowed")
    fi
done
# Also pick up files matching prefix patterns (e.g., manifests)
for prefix in "${ALLOWLIST_PREFIXES[@]}"; do
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        file="${line:3}"  # Strip status prefix (e.g., " M ")
        if [[ "$file" == "$prefix"* ]]; then
            DIRTY_STATE+=("$file")
        fi
    done <<< "$GIT_STATUS"
done

# Step 4: FEATURES.md handling
FEATURES_FILE=".agentic/spec/FEATURES.md"
if $INCLUDE_FEATURES && echo "$GIT_STATUS" | grep -qF "$FEATURES_FILE"; then
    # Validate diff is status-only
    FEATURES_DIFF=$(git diff -- "$FEATURES_FILE" 2>/dev/null || echo "")
    # Check every added/removed content line (skip diff metadata)
    BAD_LINES=$(echo "$FEATURES_DIFF" | grep -E '^[+-]' | grep -v '^+++' | grep -v '^---' | grep -v '\*\*Status\*\*:' || true)
    if [[ -n "$BAD_LINES" ]]; then
        echo "Error: FEATURES.md has non-status changes. Use a PR for prose edits."
        echo "Non-status lines found:"
        echo "$BAD_LINES" | head -5
        exit 1
    fi
    DIRTY_STATE+=("$FEATURES_FILE")
fi

# ---------------------------------------------------------------------------
# Step 5: Reject mixed staging (non-allowlist files)
# ---------------------------------------------------------------------------
STAGED=$(git diff --cached --name-only 2>/dev/null || echo "")
if [[ -n "$STAGED" ]]; then
    # Build allowlist check set
    ALLOWED_SET=("${ALLOWLIST[@]}")
    $INCLUDE_FEATURES && ALLOWED_SET+=("$FEATURES_FILE")

    NON_ALLOWLIST=()
    while IFS= read -r staged_file; do
        [[ -z "$staged_file" ]] && continue
        is_allowed=false
        for allowed in "${ALLOWED_SET[@]}"; do
            if [[ "$staged_file" == "$allowed" ]]; then
                is_allowed=true
                break
            fi
        done
        if ! $is_allowed; then
            for prefix in "${ALLOWLIST_PREFIXES[@]}"; do
                if [[ "$staged_file" == "$prefix"* ]]; then
                    is_allowed=true
                    break
                fi
            done
        fi
        if ! $is_allowed; then
            NON_ALLOWLIST+=("$staged_file")
        fi
    done <<< "$STAGED"

    if [[ ${#NON_ALLOWLIST[@]} -gt 0 ]]; then
        echo "Error: Non-state files are staged. ag flush only commits state files."
        echo "Unstage these files first (git reset HEAD <file>):"
        for f in "${NON_ALLOWLIST[@]}"; do
            echo "  - $f"
        done
        exit 1
    fi
fi

# ---------------------------------------------------------------------------
# Step 6/7: Nothing to flush / dry-run / check
# ---------------------------------------------------------------------------
if [[ ${#DIRTY_STATE[@]} -eq 0 ]]; then
    if $CHECK_ONLY; then
        exit 1  # No dirty state = clean
    fi
    echo "Nothing to flush — all state files are clean."
    exit 0
fi

if $CHECK_ONLY; then
    exit 0  # Dirty state exists
fi

if $DRY_RUN; then
    echo "Would flush ${#DIRTY_STATE[@]} state file(s):"
    for f in "${DIRTY_STATE[@]}"; do
        echo "  $f"
    done
    echo ""
    # Preview uses same basename format as the real commit message
    _preview_names=()
    for _f in "${DIRTY_STATE[@]}"; do
        _preview_names+=("$(basename "$_f")")
    done
    local_msg="chore(state): update $(IFS=', '; echo "${_preview_names[*]}")"
    echo "Commit message: $local_msg"
    if [[ "$BRANCH_MODE" == "protected" ]]; then
        echo "Mode: protected (will create branch + PR)"
    fi
    exit 0
fi

# ---------------------------------------------------------------------------
# Step 8: Content validation
# ---------------------------------------------------------------------------
if printf '%s\n' "${DIRTY_STATE[@]}" | grep -q "BACKLOG.json"; then
    if [[ -f "$PROJECT_ROOT/.agentic/BACKLOG.json" ]]; then
        if ! python3 -m json.tool "$PROJECT_ROOT/.agentic/BACKLOG.json" >/dev/null 2>&1; then
            echo "Error: BACKLOG.json is not valid JSON. Fix before flushing."
            exit 1
        fi
    fi
fi

# ---------------------------------------------------------------------------
# Step 9: Multi-agent advisory
# ---------------------------------------------------------------------------
if command -v python3 >/dev/null 2>&1 && [[ -f "$SCRIPT_DIR/agents_helpers.py" ]]; then
    OTHERS=$(python3 "$SCRIPT_DIR/agents_helpers.py" --project-root "${MAIN_PROJECT_ROOT:-$PROJECT_ROOT}" count-others "$PROJECT_ROOT" --pid $$ 2>/dev/null || echo "0")
    if [[ "$OTHERS" -gt 0 ]]; then
        echo "Advisory: $OTHERS other agent(s) active. Proceeding — conflicts will be caught by git."
    fi
fi

# ---------------------------------------------------------------------------
# Build commit message (shared by both paths)
# ---------------------------------------------------------------------------
SHORT_NAMES=()
for f in "${DIRTY_STATE[@]}"; do
    SHORT_NAMES+=("$(basename "$f")")
done
COMMIT_MSG="chore(state): update $(IFS=', '; echo "${SHORT_NAMES[*]}")"

# ---------------------------------------------------------------------------
# Branch on mode: direct vs protected (F-035)
# ---------------------------------------------------------------------------
if [[ "$BRANCH_MODE" == "protected" ]] && ! $HAS_REMOTE; then
    echo "Error: main_branch_mode is 'protected' but no remote 'origin' found."
    echo "Protected mode requires a remote to push branches and create PRs."
    echo "Add a remote: git remote add origin <url>"
    exit 1
fi

if [[ "$BRANCH_MODE" == "protected" ]] && $HAS_REMOTE; then
    # ===================================================================
    # PROTECTED MODE: ephemeral branch + PR
    # ===================================================================
    EPHEMERAL_BRANCH="state/flush-$(date +%Y%m%d-%H%M%S)-$$"

    # Cleanup function for error recovery
    _cleanup_ephemeral() {
        git checkout "$BRANCH" 2>/dev/null || true
        git branch -D "$EPHEMERAL_BRANCH" 2>/dev/null || true
        # Unstage files so user can retry
        git reset HEAD -- "${DIRTY_STATE[@]}" 2>/dev/null || true
    }

    # Clean up previously-merged state/flush branches (best-effort, no fetch)
    for ref in $(git branch -r --merged "origin/$BRANCH" 2>/dev/null | grep 'origin/state/flush-' || true); do
        remote_branch="${ref#origin/}"
        remote_branch="${remote_branch# }"  # trim leading space
        git push origin --delete "$remote_branch" 2>/dev/null || true
    done

    # Stage dirty files
    for f in "${DIRTY_STATE[@]}"; do
        git add "$f"
    done

    # Create ephemeral branch
    if ! git checkout -b "$EPHEMERAL_BRANCH" 2>/dev/null; then
        echo "Error: Could not create branch '$EPHEMERAL_BRANCH'."
        git reset HEAD -- "${DIRTY_STATE[@]}" 2>/dev/null || true
        exit 1
    fi

    # Set ERR trap for cleanup (scoped — cleared before return)
    trap '_cleanup_ephemeral; exit 1' ERR

    # Commit on ephemeral branch
    git commit --no-verify -m "$COMMIT_MSG"

    # Push ephemeral branch
    if ! git push -u origin "$EPHEMERAL_BRANCH" 2>/dev/null; then
        echo "Error: Could not push branch '$EPHEMERAL_BRANCH' to origin."
        echo "Your changes are committed locally on '$EPHEMERAL_BRANCH'."
        _cleanup_ephemeral
        trap - ERR
        exit 1
    fi

    # Create PR via gh (if available)
    PR_URL=""
    FILE_LIST=""
    for f in "${DIRTY_STATE[@]}"; do
        FILE_LIST="${FILE_LIST}- ${f}"$'\n'
    done

    if command -v gh >/dev/null 2>&1; then
        # Best-effort label creation — idempotent, errors suppressed (already exists = OK)
        gh label create "state-only" --description "Automated state-only flush" --color "ededed" 2>/dev/null || true

        PR_BODY="Auto-generated state-only flush."$'\n\n'"Files:"$'\n'"${FILE_LIST}"
        PR_URL=$(gh pr create \
            --base "$BRANCH" \
            --head "$EPHEMERAL_BRANCH" \
            --title "$COMMIT_MSG" \
            --body "$PR_BODY" \
            --label "state-only" 2>/dev/null || echo "")

        if [[ -n "$PR_URL" ]]; then
            # Attempt auto-merge (best-effort — requires repo to have auto-merge enabled)
            gh pr merge --auto --squash --delete-branch "$PR_URL" 2>/dev/null || true
        fi
    fi

    # Clear ERR trap before checkout back to trunk
    trap - ERR

    # Return to trunk
    git checkout "$BRANCH" 2>/dev/null || true

    # Reset local state files to trunk's version to prevent duplicate flushes.
    # The modifications are preserved in the PR branch.
    for f in "${DIRTY_STATE[@]}"; do
        # git checkout works for files that exist on trunk (modified files).
        # git rm handles newly-created files that don't exist on trunk.
        git checkout "$BRANCH" -- "$f" 2>/dev/null || git rm -f "$f" 2>/dev/null || true
    done
    # Clean up any residual staging from the reset
    git reset HEAD 2>/dev/null || true

    # Summary
    echo ""
    echo "Flushed ${#DIRTY_STATE[@]} state file(s) via PR:"
    for f in "${DIRTY_STATE[@]}"; do
        echo "  ✓ $f"
    done
    echo ""
    if [[ -n "$PR_URL" ]]; then
        echo "PR: $PR_URL"
        echo "Local state will update when the PR merges and you run 'git pull'."
    else
        # gh not available or PR creation failed — print manual instructions
        REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
        echo "Branch pushed: $EPHEMERAL_BRANCH"
        if [[ -n "$REMOTE_URL" ]]; then
            echo "Create a PR manually: $REMOTE_URL"
        fi
        echo "Local state will update when the PR merges and you run 'git pull'."
    fi

else
    # ===================================================================
    # DIRECT MODE: commit + push to main (original behavior)
    # ===================================================================

    # Step 10: Stage and commit dirty files locally
    # Commit FIRST, then rebase onto remote. The old approach (stage → pull
    # --rebase → commit) breaks after squash merges: git pull --rebase with
    # staged changes creates a temp stash that can conflict with the squash
    # merge's version of the same files, even when local=remote HEAD.
    # Fix: commit locally (cheap, --no-verify), then rebase onto remote.
    for f in "${DIRTY_STATE[@]}"; do
        git add "$f"
    done

    git commit --no-verify -m "$COMMIT_MSG"

    # Step 11: Rebase onto remote (reconcile if remote moved)
    if $HAS_REMOTE; then
        if ! git pull --rebase origin "$BRANCH" 2>/dev/null; then
            # Rebase conflict — undo our commit, restore working tree
            git rebase --abort 2>/dev/null || true
            git reset --soft HEAD~1 2>/dev/null || true
            git reset HEAD -- "${DIRTY_STATE[@]}" 2>/dev/null || true
            echo "Error: State conflict during rebase onto remote. Resolve manually, then re-run: ag flush"
            echo "Hint: git pull --rebase origin $BRANCH, resolve conflicts, git rebase --continue"
            exit 1
        fi
    fi

    # Step 12: Push (if remote exists)
    if $HAS_REMOTE; then
        if ! git push origin "$BRANCH" 2>/dev/null; then
            # Push failed — reset the commit, preserve working tree
            git reset --soft HEAD~1
            echo "Error: Push failed (another agent may have pushed first)."
            echo "Your changes are preserved. Re-run: ag flush"
            exit 1
        fi
    fi

    # Summary
    echo ""
    echo "Flushed ${#DIRTY_STATE[@]} state file(s) to $BRANCH:"
    for f in "${DIRTY_STATE[@]}"; do
        echo "  ✓ $f"
    done

    if ! $HAS_REMOTE; then
        echo ""
        echo "Warning: No remote 'origin' found. Committed locally but not pushed."
    fi

    # Tip for direct workflow
    GIT_WORKFLOW=$(grep -E '^\s*-?\s*git_workflow:' "$PROJECT_ROOT/STACK.md" 2>/dev/null | head -1 | sed 's/.*: *//' | tr -d ' ' || echo "")
    if [[ "$GIT_WORKFLOW" == "direct" ]]; then
        echo ""
        echo "Tip: With direct workflow, regular commits work too. ag flush is mainly for pull_request workflow."
    fi
fi
