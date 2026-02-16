#!/usr/bin/env bash
# list-tools.sh - Tool Discovery Menu
# Lists all framework tools organized by category
# Works with any AI agent (Claude Code, Cursor, Codex, Copilot)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors (disabled if not TTY)
if [ -t 1 ]; then
    BOLD='\033[1m'
    DIM='\033[2m'
    NC='\033[0m'
else
    BOLD='' DIM='' NC=''
fi

cat << EOF
${BOLD}=== Agentic Framework Tools ===${NC}

${BOLD}GATEWAY (Start Here)${NC}
  ag.sh               Single entry point - run this first!
                      Commands: start, implement, commit, done, tools, verify

${BOLD}VERIFICATION${NC}
  doctor.sh           Health check (--full, --phase, --pre-commit)
  verify.sh           Run all validation checks
  pre-commit-check.sh Pre-commit structural checks (11 gates)

${BOLD}SESSION MANAGEMENT${NC}
  wip.sh              Track work-in-progress (start, checkpoint, complete)
  journal.sh          Append to JOURNAL.md (token-efficient)
  session_log.sh      Quick checkpoints to SESSION_LOG.md
  status.sh           Update STATUS.md sections
  blocker.sh          Manage HUMAN_NEEDED.md blockers

${BOLD}FEATURES (Formal Profile)${NC}
  feature.sh          Update spec/FEATURES.md fields
  query_features.py   Search/filter features by status, tags, owner
  quick_feature.sh    Rapid feature creation
  accept.sh           Mark feature as accepted

${BOLD}CONTEXT & REPORTING${NC}
  brief.sh            Quick project context summary
  report.sh           What's missing / needs acceptance
  dashboard.sh        Project metrics dashboard
  whatchanged.sh      Recent changes summary

${BOLD}PROJECT SETUP${NC}
  start.sh            Initialize new project with framework
  setup-agent.sh      Configure agent-specific settings
  create-agent.sh     Create custom domain agents
  suggest-agents.sh   Get agent suggestions for your stack

${BOLD}CODE QUALITY${NC}
  coverage.sh         Check code annotation coverage
  deps.sh             Dependency analysis
  stale.sh            Find stale documentation
  sync_docs.sh        Sync documentation scaffolding
  drift.sh            Check for spec/code drift

${BOLD}GIT & VERSIONING${NC}
  worktree.sh         Manage git worktrees for multi-agent
  upgrade.sh          Upgrade framework version
  version_check.sh    Check framework version

${BOLD}ADVANCED${NC}
  feature_graph.sh    Visualize feature dependencies
  migration.sh        Spec migration management
  mutation_test.sh    Run mutation tests
  context-for-role.sh Get context for specific agent role

${BOLD}USAGE${NC}
  Run any tool:  bash .agentic/tools/<tool>.sh [args]
  Get help:      bash .agentic/tools/<tool>.sh --help

${BOLD}RECOMMENDED WORKFLOW${NC}
  1. ag start              # Begin session, see status
  2. ag implement F-XXXX   # Start feature with gates
  3. (do the work)
  4. ag done F-XXXX        # Verify completion
  5. ag commit             # Pre-commit checks
EOF
