#!/usr/bin/env bash
# commands/start.sh — Session start command
# Sourced by ag.sh — do NOT execute directly.
# Depends on: SCRIPT_DIR, ROOT_DIR, PROFILE, color codes, paths.sh, settings.sh

cmd_start() {
    # 0. Check for uninitialized framework (CRITICAL - check first!)
    if ! check_initialization; then
        show_init_warning
        echo -e "${YELLOW}Continuing with session start, but initialization is recommended.${NC}"
        echo ""
    fi

    echo -e "${BOLD}=== Session Start ===${NC}"
    echo ""

    # 1. Check for other active agents (AGENTS.json — all entries, not just this worktree)
    local _all_agents
    _all_agents=$(_agents_py list 2>/dev/null || true)
    if echo "$_all_agents" | grep -q '\[active\]\|\[created\]'; then
        echo -e "${YELLOW}Active agent(s) detected:${NC}"
        echo "$_all_agents"
        echo ""
    fi

    # 2. Check for WIP (interrupted work) — this worktree only
    if _has_active_wip; then
        echo -e "${YELLOW}WIP detected - previous work was interrupted${NC}"
        bash "$SCRIPT_DIR/wip.sh" check 2>/dev/null || true
        echo ""
    elif [ -f "$ROOT_DIR/.agentic/session/WIP.md" ]; then
        echo -e "${YELLOW}WIP detected (legacy WIP.md) - previous work was interrupted${NC}"
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
    if [ -f "$HUMAN_NEEDED_FILE" ]; then
        local blocker_count
        blocker_count=$(awk '/^## Active items/,/^---$/' "$HUMAN_NEEDED_FILE" 2>/dev/null | grep -c "^### HN-" || true)
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

    # 5c. Backlog display (PROMINENT) — single python3 call for performance
    local bl_display
    bl_display=$(python3 "$SCRIPT_DIR/backlog_helpers.py" --project-root "$ROOT_DIR" json-all 2>/dev/null) || true
    if [ -n "$bl_display" ] && [ "$bl_display" != "[]" ]; then
        # Parse all fields in one python3 invocation
        local bl_formatted
        bl_formatted=$(echo "$bl_display" | python3 -c "
import sys, json
from datetime import datetime, timezone
items = json.load(sys.stdin)
if not items:
    sys.exit(1)
c = items[0]
cid = c.get('id', c.get('description', ''))
desc = c.get('description', '')
if desc and desc != cid:
    print(f'ID={cid}')
    print(f'DESC={desc}')
else:
    print(f'ID={cid}')
    print('DESC=')
print(f'NOTES={c.get(\"notes\", \"\")}')
for r in c.get('refs', []):
    print(f'REF={r}')
if len(items) > 1:
    n = items[1]
    nid = n.get('id', n.get('description', ''))
    ndesc = n.get('description', '')
    if ndesc and ndesc != nid:
        print(f'NEXT={nid} — {ndesc}')
    else:
        print(f'NEXT={nid}')
print(f'TOTAL={len(items)}')
# Staleness check
became = c.get('became_current_at', '')
if became:
    try:
        dt = datetime.fromisoformat(became.replace('Z', '+00:00'))
        age = (datetime.now(timezone.utc) - dt).days
        if age >= 7:
            print(f'STALE={age}')
    except (ValueError, TypeError):
        pass
" 2>/dev/null) || true

        if [ -n "$bl_formatted" ]; then
            echo ""
            echo -e "${BOLD}═══════════════════════════════════════${NC}"

            local bl_id="" bl_desc="" bl_notes="" bl_total=""
            while IFS= read -r line; do
                case "$line" in
                    ID=*)    bl_id="${line#ID=}" ;;
                    DESC=*)  bl_desc="${line#DESC=}" ;;
                    NOTES=*) bl_notes="${line#NOTES=}" ;;
                    REF=*)   echo -e "  ${DIM}REF:    ${line#REF=}${NC}" ;;
                    NEXT=*)  echo -e "  ${DIM}NEXT:    ${line#NEXT=}${NC}" ;;
                    TOTAL=*) bl_total="${line#TOTAL=}" ;;
                    STALE=*) ;; # handled below
                esac
                # Print CURRENT/NOTES before REFs (order matters)
                if [[ "$line" == "NOTES="* ]]; then
                    if [ -n "$bl_id" ]; then
                        if [ -n "$bl_desc" ]; then
                            echo -e "  ${BOLD}CURRENT: $bl_id — $bl_desc${NC}"
                        else
                            echo -e "  ${BOLD}CURRENT: $bl_id${NC}"
                        fi
                    fi
                    if [ -n "$bl_notes" ]; then
                        echo -e "  ${DIM}NOTE:    $bl_notes${NC}"
                    fi
                fi
            done <<< "$bl_formatted"

            if [ -n "$bl_total" ]; then
                echo -e "  ${DIM}Queue:   $bl_total item(s) total${NC}"
            fi
            if is_feature_id "$bl_id" 2>/dev/null; then
                echo -e "  ${DIM}Resume:  ag implement $bl_id${NC}"
            fi
            echo -e "${BOLD}═══════════════════════════════════════${NC}"

            # Staleness warning (from same parsed output)
            local stale_days
            stale_days=$(echo "$bl_formatted" | grep '^STALE=' | head -1 | cut -d= -f2)
            if [ -n "$stale_days" ]; then
                echo -e "${YELLOW}WARNING: Current backlog item has been active for $stale_days days ($bl_id)${NC}"
                echo "  Still relevant? Or: ag backlog done | ag backlog clear"
            fi
        fi
    fi

    # 5d. Completion gate advisory
    if [ -n "$bl_id" ] && is_feature_id "$bl_id" 2>/dev/null; then
        local cg_out
        cg_out=$(python3 "$SCRIPT_DIR/backlog_helpers.py" --project-root "$ROOT_DIR" check-completion-gate "$bl_id" 2>/dev/null) || cg_out=""
        if [ -n "$cg_out" ]; then
            local stale_fid
            stale_fid=$(echo "$cg_out" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('stale_feature','') if d.get('blocked') else '')" 2>/dev/null) || stale_fid=""
            if [ -n "$stale_fid" ]; then
                echo -e "${YELLOW}WARNING: $stale_fid has merged code on main but isn't marked shipped${NC}"
                echo "  Complete it first: ag done $stale_fid"
            fi
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
