#!/usr/bin/env bash
# quick-scan.sh: DEPRECATED — replaced by dashboard.sh (v0.52.0)
#
# This script is kept for backward compatibility. It delegates to dashboard.sh.
# Remove in a future release.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "⚠ quick-scan.sh is deprecated. Use dashboard.sh instead." >&2
exec bash "$SCRIPT_DIR/dashboard.sh" "$@"
