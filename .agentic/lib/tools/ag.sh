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
source "$SCRIPT_DIR/fwlog.sh" 2>/dev/null || true

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


# get_plan_review_config is now a thin wrapper around get_setting
get_plan_review_config() {
    local key="$1"
    local default="$2"
    get_setting "$key" "$default"
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
source "$COMMANDS_DIR/help.sh"
source "$COMMANDS_DIR/diagnostics.sh"
source "$COMMANDS_DIR/settings.sh"
source "$COMMANDS_DIR/operations.sh"
source "$COMMANDS_DIR/git-init.sh"
source "$COMMANDS_DIR/contract.sh"
source "$COMMANDS_DIR/phase.sh"

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

# ---------------------------------------------------------------------------
# Main command dispatch
_AG_CMD="${1:-help}"
_AG_ARG="${*:2}"
if type flog &>/dev/null; then
    flog "ag.sh" "$_AG_CMD" "$_AG_ARG" "start"
    trap 'flog "ag.sh" "$_AG_CMD" "$_AG_ARG" "end:$?"' EXIT
fi

# v2 engine intercept removed (F-0244). All commands use v1 paths.

case "${1:-help}" in
    gate)
        # Policy engine entry point — called by hooks and CI
        shift
        PYTHONPATH="$ROOT_DIR/.agentic/lib" python3 -m gate "$@" --project-root "$ROOT_DIR"
        ;;
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
        shift; cmd_implement "$@"
        ;;
    spec)
        cmd_spec "${2:-}"
        ;;
    specs)
        cmd_specs "${2:-}"
        ;;
    contract)
        shift; cmd_contract "$@"
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
    qa)
        shift
        cmd_qa "$@"
        ;;
    trace)
        shift
        cmd_trace "$@"
        ;;
    analyze-session)
        shift
        cmd_analyze_session "$@"
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
    phase)
        shift
        cmd_phase "$@"
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
    migrate-specs)
        shift
        python3 "$SCRIPT_DIR/migrate-specs.py" --project-root "$ROOT_DIR" "$@"
        ;;
    formalize)
        shift
        bash "$SCRIPT_DIR/formalize.sh" "$@"
        ;;
    git-init)
        cmd_git_init
        ;;
    gitignore)
        bash "$SCRIPT_DIR/gitignore.sh"
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
