#!/usr/bin/env python3
"""
quality_profile_generator.py — Generate quality_checks.sh + conventions from stack knowledge.

Reads YAML knowledge files from .agentic/lib/quality_knowledge/, matches against
the project's STACK.md, and generates:
  1. quality_checks.sh (project root) — stack-specific checks with --pre-commit and --full modes
  2. conventions-stack.md (.agentic/local/) — stack-specific coding conventions
  3. quality-gate.sh (.agentic/local/extensions/gates/) — pre-commit gate wrapper

Usage:
    python3 quality_profile_generator.py --root /path/to/project [--dry-run]

Falls back to copying best-matching quality_profiles/*.sh when PyYAML is not available.
"""
from __future__ import annotations

import argparse
import os
import re
import shutil
import stat
import sys
from pathlib import Path
from textwrap import dedent
from typing import Any, Optional

# Framework library path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

# Optional YAML support — graceful fallback
try:
    import yaml
    HAS_YAML = True
except ImportError:
    HAS_YAML = False


# ---------------------------------------------------------------------------
# STACK.md parsing
# ---------------------------------------------------------------------------

_STACK_FIELD_RE = re.compile(
    r"^\s*-\s*\*\*(?P<key>[^*]+)\*\*:\s*(?P<value>.+)",
    re.IGNORECASE,
)

_SETTING_RE = re.compile(
    r"^\s*-\s*(?P<key>[a-z_][a-z0-9_]*):\s*(?P<value>[^#\n<]+)",
    re.IGNORECASE,
)


def parse_stack_md(root: Path) -> dict[str, str]:
    """Extract tech stack fields and settings from STACK.md."""
    stack_path = root / "STACK.md"
    if not stack_path.exists():
        # Try .agentic/STACK.md
        stack_path = root / ".agentic" / "STACK.md"
    if not stack_path.exists():
        return {}

    result: dict[str, str] = {}
    text = stack_path.read_text(encoding="utf-8", errors="replace")

    for line in text.splitlines():
        m = _STACK_FIELD_RE.match(line)
        if m:
            key = m.group("key").strip().lower().replace(" ", "_")
            val = m.group("value").strip()
            # Strip markdown formatting
            val = re.sub(r"[`*]", "", val)
            result[key] = val
            continue
        m = _SETTING_RE.match(line)
        if m:
            result[f"setting_{m.group('key').strip()}"] = m.group("value").strip()

    return result


# ---------------------------------------------------------------------------
# Knowledge file matching
# ---------------------------------------------------------------------------

def get_knowledge_dir() -> Path:
    """Return path to quality_knowledge/ directory."""
    return Path(__file__).resolve().parent.parent / "quality_knowledge"


def get_quality_profiles_dir() -> Path:
    """Return path to legacy quality_profiles/ directory."""
    return Path(__file__).resolve().parent.parent / "quality_profiles"


def match_knowledge_files(stack_info: dict[str, str]) -> list[tuple[int, str, Path]]:
    """
    Match STACK.md info against knowledge YAML files.
    Returns list of (score, stack_id, path) sorted by score descending.
    """
    knowledge_dir = get_knowledge_dir()
    if not knowledge_dir.exists():
        return []

    if not HAS_YAML:
        return []

    matches: list[tuple[int, str, Path]] = []
    # Exclude internal keys (prefixed with _) from matching text
    stack_text = " ".join(v for k, v in stack_info.items() if not k.startswith("_")).lower()

    for yf in sorted(knowledge_dir.glob("*.yaml")):
        if yf.name.startswith("_"):
            continue

        try:
            data = yaml.safe_load(yf.read_text(encoding="utf-8"))
        except Exception:
            continue

        if not isinstance(data, dict) or "matches" not in data:
            continue

        score = 0
        has_specific_match = False  # Framework or config file match
        match_spec = data["matches"]

        # Framework matching (highest weight)
        for fw in match_spec.get("frameworks", []):
            if fw.lower() in stack_text:
                score += 10
                has_specific_match = True

        # Language matching (only contributes if there's also a specific match)
        for lang in match_spec.get("languages", []):
            if lang.lower() in stack_text:
                score += 5

        # Config file matching (check if files exist in project)
        for cf in match_spec.get("config_files", []):
            # Support glob patterns
            if "*" in cf:
                if list(Path(stack_info.get("_root", ".")).glob(cf)):
                    score += 8
                    has_specific_match = True
            else:
                if (Path(stack_info.get("_root", ".")) / cf).exists():
                    score += 8
                    has_specific_match = True

        # Marker matching (grep source for markers)
        for marker in match_spec.get("markers", []):
            if marker.lower() in stack_text:
                score += 3
                has_specific_match = True

        # Only include if we have a specific match (framework, config, or marker)
        # Language-only matches are too broad (TypeScript matches everything)
        if score > 0 and has_specific_match:
            matches.append((score, data.get("stack_id", yf.stem), yf))

    return sorted(matches, key=lambda x: x[0], reverse=True)


