#!/usr/bin/env python3
"""
Tests for validate_specs.py - validates core claims:
1. Detects circular dependencies
2. Validates cross-references

Note: Requires yaml, python-frontmatter, jsonschema.
Skips gracefully if not installed.
"""
import sys
from pathlib import Path

# Add .agentic/lib/tools to path
sys.path.insert(0, str(Path(__file__).parent.parent / ".agentic" / "lib" / "tools"))

try:
    from validate_specs import (
        parse_markdown_features,
        detect_circular_dependencies,
        validate_cross_references
    )
    DEPS_AVAILABLE = True
except ImportError as e:
    DEPS_AVAILABLE = False
    MISSING_DEP = str(e)


def test_parse_features():
    """Test parsing features from markdown."""
    fixtures_dir = Path(__file__).parent / "fixtures"
    features = parse_markdown_features(fixtures_dir / "sample_features.md")
    
    assert len(features) == 7  # F-0001 through F-0007
    assert features[0]["id"] == "F-0001"
    assert features[1]["parent"] == "F-0001"


def test_no_circular_dependencies():
    """Test that valid dependencies don't trigger circular detection."""
    fixtures_dir = Path(__file__).parent / "fixtures"
    features = parse_markdown_features(fixtures_dir / "sample_features.md")
    
    errors = detect_circular_dependencies(features)
    assert len(errors) == 0, f"Should have no circular deps, got: {errors}"


def test_circular_dependencies_detected():
    """Test that circular dependencies ARE detected."""
    # Create features with circular dep: F-0001 -> F-0002 -> F-0001
    features = [
        {"id": "F-0001", "dependencies": ["F-0002"], "parent": None},
        {"id": "F-0002", "dependencies": ["F-0001"], "parent": None},
    ]
    
    errors = detect_circular_dependencies(features)
    assert len(errors) == 1, f"Should detect 1 cycle, got {len(errors)}"
    assert "F-0001" in errors[0]
    assert "F-0002" in errors[0]


def test_self_dependency_detected():
    """Test that self-dependency is detected."""
    features = [
        {"id": "F-0001", "dependencies": ["F-0001"], "parent": None},
    ]
    
    errors = detect_circular_dependencies(features)
    assert len(errors) == 1, "Should detect self-dependency"


def test_valid_cross_references():
    """Test that valid parent/dependency references pass validation."""
    fixtures_dir = Path(__file__).parent / "fixtures"
    features = parse_markdown_features(fixtures_dir / "sample_features.md")
    
    errors = validate_cross_references(features)
    assert len(errors) == 0, f"Should have no invalid refs, got: {errors}"


def test_invalid_parent_detected():
    """Test that invalid parent reference is detected."""
    features = [
        {"id": "F-0001", "dependencies": [], "parent": None},
        {"id": "F-0002", "dependencies": [], "parent": "F-9999"},  # Invalid parent
    ]
    
    errors = validate_cross_references(features)
    assert len(errors) == 1, f"Should detect 1 invalid parent, got {len(errors)}"
    assert "F-0002" in errors[0]
    assert "F-9999" in errors[0]


def test_invalid_dependency_detected():
    """Test that invalid dependency reference is detected."""
    features = [
        {"id": "F-0001", "dependencies": ["F-9999"], "parent": None},  # Invalid dep
    ]
    
    errors = validate_cross_references(features)
    assert len(errors) == 1, "Should detect 1 invalid dependency"
    assert "F-0001" in errors[0]
    assert "F-9999" in errors[0]


if __name__ == "__main__":
    if not DEPS_AVAILABLE:
        print("⚠️  Skipping validate_specs tests (missing dependencies)")
        print(f"   Error: {MISSING_DEP}")
        print("   Install: pip install pyyaml python-frontmatter jsonschema")
        sys.exit(0)
    
    print("Running validate_specs tests...")
    
    test_parse_features()
    print("✓ test_parse_features")
    
    test_no_circular_dependencies()
    print("✓ test_no_circular_dependencies")
    
    test_circular_dependencies_detected()
    print("✓ test_circular_dependencies_detected")
    
    test_self_dependency_detected()
    print("✓ test_self_dependency_detected")
    
    test_valid_cross_references()
    print("✓ test_valid_cross_references")
    
    test_invalid_parent_detected()
    print("✓ test_invalid_parent_detected")
    
    test_invalid_dependency_detected()
    print("✓ test_invalid_dependency_detected")
    
    print("\n✅ All validate_specs tests passed!")
    print("   Core claims validated:")
    print("   - Circular dependencies detected ✓")
    print("   - Invalid cross-references caught ✓")

