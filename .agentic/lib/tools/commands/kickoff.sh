#!/usr/bin/env bash
# commands/kickoff.sh — Vision-to-Backlog pipeline (F-0201)
# Sourced by ag.sh — do NOT execute directly.
# Depends on: SCRIPT_DIR, ROOT_DIR, PROFILE, color codes, paths.sh, settings.sh

cmd_kickoff() {
    local subcmd="${1:-}"
    shift 2>/dev/null || true

    local auto_dir="$SCRIPT_DIR/../auto"

    # Check feature tracking
    local ft
    ft=$(get_setting "feature_tracking" "no")
    if [ "$ft" = "no" ]; then
        echo -e "${YELLOW}Feature tracking is off — kickoff requires it.${NC}"
        echo "Enable with: ag set feature_tracking yes"
        exit 1
    fi

    case "$subcmd" in
        --review)
            # Present staging artifacts for review
            echo -e "${BOLD}=== Kickoff: Review Staging ===${NC}"
            echo ""
            local review_json
            review_json=$(python3 "$auto_dir/kickoff.py" review --project-root "$ROOT_DIR" 2>&1)
            local rc=$?
            if [ $rc -ne 0 ]; then
                echo -e "${RED}$review_json${NC}"
                exit 1
            fi

            # Pretty-print the review summary
            echo "$review_json" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(f\"Overview: {data.get('overview', '(none)')}\")
print()
features = data.get('features', [])
print(f'Features ({len(features)}):')
for i, f in enumerate(features):
    deps = ', '.join(f.get('dependencies', [])) or 'none'
    print(f\"  [{i}] {f['id']}: {f['name']} ({f['ac_count']} ACs, deps: {deps})\")
print()
order = data.get('backlog_order', [])
print(f'Backlog order: {\" → \".join(order)}')
print()
v = data.get('validation', {})
if v.get('valid'):
    print('Validation: PASS')
else:
    print('Validation: FAIL')
    for e in v.get('errors', []):
        print(f'  - {e}')
"
            # Display NFR suggestions if present in staging
            local staging_nfr="$ROOT_DIR/.agentic/session/kickoff-draft/NFR-SUGGESTIONS.md"
            if [ -f "$staging_nfr" ]; then
                echo ""
                echo -e "${BOLD}NFR Suggestions:${NC}"
                cat "$staging_nfr"
            fi

            echo ""
            echo -e "${BOLD}AGENT INSTRUCTION:${NC}"
            echo "Present the above to the user. They can:"
            echo "  - Edit: 'merge F-NEW-001 into F-NEW-002', 'rename F-NEW-003 to Auth'"
            echo "  - Reorder: 'put auth first'"
            echo "  - Add/remove: 'add a feature for notifications', 'remove F-NEW-004'"
            echo "  - Approve: 'ag kickoff --approve'"
            echo "  - Discard: 'ag kickoff --discard'"
            echo ""
            echo "After edits, run 'ag kickoff --review' again to re-validate."
            ;;
        --approve)
            # Promote staging to real spec files
            echo -e "${BOLD}=== Kickoff: Approve & Promote ===${NC}"
            echo ""

            # Check review_decomposition gate
            local review_mode
            review_mode=$(get_setting "review_decomposition" "skip")
            if [ "$review_mode" = "human" ]; then
                echo -e "${YELLOW}Review gate: review_decomposition = human${NC}"
                echo "Ensure you have reviewed with 'ag kickoff --review' first."
                echo ""
            fi

            local force_flag=""
            if [ "${1:-}" = "--force" ]; then
                force_flag="--force"
            fi

            python3 "$auto_dir/kickoff.py" promote $force_flag --project-root "$ROOT_DIR"
            local rc=$?
            if [ $rc -eq 0 ]; then
                echo ""
                echo -e "${GREEN}Kickoff complete!${NC}"
                echo ""
                echo -e "${BOLD}AGENT INSTRUCTION:${NC}"
                echo "Suggest next steps:"
                echo "  - 'ag auto epic F-XXXX' to implement features autonomously"
                echo "  - 'ag implement F-XXXX' to implement one feature at a time"
                echo "  - 'ag backlog list' to see the ordered queue"
            fi
            return $rc
            ;;
        --discard)
            python3 "$auto_dir/kickoff.py" discard --project-root "$ROOT_DIR"
            ;;
        --status)
            python3 "$auto_dir/kickoff.py" status --project-root "$ROOT_DIR"
            ;;
        --interview)
            echo -e "${YELLOW}Interview mode is not yet available (deferred to child feature).${NC}"
            echo "Use script mode instead: ag kickoff \"your vision here\""
            exit 1
            ;;
        --help|"")
            echo "ag kickoff - Vision-to-Backlog pipeline (F-0201)"
            echo ""
            echo "COMMANDS:"
            echo "  ag kickoff \"prompt\"       Generate features from vision (script mode)"
            echo "    --style FILE             Optional style/taste reference"
            echo "    --research FILE          Optional research/context reference"
            echo "    --no-confirm             Skip confirmation checkpoints"
            echo "  ag kickoff --review        Review staging artifacts"
            echo "  ag kickoff --approve       Validate & promote to real spec files"
            echo "    --force                  Overwrite existing OVERVIEW.md"
            echo "  ag kickoff --discard       Remove staging (start over)"
            echo "  ag kickoff --status        Show staging state (JSON)"
            echo "  ag kickoff --interview     (deferred) Multi-turn dialogue mode"
            echo ""
            echo "SETTINGS:"
            echo "  kickoff_confirm: ask|skip  Confirmation checkpoints (profile default)"
            echo "  review_decomposition       Promotion gate (human|critical_agent|skip)"
            echo ""
            echo "FLOW: ag kickoff → ag kickoff --review → iterate → ag kickoff --approve"
            ;;
        *)
            # Script mode: treat subcmd as the prompt
            local prompt="$subcmd"
            if [ -n "${1:-}" ]; then
                prompt="$prompt $*"
            fi

            # Check if staging already exists
            local status_json
            status_json=$(python3 "$auto_dir/kickoff.py" status --project-root "$ROOT_DIR" 2>&1)
            local exists
            exists=$(echo "$status_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('exists',False))" 2>/dev/null || echo "False")
            if [ "$exists" = "True" ]; then
                echo -e "${RED}Staging area already exists.${NC}"
                echo "  Review: ag kickoff --review"
                echo "  Discard: ag kickoff --discard"
                exit 1
            fi

            echo -e "${BOLD}=== Kickoff: Generate from Vision ===${NC}"
            echo ""

            # Get confirmation setting
            local confirm_mode
            confirm_mode=$(get_setting "kickoff_confirm" "ask")

            # Parse flags
            local style_file="" research_file="" no_confirm=false
            local remaining_args=()
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --style) style_file="$2"; shift 2 ;;
                    --research) research_file="$2"; shift 2 ;;
                    --no-confirm) no_confirm=true; shift ;;
                    *) remaining_args+=("$1"); shift ;;
                esac
            done

            if [ "$no_confirm" = true ]; then
                confirm_mode="skip"
            fi

            # Intent tracking
            intent_write "kickoff" "planned" "kickoff" "generate,review,validate,promote" "" || true

            # Print structured agent instructions
            echo -e "${BOLD}AGENT INSTRUCTION:${NC}"
            echo "You are running 'ag kickoff' in script mode."
            echo ""
            echo "VISION PROMPT:"
            echo "  $prompt"
            echo ""
            if [ -n "$style_file" ]; then
                echo "STYLE REFERENCE: $style_file"
                echo "  Read this file for taste/aesthetic preferences."
                echo ""
            fi
            if [ -n "$research_file" ]; then
                echo "RESEARCH REFERENCE: $research_file"
                echo "  Read this file for domain context."
                echo ""
            fi
            echo "CONFIRMATION MODE: $confirm_mode"
            if [ "$confirm_mode" = "ask" ]; then
                echo "  Pause at two checkpoints:"
                echo "  1. After parsing vision: 'I see [summary]. Correct direction?'"
                echo "  2. Before generating: 'I'll create N features: [list]. Proceed?'"
            else
                echo "  Skip confirmation checkpoints — generate directly."
            fi
            echo ""
            echo "TASK:"
            echo "  1. Parse the vision prompt into structured features"
            echo "  2. For each feature, define: name, description, acceptance criteria"
            echo "  3. Call kickoff.py to generate staging artifacts:"
            echo "     python3 $auto_dir/kickoff.py generate \\"
            echo "       --features-json '<JSON>' \\"
            echo "       --overview '<text>' \\"
            echo "       --project-root '$ROOT_DIR'"
            echo ""
            echo "  features_data format: [{\"name\": \"...\", \"description\": \"...\","
            echo "    \"criteria\": [\"...\"], \"dependencies\": [\"...\"]}]"
            echo ""
            echo "  4. After generation: run 'ag kickoff --review' to present to user"
            echo "  5. Iterate based on user feedback"
            echo "  6. When user approves: 'ag kickoff --approve'"
            echo ""
            echo "CONTEXT FILES TO READ:"
            echo "  - CONTEXT_PACK.md (project context)"
            echo "  - STACK.md (tech stack, constraints)"
            if [ -f "$ROOT_DIR/.agentic/spec/NFR.md" ]; then
                echo "  - .agentic/spec/NFR.md (non-functional requirements)"
            fi

            # NFR auto-generation: capture suggestions and write to staging (AC-008, AC-009)
            local nfr_suggestions=""
            nfr_suggestions=$(bash "$SCRIPT_DIR/nfr-generate.sh" --limit 8 2>/dev/null || true)
            if [ -n "$nfr_suggestions" ]; then
                local staging_dir="$ROOT_DIR/.agentic/session/kickoff-draft"
                mkdir -p "$staging_dir"
                echo "$nfr_suggestions" > "$staging_dir/NFR-SUGGESTIONS.md"
                echo ""
                echo "NFR SUGGESTIONS (auto-generated, saved to staging):"
                echo "$nfr_suggestions"
                echo ""
                echo "These NFR suggestions are saved at $staging_dir/NFR-SUGGESTIONS.md"
                echo "After features are generated, present these to the user for review."
                echo "To write selected NFRs: bash $SCRIPT_DIR/nfr-generate.sh --machine --limit 8 | bash $SCRIPT_DIR/nfr-write-batch.sh"
            fi
            ;;
    esac
}
