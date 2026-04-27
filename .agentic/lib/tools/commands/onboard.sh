#!/usr/bin/env bash
# commands/onboard.sh — `ag onboard` new-contributor playbook (R-011).
# Sourced by ag.sh. Depends on: ROOT_DIR, color codes.

cmd_onboard() {
    # Disable pipefail / -e locally so grep|head pipelines that legitimately
    # return 1 (no match) don't crash the command. Restored on return.
    local _saved_opts="$-"
    set +eo pipefail

    local force=0
    local out_path="$ROOT_DIR/.agentic/ONBOARDING.md"
    local template="$ROOT_DIR/.agentic/lib/init/templates/ONBOARDING.template.md"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f|--force) force=1; shift ;;
            -o|--output) out_path="$2"; shift 2 ;;
            -h|--help)
                cat <<EOF
${BOLD}ag onboard${NC} — Generate a new-contributor playbook (R-011)

  Reads STACK.md, FEATURES.md, recent journal entries, and ADRs to produce
  ${DIM}.agentic/ONBOARDING.md${NC} — a 5-minute path from fresh clone to first commit.

  Usage:
    ag onboard            # generate (refuses if file exists)
    ag onboard --force    # overwrite an existing ONBOARDING.md
    ag onboard -o PATH    # write to a different path

  Different from ${DIM}ag init${NC} (greenfield project setup) — onboard targets people
  joining an already-running project.
