"""
components.py -- Component registry for multi-component projects.

Parses an optional `## Components` table from STACK.md and provides
component-scoped context filtering, test commands, and validation.

@feature F-0179

Usage:
    from auto.components import load_registry
    registry = load_registry(Path("/project"))
    api = registry.get("api")
    if api:
        print(api.test_command)
"""
from __future__ import annotations

import re
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
        """Validate that component paths exist on disk. Returns error strings."""
        errors: list[str] = []
        for comp in self.components.values():
            full_path = self.project_root / comp.path
            if not full_path.is_dir():
                errors.append(
                    f"Component '{comp.name}': path '{comp.path}' "
                    f"does not exist at {full_path}"
                )
        return errors


# ---------------------------------------------------------------------------
# Parsing
# ---------------------------------------------------------------------------

def parse_components_table(content: str) -> list[Component]:
    """Parse a `## Components` markdown table from STACK.md content.

    Expected format:
        ## Components
        | name | path | type | test_command |
        |------|------|------|--------------|
        | api  | packages/api | python | pytest packages/api/tests/ |
    """
    components: list[Component] = []

    # Find the ## Components section
    section_re = re.compile(r"^##\s+Components", re.MULTILINE)
    match = section_re.search(content)
    if not match:
        return components

    # Extract section content (until next ## header or end of file)
    section_start = match.end()
    next_header = re.search(r"^##\s+", content[section_start:], re.MULTILINE)
    section_text = content[section_start:section_start + next_header.start()] if next_header else content[section_start:]

    # Parse markdown table rows
    table_rows: list[str] = []
    header_found = False
    separator_found = False

    for line in section_text.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("<!--"):
            continue
        if not stripped.startswith("|"):
            continue

        if not header_found:
            header_found = True
            continue  # Skip header row
        if not separator_found:
            # Skip separator row (|---|---|---|---|)
            if re.match(r"^\|[\s\-:|]+\|$", stripped):
                separator_found = True
                continue
            # If no separator, treat as data row
            separator_found = True

        table_rows.append(stripped)

    # Parse each data row
    for row in table_rows:
        cells = [c.strip() for c in row.strip("|").split("|")]

        if len(cells) >= 4:
            name = cells[0].strip()
            path = cells[1].strip()
            comp_type = cells[2].strip()
            test_cmd = cells[3].strip()
            if name and path:  # Require at least name and path
                components.append(Component(
                    name=name,
                    path=path,
                    type=comp_type,
                    test_command=test_cmd,
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
