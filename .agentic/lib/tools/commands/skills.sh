#!/usr/bin/env bash
# commands/skills.sh — Stack-matched quality skills from skills.sh marketplace (F-008)
# Sourced by ag.sh — do NOT execute directly.
# Depends on: SCRIPT_DIR, ROOT_DIR, color codes (BOLD, NC, etc.) from ag.sh
#
# PR-A of three-phase rollout. PR-B wires this into `ag init`, PR-C adds the
# STACK.md-change PostToolUse hook + instruction-file sync + LLM tests.

cmd_skills() {
    local subcmd="${1:-help}"
    shift 2>/dev/null || true

    case "$subcmd" in
        suggest|install|sync|list|remove|update-pins|request)
            python3 "$SCRIPT_DIR/skills_marketplace.py" "$subcmd" "$@"
            ;;
        help|-h|--help|"")
            cat <<'EOF'
ag skills — install stack-matched quality skills from the skills.sh marketplace

USAGE
    ag skills <subcommand> [options]

SUBCOMMANDS
    suggest                     Show skills matching current stack (no install)
    install [--all|--select ID] Install matched skills after confirm prompt
            [--accept-scripts]  Required when a skill ships executable scripts
            [--override-builtin] Install even if a built-in F-008 file covers the stack
            [--yes]             Skip confirm prompt
    sync [--dry-run]            Diff installed vs. current-stack recommendations
    list                        List installed marketplace skills
    remove <id>                 Uninstall a marketplace skill
    update-pins                 Maintainer: re-resolve HEAD shas in allowlist
    request <github-url>        Propose a new skill via templated GitHub issue

SAFETY
  * Allowlist-only (see .agentic/lib/data/skills-marketplace.yaml)
  * Mandatory sha pinning; installs refuse unpinned or seed-sha entries
  * Fetches only from raw.githubusercontent.com; honors GITHUB_TOKEN, HTTPS_PROXY
  * Scripts shipped with a skill trigger quarantine unless --accept-scripts

EXAMPLES
    ag skills suggest
    ag skills install --all
    ag skills install --select vercel-labs/agent-skills#frontend-design
    ag skills sync
    ag skills remove anthropics/skills#python-quality

See also: F-008 AC-009/010/011 (.agentic/spec/contracts/F-008.yaml)
EOF
            ;;
        *)
            echo "Unknown skills subcommand: $subcmd" >&2
            echo "Run 'ag skills help' for usage." >&2
            return 1
            ;;
    esac
}
