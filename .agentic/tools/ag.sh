#!/usr/bin/env bash
# ag.sh - Agentic Framework Gateway
# Single entry point for all framework operations
# Works with any AI agent (Claude Code, Cursor, Codex, Copilot)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors (disabled if not TTY)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' BOLD='' NC=''
fi

# Detect profile from STACK.md or directory structure
get_profile() {
    local stack_file="$ROOT_DIR/STACK.md"
    if [ -f "$stack_file" ]; then
        local profile
        profile=$(grep -i "Profile:" "$stack_file" 2>/dev/null | head -1 | sed 's/.*Profile:[[:space:]]*//' | tr -d ' ')
        if [ "$profile" = "core" ] || [ "$profile" = "core+product" ]; then
            echo "$profile"
            return
        fi
    fi
    # Infer from directory structure
    if [ -d "$ROOT_DIR/spec" ]; then
        echo "core+product"
    else
        echo "core"
    fi
}

PROFILE=$(get_profile)

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
        if grep -q "Describe the current project phase" "$ROOT_DIR/STATUS.md" 2>/dev/null; then
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
    if grep -q "Describe the current project phase" "$ROOT_DIR/STATUS.md" 2>/dev/null; then
        echo "  • STATUS.md: Current focus and project phase"
    fi

    echo ""
    echo -e "${BOLD}To initialize:${NC}"
    echo "  Run: ag init"
    echo "  Or ask your AI agent: \"Let's initialize this project\""
    echo ""
    echo -e "${BOLD}The init interview will:${NC}"
    echo "  1. Choose profile (Core vs Core+PM)"
    echo "  2. Define tech stack and project goals"
    echo "  3. Set up AI tool integrations"
    echo "  4. Configure quality gates"
    echo ""
    echo -e "See: ${BLUE}.agentic/init/init_playbook.md${NC} for full details"
    echo ""
}

show_help() {
    if [ "$PROFILE" = "core" ]; then
        cat << 'EOF'
ag - Agentic Framework Gateway (Core Profile)

USAGE:
    ag <command> [options]

COMMANDS:
    start               Session start checks + context summary
    init                Run project initialization interview
    work "description"  Start WIP tracking for a task
    commit              Run all pre-commit gates
    done                Task complete validation
    trace [options]     Spec-code traceability (drift + coverage)
    tools               List all available tools by category
    verify [--full]     Run doctor verification
    status              Show current project status
    help                Show this help

EXAMPLES:
    ag start                    # Begin a new session
    ag init                     # Initialize project (if not done)
    ag work "Add login form"    # Start working on a task
    ag commit                   # Verify ready to commit
    ag done                     # Check task completion
    ag trace                    # Full drift + coverage report
    ag trace --gaps             # Show only gaps
    ag tools                    # Discover available tools

Core profile: No formal feature tracking. Use STATUS.md for focus.
EOF
    else
        cat << 'EOF'
ag - Agentic Framework Gateway (Core+PM Profile)

USAGE:
    ag <command> [options]

COMMANDS:
    start               Session start checks + context summary
    init                Run project initialization interview
    implement F-XXXX    Verify acceptance exists, start WIP tracking
    commit              Run all pre-commit gates
    done [F-XXXX]       Feature complete validation
    trace [options]     Spec-code traceability (drift + coverage)
    tools               List all available tools by category
    verify [--full]     Run doctor verification
    status              Show current project status
    help                Show this help

EXAMPLES:
    ag start                    # Begin a new session
    ag init                     # Initialize project (if not done)
    ag implement F-0042         # Start working on feature F-0042
    ag commit                   # Verify ready to commit
    ag done F-0042              # Check feature completion
    ag trace                    # Full drift + coverage report
    ag trace F-0042             # What files implement F-0042?
    ag trace src/auth.py        # What features does auth.py implement?
    ag trace --gaps             # Show only gaps (missing implementations)
    ag trace --json             # Machine-readable combined output
    ag tools                    # Discover available tools
    ag verify --full            # Full verification

Core+PM profile: Formal feature tracking with acceptance criteria.
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
        blocker_count=$(grep -c "^## HN-" "$ROOT_DIR/HUMAN_NEEDED.md" 2>/dev/null || echo "0")
        if [ "$blocker_count" -gt 0 ]; then
            echo -e "${YELLOW}Blockers: $blocker_count item(s) need human input${NC}"
        fi
    fi

    # 6. Run doctor quick check
    echo ""
    echo -e "${BOLD}Quick Health Check:${NC}"
    bash "$SCRIPT_DIR/doctor.sh" --quick 2>/dev/null | head -20 || echo "  (doctor.sh not available)"

    echo ""
    if [ "$PROFILE" = "core" ]; then
        echo -e "${BOLD}Ready to work. Run 'ag work \"description\"' to start a task.${NC}"
    else
        echo -e "${BOLD}Ready to work. Run 'ag implement F-XXXX' to start a feature.${NC}"
    fi
}

