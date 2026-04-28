#!/usr/bin/env bash
# commands/hooks.sh — `ag hooks` git + Claude Code hook management.
# Sourced by ag.sh. Depends on: ROOT_DIR, color codes (RED/GREEN/YELLOW/BOLD/NC/DIM).
#
# History:
#   * `install` / `status` / `disable` — F-0300 era; uses `core.hooksPath`
#     redirection to .agentic/hooks/ so the same dispatcher serves agent +
#     CI runs.
#   * `register` / `unregister` — R-015. Writes Tier 0 shim hooks directly
#     to .git/hooks/pre-commit and .git/hooks/pre-push. Each shim is a
#     thin launcher that execs the Python gate. Idempotent: re-running
#     against an unchanged repo is a no-op (verified via the integrity
#     baseline). Existing hooks are backed up under .git/hooks/.backup-<ts>/
#     so `unregister` can restore the prior state.
#
# `register` and `install` are different transports for the same goal:
#   * `register` is the lower-friction local default — direct shims, no
#     git config required, immediately visible via `ls .git/hooks/`.
#   * `install` keeps shared-repo workflows centred on .agentic/hooks/ via
#     `core.hooksPath` (every clone enables hooks the same way).
# Pick whichever fits the project; both are safe to switch between.

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_hooks_require_git_repo() {
    if ! command -v git >/dev/null 2>&1 || ! git rev-parse --git-dir >/dev/null 2>&1; then
        echo -e "${RED}Error: Not a git repository.${NC}" >&2
        return 1
    fi
}

_hooks_dir() {
    # R-015 AC1 mandates `.git/hooks/pre-commit` and `.git/hooks/pre-push`
    # literally. Always resolves to .git/hooks/ — projects that want the
    # `core.hooksPath` redirection use `ag hooks install` (F-0300)
    # instead, which is the dedicated transport for that workflow.
    printf '%s/.git/hooks\n' "$ROOT_DIR"
}

_hooks_shim_pre_commit() {
    cat <<'EOF'
#!/usr/bin/env bash
# Tier 0 pre-commit gate (R-001) — fires regardless of which agent runs in
# any session. The gate logic lives in Python; this shim is just a launcher.
set -e
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
exec python3 "$ROOT/.agentic/lib/hooks/precommit_gate.py" "$@"
EOF
}

_hooks_shim_pre_push() {
    cat <<'EOF'
#!/usr/bin/env bash
# Tier 0 pre-push gate (R-002) — second-wall enforcement when the local
# range is about to leave the repo. Runs in a separate process from the
# agent session, so the agent does not control invocation.
set -e
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
exec python3 "$ROOT/.agentic/lib/hooks/prepush_gate.py" "$@"
EOF
}

# Compare a target file's contents against the shim text on stdin.
# Returns 0 when they match (idempotent path), 1 otherwise. `diff -q -`
# tells diff to read its first input from stdin directly — the canonical
# bash idiom (avoids `<(cat)` process-substitution gymnastics).
_hooks_shim_matches() {
    local target="$1"
    [ -f "$target" ] || return 1
    diff -q - "$target" >/dev/null 2>&1
}

# Returns 0 iff both Tier 0 shims already match the canonical text. Used
# by callers (e.g. cmd_init) that want to silently skip register when the
# repo is already armed.
_hooks_already_registered() {
    local hooks_dir
    hooks_dir="$(_hooks_dir)"
    _hooks_shim_pre_commit | _hooks_shim_matches "$hooks_dir/pre-commit" || return 1
    _hooks_shim_pre_push   | _hooks_shim_matches "$hooks_dir/pre-push"   || return 1
    return 0
}

# Timestamp + PID + monotonic counter — guarantees uniqueness even if two
# `register` calls fire within the same second under the same shell.
_hooks_backup_dir() {
    local seq=${_HOOKS_BACKUP_SEQ:-0}
    _HOOKS_BACKUP_SEQ=$((seq + 1))
    printf '%s/.git/hooks/.backup-%s-%s-%s\n' \
        "$ROOT_DIR" \
        "$(date -u +%Y%m%d-%H%M%S)" \
        "$$" \
        "$_HOOKS_BACKUP_SEQ"
}

# Atomic write: stage to a sibling temp file, then mv into place. A crash
# mid-write leaves the prior shim (or no file) intact rather than a
# truncated-and-empty one.
_hooks_write_shim_atomic() {
    local target="$1"
    local tmp
    tmp="${target}.tmp.$$"
    if cat > "$tmp"; then
        chmod +x "$tmp"
        mv -f "$tmp" "$target"
    else
        rm -f "$tmp"
        return 1
    fi
}

# ---------------------------------------------------------------------------
# register / unregister (R-015)
# ---------------------------------------------------------------------------

