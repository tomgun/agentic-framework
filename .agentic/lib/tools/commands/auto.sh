#!/usr/bin/env bash
# commands/auto.sh — Autonomous workflow engine
# Sourced by ag.sh — do NOT execute directly.
# Depends on: SCRIPT_DIR, ROOT_DIR, PROFILE, color codes, paths.sh, settings.sh

cmd_auto() {
    local subcmd="${1:-}"
    shift 2>/dev/null || true

    local auto_dir="$SCRIPT_DIR/../auto"

    case "$subcmd" in
        init)
            # Generate settings.json for auto mode
            local tier_flag=""
            local dry_run=""
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --tier) tier_flag="--tier $2"; shift 2 ;;
                    --dry-run) dry_run="--dry-run"; shift ;;
                    *) shift ;;
                esac
            done
            python3 "$auto_dir/init.py" --project-root "$ROOT_DIR" $tier_flag $dry_run
            ;;
        status|pause|resume|stop)
            python3 "$auto_dir/control.py" "$subcmd" --project-root "$ROOT_DIR"
            ;;
        verify)
            # Autonomous test-fix loop (F-0161)
            python3 "$auto_dir/verify.py" --project-root "$ROOT_DIR" "$@"
            ;;
        task)
            # Single-feature implementation (F-0162)
            python3 "$auto_dir/task.py" --project-root "$ROOT_DIR" "$@"
            ;;
        crunch)
            # Multi-feature batch mode (F-0163, backed by scheduler F-0186)
            python3 "$auto_dir/crunch.py" --project-root "$ROOT_DIR" "$@"
            ;;
        epic)
            # Autonomous epic execution (F-0186)
            python3 "$auto_dir/scheduler.py" --project-root "$ROOT_DIR" "$@"
            ;;
        verify-epic)
            # Integration verification for an epic (F-0204)
            python3 "$auto_dir/integration_verify.py" --project-root "$ROOT_DIR" "$@"
            ;;
        pipeline)
            # End-to-end autonomous pipeline: vision → epic → ship (F-0188)
            python3 "$auto_dir/pipeline.py" --project-root "$ROOT_DIR" "$@"
            ;;
        verify-framework)
            # Framework self-verification loop (F-0215)
            python3 "$auto_dir/framework_verify.py" --project-root "$ROOT_DIR" "$@"
            ;;
        feedback)
            python3 "$auto_dir/control.py" feedback "$@" --project-root "$ROOT_DIR"
            ;;
        ""|--help)
            echo "ag auto - Autonomous workflow engine"
            echo ""
            echo "COMMANDS:"
            echo "  init [--tier N]       Generate settings.json (N=1 sandboxed, 2 scoped, 3 interactive)"
            echo "  verify                Run test-fix loop until green (F-0161)"
            echo "    --visual              Add AI visual review of screenshots"
            echo "    --feature <F-XXXX>    Save evidence for smoke test gate (with --visual)"
            echo "  task <F-XXXX>         Implement a single feature autonomously (F-0162)"
            echo "  crunch [--features .] Implement multiple features in batch (F-0163)"
            echo "  epic <F-XXXX>         Autonomous epic execution — schedule children (F-0186)"
            echo "    --parallel            Execute children in parallel worktrees (F-0214)"
            echo "    --max-parallel N      Max concurrent agents (default: 3)"
            echo "    --timeout N           Per-feature timeout in seconds (default: 600)"
            echo "  verify-epic <F-XXXX>  Run integration verification for epic (F-0204)"
            echo "  verify-framework      Framework self-verification loop (F-0215)"
            echo "    --project <name>      Run single scenario (todo-app, api-service, etc.)"
            echo "    --all                 Run all scenarios × all settings combos"
            echo "    --json                Machine-readable output"
            echo "  pipeline              End-to-end: vision → epic → implement → ship (F-0188)"
            echo "  status                Show engine state"
            echo "  pause                 Pause running engine"
            echo "  resume                Resume paused engine"
            echo "  stop                  Stop running engine"
            echo "  feedback <AC> <text>  Send feedback for an acceptance criterion"
            echo ""
            echo "TIERS:"
            echo "  1: Sandboxed   - Docker/VM + --dangerously-skip-permissions"
            echo "  2: Scoped      - settings.json with explicit permissions (default)"
            echo "  3: Interactive - Normal approval prompts (safest, slowest)"
            ;;
        *)
            echo -e "${RED}Unknown auto command: $subcmd${NC}"
            echo "Run 'ag auto --help' for usage."
            exit 1
            ;;
    esac
}
