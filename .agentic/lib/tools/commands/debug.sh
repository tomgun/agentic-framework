#!/usr/bin/env bash
# commands/debug.sh — Behavioral trace (btrace) debug commands
# Sourced by ag.sh — do NOT execute directly.
# Depends on: SCRIPT_DIR, ROOT_DIR, PROFILE, color codes, paths.sh, settings.sh

DEBUG_DIR="$ROOT_DIR/.agentic/debug"

# Main dispatch
cmd_debug() {
    local subcmd="${1:-}"
    case "$subcmd" in
        on)   _debug_on ;;
        off)  _debug_off ;;
        list) _debug_list ;;
        show) shift; _debug_show "$@" ;;
        decisions) shift; _debug_decisions "$@" ;;
        bundle) shift; _debug_bundle "$@" ;;
        clean) shift; _debug_clean "$@" ;;
        --help|-h|help) _debug_help ;;
        "") _debug_status ;;
        *) echo "Unknown debug command: $subcmd"; _debug_help; return 1 ;;
    esac
}

_debug_help() {
    echo "Usage: ag debug <command>"
    echo ""
    echo "Behavioral Trace (btrace) — debug mode for framework analysis."
    echo ""
    echo "Commands:"
    echo "  on              Enable behavioral tracing"
    echo "  off             Disable behavioral tracing"
    echo "  list            List all captured session traces"
    echo "  show [opts]     Render timeline from trace (--session <id>, --hook <name>, --json)"
    echo "  decisions [opts] Show gate allow/deny decisions only (--session <id>, --deny-only)"
    echo "  bundle [opts]   Package debug bundle for sharing (--session <id>, --output <path>)"
    echo "  clean [opts]    Remove old traces (--days N, default 30)"
    echo ""
    echo "Toggle via STACK.md: btrace: off|on|verbose"
    echo "Override via env: AGENTIC_BTRACE=on"
    echo ""
    echo "Traces are stored per-session in .agentic/debug/"
}

_debug_status() {
    local level
    level=$(get_setting "btrace" "off")
    local env_override="${AGENTIC_BTRACE:-}"

    echo -e "${BOLD}Behavioral Trace (btrace)${NC}"
    echo ""
    if [[ -n "$env_override" ]]; then
        echo -e "  Level:    ${GREEN}${env_override}${NC} (env override)"
    elif [[ "$level" == "off" ]]; then
        echo -e "  Level:    ${DIM}off${NC}"
    else
        echo -e "  Level:    ${GREEN}${level}${NC}"
    fi

    if [[ -d "$DEBUG_DIR" ]]; then
        local count
        count=$(find "$DEBUG_DIR" -name "btrace-*.jsonl" -not -name "btrace-latest.jsonl" 2>/dev/null | wc -l)
        count="${count## }"
        echo "  Traces:   $count session(s) in .agentic/debug/"
        if [[ -L "$DEBUG_DIR/btrace-latest.jsonl" && -f "$DEBUG_DIR/btrace-latest.jsonl" ]]; then
            local latest_size
            latest_size=$(wc -l < "$DEBUG_DIR/btrace-latest.jsonl" 2>/dev/null || echo 0)
            latest_size="${latest_size## }"
            echo "  Latest:   $latest_size events"
        fi
    else
        echo "  Traces:   none (debug directory not created yet)"
    fi
    echo ""
    echo "Run 'ag debug on' to enable, 'ag debug show' to view latest trace."
}

_debug_on() {
    # Add btrace setting to STACK.md
    if grep -q '^\s*-\s*btrace:' "$ROOT_DIR/STACK.md" 2>/dev/null; then
        sed -i 's/^\(\s*-\s*btrace:\s*\).*/\1on/' "$ROOT_DIR/STACK.md"
    else
        # Append after ## Settings header
        if grep -q '## Settings' "$ROOT_DIR/STACK.md" 2>/dev/null; then
            sed -i '/## Settings/a - btrace: on' "$ROOT_DIR/STACK.md"
        else
            echo -e "\n## Settings\n- btrace: on" >> "$ROOT_DIR/STACK.md"
        fi
    fi
    echo -e "${GREEN}✓${NC} Behavioral tracing enabled (btrace: on)"
    echo "  Traces will be written to .agentic/debug/ on next session."
    echo "  For immediate effect: export AGENTIC_BTRACE=on"
}

