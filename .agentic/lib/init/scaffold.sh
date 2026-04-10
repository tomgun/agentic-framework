#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(pwd)"

if [[ ! -d "${ROOT_DIR}/.agentic/lib/init" ]]; then
  echo "ERROR: expected '.agentic/lib/init' to exist in repo root."
  echo "Run this script from your repo root (the directory that contains '.agentic/')."
  exit 1
fi

# Git initialization is now deferred by default (F-017).
# For profiles that default to git_mode: active (autonomous_formal), git is initialized here.
# Other profiles defer git until the user runs `ag git-init`.
# The profile-specific git_mode is resolved after the profile variable is set (see below).

usage() {
  cat <<'EOF'
Usage:
  bash .agentic/lib/init/scaffold.sh [--profile discovery|formal|autonomous_formal] [--non-interactive]

Options:
  --profile discovery|formal|autonomous_formal  Set the profile (default: discovery)
  --non-interactive           Skip profile prompt, use default or specified profile

Notes:
  - You can also set: AGENTIC_PROFILE=discovery|formal|autonomous_formal
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
  PROFILE="discovery"
fi

case "${PROFILE}" in
  discovery|formal|autonomous_formal) ;; # valid
  *)
    echo "ERROR: invalid profile '${PROFILE}' (expected: discovery | formal | autonomous_formal)"
    exit 2
    ;;
esac

# Resolve git_mode from profile defaults (F-017)
# autonomous_formal defaults to active (git initialized immediately)
# discovery and formal default to deferred (git activated later via `ag git-init`)
GIT_MODE="deferred"
if [[ "${PROFILE}" == "autonomous_formal" ]]; then
  GIT_MODE="active"
fi

# Initialize git if git_mode is active
if [[ "${GIT_MODE}" == "active" ]]; then
  if command -v git >/dev/null 2>&1; then
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
      git init
      echo "NEW : git repository initialized (profile: ${PROFILE})"
    fi
  else
    echo "WARN: git not installed — git_mode set to deferred"
    GIT_MODE="deferred"
  fi
else
  echo "OK  : git deferred (activate later with: ag git-init)"
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
  local proposal="$1"  # .agentic/session/proposals/FILE.md
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
  if [[ -f "${ROOT_DIR}/.agentic/lib/tools/discover.sh" ]]; then
    if bash "${ROOT_DIR}/.agentic/lib/tools/discover.sh" --profile "${PROFILE}" --root "${ROOT_DIR}" 2>&1; then
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

# User-extension directory (survives framework upgrades)
if [[ ! -d "${ROOT_DIR}/.agentic/local/extensions" ]]; then
  mkdir -p "${ROOT_DIR}/.agentic/local/extensions/skills"
  mkdir -p "${ROOT_DIR}/.agentic/local/extensions/gates"
  mkdir -p "${ROOT_DIR}/.agentic/local/extensions/hooks"
  mkdir -p "${ROOT_DIR}/.agentic/local/extensions/rules"
  mkdir -p "${ROOT_DIR}/.agentic/local/extensions/done-checks"
  mkdir -p "${ROOT_DIR}/.agentic/local/extensions/policies"
  if [[ -f "${ROOT_DIR}/.agentic/lib/init/extensions-readme.md" ]]; then
    cp "${ROOT_DIR}/.agentic/lib/init/extensions-readme.md" "${ROOT_DIR}/.agentic/local/extensions/README.md"
  fi
  # Copy customization templates if they don't exist yet
  if [[ ! -f "${ROOT_DIR}/.agentic/local/conventions.md" && -f "${ROOT_DIR}/.agentic/lib/init/conventions-local.template.md" ]]; then
    cp "${ROOT_DIR}/.agentic/lib/init/conventions-local.template.md" "${ROOT_DIR}/.agentic/local/conventions.md"
  fi
  if [[ ! -f "${ROOT_DIR}/.agentic/local/workflow-directions.md" && -f "${ROOT_DIR}/.agentic/lib/init/workflow-directions.template.md" ]]; then
    cp "${ROOT_DIR}/.agentic/lib/init/workflow-directions.template.md" "${ROOT_DIR}/.agentic/local/workflow-directions.md"
  fi
  echo "NEW : .agentic/local/extensions/ (project-specific customizations)"
