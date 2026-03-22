#!/usr/bin/env bash
# commands/specs.sh — Spec writing and brownfield spec generation
# Sourced by ag.sh — do NOT execute directly.
# Depends on: SCRIPT_DIR, ROOT_DIR, PROFILE, color codes, paths.sh, settings.sh

cmd_spec() {
    local arg="${1:-}"

    # Advisory: backlog alignment check
    if [[ -n "$arg" ]] && is_feature_id "$arg"; then
        _backlog_advisory "$arg" "spec"
    fi

    if [[ "$arg" == "--check" ]]; then
        echo -e "${BLUE}Running spec health check on all features...${NC}"
        echo ""
        bash .agentic/lib/tools/check-spec-health.sh --all
        return
    fi

    if [[ -n "$arg" ]] && echo "$arg" | grep -qE '^(F|NFR)-[0-9]+$'; then
        echo -e "${BLUE}Spec status for $arg${NC}"
        echo ""
        bash .agentic/lib/tools/check-spec-health.sh "$arg"
        return
    fi

    # Default: print spec-writing guidance for new feature
    echo -e "${BLUE}Spec-Writing Checklist${NC}"
    echo ""
    if [[ -f ".agentic/lib/checklists/spec_writing.md" ]]; then
        cat .agentic/lib/checklists/spec_writing.md
    else
        echo "Run \`ag check\` for spec guidance, or see role prompts in .agentic/prompts/"
    fi
    echo ""
    if [[ -f ".agentic/lib/workflows/spec_writing.md" ]]; then
        echo -e "Full workflow: ${BLUE}.agentic/lib/workflows/spec_writing.md${NC}"
    fi
    echo -e "Usage: ag spec F-XXXX    (check feature)  |  ag spec --check  (check all)"
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
    local report="$ROOT_DIR/.agentic/session/discovery_report.json"
    if [ ! -f "$report" ]; then
        echo -e "${YELLOW}No discovery report found.${NC}"
        echo "Run discovery first:"
        echo "  python3 .agentic/lib/tools/discover.py --root . --output .agentic/session/discovery_report.json --profile formal"
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
    for f in "$ROOT_DIR"/.agentic/journal/plans/*-specs-plan.md; do
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
            echo "     d. Write FEATURES.md entries + .agentic/spec/contracts/F-####.yaml contract files"
            echo "     e. Ask user: 'Does this look right for [Domain]?'"
            echo "     f. Mark domain as completed: change '- [ ]' to '- [x]' in plan"
            echo "  5. After all domains: cross-domain review (duplicates, gaps)"
            echo ""
            echo "Run \`ag check\` to see next steps for spec generation."
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
    echo "  2. Create plan at: .agentic/journal/plans/brownfield-specs-plan.md"
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
    echo "Run \`ag check\` to see pipeline details."

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
        echo "  python3 .agentic/lib/tools/organize_features.py --by domain"
    fi
}

_specs_status() {
    echo -e "${BOLD}=== Brownfield Spec Status ===${NC}"
    echo ""

    local plan_file=""
    for f in "$ROOT_DIR"/.agentic/journal/plans/*-specs-plan.md; do
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