# ---------------------------------------------------------------------------
# Legacy fallback: copy quality_profiles/*.sh
# ---------------------------------------------------------------------------

_LEGACY_PROFILE_MAP: dict[str, str] = {
    "juce": "juce_audio_plugin.sh",
    "vst3": "raw_vst3_plugin.sh",
    "vst": "raw_vst3_plugin.sh",
    "audio": "juce_audio_plugin.sh",
    "phaser": "game_2d_web.sh",
    "pixijs": "game_2d_web.sh",
    "pixi": "game_2d_web.sh",
    "unity": "game_unity.sh",
    "react native": "game_2d_mobile.sh",
    "expo": "game_2d_mobile.sh",
    "next.js": "webapp_with_e2e.sh",
    "nuxt": "webapp_with_e2e.sh",
    "react": "webapp_with_e2e.sh",
    "vue": "webapp_with_e2e.sh",
    "svelte": "webapp_with_e2e.sh",
}


def fallback_legacy_profile(stack_info: dict[str, str], root: Path) -> Optional[Path]:
    """Find best matching legacy quality profile when PyYAML is unavailable."""
    profiles_dir = get_quality_profiles_dir()
    if not profiles_dir.exists():
        return None

    # Exclude internal keys (prefixed with _) from matching text
    stack_text = " ".join(v for k, v in stack_info.items() if not k.startswith("_")).lower()
    for keyword, filename in _LEGACY_PROFILE_MAP.items():
        if keyword in stack_text:
            profile = profiles_dir / filename
            if profile.exists():
                return profile
    return None


# ---------------------------------------------------------------------------
# Shell script generation from YAML knowledge
# ---------------------------------------------------------------------------

