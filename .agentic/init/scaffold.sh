#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(pwd)"

if [[ ! -d "${ROOT_DIR}/.agentic/init" ]]; then
  echo "ERROR: expected '.agentic/init' to exist in repo root."
  echo "Run this script from your repo root (the directory that contains '.agentic/')."
  exit 1
fi

usage() {
  cat <<'EOF'
Usage:
  bash .agentic/init/scaffold.sh [--profile core|core+product] [--non-interactive]

Options:
  --profile core|core+product  Set the profile (default: core)
  --non-interactive            Skip profile prompt, use default or specified profile

Notes:
  - You can also set: AGENTIC_PROFILE=core|core+product
  - In non-interactive mode, agent will set profile during init_playbook
EOF
}

PROFILE="${AGENTIC_PROFILE:-}"
NON_INTERACTIVE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      PROFILE="${2:-}"
      shift 2
      ;;
    --non-interactive)
      NON_INTERACTIVE="yes"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown arg: $1"
      usage
      exit 2
      ;;
  esac
done

if [[ -z "${PROFILE}" ]]; then
  PROFILE="core"
fi

if [[ "${PROFILE}" != "core" && "${PROFILE}" != "core+product" ]]; then
  echo "ERROR: invalid profile '${PROFILE}' (expected: core | core+product)"
  exit 2
fi

copy_if_missing() {
  local src="$1"
  local dst="$2"

  if [[ -f "${dst}" ]]; then
    echo "OK  : ${dst} exists"
    return 0
  fi

  if [[ -f "${src}" ]]; then
    mkdir -p "$(dirname "${dst}")"
    cp "${src}" "${dst}"
    # Remove "(Template)" from title line in generated file
    # Template files keep the marker, but output should not have it
    if head -1 "${dst}" | grep -qi "(Template)"; then
      sed -i.bak '1s/ (Template)//g; 1s/(Template)//g' "${dst}"
      rm -f "${dst}.bak" 2>/dev/null || true
    fi
    echo "NEW : ${dst} (from ${src})"
    return 0
  fi

  mkdir -p "$(dirname "${dst}")"
  cat > "${dst}" <<'EOF'
# TODO
EOF
  echo "NEW : ${dst} (placeholder; missing template ${src})"
}

# Check if file still looks like an unedited template (bare placeholders)
file_looks_like_template() {
  local file="$1"
  [[ ! -f "$file" ]] && return 1
  local first_lines
  first_lines=$(head -3 "$file" | tr '[:upper:]' '[:lower:]')
  if echo "$first_lines" | grep -qi "(template)"; then
    return 0
  fi
  # Check if most content is still placeholder comments
  local total_lines filled_lines
  total_lines=$(wc -l < "$file" | tr -d ' ')
  filled_lines=$(grep -cvE '^\s*$|^\s*<!--.*-->$|^#' "$file" 2>/dev/null || echo "0")
  if [[ "$total_lines" -gt 5 && "$filled_lines" -lt 3 ]]; then
    return 0
  fi
  return 1
}

# Copy proposal-enhanced file if target still looks like a template, else preserve
copy_or_propose() {
  local proposal="$1"  # .agentic-state/proposals/FILE.md
  local dst="$2"

  if [[ ! -f "$proposal" ]]; then
    return 0
  fi

  if [[ ! -f "$dst" ]]; then
    # No existing file - copy proposal directly
    mkdir -p "$(dirname "$dst")"
    cp "$proposal" "$dst"
    echo "NEW : ${dst} (from discovery proposal)"
    return 0
  fi

  if file_looks_like_template "$dst"; then
    # Existing file is still a bare template - overwrite with proposal
    cp "$proposal" "$dst"
    echo "UPD : ${dst} (replaced template with discovery proposal)"
  else
    # User has customized this file - preserve it
    echo "KEEP: ${dst} (user-customized, proposal at ${proposal})"
  fi
}