_hooks_register() {
    _hooks_require_git_repo || return 1

    local hooks_dir
    hooks_dir="$(_hooks_dir)"
    mkdir -p "$hooks_dir"

    local pc="$hooks_dir/pre-commit"
    local pp="$hooks_dir/pre-push"

    local pc_matches=1 pp_matches=1
    _hooks_shim_pre_commit | _hooks_shim_matches "$pc" && pc_matches=0
    _hooks_shim_pre_push   | _hooks_shim_matches "$pp" && pp_matches=0

    if [ $pc_matches -eq 0 ] && [ $pp_matches -eq 0 ]; then
        echo -e "${GREEN}✓ Hooks already registered (no changes needed).${NC}"
        echo -e "  ${DIM}pre-commit and pre-push shims match the canonical R-001/R-002 launchers.${NC}"
        # Re-run integrity in case the user touched gate scripts but not the
        # shims. `ag integrity update` no-ops if nothing drifted.
        cmd_integrity update >/dev/null 2>&1 || true
        return 0
    fi

    # Backup any existing-but-divergent hooks so unregister can restore.
    local backup
    backup="$(_hooks_backup_dir)"
    local backed_up_any=0
    for src in "$pc" "$pp"; do
        if [ -f "$src" ]; then
            if [ $backed_up_any -eq 0 ]; then mkdir -p "$backup"; fi
            cp -p "$src" "$backup/"
            backed_up_any=1
        fi
    done

    _hooks_shim_pre_commit | _hooks_write_shim_atomic "$pc"
    _hooks_shim_pre_push   | _hooks_write_shim_atomic "$pp"

    echo -e "${GREEN}✓ Registered Tier 0 hook shims:${NC}"
    echo -e "  • ${pc#$ROOT_DIR/}"
    echo -e "  • ${pp#$ROOT_DIR/}"
    if [ $backed_up_any -eq 1 ]; then
        echo -e "  ${DIM}(prior hooks moved to ${backup#$ROOT_DIR/}/ — \`ag hooks unregister\` restores)${NC}"
    fi

    # AC3 — refresh integrity baseline so the new shims are recognised.
    if cmd_integrity update >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Integrity baseline updated (R-004).${NC}"
    else
        echo -e "${YELLOW}⚠ Integrity baseline update skipped (run \`ag integrity update\` manually if needed).${NC}"
    fi
}

_hooks_unregister() {
    _hooks_require_git_repo || return 1

    local hooks_dir
    hooks_dir="$(_hooks_dir)"
    local pc="$hooks_dir/pre-commit"
    local pp="$hooks_dir/pre-push"

    # Find the most recent backup; if none, just remove the shims.
    local last_backup
    last_backup=$(ls -1d "$ROOT_DIR/.git/hooks/.backup-"* 2>/dev/null | sort | tail -n1 || true)

    local restored=0 removed=0
    if [ -n "$last_backup" ] && [ -d "$last_backup" ]; then
        for hook in pre-commit pre-push; do
            if [ -f "$last_backup/$hook" ]; then
                cp -p "$last_backup/$hook" "$hooks_dir/$hook"
                chmod +x "$hooks_dir/$hook"
                restored=$((restored + 1))
            elif [ -f "$hooks_dir/$hook" ]; then
                rm -f "$hooks_dir/$hook"
                removed=$((removed + 1))
            fi
        done
        echo -e "${GREEN}✓ Restored from ${last_backup#$ROOT_DIR/}/${NC} ($restored restored, $removed removed)."
    else
        for hook in pre-commit pre-push; do
            if [ -f "$hooks_dir/$hook" ]; then
                rm -f "$hooks_dir/$hook"
                removed=$((removed + 1))
            fi
        done
        echo -e "${YELLOW}⚠ No backup found.${NC} $removed shim(s) removed; nothing to restore."
    fi

    # Design choice: the integrity baseline tracks **current ground truth**,
    # not the canonical Tier 0 state. After unregister the baseline will
    # reflect whatever was restored (third-party Husky hook, empty file,
    # absence). R-004's job is "detect changes from the recorded state",
    # so re-registering is the supported way to return to a known-good
    # signature — not "unregister leaves Tier 0 baseline frozen". Keeping
    # baseline == filesystem keeps the two layers in sync; agents that
    # tamper post-unregister still trip the integrity check on their
    # next commit.
    cmd_integrity update >/dev/null 2>&1 || true
}

# ---------------------------------------------------------------------------
# Existing subcommands (install / status / disable, F-0300)
# ---------------------------------------------------------------------------

_hooks_install() {
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
        if [[ -f "$hooks_target" ]] && diff -q "$hooks_source" "$hooks_target" >/dev/null 2>&1; then
            echo -e "${GREEN}✓ Claude hooks: verified (.claude/hooks.json — already up to date)${NC}"
        else
            cp "$hooks_source" "$hooks_target"
            echo -e "${GREEN}✓ Claude hooks: installed (.claude/hooks.json)${NC}"
            echo -e "${YELLOW}  ⚠ Restart Claude Code to activate hooks.${NC}"
        fi
        installed_any=true
    else
        echo -e "${YELLOW}⚠ Claude hooks: source not found (.agentic/lib/claude-hooks/hooks.json)${NC}"
    fi

    if [[ "$installed_any" == "false" ]]; then
        echo -e "${RED}✗ No hooks installed${NC}"
        return 1
    fi
}

