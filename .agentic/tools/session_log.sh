#!/usr/bin/env bash
# session_log.sh - Append-only conversation logging (token-efficient)
# 
# Usage:
#   bash .agentic/tools/session_log.sh "Brief topic" "What was discussed" "key1=value1,key2=value2"
#
# Token efficiency: APPENDS to file, never reads or rewrites whole file
#
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_FILE="${PROJECT_ROOT}/SESSION_LOG.md"

# Get arguments
TOPIC="${1:-Untitled}"
DETAILS="${2:-No details provided}"
METADATA="${3:-}"

# Generate timestamp
TIMESTAMP=$(date +"%Y-%m-%d %H:%M")

# Create log file if doesn't exist (with header)
if [[ ! -f "${LOG_FILE}" ]]; then
  cat > "${LOG_FILE}" <<'HEADER'
# Session Log

**Purpose**: Append-only conversation log for token-efficient session tracking.

**Why append-only**: Large files are expensive to read/rewrite. This file grows by appending, never rewriting.

**Usage**: Agents append entries at natural checkpoints (feature complete, decision made, significant progress).

---

HEADER
fi

# Parse metadata if provided
METADATA_LINES=""
if [[ -n "${METADATA}" ]]; then
  IFS=',' read -ra PAIRS <<< "${METADATA}"
  for pair in "${PAIRS[@]}"; do
    KEY="${pair%%=*}"
    VALUE="${pair#*=}"
    METADATA_LINES="${METADATA_LINES}- **${KEY}**: ${VALUE}\n"
  done
fi

# Append entry (never read existing content!)
cat >> "${LOG_FILE}" <<ENTRY

## ${TIMESTAMP} - ${TOPIC}

${DETAILS}

$(echo -e "${METADATA_LINES}")
---

ENTRY

echo "✓ Logged to SESSION_LOG.md (appended, no full file read)"

