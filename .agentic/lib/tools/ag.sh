#!/usr/bin/env bash
# ag.sh - Agentic Framework Gateway
# Single entry point for all framework operations
# Works with any AI agent (Claude Code, Cursor, Codex, Copilot)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${ROOT_DIR:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"

# Source shared libraries
source "$SCRIPT_DIR/../paths.sh"
source "$SCRIPT_DIR/../settings.sh"
source "$SCRIPT_DIR/intent-helpers.sh"
source "$SCRIPT_DIR/ac-parse.sh"

# Colors (disabled if not TTY)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    BOLD='\033[1m'
    DIM='\033[2m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' BOLD='' DIM='' NC=''
fi

# Profile resolved via settings.sh (sourced above)
PROFILE=$(get_setting "profile" "discovery")

# ---------------------------------------------------------------------------
# AGENTS.json helpers (F-0194: replaces direct WIP.md checks)
# ---------------------------------------------------------------------------
_agents_py() {
    command -v python3 >/dev/null 2>&1 || return 1
    python3 "$SCRIPT_DIR/agents_helpers.py" --project-root "${MAIN_PROJECT_ROOT:-$ROOT_DIR}" "$@"
}
_has_active_wip() {
    _agents_py check-worktree "$PROJECT_ROOT" >/dev/null 2>&1
}
_get_wip_feature() {
    _agents_py get-current-feature "$PROJECT_ROOT" 2>/dev/null || echo ""
}

# Resolve plan file for a feature ID — handles both dated and non-dated filenames.
# Returns the path of the first matching plan, preferring dated files.
# Usage: plan_file=$(_find_plan_file "$feature_id")
_find_plan_file() {
    local fid="$1"
    local plans_dir="$ROOT_DIR/.agentic/journal/plans"
    [ -d "$plans_dir" ] || return 1
    # Glob matches: YYYY-MM-DD-F-XXXX-plan.md or F-XXXX-plan.md
    local match
    match=$(find "$plans_dir" \( -name "*${fid}-plan.md" -o -name "*${fid}-plan-*.md" \) -type f 2>/dev/null | sort -r | head -1)
    [ -n "$match" ] && echo "$match" && return 0
    return 1
}

# Generate a dated plan filename: YYYY-MM-DD-F-XXXX-plan.md
_plan_filename() {
    echo "$(date +%Y-%m-%d)-${1}-plan.md"
}

# Check if profile is formal or autonomous_formal (both require strict enforcement)
_is_formal_like() {
    local p
    p=$(get_setting "profile" "discovery")
    [[ "$p" == "formal" || "$p" == "autonomous_formal" ]]
}

