#!/usr/bin/env bash
# ag.sh - Agentic Framework Gateway
# Single entry point for all framework operations
# Works with any AI agent (Claude Code, Cursor, Codex, Copilot)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${ROOT_DIR:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

# Source shared settings library
source "$SCRIPT_DIR/../lib/settings.sh"

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
    docs [F-XXXX]       Draft docs from registry (STACK.md ## Docs)
    set [key] [value]   View/change settings (--show, --validate, --migrate)
    hooks <sub>         Manage git hooks (install|status|disable)
    approve-onboarding  Review/approve auto-discovered proposals
    trace [options]     Spec-code traceability (drift + coverage)
    test llm [options]  Run LLM behavioral tests
    tools               List all available tools by category
    sync [--check|--quiet] Detect drift across all artifacts, auto-fix safe errors
    verify [--full]     Run doctor verification
    status              Show current project status
    help                Show this help

EXAMPLES:
    ag start                    # Begin a new session
    ag init                     # Initialize project (if not done)
    ag work "Add login form"    # Start working on a task
    ag todo "Try new library"   # Capture idea to TODO.md
    ag todo list                # Show inbox items
    ag todo done T-0001 "done"  # Resolve item
    ag docs                     # Draft docs for current work
    ag docs --list              # Show doc registry
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
    specs               Systematic brownfield spec generation by domain
    todo <args>         Quick-capture ideas/tasks to TODO.md inbox
    commit              Run all pre-commit gates
    done [F-XXXX]       Feature complete validation
    docs [F-XXXX]       Draft docs from registry (STACK.md ## Docs)
    set [key] [value]   View/change settings (--show, --validate, --migrate)
    hooks <sub>         Manage git hooks (install|status|disable)
    approve-onboarding  Review/approve auto-discovered proposals
    trace [options]     Spec-code traceability (drift + coverage)
    test llm [options]  Run LLM behavioral tests
    tools               List all available tools by category
    sync [--check|--quiet] Detect drift across all artifacts, auto-fix safe errors
    verify [--full]     Run doctor verification
    status              Show current project status
    help                Show this help

EXAMPLES:
    ag start                    # Begin a new session
    ag init                     # Initialize project (if not done)
    ag plan F-0042              # Create plan with iterative review
    ag plan F-0042 --no-review  # Create plan without review loop
    ag implement F-0042         # Start working on feature F-0042
    ag specs                    # Start/resume brownfield spec generation
    ag specs --status           # Show domain progress
    ag todo "Try new library"   # Capture idea to TODO.md
    ag todo list                # Show inbox items
    ag todo done T-0001 "done"  # Resolve item
    ag commit                   # Verify ready to commit
    ag done F-0042              # Check feature completion
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
    ag docs F-0042              # Draft docs for feature F-0042
    ag docs --list              # Show doc registry from STACK.md
    ag docs --pr                # Draft PR-trigger docs only
    ag docs --check             # Dry run: what would be drafted
    ag sync                     # Full sync: detect + auto-fix
    ag sync --check             # Dry run: detect only
    ag verify --full            # Full verification

Feature tracking with acceptance criteria.
EOF
    fi
}

# Get verification state summary
get_verification_summary() {
    local state_file="$ROOT_DIR/.agentic-state/.verification-state"
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

# Session start command
cmd_start() {
    # 0. Check for uninitialized framework (CRITICAL - check first!)
    if ! check_initialization; then
        show_init_warning
        echo -e "${YELLOW}Continuing with session start, but initialization is recommended.${NC}"
        echo ""
    fi

    echo -e "${BOLD}=== Session Start ===${NC}"
    echo ""

    # 1. Check for other active agents
    if [ -f "$ROOT_DIR/.agentic-state/AGENTS_ACTIVE.md" ]; then
        local active_count
        active_count=$(grep -c "^##" "$ROOT_DIR/.agentic-state/AGENTS_ACTIVE.md" 2>/dev/null || echo "0")
        if [ "$active_count" -gt 0 ]; then
            echo -e "${YELLOW}Multi-agent: $active_count agent(s) active${NC}"
            head -20 "$ROOT_DIR/.agentic-state/AGENTS_ACTIVE.md" 2>/dev/null | grep "^##" || true
            echo ""
        fi
    fi

    # 2. Check for WIP (interrupted work)
    if [ -f "$ROOT_DIR/.agentic-state/WIP.md" ]; then
        echo -e "${YELLOW}WIP detected - previous work was interrupted${NC}"
        bash "$SCRIPT_DIR/wip.sh" check 2>/dev/null || true
        echo ""
    fi

    # 2.5. Check memory integrity (advisory)
    bash "$SCRIPT_DIR/memory-check.sh" --quiet 2>&1 || true

    # 3. Verification status
    get_verification_summary
    echo ""

    # 4. Show current focus from STATUS.md
    if [ -f "$ROOT_DIR/STATUS.md" ]; then
        echo -e "${BOLD}Current Focus:${NC}"
        grep -A 3 "^## Current Focus" "$ROOT_DIR/STATUS.md" 2>/dev/null | tail -n +2 | head -3 || \
        grep -A 1 "Current focus:" "$ROOT_DIR/STATUS.md" 2>/dev/null || \
        echo "  (Not set in STATUS.md)"
        echo ""
    fi

    # 5. Check HUMAN_NEEDED.md for blockers
    if [ -f "$ROOT_DIR/HUMAN_NEEDED.md" ]; then
        local blocker_count
        blocker_count=$(grep -c "^### HN-" "$ROOT_DIR/HUMAN_NEEDED.md" 2>/dev/null || echo "0")
        if [ "$blocker_count" -gt 0 ]; then
            echo -e "${YELLOW}Blockers: $blocker_count item(s) need human input${NC}"
        fi
    fi

    # 5b. Check TODO.md inbox
    if [ -f "$ROOT_DIR/TODO.md" ]; then
        local todo_count
        todo_count=$(awk '/^## Inbox/,/^## Done/' "$ROOT_DIR/TODO.md" 2>/dev/null | grep -c "^### T-" || echo "0")
        if [ "$todo_count" -gt 0 ]; then
            echo -e "${BLUE}TODO inbox: $todo_count item(s)${NC} (ag todo list)"
        fi
    fi

    # 6. Run doctor quick check
    echo ""
    echo -e "${BOLD}Quick Health Check:${NC}"
    bash "$SCRIPT_DIR/doctor.sh" --quick 2>/dev/null | head -20 || echo "  (doctor.sh not available)"

    # 7. Hook configuration check
    if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
        local hooks_path
        hooks_path=$(git config core.hooksPath 2>/dev/null || echo "")
        if [ "$hooks_path" != ".agentic/hooks" ]; then
            echo -e "${YELLOW}Git hooks not configured — pre-commit quality gates inactive${NC}"
            echo -e "  Fix: ${BOLD}ag hooks install${NC}"
            echo ""
        fi
    fi

    # 8. Quick sync probe
    local sync_summary
    sync_summary=$(bash "$SCRIPT_DIR/sync.sh" --quiet 2>/dev/null || true)
    if [ -n "$sync_summary" ]; then
        echo ""
        echo -e "${YELLOW}${sync_summary}${NC}"
        echo -e "  Run ${BOLD}ag sync${NC} to auto-fix and see details"
    fi

    # Tip of the day
    local tips=(
        "Run \`ag sync\` to detect and auto-fix drift across memory, specs, docs, and tools."
        "Use \`ag plan F-XXXX\` to start a plan-review loop — two agents debate until the plan is solid."
        "Run \`ag trace\` to see which code implements which features (and find gaps)."
        "Use \`ag test llm\` to verify agents actually follow framework rules."
        "Run \`ag sync --check\` for a dry run — see what's drifted without changing anything."
        "Use \`ag trace --gaps\` to find shipped features with no code annotations."
        "Run \`ag verify --full\` for a comprehensive health check of all framework files."
        "Use \`ag specs\` to systematically generate specs for existing code, domain by domain."
        "Run \`ag tools\` to discover all available framework tools and scripts."
        "Use \`ag approve-onboarding\` to review auto-discovered project proposals after init."
    )
    local tip_index=$((RANDOM % ${#tips[@]}))
    echo ""
    echo -e "${DIM}Tip: ${tips[$tip_index]}${NC}"

    echo ""
    local ft
    ft=$(get_setting "feature_tracking" "no")
    if [ "$ft" = "no" ]; then
        echo -e "${BOLD}Ready to work. Run 'ag work \"description\"' to start a task.${NC}"
    else
        echo -e "${BOLD}Ready to work. Run 'ag implement F-XXXX' to start a feature.${NC}"
    fi
    echo -e "${DIM}Remind user: ag plan (plan-review before building) | ag sync (detect & fix drift)${NC}"
}

# Work command (Discovery profile) - start WIP tracking without feature ID
cmd_work() {
    local description="${1:-}"

    if [ -z "$description" ]; then
        echo -e "${RED}Error: Task description required${NC}"
        echo "Usage: ag work \"Add login form\""
        exit 1
    fi

    # Feature tracking: hard block — require feature ID with acceptance criteria
    local ft
    ft=$(get_setting "feature_tracking" "no")
    if [ "$ft" = "yes" ]; then
        echo -e "${RED}BLOCKED: Feature tracking is enabled — requires a feature ID with acceptance criteria.${NC}"
        echo ""
        echo "To start:"
        echo "  1. Add feature to spec/FEATURES.md (next available F-XXXX)"
        echo "  2. Create spec/acceptance/F-XXXX.md with acceptance criteria"
        echo "  3. Run: ag implement F-XXXX"
        echo ""
        echo "Disable feature_tracking to use ag work without feature IDs."
        exit 1
    fi

    echo -e "${BOLD}=== Starting Task ===${NC}"
    echo "Task: $description"
    echo ""

    # Start WIP tracking
    echo "Starting WIP tracking..."
    bash "$SCRIPT_DIR/wip.sh" start "task" "$description" "" 2>/dev/null || \
        echo -e "${YELLOW}WIP tracking not started (wip.sh not available or already active)${NC}"

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

# Plan command - create plan with iterative review
cmd_plan() {
    local feature_id="${1:-}"
    local no_review=false

    # Handle --save subcommand: ag plan --save <source-file> F-XXXX
    if [ "$feature_id" = "--save" ]; then
        local source_file="${2:-}"
        local save_fid="${3:-}"
        if [ -z "$source_file" ] || [ -z "$save_fid" ]; then
            echo -e "${RED}Usage: ag plan --save <source-file> F-XXXX${NC}"
            echo "  Copies a plan to .agentic-journal/plans/F-XXXX-plan.md"
            exit 1
        fi
        if [ ! -f "$source_file" ]; then
            echo -e "${RED}Error: Source file not found: $source_file${NC}"
            exit 1
        fi
        local dest_dir="$ROOT_DIR/.agentic-journal/plans"
        mkdir -p "$dest_dir"
        cp "$source_file" "$dest_dir/${save_fid}-plan.md"
        echo -e "${GREEN}Plan saved: $dest_dir/${save_fid}-plan.md${NC}"
        return 0
    fi

    # Parse options
    if [ "${2:-}" = "--no-review" ]; then
        no_review=true
    fi

    # Check feature tracking
    local ft
    ft=$(get_setting "feature_tracking" "no")
    if [ "$ft" = "no" ]; then
        echo -e "${YELLOW}Feature tracking is off — no feature IDs.${NC}"
        echo "Enable with: ag set feature_tracking yes"
        echo "You can still create informal plans in STATUS.md."
        exit 1
    fi

    if [ -z "$feature_id" ]; then
        echo -e "${RED}Error: Feature ID required${NC}"
        echo "Usage: ag plan F-XXXX [--no-review]"
        exit 1
    fi

    # Validate feature ID format
    if ! echo "$feature_id" | grep -qE '^F-[0-9]{4}$'; then
        echo -e "${RED}Error: Invalid feature ID format. Expected: F-XXXX (e.g., F-0042)${NC}"
        exit 1
    fi

    echo -e "${BOLD}=== Plan: $feature_id ===${NC}"
    echo ""

    # 0. Check feature exists in FEATURES.md (BLOCKING)
    if [ "${SKIP_SPEC_CHECK:-}" = "1" ]; then
        echo -e "${YELLOW}⚠ SKIP_SPEC_CHECK: Bypassing spec-first gate${NC}"
    else
        local features_file="$ROOT_DIR/spec/FEATURES.md"
        if [ -f "$features_file" ]; then
            if grep -q "^## ${feature_id}:" "$features_file"; then
                echo -e "${GREEN}Feature registered: YES${NC}"
            else
                echo -e "${RED}BLOCKED: ${feature_id} not found in FEATURES.md${NC}"
                echo "  Add it first: add an entry to spec/FEATURES.md"
                echo "  Or bypass: SKIP_SPEC_CHECK=1 ag plan $feature_id"
                exit 1
            fi
        fi
    fi

    # 1. Check acceptance criteria (advisory for plan, blocking for implement)
    local acc_file="$ROOT_DIR/spec/acceptance/${feature_id}.md"
    if [ ! -f "$acc_file" ]; then
        echo -e "${YELLOW}Note: No acceptance criteria yet (spec/acceptance/${feature_id}.md)${NC}"
        echo "  The plan-review loop can help define what to build."
        echo "  Acceptance criteria will be required before 'ag implement'."
        echo ""
    else
        echo -e "${GREEN}Acceptance criteria: EXISTS${NC}"
    fi

    # 2. Check for existing plan
    local plan_file="$ROOT_DIR/.agentic-journal/plans/${feature_id}-plan.md"
    mkdir -p "$ROOT_DIR/.agentic-journal/plans"

    if [ -f "$plan_file" ]; then
        local status
        status=$(grep -E "^\*\*Status\*\*:" "$plan_file" 2>/dev/null | head -1 | sed 's/.*Status\*\*:[[:space:]]*//' || echo "UNKNOWN")
        echo -e "${YELLOW}Existing plan found: $status${NC}"
        if [ "$status" = "APPROVED" ]; then
            echo "Plan already approved. Ready for implementation."
            echo "  Plan: $plan_file"
            return 0
        fi
        echo "  Previous plan at: $plan_file"
        echo ""
    fi

    # 3. Get config
    local enabled max_iterations
    enabled=$(get_plan_review_config "plan_review_enabled" "yes")
    max_iterations=$(get_plan_review_config "plan_review_max_iterations" "3")

    if [ "$no_review" = true ] || [ "$enabled" = "no" ]; then
        echo -e "${YELLOW}Review loop: SKIPPED${NC}"
        echo ""
        echo "Creating plan without review..."
        echo ""
        echo -e "${BOLD}AGENT INSTRUCTION:${NC}"
        echo "Create implementation plan for $feature_id."
        echo ""
        echo "Read:"
        echo "  - spec/acceptance/${feature_id}.md"
        echo "  - CONTEXT_PACK.md"
        echo ""
        echo "Write plan to: .agentic-journal/plans/${feature_id}-plan.md"
        echo "Follow format in: .agentic/workflows/plan_review_loop.md"
        echo "Set status to: APPROVED (no review)"
        return 0
    fi

    # 4. Show plan-review loop instructions
    echo -e "${GREEN}Review loop: ENABLED (max $max_iterations iterations)${NC}"
    echo ""
    echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}PLAN-REVIEW LOOP INSTRUCTIONS${NC}"
    echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "This feature uses iterative planning with critical review."
    echo "Spawn two agents: PLANNER and REVIEWER."
    echo ""
    echo -e "${BLUE}STEP 1: PLANNER creates initial plan${NC}"
    echo "  Task tool:"
    echo "    subagent_type: Plan"
    echo "    prompt: \"Create implementation plan for $feature_id."
    echo "            Read: spec/acceptance/${feature_id}.md, CONTEXT_PACK.md"
    echo "            Write to: .agentic-journal/plans/${feature_id}-plan.md"
    echo "            Follow: .agentic/workflows/plan_review_loop.md\""
    echo ""
    echo -e "${BLUE}STEP 2: REVIEWER critiques the plan${NC}"
    echo "  Task tool:"
    echo "    subagent_type: general-purpose"
    echo "    model: opus  # Critical review needs quality"
    echo "    prompt: \"Critically review plan at .agentic-journal/plans/${feature_id}-plan.md"
    echo "            Follow reviewer instructions in .agentic/workflows/plan_review_loop.md"
    echo "            Add review to Review History section."
    echo "            Set verdict: APPROVED, REVISION_NEEDED, or ESCALATE\""
    echo ""
    echo -e "${BLUE}STEP 3: Loop until APPROVED or max iterations${NC}"
    echo "  - If REVISION_NEEDED: Planner revises, Reviewer re-reviews"
    echo "  - If ESCALATE or max reached: Human intervention needed"
    echo "  - If APPROVED: Ready for 'ag implement $feature_id'"
    echo ""
    echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "Plan artifact: .agentic-journal/plans/${feature_id}-plan.md"
    echo "Workflow docs: .agentic/workflows/plan_review_loop.md"
}

# Implement command - verify acceptance exists, start WIP (Formal only)
cmd_implement() {
    local feature_id="${1:-}"

    # Check feature tracking
    local ft
    ft=$(get_setting "feature_tracking" "no")
    if [ "$ft" = "no" ]; then
        echo -e "${YELLOW}Feature tracking is off — no feature IDs.${NC}"
        echo "Use: ag work \"description\" instead"
        echo "Enable with: ag set feature_tracking yes"
        exit 1
    fi

    if [ -z "$feature_id" ]; then
        echo -e "${RED}Error: Feature ID required${NC}"
        echo "Usage: ag implement F-XXXX"
        exit 1
    fi

    # Validate feature ID format
    if ! echo "$feature_id" | grep -qE '^F-[0-9]{4}$'; then
        echo -e "${RED}Error: Invalid feature ID format. Expected: F-XXXX (e.g., F-0042)${NC}"
        exit 1
    fi

    echo -e "${BOLD}=== Implement: $feature_id ===${NC}"
    echo ""

    # 0a. Check: one feature at a time (WIP conflict detection)
    if [ -f "$ROOT_DIR/.agentic-state/WIP.md" ]; then
        # WIP.md format: "- **Feature**: F-XXXX: description" (from wip.sh line 159)
        local current_wip
        current_wip=$(grep -oE 'F-[0-9]{4}' "$ROOT_DIR/.agentic-state/WIP.md" | head -1)
        if [ -n "$current_wip" ] && [ "$current_wip" != "$feature_id" ]; then
            echo -e "${RED}BLOCKED: $current_wip is already in progress${NC}"
            echo "  Complete it first: ag done $current_wip"
            echo "  Or clear WIP: bash .agentic/tools/wip.sh complete"
            exit 1
        fi
    fi

    # 0b. Check plan-review (BLOCKING when enabled)
    local plan_review_enabled
    plan_review_enabled=$(get_plan_review_config "plan_review_enabled" "no")
    if [ "$plan_review_enabled" = "yes" ]; then
        local plan_file="$ROOT_DIR/.agentic-journal/plans/${feature_id}-plan.md"
        if [ -f "$plan_file" ]; then
            local plan_status
            plan_status=$(grep -E "^\*\*Status\*\*:" "$plan_file" 2>/dev/null | head -1 | sed 's/.*Status\*\*:[[:space:]]*//' || echo "UNKNOWN")
            if [ "$plan_status" != "APPROVED" ]; then
                echo -e "${RED}BLOCKED: Plan exists but not approved (status: $plan_status)${NC}"
                echo "  Complete the review loop: ag plan $feature_id"
                exit 1
            else
                echo -e "${GREEN}Approved plan: EXISTS${NC}"
            fi
        else
            echo -e "${RED}BLOCKED: No approved plan found (plan_review_enabled: yes)${NC}"
            echo "  Run: ag plan $feature_id"
            echo "  This starts the plan-review loop before implementation."
            exit 1
        fi
    fi

    # 0c. Auto-save plans from session-scoped tool directories to durable location
    # Claude Code uses .claude/plans/, Cursor uses .cursor/plans/
    local durable_plan="$ROOT_DIR/.agentic-journal/plans/${feature_id}-plan.md"
    if [ ! -f "$durable_plan" ]; then
        for plan_dir in "$ROOT_DIR/.claude/plans" "$ROOT_DIR/.cursor/plans"; do
            [ -d "$plan_dir" ] || continue
            for f in "$plan_dir/"*; do
                if [ -f "$f" ] && grep -q "$feature_id" "$f" 2>/dev/null; then
                    mkdir -p "$ROOT_DIR/.agentic-journal/plans"
                    cp "$f" "$durable_plan"
                    local source_rel="${plan_dir#"$ROOT_DIR"/}"
                    echo -e "${GREEN}Plan auto-saved: ${source_rel}/ -> .agentic-journal/plans/${feature_id}-plan.md${NC}"
                    break 2
                fi
            done
        done
    fi

    # 1. Spec-first gate (BLOCKING unless SKIP_SPEC_CHECK=1)
    if [ "${SKIP_SPEC_CHECK:-}" = "1" ]; then
        echo -e "${YELLOW}⚠ SKIP_SPEC_CHECK: Bypassing spec-first gate${NC}"
    else
        # 1a. Check feature exists in FEATURES.md
        local features_file="$ROOT_DIR/spec/FEATURES.md"
        if [ -f "$features_file" ]; then
            if grep -q "^## ${feature_id}:" "$features_file"; then
                echo -e "${GREEN}Feature registered: YES${NC}"
            else
                echo -e "${RED}BLOCKED: ${feature_id} not found in FEATURES.md${NC}"
                echo "  Add it first: add an entry to spec/FEATURES.md"
                echo "  Or bypass: SKIP_SPEC_CHECK=1 ag implement $feature_id"
                exit 1
            fi
        fi

        # 1b. Check acceptance criteria exist
        local acc_file="$ROOT_DIR/spec/acceptance/${feature_id}.md"
        if [ ! -f "$acc_file" ]; then
            echo -e "${RED}BLOCKED: No acceptance criteria${NC}"
            echo "  Missing: spec/acceptance/${feature_id}.md"
            echo ""
            echo "Create acceptance criteria FIRST, then run this command again."
            echo "  Template: .agentic/spec/acceptance.template.md"
            echo "  Or bypass: SKIP_SPEC_CHECK=1 ag implement $feature_id"
            exit 1
        fi
        echo -e "${GREEN}Acceptance criteria: EXISTS${NC}"
    fi

    # 3. Run planning phase check (BLOCKING)
    echo ""
    echo "Running phase check..."
    if ! bash "$SCRIPT_DIR/doctor.sh" --phase planning "$feature_id" 2>/dev/null; then
        echo -e "${RED}BLOCKED: Planning phase checks failed. Fix issues above.${NC}"
        exit 1
    fi

    # 4. Start WIP tracking
    echo ""
    echo "Starting WIP tracking..."

    # Get feature name from FEATURES.md if available
    local feature_name=""
    if [ -f "$features_file" ]; then
        feature_name=$(grep "^## ${feature_id}:" "$features_file" | sed "s/^## ${feature_id}: //" || echo "")
    fi

    bash "$SCRIPT_DIR/wip.sh" start "$feature_id" "${feature_name:-$feature_id}" "" 2>/dev/null || \
        echo -e "${YELLOW}WIP tracking not started (wip.sh not available or already active)${NC}"

    echo ""
    echo -e "${GREEN}Ready to implement ${feature_id}${NC}"
    echo "Remember: Update FEATURES.md status to 'in_progress'"
    echo ""
    echo -e "${BOLD}References:${NC}"
    echo "  Playbook: .agentic/agents/shared/auto_orchestration.md"
    echo "  Checklist: .agentic/checklists/feature_implementation.md"
}

# Commit command - pre-commit gates (profile-aware)
cmd_commit() {
    echo -e "${BOLD}=== Pre-Commit Gates ===${NC}"
    echo ""

    # 1. Check WIP exists
    local wip_mode
    wip_mode=$(get_setting "wip_before_commit" "warning")
    if [ -f "$ROOT_DIR/.agentic-state/WIP.md" ]; then
        if [ "$wip_mode" = "warning" ]; then
            echo -e "${YELLOW}WARNING: .agentic-state/WIP.md exists${NC}"
            echo "  Consider completing WIP: bash .agentic/tools/wip.sh complete"
            echo ""
        else
            echo -e "${RED}BLOCKED: .agentic-state/WIP.md exists${NC}"
            echo "  Work-in-progress must be completed before committing."
            echo "  Run: bash .agentic/tools/wip.sh complete"
            echo ""
            exit 1
        fi
    else
        echo -e "${GREEN}WIP check: PASS${NC}"
    fi

    # 2. Check for untracked files in key directories
    local untracked
    untracked=$(git status --porcelain 2>/dev/null | grep '^??' | grep -E '(src/|spec/|tests/|docs/)' | head -5 || true)
    if [ -n "$untracked" ]; then
        echo -e "${YELLOW}WARNING: Untracked files in project directories:${NC}"
        echo "$untracked" | head -5
        echo "  Consider: git add <files> or update .gitignore"
        echo ""
    else
        echo -e "${GREEN}Untracked check: PASS${NC}"
    fi

    # 3. Run doctor pre-commit checks
    local pcc
    pcc=$(get_setting "pre_commit_checks" "fast")
    echo ""
    if [ "$pcc" = "fast" ] || [ "$pcc" = "off" ]; then
        echo "Running basic checks (lightweight gates)..."
        bash "$SCRIPT_DIR/doctor.sh" --quick 2>/dev/null || true
        echo ""
        echo ""
        echo -e "${BOLD}Pre-commit artifacts check:${NC}"
        echo "   Have you updated JOURNAL.md?  (bash .agentic/tools/journal.sh ...)"
        echo "   Have you updated STATUS.md?   (bash .agentic/tools/status.sh ...)"
        echo ""
        echo -e "${GREEN}Ready to commit${NC}"
        echo "  git add <files>"
        echo "  git commit -m \"description\""
    else
        echo "Running pre-commit verification..."
        if bash "$SCRIPT_DIR/doctor.sh" --pre-commit 2>/dev/null; then
            echo ""
            echo -e "${GREEN}All pre-commit gates PASSED${NC}"

            # Additional check: FEATURES.md staleness (Formal only)
            if [ -f "$ROOT_DIR/spec/FEATURES.md" ]; then
                local spec_staged
                spec_staged=$(git diff --cached --name-only 2>/dev/null | grep "^spec/" || true)
                if [ -n "$spec_staged" ]; then
                    if ! git diff --cached --name-only 2>/dev/null | grep -q "FEATURES.md"; then
                        echo ""
                        echo -e "${YELLOW}WARNING: Spec files staged but FEATURES.md not updated${NC}"
                        echo "  Staged spec files: $(echo $spec_staged | tr '\n' ' ')"
                        echo "  Update with: bash .agentic/tools/feature.sh F-#### status <status>"
                    fi
                fi
            fi

            echo ""
            echo -e "${BOLD}Pre-commit artifacts check:${NC}"
            echo "   Have you updated JOURNAL.md?  (bash .agentic/tools/journal.sh ...)"
            echo "   Have you updated STATUS.md?   (bash .agentic/tools/status.sh ...)"
            echo ""
            echo "Ready to commit. Suggested workflow:"
            echo "  git add <files>"
            echo "  git commit -m \"feat(F-XXXX): description\""
            echo ""
            echo -e "${BOLD}Checklist:${NC} .agentic/checklists/before_commit.md"
        else
            echo ""
            echo -e "${RED}Pre-commit gates FAILED - fix issues above${NC}"
            exit 1
        fi
    fi
}

# Done command - feature/task complete validation
cmd_done() {
    local feature_id="${1:-}"

    local ft
    ft=$(get_setting "feature_tracking" "no")
    if [ "$ft" = "no" ]; then
        echo -e "${BOLD}=== Task Complete Check ===${NC}"
        echo ""
        echo -e "${BOLD}Definition of Done:${NC}"
        echo "  [ ] Task completed as described"
        echo "  [ ] Tests written and passing (if applicable)"
        echo "  [ ] STATUS.md updated"
        echo "  [ ] JOURNAL.md updated"
        echo ""
        # Quick health check (warning only — Discovery mode)
        if bash "$SCRIPT_DIR/doctor.sh" --quick 2>/dev/null; then
            echo -e "${GREEN}✓${NC} Quick health check passed"
        else
            echo -e "${YELLOW}⚠ Quick health check found issues (non-blocking)${NC}"
        fi
        echo ""
        # Check if WIP is complete
        if [ -f "$ROOT_DIR/.agentic-state/WIP.md" ]; then
            echo -e "${YELLOW}Note: WIP tracking still active. Complete it with:${NC}"
            echo "  bash .agentic/tools/wip.sh complete"
        fi
        return
    fi

    # Generate manifest for feature (Formal profile)
    if [ -n "$feature_id" ] && echo "$feature_id" | grep -qE '^F-[0-9]{4}$'; then
        echo -e "${BOLD}=== Generating Change Manifest ===${NC}"
        if bash "$SCRIPT_DIR/manifest.sh" "$feature_id" 2>/dev/null; then
            local manifest_file="$ROOT_DIR/.agentic-journal/manifests/${feature_id}.manifest.md"
            if [ -f "$manifest_file" ]; then
                # Extract stats for journal metadata
                local commit_count file_count
                commit_count=$(grep -c "^|" "$manifest_file" 2>/dev/null | head -1 || echo "0")
                commit_count=$((commit_count - 2))  # Subtract header rows
                file_count=$(grep -c "^\- \`" "$manifest_file" 2>/dev/null || echo "0")
                echo -e "${GREEN}Manifest generated: .agentic-journal/manifests/${feature_id}.manifest.md${NC}"
                echo "  Commits: $commit_count, Files: $file_count"
            fi
        else
            echo -e "${YELLOW}Could not generate manifest (no matching commits?)${NC}"
        fi
        echo ""
    fi

    # Doc drift gate (controlled by docs_gate setting)
    local docs_gate_mode
    docs_gate_mode=$(get_setting "docs_gate" "off")
    if [ "$docs_gate_mode" != "off" ]; then
        echo -e "${BOLD}=== Documentation Drift Check ===${NC}"
        if [ -n "$feature_id" ]; then
            bash "$SCRIPT_DIR/drift.sh" --docs --manifest "$feature_id" 2>/dev/null || true
        else
            bash "$SCRIPT_DIR/drift.sh" --docs 2>/dev/null || true
        fi
        if [ "$docs_gate_mode" = "blocking" ]; then
            if [ "${SKIP_DOCS_GATE:-0}" = "1" ] || [ ! -t 0 ]; then
                echo -e "${YELLOW}docs_gate: blocking — skipped (non-interactive or SKIP_DOCS_GATE=1)${NC}"
            else
                echo ""
                echo -e "${YELLOW}docs_gate: blocking — confirm docs are updated before marking complete${NC}"
                printf "  Continue marking feature complete? [y/N] "
                local doc_confirm
                read -r doc_confirm
                if [[ ! "$doc_confirm" =~ ^[Yy]$ ]]; then
                    echo -e "${RED}Aborted: Update documentation first, then run ag done again.${NC}"
                    exit 1
                fi
            fi
        fi
        echo ""
    fi

    # Doc lifecycle: draft docs from registry (after docs_gate, before complete check)
    if [[ -f "$SCRIPT_DIR/docs.sh" ]]; then
        local has_docs_registry
        has_docs_registry=$(bash "$SCRIPT_DIR/docs.sh" --list 2>/dev/null | grep -c "^  " || true)
        if [[ "$has_docs_registry" -gt 1 ]]; then
            echo -e "${BOLD}=== Doc Lifecycle ===${NC}"
            # feature_done trigger: both profiles
            if [ -n "$feature_id" ]; then
                bash "$SCRIPT_DIR/docs.sh" --trigger feature_done --manifest "$feature_id" 2>/dev/null || true
            else
                bash "$SCRIPT_DIR/docs.sh" --trigger feature_done 2>/dev/null || true
            fi
            # pr trigger: formal profile only
            local profile_val
            profile_val=$(get_setting "profile" "discovery")
            if [[ "$profile_val" == "formal" ]]; then
                if [ -n "$feature_id" ]; then
                    bash "$SCRIPT_DIR/docs.sh" --trigger pr --manifest "$feature_id" 2>/dev/null || true
                else
                    bash "$SCRIPT_DIR/docs.sh" --trigger pr 2>/dev/null || true
                fi
            fi
            echo ""
        fi
    fi

    echo -e "${BOLD}=== Feature Complete Check ===${NC}"
    echo ""

    # If feature ID provided, run specific checks
    if [ -n "$feature_id" ]; then
        if ! echo "$feature_id" | grep -qE '^F-[0-9]{4}$'; then
            echo -e "${RED}Error: Invalid feature ID format. Expected: F-XXXX${NC}"
            exit 1
        fi

        echo "Checking: $feature_id"
        echo ""

        # Run complete phase check
        if ! bash "$SCRIPT_DIR/doctor.sh" --phase complete "$feature_id" 2>/dev/null; then
            echo -e "${RED}Structural checks FAILED - fix issues above before marking complete${NC}"
        fi

        # Blocking gates (Formal)
        local done_failures=0

        # Gate 1: Acceptance file must exist
        local acc_file="$ROOT_DIR/spec/acceptance/${feature_id}.md"
        if [ ! -f "$acc_file" ]; then
            echo -e "${RED}BLOCKED: Missing acceptance criteria${NC}"
            echo "  Expected: spec/acceptance/${feature_id}.md"
            done_failures=$((done_failures + 1))
        fi

        # Gate 2: Feature must be registered in FEATURES.md (heading OR table format)
        local features_file="$ROOT_DIR/spec/FEATURES.md"
        if [ -f "$features_file" ]; then
            if ! grep -qE "^## ${feature_id}:" "$features_file" && \
               ! grep -qE "^\|[[:space:]]*${feature_id}[[:space:]]*\|" "$features_file"; then
                echo -e "${RED}BLOCKED: $feature_id not found in FEATURES.md${NC}"
                echo "  Register it first, or use: bash .agentic/tools/feature.sh $feature_id status shipped"
                done_failures=$((done_failures + 1))
            fi
        fi

        if [ "$done_failures" -gt 0 ]; then
            echo ""
            echo -e "${RED}$done_failures blocking issue(s). Fix before marking complete.${NC}"
            exit 1
        fi

        # Check for untracked feature files
        echo ""
        echo -e "${BOLD}Drift Checks:${NC}"
        local untracked_feature_files=$(git status --porcelain 2>/dev/null | grep '^??' | grep -i "$feature_id\|$(echo $feature_id | tr '[:upper:]' '[:lower:]')" || true)
        if [ -n "$untracked_feature_files" ]; then
            echo -e "${YELLOW}⚠ Untracked files related to $feature_id:${NC}"
            echo "$untracked_feature_files" | sed 's/^??/   /'
            echo "  Consider: git add <files>"
        else
            echo -e "${GREEN}✓${NC} No untracked feature files"
        fi

        # Check if acceptance criteria file exists and has untracked state
        local acc_file="$ROOT_DIR/spec/acceptance/${feature_id}.md"
        if [ -f "$acc_file" ]; then
            if git status --porcelain "$acc_file" 2>/dev/null | grep -q '^??'; then
                echo -e "${YELLOW}⚠ Acceptance criteria file is untracked:${NC}"
                echo "   spec/acceptance/${feature_id}.md"
                echo "   Consider: git add spec/acceptance/${feature_id}.md"
            fi

            # Surface [Discovered] markers
            local discovered_count
            discovered_count=$(grep -c '\[Discovered\]' "$acc_file" 2>/dev/null || echo "0")
            if [ "$discovered_count" -gt 0 ]; then
                echo ""
                echo -e "${YELLOW}📋 Spec evolved: $discovered_count requirements discovered during implementation${NC}"
            fi
            echo ""
            echo -e "${BOLD}📝 Review acceptance criteria before marking accepted:${NC}"
            echo "   cat spec/acceptance/${feature_id}.md"
        fi

        # Check FEATURES.md shipped status (heading AND table format)
        local features_file="$ROOT_DIR/spec/FEATURES.md"
        if [ -f "$features_file" ]; then
            local feature_found=false
            local is_shipped=false

            # Check heading format: ## F-XXXX: Title
            if grep -qE "^## ${feature_id}:" "$features_file"; then
                feature_found=true
                if grep -A5 "^## ${feature_id}:" "$features_file" | grep -qi "shipped"; then
                    is_shipped=true
                fi
            fi

            # Check table format: | F-XXXX | ... |
            if grep -qE "^\|[[:space:]]*${feature_id}[[:space:]]*\|" "$features_file"; then
                feature_found=true
                if grep -E "^\|[[:space:]]*${feature_id}[[:space:]]*\|" "$features_file" | grep -qi "shipped"; then
                    is_shipped=true
                fi
            fi

            if [ "$feature_found" = true ] && [ "$is_shipped" = false ]; then
                echo ""
                echo -e "${YELLOW}Note: $feature_id not marked as 'shipped' in FEATURES.md${NC}"
                echo "  To update: bash .agentic/tools/feature.sh $feature_id status shipped"
            fi
        fi

        # Remind about STATUS.md
        echo ""
        if [ -f "$ROOT_DIR/STATUS.md" ]; then
            if ! grep -q "$feature_id" "$ROOT_DIR/STATUS.md" 2>/dev/null; then
                echo -e "${YELLOW}Note: $feature_id not mentioned in STATUS.md${NC}"
                echo "  Consider updating STATUS.md to reflect completion"
            fi
        fi
    fi

    # Show definition of done checklist
    echo ""
    echo -e "${BOLD}Definition of Done Checklist:${NC}"
    echo "  [ ] All acceptance criteria met"
    echo "  [ ] Tests written and passing"
    echo "  [ ] spec/FEATURES.md updated (status: shipped)"
    echo "  [ ] Docs updated (if behavior changed)"
    echo "  [ ] Code reviewed (self-review at minimum)"
    echo "  [ ] Smoke tested (actually RUN it)"
    echo "  [ ] JOURNAL.md updated"
    echo ""
    echo "Full checklist: .agentic/checklists/feature_complete.md"

    # Check if WIP is complete
    if [ -f "$ROOT_DIR/.agentic-state/WIP.md" ]; then
        echo ""
        echo -e "${YELLOW}Note: WIP tracking still active. Complete it with:${NC}"
        echo "  bash .agentic/tools/wip.sh complete"
    fi

    # Suggest drift detection
    echo ""
    echo -e "${BLUE}Recommended: Run drift detection${NC}"
    echo "  bash .agentic/tools/drift.sh"
    echo "  (Checks: untracked files, feature status, template markers)"
}

# Tools command - list all tools
cmd_tools() {
    bash "$SCRIPT_DIR/list-tools.sh" 2>/dev/null || {
        echo -e "${BOLD}=== Available Tools ===${NC}"
        echo ""
        echo "Tools in .agentic/tools/:"
        echo ""
        ls -1 "$SCRIPT_DIR"/*.sh 2>/dev/null | xargs -I{} basename {} | sort | while read -r tool; do
            printf "  %-25s\n" "$tool"
        done
        echo ""
        echo "Run tool with: bash .agentic/tools/<tool>.sh"
    }
}

# Docs command - doc lifecycle system
cmd_docs() {
    local arg1="${1:-}"
    local arg2="${2:-}"

    # Resolve feature ID: explicit arg, or from WIP
    local feature_id=""
    if [[ "$arg1" =~ ^F-[0-9]{4}$ ]]; then
        feature_id="$arg1"
        shift 2>/dev/null || true
        arg1="${1:-}"
    elif [[ -f "$ROOT_DIR/.agentic-state/WIP.md" ]]; then
        feature_id=$(grep -oE 'F-[0-9]{4}' "$ROOT_DIR/.agentic-state/WIP.md" 2>/dev/null | head -1 || true)
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
            echo "Usage: ag docs [F-####] [--list|--check|--pr]"
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
    local full="${1:-}"

    if [ "$full" = "--full" ]; then
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
    if [ -f "$ROOT_DIR/spec/FEATURES.md" ] && grep -q '<!-- PROPOSAL' "$ROOT_DIR/spec/FEATURES.md" 2>/dev/null; then
        proposal_files+=("spec/FEATURES.md")
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
    rm -f "$ROOT_DIR/.agentic-state/discovery_report.json" 2>/dev/null || true
    rm -rf "$ROOT_DIR/.agentic-state/proposals" 2>/dev/null || true
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

    # WIP status
    if [ -f "$ROOT_DIR/.agentic-state/WIP.md" ]; then
        echo -e "${YELLOW}Active WIP:${NC}"
        head -10 "$ROOT_DIR/.agentic-state/WIP.md" 2>/dev/null | grep -E "^(Feature|Task|Started|Last):" || true
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
            F-[0-9][0-9][0-9][0-9])
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
    local acc_file="$ROOT_DIR/spec/acceptance/${feature_id}.md"
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

# Specs command - systematic brownfield spec generation
cmd_specs() {
    local arg="${1:-}"

    # Check feature tracking and spec directory
    local ft sd
    ft=$(get_setting "feature_tracking" "no")
    sd=$(get_setting "spec_directory" "no")
    if [ "$ft" = "no" ] || [ "$sd" = "no" ]; then
        echo -e "${RED}Error: ag specs requires feature_tracking and spec_directory${NC}"
        echo "Enable with: ag set feature_tracking yes && ag set spec_directory yes"
        exit 1
    fi

    # Check for discovery report
    local report="$ROOT_DIR/.agentic-state/discovery_report.json"
    if [ ! -f "$report" ]; then
        echo -e "${YELLOW}No discovery report found.${NC}"
        echo "Run discovery first:"
        echo "  python3 .agentic/tools/discover.py --root . --output .agentic-state/discovery_report.json --profile formal"
        echo ""
        echo "Or run: ag init (for full initialization)"
        exit 1
    fi

    # --status flag: show domain progress
    if [ "$arg" = "--status" ]; then
        _specs_status
        return 0
    fi

    echo -e "${BOLD}=== Brownfield Spec Generation ===${NC}"
    echo ""

    # Check for existing brownfield plan
    local plan_file=""
    for f in "$ROOT_DIR"/.agentic-journal/plans/*-specs-plan.md; do
        if [ -f "$f" ]; then
            plan_file="$f"
            break
        fi
    done

    if [ -n "$plan_file" ]; then
        local status
        status=$(grep -E "^\*\*Status\*\*:" "$plan_file" 2>/dev/null | head -1 | sed 's/.*Status\*\*:[[:space:]]*//' || echo "UNKNOWN")
        local total completed
        total=$(grep -cE "^- \[.\]" "$plan_file" 2>/dev/null || echo "0")
        completed=$(grep -cE "^- \[x\]" "$plan_file" 2>/dev/null || echo "0")

        echo -e "${BOLD}Existing plan found:${NC} $(basename "$plan_file")"
        echo "  Status: $status"
        echo "  Progress: $completed/$total domains completed"
        echo ""

        if [ "$status" = "APPROVED" ] && [ "$completed" -lt "$total" ]; then
            echo -e "${GREEN}Plan is APPROVED with uncompleted domains.${NC}"
            echo ""
            echo -e "${BOLD}AGENT INSTRUCTION:${NC} Resume brownfield spec generation."
            echo "  1. Read plan: $plan_file"
            echo "  2. Read discovery report: $report"
            echo "  3. Find next uncompleted domain (first '- [ ]' checkbox)"
            echo "  4. For that domain:"
            echo "     a. Read key source files (1-2 per cluster, max ~10)"
            echo "     b. Generate features with '- Domain:' metadata"
            echo "     c. Generate Given/When/Then acceptance criteria"
            echo "     d. Write FEATURES.md entries + spec/acceptance/F-####.md files"
            echo "     e. Ask user: 'Does this look right for [Domain]?'"
            echo "     f. Mark domain as completed: change '- [ ]' to '- [x]' in plan"
            echo "  5. After all domains: cross-domain review (duplicates, gaps)"
            echo ""
            echo "Pipeline details: .agentic/agents/shared/auto_orchestration.md"
        elif [ "$status" = "DRAFT" ] || [ "$status" = "REVIEWING" ] || [ "$status" = "REVISION_NEEDED" ]; then
            echo -e "${YELLOW}Plan needs review.${NC}"
            echo "  Continue the plan-review loop:"
            echo "  1. Read plan: $plan_file"
            echo "  2. If DRAFT/REVISION_NEEDED: revise the plan"
            echo "  3. Submit for review (set Status to REVIEWING)"
            echo "  4. Review and approve or request revisions"
        else
            echo "Plan status: $status ($completed/$total completed)"
            echo "  Plan file: $plan_file"
        fi
        return 0
    fi

    # No existing plan — print plan creation instructions
    echo -e "${YELLOW}No brownfield spec plan found.${NC}"
    echo ""

    # Show domain summary from discovery report
    local domain_count
    domain_count=$(python3 -c "
import json
report = json.load(open('$report'))
domains = report.get('domains', [])
print(len(domains))
for d in domains:
    est = d.get('estimated_features', 0)
    clusters = len(d.get('clusters', []))
    print(f\"  {d['name']} (type: {d['type']}, ~{est} features, {clusters} clusters)\")
" 2>/dev/null || echo "0")

    echo -e "${BOLD}Domains from discovery:${NC}"
    echo "$domain_count"
    echo ""

    echo -e "${BOLD}AGENT INSTRUCTION:${NC} Create a brownfield spec generation plan."
    echo ""
    echo "  1. Read discovery report: $report"
    echo "  2. Create plan at: .agentic-journal/plans/brownfield-specs-plan.md"
    echo "     Format:"
    echo "       # Brownfield Spec Generation Plan"
    echo "       **Status**: DRAFT"
    echo "       **Created**: $(date +%Y-%m-%d)"
    echo "       ## Domains"
    echo "       - [ ] Domain1 (type: frontend, ~N features)"
    echo "       - [ ] Domain2 (type: backend, ~N features)"
    echo "       ## Approach"
    echo "       - Work domains in priority order"
    echo "  3. Use the plan-review loop to validate"
    echo "  4. After APPROVED: run 'ag specs' again to begin execution"
    echo ""
    echo "Pipeline details: .agentic/agents/shared/auto_orchestration.md"

    # Token cost suggestion
    local feature_count
    feature_count=$(python3 -c "
import json
report = json.load(open('$report'))
total = sum(d.get('estimated_features', 0) for d in report.get('domains', []))
print(total)
" 2>/dev/null || echo "0")
    if [ "$feature_count" -gt 50 ]; then
        echo ""
        echo -e "${YELLOW}Token cost note: Estimated $feature_count features.${NC}"
        echo "  After generation, consider splitting FEATURES.md:"
        echo "  python3 .agentic/tools/organize_features.py --by domain"
    fi
}

_specs_status() {
    echo -e "${BOLD}=== Brownfield Spec Status ===${NC}"
    echo ""

    local plan_file=""
    for f in "$ROOT_DIR"/.agentic-journal/plans/*-specs-plan.md; do
        if [ -f "$f" ]; then
            plan_file="$f"
            break
        fi
    done

    if [ -z "$plan_file" ]; then
        echo "No brownfield spec plan found."
        echo "Start with: ag specs"
        return 0
    fi

    local status
    status=$(grep -E "^\*\*Status\*\*:" "$plan_file" 2>/dev/null | head -1 | sed 's/.*Status\*\*:[[:space:]]*//' || echo "UNKNOWN")
    local total completed
    total=$(grep -cE "^- \[.\]" "$plan_file" 2>/dev/null || echo "0")
    completed=$(grep -cE "^- \[x\]" "$plan_file" 2>/dev/null || echo "0")

    echo "Plan: $(basename "$plan_file")"
    echo "Status: $status"
    echo "Progress: $completed/$total domains completed"
    echo ""

    # Show domain checklist
    echo "Domains:"
    grep -E "^- \[.\]" "$plan_file" 2>/dev/null || echo "  (no domains listed)"
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
            if [[ ! "$value" =~ ^(discovery|formal)$ ]]; then
                echo -e "${RED}Error: profile must be 'discovery' or 'formal', got '$value'${NC}"
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
        presets_file="$ROOT_DIR/.agentic/presets/profiles.conf"
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
    specs)
        cmd_specs "${2:-}"
        ;;
    todo)
        shift
        cmd_todo "$@"
        ;;
    commit)
        cmd_commit
        ;;
    done)
        cmd_done "${2:-}"
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
    tools)
        cmd_tools
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