else
  # Ensure new extension subdirectories exist for existing projects
  mkdir -p "${ROOT_DIR}/.agentic/local/extensions/done-checks"
  mkdir -p "${ROOT_DIR}/.agentic/local/extensions/policies"
  echo "OK  : .agentic/local/extensions/ exists"
fi
# Copy customization templates for existing projects too (idempotent)
if [[ ! -f "${ROOT_DIR}/.agentic/local/conventions.md" && -f "${ROOT_DIR}/.agentic/lib/init/conventions-local.template.md" ]]; then
  cp "${ROOT_DIR}/.agentic/lib/init/conventions-local.template.md" "${ROOT_DIR}/.agentic/local/conventions.md"
fi
if [[ ! -f "${ROOT_DIR}/.agentic/local/workflow-directions.md" && -f "${ROOT_DIR}/.agentic/lib/init/workflow-directions.template.md" ]]; then
  cp "${ROOT_DIR}/.agentic/lib/init/workflow-directions.template.md" "${ROOT_DIR}/.agentic/local/workflow-directions.md"
fi

# Use discovery proposals if available, otherwise use templates
if [[ "$DISCOVERY_RAN" == "yes" && -d "${ROOT_DIR}/.agentic/session/proposals" ]]; then
  copy_or_propose "${ROOT_DIR}/.agentic/session/proposals/STACK.md" "${ROOT_DIR}/STACK.md"
  copy_or_propose "${ROOT_DIR}/.agentic/session/proposals/CONTEXT_PACK.md" "${ROOT_DIR}/CONTEXT_PACK.md"
  copy_or_propose "${ROOT_DIR}/.agentic/session/proposals/OVERVIEW.md" "${ROOT_DIR}/.agentic/OVERVIEW.md"
  # STATUS.md always from template (it's about current session, not discovered)
  copy_if_missing "${ROOT_DIR}/.agentic/lib/init/STATUS.template.md" "${ROOT_DIR}/.agentic/STATUS.md"
  # Fall back to templates for any files not generated by discovery
  [[ ! -f "${ROOT_DIR}/STACK.md" ]] && copy_if_missing "${ROOT_DIR}/.agentic/lib/init/STACK.template.md" "${ROOT_DIR}/STACK.md"
  [[ ! -f "${ROOT_DIR}/CONTEXT_PACK.md" ]] && copy_if_missing "${ROOT_DIR}/.agentic/lib/init/CONTEXT_PACK.template.md" "${ROOT_DIR}/CONTEXT_PACK.md"
  [[ ! -f "${ROOT_DIR}/.agentic/OVERVIEW.md" ]] && copy_if_missing "${ROOT_DIR}/.agentic/lib/init/OVERVIEW.template.md" "${ROOT_DIR}/.agentic/OVERVIEW.md"
else
  copy_if_missing "${ROOT_DIR}/.agentic/lib/init/STACK.template.md" "${ROOT_DIR}/STACK.md"
  copy_if_missing "${ROOT_DIR}/.agentic/lib/init/CONTEXT_PACK.template.md" "${ROOT_DIR}/CONTEXT_PACK.md"
  copy_if_missing "${ROOT_DIR}/.agentic/lib/init/STATUS.template.md" "${ROOT_DIR}/.agentic/STATUS.md"
  copy_if_missing "${ROOT_DIR}/.agentic/lib/init/OVERVIEW.template.md" "${ROOT_DIR}/.agentic/OVERVIEW.md"
fi