_debug_off() {
    if grep -q '^\s*-\s*btrace:' "$ROOT_DIR/STACK.md" 2>/dev/null; then
        sed -i 's/^\(\s*-\s*btrace:\s*\).*/\1off/' "$ROOT_DIR/STACK.md"
    fi
    echo -e "${GREEN}✓${NC} Behavioral tracing disabled (btrace: off)"
}

_debug_list() {
    if [[ ! -d "$DEBUG_DIR" ]]; then
        echo "No traces found. Enable with: ag debug on"
        return 0
    fi

    local traces
    traces=$(find "$DEBUG_DIR" -name "btrace-*.jsonl" -not -name "btrace-latest.jsonl" 2>/dev/null | sort -r)

    if [[ -z "$traces" ]]; then
        echo "No traces found. Enable with: ag debug on"
        return 0
    fi

    echo -e "${BOLD}Captured Traces${NC}"
    echo ""
    printf "  %-40s  %8s  %6s  %s\n" "SESSION" "EVENTS" "DENIES" "DATE"
    printf "  %-40s  %8s  %6s  %s\n" "-------" "------" "------" "----"

    while IFS= read -r trace_file; do
        local fname
        fname=$(basename "$trace_file")
        local sid="${fname#btrace-}"
        sid="${sid%.jsonl}"
        local events
        events=$(wc -l < "$trace_file" 2>/dev/null || echo 0)
        events="${events## }"
        local denials
        denials=$(grep -c '"decision":"deny"' "$trace_file" 2>/dev/null || echo 0)
        denials="${denials## }"
        local mod_date
        mod_date=$(date -r "$trace_file" +%Y-%m-%d 2>/dev/null || stat -c %y "$trace_file" 2>/dev/null | cut -d' ' -f1 || echo "unknown")

        local marker=""
        if [[ -L "$DEBUG_DIR/btrace-latest.jsonl" ]]; then
            local latest_target
            latest_target=$(readlink "$DEBUG_DIR/btrace-latest.jsonl" 2>/dev/null || true)
            [[ "$latest_target" == "$fname" ]] && marker=" (latest)"
        fi

        printf "  %-40s  %8s  %6s  %s%s\n" "${sid:0:40}" "$events" "$denials" "$mod_date" "$marker"
    done <<< "$traces"
}

_debug_show() {
    local session_id="" hook_filter="" json_mode=false
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --session) session_id="$2"; shift 2 ;;
            --hook) hook_filter="$2"; shift 2 ;;
            --json) json_mode=true; shift ;;
            *) shift ;;
        esac
    done

    local trace_file
    trace_file=$(_resolve_trace "$session_id") || return 1

    if $json_mode; then
        if [[ -n "$hook_filter" ]]; then
            grep "\"hook\":\"$hook_filter\"" "$trace_file"
        else
            cat "$trace_file"
        fi
        return 0
    fi

    # Render timeline
    python3 "$SCRIPT_DIR/btrace-show.py" "$trace_file" \
        ${hook_filter:+--hook "$hook_filter"} 2>/dev/null || {
        # Fallback: simple rendering if Python script not available
        echo -e "${BOLD}Behavioral Trace${NC} ($trace_file)"
        echo ""
        while IFS= read -r line; do
            local ts hook phase
            ts=$(echo "$line" | python3 -c "import sys,json; print(json.load(sys.stdin).get('ts','?'))" 2>/dev/null || echo "?")
            hook=$(echo "$line" | python3 -c "import sys,json; print(json.load(sys.stdin).get('hook','?'))" 2>/dev/null || echo "?")
            phase=$(echo "$line" | python3 -c "import sys,json; print(json.load(sys.stdin).get('phase','?'))" 2>/dev/null || echo "?")

            if [[ -n "$hook_filter" && "$hook" != "$hook_filter" ]]; then
                continue
            fi

            local decision=""
            decision=$(echo "$line" | python3 -c "import sys,json; d=json.load(sys.stdin).get('data',{}); print(d.get('decision',''))" 2>/dev/null || true)

            local color="$NC"
            local marker=""
            if [[ "$decision" == "deny" ]]; then
                color="$RED"
                marker=" *** DENY ***"
            elif [[ "$decision" == "allow" ]]; then
                color="$GREEN"
            fi

            local time_part="${ts##*T}"
            time_part="${time_part%%Z*}"
            printf "  ${DIM}[%s]${NC} ${color}%-25s %-20s${NC}%s\n" "$time_part" "$hook" "$phase" "$marker"
        done < "$trace_file"
    }
}

