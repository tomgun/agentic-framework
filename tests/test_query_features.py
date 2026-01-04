#!/usr/bin/env python3
"""
Tests for query_features.py - validates core claim: fast filtering.
"""
import sys
from pathlib import Path

# Add .agentic/tools to path
sys.path.insert(0, str(Path(__file__).parent.parent / ".agentic" / "tools"))

from query_features import parse_features, filter_features, load_features_flat


def test_parse_features():
    """Test that we can parse features from markdown."""
    fixtures_dir = Path(__file__).parent / "fixtures"
    features = load_features_flat(fixtures_dir / "sample_features.md")
    
    assert len(features) == 5, f"Expected 5 features, got {len(features)}"
    assert features[0]["id"] == "F-0001"
    assert features[0]["name"] == "User Authentication"
    assert features[0]["status"] == "shipped"


def test_filter_by_status():
    """Test filtering by status."""
    fixtures_dir = Path(__file__).parent / "fixtures"
    features = load_features_flat(fixtures_dir / "sample_features.md")
    
    class Args:
        status = "in_progress"
        tags = None
        layer = None
        domain = None
        priority = None
        owner = None
        complexity = None
        parent = None
    
    filtered = filter_features(features, Args())
    assert len(filtered) == 2, f"Expected 2 in_progress, got {len(filtered)}"
    assert all(f["status"] == "in_progress" for f in filtered)


def test_filter_by_tags():
    """Test filtering by tags."""
    fixtures_dir = Path(__file__).parent / "fixtures"
    features = load_features_flat(fixtures_dir / "sample_features.md")
    
    class Args:
        status = None
        tags = ["auth"]
        layer = None
        domain = None
        priority = None
        owner = None
        complexity = None
        parent = None
    
    filtered = filter_features(features, Args())
    assert len(filtered) == 3, f"Expected 3 auth features, got {len(filtered)}"
    assert all("auth" in f.get("tags", []) for f in filtered)


def test_filter_by_layer():
    """Test filtering by layer."""
    fixtures_dir = Path(__file__).parent / "fixtures"
    features = load_features_flat(fixtures_dir / "sample_features.md")
    
    class Args:
        status = None
        tags = None
        layer = "presentation"
        domain = None
        priority = None
        owner = None
        complexity = None
        parent = None
    
    filtered = filter_features(features, Args())
    assert len(filtered) == 2, f"Expected 2 presentation features, got {len(filtered)}"
    assert all(f.get("layer") == "presentation" for f in filtered)


def test_filter_combined():
    """Test combining multiple filters."""
    fixtures_dir = Path(__file__).parent / "fixtures"
    features = load_features_flat(fixtures_dir / "sample_features.md")
    
    class Args:
        status = "in_progress"
        tags = ["auth"]
        layer = None
        domain = None
        priority = None
        owner = None
        complexity = None
        parent = None
    
    filtered = filter_features(features, Args())
    assert len(filtered) == 1, f"Expected 1 feature, got {len(filtered)}"
    assert filtered[0]["id"] == "F-0002"


def test_filter_by_owner():
    """Test filtering by owner."""
    fixtures_dir = Path(__file__).parent / "fixtures"
    features = load_features_flat(fixtures_dir / "sample_features.md")
    
    class Args:
        status = None
        tags = None
        layer = None
        domain = None
        priority = None
        owner = "alice@example.com"
        complexity = None
        parent = None
    
    filtered = filter_features(features, Args())
    assert len(filtered) == 2, f"Expected 2 features for alice, got {len(filtered)}"
    assert all(f.get("owner") == "alice@example.com" for f in filtered)


if __name__ == "__main__":
    print("Running query_features tests...")
    test_parse_features()
    print("✓ test_parse_features")
    
    test_filter_by_status()
    print("✓ test_filter_by_status")
    
    test_filter_by_tags()
    print("✓ test_filter_by_tags")
    
    test_filter_by_layer()
    print("✓ test_filter_by_layer")
    
    test_filter_combined()
    print("✓ test_filter_combined")
    
    test_filter_by_owner()
    print("✓ test_filter_by_owner")
    
    print("\n✅ All query_features tests passed!")

