#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(pwd)"
STATUS_FILE="${ROOT_DIR}/STATUS.md"
STACK_FILE="${ROOT_DIR}/STACK.md"

# Check if retrospectives are enabled
if [[ ! -f "${STACK_FILE}" ]]; then
  echo "STACK.md not found. Skipping retrospective check."
  exit 0
fi

RETRO_ENABLED=$(grep -E '^\s*-?\s*retrospective_enabled:\s*yes' "${STACK_FILE}" || echo "")

if [[ -z "${RETRO_ENABLED}" ]]; then
  echo "Retrospectives not enabled in STACK.md."
  echo "To enable, add to STACK.md:"
  echo "  - retrospective_enabled: yes"
  exit 0
fi

echo "=== Retrospective Check ==="
echo

# Get configuration
TRIGGER=$(grep -E '^\s*-?\s*retrospective_trigger:' "${STACK_FILE}" | head -n 1 | sed 's/.*: *//' || echo "both")
INTERVAL_DAYS=$(grep -E '^\s*-?\s*retrospective_interval_days:' "${STACK_FILE}" | head -n 1 | sed 's/.*: *//' || echo "14")
INTERVAL_FEATURES=$(grep -E '^\s*-?\s*retrospective_interval_features:' "${STACK_FILE}" | head -n 1 | sed 's/.*: *//' || echo "10")

echo "Configuration:"
echo "  Trigger: ${TRIGGER}"
echo "  Interval (days): ${INTERVAL_DAYS}"
echo "  Interval (features): ${INTERVAL_FEATURES}"
echo

# Get last retrospective date from STATUS.md
LAST_RETRO_DATE=$(grep -E 'Last retrospective:' "${STATUS_FILE}" | head -n 1 | sed 's/.*: *//' | awk '{print $1}' || echo "")

if [[ -z "${LAST_RETRO_DATE}" ]]; then
  echo "⚠️  No retrospective recorded in STATUS.md yet."
  echo "   Consider running your first retrospective!"
  echo
  echo "   See: .agentic/workflows/retrospective.md"
  exit 0
fi

echo "Last retrospective: ${LAST_RETRO_DATE}"

# Check time-based trigger (if enabled)
if [[ "${TRIGGER}" == "time" || "${TRIGGER}" == "both" ]]; then
  # Calculate days since last retrospective
  if command -v gdate &> /dev/null; then
    # macOS with GNU coreutils
    LAST_RETRO_TIMESTAMP=$(gdate -d "${LAST_RETRO_DATE}" +%s)
    CURRENT_TIMESTAMP=$(gdate +%s)
  else
    # Linux
    LAST_RETRO_TIMESTAMP=$(date -d "${LAST_RETRO_DATE}" +%s)
    CURRENT_TIMESTAMP=$(date +%s)
  fi
  
  SECONDS_DIFF=$((CURRENT_TIMESTAMP - LAST_RETRO_TIMESTAMP))
  DAYS_DIFF=$((SECONDS_DIFF / 86400))
  
  echo "Days since last retrospective: ${DAYS_DIFF}"
  
  if [[ "${DAYS_DIFF}" -ge "${INTERVAL_DAYS}" ]]; then
    echo
    echo "✅ TIME TRIGGER MET: ${DAYS_DIFF} days >= ${INTERVAL_DAYS} days threshold"
    echo "   Consider running a retrospective!"
    echo
    echo "   Run: Tell your agent 'Run a project retrospective'"
    echo "   See: .agentic/workflows/retrospective.md"
    exit 1  # Exit with 1 to indicate trigger is met
  fi
fi

# Check feature-based trigger (if enabled)
if [[ "${TRIGGER}" == "features" || "${TRIGGER}" == "both" ]]; then
  # Count shipped features since last retrospective
  # This is a simplified check - could be enhanced to track exact feature count
  LAST_RETRO_FEATURES=$(grep -E 'Features shipped since last:' "${STATUS_FILE}" | head -n 1 | sed 's/.*: *//' || echo "0")
  CURRENT_SHIPPED=$(grep -c 'Status: shipped' "${ROOT_DIR}/spec/FEATURES.md" 2>/dev/null || echo "0")
  
  FEATURES_SINCE=$((CURRENT_SHIPPED - LAST_RETRO_FEATURES))
  
  echo "Features shipped since last retrospective: ${FEATURES_SINCE}"
  
  if [[ "${FEATURES_SINCE}" -ge "${INTERVAL_FEATURES}" ]]; then
    echo
    echo "✅ FEATURE TRIGGER MET: ${FEATURES_SINCE} features >= ${INTERVAL_FEATURES} features threshold"
    echo "   Consider running a retrospective!"
    echo
    echo "   Run: Tell your agent 'Run a project retrospective'"
    echo "   See: .agentic/workflows/retrospective.md"
    exit 1  # Exit with 1 to indicate trigger is met
  fi
fi

echo
echo "No retrospective triggers met. Continue with regular work."
exit 0