# Check if framework is installed but not initialized
check_initialization() {
    local issues=()

    # Check STACK.md for placeholder content
    if [ -f "$ROOT_DIR/STACK.md" ]; then
        if grep -q "What are we building:.*<!--" "$ROOT_DIR/STACK.md" 2>/dev/null; then
            issues+=("STACK.md not filled in")
        fi
        if grep -q "Primary platform:.*<!--" "$ROOT_DIR/STACK.md" 2>/dev/null; then
            issues+=("Platform not specified")
        fi
        if grep -q "Language(s):.*<!--" "$ROOT_DIR/STACK.md" 2>/dev/null; then
            issues+=("Tech stack not defined")
        fi
    fi

    # Check CONTEXT_PACK.md for placeholder content
    if [ -f "$ROOT_DIR/CONTEXT_PACK.md" ]; then
        if grep -q "What this repo is:.*<!--" "$ROOT_DIR/CONTEXT_PACK.md" 2>/dev/null; then
            issues+=("CONTEXT_PACK.md not filled in")
        fi
        if grep -q "Entry points:.*<!--" "$ROOT_DIR/CONTEXT_PACK.md" 2>/dev/null; then
            issues+=("Entry points not documented")
        fi
    fi

    # Check STATUS.md for placeholder content
    if [ -f "$ROOT_DIR/STATUS.md" ]; then
        if grep -q "what we are doing right now" "$ROOT_DIR/STATUS.md" 2>/dev/null; then
            issues+=("STATUS.md has template content")
        fi
    fi

    # If issues found, this is likely not initialized
    if [ ${#issues[@]} -gt 3 ]; then
        return 1  # Not initialized (4+ placeholder issues)
    fi
    return 0  # Initialized (or close enough)
}

# Show initialization warning
show_init_warning() {
    echo ""
    echo -e "${RED}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  ⚠️  FRAMEWORK INSTALLED BUT NOT INITIALIZED                   ║${NC}"
    echo -e "${RED}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}The Agentic Framework was installed but the init interview${NC}"
    echo -e "${YELLOW}was not completed. Key files still have placeholder content.${NC}"
    echo ""
    echo -e "${BOLD}What's missing:${NC}"

    # Show specific missing items
    if grep -q "What are we building:.*<!--" "$ROOT_DIR/STACK.md" 2>/dev/null; then
        echo "  • STACK.md: Project description, tech stack, languages"
    fi
    if grep -q "What this repo is:.*<!--" "$ROOT_DIR/CONTEXT_PACK.md" 2>/dev/null; then
        echo "  • CONTEXT_PACK.md: Architecture overview, entry points"
    fi
    if grep -q "what we are doing right now" "$ROOT_DIR/STATUS.md" 2>/dev/null; then
        echo "  • STATUS.md: Current focus and project status"
    fi

    echo ""
    echo -e "${BOLD}To initialize:${NC}"
    echo "  Run: ag init"
    echo "  Or ask your AI agent: \"Let's initialize this project\""
    echo ""
    echo -e "${BOLD}The init interview will:${NC}"
    echo "  1. Choose profile (Discovery vs Formal)"
    echo "  2. Define tech stack and project goals"
    echo "  3. Set up AI tool integrations"
    echo "  4. Configure quality gates"
    echo ""
    echo -e "See: ${BLUE}.agentic/init/init_playbook.md${NC} for full details"
    echo ""
}

show_help() {
    local ft
    ft=$(get_setting "feature_tracking" "no")
    if [ "$ft" = "no" ]; then
        cat << 'EOF'
ag - Agentic Framework Gateway

USAGE:
    ag <command> [options]

COMMANDS:
    start               Session start checks + context summary
    init                Run project initialization interview
    work "description"  Start WIP tracking for a task
    todo <args>         Quick-capture ideas/tasks to TODO.md inbox
    commit              Run all pre-commit gates
    done                Task complete validation
    flush [opts]        Commit state files to main (no PR). --dry-run, --check, --features
    dogfood [--brief]   Detect root vs template instruction file drift (framework-dev)
    docs [F-XXXX]       Draft docs from registry (STACK.md ## Docs)
    set [key] [value]   View/change settings (--show, --validate, --migrate)
    hooks <sub>         Manage git hooks (install|status|disable)
    approve-onboarding  Review/approve auto-discovered proposals
    trace [options]     Spec-code traceability (drift + coverage)
    test llm [options]  Run LLM behavioral tests
    agents <sub>        Project agent management (generate|list|clean)
    tools               List all available tools by category
    backlog <sub>       Ordered work queue (add|list|done|move|remove|clear)
    auto <sub>           Autonomous workflow (init|epic|status|pause|resume|stop|feedback)
    coord <sub>          Coordination server (start|stop|status)
    transition F-XXXX <state>  Manage feature state transitions (--status, --next, --dry-run, --unblocked)
    review [F-XXXX] [state]    Review checkpoint management (--approve, --reject, --reason)
    kickoff <sub>       Vision-to-backlog pipeline (prompt|--review|--approve|--discard|--status)
    decompose F-XXXX    Break epic into child features by component
    audit [options]     Spec verification & QA audit (--full, --status, --propagate, --metrics)
    nfr [sub]           NFR management (list, discover, coverage)
    worktree <sub>      Manage git worktrees (create|list|remove|path|status)
    intent [sub]        Manage intent journal (list|clear F-XXXX)
    formalize [T-XXXX...]  Promote TODO items to formal features + AC stubs
    sync [--check|--quiet] Detect drift across all artifacts, auto-fix safe errors
    verify [--full]     Run doctor verification
    run                 Show how to run this project
    status              Show current project status
    help                Show this help

EXAMPLES:
    ag start                    # Begin a new session
    ag init                     # Initialize project (if not done)
    ag run                      # Show how to run this project
    ag backlog add --task "X"   # Add task to work queue
    ag backlog list             # Show ordered queue
    ag work "Add login form"    # Start working on a task
    ag todo "Try new library"   # Capture idea to TODO.md
    ag todo list                # Show inbox items
    ag todo done T-0001 "done"  # Resolve item
    ag flush                    # Commit state files to main
    ag flush --dry-run          # Preview what would be flushed
    ag docs                     # Draft docs for current work
    ag docs --list              # Show doc registry
    ag docs generate            # Generate all deferred docs
    ag auto init                # Set up auto mode settings
    ag auto status              # Check engine state
    ag auto pause               # Pause running engine
    ag intent list              # Show pending/orphaned intents
    ag intent clear F-0042      # Cancel a stuck intent
    ag sync                     # Full sync: detect + auto-fix
    ag sync --check             # Dry run: detect only
    ag commit                   # Verify ready to commit
    ag done                     # Check task completion
    ag approve-onboarding       # List unapproved proposals
    ag approve-onboarding --all # Approve all proposals
    ag trace                    # Full drift + coverage report
    ag trace --gaps             # Show only gaps
    ag test llm                 # Run all LLM behavioral tests
    ag test llm --critical      # Run critical tests only
    ag tools                    # Discover available tools
    ag agents generate          # Generate project-specific agents from stack
    ag agents generate --dry-run # Preview what would be generated
    ag agents list              # List current project agents

No formal feature tracking. Use STATUS.md for focus.
EOF
    else
        cat << 'EOF'
ag - Agentic Framework Gateway (Feature Tracking)

USAGE:
    ag <command> [options]

COMMANDS:
    start               Session start checks + context summary
    init                Run project initialization interview
    plan F-XXXX         Create plan with review loop (before implementing)
    implement F-XXXX    Verify acceptance exists, start WIP tracking
    spec [F-XXXX]       Write/check spec for a feature (single feature workflow)
    specs               Systematic brownfield spec generation by domain
    todo <args>         Quick-capture ideas/tasks to TODO.md inbox
    commit              Run all pre-commit gates
    done [F-XXXX]       Feature complete validation
    flush [opts]        Commit state files to main (no PR). --dry-run, --check, --features
    dogfood [--brief]   Detect root vs template instruction file drift (framework-dev)
    docs [F-XXXX]       Draft docs from registry (STACK.md ## Docs)
    set [key] [value]   View/change settings (--show, --validate, --migrate)
    hooks <sub>         Manage git hooks (install|status|disable)
    approve-onboarding  Review/approve auto-discovered proposals
    trace [options]     Spec-code traceability (drift + coverage)
    test llm [options]  Run LLM behavioral tests
    agents <sub>        Project agent management (generate|list|clean)
    tools               List all available tools by category
    backlog <sub>       Ordered work queue (add|list|done|move|remove|clear)
    auto <sub>           Autonomous workflow (init|epic|status|pause|resume|stop|feedback)
    coord <sub>          Coordination server (start|stop|status)
    transition F-XXXX <state>  Manage feature state transitions (--status, --next, --dry-run, --unblocked)
    review [F-XXXX] [state]    Review checkpoint management (--approve, --reject, --reason)
    kickoff <sub>       Vision-to-backlog pipeline (prompt|--review|--approve|--discard|--status)
    decompose F-XXXX    Break epic into child features by component
    audit [options]     Spec verification & QA audit (--full, --status, --propagate, --metrics)
    nfr [sub]           NFR management (list, discover, coverage)
    worktree <sub>      Manage git worktrees (create|list|remove|path|status)
    intent [sub]        Manage intent journal (list|clear F-XXXX)
    formalize [T-XXXX...]  Promote TODO items to formal features + AC stubs
    sync [--check|--quiet] Detect drift across all artifacts, auto-fix safe errors
    verify [--full]     Run doctor verification
    run                 Show how to run this project
    status              Show current project status
    help                Show this help

EXAMPLES:
    ag start                    # Begin a new session
    ag init                     # Initialize project (if not done)
    ag run                      # Show how to run this project
    ag backlog add F-0042       # Add feature to work queue
    ag backlog add F-0042 -p 0  # Make it current work
    ag backlog list             # Show full queue
    ag backlog done             # Mark current done, advance
    ag plan F-0042              # Create plan with iterative review
    ag plan F-0042 --no-review  # Create plan without review loop
    ag implement F-0042         # Start working on feature F-0042
    ag spec                     # Print spec-writing checklist for new feature
    ag spec F-0042              # Show spec status for F-0042
    ag spec --check             # Run spec health check on all features
    ag specs                    # Start/resume brownfield spec generation
    ag specs --status           # Show domain progress
    ag todo "Try new library"   # Capture idea to TODO.md
    ag todo list                # Show inbox items
    ag todo done T-0001 "done"  # Resolve item
    ag flush                    # Commit state files to main
    ag flush --dry-run          # Preview what would be flushed
    ag flush --features         # Include FEATURES.md status changes
    ag commit                   # Verify ready to commit
    ag done F-0042              # Check feature completion
    ag decompose F-0042         # Break epic into child features
    ag auto init                # Set up auto mode (generates settings.json)
    ag auto init --tier 1       # Set up for Docker sandbox
    ag auto status              # Check engine state
    ag auto pause               # Pause running engine
    ag auto resume              # Resume paused engine
    ag auto stop                # Stop running engine
    ag auto epic F-0042         # Autonomously execute epic's children
    ag auto feedback AC-003 "use existing auth"
    ag approve-onboarding       # List unapproved proposals
    ag approve-onboarding --all # Approve all proposals
    ag trace                    # Full drift + coverage report
    ag trace F-0042             # What files implement F-0042?
    ag trace src/auth.py        # What features does auth.py implement?
    ag trace --gaps             # Show only gaps (missing implementations)
    ag trace --json             # Machine-readable combined output
    ag test llm                 # Run all LLM behavioral tests
    ag test llm --critical      # Run critical tests only
    ag tools                    # Discover available tools
    ag agents generate          # Generate project-specific agents from stack
    ag agents generate --dry-run # Preview what would be generated
    ag agents list              # List current project agents
    ag docs F-0042              # Draft docs for feature F-0042
    ag docs --list              # Show doc registry from STACK.md
    ag docs --pr                # Draft PR-trigger docs only
    ag docs --check             # Dry run: what would be drafted
    ag docs generate            # Generate all deferred docs
    ag docs generate F-0042     # Generate deferred docs for one feature
    ag intent list              # Show pending/orphaned intents
    ag intent clear F-0042      # Cancel a stuck intent
    ag sync                     # Full sync: detect + auto-fix
    ag sync --check             # Dry run: detect only
    ag verify --full            # Full verification

Feature tracking with acceptance criteria.
EOF
    fi
}

# Get verification state summary
get_verification_summary() {
    local state_file="$ROOT_DIR/.agentic/session/.verification-state"
    if [ -f "$state_file" ]; then
        local last_run issues result
        last_run=$(grep '"last_run"' "$state_file" 2>/dev/null | sed 's/.*: "\([^"]*\)".*/\1/' | cut -dT -f1,2 | tr T ' ' | cut -c1-16)
        issues=$(grep '"issues_count"' "$state_file" 2>/dev/null | sed 's/.*: \([0-9]*\).*/\1/')
        result=$(grep '"result"' "$state_file" 2>/dev/null | sed 's/.*: "\([^"]*\)".*/\1/')

        if [ -n "$last_run" ]; then
            if [ "$result" = "pass" ]; then
                echo -e "${GREEN}Last verified: $last_run, 0 issues${NC}"
            else
                echo -e "${YELLOW}Last verified: $last_run, $issues issue(s)${NC}"
            fi
        fi
    else
        echo -e "${YELLOW}No verification record. Run: ag verify${NC}"
    fi
}


# Work command (Discovery profile) - start WIP tracking without feature ID
cmd_work() {
    local description="${1:-}"

    if [ -z "$description" ]; then
        echo -e "${RED}Error: Task description required${NC}"
        echo "Usage: ag work \"Add login form\""
        exit 1
    fi

    # Backlog gate: block if backlog has feature items AND feature_tracking=yes
    local ft
    ft=$(get_setting "feature_tracking" "no")
    if [ "${SKIP_BACKLOG:-}" != "1" ] && [ "$ft" = "yes" ]; then
        local bl_current_json
        bl_current_json=$(python3 "$SCRIPT_DIR/backlog_helpers.py" --project-root "$ROOT_DIR" json-current 2>/dev/null) || true
        if [ -n "$bl_current_json" ]; then
            local bl_type
            bl_type=$(echo "$bl_current_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('type',''))" 2>/dev/null) || bl_type=""
            if [ "$bl_type" = "feature" ]; then
                local bl_cur_id
                bl_cur_id=$(echo "$bl_current_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null) || bl_cur_id=""
                echo -e "${RED}BLOCKED: Backlog has feature work queued (current: $bl_cur_id).${NC}"
                echo "  Work on it: ag implement $bl_cur_id"
                echo "  Clear:      ag backlog clear"
                echo "  Override:   SKIP_BACKLOG=1 ag work \"$description\""
                exit 1
            fi
        fi
    fi

    # Feature tracking: hard block — require feature ID with acceptance criteria
    if [ "$ft" = "yes" ]; then
        echo -e "${RED}BLOCKED: Feature tracking is enabled — requires a feature ID with acceptance criteria.${NC}"
        echo ""
        echo "To start:"
        echo "  1. Add feature to .agentic/spec/FEATURES.md (next available F-XXXX)"
        echo "  2. Create .agentic/spec/acceptance/F-XXXX.md with acceptance criteria"
        echo "  3. Run: ag implement F-XXXX"
        echo ""
        echo "Disable feature_tracking to use ag work without feature IDs."
        exit 1
    fi

    echo -e "${BOLD}=== Starting Task ===${NC}"
    echo "Task: $description"
    echo ""

    # Start WIP tracking (writes to AGENTS.json)
    echo "Starting WIP tracking..."
    bash "$SCRIPT_DIR/wip.sh" start "task" "$description" "" 2>/dev/null || \
        echo -e "${YELLOW}WIP tracking not started (already active or unavailable)${NC}"

    echo ""
    echo -e "${GREEN}Ready to work on: $description${NC}"
    echo "Update STATUS.md with your progress."
    echo ""
    echo -e "${BLUE}💡 Tip: Even rough acceptance criteria help — 2-3 bullet points:${NC}"
    echo -e "${BLUE}   What would success look like? What should the user be able to do?${NC}"
}

# get_plan_review_config is now a thin wrapper around get_setting
get_plan_review_config() {
    local key="$1"
    local default="$2"
    get_setting "$key" "$default"
}


# Intent command — manage write-ahead intents for crash recovery (F-0200)
cmd_intent() {
    local subcmd="${1:-list}"
    shift 2>/dev/null || true

    local main_root="${MAIN_PROJECT_ROOT:-$ROOT_DIR}"
    local intents_script="$SCRIPT_DIR/../auto/intents.py"

    if [ ! -f "$intents_script" ]; then
        echo -e "${RED}intents.py not found${NC}" >&2
        return 1
    fi
    if ! command -v python3 >/dev/null 2>&1; then
        echo -e "${RED}python3 required${NC}" >&2
        return 1
    fi

    case "$subcmd" in
        list)
            echo -e "${BOLD}=== Intent Journal ===${NC}"
            echo ""

            # Current session intents
            local sid_file="$main_root/.agentic/session/.current-session-id"
            local session_id=""
            if [ -f "$sid_file" ]; then
                session_id=$(cat "$sid_file" 2>/dev/null | tr -d '[:space:]')
            fi

            if [ -n "$session_id" ]; then
                local pending
                pending=$(python3 "$intents_script" --project-root "$main_root" \
                    get-pending --session-id "$session_id" 2>/dev/null || true)
                if [ -n "$pending" ]; then
                    echo -e "${YELLOW}Pending intents (current session):${NC}"
                    echo "$pending" | python3 -c "
import sys, json
items = json.load(sys.stdin)
for i in items:
    fid = i.get('feature_id', '?')
    cmd = i.get('command', '?')
    target = i.get('target_state', '?')
    remaining = i.get('steps_remaining', [])
    completed = i.get('steps_completed', [])
    attempts = i.get('attempt_count', 1)
    print(f'  {fid}: ag {cmd} -> {target}')
    print(f'    Completed: {completed}')
    print(f'    Remaining: {remaining}')
    print(f'    Attempts: {attempts}')
    print()
" 2>/dev/null || echo "  (parse error)"
                else
                    echo -e "${GREEN}No pending intents in current session.${NC}"
                fi
            else
                echo -e "${DIM}No current session.${NC}"
            fi

            # Orphaned intents
            local orphans
            orphans=$(python3 "$intents_script" --project-root "$main_root" \
                get-orphaned 2>/dev/null || true)
            if [ -n "$orphans" ]; then
                echo ""
                echo -e "${YELLOW}Orphaned intents (from crashed sessions):${NC}"
                echo "$orphans" | python3 -c "
import sys, json
items = json.load(sys.stdin)
for i in items:
    fid = i.get('feature_id', '?')
    cmd = i.get('command', '?')
    created = i.get('created_at', '?')
    remaining = i.get('steps_remaining', [])
    print(f'  {fid}: ag {cmd} (created {created})')
    print(f'    Remaining: {remaining}')
    print()
" 2>/dev/null || echo "  (parse error)"
                echo -e "${DIM}Run \`ag intent clear F-XXXX\` to discard, or \`ag sync\` to auto-adopt.${NC}"
            fi

            echo ""
            ;;
        clear)
            local feature_id="${1:-}"
            if [ -z "$feature_id" ]; then
                echo "Usage: ag intent clear <F-XXXX>" >&2
                return 1
            fi

            # Cancel intent (marks as cancelled, undoes completed steps)
            intent_cancel "$feature_id"
            local exit_code=$?

            if [ $exit_code -eq 0 ]; then
                echo -e "${GREEN}Cancelled intent for $feature_id${NC}"
                echo -e "${DIM}Note: If worktree or WIP was created, remove manually if no longer needed.${NC}"
            else
                echo -e "${YELLOW}No active intent found for $feature_id${NC}"
            fi
            ;;
        --help|-h|help)
            echo "Usage: ag intent [list|clear] [options]"
            echo ""
            echo "  list              Show all intents (current session + orphaned)"
            echo "  clear F-XXXX      Cancel intent and mark for cleanup"
            echo ""
            echo "Intents are write-ahead journal entries for crash recovery."
            echo "When an ag command is interrupted, \`ag sync\` can resume from"
            echo "the last checkpoint."
            ;;
        *)
            echo "Unknown intent subcommand: $subcmd" >&2
            echo "Run 'ag intent --help' for usage." >&2
            return 1
            ;;
    esac
}

# Tools command - list all tools
# Agents command — project-specific agent management
cmd_agents() {
    local subcmd="${1:-}"
    shift 2>/dev/null || true

    case "$subcmd" in
        generate)
            bash "$SCRIPT_DIR/generate-project-agents.sh" "$@"
            ;;
        list)
            local project_dir="$SCRIPT_DIR/../agents/claude/subagents-project"
            if [ -d "$project_dir" ] && ls "$project_dir"/*.md >/dev/null 2>&1; then
                echo -e "${BOLD}Project-specific agents:${NC}"
                for f in "$project_dir"/*.md; do
                    [ -f "$f" ] || continue
                    local name
                    name=$(basename "$f" .md)
                    local marker="AUTO-GENERATED"
                    if head -5 "$f" | grep -q 'CUSTOMIZED'; then
                        marker="CUSTOMIZED"
                    fi
                    echo -e "  $name ($marker)"
                done
            else
                echo "No project-specific agents. Run: ag agents generate"
            fi
            ;;
        clean)
            bash "$SCRIPT_DIR/generate-project-agents.sh" --clean "$@"
            ;;
        *)
            echo "Usage: ag agents <generate|list|clean> [options]"
            echo ""
            echo "  generate [--dry-run]  Generate project agents from stack detection"
            echo "  list                  Show current project agents"
            echo "  clean [--dry-run]     Remove auto-generated agents (keeps CUSTOMIZED)"
            ;;
    esac
}

cmd_tools() {
    bash "$SCRIPT_DIR/list-tools.sh" 2>/dev/null || {
        echo -e "${BOLD}=== Available Tools ===${NC}"
        echo ""
        echo "Tools in .agentic/lib/tools/:"
        echo ""
        ls -1 "$SCRIPT_DIR"/*.sh 2>/dev/null | xargs -I{} basename {} | sort | while read -r tool; do
            printf "  %-25s\n" "$tool"
        done
        echo ""
        echo "Run tool with: bash .agentic/lib/tools/<tool>.sh"
    }
}

# Merge command — wraps gh pr merge + ag done (structural chaining)
# Ensures post-merge completion always runs. Prevents the §14/§16 failure
# where the agent merges a PR but forgets to run ag done.
cmd_merge() {
    local pr_number="${1:-}"
    local feature_id="${2:-}"

    if [ -z "$pr_number" ]; then
        echo -e "${RED}Usage: ag merge <pr-number> [F-XXXX]${NC}"
        echo "  Merges a PR and runs ag done for the feature."
        echo ""
        echo "  If F-XXXX is not provided, attempts to extract from PR title."
        echo "  Example: ag merge 148 F-0222"
        exit 1
    fi

    echo -e "${BOLD}=== Merge PR #$pr_number ===${NC}"
    echo ""

    # Extract feature ID from PR title if not provided
    if [ -z "$feature_id" ]; then
        local pr_title
        pr_title=$(gh pr view "$pr_number" --json title -q '.title' 2>/dev/null || echo "")
        feature_id=$(echo "$pr_title" | grep -oE "$FEATURE_ID_ERE" | head -1 || echo "")
        if [ -n "$feature_id" ]; then
            echo "Detected feature: $feature_id (from PR title)"
        fi
    fi

    # Merge the PR (squash strategy — matches formal profile convention)
    echo "Merging PR #$pr_number..."
    if ! gh pr merge "$pr_number" --squash --delete-branch; then
        echo -e "${RED}Merge failed${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ PR #$pr_number merged${NC}"
    echo ""

    # Ensure we're on main
    local current_branch
    current_branch=$(git branch --show-current 2>/dev/null)
    if [ "$current_branch" != "main" ] && [ "$current_branch" != "master" ]; then
        echo "Switching to main..."
        git checkout main -q 2>/dev/null || git checkout master -q 2>/dev/null
    fi

    # Run ag done
    if [ -n "$feature_id" ]; then
        echo -e "${BOLD}=== Post-Merge: ag done $feature_id ===${NC}"
        echo ""
        cmd_done "$feature_id"
    else
        echo -e "${YELLOW}No feature ID detected — run ag done F-XXXX manually${NC}"
    fi
}

# Docs command - doc lifecycle system
cmd_docs() {
    local arg1="${1:-}"
    local arg2="${2:-}"

    # Resolve feature ID: explicit arg, or from WIP
    local feature_id=""
    if is_feature_id "$arg1"; then
        feature_id="$arg1"
        shift 2>/dev/null || true
        arg1="${1:-}"
    else
        # Try AGENTS.json first, then WIP.md fallback
        feature_id=$(_get_wip_feature)
        if [[ -z "$feature_id" ]] && [[ -f "$ROOT_DIR/.agentic/session/WIP.md" ]]; then
            feature_id=$(grep -oE "$FEATURE_ID_ERE" "$ROOT_DIR/.agentic/session/WIP.md" 2>/dev/null | head -1 || true)
        fi
    fi

    case "$arg1" in
        --list)
            bash "$SCRIPT_DIR/docs.sh" --list
            ;;
        --check)
            if [[ -n "$feature_id" ]]; then
                bash "$SCRIPT_DIR/docs.sh" --trigger feature_done --check --manifest "$feature_id"
                bash "$SCRIPT_DIR/docs.sh" --trigger pr --check --manifest "$feature_id"
            else
                echo -e "${RED}No feature ID given and no WIP active. Usage: ag docs F-####${NC}"
                exit 1
            fi
            ;;
        --generate|generate)
            # Generate deferred docs (all pending, or filtered by feature ID)
            _docs_generate "${feature_id:-}"
            ;;
        --pr)
            if [[ -n "$feature_id" ]]; then
                bash "$SCRIPT_DIR/docs.sh" --trigger pr --manifest "$feature_id"
            else
                echo -e "${RED}No feature ID given and no WIP active. Usage: ag docs --pr F-####${NC}"
                exit 1
            fi
            ;;
        "")
            # Default: run both feature_done + pr triggers
            if [[ -n "$feature_id" ]]; then
                bash "$SCRIPT_DIR/docs.sh" --trigger feature_done --manifest "$feature_id"
                bash "$SCRIPT_DIR/docs.sh" --trigger pr --manifest "$feature_id"
            else
                echo -e "${RED}No feature ID given and no WIP active. Usage: ag docs F-####${NC}"
                exit 1
            fi
            ;;
        *)
            echo -e "${RED}Unknown docs subcommand: $arg1${NC}"
            echo "Usage: ag docs [F-####] [--list|--check|--pr|--generate]"
            exit 1
            ;;
    esac
}

# Hooks command - manage git hook configuration
cmd_hooks() {
    local subcmd="${1:-}"
    local flag="${2:-}"

    case "$subcmd" in
        install)
            if ! command -v git >/dev/null 2>&1 || ! git rev-parse --git-dir >/dev/null 2>&1; then
                echo -e "${RED}Error: Not a git repository${NC}"
                exit 1
            fi
            git config core.hooksPath .agentic/hooks
            echo -e "${GREEN}Hooks installed: core.hooksPath set to .agentic/hooks${NC}"
            ;;
        status)
            if ! command -v git >/dev/null 2>&1 || ! git rev-parse --git-dir >/dev/null 2>&1; then
                echo -e "${RED}Error: Not a git repository${NC}"
                exit 1
            fi
            local hooks_path
            hooks_path=$(git config core.hooksPath 2>/dev/null || echo "")
            if [ "$hooks_path" = ".agentic/hooks" ]; then
                echo -e "${GREEN}INSTALLED${NC}: core.hooksPath = .agentic/hooks"
                # Show current mode
                local mode="fast"
                if [ -f "$ROOT_DIR/STACK.md" ]; then
                    local raw
                    raw=$(grep -iE "^[- ]*pre_commit_hook:" "$ROOT_DIR/STACK.md" 2>/dev/null | head -1 | sed 's/.*:[[:space:]]*//' | sed 's/[[:space:]]*#.*//' | tr -d ' ')
                    case "$raw" in
                        yes) mode="fast" ;;
                        no|fast|full) mode="$raw" ;;
                    esac
                fi
                echo "  Mode: $mode (set pre_commit_hook in STACK.md)"
            elif [ -n "$hooks_path" ]; then
                echo -e "${YELLOW}CUSTOM${NC}: core.hooksPath = $hooks_path (not .agentic/hooks)"
            else
                echo -e "${RED}NOT INSTALLED${NC}: core.hooksPath not configured"
                echo "  Run: ag hooks install"
            fi
            ;;
        disable)
            if [ "$flag" != "--confirm" ]; then
                echo -e "${RED}WARNING: This disables all pre-commit quality gates.${NC}"
                echo ""
                echo "Commits will no longer be checked for:"
                echo "  - WIP lock, journal/status freshness, complexity limits"
                echo "  - Branch policy, spec validation, test execution"
                echo ""
                echo "To proceed: ag hooks disable --confirm"
                exit 1
            fi
            if ! command -v git >/dev/null 2>&1 || ! git rev-parse --git-dir >/dev/null 2>&1; then
                echo -e "${RED}Error: Not a git repository${NC}"
                exit 1
            fi
            git config --unset core.hooksPath 2>/dev/null || true
            echo -e "${YELLOW}Hooks disabled: core.hooksPath unset${NC}"
            echo "  Re-enable with: ag hooks install"
            ;;
        *)
            echo "Usage: ag hooks <install|status|disable>"
            echo ""
            echo "Commands:"
            echo "  install             Set core.hooksPath to .agentic/hooks"
            echo "  status              Show current hook configuration"
            echo "  disable --confirm   Remove core.hooksPath (disables all quality gates)"
            ;;
    esac
}


