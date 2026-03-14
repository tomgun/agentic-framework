"""Tests for F-0187: Multi-Repo Umbrella.

@feature F-0187
"""
import sys
import textwrap
from pathlib import Path

import pytest

# Ensure auto/ is importable
_LIB_DIR = Path(__file__).resolve().parent.parent / ".agentic" / "lib"
sys.path.insert(0, str(_LIB_DIR))

from auto.components import Component, ComponentRegistry, load_registry
from auto.umbrella import (
    Contract,
    ContractResult,
    UmbrellaInputs,
    UmbrellaProject,
    collect_inputs,
    get_component_root,
    parse_contracts_table,
    resolve_umbrella,
    validate_contracts,
)


# ---------------------------------------------------------------------------
# resolve_umbrella (AC-002)
# ---------------------------------------------------------------------------

class TestResolveUmbrella:
    """Test umbrella project resolution."""

    def test_returns_none_for_single_repo(self, tmp_path):
        """AC-005: Single-repo projects get None (unaffected)."""
        (tmp_path / "STACK.md").write_text(textwrap.dedent("""\
            ## Components
            | name | path | type | test_command |
            |------|------|------|--------------|
            | api  | packages/api | python | pytest |
        """))
        (tmp_path / "packages" / "api").mkdir(parents=True)

        result = resolve_umbrella(tmp_path)
        assert result is None

    def test_returns_none_for_no_components(self, tmp_path):
        """No Components section → None."""
        (tmp_path / "STACK.md").write_text("# STACK\n## Summary\n")
        result = resolve_umbrella(tmp_path)
        assert result is None

    def test_resolves_multi_repo_components(self, tmp_path):
        """AC-002: Resolves cross-repo component paths."""
        # Create umbrella repo
        umbrella = tmp_path / "umbrella"
        umbrella.mkdir()
        (umbrella / "STACK.md").write_text(textwrap.dedent("""\
            ## Components
            | name | path | repo | type | test_command |
            |------|------|------|------|--------------|
            | api  | ../api-service | https://github.com/org/api | python | pytest |
            | web  | ../web-app | https://github.com/org/web | typescript | npm test |
        """))

        # Create sibling repos with .git dirs
        api = tmp_path / "api-service"
        api.mkdir()
        (api / ".git").mkdir()

        web = tmp_path / "web-app"
        web.mkdir()
        (web / ".git").mkdir()

        result = resolve_umbrella(umbrella)
        assert result is not None
        assert len(result.component_roots) == 2
        assert result.missing_repos == []
        assert result.component_roots["api"] == api.resolve()
        assert result.component_roots["web"] == web.resolve()

    def test_detects_missing_repos(self, tmp_path):
        """AC-002: Missing repos reported with clone instructions."""
        (tmp_path / "STACK.md").write_text(textwrap.dedent("""\
            ## Components
            | name | path | repo | type | test_command |
            |------|------|------|------|--------------|
            | api  | ../api-service | https://github.com/org/api | python | pytest |
        """))
        # Don't create the sibling directory

        result = resolve_umbrella(tmp_path)
        assert result is not None
        assert len(result.missing_repos) == 1
        assert "api" in result.missing_repos[0]
        assert "git clone" in result.missing_repos[0]
        assert "api" not in result.component_roots

    def test_detects_missing_git_dir(self, tmp_path):
        """AC-002: Directory exists but no .git → warning."""
        umbrella = tmp_path / "umbrella"
        umbrella.mkdir()
        (umbrella / "STACK.md").write_text(textwrap.dedent("""\
            ## Components
            | name | path | repo | type | test_command |
            |------|------|------|------|--------------|
            | api  | ../api-service | https://github.com/org/api | python | pytest |
        """))

        # Create directory but no .git
        api = tmp_path / "api-service"
        api.mkdir()

        result = resolve_umbrella(umbrella)
        assert result is not None
        assert len(result.missing_repos) == 1
        assert "not a git repository" in result.missing_repos[0]

    def test_mixed_local_and_external(self, tmp_path):
        """Mix of local (no repo) and external (with repo) components."""
        umbrella = tmp_path / "umbrella"
        umbrella.mkdir()
        (umbrella / "STACK.md").write_text(textwrap.dedent("""\
            ## Components
            | name | path | repo | type | test_command |
            |------|------|------|------|--------------|
            | api  | ../api-service | https://github.com/org/api | python | pytest |
            | shared | packages/shared | | typescript | npm test |
        """))

        # External repo
        api = tmp_path / "api-service"
        api.mkdir()
        (api / ".git").mkdir()

        # Local component
        (umbrella / "packages" / "shared").mkdir(parents=True)

        result = resolve_umbrella(umbrella)
        assert result is not None
        assert "api" in result.component_roots
        assert "shared" in result.component_roots
        assert result.missing_repos == []


