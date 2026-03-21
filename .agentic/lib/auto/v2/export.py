"""
export.py — Generate tool-specific instruction files from shared sections.

Composes instruction files for Claude, Cursor, Copilot, and Codex from
shared content sections + per-tool adapters + project settings.

Usage:
    ag export claude         # generate for one tool
    ag export all            # generate for all tools
    ag export --list         # show supported tools
    ag export --diff claude  # preview changes without writing
    ag export claude --mcp   # also generate MCP config
"""
from __future__ import annotations

import json
import os
import shutil
import sys
from pathlib import Path
from typing import Optional

from .export_sections import SECTIONS, ProjectSettings
from .export_adapters import ADAPTERS, ToolAdapter, get_adapter, list_adapters

# Marker format: embedded in generated files for safe regeneration
MARKER_VERSION = "v1"


def _make_marker(tool: str, fmt: str) -> str:
    """Create the regeneration marker comment."""
    content = f"ag-export: {tool} {MARKER_VERSION}"
    if fmt == "html":
        return f"<!-- {content} -->"
    return f"# {content}"


def _has_marker(path: Path, tool: str) -> bool:
    """Check if a file contains the ag-export marker."""
    if not path.exists():
        return False
    try:
        text = path.read_text()
        return f"ag-export: {tool}" in text
    except (OSError, UnicodeDecodeError):
        return False


def _read_project_settings(project_root: Path) -> ProjectSettings:
    """Extract project settings from config and STACK.md."""
    settings = ProjectSettings()

    # Try to load from v2 config
    try:
        from .config import load_config
        config = load_config(project_root)
        # Extract verification commands
        if config.verification_commands:
            settings.verification_commands = [
                cmd.run for cmd in config.verification_commands
            ]
    except (FileNotFoundError, Exception):
        pass

    # Read STACK.md for profile/mode/plan_review settings
    stack_path = project_root / "STACK.md"
    if stack_path.exists():
        try:
            text = stack_path.read_text()
            for line in text.split("\n"):
                stripped = line.strip()
                if stripped.startswith("- profile:"):
                    val = stripped.split(":", 1)[1].strip()
                    if val:
                        settings.profile = val
                elif stripped.startswith("- plan_review_enabled:"):
                    val = stripped.split(":", 1)[1].strip()
                    settings.plan_review_enabled = val.lower() in ("yes", "true")
        except (OSError, UnicodeDecodeError):
            pass

    # Detect mode from active work items or default
    try:
        from . import work_items
        items = work_items.list_items(project_root)
        active = [i for i in items if i.status not in ("shipped", "deprecated")]
        if active:
            settings.mode = active[0].mode
    except Exception:
        pass

    return settings


# ---------------------------------------------------------------------------
# Generator
# ---------------------------------------------------------------------------


