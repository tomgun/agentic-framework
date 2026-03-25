#!/usr/bin/env bash
# commands/phase.sh — Multi-session plan phase tracking (F-032)
# Sourced by ag.sh — do NOT execute directly.
# Depends on: SCRIPT_DIR, ROOT_DIR, AGENTIC_LIB, color codes, paths.sh, settings.sh

cmd_phase() {
    local subcmd="${1:-}"
    shift 2>/dev/null || true

    case "$subcmd" in
        list)
            local feature_id="${1:-}"
            if [ -z "$feature_id" ]; then
                echo -e "${RED}Usage: ag phase list F-XXXX${NC}"
                exit 1
            fi
            PYTHONPATH="$AGENTIC_LIB" python3 "$AGENTIC_LIB/auto/phases.py" \
                --project-root "$ROOT_DIR" list "$feature_id"
            ;;
        done)
            local feature_id="${1:-}"
            local phase_id="${2:-}"
            if [ -z "$feature_id" ] || [ -z "$phase_id" ]; then
                echo -e "${RED}Usage: ag phase done F-XXXX <phase_id>${NC}"
                exit 1
            fi
            if PYTHONPATH="$AGENTIC_LIB" python3 "$AGENTIC_LIB/auto/phases.py" \
                --project-root "$ROOT_DIR" update "$feature_id" "$phase_id" complete; then
                echo -e "${GREEN}✓ Phase $phase_id marked complete${NC}"
                # Show updated progress
                PYTHONPATH="$AGENTIC_LIB" python3 "$AGENTIC_LIB/auto/phases.py" \
                    --project-root "$ROOT_DIR" progress "$feature_id" 2>/dev/null || true
            else
                echo -e "${RED}Failed to mark phase $phase_id as complete${NC}"
                exit 1
            fi
            ;;
        active)
            local feature_id="${1:-}"
            local phase_id="${2:-}"
            if [ -z "$feature_id" ] || [ -z "$phase_id" ]; then
                echo -e "${RED}Usage: ag phase active F-XXXX <phase_id>${NC}"
                exit 1
            fi
            if PYTHONPATH="$AGENTIC_LIB" python3 "$AGENTIC_LIB/auto/phases.py" \
                --project-root "$ROOT_DIR" update "$feature_id" "$phase_id" active; then
                echo -e "${GREEN}✓ Phase $phase_id marked active${NC}"
            else
                echo -e "${RED}Failed to mark phase $phase_id as active${NC}"
                exit 1
            fi
            ;;
        drop)
            local feature_id="${1:-}"
            local phase_id="${2:-}"
            if [ -z "$feature_id" ] || [ -z "$phase_id" ]; then
                echo -e "${RED}Usage: ag phase drop F-XXXX <phase_id>${NC}"
                exit 1
            fi
            if PYTHONPATH="$AGENTIC_LIB" python3 "$AGENTIC_LIB/auto/phases.py" \
                --project-root "$ROOT_DIR" update "$feature_id" "$phase_id" dropped; then
                echo -e "${GREEN}✓ Phase $phase_id dropped${NC}"
            else
                echo -e "${RED}Failed to drop phase $phase_id${NC}"
                exit 1
            fi
            ;;
        sync)
            local feature_id="${1:-}"
            if [ -z "$feature_id" ]; then
                echo -e "${RED}Usage: ag phase sync F-XXXX${NC}"
                exit 1
            fi
            PYTHONPATH="$AGENTIC_LIB" python3 "$AGENTIC_LIB/auto/phases.py" \
                --project-root "$ROOT_DIR" sync "$feature_id"
            ;;
        ""|help)
            echo "ag phase — Multi-session plan phase tracking"
            echo ""
            echo "USAGE:"
            echo "  ag phase list F-XXXX          Show phases and status"
            echo "  ag phase done F-XXXX <id>     Mark phase complete"
            echo "  ag phase active F-XXXX <id>   Mark phase as active"
            echo "  ag phase drop F-XXXX <id>     Mark phase as dropped"
            echo "  ag phase sync F-XXXX          Re-parse plan, reconcile phases"
            ;;
        *)
            echo -e "${RED}Unknown subcommand: $subcmd${NC}"
            echo "Run: ag phase help"
            exit 1
            ;;
    esac
}
