#!/usr/bin/env bash
# feature.sh - Update feature fields in .agentic/spec/FEATURES.md (token-efficient)
#
# Usage:
#   bash .agentic/tools/feature.sh F-002 status in_progress
#   bash .agentic/tools/feature.sh F-002 status shipped
#   bash .agentic/tools/feature.sh F-002 impl-state partial
#   bash .agentic/tools/feature.sh F-002 impl-state complete
#   bash .agentic/tools/feature.sh F-002 tests complete
#   bash .agentic/tools/feature.sh F-002 accepted yes
#
# Token efficiency: Updates single field for single feature (no full file read)
#
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../paths.sh"
# FEATURES_FILE provided by paths.sh

# Check if FEATURES.md exists
if [[ ! -f "${FEATURES_FILE}" ]]; then
  echo "Error: .agentic/spec/FEATURES.md not found. Run project scaffold or create manually."
  exit 1
fi

# Arguments
FEATURE_ID="${1:-}"
FIELD="${2:-}"
VALUE="${3:-}"

if [[ -z "${FEATURE_ID}" ]] || [[ -z "${FIELD}" ]] || [[ -z "${VALUE}" ]]; then
  cat <<'USAGE'
Usage: bash feature.sh <feature-id> <field> <value> [extra]

Fields:
  add          - Create new feature: feature.sh F-XXXX add "Feature Name" [domain]
  status       - planned | specced | criteria_set | tests_written | implementing | verified | documented | committed | shipped | deprecated
  impl-state   - none | partial | complete
  tests        - todo | partial | complete | n/a
  accepted     - yes | no
  parent       - F-XXXX (parent feature ID)
  source       - path to design document (ADR, roadmap, epic plan)

Examples:
  bash feature.sh F-002 add "My Feature" infrastructure
  bash feature.sh F-002 status in_progress
  bash feature.sh F-002 status shipped
  bash feature.sh F-002 impl-state complete
  bash feature.sh F-002 tests complete
  bash feature.sh F-002 accepted yes
  bash feature.sh F-002 parent F-001
  bash feature.sh F-002 source spec/adr/ADR-001.md
USAGE
  exit 1
fi

# --- Cap subcommand: discovery-format capability entries (F-042) ---
# Must be checked BEFORE the add handler (which also matches FIELD=add when FEATURE_ID=cap)
if [[ "${FEATURE_ID}" == "cap" ]]; then
  # Inline the cap handler here — source is below after formal add
  _CAP_ACTION="${FIELD}"
  _CAP_NAME="${VALUE}"

  if [[ -z "$_CAP_ACTION" || -z "$_CAP_NAME" ]]; then
    cat <<'CAP_USAGE'
Usage: bash feature.sh cap <action> "Name" [args]

Actions:
  add "Name" "Description" [--decisions "..."]   Add a capability entry
  status "Name" built|in_progress|planned         Update capability status

Examples:
  bash feature.sh cap add "Search" "Full-text product search"
  bash feature.sh cap add "Search" "Full-text search" --decisions "Used ES over Postgres FTS"
  bash feature.sh cap status "Search" built
