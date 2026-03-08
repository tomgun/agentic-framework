"""Tests for F-0179: Component Registry and Scoped Context.

@feature F-0179
"""
import sys
import textwrap
from pathlib import Path

import pytest

# Ensure auto/ is importable
_LIB_DIR = Path(__file__).resolve().parent.parent / ".agentic" / "lib"
sys.path.insert(0, str(_LIB_DIR))

from auto.components import (
    Component,
    ComponentRegistry,
    auto_detect_components,
    load_registry,
    parse_components_table,
)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

SAMPLE_STACK_WITH_COMPONENTS = textwrap.dedent("""\
    # STACK.md

    ## Summary
    - What: A multi-component web app

    ## Components
    | name | path | type | test_command |
    |------|------|------|--------------|
    | api  | packages/api | python | pytest packages/api/tests/ |
    | web  | packages/web | typescript | npm run test --workspace=web |
    | shared | packages/shared | typescript | npm run test --workspace=shared |

    ## Testing
    - Unit test framework: pytest
""")

SAMPLE_STACK_WITHOUT_COMPONENTS = textwrap.dedent("""\
    # STACK.md

    ## Summary
    - What: A simple project

    ## Testing
    - Unit test framework: pytest
""")

SAMPLE_STACK_EMPTY_TABLE = textwrap.dedent("""\
    # STACK.md

    ## Components
    | name | path | type | test_command |
    |------|------|------|--------------|

    ## Testing
    - Unit test framework: pytest
""")

SAMPLE_STACK_COMMENTED = textwrap.dedent("""\
    # STACK.md

    ## Components (optional, for monorepos)
    <!-- Uncomment and fill for multi-component projects -->
    <!-- | name | path | type | test_command | -->
    <!-- |------|------|------|--------------|  -->
    <!-- | api  | packages/api | python | pytest packages/api/tests/ | -->

    ## Testing
    - Unit test framework: pytest
""")


# ---------------------------------------------------------------------------
# parse_components_table
# ---------------------------------------------------------------------------

class TestParseComponentsTable:
    """Test markdown table parsing."""

    def test_parses_valid_table(self):
        components = parse_components_table(SAMPLE_STACK_WITH_COMPONENTS)
        assert len(components) == 3

        api = components[0]
        assert api.name == "api"
        assert api.path == "packages/api"
        assert api.type == "python"
        assert api.test_command == "pytest packages/api/tests/"

        web = components[1]
        assert web.name == "web"
        assert web.path == "packages/web"
        assert web.type == "typescript"

    def test_missing_section_returns_empty(self):
        """AC-007: No Components section = empty list."""
        components = parse_components_table(SAMPLE_STACK_WITHOUT_COMPONENTS)
        assert components == []

    def test_empty_table_returns_empty(self):
        components = parse_components_table(SAMPLE_STACK_EMPTY_TABLE)
        assert components == []

    def test_commented_section_returns_empty(self):
        components = parse_components_table(SAMPLE_STACK_COMMENTED)
        assert components == []

    def test_handles_extra_whitespace(self):
        content = textwrap.dedent("""\
            ## Components
            | name   |   path          |  type       |   test_command              |
            |--------|-----------------|-------------|----------------------------|
            |  api   |  packages/api   |  python     |  pytest packages/api/       |
        """)
        components = parse_components_table(content)
        assert len(components) == 1
        assert components[0].name == "api"
        assert components[0].path == "packages/api"

    def test_single_component(self):
        content = textwrap.dedent("""\
            ## Components
            | name | path | type | test_command |
            |------|------|------|--------------|
            | core | src/core | python | pytest |
        """)
        components = parse_components_table(content)
        assert len(components) == 1
        assert components[0].name == "core"


# ---------------------------------------------------------------------------
# ComponentRegistry
# ---------------------------------------------------------------------------

class TestComponentRegistry:
    """Test registry operations."""

    @pytest.fixture
    def registry(self, tmp_path):
        """Create a registry with test components."""
        # Create directories
        (tmp_path / "packages" / "api").mkdir(parents=True)
        (tmp_path / "packages" / "web").mkdir(parents=True)

        components = {
            "api": Component("api", "packages/api", "python", "pytest"),
            "web": Component("web", "packages/web", "typescript", "npm test"),
        }
        return ComponentRegistry(components=components, project_root=tmp_path)

    def test_get_by_name(self, registry):
        api = registry.get("api")
        assert api is not None
        assert api.name == "api"
        assert api.type == "python"

    def test_get_returns_none_for_missing(self, registry):
        assert registry.get("nonexistent") is None

    def test_list_all(self, registry):
        all_comps = registry.list_all()
        assert len(all_comps) == 2
        names = {c.name for c in all_comps}
        assert names == {"api", "web"}

    def test_get_for_path(self, registry):
        """Reverse lookup: find component for a file path."""
        comp = registry.get_for_path("packages/api/src/main.py")
        assert comp is not None
        assert comp.name == "api"

    def test_get_for_path_returns_none_for_unknown(self, registry):
        assert registry.get_for_path("some/other/file.py") is None

    def test_get_for_path_picks_longest_match(self, tmp_path):
        """When paths overlap, pick the most specific component."""
        (tmp_path / "packages").mkdir()
        (tmp_path / "packages" / "api").mkdir()
        (tmp_path / "packages" / "api" / "v2").mkdir()

        components = {
            "packages": Component("packages", "packages", "python", ""),
            "api": Component("api", "packages/api", "python", ""),
            "api-v2": Component("api-v2", "packages/api/v2", "python", ""),
        }
        reg = ComponentRegistry(components=components, project_root=tmp_path)

        comp = reg.get_for_path("packages/api/v2/handler.py")
        assert comp is not None
        assert comp.name == "api-v2"


