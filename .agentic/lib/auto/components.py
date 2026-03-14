"""
components.py -- Component registry for multi-component projects.

Parses an optional `## Components` table from STACK.md and provides
component-scoped context filtering, test commands, and validation.

@feature F-0179, F-0187

Usage:
    from auto.components import load_registry
    registry = load_registry(Path("/project"))
    api = registry.get("api")
    if api:
        print(api.test_command)
"""
from __future__ import annotations

import re
import sys
import warnings
from dataclasses import dataclass
from pathlib import Path


# ---------------------------------------------------------------------------
# Data model
# ---------------------------------------------------------------------------

@dataclass
class Component:
    """A project component (e.g., api, web, mobile)."""
    name: str
    path: str        # Relative path from project root
    type: str        # e.g., "python", "typescript", "rust", "go"
    test_command: str  # e.g., "pytest packages/api/tests/"
    repo: str | None = None  # Git URL for cross-repo components (F-0187)


@dataclass
class ComponentRegistry:
    """Registry of project components parsed from STACK.md."""
    components: dict[str, Component]
    project_root: Path

    def get(self, name: str) -> Component | None:
        """Get a component by name."""
        return self.components.get(name)

    def list_all(self) -> list[Component]:
        """List all registered components."""
        return list(self.components.values())

    def get_for_path(self, file_path: str) -> Component | None:
        """Reverse lookup: find which component owns a file path."""
        # Normalize to forward slashes for comparison
        normalized = file_path.replace("\\", "/")
        best_match: Component | None = None
        best_len = 0
        for comp in self.components.values():
            comp_path = comp.path.replace("\\", "/").rstrip("/") + "/"
            if normalized.startswith(comp_path) and len(comp_path) > best_len:
                best_match = comp
                best_len = len(comp_path)
        return best_match

    def validate(self) -> list[str]:
        """Validate that component paths exist on disk. Returns error strings.

        Components with ``repo`` set are skipped — their paths may be outside
        the project root and should be validated via ``resolve_umbrella`` instead.
        """
        errors: list[str] = []
        for comp in self.components.values():
            if comp.repo:
                continue  # Cross-repo components validated by umbrella
            full_path = self.project_root / comp.path
            if not full_path.is_dir():
                errors.append(
                    f"Component '{comp.name}': path '{comp.path}' "
                    f"does not exist at {full_path}"
                )
        return errors

    # -- F-0187: Multi-repo helpers ----------------------------------------

    def is_multi_repo(self) -> bool:
        """Return True if any component has a repo URL set."""
        return any(c.repo for c in self.components.values())

    def get_external_components(self) -> list[Component]:
        """Return components with a repo URL (cross-repo)."""
        return [c for c in self.components.values() if c.repo]

    def get_local_components(self) -> list[Component]:
        """Return components without a repo URL (local/monorepo)."""
        return [c for c in self.components.values() if not c.repo]


# ---------------------------------------------------------------------------
# Shared markdown table parser (F-0187)
# ---------------------------------------------------------------------------

def parse_markdown_table(
    content: str,
    section_name: str,
) -> tuple[list[str], list[list[str]]]:
    """Parse a markdown table from a named ``## Section`` in markdown content.

    Returns ``(column_names, rows)`` where column_names are lowercased header
    strings and each row is a list of stripped cell strings.  Returns
    ``([], [])`` if the section is not found or the table is empty.
    """
    # Find the ## <section_name> section (match with optional trailing text)
    section_re = re.compile(
        rf"^##\s+{re.escape(section_name)}\b", re.MULTILINE,
    )
    match = section_re.search(content)
    if not match:
        return [], []

    # Extract section content (until next ## header or end of file)
    section_start = match.end()
    next_header = re.search(r"^##\s+", content[section_start:], re.MULTILINE)
    section_text = (
        content[section_start:section_start + next_header.start()]
        if next_header
        else content[section_start:]
    )

    column_names: list[str] = []
    rows: list[list[str]] = []
    header_found = False
    separator_found = False

    for line in section_text.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("<!--"):
            continue
        if not stripped.startswith("|"):
            continue

        if not header_found:
            # Parse header row to get column names
            column_names = [
                c.strip().lower()
                for c in stripped.strip("|").split("|")
            ]
            header_found = True
            continue

        if not separator_found:
            if re.match(r"^\|[\s\-:|]+\|$", stripped):
                separator_found = True
                continue
            separator_found = True

        # Data row
        cells = [c.strip() for c in stripped.strip("|").split("|")]
        rows.append(cells)

    return column_names, rows


# ---------------------------------------------------------------------------
# Component table parsing
# ---------------------------------------------------------------------------

