#!/usr/bin/env bash
# commands/implement.sh — Feature implementation gate checks
# Sourced by ag.sh — do NOT execute directly.
# Depends on: SCRIPT_DIR, ROOT_DIR, PROFILE, color codes, paths.sh, settings.sh

cmd_implement() {
    # Parse flags from any position (--skip-clarity/--force can come before or after F-XXXX)
    local skip_clarity="${SKIP_CLARITY:-0}"
    local force=0
    local feature_id=""
    local arg
    for arg in "$@"; do
        case "$arg" in
            --skip-clarity) skip_clarity=1 ;;
            --force) force=1 ;;
            *) [[ -z "$feature_id" ]] && feature_id="$arg" ;;
        esac
    done

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
    if ! is_feature_id "$feature_id"; then
        echo -e "${RED}Error: Invalid feature ID format. Expected: F-XXXX (e.g., F-0042)${NC}"
        exit 1
    fi

    echo -e "${BOLD}=== Implement: $feature_id ===${NC}"
    echo ""

    # 0a. Check: one feature at a time (WIP conflict detection via AGENTS.json)
    local current_wip
    current_wip=$(_get_wip_feature)
    if [ -n "$current_wip" ] && [ "$current_wip" != "$feature_id" ]; then
        echo -e "${RED}BLOCKED: $current_wip is already in progress${NC}"
        echo "  Complete it first: ag done $current_wip"
        echo "  Or clear WIP: bash .agentic/lib/tools/wip.sh complete"
        exit 1
    fi

    # 0b. Backlog gate
    if [ "${SKIP_BACKLOG:-}" = "1" ]; then
        echo -e "${YELLOW}SKIP_BACKLOG: Bypassing backlog gate${NC}" >&2
    else
        # Check if feature is shipped/deprecated (lifecycle cross-check)
        if [ -f "$ROOT_DIR/.agentic/spec/FEATURES.md" ]; then
            local feat_status_line
            feat_status_line=$(grep -A2 "^## ${feature_id}:" "$ROOT_DIR/.agentic/spec/FEATURES.md" 2>/dev/null | grep -i "status" | head -1 || true)
            if echo "$feat_status_line" | grep -qi "shipped\|deprecated"; then
                echo -e "${RED}BLOCKED: $feature_id lifecycle state is shipped/deprecated${NC}"
                echo "  Cannot implement a feature that's already shipped."
                echo "  Override: SKIP_BACKLOG=1 ag implement $feature_id"
                exit 1
            fi
        fi

        # Auto-upsert into backlog (add at position 0 if not present)
        local bl_position
        bl_position=$(python3 "$SCRIPT_DIR/backlog_helpers.py" --project-root "$ROOT_DIR" upsert "$feature_id" 2>/dev/null) || bl_position=""

        if [ -n "$bl_position" ] && [ "$bl_position" != "0" ]; then
            # Feature is in backlog but NOT at position 0 — HARD BLOCK
            local bl_current_id
            bl_current_id=$(python3 "$SCRIPT_DIR/backlog_helpers.py" --project-root "$ROOT_DIR" json-current 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null) || bl_current_id="unknown"
            echo -e "${RED}BLOCKED: Backlog says current work is $bl_current_id.${NC}"
            echo "  Work on it:   ag implement $bl_current_id"
            echo "  Reprioritize: ag backlog move $feature_id 0"
            echo "  Override:     SKIP_BACKLOG=1 ag implement $feature_id"
            exit 1
        fi

        # Check dependencies (advisory warning)
        local dep_check
        dep_check=$(python3 "$SCRIPT_DIR/backlog_helpers.py" --project-root "$ROOT_DIR" check-deps "$feature_id" 2>/dev/null) || true
        if [ -n "$dep_check" ]; then
            echo -e "${YELLOW}WARNING: $feature_id has unmet dependencies:${NC}"
            echo "$dep_check" | while read -r line; do
                echo "  $line"
            done
            echo ""
        fi
    fi

    # 0b2. Completion gate: check if prior backlog items have merged code but aren't shipped
    if [ "${SKIP_BACKLOG:-}" != "1" ]; then
        local cg_out
        cg_out=$(python3 "$SCRIPT_DIR/backlog_helpers.py" --project-root "$ROOT_DIR" check-completion-gate "$feature_id" 2>/dev/null) || cg_out=""
        if [ -n "$cg_out" ]; then
            local cg_blocked cg_stale
            cg_blocked=$(echo "$cg_out" | python3 -c "import json,sys; print(json.load(sys.stdin).get('blocked',False))" 2>/dev/null) || cg_blocked="False"
            if [ "$cg_blocked" = "True" ]; then
                cg_stale=$(echo "$cg_out" | python3 -c "import json,sys; print(json.load(sys.stdin).get('stale_feature',''))" 2>/dev/null) || cg_stale="unknown"
                if [ "$force" = "1" ]; then
                    echo -e "${YELLOW}WARNING: $cg_stale has merged code on main but is still marked 'planned'${NC}"
                    echo "  Consider running: ag done $cg_stale"
                    echo ""
                else
                    echo -e "${RED}BLOCKED: $cg_stale has merged code on main but is still marked 'planned'${NC}"
                    echo "  Run: ag done $cg_stale"
                    echo "  Or bypass: ag implement --force $feature_id"
                    exit 1
                fi
            fi
        fi
    fi

    # 0c. Auto-save plans from session-scoped tool directories to durable location
    # Must run BEFORE gate check so the gate can find auto-saved plans
    # Claude Code uses .claude/plans/, Cursor uses .cursor/plans/
    local existing_plan
    existing_plan=$(_find_plan_file "$feature_id" || echo "")
    if [ -z "$existing_plan" ]; then
        for plan_dir in "$ROOT_DIR/.claude/plans" "$ROOT_DIR/.cursor/plans"; do
            [ -d "$plan_dir" ] || continue
            for f in "$plan_dir/"*; do
                if [ -f "$f" ] && grep -q "$feature_id" "$f" 2>/dev/null; then
                    mkdir -p "$ROOT_DIR/.agentic/journal/plans"
                    local dest_name
                    dest_name=$(_plan_filename "$feature_id")
                    cp "$f" "$ROOT_DIR/.agentic/journal/plans/$dest_name"
                    local source_rel="${plan_dir#"$ROOT_DIR"/}"
                    echo -e "${GREEN}Plan auto-saved: ${source_rel}/ -> .agentic/journal/plans/$dest_name${NC}"
                    break 2
                fi
            done
        done
    fi

    # 0d. Check plan-review (BLOCKING when enabled)
    local plan_review_enabled
    plan_review_enabled=$(get_plan_review_config "plan_review_enabled" "no")
    if [ "$plan_review_enabled" = "yes" ]; then
        local plan_file
        plan_file=$(_find_plan_file "$feature_id" || echo "")
        if [ -n "$plan_file" ] && [ -f "$plan_file" ]; then
            local plan_status
            plan_status=$(grep -E "^\*\*Status\*\*:" "$plan_file" 2>/dev/null | head -1 | sed 's/.*Status\*\*:[[:space:]]*//' || echo "UNKNOWN")
            if [ "$plan_status" != "APPROVED" ]; then
                echo -e "${RED}BLOCKED: Plan exists but not approved (status: $plan_status)${NC}"
                echo ""
                echo "  REQUIRED: Run dialectical review before implementing."
                echo "  1. Spawn Critic + Advocate agents (see planning-features Step 5.5)"
                echo "  2. Present synthesis to user"
                echo "  3. After user says 'Proceed', update plan status to APPROVED"
                echo "  4. Re-run: ag implement $feature_id"
                echo ""
                echo "  Do NOT assess the plan yourself — the review agents do this with fresh context."
                exit 1
            else
                echo -e "${GREEN}Approved plan: EXISTS${NC}"
            fi
        else
            echo -e "${RED}BLOCKED: No approved plan found (plan_review_enabled: yes)${NC}"
            echo ""
            echo "  1. Save your plan to .agentic/journal/plans/YYYY-MM-DD-${feature_id}-plan.md with Status: DRAFT"
            echo "  2. Run dialectical review (Critic + Advocate agents)"
            echo "  3. After user approval, update Status to APPROVED"
            echo "  4. Re-run: ag implement $feature_id"
            exit 1
        fi
    fi

    # 0e. User input guidance (INFO, not blocking)
    if [[ -f "$CONTRACTS_DIR/${feature_id}.yaml" ]] && command -v python3 >/dev/null 2>&1; then
        local ui_preview
        ui_preview=$(PYTHONPATH="$ROOT_DIR/.agentic/lib" python3 -c "
from pathlib import Path; from contracts import load_contract
c = load_contract(Path('$CONTRACTS_DIR/${feature_id}.yaml'))
if c.has_pending_input:
    lines = c.user_input.strip().splitlines()
    print(lines[0][:80] + (' ...' if len(lines) > 1 else ''))
" 2>/dev/null) || ui_preview=""
        if [[ -n "$ui_preview" ]]; then
            echo -e "${BOLD}📥 Pending user input:${NC}"
            echo "  > $ui_preview"
            echo "  Workflow: read input -> write tests -> implement -> add migration -> clear field"
            echo "  Details: ag contract pending"
            echo ""
        fi
    fi

    # 1. Spec-first gate (BLOCKING unless SKIP_SPEC_CHECK=1)
    if [ "${SKIP_SPEC_CHECK:-}" = "1" ]; then
        echo -e "${YELLOW}⚠ SKIP_SPEC_CHECK: Bypassing spec-first gate${NC}"
    else
        # 1a. Check feature exists in FEATURES.md
        local features_file="$ROOT_DIR/.agentic/spec/FEATURES.md"
        if [ -f "$features_file" ]; then
            if grep -q "^## ${feature_id}:" "$features_file"; then
                echo -e "${GREEN}Feature registered: YES${NC}"
            else
                echo -e "${RED}BLOCKED: ${feature_id} not found in FEATURES.md${NC}"
                echo "  Add it first: add an entry to .agentic/spec/FEATURES.md"
                echo "  Or bypass: SKIP_SPEC_CHECK=1 ag implement $feature_id"
                exit 1
            fi
        fi

        # 1b. Check contract or acceptance criteria exist
        local contract_file="$CONTRACTS_DIR/${feature_id}.yaml"
        local acc_file="$ACCEPTANCE_DIR/${feature_id}.md"
        if [ -f "$contract_file" ]; then
            echo -e "${GREEN}Contract: EXISTS ($contract_file)${NC}"
        elif [ -f "$acc_file" ]; then
            echo -e "${GREEN}Acceptance criteria: EXISTS (legacy format)${NC}"
        else
            echo -e "${RED}BLOCKED: No contract or acceptance criteria${NC}"
            echo "  Missing: .agentic/spec/contracts/${feature_id}.yaml"
            echo ""
            echo "Create a contract FIRST, then run this command again."
            echo "  Create: ag contract create $feature_id"
            echo "  Or bypass: SKIP_SPEC_CHECK=1 ag implement $feature_id"
            exit 1
        fi
    fi

    # 2. AC clarity gate (spec-analyze --gate) — skipped on re-implement
    local current_wip
    current_wip=$(_get_wip_feature)
    if [[ "$skip_clarity" -eq 1 ]]; then
        echo -e "${YELLOW}⚠ SKIP_CLARITY: Bypassing AC clarity gate${NC}"
        bash "$SCRIPT_DIR/journal.sh" "AC clarity gate bypassed" "$feature_id: --skip-clarity used" "" "" 2>/dev/null || true
    elif [[ -n "$current_wip" && "$current_wip" == "$feature_id" ]]; then
        # Re-implement: feature already in progress, skip clarity gate
        true
    elif [[ -f "$CONTRACTS_DIR/${feature_id}.yaml" ]]; then
        # Contract exists — validate assertions
        local validate_exit=0
        python3 "$AGENTIC_LIB/contracts.py" validate "$CONTRACTS_DIR/${feature_id}.yaml" 2>/dev/null || validate_exit=$?
        if [[ "$validate_exit" -ne 0 ]]; then
            echo -e "${YELLOW}⚠ Contract validation warnings for $feature_id${NC}"
        fi
    elif [[ -f "$ACCEPTANCE_DIR/${feature_id}.md" ]]; then
        local sa_exit=0
        if _is_formal_like; then
            # Formal: CRITICAL findings block
            bash "$SCRIPT_DIR/spec-analyze.sh" "$feature_id" --gate 2>/dev/null || sa_exit=$?
            if [[ "$sa_exit" -ne 0 ]]; then
                echo ""
                echo -e "${RED}BLOCKED: AC clarity gate found CRITICAL issues${NC}"
                echo "  Fix the vague ACs above, or bypass: SKIP_CLARITY=1 ag implement $feature_id"
                exit 1
            fi
        else
            # Discovery: advisory only
            bash "$SCRIPT_DIR/spec-analyze.sh" "$feature_id" --gate 2>/dev/null || true
        fi
    fi

    # 2b. NFR staleness detection (advisory)
    local nfr_file="$ROOT_DIR/.agentic/spec/NFR.md"
    local contract_path="$CONTRACTS_DIR/${feature_id}.yaml"
    local acc_file_path="$ACCEPTANCE_DIR/${feature_id}.md"
    local nfr_ref_file=""
    if [[ -f "$contract_path" ]]; then
        nfr_ref_file="$contract_path"
    elif [[ -f "$acc_file_path" ]]; then
        nfr_ref_file="$acc_file_path"
    fi
    if [[ -f "$nfr_file" && -n "$nfr_ref_file" && -f "$nfr_ref_file" ]]; then
        # Check if file references any NFRs
        if grep -qE 'NFR-[0-9]+' "$nfr_ref_file" 2>/dev/null; then
            local nfr_ts ref_ts
            nfr_ts=$(git log -1 --format=%ct -- "$nfr_file" 2>/dev/null) || nfr_ts=""
            ref_ts=$(git log -1 --format=%ct -- "$nfr_ref_file" 2>/dev/null) || ref_ts=""
            # Only warn if both timestamps exist and NFR.md is newer
            if [[ -n "$nfr_ts" && -n "$ref_ts" && "$nfr_ts" -gt "$ref_ts" ]]; then
                echo -e "${YELLOW}⚠ NFR.md has changed since this feature's spec was written.${NC}"
                echo "  Run: bash .agentic/lib/tools/nfr-propagate.sh sync $feature_id"
            fi
        fi
    fi

    # 3. Run planning phase check (BLOCKING)
    echo ""
    echo "Running phase check..."
    if ! bash "$SCRIPT_DIR/doctor.sh" --phase planning "$feature_id" 2>/dev/null; then
        echo -e "${RED}BLOCKED: Planning phase checks failed. Fix issues above.${NC}"
        exit 1
    fi

    # 4. Get feature name from FEATURES.md if available
    local feature_name=""
    if [ -f "$features_file" ]; then
        feature_name=$(grep "^## ${feature_id}:" "$features_file" | sed "s/^## ${feature_id}: //" || echo "")
    fi

    # --- Intent-driven execution (F-0200) ---
    # Write intent before any mutable work. Each step is checkpointed.
    # If the process dies mid-sequence, ag sync can resume from last checkpoint.
    local wt_mode
    wt_mode=$(get_setting "worktree_mode" "off")
    local worktree_path=""
    local enforcement
    enforcement=$(_get_state_enforcement)

    # Build step list based on what will actually run
    local intent_steps="register_wip,create_worktree"
    if [ "$enforcement" != "off" ]; then
        intent_steps="${intent_steps},transition_state"
    fi
    intent_steps="${intent_steps},update_status"

    # Write intent (advisory — failure does not block)
    intent_write "$feature_id" "implementing" "implement" "$intent_steps" "" || true

    # 5. Worktree creation (when worktree_mode == always AND git active — F-0250)
    local impl_git_mode
    impl_git_mode=$(get_setting "git_mode" "active")
    if [[ "$impl_git_mode" != "active" ]] && [[ "$wt_mode" == "always" ]]; then
        echo -e "${YELLOW}Worktree mode requires git. Working in-place (git_mode: ${impl_git_mode}).${NC}"
        echo "  Run: ag git-init    to enable worktrees"
        wt_mode="off"
    fi
    if [ "$wt_mode" = "always" ]; then
        echo ""
        echo "Creating worktree for ${feature_id}..."
        worktree_path=$(bash "$SCRIPT_DIR/worktree.sh" create "$feature_id" "${feature_name:-$feature_id}" 2>/dev/null | tail -1) || true
        if [ -n "$worktree_path" ] && [ -d "$worktree_path" ]; then
            echo -e "${GREEN}Worktree ready: $worktree_path${NC}"
            echo "  cd $worktree_path"
            echo "  Then run: bash .agentic/lib/tools/wip.sh start $feature_id \"${feature_name:-$feature_id}\" \"\""
        else
            echo -e "${YELLOW}Worktree creation failed — continuing in main repo${NC}"
        fi
    fi
    intent_checkpoint "$feature_id" "create_worktree" || true

    # 6. Start WIP tracking (skip if worktree_mode=always — agent starts WIP in worktree)
    if [ "$wt_mode" != "always" ]; then
        echo ""
        echo "Starting WIP tracking..."
        bash "$SCRIPT_DIR/wip.sh" start "$feature_id" "${feature_name:-$feature_id}" "" 2>/dev/null || \
            echo -e "${YELLOW}WIP tracking not started (already active or unavailable)${NC}"
    fi
    intent_checkpoint "$feature_id" "register_wip" || true

    # 7. State transition (controlled by state_enforcement setting)
    if [ "$enforcement" != "off" ]; then
        echo ""
        echo "Transitioning state to implementing..."
        local _enforce_flag=""
        if [ "$enforcement" = "blocking" ]; then
            _enforce_flag="--enforce"
        fi
        local transition_out=""
        local transition_rc=0
        transition_out=$(python3 "$SCRIPT_DIR/../auto/state_machine.py" \
            --project-root "${MAIN_PROJECT_ROOT:-$ROOT_DIR}" \
            $_enforce_flag \
            "$feature_id" implementing 2>&1) || transition_rc=$?
        if [ "$transition_rc" -eq 0 ] || echo "$transition_out" | grep -q "no-op"; then
            echo -e "${GREEN}State: implementing${NC}"
            intent_checkpoint "$feature_id" "transition_state" || true
        else
            if [ "$enforcement" = "blocking" ]; then
                echo -e "${RED}BLOCKED: State transition failed${NC}"
                echo "$transition_out"
                echo -e "${YELLOW}To bypass: set state_enforcement: advisory in STACK.md${NC}"
                intent_cancel "$feature_id" || true
                exit 1
            else
                # advisory: warn and continue
                echo -e "${YELLOW}WARNING: State transition failed (advisory mode, continuing)${NC}"
                echo "$transition_out" | head -3
                intent_checkpoint "$feature_id" "transition_state" || true
            fi
        fi
    fi

    # 8. Update status
    intent_checkpoint "$feature_id" "update_status" || true

    # Clear intent — all steps complete
    intent_clear "$feature_id" || true

    # 8b. Phase tracking (F-032): fallback extraction, auto-sync, progress display
    if command -v python3 >/dev/null 2>&1; then
        local tasks_yaml="$ROOT_DIR/.agentic/work/${feature_id}/tasks.yaml"
        local _impl_plan
        _impl_plan=$(_find_plan_file "$feature_id" || echo "")
        if [ ! -f "$tasks_yaml" ]; then
            # Fallback: extract phases from approved plan if tasks.yaml missing
            if [ -n "$_impl_plan" ] && [ -f "$_impl_plan" ]; then
                local _impl_phases
                _impl_phases=$(PYTHONPATH="$AGENTIC_LIB" python3 "$AGENTIC_LIB/auto/phases.py" \
                    --project-root "$ROOT_DIR" create-from-plan "$feature_id" "$_impl_plan" 2>/dev/null) || _impl_phases=""
                if [ -n "$_impl_phases" ]; then
                    echo -e "${GREEN}Phase tracking: $_impl_phases → tasks.yaml${NC}"
                fi
            fi
        elif [ -n "$_impl_plan" ] && [ -f "$_impl_plan" ] && [ "$_impl_plan" -nt "$tasks_yaml" ]; then
            # Auto-sync: plan was revised after tasks.yaml was created
            local _sync_out
            _sync_out=$(PYTHONPATH="$AGENTIC_LIB" python3 "$AGENTIC_LIB/auto/phases.py" \
                --project-root "$ROOT_DIR" sync "$feature_id" 2>/dev/null) || _sync_out=""
            if [ -n "$_sync_out" ] && [ "$_sync_out" != "No changes" ]; then
                echo -e "${YELLOW}Phase auto-sync (plan revised): ${_sync_out}${NC}"
            fi
        fi
        # Show phase progress if tasks.yaml exists
        local _phase_summary
        _phase_summary=$(PYTHONPATH="$AGENTIC_LIB" python3 "$AGENTIC_LIB/auto/phases.py" \
            --project-root "$ROOT_DIR" progress "$feature_id" 2>/dev/null) || _phase_summary=""
        if [ -n "$_phase_summary" ]; then
            echo ""
            echo -e "${BOLD}Phase progress:${NC} $_phase_summary"
            echo "  Run: ag phase list $feature_id"
        fi
    fi

    echo ""
    echo -e "${GREEN}Ready to implement ${feature_id}${NC}"
    echo "Remember: Update FEATURES.md status to 'in_progress'"
    echo ""
    echo -e "${BOLD}References:${NC}"
    echo "  Run \`ag check ${feature_id}\` for next steps"
    if [[ -f ".agentic/lib/checklists/feature_implementation.md" ]]; then
        echo "  Checklist: .agentic/lib/checklists/feature_implementation.md"
    else
        echo "  Guidance: See role prompts in .agentic/prompts/ or run \`ag check\`"
    fi
}