# Work command (Core profile) - start WIP tracking without feature ID
cmd_work() {
    local description="${1:-}"

    if [ -z "$description" ]; then
        echo -e "${RED}Error: Task description required${NC}"
        echo "Usage: ag work \"Add login form\""
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
}

# Implement command - verify acceptance exists, start WIP (Core+PM only)
cmd_implement() {
    local feature_id="${1:-}"

    # Check profile
    if [ "$PROFILE" = "core" ]; then
        echo -e "${YELLOW}Core profile detected - no feature IDs.${NC}"
        echo "Use: ag work \"description\" instead"
        echo "Or switch to Core+PM profile for formal feature tracking."
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

    # 1. Check acceptance criteria exist
    local acc_file="$ROOT_DIR/spec/acceptance/${feature_id}.md"
    if [ ! -f "$acc_file" ]; then
        echo -e "${RED}BLOCKED: No acceptance criteria${NC}"
        echo "  Missing: spec/acceptance/${feature_id}.md"
        echo ""
        echo "Create acceptance criteria FIRST, then run this command again."
        echo "Template: .agentic/spec/acceptance.template.md"
        exit 1
    fi

    echo -e "${GREEN}Acceptance criteria: EXISTS${NC}"

    # 2. Check if feature is in FEATURES.md
    local features_file="$ROOT_DIR/spec/FEATURES.md"
    if [ -f "$features_file" ]; then
        if grep -q "^## ${feature_id}:" "$features_file"; then
            echo -e "${GREEN}Feature registered: YES${NC}"
            # Show feature name
            grep "^## ${feature_id}:" "$features_file" | head -1
        else
            echo -e "${YELLOW}Feature not in FEATURES.md - add it first${NC}"
        fi
    fi

    # 3. Run planning phase check
    echo ""
    echo "Running phase check..."
    bash "$SCRIPT_DIR/doctor.sh" --phase planning "$feature_id" 2>/dev/null || true

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
}

