#!/usr/bin/env bash
# commands/fix.sh — `ag fix` hotfix-mode commit (R-010).
# Sourced by ag.sh. Depends on: ROOT_DIR, color codes.

cmd_fix() {
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || -z "${1:-}" ]]; then
        cat <<EOF
${BOLD}ag fix "<short-message>"${NC} — hotfix mode commit (R-010)

  Skips spec/contract-existence and plan-approval checks. Still requires:
    • integrity baseline match (R-004)
    • test command (if STACK.md test_command is set)
    • journal freshness (formal+ profiles)
    • shipped-contract migration entry (if a shipped contract was touched)

  Usage:
    ag fix "log offer staleness"           # commit staged changes as hotfix
    ag fix "log offer staleness" -- file1  # forward extra args to git commit

  Every passing hotfix commit emits a 'hotfix_commit' event with the reason
  to .agentic/journal/events.jsonl. The commit message gains a [hotfix] tag
  in the footer so the audit trail is greppable.

  This is for emergencies. If you're using it more than rarely, the affected
  feature probably needs a real spec — not a fix. See FRAMEWORK_DEVELOPMENT.md.
EOF
        return 0
    fi

    local reason="$1"
    shift

    # Forward any remaining args to git commit (e.g., specific file paths).
    local -a extra_args=("$@")

    # Gate: git must be active.
    local git_mode
    git_mode=$(get_setting "git_mode" "active")
    if [[ "$git_mode" != "active" ]]; then
        echo -e "${YELLOW}Git not active (git_mode: ${git_mode}).${NC}"
        echo "  Run: ag git-init    to enable version control"
        return 0
    fi

    # Breadcrumb so the gate (R-001 AC6) recognizes this as a sanctioned commit.
    mkdir -p "$ROOT_DIR/.agentic/session"
    printf 'invoked-via-ag\n' > "$ROOT_DIR/.agentic/session/.gate-invoked-via-ag"

    # Compose commit message: subject + [hotfix] footer.
    local message
    message="fix: ${reason}

[hotfix]"

    echo -e "${YELLOW}=== ag fix — hotfix mode ===${NC}"
    echo -e "${DIM}reason: ${reason}${NC}"
    echo -e "${DIM}AGENT_FIX_MODE=1 — pre-commit will skip spec/plan checks but still run tests${NC}"
    echo ""

    AGENT_FIX_MODE=1 \
    AGENT_FIX_REASON="$reason" \
    git commit -m "$message" "${extra_args[@]}"
}
