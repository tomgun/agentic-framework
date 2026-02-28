#!/usr/bin/env bash
# DEPRECATED: Use `bash .agentic/tools/sync.sh` instead.
# Staleness checks are now consolidated in sync.sh Phase 2.
# This wrapper will be removed in a future version.

echo "⚠ stale.sh is deprecated — use 'ag sync' or 'bash .agentic/tools/sync.sh' instead."
echo "  Staleness checks are now part of sync.sh Phase 2."
echo "  The --days parameter is no longer supported; sync.sh uses a 15-commit threshold."
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "$SCRIPT_DIR/sync.sh" --check
