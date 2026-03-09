#!/usr/bin/env bash
# quick-scan.sh: DEPRECATED — replaced by dashboard.sh (v0.52.0)
#
# This script is kept for backward compatibility. It delegates to dashboard.sh.
# Remove in a future release.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$SCRIPT_DIR/../../../.." && pwd)}"
echo "⚠ quick-scan.sh is deprecated. Use .agentic/lib/tools/dashboard.sh instead." >&2
exec bash "$PROJECT_ROOT/.agentic/lib/tools/dashboard.sh" "$@"