# Coordination server command (F-0185)
cmd_coord() {
    local subcmd="${1:-}"
    shift 2>/dev/null || true

    local auto_dir="$SCRIPT_DIR/../auto"

    case "$subcmd" in
        start|stop|status)
            python3 "$auto_dir/coord_server.py" "$subcmd" --project-root "$ROOT_DIR" "$@"
            ;;
        ""|--help)
            echo "ag coord - Coordination Server for parallel agent coordination"
            echo ""
            echo "COMMANDS:"
            echo "  start [--port N] [--bind ADDR]   Start coordination server"
            echo "  stop                              Stop coordination server"
            echo "  status                            Check server status"
            echo ""
            echo "SETTINGS (in STACK.md):"
            echo "  coord_enabled: yes|no             Enable server (default: no)"
            echo "  coord_port: 4185                  HTTP port"
            echo "  coord_bind: 127.0.0.1             Bind address (0.0.0.0 for Docker)"
            ;;
        *)
            echo -e "${RED}Unknown coord command: $subcmd${NC}"
            echo "Run 'ag coord --help' for usage."
            exit 1
            ;;
    esac
}

# Sync command - unified drift detection + auto-fix
cmd_sync() {
    local flag="${1:-}"
    bash "$SCRIPT_DIR/sync.sh" $flag

    # Doc staleness check (session trigger)
    if [[ -f "$SCRIPT_DIR/docs.sh" ]]; then
        local has_docs
        has_docs=$(bash "$SCRIPT_DIR/docs.sh" --list 2>/dev/null | grep -c "^  " || true)
        if [[ "$has_docs" -gt 1 ]]; then
            echo ""
            echo -e "${BOLD}--- Doc Staleness ---${NC}"
            bash "$SCRIPT_DIR/docs.sh" --trigger session 2>/dev/null || true
        fi
    fi
}

