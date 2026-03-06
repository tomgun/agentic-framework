#!/usr/bin/env bash
set -euo pipefail

echo "=== agentic start ==="
echo

bash .agentic/init/scaffold.sh
echo

echo "Next: run the init planning session:"
echo "- Open your agent and point it to: .agentic/init/init_playbook.md"
echo

echo "Optional (scaffold system docs):"
echo "- bash .agentic/tools/sync_docs.sh"
echo

echo "Optional (sanity checks):"
echo "- bash .agentic/tools/doctor.sh"
echo "- bash .agentic/tools/report.sh"


