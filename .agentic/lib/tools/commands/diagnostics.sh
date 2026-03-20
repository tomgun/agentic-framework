#!/usr/bin/env bash
# commands/diagnostics.sh — Traceability, testing, and diagnostic commands
# Sourced by ag.sh — do NOT execute directly.
# Depends on: SCRIPT_DIR, ROOT_DIR, PROFILE, color codes, paths.sh, settings.sh

# Analyze session logs for workflow violations
cmd_analyze_session() {
    local arg="${1:-}"
    local json_flag=""
    if [[ "$arg" == "--json" ]]; then
        json_flag="--json"
        shift
        arg="${1:-}"
    elif [[ "${2:-}" == "--json" ]]; then
        json_flag="--json"
    fi

    if [[ -z "$arg" || "$arg" == "--help" || "$arg" == "-h" ]]; then
        echo "Usage: ag analyze-session <session-log.jsonl> [--json]"
        echo ""
        echo "Analyze Claude Code session logs for workflow violations."
        echo "Detects: stopped after plan exit, code before review, skipped planning."
        echo ""
        echo "Examples:"
        echo "  ag analyze-session ~/.claude/projects/-workspace/<session-id>.jsonl"
        echo "  ag analyze-session <path> --json"
        return 0
    fi

    python3 "$SCRIPT_DIR/session-analyze.py" "$arg" $json_flag
}

# Trace command - spec-code traceability
cmd_trace() {
    local arg="${1:-}"
    local json_mode=false
    local gaps_mode=false
    local tests_mode=false
    local orphans_mode=false

    # Parse options
    while [[ -n "$arg" ]]; do
        case "$arg" in
            --json)
                json_mode=true
                shift 2>/dev/null || true
                arg="${1:-}"
                ;;
            --gaps)
                gaps_mode=true
                shift 2>/dev/null || true
                arg="${1:-}"
                ;;
            --tests)
                tests_mode=true
                shift 2>/dev/null || true
                arg="${1:-}"
                ;;
            --orphans)
                orphans_mode=true
                shift 2>/dev/null || true
                arg="${1:-}"
                ;;
            F-[0-9][0-9][0-9][0-9]*)
                # Feature lookup: what files implement this feature?
                cmd_trace_feature "$arg"
                return
                ;;
            *)
                # Check if it's a file path
                if [ -f "$arg" ] || [ -f "$ROOT_DIR/$arg" ]; then
                    cmd_trace_file "$arg"
                    return
                fi
                echo -e "${RED}Unknown option or target: $arg${NC}"
                return 1
                ;;
        esac
    done

    # Full trace (combined drift + coverage)
    if [ "$json_mode" = true ]; then
        cmd_trace_json
    elif [ "$gaps_mode" = true ]; then
        cmd_trace_gaps
    elif [ "$tests_mode" = true ]; then
        python3 "$SCRIPT_DIR/coverage.py" --test-mapping 2>/dev/null
    elif [ "$orphans_mode" = true ]; then
        cmd_trace_orphans
    else
        cmd_trace_full
    fi
}

cmd_trace_full() {
    echo -e "${BOLD}=== Spec ↔ Code Traceability ===${NC}"
    echo ""

    # Run drift detection
    echo -e "${BLUE}--- Drift Detection ---${NC}"
    bash "$SCRIPT_DIR/drift.sh" --check 2>/dev/null || true
    echo ""

    # Run coverage check
    echo -e "${BLUE}--- Coverage Analysis ---${NC}"
    python3 "$SCRIPT_DIR/coverage.py" 2>/dev/null || true
}

cmd_trace_json() {
    # Combine JSON outputs from drift.sh and coverage.py
    local drift_file coverage_file
    drift_file=$(mktemp)
    coverage_file=$(mktemp)

    # Use || true to ignore exit codes (both tools return 1 if issues found)
    bash "$SCRIPT_DIR/drift.sh" --json 2>/dev/null > "$drift_file" || true
    python3 "$SCRIPT_DIR/coverage.py" --json 2>/dev/null > "$coverage_file" || true

    # Merge the two JSON outputs
    python3 - "$drift_file" "$coverage_file" << 'PYEOF'
import json
import sys
from datetime import datetime, timezone

drift_file = sys.argv[1]
coverage_file = sys.argv[2]

with open(drift_file) as f:
    drift = json.load(f)
with open(coverage_file) as f:
    coverage = json.load(f)

combined = {
    "tool": "trace",
    "timestamp": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
    "drift": drift,
    "coverage": coverage,
    "summary": {
        "total_drift_issues": drift.get("summary", {}).get("total_issues", 0),
        "total_coverage_issues": len(coverage.get("issues", [])),
        "annotated_features": coverage.get("summary", {}).get("annotated_features", 0),
        "implemented_features": coverage.get("summary", {}).get("implemented_features", 0),
    }
}
print(json.dumps(combined, indent=2))
PYEOF

    rm -f "$drift_file" "$coverage_file"
}

