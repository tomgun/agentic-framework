#!/usr/bin/env bash
# List all active sequential agent pipelines

set -euo pipefail

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "▶ ACTIVE PIPELINES"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

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
  exit 0
fi

# Get pipeline directory
PIPELINE_DIR=$(grep -E "^- pipeline_coordination_file:" STACK.md | sed 's/.*: //' || echo "..agentic/pipeline")

if [[ ! -d "$PIPELINE_DIR" ]]; then
  echo "No pipelines created yet."
  echo ""
  echo "Pipeline directory: $PIPELINE_DIR (doesn't exist)"
  exit 0
fi

# Count pipelines
PIPELINE_COUNT=$(find "$PIPELINE_DIR" -name "*-pipeline.md" -type f | wc -l | tr -d ' ')

if [[ "$PIPELINE_COUNT" == "0" ]]; then
  echo "No active pipelines."
  echo ""
  echo "Pipeline directory: $PIPELINE_DIR (empty)"
  exit 0
fi

echo "Found $PIPELINE_COUNT active pipeline(s):"
echo ""

# List each pipeline with summary
find "$PIPELINE_DIR" -name "*-pipeline.md" -type f | while read -r file; do
  FEATURE=$(basename "$file" | sed 's/-pipeline.md//')
  
  # Extract key info
  CURRENT_AGENT=$(grep -E "^- Current agent:" "$file" | sed 's/.*: //' | head -1 || echo "Unknown")
  PHASE=$(grep -E "^- Phase:" "$file" | sed 's/.*: //' | head -1 || echo "Unknown")
  LAST_UPDATED=$(grep -E "^- Last updated:" "$file" | sed 's/.*: //' | head -1 || echo "Unknown")
  
  # Count completed agents
  COMPLETED_COUNT=$(grep -c "^- ✅" "$file" || echo "0")
  
  echo "┌─────────────────────────────────────────────────────────────────────"
  echo "│ Feature: $FEATURE"
  echo "│ Current: $CURRENT_AGENT"
  echo "│ Phase: $PHASE"
  echo "│ Completed: $COMPLETED_COUNT agents"
  echo "│ Last updated: $LAST_UPDATED"
  echo "│ File: $file"
  echo "└─────────────────────────────────────────────────────────────────────"
  echo ""
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "To view detailed status: bash .agentic/tools/pipeline_status.sh F-####"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

