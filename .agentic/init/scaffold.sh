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
  bash .agentic/init/scaffold.sh [--profile discovery|formal] [--non-interactive]

Options:
  --profile discovery|formal  Set the profile (default: discovery)
  --non-interactive           Skip profile prompt, use default or specified profile

Notes:
  - You can also set: AGENTIC_PROFILE=discovery|formal
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
  discovery|formal) ;; # valid
  *)
    echo "ERROR: invalid profile '${PROFILE}' (expected: discovery | formal)"
    exit 2
    ;;
esac

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

# Create remaining state files from config (single source of truth)
# Files handled by the brownfield block above are skipped here to avoid duplicate output
BROWNFIELD_HANDLED="STATUS.md STACK.md CONTEXT_PACK.md OVERVIEW.md"
STATE_FILES_CONF="${ROOT_DIR}/.agentic/init/state-files.conf"
if [[ -f "$STATE_FILES_CONF" ]]; then
  while IFS=: read -r dst_rel src_rel file_profile; do
    [[ "$dst_rel" =~ ^#|^[[:space:]]*$ ]] && continue
    [[ "$file_profile" == "formal" && "$PROFILE" != "formal" ]] && continue
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
  PRESETS_FILE="${ROOT_DIR}/.agentic/presets/profiles.conf"
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

# AGENTS.md is now created by the config loop above (from .agentic/init/AGENTS.template.md)

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
  if [[ -f "${ROOT_DIR}/.agentic/tools/setup-agent.sh" ]]; then
    bash "${ROOT_DIR}/.agentic/tools/setup-agent.sh" all 2>/dev/null || true
  fi
  echo ""
  if [[ "$DISCOVERY_RAN" == "yes" ]]; then
    echo "Done (Discovery + auto-discovery). Proposals in .agentic-state/proposals/"
    echo "Next: tell your agent to initialize using .agentic/init/init_playbook.md"
    echo "      The agent will review discovery results with you before finalizing."
  else
    echo "Done (Discovery). Next: tell your agent to initialize using .agentic/init/init_playbook.md"
  fi
  echo ""
  echo "Optional: For multi-agent development, run:"
  echo "  bash .agentic/tools/setup-agent.sh pipeline       # Pipeline infrastructure"
  echo "  bash .agentic/tools/setup-agent.sh cursor-agents  # Cursor-specific agents"
  echo "To enable Formal profile later: bash .agentic/tools/enable-formal.sh"
  
  # Note about tool setup (don't auto-create - let init_playbook ask)
  echo ""
  echo "Tool-specific setup:"
  echo "  The agent will ask which AI tool(s) you use during initialization."
  echo "  Or run manually: bash .agentic/tools/setup-agent.sh <tool>"
  echo "  Available: claude, cursor, copilot, codex"
  exit 0
fi

# Profile: formal
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

# FEATURES.md: prefer brownfield proposal over template (other formal files already created by config loop)
if [[ "$DISCOVERY_RAN" == "yes" && -f "${ROOT_DIR}/.agentic-state/proposals/FEATURES.md" ]]; then
  copy_or_propose "${ROOT_DIR}/.agentic-state/proposals/FEATURES.md" "${ROOT_DIR}/spec/FEATURES.md"
fi

# Configure git hooks via core.hooksPath (both profiles)
if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
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
if [[ -f "${ROOT_DIR}/.agentic/tools/setup-agent.sh" ]]; then
  bash "${ROOT_DIR}/.agentic/tools/setup-agent.sh" all 2>/dev/null || true
  
  # For Formal: also set up pipeline infrastructure for multi-agent work
  echo ""
  echo "Setting up multi-agent pipeline infrastructure..."
  bash "${ROOT_DIR}/.agentic/tools/setup-agent.sh" pipeline 2>/dev/null || true
fi

echo ""
if [[ "$DISCOVERY_RAN" == "yes" ]]; then
  echo "Done (Formal + auto-discovery). Proposals in .agentic-state/proposals/"
  echo "Next: run the agent-guided init in .agentic/init/init_playbook.md"
  echo "      The agent will review discovery results with you before finalizing."
else
  echo "Done (Formal). Next: run the agent-guided init in .agentic/init/init_playbook.md"
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