cmd_trace_gaps() {
    echo -e "${BOLD}=== Implementation Gaps ===${NC}"
    echo ""

    # Features with missing annotations
    echo -e "${YELLOW}Features without code annotations:${NC}"
    python3 "$SCRIPT_DIR/coverage.py" --json 2>/dev/null | \
        python3 -c "
import json
import sys
data = json.load(sys.stdin)
for issue in data.get('issues', []):
    if issue.get('type') == 'missing_annotation':
        print(f\"  {issue['feature']}: {issue.get('status', '')} - no @feature annotations\")
"
    echo ""

    # Features with incomplete acceptance criteria
    echo -e "${YELLOW}Shipped features with incomplete acceptance:${NC}"
    bash "$SCRIPT_DIR/drift.sh" --json 2>/dev/null | \
        python3 -c "
import json
import sys
data = json.load(sys.stdin)
for issue in data.get('issues', []):
    if issue.get('type') in ('incomplete_shipped', 'status_drift'):
        print(f\"  {issue.get('feature', 'unknown')}: {issue.get('description', '')}\")
"
}

cmd_trace_orphans() {
    echo -e "${BOLD}=== Orphaned Code & Annotations ===${NC}"
    echo ""

    # Orphaned annotations
    echo -e "${YELLOW}Orphaned @feature annotations (feature doesn't exist):${NC}"
    python3 "$SCRIPT_DIR/coverage.py" --json 2>/dev/null | \
        python3 -c "
import json
import sys
data = json.load(sys.stdin)
found = False
for issue in data.get('issues', []):
    if issue.get('type') == 'orphaned_annotation':
        found = True
        print(f\"  {issue['feature']} in {issue.get('file', 'unknown')}\")
if not found:
    print('  None found')
"
    echo ""

    # Undocumented code
    echo -e "${YELLOW}Undocumented exports:${NC}"
    bash "$SCRIPT_DIR/drift.sh" --json 2>/dev/null | \
        python3 -c "
import json
import sys
data = json.load(sys.stdin)
found = False
for issue in data.get('issues', []):
    if issue.get('type') == 'undocumented_code':
        found = True
        print(f\"  {issue.get('export', 'unknown')}\")
if not found:
    print('  None found')
" | head -15
}

cmd_trace_feature() {
    local feature_id="$1"
    echo -e "${BOLD}=== Files implementing $feature_id ===${NC}"
    echo ""

    python3 "$SCRIPT_DIR/coverage.py" --json 2>/dev/null | \
        python3 -c "
import json
import sys

data = json.load(sys.stdin)
fid = '$feature_id'

# Find in full scan (we need annotations data which isn't in JSON output)
# Fall back to direct scan
" 2>/dev/null || true

    # Direct grep for @feature annotations
    echo "Files with @feature $feature_id annotation:"
    grep -rl "@feature $feature_id" "$ROOT_DIR" --include="*.py" --include="*.ts" --include="*.js" --include="*.go" --include="*.rs" --include="*.java" --include="*.sh" 2>/dev/null | \
        while read -r f; do
            echo "  - ${f#$ROOT_DIR/}"
        done || echo "  (none found)"
    echo ""

    # Check acceptance criteria
    local acc_file="$ROOT_DIR/.agentic/spec/acceptance/${feature_id}.md"
    if [ -f "$acc_file" ]; then
        echo "Acceptance criteria: $acc_file"
        local total complete
        total=$(grep -cE "^- \[.\]" "$acc_file" 2>/dev/null || echo "0")
        complete=$(grep -cE "^- \[x\]" "$acc_file" 2>/dev/null || echo "0")
        echo "  Progress: $complete/$total complete"
    fi
}

cmd_trace_file() {
    local target_file="$1"
    python3 "$SCRIPT_DIR/coverage.py" --reverse "$target_file" 2>/dev/null
}

# Test command - run LLM behavioral tests
cmd_test() {
    local test_type="${1:-}"
    shift 2>/dev/null || true
    
    case "$test_type" in
        llm)
            cmd_test_llm "$@"
            ;;
        unit|framework)
            echo -e "${BOLD}=== Framework Unit Tests ===${NC}"
            bash "$ROOT_DIR/tests/validate_framework.sh"
            ;;
        "")
            echo -e "${RED}Error: Test type required${NC}"
            echo "Usage: ag test llm [--critical|--list|--setup TEST_ID]"
            echo "       ag test unit"
            exit 1
            ;;
        *)
            echo -e "${RED}Unknown test type: $test_type${NC}"
            echo "Available: llm, unit"
            exit 1
            ;;
    esac
}

