"""
export_adapters.py — Per-tool adapter configurations for ag export.

Each adapter defines:
- output_path: where the generated file goes (relative to project root)
- heading: file header/title
- marker_format: comment style for the regeneration marker
- sections: ordered list of section IDs to include
"""
from __future__ import annotations

from dataclasses import dataclass


@dataclass
class ToolAdapter:
    """Configuration for generating a tool-specific instruction file."""
    name: str
    output_path: str
    heading: str
    marker_format: str  # "html" for <!-- -->, "hash" for # comment
    sections: list[str]
    mcp_config_path: str | None = None  # path for MCP config if supported


# ---------------------------------------------------------------------------
# Adapter definitions
# ---------------------------------------------------------------------------

ADAPTERS: dict[str, ToolAdapter] = {
    "claude": ToolAdapter(
        name="claude",
        output_path="CLAUDE.md",
        heading="# Project Instructions",
        marker_format="html",
        sections=[
            "preamble",
            "session_start",
            "workflow_commands",
            "artifacts",
            "plan_mode_exit",
            "core_rules",
            "token_scripts",
            "conventions_ref",
            "project_settings",
        ],
        mcp_config_path=".claude/mcp.json",
    ),
    "cursor": ToolAdapter(
        name="cursor",
        output_path=".cursorrules",
        heading="",
        marker_format="html",
        sections=[
            "preamble",
            "workflow_commands",
            "artifacts",
            "trigger_words",
            "core_rules",
            "token_scripts",
            "conventions_ref",
            "project_settings",
        ],
        mcp_config_path=".cursor/mcp.json",
    ),
    "copilot": ToolAdapter(
        name="copilot",
        output_path=".github/copilot-instructions.md",
        heading="# Copilot Instructions",
        marker_format="html",
        sections=[
            "preamble",
            "workflow_commands",
            "artifacts",
            "trigger_words",
            "core_rules",
            "token_scripts",
            "conventions_ref",
            "project_settings",
        ],
    ),
    "codex": ToolAdapter(
        name="codex",
        output_path="AGENTS.md",
        heading="# Codex Instructions",
        marker_format="html",
        sections=[
            "preamble",
            "sandbox_note",
            "workflow_commands",
            "artifacts",
            "trigger_words",
            "core_rules",
            "token_scripts",
            "conventions_ref",
            "project_settings",
        ],
    ),
}


def get_adapter(tool: str) -> ToolAdapter | None:
    """Look up an adapter by tool name."""
    return ADAPTERS.get(tool)


def list_adapters() -> list[str]:
    """Return sorted list of supported tool names."""
    return sorted(ADAPTERS.keys())