# Detect if project has existing source code (brownfield project)
detect_existing_codebase() {
  local src_count=0
  local marker_count=0

  # Count source files (exclude framework/build dirs)
  src_count=$(find "$ROOT_DIR" \
    -not -path '*/.agentic/*' \
    -not -path '*/.agentic-*/*' \
    -not -path '*/node_modules/*' \
    -not -path '*/.git/*' \
    -not -path '*/__pycache__/*' \
    -not -path '*/build/*' \
    -not -path '*/dist/*' \
    -not -path '*/.next/*' \
    -not -path '*/target/*' \
    -not -path '*/vendor/*' \
    \( -name '*.py' -o -name '*.ts' -o -name '*.js' -o -name '*.go' \
       -o -name '*.rs' -o -name '*.java' -o -name '*.rb' -o -name '*.gd' \
       -o -name '*.cs' -o -name '*.cpp' -o -name '*.c' -o -name '*.swift' \
       -o -name '*.tsx' -o -name '*.jsx' -o -name '*.kt' -o -name '*.scala' \) \
    -maxdepth 5 2>/dev/null | head -100 | wc -l | tr -d ' ')

  # Check for project markers
  for marker in package.json requirements.txt Cargo.toml go.mod pyproject.toml \
                 Gemfile build.gradle pom.xml composer.json Makefile CMakeLists.txt; do
    [[ -f "$ROOT_DIR/$marker" ]] && marker_count=$((marker_count + 1))
  done

  # Brownfield if: 3+ source files or 1+ project markers
  [[ "$src_count" -ge 3 || "$marker_count" -ge 1 ]]
}

echo "=== agentic scaffold ==="
echo "Profile: ${PROFILE}"
echo ""

# Brownfield detection: run discovery if existing codebase found
DISCOVERY_RAN=""
if detect_existing_codebase; then
  echo "Existing codebase detected - running auto-discovery..."
  if [[ -f "${ROOT_DIR}/.agentic/tools/discover.sh" ]]; then
    if bash "${ROOT_DIR}/.agentic/tools/discover.sh" --profile "${PROFILE}" --root "${ROOT_DIR}" 2>&1; then
      DISCOVERY_RAN="yes"
      echo ""
    else
      echo "WARN: Auto-discovery failed (continuing with standard init)"
      echo ""
    fi
  fi
fi

# Core directories (available in both profiles)
mkdir -p "${ROOT_DIR}/docs" "${ROOT_DIR}/docs/research" "${ROOT_DIR}/docs/architecture/diagrams"
echo "OK  : ensured directories docs/, docs/research/, docs/architecture/diagrams/"

# Use discovery proposals if available, otherwise use templates
if [[ "$DISCOVERY_RAN" == "yes" && -d "${ROOT_DIR}/.agentic-state/proposals" ]]; then
  copy_or_propose "${ROOT_DIR}/.agentic-state/proposals/STACK.md" "${ROOT_DIR}/STACK.md"
  copy_or_propose "${ROOT_DIR}/.agentic-state/proposals/CONTEXT_PACK.md" "${ROOT_DIR}/CONTEXT_PACK.md"
  copy_or_propose "${ROOT_DIR}/.agentic-state/proposals/OVERVIEW.md" "${ROOT_DIR}/OVERVIEW.md"
  # STATUS.md always from template (it's about current session, not discovered)
  copy_if_missing "${ROOT_DIR}/.agentic/init/STATUS.template.md" "${ROOT_DIR}/STATUS.md"
  # Fall back to templates for any files not generated by discovery
  [[ ! -f "${ROOT_DIR}/STACK.md" ]] && copy_if_missing "${ROOT_DIR}/.agentic/init/STACK.template.md" "${ROOT_DIR}/STACK.md"
  [[ ! -f "${ROOT_DIR}/CONTEXT_PACK.md" ]] && copy_if_missing "${ROOT_DIR}/.agentic/init/CONTEXT_PACK.template.md" "${ROOT_DIR}/CONTEXT_PACK.md"
  [[ ! -f "${ROOT_DIR}/OVERVIEW.md" ]] && copy_if_missing "${ROOT_DIR}/.agentic/init/OVERVIEW.template.md" "${ROOT_DIR}/OVERVIEW.md"
