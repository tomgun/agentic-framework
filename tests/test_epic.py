#!/usr/bin/env python3
"""
Tests for epic.py — epic decomposition and parent-child status derivation.

@feature F-0184
"""
import os
import sys
import textwrap
from pathlib import Path

import pytest

# Add paths for imports
sys.path.insert(0, str(Path(__file__).parent.parent / ".agentic" / "lib"))
sys.path.insert(0, str(Path(__file__).parent.parent / ".agentic" / "lib" / "tools"))
sys.path.insert(0, str(Path(__file__).parent.parent / ".agentic" / "lib" / "auto"))

from auto.epic import (
    derive_epic_status,
    propose_decomposition,
    create_child_features,
    decompose,
    extract_subfeature,
    recompute_epic_status,
    _parse_ac_groups,
    _derive_child_name,
    _build_child_contract,
    _get_feature_status,
    _get_feature_parent,
    _get_children_statuses,
    get_next_feature_id,
)
from ids import get_depth, get_next_child_id, MAX_DEPTH


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def tmp_project(tmp_path):
    """Create a minimal project structure for testing."""
    # .agentic directories
    spec_dir = tmp_path / ".agentic" / "spec"
    spec_dir.mkdir(parents=True)
    acceptance_dir = spec_dir / "acceptance"
    acceptance_dir.mkdir()
    tools_dir = tmp_path / ".agentic" / "lib" / "tools"
    tools_dir.mkdir(parents=True)
    auto_dir = tmp_path / ".agentic" / "lib" / "auto"
    auto_dir.mkdir(parents=True)
    session_dir = tmp_path / ".agentic" / "session"
    session_dir.mkdir(parents=True)

    # Copy feature.sh from real project
    real_feature_sh = Path(__file__).parent.parent / ".agentic" / "lib" / "tools" / "feature.sh"
    if real_feature_sh.exists():
        (tools_dir / "feature.sh").write_text(real_feature_sh.read_text())

    # Copy paths.sh and ids.sh from real project
    real_paths_sh = Path(__file__).parent.parent / ".agentic" / "lib" / "paths.sh"
    if real_paths_sh.exists():
        (tmp_path / ".agentic" / "lib" / "paths.sh").write_text(
            real_paths_sh.read_text()
        )
    real_ids_sh = Path(__file__).parent.parent / ".agentic" / "lib" / "ids.sh"
    if real_ids_sh.exists():
        (tmp_path / ".agentic" / "lib" / "ids.sh").write_text(
            real_ids_sh.read_text()
        )

    # STACK.md with settings
    (tmp_path / "STACK.md").write_text(textwrap.dedent("""\
        # Stack

        ## Settings
        - profile: formal
        - review_decomposition: skip
    """))

    return tmp_path


def _write_features(tmp_project, content):
    """Write FEATURES.md content to the tmp project."""
    features_file = tmp_project / ".agentic" / "spec" / "FEATURES.md"
    features_file.write_text(content)
    return features_file


def _write_ac(tmp_project, feature_id, content):
    """Write an acceptance criteria file."""
    ac_file = tmp_project / ".agentic" / "spec" / "acceptance" / f"{feature_id}.md"
    ac_file.write_text(content)
    return ac_file


# ---------------------------------------------------------------------------
# derive_epic_status tests (AC-005)
# ---------------------------------------------------------------------------

class TestDeriveEpicStatus:
    def test_empty_list_returns_none(self):
        assert derive_epic_status([]) is None

    def test_all_shipped(self):
        assert derive_epic_status(["shipped", "shipped", "shipped"]) == "shipped"

    def test_all_deprecated(self):
        assert derive_epic_status(["deprecated", "deprecated"]) == "deprecated"

    def test_mixed_deprecated_and_shipped(self):
        """Deprecated children are excluded; remaining all shipped → shipped."""
        assert derive_epic_status(["shipped", "deprecated", "shipped"]) == "shipped"

    def test_any_implementing(self):
        assert derive_epic_status(["shipped", "implementing", "planned"]) == "implementing"

    def test_any_verified(self):
        """Verified is an active state → epic should be implementing."""
        assert derive_epic_status(["shipped", "verified", "planned"]) == "implementing"

    def test_any_documented(self):
        assert derive_epic_status(["shipped", "documented"]) == "implementing"

    def test_any_committed(self):
        assert derive_epic_status(["shipped", "committed"]) == "implementing"

    def test_all_early_states(self):
        assert derive_epic_status(["planned", "specced", "criteria_set"]) == "criteria_set"

    def test_all_planned(self):
        assert derive_epic_status(["planned", "planned"]) == "criteria_set"

    def test_fallback_min_state(self):
        """When no specific rule matches, return minimum state."""
        assert derive_epic_status(["tests_written", "criteria_set"]) == "criteria_set"

    def test_single_child_shipped(self):
        assert derive_epic_status(["shipped"]) == "shipped"

    def test_single_child_implementing(self):
        assert derive_epic_status(["implementing"]) == "implementing"

    def test_regression_child_implementing_after_verified(self):
        """If a child regresses to implementing, epic reflects that."""
        assert derive_epic_status(["shipped", "implementing"]) == "implementing"


