#!/usr/bin/env bash
# commands/commit.sh — Pre-commit gates (profile-aware)
# Sourced by ag.sh — do NOT execute directly.
# Depends on: SCRIPT_DIR, ROOT_DIR, PROFILE, color codes, paths.sh, settings.sh

cmd_commit() {
    # Gate: git must be active (F-0250)
    local git_mode
    git_mode=$(get_setting "git_mode" "active")
    if [[ "$git_mode" != "active" ]]; then
        echo -e "${YELLOW}Git not active (git_mode: ${git_mode}).${NC}"
        echo "  Run: ag git-init    to enable version control"
        echo ""
        return 0
    fi

    echo -e "${BOLD}=== Pre-Commit Gates ===${NC}"
    echo ""

    # 1. Check WIP exists (AGENTS.json, with WIP.md fallback)
    local wip_mode
    wip_mode=$(get_setting "wip_before_commit" "warning")
    if _has_active_wip || [ -f "$ROOT_DIR/.agentic/session/WIP.md" ]; then
        if [ "$wip_mode" = "warning" ]; then
            echo -e "${YELLOW}WARNING: Active WIP detected${NC}"
            echo "  Consider completing WIP: bash .agentic/lib/tools/wip.sh complete"
            echo ""
        else
            echo -e "${RED}BLOCKED: Active WIP detected${NC}"
            echo "  Work-in-progress must be completed before committing."
            echo "  Run: bash .agentic/lib/tools/wip.sh complete"
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

    # 3. Stack-specific quality checks (F-302)
    local qc_script="${ROOT_DIR}/quality_checks.sh"
    if [[ -f "$qc_script" ]]; then
        local qc_mode
        qc_mode=$(get_setting "quality_checks" "blocking")
        if [[ "$qc_mode" != "off" ]]; then
            echo "Running stack-specific quality checks..."
            if bash "$qc_script" --pre-commit 2>&1; then
                echo -e "${GREEN}Quality checks: PASS${NC}"
            else
                if [[ "$qc_mode" == "blocking" ]]; then
                    echo -e "${RED}Quality checks FAILED${NC}"
                    echo "  Fix issues above, or: ag set quality_checks advisory"
                    exit 1
                else
                    echo -e "${YELLOW}Quality checks: WARN (advisory mode)${NC}"
                fi
            fi
            echo ""
        fi
    fi

    # 4. Run doctor pre-commit checks
    local pcc
    pcc=$(get_setting "pre_commit_checks" "fast")
    echo ""
    if [ "$pcc" = "fast" ] || [ "$pcc" = "off" ]; then
        echo "Running basic checks (lightweight gates)..."
        bash "$SCRIPT_DIR/doctor.sh" --quick 2>/dev/null || true
        echo ""
        echo ""
        echo -e "${BOLD}Pre-commit artifacts check:${NC}"
        echo "   Have you updated JOURNAL.md?  (bash .agentic/lib/tools/journal.sh ...)"
        echo "   Have you updated STATUS.md?   (bash .agentic/lib/tools/status.sh ...)"
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
            if [ -f "$ROOT_DIR/.agentic/spec/FEATURES.md" ]; then
                local spec_staged
                spec_staged=$(git diff --cached --name-only 2>/dev/null | grep "^spec/" || true)
                if [ -n "$spec_staged" ]; then
                    if ! git diff --cached --name-only 2>/dev/null | grep -q "FEATURES.md"; then
                        echo ""
                        echo -e "${YELLOW}WARNING: Spec files staged but FEATURES.md not updated${NC}"
                        echo "  Staged spec files: $(echo $spec_staged | tr '\n' ' ')"
                        echo "  Update with: bash .agentic/lib/tools/feature.sh F-#### status <status>"
                    fi
                fi
            fi

            echo ""
            echo -e "${BOLD}Pre-commit artifacts check:${NC}"
            echo "   Have you updated JOURNAL.md?  (bash .agentic/lib/tools/journal.sh ...)"
            echo "   Have you updated STATUS.md?   (bash .agentic/lib/tools/status.sh ...)"
            echo ""
            echo "Ready to commit. Suggested workflow:"
            echo "  git add <files>"
            echo "  git commit -m \"feat(F-XXXX): description\""
            echo ""
            if [[ -f ".agentic/lib/checklists/before_commit.md" ]]; then
                echo -e "${BOLD}Checklist:${NC} .agentic/lib/checklists/before_commit.md"
            else
                echo -e "${BOLD}Guidance:${NC} Run \`ag check\` for pre-commit guidance"
            fi

            # Run after-commit lifecycle hook if present
            local _hook="${ROOT_DIR}/.agentic/local/extensions/hooks/after-commit.sh"
            if [[ -f "$_hook" ]]; then
                echo ""
                echo -e "${BOLD}Running after-commit hook...${NC}"
                (set +e; timeout 10 bash "$_hook" 2>&1) || echo "  ⚠️  after-commit hook failed (non-blocking)"
            fi
        else
            echo ""
            echo -e "${RED}Pre-commit gates FAILED - fix issues above${NC}"
            exit 1
        fi
    fi
}