else
  copy_if_missing "${ROOT_DIR}/.agentic/init/STACK.template.md" "${ROOT_DIR}/STACK.md"
  copy_if_missing "${ROOT_DIR}/.agentic/init/CONTEXT_PACK.template.md" "${ROOT_DIR}/CONTEXT_PACK.md"
  copy_if_missing "${ROOT_DIR}/.agentic/init/STATUS.template.md" "${ROOT_DIR}/STATUS.md"
  copy_if_missing "${ROOT_DIR}/.agentic/init/OVERVIEW.template.md" "${ROOT_DIR}/OVERVIEW.md"
fi

# JOURNAL.md moved to .agentic-journal/ directory (v0.23.0+)
mkdir -p "${ROOT_DIR}/.agentic-journal"
copy_if_missing "${ROOT_DIR}/.agentic/spec/JOURNAL.template.md" "${ROOT_DIR}/.agentic-journal/JOURNAL.md"

copy_if_missing "${ROOT_DIR}/.agentic/spec/HUMAN_NEEDED.template.md" "${ROOT_DIR}/HUMAN_NEEDED.md"

# Ensure STACK.md has Profile field (newer versions)
if [[ -f "${ROOT_DIR}/STACK.md" ]]; then
  if grep -qE '^[[:space:]]*-[[:space:]]*Profile:' "${ROOT_DIR}/STACK.md"; then
    # Normalize to the selected profile
    sed -i.bak -E "s/^([[:space:]]*-[[:space:]]*Profile:[[:space:]]*).*/\\1${PROFILE}  # core | core+product/" "${ROOT_DIR}/STACK.md"
    rm -f "${ROOT_DIR}/STACK.md.bak" 2>/dev/null || true
    echo "OK  : STACK.md Profile set to ${PROFILE}"
  else
    # Insert right after the Version line inside "## Agentic framework"
    perl -0777 -i -pe "s/(## Agentic framework\\n- Version:[^\\n]*\\n)/\\1- Profile: ${PROFILE}  \\# core | core+product\\n/" "${ROOT_DIR}/STACK.md" || true
    echo "NEW : STACK.md Profile: ${PROFILE}"
  fi

  # Set profile-aware git_workflow default
  # Core profile → direct (fast iteration, user can override during init)
  # Core+PM profile → pull_request (formal tracking = formal review)
  if [[ "${PROFILE}" == "core" ]]; then
    GIT_WORKFLOW_DEFAULT="direct"
  else
    GIT_WORKFLOW_DEFAULT="pull_request"
  fi

  if grep -qE '^[[:space:]]*-[[:space:]]*git_workflow:' "${ROOT_DIR}/STACK.md"; then
    # Update existing git_workflow line to profile default
    sed -i.bak -E "s/^([[:space:]]*-[[:space:]]*git_workflow:[[:space:]]*).*/\\1${GIT_WORKFLOW_DEFAULT}/" "${ROOT_DIR}/STACK.md"
    rm -f "${ROOT_DIR}/STACK.md.bak" 2>/dev/null || true
    echo "OK  : STACK.md git_workflow set to ${GIT_WORKFLOW_DEFAULT} (${PROFILE} default)"
  fi
fi

# Shared agent rules at repo root (recommended).
# Keep agentic framework content in .agentic/, but place a small entrypoint at repo root for tools that only read root files.
if [[ ! -f "${ROOT_DIR}/AGENTS.md" ]]; then
  cat > "${ROOT_DIR}/AGENTS.md" <<'EOF'
# AGENTS.md

> **Note**: This file is a REFERENCE document. It is NOT auto-loaded by AI tools.
> The auto-loaded files (CLAUDE.md, .cursorrules, etc.) point to this file.

This repo uses the **Agentic Framework** located at `.agentic/`.

## Non-negotiables