# ---------------------------------------------------------------------------
# _parse_ac_groups tests
# ---------------------------------------------------------------------------

class TestParseAcGroups:
    def test_basic_parsing(self):
        content = textwrap.dedent("""\
            # F-0100: Test Epic

            ## Acceptance Criteria

            - [ ] **AC-001**: Feature must do X
            - [ ] **AC-002**: Feature must do Y
            - [ ] **AC-003**: Feature must do Z
        """)
        groups = _parse_ac_groups(content)
        assert len(groups) == 3
        assert groups[0][0] == "AC-001"
        assert groups[0][1] == "Feature must do X"
        assert groups[1][0] == "AC-002"
        assert groups[2][0] == "AC-003"

    def test_multiline_ac(self):
        content = textwrap.dedent("""\
            - [ ] **AC-001**: Feature must handle auth
            Some extra detail about auth
            - [ ] **AC-002**: Feature must handle payments
        """)
        groups = _parse_ac_groups(content)
        assert len(groups) == 2
        assert len(groups[0][2]) == 2  # AC line + extra detail
        assert "extra detail" in groups[0][2][1]

    def test_no_ac_markers(self):
        content = "Just some prose without AC markers."
        groups = _parse_ac_groups(content)
        assert len(groups) == 0

    def test_single_ac(self):
        content = "- [ ] **AC-001**: The only criterion"
        groups = _parse_ac_groups(content)
        assert len(groups) == 1


# ---------------------------------------------------------------------------
# _derive_child_name tests
# ---------------------------------------------------------------------------

class TestDeriveChildName:
    def test_basic_name(self):
        name = _derive_child_name("AC-001", "User authentication works", "F-0100")
        assert name == "User authentication works"

    def test_strips_verbs(self):
        name = _derive_child_name("AC-001", "shall handle login requests", "F-0100")
        assert name == "Handle login requests"

    def test_truncates_long_names(self):
        long_text = "A" * 100
        name = _derive_child_name("AC-001", long_text, "F-0100")
        assert len(name) <= 60

    def test_empty_text_fallback(self):
        name = _derive_child_name("AC-001", "", "F-0100")
        assert "F-0100" in name
        assert "AC-001" in name


# ---------------------------------------------------------------------------
# get_next_feature_id tests
# ---------------------------------------------------------------------------

class TestGetNextFeatureId:
    def test_with_existing_features(self, tmp_project):
        features_file = _write_features(tmp_project, textwrap.dedent("""\
            ## F-0001: First
            **Status**: shipped

            ## F-0005: Fifth
            **Status**: planned
        """))
        assert get_next_feature_id(features_file) == 6

    def test_nonexistent_file(self, tmp_path):
        assert get_next_feature_id(tmp_path / "nonexistent.md") == 1


# ---------------------------------------------------------------------------
# _get_feature_status / _get_feature_parent tests
# ---------------------------------------------------------------------------

class TestFeatureHelpers:
    def test_get_status(self, tmp_project):
        features_file = _write_features(tmp_project, textwrap.dedent("""\
            ## F-0100: Epic
            **Status**: planned
        """))
        assert _get_feature_status(features_file, "F-0100") == "planned"

    def test_get_status_not_found(self, tmp_project):
        features_file = _write_features(tmp_project, "## F-0001: Other\n**Status**: shipped\n")
        assert _get_feature_status(features_file, "F-9999") is None

    def test_get_parent(self, tmp_project):
        features_file = _write_features(tmp_project, textwrap.dedent("""\
            ## F-0010: Child
            **Status**: planned
            **Parent**: F-0001
        """))
        assert _get_feature_parent(features_file, "F-0010") == "F-0001"

    def test_get_parent_none(self, tmp_project):
        features_file = _write_features(tmp_project, textwrap.dedent("""\
            ## F-0010: NoParent
            **Status**: planned
        """))
        assert _get_feature_parent(features_file, "F-0010") is None

    def test_get_children_statuses(self, tmp_project):
        features_file = _write_features(tmp_project, textwrap.dedent("""\
            ## F-0100: Epic
            **Status**: planned

            ## F-0101: Child A
            **Status**: implementing
            **Parent**: F-0100

            ## F-0102: Child B
            **Status**: shipped
            **Parent**: F-0100

            ## F-0200: Unrelated
            **Status**: planned
        """))
        statuses = _get_children_statuses(features_file, "F-0100")
        assert sorted(statuses) == ["implementing", "shipped"]


