#!/usr/bin/env bash
# validation-cache.sh: Cache validation results to avoid redundant checks
#
# Purpose: Speed up doctor.sh, verify.sh, and validate_specs.py by caching results
#
# Usage:
#   bash .agentic/tools/validation-cache.sh check doctor    # Check if cached results exist
#   bash .agentic/tools/validation-cache.sh get doctor      # Get cached results
#   bash .agentic/tools/validation-cache.sh set doctor "OK" # Store results
#   bash .agentic/tools/validation-cache.sh clear           # Clear all cache
#
# Cache invalidation:
#   - Time-based: Cache expires after 5 minutes
#   - File-based: Cache invalidates when relevant files change (via hash)

set -euo pipefail

PROJECT_ROOT="${1:-$(pwd)}"
CACHE_DIR=".agentic/.cache"
CACHE_FILE="$CACHE_DIR/validation-results.json"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Ensure cache directory exists
mkdir -p "$CACHE_DIR"

# Initialize cache file if doesn't exist
if [[ ! -f "$CACHE_FILE" ]]; then
  echo '{}' > "$CACHE_FILE"
fi

# Function: Get hash of relevant files
get_files_hash() {
  local validation_type="$1"
  
  case "$validation_type" in
    doctor)
      # Hash structure files
      find . -maxdepth 2 -name "*.md" -type f ! -path "./.git/*" ! -path "./.agentic/.cache/*" 2>/dev/null | sort | xargs md5sum 2>/dev/null | md5sum | awk '{print $1}' || echo "none"
      ;;
    specs)
      # Hash spec files
      find spec -name "*.md" -type f 2>/dev/null | sort | xargs md5sum 2>/dev/null | md5sum | awk '{print $1}' || echo "none"
      ;;
    verify)
      # Hash all tracked files
      git ls-files 2>/dev/null | xargs md5sum 2>/dev/null | md5sum | awk '{print $1}' || echo "none"
      ;;
    *)
      echo "none"
      ;;
  esac
}

# Function: Check if cache is valid
is_cache_valid() {
  local validation_type="$1"
  
  # Get cached data
  local cached_data=$(jq -r ".[\"$validation_type\"]" "$CACHE_FILE" 2>/dev/null || echo "null")
  
  if [[ "$cached_data" == "null" ]]; then
    return 1  # No cache
  fi
  
  # Check timestamp (5 minute expiry)
  local cached_timestamp=$(echo "$cached_data" | jq -r '.timestamp' 2>/dev/null || echo "0")
  local current_timestamp=$(date +%s)
  local age=$((current_timestamp - cached_timestamp))
  
  if [[ $age -gt 300 ]]; then  # 5 minutes = 300 seconds
    return 1  # Cache too old
  fi
  
  # Check file hash
  local cached_hash=$(echo "$cached_data" | jq -r '.files_hash' 2>/dev/null || echo "none")
  local current_hash=$(get_files_hash "$validation_type")
  
  if [[ "$cached_hash" != "$current_hash" ]]; then
    return 1  # Files changed
  fi
  
  return 0  # Cache is valid
}

# Command: check
cmd_check() {
  local validation_type="$1"
  
  if is_cache_valid "$validation_type"; then
    echo -e "${GREEN}✓ Valid cache exists for '$validation_type'${NC}"
    exit 0
  else
    echo -e "${YELLOW}✗ No valid cache for '$validation_type'${NC}"
    exit 1
  fi
}

# Command: get
cmd_get() {
  local validation_type="$1"
  
  if ! is_cache_valid "$validation_type"; then
    echo "ERROR: No valid cache" >&2
    exit 1
  fi
  
  jq -r ".[\"$validation_type\"].result" "$CACHE_FILE"
}

# Command: set
cmd_set() {
  local validation_type="$1"
  local result="$2"
  
  local timestamp=$(date +%s)
  local files_hash=$(get_files_hash "$validation_type")
  
  # Create cache entry
  local cache_entry=$(jq -n \
    --arg result "$result" \
    --arg timestamp "$timestamp" \
    --arg hash "$files_hash" \
    '{result: $result, timestamp: ($timestamp | tonumber), files_hash: $hash}')
  
  # Update cache file
  jq ".[\"$validation_type\"] = $cache_entry" "$CACHE_FILE" > "$CACHE_FILE.tmp"
  mv "$CACHE_FILE.tmp" "$CACHE_FILE"
  
  echo -e "${GREEN}✓ Cached results for '$validation_type'${NC}"
}

# Command: clear
cmd_clear() {
  echo '{}' > "$CACHE_FILE"
  echo -e "${GREEN}✓ Cache cleared${NC}"
}

# Main
COMMAND="${1:-help}"

case "$COMMAND" in
  check)
    if [[ $# -lt 2 ]]; then
      echo "Usage: validation-cache.sh check <type>"
      exit 1
    fi
    cmd_check "$2"
    ;;
  get)
    if [[ $# -lt 2 ]]; then
      echo "Usage: validation-cache.sh get <type>"
      exit 1
    fi
    cmd_get "$2"
    ;;
  set)
    if [[ $# -lt 3 ]]; then
      echo "Usage: validation-cache.sh set <type> <result>"
      exit 1
    fi
    cmd_set "$2" "$3"
    ;;
  clear)
    cmd_clear
    ;;
  help|*)
    cat << EOF
validation-cache.sh: Cache validation results to speed up checks

Usage:
  validation-cache.sh check <type>        Check if cache is valid
  validation-cache.sh get <type>          Get cached results
  validation-cache.sh set <type> <result> Store results in cache
  validation-cache.sh clear               Clear all cache

Types:
  doctor  - Project structure validation (doctor.sh)
  specs   - Spec format validation (validate_specs.py)
  verify  - Comprehensive checks (verify.sh)

Cache invalidation:
  - Time: 5 minutes
  - Files: Automatically when relevant files change

Example:
  # In doctor.sh:
  if bash .agentic/tools/validation-cache.sh check doctor; then
    bash .agentic/tools/validation-cache.sh get doctor
    exit 0
  fi
  
  # Run actual validation
  result=\$(run_doctor_checks)
  
  # Cache result
  bash .agentic/tools/validation-cache.sh set doctor "\$result"
  echo "\$result"
EOF
    ;;
esac