EOF
                return 0
                ;;
            *)
                echo -e "${RED}Unknown ag onboard flag: $1${NC}"
                return 1
                ;;
        esac
    done

    if [[ ! -f "$template" ]]; then
        echo -e "${RED}Template missing:${NC} $template"
        echo "  Reinstall the framework or restore the templates directory."
        return 1
    fi

    if [[ -f "$out_path" && "$force" -ne 1 ]]; then
        echo -e "${YELLOW}$out_path already exists.${NC}"
        echo "  Use ${BOLD}ag onboard --force${NC} to regenerate."
        return 1
    fi

    # ----- Project name from git remote or fallback to dir name -------------
    local project_name
    project_name=$(basename "$(cd "$ROOT_DIR" && pwd)")
    if command -v git >/dev/null 2>&1 && git -C "$ROOT_DIR" rev-parse --git-dir >/dev/null 2>&1; then
        local remote_url
        remote_url=$(git -C "$ROOT_DIR" config --get remote.origin.url 2>/dev/null || echo "")
        if [[ -n "$remote_url" ]]; then
            local from_remote
            from_remote=$(basename "$remote_url" .git)
            if [[ -n "$from_remote" ]]; then
                project_name="$from_remote"
            fi
        fi
    fi

    local generated_at
    generated_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # ----- Project overview: first non-empty paragraph of STACK.md ----------
    local overview="(no STACK.md found — run \`ag init\` to bootstrap)"
    if [[ -f "$ROOT_DIR/STACK.md" ]]; then
        overview=$(awk '
            /^[A-Za-z#]/ && !/^#/ { print; found=1 }
            found && /^$/ { exit }
            /^## Purpose/ { capture=1; next }
            capture && /^[A-Z]/ { print; capture=0 }
        ' "$ROOT_DIR/STACK.md" | head -10 | sed '/^$/d')
        if [[ -z "$overview" ]]; then
            overview=$(grep -E '^(Purpose:|Profile:|Version:)' "$ROOT_DIR/STACK.md" | head -5)
        fi
        [[ -z "$overview" ]] && overview="(see STACK.md — auto-extract found nothing)"
    fi

    # ----- Tech stack: lines under "## Stack" / "## Tech" / "## Settings" ---
    local tech_stack="(see STACK.md)"
    if [[ -f "$ROOT_DIR/STACK.md" ]]; then
        tech_stack=$(awk '
            /^## (Stack|Tech|Languages|Frameworks|Settings)/ { capture=1; next }
            /^## / && capture { exit }
            capture && NF { print }
        ' "$ROOT_DIR/STACK.md" | head -25)
        [[ -z "$tech_stack" ]] && tech_stack="(no Stack/Tech/Settings section in STACK.md)"
    fi

    # ----- Current focus: latest STATUS.md "Current focus" + last journal ---
    local current_focus="(no STATUS.md or recent journal entries)"
    local status_md="$ROOT_DIR/.agentic/STATUS.md"
    [[ ! -f "$status_md" ]] && status_md="$ROOT_DIR/STATUS.md"
    if [[ -f "$status_md" ]]; then
        current_focus=$(awk '
            /^## Current/ { capture=1; next }
            /^## / && capture { exit }
            capture && NF { print }
        ' "$status_md" | head -15)
    fi
    if [[ -z "$current_focus" ]]; then
        current_focus="(STATUS.md present but no Current section parsed)"
    fi
    # Append last 3 journal entries (titles only)
    local journal="$ROOT_DIR/.agentic/journal/JOURNAL.md"
    [[ ! -f "$journal" ]] && journal="$ROOT_DIR/.agentic/JOURNAL.md"
    if [[ -f "$journal" ]]; then
        local recent
        recent=$(grep -E '^## ' "$journal" 2>/dev/null | tail -5 | sed 's/^## /  • /')
        if [[ -n "$recent" ]]; then
            current_focus+=$'\n\n**Recent journal entries:**\n'"$recent"
        fi
    fi

    # ----- First tasks: planned features in FEATURES.md, or backlog --------
    local first_tasks="(no FEATURES.md or BACKLOG — try \`ag backlog list\`)"
    if [[ -f "$ROOT_DIR/.agentic/spec/FEATURES.md" ]]; then
        local planned
        planned=$(grep -E '^\| F-[0-9]+ .* \| (planned|in_progress)' \
            "$ROOT_DIR/.agentic/spec/FEATURES.md" 2>/dev/null | head -5 \
            | sed -E 's/^\| (F-[0-9]+) \| ([^|]+) \|.*/  • \1 — \2/')
        if [[ -n "$planned" ]]; then
            first_tasks="Planned / in-progress features in FEATURES.md:"$'\n\n'"$planned"$'\n\nUse `ag backlog list` for the prioritized queue.'
        fi
    fi

    # ----- ADR index: filenames + first non-empty title line ---------------
    local adr_index="(no .agentic/spec/adr/ — formal profile not adopted)"
    if [[ -d "$ROOT_DIR/.agentic/spec/adr" ]]; then
        local adrs
        adrs=$(find "$ROOT_DIR/.agentic/spec/adr" -maxdepth 1 -name "ADR-*.md" -type f 2>/dev/null | sort)
        if [[ -n "$adrs" ]]; then
            adr_index=""
            while IFS= read -r adr; do
                local fname
                fname=$(basename "$adr")
                local title
                title=$(grep -E '^# ' "$adr" | head -1 | sed -E 's/^# *//')
                [[ -z "$title" ]] && title="(no title)"
                adr_index+="  • [$fname](.agentic/spec/adr/$fname) — $title"$'\n'
            done <<< "$adrs"
        fi
    fi

    # ----- Substitute via python (handles multi-line values safely) ---------
    # Restore strict shell options BEFORE the python heredoc so a substitution
    # error fails loud instead of silently claiming success below.
    case "$_saved_opts" in *e*) set -e ;; esac
    case "$_saved_opts" in *o*) set -o pipefail ;; esac

    PYTHONIOENCODING=utf-8 \
    PROJECT_NAME="$project_name" \
    GENERATED_AT="$generated_at" \
    PROJECT_OVERVIEW="$overview" \
    TECH_STACK="$tech_stack" \
    CURRENT_FOCUS="$current_focus" \
    FIRST_TASKS="$first_tasks" \
    ADR_INDEX="$adr_index" \
    python3 - "$template" "$out_path" <<'PYEOF'
import os
import sys

template_path, out_path = sys.argv[1], sys.argv[2]
with open(template_path, "r", encoding="utf-8") as fh:
    body = fh.read()
substitutions = {
    "{{PROJECT_NAME}}": os.environ.get("PROJECT_NAME", "this project"),
    "{{GENERATED_AT}}": os.environ.get("GENERATED_AT", ""),
    "{{PROJECT_OVERVIEW}}": os.environ.get("PROJECT_OVERVIEW", ""),
    "{{TECH_STACK}}": os.environ.get("TECH_STACK", ""),
    "{{CURRENT_FOCUS}}": os.environ.get("CURRENT_FOCUS", ""),
    "{{FIRST_TASKS}}": os.environ.get("FIRST_TASKS", ""),
    "{{ADR_INDEX}}": os.environ.get("ADR_INDEX", ""),
}
for marker, value in substitutions.items():
    body = body.replace(marker, value.rstrip("\n"))
with open(out_path, "w", encoding="utf-8") as fh:
    fh.write(body)
PYEOF

    # Verify the file was actually written. Catches the case where the python
    # heredoc raises before write (template missing a marker, permission fail).
    if [[ ! -s "$out_path" ]]; then
        echo -e "${RED}✗${NC} Substitution failed — $out_path is empty or missing." >&2
        return 1
    fi

    echo -e "${GREEN}✓${NC} Wrote $out_path"
    echo ""
    echo "Next: skim it, edit the ${BOLD}People / channels${NC} section, and commit."
    echo "  ${DIM}ag onboard --force${NC} to regenerate later."
    # Strict mode was already restored before the python heredoc above.
}