# ---------------------------------------------------------------------------
# propose_decomposition tests (AC-001, AC-002)
# ---------------------------------------------------------------------------

class TestProposeDecomposition:
    def test_basic_decomposition(self, tmp_project):
        _write_features(tmp_project, textwrap.dedent("""\
            ## F-0100: Test Epic
            **Status**: planned
        """))
        _write_ac(tmp_project, "F-0100", textwrap.dedent("""\
            # F-0100: Test Epic

            ## Acceptance Criteria

            - [ ] **AC-001**: Handle user registration
            - [ ] **AC-002**: Handle login flow
            - [ ] **AC-003**: Handle password reset
        """))

        children = propose_decomposition(tmp_project, "F-0100")
        assert len(children) == 3
        assert children[0]["parent"] == "F-0100"
        # Children now get dotted IDs: F-0100.1, F-0100.2, F-0100.3
        assert children[0]["id"] == "F-0100.1"
        assert children[1]["id"] == "F-0100.2"
        assert children[2]["id"] == "F-0100.3"

    def test_no_ac_file_raises(self, tmp_project):
        _write_features(tmp_project, "## F-0100: Epic\n**Status**: planned\n")
        with pytest.raises(FileNotFoundError):
            propose_decomposition(tmp_project, "F-0100")

    def test_empty_ac_raises(self, tmp_project):
        _write_features(tmp_project, "## F-0100: Epic\n**Status**: planned\n")
        _write_ac(tmp_project, "F-0100", "Just prose, no AC markers.")
        with pytest.raises(ValueError, match="No AC-NNN"):
            propose_decomposition(tmp_project, "F-0100")

    def test_without_components(self, tmp_project):
        """Decomposition works even without component registry."""
        _write_features(tmp_project, "## F-0100: Epic\n**Status**: planned\n")
        _write_ac(tmp_project, "F-0100", "- [ ] **AC-001**: Something\n")
        children = propose_decomposition(tmp_project, "F-0100")
        assert len(children) == 1
        assert children[0]["component"] is None

    def test_with_components(self, tmp_project):
        """Components are matched by keyword overlap."""
        # Add components to STACK.md
        (tmp_project / "STACK.md").write_text(textwrap.dedent("""\
            # Stack

            ## Settings
            - profile: formal
            - review_decomposition: skip

            ## Components
            | name | path | type | test_command |
            |------|------|------|--------------|
            | api | packages/api | python | pytest |
            | web | packages/web | typescript | npm test |
        """))
        _write_features(tmp_project, "## F-0100: Epic\n**Status**: planned\n")
        _write_ac(tmp_project, "F-0100", textwrap.dedent("""\
            - [ ] **AC-001**: The api must handle auth requests
            - [ ] **AC-002**: The web must show login form
        """))
        children = propose_decomposition(tmp_project, "F-0100")
        assert len(children) == 2
        assert children[0]["component"] == "api"
        assert children[1]["component"] == "web"


# ---------------------------------------------------------------------------
# create_child_features tests (AC-004, AC-008)
# ---------------------------------------------------------------------------

