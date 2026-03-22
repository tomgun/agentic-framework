#!/usr/bin/env python3
"""
Tests for the YAML contract parser and validator (F-0302).
"""
import json
import sys
import tempfile
from pathlib import Path

import pytest

# Add lib/ to path
sys.path.insert(0, str(Path(__file__).parent.parent / ".agentic" / "lib"))

from contracts import (
    Assertion,
    Contract,
    Migration,
    Scenario,
    coverage_report,
    get_contract_by_id,
    get_contracts_by_lifecycle,
    get_pending_user_input,
    lifecycle_to_status,
    load_all_contracts,
    load_contract,
    save_contract,
    validate_contract,
    validate_contract_file,
    verify_assertion,
    verify_contract,
)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def contracts_dir():
    """Create a temp directory with sample contracts."""
    with tempfile.TemporaryDirectory() as tmpdir:
        contracts = Path(tmpdir) / "contracts"
        contracts.mkdir()
        yield contracts


@pytest.fixture
def sample_contract():
    """A valid minimal contract."""
    return Contract(
        id="F-0099",
        name="Test Feature",
        lifecycle="shipped",
        description="A test feature for unit testing the contract system",
        assertions=[
            Assertion(id="AC-001", text="Something works correctly", type="structural",
                      verify="true", tests=["tests/test_foo.py"]),
            Assertion(id="AC-002", text="Behavior is correct", type="behavioral",
                      tests=["tests/test_bar.py"]),
        ],
        protection="contract",
        category="core",
        since="v0.70.0",
    )


@pytest.fixture
def draft_contract():
    """A draft/exploring contract."""
    return Contract(
        id="F-0100",
        name="Draft Feature",
        lifecycle="exploring",
        description="A feature being explored with draft assertions",
        assertions=[
            Assertion(id="AC-001", text="Maybe this works", type="structural", draft=True),
        ],
        protection="none",
    )


@pytest.fixture
def contract_with_input():
    """A contract with pending user input."""
    return Contract(
        id="F-0101",
        name="Feature With Input",
        lifecycle="shipped",
        description="A shipped feature where user wants a change",
        assertions=[
            Assertion(id="AC-001", text="Feature does the thing", type="structural",
                      verify="true"),
        ],
        protection="contract",
        user_input="Please add support for XYZ format",
    )


# ---------------------------------------------------------------------------
# Contract creation and serialization
# ---------------------------------------------------------------------------

class TestContractCreation:
    def test_from_dict_minimal(self):
        d = {
            "id": "F-0001",
            "name": "Minimal",
            "lifecycle": "exploring",
            "description": "A minimal test contract",
            "assertions": [{"id": "AC-001", "text": "It works", "type": "structural"}],
        }
        c = Contract.from_dict(d)
        assert c.id == "F-0001"
        assert c.lifecycle == "exploring"
        assert c.protection == "none"
        assert c.profile == "both"
        assert len(c.assertions) == 1

    def test_from_dict_full(self):
        d = {
            "id": "F-0003",
            "name": "Spec-Driven Development",
            "lifecycle": "shipped",
            "since": "v0.1.0",
            "profile": "formal",
            "protection": "contract",
            "category": "core-workflow",
            "description": "Full contract with all fields populated",
            "consolidated_from": ["F-0005", "F-0006"],
            "user_input": "",
            "assertions": [
                {"id": "AC-001", "text": "First criterion", "type": "structural",
                 "verify": "test -f foo", "tests": ["tests/test_a.py"]},
                {"id": "AC-002", "text": "Second criterion", "type": "behavioral"},
            ],
            "nfr_refs": ["NFR-0004"],
            "scenarios": [
                {"name": "S1", "given": "G", "when": "W", "then": "T"},
            ],
            "migrations": [
                {"id": "M-2026-03-22-001", "date": "2026-03-22",
                 "trigger": "external", "reason": "API changed",
                 "changes": ["AC-001: updated verify"]},
            ],
            "tags": ["formal-only"],
            "parent": None,
            "children": [],
        }
        c = Contract.from_dict(d)
        assert c.id == "F-0003"
        assert c.protection == "contract"
        assert len(c.assertions) == 2
        assert len(c.scenarios) == 1
        assert len(c.migrations) == 1
        assert c.consolidated_from == ["F-0005", "F-0006"]
        assert c.nfr_refs == ["NFR-0004"]
        assert c.tags == ["formal-only"]

    def test_to_dict_roundtrip(self, sample_contract):
        d = sample_contract.to_dict()
        c2 = Contract.from_dict(d)
        assert c2.id == sample_contract.id
        assert c2.name == sample_contract.name
        assert c2.lifecycle == sample_contract.lifecycle
        assert len(c2.assertions) == len(sample_contract.assertions)


# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

