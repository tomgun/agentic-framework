#!/usr/bin/env bash
# status.sh — Display publishing progress from publish-state.json
# Usage: status.sh [--json]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${PROJECT_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
STATE_FILE="$ROOT_DIR/.agentic/session/publish-state.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

status_icon() {
    case "$1" in
        passed)  echo -e "${GREEN}✓${NC}" ;;
        failed)  echo -e "${RED}✗${NC}" ;;
        running) echo -e "${BLUE}⟳${NC}" ;;
        skipped) echo -e "${YELLOW}⊘${NC}" ;;
        pending) echo "○" ;;
        *)       echo "?" ;;
    esac
}

main() {
    if [[ "${1:-}" == "--json" ]]; then
        if [[ -f "$STATE_FILE" ]]; then
            cat "$STATE_FILE"
        else
            echo "{}"
        fi
        return 0
    fi

    if [[ ! -f "$STATE_FILE" ]]; then
        echo "No publish state found."
        echo "Run 'ag publish <ios|android>' to start publishing."
        return 0
    fi

    # Parse with python3 (available in framework)
    python3 - "$STATE_FILE" << 'PYTHON'
import json, sys

with open(sys.argv[1]) as f:
    state = json.load(f)

platform = state.get("platform", "unknown")
provider = state.get("provider", "unknown")
started = state.get("started_at", "unknown")
dry_run = state.get("dry_run", False)

print(f"=== Publish Status ===")
print(f"Platform:  {platform}")
print(f"Provider:  {provider}")
print(f"Started:   {started}")
if dry_run:
    print(f"Mode:      DRY RUN")
print()

phases = state.get("phases", {})
phase_order = ["preflight", "build", "screenshots", "metadata", "submit", "monitor"]

icons = {"passed": "✓", "failed": "✗", "running": "⟳", "skipped": "⊘", "pending": "○"}

for phase in phase_order:
    info = phases.get(phase, {})
    status = info.get("status", "pending")
    icon = icons.get(status, "?")
    line = f"  {icon} {phase}: {status}"
    if "reason" in info:
        line += f" ({info['reason']})"
    if "error" in info:
        line += f" — {info['error']}"
    if "artifact" in info:
        line += f" → {info['artifact']}"
    print(line)

# Summary
total = len(phase_order)
passed = sum(1 for p in phase_order if phases.get(p, {}).get("status") == "passed")
failed = sum(1 for p in phase_order if phases.get(p, {}).get("status") == "failed")
skipped = sum(1 for p in phase_order if phases.get(p, {}).get("status") == "skipped")
pending = total - passed - failed - skipped

print()
if failed > 0:
    print(f"Status: FAILED ({passed} passed, {failed} failed, {skipped} skipped, {pending} pending)")
elif pending > 0:
    print(f"Status: IN PROGRESS ({passed} passed, {skipped} skipped, {pending} pending)")
else:
    print(f"Status: COMPLETE ({passed} passed, {skipped} skipped)")
PYTHON
}

main "$@"
