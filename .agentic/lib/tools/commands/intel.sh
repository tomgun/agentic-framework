#!/usr/bin/env bash
# commands/intel.sh — Intelligence engine commands (patterns, anatomy, quality)
# Sourced by ag.sh — do NOT execute directly.
# Depends on: SCRIPT_DIR, ROOT_DIR, PROFILE, color codes, paths.sh, settings.sh

INTEL_DIR="${ROOT_DIR}/.agentic/intel"
PATTERNS_FILE="${INTEL_DIR}/patterns.yaml"
PROJECT_MEMORY_FILE="${INTEL_DIR}/project-memory.yaml"
ANATOMY_FILE="${INTEL_DIR}/anatomy.yaml"
ANATOMY_INDEX="${INTEL_DIR}/anatomy.index"
TOKEN_SUMMARY="${INTEL_DIR}/token-summary.json"
SESSION_DIR="${ROOT_DIR}/.agentic/session"
TOKEN_EVENTS="${SESSION_DIR}/token-events.log"
TOKEN_LEDGER="${SESSION_DIR}/token-ledger.json"
INTEL_EVENTS="${SESSION_DIR}/intel-events.log"
INTEL_SUMMARY="${INTEL_DIR}/intel-summary.json"

_INTEL_VALID_SEVERITIES="error warning info"
_INTEL_VALID_CEREBRUM_TYPES="preference learning decision"

# ---------------------------------------------------------------------------
# Intel event logger — records when framework intelligence is sourced vs. not
# Format: TIMESTAMP|EVENT|DETAIL|ITEMS
#   EVENT: query|enforce|mutate|scan
#   DETAIL: subcommand or source description
#   ITEMS: count of intelligence items surfaced (0 = nothing found)
# Consumers: Stop.sh (session summary), ag intel stats, audit
# ---------------------------------------------------------------------------
_intel_log() {
    local event="${1:-}" detail="${2:-}" items="${3:-0}"
    local ts
    ts="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "unknown")"
    mkdir -p "$SESSION_DIR" 2>/dev/null || true
    printf '%s|%s|%s|%s\n' "$ts" "$event" "$detail" "$items" \
        >> "$INTEL_EVENTS" 2>/dev/null || true
}

# Safe grep count — strips whitespace from grep -c output for arithmetic
_intel_count() {
    local val
    val=$(grep -c "$@" 2>/dev/null || echo 0)
    val="${val## }"; val="${val%% }"; val="${val%%[!0-9]*}"
    echo "${val:-0}"
}

cmd_intel() {
    local subcmd="${1:-help}"
    shift 2>/dev/null || true

    case "$subcmd" in
        check)     _intel_check "$@" ;;
        learn)     _intel_learn "$@" ;;
        remove)    _intel_remove "$@" ;;
        patterns)  _intel_patterns "$@" ;;
        remember)        _intel_remember "$@" ;;
        review-session)  _intel_review_session "$@" ;;
        batch-remember)  _intel_batch_remember "$@" ;;
        memory|cerebrum)  _intel_memory "$@" ;;
        decisions)       _intel_decisions "$@" ;;
        forget)          _intel_forget "$@" ;;
        scan)      _intel_scan "$@" ;;
        file)      _intel_file "$@" ;;
        stats)     _intel_stats "$@" ;;
        bootstrap)     _intel_bootstrap "$@" ;;
        retro)         _intel_retro "$@" ;;
        architecture)  _intel_architecture "$@" ;;
        spec)          _intel_spec "$@" ;;
        implement)     _intel_implement "$@" ;;
        test)          _intel_test "$@" ;;
        report)        _intel_report "$@" ;;
        help|--help|-h) _intel_help ;;
        *)
            echo -e "${RED}Unknown intel subcommand: $subcmd${NC}"
            _intel_help
            return 1
            ;;
    esac
}

_intel_help() {
    echo -e "${BOLD}ag intel${NC} — Intelligence engine"
    echo ""
    echo "  ${BOLD}Patterns${NC} (enforced at write-time)"
    echo "  check PATH [--json]       Show patterns matching a file path"
    echo "  learn \"text\" --reason \"why\" --scope \"glob\"  Add an enforced pattern"
    echo "  remove P-XXXX             Remove a pattern by ID"
    echo "  patterns [--scope PATH]   List all patterns (optionally filtered by scope)"
    echo ""
    echo "  ${BOLD}Project Memory${NC} (preferences, learnings, decisions)"
    echo "  remember \"text\" [--type preference|learning|decision] [--context \"...\"]"
    echo "  memory [--type TYPE]      List project memory entries"
    echo "  forget C-XXXX             Remove a project memory entry"
    echo "  review-session            Display session prompts for preference review"
    echo "  decisions                 List all decisions with provenance"
    echo ""
    echo "  ${BOLD}Anatomy${NC} (file intelligence)"
    echo "  scan [--check]            Scan project files → anatomy.yaml + index"
    echo "  file PATH                 Lookup file: summary, tokens, language"
    echo ""
    echo "  ${BOLD}Knowledge Generation${NC}"
    echo "  bootstrap                 Generate domain intelligence from stack + codebase"
    echo "  retro                     Analyze issues/lessons → suggest new patterns"
    echo ""
    echo "  ${BOLD}Phase-Aware Queries${NC} (intelligence for workflow phases)"
    echo "  architecture              Planning context: ADRs, NFRs, quality checks"
    echo "  spec [F-XXXX]             Spec context: features, contracts, quality checks"
    echo "  implement [F-XXXX]        Implementation context: conventions, patterns, quality checks"
    echo "  test [F-XXXX]             Testing context: strategy, infra, quality checks"
    echo ""
    echo "  ${BOLD}Metrics${NC}"
    echo "  stats [--session]         Show token metrics (session + lifetime)"
    echo "  report --quota            Pro/Max quota usage in last 5h window (R-013)"
}

# ---------------------------------------------------------------------------
# `ag intel report` — JSONL-backed reports (R-013 + future R-101/R-209/R-407).
# ---------------------------------------------------------------------------
_intel_report() {
    local kind=""
    local extra=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --quota)
                kind="quota"
                shift
                ;;
            --json|--no-color)
                extra+=("$1"); shift
                ;;
            --window-seconds|--ceiling-tokens|--token-ledger|--journal-dir)
                extra+=("$1" "${2:-}"); shift 2
                ;;
            -h|--help)
                echo -e "${BOLD}ag intel report${NC} — JSONL-backed reports"
                echo ""
                echo "  --quota              Pro/Max quota usage report (5h trailing window)"
                echo "  --window-seconds N   Override window (default 18000 = 5h)"
                echo "  --ceiling-tokens N   Override quota ceiling (default: STACK.md)"
                echo "  --json               Emit JSON instead of human-readable text"
                echo "  --no-color           Disable ANSI colors"
                return 0
                ;;
            *)
                echo -e "${RED}Unknown report flag: $1${NC}"
                return 1
                ;;
        esac
    done

    if [[ "$kind" != "quota" ]]; then
        echo -e "${RED}ag intel report requires --quota (more report types coming).${NC}"
        return 2
    fi

    # Resolve ceiling from STACK.md when not overridden on the CLI.
    local ceiling_arg=()
    local has_ceiling=0
    for arg in "${extra[@]}"; do
        if [[ "$arg" == "--ceiling-tokens" ]]; then
            has_ceiling=1
            break
        fi
    done
    if [[ "$has_ceiling" -eq 0 ]]; then
        local stack_ceiling
        stack_ceiling=$(get_setting "quota_pro_max_window_tokens" "")
        if [[ -n "$stack_ceiling" ]]; then
            ceiling_arg=(--ceiling-tokens "$stack_ceiling")
        fi
    fi

    local journal_dir="$ROOT_DIR/.agentic/journal"
    PYTHONPATH="$ROOT_DIR/.agentic/lib${PYTHONPATH:+:$PYTHONPATH}" \
        python3 -m quota \
        --journal-dir "$journal_dir" \
        "${ceiling_arg[@]}" \
        "${extra[@]}"
}

# ---------------------------------------------------------------------------
# Shared YAML parser — iterates patterns.yaml, calls a callback per entry.
# Usage: _intel_each_pattern <callback> [extra_args...]
# Callback signature: callback id text reason scope severity source [extra_args...]
# The parser handles the "last entry" flush internally — no duplication needed.
# ---------------------------------------------------------------------------
_intel_each_pattern() {
    local callback="$1"
    shift
    local extra_args=("$@")

    [[ ! -f "$PATTERNS_FILE" ]] && return 0

    local _id="" _text="" _reason="" _scope="" _severity="" _source=""

    _intel_flush_entry() {
        if [[ -n "$_id" ]]; then
            "$callback" "$_id" "$_text" "$_reason" "$_scope" "$_severity" "$_source" "${extra_args[@]}"
        fi
    }

    while IFS= read -r _line; do
        case "$_line" in
            *"- id: "*)
                _intel_flush_entry
                _id="${_line#*"- id: "}"
                _id="${_id//\"/}"
                _id="${_id## }"
                _text="" _reason="" _scope="" _severity="" _source=""
                ;;
            *"text: "*)
                _text="${_line#*"text: "}"
                _text="${_text//\"/}"
                ;;
            *"reason: "*)
                _reason="${_line#*"reason: "}"
                _reason="${_reason//\"/}"
                ;;
            *"scope: "*)
                _scope="${_line#*"scope: "}"
                _scope="${_scope//\"/}"
                ;;
            *"severity: "*)
                _severity="${_line#*"severity: "}"
                _severity="${_severity//\"/}"
                ;;
            *"source: "*)
                _source="${_line#*"source: "}"
                _source="${_source//\"/}"
                ;;
        esac
    done < "$PATTERNS_FILE"

    # Flush last entry
    _intel_flush_entry
    unset -f _intel_flush_entry
}

# ---------------------------------------------------------------------------
# Glob match: check if path matches a scope pattern.
# Supports: *.sh, .agentic/lib/claude-hooks/*.sh, *.py, etc.
# Limitation: bash case globs don't support **/ recursive matching.
#   Patterns like "src/**/*.py" won't work. Use "*.py" or "src/*.py" instead.
# ---------------------------------------------------------------------------
_intel_glob_match() {
    local path="$1" pattern="$2"

    [[ -z "$pattern" ]] && return 1

    local filename="${path##*/}"

    # shellcheck disable=SC2254
    case "$path" in $pattern) return 0 ;; esac

    # shellcheck disable=SC2254
    case "$filename" in $pattern) return 0 ;; esac

    # For directory-qualified patterns, try relative path variants
    local rel_path="${path#./}"
    rel_path="${rel_path#/}"

    # shellcheck disable=SC2254
    case "$rel_path" in $pattern) return 0 ;; esac
    # shellcheck disable=SC2254
    case "./$rel_path" in $pattern) return 0 ;; esac

    return 1
}

# ---------------------------------------------------------------------------
# check — find patterns matching a file path
# ---------------------------------------------------------------------------
_intel_check() {
    local target_path="" json_mode=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --json) json_mode=true ;;
            *) [[ -z "$target_path" ]] && target_path="$1" ;;
        esac
        shift
    done

    if [[ -z "$target_path" ]]; then
        echo -e "${RED}Error: PATH required${NC}"
        echo "Usage: ag intel check PATH [--json]"
        return 1
    fi

    [[ ! -f "$PATTERNS_FILE" ]] && { $json_mode && echo "[]"; return 0; }

    # Collect matches
    _INTEL_CHECK_MATCHES=()
    _INTEL_CHECK_TARGET="$target_path"
    _INTEL_CHECK_JSON="$json_mode"

    _intel_check_callback() {
        local id="$1" text="$2" reason="$3" scope="$4" severity="${5:-warning}" source="$6"
        if _intel_glob_match "$_INTEL_CHECK_TARGET" "$scope"; then
            if [[ "$_INTEL_CHECK_JSON" == "true" ]]; then
                _INTEL_CHECK_MATCHES+=("{\"id\":\"$id\",\"text\":\"$text\",\"scope\":\"$scope\",\"severity\":\"$severity\"}")
            else
                local color="$YELLOW" icon="⚠️"
                case "$severity" in
                    error) color="$RED"; icon="🚨" ;;
                    info)  color="$BLUE"; icon="ℹ️" ;;
                esac
                echo -e "${color}${icon} ${id}: ${text}${NC}"
                [[ -n "$reason" ]] && echo -e "  ${DIM}Reason: ${reason}${NC}"
            fi
        fi
    }

    _intel_each_pattern _intel_check_callback

    if [[ "$json_mode" == "true" ]]; then
        local IFS=","
        echo "[${_INTEL_CHECK_MATCHES[*]:-}]"
    fi

    unset _INTEL_CHECK_MATCHES _INTEL_CHECK_TARGET _INTEL_CHECK_JSON
}