class TestGetComponentRoot:
    """Test component root lookup."""

    def test_returns_resolved_path(self, tmp_path):
        umbrella = UmbrellaProject(
            project_root=tmp_path,
            registry=ComponentRegistry(components={}, project_root=tmp_path),
            component_roots={"api": tmp_path / "api"},
        )
        assert get_component_root(umbrella, "api") == tmp_path / "api"

    def test_returns_none_for_missing(self, tmp_path):
        umbrella = UmbrellaProject(
            project_root=tmp_path,
            registry=ComponentRegistry(components={}, project_root=tmp_path),
        )
        assert get_component_root(umbrella, "nope") is None


# ---------------------------------------------------------------------------
# Contract checking (AC-003)
# ---------------------------------------------------------------------------

SAMPLE_STACK_WITH_CONTRACTS = textwrap.dedent("""\
    ## Components
    | name | path | type | test_command |
    |------|------|------|--------------|
    | api  | packages/api | python | pytest |
    | web  | packages/web | typescript | npm test |

    ## Contracts
    | name | path | format | producer | consumers |
    |------|------|--------|----------|-----------|
    | user-api | contracts/user-api.yaml | openapi | api | web |
    | events | contracts/events.proto | protobuf | api | web, analytics |
""")


class TestParseContractsTable:
    """Test contract table parsing."""

    def test_parses_contracts(self):
        contracts = parse_contracts_table(SAMPLE_STACK_WITH_CONTRACTS)
        assert len(contracts) == 2

        user_api = contracts[0]
        assert user_api.name == "user-api"
        assert user_api.path == "contracts/user-api.yaml"
        assert user_api.format == "openapi"
        assert user_api.producer == "api"
        assert user_api.consumers == ["web"]

        events = contracts[1]
        assert events.name == "events"
        assert events.consumers == ["web", "analytics"]

    def test_no_contracts_section(self):
        contracts = parse_contracts_table("## Components\n| name | path |\n")
        assert contracts == []

    def test_empty_contracts_table(self):
        content = textwrap.dedent("""\
            ## Contracts
            | name | path | format | producer | consumers |
            |------|------|--------|----------|-----------|

            ## Other
        """)
        contracts = parse_contracts_table(content)
        assert contracts == []

    def test_contract_without_producer(self):
        content = textwrap.dedent("""\
            ## Contracts
            | name | path | format | producer | consumers |
            |------|------|--------|----------|-----------|
            | schema | schema.json | json-schema | | web |
        """)
        contracts = parse_contracts_table(content)
        assert len(contracts) == 1
        assert contracts[0].producer is None


