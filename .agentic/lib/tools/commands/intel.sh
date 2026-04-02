#!/usr/bin/env bash
# commands/intel.sh — Intelligence engine commands (patterns, anatomy, quality)
# Sourced by ag.sh — do NOT execute directly.
# Depends on: SCRIPT_DIR, ROOT_DIR, PROFILE, color codes, paths.sh, settings.sh

INTEL_DIR="${ROOT_DIR}/.agentic/intel"
PATTERNS_FILE="${INTEL_DIR}/patterns.yaml"

cmd_intel() {
    local subcmd="${1:-help}"
    shift 2>/dev/null || true

    case "$subcmd" in
        check)    _intel_check "$@" ;;
        learn)    _intel_learn "$@" ;;
        patterns) _intel_patterns "$@" ;;
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
    echo "  ${BOLD}Phase 1: Patterns${NC}"
    echo "  check PATH               Show patterns matching a file path"
    echo "  learn \"text\" --reason \"why\" --scope \"glob\"  Add an enforced pattern"
    echo "  patterns [--scope PATH]   List all patterns (optionally filtered by scope)"
    echo ""
    echo "Patterns file: ${PATTERNS_FILE}"
}

# ---------------------------------------------------------------------------
# check — find patterns matching a file path
# ---------------------------------------------------------------------------
_intel_check() {
    local target_path="${1:-}"

    if [[ -z "$target_path" ]]; then
        echo -e "${RED}Error: PATH required${NC}"
        echo "Usage: ag intel check PATH"
        return 1
    fi

    if [[ ! -f "$PATTERNS_FILE" ]]; then
        return 0  # No patterns file = no matches
    fi

    local match_count=0
    local current_id="" current_text="" current_reason="" current_scope="" current_severity=""

    while IFS= read -r line; do
        # Parse YAML entries (simple line-by-line parser for flat structure)
        case "$line" in
            *"- id: "*)
                # If we have a pending entry, check it
                if [[ -n "$current_id" ]]; then
                    _intel_check_match "$target_path" "$current_id" "$current_text" "$current_reason" "$current_scope" "$current_severity" && match_count=$((match_count + 1))
                fi
                current_id="${line#*"- id: "}"
                current_id="${current_id//\"/}"
                current_id="${current_id## }"
                current_text="" current_reason="" current_scope="" current_severity=""
                ;;
            *"text: "*)
                current_text="${line#*"text: "}"
                current_text="${current_text//\"/}"
                ;;
            *"reason: "*)
                current_reason="${line#*"reason: "}"
                current_reason="${current_reason//\"/}"
                ;;
            *"scope: "*)
                current_scope="${line#*"scope: "}"
                current_scope="${current_scope//\"/}"
                ;;
            *"severity: "*)
                current_severity="${line#*"severity: "}"
                current_severity="${current_severity//\"/}"
                ;;
        esac
    done < "$PATTERNS_FILE"

    # Check last entry
    if [[ -n "$current_id" ]]; then
        _intel_check_match "$target_path" "$current_id" "$current_text" "$current_reason" "$current_scope" "$current_severity" && match_count=$((match_count + 1))
    fi

    if [[ $match_count -eq 0 ]]; then
        return 0  # No matches, clean exit
    fi
}

# Check if a pattern's scope matches a target path using bash glob
_intel_check_match() {
    local target="$1" id="$2" text="$3" reason="$4" scope="$5" severity="$6"

    # Default severity
    severity="${severity:-warning}"

    if _intel_glob_match "$target" "$scope"; then
        local color="$YELLOW"
        local icon="⚠️"
        case "$severity" in
            error) color="$RED"; icon="🚨" ;;
            info)  color="$BLUE"; icon="ℹ️" ;;
        esac
        echo -e "${color}${icon} ${id}: ${text}${NC}"
        if [[ -n "$reason" ]]; then
            echo -e "  ${DIM}Reason: ${reason}${NC}"
        fi
        return 0
    fi
    return 1
}