# ---------------------------------------------------------------------------
# learn — add a new pattern
# ---------------------------------------------------------------------------
_intel_learn() {
    local text="" reason="" scope="" severity="warning"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --reason)  shift; reason="${1:-}" ;;
            --scope)   shift; scope="${1:-}" ;;
            --severity) shift; severity="${1:-}" ;;
            *)
                if [[ -z "$text" ]]; then
                    text="$1"
                else
                    echo -e "${RED}Error: unexpected argument: $1${NC}"
                    return 1
                fi
                ;;
        esac
        shift
    done

    if [[ -z "$text" ]]; then
        echo -e "${RED}Error: pattern text required${NC}"
        echo "Usage: ag intel learn \"text\" --reason \"why\" --scope \"*.py\""
        return 1
    fi

    if [[ -z "$scope" ]]; then
        echo -e "${RED}Error: --scope required${NC}"
        echo "Usage: ag intel learn \"text\" --reason \"why\" --scope \"*.py\""
        return 1
    fi

    # Validate severity
    if [[ ! " $_INTEL_VALID_SEVERITIES " =~ " $severity " ]]; then
        echo -e "${RED}Error: invalid severity '$severity'. Must be one of: $_INTEL_VALID_SEVERITIES${NC}"
        return 1
    fi

    # Ensure intel directory and patterns file exist
    mkdir -p "$INTEL_DIR"
    if [[ ! -f "$PATTERNS_FILE" ]]; then
        cat > "$PATTERNS_FILE" <<'INIT'
version: 1
description: >
  Machine-matchable patterns enforced at write-time via hooks.
patterns:
INIT
    fi

    # Find next pattern ID
    local max_id=0
    while IFS= read -r line; do
        if [[ "$line" =~ "- id: P-"([0-9]+) ]]; then
            local num="${BASH_REMATCH[1]}"
            num=$((10#$num))
            if (( num > max_id )); then
                max_id=$num
            fi
        fi
    done < "$PATTERNS_FILE"
    local next_id
    next_id=$(printf "P-%04d" $((max_id + 1)))

    # Escape double quotes in values for YAML
    text="${text//\"/\\\"}"
    reason="${reason//\"/\\\"}"

    cat >> "$PATTERNS_FILE" <<EOF

  - id: ${next_id}
    text: "${text}"
    reason: "${reason}"
    scope: "${scope}"
    severity: ${severity}
    source: manual
EOF

    echo -e "${GREEN}✓ Added pattern ${next_id}: ${text}${NC}"
    echo -e "  Scope: ${scope} | Severity: ${severity}"
    _intel_log "mutate" "learn:${next_id}" "1"
}

# ---------------------------------------------------------------------------
# remove — remove a pattern by ID
# ---------------------------------------------------------------------------
_intel_remove() {
    local pattern_id="${1:-}"

    if [[ -z "$pattern_id" ]]; then
        echo -e "${RED}Error: pattern ID required${NC}"
        echo "Usage: ag intel remove P-XXXX"
        return 1
    fi

    if [[ ! -f "$PATTERNS_FILE" ]]; then
        echo -e "${RED}Error: no patterns file found${NC}"
        return 1
    fi

    # Check pattern exists
    if ! grep -q "id: ${pattern_id}$" "$PATTERNS_FILE" 2>/dev/null && \
       ! grep -q "id: \"${pattern_id}\"" "$PATTERNS_FILE" 2>/dev/null; then
        echo -e "${RED}Error: pattern ${pattern_id} not found${NC}"
        return 1
    fi

    # Remove the pattern block: from "  - id: P-XXXX" to the next "  - id:" or EOF
    local tmp_file
    tmp_file=$(mktemp)
    local skip=false
    local removed=false
    local blank_buffer=""

    while IFS= read -r line; do
        if [[ "$line" == *"- id: ${pattern_id}"* ]]; then
            skip=true
            removed=true
            blank_buffer=""
            continue
        fi
        if $skip; then
            if [[ "$line" == *"- id: "* ]]; then
                # Next entry — stop skipping, emit this line
                skip=false
                echo "$line" >> "$tmp_file"
            fi
            # Skip lines belonging to the removed entry (and trailing blanks)
            continue
        fi
        # Buffer blank lines so we don't leave extra gaps
        if [[ -z "$line" ]]; then
            blank_buffer="${blank_buffer}
"
        else
            [[ -n "$blank_buffer" ]] && printf "%s" "$blank_buffer" >> "$tmp_file"
            blank_buffer=""
            echo "$line" >> "$tmp_file"
        fi
    done < "$PATTERNS_FILE"

    if $removed; then
        mv "$tmp_file" "$PATTERNS_FILE"
        echo -e "${GREEN}✓ Removed pattern ${pattern_id}${NC}"
        _intel_log "mutate" "remove:${pattern_id}" "1"
    else
        rm -f "$tmp_file"
        echo -e "${RED}Error: pattern ${pattern_id} not found${NC}"
        return 1
    fi
}

# ---------------------------------------------------------------------------
# patterns — list all patterns (optionally filtered by scope)
# ---------------------------------------------------------------------------
_intel_patterns() {
    local scope_filter=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --scope) shift; scope_filter="${1:-}" ;;
            *) scope_filter="$1" ;;
        esac
        shift
    done

    if [[ ! -f "$PATTERNS_FILE" ]]; then
        echo -e "${YELLOW}No patterns file found at ${PATTERNS_FILE}${NC}"
        echo "Run: ag intel learn \"text\" --reason \"why\" --scope \"*.py\" to create one"
        return 0
    fi

    local count=0

    echo -e "${BOLD}Patterns${NC} (${PATTERNS_FILE})"
    echo ""

    _INTEL_LIST_FILTER="$scope_filter"
    _INTEL_LIST_COUNT=0

    _intel_list_callback() {
        local id="$1" text="$2" reason="$3" scope="$4" severity="$5" source="$6"

        if [[ -n "$_INTEL_LIST_FILTER" ]]; then
            _intel_glob_match "$_INTEL_LIST_FILTER" "$scope" || return 0
        fi

        local sev_color="$YELLOW"
        case "$severity" in
            error) sev_color="$RED" ;;
            info)  sev_color="$BLUE" ;;
        esac

        echo -e "  ${sev_color}${id}${NC} [${severity:-warning}] ${text}"
        echo -e "    ${DIM}Scope: ${scope}  Source: ${source:-unknown}${NC}"
        _INTEL_LIST_COUNT=$((_INTEL_LIST_COUNT + 1))
    }

    _intel_each_pattern _intel_list_callback

    echo ""
    echo -e "${DIM}${_INTEL_LIST_COUNT} pattern(s) shown${NC}"

    unset _INTEL_LIST_FILTER _INTEL_LIST_COUNT
}

# ===========================================================================
# Cerebrum — project-scoped learning from user corrections & discoveries
# ===========================================================================

# ---------------------------------------------------------------------------
# remember — capture a preference, learning, or decision
# ---------------------------------------------------------------------------
_intel_remember() {
    local text="" entry_type="preference" context="" source="manual" session_id=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --type)    shift; entry_type="${1:-}" ;;
            --context) shift; context="${1:-}" ;;
            --source)  shift; source="${1:-manual}" ;;
            --session) shift; session_id="${1:-}" ;;
            *)
                if [[ -z "$text" ]]; then
                    text="$1"
                else
                    echo -e "${RED}Error: unexpected argument: $1${NC}"
                    return 1
                fi
                ;;
        esac
        shift
    done

    if [[ -z "$text" ]]; then
        echo -e "${RED}Error: text required${NC}"
        echo "Usage: ag intel remember \"text\" [--type preference|learning|decision] [--context \"...\"] [--source manual|agent_capture|settings_change|session_audit] [--session ID]"
        return 1
    fi

    # Auto-read session ID if not provided
    if [[ -z "$session_id" && -f "$PROJECT_ROOT/.agentic/session/.current-session-id" ]]; then
        session_id=$(cat "$PROJECT_ROOT/.agentic/session/.current-session-id" 2>/dev/null || true)
    fi

    if [[ ! " $_INTEL_VALID_CEREBRUM_TYPES " =~ " $entry_type " ]]; then
        echo -e "${RED}Error: invalid type '$entry_type'. Must be one of: $_INTEL_VALID_CEREBRUM_TYPES${NC}"
        return 1
    fi

    mkdir -p "$INTEL_DIR"
    if [[ ! -f "$PROJECT_MEMORY_FILE" ]]; then
        cat > "$PROJECT_MEMORY_FILE" <<'INIT'
version: 1
description: >
  Project-scoped intelligence from user corrections and discoveries.
entries:
INIT
    fi

    # Find next project memory ID
    local max_id=0
    while IFS= read -r line; do
        if [[ "$line" =~ "- id: C-"([0-9]+) ]]; then
            local num="${BASH_REMATCH[1]}"
            num=$((10#$num))
            (( num > max_id )) && max_id=$num
        fi
    done < "$PROJECT_MEMORY_FILE"
    local next_id
    next_id=$(printf "C-%04d" $((max_id + 1)))

    local today
    today=$(date +%Y-%m-%d)

    # Escape quotes for YAML
    text="${text//\"/\\\"}"
    context="${context//\"/\\\"}"

    # Replace empty entries array if this is the first entry
    if grep -q "^entries: \[\]" "$PROJECT_MEMORY_FILE" 2>/dev/null; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' 's/^entries: \[\]/entries:/' "$PROJECT_MEMORY_FILE"
        else
            sed -i 's/^entries: \[\]/entries:/' "$PROJECT_MEMORY_FILE"
        fi
    fi

    # Append entry
    {
        echo ""
        echo "  - id: ${next_id}"
        echo "    type: ${entry_type}"
        echo "    text: \"${text}\""
        [[ -n "$context" ]] && echo "    context: \"${context}\""
        [[ -n "$source" && "$source" != "manual" ]] && echo "    source: ${source}"
        [[ -n "$session_id" ]] && echo "    session: ${session_id}"
        echo "    date: ${today}"
    } >> "$PROJECT_MEMORY_FILE"

    local type_icon="💡"
    case "$entry_type" in
        preference) type_icon="🎯" ;;
        learning)   type_icon="📚" ;;
        decision)   type_icon="⚖️" ;;
    esac

    echo -e "${GREEN}✓ Remembered ${next_id} [${entry_type}]: ${text}${NC}"
    echo -e "  ${type_icon} Stored in project-memory.yaml"
    _intel_log "mutate" "remember:${next_id}:${entry_type}:${source}" "1"

    # Decisions are stored in project-memory.yaml — no auto-journal.
    # If a decision is journal-worthy, the caller should log it explicitly.
}

# ---------------------------------------------------------------------------
# review-session — display prompt buffer for LLM-driven preference review
# ---------------------------------------------------------------------------
_intel_review_session() {
    local buffer_file="$PROJECT_ROOT/.agentic/session/prompt-buffer.log"

    if [[ ! -f "$buffer_file" ]]; then
        echo -e "${YELLOW}No prompt buffer found for this session.${NC}"
        return 0
    fi

    local count=0
    echo -e "${BOLD}Session Prompt Buffer${NC}"
    echo -e "${DIM}Review these prompts for preferences, decisions, or corrections worth capturing:${NC}"
    echo ""

    while IFS='|' read -r timestamp prompt_text; do
        [[ -z "$prompt_text" ]] && continue
        count=$((count + 1))
        echo -e "  ${DIM}${timestamp}${NC}  ${prompt_text}"
    done < "$buffer_file"

    echo ""
    echo -e "${DIM}${count} prompt(s) in buffer${NC}"
    echo ""
    echo -e "To capture: ${BOLD}ag intel remember \"...\" --type preference|learning|decision --context \"...\"${NC}"
}

# ---------------------------------------------------------------------------
# batch-remember — DEPRECATED: use review-session instead
# ---------------------------------------------------------------------------
_intel_batch_remember() {
    local buffer_file="$PROJECT_ROOT/.agentic/session/decision-buffer.log"
    local from_buffer=0

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --from-buffer) from_buffer=1 ;;
            *) buffer_file="$1" ;;
        esac
        shift
    done

    if [[ "$from_buffer" -eq 1 ]]; then
        buffer_file="$PROJECT_ROOT/.agentic/session/decision-buffer.log"
    fi

    if [[ ! -f "$buffer_file" ]]; then
        echo -e "${YELLOW}No decision buffer found at $buffer_file${NC}"
        return 0
    fi

    local count=0
    while IFS='|' read -r timestamp signal_type prompt_text; do
        [[ -z "$prompt_text" ]] && continue
        local ctype="preference"
        case "$signal_type" in
            instruction)       ctype="preference" ;;
            decision|confirmation|action_confirmed) ctype="decision" ;;
            correction)        ctype="learning" ;;
        esac
        _intel_remember "$prompt_text" --type "$ctype" \
            --context "auto-captured from $signal_type signal" \
            --source session_audit
        ((count++)) || true
    done < "$buffer_file"

    if [[ "$count" -gt 0 ]]; then
        echo -e "\n${GREEN}✓ Batch-captured $count entries from decision buffer${NC}"
    else
        echo -e "${YELLOW}Decision buffer was empty${NC}"
    fi
}