# Commit command - pre-commit gates (profile-aware)
cmd_commit() {
    echo -e "${BOLD}=== Pre-Commit Gates ($PROFILE) ===${NC}"
    echo ""

    # 1. Check WIP exists
    if [ -f "$ROOT_DIR/.agentic-state/WIP.md" ]; then
        if [ "$PROFILE" = "core" ]; then
            # Core mode: WIP is a warning, not a blocker (exploratory work)
            echo -e "${YELLOW}WARNING: .agentic-state/WIP.md exists${NC}"
            echo "  Consider completing WIP: bash .agentic/tools/wip.sh complete"
            echo ""
        else
            # Core+PM mode: WIP is a blocker (formal tracking)
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

    # 3. Run doctor pre-commit checks (Core mode is more lenient)
    echo ""
    if [ "$PROFILE" = "core" ]; then
        echo "Running basic checks (Core mode - lighter gates)..."
        # Core mode: just check for basic issues, don't block on spec stuff
        bash "$SCRIPT_DIR/doctor.sh" --quick 2>/dev/null || true
        echo ""
        echo -e "${GREEN}Core mode: Ready to commit${NC}"
        echo "  git add <files>"
        echo "  git commit -m \"description\""
    else
        echo "Running pre-commit verification..."
        if bash "$SCRIPT_DIR/doctor.sh" --pre-commit 2>/dev/null; then
            echo ""
            echo -e "${GREEN}All pre-commit gates PASSED${NC}"
            echo ""
            echo "Ready to commit. Suggested workflow:"
            echo "  git add <files>"
            echo "  git commit -m \"feat(F-XXXX): description\""
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

    if [ "$PROFILE" = "core" ]; then
        echo -e "${BOLD}=== Task Complete Check ===${NC}"
        echo ""
        echo -e "${BOLD}Definition of Done (Core):${NC}"
        echo "  [ ] Task completed as described"
        echo "  [ ] Tests written and passing (if applicable)"
        echo "  [ ] STATUS.md updated"
        echo "  [ ] JOURNAL.md updated"
        echo ""
        # Check if WIP is complete
        if [ -f "$ROOT_DIR/.agentic-state/WIP.md" ]; then
            echo -e "${YELLOW}Note: WIP tracking still active. Complete it with:${NC}"
            echo "  bash .agentic/tools/wip.sh complete"
        fi
        return
    fi

    # Generate manifest for feature (Core+PM profile)
    if [ -n "$feature_id" ] && echo "$feature_id" | grep -qE '^F-[0-9]{4}$'; then
        echo -e "${BOLD}=== Generating Change Manifest ===${NC}"
        if bash "$SCRIPT_DIR/manifest.sh" "$feature_id" 2>/dev/null; then
            local manifest_file="$ROOT_DIR/.agentic-state/manifests/${feature_id}.manifest.md"
            if [ -f "$manifest_file" ]; then
                # Extract stats for journal metadata
                local commit_count file_count
                commit_count=$(grep -c "^|" "$manifest_file" 2>/dev/null | head -1 || echo "0")
                commit_count=$((commit_count - 2))  # Subtract header rows
                file_count=$(grep -c "^\- \`" "$manifest_file" 2>/dev/null || echo "0")
                echo -e "${GREEN}Manifest generated: .agentic-state/manifests/${feature_id}.manifest.md${NC}"
                echo "  Commits: $commit_count, Files: $file_count"
            fi
        else
            echo -e "${YELLOW}Could not generate manifest (no matching commits?)${NC}"
        fi
        echo ""
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
        bash "$SCRIPT_DIR/doctor.sh" --phase complete "$feature_id" 2>/dev/null || true

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
        fi

        # Auto-update FEATURES.md status to shipped if using table format
        local features_file="$ROOT_DIR/spec/FEATURES.md"
        if [ -f "$features_file" ]; then
            if grep -qE "^\|[[:space:]]*${feature_id}[[:space:]]*\|" "$features_file"; then
                # Table format detected - check if not already shipped
                if ! grep -E "^\|[[:space:]]*${feature_id}[[:space:]]*\|" "$features_file" | grep -qi "shipped"; then
                    echo ""
                    echo -e "${YELLOW}Note: $feature_id not marked as 'shipped' in FEATURES.md (table format)${NC}"
                    echo "  To update: bash .agentic/tools/feature.sh $feature_id status shipped"
                fi
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

# Verify command - doctor checks
cmd_verify() {
    local full="${1:-}"

    if [ "$full" = "--full" ]; then
        bash "$SCRIPT_DIR/doctor.sh" --full
    else
        bash "$SCRIPT_DIR/doctor.sh"
    fi
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
    echo "  1. Choose profile: Core (lightweight) or Core+PM (formal specs)"
    echo "  2. Set up AI tools: Claude, Cursor, Copilot, Codex"
    echo "  3. Define project: Tech stack, languages, frameworks"
    echo "  4. Configure quality: Testing approach, quality gates"
    echo "  5. Document architecture: Entry points, data flow"
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
    echo "  • Create any needed spec files (Core+PM)"
    echo ""
    echo -e "Init playbook: ${BLUE}.agentic/init/init_playbook.md${NC}"
    echo -e "Init questions: ${BLUE}.agentic/init/init_questions.md${NC}"
}

cmd_status() {
    echo -e "${BOLD}=== Project Status ===${NC}"
    echo "Profile: $PROFILE"
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
    implement)
        cmd_implement "${2:-}"
        ;;
    commit)
        cmd_commit
        ;;
    done)
        cmd_done "${2:-}"
        ;;
    trace)
        shift
        cmd_trace "$@"
        ;;
    tools)
        cmd_tools
        ;;
    verify)
        cmd_verify "${2:-}"
        ;;
    status)
        cmd_status
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