_hooks_status() {
    echo "Hook Status"
    echo "━━━━━━━━━━━"

    # Git hooks (core.hooksPath form, F-0300)
    echo ""
    echo "Git hooks (pre-commit, F-0300 / core.hooksPath):"
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
            echo -e "  ${DIM}— core.hooksPath not configured (R-015 register may still have written .git/hooks/* directly)${NC}"
        fi
    else
        echo -e "  ${YELLOW}⚠ N/A${NC} (not a git repository — git_mode may be deferred)"
    fi

    # Tier 0 shim status (R-015 register form)
    echo ""
    echo "Tier 0 shim hooks (R-015 / direct .git/hooks/):"
    if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
        local hooks_dir pc_status pp_status
        hooks_dir="$(_hooks_dir)"
        pc_status="${RED}✗ missing${NC}"
        pp_status="${RED}✗ missing${NC}"
        if _hooks_shim_pre_commit | _hooks_shim_matches "$hooks_dir/pre-commit"; then
            pc_status="${GREEN}✓ canonical${NC}"
        elif [ -f "$hooks_dir/pre-commit" ]; then
            pc_status="${YELLOW}⚠ custom (not the R-001 shim)${NC}"
        fi
        if _hooks_shim_pre_push | _hooks_shim_matches "$hooks_dir/pre-push"; then
            pp_status="${GREEN}✓ canonical${NC}"
        elif [ -f "$hooks_dir/pre-push" ]; then
            pp_status="${YELLOW}⚠ custom (not the R-002 shim)${NC}"
        fi
        echo -e "  pre-commit : $pc_status"
        echo -e "  pre-push   : $pp_status"
        local backups
        backups=$(ls -1d "$ROOT_DIR/.git/hooks/.backup-"* 2>/dev/null | wc -l | tr -d ' ')
        if [ "$backups" -gt 0 ]; then
            echo -e "  ${DIM}backups available: $backups${NC}"
        fi
    fi

    # Claude Code hooks (F-0300)
    echo ""
    echo "Claude Code hooks (enforcement):"
    local claude_hooks="$ROOT_DIR/.claude/hooks.json"
    local hooks_source="$ROOT_DIR/.agentic/lib/claude-hooks/hooks.json"
    if [[ -f "$claude_hooks" ]]; then
        echo -e "  ${GREEN}✓ INSTALLED${NC}: .claude/hooks.json"
        if command -v python3 >/dev/null 2>&1; then
            python3 "$ROOT_DIR/.agentic/lib/auto/init.py" \
                --hooks-status --project-root "$ROOT_DIR" 2>/dev/null \
                | grep "^  " || true
        fi
    elif [[ -f "$hooks_source" ]]; then
        echo -e "  ${RED}✗ NOT INSTALLED${NC}: .claude/hooks.json missing"
        echo "  Source exists at .agentic/lib/claude-hooks/hooks.json"
        echo "  Run: ag hooks install"
    else
        echo -e "  ${YELLOW}⚠ N/A${NC}: no hook source found"
    fi
}

_hooks_disable() {
    local flag="${1:-}"
    if [ "$flag" != "--confirm" ]; then
        echo -e "${RED}WARNING: This disables all pre-commit quality gates.${NC}"
        echo ""
        echo "Commits will no longer be checked for:"
        echo "  - WIP lock, journal/status freshness, complexity limits"
        echo "  - Branch policy, spec validation, test execution"
        echo ""
        echo "To proceed: ag hooks disable --confirm"
        return 1
    fi
    if ! command -v git >/dev/null 2>&1 || ! git rev-parse --git-dir >/dev/null 2>&1; then
        echo -e "${RED}Error: Not a git repository${NC}"
        return 1
    fi
    git config --unset core.hooksPath 2>/dev/null || true
    echo -e "${YELLOW}Hooks disabled: core.hooksPath unset${NC}"
    echo "  Re-enable with: ag hooks install (or ag hooks register)"
}

_hooks_help() {
    echo -e "${BOLD}ag hooks${NC} — git + Claude Code hook management"
    echo ""
    echo "  register             Write Tier 0 shims to .git/hooks/pre-commit + pre-push"
    echo "                       and refresh the integrity baseline (R-015). Idempotent."
    echo "  unregister           Remove the shims; restore the most recent backup if any."
    echo "  install              Install via core.hooksPath = .agentic/hooks/ (F-0300)."
    echo "  status               Show current hook configuration (shim form + core.hooksPath form)."
    echo "  disable --confirm    Unset core.hooksPath (does NOT remove shims; use unregister for that)."
}

# ---------------------------------------------------------------------------
# Public dispatcher
# ---------------------------------------------------------------------------

cmd_hooks() {
    local subcmd="${1:-}"
    local flag="${2:-}"

    case "$subcmd" in
        register)               _hooks_register ;;
        unregister)             _hooks_unregister ;;
        install)                _hooks_install ;;
        status)                 _hooks_status ;;
        disable)                _hooks_disable "$flag" ;;
        help|--help|-h|"")      _hooks_help ;;
        *)
            echo -e "${RED}Unknown hooks subcommand: $subcmd${NC}" >&2
            _hooks_help
            return 1
            ;;
    esac
}