# ---------------------------------------------------------------------------
# decisions — list all decisions with provenance
# ---------------------------------------------------------------------------
_intel_decisions() {
    echo -e "${BOLD}=== Decisions ===${NC}"
    _intel_memory --type decision

    # Also show recent journal decisions
    local journal_file=""
    if [[ -f "$PROJECT_ROOT/.agentic/journal/JOURNAL.md" ]]; then
        journal_file="$PROJECT_ROOT/.agentic/journal/JOURNAL.md"
    elif [[ -f "$PROJECT_ROOT/JOURNAL.md" ]]; then
        journal_file="$PROJECT_ROOT/JOURNAL.md"
    fi

    if [[ -n "$journal_file" ]]; then
        local journal_decisions
        journal_decisions=$(grep "Decision:" "$journal_file" 2>/dev/null | tail -10 || true)
        if [[ -n "$journal_decisions" ]]; then
            echo ""
            echo -e "${BOLD}--- Journal decisions (last 10) ---${NC}"
            echo "$journal_decisions"
        fi
    fi
}

# ---------------------------------------------------------------------------
# memory — list project memory entries (preferences, learnings, decisions)
# ---------------------------------------------------------------------------
_intel_memory() {
    local type_filter=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --type) shift; type_filter="${1:-}" ;;
            *) type_filter="$1" ;;
        esac
        shift
    done

    if [[ ! -f "$PROJECT_MEMORY_FILE" ]]; then
        echo -e "${YELLOW}No project memory file found at ${PROJECT_MEMORY_FILE}${NC}"
        echo "Run: ag intel remember \"text\" to create one"
        return 0
    fi

    echo -e "${BOLD}Cerebrum${NC} (${PROJECT_MEMORY_FILE})"
    echo ""

    local count=0
    local _id="" _type="" _text="" _context="" _date=""

    _memory_print() {
        [[ -z "$_id" ]] && return

        if [[ -n "$type_filter" && "$_type" != "$type_filter" ]]; then
            return
        fi

        local icon="💡"
        case "$_type" in
            preference) icon="🎯" ;;
            learning)   icon="📚" ;;
            decision)   icon="⚖️" ;;
        esac

        echo -e "  ${icon} ${BOLD}${_id}${NC} [${_type}] ${_text}"
        [[ -n "$_context" ]] && echo -e "    ${DIM}Context: ${_context}${NC}"
        [[ -n "$_date" ]] && echo -e "    ${DIM}Date: ${_date}${NC}"
        count=$((count + 1))
    }

    while IFS= read -r line; do
        case "$line" in
            *"- id: "*)
                _memory_print
                _id="${line#*"- id: "}"; _id="${_id//\"/}"; _id="${_id## }"
                _type="" _text="" _context="" _date=""
                ;;
            *"type: "*)    _type="${line#*"type: "}"; _type="${_type//\"/}" ;;
            *"context: "*) _context="${line#*"context: "}"; _context="${_context//\"/}" ;;
            *"date: "*)    _date="${line#*"date: "}"; _date="${_date//\"/}" ;;
            *"text: "*)    _text="${line#*"text: "}"; _text="${_text//\"/}" ;;
        esac
    done < "$PROJECT_MEMORY_FILE"
    _memory_print  # last entry

    echo ""
    echo -e "${DIM}${count} entry/entries shown${NC}"
}

# ---------------------------------------------------------------------------
# forget — remove a project memory entry by ID
# ---------------------------------------------------------------------------
_intel_forget() {
    local entry_id="${1:-}"

    if [[ -z "$entry_id" ]]; then
        echo -e "${RED}Error: project memory entry ID required${NC}"
        echo "Usage: ag intel forget C-XXXX"
        return 1
    fi

    if [[ ! -f "$PROJECT_MEMORY_FILE" ]]; then
        echo -e "${RED}Error: no project memory file found${NC}"
        return 1
    fi

    if ! grep -q "id: ${entry_id}" "$PROJECT_MEMORY_FILE" 2>/dev/null; then
        echo -e "${RED}Error: entry ${entry_id} not found${NC}"
        return 1
    fi

    local tmp_file
    tmp_file=$(mktemp)
    local skip=false removed=false blank_buffer=""

    while IFS= read -r line; do
        if [[ "$line" == *"- id: ${entry_id}"* ]]; then
            skip=true; removed=true; blank_buffer=""; continue
        fi
        if $skip; then
            if [[ "$line" == *"- id: "* ]]; then
                skip=false
                echo "$line" >> "$tmp_file"
            fi
            continue
        fi
        if [[ -z "$line" ]]; then
            blank_buffer="${blank_buffer}
"
        else
            [[ -n "$blank_buffer" ]] && printf "%s" "$blank_buffer" >> "$tmp_file"
            blank_buffer=""
            echo "$line" >> "$tmp_file"
        fi
    done < "$PROJECT_MEMORY_FILE"

    if $removed; then
        mv "$tmp_file" "$PROJECT_MEMORY_FILE"
        echo -e "${GREEN}✓ Forgot ${entry_id}${NC}"
        _intel_log "mutate" "forget:${entry_id}" "1"
    else
        rm -f "$tmp_file"
        echo -e "${RED}Error: entry ${entry_id} not found${NC}"
        return 1
    fi
}

# ===========================================================================
# Phase 2: Anatomy — File Intelligence
# ===========================================================================

# ---------------------------------------------------------------------------
# scan — generate anatomy.yaml + anatomy.index from project files
# ---------------------------------------------------------------------------
_intel_scan() {
    local check_mode=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --check) check_mode=true ;;
        esac
        shift
    done

    if $check_mode; then
        _intel_scan_check
        return $?
    fi

    mkdir -p "$INTEL_DIR"

    echo -e "${BOLD}Scanning project files...${NC}"

    # Get file list (prefer git ls-files for .gitignore respect)
    local file_list
    if git -C "$ROOT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        file_list=$(cd "$ROOT_DIR" && git ls-files --cached --others --exclude-standard 2>/dev/null)
    else
        file_list=$(find "$ROOT_DIR" -type f \
            -not -path "*/.git/*" \
            -not -path "*/node_modules/*" \
            -not -path "*/__pycache__/*" \
            -not -path "*/.agentic/.cache/*" \
            -not -path "*/.agentic/session/*" \
            2>/dev/null | sed "s|^${ROOT_DIR}/||")
    fi

    local total_files=0 total_tokens=0
    local timestamp
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    # Build in temp files, then move atomically
    local tmp_yaml tmp_index
    tmp_yaml=$(mktemp)
    tmp_index=$(mktemp)

    # Write YAML header (placeholder for file_count/total_tokens — updated at end)
    cat > "$tmp_yaml" <<EOF
version: 1
generated: "$timestamp"
file_count: 0
total_tokens: 0
files:
EOF

    while IFS= read -r filepath; do
        [[ -z "$filepath" ]] && continue
        [[ ! -f "${ROOT_DIR}/${filepath}" ]] && continue

        # Skip binary / non-text files by extension
        case "$filepath" in
            *.png|*.jpg|*.jpeg|*.gif|*.ico|*.bmp|*.webp|*.svg) continue ;;
            *.woff|*.woff2|*.ttf|*.eot|*.otf) continue ;;
            *.mp3|*.mp4|*.avi|*.mov|*.wav|*.ogg) continue ;;
            *.zip|*.tar|*.gz|*.bz2|*.xz|*.7z|*.rar) continue ;;
            *.pyc|*.pyo|*.so|*.dylib|*.o|*.a|*.class) continue ;;
            *.exe|*.dll|*.bin|*.dat) continue ;;
            package-lock.json|yarn.lock|pnpm-lock.yaml|Gemfile.lock|Cargo.lock|poetry.lock|composer.lock) continue ;;
        esac

        # Skip files > 500KB (likely generated)
        local file_size
        file_size=$(wc -c < "${ROOT_DIR}/${filepath}" 2>/dev/null || echo 0)
        file_size="${file_size## }"
        (( file_size > 512000 )) && continue

        local lang summary tokens

        # Language detection
        lang=$(_intel_detect_language "$filepath")

        # Token estimate: ~4 chars per token
        tokens=$(( file_size / 4 ))

        # Summary extraction
        summary=$(_intel_extract_summary "${ROOT_DIR}/${filepath}" "$lang")
        # Escape double quotes and backslashes for YAML
        summary="${summary//\\/\\\\}"
        summary="${summary//\"/\\\"}"

        # Append to YAML
        cat >> "$tmp_yaml" <<EOF
  - path: "$filepath"
    summary: "$summary"
    tokens: $tokens
    language: $lang
    related: []
EOF

        # Append to index (tab-separated: path, summary, tokens, language)
        printf '%s\t%s\t%d\t%s\n' "$filepath" "$summary" "$tokens" "$lang" >> "$tmp_index"

        total_files=$((total_files + 1))
        total_tokens=$((total_tokens + tokens))
    done <<< "$file_list"

    # Update counts in YAML header
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s/^file_count: 0/file_count: $total_files/" "$tmp_yaml"
        sed -i '' "s/^total_tokens: 0/total_tokens: $total_tokens/" "$tmp_yaml"
    else
        sed -i "s/^file_count: 0/file_count: $total_files/" "$tmp_yaml"
        sed -i "s/^total_tokens: 0/total_tokens: $total_tokens/" "$tmp_yaml"
    fi

    # Atomic move
    mv "$tmp_yaml" "$ANATOMY_FILE"
    mv "$tmp_index" "$ANATOMY_INDEX"

    echo -e "${GREEN}✓ Scanned ${total_files} files (~${total_tokens} estimated tokens)${NC}"
    echo -e "  ${DIM}${ANATOMY_FILE}${NC}"
    echo -e "  ${DIM}${ANATOMY_INDEX} (gitignored, for fast lookup)${NC}"
    _intel_log "scan" "anatomy" "$total_files"
}

_intel_scan_check() {
    if [[ ! -f "$ANATOMY_FILE" ]]; then
        echo -e "${RED}anatomy.yaml missing. Run: ag intel scan${NC}"
        return 1
    fi

    # Check if any tracked files are newer than anatomy.yaml.
    # Prefer git ls-files to avoid false positives from build artifacts.
    local stale_files
    if git -C "$ROOT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        stale_files=$(cd "$ROOT_DIR" && git ls-files --cached --others --exclude-standard 2>/dev/null \
            | while IFS= read -r f; do
                # Skip session/cache files — they change every tool use and aren't project code
                if [[ "$f" == .agentic/session/* || "$f" == .agentic/.cache/* ]]; then continue; fi
                [[ -f "$f" && "$f" -nt "$ANATOMY_FILE" ]] && echo "$f" && break
              done)
    else
        stale_files=$(find "$ROOT_DIR" -type f \
            -newer "$ANATOMY_FILE" \
            -not -path "*/.git/*" \
            -not -path "*/node_modules/*" \
            -not -path "*/__pycache__/*" \
            -not -path "*/.agentic/session/*" \
            -not -path "*/.agentic/.cache/*" \
            -not -path "*/build/*" \
            -not -path "*/dist/*" \
            -not -path "*/.next/*" \
            -not -path "*/target/*" \
            2>/dev/null | head -1)
    fi

    if [[ -n "$stale_files" ]]; then
        echo -e "${YELLOW}anatomy.yaml is stale (files changed since last scan)${NC}"
        echo "Run: ag intel scan"
        return 1
    fi

    echo -e "${GREEN}✓ anatomy.yaml is fresh${NC}"
    return 0
}

# ---------------------------------------------------------------------------
# Language detection from file extension
# ---------------------------------------------------------------------------
_intel_detect_language() {
    local filepath="$1"
    local ext="${filepath##*.}"
    local basename="${filepath##*/}"

    case "$ext" in
        py)             echo "python" ;;
        sh|bash|zsh)    echo "shell" ;;
        js|mjs|cjs)     echo "javascript" ;;
        ts|mts|cts)     echo "typescript" ;;
        tsx)            echo "tsx" ;;
        jsx)            echo "jsx" ;;
        rb)             echo "ruby" ;;
        go)             echo "go" ;;
        rs)             echo "rust" ;;
        java)           echo "java" ;;
        kt|kts)         echo "kotlin" ;;
        swift)          echo "swift" ;;
        c|h)            echo "c" ;;
        cpp|cc|cxx|hpp) echo "cpp" ;;
        cs)             echo "csharp" ;;
        yaml|yml)       echo "yaml" ;;
        json)           echo "json" ;;
        md)             echo "markdown" ;;
        txt)            echo "text" ;;
        toml)           echo "toml" ;;
        cfg|ini|conf)   echo "config" ;;
        html|htm)       echo "html" ;;
        css)            echo "css" ;;
        scss)           echo "scss" ;;
        sass)           echo "sass" ;;
        less)           echo "less" ;;
        sql)            echo "sql" ;;
        *)
            case "$basename" in
                Makefile|makefile|GNUmakefile) echo "makefile" ;;
                Dockerfile*)                   echo "dockerfile" ;;
                .gitignore|.gitattributes)     echo "config" ;;
                *)                             echo "unknown" ;;
            esac
            ;;
    esac
}