# Verify command - doctor checks
cmd_verify() {
    local arg="${1:-}"

    # ag verify F-XXXX — run automated verification commands from AC file
    if is_feature_id "$arg"; then
        local feature_id="$arg"
        local acc_file="$ROOT_DIR/.agentic/spec/acceptance/${feature_id}.md"
        if [ ! -f "$acc_file" ]; then
            echo -e "${RED}No acceptance criteria file: $acc_file${NC}"
            return 1
        fi

        echo -e "${BOLD}=== Verify: $feature_id ===${NC}"
        echo ""

        # Extract automated verification commands from ## Verification section
        local in_verification=false
        local commands=()
        while IFS= read -r line; do
            if echo "$line" | grep -q '^## Verification'; then
                in_verification=true
                continue
            fi
            if [ "$in_verification" = true ] && echo "$line" | grep -qE '^## '; then
                break
            fi
            if [ "$in_verification" = true ] && echo "$line" | grep -q '\*\*Automated\*\*'; then
                # Extract command between backticks
                local cmd
                cmd=$(echo "$line" | sed 's/.*`\([^`]*\)`.*/\1/')
                if [ -n "$cmd" ] && [ "$cmd" != "$line" ]; then
                    commands+=("$cmd")
                fi
            fi
        done < "$acc_file"

        if [ ${#commands[@]} -eq 0 ]; then
            echo -e "${YELLOW}No automated verification commands found in $acc_file${NC}"
            echo "  Add lines like: - **Automated**: \`pytest tests/test_foo.py -v\`"
            return 0
        fi

        local failed=0
        for cmd in "${commands[@]}"; do
            echo -e "${BLUE}Running: $cmd${NC}"
            local _verify_output=""
            _verify_output=$(bash -c "$cmd" 2>&1)
            local _verify_rc=$?
            if [ "$_verify_rc" -eq 0 ]; then
                echo -e "${GREEN}✓ PASSED${NC}"
            else
                echo -e "${RED}✗ FAILED${NC}"
                echo "$_verify_output" | tail -20
                failed=$((failed + 1))
            fi
            echo ""
        done

        if [ "$failed" -gt 0 ]; then
            echo -e "${RED}$failed verification(s) failed${NC}"
            return 1
        fi
        echo -e "${GREEN}All ${#commands[@]} verification(s) passed${NC}"
        return 0
    fi

    # ag verify / ag verify --full — general health check
    if [ "$arg" = "--full" ]; then
        bash "$SCRIPT_DIR/doctor.sh" --full
    else
        bash "$SCRIPT_DIR/doctor.sh"
    fi
}

# Approve onboarding proposals
cmd_approve_onboarding() {
    local target="${1:-}"

    # Find files with PROPOSAL markers
    local proposal_files=()
    for f in STACK.md CONTEXT_PACK.md OVERVIEW.md; do
        if [ -f "$ROOT_DIR/$f" ] && grep -q '<!-- PROPOSAL' "$ROOT_DIR/$f" 2>/dev/null; then
            proposal_files+=("$f")
        fi
    done
    # Formal files
    if [ -f "$ROOT_DIR/.agentic/spec/FEATURES.md" ] && grep -q '<!-- PROPOSAL' "$ROOT_DIR/.agentic/spec/FEATURES.md" 2>/dev/null; then
        proposal_files+=(".agentic/spec/FEATURES.md")
    fi
    # Acceptance criteria
    if [ -d "$ROOT_DIR/spec/acceptance" ]; then
        while IFS= read -r -d '' f; do
            if grep -q '<!-- PROPOSAL' "$f" 2>/dev/null; then
                local rel="${f#$ROOT_DIR/}"
                proposal_files+=("$rel")
            fi
        done < <(find "$ROOT_DIR/spec/acceptance" -name "F-*.md" -print0 2>/dev/null)
    fi

    if [ ${#proposal_files[@]} -eq 0 ]; then
        echo -e "${GREEN}No unapproved proposals found.${NC}"
        return 0
    fi

    # No args: list status
    if [ -z "$target" ]; then
        echo -e "${BOLD}=== Onboarding Proposals ===${NC}"
        echo ""
        echo "Files with unapproved proposals:"
        for f in "${proposal_files[@]}"; do
            echo "  - $f"
        done
        echo ""
        echo "Commands:"
        echo "  ag approve-onboarding <file>  # Approve single file"
        echo "  ag approve-onboarding --all   # Approve all files"
        return 0
    fi

    # --all: approve all
    if [ "$target" = "--all" ]; then
        echo -e "${BOLD}Approving all proposals...${NC}"
        for f in "${proposal_files[@]}"; do
            _strip_proposal_markers "$ROOT_DIR/$f"
            echo -e "  ${GREEN}✓${NC} $f"
        done
        _cleanup_proposals
        echo ""
        echo -e "${GREEN}All proposals approved.${NC}"
        return 0
    fi

    # Single file approval
    local full_path="$ROOT_DIR/$target"
    if [ ! -f "$full_path" ]; then
        echo -e "${RED}File not found: $target${NC}"
        return 1
    fi
    if ! grep -q '<!-- PROPOSAL' "$full_path" 2>/dev/null; then
        echo -e "${YELLOW}$target has no proposal markers.${NC}"
        return 0
    fi

    _strip_proposal_markers "$full_path"
    echo -e "${GREEN}✓ Approved: $target${NC}"

    # Check if all proposals are now approved
    local remaining=0
    for f in "${proposal_files[@]}"; do
        if [ "$f" != "$target" ] && grep -q '<!-- PROPOSAL' "$ROOT_DIR/$f" 2>/dev/null; then
            remaining=$((remaining + 1))
        fi
    done
    if [ "$remaining" -eq 0 ]; then
        _cleanup_proposals
        echo -e "${GREEN}All proposals approved.${NC}"
    else
        echo "$remaining file(s) still have proposals. Run: ag approve-onboarding"
    fi
}

# Strip PROPOSAL and confidence markers from a file
_strip_proposal_markers() {
    local file="$1"
    # Remove PROPOSAL header line
    sed -i.bak '/<!-- PROPOSAL: Auto-discovered by ag init/d' "$file"
    # Remove confidence markers
    sed -i.bak 's/ <!-- confidence: [a-z]* -->//g' "$file"
    rm -f "${file}.bak" 2>/dev/null || true
}

# Clean up discovery artifacts after all proposals approved
_cleanup_proposals() {
    rm -f "$ROOT_DIR/.agentic/session/discovery_report.json" 2>/dev/null || true
    rm -rf "$ROOT_DIR/.agentic/session/proposals" 2>/dev/null || true
}

# Status command - show project status
# Init command - guide through project initialization
cmd_init() {
    echo -e "${BOLD}=== Project Initialization ===${NC}"
    echo ""

    # Check current state
    if check_initialization; then
        echo -e "${GREEN}Project appears to be already initialized.${NC}"
        echo ""
        echo "Key files have content:"
        [ -f "$ROOT_DIR/STACK.md" ] && echo "  • STACK.md"
        [ -f "$ROOT_DIR/CONTEXT_PACK.md" ] && echo "  • CONTEXT_PACK.md"
        [ -f "$ROOT_DIR/STATUS.md" ] && echo "  • STATUS.md"
        echo ""
        echo "To re-run initialization, ask your AI agent:"
        echo "  \"Let's review and update the project initialization\""
        echo ""
        return 0
    fi

    echo "This project needs initialization."
    echo ""
    echo -e "${BOLD}What initialization does:${NC}"
    echo "  1. Auto-discover existing code (if brownfield project)"
    echo "  2. Choose profile: Discovery (lightweight) or Formal (formal specs)"
    echo "  3. Set up AI tools: Claude, Cursor, Copilot, Codex"
    echo "  4. Define project: Tech stack, languages, frameworks"
    echo "  5. Configure quality: Testing approach, quality gates"
    echo "  6. Document architecture: Entry points, data flow"
    echo ""
    echo -e "${BOLD}To initialize, ask your AI agent:${NC}"
    echo ""
    echo -e "  ${GREEN}\"Let's initialize this project with the Agentic Framework\"${NC}"
    echo ""
    echo -e "Or provide context:"
    echo ""
    echo -e "  ${GREEN}\"Initialize this project. It's a [web app/CLI/game] using [stack]\"${NC}"
    echo ""
    echo -e "${BOLD}The agent will:${NC}"
    echo "  • Ask clarifying questions about your project"
    echo "  • Fill in STACK.md, STATUS.md, CONTEXT_PACK.md"
    echo "  • Set up appropriate quality gates"
    echo "  • Create any needed spec files (Formal)"
    echo ""
    echo -e "Init playbook: ${BLUE}.agentic/init/init_playbook.md${NC}"
    echo -e "Init questions: ${BLUE}.agentic/init/init_questions.md${NC}"
}

cmd_status() {
    echo -e "${BOLD}=== Project Status ===${NC}"
    echo "Profile: $(get_setting profile discovery)"
    echo ""

    # Verification status
    get_verification_summary
    echo ""

    # WIP status (AGENTS.json, with WIP.md fallback)
    if _has_active_wip; then
        echo -e "${YELLOW}Active WIP:${NC}"
        _agents_py list 2>/dev/null || true
    elif [ -f "$ROOT_DIR/.agentic/session/WIP.md" ]; then
        echo -e "${YELLOW}Active WIP (legacy):${NC}"
        head -10 "$ROOT_DIR/.agentic/session/WIP.md" 2>/dev/null | grep -E "^(Feature|Task|Started|Last):" || true
    else
        echo "No active WIP"
    fi
    echo ""

    # STATUS.md summary
    if [ -f "$ROOT_DIR/STATUS.md" ]; then
        echo -e "${BOLD}From STATUS.md:${NC}"
        head -30 "$ROOT_DIR/STATUS.md" 2>/dev/null
    fi
}

# Trace command - spec-code traceability
cmd_trace() {
    local arg="${1:-}"
    local json_mode=false
    local gaps_mode=false
    local tests_mode=false
    local orphans_mode=false

    # Parse options
    while [[ -n "$arg" ]]; do
        case "$arg" in
            --json)
                json_mode=true
                shift 2>/dev/null || true
                arg="${1:-}"
                ;;
            --gaps)
                gaps_mode=true
                shift 2>/dev/null || true
                arg="${1:-}"
                ;;
            --tests)
                tests_mode=true
                shift 2>/dev/null || true
                arg="${1:-}"
                ;;
            --orphans)
                orphans_mode=true
                shift 2>/dev/null || true
                arg="${1:-}"
                ;;
            F-[0-9][0-9][0-9][0-9]*)
                # Feature lookup: what files implement this feature?
                cmd_trace_feature "$arg"
                return
                ;;
            *)
                # Check if it's a file path
                if [ -f "$arg" ] || [ -f "$ROOT_DIR/$arg" ]; then
                    cmd_trace_file "$arg"
                    return
                fi
                echo -e "${RED}Unknown option or target: $arg${NC}"
                return 1
                ;;
        esac
    done

    # Full trace (combined drift + coverage)
    if [ "$json_mode" = true ]; then
        cmd_trace_json
    elif [ "$gaps_mode" = true ]; then
        cmd_trace_gaps
    elif [ "$tests_mode" = true ]; then
        python3 "$SCRIPT_DIR/coverage.py" --test-mapping 2>/dev/null
    elif [ "$orphans_mode" = true ]; then
        cmd_trace_orphans
    else
        cmd_trace_full
    fi
}

