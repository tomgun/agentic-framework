#!/usr/bin/env bash
# paths.sh — Central path resolver for the Agentic Framework
#
# Source this from any tool script:
#   source "$(dirname "${BASH_SOURCE[0]}")/paths.sh"         # from lib/ root
#   source "$(dirname "${BASH_SOURCE[0]}")/../lib/paths.sh"   # from tools/ (inside lib/)
#   source "$(dirname "${BASH_SOURCE[0]}")/../lib/paths.sh"   # from tools/ (current layout)
#
# Provides all path variables needed by framework scripts.
# During the directory restructure, this file is the SINGLE place to update
# when files move — all scripts that source it automatically get new paths.
#
# Supports backward compatibility: when a file doesn't exist at the new
# location but exists at the old location, the old path is returned.

# Guard against double-sourcing
[[ -n "${_AGENTIC_PATHS_LOADED:-}" ]] && return 0
_AGENTIC_PATHS_LOADED=1

# ---------------------------------------------------------------------------
# Core directory resolution
# ---------------------------------------------------------------------------

# AGENTIC_LIB: where this file lives (.agentic/lib/)
AGENTIC_LIB="${AGENTIC_LIB:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

# AGENTIC_ROOT: the .agentic/ directory
AGENTIC_ROOT="${AGENTIC_ROOT:-$(cd "$AGENTIC_LIB/.." && pwd)}"

# PROJECT_ROOT: the project root directory
# Allows override via ROOT_DIR (used by ag.sh and others) or CLAUDE_PROJECT_DIR (hooks)
if [[ -n "${ROOT_DIR:-}" ]]; then
    PROJECT_ROOT="$ROOT_DIR"
elif [[ -n "${CLAUDE_PROJECT_DIR:-}" ]]; then
    PROJECT_ROOT="$CLAUDE_PROJECT_DIR"
else
    PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$AGENTIC_ROOT/.." && pwd)}"
fi

# MAIN_PROJECT_ROOT: always the main repo (not a worktree)
# In a worktree, git-common-dir differs from git-dir; the main repo is the parent of git-common-dir.
MAIN_PROJECT_ROOT="$PROJECT_ROOT"
if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
    _git_common=$(git rev-parse --git-common-dir 2>/dev/null)
    _git_dir=$(git rev-parse --git-dir 2>/dev/null)
    if [[ -n "$_git_common" && -n "$_git_dir" && "$_git_common" != "$_git_dir" ]]; then
        MAIN_PROJECT_ROOT=$(cd "$(dirname "$_git_common")" && pwd)
    fi
fi
AGENTS_JSON="$MAIN_PROJECT_ROOT/.agentic/session/AGENTS.json"

# ---------------------------------------------------------------------------
# Backward-compatibility helper
# Returns $1 if it exists, else $2 if it exists, else $1 (new location)
# ---------------------------------------------------------------------------
_resolve_path() {
    local new_path="$1"
    local legacy_path="${2:-}"
    if [[ -z "$legacy_path" ]]; then
        echo "$new_path"
    elif [[ -e "$new_path" ]]; then
        echo "$new_path"
    elif [[ -e "$legacy_path" ]]; then
        echo "$legacy_path"
    else
        echo "$new_path"
    fi
}

# ---------------------------------------------------------------------------
# Project config (stays at project root — tool conventions)
# ---------------------------------------------------------------------------
CLAUDE_MD_FILE="$PROJECT_ROOT/CLAUDE.md"
STACK_FILE="$PROJECT_ROOT/STACK.md"
CONTEXT_PACK_FILE="$PROJECT_ROOT/CONTEXT_PACK.md"
AGENTS_FILE="$PROJECT_ROOT/AGENTS.md"