def generate_quality_checks_sh(
    knowledge_files: list[tuple[dict, Path]],
    root: Path,
) -> str:
    """Generate quality_checks.sh content from matched knowledge files."""
    sections: list[str] = []
    stack_names: list[str] = []

    for data, _path in knowledge_files:
        stack_names.append(data.get("display_name", data.get("stack_id", "Unknown")))

    header = dedent(f"""\
        #!/usr/bin/env bash
        # Auto-generated quality profile: {' + '.join(stack_names)}
        # Generated by: ag quality setup
        # Customize thresholds as needed — this file is yours to edit.
        set -euo pipefail

        MODE="${{1:---pre-commit}}"
        ERRORS=0
        WARNINGS=0

        echo "=== Quality Validation ==="
        echo "Profile: {' + '.join(stack_names)}"
        echo "Mode: ${{MODE}}"
        echo
    """)
    sections.append(header)

    for data, _path in knowledge_files:
        stack_id = data.get("stack_id", "unknown")
        display = data.get("display_name", stack_id)
        checks = data.get("quality_checks", {})

        pre_commit_checks = checks.get("pre_commit", [])
        full_checks = checks.get("full", [])

        section = f'\n# --- {display} ---\n'
        section += f'echo "--- {display} ---"\n'

        # Pre-commit checks (always run)
        for i, check in enumerate(pre_commit_checks, 1):
            name = check.get("name", f"Check {i}")
            command = check.get("command", "true")
            required = check.get("required", True)
            condition = check.get("condition", "")

            if condition:
                section += f'\nif {condition}; then\n'
                indent = "  "
            else:
                section += "\n"
                indent = ""

            section += f'{indent}echo "{i}. {name}..."\n'
            # Pipe command through tail only if it doesn't already have one
            run_cmd = command if "| tail" in command else f'{command} 2>&1 | tail -n 20'
            section += f'{indent}if {run_cmd}; then\n'
            section += f'{indent}  echo "  ✅ {name} passed"\n'
            section += f'{indent}else\n'

            if required:
                section += f'{indent}  echo "  ❌ {name} FAILED"\n'
                section += f'{indent}  ERRORS=$((ERRORS + 1))\n'
            else:
                section += f'{indent}  echo "  ⚠️  {name} failed (non-blocking)"\n'
                section += f'{indent}  WARNINGS=$((WARNINGS + 1))\n'

            section += f'{indent}fi\n'

            if condition:
                section += "fi\n"

        # Full-only checks
        if full_checks:
            section += '\nif [[ "$MODE" == "--full" ]]; then\n'
            for i, check in enumerate(full_checks, len(pre_commit_checks) + 1):
                name = check.get("name", f"Check {i}")
                command = check.get("command", "true")
                required = check.get("required", True)
                condition = check.get("condition", "")

                if condition:
                    section += f'  if {condition}; then\n'
                    indent = "    "
                else:
                    indent = "  "

                run_cmd = command if "| tail" in command else f'{command} 2>&1 | tail -n 20'
                section += f'{indent}echo "{i}. {name}..."\n'
                section += f'{indent}if {run_cmd}; then\n'
                section += f'{indent}  echo "  ✅ {name} passed"\n'
                section += f'{indent}else\n'

                if required:
                    section += f'{indent}  echo "  ❌ {name} FAILED"\n'
                    section += f'{indent}  ERRORS=$((ERRORS + 1))\n'
                else:
                    section += f'{indent}  echo "  ⚠️  {name} failed (non-blocking)"\n'
                    section += f'{indent}  WARNINGS=$((WARNINGS + 1))\n'

                section += f'{indent}fi\n'

                if condition:
                    section += '  fi\n'

            section += 'fi\n'

        section += 'echo\n'
        sections.append(section)

    # Footer
    footer = dedent("""\
        # === Summary ===
        echo "=========================================="
        if [[ $ERRORS -eq 0 ]]; then
          if [[ $WARNINGS -gt 0 ]]; then
            echo "✅ All critical checks passed ($WARNINGS warning(s))"
          else
            echo "✅ All quality checks passed!"
          fi
          exit 0
        else
          echo "❌ $ERRORS critical check(s) failed ($WARNINGS warning(s))"
          exit 1
        fi
    """)
    sections.append(footer)

    return "".join(sections)


def generate_conventions_stack_md(
    knowledge_files: list[tuple[dict, Path]],
) -> str:
    """Generate conventions-stack.md from matched knowledge files."""
    lines: list[str] = [
        "# Stack-Specific Conventions",
        "",
        "Auto-generated from quality knowledge files. Supplements `conventions.md`.",
        "Edit freely — this file is yours. Regenerate with `ag quality setup`.",
        "",
    ]

    for data, kf_path in knowledge_files:
        display = data.get("display_name", data.get("stack_id", "Unknown"))
        stack_id = data.get("stack_id", "unknown")
        lines.append(f"## {display}")
        lines.append("")

        # Conventions
        conventions = data.get("conventions", [])
        if conventions:
            lines.append("### Coding Rules")
            lines.append("")
            for conv in conventions:
                lines.append(f"- {conv}")
            lines.append("")

        # Security
        security = data.get("security", [])
        if security:
            lines.append("### Security")
            lines.append("")
            for sec in security:
                lines.append(f"- {sec}")
            lines.append("")

        # Performance
        performance = data.get("performance", [])
        if performance:
            lines.append("### Performance")
            lines.append("")
            for perf in performance:
                lines.append(f"- {perf}")
            lines.append("")

        # Library selection
        lib_sel = data.get("library_selection", [])
        if lib_sel:
            lines.append("### Library Selection")
            lines.append("")
            lines.append("| Category | Prefer | Avoid | Reason |")
            lines.append("|----------|--------|-------|--------|")
            for entry in lib_sel:
                cat = entry.get("category", "")
                prefer = entry.get("prefer", "")
                avoid = entry.get("avoid", "")
                reason = entry.get("reason", "")
                lines.append(f"| {cat} | {prefer} | {avoid} | {reason} |")
            lines.append("")

        # Testing strategy
        testing = data.get("testing_strategy", {})
        if testing:
            lines.append("### Testing Strategy")
            lines.append("")
            for level in ["unit", "integration", "e2e"]:
                ts = testing.get(level, {})
                if ts:
                    fw = ts.get("framework", "")
                    focus = ts.get("focus", "")
                    cmd = ts.get("command", "")
                    lines.append(f"- **{level.title()}**: {fw} — {focus}")
                    if cmd:
                        lines.append(f"  - Command: `{cmd}`")
            lines.append("")

        # Deep knowledge reference
        knowledge_md = kf_path.with_suffix("").with_suffix(".knowledge.md")
        if knowledge_md.exists():
            lines.append(f"### Deep Knowledge")
            lines.append(f"")
            lines.append(f"See: `{knowledge_md}` for detailed domain expertise")
            lines.append(f"(library selection rationale, anti-patterns, testing templates)")
            lines.append("")

    return "\n".join(lines)


