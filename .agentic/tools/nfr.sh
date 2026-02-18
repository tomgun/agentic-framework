#!/usr/bin/env bash
# nfr.sh - Update NFR fields in spec/NFR.md (token-efficient)
#
# Usage:
#   bash .agentic/tools/nfr.sh NFR-0001 status met
#   bash .agentic/tools/nfr.sh NFR-0001 show
#   bash .agentic/tools/nfr.sh list
#
# Token efficiency: Updates single field for single NFR (no full file read)
#
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
NFR_FILE="${PROJECT_ROOT}/spec/NFR.md"

# Check if NFR.md exists
if [[ ! -f "${NFR_FILE}" ]]; then
  echo "Error: spec/NFR.md not found. This project may not define NFRs."
  exit 1
fi

# Arguments
CMD="${1:-}"

if [[ -z "${CMD}" ]]; then
  cat <<'USAGE'
Usage:
  bash nfr.sh list                    # List all NFRs with status
  bash nfr.sh NFR-#### show           # Show single NFR details
  bash nfr.sh NFR-#### status <value> # Update Current status

Status values: unknown | partial | met | violated

Examples:
  bash nfr.sh list
  bash nfr.sh NFR-0001 show
  bash nfr.sh NFR-0001 status met
  bash nfr.sh NFR-0001 status violated
USAGE
  exit 1
fi

# --- list command (no NFR ID needed) ---
if [[ "${CMD}" == "list" ]]; then
  echo "NFRs in spec/NFR.md:"
  echo "---"
  awk '
  /^## NFR-[0-9]{4}:/ {
    if (id != "") {
      printf "  %-10s [%-8s] %s\n", id, status, name
    }
    id = $2
    sub(/:$/, "", id)
    name = $0
    sub(/^## NFR-[0-9]+: */, "", name)
    status = "unknown"
  }
  /^- Current status:/ {
    s = $0
    sub(/^- Current status: */, "", s)
    sub(/ *<!--.*-->.*$/, "", s)
    gsub(/^ +| +$/, "", s)
    status = s
  }
  END {
    if (id != "") printf "  %-10s [%-8s] %s\n", id, status, name
  }' "${NFR_FILE}"
  exit 0
fi

# --- Commands that take an NFR ID ---
NFR_ID="${CMD}"
SUBCMD="${2:-}"

# Validate NFR ID format
if [[ ! "${NFR_ID}" =~ ^NFR-[0-9]{4}$ ]]; then
  echo "Error: NFR ID must be in format NFR-#### (or use 'list' command)"
  exit 1
fi

# Check if NFR exists
if ! grep -q "^## ${NFR_ID}:" "${NFR_FILE}"; then
  echo "Error: ${NFR_ID} not found in spec/NFR.md"
  exit 1
fi

# --- show command ---
if [[ "${SUBCMD}" == "show" ]]; then
  awk -v nfr="${NFR_ID}" '
  /^## / {
    if (found) exit
    if ($0 ~ "^## " nfr ":") found = 1
  }
  found { print }
  ' "${NFR_FILE}"
  exit 0
fi

# --- status command ---
if [[ "${SUBCMD}" == "status" ]]; then
  VALUE="${3:-}"
  if [[ -z "${VALUE}" ]]; then
    echo "Error: Missing status value. Valid: unknown | partial | met | violated"
    exit 1
  fi

  # Validate status value
  case "${VALUE}" in
    unknown|partial|met|violated) ;;
    *) echo "Error: Invalid status '${VALUE}'. Valid: unknown | partial | met | violated"; exit 1 ;;
  esac

  # Update the Current status field for the matching NFR
  TEMP_FILE=$(mktemp)
  awk -v nfr="${NFR_ID}" -v value="${VALUE}" '
  /^## / {
    if ($0 ~ "^## " nfr ":") {
      in_nfr = 1
    } else {
      in_nfr = 0
    }
  }
  in_nfr && /^- Current status:/ {
    print "- Current status: " value
    next
  }
  { print }
  ' "${NFR_FILE}" > "${TEMP_FILE}"

  mv "${TEMP_FILE}" "${NFR_FILE}"
  echo "Updated ${NFR_ID} status -> ${VALUE} in spec/NFR.md"
  exit 0
fi

if [[ -z "${SUBCMD}" ]]; then
  echo "Error: Missing command for ${NFR_ID}. Use: show | status <value>"
else
  echo "Error: Unknown command '${SUBCMD}'. Use: show | status"
fi
exit 1