class TestCreateChildFeatures:
    def test_appends_to_features_md(self, tmp_project):
        features_file = _write_features(tmp_project, textwrap.dedent("""\
            ## F-0100: Test Epic
            **Status**: planned
            **Category**: Core
        """))
        children = [
            {
                "id": "F-0101",
                "name": "Child A",
                "parent": "F-0100",
                "component": None,
                "ac_lines": ["- [ ] **AC-001**: Do thing A"],
            },
            {
                "id": "F-0102",
                "name": "Child B",
                "parent": "F-0100",
                "component": "api",
                "ac_lines": ["- [ ] **AC-002**: Do thing B"],
            },
        ]
        success, msgs = create_child_features(tmp_project, "F-0100", children)
        assert success

        content = features_file.read_text()
        assert "## F-0101: Child A" in content
        assert "## F-0102: Child B" in content
        assert "**Parent**: F-0100" in content
        assert "**Component**: api" in content

    def test_creates_contract_files(self, tmp_project):
        _write_features(tmp_project, "## F-0100: Epic\n**Status**: planned\n")
        contracts_dir = tmp_project / ".agentic" / "spec" / "contracts"
        contracts_dir.mkdir(parents=True, exist_ok=True)
        children = [{
            "id": "F-0101",
            "name": "Child",
            "parent": "F-0100",
            "component": None,
            "ac_lines": ["- [ ] **AC-001**: Test criterion"],
        }]
        create_child_features(tmp_project, "F-0100", children)

        contract_file = contracts_dir / "F-0101.yaml"
        assert contract_file.exists()
        content = contract_file.read_text()
        assert "F-0100" in content  # parent reference
        assert "Test criterion" in content

    def test_inherits_parent_category(self, tmp_project):
        _write_features(tmp_project, textwrap.dedent("""\
            ## F-0100: Epic
            **Status**: planned
            **Category**: Quality
        """))
        children = [{
            "id": "F-0101",
            "name": "Child",
            "parent": "F-0100",
            "component": None,
            "ac_lines": ["- [ ] **AC-001**: Test thing"],
        }]
        create_child_features(tmp_project, "F-0100", children)

        content = (tmp_project / ".agentic" / "spec" / "FEATURES.md").read_text()
        assert "**Category**: Quality" in content.split("## F-0101")[1]

    def test_component_scoped_contract(self, tmp_project):
        _write_features(tmp_project, "## F-0100: Epic\n**Status**: planned\n")
        contracts_dir = tmp_project / ".agentic" / "spec" / "contracts"
        contracts_dir.mkdir(parents=True, exist_ok=True)
        children = [{
            "id": "F-0100.1",
            "name": "API Child",
            "parent": "F-0100",
            "component": "api",
            "ac_lines": ["- [ ] **AC-001**: API must authenticate"],
        }]
        create_child_features(tmp_project, "F-0100", children)

        contract_file = contracts_dir / "F-0100.1.yaml"
        import yaml
        data = yaml.safe_load(contract_file.read_text())
        assert data.get("component") == "api"


# ---------------------------------------------------------------------------
# decompose tests (AC-003)
# ---------------------------------------------------------------------------

class TestDecompose:
    def _setup_epic(self, tmp_project):
        """Set up a basic decomposable epic."""
        _write_features(tmp_project, textwrap.dedent("""\
            ## F-0100: Test Epic
            **Status**: planned
        """))
        _write_ac(tmp_project, "F-0100", textwrap.dedent("""\
            # F-0100: Test Epic

            ## Acceptance Criteria

            - [ ] **AC-001**: Handle registration
            - [ ] **AC-002**: Handle login
        """))

    def test_basic_decompose(self, tmp_project):
        self._setup_epic(tmp_project)
        success, msgs = decompose(tmp_project, "F-0100")
        assert success
        assert any("Created 2 child features" in m for m in msgs)

    def test_wrong_state_blocks(self, tmp_project):
        _write_features(tmp_project, "## F-0100: Epic\n**Status**: implementing\n")
        _write_ac(tmp_project, "F-0100", "- [ ] **AC-001**: X\n")
        success, msgs = decompose(tmp_project, "F-0100")
        assert not success
        assert any("implementing" in m for m in msgs)

    def test_criteria_set_state_allowed(self, tmp_project):
        """Features in criteria_set state can be decomposed."""
        _write_features(tmp_project, "## F-0100: Epic\n**Status**: criteria_set\n")
        _write_ac(tmp_project, "F-0100", "- [ ] **AC-001**: Thing\n")
        success, msgs = decompose(tmp_project, "F-0100")
        assert success

    def test_missing_feature_blocks(self, tmp_project):
        _write_features(tmp_project, "## F-0001: Other\n**Status**: planned\n")
        success, msgs = decompose(tmp_project, "F-9999")
        assert not success
        assert any("not found" in m for m in msgs)

    def test_missing_ac_blocks(self, tmp_project):
        _write_features(tmp_project, "## F-0100: Epic\n**Status**: planned\n")
        success, msgs = decompose(tmp_project, "F-0100")
        assert not success
        assert any("acceptance criteria" in m.lower() for m in msgs)

    def test_idempotency_blocks_without_force(self, tmp_project):
        self._setup_epic(tmp_project)
        # First decompose
        decompose(tmp_project, "F-0100")
        # Second decompose should fail
        success, msgs = decompose(tmp_project, "F-0100")
        assert not success
        assert any("already has" in m for m in msgs)

    def test_idempotency_allows_with_force(self, tmp_project):
        self._setup_epic(tmp_project)
        decompose(tmp_project, "F-0100")
        success, msgs = decompose(tmp_project, "F-0100", force=True)
        assert success

    def test_human_review_blocks(self, tmp_project):
        """When review_decomposition=human, decompose prints proposal but doesn't create."""
        (tmp_project / "STACK.md").write_text(textwrap.dedent("""\
            # Stack
            ## Settings
            - profile: formal
            - review_decomposition: human
        """))
        self._setup_epic(tmp_project)
        success, msgs = decompose(tmp_project, "F-0100")
        assert success  # Returns True (proposal printed, not an error)
        assert any("--confirm" in m for m in msgs)
        # Children should NOT be created
        features = (tmp_project / ".agentic" / "spec" / "FEATURES.md").read_text()
        assert "F-0100.1" not in features

    def test_human_review_confirm_creates(self, tmp_project):
        """With --confirm, children are created even in human review mode."""
        (tmp_project / "STACK.md").write_text(textwrap.dedent("""\
            # Stack
            ## Settings
            - profile: formal
            - review_decomposition: human
        """))
        self._setup_epic(tmp_project)
        success, msgs = decompose(tmp_project, "F-0100", confirm=True)
        assert success
        assert any("Created" in m for m in msgs)