# ---------------------------------------------------------------------------
# Tracking files (flat at .agentic/ root)
# ---------------------------------------------------------------------------
STATUS_FILE="$(_resolve_path "$AGENTIC_ROOT/STATUS.md" "$PROJECT_ROOT/STATUS.md")"
TODO_FILE="$(_resolve_path "$AGENTIC_ROOT/TODO.md" "$PROJECT_ROOT/TODO.md")"
HUMAN_NEEDED_FILE="$(_resolve_path "$AGENTIC_ROOT/HUMAN_NEEDED.md" "$PROJECT_ROOT/HUMAN_NEEDED.md")"
CONTRIBUTIONS_FILE="$(_resolve_path "$AGENTIC_ROOT/CONTRIBUTIONS.md" "$PROJECT_ROOT/CONTRIBUTIONS.md")"
OVERVIEW_FILE="$(_resolve_path "$AGENTIC_ROOT/OVERVIEW.md" "$PROJECT_ROOT/OVERVIEW.md")"
BACKLOG_FILE="$AGENTIC_ROOT/BACKLOG.json"

# ---------------------------------------------------------------------------
# Journal (.agentic/journal/)
# ---------------------------------------------------------------------------
JOURNAL_DIR="$(_resolve_path "$AGENTIC_ROOT/journal" "$PROJECT_ROOT/.agentic-journal")"
JOURNAL_FILE="$(_resolve_path "$AGENTIC_ROOT/journal/JOURNAL.md" "$PROJECT_ROOT/.agentic-journal/JOURNAL.md")"
PLANS_DIR="$(_resolve_path "$AGENTIC_ROOT/journal/plans" "$PROJECT_ROOT/.agentic-journal/plans")"
LESSONS_DIR="$(_resolve_path "$AGENTIC_ROOT/journal/lessons" "$PROJECT_ROOT/.agentic-journal/lessons")"
MANIFESTS_DIR="$(_resolve_path "$AGENTIC_ROOT/journal/manifests" "$PROJECT_ROOT/.agentic-journal/manifests")"

# ---------------------------------------------------------------------------
# Specs (.agentic/spec/)
# ---------------------------------------------------------------------------
SPEC_DIR="$(_resolve_path "$AGENTIC_ROOT/spec" "$PROJECT_ROOT/spec")"
FEATURES_FILE="$(_resolve_path "$AGENTIC_ROOT/spec/FEATURES.md" "$PROJECT_ROOT/spec/FEATURES.md")"
ISSUES_FILE="$(_resolve_path "$AGENTIC_ROOT/spec/ISSUES.md" "$PROJECT_ROOT/spec/ISSUES.md")"
NFR_FILE="$(_resolve_path "$AGENTIC_ROOT/spec/NFR.md" "$PROJECT_ROOT/spec/NFR.md")"
REFERENCES_FILE="$(_resolve_path "$AGENTIC_ROOT/spec/REFERENCES.md" "$PROJECT_ROOT/spec/REFERENCES.md")"
LESSONS_FILE="$(_resolve_path "$AGENTIC_ROOT/spec/LESSONS.md" "$PROJECT_ROOT/spec/LESSONS.md")"
ACCEPTANCE_DIR="$(_resolve_path "$AGENTIC_ROOT/spec/acceptance" "$PROJECT_ROOT/spec/acceptance")"
ADR_DIR="$(_resolve_path "$AGENTIC_ROOT/spec/adr" "$PROJECT_ROOT/spec/adr")"
MIGRATIONS_DIR="$(_resolve_path "$AGENTIC_ROOT/spec/migrations" "$PROJECT_ROOT/spec/migrations")"

# ---------------------------------------------------------------------------
# Session (ephemeral state, .agentic/session/)
# ---------------------------------------------------------------------------
SESSION_DIR="$(_resolve_path "$AGENTIC_ROOT/session" "$PROJECT_ROOT/.agentic-state")"
WIP_FILE="$(_resolve_path "$AGENTIC_ROOT/session/WIP.md" "$PROJECT_ROOT/.agentic-state/WIP.md")"
AGENTS_ACTIVE_FILE="$(_resolve_path "$AGENTIC_ROOT/session/AGENTS_ACTIVE.md" "$PROJECT_ROOT/.agentic-state/AGENTS_ACTIVE.md")"
PROPOSALS_DIR="$(_resolve_path "$AGENTIC_ROOT/session/proposals" "$PROJECT_ROOT/.agentic-state/proposals")"
VERIFICATION_STATE="$(_resolve_path "$AGENTIC_ROOT/session/.verification-state" "$PROJECT_ROOT/.agentic-state/.verification-state")"