# ---------------------------------------------------------------------------
# Extract a one-line summary from a file's first few lines
# ---------------------------------------------------------------------------
_intel_extract_summary() {
    local filepath="$1" lang="$2"
    local line=""

    case "$lang" in
        python|shell|yaml|config|toml|ruby|makefile)
            # Hash-comment languages: first comment line (skip shebang)
            line=$(head -10 "$filepath" 2>/dev/null | grep -m1 '^[[:space:]]*#[^!]' | sed 's/^[[:space:]]*#[[:space:]]*//')
            ;;
        javascript|typescript|tsx|jsx|go|rust|java|kotlin|swift|c|cpp|csharp|css|scss|sass|less)
            # C-style comment languages
            line=$(head -20 "$filepath" 2>/dev/null | grep -m1 -E '^[[:space:]]*(//|/\*)' | sed 's|^[[:space:]]*/[/*][[:space:]]*||' | sed 's|\*/.*||')
            ;;
        markdown)
            # First heading
            line=$(head -5 "$filepath" 2>/dev/null | grep -m1 '^#' | sed 's/^#*[[:space:]]*//')
            ;;
        json)
            # No comments — use filename
            line=""
            ;;
        *)
            line=$(head -3 "$filepath" 2>/dev/null | grep -m1 -v '^[[:space:]]*$')
            ;;
    esac

    # Truncate to 80 chars, fallback to filename
    line="${line:0:80}"
    # Trim trailing whitespace
    line="${line%"${line##*[![:space:]]}"}"

    if [[ -z "$line" ]]; then
        line="${filepath##*/}"
    fi

    echo "$line"
}

# ---------------------------------------------------------------------------
# Rebuild anatomy.index from anatomy.yaml (for when YAML is pulled from git)
# ---------------------------------------------------------------------------
_intel_rebuild_index() {
    [[ ! -f "$ANATOMY_FILE" ]] && return 1

    local tmp_index
    tmp_index=$(mktemp)
    local _path="" _summary="" _tokens="" _lang=""

    _anat_flush() {
        if [[ -n "$_path" ]]; then
            printf '%s\t%s\t%s\t%s\n' "$_path" "$_summary" "${_tokens:-0}" "${_lang:-unknown}" >> "$tmp_index"
        fi
    }

    while IFS= read -r line; do
        case "$line" in
            *"- path: "*)
                _anat_flush
                _path="${line#*\"}" ; _path="${_path%%\"*}"
                _summary="" _tokens="" _lang=""
                ;;
            *"summary: "*)
                _summary="${line#*\"}" ; _summary="${_summary%%\"*}"
                ;;
            *"tokens: "*)
                _tokens="${line#*"tokens: "}" ; _tokens="${_tokens%% *}"
                ;;
            *"language: "*)
                _lang="${line#*"language: "}" ; _lang="${_lang%% *}"
                ;;
        esac
    done < "$ANATOMY_FILE"
    _anat_flush
    unset -f _anat_flush

    mv "$tmp_index" "$ANATOMY_INDEX"
}

# ---------------------------------------------------------------------------
# file — lookup a file's intelligence from anatomy.index
# ---------------------------------------------------------------------------
_intel_file() {
    local target_path="${1:-}"

    if [[ -z "$target_path" ]]; then
        echo -e "${RED}Error: PATH required${NC}"
        echo "Usage: ag intel file PATH"
        return 1
    fi

    # Normalize: strip leading ./ or /
    target_path="${target_path#./}"
    target_path="${target_path#"${ROOT_DIR}/"}"

    # Rebuild index from YAML if index is missing but YAML exists
    if [[ ! -f "$ANATOMY_INDEX" && -f "$ANATOMY_FILE" ]]; then
        _intel_rebuild_index
    fi

    # Try anatomy.index (fast grep)
    if [[ -f "$ANATOMY_INDEX" ]]; then
        local result
        result=$(grep "^${target_path}	" "$ANATOMY_INDEX" 2>/dev/null | head -1)

        if [[ -n "$result" ]]; then
            local summary tokens lang
            IFS=$'\t' read -r _ summary tokens lang <<< "$result"

            echo -e "${BOLD}${target_path}${NC}"
            echo -e "  ~${tokens} tokens | ${lang}"
            echo -e "  ${DIM}${summary}${NC}"
            return 0
        fi
    fi

    # Fallback: compute on-the-fly if file exists
    local abs_path="${ROOT_DIR}/${target_path}"
    if [[ -f "$abs_path" ]]; then
        local lang char_count tokens summary
        lang=$(_intel_detect_language "$target_path")
        char_count=$(wc -c < "$abs_path" 2>/dev/null || echo 0)
        char_count="${char_count## }"
        tokens=$(( char_count / 4 ))
        summary=$(_intel_extract_summary "$abs_path" "$lang")

        echo -e "${BOLD}${target_path}${NC} ${DIM}(not in index)${NC}"
        echo -e "  ~${tokens} tokens | ${lang}"
        echo -e "  ${DIM}${summary}${NC}"
        echo -e ""
        echo -e "${YELLOW}Run 'ag intel scan' to update the index${NC}"
        return 0
    fi

    echo -e "${RED}File not found: ${target_path}${NC}"
    return 1
}

# ===========================================================================
# Phase 2: Token Ledger — Measurement & Metrics
# ===========================================================================

# ---------------------------------------------------------------------------
# stats — display token metrics (session + lifetime)
# ---------------------------------------------------------------------------
_intel_stats() {
    local session_only=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --session) session_only=true ;;
        esac
        shift
    done

    echo -e "${BOLD}Intelligence Engine — Metrics${NC}"
    echo ""

    _intel_show_session_stats
    echo ""
    _intel_show_session_intel_stats

    if ! $session_only; then
        echo ""
        _intel_show_lifetime_stats
        echo ""
        _intel_show_lifetime_intel_stats
    fi
}

_intel_show_session_stats() {
    if [[ ! -f "$TOKEN_EVENTS" ]]; then
        echo -e "  ${DIM}No session data yet (tracking starts after first tool use)${NC}"
        return 0
    fi

    local reads writes unique_reads repeated_reads estimated_cost
    reads=$(grep -c '^R|' "$TOKEN_EVENTS" 2>/dev/null || echo 0)
    writes=$(grep -c '^W|' "$TOKEN_EVENTS" 2>/dev/null || echo 0)
    unique_reads=$(grep '^R|' "$TOKEN_EVENTS" 2>/dev/null | cut -d'|' -f2 | sort -u | wc -l 2>/dev/null || echo 0)
    unique_reads="${unique_reads## }"
    repeated_reads=$((reads - unique_reads))
    if [[ $repeated_reads -lt 0 ]]; then repeated_reads=0; fi
    estimated_cost=$(awk -F'|' '{sum += $3} END {print sum+0}' "$TOKEN_EVENTS" 2>/dev/null || echo 0)

    echo -e "${BOLD}📊 Current Session${NC}"
    echo -e "  Reads:        ${reads} total, ${unique_reads} unique, ${repeated_reads} repeated"
    echo -e "  Writes:       ${writes}"
    echo -e "  Est. context: ~${estimated_cost} tokens"
}

_intel_show_lifetime_stats() {
    if [[ ! -f "$TOKEN_SUMMARY" ]]; then
        echo -e "  ${DIM}No lifetime data yet (aggregated after first session ends)${NC}"
        return 0
    fi

    local sessions reads writes repeated cost updated
    sessions=$(_intel_json_int "$TOKEN_SUMMARY" "total_sessions")
    reads=$(_intel_json_int "$TOKEN_SUMMARY" "total_reads")
    writes=$(_intel_json_int "$TOKEN_SUMMARY" "total_writes")
    repeated=$(_intel_json_int "$TOKEN_SUMMARY" "total_repeated_reads")
    cost=$(_intel_json_int "$TOKEN_SUMMARY" "total_estimated_cost")
    updated=$(_intel_json_str "$TOKEN_SUMMARY" "last_updated")

    echo -e "${BOLD}📈 Lifetime Aggregate${NC}"
    echo -e "  Sessions:     ${sessions}"
    echo -e "  Total reads:  ${reads} (${repeated} repeated)"
    echo -e "  Total writes: ${writes}"
    echo -e "  Est. context: ~${cost} tokens"
    [[ -n "$updated" ]] && echo -e "  ${DIM}Last updated: ${updated}${NC}"
}

_intel_show_session_intel_stats() {
    if [[ ! -f "$INTEL_EVENTS" ]]; then
        echo -e "  ${DIM}No intel sourcing events yet${NC}"
        return 0
    fi

    local queries enforces mutates scans total_items
    queries=$(grep -c '^.*|query|' "$INTEL_EVENTS" 2>/dev/null || echo 0)
    enforces=$(grep -c '^.*|enforce|' "$INTEL_EVENTS" 2>/dev/null || echo 0)
    mutates=$(grep -c '^.*|mutate|' "$INTEL_EVENTS" 2>/dev/null || echo 0)
    scans=$(grep -c '^.*|scan|' "$INTEL_EVENTS" 2>/dev/null || echo 0)
    total_items=$(awk -F'|' '{sum += $4} END {print sum+0}' "$INTEL_EVENTS" 2>/dev/null || echo 0)

    echo -e "${BOLD}🧠 Intelligence Sourcing (Session)${NC}"
    echo -e "  Queries:       ${queries} (ag intel architecture|spec|implement|test)"
    echo -e "  Enforcements:  ${enforces} (pattern warnings at write-time)"
    echo -e "  Mutations:     ${mutates} (learn, remember, forget, remove)"
    echo -e "  Scans:         ${scans} (anatomy, bootstrap, retro)"
    echo -e "  Items sourced: ${total_items}"
    if [[ $queries -eq 0 && $enforces -eq 0 ]]; then
        echo -e "  ${YELLOW}⚠ No intelligence queried — agent may be improvising${NC}"
    fi
}

_intel_show_lifetime_intel_stats() {
    if [[ ! -f "$INTEL_SUMMARY" ]]; then
        echo -e "  ${DIM}No lifetime intel data yet${NC}"
        return 0
    fi

    local sessions queries enforces mutates scans items updated
    sessions=$(_intel_json_int "$INTEL_SUMMARY" "total_sessions")
    queries=$(_intel_json_int "$INTEL_SUMMARY" "total_queries")
    enforces=$(_intel_json_int "$INTEL_SUMMARY" "total_enforcements")
    mutates=$(_intel_json_int "$INTEL_SUMMARY" "total_mutations")
    scans=$(_intel_json_int "$INTEL_SUMMARY" "total_scans")
    items=$(_intel_json_int "$INTEL_SUMMARY" "total_items_surfaced")
    updated=$(_intel_json_str "$INTEL_SUMMARY" "last_updated")

    echo -e "${BOLD}🧠 Intelligence Sourcing (Lifetime)${NC}"
    echo -e "  Sessions:      ${sessions}"
    echo -e "  Queries:       ${queries}"
    echo -e "  Enforcements:  ${enforces}"
    echo -e "  Mutations:     ${mutates}"
    echo -e "  Scans:         ${scans}"
    echo -e "  Items sourced: ${items}"
    [[ -n "$updated" ]] && echo -e "  ${DIM}Last updated: ${updated}${NC}"
}

# ---------------------------------------------------------------------------
# JSON helpers — extract values from simple flat JSON without jq
# ---------------------------------------------------------------------------
_intel_json_int() {
    local file="$1" key="$2"
    # Anchored match: requires key followed by ": <digits>" — head -1 prevents substring collisions
    grep -o "\"${key}\"[[:space:]]*:[[:space:]]*[0-9]*" "$file" 2>/dev/null | head -1 | grep -o '[0-9]*$' || echo 0
}

_intel_json_str() {
    local file="$1" key="$2"
    grep -o "\"${key}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "$file" 2>/dev/null | head -1 | sed "s/.*\"${key}\"[[:space:]]*:[[:space:]]*\"//;s/\"//" || echo ""
}

# ===========================================================================
# Phase 3: Bootstrap + Quality Intelligence
# ===========================================================================

QUALITY_CHECKLIST="${INTEL_DIR}/quality-checklist.yaml"
TEST_STRATEGY="${INTEL_DIR}/test-strategy.yaml"

