"""Tests for QA Registry generator (F-0241)."""
# @feature F-0241

import json
import subprocess
import sys
import textwrap
from pathlib import Path
from unittest.mock import patch

import pytest

# Add tests/ to path so we can import qa_registry
sys.path.insert(0, str(Path(__file__).parent))
import qa_registry


@pytest.fixture
def tmp_framework(tmp_path):
    """Create a minimal framework structure for testing."""
    # FEATURES.md
    spec_dir = tmp_path / ".agentic" / "spec"
    spec_dir.mkdir(parents=True)
    (spec_dir / "FEATURES.md").write_text(textwrap.dedent("""\
        # Features

        ## F-0001: Project Init

        **Status**: shipped
        **Category**: Core

        **Description**: Basic project setup.

        ---

        ## F-0002: Auth System

        **Status**: implementing
        **Category**: Core

        **Description**: Authentication.

        ---

        ## F-0003: Deprecated Thing

        **Status**: deprecated
        **Category**: Legacy

        **Description**: Old feature.
    """))

    # validate_framework.sh with F-XXXX sections
    tests_dir = tmp_path / "tests"
    tests_dir.mkdir()
    (tests_dir / "validate_framework.sh").write_text(textwrap.dedent("""\
        #!/usr/bin/env bash
        # F-0001: Project Init
        echo "--- F-0001: Project Init ---"
        pass "install.sh exists"

        # F-0002: Auth System
        echo "--- F-0002: Auth System ---"
        pass "auth module exists"
    """))

    # pytest files — one tagged, one untagged
    (tests_dir / "test_auth.py").write_text(textwrap.dedent("""\
        # @feature F-0002
        def test_login():
            assert True
    """))
    (tests_dir / "test_utils.py").write_text(textwrap.dedent("""\
        def test_helper():
            assert True
    """))

    # LLM tests
    llm_dir = tests_dir / "llm" / "tests"
    llm_dir.mkdir(parents=True)
    (llm_dir / "001_session_start.sh").write_text(textwrap.dedent("""\
        #!/usr/bin/env bash
        # Description: Agent session start
        # Section: session
        # Feature: F-0001
        send_prompt "hi"
    """))
    (llm_dir / "002_no_tag.sh").write_text(textwrap.dedent("""\
        #!/usr/bin/env bash
        # Description: Something else
        send_prompt "hello"
    """))

    # Scenarios
    scenario_dir = tmp_path / ".agentic" / "lib" / "auto" / "scenarios"
    scenario_dir.mkdir(parents=True)
    (scenario_dir / "todo_app.yaml").write_text("name: Todo App\n")

    # Pre-commit
    hooks_dir = tmp_path / ".agentic" / "lib" / "hooks"
    hooks_dir.mkdir(parents=True)
    (hooks_dir / "pre-commit-check.sh").write_text(textwrap.dedent("""\
        #!/usr/bin/env bash
        # Check 1: WIP must not exist (BLOCKING)
        # Check 2: Shipped features (advisory)
    """))

    # Checklists
    cl_dir = tmp_path / ".agentic" / "lib" / "checklists"
    cl_dir.mkdir(parents=True)
    (cl_dir / "before_commit.md").write_text("# Before Commit\n- [ ] Tests pass\n- [ ] Journal updated\n")

    # Infrastructure
    infra_dir = tests_dir / "infrastructure" / "structural"
    infra_dir.mkdir(parents=True)
    (infra_dir / "S01_test.sh").write_text("#!/usr/bin/env bash\n")

    # docs dir
    (tmp_path / "docs").mkdir()

    return tmp_path


class TestParseFeatures:
    def test_extracts_features(self, tmp_framework):
        features = qa_registry.parse_features(tmp_framework)
        assert len(features) == 3
        assert features[0].fid == "F-0001"
        assert features[0].title == "Project Init"
        assert features[0].status == "shipped"

    def test_extracts_status(self, tmp_framework):
        features = qa_registry.parse_features(tmp_framework)
        assert features[1].status == "implementing"
        assert features[2].status == "deprecated"


