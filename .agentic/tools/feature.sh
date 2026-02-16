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
  echo "Error: spec/FEATURES.md not found. This project may not use Formal mode."
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

# Check if feature exists (support both table and heading formats)
if ! grep -qE "(^## ${FEATURE_ID}:|^### ${FEATURE_ID}:?|\| ${FEATURE_ID} \|)" "${FEATURES_FILE}"; then
  echo "Error: Feature ${FEATURE_ID} not found in FEATURES.md"
  exit 1
fi

# Detect format: table or heading-based
if grep -q "| ${FEATURE_ID} |" "${FEATURES_FILE}"; then
  FORMAT="table"
else
  FORMAT="heading"
fi

# Update timestamp
TIMESTAMP=$(date +"%Y-%m-%d")

# Temporary file for safe updates
TEMP_FILE=$(mktemp)

# Process the file based on format
if [[ "${FORMAT}" == "table" ]]; then
  # Table format: | F-0003 | Name | Status | Impl | Tests | Accepted |
  # Column mapping: 1=ID, 2=Name, 3=Status, 4=Impl, 5=Tests, 6=Accepted
  case "${FIELD}" in
    status)     COL=3 ;;
    impl-state) COL=4; VALUE=$(echo "${VALUE}" | sed 's/none/-/; s/partial/partial/; s/complete/complete/') ;;
    tests)      COL=5; VALUE=$(echo "${VALUE}" | sed 's/todo/-/; s/n\/a/-/') ;;
    accepted)   COL=6 ;;
    *) echo "Error: Unknown field ${FIELD}"; exit 1 ;;
  esac

  awk -v fid="${FEATURE_ID}" -v col="${COL}" -v value="${VALUE}" '
  /\| '"${FEATURE_ID}"' \|/ {
    n = split($0, fields, "|")
    for (i = 1; i <= n; i++) {
      gsub(/^[ \t]+|[ \t]+$/, "", fields[i])  # trim
    }
    fields[col + 1] = value  # +1 because split includes empty first element

    # Reconstruct row
    printf "|"
    for (i = 2; i <= n - 1; i++) {
      printf " %s |", fields[i]
    }
    printf "\n"
    next
  }
  { print }
  ' "${FEATURES_FILE}" > "${TEMP_FILE}"
else
  # Heading format: ## F-0003: Name with - Status: lines
  awk -v fid="${FEATURE_ID}" -v field="${FIELD}" -v value="${VALUE}" -v ts="${TIMESTAMP}" '
  /^##+ F-[0-9]{4}:?/ {
    if ($0 ~ fid) {
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
fi

# Replace original file
mv "${TEMP_FILE}" "${FEATURES_FILE}"

echo "✓ Updated ${FEATURE_ID} ${FIELD} → ${VALUE} in FEATURES.md"
echo "Note: Review with 'git diff spec/FEATURES.md'"