# ---------------------------------------------------------------------------
# Validation (AC-008)
# ---------------------------------------------------------------------------

class TestValidation:
    """Test path validation."""

    def test_validates_existing_paths(self, tmp_path):
        (tmp_path / "packages" / "api").mkdir(parents=True)
        components = {"api": Component("api", "packages/api", "python", "")}
        reg = ComponentRegistry(components=components, project_root=tmp_path)

        errors = reg.validate()
        assert errors == []

    def test_reports_missing_paths(self, tmp_path):
        components = {"api": Component("api", "packages/api", "python", "")}
        reg = ComponentRegistry(components=components, project_root=tmp_path)

        errors = reg.validate()
        assert len(errors) == 1
        assert "packages/api" in errors[0]
        assert "does not exist" in errors[0]


# ---------------------------------------------------------------------------
# load_registry
# ---------------------------------------------------------------------------

class TestLoadRegistry:
    """Test loading from STACK.md on disk."""

    def test_loads_from_stack_md(self, tmp_path):
        (tmp_path / "STACK.md").write_text(SAMPLE_STACK_WITH_COMPONENTS)
        registry = load_registry(tmp_path)
        assert len(registry.list_all()) == 3
        assert registry.get("api") is not None

    def test_no_stack_md_returns_empty(self, tmp_path):
        """AC-007: Missing STACK.md = empty registry."""
        registry = load_registry(tmp_path)
        assert len(registry.list_all()) == 0

    def test_stack_without_components_returns_empty(self, tmp_path):
        """AC-007: STACK.md without Components section = empty registry."""
        (tmp_path / "STACK.md").write_text(SAMPLE_STACK_WITHOUT_COMPONENTS)
        registry = load_registry(tmp_path)
        assert len(registry.list_all()) == 0


# ---------------------------------------------------------------------------
# Auto-detection (AC-004)
# ---------------------------------------------------------------------------

class TestAutoDetect:
    """Test auto-detection of components in monorepos."""

    def test_detects_python_subproject(self, tmp_path):
        sub = tmp_path / "packages" / "api"
        sub.mkdir(parents=True)
        (sub / "pyproject.toml").write_text("[project]\nname = 'api'")

        components = auto_detect_components(tmp_path)
        assert len(components) == 1
        assert components[0].name == "api"
        assert components[0].type == "python"
        assert components[0].path == "packages/api"

    def test_detects_node_subproject(self, tmp_path):
        sub = tmp_path / "packages" / "web"
        sub.mkdir(parents=True)
        (sub / "package.json").write_text('{"name": "web"}')

        components = auto_detect_components(tmp_path)
        assert len(components) == 1
        assert components[0].name == "web"
        assert components[0].type == "typescript"

    def test_detects_go_subproject(self, tmp_path):
        sub = tmp_path / "services" / "gateway"
        sub.mkdir(parents=True)
        (sub / "go.mod").write_text("module gateway")

        components = auto_detect_components(tmp_path)
        assert len(components) == 1
        assert components[0].type == "go"

    def test_detects_rust_subproject(self, tmp_path):
        sub = tmp_path / "crates" / "engine"
        sub.mkdir(parents=True)
        (sub / "Cargo.toml").write_text("[package]\nname = 'engine'")

        components = auto_detect_components(tmp_path)
        assert len(components) == 1
        assert components[0].type == "rust"

    def test_skips_root_level_markers(self, tmp_path):
        """Root-level package.json is the whole project, not a component."""
        (tmp_path / "package.json").write_text('{"name": "root"}')
        components = auto_detect_components(tmp_path)
        assert components == []

    def test_empty_project_returns_empty(self, tmp_path):
        components = auto_detect_components(tmp_path)
        assert components == []

    def test_skips_node_modules(self, tmp_path):
        bad = tmp_path / "node_modules" / "some-pkg"
        bad.mkdir(parents=True)
        (bad / "package.json").write_text('{"name": "bad"}')
        components = auto_detect_components(tmp_path)
        assert components == []

    def test_multiple_components(self, tmp_path):
        api = tmp_path / "packages" / "api"
        api.mkdir(parents=True)
        (api / "pyproject.toml").write_text("[project]")

        web = tmp_path / "packages" / "web"
        web.mkdir(parents=True)
        (web / "package.json").write_text("{}")

        components = auto_detect_components(tmp_path)
        assert len(components) == 2
        names = {c.name for c in components}
        assert names == {"api", "web"}
