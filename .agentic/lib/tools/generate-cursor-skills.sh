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
EXT_SKILLS_DIR="$PROJECT_ROOT/.agentic/local/extensions/skills"
OUTPUT_DIR="${1:-$PROJECT_ROOT/.cursor/skills}"

if [[ ! -d "$CLAUDE_SKILLS_DIR" ]]; then
  echo "Error: Claude skills directory not found at $CLAUDE_SKILLS_DIR" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

# Translate a single skill source directory → Cursor skill output directory.
# Args: <source_dir> <skill_name>
_translate_skill() {
  local skill_dir="$1"
  local skill_name="$2"
  local skill_file="$skill_dir/SKILL.md"
  [[ -f "$skill_file" ]] || return 0

  local out_dir="$OUTPUT_DIR/$skill_name"
  mkdir -p "$out_dir"

  # Transform SKILL.md: compatibility string Claude Code → Cursor Agent mode
  sed \
    -e 's/compatibility: "Requires Claude Code/compatibility: "Requires Cursor Agent mode/' \
    -e 's/Requires Claude Code/Requires Cursor Agent mode/g' \
    "$skill_file" > "$out_dir/SKILL.md"

  # Copy supporting files (scripts, references) except SKILL.md and .source.json (internal)
  for f in "$skill_dir"/*; do
    [[ -f "$f" ]] || continue
    local fname
    fname=$(basename "$f")
    [[ "$fname" == "SKILL.md" ]] && continue
    [[ "$fname" == ".source.json" ]] && continue
    cp "$f" "$out_dir/"
  done
}

_count=0
# 1. Core skills shipped with the framework
for skill_dir in "$CLAUDE_SKILLS_DIR"/*/; do
  [[ -d "$skill_dir" ]] || continue
  _translate_skill "$skill_dir" "$(basename "$skill_dir")"
  _count=$((_count + 1))
done

# 2. User/marketplace skills from .agentic/local/extensions/skills/
#    Includes marketplace-* skills installed via `ag skills install` (F-008 AC-011)
if [[ -d "$EXT_SKILLS_DIR" ]]; then
  for skill_dir in "$EXT_SKILLS_DIR"/*/; do
    [[ -d "$skill_dir" ]] || continue
    _translate_skill "$skill_dir" "$(basename "$skill_dir")"
    _count=$((_count + 1))
  done
fi

echo "$_count skills generated in $OUTPUT_DIR"