CAP_USAGE
    exit 1
  fi

  source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../settings.sh" 2>/dev/null || true
  _ft=$(get_setting "feature_tracking" "no" 2>/dev/null || echo "no")

  if [[ "$_CAP_ACTION" == "add" ]]; then
    _CAP_DESC=""
    _CAP_DECISIONS=""
    _cap_skip=0
    for _cap_arg in "${@:4}"; do
      if [[ $_cap_skip -eq 1 ]]; then
        _CAP_DECISIONS="$_cap_arg"
        _cap_skip=0
        continue
      fi
      case "$_cap_arg" in
        --decisions) _cap_skip=1 ;;
        --decisions=*) _CAP_DECISIONS="${_cap_arg#--decisions=}" ;;
        *) [[ -z "$_CAP_DESC" ]] && _CAP_DESC="$_cap_arg" ;;
      esac
    done

    if grep -qF "## ${_CAP_NAME}" "${FEATURES_FILE}" 2>/dev/null; then
      echo "Error: Capability '${_CAP_NAME}' already exists in FEATURES.md"
      exit 1
    fi

    if [[ "$_ft" == "yes" ]]; then
      NEXT_ID=$(grep -oE 'F-[0-9]+' "${FEATURES_FILE}" 2>/dev/null | sed 's/F-//' | sort -n | tail -1)
      NEXT_ID=${NEXT_ID:-0}
      NEXT_ID=$(printf "F-%03d" $((10#$NEXT_ID + 1)))
      bash "${BASH_SOURCE[0]}" "$NEXT_ID" add "$_CAP_NAME" "general"
      exit $?
    fi

    {
      echo ""
      echo "---"
      echo ""
      echo "## ${_CAP_NAME}"
      echo "**Status**: planned"
      [[ -n "$_CAP_DESC" ]] && echo "$_CAP_DESC"
      [[ -n "$_CAP_DECISIONS" ]] && echo "Decisions: $_CAP_DECISIONS"
    } >> "${FEATURES_FILE}"
    echo "✓ Added capability: ${_CAP_NAME}"
    exit 0
  fi

  if [[ "$_CAP_ACTION" == "status" ]]; then
    _NEW_STATUS="${4:-}"
    if [[ -z "$_NEW_STATUS" ]]; then
      echo "Error: Status value required (built, in_progress, planned)"
      exit 1
    fi
    case "$_NEW_STATUS" in
      built|in_progress|planned) ;;
      shipped) _NEW_STATUS="built" ;;
      *) echo "Error: Invalid discovery status '$_NEW_STATUS'. Use: built, in_progress, planned"; exit 1 ;;
    esac
    if grep -qF "## ${_CAP_NAME}" "${FEATURES_FILE}" 2>/dev/null; then
      awk -v name="## ${_CAP_NAME}" -v status="$_NEW_STATUS" '
        index($0, name) == 1 { found=1 }
        found && /^\*\*Status\*\*:/ { sub(/\*\*Status\*\*: *[a-z_]+/, "**Status**: " status); found=0 }
        { print }
      ' "${FEATURES_FILE}" > "${FEATURES_FILE}.tmp" && mv "${FEATURES_FILE}.tmp" "${FEATURES_FILE}"
      echo "✓ ${_CAP_NAME} → ${_NEW_STATUS}"
    else
      echo "Error: Capability '${_CAP_NAME}' not found in FEATURES.md"
      exit 1
    fi
    exit 0
  fi

  echo "Error: Unknown cap action '$_CAP_ACTION'. Use: add, status"
  exit 1
fi

# --- Add subcommand: create a new feature in heading format (F-0300 R4) ---
# Note: FEATURES_FILE existence is already checked at line 20 (exits if missing).
if [[ "${FIELD}" == "add" ]]; then
  FEATURE_NAME="${VALUE}"
  DOMAIN="${4:-general}"

  # Check if feature already exists
  if grep -qE "(^## ${FEATURE_ID}:|^### ${FEATURE_ID}:?|\| ${FEATURE_ID} \|)" "${FEATURES_FILE}" 2>/dev/null; then
    echo "Error: Feature ${FEATURE_ID} already exists in FEATURES.md"
    exit 1
  fi

  # Append new feature in heading format
  cat >> "${FEATURES_FILE}" << EOF

---

## ${FEATURE_ID}: ${FEATURE_NAME}

**Status**: planned
**Category**: ${DOMAIN}
**Priority**: medium
**Complexity**: medium

**Description**: (TODO: add description)

**Implementation**:
- State: none
- Code: (TODO)
- Tests: (TODO)