class TestValidation:
    def test_valid_contract(self, sample_contract):
        errors = validate_contract(sample_contract)
        assert errors == []

    def test_valid_draft(self, draft_contract):
        errors = validate_contract(draft_contract)
        assert errors == []

    def test_missing_id(self):
        c = Contract(id="", name="Test", lifecycle="exploring",
                     description="Test description here",
                     assertions=[Assertion(id="AC-001", text="Test assertion", type="structural", draft=True)])
        errors = validate_contract(c)
        assert any("id" in e.lower() for e in errors)

    def test_invalid_id_format(self):
        c = Contract(id="FEAT-01", name="Test", lifecycle="exploring",
                     description="Test description here",
                     assertions=[Assertion(id="AC-001", text="Test assertion", type="structural", draft=True)])
        errors = validate_contract(c)
        assert any("id" in e.lower() or "format" in e.lower() for e in errors)

    def test_invalid_lifecycle(self):
        c = Contract(id="F-0001", name="Test", lifecycle="bogus",
                     description="Test description here",
                     assertions=[Assertion(id="AC-001", text="Test assertion", type="structural", draft=True)])
        errors = validate_contract(c)
        assert any("lifecycle" in e.lower() for e in errors)

    def test_no_assertions(self):
        c = Contract(id="F-0001", name="Test", lifecycle="exploring",
                     description="Test description here", assertions=[])
        errors = validate_contract(c)
        assert any("assertion" in e.lower() for e in errors)

    def test_duplicate_assertion_ids(self):
        c = Contract(id="F-0001", name="Test", lifecycle="exploring",
                     description="Test description here",
                     assertions=[
                         Assertion(id="AC-001", text="First assertion", type="structural", draft=True),
                         Assertion(id="AC-001", text="Duplicate ID assertion", type="behavioral"),
                     ])
        errors = validate_contract(c)
        assert any("duplicate" in e.lower() for e in errors)

    def test_structural_without_verify_not_draft(self):
        c = Contract(id="F-0001", name="Test", lifecycle="exploring",
                     description="Test description here",
                     assertions=[
                         Assertion(id="AC-001", text="Missing verify command", type="structural"),
                     ])
        errors = validate_contract(c)
        assert any("verify" in e.lower() for e in errors)

    def test_contract_protection_requires_shipped(self):
        c = Contract(id="F-0001", name="Test", lifecycle="implementing",
                     description="Test description here",
                     protection="contract",
                     assertions=[Assertion(id="AC-001", text="Test assertion", type="structural", draft=True)])
        errors = validate_contract(c)
        assert any("shipped" in e.lower() or "protection" in e.lower() for e in errors)

    def test_short_description(self):
        c = Contract(id="F-0001", name="Test", lifecycle="exploring",
                     description="Short",
                     assertions=[Assertion(id="AC-001", text="Test assertion", type="structural", draft=True)])
        errors = validate_contract(c)
        assert any("description" in e.lower() for e in errors)


# ---------------------------------------------------------------------------
# Properties
# ---------------------------------------------------------------------------

class TestProperties:
    def test_is_shipped(self, sample_contract):
        assert sample_contract.is_shipped is True

    def test_is_not_shipped(self, draft_contract):
        assert draft_contract.is_shipped is False

    def test_is_protected(self, sample_contract):
        assert sample_contract.is_protected is True

    def test_not_protected_when_unshipped(self, draft_contract):
        assert draft_contract.is_protected is False

    def test_has_pending_input(self, contract_with_input):
        assert contract_with_input.has_pending_input is True

    def test_no_pending_input(self, sample_contract):
        assert sample_contract.has_pending_input is False

    def test_structural_assertions(self, sample_contract):
        structural = sample_contract.structural_assertions
        assert len(structural) == 1
        assert structural[0].id == "AC-001"

    def test_behavioral_assertions(self, sample_contract):
        behavioral = sample_contract.behavioral_assertions
        assert len(behavioral) == 1
        assert behavioral[0].id == "AC-002"

    def test_draft_assertions(self, draft_contract):
        drafts = draft_contract.draft_assertions
        assert len(drafts) == 1


# ---------------------------------------------------------------------------
# Save and load
# ---------------------------------------------------------------------------

class TestSaveLoad:
    def test_save_and_load(self, contracts_dir, sample_contract):
        path = contracts_dir / "F-0099.yaml"
        save_contract(sample_contract, path)
        assert path.exists()

        loaded = load_contract(path)
        assert loaded.id == "F-0099"
        assert loaded.name == "Test Feature"
        assert len(loaded.assertions) == 2

    def test_load_all(self, contracts_dir, sample_contract, draft_contract):
        save_contract(sample_contract, contracts_dir / "F-0099.yaml")
        save_contract(draft_contract, contracts_dir / "F-0100.yaml")

        all_c = load_all_contracts(contracts_dir)
        assert len(all_c) == 2

    def test_load_nonexistent_dir(self):
        result = load_all_contracts(Path("/nonexistent/path"))
        assert result == []

    def test_validate_file(self, contracts_dir, sample_contract):
        path = contracts_dir / "F-0099.yaml"
        save_contract(sample_contract, path)
        errors = validate_contract_file(path)
        assert errors == []