class ExportGenerator:
    """Composes instruction files from sections + adapters + settings."""

    def __init__(self, project_root: Path):
        self.project_root = project_root
        self.settings = _read_project_settings(project_root)

    def generate(self, tool: str) -> str:
        """Generate the full content for a tool's instruction file."""
        adapter = get_adapter(tool)
        if not adapter:
            raise ValueError(f"Unknown tool: '{tool}'. Supported: {', '.join(list_adapters())}")

        parts: list[str] = []

        # Marker at top
        parts.append(_make_marker(tool, adapter.marker_format))
        parts.append("")

        # Heading
        if adapter.heading:
            parts.append(adapter.heading)
            parts.append("")

        # Sections
        for section_id in adapter.sections:
            fn = SECTIONS.get(section_id)
            if not fn:
                continue
            if section_id == "project_settings":
                content = fn(self.settings)
            else:
                content = fn()
            parts.append(content)
            parts.append("")

        return "\n".join(parts).rstrip() + "\n"

    def generate_diff(self, tool: str) -> str | None:
        """Compare generated content with existing file.

        Returns None if files match, otherwise returns a human-readable diff.
        """
        adapter = get_adapter(tool)
        if not adapter:
            raise ValueError(f"Unknown tool: '{tool}'")

        target = self.project_root / adapter.output_path
        new_content = self.generate(tool)

        if not target.exists():
            return f"[NEW] {adapter.output_path} would be created ({len(new_content)} bytes)"

        existing = target.read_text()
        if existing == new_content:
            return None

        # Simple line diff
        old_lines = existing.splitlines()
        new_lines = new_content.splitlines()

        changes: list[str] = []
        changes.append(f"[CHANGED] {adapter.output_path}:")

        # Show added/removed line counts
        added = len(new_lines) - len(old_lines)
        if added > 0:
            changes.append(f"  +{added} lines")
        elif added < 0:
            changes.append(f"  {added} lines")
        else:
            changes.append(f"  {len(new_lines)} lines (content differs)")

        return "\n".join(changes)

    def write(self, tool: str) -> tuple[str, bool]:
        """Write the generated file to disk.

        Returns (output_path, backed_up).
        """
        adapter = get_adapter(tool)
        if not adapter:
            raise ValueError(f"Unknown tool: '{tool}'")

        target = self.project_root / adapter.output_path
        content = self.generate(tool)
        backed_up = False

        # Ensure parent directory exists
        target.parent.mkdir(parents=True, exist_ok=True)

        # Safe regeneration: backup if exists without marker
        if target.exists() and not _has_marker(target, tool):
            backup = target.with_suffix(target.suffix + ".bak")
            shutil.copy2(str(target), str(backup))
            backed_up = True

        target.write_text(content)
        return (adapter.output_path, backed_up)

    def write_mcp_config(self, tool: str) -> str | None:
        """Generate MCP config JSON for tools that support it.

        Returns the output path, or None if tool doesn't support MCP.
        """
        adapter = get_adapter(tool)
        if not adapter or not adapter.mcp_config_path:
            return None

        config = {
            "mcpServers": {
                "agentic": {
                    "command": "python3",
                    "args": ["-m", "auto.v2.mcp_server"],
                    "cwd": ".agentic/lib",
                }
            }
        }

        target = self.project_root / adapter.mcp_config_path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(json.dumps(config, indent=2) + "\n")
        return adapter.mcp_config_path


# ---------------------------------------------------------------------------
# CLI command
# ---------------------------------------------------------------------------


def cmd_export(project_root: Path, args: list[str]) -> int:
    """CLI handler for `ag export`.

    Usage:
        ag export claude        Generate for one tool
        ag export all           Generate for all tools
        ag export --list        Show supported tools
        ag export --diff claude Preview changes without writing
        ag export claude --mcp  Also generate MCP config
    """
    if not args:
        print("Usage: ag export <tool|all> [--diff] [--list] [--mcp]")
        print(f"  Supported tools: {', '.join(list_adapters())}")
        return 0

    # Parse flags
    diff_mode = "--diff" in args
    show_list = "--list" in args
    with_mcp = "--mcp" in args
    tool_args = [a for a in args if not a.startswith("--")]

    if show_list:
        print("Supported tools:")
        for name in list_adapters():
            adapter = get_adapter(name)
            if adapter:
                print(f"  {name:10s} → {adapter.output_path}")
        return 0

    generator = ExportGenerator(project_root)

    # Determine which tools to process
    if not tool_args:
        if diff_mode:
            # --diff without tool means diff all
            tool_args = ["all"]
        else:
            print("Usage: ag export <tool|all> [--diff] [--list] [--mcp]")
            return 1

    if tool_args[0] == "all":
        tools = list_adapters()
    else:
        tools = tool_args[:1]

    # Validate tool names
    for tool in tools:
        if tool not in ADAPTERS:
            print(f"Unknown tool: '{tool}'. Supported: {', '.join(list_adapters())}", file=sys.stderr)
            return 1

    if diff_mode:
        any_diff = False
        for tool in tools:
            diff = generator.generate_diff(tool)
            if diff:
                print(diff)
                any_diff = True
            else:
                adapter = get_adapter(tool)
                if adapter:
                    print(f"[OK] {adapter.output_path} is up to date")
        return 0

    # Write mode
    for tool in tools:
        path, backed_up = generator.write(tool)
        status = " (backed up existing)" if backed_up else ""
        print(f"  {path}{status}")

        if with_mcp:
            mcp_path = generator.write_mcp_config(tool)
            if mcp_path:
                print(f"  {mcp_path} (MCP config)")

    print(f"\nGenerated {len(tools)} instruction file(s).")
    return 0