# ---------------------------------------------------------------------------
# recompute_epic_status tests (AC-006)
# ---------------------------------------------------------------------------

class TestRecomputeEpicStatus:
    def test_no_children_returns_false(self, tmp_project):
        _write_features(tmp_project, "## F-0100: Epic\n**Status**: planned\n")
        changed, msgs = recompute_epic_status(tmp_project, "F-0100")
        assert not changed

    def test_depth_guard(self, tmp_project):
        _write_features(tmp_project, "## F-0100: Epic\n**Status**: planned\n")
        changed, msgs = recompute_epic_status(tmp_project, "F-0100", _depth=3)
        assert not changed
        assert any("Max depth" in m for m in msgs)

    def test_recomputes_when_children_change(self, tmp_project):
        _write_features(tmp_project, textwrap.dedent("""\
            ## F-0100: Epic
            **Status**: planned

            ## F-0101: Child A
            **Status**: shipped
            **Parent**: F-0100

            ## F-0102: Child B
            **Status**: shipped
            **Parent**: F-0100
        """))
        changed, msgs = recompute_epic_status(tmp_project, "F-0100")
        assert changed
        assert any("shipped" in m for m in msgs)

    def test_no_change_when_status_matches(self, tmp_project):
        _write_features(tmp_project, textwrap.dedent("""\
            ## F-0100: Epic
            **Status**: implementing

            ## F-0101: Child A
            **Status**: implementing
            **Parent**: F-0100
        """))
        changed, msgs = recompute_epic_status(tmp_project, "F-0100")
        assert not changed


# ---------------------------------------------------------------------------
# Integration: parent-child wiring (AC-004, AC-007)
# ---------------------------------------------------------------------------

class TestParentChildWiring:
    def test_children_have_parent_field(self, tmp_project):
        """Created children link back to parent via Parent field."""
        _write_features(tmp_project, "## F-0100: Epic\n**Status**: planned\n")
        _write_ac(tmp_project, "F-0100", "- [ ] **AC-001**: Do X\n- [ ] **AC-002**: Do Y\n")
        decompose(tmp_project, "F-0100")

        features_file = tmp_project / ".agentic" / "spec" / "FEATURES.md"
        # Children now get dotted IDs
        parent_1 = _get_feature_parent(features_file, "F-0100.1")
        parent_2 = _get_feature_parent(features_file, "F-0100.2")
        assert parent_1 == "F-0100"
        assert parent_2 == "F-0100"

    def test_query_children_works(self, tmp_project):
        """get_children finds created children."""
        _write_features(tmp_project, "## F-0100: Epic\n**Status**: planned\n")
        _write_ac(tmp_project, "F-0100", "- [ ] **AC-001**: X\n- [ ] **AC-002**: Y\n")
        decompose(tmp_project, "F-0100")

        features_file = tmp_project / ".agentic" / "spec" / "FEATURES.md"
        statuses = _get_children_statuses(features_file, "F-0100")
        assert len(statuses) == 2
        assert all(s == "planned" for s in statuses)


# ---------------------------------------------------------------------------
# _build_child_contract tests (F-0302)
# ---------------------------------------------------------------------------

