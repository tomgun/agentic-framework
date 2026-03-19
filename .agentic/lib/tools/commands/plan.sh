#!/usr/bin/env bash
# commands/plan.sh — Plan command with iterative review
# Sourced by ag.sh — do NOT execute directly.
# Depends on: SCRIPT_DIR, ROOT_DIR, PROFILE, color codes, paths.sh, settings.sh

cmd_plan() {
    local feature_id="${1:-}"
    local no_review=false

    # Handle --save subcommand: ag plan --save <source-file> F-XXXX
    if [ "$feature_id" = "--save" ]; then
        local source_file="${2:-}"
        local save_fid="${3:-}"
        if [ -z "$source_file" ] || [ -z "$save_fid" ]; then
            echo -e "${RED}Usage: ag plan --save <source-file> F-XXXX${NC}"
            echo "  Copies a plan to .agentic/journal/plans/YYYY-MM-DD-F-XXXX-plan.md"
            exit 1
        fi
        if [ ! -f "$source_file" ]; then
            echo -e "${RED}Error: Source file not found: $source_file${NC}"
            exit 1
        fi
        local dest_dir="$ROOT_DIR/.agentic/journal/plans"
        mkdir -p "$dest_dir"
        local dest_name
        dest_name=$(_plan_filename "$save_fid")
        cp "$source_file" "$dest_dir/$dest_name"
        echo -e "${GREEN}Plan saved: $dest_dir/$dest_name${NC}"
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
    if ! is_feature_id "$feature_id"; then
        echo -e "${RED}Error: Invalid feature ID format. Expected: F-XXXX (e.g., F-0042)${NC}"
        exit 1
    fi

    echo -e "${BOLD}=== Plan: $feature_id ===${NC}"
    echo ""

    # 0. Advisory: backlog alignment check
    _backlog_advisory "$feature_id" "plan"

    # 0a. Check feature exists in FEATURES.md (BLOCKING)
    if [ "${SKIP_SPEC_CHECK:-}" = "1" ]; then
        echo -e "${YELLOW}⚠ SKIP_SPEC_CHECK: Bypassing spec-first gate${NC}"
    else
        local features_file="$ROOT_DIR/.agentic/spec/FEATURES.md"
        if [ -f "$features_file" ]; then
            if grep -q "^## ${feature_id}:" "$features_file"; then
                echo -e "${GREEN}Feature registered: YES${NC}"
            else
                echo -e "${RED}BLOCKED: ${feature_id} not found in FEATURES.md${NC}"
                echo "  Add it first: add an entry to .agentic/spec/FEATURES.md"
                echo "  Or bypass: SKIP_SPEC_CHECK=1 ag plan $feature_id"
                exit 1
            fi
        fi
    fi

    # 1. Check acceptance criteria (advisory for plan, blocking for implement)
    local acc_file="$ROOT_DIR/.agentic/spec/acceptance/${feature_id}.md"
    if [ ! -f "$acc_file" ]; then
        echo -e "${YELLOW}Note: No acceptance criteria yet (.agentic/spec/acceptance/${feature_id}.md)${NC}"
        echo "  The plan-review loop can help define what to build."
        echo "  Acceptance criteria will be required before 'ag implement'."
        echo ""
    else
        echo -e "${GREEN}Acceptance criteria: EXISTS${NC}"
    fi

    # 2. Check for existing plan
    mkdir -p "$ROOT_DIR/.agentic/journal/plans"
    local plan_file
    plan_file=$(_find_plan_file "$feature_id" || echo "")

    if [ -n "$plan_file" ] && [ -f "$plan_file" ]; then
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
        echo "  - .agentic/spec/acceptance/${feature_id}.md"
        echo "  - CONTEXT_PACK.md"
        echo ""
        echo "Write plan to: .agentic/journal/plans/$(date +%Y-%m-%d)-${feature_id}-plan.md"
        echo "Follow format in: .agentic/lib/workflows/plan_review_loop.md"
        echo "Set status to: APPROVED (no review)"
        return 0
    fi

    # 4. Show plan-review loop instructions (dialectical: critic + advocate)
    echo -e "${GREEN}Review loop: ENABLED (max $max_iterations iterations)${NC}"
    echo ""
    echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}PLAN-REVIEW LOOP INSTRUCTIONS${NC}"
    echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "This feature uses iterative planning with dialectical review."
    echo "Each iteration: Planner → Critic + Advocate (fresh context) → Synthesis → User decides."
    echo ""
    echo -e "${BLUE}STEP 1: PLANNER creates/revises plan${NC}"
    echo "  Agent tool:"
    echo "    subagent_type: Plan"
    echo "    prompt: \"Create implementation plan for $feature_id."
    echo "            Read: .agentic/spec/acceptance/${feature_id}.md, CONTEXT_PACK.md"
    echo "            Write to: .agentic/journal/plans/$(date +%Y-%m-%d)-${feature_id}-plan.md"
    echo "            Follow: .agentic/lib/workflows/plan_review_loop.md\""
    echo ""
    echo -e "${BLUE}STEP 2: CRITIC + ADVOCATE review in parallel (fresh context)${NC}"
    echo "  Spawn TWO agents IN PARALLEL with FRESH CONTEXT:"
    echo ""
    echo "  CRITIC (adversarial — find flaws):"
    echo "    Agent tool:"
    echo "      subagent_type: general-purpose"
    echo "      prompt: \"You are a PLAN CRITIC with fresh context."
    echo "              Read plan: .agentic/journal/plans/*${feature_id}-plan.md (glob — file has date prefix)"
    echo "              Read requirements: .agentic/spec/acceptance/${feature_id}.md"
    echo "              Follow: .agentic/lib/agents/claude/subagents/plan-critic-agent.md"
    echo "              Output your structured critique.\""
    echo ""
    echo "  ADVOCATE (defensive — explain trade-offs):"
    echo "    Agent tool:"
    echo "      subagent_type: general-purpose"
    echo "      prompt: \"You are a PLAN ADVOCATE with fresh context."
    echo "              Read plan: .agentic/journal/plans/*${feature_id}-plan.md (glob — file has date prefix)"
    echo "              Read requirements: .agentic/spec/acceptance/${feature_id}.md"
    echo "              Follow: .agentic/lib/agents/claude/subagents/plan-advocate-agent.md"
    echo "              Output your structured defense.\""
    echo ""
    echo -e "${BLUE}STEP 3: SYNTHESIZE and present to user${NC}"
    echo "  Synthesize both perspectives (see .agentic/lib/workflows/dialectical_review.md)"
    echo "  Include Revision Guidance section."
    echo "  Present inline. User chooses: Proceed | Revise | Reject"
    echo ""
    echo -e "${BLUE}STEP 4: Iterate or proceed${NC}"
    echo "  - Proceed: Set plan status to APPROVED. Ready for 'ag implement $feature_id'"
    echo "  - Revise: Planner revises based on user direction + synthesis guidance."
    echo "            Fresh Critic + Advocate run again on revised plan (new iteration)."
    echo "  - Reject: Abandon plan. Start over or escalate to human."
    echo "  - At max $max_iterations iterations: suggest human escalation (advisory)."
    echo ""
    echo -e "${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "Plan artifact: .agentic/journal/plans/YYYY-MM-DD-${feature_id}-plan.md"
    echo "Review mechanism: .agentic/lib/workflows/dialectical_review.md"
    echo "Full workflow: .agentic/lib/workflows/plan_review_loop.md"
    echo ""
}