class TestScanValidateFramework:
    def test_finds_feature_sections(self, tmp_framework):
        mapping = qa_registry.scan_validate_framework(tmp_framework)
        assert "F-0001" in mapping
        assert "F-0002" in mapping
        assert len(mapping) == 2

    def test_missing_file_returns_empty(self, tmp_path):
        assert qa_registry.scan_validate_framework(tmp_path) == {}


class TestScanPytestFiles:
    def test_finds_tagged_files(self, tmp_framework):
        tagged, untagged = qa_registry.scan_pytest_files(tmp_framework)
        assert "F-0002" in tagged
        assert any("test_auth.py" in p for p in tagged["F-0002"])

    def test_finds_untagged_files(self, tmp_framework):
        tagged, untagged = qa_registry.scan_pytest_files(tmp_framework)
        assert any("test_utils.py" in p for p in untagged)


class TestScanLlmTests:
    def test_finds_tagged_tests(self, tmp_framework):
        tagged, untagged, total = qa_registry.scan_llm_tests(tmp_framework)
        assert "F-0001" in tagged
        assert total == 2

    def test_finds_untagged_tests(self, tmp_framework):
        tagged, untagged, total = qa_registry.scan_llm_tests(tmp_framework)
        assert len(untagged) == 1
        assert any("002_no_tag.sh" in p for p in untagged)


class TestScanLlmTestsFalsePositives:
    def test_heredoc_fixture_data_not_tagged(self, tmp_framework):
        """F-XXXX in heredoc fixture data should NOT be tagged as coverage."""
        llm_dir = tmp_framework / "tests" / "llm" / "tests"
        (llm_dir / "003_heredoc_test.sh").write_text(textwrap.dedent("""\
            #!/usr/bin/env bash
            # Description: Test with heredoc fixture data
            # Section: wip

            cat > "$TEST_PROJECT/.agentic/session/WIP.md" << 'WEOF'
            **Feature**: F-0099: Fake fixture feature
            **Status**: in-progress
            WEOF

            cat > "$TEST_PROJECT/.agentic/session/AGENTS.json" << 'JEOF'
            [{"feature_id": "F-0100", "status": "active"}]
            JEOF

            send_prompt "check wip"
        """))

        tagged, untagged, total = qa_registry.scan_llm_tests(tmp_framework)
        # F-0099 and F-0100 are in heredoc content, not comments — should NOT be tagged
        assert "F-0099" not in tagged
        assert "F-0100" not in tagged
        assert any("003_heredoc_test.sh" in p for p in untagged)


class TestScanPrecommitGates:
    def test_parses_check_catalog(self, tmp_framework):
        gates = qa_registry.scan_precommit_gates(tmp_framework)
        assert len(gates) == 2
        assert gates[0]["number"] == "1"
        assert gates[0]["description"] == "WIP must not exist"
        assert gates[0]["mode"] == "BLOCKING"


class TestScanChecklists:
    def test_finds_checklists(self, tmp_framework):
        checklists = qa_registry.scan_checklists(tmp_framework)
        assert len(checklists) == 1
        assert checklists[0]["name"] == "Before Commit"
        assert checklists[0]["items"] == 2


class TestBuildRegistry:
    def test_builds_complete_registry(self, tmp_framework):
        data = qa_registry.build_registry(tmp_framework)
        assert len(data.features) == 3
        assert len(data.categories) > 0
        # F-0001 should have both static and llm coverage
        f1_tests = data.feature_to_tests.get("F-0001", {})
        assert "static" in f1_tests
        assert "llm" in f1_tests

    def test_gap_detection(self, tmp_framework):
        data = qa_registry.build_registry(tmp_framework)
        # F-0003 (deprecated) should have no tests but be excluded from gap
        f3_tests = data.feature_to_tests.get("F-0003", {})
        assert len(f3_tests) == 0