_debug_decisions() {
    local session_id="" deny_only=false
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --session) session_id="$2"; shift 2 ;;
            --deny-only) deny_only=true; shift ;;
            *) shift ;;
        esac
    done

    local trace_file
    trace_file=$(_resolve_trace "$session_id") || return 1

    echo -e "${BOLD}Gate Decisions${NC}"
    echo ""

    local total=0 denials=0 allows=0
    while IFS= read -r line; do
        local decision=""
        decision=$(echo "$line" | python3 -c "import sys,json; d=json.load(sys.stdin).get('data',{}); print(d.get('decision',''))" 2>/dev/null || true)

        [[ -z "$decision" ]] && continue

        total=$((total + 1))

        if [[ "$decision" == "deny" ]]; then
            denials=$((denials + 1))
        else
            allows=$((allows + 1))
            $deny_only && continue
        fi

        local ts hook reason tool_info
        ts=$(echo "$line" | python3 -c "import sys,json; print(json.load(sys.stdin).get('ts','?'))" 2>/dev/null || echo "?")
        hook=$(echo "$line" | python3 -c "import sys,json; print(json.load(sys.stdin).get('hook','?'))" 2>/dev/null || echo "?")
        reason=$(echo "$line" | python3 -c "import sys,json; d=json.load(sys.stdin).get('data',{}); print(d.get('reason',''))" 2>/dev/null || true)

        local time_part="${ts##*T}"
        time_part="${time_part%%Z*}"

        if [[ "$decision" == "deny" ]]; then
            printf "  ${RED}[%s] %-15s DENY${NC}  %s\n" "$time_part" "$hook" "$reason"
        else
            printf "  ${GREEN}[%s] %-15s ALLOW${NC}\n" "$time_part" "$hook"
        fi
    done < "$trace_file"

    echo ""
    echo "Total: $total decisions ($allows allow, $denials deny)"
}