def generate_quality_gate_sh(root: Path, timeout: int = 60) -> str:
    """Generate the pre-commit gate wrapper for extensions/gates/."""
    return dedent(f"""\
        #!/usr/bin/env bash
        # AUTO-GENERATED by quality profile generator — regenerate with: ag quality setup
        # Runs stack-specific quality checks on pre-commit (Check 17 of pre-commit-check.sh)
        set -euo pipefail

        QUALITY_SCRIPT="$(git rev-parse --show-toplevel 2>/dev/null || echo ".")/quality_checks.sh"

        if [[ ! -f "$QUALITY_SCRIPT" ]]; then
          exit 0  # No quality script — pass silently
        fi

        # Timeout prevents slow checks from blocking commits indefinitely
        if command -v timeout &>/dev/null; then
          timeout {timeout} bash "$QUALITY_SCRIPT" --pre-commit
        else
          bash "$QUALITY_SCRIPT" --pre-commit
        fi
    """)


# ---------------------------------------------------------------------------
# Main generation orchestration
# ---------------------------------------------------------------------------

def generate(
    root: Path,
    dry_run: bool = False,
    force: bool = False,
) -> dict[str, str]:
    """
    Main entry point. Generates quality profile artifacts for a project.

    Returns dict of {filepath: content} for all generated files.
    """
    root = root.resolve()
    stack_info = parse_stack_md(root)
    stack_info["_root"] = str(root)

    outputs: dict[str, str] = {}

    # Try YAML knowledge files first
    if HAS_YAML:
        matched = match_knowledge_files(stack_info)
        if matched:
            # Load full YAML data for matched files
            knowledge_files: list[tuple[dict, Path]] = []
            for _score, _stack_id, kf_path in matched:
                try:
                    data = yaml.safe_load(kf_path.read_text(encoding="utf-8"))
                    knowledge_files.append((data, kf_path))
                except Exception:
                    continue

            if knowledge_files:
                # Generate quality_checks.sh
                qc_content = generate_quality_checks_sh(knowledge_files, root)
                qc_path = root / "quality_checks.sh"

                # Backward compatibility: don't overwrite existing user-customized file
                if qc_path.exists() and not force:
                    alt_path = root / "quality_checks.sh.generated"
                    outputs[str(alt_path)] = qc_content
                    print(f"  ⚠️  quality_checks.sh already exists")
                    print(f"     Generated version written to: quality_checks.sh.generated")
                    print(f"     Compare and merge manually, or use --force to overwrite")
                else:
                    outputs[str(qc_path)] = qc_content

                # Generate conventions-stack.md
                conv_path = root / ".agentic" / "local" / "conventions-stack.md"
                outputs[str(conv_path)] = generate_conventions_stack_md(knowledge_files)

                # Generate quality-gate.sh
                timeout_setting = stack_info.get("setting_quality_checks_timeout", "60")
                try:
                    timeout_val = int(timeout_setting)
                except ValueError:
                    timeout_val = 60
                gate_path = root / ".agentic" / "local" / "extensions" / "gates" / "quality-gate.sh"
                outputs[str(gate_path)] = generate_quality_gate_sh(root, timeout_val)

                # Report
                names = [d.get("display_name", d.get("stack_id", "?")) for d, _ in knowledge_files]
                print(f"  Matched stacks: {', '.join(names)}")

                if dry_run:
                    print(f"\n  [DRY RUN] Would generate:")
                    for path in outputs:
                        print(f"    - {os.path.relpath(path, root)}")
                    return outputs

                # Write outputs
                for path, content in outputs.items():
                    p = Path(path)
                    p.parent.mkdir(parents=True, exist_ok=True)
                    p.write_text(content, encoding="utf-8")
                    # Make shell scripts executable
                    if path.endswith(".sh"):
                        p.chmod(p.stat().st_mode | stat.S_IEXEC | stat.S_IXGRP | stat.S_IXOTH)
                    print(f"  ✓ Generated: {os.path.relpath(path, root)}")

                return outputs

    # Fallback: copy legacy quality_profiles/*.sh
    legacy = fallback_legacy_profile(stack_info, root)
    if legacy:
        qc_path = root / "quality_checks.sh"
        if qc_path.exists() and not force:
            print(f"  ⚠️  quality_checks.sh already exists (skipping legacy copy)")
        elif dry_run:
            print(f"  [DRY RUN] Would copy legacy profile: {legacy.name}")
        else:
            shutil.copy2(legacy, qc_path)
            qc_path.chmod(qc_path.stat().st_mode | stat.S_IEXEC)
            print(f"  ✓ Copied legacy profile: {legacy.name} → quality_checks.sh")
            if not HAS_YAML:
                print(f"  ℹ️  Install PyYAML for full knowledge-based generation: pip3 install pyyaml")
        outputs[str(qc_path)] = legacy.read_text(encoding="utf-8")
        return outputs

    print("  ℹ️  No matching quality profile found for this stack")
    print("     Add stack info to STACK.md and run: ag quality setup")
    return outputs