# ---------------------------------------------------------------------------
# bootstrap — gather stack + codebase context, output generation instructions
# ---------------------------------------------------------------------------
_intel_bootstrap() {
    local STACK_FILE="${ROOT_DIR}/STACK.md"

    echo -e "${BOLD}Intelligence Bootstrap${NC}"
    echo -e "${DIM}Analyzing project stack and codebase...${NC}"
    echo ""

    # --- 1. Read STACK.md ---
    local stack_lang="" stack_framework="" stack_domain="" stack_db="" stack_deploy=""
    local stack_testing="" stack_pkg="" stack_platform=""

    if [[ -f "$STACK_FILE" ]]; then
        # Helper to extract "- Key: value" or "- Key(s): value" from STACK.md
        _stack_get() {
            grep -iE "^-\s*$1" "$STACK_FILE" 2>/dev/null | head -1 | sed 's/^[^:]*: *//' | sed 's/#.*//' | sed 's/[[:space:]]*$//' || true
        }
        stack_lang=$(_stack_get "Language")
        stack_framework=$(_stack_get "(App framework|app_framework|App Framework)")
        stack_domain=$(_stack_get "Domain")
        stack_db=$(_stack_get "Database")
        stack_deploy=$(_stack_get "(Deploy|Hosting)")
        stack_testing=$(_stack_get "(Testing|Test framework|test_framework)")
        stack_pkg=$(_stack_get "Package manager")
        stack_platform=$(_stack_get "Primary platform")
        echo -e "${GREEN}✓ STACK.md found${NC}"
    else
        echo -e "${YELLOW}⚠ No STACK.md found — using codebase detection only${NC}"
    fi

    # --- 2. Detect from codebase ---
    local detected_langs="" detected_frameworks="" detected_test_frameworks=""
    local detected_pkg="" detected_dirs="" detected_key_imports=""

    # Helper: grep-based detection safe under set -e
    _has_dep() { echo "$1" | grep -qiw "$2" 2>/dev/null; }

    # Package manager / language detection
    if [[ -f "${ROOT_DIR}/package.json" ]]; then
        detected_langs="${detected_langs}javascript/typescript, "
        detected_pkg="npm"
        [[ -f "${ROOT_DIR}/yarn.lock" ]] && detected_pkg="yarn"
        [[ -f "${ROOT_DIR}/pnpm-lock.yaml" ]] && detected_pkg="pnpm"
        [[ -f "${ROOT_DIR}/bun.lockb" ]] && detected_pkg="bun"

        # Extract key dependencies from package.json
        local pkg_deps
        pkg_deps=$(grep -oE '"[^"]+":' "${ROOT_DIR}/package.json" 2>/dev/null | tr -d '":' | sort -u | head -30 || true)
        # Detect frameworks from dependencies
        _has_dep "$pkg_deps" "react" && detected_frameworks="${detected_frameworks}React, "
        _has_dep "$pkg_deps" "next" && detected_frameworks="${detected_frameworks}Next.js, "
        _has_dep "$pkg_deps" "vue" && detected_frameworks="${detected_frameworks}Vue, "
        _has_dep "$pkg_deps" "nuxt" && detected_frameworks="${detected_frameworks}Nuxt, "
        _has_dep "$pkg_deps" "svelte" && detected_frameworks="${detected_frameworks}Svelte, "
        _has_dep "$pkg_deps" "express" && detected_frameworks="${detected_frameworks}Express, "
        _has_dep "$pkg_deps" "fastify" && detected_frameworks="${detected_frameworks}Fastify, "
        _has_dep "$pkg_deps" "nestjs" && detected_frameworks="${detected_frameworks}NestJS, "
        _has_dep "$pkg_deps" "angular" && detected_frameworks="${detected_frameworks}Angular, "
        # Detect test frameworks
        _has_dep "$pkg_deps" "jest" && detected_test_frameworks="${detected_test_frameworks}jest, "
        _has_dep "$pkg_deps" "vitest" && detected_test_frameworks="${detected_test_frameworks}vitest, "
        _has_dep "$pkg_deps" "mocha" && detected_test_frameworks="${detected_test_frameworks}mocha, "
        _has_dep "$pkg_deps" "playwright" && detected_test_frameworks="${detected_test_frameworks}playwright, "
        _has_dep "$pkg_deps" "cypress" && detected_test_frameworks="${detected_test_frameworks}cypress, "
        _has_dep "$pkg_deps" "testing-library" && detected_test_frameworks="${detected_test_frameworks}testing-library, "
    fi

    if [[ -f "${ROOT_DIR}/requirements.txt" || -f "${ROOT_DIR}/pyproject.toml" || -f "${ROOT_DIR}/setup.py" || -f "${ROOT_DIR}/Pipfile" ]]; then
        detected_langs="${detected_langs}python, "
        if [[ -z "$detected_pkg" ]]; then
            detected_pkg="pip"
            [[ -f "${ROOT_DIR}/Pipfile" ]] && detected_pkg="pipenv"
            [[ -f "${ROOT_DIR}/poetry.lock" ]] && detected_pkg="poetry"
        fi

        # Detect frameworks from requirements/pyproject
        local py_deps=""
        [[ -f "${ROOT_DIR}/requirements.txt" ]] && py_deps=$(cat "${ROOT_DIR}/requirements.txt" 2>/dev/null || true)
        [[ -f "${ROOT_DIR}/pyproject.toml" ]] && py_deps="${py_deps} $(cat "${ROOT_DIR}/pyproject.toml" 2>/dev/null || true)"
        _has_dep "$py_deps" "django" && detected_frameworks="${detected_frameworks}Django, "
        _has_dep "$py_deps" "flask" && detected_frameworks="${detected_frameworks}Flask, "
        _has_dep "$py_deps" "fastapi" && detected_frameworks="${detected_frameworks}FastAPI, "
        _has_dep "$py_deps" "pytest" && detected_test_frameworks="${detected_test_frameworks}pytest, "
        _has_dep "$py_deps" "unittest" && detected_test_frameworks="${detected_test_frameworks}unittest, "
    fi

    if [[ -f "${ROOT_DIR}/Cargo.toml" ]]; then
        detected_langs="${detected_langs}rust, "
        detected_pkg="cargo"
    fi

    if [[ -f "${ROOT_DIR}/go.mod" ]]; then
        detected_langs="${detected_langs}go, "
        detected_pkg="go modules"
    fi

    if [[ -f "${ROOT_DIR}/Gemfile" ]]; then
        detected_langs="${detected_langs}ruby, "
        detected_pkg="bundler"
        local rb_deps
        rb_deps=$(cat "${ROOT_DIR}/Gemfile" 2>/dev/null || true)
        _has_dep "$rb_deps" "rails" && detected_frameworks="${detected_frameworks}Rails, "
        _has_dep "$rb_deps" "rspec" && detected_test_frameworks="${detected_test_frameworks}rspec, "
    fi

    if [[ -f "${ROOT_DIR}/build.gradle" || -f "${ROOT_DIR}/build.gradle.kts" || -f "${ROOT_DIR}/pom.xml" ]]; then
        detected_langs="${detected_langs}java/kotlin, "
        [[ -f "${ROOT_DIR}/build.gradle" || -f "${ROOT_DIR}/build.gradle.kts" ]] && detected_pkg="gradle"
        [[ -f "${ROOT_DIR}/pom.xml" ]] && detected_pkg="maven"
    fi

    # Detect TypeScript specifically
    if [[ -f "${ROOT_DIR}/tsconfig.json" ]]; then
        detected_langs=$(echo "$detected_langs" | sed 's/javascript\/typescript/typescript/' || true)
    fi

    # Trim trailing ", "
    detected_langs="${detected_langs%, }"
    detected_frameworks="${detected_frameworks%, }"
    detected_test_frameworks="${detected_test_frameworks%, }"

    # Directory structure scan
    local dir_list=""
    for d in src lib app pages components hooks utils helpers services api routes models controllers tests test spec __tests__ e2e cypress public static assets docs; do
        [[ -d "${ROOT_DIR}/${d}" ]] && dir_list="${dir_list}${d}/, "
    done
    dir_list="${dir_list%, }"

    # Test directory detection
    local test_dirs=""
    for d in tests test spec __tests__ e2e cypress; do
        [[ -d "${ROOT_DIR}/${d}" ]] && test_dirs="${test_dirs}${d}/, "
    done
    test_dirs="${test_dirs%, }"

    # Count files by type
    local file_counts=""
    if git -C "$ROOT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        file_counts=$(cd "$ROOT_DIR" && git ls-files --cached --others --exclude-standard 2>/dev/null \
            | sed 's/.*\.//' | sort | uniq -c | sort -rn | head -10 || true)
    fi

    echo -e "${GREEN}✓ Codebase scanned${NC}"
    echo ""

    # --- 3. Merge STACK.md + detected info ---
    local final_lang="${stack_lang:-$detected_langs}"
    local final_framework="${stack_framework:-$detected_frameworks}"
    local final_test="${stack_testing:-$detected_test_frameworks}"
    local final_pkg="${stack_pkg:-$detected_pkg}"
    local final_domain="${stack_domain:-}"
    local final_db="${stack_db:-}"
    local final_deploy="${stack_deploy:-}"
    local final_platform="${stack_platform:-}"

    # --- 4. Output stack summary ---
    echo "═══════════════════════════════════════════════════════"
    echo -e "${BOLD}Stack Analysis${NC}"
    echo "═══════════════════════════════════════════════════════"
    echo ""
    echo -e "  Language:       ${final_lang:-unknown}"
    echo -e "  Framework:      ${final_framework:-none detected}"
    echo -e "  Domain:         ${final_domain:-not specified}"
    echo -e "  Database:       ${final_db:-none detected}"
    echo -e "  Deployment:     ${final_deploy:-not specified}"
    echo -e "  Package mgr:    ${final_pkg:-unknown}"
    echo -e "  Test framework: ${final_test:-none detected}"
    echo -e "  Platform:       ${final_platform:-not specified}"
    echo -e "  Directories:    ${dir_list:-none detected}"
    echo -e "  Test dirs:      ${test_dirs:-none detected}"
    echo ""

    if [[ -n "$file_counts" ]]; then
        echo -e "  ${BOLD}File types:${NC}"
        echo "$file_counts" | while IFS= read -r line; do
            echo "    $line"
        done
        echo ""
    fi

    # --- 5. Check existing intel files ---
    local has_quality=false has_strategy=false
    [[ -f "$QUALITY_CHECKLIST" ]] && has_quality=true
    [[ -f "$TEST_STRATEGY" ]] && has_strategy=true

    if $has_quality || $has_strategy; then
        echo -e "${YELLOW}⚠ Existing intelligence files detected:${NC}"
        $has_quality && echo -e "  - quality-checklist.yaml (will be overwritten)"
        $has_strategy && echo -e "  - test-strategy.yaml (will be overwritten)"
        echo ""
    fi

    # --- 6. Output generation instructions ---
    echo "═══════════════════════════════════════════════════════"
    echo -e "${BOLD}Generation Instructions${NC}"
    echo "═══════════════════════════════════════════════════════"
    echo ""
    echo "Based on the stack analysis above, generate three artifacts:"
    echo ""
    echo -e "${BOLD}1. Quality Checklist${NC} → ${QUALITY_CHECKLIST}"
    echo "   Generate quality-checklist.yaml with this structure:"
    echo ""
    cat <<'TEMPLATE_QC'
   version: 1
   source: bootstrap
   stack: "<detected stack summary>"
   dimensions:
     usability:
       planning:
         - "<actionable check item referencing concrete tool/pattern>"
       spec:
         - "<item>"
       implementation:
         - "<item>"
       testing:
         - "<item>"
     architecture:
       planning: [...]
       spec: [...]
       implementation: [...]
       testing: [...]
     code_quality:
       planning: [...]
       spec: [...]
       implementation: [...]
       testing: [...]
     testability:
       planning: [...]
       spec: [...]
       implementation: [...]
       testing: [...]
     spec_adherence:
       planning:
         - "<item> [formal]"  # Items with [formal] are hidden in Discovery mode
       spec: [...]
       implementation: [...]
       testing: [...]
TEMPLATE_QC
    echo ""
    echo "   Requirements:"
    echo "   - Items must be ACTIONABLE and SPECIFIC to the ${final_lang:-detected} + ${final_framework:-detected} stack"
    echo "   - Reference concrete tools, libraries, or patterns (e.g., 'axe-core accessibility checks' not 'check accessibility')"
    echo "   - 3-5 items per dimension × phase (not generic platitudes)"
    echo "   - Items tagged [formal] only shown when profile is formal/autonomous_formal"
    echo "   - Domain-specific items if domain is known: ${final_domain:-not specified}"
    echo ""
    echo -e "${BOLD}2. Test Strategy${NC} → ${TEST_STRATEGY}"
    echo "   Generate test-strategy.yaml with this structure:"
    echo ""
    cat <<'TEMPLATE_TS'
   version: 1
   source: bootstrap
   stack: "<detected stack summary>"
   levels:
     unit:
       focus: "<what to test at this level>"
       framework: "<detected or recommended test framework>"
       colocate: true  # or false — tests next to source?
       patterns:
         - "<positive testing pattern>"
       antipatterns:
         - "<common mistake to avoid>"
     component:
       focus: "..."
       framework: "..."
       patterns: [...]
       antipatterns: [...]
     integration:
       focus: "..."
       framework: "..."
       patterns: [...]
       antipatterns: [...]
     e2e:
       focus: "..."
       framework: "..."
       patterns: [...]
       antipatterns: [...]
TEMPLATE_TS
    echo ""
    echo "   Requirements:"
    echo "   - Framework field should match detected test framework: ${final_test:-recommend based on stack}"
    echo "   - Focus describes WHAT to test at each level (not how)"
    echo "   - Patterns: 2-4 positive practices specific to the stack"
    echo "   - Antipatterns: 2-3 common mistakes specific to the stack"
    echo ""
    echo -e "${BOLD}3. Stack-Specific Patterns${NC} → append to ${PATTERNS_FILE}"
    echo "   Generate 5-10 anti-patterns specific to ${final_lang:-the detected stack} + ${final_framework:-the detected framework}."
    echo "   Use \`ag intel learn\` to add each pattern. Example:"
    echo ""
    echo "   ag intel learn \"Don't use any type — defeats TypeScript safety\" \\"
    echo "     --reason \"Type safety is the primary value of TypeScript\" \\"
    echo "     --scope \"*.ts\" --severity warning"
    echo ""
    echo "   Each pattern needs: text (what not to do), reason (why), scope (file glob), severity."
    echo ""

    echo "═══════════════════════════════════════════════════════"
    echo -e "${BOLD}After Generation${NC}"
    echo "═══════════════════════════════════════════════════════"
    echo ""
    echo "1. Write quality-checklist.yaml to: ${QUALITY_CHECKLIST}"
    echo "2. Write test-strategy.yaml to: ${TEST_STRATEGY}"
    echo "3. Add patterns via: ag intel learn \"text\" --reason \"why\" --scope \"glob\""
    echo "4. Review generated content with the user before finalizing"
    echo ""
    echo -e "${DIM}Tip: Run \`ag intel retro\` after using the project for a while to discover additional patterns from real issues.${NC}"

    unset -f _stack_get _has_dep

    # Log: count detected sources (STACK.md + each package file found)
    local _il_items=0
    [[ -f "$STACK_FILE" ]] && _il_items=$(( _il_items + 1 ))
    [[ -n "$detected_langs" ]] && _il_items=$(( _il_items + 1 ))
    [[ -n "$detected_frameworks" ]] && _il_items=$(( _il_items + 1 ))
    [[ -n "$detected_test_frameworks" ]] && _il_items=$(( _il_items + 1 ))
    _intel_log "scan" "bootstrap" "$_il_items"
}