class TestBuildChildContract:
    def test_produces_valid_yaml(self):
        """Contract output should be parseable YAML with correct schema."""
        import yaml
        child = {
            "id": "F-0201",
            "name": "Auth Subsystem",
            "ac_lines": [
                '- [ ] **AC-001**: Users can log in',
                '- [ ] **AC-002**: Tokens expire after 1h',
            ],
        }
        content = _build_child_contract(child, "F-0200")
        data = yaml.safe_load(content)
        assert data["id"] == "F-0201"
        assert data["name"] == "Auth Subsystem"
        assert data["lifecycle"] == "exploring"
        assert data["parent"] == "F-0200"
        assert len(data["assertions"]) == 2

    def test_assertion_fields(self):
        """Each assertion should have id, text, and valid type."""
        import yaml
        child = {
            "id": "F-0301",
            "name": "Test Feature",
            "ac_lines": ['- [ ] **AC-001**: Something works'],
        }
        content = _build_child_contract(child, "F-0300")
        data = yaml.safe_load(content)
        a = data["assertions"][0]
        assert a["id"] == "AC-001"
        assert a["text"] == "Something works"
        assert a["type"] in ("structural", "behavioral")

    def test_plain_text_ac_lines(self):
        """AC lines without **AC-NNN** format get sequential IDs."""
        import yaml
        child = {
            "id": "F-0401",
            "name": "Plain ACs",
            "ac_lines": ['- [ ] First thing', '- [ ] Second thing'],
        }
        content = _build_child_contract(child, "F-0400")
        data = yaml.safe_load(content)
        assert data["assertions"][0]["id"] == "AC-001"
        assert data["assertions"][1]["id"] == "AC-002"

    def test_component_field_in_contract(self):
        """Component should appear as a top-level field, not tags."""
        import yaml
        child = {
            "id": "F-0501",
            "name": "API Layer",
            "component": "api",
            "ac_lines": ['- [ ] **AC-001**: Endpoint exists'],
        }
        content = _build_child_contract(child, "F-0500")
        data = yaml.safe_load(content)
        assert data.get("component") == "api"
        assert "tags" not in data  # component replaced tags pattern

    def test_no_component_omits_field(self):
        """Without component, neither component nor tags should appear."""
        import yaml
        child = {
            "id": "F-0601",
            "name": "Generic Feature",
            "ac_lines": ['- [ ] **AC-001**: Works'],
        }
        content = _build_child_contract(child, "F-0600")
        data = yaml.safe_load(content)
        assert "component" not in data
        assert "tags" not in data


# ---------------------------------------------------------------------------
# Dotted ID decomposition tests (Phase 1b)
# ---------------------------------------------------------------------------

class TestDottedIdDecomposition:
    """Verify decomposition produces dotted child IDs (F-XXX.1, F-XXX.2)."""

    def test_children_get_dotted_ids(self, tmp_project):
        """Decompose creates children with dotted IDs under parent."""
        _write_features(tmp_project, "## F-0100: Epic\n**Status**: planned\n")
        _write_ac(tmp_project, "F-0100", textwrap.dedent("""\
            - [ ] **AC-001**: Handle auth
            - [ ] **AC-002**: Handle payments
        """))
        children = propose_decomposition(tmp_project, "F-0100")
        assert children[0]["id"] == "F-0100.1"
        assert children[1]["id"] == "F-0100.2"
        assert all(c["parent"] == "F-0100" for c in children)

    def test_existing_children_skipped(self, tmp_project):
        """When parent already has children, new ones get the next number."""
        _write_features(tmp_project, textwrap.dedent("""\
            ## F-0100: Epic
            **Status**: planned

            ## F-0100.1: Existing Child
            **Status**: implementing
            **Parent**: F-0100
        """))
        _write_ac(tmp_project, "F-0100", textwrap.dedent("""\
            - [ ] **AC-001**: New thing A
            - [ ] **AC-002**: New thing B
        """))
        children = propose_decomposition(tmp_project, "F-0100")
        # Should start at .2 since .1 already exists
        assert children[0]["id"] == "F-0100.2"
        assert children[1]["id"] == "F-0100.3"

    def test_decompose_child_creates_grandchildren(self, tmp_project):
        """Decomposing a child (depth 1) creates grandchildren (depth 2)."""
        _write_features(tmp_project, textwrap.dedent("""\
            ## F-0100: Epic
            **Status**: planned

            ## F-0100.1: Child Feature
            **Status**: planned
            **Parent**: F-0100
        """))
        _write_ac(tmp_project, "F-0100.1", textwrap.dedent("""\
            - [ ] **AC-001**: Sub-thing A
            - [ ] **AC-002**: Sub-thing B
        """))
        children = propose_decomposition(tmp_project, "F-0100.1")
        assert children[0]["id"] == "F-0100.1.1"
        assert children[1]["id"] == "F-0100.1.2"
        assert all(c["parent"] == "F-0100.1" for c in children)

    def test_contract_files_use_dotted_names(self, tmp_project):
        """Contract YAML files are named with dotted IDs (F-0100.1.yaml)."""
        _write_features(tmp_project, "## F-0100: Epic\n**Status**: planned\n")
        contracts_dir = tmp_project / ".agentic" / "spec" / "contracts"
        contracts_dir.mkdir(parents=True, exist_ok=True)
        _write_ac(tmp_project, "F-0100", "- [ ] **AC-001**: Thing\n")
        decompose(tmp_project, "F-0100")

        assert (contracts_dir / "F-0100.1.yaml").exists()