cmd_trace_full() {
    echo -e "${BOLD}=== Spec ↔ Code Traceability ===${NC}"
    echo ""

    # Run drift detection
    echo -e "${BLUE}--- Drift Detection ---${NC}"
    bash "$SCRIPT_DIR/drift.sh" --check 2>/dev/null || true
    echo ""

    # Run coverage check
    echo -e "${BLUE}--- Coverage Analysis ---${NC}"
    python3 "$SCRIPT_DIR/coverage.py" 2>/dev/null || true
}

cmd_trace_json() {
    # Combine JSON outputs from drift.sh and coverage.py
    local drift_file coverage_file
    drift_file=$(mktemp)
    coverage_file=$(mktemp)

    # Use || true to ignore exit codes (both tools return 1 if issues found)
    bash "$SCRIPT_DIR/drift.sh" --json 2>/dev/null > "$drift_file" || true
    python3 "$SCRIPT_DIR/coverage.py" --json 2>/dev/null > "$coverage_file" || true

    # Merge the two JSON outputs
    python3 - "$drift_file" "$coverage_file" << 'PYEOF'
import json
import sys
from datetime import datetime, timezone

drift_file = sys.argv[1]
coverage_file = sys.argv[2]

with open(drift_file) as f:
    drift = json.load(f)
with open(coverage_file) as f:
    coverage = json.load(f)

combined = {
    "tool": "trace",
    "timestamp": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
    "drift": drift,
    "coverage": coverage,
    "summary": {
        "total_drift_issues": drift.get("summary", {}).get("total_issues", 0),
        "total_coverage_issues": len(coverage.get("issues", [])),
        "annotated_features": coverage.get("summary", {}).get("annotated_features", 0),
        "implemented_features": coverage.get("summary", {}).get("implemented_features", 0),
    }
}
print(json.dumps(combined, indent=2))
PYEOF

    rm -f "$drift_file" "$coverage_file"
}

cmd_trace_gaps() {
    echo -e "${BOLD}=== Implementation Gaps ===${NC}"
    echo ""

    # Features with missing annotations
    echo -e "${YELLOW}Features without code annotations:${NC}"
    python3 "$SCRIPT_DIR/coverage.py" --json 2>/dev/null | \
        python3 -c "
import json
import sys
data = json.load(sys.stdin)
for issue in data.get('issues', []):
    if issue.get('type') == 'missing_annotation':
        print(f\"  {issue['feature']}: {issue.get('status', '')} - no @feature annotations\")
"
    echo ""

    # Features with incomplete acceptance criteria
    echo -e "${YELLOW}Shipped features with incomplete acceptance:${NC}"
    bash "$SCRIPT_DIR/drift.sh" --json 2>/dev/null | \
        python3 -c "
import json
import sys
data = json.load(sys.stdin)
for issue in data.get('issues', []):
    if issue.get('type') in ('incomplete_shipped', 'status_drift'):
        print(f\"  {issue.get('feature', 'unknown')}: {issue.get('description', '')}\")
"
}

cmd_trace_orphans() {
    echo -e "${BOLD}=== Orphaned Code & Annotations ===${NC}"
    echo ""

    # Orphaned annotations
    echo -e "${YELLOW}Orphaned @feature annotations (feature doesn't exist):${NC}"
    python3 "$SCRIPT_DIR/coverage.py" --json 2>/dev/null | \
        python3 -c "
import json
import sys
data = json.load(sys.stdin)
found = False
for issue in data.get('issues', []):
    if issue.get('type') == 'orphaned_annotation':
        found = True
        print(f\"  {issue['feature']} in {issue.get('file', 'unknown')}\")
if not found:
    print('  None found')
"
    echo ""

    # Undocumented code
    echo -e "${YELLOW}Undocumented exports:${NC}"
    bash "$SCRIPT_DIR/drift.sh" --json 2>/dev/null | \
        python3 -c "
import json
import sys
data = json.load(sys.stdin)
found = False
for issue in data.get('issues', []):
    if issue.get('type') == 'undocumented_code':
        found = True
        print(f\"  {issue.get('export', 'unknown')}\")
if not found:
    print('  None found')
" | head -15
}

cmd_trace_feature() {
    local feature_id="$1"
    echo -e "${BOLD}=== Files implementing $feature_id ===${NC}"
    echo ""

    python3 "$SCRIPT_DIR/coverage.py" --json 2>/dev/null | \
        python3 -c "
import json
import sys

data = json.load(sys.stdin)
fid = '$feature_id'

# Find in full scan (we need annotations data which isn't in JSON output)
# Fall back to direct scan
" 2>/dev/null || true

    # Direct grep for @feature annotations
    echo "Files with @feature $feature_id annotation:"
    grep -rl "@feature $feature_id" "$ROOT_DIR" --include="*.py" --include="*.ts" --include="*.js" --include="*.go" --include="*.rs" --include="*.java" --include="*.sh" 2>/dev/null | \
        while read -r f; do
            echo "  - ${f#$ROOT_DIR/}"
        done || echo "  (none found)"
    echo ""

    # Check acceptance criteria
    local acc_file="$ROOT_DIR/.agentic/spec/acceptance/${feature_id}.md"
    if [ -f "$acc_file" ]; then
        echo "Acceptance criteria: $acc_file"
        local total complete
        total=$(grep -cE "^- \[.\]" "$acc_file" 2>/dev/null || echo "0")
        complete=$(grep -cE "^- \[x\]" "$acc_file" 2>/dev/null || echo "0")
        echo "  Progress: $complete/$total complete"
    fi
}

cmd_trace_file() {
    local target_file="$1"
    python3 "$SCRIPT_DIR/coverage.py" --reverse "$target_file" 2>/dev/null
}

# Test command - run LLM behavioral tests
cmd_test() {
    local test_type="${1:-}"
    shift 2>/dev/null || true
    
    case "$test_type" in
        llm)
            cmd_test_llm "$@"
            ;;
        unit|framework)
            echo -e "${BOLD}=== Framework Unit Tests ===${NC}"
            bash "$ROOT_DIR/tests/validate_framework.sh"
            ;;
        "")
            echo -e "${RED}Error: Test type required${NC}"
            echo "Usage: ag test llm [--critical|--list|--setup TEST_ID]"
            echo "       ag test unit"
            exit 1
            ;;
        *)
            echo -e "${RED}Unknown test type: $test_type${NC}"
            echo "Available: llm, unit"
            exit 1
            ;;
    esac
}

