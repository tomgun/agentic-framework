"""
init.py -- Initialize autonomous workflow mode for a project.

Reads STACK.md to detect toolchain, generates a project-specific
settings.json for Tier 2 (scoped permissions).

Usage:
    python -m auto.init [--tier 1|2|3] [--project-root .]
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

_LIB_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(_LIB_DIR))
from paths import get_paths  # noqa: E402

# Base template
TEMPLATE_PATH = Path(__file__).resolve().parent / "settings-template.json"

# Package manager -> additional Bash patterns
PACKAGE_MANAGER_RULES: dict[str, list[str]] = {
    "npm": [
        "Bash(cd * && npm test *)",
        "Bash(cd * && npm run *)",
        "Bash(cd * && npx *)",
    ],
    "pnpm": [
        "Bash(cd * && pnpm *)",
        "Bash(cd * && pnpm test *)",
        "Bash(cd * && pnpm run *)",
    ],
    "yarn": [
        "Bash(cd * && yarn *)",
        "Bash(cd * && yarn test *)",
        "Bash(cd * && yarn run *)",
    ],
    "bun": [
        "Bash(cd * && bun *)",
        "Bash(cd * && bun test *)",
        "Bash(cd * && bun run *)",
    ],
    "pip": [
        "Bash(cd * && python *)",
        "Bash(cd * && pip *)",
        "Bash(cd * && pytest *)",
    ],
    "poetry": [
        "Bash(cd * && python *)",
        "Bash(cd * && poetry *)",
        "Bash(cd * && pytest *)",
    ],
    "cargo": [
        "Bash(cd * && cargo *)",
    ],
    "go": [
        "Bash(cd * && go *)",
    ],
    "make": [
        "Bash(cd * && make *)",
    ],
}

# Language -> additional patterns
LANGUAGE_RULES: dict[str, list[str]] = {
    "python": [
        "Bash(cd * && python *)",
        "Bash(cd * && pytest *)",
        "Bash(cd * && ruff *)",
    ],
    "typescript": [
        "Bash(cd * && tsc *)",
        "Bash(cd * && tsx *)",
    ],
    "javascript": [],
    "rust": [
        "Bash(cd * && cargo *)",
    ],
    "go": [
        "Bash(cd * && go *)",
    ],
    "bash": [
        "Bash(cd * && bash *)",
        "Bash(cd * && shellcheck *)",
    ],
}


def detect_stack(project_root: Path) -> dict:
    """Read STACK.md and extract package manager and languages."""
    paths = get_paths(project_root)
    stack_file = paths.stack_file
    result = {"package_manager": None, "languages": [], "test_runner": None}

    if not stack_file.exists():
        return result

    content = stack_file.read_text()

    # Package manager
    pm_match = re.search(r"Package manager:\s*(.+)", content, re.IGNORECASE)
    if pm_match:
        pm = pm_match.group(1).strip().lower().split(",")[0].split("(")[0].strip()
        if pm and pm != "n/a":
            result["package_manager"] = pm

    # Languages
    lang_match = re.search(r"Language\(s\):\s*(.+)", content, re.IGNORECASE)
    if lang_match:
        langs = [l.strip().lower() for l in lang_match.group(1).split(",")]
        result["languages"] = [l for l in langs if l]

    # Test runner
    test_match = re.search(r"Test runner:\s*(.+)", content, re.IGNORECASE)
    if test_match:
        result["test_runner"] = test_match.group(1).strip().lower()

    return result


def generate_settings(
    project_root: Path, tier: int = 2
) -> dict:
    """Generate a project-specific settings.json.

    Args:
        project_root: Project root directory
        tier: 1 (sandboxed), 2 (scoped), or 3 (interactive)

    Returns:
        Settings dict ready to write as JSON.
    """
    if tier == 1:
        # Tier 1: Docker sandbox -- skip permissions entirely
        return {
            "_comment": "Tier 1: Sandboxed. Use --dangerously-skip-permissions inside Docker.",
            "permissions": {"allow": ["*"], "deny": []},
        }

    if tier == 3:
        # Tier 3: Interactive -- no special settings needed
        return {
            "_comment": "Tier 3: Interactive. Normal approval prompts.",
            "permissions": {"allow": [], "deny": []},
        }

    # Tier 2: Scoped permissions
    template = json.loads(TEMPLATE_PATH.read_text())
    allow_set = set(template["permissions"]["allow"])
    deny_set = set(template["permissions"]["deny"])

    stack = detect_stack(project_root)

    # Add package manager rules
    pm = stack.get("package_manager")
    if pm and pm in PACKAGE_MANAGER_RULES:
        allow_set.update(PACKAGE_MANAGER_RULES[pm])

    # Add language rules
    for lang in stack.get("languages", []):
        if lang in LANGUAGE_RULES:
            allow_set.update(LANGUAGE_RULES[lang])

    return {
        "_comment": f"Tier 2: Scoped permissions. Generated from STACK.md (pm={pm}).",
        "_tier": 2,
        "permissions": {
            "allow": sorted(allow_set),
            "deny": sorted(deny_set),
        },
    }


def ensure_hooks(project_root: Path) -> bool:
    """Ensure Claude Code hooks are installed at .claude/hooks.json.

    Copies the canonical hooks.json from .agentic/lib/claude-hooks/ if
    .claude/hooks.json doesn't already exist.

    Returns True if hooks were installed (or already present).
    """
    hooks_source = project_root / ".agentic" / "lib" / "claude-hooks" / "hooks.json"
    hooks_target = project_root / ".claude" / "hooks.json"

    if hooks_target.exists():
        return True

    if not hooks_source.exists():
        return False

    hooks_target.parent.mkdir(exist_ok=True)
    import shutil
    shutil.copy2(str(hooks_source), str(hooks_target))
    return True


def write_settings(project_root: Path, tier: int = 2) -> Path:
    """Generate and write settings.json to .claude/settings.json.

    Also ensures Claude Code hooks are installed alongside permissions.

    Returns the path to the written file.
    """
    settings = generate_settings(project_root, tier)
    output_dir = project_root / ".claude"
    output_dir.mkdir(exist_ok=True)
    output_path = output_dir / "settings.json"
    output_path.write_text(json.dumps(settings, indent=2) + "\n")

    # Ensure hooks are installed alongside settings (F-0300 R0)
    ensure_hooks(project_root)

    return output_path


def hooks_status(project_root: Path) -> dict:
    """Check Claude Code hook installation status.

    Returns dict with hook status information.
    """
    hooks_source = project_root / ".agentic" / "lib" / "claude-hooks" / "hooks.json"
    hooks_target = project_root / ".claude" / "hooks.json"

    result = {
        "source_exists": hooks_source.exists(),
        "installed": hooks_target.exists(),
        "hooks": {},
    }

    if hooks_target.exists():
        try:
            data = json.loads(hooks_target.read_text())
            for event, entries in data.get("hooks", {}).items():
                for entry in entries:
                    for hook in entry.get("hooks", []):
                        cmd = hook.get("command", "")
                        # Check if the script exists
                        cmd_resolved = cmd.replace(
                            "${CLAUDE_PROJECT_DIR}", str(project_root)
                        )
                        script_exists = Path(cmd_resolved).exists()
                        result["hooks"][event] = {
                            "registered": True,
                            "script_exists": script_exists,
                            "command": cmd,
                        }
        except (json.JSONDecodeError, KeyError):
            result["parse_error"] = True

    return result


def main() -> int:
    """CLI entry point."""
    import argparse

    parser = argparse.ArgumentParser(description="Initialize auto mode settings")
    parser.add_argument(
        "--tier",
        type=int,
        choices=[1, 2, 3],
        default=2,
        help="Trust tier (1=sandboxed, 2=scoped, 3=interactive)",
    )
    parser.add_argument(
        "--project-root",
        type=Path,
        default=Path.cwd(),
        help="Project root directory",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print settings without writing",
    )
    parser.add_argument(
        "--hooks-status",
        action="store_true",
        help="Check hook installation status",
    )
    args = parser.parse_args()

    if args.hooks_status:
        status = hooks_status(args.project_root)
        if not status["source_exists"]:
            print("✗ Hook source not found (.agentic/lib/claude-hooks/hooks.json)")
            return 1
        if not status["installed"]:
            print("✗ Hooks NOT installed (.claude/hooks.json missing)")
            print("  Fix: run `ag auto init` or `bash .agentic/lib/tools/setup-agent.sh claude`")
            return 1
        print("✓ Hooks installed (.claude/hooks.json)")
        for event, info in sorted(status["hooks"].items()):
            marker = "✓" if info["script_exists"] else "✗"
            print(f"  {marker} {event}: {info['command']}")
        return 0

    settings = generate_settings(args.project_root, args.tier)

    if args.dry_run:
        print(json.dumps(settings, indent=2))
        return 0

    path = write_settings(args.project_root, args.tier)
    tier_names = {1: "Sandboxed", 2: "Scoped", 3: "Interactive"}
    print(f"Tier {args.tier} ({tier_names[args.tier]}) settings written to: {path}")
    print("\n⚠ Hooks and permissions take effect on next Claude session start.")
    print("  Restart Claude Code to activate enforcement hooks.")

    if args.tier == 1:
        print("\nFor Tier 1, run Claude inside Docker:")
        print("  docker run ... claude --dangerously-skip-permissions")
    elif args.tier == 2:
        print("\nFor Tier 2, start Claude with:")
        print(f"  claude --settings {path}")
    else:
        print("\nFor Tier 3, just run Claude normally (approval prompts active).")

    return 0


if __name__ == "__main__":
    sys.exit(main())