# Create remaining state files from config (single source of truth)
# Files handled by the brownfield block above are skipped here to avoid duplicate output
BROWNFIELD_HANDLED=".agentic/STATUS.md STACK.md CONTEXT_PACK.md .agentic/OVERVIEW.md"
STATE_FILES_CONF="${ROOT_DIR}/.agentic/lib/init/state-files.conf"
if [[ -f "$STATE_FILES_CONF" ]]; then
  while IFS=: read -r dst_rel src_rel file_profile; do
    [[ "$dst_rel" =~ ^#|^[[:space:]]*$ ]] && continue
    # Source settings.sh for is_formal_like if not already loaded
    if ! type is_formal_like &>/dev/null && [[ -f "$ROOT_DIR/.agentic/lib/settings.sh" ]]; then
      source "$ROOT_DIR/.agentic/lib/settings.sh"
    fi
    [[ "$file_profile" == "formal" ]] && ! is_formal_like "$PROFILE" && continue
    [[ " $BROWNFIELD_HANDLED " == *" $dst_rel "* ]] && continue
    copy_if_missing "${ROOT_DIR}/${src_rel}" "${ROOT_DIR}/${dst_rel}"
  done < "$STATE_FILES_CONF"
fi

# Configure STACK.md settings for selected profile
if [[ -f "${ROOT_DIR}/STACK.md" ]]; then
  # Set profile in ## Settings section
  if grep -qE '^- profile:' "${ROOT_DIR}/STACK.md"; then
    sed -i.bak -E "s/^(- profile:[[:space:]]*).*/\\1${PROFILE}/" "${ROOT_DIR}/STACK.md"
    rm -f "${ROOT_DIR}/STACK.md.bak" 2>/dev/null || true
    echo "OK  : STACK.md profile set to ${PROFILE}"
  fi

  # Legacy: also update Profile field in ## Agentic framework if present
  if grep -qE '^[[:space:]]*-[[:space:]]*Profile:' "${ROOT_DIR}/STACK.md"; then
    sed -i.bak -E "s/^([[:space:]]*-[[:space:]]*Profile:[[:space:]]*).*/\\1${PROFILE}  # discovery | formal/" "${ROOT_DIR}/STACK.md"
    rm -f "${ROOT_DIR}/STACK.md.bak" 2>/dev/null || true
  fi

  # Replace all settings values from profile preset
  PRESETS_FILE="${ROOT_DIR}/.agentic/lib/presets/profiles.conf"
  if [[ -f "$PRESETS_FILE" ]]; then
    while IFS='=' read -r preset_key preset_value; do
      [[ "$preset_key" =~ ^#|^$ ]] && continue
      [[ -z "$preset_key" ]] && continue
      if [[ "$preset_key" =~ ^${PROFILE}\.(.*) ]]; then
        setting_name="${BASH_REMATCH[1]}"
        sed -i.bak -E "s/^(- ${setting_name}:[[:space:]]*).*/\\1${preset_value}/" "${ROOT_DIR}/STACK.md"
        rm -f "${ROOT_DIR}/STACK.md.bak" 2>/dev/null || true
      fi
    done < "$PRESETS_FILE"
    echo "OK  : STACK.md settings populated for ${PROFILE} profile"
  fi
fi

# Generate stack-specific quality profile if discovery detected a stack (F-302)
if [[ "$DISCOVERY_RAN" == "yes" && -f "${ROOT_DIR}/STACK.md" ]]; then
  QUALITY_GEN="${ROOT_DIR}/.agentic/lib/tools/generate-quality-profile.sh"
  if [[ -f "$QUALITY_GEN" ]]; then
    echo ""
    echo "Setting up stack-specific quality checks..."
    bash "$QUALITY_GEN" --root "$ROOT_DIR" 2>&1 || echo "WARN: Quality profile generation failed (continuing)"
    echo ""
  fi
fi

# AGENTS.md is now created by the config loop above (from .agentic/lib/init/AGENTS.template.md)

if [[ "${PROFILE}" == "discovery" ]]; then
  # Configure git hooks for Discovery profile too
  if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
    CURRENT_HOOKS_PATH=$(git config core.hooksPath 2>/dev/null || echo "")
    if [[ "$CURRENT_HOOKS_PATH" != ".agentic/hooks" ]]; then
      GIT_VERSION=$(git --version | grep -oE '[0-9]+\.[0-9]+' | head -1)
      GIT_MAJOR=$(echo "$GIT_VERSION" | cut -d. -f1)
      GIT_MINOR=$(echo "$GIT_VERSION" | cut -d. -f2)
      if [[ "$GIT_MAJOR" -gt 2 ]] || [[ "$GIT_MAJOR" -eq 2 && "$GIT_MINOR" -ge 9 ]]; then
        git config core.hooksPath .agentic/hooks
        echo "NEW : git core.hooksPath set to .agentic/hooks"
      fi
    else
      echo "OK  : git hooks already configured"
    fi
  fi

  echo ""
  # Set up tool-specific auto-loaded files
  echo "Setting up AI tool integration..."
  if [[ -f "${ROOT_DIR}/.agentic/lib/tools/setup-agent.sh" ]]; then
    bash "${ROOT_DIR}/.agentic/lib/tools/setup-agent.sh" all 2>/dev/null || true
  fi
  # Generate project-specific agents from detected stack (Layer A)
  if [[ "$DISCOVERY_RAN" == "yes" ]] && [[ -f "${ROOT_DIR}/.agentic/lib/tools/generate-project-agents.sh" ]]; then
    echo "Generating project-specific agents..."
    bash "${ROOT_DIR}/.agentic/lib/tools/generate-project-agents.sh" 2>/dev/null || true
  fi
  echo ""
  if [[ "$DISCOVERY_RAN" == "yes" ]]; then
    echo "Done (Discovery + auto-discovery). Proposals in .agentic/session/proposals/"
    echo "Next: tell your agent to initialize using .agentic/lib/init/init_playbook.md"
    echo "      The agent will review discovery results with you before finalizing."
  else
    echo "Done (Discovery). Next: tell your agent to initialize using .agentic/lib/init/init_playbook.md"
  fi
  echo ""
  echo "Optional: For multi-agent development, run:"
  echo "  bash .agentic/lib/tools/setup-agent.sh pipeline       # Pipeline infrastructure"
  echo "  bash .agentic/lib/tools/setup-agent.sh cursor-agents  # Cursor-specific agents"
  echo "To enable Formal profile later: bash .agentic/lib/tools/enable-formal.sh"
  
  echo ""
  echo "Tool-specific setup:"
  echo "  ✓ All AI tool configs pre-installed (claude, cursor, copilot, codex)."
  echo "  The agent will verify which tools you use and offer to prune unused configs."
  echo "  To add tools later: bash .agentic/lib/tools/setup-agent.sh <tool>"
  exit 0
fi

# Profile: formal
mkdir -p "${ROOT_DIR}/.agentic/spec" "${ROOT_DIR}/.agentic/spec/adr" "${ROOT_DIR}/.agentic/spec/tasks" "${ROOT_DIR}/.agentic/spec/contracts" "${ROOT_DIR}/.agentic/spec/acceptance"
echo "OK  : ensured directories .agentic/spec/, .agentic/spec/adr, .agentic/spec/tasks, .agentic/spec/contracts, .agentic/spec/acceptance"

# Copy contract template if not present (YAML contracts are the primary spec format)
if [[ ! -f "${ROOT_DIR}/.agentic/spec/contracts/.template.yaml" ]]; then
  if [[ -f "${ROOT_DIR}/.agentic/lib/templates/contract.template.yaml" ]]; then
    cp "${ROOT_DIR}/.agentic/lib/templates/contract.template.yaml" "${ROOT_DIR}/.agentic/spec/contracts/.template.yaml"
    echo "NEW : .agentic/spec/contracts/.template.yaml (contract format reference)"
  fi
fi

# Note: STATUS.md already created above (shared by both profiles)

# Note: PRD.md is deprecated in favor of OVERVIEW.md
# OVERVIEW.md is created above for both profiles

if [[ ! -f "${ROOT_DIR}/.agentic/spec/TECH_SPEC.md" ]]; then
  if [[ -f "${ROOT_DIR}/.agentic/lib/templates/TECH_SPEC.template.md" ]]; then
    cp "${ROOT_DIR}/.agentic/lib/templates/TECH_SPEC.template.md" "${ROOT_DIR}/.agentic/spec/TECH_SPEC.md"
    echo "NEW : .agentic/spec/TECH_SPEC.md (from .agentic/lib/templates/TECH_SPEC.template.md)"
  else
    cat > "${ROOT_DIR}/.agentic/spec/TECH_SPEC.md" <<'EOF'
# TECH_SPEC (Draft)

## Architecture overview

## Components

## Data flow

## Testing strategy

## Risks

EOF
    echo "NEW : .agentic/spec/TECH_SPEC.md (placeholder)"
  fi
else
  echo "OK  : .agentic/spec/TECH_SPEC.md exists"
fi

# FEATURES.md: prefer brownfield proposal over template (other formal files already created by config loop)
if [[ "$DISCOVERY_RAN" == "yes" && -f "${ROOT_DIR}/.agentic/session/proposals/FEATURES.md" ]]; then
  copy_or_propose "${ROOT_DIR}/.agentic/session/proposals/FEATURES.md" "${ROOT_DIR}/.agentic/.agentic/spec/FEATURES.md"
fi

# Configure git hooks via core.hooksPath (only when git_mode is active — F-017)
if [[ "${GIT_MODE}" == "active" ]] && command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
  CURRENT_HOOKS_PATH=$(git config core.hooksPath 2>/dev/null || echo "")
  if [[ "$CURRENT_HOOKS_PATH" == ".agentic/hooks" ]]; then
    echo "OK  : git hooks already configured (core.hooksPath = .agentic/hooks)"
  else
    # Check git version supports core.hooksPath (git >= 2.9)
    GIT_VERSION=$(git --version | grep -oE '[0-9]+\.[0-9]+' | head -1)
    GIT_MAJOR=$(echo "$GIT_VERSION" | cut -d. -f1)
    GIT_MINOR=$(echo "$GIT_VERSION" | cut -d. -f2)
    if [[ "$GIT_MAJOR" -gt 2 ]] || [[ "$GIT_MAJOR" -eq 2 && "$GIT_MINOR" -ge 9 ]]; then
      git config core.hooksPath .agentic/hooks
      echo "NEW : git core.hooksPath set to .agentic/hooks"
    else
      # Fallback: file copy for git < 2.9
      if [[ -f "${ROOT_DIR}/.agentic/hooks/pre-commit" ]]; then
        mkdir -p "${ROOT_DIR}/.git/hooks"
        cp "${ROOT_DIR}/.agentic/hooks/pre-commit" "${ROOT_DIR}/.git/hooks/pre-commit"
        chmod +x "${ROOT_DIR}/.git/hooks/pre-commit"
        echo "NEW : .git/hooks/pre-commit (fallback for git < 2.9)"
      fi
    fi
  fi
fi

# Set up tool-specific auto-loaded files
echo ""
echo "Setting up AI tool integration..."
if [[ -f "${ROOT_DIR}/.agentic/lib/tools/setup-agent.sh" ]]; then
  bash "${ROOT_DIR}/.agentic/lib/tools/setup-agent.sh" all 2>/dev/null || true
  
  # For Formal: also set up pipeline infrastructure for multi-agent work
  echo ""
  echo "Setting up multi-agent pipeline infrastructure..."
  bash "${ROOT_DIR}/.agentic/lib/tools/setup-agent.sh" pipeline 2>/dev/null || true
fi

# Generate project-specific agents from detected stack (Layer A)
if [[ "$DISCOVERY_RAN" == "yes" ]] && [[ -f "${ROOT_DIR}/.agentic/lib/tools/generate-project-agents.sh" ]]; then
  echo ""
  echo "Generating project-specific agents..."
  bash "${ROOT_DIR}/.agentic/lib/tools/generate-project-agents.sh" 2>/dev/null || true
fi

echo ""
if [[ "$DISCOVERY_RAN" == "yes" ]]; then
  echo "Done (Formal + auto-discovery). Proposals in .agentic/session/proposals/"
  echo "Next: run the agent-guided init in .agentic/lib/init/init_playbook.md"
  echo "      The agent will review discovery results with you before finalizing."
else
  echo "Done (Formal). Next: run the agent-guided init in .agentic/lib/init/init_playbook.md"
fi
echo ""
echo "Multi-agent setup:"
echo "  - Pipeline infrastructure: ✓ Created (AGENTS.json, .agentic/pipeline/)"
echo "  - Agent roles: Available in .agentic/lib/agents/roles/"
echo "  - To copy roles to Cursor: bash .agentic/lib/tools/setup-agent.sh cursor-agents"

echo ""
echo "Tool-specific setup:"
echo "  ✓ All AI tool configs pre-installed (claude, cursor, copilot, codex)."
echo "  The agent will verify which tools you use and offer to prune unused configs."
echo "  To add tools later: bash .agentic/lib/tools/setup-agent.sh <tool>"