# LLM behavioral tests
cmd_test_llm() {
    local arg="${1:-}"
    local runner="$ROOT_DIR/tests/llm/interactive_runner.py"
    local harness="$ROOT_DIR/tests/llm/harness.sh"
    
    # Detect environment
    local env="unknown"
    if command -v claude &>/dev/null; then
        env="claude"
    elif command -v codex &>/dev/null; then
        env="codex"
    elif [[ -n "${CURSOR_SESSION:-}" ]] || pgrep -f "Cursor" &>/dev/null; then
        env="cursor-ide"
    elif [[ -n "${VSCODE_PID:-}" ]]; then
        env="copilot-ide"
    fi
    
    echo -e "${BOLD}=== LLM Behavioral Tests ===${NC}"
    echo "Environment: $env"
    echo ""
    
    case "$arg" in
        --list)
            python3 "$runner" --list
            ;;
        --critical)
            if [[ "$env" == "claude" ]]; then
                echo "Using Claude CLI (automated)..."
                TOOL=claude bash "$harness" --critical
            elif [[ "$env" == "codex" ]]; then
                echo "Using Codex CLI (automated)..."
                TOOL=codex bash "$harness" --critical
            else
                echo "Using interactive mode (agent-driven)..."
                echo ""
                python3 "$runner" --list --critical
                echo ""
                echo -e "${YELLOW}To run these tests interactively:${NC}"
                echo "  python3 tests/llm/interactive_runner.py --interactive --critical"
                echo ""
                echo -e "${YELLOW}Or run individually:${NC}"
                echo "  python3 tests/llm/interactive_runner.py --setup 001"
                echo "  (Agent responds to prompt)"
                echo "  python3 tests/llm/interactive_runner.py --verify 001"
            fi
            ;;
        --setup)
            local test_id="${2:-}"
            if [[ -z "$test_id" ]]; then
                echo -e "${RED}Error: Test ID required${NC}"
                echo "Usage: ag test llm --setup 001"
                exit 1
            fi
            python3 "$runner" --setup "$test_id"
            ;;
        --verify)
            local test_id="${2:-}"
            if [[ -z "$test_id" ]]; then
                echo -e "${RED}Error: Test ID required${NC}"
                echo "Usage: ag test llm --verify 001"
                exit 1
            fi
            shift  # Remove --verify
            python3 "$runner" --verify "$@"
            ;;
        --interactive)
            if [[ "$env" == "cursor-ide" ]] || [[ "$env" == "copilot-ide" ]]; then
                echo "Running in interactive mode..."
                python3 "$runner" --interactive "${@:2}"
            else
                echo -e "${YELLOW}Interactive mode is for IDE-based tools (Cursor, Copilot).${NC}"
                echo "Your environment ($env) supports automated tests:"
                echo "  TOOL=$env bash tests/llm/harness.sh"
            fi
            ;;
        --detect)
            echo "Detected environment: $env"
            case "$env" in
                claude)
                    echo "  Claude CLI available - fully automated tests"
                    echo "  Run: bash tests/llm/harness.sh"
                    ;;
                codex)
                    echo "  Codex CLI available - fully automated tests"
                    echo "  Run: TOOL=codex bash tests/llm/harness.sh"
                    ;;
                cursor-ide)
                    echo "  Running inside Cursor IDE - use interactive mode"
                    echo "  Run: ag test llm --interactive --critical"
                    ;;
                copilot-ide)
                    echo "  Running inside VS Code (Copilot) - use interactive mode"
                    echo "  Run: ag test llm --interactive --critical"
                    ;;
                *)
                    echo "  Unknown environment"
                    echo "  Install: claude CLI, codex CLI, or run from Cursor/Copilot"
                    ;;
            esac
            ;;
        ""|--help)
            echo "LLM behavioral tests verify agent compliance with framework rules."
            echo ""
            echo "Usage: ag test llm [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --list              List all available tests"
            echo "  --critical          Run/list critical tests only"
            echo "  --setup TEST_ID     Set up project for a specific test"
            echo "  --verify TEST_ID    Verify outcomes of a test"
            echo "  --interactive       Run tests interactively (for Cursor/Copilot)"
            echo "  --detect            Show detected environment"
            echo ""
            echo "Environments:"
            echo "  Claude CLI (claude):    Fully automated via 'bash tests/llm/harness.sh'"
            echo "  Codex CLI (codex):      Fully automated via 'TOOL=codex bash tests/llm/harness.sh'"
            echo "  Cursor IDE:             Interactive mode - agent responds to prompts"
            echo "  Copilot IDE:            Interactive mode - agent responds to prompts"
            echo ""
            echo "Current environment: $env"
            ;;
        *)
            # Check if it's a test ID
            if echo "$arg" | grep -qE '^[0-9]+'; then
                python3 "$runner" --setup "$arg"
            else
                echo -e "${RED}Unknown option: $arg${NC}"
                cmd_test_llm --help
                exit 1
            fi
            ;;
    esac
}


# Set command — manage settings
cmd_set() {
    local arg1="${1:-}"
    local arg2="${2:-}"

    case "$arg1" in
        --show|"")
            echo -e "${BOLD}=== Resolved Settings ===${NC}"
            echo ""
            show_all_settings
            echo ""
            # Constraint check
            local violations
            violations=$(validate_constraints 2>&1)
            if [ -n "$violations" ]; then
                echo -e "${YELLOW}Constraint warnings:${NC}"
                echo "$violations"
            else
                echo -e "${GREEN}All constraint rules satisfied.${NC}"
            fi
            ;;
        --validate)
            echo -e "${BOLD}=== Constraint Validation ===${NC}"
            local violations
            violations=$(validate_constraints 2>&1)
            if [ -n "$violations" ]; then
                echo -e "${RED}Violations:${NC}"
                echo "$violations"
                exit 1
            else
                echo -e "${GREEN}All constraints satisfied.${NC}"
            fi
            ;;
        --migrate)
            echo -e "${BOLD}=== Migrate Settings ===${NC}"
            _settings_migrate
            ;;
        *)
            # ag set <key> <value>
            if [ -z "$arg2" ]; then
                echo -e "${RED}Error: Value required${NC}"
                echo "Usage: ag set <key> <value>"
                echo "       ag set --show"
                echo "       ag set --validate"
                echo "       ag set --migrate"
                exit 1
            fi
            _settings_set_value "$arg1" "$arg2"
            ;;
    esac
}