class TestValidateContracts:
    """Test contract validation."""

    def test_validates_existing_contract(self, tmp_path):
        """Contract file exists, producer/consumer valid."""
        (tmp_path / "STACK.md").write_text(SAMPLE_STACK_WITH_CONTRACTS)
        (tmp_path / "contracts").mkdir()
        (tmp_path / "contracts" / "user-api.yaml").write_text("openapi: 3.0")
        (tmp_path / "contracts" / "events.proto").write_text("syntax = 'proto3';")

        registry = load_registry(tmp_path)
        results = validate_contracts(tmp_path, registry)

        assert len(results) == 2
        # user-api: file exists, valid producer/consumer
        assert results[0].exists is True
        # Only warning should be about 'analytics' not being a registered component
        analytics_warnings = [w for w in results[1].warnings if "analytics" in w]
        assert len(analytics_warnings) == 1

    def test_missing_contract_file(self, tmp_path):
        """Contract file does not exist."""
        (tmp_path / "STACK.md").write_text(textwrap.dedent("""\
            ## Components
            | name | path | type | test_command |
            |------|------|------|--------------|
            | api | packages/api | python | pytest |

            ## Contracts
            | name | path | format | producer | consumers |
            |------|------|--------|----------|-----------|
            | missing | contracts/nope.yaml | openapi | api | |
        """))

        registry = load_registry(tmp_path)
        results = validate_contracts(tmp_path, registry)

        assert len(results) == 1
        assert results[0].exists is False
        assert any("does not exist" in w for w in results[0].warnings)

    def test_invalid_producer(self, tmp_path):
        """Producer not in component registry."""
        (tmp_path / "STACK.md").write_text(textwrap.dedent("""\
            ## Components
            | name | path | type | test_command |
            |------|------|------|--------------|
            | web | packages/web | typescript | npm test |

            ## Contracts
            | name | path | format | producer | consumers |
            |------|------|--------|----------|-----------|
            | api-spec | spec.yaml | openapi | billing | web |
        """))
        (tmp_path / "spec.yaml").write_text("openapi: 3.0")

        registry = load_registry(tmp_path)
        results = validate_contracts(tmp_path, registry)

        assert len(results) == 1
        assert any("billing" in w and "not a registered" in w for w in results[0].warnings)

    def test_no_stack_md_returns_empty(self, tmp_path):
        registry = ComponentRegistry(components={}, project_root=tmp_path)
        results = validate_contracts(tmp_path, registry)
        assert results == []


# ---------------------------------------------------------------------------
# Input collection (AC-004)
# ---------------------------------------------------------------------------

class TestCollectInputs:
    """Test input validation and resolution."""

    def test_collects_valid_inputs(self, tmp_path):
        (tmp_path / "style.md").write_text("style guide")
        (tmp_path / "research.pdf").write_text("research")
        (tmp_path / "contracts").mkdir()

        result = collect_inputs(
            project_root=tmp_path,
            vision="Build a marketplace",
            style_refs=["style.md"],
            research_refs=["research.pdf"],
            contract_dir="contracts",
        )

        assert result.vision == "Build a marketplace"
        assert len(result.style_refs) == 1
        assert result.style_refs[0] == (tmp_path / "style.md").resolve()
        assert len(result.research_refs) == 1
        assert result.contract_dir == (tmp_path / "contracts").resolve()

    def test_missing_style_ref_raises(self, tmp_path):
        with pytest.raises(FileNotFoundError, match="Style reference"):
            collect_inputs(
                project_root=tmp_path,
                vision="test",
                style_refs=["nonexistent.md"],
            )

    def test_missing_research_ref_raises(self, tmp_path):
        with pytest.raises(FileNotFoundError, match="Research reference"):
            collect_inputs(
                project_root=tmp_path,
                vision="test",
                research_refs=["nonexistent.pdf"],
            )

    def test_missing_contract_dir_raises(self, tmp_path):
        with pytest.raises(FileNotFoundError, match="Contract directory"):
            collect_inputs(
                project_root=tmp_path,
                vision="test",
                contract_dir="nonexistent/",
            )

    def test_minimal_inputs(self, tmp_path):
        """Vision only — no optional refs."""
        result = collect_inputs(
            project_root=tmp_path,
            vision="Build something",
        )
        assert result.vision == "Build something"
        assert result.style_refs == []
        assert result.research_refs == []
        assert result.contract_dir is None