# ---------------------------------------------------------------------------
# retro — analyze issues/lessons for pattern extraction opportunities
# ---------------------------------------------------------------------------
_intel_retro() {
    local ISSUES_FILE="${ROOT_DIR}/.agentic/ISSUES.md"
    local LESSONS_FILE="${ROOT_DIR}/.agentic/LESSONS.md"
    local FEATURES_FILE="${ROOT_DIR}/.agentic/spec/FEATURES.md"

    echo -e "${BOLD}Intelligence Retro${NC}"
    echo -e "${DIM}Analyzing project history for pattern opportunities...${NC}"
    echo ""

    local has_data=false

    # --- 1. Read existing patterns to avoid duplicates ---
    local existing_patterns=""
    if [[ -f "$PATTERNS_FILE" ]]; then
        existing_patterns=$(grep "text:" "$PATTERNS_FILE" 2>/dev/null | sed 's/.*text: *//' | sed 's/"//g' || true)
        local pattern_count
        pattern_count=$(_intel_count "^  - id:" "$PATTERNS_FILE")
        echo -e "${GREEN}✓ ${pattern_count} existing patterns loaded${NC}"
    else
        echo -e "${YELLOW}⚠ No patterns.yaml — retro will suggest initial patterns${NC}"
    fi

    # --- 2. Analyze ISSUES.md ---
    echo ""
    echo "═══════════════════════════════════════════════════════"
    echo -e "${BOLD}Issues Analysis${NC}"
    echo "═══════════════════════════════════════════════════════"
    echo ""

    if [[ -f "$ISSUES_FILE" ]]; then
        has_data=true
        local issue_count
        issue_count=$(grep -cE "^##\s" "$ISSUES_FILE" 2>/dev/null || echo 0)
        echo -e "Found ${issue_count} issue(s) in ISSUES.md"
        echo ""

        # Show issues grouped by status/severity if available
        local open_issues
        open_issues=$(grep -B1 -A5 "status:.*open\|Status:.*Open\|^## " "$ISSUES_FILE" 2>/dev/null | head -40 || true)
        if [[ -n "$open_issues" ]]; then
            echo -e "${BOLD}Open/Recent Issues:${NC}"
            echo "$open_issues"
            echo ""
        else
            echo -e "${DIM}Issue content:${NC}"
            head -60 "$ISSUES_FILE" 2>/dev/null
            echo ""
        fi
    else
        echo -e "${DIM}No ISSUES.md found — skip issue analysis${NC}"
    fi

    # --- 3. Analyze LESSONS.md ---
    echo "═══════════════════════════════════════════════════════"
    echo -e "${BOLD}Lessons Analysis${NC}"
    echo "═══════════════════════════════════════════════════════"
    echo ""

    if [[ -f "$LESSONS_FILE" ]]; then
        has_data=true
        local lesson_count
        lesson_count=$(grep -cE "^##\s|^- L-[0-9]" "$LESSONS_FILE" 2>/dev/null || echo 0)
        echo -e "Found ${lesson_count} lesson(s) in LESSONS.md"
        echo ""

        # Check which lessons already have corresponding patterns
        echo -e "${BOLD}Lessons NOT yet in patterns.yaml:${NC}"
        local unextracted=0
        while IFS= read -r line; do
            # Try to match lesson text against existing pattern texts
            local lesson_text="${line#*: }"
            lesson_text="${lesson_text:0:60}"  # First 60 chars for matching
            if [[ -z "$existing_patterns" ]] || ! echo "$existing_patterns" | grep -qiF "${lesson_text:0:30}"; then
                echo "  → $line"
                unextracted=$((unextracted + 1))
            fi
        done < <(grep -E "^##\s|^- L-[0-9]" "$LESSONS_FILE" 2>/dev/null | head -20 || true)

        if [[ $unextracted -eq 0 ]]; then
            echo -e "  ${GREEN}All lessons already covered by patterns${NC}"
        fi
        echo ""
    else
        echo -e "${DIM}No LESSONS.md found — skip lesson analysis${NC}"
    fi

    # --- 4. Analyze shipped features for quality gaps ---
    echo "═══════════════════════════════════════════════════════"
    echo -e "${BOLD}Shipped Features${NC}"
    echo "═══════════════════════════════════════════════════════"
    echo ""

    if [[ -f "$FEATURES_FILE" ]]; then
        has_data=true
        local shipped
        shipped=$(grep -iE "shipped|done|complete" "$FEATURES_FILE" 2>/dev/null | head -20 || true)
        if [[ -n "$shipped" ]]; then
            local shipped_count
            shipped_count=$(echo "$shipped" | wc -l)
            shipped_count="${shipped_count## }"
            echo -e "${shipped_count} shipped feature(s)"
            echo "$shipped" | head -10
        else
            echo -e "${DIM}No shipped features found${NC}"
        fi
    else
        echo -e "${DIM}No FEATURES.md found${NC}"
    fi

    # --- 5. Check quality checklist coverage ---
    echo ""
    echo "═══════════════════════════════════════════════════════"
    echo -e "${BOLD}Quality Checklist Status${NC}"
    echo "═══════════════════════════════════════════════════════"
    echo ""

    if [[ -f "$QUALITY_CHECKLIST" ]]; then
        local checklist_items
        checklist_items=$(grep -cE "^\s+- " "$QUALITY_CHECKLIST" 2>/dev/null || echo 0)
        echo -e "Quality checklist: ${checklist_items} items across 5 dimensions"
        echo -e "${DIM}Compare issues against checklist to find gap dimensions${NC}"
    else
        echo -e "${YELLOW}⚠ No quality-checklist.yaml — run \`ag intel bootstrap\` first${NC}"
    fi

    echo ""

    if ! $has_data; then
        echo -e "${YELLOW}No project history data found (ISSUES.md, LESSONS.md, FEATURES.md).${NC}"
        echo -e "Retro works best after the project has accumulated some history."
        echo -e "Run \`ag intel bootstrap\` for initial intelligence from stack analysis."
        return 0
    fi

    # --- 6. Generation instructions ---
    echo "═══════════════════════════════════════════════════════"
    echo -e "${BOLD}Retro Generation Instructions${NC}"
    echo "═══════════════════════════════════════════════════════"
    echo ""
    echo "Based on the analysis above, identify and suggest:"
    echo ""
    echo "1. ${BOLD}New patterns${NC} from recurring issues or lessons not yet captured:"
    echo "   Use: ag intel learn \"text\" --reason \"why\" --scope \"glob\" --severity warning"
    echo ""
    echo "2. ${BOLD}Quality checklist gaps${NC} — dimensions where issues occur but no check exists:"
    echo "   Add items to the appropriate dimension × phase in quality-checklist.yaml"
    echo ""
    echo "3. ${BOLD}Test strategy gaps${NC} — categories of bugs that better testing would catch:"
    echo "   Update test-strategy.yaml with specific patterns/antipatterns"
    echo ""
    echo "4. ${BOLD}NFR suggestions${NC} — if issues reveal missing non-functional requirements:"
    echo "   Use: ag nfr discover"
    echo ""

    if [[ -n "$existing_patterns" ]]; then
        echo -e "${BOLD}Existing patterns (avoid duplicates):${NC}"
        echo "$existing_patterns" | while IFS= read -r p; do
            echo "  • $p"
        done
        echo ""
    fi

    echo -e "${DIM}Tip: Run retro periodically after shipping features to keep intelligence current.${NC}"

    # Log: count data sources analyzed
    local _il_items=0
    [[ -f "$PATTERNS_FILE" ]] && _il_items=$(( _il_items + $(_intel_count "^  - id:" "$PATTERNS_FILE") ))
    [[ -f "${ROOT_DIR}/.agentic/ISSUES.md" ]] && _il_items=$(( _il_items + $(_intel_count -E "^##\s" "${ROOT_DIR}/.agentic/ISSUES.md") ))
    [[ -f "${ROOT_DIR}/.agentic/LESSONS.md" ]] && _il_items=$(( _il_items + $(_intel_count -E "^##\s|^- L-" "${ROOT_DIR}/.agentic/LESSONS.md") ))
    _intel_log "scan" "retro" "$_il_items"
}

# ===========================================================================
# Phase 4: Phase-Aware Queries + Skill Integration
# ===========================================================================

# ---------------------------------------------------------------------------
# _intel_is_discovery — returns 0 if profile is discovery (not formal-like)
# ---------------------------------------------------------------------------
_intel_is_discovery() {
    [[ "$PROFILE" != "formal" && "$PROFILE" != "autonomous_formal" ]]
}