# Set a single setting value in STACK.md ## Settings section
_settings_set_value() {
    local key="$1"
    local value="$2"
    local stack_file="$ROOT_DIR/STACK.md"

    # Validate key format (prevent regex injection)
    if [[ ! "$key" =~ ^[a-z_][a-z0-9_]*$ ]]; then
        echo -e "${RED}Error: Invalid setting key '$key' (must be lowercase letters, digits, underscores)${NC}"
        exit 1
    fi

    # Validate values for enum settings
    case "$key" in
        profile)
            if [[ ! "$value" =~ ^(discovery|formal|autonomous_formal)$ ]]; then
                echo -e "${RED}Error: profile must be 'discovery', 'formal', or 'autonomous_formal', got '$value'${NC}"
                exit 1
            fi
            ;;
        feature_tracking|plan_review_enabled|spec_directory)
            if [[ ! "$value" =~ ^(yes|no)$ ]]; then
                echo -e "${RED}Error: $key must be 'yes' or 'no', got '$value'${NC}"
                exit 1
            fi
            ;;
        acceptance_criteria)
            if [[ ! "$value" =~ ^(blocking|recommended|off)$ ]]; then
                echo -e "${RED}Error: acceptance_criteria must be 'blocking', 'recommended', or 'off', got '$value'${NC}"
                exit 1
            fi
            ;;
        wip_before_commit)
            if [[ ! "$value" =~ ^(blocking|warning)$ ]]; then
                echo -e "${RED}Error: wip_before_commit must be 'blocking' or 'warning', got '$value'${NC}"
                exit 1
            fi
            ;;
        docs_gate)
            if [[ ! "$value" =~ ^(off|warning|blocking)$ ]]; then
                echo -e "${RED}Error: docs_gate must be 'off', 'warning', or 'blocking', got '$value'${NC}"
                exit 1
            fi
            ;;
        smoke_test_evidence)
            if [[ ! "$value" =~ ^(off|recommended|required)$ ]]; then
                echo -e "${RED}Error: smoke_test_evidence must be 'off', 'recommended', or 'required', got '$value'${NC}"
                exit 1
            fi
            ;;
        docs_mode)
            if [[ ! "$value" =~ ^(inline|deferred)$ ]]; then
                echo -e "${RED}Error: docs_mode must be 'inline' or 'deferred', got '$value'${NC}"
                exit 1
            fi
            ;;
        pre_commit_checks)
            if [[ ! "$value" =~ ^(full|fast|off)$ ]]; then
                echo -e "${RED}Error: pre_commit_checks must be 'full', 'fast', or 'off', got '$value'${NC}"
                exit 1
            fi
            ;;
        pre_commit_hook)
            if [[ ! "$value" =~ ^(fast|full|no)$ ]]; then
                echo -e "${RED}Error: pre_commit_hook must be 'fast', 'full', or 'no', got '$value'${NC}"
                exit 1
            fi
            ;;
        git_workflow)
            if [[ ! "$value" =~ ^(pull_request|direct)$ ]]; then
                echo -e "${RED}Error: git_workflow must be 'pull_request' or 'direct', got '$value'${NC}"
                exit 1
            fi
            ;;
        max_files_per_commit|max_added_lines|max_code_file_length)
            if [[ ! "$value" =~ ^[0-9]+$ ]]; then
                echo -e "${RED}Error: $key must be a positive integer, got '$value'${NC}"
                exit 1
            fi
            ;;
        review_spec|review_criteria|review_plan|review_code|review_merge|review_decomposition|review_regression|review_taste)
            if [[ ! "$value" =~ ^(human|critical_agent|skip|auto)$ ]]; then
                echo -e "${RED}Error: $key must be 'human', 'critical_agent', or 'skip', got '$value'${NC}"
                exit 1
            fi
            ;;
    esac

    if [ ! -f "$stack_file" ]; then
        echo -e "${RED}Error: STACK.md not found${NC}"
        exit 1
    fi

    # Capture old profile before writing (used by profile cascade below)
    if [[ "$key" == "profile" ]]; then
        _PREV_PROFILE=$(get_setting "profile" "discovery")
    fi

    # Ensure ## Settings section exists
    if ! grep -q "^## Settings" "$stack_file" 2>/dev/null; then
        _settings_create_section
    fi

    # Check if key already exists in ## Settings section
    # We need to be careful to only match within the section
    local in_section=0
    local found=0
    local tmpfile
    tmpfile=$(mktemp)

    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$in_section" -eq 0 ]]; then
            echo "$line" >> "$tmpfile"
            if [[ "$line" =~ ^##[[:space:]]+Settings ]]; then
                in_section=1
            fi
        elif [[ "$line" =~ ^##[[:space:]]+[^#] ]]; then
            # Exiting settings section
            if [[ "$found" -eq 0 ]]; then
                # Key not found in section, add it before next H2
                echo "- ${key}: ${value}" >> "$tmpfile"
                found=1
            fi
            in_section=0
            echo "$line" >> "$tmpfile"
        else
            # Inside settings section
            if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*${key}: ]]; then
                echo "- ${key}: ${value}" >> "$tmpfile"
                found=1
            else
                echo "$line" >> "$tmpfile"
            fi
        fi
    done < "$stack_file"

    # If still in section at EOF and not found, append
    if [[ "$found" -eq 0 ]]; then
        echo "- ${key}: ${value}" >> "$tmpfile"
    fi

    mv "$tmpfile" "$stack_file"

    # Invalidate caches
    _SETTINGS_SECTION_EXTRACTED=0
    _SETTINGS_SECTION_CACHE=""
    _SETTINGS_PROFILE_RESOLVED=0
    _SETTINGS_PROFILE_CACHE=""

    echo -e "${GREEN}Set ${key} = ${value}${NC}"

    # Smart profile cascade: update all settings to new profile defaults,
    # but preserve any settings the user has customized away from the old profile
    if [[ "$key" == "profile" ]]; then
        local old_profile presets_file
        old_profile="${_PREV_PROFILE:-discovery}"
        presets_file="$ROOT_DIR/.agentic/lib/presets/profiles.conf"
        if [[ -f "$presets_file" ]]; then
            local changed=0
            while IFS='=' read -r preset_key preset_value; do
                [[ "$preset_key" =~ ^#|^$ ]] && continue
                [[ -z "$preset_key" ]] && continue
                if [[ "$preset_key" =~ ^${value}\.(.*) ]]; then
                    local setting_name="${BASH_REMATCH[1]}"
                    local new_value="$preset_value"
                    # Get old profile default for this setting
                    local old_default
                    old_default=$(grep "^${old_profile}.${setting_name}=" "$presets_file" | cut -d= -f2)
                    # Re-read current value from file (cache was invalidated)
                    _SETTINGS_SECTION_EXTRACTED=0; _SETTINGS_SECTION_CACHE=""
                    local current_value
                    current_value=$(get_setting "$setting_name" "")
                    # Only overwrite if current value matches old profile default (user didn't customize)
                    if [[ "$current_value" == "$old_default" || -z "$current_value" ]]; then
                        sed -i.bak -E "s/^(- ${setting_name}:[[:space:]]*).*/\\1${new_value}/" "$stack_file"
                        rm -f "$stack_file.bak" 2>/dev/null || true
                        changed=$((changed + 1))
                    fi
                fi
            done < "$presets_file"
            # Clear caches and validate constraints once at end
            _SETTINGS_SECTION_EXTRACTED=0; _SETTINGS_SECTION_CACHE=""
            _SETTINGS_PROFILE_RESOLVED=0; _SETTINGS_PROFILE_CACHE=""
            local violations
            violations=$(validate_constraints 2>&1)
            if [ -n "$violations" ]; then
                echo ""
                echo -e "${YELLOW}Warning — constraint issues:${NC}"
                echo "$violations"
            fi
            echo "Switched to ${value} profile ($changed settings updated, customized settings preserved)"
            return
        fi
    fi

    # Validate constraints after change
    local violations
    violations=$(validate_constraints 2>&1)
    if [ -n "$violations" ]; then
        echo ""
        echo -e "${YELLOW}Warning — constraint issues:${NC}"
        echo "$violations"
    fi
}

# Create ## Settings section in STACK.md if missing
_settings_create_section() {
    local stack_file="$ROOT_DIR/STACK.md"
    local profile
    profile=$(_get_profile)

    # Find a good insertion point — after ## Agentic framework section
    local tmpfile
    tmpfile=$(mktemp)
    local inserted=0

    while IFS= read -r line; do
        echo "$line" >> "$tmpfile"
        # Insert after the "- Source:" line in ## Agentic framework section
        if [[ "$inserted" -eq 0 ]] && [[ "$line" =~ ^-[[:space:]]*Source: ]]; then
            echo "" >> "$tmpfile"
            echo "## Settings" >> "$tmpfile"
            echo "<!-- Profile sets defaults. Override individual settings below. -->" >> "$tmpfile"
            echo "- profile: ${profile}" >> "$tmpfile"
            echo "" >> "$tmpfile"
            inserted=1
        fi
    done < "$stack_file"

    # Fallback: append at end
    if [[ "$inserted" -eq 0 ]]; then
        echo "" >> "$tmpfile"
        echo "## Settings" >> "$tmpfile"
        echo "<!-- Profile sets defaults. Override individual settings below. -->" >> "$tmpfile"
        echo "- profile: ${profile}" >> "$tmpfile"
        echo "" >> "$tmpfile"
    fi

    mv "$tmpfile" "$stack_file"
}

# Migrate: add ## Settings section with current values
_settings_migrate() {
    local stack_file="$ROOT_DIR/STACK.md"

    if [ ! -f "$stack_file" ]; then
        echo -e "${RED}Error: STACK.md not found${NC}"
        exit 1
    fi

    if grep -q "^## Settings" "$stack_file" 2>/dev/null; then
        echo -e "${YELLOW}## Settings section already exists in STACK.md${NC}"
        echo "Run 'ag set --show' to see resolved settings."
        return 0
    fi

    _settings_create_section
    echo -e "${GREEN}Created ## Settings section in STACK.md${NC}"
    echo ""
    echo "Current resolved settings:"
    show_all_settings
}

# Todo command - quick-capture ideas/tasks to TODO.md
cmd_todo() {
    local first_arg="${1:-}"

    if [ -z "$first_arg" ]; then
        echo -e "${RED}Error: Description or subcommand required${NC}"
        echo "Usage: ag todo \"description\"          # add item"
        echo "       ag todo list                    # show inbox"
        echo "       ag todo done T-0001 \"resolved\"  # resolve item"
        echo "       ag todo drop T-0001 \"reason\"    # drop item"
        echo "       ag todo triage T-0001 feature   # promote to FEATURES.md"
        exit 1
    fi

    case "$first_arg" in
        list|done|drop|triage)
            shift
            bash "$SCRIPT_DIR/todo.sh" "$first_arg" "$@"
            ;;
        *)
            # Default: treat as "add" with description
            shift
            bash "$SCRIPT_DIR/todo.sh" add "$first_arg" "$@"
            ;;
    esac
}

# --- ag feedback ---
cmd_feedback() {
    local first_arg="${1:-}"

    if [ -z "$first_arg" ]; then
        echo -e "${RED}Error: Subcommand or feedback text required${NC}"
        echo "Usage: ag feedback \"text\"                      # classify + persist"
        echo "       ag feedback --bug \"text\"                 # direct route to ISSUES.md"
        echo "       ag feedback --feature \"text\"             # direct route to TODO.md"
        echo "       ag feedback --ac F-XXXX AC-XXX \"text\"    # AC adjustment"
        echo "       ag feedback log [--pending]              # show entries"
        echo "       ag feedback route FB-XXXX                # route pending item"
        echo "       ag feedback classify FB-XXXX type        # reclassify"
        echo "       ag feedback done FB-XXXX [\"resolution\"]  # mark resolved"
        exit 1
    fi

    case "$first_arg" in
        log|route|classify|done)
            shift
            bash "$SCRIPT_DIR/feedback.sh" "$first_arg" "$@"
            ;;
        --bug|--feature|--ac)
            # Direct type flags: pass everything to add
            bash "$SCRIPT_DIR/feedback.sh" add "$@"
            ;;
        *)
            # Default: treat as "add" with text
            shift
            bash "$SCRIPT_DIR/feedback.sh" add "$first_arg" "$@"
            ;;
    esac
}