# LLM behavioral tests
cmd_test_llm() {
    local arg="${1:-}"
    local runner="$ROOT_DIR/tests/llm/interactive_runner.py"
    local harness="$ROOT_DIR/tests/llm/harness.sh"
    
    # Detect environment
    local env="unknown"
    if command -v claude &>/dev/null; then
        env="claude"
    elif command -v codex &>/dev/null; then
        env="codex"
    elif [[ -n "${CURSOR_SESSION:-}" ]] || pgrep -f "Cursor" &>/dev/null; then
        env="cursor-ide"
    elif [[ -n "${VSCODE_PID:-}" ]]; then
        env="copilot-ide"
    fi
    
    echo -e "${BOLD}=== LLM Behavioral Tests ===${NC}"
    echo "Environment: $env"
    echo ""
    
    case "$arg" in
        --list)
            python3 "$runner" --list
            ;;
        --critical)
            if [[ "$env" == "claude" ]]; then
                echo "Using Claude CLI (automated)..."
                TOOL=claude bash "$harness" --critical
            elif [[ "$env" == "codex" ]]; then
                echo "Using Codex CLI (automated)..."
                TOOL=codex bash "$harness" --critical
            else
                echo "Using interactive mode (agent-driven)..."
                echo ""
                python3 "$runner" --list --critical
                echo ""
                echo -e "${YELLOW}To run these tests interactively:${NC}"
                echo "  python3 tests/llm/interactive_runner.py --interactive --critical"
                echo ""
                echo -e "${YELLOW}Or run individually:${NC}"
                echo "  python3 tests/llm/interactive_runner.py --setup 001"
                echo "  (Agent responds to prompt)"
                echo "  python3 tests/llm/interactive_runner.py --verify 001"
            fi
            ;;
        --setup)
            local test_id="${2:-}"
            if [[ -z "$test_id" ]]; then
                echo -e "${RED}Error: Test ID required${NC}"
                echo "Usage: ag test llm --setup 001"
                exit 1
            fi
            python3 "$runner" --setup "$test_id"
            ;;
        --verify)
            local test_id="${2:-}"
            if [[ -z "$test_id" ]]; then
                echo -e "${RED}Error: Test ID required${NC}"
                echo "Usage: ag test llm --verify 001"
                exit 1
            fi
            shift  # Remove --verify
            python3 "$runner" --verify "$@"
            ;;
        --interactive)
            if [[ "$env" == "cursor-ide" ]] || [[ "$env" == "copilot-ide" ]]; then
                echo "Running in interactive mode..."
                python3 "$runner" --interactive "${@:2}"
            else
                echo -e "${YELLOW}Interactive mode is for IDE-based tools (Cursor, Copilot).${NC}"
                echo "Your environment ($env) supports automated tests:"
                echo "  TOOL=$env bash tests/llm/harness.sh"
            fi
            ;;
        --detect)
            echo "Detected environment: $env"
            case "$env" in
                claude)
                    echo "  Claude CLI available - fully automated tests"
                    echo "  Run: bash tests/llm/harness.sh"
                    ;;
                codex)
                    echo "  Codex CLI available - fully automated tests"
                    echo "  Run: TOOL=codex bash tests/llm/harness.sh"
                    ;;
                cursor-ide)
                    echo "  Running inside Cursor IDE - use interactive mode"
                    echo "  Run: ag test llm --interactive --critical"
                    ;;
                copilot-ide)
                    echo "  Running inside VS Code (Copilot) - use interactive mode"
                    echo "  Run: ag test llm --interactive --critical"
                    ;;
                *)
                    echo "  Unknown environment"
                    echo "  Install: claude CLI, codex CLI, or run from Cursor/Copilot"
                    ;;
            esac
            ;;
        ""|--help)
            echo "LLM behavioral tests verify agent compliance with framework rules."
            echo ""
            echo "Usage: ag test llm [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --list              List all available tests"
            echo "  --critical          Run/list critical tests only"
            echo "  --setup TEST_ID     Set up project for a specific test"
            echo "  --verify TEST_ID    Verify outcomes of a test"
            echo "  --interactive       Run tests interactively (for Cursor/Copilot)"
            echo "  --detect            Show detected environment"
            echo ""
            echo "Environments:"
            echo "  Claude CLI (claude):    Fully automated via 'bash tests/llm/harness.sh'"
            echo "  Codex CLI (codex):      Fully automated via 'TOOL=codex bash tests/llm/harness.sh'"
            echo "  Cursor IDE:             Interactive mode - agent responds to prompts"
            echo "  Copilot IDE:            Interactive mode - agent responds to prompts"
            echo ""
            echo "Current environment: $env"
            ;;
        *)
            # Check if it's a test ID
            if echo "$arg" | grep -qE '^[0-9]+'; then
                python3 "$runner" --setup "$arg"
            else
                echo -e "${RED}Unknown option: $arg${NC}"
                cmd_test_llm --help
                exit 1
            fi
            ;;
    esac
}
