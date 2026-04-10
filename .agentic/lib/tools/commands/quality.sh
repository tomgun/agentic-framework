#!/usr/bin/env bash
# commands/quality.sh — Stack-specific quality profile management (F-008)
# Sourced by ag.sh — do NOT execute directly.
# Depends on: SCRIPT_DIR, ROOT_DIR, PROFILE, color codes, paths.sh, settings.sh

cmd_quality() {
    local subcmd="${1:-help}"
    shift 2>/dev/null || true

    case "$subcmd" in
        setup)
            echo -e "${BOLD}=== Quality Profile Setup ===${NC}"
            echo ""

            local dry_run=""
            local force=""
            for arg in "$@"; do
                case "$arg" in
                    --dry-run) dry_run="--dry-run" ;;
                    --force) force="--force" ;;
                esac
            done

            bash "$SCRIPT_DIR/generate-quality-profile.sh" \
                --root "$ROOT_DIR" $dry_run $force

            echo ""
            if [[ -z "$dry_run" ]]; then
                # Show enforcement setting
                local qc_setting
                qc_setting=$(get_setting "quality_checks" "blocking")
                echo -e "  Enforcement: ${BOLD}${qc_setting}${NC}"
                echo "  Change with: ag set quality_checks advisory"
                echo ""
                echo "  Run checks:  ag quality run"
                echo "  Full suite:  ag quality run --full"
            fi
            ;;

        run)
            local mode="${1:---pre-commit}"
            local qc_script="${ROOT_DIR}/quality_checks.sh"

            if [[ ! -f "$qc_script" ]]; then
                echo -e "${YELLOW}No quality_checks.sh found.${NC}"
                echo "  Run: ag quality setup"
                return 1
            fi

            echo -e "${BOLD}=== Quality Checks ($mode) ===${NC}"
            echo ""
            bash "$qc_script" "$mode"
            ;;

        status)
            python3 "$SCRIPT_DIR/quality_profile_generator.py" \
                --root "$ROOT_DIR" --status 2>/dev/null || {
                echo "Quality profile status requires Python 3."
                return 1
            }
            ;;

        help|*)
            echo "Usage: ag quality <subcommand>"
            echo ""
            echo "  setup [--dry-run] [--force]  Generate quality profile from detected stack"
            echo "  run [--pre-commit|--full]     Run quality checks"
            echo "  status                        Show quality profile status"
            ;;
    esac
}