# ---------------------------------------------------------------------------
# _intel_quality_for_phase — extract quality-checklist items for a workflow phase
# Usage: _intel_quality_for_phase <phase>  (planning|spec|implementation|testing)
# Outputs items grouped by dimension. Filters [formal] in Discovery mode.
# ---------------------------------------------------------------------------
_intel_quality_for_phase() {
    local phase="$1"

    if [[ ! -f "$QUALITY_CHECKLIST" ]]; then
        echo -e "  ${DIM}No quality-checklist.yaml — run \`ag intel bootstrap\` to generate${NC}"
        return 0
    fi

    local current_dimension="" prev_dimension="" in_phase=false in_dimensions=false
    local item_count=0

    while IFS= read -r line; do
        # Detect the dimensions: top-level key
        if [[ "$line" =~ ^dimensions:[[:space:]]*$ ]]; then
            in_dimensions=true
            continue
        fi
        # Detect dimension headers (exactly 2-space indent under dimensions:)
        if $in_dimensions && [[ "$line" =~ ^[[:space:]][[:space:]][a-z_]+:[[:space:]]*$ ]] && [[ ! "$line" =~ ^[[:space:]][[:space:]][[:space:]] ]]; then
            local dim="${line%%:*}"
            dim="${dim#"${dim%%[![:space:]]*}"}"  # trim leading spaces
            # Rename spec_adherence → intent_adherence in Discovery
            if _intel_is_discovery && [[ "$dim" == "spec_adherence" ]]; then
                dim="intent_adherence"
            fi
            current_dimension="$dim"
            in_phase=false
        fi
        # Detect phase sub-key (4+ spaces)
        if [[ "$line" =~ ^[[:space:]]{4,8}${phase}:[[:space:]]*$ ]] || [[ "$line" =~ ^[[:space:]]{4,8}${phase}:[[:space:]]*\[ ]]; then
            in_phase=true
            continue
        fi
        # Detect next phase sub-key (exit current phase)
        if $in_phase && [[ "$line" =~ ^[[:space:]]{4,8}[a-z]+: ]]; then
            in_phase=false
        fi
        # Extract items within the active phase
        if $in_phase && [[ "$line" =~ ^[[:space:]]*-[[:space:]] ]]; then
            local item="${line#*- }"
            item="${item//\"/}"
            # Filter [formal] items in Discovery mode
            if _intel_is_discovery && [[ "$item" == *"[formal]"* ]]; then
                continue
            fi
            if [[ $item_count -eq 0 || "$prev_dimension" != "$current_dimension" ]]; then
                echo -e "  ${BOLD}${current_dimension}${NC}"
                prev_dimension="$current_dimension"
            fi
            echo -e "    • ${item}"
            item_count=$((item_count + 1))
        fi
    done < "$QUALITY_CHECKLIST"

    if [[ $item_count -eq 0 ]]; then
        echo -e "  ${DIM}No items found for phase: ${phase}${NC}"
    fi
}

# ---------------------------------------------------------------------------
# _intel_fmt_error_pattern — callback for _intel_each_pattern, prints error-severity patterns
# ---------------------------------------------------------------------------
_intel_fmt_error_pattern() {
    local _id="$1" _text="$2" _reason="$3" _scope="$4" _severity="$5"
    if [[ "$_severity" == "error" ]]; then
        echo -e "  ${RED}⛔${NC} ${_text} ${DIM}[${_scope}]${NC}"
    fi
}

# ---------------------------------------------------------------------------
# _intel_show_spec — show active spec summary for a feature
# ---------------------------------------------------------------------------
_intel_show_spec() {
    local feature_id="$1"
    local contract_file="${ROOT_DIR}/.agentic/spec/contracts/${feature_id}.yaml"

    if [[ -f "$contract_file" ]]; then
        local ac_count
        ac_count=$(grep -c "^  - id:" "$contract_file" 2>/dev/null || echo 0)
        local lifecycle
        lifecycle=$(grep "^lifecycle:" "$contract_file" 2>/dev/null | head -1 | sed 's/lifecycle: *//' || echo "unknown")
        echo -e "  Contract: ${contract_file##*/} (${ac_count} assertions, lifecycle: ${lifecycle})"
    else
        echo -e "  ${DIM}No contract found for ${feature_id}${NC}"
    fi
}

# ---------------------------------------------------------------------------
# architecture — pre-planning intelligence query
# Reads: ADRs, NFRs, CONTEXT_PACK, quality-checklist[planning]
# ---------------------------------------------------------------------------
_intel_architecture() {
    local _il_items=0  # track intelligence items surfaced
    local ADR_DIR="${ROOT_DIR}/.agentic/spec/adr"
    local NFR_FILE="${ROOT_DIR}/.agentic/spec/NFR.md"
    local CONTEXT_FILE="${ROOT_DIR}/CONTEXT_PACK.md"

    echo -e "${BOLD}Intelligence — Architecture (Planning Phase)${NC}"
    _intel_is_discovery && echo -e "${DIM}Profile: discovery${NC}" || echo -e "${DIM}Profile: ${PROFILE}${NC}"
    echo ""

    # --- 1. ADRs ---
    echo "═══════════════════════════════════════════════════════"
    echo -e "${BOLD}Architecture Decision Records${NC}"
    echo "═══════════════════════════════════════════════════════"
    echo ""

    if [[ -d "$ADR_DIR" ]]; then
        local adr_count=0
        for adr_file in "$ADR_DIR"/*.md; do
            [[ ! -f "$adr_file" ]] && continue
            adr_count=$((adr_count + 1))
            local adr_name
            adr_name=$(basename "$adr_file" .md)
            # Extract title from first heading
            local adr_title
            adr_title=$(grep -m1 "^#" "$adr_file" 2>/dev/null | sed 's/^#* *//' || echo "$adr_name")
            echo -e "  📋 ${BOLD}${adr_name}${NC}: ${adr_title}"
            # Extract status and decision summary
            local adr_status
            adr_status=$(grep -i "^status:" "$adr_file" 2>/dev/null | head -1 | sed 's/[Ss]tatus: *//' || true)
            [[ -n "$adr_status" ]] && echo -e "     Status: ${adr_status}"
            # Show first line of Decision section
            local adr_decision
            adr_decision=$(sed -n '/^## Decision/,/^##/{/^## Decision/d;/^##/d;/^$/d;p;}' "$adr_file" 2>/dev/null | head -2 || true)
            [[ -n "$adr_decision" ]] && echo -e "     ${DIM}${adr_decision}${NC}"
            echo ""
        done
        [[ $adr_count -eq 0 ]] && echo -e "  ${DIM}No ADR files found${NC}"
    else
        echo -e "  ${DIM}No ADR directory (.agentic/spec/adr/)${NC}"
    fi

    # --- 2. NFRs ---
    echo "═══════════════════════════════════════════════════════"
    echo -e "${BOLD}Non-Functional Requirements${NC}"
    echo "═══════════════════════════════════════════════════════"
    echo ""

    if [[ -f "$NFR_FILE" ]]; then
        # Show NFR entries (heading + first content line only)
        local nfr_count=0 nfr_showed_content=false
        while IFS= read -r line; do
            if [[ "$line" =~ ^##[[:space:]] ]]; then
                nfr_count=$((nfr_count + 1))
                nfr_showed_content=false
                echo -e "  ${BOLD}${line#\#\# }${NC}"
            elif ! $nfr_showed_content && [[ $nfr_count -gt 0 && -n "$line" && "$line" != "---" && ! "$line" =~ ^# && ! "$line" =~ ^- ]]; then
                echo -e "  ${DIM}${line}${NC}"
                nfr_showed_content=true
                echo ""
            fi
        done < "$NFR_FILE"
        [[ $nfr_count -eq 0 ]] && echo -e "  ${DIM}No NFRs defined${NC}"
    else
        echo -e "  ${DIM}No NFR.md found — run \`ag nfr discover\` to generate${NC}"
    fi

    # --- 3. CONTEXT_PACK ---
    echo "═══════════════════════════════════════════════════════"
    echo -e "${BOLD}Context Pack Summary${NC}"
    echo "═══════════════════════════════════════════════════════"
    echo ""

    if [[ -f "$CONTEXT_FILE" ]]; then
        # Show section headings to give overview
        grep "^##" "$CONTEXT_FILE" 2>/dev/null | while IFS= read -r heading; do
            echo -e "  ${heading}"
        done
        echo ""
        echo -e "  ${DIM}Full context: CONTEXT_PACK.md${NC}"
    else
        echo -e "  ${DIM}No CONTEXT_PACK.md found${NC}"
    fi

    # --- 4. Quality Checklist — Planning Phase ---
    echo ""
    echo "═══════════════════════════════════════════════════════"
    echo -e "${BOLD}Quality Checks — Planning Phase${NC}"
    echo "═══════════════════════════════════════════════════════"
    echo ""

    _intel_quality_for_phase "planning"

    echo ""
    echo -e "${DIM}Use this intelligence to inform architectural decisions during planning.${NC}"

    # Log intelligence sourcing
    _il_items=0
    [[ -d "$ADR_DIR" ]] && { local _c; _c=$(ls "$ADR_DIR"/*.md 2>/dev/null | wc -l); _c="${_c## }"; _il_items=$(( _il_items + _c )); }
    [[ -f "$NFR_FILE" ]] && _il_items=$(( _il_items + $(_intel_count -E "^##\s" "$NFR_FILE") ))
    [[ -f "$CONTEXT_FILE" ]] && _il_items=$(( _il_items + 1 ))
    [[ -f "$QUALITY_CHECKLIST" ]] && _il_items=$(( _il_items + 1 ))
    _intel_log "query" "architecture" "$_il_items"
}

# ---------------------------------------------------------------------------
# spec — pre-spec-writing intelligence query
# Reads: FEATURES.md, contracts, NFRs, quality-checklist[spec]
# ---------------------------------------------------------------------------
_intel_spec() {
    local feature_id="${1:-}"
    local FEATURES_FILE="${ROOT_DIR}/.agentic/spec/FEATURES.md"
    local NFR_FILE="${ROOT_DIR}/.agentic/spec/NFR.md"
    local CONTRACTS_DIR="${ROOT_DIR}/.agentic/spec/contracts"

    # In formal profiles, F-XXXX is expected (warn if missing)
    if [[ -z "$feature_id" ]] && ! _intel_is_discovery; then
        echo -e "${YELLOW}⚠ Feature ID recommended in ${PROFILE} profile: ag intel spec F-XXXX${NC}"
        echo ""
    fi

    echo -e "${BOLD}Intelligence — Spec (Spec-Writing Phase)${NC}"
    _intel_is_discovery && echo -e "${DIM}Profile: discovery${NC}" || echo -e "${DIM}Profile: ${PROFILE}${NC}"
    echo ""

    # --- 1. Active spec for this feature ---
    if [[ -n "$feature_id" ]]; then
        echo "═══════════════════════════════════════════════════════"
        echo -e "${BOLD}Active Spec: ${feature_id}${NC}"
        echo "═══════════════════════════════════════════════════════"
        echo ""
        _intel_show_spec "$feature_id"
        echo ""
    fi

    # --- 2. Related / overlapping features ---
    echo "═══════════════════════════════════════════════════════"
    echo -e "${BOLD}Feature Landscape${NC}"
    echo "═══════════════════════════════════════════════════════"
    echo ""

    if [[ -f "$FEATURES_FILE" ]]; then
        # Extract summary from category table if present
        local summary_line
        summary_line=$(grep -E "^\| \*\*Total\*\*" "$FEATURES_FILE" 2>/dev/null | head -1 || true)
        if [[ -n "$summary_line" ]]; then
            echo -e "  ${summary_line}"
        else
            local total
            total=$(grep -cE "^## F-" "$FEATURES_FILE" 2>/dev/null || echo 0)
            echo -e "  ${total} features defined"
        fi
        echo ""

        # Show current feature if feature_id given
        if [[ -n "$feature_id" ]]; then
            local feature_heading
            feature_heading=$(grep -m1 "^## ${feature_id}:" "$FEATURES_FILE" 2>/dev/null || true)
            if [[ -n "$feature_heading" ]]; then
                echo -e "  ${BOLD}Current:${NC} ${feature_heading#\#\# }"
                echo ""
            fi
        fi

        # Show recently shipped features (check for overlap)
        echo -e "  ${BOLD}Recently shipped (check for overlap):${NC}"
        grep -B2 "shipped" "$FEATURES_FILE" 2>/dev/null | grep "^## F-" | tail -8 | while IFS= read -r line; do
            echo -e "  ${DIM}${line#\#\# }${NC}"
        done
        echo ""
    else
        echo -e "  ${DIM}No FEATURES.md found${NC}"
    fi

    # --- 3. Existing contracts (AC patterns) ---
    echo "═══════════════════════════════════════════════════════"
    echo -e "${BOLD}Contract Patterns${NC}"
    echo "═══════════════════════════════════════════════════════"
    echo ""

    if [[ -d "$CONTRACTS_DIR" ]]; then
        local contract_count=0 total_behavioral=0 total_structural=0
        contract_count=$(ls "$CONTRACTS_DIR"/*.yaml 2>/dev/null | wc -l)
        contract_count="${contract_count## }"
        total_behavioral=$(grep -rl "type: behavioral" "$CONTRACTS_DIR"/*.yaml 2>/dev/null | wc -l)
        total_behavioral="${total_behavioral## }"
        total_structural=$(grep -rl "type: structural" "$CONTRACTS_DIR"/*.yaml 2>/dev/null | wc -l)
        total_structural="${total_structural## }"
        echo -e "  ${contract_count} contracts, ${total_behavioral} with behavioral + ${total_structural} with structural assertions"
        echo -e "  ${DIM}Tip: Review existing contracts for AC style consistency${NC}"
    else
        echo -e "  ${DIM}No contracts directory${NC}"
    fi

    # --- 4. NFRs that constrain spec ---
    echo ""
    echo "═══════════════════════════════════════════════════════"
    echo -e "${BOLD}NFR Constraints${NC}"
    echo "═══════════════════════════════════════════════════════"
    echo ""

    if [[ -f "$NFR_FILE" ]]; then
        local nfr_count
        nfr_count=$(grep -cE "^## " "$NFR_FILE" 2>/dev/null || echo 0)
        echo -e "  ${nfr_count} NFR(s) defined — incorporate into acceptance criteria"
        grep "^## " "$NFR_FILE" 2>/dev/null | while IFS= read -r line; do
            echo -e "  • ${line#\#\# }"
        done
    else
        echo -e "  ${DIM}No NFR.md — consider \`ag nfr discover\`${NC}"
    fi

    # --- 5. Quality Checklist — Spec Phase ---
    echo ""
    echo "═══════════════════════════════════════════════════════"
    echo -e "${BOLD}Quality Checks — Spec Phase${NC}"
    echo "═══════════════════════════════════════════════════════"
    echo ""

    _intel_quality_for_phase "spec"

    echo ""
    echo -e "${DIM}Use this intelligence to write thorough, non-overlapping acceptance criteria.${NC}"

    # Log intelligence sourcing
    local _il_items=0
    [[ -f "${ROOT_DIR}/.agentic/spec/FEATURES.md" ]] && _il_items=$(( _il_items + $(_intel_count -E "^##\s" "${ROOT_DIR}/.agentic/spec/FEATURES.md") ))
    [[ -d "${ROOT_DIR}/.agentic/spec/contracts" ]] && { local _c; _c=$(ls "${ROOT_DIR}/.agentic/spec/contracts/"*.yaml 2>/dev/null | wc -l); _c="${_c## }"; _il_items=$(( _il_items + _c )); }
    [[ -f "${ROOT_DIR}/.agentic/spec/NFR.md" ]] && _il_items=$(( _il_items + 1 ))
    [[ -f "$QUALITY_CHECKLIST" ]] && _il_items=$(( _il_items + 1 ))
    _intel_log "query" "spec${feature_id:+:$feature_id}" "$_il_items"
}

# ---------------------------------------------------------------------------
# implement — pre-implementation intelligence query
# Reads: conventions.md, LESSONS.md, patterns, quality-checklist[implementation], active spec
# ---------------------------------------------------------------------------
_intel_implement() {
    local feature_id="${1:-}"
    local CONVENTIONS_FILE="${ROOT_DIR}/.agentic/conventions.md"
    local LESSONS_FILE="${ROOT_DIR}/.agentic/LESSONS.md"

    # In formal profiles, F-XXXX is expected
    if [[ -z "$feature_id" ]] && ! _intel_is_discovery; then
        echo -e "${YELLOW}⚠ Feature ID recommended in ${PROFILE} profile: ag intel implement F-XXXX${NC}"
        echo ""
    fi

    echo -e "${BOLD}Intelligence — Implementation Phase${NC}"
    _intel_is_discovery && echo -e "${DIM}Profile: discovery${NC}" || echo -e "${DIM}Profile: ${PROFILE}${NC}"
    echo ""

    # --- 1. Active spec ---
    if [[ -n "$feature_id" ]]; then
        echo "═══════════════════════════════════════════════════════"
        echo -e "${BOLD}Active Spec: ${feature_id}${NC}"
        echo "═══════════════════════════════════════════════════════"
        echo ""
        _intel_show_spec "$feature_id"
        echo ""
    fi

    # --- 2. Code Conventions ---
    echo "═══════════════════════════════════════════════════════"
    echo -e "${BOLD}Code Conventions${NC}"
    echo "═══════════════════════════════════════════════════════"
    echo ""

    if [[ -f "$CONVENTIONS_FILE" ]]; then
        # Show convention headings + first line of content
        local in_section=false
        while IFS= read -r line; do
            if [[ "$line" =~ ^## ]]; then
                echo -e "  ${BOLD}${line#\#\# }${NC}"
                in_section=true
            elif $in_section && [[ -n "$line" && ! "$line" =~ ^# ]]; then
                echo -e "  ${DIM}${line}${NC}"
                in_section=false
                echo ""
            fi
        done < "$CONVENTIONS_FILE"
        echo -e "  ${DIM}Full conventions: .agentic/conventions.md${NC}"
    else
        echo -e "  ${DIM}No conventions.md found${NC}"
    fi

    # --- 3. Enforced Patterns ---
    echo ""
    echo "═══════════════════════════════════════════════════════"
    echo -e "${BOLD}Enforced Patterns${NC}"
    echo "═══════════════════════════════════════════════════════"
    echo ""

    if [[ -f "$PATTERNS_FILE" ]]; then
        local pattern_count
        pattern_count=$(_intel_count "^  - id:" "$PATTERNS_FILE")
        echo -e "  ${pattern_count} active patterns (checked at write-time by hook)"
        echo ""
        # Show error-severity patterns as most critical
        local error_lines
        error_lines=$(_intel_each_pattern _intel_fmt_error_pattern)
        if [[ -n "$error_lines" ]]; then
            echo "$error_lines"
        else
            echo -e "  ${DIM}No error-severity patterns${NC}"
        fi
        echo ""
        echo -e "  ${DIM}Run \`ag intel patterns\` for full list${NC}"
    else
        echo -e "  ${DIM}No patterns.yaml — run \`ag intel bootstrap\`${NC}"
    fi

    # --- 4. Lessons Learned ---
    echo ""
    echo "═══════════════════════════════════════════════════════"
    echo -e "${BOLD}Lessons Learned${NC}"
    echo "═══════════════════════════════════════════════════════"
    echo ""

    if [[ -f "$LESSONS_FILE" ]]; then
        local lesson_count
        lesson_count=$(grep -cE "^##\s|^- L-" "$LESSONS_FILE" 2>/dev/null || echo 0)
        echo -e "  ${lesson_count} lesson(s) recorded"
        # Show most recent lessons
        grep -E "^##\s|^- L-" "$LESSONS_FILE" 2>/dev/null | tail -5 | while IFS= read -r line; do
            echo -e "  ${DIM}${line}${NC}"
        done
        echo ""
        echo -e "  ${DIM}Full lessons: .agentic/LESSONS.md${NC}"
    else
        echo -e "  ${DIM}No LESSONS.md — lessons accumulate as issues are resolved${NC}"
    fi

    # --- 5. Cerebrum (project knowledge) ---
    echo ""
    echo "═══════════════════════════════════════════════════════"
    echo -e "${BOLD}Project Knowledge (Cerebrum)${NC}"
    echo "═══════════════════════════════════════════════════════"
    echo ""

    if [[ -f "$PROJECT_MEMORY_FILE" ]]; then
        local memory_count
        memory_count=$(_intel_count "^  - id:" "$PROJECT_MEMORY_FILE")
        echo -e "  ${memory_count} knowledge entries (preferences, learnings, decisions)"
        echo -e "  ${DIM}Run \`ag intel memory\` for full list${NC}"
    else
        echo -e "  ${DIM}No project-memory.yaml yet${NC}"
    fi

    # --- 6. Quality Checklist — Implementation Phase ---
    echo ""
    echo "═══════════════════════════════════════════════════════"
    echo -e "${BOLD}Quality Checks — Implementation Phase${NC}"
    echo "═══════════════════════════════════════════════════════"
    echo ""

    _intel_quality_for_phase "implementation"

    echo ""
    echo -e "${DIM}Use this intelligence to write code that follows project conventions and avoids known pitfalls.${NC}"

    # Log intelligence sourcing
    local _il_items=0
    [[ -f "${ROOT_DIR}/.agentic/conventions.md" ]] && _il_items=$(( _il_items + 1 ))
    [[ -f "$PATTERNS_FILE" ]] && _il_items=$(( _il_items + $(_intel_count "^  - id:" "$PATTERNS_FILE") ))
    [[ -f "${ROOT_DIR}/.agentic/LESSONS.md" ]] && _il_items=$(( _il_items + $(_intel_count -E "^##\s|^- L-" "${ROOT_DIR}/.agentic/LESSONS.md") ))
    [[ -f "$PROJECT_MEMORY_FILE" ]] && _il_items=$(( _il_items + $(_intel_count "^  - id:" "$PROJECT_MEMORY_FILE") ))
    [[ -f "$QUALITY_CHECKLIST" ]] && _il_items=$(( _il_items + 1 ))
    _intel_log "query" "implement${feature_id:+:$feature_id}" "$_il_items"
}

# ---------------------------------------------------------------------------
# test — pre-testing intelligence query
# Reads: STACK.md, ISSUES.md, test-strategy.yaml, quality-checklist[testing]
# ---------------------------------------------------------------------------
_intel_test() {
    local feature_id="${1:-}"
    local STACK_FILE="${ROOT_DIR}/STACK.md"
    local ISSUES_FILE="${ROOT_DIR}/.agentic/ISSUES.md"

    # In formal profiles, F-XXXX is expected
    if [[ -z "$feature_id" ]] && ! _intel_is_discovery; then
        echo -e "${YELLOW}⚠ Feature ID recommended in ${PROFILE} profile: ag intel test F-XXXX${NC}"
        echo ""
    fi

    echo -e "${BOLD}Intelligence — Testing Phase${NC}"
    _intel_is_discovery && echo -e "${DIM}Profile: discovery${NC}" || echo -e "${DIM}Profile: ${PROFILE}${NC}"
    echo ""

    # --- 1. Active spec ---
    if [[ -n "$feature_id" ]]; then
        echo "═══════════════════════════════════════════════════════"
        echo -e "${BOLD}Active Spec: ${feature_id}${NC}"
        echo "═══════════════════════════════════════════════════════"
        echo ""
        _intel_show_spec "$feature_id"
        echo ""
    fi

    # --- 2. Test Strategy ---
    echo "═══════════════════════════════════════════════════════"
    echo -e "${BOLD}Test Strategy${NC}"
    echo "═══════════════════════════════════════════════════════"
    echo ""

    if [[ -f "$TEST_STRATEGY" ]]; then
        # Parse and display test levels
        local current_level="" in_patterns=false in_antipatterns=false
        while IFS= read -r line; do
            # Detect level headers
            if [[ "$line" =~ ^[[:space:]]{2,4}(unit|component|integration|e2e): ]]; then
                local level="${line%%:*}"
                level="${level#"${level%%[![:space:]]*}"}"
                echo -e "  ${BOLD}${level}${NC}"
                current_level="$level"
                in_patterns=false; in_antipatterns=false
            elif [[ "$line" =~ ^[[:space:]]*focus: ]]; then
                local focus="${line#*focus: }"
                focus="${focus//\"/}"
                echo -e "    Focus: ${focus}"
            elif [[ "$line" =~ ^[[:space:]]*framework: ]]; then
                local fw="${line#*framework: }"
                fw="${fw//\"/}"
                echo -e "    Framework: ${fw}"
            elif [[ "$line" =~ ^[[:space:]]*patterns: ]]; then
                in_patterns=true; in_antipatterns=false
                echo -e "    ${GREEN}Patterns:${NC}"
            elif [[ "$line" =~ ^[[:space:]]*antipatterns: ]]; then
                in_antipatterns=true; in_patterns=false
                echo -e "    ${RED}Antipatterns:${NC}"
            elif [[ "$line" =~ ^[[:space:]]*-[[:space:]] ]]; then
                local item="${line#*- }"
                item="${item//\"/}"
                if $in_patterns; then
                    echo -e "      ${GREEN}✓${NC} ${item}"
                elif $in_antipatterns; then
                    echo -e "      ${RED}✗${NC} ${item}"
                fi
            elif [[ "$line" =~ ^[[:space:]]*[a-z]+: && ! "$line" =~ ^[[:space:]]*(focus|framework|colocate|patterns|antipatterns): ]]; then
                in_patterns=false; in_antipatterns=false
            fi
        done < "$TEST_STRATEGY"
        echo ""
    else
        echo -e "  ${DIM}No test-strategy.yaml — run \`ag intel bootstrap\` to generate${NC}"
        echo ""
    fi

    # --- 3. Test Infrastructure (from STACK.md) ---
    echo "═══════════════════════════════════════════════════════"
    echo -e "${BOLD}Test Infrastructure${NC}"
    echo "═══════════════════════════════════════════════════════"
    echo ""

    if [[ -f "$STACK_FILE" ]]; then
        local test_fw
        test_fw=$(grep -iE "^-\s*(Testing|Test framework|test_framework)" "$STACK_FILE" 2>/dev/null | head -1 | sed 's/^[^:]*: *//' || true)
        if [[ -n "$test_fw" ]]; then
            echo -e "  Test framework: ${test_fw}"
        fi
    fi

    # Detect test directories
    local test_dirs=""
    for d in tests test spec __tests__ e2e cypress; do
        [[ -d "${ROOT_DIR}/${d}" ]] && test_dirs="${test_dirs}${d}/, "
    done
    test_dirs="${test_dirs%, }"
    if [[ -n "$test_dirs" ]]; then
        echo -e "  Test directories: ${test_dirs}"
    fi

    # Count existing tests
    local test_count=0
    if git -C "$ROOT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        test_count=$(cd "$ROOT_DIR" && git ls-files --cached --others --exclude-standard 2>/dev/null \
            | grep -cE "(test_|_test\.|\.test\.|\.spec\.|tests/|test/|__tests__/)" || echo 0)
    fi
    echo -e "  Test files: ~${test_count}"
    echo ""

    # --- 4. Known Bugs / Issues ---
    echo "═══════════════════════════════════════════════════════"
    echo -e "${BOLD}Known Issues${NC}"
    echo "═══════════════════════════════════════════════════════"
    echo ""

    if [[ -f "$ISSUES_FILE" ]]; then
        local issue_count
        issue_count=$(grep -cE "^##\s" "$ISSUES_FILE" 2>/dev/null || echo 0)
        echo -e "  ${issue_count} known issue(s) — check for test coverage gaps"
        grep "^## " "$ISSUES_FILE" 2>/dev/null | head -8 | while IFS= read -r line; do
            echo -e "  ${DIM}${line#\#\# }${NC}"
        done
    else
        echo -e "  ${DIM}No ISSUES.md${NC}"
    fi

    # --- 5. Quality Checklist — Testing Phase ---
    echo ""
    echo "═══════════════════════════════════════════════════════"
    echo -e "${BOLD}Quality Checks — Testing Phase${NC}"
    echo "═══════════════════════════════════════════════════════"
    echo ""

    _intel_quality_for_phase "testing"

    echo ""
    echo -e "${DIM}Use this intelligence to write thorough tests covering known gaps and quality dimensions.${NC}"

    # Log intelligence sourcing
    local _il_items=0
    [[ -f "$TEST_STRATEGY" ]] && _il_items=$(( _il_items + 1 ))
    [[ -f "${ROOT_DIR}/.agentic/ISSUES.md" ]] && _il_items=$(( _il_items + $(_intel_count -E "^##\s" "${ROOT_DIR}/.agentic/ISSUES.md") ))
    [[ -f "$QUALITY_CHECKLIST" ]] && _il_items=$(( _il_items + 1 ))
    _intel_log "query" "test${feature_id:+:$feature_id}" "$_il_items"
}
