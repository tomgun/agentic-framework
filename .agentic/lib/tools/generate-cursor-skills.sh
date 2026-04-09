#!/usr/bin/env bash
# generate-cursor-skills.sh: Adapt Claude skills for Cursor's .cursor/skills/ format
#
# Cursor supports the same SKILL.md open standard as Claude Code.
# This script copies Claude skill templates with minor adaptations:
#   - compatibility field updated for Cursor
#
# Usage:
#   bash .agentic/lib/tools/generate-cursor-skills.sh [--output-dir <dir>]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../paths.sh"

CLAUDE_SKILLS_DIR="$AGENTIC_LIB/agents/claude/skills"
OUTPUT_DIR="${1:-$PROJECT_ROOT/.cursor/skills}"

if [[ ! -d "$CLAUDE_SKILLS_DIR" ]]; then
  echo "Error: Claude skills directory not found at $CLAUDE_SKILLS_DIR" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

_count=0
for skill_dir in "$CLAUDE_SKILLS_DIR"/*/; do
  [[ -d "$skill_dir" ]] || continue
  skill_name=$(basename "$skill_dir")
  skill_file="$skill_dir/SKILL.md"
  [[ -f "$skill_file" ]] || continue

  # Create output directory
  out_dir="$OUTPUT_DIR/$skill_name"
  mkdir -p "$out_dir"

  # Transform SKILL.md
  # 1. Update compatibility line
  # 2. Map allowed-tools
  sed \
    -e 's/compatibility: "Requires Claude Code/compatibility: "Requires Cursor Agent mode/' \
    -e 's/Requires Claude Code/Requires Cursor Agent mode/g' \
    "$skill_file" > "$out_dir/SKILL.md"

  # Copy any supporting files (scripts, references) if they exist
  for f in "$skill_dir"/*; do
    [[ -f "$f" ]] || continue
    fname=$(basename "$f")
    [[ "$fname" == "SKILL.md" ]] && continue
    cp "$f" "$out_dir/"
  done

  _count=$((_count + 1))
done

echo "$_count skills generated in $OUTPUT_DIR"
