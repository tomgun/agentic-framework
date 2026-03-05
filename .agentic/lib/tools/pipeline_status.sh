#!/usr/bin/env bash
# Show status of sequential agent pipeline for a feature

set -euo pipefail

FEATURE=${1:-}

if [[ -z "$FEATURE" ]]; then
  echo "Usage: bash .agentic/tools/pipeline_status.sh F-####"
  echo ""
  echo "Shows the status of the sequential agent pipeline for a feature."
  echo ""
  echo "Examples:"
  echo "  bash .agentic/tools/pipeline_status.sh F-0042"
  echo "  bash .agentic/tools/pipeline_status.sh           # List all active pipelines"
  exit 1
fi

# Check if pipeline mode enabled
if [[ ! -f "STACK.md" ]]; then
  echo "❌ STACK.md not found. Are you in the project root?"
  exit 1
fi

PIPELINE_ENABLED=$(grep -E "^- pipeline_enabled:" STACK.md | sed 's/.*: //' || echo "no")

if [[ "$PIPELINE_ENABLED" != "yes" ]]; then
  echo "❌ Pipeline mode not enabled in STACK.md"
  echo ""
  echo "To enable:"
  echo "  1. Edit STACK.md"
  echo "  2. Set: pipeline_enabled: yes"
  echo "  3. Configure: pipeline_mode (manual/auto), pipeline_agents (minimal/standard/full)"
  exit 1
fi

# Get pipeline directory
PIPELINE_DIR=$(grep -E "^- pipeline_coordination_file:" STACK.md | sed 's/.*: //' || echo "..agentic/pipeline")

if [[ ! -d "$PIPELINE_DIR" ]]; then
  echo "❌ Pipeline directory not found: $PIPELINE_DIR"
  echo ""
  echo "No pipelines have been created yet."
  exit 1
fi

PIPELINE_FILE="$PIPELINE_DIR/${FEATURE}-pipeline.md"

if [[ ! -f "$PIPELINE_FILE" ]]; then
  echo "❌ No pipeline found for $FEATURE"
  echo ""
  echo "Available pipelines:"
  find "$PIPELINE_DIR" -name "*.md" -type f | while read -r file; do
    FEAT=$(basename "$file" | sed 's/-pipeline.md//')
    echo "  - $FEAT"
  done
  exit 1
fi

# Display pipeline status
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "▶ PIPELINE STATUS: $FEATURE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

cat "$PIPELINE_FILE"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Pipeline file: $PIPELINE_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