# Column name aliases (lowercased) -> Component field name
_COMPONENT_COLUMN_MAP = {
    "name": "name",
    "path": "path",
    "type": "type",
    "test_command": "test_command",
    "test command": "test_command",
    "repo": "repo",
}


def parse_components_table(content: str) -> list[Component]:
    """Parse a ``## Components`` markdown table from STACK.md content.

    Supports both 4-column (legacy) and 5-column (with Repo) tables.
    Column order does not matter — columns are matched by header name.
    """
    column_names, rows = parse_markdown_table(content, "Components")
    if not column_names or not rows:
        return []

    # Map header positions to field names
    col_map: dict[int, str] = {}
    for i, col in enumerate(column_names):
        field = _COMPONENT_COLUMN_MAP.get(col)
        if field:
            col_map[i] = field

    # Require at least name and path columns
    field_set = set(col_map.values())
    if "name" not in field_set or "path" not in field_set:
        return []

    components: list[Component] = []
    seen_names: set[str] = set()

    for row in rows:
        fields: dict[str, str] = {}
        for i, cell in enumerate(row):
            if i in col_map:
                fields[col_map[i]] = cell.strip()

        name = fields.get("name", "")
        path = fields.get("path", "")
        if not name or not path:
            continue

        if name in seen_names:
            warnings.warn(
                f"Duplicate component name '{name}' in Components table; "
                f"keeping last occurrence",
                stacklevel=2,
            )
            # Remove previous entry with same name
            components = [c for c in components if c.name != name]

        seen_names.add(name)
        repo = fields.get("repo") or None  # Treat empty string as None
        components.append(Component(
            name=name,
            path=path,
            type=fields.get("type", ""),
            test_command=fields.get("test_command", ""),
            repo=repo,
        ))

    return components


# ---------------------------------------------------------------------------
# Loading
# ---------------------------------------------------------------------------

def load_registry(project_root: Path) -> ComponentRegistry:
    """Load component registry from STACK.md."""
    stack_file = project_root / "STACK.md"
    if not stack_file.exists():
        # Try .agentic/ location
        stack_file = project_root / ".agentic" / "STACK.md"
    if not stack_file.exists():
        return ComponentRegistry(components={}, project_root=project_root)

    content = stack_file.read_text(errors="ignore")
    components = parse_components_table(content)
    return ComponentRegistry(
        components={c.name: c for c in components},
        project_root=project_root,
    )


# ---------------------------------------------------------------------------
# Auto-detection
# ---------------------------------------------------------------------------

# Markers that indicate a sub-project / component
_COMPONENT_MARKERS = {
    "package.json": "typescript",
    "pyproject.toml": "python",
    "setup.py": "python",
    "Cargo.toml": "rust",
    "go.mod": "go",
    "pom.xml": "java",
    "build.gradle": "java",
    "Gemfile": "ruby",
}

# Default test commands per type
_DEFAULT_TEST_COMMANDS = {
    "typescript": "npm test",
    "python": "pytest",
    "rust": "cargo test",
    "go": "go test ./...",
    "java": "mvn test",
    "ruby": "bundle exec rspec",
}


def auto_detect_components(project_root: Path) -> list[Component]:
    """Auto-detect components in a monorepo by scanning for project markers.

    Scans immediate subdirectories (max 2 levels deep) for package.json,
    pyproject.toml, Cargo.toml, go.mod, etc.
    """
    components: list[Component] = []
    seen_paths: set[str] = set()

    # Directories to skip
    skip_dirs = {
        ".git", ".agentic", "node_modules", "__pycache__",
        ".venv", "venv", "target", "dist", "build", ".next",
    }

    for depth in range(1, 3):  # 1 and 2 levels deep
        pattern = "/".join(["*"] * depth)
        for marker_file, comp_type in _COMPONENT_MARKERS.items():
            for found in project_root.glob(f"{pattern}/{marker_file}"):
                comp_dir = found.parent
                rel_path = str(comp_dir.relative_to(project_root))

                # Skip root-level markers (that's the whole project, not a component)
                if rel_path == ".":
                    continue

                # Skip excluded directories
                if any(part in skip_dirs for part in comp_dir.parts):
                    continue

                if rel_path in seen_paths:
                    continue
                seen_paths.add(rel_path)

                test_cmd = _DEFAULT_TEST_COMMANDS.get(comp_type, "")
                components.append(Component(
                    name=comp_dir.name,
                    path=rel_path,
                    type=comp_type,
                    test_command=test_cmd,
                ))

    # Sort by path for deterministic output
    components.sort(key=lambda c: c.path)
    return components
