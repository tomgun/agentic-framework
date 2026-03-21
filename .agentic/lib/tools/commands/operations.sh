#!/usr/bin/env bash
# commands/operations.sh — Remaining command functions (work, merge, docs, hooks, etc.)
# Sourced by ag.sh — do NOT execute directly.
# Depends on: SCRIPT_DIR, ROOT_DIR, PROFILE, color codes, paths.sh, settings.sh

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
    # Gate: git must be active (F-0250)
    local git_mode
    git_mode=$(get_setting "git_mode" "active")
    if [[ "$git_mode" != "active" ]]; then
        echo -e "${YELLOW}Git not active (git_mode: ${git_mode}).${NC}"
        echo "  Run: ag git-init    to enable version control"
        echo ""
        return 0
    fi

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


# Hooks command - manage git and Claude Code hook configuration
cmd_hooks() {
    local subcmd="${1:-}"
    local flag="${2:-}"

    case "$subcmd" in
        install)
            # Install both git hooks and Claude Code hooks (F-0300)
            local installed_any=false

            # Git hooks (if git is available)
            if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
                git config core.hooksPath .agentic/hooks
                echo -e "${GREEN}✓ Git hooks: core.hooksPath set to .agentic/hooks${NC}"
                installed_any=true
            else
                echo -e "${YELLOW}⚠ Git hooks: skipped (not a git repository)${NC}"
            fi

            # Claude Code hooks
            local hooks_source="$ROOT_DIR/.agentic/lib/claude-hooks/hooks.json"
            local hooks_target="$ROOT_DIR/.claude/hooks.json"
            if [[ -f "$hooks_source" ]]; then
                mkdir -p "$ROOT_DIR/.claude"
                cp "$hooks_source" "$hooks_target"
                echo -e "${GREEN}✓ Claude hooks: installed (.claude/hooks.json)${NC}"
                echo -e "${YELLOW}  ⚠ Restart Claude Code to activate hooks.${NC}"
                installed_any=true
            else
                echo -e "${YELLOW}⚠ Claude hooks: source not found (.agentic/lib/claude-hooks/hooks.json)${NC}"
            fi

            if [[ "$installed_any" == "false" ]]; then
                echo -e "${RED}✗ No hooks installed${NC}"
                exit 1
            fi
            ;;
        status)
            echo "Hook Status"
            echo "━━━━━━━━━━━"

            # Git hooks
            echo ""
            echo "Git hooks (pre-commit):"
            if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
                local hooks_path
                hooks_path=$(git config core.hooksPath 2>/dev/null || echo "")
                if [ "$hooks_path" = ".agentic/hooks" ]; then
                    echo -e "  ${GREEN}✓ INSTALLED${NC}: core.hooksPath = .agentic/hooks"
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
                    echo -e "  ${YELLOW}⚠ CUSTOM${NC}: core.hooksPath = $hooks_path"
                else
                    echo -e "  ${RED}✗ NOT INSTALLED${NC}: core.hooksPath not configured"
                fi
            else
                echo -e "  ${YELLOW}⚠ N/A${NC} (not a git repository — git_mode may be deferred)"
            fi

            # Claude Code hooks (F-0300)
            echo ""
            echo "Claude Code hooks (enforcement):"
            local claude_hooks="$ROOT_DIR/.claude/hooks.json"
            local hooks_source="$ROOT_DIR/.agentic/lib/claude-hooks/hooks.json"
            if [[ -f "$claude_hooks" ]]; then
                echo -e "  ${GREEN}✓ INSTALLED${NC}: .claude/hooks.json"
                # List registered hook events
                if command -v python3 >/dev/null 2>&1; then
                    python3 -c "
import json, os
with open('$claude_hooks') as f:
    data = json.load(f)
for event, entries in sorted(data.get('hooks', {}).items()):
    scripts = []
    for entry in entries:
        for hook in entry.get('hooks', []):
            cmd = hook.get('command', '')
            script = cmd.replace('\${CLAUDE_PROJECT_DIR}', '$ROOT_DIR')
            exists = os.path.isfile(script)
            marker = '✓' if exists else '✗'
            scripts.append(f'{marker} {event}')
    for s in scripts:
        print(f'    {s}')
" 2>/dev/null || echo "    (could not parse hooks.json)"
                fi
            elif [[ -f "$hooks_source" ]]; then
                echo -e "  ${RED}✗ NOT INSTALLED${NC}: .claude/hooks.json missing"
                echo "  Source exists at .agentic/lib/claude-hooks/hooks.json"
                echo "  Run: ag hooks install"
            else
                echo -e "  ${YELLOW}⚠ N/A${NC}: no hook source found"
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
            echo "  install             Install git hooks + Claude Code hooks"
            echo "  status              Show current hook configuration (git + Claude)"
            echo "  disable --confirm   Remove core.hooksPath (disables git quality gates)"
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