**Document blockers immediately:**
- When you identify something requiring human action (install dependency, make decision, access credentials), ADD IT TO `HUMAN_NEEDED.md` IMMEDIATELY
- Don't just mention it in chat - document it so it's not forgotten

**Keep documentation current:**
- Update `.agentic-journal/JOURNAL.md` before ending ANY session (if session ends abruptly, JOURNAL is the only record)
- Keep `OVERVIEW.md` up to date with vision and completed capabilities
- Keep `CONTEXT_PACK.md` current when architecture changes
- If this repo uses the Core+Product profile: keep `STATUS.md` and `/spec/*` truthful

**Code quality:**
- Add/update tests for new or changed logic
- Run smoke tests before claiming features work
- Separate business logic from UI for testability

## Full Guidelines

See `.agentic/agents/shared/agent_operating_guidelines.md`

## Tool-Specific Files

These are auto-loaded by your AI tool:
- **Claude Code**: `CLAUDE.md`
- **Cursor**: `.cursorrules`
- **GitHub Copilot**: `.github/copilot-instructions.md`

To regenerate: `bash .agentic/tools/setup-agent.sh all`
EOF
  echo "NEW : ${ROOT_DIR}/AGENTS.md (entrypoint)"
else
  echo "OK  : ${ROOT_DIR}/AGENTS.md exists"
fi

if [[ "${PROFILE}" == "core" ]]; then
  echo ""
  # Set up tool-specific auto-loaded files
  echo "Setting up AI tool integration..."
  if [[ -f "${ROOT_DIR}/.agentic/tools/setup-agent.sh" ]]; then
    bash "${ROOT_DIR}/.agentic/tools/setup-agent.sh" all 2>/dev/null || true
  fi
  echo ""
  if [[ "$DISCOVERY_RAN" == "yes" ]]; then
    echo "Done (Core + auto-discovery). Proposals in .agentic-state/proposals/"
    echo "Next: tell your agent to initialize using .agentic/init/init_playbook.md"
    echo "      The agent will review discovery results with you before finalizing."
  else
    echo "Done (Core). Next: tell your agent to initialize using .agentic/init/init_playbook.md"
  fi
  echo ""
  echo "Optional: For multi-agent development, run:"
  echo "  bash .agentic/tools/setup-agent.sh pipeline       # Pipeline infrastructure"
  echo "  bash .agentic/tools/setup-agent.sh cursor-agents  # Cursor-specific agents"
  echo "To enable Product Management later: bash .agentic/tools/enable-product-management.sh"
  
  # Note about tool setup (don't auto-create - let init_playbook ask)
  echo ""
  echo "Tool-specific setup:"
  echo "  The agent will ask which AI tool(s) you use during initialization."
  echo "  Or run manually: bash .agentic/tools/setup-agent.sh <tool>"
  echo "  Available: claude, cursor, copilot, codex"
  exit 0
fi

# Profile: core+product
mkdir -p "${ROOT_DIR}/spec" "${ROOT_DIR}/spec/adr" "${ROOT_DIR}/spec/tasks" "${ROOT_DIR}/spec/acceptance"
echo "OK  : ensured directories spec/, spec/adr, spec/tasks, spec/acceptance"

# Note: STATUS.md already created above (shared by both profiles)

# Note: PRD.md is deprecated in favor of OVERVIEW.md at root level
# OVERVIEW.md is created above for both profiles

if [[ ! -f "${ROOT_DIR}/spec/TECH_SPEC.md" ]]; then
  if [[ -f "${ROOT_DIR}/.agentic/spec/TECH_SPEC.template.md" ]]; then
    cp "${ROOT_DIR}/.agentic/spec/TECH_SPEC.template.md" "${ROOT_DIR}/spec/TECH_SPEC.md"
    echo "NEW : spec/TECH_SPEC.md (from .agentic/spec/TECH_SPEC.template.md)"
  else
    cat > "${ROOT_DIR}/spec/TECH_SPEC.md" <<'EOF'
# TECH_SPEC (Draft)

## Architecture overview

