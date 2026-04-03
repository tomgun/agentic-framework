#!/usr/bin/env bash
# commands/done.sh — Feature/task complete validation + doc lifecycle
# Sourced by ag.sh — do NOT execute directly.
# Depends on: SCRIPT_DIR, ROOT_DIR, PROFILE, color codes, paths.sh, settings.sh

# ---------------------------------------------------------------------------
# _defer_docs: Log deferred doc entries instead of triggering inline drafting
#   $1 = feature_id (optional)
# Requires jq. Writes to $MAIN_PROJECT_ROOT/.agentic/deferred-docs.json
# ---------------------------------------------------------------------------
_defer_docs() {
    local fid="${1:-}"
    local deferred_log="${MAIN_PROJECT_ROOT:-$ROOT_DIR}/.agentic/deferred-docs.json"

    if ! command -v jq >/dev/null 2>&1; then
        echo -e "${YELLOW}Warning: jq not found — cannot defer docs. Install jq or set docs_mode: inline${NC}"
        return 1
    fi

    # Get doc registry entries with feature_done/pr trigger via parse_registry pattern
    # Collect path|type pairs, then build JSON array in one jq call
    local stack_file="${ROOT_DIR}/STACK.md"
    local doc_pairs=""
    if [[ -f "$stack_file" ]]; then
        local in_docs=false
        while IFS= read -r line; do
            if [[ "$line" =~ ^##[[:space:]]+Docs ]]; then
                in_docs=true; continue
            fi
            if $in_docs && [[ "$line" =~ ^##[[:space:]] ]]; then
                break
            fi
            if $in_docs && [[ "$line" =~ ^-[[:space:]]*doc:[[:space:]]* ]]; then
                local entry="${line#*doc:}"
                local d_path d_type d_trigger
                d_path=$(echo "$entry" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$1); print $1}')
                d_type=$(echo "$entry" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$2); print $2}')
                d_trigger=$(echo "$entry" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$3); print $3}')
                if [[ "$d_trigger" == "feature_done" || "$d_trigger" == "pr" ]]; then
                    doc_pairs+="${d_path}|${d_type}"$'\n'
                fi
            fi
        done < "$stack_file"
    fi

    # Build stale_docs JSON from collected pairs in one jq call
    local stale_docs_json="[]"
    if [[ -n "$doc_pairs" ]]; then
        stale_docs_json=$(printf '%s' "$doc_pairs" | grep -v '^$' | while IFS='|' read -r p t; do
            printf '{"path":"%s","type":"%s"}\n' "$p" "$t"
        done | jq -s '.')
    fi

    local doc_count
    doc_count=$(echo "$stale_docs_json" | jq 'length')
    if [[ "$doc_count" -eq 0 ]]; then
        return 0
    fi

    # Get changed files (build JSON array in one jq call for performance)
    local files_json="[]"
    local manifest_file="$ROOT_DIR/.agentic/journal/manifests/${fid}.manifest.md"
    local files_list=""
    if [[ -n "$fid" && -f "$manifest_file" ]]; then
        files_list=$(sed -n 's/^- `\([^`]*\)`.*/\1/p' "$manifest_file" 2>/dev/null || true)
    else
        files_list=$(git diff --name-only HEAD~1 2>/dev/null || true)
    fi
    if [[ -n "$files_list" ]]; then
        files_json=$(printf '%s\n' "$files_list" | jq -R . | jq -s .)
    fi

    local commit_sha
    commit_sha=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local description="Deferred doc updates for ${fid:-unknown feature}"

    # Initialize file if missing
    if [[ ! -f "$deferred_log" ]]; then
        echo "[]" > "$deferred_log"
    fi

    # Append entry atomically
    local tmp_file="${deferred_log}.tmp"
    jq --arg fid "${fid:-}" \
       --arg ts "$timestamp" \
       --arg desc "$description" \
       --arg sha "$commit_sha" \
       --argjson files "$files_json" \
       --argjson stale "$stale_docs_json" \
       '. + [{"feature_id": $fid, "timestamp": $ts, "files_changed": $files, "description": $desc, "stale_docs": $stale, "commit_sha": $sha}]' \
       "$deferred_log" > "$tmp_file" && mv "$tmp_file" "$deferred_log"

    echo -e "${GREEN}Deferred doc updates for ${doc_count} doc(s). Run \`ag docs generate\` later.${NC}"
}

# ---------------------------------------------------------------------------
# _docs_generate: Process deferred doc entries
#   $1 = feature_id filter (optional, empty = all)
# ---------------------------------------------------------------------------
_docs_generate() {
    local filter_fid="${1:-}"
    local deferred_log="${MAIN_PROJECT_ROOT:-$ROOT_DIR}/.agentic/deferred-docs.json"

    if ! command -v jq >/dev/null 2>&1; then
        echo -e "${RED}Error: jq required for deferred docs. Install jq.${NC}"
        exit 1
    fi

    if [[ ! -f "$deferred_log" ]]; then
        echo "No deferred docs pending."
        return 0
    fi

    local total
    total=$(jq 'length' "$deferred_log")
    if [[ "$total" -eq 0 ]]; then
        echo "No deferred docs pending."
        return 0
    fi

    # Get entries to process (filtered or all)
    local entries
    if [[ -n "$filter_fid" ]]; then
        entries=$(jq -c --arg fid "$filter_fid" '[.[] | select(.feature_id == $fid)]' "$deferred_log")
    else
        entries=$(jq -c '.' "$deferred_log")
    fi

    local count
    count=$(echo "$entries" | jq 'length')
    if [[ "$count" -eq 0 ]]; then
        echo "No deferred docs pending${filter_fid:+ for $filter_fid}."
        return 0
    fi

    echo -e "${BOLD}=== Generating Deferred Docs ($count entries) ===${NC}"
    echo ""

    local processed=0
    for i in $(seq 0 $((count - 1))); do
        local entry
        entry=$(echo "$entries" | jq -c ".[$i]")
        local fid
        fid=$(echo "$entry" | jq -r '.feature_id')
        local sha
        sha=$(echo "$entry" | jq -r '.commit_sha')

        echo -e "${BOLD}--- ${fid:-unknown} (commit: ${sha}) ---${NC}"

        # Trigger doc generation
        if [[ -n "$fid" && "$fid" != "null" && "$fid" != "" ]]; then
            bash "$SCRIPT_DIR/docs.sh" --trigger feature_done --manifest "$fid" 2>/dev/null || true
        else
            bash "$SCRIPT_DIR/docs.sh" --trigger feature_done 2>/dev/null || true
        fi

        # Remove this entry from the log (one-by-one for interruption safety)
        local tmp_file="${deferred_log}.tmp"
        jq --arg fid "$fid" --arg sha "$sha" \
           '[.[] | select(.feature_id != $fid or .commit_sha != $sha)]' \
           "$deferred_log" > "$tmp_file" && mv "$tmp_file" "$deferred_log"

        processed=$((processed + 1))
        echo ""
    done

    echo -e "${GREEN}Processed $processed deferred doc entries.${NC}"

    # Clean up empty log
    local remaining
    remaining=$(jq 'length' "$deferred_log" 2>/dev/null || echo "0")
    if [[ "$remaining" -eq 0 ]]; then
        rm -f "$deferred_log"
        echo "Deferred log cleared."
    else
        echo "$remaining entries remaining."
    fi
}

# Done command - feature/task complete validation
cmd_done() {
    # Parse args: feature ID + optional flags
    local feature_id=""
    local force_phases=0
    local explicit_type=""
    local _skip_next=0
    local arg
    for arg in "$@"; do
        if [ "$_skip_next" -eq 1 ]; then
            explicit_type="$arg"
            _skip_next=0
            continue
        fi
        case "$arg" in
            --force-phases) force_phases=1 ;;
            --type) _skip_next=1 ;;
            --type=*) explicit_type="${arg#--type=}" ;;
            *) [[ -z "$feature_id" ]] && feature_id="$arg" ;;
        esac
    done

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
        echo "  [ ] Capability catalog updated (FEATURES.md)"
        echo ""
        # Quick health check (warning only — Discovery mode)
        if bash "$SCRIPT_DIR/doctor.sh" --quick 2>/dev/null; then
            echo -e "${GREEN}✓${NC} Quick health check passed"
        else
            echo -e "${YELLOW}⚠ Quick health check found issues (non-blocking)${NC}"
        fi
        echo ""
        # Capability catalog check (F-042)
        if [ -f "${ROOT_DIR}/.agentic/session/.cap_updated" ]; then
            echo -e "${GREEN}✓${NC} Capability catalog updated this session"
        elif [ -f "${ROOT_DIR}/.agentic/spec/FEATURES.md" ]; then
            echo -e "${YELLOW}⚠ Capability catalog not updated. Register what you built:${NC}"
            echo "  Edit .agentic/spec/FEATURES.md or run: bash .agentic/lib/tools/feature.sh cap add \"Name\" \"Description\""
        fi
        # Journal freshness check (F-042)
        local _journal_path="${ROOT_DIR}/.agentic/journal/JOURNAL.md"
        if [ -f "$_journal_path" ] && [ -d "${ROOT_DIR}/.agentic/session" ]; then
            local _sess_start _journal_mtime
            _sess_start=$(stat -c %Y "${ROOT_DIR}/.agentic/session" 2>/dev/null || stat -f %m "${ROOT_DIR}/.agentic/session" 2>/dev/null || echo 0)
            _journal_mtime=$(stat -c %Y "$_journal_path" 2>/dev/null || stat -f %m "$_journal_path" 2>/dev/null || echo 0)
            if [ "$_journal_mtime" -le "$_sess_start" ] 2>/dev/null; then
                echo -e "${YELLOW}⚠ No journal entry this session. Record what you did:${NC}"
                echo "  bash .agentic/lib/tools/journal.sh \"Topic\" \"What changed\" \"Next\" \"Blockers\" --why \"Motivation\""
            else
                echo -e "${GREEN}✓${NC} Journal updated this session"
            fi
        fi
        echo ""
        # Check if WIP is complete
        if _has_active_wip || [ -f "$ROOT_DIR/.agentic/session/WIP.md" ]; then
            echo -e "${YELLOW}Note: WIP tracking still active. Complete it with:${NC}"
            echo "  bash .agentic/lib/tools/wip.sh complete"
        fi
        return
    fi

    # Warn about uncommitted changes (structural nudge — T-0034)
    if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
        echo -e "${YELLOW}⚠ You have uncommitted changes.${NC} Consider running \`ag commit\` first."
        echo ""
    fi

    # --- Plan backstop (F-0222/§16) ---
    # Catches retroactive planning: if plan_review_enabled but no approved plan,
    # block shipping. This is order-independent — works even if ag implement was
    # never run. State-based check, not workflow-position check.
    local plan_review_enabled_done
    plan_review_enabled_done=$(get_plan_review_config "plan_review_enabled" "no")
    if [ "$plan_review_enabled_done" = "yes" ] && [ -n "$feature_id" ] && is_feature_id "$feature_id"; then
        local _plan_glob
        _plan_glob=$(_find_plan_file "$feature_id" || echo "")
        if [ -z "$_plan_glob" ]; then
            echo -e "${RED}BLOCKED: No plan found for $feature_id (plan_review_enabled: yes)${NC}"
            echo "  Create a plan first: ag plan $feature_id"
            echo -e "${YELLOW}To bypass: set plan_review_enabled: no in STACK.md${NC}"
            exit 1
        else
            local _plan_status
            _plan_status=$(grep -E "^\*\*Status\*\*:" "$_plan_glob" 2>/dev/null | head -1 | sed 's/.*Status\*\*:[[:space:]]*//' || echo "UNKNOWN")
            if [ "$_plan_status" != "APPROVED" ]; then
                echo -e "${RED}BLOCKED: Plan for $feature_id is ${_plan_status}, not APPROVED${NC}"
                echo "  Plan: $_plan_glob"
                echo "  Run dialectical review and approve the plan first"
                echo -e "${YELLOW}To bypass: set plan_review_enabled: no in STACK.md${NC}"
                exit 1
            fi
        fi
    fi

    # --- Phase completion gate (F-032) ---
    # If tasks.yaml exists with incomplete phases, block shipping.
    if [ -n "$feature_id" ] && is_feature_id "$feature_id"; then
        local _phase_check_exit=0
        local _phase_msg=""
        _phase_msg=$(PYTHONPATH="$AGENTIC_LIB" python3 "$AGENTIC_LIB/auto/phases.py" \
            --project-root "${MAIN_PROJECT_ROOT:-$ROOT_DIR}" check "$feature_id" 2>/dev/null) || _phase_check_exit=$?
        if [ "$_phase_check_exit" -eq 1 ]; then
            if [ "$force_phases" -eq 1 ]; then
                echo -e "${YELLOW}⚠ Phase gate bypassed (--force-phases): $_phase_msg${NC}"
                bash "$SCRIPT_DIR/journal.sh" "Phase gate bypassed" \
                    "$feature_id: --force-phases used. $_phase_msg" "" "" \
                    --why "Incomplete phases overridden at shipping time" 2>/dev/null || true
            else
                echo -e "${RED}BLOCKED: $_phase_msg${NC}"
                echo "  Options:"
                echo "    ag phase done $feature_id <phase_id>    Mark a phase complete"
                echo "    ag phase drop $feature_id <phase_id>    Drop a phase"
                echo "    ag done $feature_id --force-phases       Bypass this gate"
                echo ""
                echo "  Run: ag phase list $feature_id   to see all phases"
                exit 1
            fi
        elif [ -n "$_phase_msg" ]; then
            echo -e "${GREEN}✓ $_phase_msg${NC}"
        fi
    fi

    # --- Automated verification gate ---
    # Run automated verification commands from AC file before shipping.
    # Advisory for discovery, blocking for formal profiles.
    if [ -n "$feature_id" ] && is_feature_id "$feature_id"; then
        local auto_verify_contract="$CONTRACTS_DIR/${feature_id}.yaml"
        local auto_verify_acc="$ACCEPTANCE_DIR/${feature_id}.md"
        if [ -f "$auto_verify_contract" ] || { [ -f "$auto_verify_acc" ] && grep -q '\*\*Automated\*\*' "$auto_verify_acc"; }; then
            echo -e "${BOLD}=== Running Automated Verification ===${NC}"
            if cmd_verify "$feature_id"; then
                echo ""
            else
                local _ac_setting
                _ac_setting="$(get_setting "acceptance_criteria" "blocking")"
                if [ "$_ac_setting" = "blocking" ]; then
                    echo -e "${RED}BLOCKED: Automated verification failed for $feature_id${NC}"
                    echo -e "${YELLOW}To bypass: set acceptance_criteria: recommended in STACK.md${NC}"
                    exit 1
                else
                    echo -e "${YELLOW}WARNING: Automated verification failed (advisory, continuing)${NC}"
                fi
                echo ""
            fi
        fi
    fi

    # --- Intent-driven execution (F-0200) ---
    # Write intent before any mutable work. Each step is checkpointed.
    # If the process dies mid-sequence, ag sync can resume from last checkpoint.
    local enforcement
    enforcement=$(_get_state_enforcement)

    if [ -n "$feature_id" ] && is_feature_id "$feature_id"; then
        # Build step list based on what will actually run
        local intent_steps="generate_manifest,check_drift,check_ac_completion"
        if [ "$enforcement" != "off" ]; then
            intent_steps="${intent_steps},transition_verified,transition_documented,transition_committed,transition_shipped"
        fi
        intent_steps="${intent_steps},complete_wip,advance_backlog"

        # Write intent (advisory — failure does not block)
        intent_write "$feature_id" "shipped" "done" "$intent_steps" "" || true
    fi

    # Generate manifest for feature (Formal profile)
    if [ -n "$feature_id" ] && is_feature_id "$feature_id"; then
        echo -e "${BOLD}=== Generating Change Manifest ===${NC}"
        if bash "$SCRIPT_DIR/manifest.sh" "$feature_id" 2>/dev/null; then
            local manifest_file="$ROOT_DIR/.agentic/journal/manifests/${feature_id}.manifest.md"
            if [ -f "$manifest_file" ]; then
                # Extract stats for journal metadata
                local commit_count file_count
                commit_count=$(grep -c "^|" "$manifest_file" 2>/dev/null | head -1 || echo "0")
                commit_count=$((commit_count - 2))  # Subtract header rows
                file_count=$(grep -c "^\- \`" "$manifest_file" 2>/dev/null || echo "0")
                echo -e "${GREEN}Manifest generated: .agentic/journal/manifests/${feature_id}.manifest.md${NC}"
                echo "  Commits: $commit_count, Files: $file_count"
            fi
        else
            echo -e "${YELLOW}Could not generate manifest (no matching commits?)${NC}"
        fi
        echo ""
        intent_checkpoint "$feature_id" "generate_manifest" || true
    fi

    # Doc drift gate (controlled by docs_gate setting)
    local docs_gate_mode
    docs_gate_mode=$(get_setting "docs_gate" "off")
    local docs_mode_val
    docs_mode_val=$(get_setting "docs_mode" "inline")

    # Freshness result saved here, checked as Gate 4 in done_failures block (after doc lifecycle fires)
    local docs_freshness_exit=0

    if [ "$docs_gate_mode" != "off" ]; then
        echo -e "${BOLD}=== Documentation Drift Check ===${NC}"
        if [ -n "$feature_id" ]; then
            bash "$SCRIPT_DIR/drift.sh" --docs --manifest "$feature_id" 2>/dev/null || true
        else
            bash "$SCRIPT_DIR/drift.sh" --docs 2>/dev/null || true
        fi

        # Registry validation (registered-but-missing + unregistered docs)
        echo ""
        local validate_exit=0
        if [[ -f "$SCRIPT_DIR/docs.sh" ]]; then
            bash "$SCRIPT_DIR/docs.sh" --validate 2>/dev/null || validate_exit=$?
        fi

        if [ "${validate_exit:-0}" -ne 0 ]; then
            echo -e "${YELLOW}⚠ Registry validation found issues (see above)${NC}"
        fi

        echo ""
    fi
    if [ -n "$feature_id" ] && is_feature_id "$feature_id"; then
        intent_checkpoint "$feature_id" "check_drift" || true
    fi

    # Doc lifecycle: draft docs from registry (after docs_gate, before complete check)
    # Guarded by docs_gate != off (no doc work when docs_gate: off)
    if [ "$docs_gate_mode" != "off" ] && [[ -f "$SCRIPT_DIR/docs.sh" ]]; then
        local has_docs_registry
        has_docs_registry=$(bash "$SCRIPT_DIR/docs.sh" --list 2>/dev/null | grep -c "^  " || true)
        if [[ "$has_docs_registry" -gt 1 ]]; then
            if [ "$docs_mode_val" = "deferred" ]; then
                # Deferred mode: log what would be drafted, don't trigger inline
                echo -e "${BOLD}=== Doc Lifecycle (deferred) ===${NC}"
                _defer_docs "$feature_id"
            else
                # Inline mode (default): trigger doc drafting immediately
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
            fi
            echo ""
        fi
    fi

    # Doc freshness gate: runs AFTER doc lifecycle (agent had chance to update docs)
    # Result saved in docs_freshness_exit, checked as Gate 4 in done_failures block
    if [ "$docs_gate_mode" != "off" ] && [[ -f "$SCRIPT_DIR/docs.sh" ]]; then
        if [ "$docs_mode_val" = "deferred" ]; then
            # Deferred mode: skip freshness blocking (docs logged for later)
            # But still check registry health — missing files are always an error
            # Reuse validate_exit from earlier drift check section (avoid double --validate call)
            if [[ "${validate_exit:-0}" -ne 0 ]]; then
                docs_freshness_exit=1
            fi
        else
            echo -e "${BOLD}=== Doc Freshness Check ===${NC}"
            if [ -n "$feature_id" ]; then
                bash "$SCRIPT_DIR/docs.sh" --check-freshness --trigger feature_done --manifest "$feature_id" 2>/dev/null || docs_freshness_exit=$?
            else
                bash "$SCRIPT_DIR/docs.sh" --check-freshness --trigger feature_done 2>/dev/null || docs_freshness_exit=$?
            fi
            echo ""
        fi
    fi

    # Smoke test evidence gate
    local smoke_evidence_mode
    smoke_evidence_mode=$(get_setting "smoke_test_evidence" "off")

    if [ "$smoke_evidence_mode" != "off" ] && [ -n "$feature_id" ] && is_feature_id "$feature_id"; then
        echo -e "${BOLD}=== Smoke Test Evidence Check ===${NC}"
        mkdir -p "$ROOT_DIR/.agentic/journal/evidence"
        local evidence_found=""
        for f in "$ROOT_DIR/.agentic/journal/evidence/${feature_id}-smoke".*; do
            [ -e "$f" ] && evidence_found="$f" && break
        done
        if [ -n "$evidence_found" ]; then
            echo -e "${GREEN}✓ Evidence found: $(basename "$evidence_found")${NC}"
        elif [ "$smoke_evidence_mode" = "required" ]; then
            if [ "${SKIP_SMOKE_EVIDENCE:-0}" = "1" ] || [ ! -t 0 ]; then
                echo -e "${YELLOW}smoke_test_evidence: required — skipped (non-interactive)${NC}"
            else
                echo -e "${RED}BLOCKED: No smoke test evidence for $feature_id${NC}"
                echo "  Expected: .agentic/journal/evidence/${feature_id}-smoke.*"
                echo "  Create manually, or run: ag auto verify --visual --feature $feature_id"
                exit 1
            fi
        else
            echo -e "${YELLOW}⚠ No smoke test evidence for $feature_id${NC}"
            echo "  Tip: Create .agentic/journal/evidence/${feature_id}-smoke.md manually"
            echo "  Or run: ag auto verify --visual --feature $feature_id (requires E2E screenshots config)"
        fi
        echo ""
    fi

    echo -e "${BOLD}=== Feature Complete Check ===${NC}"
    echo ""

    # If feature ID provided, run specific checks
    if [ -n "$feature_id" ]; then
        if ! is_feature_id "$feature_id"; then
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

        # Gate 1: Contract or acceptance file must exist
        local contract_file="$CONTRACTS_DIR/${feature_id}.yaml"
        local acc_file="$ACCEPTANCE_DIR/${feature_id}.md"
        local has_contract=false
        if [ -f "$contract_file" ]; then
            has_contract=true
        elif [ ! -f "$acc_file" ]; then
            echo -e "${RED}BLOCKED: Missing contract or acceptance criteria${NC}"
            echo "  Expected: .agentic/spec/contracts/${feature_id}.yaml"
            done_failures=$((done_failures + 1))
        fi

        # Gate 2: Feature must be registered in FEATURES.md (heading OR table format)
        local features_file="$ROOT_DIR/.agentic/spec/FEATURES.md"
        if [ -f "$features_file" ]; then
            if ! grep -qE "^## ${feature_id}:" "$features_file" && \
               ! grep -qE "^\|[[:space:]]*${feature_id}[[:space:]]*\|" "$features_file"; then
                echo -e "${RED}BLOCKED: $feature_id not found in FEATURES.md${NC}"
                echo "  Register it first, or use: bash .agentic/lib/tools/feature.sh $feature_id status shipped"
                done_failures=$((done_failures + 1))
            fi
        fi

        # Gate 3: AC completion check — contract assertions or legacy markdown
        if [ "$has_contract" = true ]; then
            # Contract-based: run structural assertions via verify-contracts.sh
            echo ""
            echo -e "${BOLD}Contract Assertion Check:${NC}"
            local verify_exit=0
            local verify_output
            verify_output=$(bash "$SCRIPT_DIR/verify-contracts.sh" --feature "$feature_id" 2>/dev/null) || verify_exit=$?
            if [ "$verify_exit" -ne 0 ]; then
                echo -e "${RED}BLOCKED: Contract assertions failed${NC}"
                echo "$verify_output" | head -20
                done_failures=$((done_failures + 1))
            else
                local assertion_count
                assertion_count=$(python3 - "$AGENTIC_LIB" "$contract_file" <<'PYEOF'
import sys; sys.path.insert(0, sys.argv[1])
from pathlib import Path
from contracts import load_contract
print(len(load_contract(Path(sys.argv[2])).assertions))
PYEOF
) || assertion_count="?"
                echo -e "${GREEN}✓ All structural assertions pass ($assertion_count total)${NC}"
            fi
        elif [ -f "$acc_file" ]; then
            local total_acs=0 checked_acs=0 ac_pct=100
            total_acs=$(ac_count_total "$acc_file")
            checked_acs=$(ac_count_checked "$acc_file")

            # Legacy format advisory
            if ac_has_legacy_format "$acc_file"; then
                echo -e "  ${BLUE}ℹ${NC} Legacy AC format detected — consider migrating to checkbox format: \`- [ ] **AC-NNN**:\`"
            fi

            if [ "$total_acs" -gt 0 ]; then
                ac_pct=$(ac_completion_pct "$acc_file")
                echo ""
                echo -e "${BOLD}AC Completion:${NC} ${checked_acs}/${total_acs} (${ac_pct}%)"

                local ac_setting
                ac_setting="$(get_setting "acceptance_criteria" "blocking")"
                local ac_failed=0

                if ac_has_priority_groups "$acc_file"; then
                    # Priority-group-aware enforcement:
                    # P1 groups = 100% required, P2/P3 = 80%
                    local p1_total p1_checked p1_pct
                    p1_total=$(ac_count_total_in_group "$acc_file" "P1")
                    p1_checked=$(ac_count_checked_in_group "$acc_file" "P1")
                    p1_pct=$(ac_completion_pct_in_group "$acc_file" "P1")

                    # Ungrouped ACs treated as P1 when groups exist (mixed format)
                    local ug_total ug_checked
                    ug_total=$(ac_count_total_in_group "$acc_file" "ungrouped")
                    ug_checked=$(ac_count_checked_in_group "$acc_file" "ungrouped")
                    p1_total=$((p1_total + ug_total))
                    p1_checked=$((p1_checked + ug_checked))
                    if [ "$p1_total" -gt 0 ]; then
                        p1_pct=$((p1_checked * 100 / p1_total))
                    fi

                    local p2_total p2_checked p2_pct
                    p2_total=$(ac_count_total_in_group "$acc_file" "P2")
                    p2_checked=$(ac_count_checked_in_group "$acc_file" "P2")
                    p2_pct=$(ac_completion_pct_in_group "$acc_file" "P2")

                    echo -e "  P1: ${p1_checked}/${p1_total} (${p1_pct}%)  P2: ${p2_checked}/${p2_total} (${p2_pct}%)"

                    if [ "$p1_total" -gt 0 ] && [ "$p1_pct" -lt 100 ]; then
                        ac_failed=1
                        echo -e "${RED}P1 ACs incomplete: ${p1_pct}% < 100% required${NC}"
                    fi
                    if [ "$p2_total" -gt 0 ] && [ "$p2_pct" -lt 80 ]; then
                        ac_failed=1
                        echo -e "${RED}P2 ACs incomplete: ${p2_pct}% < 80% threshold${NC}"
                    fi
                else
                    # Flat-list specs: existing 80% threshold (no regression)
                    if [ "$ac_pct" -lt 80 ]; then
                        ac_failed=1
                    fi
                fi

                if [ "$ac_failed" -eq 1 ]; then
                    if [ "$ac_setting" = "blocking" ]; then
                        echo -e "${RED}BLOCKED: AC completion below threshold${NC}"
                        echo "  Fix failing assertions in .agentic/spec/contracts/${feature_id}.yaml"
                        done_failures=$((done_failures + 1))
                    else
                        echo -e "${YELLOW}WARNING: AC completion below threshold${NC}"
                    fi
                fi
            fi
        fi

        # Gate 4: Doc freshness (checked after doc lifecycle gave agent a chance to update)
        if [ "$docs_freshness_exit" -ne 0 ]; then
            if [ "$docs_gate_mode" = "blocking" ]; then
                echo -e "${RED}BLOCKED: Documentation not up to date${NC}"
                echo "  Run: bash .agentic/lib/tools/docs.sh --check-freshness to see stale docs"
                echo "  Update stale docs, then run ag done again."
                done_failures=$((done_failures + 1))
            elif [ "$docs_gate_mode" = "warning" ]; then
                echo -e "${YELLOW}WARNING: Documentation may be stale (docs_gate: warning)${NC}"
                echo "  Run: bash .agentic/lib/tools/docs.sh --check-freshness to see details"
            fi
        fi

        if [ "$done_failures" -gt 0 ]; then
            echo ""
            echo -e "${RED}$done_failures blocking issue(s). Fix before marking complete.${NC}"
            exit 1
        fi
        intent_checkpoint "$feature_id" "check_ac_completion" || true

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

        # Check if contract/acceptance file has untracked state
        if [ -f "$contract_file" ]; then
            if git status --porcelain "$contract_file" 2>/dev/null | grep -q '^??'; then
                echo -e "${YELLOW}⚠ Contract file is untracked:${NC}"
                echo "   .agentic/spec/contracts/${feature_id}.yaml"
                echo "   Consider: git add .agentic/spec/contracts/${feature_id}.yaml"
            fi
            echo ""
            echo -e "${BOLD}📝 Review contract before marking accepted:${NC}"
            echo "   cat .agentic/spec/contracts/${feature_id}.yaml"
        elif [ -f "$acc_file" ]; then
            if git status --porcelain "$acc_file" 2>/dev/null | grep -q '^??'; then
                echo -e "${YELLOW}⚠ Acceptance criteria file is untracked (legacy format)${NC}"
            fi
            # Surface [Discovered] markers
            local discovered_count
            discovered_count=$(grep -c '\[Discovered\]' "$acc_file" 2>/dev/null || echo "0")
            if [ "$discovered_count" -gt 0 ]; then
                echo ""
                echo -e "${YELLOW}📋 Spec evolved: $discovered_count requirements discovered during implementation${NC}"
            fi
        fi

        # Check FEATURES.md shipped status (heading AND table format)
        local features_file="$ROOT_DIR/.agentic/spec/FEATURES.md"
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
                echo -e "${BOLD}Auto-marking $feature_id as shipped in FEATURES.md${NC}"
                if bash "$SCRIPT_DIR/feature.sh" "$feature_id" status shipped 2>/dev/null; then
                    echo -e "${GREEN}✓ $feature_id marked as shipped${NC}"
                else
                    echo -e "${YELLOW}⚠ Could not auto-mark $feature_id as shipped${NC}"
                    echo "  Manual update: bash .agentic/lib/tools/feature.sh $feature_id status shipped"
                fi
            fi
        fi

        # Also update contract lifecycle to shipped
        if [ -f "$contract_file" ]; then
            python3 - "$AGENTIC_LIB" "$contract_file" <<'PYEOF' 2>/dev/null || true