# ---------------------------------------------------------------------------
# Framework lib directories (inside .agentic/lib/)
# ---------------------------------------------------------------------------
TOOLS_DIR="$(_resolve_path "$AGENTIC_LIB/tools" "$AGENTIC_ROOT/tools")"
AGENTS_LIB_DIR="$(_resolve_path "$AGENTIC_LIB/agents" "$AGENTIC_ROOT/agents")"
WORKFLOWS_DIR="$(_resolve_path "$AGENTIC_LIB/workflows" "$AGENTIC_ROOT/workflows")"
QUALITY_DIR="$(_resolve_path "$AGENTIC_LIB/quality" "$AGENTIC_ROOT/quality")"
CHECKLISTS_DIR="$(_resolve_path "$AGENTIC_LIB/checklists" "$AGENTIC_ROOT/checklists")"
INIT_DIR="$(_resolve_path "$AGENTIC_LIB/init" "$AGENTIC_ROOT/init")"
HOOKS_LIB_DIR="$(_resolve_path "$AGENTIC_LIB/hooks" "$AGENTIC_ROOT/hooks")"
CLAUDE_HOOKS_LIB_DIR="$(_resolve_path "$AGENTIC_LIB/claude-hooks" "$AGENTIC_ROOT/claude-hooks")"
PROMPTS_DIR="$(_resolve_path "$AGENTIC_LIB/prompts" "$AGENTIC_ROOT/prompts")"
SCHEMAS_DIR="$(_resolve_path "$AGENTIC_LIB/schemas" "$AGENTIC_ROOT/schemas")"
PRESETS_DIR="$(_resolve_path "$AGENTIC_LIB/presets" "$AGENTIC_ROOT/presets")"
SUPPORT_DIR="$(_resolve_path "$AGENTIC_LIB/support" "$AGENTIC_ROOT/support")"
TOKEN_EFFICIENCY_DIR="$(_resolve_path "$AGENTIC_LIB/token_efficiency" "$AGENTIC_ROOT/token_efficiency")"
QUALITY_PROFILES_DIR="$(_resolve_path "$AGENTIC_LIB/quality_profiles" "$AGENTIC_ROOT/quality_profiles")"
TEMPLATES_DIR="$(_resolve_path "$AGENTIC_LIB/templates" "$AGENTIC_ROOT/spec")"

# Framework docs (inside .agentic/lib/)
PRINCIPLES_FILE="$(_resolve_path "$AGENTIC_LIB/PRINCIPLES.md" "$AGENTIC_ROOT/PRINCIPLES.md")"
DEVELOPER_GUIDE_FILE="$(_resolve_path "$AGENTIC_LIB/DEVELOPER_GUIDE.md" "$AGENTIC_ROOT/DEVELOPER_GUIDE.md")"
FRAMEWORK_MAP_FILE="$(_resolve_path "$AGENTIC_LIB/FRAMEWORK_MAP.md" "$AGENTIC_ROOT/FRAMEWORK_MAP.md")"
VERSION_FILE="$(_resolve_path "$AGENTIC_LIB/VERSION" "$AGENTIC_ROOT/VERSION")"

# ---------------------------------------------------------------------------
# User extensions (.agentic/local/)
# ---------------------------------------------------------------------------
LOCAL_DIR="$(_resolve_path "$AGENTIC_ROOT/local" "$PROJECT_ROOT/.agentic-local")"

# ---------------------------------------------------------------------------
# Convenience: export ROOT_DIR for scripts that expect it
# ---------------------------------------------------------------------------
ROOT_DIR="$PROJECT_ROOT"
export ROOT_DIR PROJECT_ROOT MAIN_PROJECT_ROOT AGENTIC_ROOT AGENTIC_LIB AGENTS_JSON