# ---------------------------------------------------------------------------
# Queries
# ---------------------------------------------------------------------------

class TestQueries:
    def test_get_pending_user_input(self, contracts_dir, sample_contract, contract_with_input):
        save_contract(sample_contract, contracts_dir / "F-0099.yaml")
        save_contract(contract_with_input, contracts_dir / "F-0101.yaml")

        pending = get_pending_user_input(contracts_dir)
        assert len(pending) == 1
        assert pending[0].id == "F-0101"

    def test_get_by_lifecycle(self, contracts_dir, sample_contract, draft_contract):
        save_contract(sample_contract, contracts_dir / "F-0099.yaml")
        save_contract(draft_contract, contracts_dir / "F-0100.yaml")

        shipped = get_contracts_by_lifecycle(contracts_dir, "shipped")
        assert len(shipped) == 1
        assert shipped[0].id == "F-0099"

    def test_get_by_id(self, contracts_dir, sample_contract):
        save_contract(sample_contract, contracts_dir / "F-0099.yaml")

        found = get_contract_by_id(contracts_dir, "F-0099")
        assert found is not None
        assert found.id == "F-0099"

    def test_get_by_id_not_found(self, contracts_dir):
        found = get_contract_by_id(contracts_dir, "F-9999")
        assert found is None


# ---------------------------------------------------------------------------
# Verification
# ---------------------------------------------------------------------------

class TestVerification:
    def test_verify_passing_assertion(self):
        a = Assertion(id="AC-001", text="True always passes", type="structural", verify="true")
        result = verify_assertion(a, Path("."))
        assert result.passed is True
        assert result.skipped is False

    def test_verify_failing_assertion(self):
        a = Assertion(id="AC-001", text="File exists", type="structural",
                      verify="test -f /nonexistent/file/path")
        result = verify_assertion(a, Path("."))
        assert result.passed is False

    def test_verify_behavioral_skipped(self):
        a = Assertion(id="AC-001", text="Behavior", type="behavioral")
        result = verify_assertion(a, Path("."))
        assert result.skipped is True

    def test_verify_draft_skipped(self):
        a = Assertion(id="AC-001", text="Draft", type="structural", draft=True)
        result = verify_assertion(a, Path("."))
        assert result.skipped is True

    def test_verify_contract(self, sample_contract):
        result = verify_contract(sample_contract, Path("."))
        assert result["contract_id"] == "F-0099"
        assert result["passed"] >= 1
        assert result["skipped"] >= 1  # behavioral


# ---------------------------------------------------------------------------
# Coverage
# ---------------------------------------------------------------------------

class TestCoverage:
    def test_coverage_report(self, contracts_dir, sample_contract):
        save_contract(sample_contract, contracts_dir / "F-0099.yaml")

        report = coverage_report(contracts_dir)
        assert report["total_assertions"] == 2
        assert report["with_tests"] == 2
        assert report["coverage_pct"] == 100.0
        assert report["gaps"] == []

    def test_coverage_with_gaps(self, contracts_dir):
        c = Contract(
            id="F-0050",
            name="Gappy",
            lifecycle="shipped",
            description="Feature with coverage gaps for testing",
            assertions=[
                Assertion(id="AC-001", text="No tests or verify", type="structural"),
            ],
            protection="contract",
        )
        save_contract(c, contracts_dir / "F-0050.yaml")

        report = coverage_report(contracts_dir)
        assert len(report["gaps"]) == 1
        assert report["gaps"][0]["assertion"] == "AC-001"


# ---------------------------------------------------------------------------
# Lifecycle mapping
# ---------------------------------------------------------------------------

class TestLifecycleMapping:
    def test_shipped_to_status(self):
        assert lifecycle_to_status("shipped") == "shipped"

    def test_implementing_to_status(self):
        assert lifecycle_to_status("implementing") == "in_progress"

    def test_exploring_to_status(self):
        assert lifecycle_to_status("exploring") == "planned"

    def test_deprecated_to_status(self):
        assert lifecycle_to_status("deprecated") == "deprecated"


# ---------------------------------------------------------------------------
# Migration data class
# ---------------------------------------------------------------------------

class TestMigration:
    def test_migration_roundtrip(self):
        m = Migration(
            id="M-2026-03-22-001",
            date="2026-03-22",
            trigger="external",
            reason="API changed",
            changes=["AC-001: updated verify command"],
            approved_by="user",
        )
        d = m.to_dict()
        m2 = Migration.from_dict(d)
        assert m2.id == m.id
        assert m2.trigger == "external"
        assert len(m2.changes) == 1
