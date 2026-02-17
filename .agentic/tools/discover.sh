#!/usr/bin/env bash
# discover.sh - Orchestrate project discovery for brownfield onboarding
# Called by scaffold.sh when existing codebase is detected
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source settings library if available
if [[ -f "$SCRIPT_DIR/../lib/settings.sh" ]]; then
  source "$SCRIPT_DIR/../lib/settings.sh"
fi

# Defaults
PROFILE=""
ROOT_DIR="$(pwd)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      PROFILE="${2:-}"
      shift 2
      ;;
    --root)
      ROOT_DIR="${2:-$(pwd)}"
      shift 2
      ;;
    -h|--help)
      echo "Usage: bash .agentic/tools/discover.sh [--profile discovery|formal] [--root DIR]"
      echo "Analyzes existing codebase and generates onboarding proposals."
      exit 0
      ;;
    *)
      echo "Unknown arg: $1" >&2
      exit 2
      ;;
  esac
done

# Resolve profile from settings if not explicitly provided
if [[ -z "$PROFILE" ]]; then
  if type get_setting &>/dev/null; then
    PROFILE="$(get_setting "profile" "discovery")"
  else
    PROFILE="discovery"
  fi
fi

# Check Python 3 availability
if ! command -v python3 &>/dev/null; then
  echo "ERROR: Python 3 is required for auto-discovery but not found." >&2
  echo "Install Python 3 or skip auto-discovery with standard init." >&2
  exit 1
fi

# Ensure output directory exists
mkdir -p "${ROOT_DIR}/.agentic-state/proposals"

REPORT_PATH="${ROOT_DIR}/.agentic-state/discovery_report.json"
PROPOSALS_DIR="${ROOT_DIR}/.agentic-state/proposals"

echo "Running codebase analysis..."

# Step 1: Analyze codebase and generate discovery report
if ! python3 "${SCRIPT_DIR}/discover.py" \
    --root "$ROOT_DIR" \
    --output "$REPORT_PATH" \
    --profile "$PROFILE"; then
  echo "WARN: Codebase analysis failed" >&2
  exit 1
fi

echo "Generating proposals..."

# Step 2: Render proposals from discovery report
if ! python3 "${SCRIPT_DIR}/render_proposals.py" \
    --report "$REPORT_PATH" \
    --templates "${ROOT_DIR}/.agentic/init" \
    --output "$PROPOSALS_DIR" \
    --profile "$PROFILE"; then
  echo "WARN: Proposal rendering failed" >&2
  exit 1
fi

# Summary
echo ""
echo "Auto-discovery complete:"
echo "  Report: ${REPORT_PATH}"
echo "  Proposals: ${PROPOSALS_DIR}/"
if [[ -f "$REPORT_PATH" ]]; then
  # Quick summary from JSON
  python3 -c "
import json, sys
try:
    r = json.load(open('${REPORT_PATH}'))
    stack = r.get('stack', {})
    lang = stack.get('language', 'unknown')
    fw = stack.get('framework', '')
    feat_count = len(r.get('features', []))
    print(f'  Detected: {lang}' + (f' / {fw}' if fw else ''))
    if feat_count:
        print(f'  Features discovered: {feat_count}')
except Exception:
    pass
" 2>/dev/null || true
fi
echo ""
echo "Proposals are marked with <!-- PROPOSAL --> and require human review."
echo "Approve with: ag approve-onboarding"