**Contract**: See \`spec/contracts/${FEATURE_ID}.yaml\`
EOF

  echo "✓ Added ${FEATURE_ID}: ${FEATURE_NAME} (domain: ${DOMAIN}) to FEATURES.md"

  # Auto-create draft contract if contracts dir exists and contract doesn't
  CONTRACTS_DIR="${SPEC_DIR}/contracts"
  CONTRACT_FILE="${CONTRACTS_DIR}/${FEATURE_ID}.yaml"
  if [[ -d "${CONTRACTS_DIR}" ]] && [[ ! -f "${CONTRACT_FILE}" ]]; then
    if command -v python3 >/dev/null 2>&1; then
      _AG_CONTRACT_FILE="$CONTRACT_FILE" \
      _AG_FEATURE_ID="$FEATURE_ID" \
      _AG_NAME="$FEATURE_NAME" \
      _AG_DOMAIN="$DOMAIN" \
      PYTHONPATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../" python3 -c "
import os
from pathlib import Path
from contracts import Contract, Assertion, save_contract

contract = Contract(
    id=os.environ['_AG_FEATURE_ID'],
    name=os.environ['_AG_NAME'],
    lifecycle='exploring',
    description='TODO: Describe what this feature does and why it exists.',
    assertions=[
        Assertion(id='AC-001', text='TODO: First acceptance criterion', type='structural', draft=True),
    ],
    protection='none',
    category=os.environ.get('_AG_DOMAIN', 'uncategorized'),
)
save_contract(contract, Path(os.environ['_AG_CONTRACT_FILE']))
print(f\"  + Created draft contract: {os.environ['_AG_CONTRACT_FILE']}\")
" 2>/dev/null || true
    fi
  fi

  exit 0
fi

# Validate feature ID format
if ! is_feature_id "${FEATURE_ID}"; then
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
  # Table format: | F-002 | Name | Status | Impl | Tests | Accepted |
  # Column mapping: 1=ID, 2=Name, 3=Status, 4=Impl, 5=Tests, 6=Accepted
  case "${FIELD}" in
    status)     COL=3 ;;
    impl-state) COL=4; VALUE=$(echo "${VALUE}" | sed 's/none/-/; s/partial/partial/; s/complete/complete/') ;;
    tests)      COL=5; VALUE=$(echo "${VALUE}" | sed 's/todo/-/; s/n\/a/-/') ;;
    accepted)   COL=6 ;;
    parent)     echo "Error: parent field not supported in table format"; exit 1 ;;
    source)     echo "Error: source field not supported in table format"; exit 1 ;;
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
  # Heading format: ## F-002: Name with - Status: lines
  awk -v fid="${FEATURE_ID}" -v field="${FIELD}" -v value="${VALUE}" -v ts="${TIMESTAMP}" '
  BEGIN { SOURCE_DONE = 0 }
  /^##[#]? F-[0-9][0-9][0-9][0-9]+:/ {
    if ($0 ~ fid) {
      IN_FEATURE = 1
      SOURCE_DONE = 0
    } else {
      IN_FEATURE = 0
    }
  }

  IN_FEATURE && field == "status" && /^(\*\*Status\*\*|- Status):/ {
    if ($0 ~ /^\*\*Status\*\*/) {
      print "**Status**: " value
    } else {
      print "- Status: " value
    }
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

  IN_FEATURE && field == "parent" && /^(\*\*Parent\*\*|- Parent):/ {
    if ($0 ~ /^\*\*Parent\*\*/) {
      print "**Parent**: " value
    } else {
      print "- Parent: " value
    }
    next
  }

  IN_FEATURE && field == "source" && /^(\*\*Source\*\*|- Source):/ {
    if ($0 ~ /^\*\*Source\*\*/) {
      print "**Source**: " value
    } else {
      print "- Source: " value
    }
    SOURCE_DONE = 1
    next
  }

  # Insert **Source** after **Status** if not already present
  IN_FEATURE && field == "source" && !SOURCE_DONE && /^\*\*Status\*\*:/ {
    print
    print "**Source**: " value
    SOURCE_DONE = 1
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
echo "Note: Review with 'git diff .agentic/spec/FEATURES.md'"