# Glob match: check if path matches a scope pattern
# Supports: *.sh, .agentic/lib/claude-hooks/*.sh, *.py, etc.
_intel_glob_match() {
    local path="$1" pattern="$2"

    [[ -z "$pattern" ]] && return 1

    # Get just the filename for simple globs like *.sh
    local filename="${path##*/}"

    # Try matching the full path first
    # shellcheck disable=SC2254
    case "$path" in
        $pattern) return 0 ;;
    esac

    # Try matching just the filename against the pattern
    # shellcheck disable=SC2254
    case "$filename" in
        $pattern) return 0 ;;
    esac

    # For directory-qualified patterns like .agentic/lib/claude-hooks/*.sh
    # try matching against relative path variants
    local rel_path="$path"
    # Strip leading ./ if present
    rel_path="${rel_path#./}"
    # Strip leading / if absolute
    rel_path="${rel_path#/}"

    # shellcheck disable=SC2254
    case "$rel_path" in
        $pattern) return 0 ;;
    esac

    # Try with leading ./
    # shellcheck disable=SC2254
    case "./$rel_path" in
        $pattern) return 0 ;;
    esac

    return 1
}

# ---------------------------------------------------------------------------
# learn — add a new pattern
# ---------------------------------------------------------------------------
_intel_learn() {
    local text="" reason="" scope="" severity="warning"

    # Parse args: first positional = text, then --flags
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
            # Strip leading zeros for arithmetic
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

    # Append new pattern
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
    local current_id="" current_text="" current_reason="" current_scope="" current_severity="" current_source=""

    echo -e "${BOLD}Patterns${NC} (${PATTERNS_FILE})"
    echo ""

    while IFS= read -r line; do
        case "$line" in
            *"- id: "*)
                if [[ -n "$current_id" ]]; then
                    _intel_print_pattern "$scope_filter" "$current_id" "$current_text" "$current_reason" "$current_scope" "$current_severity" "$current_source" && count=$((count + 1))
                fi
                current_id="${line#*"- id: "}"
                current_id="${current_id//\"/}"
                current_id="${current_id## }"
                current_text="" current_reason="" current_scope="" current_severity="" current_source=""
                ;;
            *"text: "*)
                current_text="${line#*"text: "}"
                current_text="${current_text//\"/}"
                ;;
            *"reason: "*)
                current_reason="${line#*"reason: "}"
                current_reason="${current_reason//\"/}"
                ;;
            *"scope: "*)
                current_scope="${line#*"scope: "}"
                current_scope="${current_scope//\"/}"
                ;;
            *"severity: "*)
                current_severity="${line#*"severity: "}"
                current_severity="${current_severity//\"/}"
                ;;
            *"source: "*)
                current_source="${line#*"source: "}"
                current_source="${current_source//\"/}"
                ;;
        esac
    done < "$PATTERNS_FILE"

    # Print last entry
    if [[ -n "$current_id" ]]; then
        _intel_print_pattern "$scope_filter" "$current_id" "$current_text" "$current_reason" "$current_scope" "$current_severity" "$current_source" && count=$((count + 1))
    fi

    echo ""
    echo -e "${DIM}${count} pattern(s) shown${NC}"
}

_intel_print_pattern() {
    local scope_filter="$1" id="$2" text="$3" reason="$4" scope="$5" severity="$6" source="$7"

    # If scope filter given, check match
    if [[ -n "$scope_filter" ]]; then
        if ! _intel_glob_match "$scope_filter" "$scope"; then
            return 1
        fi
    fi

    local sev_color="$YELLOW"
    case "$severity" in
        error) sev_color="$RED" ;;
        info)  sev_color="$BLUE" ;;
    esac

    echo -e "  ${sev_color}${id}${NC} [${severity:-warning}] ${text}"
    echo -e "    ${DIM}Scope: ${scope}  Source: ${source:-unknown}${NC}"

    return 0
}