# ---------------------------------------------------------------------------
# Depth guard tests (Phase 1b)
# ---------------------------------------------------------------------------

class TestDepthGuard:
    """Verify decomposition respects MAX_DEPTH limit."""

    def test_cannot_decompose_at_max_depth(self, tmp_project):
        """Features at MAX_DEPTH cannot be decomposed further."""
        # F-0100.1.2 is depth 2 (= MAX_DEPTH)
        _write_features(tmp_project, textwrap.dedent("""\
            ## F-0100: Root
            **Status**: planned

            ## F-0100.1: Child
            **Status**: planned
            **Parent**: F-0100

            ## F-0100.1.2: Grandchild
            **Status**: planned
            **Parent**: F-0100.1
        """))
        _write_ac(tmp_project, "F-0100.1.2", "- [ ] **AC-001**: Deep thing\n")
        success, msgs = decompose(tmp_project, "F-0100.1.2")
        assert not success
        assert any("depth" in m.lower() for m in msgs)

    def test_can_decompose_at_depth_1(self, tmp_project):
        """Children (depth 1) can still be decomposed into grandchildren."""
        _write_features(tmp_project, textwrap.dedent("""\
            ## F-0100: Root
            **Status**: planned

            ## F-0100.1: Child
            **Status**: planned
            **Parent**: F-0100
        """))
        _write_ac(tmp_project, "F-0100.1", "- [ ] **AC-001**: Sub-thing\n")
        success, msgs = decompose(tmp_project, "F-0100.1")
        assert success

    def test_root_can_decompose(self, tmp_project):
        """Root features (depth 0) can be decomposed."""
        _write_features(tmp_project, "## F-0100: Root\n**Status**: planned\n")
        _write_ac(tmp_project, "F-0100", "- [ ] **AC-001**: Thing\n")
        success, msgs = decompose(tmp_project, "F-0100")
        assert success


# ---------------------------------------------------------------------------
# extract_subfeature tests (Phase 1b)
# ---------------------------------------------------------------------------

def _write_contract(tmp_project, feature_id, content):
    """Write a contract YAML file."""
    contracts_dir = tmp_project / ".agentic" / "spec" / "contracts"
    contracts_dir.mkdir(parents=True, exist_ok=True)
    contract_file = contracts_dir / f"{feature_id}.yaml"
    contract_file.write_text(content)
    return contract_file


