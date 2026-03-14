"""Tests for F-0179: Component Registry and Scoped Context.

@feature F-0179, F-0187
"""
import sys
import textwrap
import warnings
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
    parse_markdown_table,
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
# parse_markdown_table (F-0187 shared helper)
# ---------------------------------------------------------------------------

class TestParseMarkdownTable:
    """Test the shared markdown table parser."""

    def test_parses_section(self):
        content = textwrap.dedent("""\
            ## MySection
            | col_a | col_b |
            |-------|-------|
            | x     | y     |
        """)
        cols, rows = parse_markdown_table(content, "MySection")
        assert cols == ["col_a", "col_b"]
        assert rows == [["x", "y"]]

    def test_returns_empty_for_missing_section(self):
        cols, rows = parse_markdown_table("## Other\n", "Missing")
        assert cols == []
        assert rows == []

    def test_returns_empty_for_empty_table(self):
        content = textwrap.dedent("""\
            ## MySection
            | col_a | col_b |
            |-------|-------|

            ## Next
        """)
        cols, rows = parse_markdown_table(content, "MySection")
        assert cols == ["col_a", "col_b"]
        assert rows == []

    def test_columns_are_lowercased(self):
        content = textwrap.dedent("""\
            ## Data
            | Name | PATH | Type |
            |------|------|------|
            | a    | b    | c    |
        """)
        cols, rows = parse_markdown_table(content, "Data")
        assert cols == ["name", "path", "type"]

    def test_handles_section_with_trailing_text(self):
        content = textwrap.dedent("""\
            ## Components (optional, for monorepos)
            | name | path |
            |------|------|
            | api  | src/ |
        """)
        cols, rows = parse_markdown_table(content, "Components")
        assert cols == ["name", "path"]
        assert len(rows) == 1


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
        assert api.repo is None  # F-0187: no repo column

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

    # -- F-0187: 5-column table with Repo column ----------------------------

    def test_parses_five_column_table_with_repo(self):
        """AC-001: Repo column supported."""
        content = textwrap.dedent("""\
            ## Components
            | name | path | repo | type | test_command |
            |------|------|------|------|--------------|
            | api  | ../api-service | https://github.com/org/api | python | pytest |
            | web  | packages/web | | typescript | npm test |
        """)
        components = parse_components_table(content)
        assert len(components) == 2

        api = components[0]
        assert api.name == "api"
        assert api.path == "../api-service"
        assert api.repo == "https://github.com/org/api"
        assert api.type == "python"

        web = components[1]
        assert web.name == "web"
        assert web.repo is None  # Empty repo = None

    def test_reordered_columns(self):
        """AC-001: Column order doesn't matter — header-aware parsing."""
        content = textwrap.dedent("""\
            ## Components
            | type | name | test_command | repo | path |
            |------|------|-------------|------|------|
            | python | api | pytest | https://github.com/org/api | ../api |
        """)
        components = parse_components_table(content)
        assert len(components) == 1
        assert components[0].name == "api"
        assert components[0].type == "python"
        assert components[0].path == "../api"
        assert components[0].repo == "https://github.com/org/api"
        assert components[0].test_command == "pytest"

    def test_test_command_with_space_header(self):
        """'test command' (with space) is accepted as column name."""
        content = textwrap.dedent("""\
            ## Components
            | name | path | type | test command |
            |------|------|------|-------------|
            | api  | src/api | python | pytest |
        """)
        components = parse_components_table(content)
        assert len(components) == 1
        assert components[0].test_command == "pytest"

    def test_duplicate_component_name_warns(self):
        """Duplicate names produce a warning and keep the last."""
        content = textwrap.dedent("""\
            ## Components
            | name | path | type | test_command |
            |------|------|------|--------------|
            | api  | packages/api-v1 | python | pytest v1 |
            | api  | packages/api-v2 | python | pytest v2 |
        """)
        with warnings.catch_warnings(record=True) as w:
            warnings.simplefilter("always")
            components = parse_components_table(content)
            assert len(components) == 1
            assert components[0].path == "packages/api-v2"
            assert len(w) == 1
            assert "Duplicate component name" in str(w[0].message)


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

    # -- F-0187: Multi-repo helpers ----------------------------------------

    def test_is_multi_repo_false(self, registry):
        """No repo fields → not multi-repo."""
        assert registry.is_multi_repo() is False

    def test_is_multi_repo_true(self, tmp_path):
        components = {
            "api": Component("api", "../api", "python", "", repo="https://github.com/org/api"),
        }
        reg = ComponentRegistry(components=components, project_root=tmp_path)
        assert reg.is_multi_repo() is True

    def test_get_external_components(self, tmp_path):
        components = {
            "api": Component("api", "../api", "python", "", repo="https://github.com/org/api"),
            "web": Component("web", "packages/web", "typescript", ""),
        }
        reg = ComponentRegistry(components=components, project_root=tmp_path)
        external = reg.get_external_components()
        assert len(external) == 1
        assert external[0].name == "api"

    def test_get_local_components(self, tmp_path):
        components = {
            "api": Component("api", "../api", "python", "", repo="https://github.com/org/api"),
            "web": Component("web", "packages/web", "typescript", ""),
        }
        reg = ComponentRegistry(components=components, project_root=tmp_path)
        local = reg.get_local_components()
        assert len(local) == 1
        assert local[0].name == "web"


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

    def test_skips_cross_repo_components(self, tmp_path):
        """F-0187: Components with repo set are skipped in validate()."""
        components = {
            "api": Component("api", "../api-service", "python", "",
                             repo="https://github.com/org/api"),
        }
        reg = ComponentRegistry(components=components, project_root=tmp_path)
        errors = reg.validate()
        assert errors == []  # Skipped, not an error


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

    def test_loads_five_column_table(self, tmp_path):
        """F-0187: 5-column table with Repo loads correctly."""
        (tmp_path / "STACK.md").write_text(textwrap.dedent("""\
            ## Components
            | name | path | repo | type | test_command |
            |------|------|------|------|--------------|
            | api  | ../api | https://github.com/org/api | python | pytest |
        """))
        registry = load_registry(tmp_path)
        assert len(registry.list_all()) == 1
        api = registry.get("api")
        assert api is not None
        assert api.repo == "https://github.com/org/api"


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

    def test_auto_detected_components_have_no_repo(self, tmp_path):
        """F-0187: Auto-detected components always have repo=None."""
        sub = tmp_path / "packages" / "api"
        sub.mkdir(parents=True)
        (sub / "pyproject.toml").write_text("[project]")

        components = auto_detect_components(tmp_path)
        assert len(components) == 1
        assert components[0].repo is None
