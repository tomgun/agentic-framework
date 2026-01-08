#!/usr/bin/env bash
# feature.sh - Update feature fields in spec/FEATURES.md (token-efficient)
#
# Usage:
#   bash .agentic/tools/feature.sh F-0003 status in_progress
#   bash .agentic/tools/feature.sh F-0003 status shipped
#   bash .agentic/tools/feature.sh F-0003 impl-state partial
#   bash .agentic/tools/feature.sh F-0003 impl-state complete
#   bash .agentic/tools/feature.sh F-0003 tests complete
#   bash .agentic/tools/feature.sh F-0003 accepted yes
#
# Token efficiency: Updates single field for single feature (no full file read)
#
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FEATURES_FILE="${PROJECT_ROOT}/spec/FEATURES.md"

# Check if FEATURES.md exists
if [[ ! -f "${FEATURES_FILE}" ]]; then
  echo "Error: spec/FEATURES.md not found. This project may not use Core+PM mode."
  exit 1
fi

# Arguments
FEATURE_ID="${1:-}"
FIELD="${2:-}"
VALUE="${3:-}"

if [[ -z "${FEATURE_ID}" ]] || [[ -z "${FIELD}" ]] || [[ -z "${VALUE}" ]]; then
  cat <<'USAGE'
Usage: bash feature.sh <feature-id> <field> <value>

Fields:
  status       - planned | in_progress | shipped | deprecated
  impl-state   - none | partial | complete
  tests        - todo | partial | complete | n/a
  accepted     - yes | no

Examples:
  bash feature.sh F-0003 status in_progress
  bash feature.sh F-0003 status shipped
  bash feature.sh F-0003 impl-state complete
  bash feature.sh F-0003 tests complete
  bash feature.sh F-0003 accepted yes
USAGE
  exit 1
fi

# Validate feature ID format
if [[ ! "${FEATURE_ID}" =~ ^F-[0-9]{4}$ ]]; then
  echo "Error: Feature ID must be in format F-####"
  exit 1
fi

# Check if feature exists
if ! grep -q "^## ${FEATURE_ID}:" "${FEATURES_FILE}"; then
  echo "Error: Feature ${FEATURE_ID} not found in FEATURES.md"
  exit 1
fi

# Update timestamp
TIMESTAMP=$(date +"%Y-%m-%d")

# Temporary file for safe updates
TEMP_FILE=$(mktemp)

# Process the file
IN_FEATURE=false
awk -v fid="${FEATURE_ID}" -v field="${FIELD}" -v value="${VALUE}" -v ts="${TIMESTAMP}" '
/^## F-[0-9]{4}:/ {
  if ($0 ~ "^## " fid ":") {
    IN_FEATURE = 1
  } else {
    IN_FEATURE = 0
  }
}

IN_FEATURE && field == "status" && /^- Status:/ {
  print "- Status: " value
  next
}

IN_FEATURE && field == "impl-state" && /^  - State:/ {
  print "  - State: " value
  next
}

IN_FEATURE && field == "tests" && /^  - Unit:/ {
  print "  - Unit: " value
  next
}

IN_FEATURE && field == "accepted" && /^  - Accepted:/ {
  print "  - Accepted: " value
  if (value == "yes") {
    getline
    print "  - Accepted at: " ts
  } else {
    getline
  }
  next
}

{ print }
' "${FEATURES_FILE}" > "${TEMP_FILE}"

# Replace original file
mv "${TEMP_FILE}" "${FEATURES_FILE}"

echo "✓ Updated ${FEATURE_ID} ${FIELD} → ${VALUE} in FEATURES.md"
echo "Note: Review with 'git diff spec/FEATURES.md'"