## Components

## Data flow

## Testing strategy

## Risks

EOF
    echo "NEW : spec/TECH_SPEC.md (placeholder)"
  fi
else
  echo "OK  : spec/TECH_SPEC.md exists"
fi

if [[ "$DISCOVERY_RAN" == "yes" && -f "${ROOT_DIR}/.agentic-state/proposals/FEATURES.md" ]]; then
  copy_or_propose "${ROOT_DIR}/.agentic-state/proposals/FEATURES.md" "${ROOT_DIR}/spec/FEATURES.md"
else
  copy_if_missing "${ROOT_DIR}/.agentic/spec/FEATURES.template.md" "${ROOT_DIR}/spec/FEATURES.md"
fi
copy_if_missing "${ROOT_DIR}/.agentic/spec/ISSUES.template.md" "${ROOT_DIR}/spec/ISSUES.md"
copy_if_missing "${ROOT_DIR}/.agentic/spec/LESSONS.template.md" "${ROOT_DIR}/spec/LESSONS.md"
copy_if_missing "${ROOT_DIR}/.agentic/spec/NFR.template.md" "${ROOT_DIR}/spec/NFR.md"
copy_if_missing "${ROOT_DIR}/.agentic/spec/REFERENCES.template.md" "${ROOT_DIR}/spec/REFERENCES.md"
copy_if_missing "${ROOT_DIR}/.agentic/spec/acceptance/README.template.md" "${ROOT_DIR}/spec/acceptance/README.md"

# Install pre-commit hook for spec validation (Core+PM only)
if [[ -f "${ROOT_DIR}/.git/hooks/pre-commit" ]]; then
  echo "OK  : .git/hooks/pre-commit exists (not overwriting)"
else
  if [[ -f "${ROOT_DIR}/.agentic/hooks/pre-commit" ]]; then
    mkdir -p "${ROOT_DIR}/.git/hooks"
    cp "${ROOT_DIR}/.agentic/hooks/pre-commit" "${ROOT_DIR}/.git/hooks/pre-commit"
    chmod +x "${ROOT_DIR}/.git/hooks/pre-commit"
    echo "NEW : .git/hooks/pre-commit (spec validation before commits)"
  else
    echo "WARN: .agentic/hooks/pre-commit template not found"
  fi
fi

# Set up tool-specific auto-loaded files
echo ""
echo "Setting up AI tool integration..."
if [[ -f "${ROOT_DIR}/.agentic/tools/setup-agent.sh" ]]; then
  bash "${ROOT_DIR}/.agentic/tools/setup-agent.sh" all 2>/dev/null || true
  
  # For Core+PM: also set up pipeline infrastructure for multi-agent work
  echo ""
  echo "Setting up multi-agent pipeline infrastructure..."
  bash "${ROOT_DIR}/.agentic/tools/setup-agent.sh" pipeline 2>/dev/null || true
fi

echo ""
if [[ "$DISCOVERY_RAN" == "yes" ]]; then
  echo "Done (Core+PM + auto-discovery). Proposals in .agentic-state/proposals/"
  echo "Next: run the agent-guided init in .agentic/init/init_playbook.md"
  echo "      The agent will review discovery results with you before finalizing."
else
  echo "Done (Core+PM). Next: run the agent-guided init in .agentic/init/init_playbook.md"
fi
echo ""
echo "Multi-agent setup:"
echo "  - Pipeline infrastructure: ✓ Created (AGENTS_ACTIVE.md, .agentic/pipeline/)"
echo "  - Agent roles: Available in .agentic/agents/roles/"
echo "  - To copy roles to Cursor: bash .agentic/tools/setup-agent.sh cursor-agents"

# Note about tool setup (don't auto-create - let init_playbook ask)
echo ""
echo "Tool-specific setup:"
echo "  The agent will ask which AI tool(s) you use during initialization."
echo "  Or run manually: bash .agentic/tools/setup-agent.sh <tool>"
echo "  Available: claude, cursor, copilot, codex"