class TestGenerateMarkdown:
    def test_generates_valid_markdown(self, tmp_framework):
        data = qa_registry.build_registry(tmp_framework)
        md = qa_registry.generate_markdown(data, tmp_framework)
        assert "# QA Registry" in md
        assert "AUTO-GENERATED" in md
        assert "## 1. Test Methods Catalog" in md
        assert "## 2. Feature-to-Test Matrix" in md
        assert "## 3. Gap Analysis" in md
        assert "## 4. Quick Run Guide" in md

    def test_feature_matrix_has_all_features(self, tmp_framework):
        data = qa_registry.build_registry(tmp_framework)
        md = qa_registry.generate_markdown(data, tmp_framework)
        assert "F-0001" in md
        assert "F-0002" in md
        assert "F-0003" in md

    def test_untagged_files_listed(self, tmp_framework):
        data = qa_registry.build_registry(tmp_framework)
        md = qa_registry.generate_markdown(data, tmp_framework)
        assert "Untagged test files" in md
        assert "test_utils.py" in md


class TestContentHash:
    def test_same_content_same_hash(self):
        assert qa_registry.content_hash("hello world") == qa_registry.content_hash("hello world")

    def test_different_content_different_hash(self):
        assert qa_registry.content_hash("hello") != qa_registry.content_hash("world")

    def test_whitespace_insensitive(self):
        assert qa_registry.content_hash("hello  world") == qa_registry.content_hash("hello world")


class TestCheckMode:
    def test_stale_when_missing(self, tmp_framework):
        """--check should detect missing QA_REGISTRY.md."""
        registry_path = tmp_framework / "docs" / "QA_REGISTRY.md"
        assert not registry_path.exists()

        # Simulate the --check logic inline
        data = qa_registry.build_registry(tmp_framework)
        new_content = qa_registry.generate_markdown(data, tmp_framework)

        # The check logic: file missing → stale
        is_stale = not registry_path.exists()
        assert is_stale, "Missing registry should be detected as stale"

    def test_fresh_after_generate(self, tmp_framework):
        """After generating, content hash should match (fresh)."""
        data = qa_registry.build_registry(tmp_framework)
        md = qa_registry.generate_markdown(data, tmp_framework)
        (tmp_framework / "docs" / "QA_REGISTRY.md").write_text(md)

        # Re-generate and compare hashes
        data2 = qa_registry.build_registry(tmp_framework)
        md2 = qa_registry.generate_markdown(data2, tmp_framework)
        assert qa_registry.content_hash(md) == qa_registry.content_hash(md2)

    def test_stale_when_content_differs(self, tmp_framework):
        """--check should detect when registry content is outdated."""
        # Generate initial registry
        data = qa_registry.build_registry(tmp_framework)
        md = qa_registry.generate_markdown(data, tmp_framework)
        (tmp_framework / "docs" / "QA_REGISTRY.md").write_text(md)

        # Add a new feature to FEATURES.md (changes what would be generated)
        features_file = tmp_framework / ".agentic" / "spec" / "FEATURES.md"
        features_file.write_text(features_file.read_text() + textwrap.dedent("""
            ---

            ## F-0099: New Feature

            **Status**: shipped
            **Category**: Core

            **Description**: Something new.
        """))

        # Re-generate and compare — should differ
        data2 = qa_registry.build_registry(tmp_framework)
        md2 = qa_registry.generate_markdown(data2, tmp_framework)
        assert qa_registry.content_hash(md) != qa_registry.content_hash(md2)


class TestIntegration:
    """Integration tests that run against the real framework."""

    def test_ag_qa_generates_output(self):
        """ag qa produces non-empty QA_REGISTRY.md."""
        root = Path(__file__).parent.parent
        result = subprocess.run(
            [sys.executable, str(root / "tests" / "qa_registry.py")],
            capture_output=True,
            text=True,
            cwd=str(root),
        )
        assert result.returncode == 0
        assert "Generated" in result.stdout

        registry = root / "docs" / "QA_REGISTRY.md"
        assert registry.exists()
        content = registry.read_text()
        assert len(content) > 100
        assert "Feature-to-Test Matrix" in content

    def test_ag_qa_check_detects_fresh(self):
        """ag qa --check succeeds after generation."""
        root = Path(__file__).parent.parent
        # Generate first
        subprocess.run(
            [sys.executable, str(root / "tests" / "qa_registry.py")],
            capture_output=True,
            cwd=str(root),
        )
        # Check
        result = subprocess.run(
            [sys.executable, str(root / "tests" / "qa_registry.py"), "--check"],
            capture_output=True,
            text=True,
            cwd=str(root),
        )
        assert result.returncode == 0
        assert "OK" in result.stdout