class TestExtractSubfeature:
    """Tests for extracting specific ACs from parent into a new child."""

    def test_basic_extraction(self, tmp_project):
        """Extract ACs from parent → creates child with dotted ID."""
        _write_features(tmp_project, "## F-0100: Epic\n**Status**: planned\n")
        _write_contract(tmp_project, "F-0100", textwrap.dedent("""\
            id: F-0100
            name: Test Epic
            lifecycle: planned
            description: An epic feature.
            assertions:
              - id: AC-001
                text: Handle registration
                type: behavioral
              - id: AC-002
                text: Handle login
                type: behavioral
              - id: AC-003
                text: Handle password reset
                type: behavioral
        """))

        success, msgs = extract_subfeature(
            tmp_project, "F-0100", ["AC-001", "AC-002"],
            child_name="Auth Subsystem",
        )
        assert success
        assert any("F-0100.1" in m for m in msgs)
        assert any("2 ACs" in m for m in msgs)

        # Child contract should exist
        import yaml
        child_file = tmp_project / ".agentic" / "spec" / "contracts" / "F-0100.1.yaml"
        assert child_file.exists()
        child_data = yaml.safe_load(child_file.read_text())
        assert child_data["parent"] == "F-0100"
        assert len(child_data["assertions"]) == 2

        # Parent should retain only AC-003
        parent_data = yaml.safe_load(
            (tmp_project / ".agentic" / "spec" / "contracts" / "F-0100.yaml").read_text()
        )
        assert len(parent_data["assertions"]) == 1
        assert parent_data["assertions"][0]["id"] == "AC-003"

    def test_parent_children_list_updated(self, tmp_project):
        """Parent's children field is updated after extraction."""
        _write_features(tmp_project, "## F-0100: Epic\n**Status**: planned\n")
        _write_contract(tmp_project, "F-0100", textwrap.dedent("""\
            id: F-0100
            name: Test Epic
            lifecycle: planned
            description: An epic feature.
            assertions:
              - id: AC-001
                text: Thing A
                type: behavioral
              - id: AC-002
                text: Thing B
                type: behavioral
        """))

        extract_subfeature(tmp_project, "F-0100", ["AC-001"])

        import yaml
        parent_data = yaml.safe_load(
            (tmp_project / ".agentic" / "spec" / "contracts" / "F-0100.yaml").read_text()
        )
        assert "F-0100.1" in parent_data.get("children", [])

    def test_missing_ac_fails(self, tmp_project):
        """Requesting a non-existent AC ID fails."""
        _write_features(tmp_project, "## F-0100: Epic\n**Status**: planned\n")
        _write_contract(tmp_project, "F-0100", textwrap.dedent("""\
            id: F-0100
            name: Test Epic
            lifecycle: planned
            description: An epic.
            assertions:
              - id: AC-001
                text: Only assertion
                type: behavioral
        """))

        success, msgs = extract_subfeature(
            tmp_project, "F-0100", ["AC-001", "AC-999"],
        )
        assert not success
        assert any("AC-999" in m for m in msgs)

    def test_shipped_state_blocks_extraction(self, tmp_project):
        """Cannot extract ACs from a shipped feature."""
        _write_features(tmp_project, "## F-0100: Epic\n**Status**: shipped\n")
        _write_contract(tmp_project, "F-0100", textwrap.dedent("""\
            id: F-0100
            name: Test Epic
            lifecycle: shipped
            description: Shipped epic.
            assertions:
              - id: AC-001
                text: Something
                type: behavioral
        """))

        success, msgs = extract_subfeature(tmp_project, "F-0100", ["AC-001"])
        assert not success
        assert any("shipped" in m for m in msgs)

    def test_depth_guard_blocks_extraction(self, tmp_project):
        """Cannot extract from a grandchild (depth 2)."""
        _write_features(tmp_project, textwrap.dedent("""\
            ## F-0100: Root
            **Status**: planned

            ## F-0100.1.2: Grandchild
            **Status**: planned
            **Parent**: F-0100.1
        """))
        _write_contract(tmp_project, "F-0100.1.2", textwrap.dedent("""\
            id: F-0100.1.2
            name: Grandchild
            lifecycle: planned
            description: Deep feature.
            parent: F-0100.1
            assertions:
              - id: AC-001
                text: Deep thing
                type: behavioral
        """))

        success, msgs = extract_subfeature(
            tmp_project, "F-0100.1.2", ["AC-001"],
        )
        assert not success
        assert any("depth" in m.lower() for m in msgs)

    def test_auto_derives_name(self, tmp_project):
        """Without explicit name, derives from first extracted AC."""
        _write_features(tmp_project, "## F-0100: Epic\n**Status**: planned\n")
        _write_contract(tmp_project, "F-0100", textwrap.dedent("""\
            id: F-0100
            name: Test Epic
            lifecycle: planned
            description: Epic.
            assertions:
              - id: AC-001
                text: Handle user authentication
                type: behavioral
              - id: AC-002
                text: Something else
                type: behavioral
        """))

        success, msgs = extract_subfeature(tmp_project, "F-0100", ["AC-001"])
        assert success

        import yaml
        child_data = yaml.safe_load(
            (tmp_project / ".agentic" / "spec" / "contracts" / "F-0100.1.yaml").read_text()
        )
        assert "authentication" in child_data["name"].lower() or "Handle" in child_data["name"]

    def test_sequential_extractions(self, tmp_project):
        """Multiple extractions get sequential dotted IDs."""
        _write_features(tmp_project, "## F-0100: Epic\n**Status**: planned\n")
        _write_contract(tmp_project, "F-0100", textwrap.dedent("""\
            id: F-0100
            name: Test Epic
            lifecycle: planned
            description: Epic.
            assertions:
              - id: AC-001
                text: Thing A
                type: behavioral
              - id: AC-002
                text: Thing B
                type: behavioral
              - id: AC-003
                text: Thing C
                type: behavioral
        """))

        # First extraction
        success1, _ = extract_subfeature(
            tmp_project, "F-0100", ["AC-001"], child_name="First Child",
        )
        assert success1

        # Second extraction
        success2, msgs2 = extract_subfeature(
            tmp_project, "F-0100", ["AC-002"], child_name="Second Child",
        )
        assert success2
        assert any("F-0100.2" in m for m in msgs2)

        contracts_dir = tmp_project / ".agentic" / "spec" / "contracts"
        assert (contracts_dir / "F-0100.1.yaml").exists()
        assert (contracts_dir / "F-0100.2.yaml").exists()
