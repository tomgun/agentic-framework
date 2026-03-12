#!/usr/bin/env bash
# kickoff.sh -- Thin wrapper for kickoff.py operations.
# Called by ag.sh cmd_kickoff. Delegates to Python for all logic.
#
# Usage:
#   bash kickoff.sh generate --features-json '...' [--overview TEXT] [--project-root PATH]
#   bash kickoff.sh validate [--project-root PATH]
#   bash kickoff.sh review [--project-root PATH]
#   bash kickoff.sh promote [--force] [--project-root PATH]
#   bash kickoff.sh discard [--project-root PATH]
#   bash kickoff.sh status [--project-root PATH]
#   bash kickoff.sh merge <source> <target> [--project-root PATH]
#   bash kickoff.sh rename <id> <name> [--project-root PATH]
#   bash kickoff.sh remove <id> [--project-root PATH]
#   bash kickoff.sh reorder <id1> <id2> ... [--project-root PATH]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUTO_DIR="$SCRIPT_DIR/../auto"

python3 "$AUTO_DIR/kickoff.py" "$@"
