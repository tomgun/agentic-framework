#!/usr/bin/env bash
# commands/intel.sh — Intelligence engine commands (patterns, anatomy, quality)
# Sourced by ag.sh — do NOT execute directly.
# Depends on: SCRIPT_DIR, ROOT_DIR, PROFILE, color codes, paths.sh, settings.sh

INTEL_DIR="${ROOT_DIR}/.agentic/intel"
PATTERNS_FILE="${INTEL_DIR}/patterns.yaml"
CEREBRUM_FILE="${INTEL_DIR}/cerebrum.yaml"

_INTEL_VALID_SEVERITIES="error warning info"
_INTEL_VALID_CEREBRUM_TYPES="preference learning decision"

cmd_intel() {
    local subcmd="${1:-help}"
    shift 2>/dev/null || true

    case "$subcmd" in
        check)    _intel_check "$@" ;;
        learn)    _intel_learn "$@" ;;
        remove)   _intel_remove "$@" ;;
        patterns) _intel_patterns "$@" ;;
        remember) _intel_remember "$@" ;;
        cerebrum) _intel_cerebrum "$@" ;;
        forget)   _intel_forget "$@" ;;
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
    echo "  ${BOLD}Cerebrum${NC} (project knowledge from corrections & discoveries)"
    echo "  remember \"text\" [--type preference|learning|decision] [--context \"...\"]"
    echo "  cerebrum [--type TYPE]    List cerebrum entries"
    echo "  forget C-XXXX             Remove a cerebrum entry"
    echo ""
    echo "Files: ${PATTERNS_FILE} | ${CEREBRUM_FILE}"
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
    local text="" entry_type="preference" context=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --type)    shift; entry_type="${1:-}" ;;
            --context) shift; context="${1:-}" ;;
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
        echo "Usage: ag intel remember \"text\" [--type preference|learning|decision] [--context \"...\"]"
        return 1
    fi

    if [[ ! " $_INTEL_VALID_CEREBRUM_TYPES " =~ " $entry_type " ]]; then
        echo -e "${RED}Error: invalid type '$entry_type'. Must be one of: $_INTEL_VALID_CEREBRUM_TYPES${NC}"
        return 1
    fi

    mkdir -p "$INTEL_DIR"
    if [[ ! -f "$CEREBRUM_FILE" ]]; then
        cat > "$CEREBRUM_FILE" <<'INIT'
version: 1
description: >
  Project-scoped intelligence from user corrections and discoveries.
entries:
INIT
    fi

    # Find next cerebrum ID
    local max_id=0
    while IFS= read -r line; do
        if [[ "$line" =~ "- id: C-"([0-9]+) ]]; then
            local num="${BASH_REMATCH[1]}"
            num=$((10#$num))
            (( num > max_id )) && max_id=$num
        fi
    done < "$CEREBRUM_FILE"
    local next_id
    next_id=$(printf "C-%04d" $((max_id + 1)))

    local today
    today=$(date +%Y-%m-%d)

    # Escape quotes for YAML
    text="${text//\"/\\\"}"
    context="${context//\"/\\\"}"

    # Replace empty entries array if this is the first entry
    if grep -q "^entries: \[\]" "$CEREBRUM_FILE" 2>/dev/null; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' 's/^entries: \[\]/entries:/' "$CEREBRUM_FILE"
        else
            sed -i 's/^entries: \[\]/entries:/' "$CEREBRUM_FILE"
        fi
    fi

    # Append entry
    {
        echo ""
        echo "  - id: ${next_id}"
        echo "    type: ${entry_type}"
        echo "    text: \"${text}\""
        [[ -n "$context" ]] && echo "    context: \"${context}\""
        echo "    date: ${today}"
    } >> "$CEREBRUM_FILE"

    local type_icon="💡"
    case "$entry_type" in
        preference) type_icon="🎯" ;;
        learning)   type_icon="📚" ;;
        decision)   type_icon="⚖️" ;;
    esac

    echo -e "${GREEN}✓ Remembered ${next_id} [${entry_type}]: ${text}${NC}"
    echo -e "  ${type_icon} Stored in cerebrum.yaml"
}

# ---------------------------------------------------------------------------
# cerebrum — list cerebrum entries
# ---------------------------------------------------------------------------
_intel_cerebrum() {
    local type_filter=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --type) shift; type_filter="${1:-}" ;;
            *) type_filter="$1" ;;
        esac
        shift
    done

    if [[ ! -f "$CEREBRUM_FILE" ]]; then
        echo -e "${YELLOW}No cerebrum file found at ${CEREBRUM_FILE}${NC}"
        echo "Run: ag intel remember \"text\" to create one"
        return 0
    fi

    echo -e "${BOLD}Cerebrum${NC} (${CEREBRUM_FILE})"
    echo ""

    local count=0
    local _id="" _type="" _text="" _context="" _date=""

    _cerebrum_print() {
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
                _cerebrum_print
                _id="${line#*"- id: "}"; _id="${_id//\"/}"; _id="${_id## }"
                _type="" _text="" _context="" _date=""
                ;;
            *"type: "*)    _type="${line#*"type: "}"; _type="${_type//\"/}" ;;
            *"context: "*) _context="${line#*"context: "}"; _context="${_context//\"/}" ;;
            *"date: "*)    _date="${line#*"date: "}"; _date="${_date//\"/}" ;;
            *"text: "*)    _text="${line#*"text: "}"; _text="${_text//\"/}" ;;
        esac
    done < "$CEREBRUM_FILE"
    _cerebrum_print  # last entry

    echo ""
    echo -e "${DIM}${count} entry/entries shown${NC}"
}

# ---------------------------------------------------------------------------
# forget — remove a cerebrum entry by ID
# ---------------------------------------------------------------------------
_intel_forget() {
    local entry_id="${1:-}"

    if [[ -z "$entry_id" ]]; then
        echo -e "${RED}Error: cerebrum entry ID required${NC}"
        echo "Usage: ag intel forget C-XXXX"
        return 1
    fi

    if [[ ! -f "$CEREBRUM_FILE" ]]; then
        echo -e "${RED}Error: no cerebrum file found${NC}"
        return 1
    fi

    if ! grep -q "id: ${entry_id}" "$CEREBRUM_FILE" 2>/dev/null; then
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
    done < "$CEREBRUM_FILE"

    if $removed; then
        mv "$tmp_file" "$CEREBRUM_FILE"
        echo -e "${GREEN}✓ Forgot ${entry_id}${NC}"
    else
        rm -f "$tmp_file"
        echo -e "${RED}Error: entry ${entry_id} not found${NC}"
        return 1
    fi
}