_debug_bundle() {
    local session_id="" output_path=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --session) session_id="$2"; shift 2 ;;
            --output) output_path="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    local bundle_name="btrace-bundle-$(date +%Y%m%d-%H%M%S)"
    local bundle_dir="/tmp/$bundle_name"
    mkdir -p "$bundle_dir/traces"

    # Collect traces
    if [[ -n "$session_id" ]]; then
        local trace_file
        trace_file=$(_resolve_trace "$session_id") || return 1
        cp "$trace_file" "$bundle_dir/traces/"
    elif [[ -d "$DEBUG_DIR" ]]; then
        find "$DEBUG_DIR" -name "btrace-*.jsonl" -not -name "btrace-latest.jsonl" -exec cp {} "$bundle_dir/traces/" \; 2>/dev/null || true
    fi

    # Collect supporting files
    [[ -f "$ROOT_DIR/.agentic/session/framework.log" ]] && cp "$ROOT_DIR/.agentic/session/framework.log" "$bundle_dir/" 2>/dev/null || true
    [[ -f "$ROOT_DIR/.agentic/session/intel-events.log" ]] && cp "$ROOT_DIR/.agentic/session/intel-events.log" "$bundle_dir/" 2>/dev/null || true
    [[ -f "$ROOT_DIR/.agentic/session/token-events.log" ]] && cp "$ROOT_DIR/.agentic/session/token-events.log" "$bundle_dir/" 2>/dev/null || true
    [[ -f "$ROOT_DIR/.agentic/session/intents.json" ]] && cp "$ROOT_DIR/.agentic/session/intents.json" "$bundle_dir/" 2>/dev/null || true
    [[ -f "$ROOT_DIR/.claude/hooks.json" ]] && cp "$ROOT_DIR/.claude/hooks.json" "$bundle_dir/" 2>/dev/null || true

    # Settings snapshot
    local profile
    profile=$(get_setting "profile" "unknown")
    local version="unknown"
    [[ -f "$ROOT_DIR/VERSION" ]] && version=$(cat "$ROOT_DIR/VERSION" 2>/dev/null || echo "unknown")
    [[ "$version" == "unknown" && -f "$ROOT_DIR/.agentic/lib/VERSION" ]] && version=$(cat "$ROOT_DIR/.agentic/lib/VERSION" 2>/dev/null || echo "unknown")

    local trace_count
    trace_count=$(find "$bundle_dir/traces" -name "*.jsonl" 2>/dev/null | wc -l)
    trace_count="${trace_count## }"
    local total_events=0 total_denials=0
    for f in "$bundle_dir/traces"/*.jsonl; do
        [[ -f "$f" ]] || continue
        local ec
        ec=$(wc -l < "$f" 2>/dev/null || echo 0); ec="${ec## }"
        total_events=$((total_events + ec))
        local dc
        dc=$(grep -c '"decision":"deny"' "$f" 2>/dev/null || echo 0); dc="${dc## }"
        total_denials=$((total_denials + dc))
    done

    # Write metadata
    cat > "$bundle_dir/metadata.json" <<EOF
{
  "bundle_version": "1.0.0",
  "framework_version": "$version",
  "profile": "$profile",
  "btrace_level": "$(get_setting "btrace" "off")",
  "bundle_created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "session_count": $trace_count,
  "total_events": $total_events,
  "total_denials": $total_denials,
  "platform": "$(uname -s)"
}
EOF

    # Settings snapshot
    if type show_all_settings &>/dev/null; then
        show_all_settings > "$bundle_dir/settings-snapshot.txt" 2>/dev/null || true
    fi

    # Package
    [[ -z "$output_path" ]] && output_path="$DEBUG_DIR/$bundle_name.tar.gz"
    mkdir -p "$(dirname "$output_path")" 2>/dev/null || true
    tar czf "$output_path" -C /tmp "$bundle_name" 2>/dev/null

    rm -rf "$bundle_dir"

    echo -e "${GREEN}✓${NC} Debug bundle created: $output_path"
    echo "  Sessions: $trace_count | Events: $total_events | Denials: $total_denials"
    echo ""
    echo "Share this file with the framework dev team for analysis."
}

_debug_clean() {
    local days=30
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --days) days="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    if [[ ! -d "$DEBUG_DIR" ]]; then
        echo "No debug directory found."
        return 0
    fi

    local count
    count=$(find "$DEBUG_DIR" -name "btrace-*.jsonl" -not -name "btrace-latest.jsonl" -mtime "+$days" 2>/dev/null | wc -l)
    count="${count## }"

    if [[ "$count" -eq 0 ]]; then
        echo "No traces older than $days days."
        return 0
    fi

    find "$DEBUG_DIR" -name "btrace-*.jsonl" -not -name "btrace-latest.jsonl" -mtime "+$days" -delete 2>/dev/null
    # Also clean old bundles
    find "$DEBUG_DIR" -name "btrace-bundle-*.tar.gz" -mtime "+$days" -delete 2>/dev/null

    echo -e "${GREEN}✓${NC} Removed $count trace(s) older than $days days."
}

# Helper: resolve trace file path from session ID or use latest
_resolve_trace() {
    local session_id="$1"

    if [[ -n "$session_id" ]]; then
        local f="$DEBUG_DIR/btrace-${session_id}.jsonl"
        if [[ -f "$f" ]]; then
            echo "$f"
            return 0
        fi
        # Try partial match
        local match
        match=$(find "$DEBUG_DIR" -name "btrace-${session_id}*.jsonl" -not -name "btrace-latest.jsonl" 2>/dev/null | head -1)
        if [[ -n "$match" ]]; then
            echo "$match"
            return 0
        fi
        echo -e "${RED}No trace found for session: $session_id${NC}" >&2
        return 1
    fi

    # Default to latest
    if [[ -L "$DEBUG_DIR/btrace-latest.jsonl" && -f "$DEBUG_DIR/btrace-latest.jsonl" ]]; then
        echo "$DEBUG_DIR/btrace-latest.jsonl"
        return 0
    fi

    # Fallback: most recent trace file
    local latest
    latest=$(find "$DEBUG_DIR" -name "btrace-*.jsonl" -not -name "btrace-latest.jsonl" 2>/dev/null | sort -r | head -1)
    if [[ -n "$latest" ]]; then
        echo "$latest"
        return 0
    fi

    echo -e "${RED}No traces found. Enable with: ag debug on${NC}" >&2
    return 1
}
