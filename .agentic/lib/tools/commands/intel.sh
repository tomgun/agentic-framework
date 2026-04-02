#!/usr/bin/env bash
# commands/intel.sh — Intelligence engine commands (patterns, anatomy, quality)
# Sourced by ag.sh — do NOT execute directly.
# Depends on: SCRIPT_DIR, ROOT_DIR, PROFILE, color codes, paths.sh, settings.sh

INTEL_DIR="${ROOT_DIR}/.agentic/intel"
PATTERNS_FILE="${INTEL_DIR}/patterns.yaml"
CEREBRUM_FILE="${INTEL_DIR}/cerebrum.yaml"
ANATOMY_FILE="${INTEL_DIR}/anatomy.yaml"
ANATOMY_INDEX="${INTEL_DIR}/anatomy.index"
TOKEN_SUMMARY="${INTEL_DIR}/token-summary.json"
SESSION_DIR="${ROOT_DIR}/.agentic/session"
TOKEN_EVENTS="${SESSION_DIR}/token-events.log"
TOKEN_LEDGER="${SESSION_DIR}/token-ledger.json"

_INTEL_VALID_SEVERITIES="error warning info"
_INTEL_VALID_CEREBRUM_TYPES="preference learning decision"

cmd_intel() {
    local subcmd="${1:-help}"
    shift 2>/dev/null || true

    case "$subcmd" in
        check)     _intel_check "$@" ;;
        learn)     _intel_learn "$@" ;;
        remove)    _intel_remove "$@" ;;
        patterns)  _intel_patterns "$@" ;;
        remember)  _intel_remember "$@" ;;
        cerebrum)  _intel_cerebrum "$@" ;;
        forget)    _intel_forget "$@" ;;
        scan)      _intel_scan "$@" ;;
        file)      _intel_file "$@" ;;
        stats)     _intel_stats "$@" ;;
        bootstrap) _intel_bootstrap "$@" ;;
        retro)     _intel_retro "$@" ;;
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
    echo "  ${BOLD}Anatomy${NC} (file intelligence)"
    echo "  scan [--check]            Scan project files → anatomy.yaml + index"
    echo "  file PATH                 Lookup file: summary, tokens, language"
    echo ""
    echo "  ${BOLD}Knowledge Generation${NC}"
    echo "  bootstrap                 Generate domain intelligence from stack + codebase"
    echo "  retro                     Analyze issues/lessons → suggest new patterns"
    echo ""
    echo "  ${BOLD}Metrics${NC}"
    echo "  stats [--session]         Show token metrics (session + lifetime)"
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

    echo -e "${BOLD}Intelligence Engine — Token Metrics${NC}"
    echo ""

    _intel_show_session_stats

    if ! $session_only; then
        echo ""
        _intel_show_lifetime_stats
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
        stack_framework=$(_stack_get "(App framework|app_framework|Framework)")
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
        detected_pkg="${detected_pkg:-pip}"
        [[ -f "${ROOT_DIR}/Pipfile" ]] && detected_pkg="pipenv"
        [[ -f "${ROOT_DIR}/poetry.lock" ]] && detected_pkg="poetry"

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
    local has_quality=false has_strategy=false has_patterns=false
    [[ -f "$QUALITY_CHECKLIST" ]] && has_quality=true
    [[ -f "$TEST_STRATEGY" ]] && has_strategy=true
    [[ -f "$PATTERNS_FILE" ]] && has_patterns=true

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
        pattern_count=$(grep -c "^  - id:" "$PATTERNS_FILE" 2>/dev/null || echo 0)
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
}