import sys; sys.path.insert(0, sys.argv[1])
from pathlib import Path
from contracts import load_contract, save_contract
c = load_contract(Path(sys.argv[2]))
if c.lifecycle != 'shipped':
    c.lifecycle = 'shipped'
    c.protection = 'contract'
    save_contract(c)
    print('Contract lifecycle → shipped')
PYEOF
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

    # Show definition of done checklist (task-type-aware via dod.py)
    local resolved_type="implementation"
    resolved_type=$(python3 "$AGENTIC_LIB/dod.py" resolve-type "${feature_id:-}" \
        ${explicit_type:+--type "$explicit_type"} --project-root "$ROOT_DIR" 2>/dev/null) || resolved_type="implementation"

    echo ""
    echo -e "${BOLD}Definition of Done (${resolved_type}):${NC}"

    local checklist_output
    checklist_output=$(python3 "$AGENTIC_LIB/dod.py" checklist --type "$resolved_type" \
        --project-root "$ROOT_DIR" 2>/dev/null) || checklist_output=""

    if [ -n "$checklist_output" ]; then
        echo "$checklist_output"
    else
        # Fallback: legacy hardcoded list
        echo "  [ ] All acceptance criteria met"
        echo "  [ ] Tests written for feature"
        echo "  [ ] All tests passing"
        echo "  [ ] .agentic/spec/FEATURES.md updated (status: shipped)"
        echo "  [ ] Docs updated (if behavior changed)"
        echo "  [ ] Code reviewed (self-review at minimum)"
        echo "  [ ] Smoke tested (actually RUN it)"
        echo "  [ ] JOURNAL.md updated"
    fi
    echo ""
    if [[ -f ".agentic/lib/checklists/feature_complete.md" ]]; then
        echo "Full checklist: .agentic/lib/checklists/feature_complete.md"
    else
        echo "Run \`ag check\` for completion guidance"
    fi

    # State transitions (controlled by state_enforcement setting)
    # Reliability (crash recovery) is always active via intent checkpoints above.
    # State machine transitions are only attempted when state_enforcement != off.
    if [ -n "$feature_id" ] && is_feature_id "$feature_id" && [ "$enforcement" != "off" ]; then
        echo ""
        echo -e "${BOLD}=== State Transitions ===${NC}"
        local _enforce_flag=""
        if [ "$enforcement" = "blocking" ]; then
            _enforce_flag="--enforce"
        fi
        local _done_states="verified documented committed shipped"
        for _target_state in $_done_states; do
            local _trans_out=""
            local _trans_rc=0
            _trans_out=$(python3 "$SCRIPT_DIR/../auto/state_machine.py" \
                --project-root "${MAIN_PROJECT_ROOT:-$ROOT_DIR}" \
                $_enforce_flag \
                transition "$feature_id" "$_target_state" 2>&1) || _trans_rc=$?
            if [ "$_trans_rc" -eq 0 ] || echo "$_trans_out" | grep -q "no-op"; then
                echo -e "${GREEN}State: $_target_state${NC}"
            else
                if [ "$enforcement" = "blocking" ]; then
                    echo -e "${RED}BLOCKED: State transition to $_target_state failed${NC}"
                    echo "$_trans_out"
                    echo -e "${YELLOW}To bypass: set state_enforcement: advisory in STACK.md${NC}"
                    intent_cancel "$feature_id" || true
                    exit 1
                else
                    # advisory: warn and continue
                    echo -e "${YELLOW}WARNING: Transition to $_target_state failed (advisory, continuing)${NC}"
                    echo "$_trans_out" | head -3
                fi
            fi
            intent_checkpoint "$feature_id" "transition_${_target_state}" || true
        done
    fi

    # Check if WIP is complete
    if _has_active_wip || [ -f "$ROOT_DIR/.agentic/session/WIP.md" ]; then
        echo ""
        echo -e "${YELLOW}Note: WIP tracking still active. Complete it with:${NC}"
        echo "  bash .agentic/lib/tools/wip.sh complete"
    fi

    # Worktree auto-cleanup (when worktree_mode=always and feature_id provided)
    local wt_mode
    wt_mode=$(get_setting "worktree_mode" "off")
    if [ "$wt_mode" = "always" ] && [ -n "$feature_id" ]; then
        local wt_path
        wt_path=$(bash "$SCRIPT_DIR/worktree.sh" path "$feature_id" 2>/dev/null) || wt_path=""
        if [ -n "$wt_path" ] && [ -d "$wt_path" ]; then
            echo ""
            echo -e "${BOLD}=== Worktree Cleanup ===${NC}"
            if bash "$SCRIPT_DIR/worktree.sh" auto-remove "$feature_id" 2>/dev/null; then
                echo -e "${GREEN}✓ Worktree cleaned up${NC}"
            else
                echo -e "${YELLOW}⚠ Worktree has uncommitted changes — preserved at: $wt_path${NC}"
                echo "  Clean up manually after committing/discarding changes"
            fi
        fi
    fi
    if [ -n "$feature_id" ] && is_feature_id "$feature_id"; then
        intent_checkpoint "$feature_id" "complete_wip" || true
    fi

    # Phase tracking cleanup (F-032): remove tasks.yaml after feature ships
    if [ -n "$feature_id" ] && is_feature_id "$feature_id"; then
        local _tasks_yaml="$ROOT_DIR/.agentic/work/${feature_id}/tasks.yaml"
        if [ -f "$_tasks_yaml" ]; then
            rm -f "$_tasks_yaml"
            echo -e "${GREEN}✓ Phase tracking cleaned up (tasks.yaml removed)${NC}"
        fi
    fi

    # Suggest drift detection
    echo ""
    echo -e "${BLUE}Recommended: Run drift detection${NC}"
    echo "  bash .agentic/lib/tools/drift.sh"
    echo "  (Checks: untracked files, feature status, template markers)"

    # Backlog auto-remove completed feature (by ID, regardless of position)
    if [ -n "$feature_id" ] && is_feature_id "$feature_id"; then
        # Check if feature is in the backlog at all
        if python3 "$SCRIPT_DIR/backlog_helpers.py" --project-root "$ROOT_DIR" list 2>/dev/null | grep -q "$feature_id"; then
            echo ""
            echo -e "${BOLD}=== Backlog Cleanup ===${NC}"
            if bash "$SCRIPT_DIR/backlog.sh" remove "$feature_id" 2>/dev/null; then
                echo -e "${GREEN}✓ $feature_id removed from backlog${NC}"
            else
                echo -e "${YELLOW}⚠ Could not remove $feature_id from backlog${NC}"
            fi
        fi
        intent_checkpoint "$feature_id" "advance_backlog" || true
    fi

    # VERSION bump + flush (only on main — worktrees skip this)
    local current_branch
    current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
    local _done_trunk="${AG_TRUNK_BRANCH:-}"
    if [[ -n "$_done_trunk" && "$current_branch" == "$_done_trunk" ]] \
       || [[ -z "$_done_trunk" && ("$current_branch" == "main" || "$current_branch" == "master") ]]; then
        # VERSION bump (patch by default)
        if [ -f "$ROOT_DIR/VERSION" ]; then
            local current_ver new_ver major minor patch_num
            current_ver=$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")
            if [[ "$current_ver" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                IFS='.' read -r major minor patch_num <<< "$current_ver"
                new_ver="${major}.${minor}.$((patch_num + 1))"
                echo ""
                echo -e "${BOLD}=== VERSION Bump ===${NC}"
                echo "  $current_ver → $new_ver"
                echo "$new_ver" > "$ROOT_DIR/VERSION"
                echo -e "${GREEN}✓ VERSION bumped to $new_ver${NC}"
                # Framework-dev: sync .agentic/lib/VERSION (dashboard reads this)
                if [ -f "$ROOT_DIR/FRAMEWORK_DEVELOPMENT.md" ] && [ -f "${VERSION_FILE:-}" ]; then
                    echo "$new_ver" > "$VERSION_FILE"
                fi
            else
                echo -e "${YELLOW}⚠ VERSION file format unexpected: $current_ver (skipping auto-bump)${NC}"
            fi
        fi

        # Post-merge dogfood sync BEFORE flush (framework-dev only — F-0226)
        # Runs before flush so all changes (VERSION + dogfood drift) go in
        # a single flush — important for protected mode (F-035) where each
        # flush creates a PR.
        if [ -f "$ROOT_DIR/FRAMEWORK_DEVELOPMENT.md" ]; then
            echo ""
            echo -e "${BOLD}=== Dogfood Sync ===${NC}"
            if bash "$SCRIPT_DIR/dogfood-sync.sh" --auto-fix 2>/dev/null; then
                echo -e "  ${GREEN}✓${NC} No drift detected"
            else
                echo -e "  ${YELLOW}⚠${NC} Drift detected — auto-fix attempted. Review changes."
            fi
        fi

        # Flush state files to main (or create PR in protected mode)
        echo ""
        echo -e "${BOLD}=== Flushing State ===${NC}"
        bash "$SCRIPT_DIR/state-commit.sh" --features || true

        # Protected-mode guidance (F-035)
        local _done_branch_mode
        _done_branch_mode=$(get_setting "main_branch_mode" "direct" 2>/dev/null || echo "direct")
        if [[ "$_done_branch_mode" == "protected" ]]; then
            echo -e "  ${BLUE}Note: State changes sent as PR. Merge it to complete the version bump.${NC}"
        fi
    else
        echo ""
        echo -e "${BLUE}On branch '$current_branch' — run 'ag flush --features' after returning to main.${NC}"
    fi

    # Run after-done lifecycle hook if present
    local _hook="${ROOT_DIR}/.agentic/local/extensions/hooks/after-done.sh"
    if [[ -f "$_hook" ]]; then
        echo ""
        echo -e "${BOLD}Running after-done hook...${NC}"
        (set +e; timeout 10 bash "$_hook" "$feature_id" 2>&1) || echo "  ⚠️  after-done hook failed (non-blocking)"
    fi

    # Clear intent — all steps complete
    if [ -n "$feature_id" ] && is_feature_id "$feature_id"; then
        intent_clear "$feature_id" || true
    fi

    # Show dashboard for status summary (T-0049)
    if [ -t 1 ]; then
        echo ""
        bash "$SCRIPT_DIR/dashboard.sh" 2>/dev/null || true
    fi
}