# --- ag audit ---
cmd_audit() {
    local arg="${1:-}"
    case "$arg" in
        --full|--report)
            bash "$SCRIPT_DIR/spec-audit.sh" --report
            ;;
        --status)
            bash "$SCRIPT_DIR/spec-audit.sh" --status
            ;;
        --propagate)
            bash "$SCRIPT_DIR/spec-audit.sh" --propagate "${2:-}"
            ;;
        --metrics)
            bash "$SCRIPT_DIR/spec-metrics.sh" "${2:-}"
            ;;
        --since-last|"")
            bash "$SCRIPT_DIR/spec-audit.sh" --since-last
            ;;
        *)
            bash "$SCRIPT_DIR/spec-audit.sh" "$arg"
            ;;
    esac
}

# --- ag nfr ---
cmd_nfr() {
    local subcmd="${1:-}"
    shift 2>/dev/null || true
    case "$subcmd" in
        list|"")
            bash "$SCRIPT_DIR/nfr.sh" list
            ;;
        discover)
            echo -e "${BOLD}NFR Discovery${NC}"
            echo ""
            # Run nfr-generate.sh for smart recommendations (default limit 8)
            local gen_args=("--limit" "8")
            # Append any remaining args (--project-type, --components, --all)
            # User can override --limit by passing their own --limit N (last wins in arg parsing)
            [[ $# -gt 0 ]] && gen_args+=("$@")
            bash "$SCRIPT_DIR/nfr-generate.sh" "${gen_args[@]}"
            local rc=$?
            if [[ $rc -eq 0 ]]; then
                echo ""
                echo "--- AGENT INSTRUCTION ---"
                echo "Present the recommendations above to the user. For each selected NFR:"
                echo "1. Let the user customize thresholds (values in {threshold} placeholders)"
                echo "2. Write selected NFRs using the batch writer:"
                echo "   bash $SCRIPT_DIR/nfr-generate.sh --machine --limit 8 | bash $SCRIPT_DIR/nfr-write-batch.sh"
                echo "   Or for selective write, filter the machine output to desired entries first."
                echo "3. Create acceptance files: .agentic/spec/acceptance/NFR-XXXX.md"
                echo "'looks good' or 'all' = pipe all through batch writer with default thresholds."
                echo "'just 1,3,5' = filter to those entries, then pipe through batch writer."
                echo "'none' = skip NFR setup."
                echo "--- END INSTRUCTION ---"
            fi
            ;;
        coverage)
            bash "$SCRIPT_DIR/nfr-health.sh" --coverage-only
            ;;
        health)
            bash "$SCRIPT_DIR/nfr-health.sh" "$@"
            ;;
        sync)
            bash "$SCRIPT_DIR/nfr-propagate.sh" sync "$@"
            ;;
        test-check)
            bash "$SCRIPT_DIR/nfr-test-check.sh" "$@"
            ;;
        capture)
            bash "$SCRIPT_DIR/nfr-capture.sh" "$@"
            ;;
        *)
            if [[ "$subcmd" =~ ^NFR-[0-9]{4}$ ]]; then
                bash "$SCRIPT_DIR/nfr.sh" "$subcmd" "${1:-show}"
            else
                echo "Usage: ag nfr <command> [args]"
                echo ""
                echo "Commands:"
                echo "  list               List all NFRs with status"
                echo "  discover           Smart NFR recommendations based on stack"
                echo "  health             NFR health report (status, coverage, staleness)"
                echo "  coverage           NFR coverage across features"
                echo "  sync F-XXXX        Compare current ACs vs expected NFR constraints"
                echo "  test-check F-XXXX  Check NFR test coverage for a feature"
                echo "  capture \"stmt\"     Capture informal invariant as structured NFR"
                echo "  NFR-XXXX [show]    Show/update specific NFR"
            fi
            ;;
    esac
}

# Backlog command — manage ordered work queue
cmd_backlog() {
    local subcmd="${1:-}"
    shift 2>/dev/null || true

    case "$subcmd" in
        add|current|next|done|list|remove|move|clear)
            bash "$SCRIPT_DIR/backlog.sh" "$subcmd" "$@"
            ;;
        ""|--help)
            echo "ag backlog — Ordered work queue"
            echo ""
            echo "COMMANDS:"
            echo "  (none)           Show current + next"
            echo "  list             Full queue with positions"
            echo "  add F-XXXX       Append feature to queue (auto-discovers refs)"
            echo "  add F-XXXX -p 0  Make it current (top of queue)"
            echo "  add --task \"X\"   Add non-feature task"
            echo "  done             Remove position 0, advance"
            echo "  move F-XXXX N    Reprioritize to position N"
            echo "  remove F-XXXX    Remove from queue"
            echo "  clear            Empty queue"
            ;;
        *)
            echo "Unknown backlog subcommand: $subcmd" >&2
            echo "Run 'ag backlog --help' for usage." >&2
            return 1
            ;;
    esac
}

# Backlog advisory warning helper (for plan/spec commands)
_backlog_advisory() {
    local feature_id="$1"
    local command_name="$2"
    [ -z "$feature_id" ] && return 0
    is_feature_id "$feature_id" || return 0

    local current_json
    current_json=$(python3 "$SCRIPT_DIR/backlog_helpers.py" --project-root "$ROOT_DIR" json-current 2>/dev/null) || return 0
    [ -z "$current_json" ] && return 0

    local current_id
    current_id=$(echo "$current_json" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('id',''))" 2>/dev/null) || return 0

    if [ -n "$current_id" ] && [ "$current_id" != "$feature_id" ]; then
        echo -e "${YELLOW}ADVISORY: Backlog says current work is $current_id (running $command_name for $feature_id)${NC}"
        echo -e "  ${DIM}Work on current: ag implement $current_id${NC}"
        echo ""
    fi
    return 0
}

# ---------------------------------------------------------------------------
# Source command modules
# ---------------------------------------------------------------------------
COMMANDS_DIR="$SCRIPT_DIR/commands"
source "$COMMANDS_DIR/start.sh"
source "$COMMANDS_DIR/plan.sh"
source "$COMMANDS_DIR/implement.sh"
source "$COMMANDS_DIR/commit.sh"
source "$COMMANDS_DIR/done.sh"
source "$COMMANDS_DIR/kickoff.sh"
source "$COMMANDS_DIR/auto.sh"
source "$COMMANDS_DIR/specs.sh"

# Self-healing: ensure pre-commit hooks are installed on every ag invocation
# Addresses D2 (Deterministic Enforcement) — hooks must survive git config resets
_ensure_hooks() {
    local hook_mode
    hook_mode=$(get_setting "pre_commit_hook" "fast")
    [[ "$hook_mode" == "no" ]] && return 0
    [[ ! -d "$ROOT_DIR/.agentic/hooks" ]] && return 0
    command -v git >/dev/null 2>&1 || return 0
    git rev-parse --git-dir >/dev/null 2>&1 || return 0
    local hooks_path
    hooks_path=$(git config core.hooksPath 2>/dev/null || echo "")
    if [[ "$hooks_path" != ".agentic/hooks" ]]; then
        git config core.hooksPath .agentic/hooks
        echo -e "${YELLOW}Auto-fixed: pre-commit hooks installed (core.hooksPath)${NC}" >&2
    fi
}
_ensure_hooks

# Main command dispatch
case "${1:-help}" in
    start)
        cmd_start
        ;;
    init)
        cmd_init
        ;;
    work)
        cmd_work "${2:-}"
        ;;
    plan)
        cmd_plan "${2:-}" "${3:-}"
        ;;
    implement)
        cmd_implement "${2:-}"
        ;;
    spec)
        cmd_spec "${2:-}"
        ;;
    specs)
        cmd_specs "${2:-}"
        ;;
    todo)
        shift
        cmd_todo "$@"
        ;;
    feedback)
        shift
        cmd_feedback "$@"
        ;;
    commit)
        cmd_commit
        ;;
    done)
        cmd_done "${2:-}"
        ;;
    merge)
        cmd_merge "${2:-}" "${3:-}"
        ;;
    docs)
        shift
        cmd_docs "$@"
        ;;
    hooks)
        cmd_hooks "${2:-}" "${3:-}"
        ;;
    trace)
        shift
        cmd_trace "$@"
        ;;
    test)
        shift
        cmd_test "$@"
        ;;
    agents)
        shift
        cmd_agents "$@"
        ;;
    tools)
        cmd_tools
        ;;
    auto)
        shift
        cmd_auto "$@"
        ;;
    coord)
        shift
        cmd_coord "$@"
        ;;
    backlog)
        shift
        cmd_backlog "$@"
        ;;
    transition)
        shift
        python3 "$SCRIPT_DIR/../auto/state_machine.py" --project-root "$ROOT_DIR" "$@"
        ;;
    review)
        shift
        python3 "$SCRIPT_DIR/../auto/review.py" --project-root "$ROOT_DIR" "$@"
        ;;
    kickoff)
        shift
        cmd_kickoff "$@"
        ;;
    decompose)
        shift
        python3 "$SCRIPT_DIR/../auto/epic.py" decompose --project-root "$ROOT_DIR" "$@"
        ;;
    audit)
        shift
        cmd_audit "$@"
        ;;
    nfr)
        shift
        cmd_nfr "$@"
        ;;
    dogfood)
        shift
        bash "$SCRIPT_DIR/dogfood-sync.sh" "$@"
        ;;
    flush)
        shift
        bash "$SCRIPT_DIR/state-commit.sh" "$@"
        ;;
    worktree)
        shift
        bash "$SCRIPT_DIR/worktree.sh" "$@"
        ;;
    intent)
        shift
        cmd_intent "$@"
        ;;
    sync)
        cmd_sync "${2:-}"
        ;;
    verify)
        cmd_verify "${2:-}"
        ;;
    approve-onboarding)
        cmd_approve_onboarding "${2:-}"
        ;;
    status)
        cmd_status
        ;;
    set)
        shift
        cmd_set "$@"
        ;;
    run)
        bash "$SCRIPT_DIR/run.sh"
        ;;
    formalize)
        shift
        bash "$SCRIPT_DIR/formalize.sh" "$@"
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        echo ""
        show_help
        exit 1
        ;;
esac