def show_status(root: Path) -> None:
    """Show quality profile status for a project."""
    root = root.resolve()
    stack_info = parse_stack_md(root)
    stack_info["_root"] = str(root)

    print("=== Quality Profile Status ===")
    print()

    # Check quality_checks.sh
    qc = root / "quality_checks.sh"
    if qc.exists():
        print(f"  quality_checks.sh: ✅ exists ({qc.stat().st_size} bytes)")
    else:
        print(f"  quality_checks.sh: ❌ not found")

    # Check conventions-stack.md
    conv = root / ".agentic" / "local" / "conventions-stack.md"
    if conv.exists():
        print(f"  conventions-stack.md: ✅ exists")
    else:
        print(f"  conventions-stack.md: ❌ not found")

    # Check quality-gate.sh
    gate = root / ".agentic" / "local" / "extensions" / "gates" / "quality-gate.sh"
    if gate.exists():
        print(f"  quality-gate.sh: ✅ wired into pre-commit")
    else:
        print(f"  quality-gate.sh: ❌ not wired into pre-commit")

    # Show matched stacks
    if HAS_YAML:
        matched = match_knowledge_files(stack_info)
        if matched:
            print()
            print(f"  Detected stacks:")
            for score, stack_id, kf_path in matched:
                print(f"    - {stack_id} (confidence: {score})")
        else:
            print()
            print(f"  No matching stacks detected from STACK.md")
    else:
        print()
        print(f"  ℹ️  PyYAML not installed — install for knowledge-based detection")

    # Show quality_checks setting
    setting = stack_info.get("setting_quality_checks", "blocking")
    print()
    print(f"  Enforcement: {setting}")


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(
        description="Generate stack-specific quality profile from knowledge files"
    )
    parser.add_argument(
        "--root", type=Path, default=Path("."),
        help="Project root directory (default: current directory)"
    )
    parser.add_argument(
        "--dry-run", action="store_true",
        help="Show what would be generated without writing files"
    )
    parser.add_argument(
        "--force", action="store_true",
        help="Overwrite existing quality_checks.sh"
    )
    parser.add_argument(
        "--status", action="store_true",
        help="Show quality profile status"
    )
    args = parser.parse_args()

    if args.status:
        show_status(args.root)
    else:
        generate(args.root, dry_run=args.dry_run, force=args.force)


if __name__ == "__main__":
    main()
