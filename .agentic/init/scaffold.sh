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
    echo "NEW : ${dst} (from ${src})"
    return 0
  fi

  mkdir -p "$(dirname "${dst}")"
  cat > "${dst}" <<'EOF'
# TODO
EOF
  echo "NEW : ${dst} (placeholder; missing template ${src})"
}

echo "=== agentic scaffold ==="
echo "Profile: ${PROFILE}"
echo ""

# Core directories (available in both profiles)
mkdir -p "${ROOT_DIR}/docs" "${ROOT_DIR}/docs/research" "${ROOT_DIR}/docs/architecture/diagrams"
echo "OK  : ensured directories docs/, docs/research/, docs/architecture/diagrams/"

copy_if_missing "${ROOT_DIR}/.agentic/init/STACK.template.md" "${ROOT_DIR}/STACK.md"
copy_if_missing "${ROOT_DIR}/.agentic/init/CONTEXT_PACK.template.md" "${ROOT_DIR}/CONTEXT_PACK.md"
copy_if_missing "${ROOT_DIR}/.agentic/init/STATUS.template.md" "${ROOT_DIR}/STATUS.md"
copy_if_missing "${ROOT_DIR}/.agentic/init/PRODUCT.template.md" "${ROOT_DIR}/PRODUCT.md"
copy_if_missing "${ROOT_DIR}/.agentic/spec/JOURNAL.template.md" "${ROOT_DIR}/JOURNAL.md"
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
- Update `JOURNAL.md` before ending ANY session (if session ends abruptly, JOURNAL is the only record)
- Keep `PRODUCT.md` up to date with decisions and completed capabilities
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
  echo "Done (Core). Next: tell your agent to initialize using .agentic/init/init_playbook.md"
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
  echo "  Available: claude, cursor, copilot, codex, gemini"
  exit 0
fi

# Profile: core+product
mkdir -p "${ROOT_DIR}/spec" "${ROOT_DIR}/spec/adr" "${ROOT_DIR}/spec/tasks" "${ROOT_DIR}/spec/acceptance"
echo "OK  : ensured directories spec/, spec/adr, spec/tasks, spec/acceptance"

# Note: STATUS.md already created above (shared by both profiles)

# Seed specs (use framework templates if present; otherwise placeholders).
if [[ ! -f "${ROOT_DIR}/spec/PRD.md" ]]; then
  if [[ -f "${ROOT_DIR}/.agentic/spec/PRD.template.md" ]]; then
    cp "${ROOT_DIR}/.agentic/spec/PRD.template.md" "${ROOT_DIR}/spec/PRD.md"
    echo "NEW : spec/PRD.md (from .agentic/spec/PRD.template.md)"
  else
    cat > "${ROOT_DIR}/spec/PRD.md" <<'EOF'
# PRD (Draft)

## Problem

## Goals

## Non-goals

## Users & primary workflow

## Success criteria

EOF
    echo "NEW : spec/PRD.md (placeholder)"
  fi
else
  echo "OK  : spec/PRD.md exists"
fi

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

copy_if_missing "${ROOT_DIR}/.agentic/spec/OVERVIEW.template.md" "${ROOT_DIR}/spec/OVERVIEW.md"
copy_if_missing "${ROOT_DIR}/.agentic/spec/FEATURES.template.md" "${ROOT_DIR}/spec/FEATURES.md"
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
echo "Done (Core+PM). Next: run the agent-guided init in .agentic/init/init_playbook.md"
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
echo "  Available: claude, cursor, copilot, codex, gemini"


